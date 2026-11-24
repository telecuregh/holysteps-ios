import Foundation

/// Android's cycle math (AppViewModel.computeCycleDay / computeCyclePrediction, CycleSigns.predictedCycleLength and
/// daysLate). Dates are the phone's local days.
enum CycleLogic {
    static let lateMaxDays = 60

    static func days(_ a: Date, _ b: Date) -> Int {
        let c = Calendar.current
        return c.dateComponents([.day], from: c.startOfDay(for: a), to: c.startOfDay(for: b)).day ?? 0
    }
    static func plus(_ d: Date, _ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: Calendar.current.startOfDay(for: d)) ?? d }

    /// A late period keeps counting (day 31 of 28); far past due, the days roll on with the usual length.
    static func cycleDay(lastStart: Date, length: Int, today: Date = Date()) -> Int {
        guard length > 0 else { return 1 }
        let diff = days(lastStart, today)
        if diff < 0 { return 1 }
        if diff < length + lateMaxDays { return diff + 1 }
        return diff % length + 1
    }

    static func daysLate(lastStart: Date, length: Int, today: Date = Date()) -> Int {
        let late = days(plus(lastStart, length), today)
        return (1...lateMaxDays).contains(late) ? late : 0
    }

    static func cycleLengths(_ starts: [Date]) -> [Int] {
        let s = starts.sorted()
        return zip(s, s.dropFirst()).map { days($0, $1) }.filter { (15...90).contains($0) }
    }

    /// The average of the last 6 typical cycles out of the last 12; with fewer than 3, the entered length counts too.
    static func predictedLength(_ starts: [Date], fallback: Int) -> Int {
        let base = min(90, max(15, fallback))
        let lens = Array(cycleLengths(starts).suffix(12))
        if lens.isEmpty { return base }
        if lens.count < 3 { return Int((Double(lens.reduce(0, +) + base) / Double(lens.count + 1)).rounded()) }
        let median = lens.sorted()[lens.count / 2]
        var typical = lens.filter { abs($0 - median) <= 9 }
        if typical.isEmpty { typical = lens }
        let last = typical.suffix(6)
        return min(90, max(15, Int((Double(last.reduce(0, +)) / Double(last.count)).rounded())))
    }

    struct Prediction {
        let nextPeriod: Date, fertileStart: Date, fertileEnd: Date, ovulation: Date
        let daysUntil: Int, daysLate: Int
    }

    static func predict(lastStart: Date, length: Int, periodLength: Int, today: Date = Date()) -> Prediction {
        let late = daysLate(lastStart: lastStart, length: length, today: today)
        var start = Calendar.current.startOfDay(for: lastStart)
        var guardN = 0
        while late == 0 && guardN < 24 {
            let probe = plus(start, length)
            if probe > today { break }
            start = probe; guardN += 1
        }
        let next = plus(start, length)
        let ov = max(length - 14, periodLength + 2) - 1
        return Prediction(nextPeriod: next, fertileStart: plus(start, max(0, ov - 5)), fertileEnd: plus(start, ov + 1),
                          ovulation: plus(start, ov), daysUntil: days(today, next), daysLate: late)
    }
}

/// Android's phase plans (data/AppState.kt phasePool), extracted to Resources/cycle_plans.json, with the same daily
/// rotation (dailyRotation / dailyPick on the local epoch day).
struct PhasePlan {
    let whyFeel, move, nourish, mind, mealIdea, mindsetTip: String
    let moveIdeas, eatMore, limitFoods, journalPrompts: [String]

    private static let pools: [String: [String: Any]] = {
        guard let url = Bundle.main.url(forResource: "cycle_plans", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return [:] }
        return obj
    }()

    static var epochDay: Int {
        let now = Date()
        return Int((now.timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT(for: now))) / 86_400)
    }

    static func rotation(_ pool: [String], _ count: Int, _ seed: Int) -> [String] {
        guard !pool.isEmpty else { return [] }
        let n = pool.count, start = ((seed % n) + n) % n
        return (0..<min(count, n)).map { pool[(start + $0) % n] }
    }

    static func forPhase(_ phase: CyclePhase, seed: Int = epochDay) -> PhasePlan? {
        guard let p = pools[phase.rawValue] else { return nil }
        func list(_ k: String) -> [String] { p[k] as? [String] ?? [] }
        func str(_ k: String) -> String { p[k] as? String ?? "" }
        return PhasePlan(whyFeel: rotation(list("whyFeelPool"), 1, seed).first ?? "", move: str("move"), nourish: str("nourish"), mind: str("mind"),
                         mealIdea: rotation(list("mealIdeaPool"), 1, seed).first ?? "", mindsetTip: rotation(list("mindsetTipPool"), 1, seed).first ?? "",
                         moveIdeas: rotation(list("moveIdeasPool"), 4, seed), eatMore: rotation(list("eatMorePool"), 4, seed),
                         limitFoods: rotation(list("limitPool"), 2, seed), journalPrompts: rotation(list("journalPool"), 4, seed))
    }
}

/// Flow and symptoms by day, kept only on this phone.
final class CycleLog: ObservableObject {
    static let shared = CycleLog()
    @Published private(set) var symptoms: [String: [String]] { didSet { UserDefaults.standard.set(symptoms, forKey: "cycleSymptoms") } }
    @Published private(set) var flow: [String: String] { didSet { UserDefaults.standard.set(flow, forKey: "cycleFlow") } }

    private init() {
        symptoms = UserDefaults.standard.dictionary(forKey: "cycleSymptoms") as? [String: [String]] ?? [:]
        flow = UserDefaults.standard.dictionary(forKey: "cycleFlow") as? [String: String] ?? [:]
    }

    var today: Set<String> { Set(symptoms[AppStore.dayKey()] ?? []) }

    func toggle(_ s: String) {
        let k = AppStore.dayKey()
        var list = symptoms[k] ?? []
        if let i = list.firstIndex(of: s) { list.remove(at: i) } else { list.append(s) }
        symptoms[k] = list.isEmpty ? nil : list
        ActivityLog.shared.add(.tracker)
    }

    func setFlow(_ f: String) { flow[AppStore.dayKey()] = f; ActivityLog.shared.add(.tracker) }
    func erase() { symptoms = [:]; flow = [:] }

    static let common = ["😣 Cramps", "😴 Tired", "🌊 Bloating", "🤕 Headache", "😤 Irritable", "😢 Low mood",
                         "😰 Anxious", "🍫 Cravings", "💧 Acne", "🌸 Tender breasts", "🔙 Back pain", "😵 Nausea",
                         "🌙 Poor sleep", "✨ Energetic", "😊 Happy", "💗 High libido"]
    static let flows = ["Spotting", "Light", "Medium", "Heavy"]

    /// Android's symptomRelief: a short, safe care tip for the common symptoms.
    static func relief(_ s: String) -> String? {
        let tips: [(String, String)] = [
            ("Cramps", "Heat on your lower belly and a gentle walk can ease cramps. An over-the-counter pain reliever like ibuprofen, taken as the label says, helps many people."),
            ("Tired", "Prioritize an earlier bedtime and short daylight walks. Iron and hydration help."),
            ("Bloating", "Drink more water, go easy on salt, and try peppermint or ginger tea."),
            ("Headache", "Hydrate, rest your eyes from screens, and try a cool cloth on your forehead."),
            ("Irritable", "Give yourself extra margin today. A slow walk and deep breaths reset the nervous system."),
            ("Low mood", "Reach out to someone you trust and get some sunlight. If low mood lasts for weeks, talk to a doctor."),
            ("Anxious", "Try box breathing: in 4, hold 4, out 4, hold 4. Repeat 4 times."),
            ("Cravings", "Pair sweets with protein or fiber, like dark chocolate with nuts or fruit with yogurt, to keep energy steadier."),
            ("Acne", "Gentle cleansing, no picking, and plenty of water. Hormonal breakouts usually pass with the phase."),
            ("Tender", "A supportive bra and less caffeine can help."),
            ("Back pain", "Heat, gentle stretching (child's pose, cat-cow), and an easy walk."),
            ("Nausea", "Small, plain meals, ginger, and fresh air. Sip water slowly."),
            ("Poor sleep", "Keep your room cool and dark and put the phone away 30 minutes before bed."),
        ]
        return tips.first { s.contains($0.0) }?.1
    }
}
