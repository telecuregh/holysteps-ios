import SwiftUI

/// Kotlin's default Random (XorWow), so the iOS quiz picks exactly what Android picks: the same three questions for
/// everyone each day, with answers in the same order, so friends on either phone can compare.
struct KotlinRandom {
    private var x: Int32, y: Int32, z: Int32, w: Int32, v: Int32, addend: Int32

    init(seed: Int32) {
        let s1 = seed, s2 = seed >> 31
        x = s1; y = s2; z = 0; w = 0; v = ~s1
        addend = (s1 &<< 10) ^ Int32(bitPattern: UInt32(bitPattern: s2) >> 4)
        for _ in 0..<64 { _ = nextInt() }
    }

    mutating func nextInt() -> Int32 {
        var t = x
        t = t ^ Int32(bitPattern: UInt32(bitPattern: t) >> 2)
        x = y; y = z; z = w
        let v0 = v
        w = v0
        v = (v0 ^ (v0 &<< 4)) ^ (t ^ (t &<< 1))
        addend = addend &+ 362437
        return v &+ addend
    }

    /// Kotlin's nextInt(until).
    mutating func nextInt(until n: Int32) -> Int32 {
        precondition(n > 0)
        if n & -n == n {
            let bitCount = Int32(31 - n.leadingZeroBitCount)
            if bitCount == 0 { _ = nextInt(); return 0 }
            return Int32(bitPattern: UInt32(bitPattern: nextInt()) >> UInt32(32 - bitCount)) & ((-bitCount) >> 31)
        }
        while true {
            let bits = Int32(bitPattern: UInt32(bitPattern: nextInt()) >> 1)
            let r = bits % n
            if bits &- r &+ (n - 1) >= 0 { return r }
        }
    }

    /// Kotlin's shuffled(random): Fisher–Yates from the end.
    mutating func shuffled<T>(_ list: [T]) -> [T] {
        var a = list
        var i = a.count - 1
        while i >= 1 {
            let j = Int(nextInt(until: Int32(i + 1)))
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }

    /// Java's String.hashCode.
    static func javaHash(_ s: String) -> Int32 {
        s.utf16.reduce(Int32(0)) { h, c in h &* 31 &+ Int32(c) }
    }
}

struct QuizQuestion: Decodable, Hashable {
    let q: String
    let a: String
    let w: [String]
    let r: String
}

/// Daily Bible quiz (Android's BibleQuiz.kt): three questions a day, about 30 seconds.
enum BibleQuiz {
    static let perDay = 3
    /// Days since 2026-01-01, when the quiz began.
    static let epochDay = 20454

    static let all: [QuizQuestion] = {
        guard let u = Bundle.main.url(forResource: "quiz", withExtension: "json"), let d = try? Data(contentsOf: u) else { return [] }
        return (try? JSONDecoder().decode([QuizQuestion].self, from: d)) ?? []
    }()

    /// The bank in a fixed shuffled order, so days walk through every question before any repeats.
    static let order: [Int] = { var r = KotlinRandom(seed: 2026); return r.shuffled(Array(all.indices)) }()

    static func dayIndex(_ date: Date = Date()) -> Int { SermonWeekLogic.today(date) - epochDay }

    static func today(_ date: Date = Date()) -> [QuizQuestion] {
        guard !all.isEmpty else { return [] }
        let start = dayIndex(date) * perDay
        return (0..<perDay).map { all[order[((start + $0) % all.count + all.count) % all.count]] }
    }

    /// The four answers in an order fixed for the day, so a reopened quiz looks the same.
    static func options(_ q: QuizQuestion, dateKey: String) -> [String] {
        var r = KotlinRandom(seed: KotlinRandom.javaHash(dateKey + q.q))
        return r.shuffled(q.w + [q.a])
    }
}

@MainActor
final class QuizLog: ObservableObject {
    static let shared = QuizLog()
    /// "yyyy-MM-dd" → correct answers, the last 90 days.
    @Published private(set) var log: [String: Int] {
        didSet {
            let keep = log.keys.sorted().suffix(90)
            UserDefaults.standard.set(log.filter { keep.contains($0.key) }, forKey: "quizLog")
        }
    }
    private init() { log = UserDefaults.standard.dictionary(forKey: "quizLog") as? [String: Int] ?? [:] }

    func record(_ score: Int) { log[AppStore.dayKey()] = score }

    /// Days in a row the quiz was played, ending today (or yesterday while today is still open).
    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        if log[AppStore.dayKey(day)] == nil { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var n = 0
        while log[AppStore.dayKey(day)] != nil { n += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        return n
    }
    func erase() { log = [:] }
}

struct QuizCard: View {
    @ObservedObject private var quiz = QuizLog.shared

    var body: some View {
        let played = quiz.log[AppStore.dayKey()]
        NavigationLink { BibleQuizView() } label: {
            GlassCard {
                HStack(spacing: 12) {
                    Text(verbatim: "🧠").font(.title)
                    VStack(alignment: .leading, spacing: 2) {
                        T("Daily Bible quiz").font(.headline).foregroundStyle(HS.text)
                        if let p = played {
                            Text(verbatim: tr("Today: \(p) of \(BibleQuiz.perDay)") + (quiz.streak > 1 ? " · 🔥 " + tr("\(quiz.streak) days") : "") + " · " + tr("new one tomorrow"))
                                .font(.caption).foregroundStyle(HS.textMuted)
                        } else {
                            T("3 questions · 30 seconds").font(.caption).foregroundStyle(HS.textMuted)
                        }
                    }
                    Spacer()
                    T(played != nil ? "✓" : "Play →").font(.footnote.bold()).foregroundStyle(played != nil ? HS.body : HS.peach)
                }
            }
        }
    }
}

struct BibleQuizView: View {
    @ObservedObject private var quiz = QuizLog.shared
    private let questions = BibleQuiz.today()
    private let dateKey = AppStore.dayKey()
    @State private var index = 0
    @State private var picked: String?
    @State private var correct = 0
    @State private var started = Date()
    @State private var seconds = 0

    private let right = Color(hex: 0x34D399)
    private let wrong = Color(hex: 0xF87171)

    var body: some View {
        let played = quiz.log[dateKey]
        let finished = played != nil || index >= questions.count
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("Daily Bible quiz").font(.system(size: 26, weight: .semibold)).foregroundStyle(HS.text)
                    T("Three questions, about 30 seconds. Everyone gets the same three today.").font(.footnote).foregroundStyle(HS.textMuted)
                    if !finished, index < questions.count {
                        question(questions[index])
                    } else {
                        result(played ?? correct)
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func question(_ q: QuizQuestion) -> some View {
        ProgressView(value: Double(index), total: Double(questions.count)).tint(HS.goldButton)
        T("Question \(index + 1) of \(questions.count)").font(.caption.bold()).foregroundStyle(HS.gold)
        T(q.q).font(.title3.weight(.semibold)).foregroundStyle(HS.text)
        ForEach(BibleQuiz.options(q, dateKey: dateKey), id: \.self) { opt in
            let show = picked != nil
            let isRight = opt == q.a
            let chosen = picked == opt
            Button {
                guard picked == nil else { return }
                picked = opt
                if isRight { correct += 1 }
            } label: {
                T(opt).foregroundStyle(HS.text).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(show && isRight ? right.opacity(0.15) : (show && chosen ? wrong.opacity(0.15) : HS.card)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(show && isRight ? right : (show && chosen ? wrong : HS.gold.opacity(0.3)), lineWidth: show && (chosen || isRight) ? 2 : 1))
            }
            .buttonStyle(.plain)
            .disabled(show)
        }
        if let p = picked {
            Text(verbatim: p == q.a ? tr("Correct!") + " · " + tr(q.r) : tr("The answer is") + " " + tr(q.a) + " · " + tr(q.r))
                .font(.footnote.weight(.semibold)).foregroundStyle(p == q.a ? right : HS.textMuted)
            GoldButton(title: index + 1 >= questions.count ? "See my score" : "Next question") {
                picked = nil
                index += 1
                if index >= questions.count {
                    seconds = Int(Date().timeIntervalSince(started))
                    quiz.record(correct)
                }
            }
        }
    }

    private func result(_ score: Int) -> some View {
        let perfect = score == BibleQuiz.perDay
        let share = (perfect ? "I got 3 out of 3 on today's HolySteps Bible quiz! 🏆 Can you?"
                     : "I got \(score) out of 3 on today's HolySteps Bible quiz. Can you beat me?") + " " + tr("Same three questions for everyone today:") + " " + AppLinks.site
        return GlassCard {
            VStack(spacing: 8) {
                Text(verbatim: perfect ? "🏆" : (score > 0 ? "📖" : "🌱")).font(.system(size: 44))
                Text(verbatim: tr("\(score) of \(BibleQuiz.perDay)")).font(.system(size: 30, weight: .heavy)).foregroundStyle(HS.text)
                T(perfect ? "Perfect!" : (score > 0 ? "Well done." : "Every question is a chance to learn. Try again tomorrow."))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(HS.gold).multilineTextAlignment(.center)
                if seconds > 0 && seconds <= 600 { Text(verbatim: "\(seconds)s").font(.caption).foregroundStyle(HS.textMuted) }
                if quiz.streak > 1 { T("🔥 \(quiz.streak) days in a row").font(.footnote).foregroundStyle(HS.textMuted) }
                ShareLink(item: tr(share)) {
                    T(perfect ? "Share my perfect score" : "Challenge a friend").font(.headline).foregroundStyle(HS.onGold)
                        .frame(maxWidth: .infinity).padding(.vertical, 13).background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
                }
                T("A new quiz opens tomorrow.").font(.caption2).foregroundStyle(HS.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
