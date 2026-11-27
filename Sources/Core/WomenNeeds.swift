import Foundation
import SwiftUI

// MARK: - PeriStage (STRAW+10 perimenopause detection)

/// Mirrors Android's data/WomenNeeds.kt PeriStage.
/// STRAW+10 criteria:
///   Early transition: ≥2 consecutive cycles differing by ≥7 days from the previous cycle.
///   Late transition:  ≥60 consecutive days without a period.
///   Twelve months:    12 months since the last period (clinical menopause).
/// Source: Harlow et al. 2012, Menopause 19(4):387-395.
enum PeriStage: String {
    case notEnough   = "NOT_ENOUGH"
    case steady      = "STEADY"
    case early       = "EARLY"
    case late        = "LATE"
    case twelveMonths = "TWELVE_MONTHS"

    static let source = "STRAW+10 staging criteria · Harlow et al., Menopause 2012"
    static let seeADoctor = "Any bleeding that returns after 12 months without a period always needs a doctor visit right away."

    static func read(starts: [Date], today: Date = Date()) -> PeriStage {
        let sorted = starts.map { Calendar.current.startOfDay(for: $0) }.sorted()
        guard sorted.count >= 2 else { return .notEnough }

        // 12-month rule
        if let last = sorted.last {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: Calendar.current.startOfDay(for: today)).day ?? 0
            if daysSince >= 365 { return .twelveMonths }
            if daysSince >= 60  { return .late }
        }

        // Gap list
        let gaps = zip(sorted, sorted.dropFirst()).map { b, a -> Int in
            Calendar.current.dateComponents([.day], from: b, to: a).day ?? 0
        }.filter { (15...90).contains($0) }

        guard gaps.count >= 2 else { return .notEnough }

        // Early transition: ≥2 consecutive gaps differing by ≥7 days
        for i in 0 ..< gaps.count - 1 {
            if abs(gaps[i] - gaps[i + 1]) >= 7 { return .early }
        }
        return .steady
    }
}

// MARK: - PredictionRange (confidence-aware next-period window)

/// Mirrors Android's data/WomenNeeds.kt PredictionRange.
struct PredictionRange {
    enum Confidence: String { case low, medium, high }

    let earliest: Date
    let latest: Date
    let confidence: Confidence
    let why: String

    static func forNext(
        starts: [Date],
        predictedNext: Date,
        isIrregular: Bool,
        periStage: PeriStage
    ) -> PredictionRange {
        let cal = Calendar.current

        switch periStage {
        case .late, .twelveMonths:
            return PredictionRange(
                earliest: predictedNext,
                latest: cal.date(byAdding: .day, value: 60, to: predictedNext) ?? predictedNext,
                confidence: .low,
                why: "Cycles are very irregular in the late transition. This is a rough estimate only."
            )
        case .early:
            return PredictionRange(
                earliest: cal.date(byAdding: .day, value: -7, to: predictedNext) ?? predictedNext,
                latest: cal.date(byAdding: .day, value: 7, to: predictedNext) ?? predictedNext,
                confidence: .medium,
                why: "Your cycle length has been variable. The window is wider to account for that."
            )
        default:
            if isIrregular {
                return PredictionRange(
                    earliest: cal.date(byAdding: .day, value: -5, to: predictedNext) ?? predictedNext,
                    latest: cal.date(byAdding: .day, value: 5, to: predictedNext) ?? predictedNext,
                    confidence: .medium,
                    why: "Your cycles vary a little. This ±5-day window covers most of them."
                )
            } else {
                return PredictionRange(
                    earliest: cal.date(byAdding: .day, value: -2, to: predictedNext) ?? predictedNext,
                    latest: cal.date(byAdding: .day, value: 2, to: predictedNext) ?? predictedNext,
                    confidence: .high,
                    why: "Your cycle has been consistent. This tight window should be close."
                )
            }
        }
    }
}

// MARK: - PregnancyLoss

/// Mirrors Android's data/WomenNeeds.kt PregnancyLoss.
/// Loss data is never shared with partner coaching, Cycle Circles, or any AI feature.
final class PregnancyLoss: ObservableObject {
    static let shared = PregnancyLoss()

    @Published private(set) var since: Date?
    @Published private(set) var paused: Bool = false

    private let key = "loss_since_v1"
    private let pausedKey = "loss_paused_v1"

    private init() {
        if let ts = UserDefaults.standard.object(forKey: key) as? Double {
            since = Date(timeIntervalSince1970: ts)
        }
        paused = UserDefaults.standard.bool(forKey: pausedKey)
    }

    var isActive: Bool { since != nil }

    func start() {
        since = Calendar.current.startOfDay(for: Date())
        paused = false
        save()
    }

    func resume() {
        paused = false
        save()
    }

    func pause() {
        paused = true
        save()
    }

    /// Called when the user logs a new period start — marks the healing path as returned.
    func periodLogged() {
        // Keep the record but mark it resolved so CycleView can show the gentle "returned" message.
        guard since != nil else { return }
        clear()
    }

    func clear() {
        since = nil; paused = false
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: pausedKey)
    }

    private func save() {
        if let d = since { UserDefaults.standard.set(d.timeIntervalSince1970, forKey: key) }
        UserDefaults.standard.set(paused, forKey: pausedKey)
    }

    // MARK: Content strings

    static let opening       = "This is a safe, private space on your phone. Nothing here is shared."
    static let notYourFault  = "A loss is never your fault. Most early losses happen because of chromosomal differences that could not be changed."
    static let whatToExpect  = "Your period usually returns in 4–6 weeks. Ovulation can happen as soon as 2 weeks after a loss, before your first period back."
    static let callDoctor    = "Call your doctor if you soak more than 2 pads in an hour for 2 hours in a row, have a fever above 100.4 °F, or notice severe pain or foul-smelling discharge."
    static let emergency     = "Go to the ER or call 911 for heavy bleeding that won't slow, fainting, or severe chest pain."
    static let grief         = "Grief after a loss is real and can come in waves — sadness, anger, numbness — sometimes together. All of that is normal."
    static let support       = "Talking to your doctor, a counselor, or a trusted friend can help. The National Alliance for Eating Disorders helpline is at 1-866-662-1235. For crisis support: 988 Lifeline."
    static let tryingAgain   = "Most doctors suggest waiting one full menstrual cycle before trying again, but the right timing is a personal decision to make with your doctor."
    static let prayer        = ""The Lord is close to the brokenhearted and saves those who are crushed in spirit." — Psalm 34:18 (KJV)"
    static let source        = "Sources: ACOG Practice Bulletin 150; Mayo Clinic pregnancy loss recovery guidelines."
}

// MARK: - CycleFacts (sourced Q&As for Insights tab)

struct CycleFact: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let source: String
}

enum CycleFacts {
    static let all: [CycleFact] = [
        CycleFact(
            question: "What is a normal cycle length?",
            answer: "Most cycles are 21–35 days long. The average is about 28 days, but anywhere in that range is considered normal.",
            source: "ACOG FAQ — Menstruation in Girls and Adolescents"
        ),
        CycleFact(
            question: "How long does a normal period last?",
            answer: "A typical period lasts 2–7 days. Shorter or longer may be worth mentioning to your doctor.",
            source: "CDC — Women's Reproductive Health"
        ),
        CycleFact(
            question: "When does ovulation happen?",
            answer: "Ovulation usually happens around 12–16 days before your next period — not necessarily on day 14, since that is based on a textbook 28-day cycle.",
            source: "ACOG Patient FAQ — Fertility Awareness Methods"
        ),
        CycleFact(
            question: "What is the fertile window?",
            answer: "The fertile window is roughly the 5 days before ovulation plus ovulation day itself. Sperm can survive up to 5 days inside the body.",
            source: "Mayo Clinic — Conception: How It Works"
        ),
        CycleFact(
            question: "What counts as heavy bleeding?",
            answer: "Soaking a pad or tampon every hour for several hours in a row, passing clots larger than a quarter, or bleeding for more than 7 days. Talk to your doctor if this happens.",
            source: "CDC — Heavy Menstrual Bleeding"
        ),
        CycleFact(
            question: "What is perimenopause?",
            answer: "Perimenopause is the transition to menopause, usually lasting 4–8 years. Early signs include cycles that are 7 or more days shorter or longer than usual. Late perimenopause can include gaps of 60 days or more.",
            source: "STRAW+10 staging · Harlow et al., Menopause 2012"
        ),
        CycleFact(
            question: "Does stress affect your cycle?",
            answer: "Yes. High stress can delay or suppress ovulation, lengthen your cycle, or even stop your period temporarily.",
            source: "ACOG — Stress and Your Period"
        ),
        CycleFact(
            question: "What is HolySteps not?",
            answer: "HolySteps is not a medical device and cannot diagnose anything. Talk to your doctor about heavy bleeding, severe pain, missed periods, or any health concern.",
            source: "HolySteps — About this app"
        ),
    ]
}
