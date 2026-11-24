import Foundation
import CryptoKit
import SwiftUI

/// One sermon, from Android's Sermons.kt, FacingSermons.kt and BibleSermons.kt (extracted to Resources/sermons.json.gz
/// by tools/sermons2json.py). Scripts use the same light markup as Android's Audio Sanctuary: blank-line separated
/// paragraphs, "[PAUSE 6 SECONDS]" for silence, any other bracketed line is a stage direction and is skipped.
struct Sermon: Identifiable, Decodable, Hashable {
    enum Group: String, Decodable { case weekly, facing, books, seasons }

    let id: String
    let group: Group
    let title: String
    let subtitle: String
    let scene: String
    /// Joel's recordings (ElevenLabs). They're served only to signed-in accounts (phase 2); until then the sermon is
    /// read from its script.
    let recorded: [String]
    let script: String

    static func == (a: Sermon, b: Sermon) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var segments: [Segment] { Sermon.parse(script) }

    /// Narration pace for estimates: 135 words a minute, as on Android.
    var estimatedSeconds: Int {
        segments.reduce(0) { sum, s in
            switch s {
            case .speech(let t): return sum + max(2, Int(Double(t.split(whereSeparator: \.isWhitespace).count) * 60 / 135 + 0.8))
            case .pause(let n): return sum + n
            }
        }
    }
    var minutesLabel: String { "\(max(1, (estimatedSeconds + 30) / 60)) min" }

    /// Voice-pack id on holysteps.org/voice ("j_" + the sermon id).
    var packId: String { "j_\(id)" }

    enum Segment: Equatable {
        case speech(String)
        case pause(Int)
    }

    private static let pauseRe = try! NSRegularExpression(pattern: #"^\[\s*PAUSE\s+(\d+)\s*(SECONDS?|SEC|S)?\s*]$"#, options: .caseInsensitive)

    static func parse(_ script: String) -> [Segment] {
        var out: [Segment] = []
        var paragraph: [String] = []
        func flush() {
            let text = paragraph.joined(separator: " ").split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if !text.isEmpty { out.append(.speech(text)) }
            paragraph.removeAll()
        }
        for raw in script.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush() }
            else if line.hasPrefix("[") && line.hasSuffix("]") {
                flush()
                let ns = line as NSString
                if let m = pauseRe.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
                   let n = Int(ns.substring(with: m.range(at: 1))) {
                    out.append(.pause(min(120, max(1, n))))
                }
            } else { paragraph.append(line) }
        }
        flush()
        return out
    }
}

/// Text as the narrator speaks it, and its key in a voice pack (Android's spokenText / narrationKey).
enum Narration {
    private static let fraction = try! NSRegularExpression(pattern: #"(\d+)\s*/\s*(\d+)"#)

    static func spoken(_ caption: String) -> String {
        var s = caption.replacingOccurrences(of: "LORD", with: "Lord").replacingOccurrences(of: "GOD", with: "God")
            .replacingOccurrences(of: " \u{2014} ", with: ", ").replacingOccurrences(of: "\u{2014}", with: ", ")
            .replacingOccurrences(of: "\u{2026}", with: "...").replacingOccurrences(of: " \u{00B7} ", with: ", ")
        s = fraction.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "$1 of $2")
        s = s.replacingOccurrences(of: "\u{00B0}", with: " degrees")
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The first 16 hex digits of SHA-1 of the spoken words.
    static func key(_ caption: String) -> String {
        Insecure.SHA1.hash(data: Data(spoken(caption).utf8)).map { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}

enum SermonLibrary {
    static let all: [Sermon] = {
        guard let data = Bundle.main.resourceData("sermons.json.gz"),
              let list = try? JSONDecoder().decode([Sermon].self, from: data) else { return [] }
        return list
    }()
    private static let byId: [String: Sermon] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func sermon(_ id: String) -> Sermon? { byId[id] ?? byId["sermon_\(id)"] }
    static var weekly: [Sermon] { all.filter { $0.group == .weekly } }
    static var books: [Sermon] { all.filter { $0.group == .books } }
    static var seasons: [Sermon] { all.filter { $0.group == .seasons } }

    /// Weekly sermons the preacher voice reads (not Joel's recordings): the free weekly rotation on Android.
    static var narratedWeekly: [Sermon] { weekly.filter { $0.recorded.isEmpty } }

    /// Joel's facing-topic recording → the weekly sermon on the same topic (Android's FacingSermons.JOEL_FOR, reversed).
    static let weeklyForFacing: [String: String] = [
        "01": "when_worry_wont_stop", "02": "when_the_dark_days_come", "03": "when_hope_feels_far",
        "04": "when_you_lose_someone", "05": "lonely_in_a_crowd", "07": "when_you_dont_feel_enough",
        "08": "when_youre_burned_out", "09": "when_everything_is_too_much", "10": "when_the_future_scares_you",
        "12": "when_anger_takes_over", "13": "when_you_cant_sleep", "14": "when_the_past_wont_let_you_sleep",
        "15": "when_youre_fighting_addiction", "16": "when_your_heart_is_broken", "17": "when_you_compare_yourself",
        "18": "when_the_pain_doesnt_go_away",
    ]
}

// MARK: - The weekly sermon

/// Week math from Android's SermonWeekLogic: a new sermon each week on the person's sermon day (Sunday by default).
enum SermonWeekLogic {
    /// ISO day of the week: 1 = Monday … 7 = Sunday (1970-01-01 was a Thursday).
    static func dayOfWeek(_ epochDay: Int) -> Int { ((epochDay + 3) % 7 + 7) % 7 + 1 }
    static func weekStart(_ epochDay: Int, _ sermonDay: Int) -> Int { epochDay - ((dayOfWeek(epochDay) - sermonDay) % 7 + 7) % 7 }
    static func floorDiv(_ a: Int, _ b: Int) -> Int { Int((Double(a) / Double(b)).rounded(.down)) }
    static func index(_ epochDay: Int, _ sermonDay: Int, _ count: Int) -> Int {
        ((floorDiv(weekStart(epochDay, sermonDay), 7) % count) + count) % count
    }
    static func isSermonDay(_ epochDay: Int, _ sermonDay: Int) -> Bool { dayOfWeek(epochDay) == sermonDay }
    static func daysUntil(_ epochDay: Int, _ sermonDay: Int) -> Int { ((sermonDay - dayOfWeek(epochDay)) % 7 + 7) % 7 }
    /// The Through the Bible series began the week of Monday, Nov 16, 2026: Genesis that week, then a book a week.
    static let bibleSeriesStart = 20773
    static func booksReleased(_ epochDay: Int, _ sermonDay: Int, _ total: Int) -> Int {
        min(total, max(1, floorDiv(weekStart(epochDay, sermonDay) - weekStart(bibleSeriesStart, sermonDay), 7) + 1))
    }
    static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static func dayName(_ iso: Int) -> String { dayNames[max(0, min(6, iso - 1))] }

    /// Days since 1970-01-01 in the phone's time zone.
    static func today(_ date: Date = Date()) -> Int {
        let secs = date.timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT(for: date))
        return Int((secs / 86_400).rounded(.down))
    }
}

/// The person's sermon day and reminder, and this week's sermon.
@MainActor
final class SermonWeek: ObservableObject {
    static let shared = SermonWeek()
    static let remindHour = 9

    @Published var day: Int { didSet { UserDefaults.standard.set(day, forKey: "sermonDay"); SermonReminder.schedule() } }
    @Published var remind: Bool { didSet { UserDefaults.standard.set(remind, forKey: "sermonRemind"); SermonReminder.schedule() } }
    /// Sermons heard to the end, by id.
    @Published private(set) var heard: Set<String> { didSet { UserDefaults.standard.set(Array(heard), forKey: "sermonsHeard") } }

    private init() {
        let d = UserDefaults.standard
        let saved = d.integer(forKey: "sermonDay")
        day = (1...7).contains(saved) ? saved : 7
        remind = d.object(forKey: "sermonRemind") as? Bool ?? true
        heard = Set(d.stringArray(forKey: "sermonsHeard") ?? [])
    }

    /// This week's sermon: the preacher's weekly rotation, the same one everyone with this sermon day hears.
    func current(_ epochDay: Int = SermonWeekLogic.today()) -> Sermon? {
        let list = SermonLibrary.narratedWeekly
        guard !list.isEmpty else { return nil }
        return list[SermonWeekLogic.index(epochDay, day, list.count)]
    }

    var daysUntilNext: Int { SermonWeekLogic.daysUntil(SermonWeekLogic.today(), day) }

    /// Through the Bible: books released so far (one more each week on the sermon day).
    var booksReleased: Int { SermonWeekLogic.booksReleased(SermonWeekLogic.today(), day, max(1, SermonLibrary.books.count)) }

    func markHeard(_ id: String) { if !heard.contains(id) { heard.insert(id) } }
    func eraseHeard() { heard = [] }
}
