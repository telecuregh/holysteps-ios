import Foundation
import SwiftUI

enum ReaderFont: String, Codable, CaseIterable, Identifiable {
    case serif, sans
    var id: String { rawValue }
    var label: String { self == .serif ? "Serif" : "Sans" }
}

/// How the reader shows the text. Kept on this phone.
struct ReaderPrefs: Codable, Equatable {
    static let sizes = 13...32
    static let lines: [Double] = [1.3, 1.45, 1.6, 1.8, 2.0]

    var textSize: Int = 17
    var lineSpacing: Double = 1.6
    var font: ReaderFont = .sans
    var highContrast = false
    var verseNumbers = true

    /// Android sets the whole line height (size × spacing); iOS adds space between lines, and a font's own line
    /// is about 1.2 × its size, so the gap is the difference.
    var lineGap: CGFloat { CGFloat(max(0, Double(textSize) * (lineSpacing - 1.2))) }
}

/// Where the person is in the Bible, which translation they read, their highlights and notes, the chapters they've
/// read and their one-year plan. Everything stays on the phone (UserDefaults).
@MainActor
final class BibleState: ObservableObject {
    static let shared = BibleState()

    @Published var translationId: String { didSet { d.set(translationId, forKey: "bibleTranslation") } }
    @Published var lastBook: String { didSet { d.set(lastBook, forKey: "bibleLastBook") } }
    @Published var lastCh: Int { didSet { d.set(lastCh, forKey: "bibleLastCh") } }
    @Published private(set) var highlights: [Highlight] { didSet { saveHighlights() } }
    @Published private(set) var chaptersRead: Set<String> { didSet { d.set(Array(chaptersRead), forKey: "bibleChaptersRead") } }
    @Published var planStart: Date? { didSet { d.set(planStart, forKey: "biblePlanStart") } }
    /// Android's Bible reading plan counter: the next day of the one-year plan to read, and the date the last was done.
    @Published private(set) var readingDay: Int { didSet { d.set(readingDay, forKey: "bibleReadingDay") } }
    @Published private(set) var readingDate: String { didSet { d.set(readingDate, forKey: "bibleReadingDate") } }
    @Published var prefs: ReaderPrefs { didSet { if let data = try? JSONEncoder().encode(prefs) { d.set(data, forKey: "bibleReaderPrefs") } } }

    private let d = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        translationId = d.string(forKey: "bibleTranslation") ?? Bible.defaultId(phoneLang: I18n.shared.bibleLang)
        lastBook = d.string(forKey: "bibleLastBook") ?? "John"
        lastCh = max(1, d.integer(forKey: "bibleLastCh"))
        chaptersRead = Set(d.stringArray(forKey: "bibleChaptersRead") ?? [])
        planStart = d.object(forKey: "biblePlanStart") as? Date
        readingDay = max(1, d.integer(forKey: "bibleReadingDay"))
        readingDate = d.string(forKey: "bibleReadingDate") ?? ""
        prefs = (d.data(forKey: "bibleReaderPrefs")).flatMap { try? JSONDecoder().decode(ReaderPrefs.self, from: $0) } ?? ReaderPrefs()
        if let data = d.data(forKey: "bibleHighlights"), let list = try? JSONDecoder().decode([Highlight].self, from: data) {
            highlights = Highlights.keepNewestPerVerse(Array(list.suffix(Highlights.max)))
        } else {
            highlights = []
        }
    }

    private func saveHighlights() {
        if let data = try? JSONEncoder().encode(Array(highlights.suffix(Highlights.max))) { d.set(data, forKey: "bibleHighlights") }
    }

    static var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    func toggleHighlight(_ h: Highlight) { highlights = Highlights.toggle(highlights, h) }

    func saveNote(book: String, ch: Int, v: Int, verseText: String, translation: String, note: String) {
        highlights = Highlights.withNote(highlights, book: book, ch: ch, v: v, verseText: verseText, translation: translation, note: note, nowMs: BibleState.nowMs)
    }

    func setNote(key: String, note: String) {
        guard let h = highlights.first(where: { $0.key == key }) else { return }
        saveNote(book: h.book, ch: h.ch, v: h.v, verseText: h.text, translation: h.translation, note: note)
    }

    func marks(book: String, ch: Int) -> [Int: Highlight] {
        Dictionary(highlights.filter { $0.book == book && $0.ch == ch }.map { ($0.v, $0) }, uniquingKeysWith: { _, b in b })
    }

    func setLast(_ book: String, _ ch: Int) {
        if lastBook != book { lastBook = book }
        if lastCh != ch { lastCh = ch }
    }

    // MARK: Reading

    static func chapterKey(_ book: String, _ ch: Int) -> String { "\(book)|\(ch)" }
    func isRead(_ book: String, _ ch: Int) -> Bool { chaptersRead.contains(BibleState.chapterKey(book, ch)) }

    /// A chapter read to its end, or heard to its last verse. It also counts for today's reading streak.
    func chapterRead(_ book: String, _ ch: Int, store: AppStore?) {
        let k = BibleState.chapterKey(book, ch)
        if !chaptersRead.contains(k) { chaptersRead.insert(k) }
        store?.readDays.insert(AppStore.dayKey())
        // Reading every chapter of today's plan completes the day.
        if !bibleReadToday, BiblePlan.chapters(day: shownDay).allSatisfy({ isRead($0.book, $0.ch) }) { completeBibleReading(store: store) }
    }

    // MARK: One-year plan

    var bibleReadToday: Bool { readingDate == AppStore.dayKey() }
    /// Once today's reading is done the plan keeps showing today's day (the next one opens tomorrow).
    var shownDay: Int { (max(1, bibleReadToday ? readingDay - 1 : readingDay) - 1) % BiblePlan.days + 1 }

    func completeBibleReading(store: AppStore?) {
        guard !bibleReadToday else { return }
        readingDate = AppStore.dayKey()
        readingDay += 1
        store?.readDays.insert(AppStore.dayKey())
    }

    var planDay: Int? {
        guard let start = planStart else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: Date())).day ?? 0
        return max(1, days + 1)
    }

    func startPlan() { planStart = Calendar.current.startOfDay(for: Date()) }
    func stopPlan() { planStart = nil }

    /// Profile → Erase: highlights, notes, chapters read and the plan. Downloaded Bibles stay (they're public texts).
    func eraseAll() {
        highlights = []
        chaptersRead = []
        planStart = nil
        readingDay = 1
        readingDate = ""
    }

    func planDone(day: Int) -> Bool { BiblePlan.chapters(day: day).allSatisfy { isRead($0.book, $0.ch) } }
}
