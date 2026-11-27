import SwiftUI
import HealthKit

/// Android's Walk through the Bible (BibleWalk.kt, BibleWalkScreen.kt): every kilometer walked since the start day opens
/// the next chapter, Genesis 1 to Revelation 22 (1,189 chapters). Walking opens chapters; reading them is up to her, and
/// both counts are kept. Steps come from Apple Health (summed since the start day) plus walks logged by hand.
enum BibleWalk {
    static let books: [(String, Int)] = [
        ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34), ("Joshua", 24),
        ("Judges", 21), ("Ruth", 4), ("1 Samuel", 31), ("2 Samuel", 24), ("1 Kings", 22), ("2 Kings", 25),
        ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10), ("Nehemiah", 13), ("Esther", 10), ("Job", 42),
        ("Psalms", 150), ("Proverbs", 31), ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66), ("Jeremiah", 52),
        ("Lamentations", 5), ("Ezekiel", 48), ("Daniel", 12), ("Hosea", 14), ("Joel", 3), ("Amos", 9),
        ("Obadiah", 1), ("Jonah", 4), ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3), ("Zephaniah", 3),
        ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4), ("Matthew", 28), ("Mark", 16), ("Luke", 24),
        ("John", 21), ("Acts", 28), ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13), ("Galatians", 6),
        ("Ephesians", 6), ("Philippians", 4), ("Colossians", 4), ("1 Thessalonians", 5), ("2 Thessalonians", 3), ("1 Timothy", 6),
        ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1), ("Hebrews", 13), ("James", 5), ("1 Peter", 5),
        ("2 Peter", 3), ("1 John", 5), ("2 John", 1), ("3 John", 1), ("Jude", 1), ("Revelation", 22)
    ]
    static let total = books.reduce(0) { $0 + $1.1 }
    static let strideKm = 0.000762
    static var stepsPerChapter: Int { Int(1 / strideKm) }

    static func chapter(_ n: Int) -> (book: String, ch: Int) {
        var left = min(max(n, 1), total)
        for b in books { if left <= b.1 { return (b.0, left) }; left -= b.1 }
        return (books.last!.0, books.last!.1)
    }
    static func label(_ n: Int) -> String { let c = chapter(n); return c.book == "Psalms" ? "Psalm \(c.ch)" : "\(c.book) \(c.ch)" }
    static func booksDone(_ chapters: Int) -> Int {
        var left = chapters, done = 0
        for b in books { if left < b.1 { break }; left -= b.1; done += 1 }
        return done
    }
    static func milestone(_ chapters: Int) -> String? {
        guard chapters > 0 else { return nil }
        if chapters >= total { return "You walked through the whole Bible, Genesis to Revelation!" }
        let c = chapter(chapters)
        guard let b = books.first(where: { $0.0 == c.book }), c.ch == b.1 else { return nil }
        switch c.book {
        case "Deuteronomy": return "You walked through the Law, Genesis to Deuteronomy!"
        case "Malachi": return "You walked through the whole Old Testament!"
        case "John": return "You walked through all four Gospels!"
        case "Psalms": return "You walked through all 150 Psalms!"
        default: return "You finished \(c.book)!"
        }
    }
    struct Progress { let started: Bool; let km: Double; let unlocked, read, stepsToNext: Int
        var waiting: Int { max(0, unlocked - read) }; var fraction: Double { Double(unlocked) / Double(total) } }
    static func progress(steps: Int, started: Bool, read: Int) -> Progress {
        guard started else { return Progress(started: false, km: 0, unlocked: 0, read: 0, stepsToNext: stepsPerChapter) }
        let km = Double(max(0, steps)) * strideKm
        let unlocked = min(max(Int(km), 0), total)
        let next = unlocked >= total ? 0 : max(1, Int((Double(unlocked + 1) - km) / strideKm))
        return Progress(started: true, km: km, unlocked: unlocked, read: min(max(read, 0), unlocked), stepsToNext: next)
    }
}

@MainActor
final class BibleWalkModel: ObservableObject {
    @AppStorage("bibleWalkStart") var start = ""          // dayKey
    @AppStorage("bibleWalkRead") var read = 0
    @AppStorage("bibleWalkSeen") var seen = 0
    @Published var steps = 0
    @Published var celebrate: String?
    private let health = HKHealthStore()

    var progress: BibleWalk.Progress { BibleWalk.progress(steps: steps, started: !start.isEmpty, read: read) }

    func refresh() async {
        guard let from = AppStore.date(fromKey: start) else { steps = 0; return }
        var total = 0
        if HKHealthStore.isHealthDataAvailable(), let type = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            total = await withCheckedContinuation { (c: CheckedContinuation<Int, Never>) in
                let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: from, end: Date()),
                                          options: .cumulativeSum) { _, s, _ in c.resume(returning: Int(s?.sumQuantity()?.doubleValue(for: .count()) ?? 0)) }
                health.execute(q)
            }
        }
        let manual = (UserDefaults.standard.dictionary(forKey: "manualSteps") as? [String: Int] ?? [:]).filter { $0.key >= start }.values.reduce(0, +)
        steps = total + manual
        let u = progress.unlocked
        if u > seen { celebrate = (seen + 1...u).reversed().lazy.compactMap { BibleWalk.milestone($0) }.first; seen = u }
    }
    func begin() { start = AppStore.dayKey(); read = 0; seen = 0; steps = 0 }
    func markRead(_ yes: Bool) { read = min(max(read + (yes ? 1 : -1), 0), progress.unlocked) }
}

struct BibleWalkView: View {
    @StateObject private var m = BibleWalkModel()
    @State private var reading: Int?
    @State private var restart = false

    var body: some View {
        let p = m.progress
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GlassCard(warm: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            T("📖 WALK THROUGH THE BIBLE").font(.hs(11, .semibold)).foregroundStyle(HS.readable(0xD9B49F))
                            D(!p.started ? tr("About 1,300 steps, one chapter")
                              : p.unlocked == 0 ? tr("Genesis 1 is \(p.stepsToNext.formatted()) steps away")
                              : tr("You've walked into \(BibleWalk.label(p.unlocked))")).font(.hs(24)).foregroundStyle(HS.text)
                            T("step by step through Scripture").font(.hs(14).italic()).foregroundStyle(HS.textSecondary)
                            if p.started {
                                ProgressView(value: p.fraction).tint(Color(hex: 0xD9B49F))
                                D(tr("\(p.unlocked) of \(BibleWalk.total) chapters opened · \(p.read) read · \(BibleWalk.booksDone(p.unlocked)) books walked"))
                                    .font(.hs(12)).foregroundStyle(HS.textMuted)
                                if p.unlocked < BibleWalk.total {
                                    D(tr("\(p.stepsToNext.formatted()) steps to \(BibleWalk.label(p.unlocked + 1))")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                            }
                        }
                    }
                    if !p.started {
                        T("Every kilometer you walk (about 1,300 steps) opens the next chapter, Genesis 1 to Revelation 22. Your walking opens chapters; reading them is up to you, and HolySteps keeps both counts so you can see whether your reading keeps pace with your feet.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        GoldButton(title: "Start at Genesis 1 today") { m.begin() }
                    } else {
                        if p.waiting > 0 {
                            let next = p.read + 1
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    D(tr("Next to read: \(BibleWalk.label(next))")).font(.hs(15, .bold)).foregroundStyle(HS.text)
                                    D(tr("\(p.waiting) opened chapter\(p.waiting == 1 ? "" : "s") waiting")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                    HStack {
                                        GoldButton(title: "Read it") { reading = next }
                                        Button(tr("Mark as read")) { m.markRead(true) }.buttonStyle(.bordered)
                                    }
                                }
                            }
                        } else if p.read > 0 {
                            T("You've read every chapter you've walked to. Keep walking to open the next one.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        }
                        if p.read > 0 { Button(tr("Take back the last chapter marked read")) { m.markRead(false) }.font(.hs(12)).foregroundStyle(HS.textMuted) }
                        Button(tr("Start again from Genesis 1")) { restart = true }.font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    T("Steps come from Apple Health, plus walks you log by hand.").font(.hs(11)).foregroundStyle(HS.textMuted)
                }.padding(20)
            }.refreshable { await m.refresh() }
        }
        .task { await m.refresh() }
        .sheet(item: Binding(get: { reading.map { WalkChapter(n: $0) } }, set: { reading = $0?.n })) { c in
            let ch = BibleWalk.chapter(c.n)
            NavigationStack { BibleReaderView(startBook: ch.book, startCh: ch.ch) }
        }
        .alert(tr("Start again?"), isPresented: $restart) {
            Button(tr("Start again"), role: .destructive) { m.begin() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("Your walk goes back to Genesis 1 from today. Your chapters read go back to zero.") }
        .alert(Text(tr(m.celebrate ?? "")), isPresented: Binding(get: { m.celebrate != nil }, set: { if !$0 { m.celebrate = nil } })) {
            Button(tr("Amen")) { m.celebrate = nil }
        }
    }
}

private struct WalkChapter: Identifiable { let n: Int; var id: Int { n } }
