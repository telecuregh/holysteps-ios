import Foundation
import CryptoKit

/// The in-app Bible, ported from Android's Bible.kt: public-domain and openly licensed translations in English and
/// 27 other languages, each downloaded once from holysteps.org/bible and then read offline. Every file uses the
/// English book names as its keys (so plans, highlights and links work in any language) and carries each book's name
/// in its own language for display.
enum Bible {
    static let baseURL = URL(string: "https://holysteps.org/bible")!

    struct Translation: Identifiable, Hashable {
        let id: String
        let name: String
        var file: String = ""
        var bytes: Int = 0
        var sha256: String = ""
        /// ISO 639-1 code ("en", "es", …) and the language's name in itself ("Español").
        var lang: String = "en"
        var language: String = "English"
        /// Required credit for openly licensed (not public-domain) texts; blank when none is needed.
        var attribution: String = ""
        var catholic: Bool = false
    }

    private static let irv = "Indian Revised Version, CC BY-SA 4.0 (Bridge Connectivity Solutions)"

    /// Shown before the index loads; the server's index adds file names and hashes.
    static let known: [Translation] = [
        Translation(id: "KJV", name: "King James Version"),
        Translation(id: "ASV", name: "American Standard Version"),
        Translation(id: "BBE", name: "Bible in Basic English"),
        Translation(id: "YLT", name: "Young's Literal Translation"),
        Translation(id: "DRC", name: "Douay-Rheims (Catholic)", catholic: true),
        Translation(id: "WBT", name: "Webster's Bible"),
        Translation(id: "RVES", name: "Reina-Valera 1909", lang: "es", language: "Español"),
        Translation(id: "JNDFR", name: "Bible J.N. Darby (1885)", lang: "fr", language: "Français"),
        Translation(id: "CRAMP", name: "Bible Crampon 1923 (Catholique)", lang: "fr", language: "Français", catholic: true),
        Translation(id: "BLIVRE", name: "Bíblia Livre", lang: "pt", language: "Português", attribution: "Bíblia Livre, CC BY 3.0 (bibliaportugues.com)"),
        Translation(id: "ELBDE", name: "Elberfelder Bibel 1905", lang: "de", language: "Deutsch"),
        Translation(id: "LUTDE", name: "Luther-Bibel 1545 (heutige Schreibung)", lang: "de", language: "Deutsch"),
        Translation(id: "CUVZH", name: "和合本 (1919)", lang: "zh", language: "中文"),
        Translation(id: "KORRV", name: "개역한글", lang: "ko", language: "한국어"),
        Translation(id: "KOUGO", name: "口語訳 (1955)", lang: "ja", language: "日本語"),
        Translation(id: "SYNRU", name: "Синодальный перевод", lang: "ru", language: "Русский"),
        Translation(id: "ABTL", name: "Ang Biblia (1905)", lang: "tl", language: "Tagalog"),
        Translation(id: "VIET", name: "Kinh Thánh (1934)", lang: "vi", language: "Tiếng Việt"),
        Translation(id: "SVNL", name: "Statenvertaling", lang: "nl", language: "Nederlands"),
        Translation(id: "GDAPL", name: "Biblia Gdańska (1881)", lang: "pl", language: "Polski"),
        Translation(id: "KARHU", name: "Károli Biblia (1908)", lang: "hu", language: "Magyar"),
        Translation(id: "BKRCS", name: "Bible kralická", lang: "cs", language: "Čeština"),
        Translation(id: "SVSE", name: "Bibeln 1917", lang: "sv", language: "Svenska"),
        Translation(id: "VAMEL", name: "Βάμβας (1850)", lang: "el", language: "Ελληνικά"),
        Translation(id: "CORRO", name: "Cornilescu (1924)", lang: "ro", language: "Română"),
        Translation(id: "IRVHI", name: "इंडियन रिवाइज्ड वर्जन", lang: "hi", language: "हिन्दी", attribution: irv),
        Translation(id: "IRVBN", name: "ইন্ডিয়ান রিভাইজড ভার্সন", lang: "bn", language: "বাংলা", attribution: irv),
        Translation(id: "IRVTA", name: "இந்தியன் ரிவைஸ்டு வெர்ஷன்", lang: "ta", language: "தமிழ்", attribution: irv),
        Translation(id: "IRVTE", name: "ఇండియన్ రివైజ్డ్ వెర్షన్", lang: "te", language: "తెలుగు", attribution: irv),
        Translation(id: "IRVMR", name: "इंडियन रिवाइज्ड वर्जन", lang: "mr", language: "मराठी", attribution: irv),
        Translation(id: "IRVGU", name: "ઇન્ડિયન રિવાઇઝ્ડ વર્ઝન", lang: "gu", language: "ગુજરાતી", attribution: irv),
        Translation(id: "IRVKN", name: "ಇಂಡಿಯನ್ ರಿವೈಸ್ಡ್ ವರ್ಷನ್", lang: "kn", language: "ಕನ್ನಡ", attribution: irv),
        Translation(id: "IRVML", name: "ഇന്ത്യൻ റിവൈസ്ഡ് വേർഷൻ", lang: "ml", language: "മലയാളം", attribution: irv),
        Translation(id: "IRVPA", name: "ਇੰਡੀਅਨ ਰੀਵਾਈਜ਼ਡ ਵਰਜ਼ਨ", lang: "pa", language: "ਪੰਜਾਬੀ", attribution: irv),
        Translation(id: "TWIAK", name: "Twi Kronkron Asɛm (Akuapem)", lang: "ak", language: "Twi (Akuapem)", attribution: "Biblica® Open Akuapem Twi Contemporary Bible, CC BY-SA 4.0 (Biblica, Inc.)"),
        Translation(id: "EWEGH", name: "Ŋɔŋlɔ Kɔkɔe (Ewe)", lang: "ee", language: "Eʋegbe", attribution: "Biblica® Open Ewe Contemporary Scriptures, CC BY-SA 4.0 (Biblica, Inc.)"),
        Translation(id: "VNPUK", name: "Біблія Відкрита (НЗ і Псалми)", lang: "uk", language: "Українська", attribution: "Biblica® Open New Ukrainian Translation, CC BY-SA 4.0 (Biblica, Inc.)"),
    ]

    /// The 66 books in Protestant canon order. Cross-references and places use these indexes.
    static let canon: [(name: String, chapters: Int)] = [
        ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34),
        ("Joshua", 24), ("Judges", 21), ("Ruth", 4), ("1 Samuel", 31), ("2 Samuel", 24),
        ("1 Kings", 22), ("2 Kings", 25), ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10),
        ("Nehemiah", 13), ("Esther", 10), ("Job", 42), ("Psalms", 150), ("Proverbs", 31),
        ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66), ("Jeremiah", 52), ("Lamentations", 5),
        ("Ezekiel", 48), ("Daniel", 12), ("Hosea", 14), ("Joel", 3), ("Amos", 9),
        ("Obadiah", 1), ("Jonah", 4), ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3),
        ("Zephaniah", 3), ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4),
        ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21), ("Acts", 28),
        ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13), ("Galatians", 6), ("Ephesians", 6),
        ("Philippians", 4), ("Colossians", 4), ("1 Thessalonians", 5), ("2 Thessalonians", 3), ("1 Timothy", 6),
        ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1), ("Hebrews", 13), ("James", 5),
        ("1 Peter", 5), ("2 Peter", 3), ("1 John", 5), ("2 John", 1), ("3 John", 1),
        ("Jude", 1), ("Revelation", 22),
    ]
    static let canonNames: [String] = canon.map { $0.name }
    static func canonIndex(_ book: String) -> Int { canonNames.firstIndex(of: book) ?? -1 }

    /// The translation to open first: the phone's language when HolySteps has a Bible in it, otherwise English.
    static func defaultId(phoneLang: String, catholic: Bool = false, list: [Translation] = known) -> String {
        var lang = phoneLang.lowercased()
        if lang == "fil" { lang = "tl" } else if lang == "tw" { lang = "ak" }
        let inLang = list.filter { $0.lang == lang }
        let pick = (catholic ? inLang.first { $0.catholic } : nil) ?? inLang.first { !$0.catholic } ?? inLang.first
        return pick?.id ?? (catholic ? "DRC" : "KJV")
    }

    /// Languages with at least one translation, in list order (English first).
    struct Language: Identifiable, Hashable { let code: String; let name: String; var id: String { code } }

    static func languages(_ list: [Translation]) -> [Language] {
        var seen = Set<String>()
        return list.compactMap { t in seen.insert(t.lang).inserted ? Language(code: t.lang, name: t.language) : nil }
    }

    /// "Psalms" reads "Psalm" for a single reference.
    static func englishDisplay(_ book: String) -> String { book == "Psalms" ? "Psalm" : book }

    /// Translations that number the Psalms like the Greek Septuagint.
    static func psalmNote(_ id: String, book: String) -> String? {
        guard book == "Psalms" else { return nil }
        if id == "DRC" { return "The Douay-Rheims numbers most Psalms one lower (Psalm 23 here is Psalm 22)." }
        if id == "SYNRU" { return "В Синодальном переводе большинство псалмов имеют номер на один меньше (Псалом 23 здесь — Псалом 22)." }
        return nil
    }

    // MARK: - A loaded translation

    final class Text {
        let id: String
        let name: String
        let books: [(name: String, chapters: [[String]])]
        private let local: [String: String]
        private let index: [String: Int]
        private var folded: [[[String]]]?
        private let foldLock = NSLock()

        init(id: String, name: String, books: [(name: String, chapters: [[String]])], local: [String: String]) {
            self.id = id; self.name = name; self.books = books; self.local = local
            var idx: [String: Int] = [:]
            for (i, b) in books.enumerated() { idx[b.name] = i }
            self.index = idx
        }

        func has(_ book: String) -> Bool { index[book] != nil }
        func bookIndex(_ book: String) -> Int? { index[book] }
        func chapter(_ book: String, _ ch: Int) -> [String] {
            guard let i = index[book], ch >= 1, ch <= books[i].chapters.count else { return [] }
            return books[i].chapters[ch - 1]
        }
        func chapters(_ book: String) -> Int { index[book].map { books[$0].chapters.count } ?? 0 }

        /// The book's name in this translation's language ("Psalm" for a single English Psalm reference).
        func display(_ book: String, single: Bool = true) -> String {
            if let l = local[book], !l.isEmpty, l != book { return l }
            return single && book == "Psalms" ? "Psalm" : book
        }

        /// Every verse folded for search, built once per translation.
        fileprivate func foldedVerses() -> [[[String]]] {
            foldLock.lock(); defer { foldLock.unlock() }
            if let f = folded { return f }
            let f = books.map { $0.chapters.map { $0.map(Bible.foldWords) } }
            folded = f
            return f
        }
    }

    static func parse(_ data: Data) throws -> Text {
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = o["id"] as? String, let books = o["books"] as? [[String: Any]] else {
            throw BibleError.message("The download was damaged. Please try again.")
        }
        var local: [String: String] = [:]
        var out: [(name: String, chapters: [[String]])] = []
        out.reserveCapacity(books.count)
        for b in books {
            guard let n = b["n"] as? String, let c = b["c"] as? [[String]] else { continue }
            if let d = b["d"] as? String, !d.isEmpty { local[n] = d }
            out.append((n, c))
        }
        return Text(id: id, name: o["name"] as? String ?? id, books: out, local: local)
    }

    // MARK: - Search (a reference jumps there; words find every verse with them)

    struct Ref: Equatable { let book: String; let ch: Int; let v: Int? }
    struct Hit: Identifiable { let book: String; let ch: Int; let v: Int; let text: String; var id: String { "\(book)|\(ch)|\(v)" } }

    private static func isMark(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    }
    private static func isWord(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber: return true
        default: return false
        }
    }

    /// Lowercase, accents and punctuation removed: "Génesis" == "genesis", "1 Cor." == "1cor".
    static func fold(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.decomposedStringWithCanonicalMapping.lowercased().unicodeScalars where !isMark(u) && isWord(u) {
            out.append(u)
        }
        return String(out)
    }

    /// Like fold but keeps word breaks: " for god so loved the world ".
    static func foldWords(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        out.append(" ")
        var space = true
        for u in s.decomposedStringWithCanonicalMapping.lowercased().unicodeScalars where !isMark(u) {
            if isWord(u) { out.append(u); space = false }
            else if !space { out.append(" "); space = true }
        }
        if !space { out.append(" ") }
        return String(out)
    }

    private static let abbrev: [String: String] = [
        "gn": "Genesis", "dt": "Deuteronomy", "jdg": "Judges", "jgs": "Judges", "ps": "Psalms", "psa": "Psalms",
        "pss": "Psalms", "prv": "Proverbs", "eccl": "Ecclesiastes", "qoh": "Ecclesiastes", "sg": "Song of Solomon",
        "sos": "Song of Solomon", "mt": "Matthew", "mk": "Mark", "mrk": "Mark", "lk": "Luke", "jn": "John",
        "jhn": "John", "rm": "Romans", "rom": "Romans", "1jn": "1 John", "2jn": "2 John", "3jn": "3 John",
        "phm": "Philemon", "jas": "James", "jm": "James", "rv": "Revelation", "rev": "Revelation",
    ]
    private static let refRegex = try! NSRegularExpression(
        pattern: #"^\s*([1-3]?\s*[\p{L}][\p{L} .]*?)\.?\s*(\d{1,3})(?:\s*[:.,\s]\s*(\d{1,3}))?\s*$"#)

    /// "John 3:16", "jn 3 16", "1 cor 13", "Ps 23", "Salmos 23:1" → that place, if it exists in `t`.
    static func parseRef(_ query: String, in t: Text) -> Ref? {
        let ns = query as NSString
        guard let m = refRegex.firstMatch(in: query, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let name = fold(ns.substring(with: m.range(at: 1)))
        guard name.count >= 2 else { return nil }
        let books = t.books.map { $0.name }
        let names = books.map { b in (b, [fold(b), fold(t.display(b, single: false)), fold(t.display(b))]) }
        let book = names.first(where: { $0.1.contains(name) })?.0
            ?? abbrev[name].flatMap { books.contains($0) ? $0 : nil }
            ?? names.first(where: { $0.1.contains(where: { $0.hasPrefix(name) }) })?.0
        guard let book, let ch = Int(ns.substring(with: m.range(at: 2))), ch >= 1, ch <= t.chapters(book) else { return nil }
        var v: Int?
        if m.range(at: 3).location != NSNotFound, let n = Int(ns.substring(with: m.range(at: 3))), n >= 1, n <= t.chapter(book, ch).count { v = n }
        return Ref(book: book, ch: ch, v: v)
    }

    /// Every verse containing all the words of `query` (any order, accents ignored), in Bible order. A word matches
    /// the start of a word, so "love" finds "loved" and "loving" but "art" doesn't match "heart".
    static func search(_ t: Text, _ query: String, limit: Int = 200) -> [Hit] {
        var seen = Set<String>()
        let words = foldWords(query).split(separator: " ").map(String.init).filter { $0.count >= 2 && seen.insert($0).inserted }.map { " " + $0 }
        if words.isEmpty { return [] }
        let folded = t.foldedVerses()
        var out: [Hit] = []
        for (bi, book) in t.books.enumerated() {
            for (ci, verses) in book.chapters.enumerated() {
                for (vi, verse) in verses.enumerated() where words.allSatisfy({ folded[bi][ci][vi].contains($0) }) {
                    out.append(Hit(book: book.name, ch: ci + 1, v: vi + 1, text: verse))
                    if out.count >= limit { return out }
                }
            }
        }
        return out
    }
}

enum BibleError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return tr(m) }; return nil }
}

// MARK: - Highlights and notes

enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case GOLD, ROSE, SKY, MINT
    var id: String { rawValue }
    var hex: UInt32 {
        switch self { case .GOLD: return 0xFBBF24; case .ROSE: return 0xF472B6; case .SKY: return 0x60A5FA; case .MINT: return 0x34D399 }
    }
    var label: String {
        switch self { case .GOLD: return "Gold"; case .ROSE: return "Rose"; case .SKY: return "Sky"; case .MINT: return "Mint" }
    }
}

/// A saved verse: highlighted in a color, or (when noteOnly) just carrying a note. Same JSON keys as Android.
struct Highlight: Codable, Identifiable, Equatable {
    var book: String
    var ch: Int
    var v: Int
    var color: HighlightColor
    var text: String
    var translation: String
    var atMs: Int64
    var note: String = ""
    var noteOnly: Bool = false

    var id: String { key }
    var key: String { "\(book)|\(ch)|\(v)" }
    var ref: String { "\(Bible.englishDisplay(book)) \(ch):\(v)" }
    var isHighlighted: Bool { !noteOnly }

    enum CodingKeys: String, CodingKey { case book = "b", ch = "c", v, color = "k", text = "t", translation = "tr", atMs = "at", note = "n", noteOnly = "o" }

    init(book: String, ch: Int, v: Int, color: HighlightColor, text: String, translation: String, atMs: Int64, note: String = "", noteOnly: Bool = false) {
        self.book = book; self.ch = ch; self.v = v; self.color = color; self.text = text
        self.translation = translation; self.atMs = atMs; self.note = note; self.noteOnly = noteOnly
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        book = try c.decode(String.self, forKey: .book)
        ch = try c.decode(Int.self, forKey: .ch)
        v = try c.decode(Int.self, forKey: .v)
        color = (try? c.decode(HighlightColor.self, forKey: .color)) ?? .GOLD
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        translation = (try? c.decode(String.self, forKey: .translation)) ?? "KJV"
        atMs = (try? c.decode(Int64.self, forKey: .atMs)) ?? 0
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
        noteOnly = ((try? c.decode(Int.self, forKey: .noteOnly)) ?? 0) == 1
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(book, forKey: .book); try c.encode(ch, forKey: .ch); try c.encode(v, forKey: .v)
        try c.encode(color, forKey: .color); try c.encode(String(text.prefix(600)), forKey: .text)
        try c.encode(translation, forKey: .translation); try c.encode(atMs, forKey: .atMs)
        try c.encode(String(note.prefix(Highlights.maxNote)), forKey: .note)
        if noteOnly { try c.encode(1, forKey: .noteOnly) }
    }
}

enum Highlights {
    static let max = 1000
    static let maxNote = 2000

    /// A verse has one entry; the newest wins (the list is oldest-first).
    static func keepNewestPerVerse(_ list: [Highlight]) -> [Highlight] {
        var seen = Set<String>()
        return list.reversed().filter { seen.insert($0.key).inserted }.reversed()
    }

    /// Adds or recolors a highlight; the same color again removes it. A verse with a note keeps the note.
    static func toggle(_ list: [Highlight], _ h: Highlight) -> [Highlight] {
        let old = list.first { $0.key == h.key }
        var rest = list.filter { $0.key != h.key }
        guard let old else { var n = h; n.noteOnly = false; return Array((rest + [n]).suffix(max)) }
        if old.isHighlighted && old.color == h.color {
            if !old.note.isEmpty { var n = old; n.noteOnly = true; rest.append(n) }
            return rest
        }
        var n = h; n.note = old.note; n.noteOnly = false
        return rest + [n]
    }

    /// Sets the note on a verse. A verse with no highlight gets a note-only entry; clearing the note of a note-only
    /// verse removes it; a highlighted verse keeps its color either way.
    static func withNote(_ list: [Highlight], book: String, ch: Int, v: Int, verseText: String, translation: String, note: String, nowMs: Int64) -> [Highlight] {
        let clean = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNote))
        let key = "\(book)|\(ch)|\(v)"
        let old = list.first { $0.key == key }
        let rest = list.filter { $0.key != key }
        switch (old, clean.isEmpty) {
        case (nil, true): return list
        case (nil, false):
            return Array((rest + [Highlight(book: book, ch: ch, v: v, color: .GOLD, text: verseText, translation: translation, atMs: nowMs, note: clean, noteOnly: true)]).suffix(max))
        case (let o?, true) where o.noteOnly: return rest
        default: return list.map { var x = $0; if x.key == key { x.note = clean }; return x }
        }
    }
}

// MARK: - Downloading and caching

actor BibleRepository {
    static let shared = BibleRepository()

    private var index: [Bible.Translation]?
    private var commentaryIndex: [String: (file: String, sha: String)]?
    private var cache: [String: Bible.Text] = [:]
    private var cacheOrder: [String] = []

    private var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("bible", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw BibleError.message("HTTP error") }
        return data
    }

    private static let fileRegex = try! NSRegularExpression(pattern: #"^[a-z]{2,8}\.[0-9a-f]{12}\.json\.gz$"#)
    private static func validFile(_ f: String) -> Bool {
        fileRegex.firstMatch(in: f, range: NSRange(location: 0, length: (f as NSString).length)) != nil
    }

    /// The server's list of translations (cached to disk for offline use), or the built-in list.
    func translations() async -> [Bible.Translation] {
        if let index { return index }
        let saved = dir.appendingPathComponent("index.json")
        var data = try? await get(Bible.baseURL.appendingPathComponent("index.json"))
        if let d = data { try? d.write(to: saved, options: .atomic) } else { data = try? Data(contentsOf: saved) }
        guard let data, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = o["translations"] as? [[String: Any]] else { return Bible.known }
        let list: [Bible.Translation] = arr.compactMap { t in
            guard let id = t["id"] as? String, let file = t["file"] as? String, BibleRepository.validFile(file) else { return nil }
            let k = Bible.known.first { $0.id == id }
            func str(_ key: String, _ fallback: String) -> String { ((t[key] as? String).flatMap { $0.isEmpty ? nil : $0 }) ?? fallback }
            return Bible.Translation(id: id, name: str("name", k?.name ?? id), file: file, bytes: t["bytes"] as? Int ?? 0,
                                     sha256: t["sha256"] as? String ?? "", lang: str("lang", k?.lang ?? "en"),
                                     language: str("language", k?.language ?? "English"),
                                     attribution: (t["attribution"] as? String) ?? k?.attribution ?? "",
                                     catholic: k?.catholic ?? (t["catholic"] as? Bool ?? false))
        }
        if let c = o["commentary"] as? [String: Any], let books = c["books"] as? [[String: Any]] {
            var m: [String: (String, String)] = [:]
            for b in books {
                if let name = b["b"] as? String, let file = b["file"] as? String, BibleRepository.validFile(file) {
                    m[name] = (file, b["sha256"] as? String ?? "")
                }
            }
            commentaryIndex = m
        }
        if list.isEmpty { return Bible.known }
        index = list
        return list
    }

    func isDownloaded(_ t: Bible.Translation) -> Bool {
        !t.file.isEmpty && FileManager.default.fileExists(atPath: dir.appendingPathComponent(t.file).path)
    }

    func downloadedIds() async -> Set<String> {
        Set(await translations().filter { isDownloaded($0) }.map { $0.id })
    }

    private static func sha256Hex(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

    /// Loads a translation, downloading it first if needed (about 1.2 MB).
    func load(_ id: String) async throws -> Bible.Text {
        if let t = cache[id] { return t }
        guard let t = await translations().first(where: { $0.id == id }) else { throw BibleError.message("That translation isn't available.") }
        if t.file.isEmpty { throw BibleError.message("Connect to the internet once to download the \(t.name).") }
        let f = dir.appendingPathComponent(t.file)
        if !FileManager.default.fileExists(atPath: f.path) {
            let bytes: Data
            do { bytes = try await get(Bible.baseURL.appendingPathComponent(t.file)) }
            catch { throw BibleError.message("Couldn't download the \(t.name). Check your connection and try again.") }
            if !t.sha256.isEmpty && BibleRepository.sha256Hex(bytes) != t.sha256 { throw BibleError.message("The download was damaged. Please try again.") }
            // Older copies of this translation are replaced.
            let prefix = id.lowercased() + "."
            for old in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where old.hasPrefix(prefix) && old != t.file {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(old))
            }
            try bytes.write(to: f, options: .atomic)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var fu = f; try? fu.setResourceValues(values)
        }
        let text: Bible.Text
        do { text = try Bible.parse(try Data(contentsOf: f).gunzipped()) }
        catch { try? FileManager.default.removeItem(at: f); throw BibleError.message("The download was damaged. Please try again.") }
        cache[id] = text
        cacheOrder.removeAll { $0 == id }
        cacheOrder.append(id)
        while cacheOrder.count > 3 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
        return text
    }

    // MARK: Commentary (Matthew Henry), one file per book

    func isCommentaryDownloaded(_ book: String) async -> Bool {
        _ = await translations()
        guard let e = commentaryIndex?[book] else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(e.file).path)
    }

    func commentary(book: String, ch: Int) async throws -> Commentary.Chapter? {
        _ = await translations()
        guard let e = commentaryIndex?[book] else { throw BibleError.message("Connect to the internet once to download the commentary.") }
        let f = dir.appendingPathComponent(e.file)
        if !FileManager.default.fileExists(atPath: f.path) {
            let bytes: Data
            do { bytes = try await get(Bible.baseURL.appendingPathComponent(e.file)) }
            catch { throw BibleError.message("Couldn't download the commentary. Check your connection and try again.") }
            if !e.sha.isEmpty && BibleRepository.sha256Hex(bytes) != e.sha { throw BibleError.message("The download was damaged. Please try again.") }
            try bytes.write(to: f, options: .atomic)
        }
        guard let o = try JSONSerialization.jsonObject(with: try Data(contentsOf: f).gunzipped()) as? [String: Any],
              let chapters = o["c"] as? [[String: Any]], ch >= 1, ch <= chapters.count else { return nil }
        let c = chapters[ch - 1]
        let sections: [Commentary.Section] = (c["s"] as? [[Any]] ?? []).compactMap { s in
            guard s.count >= 3, let from = s[0] as? Int, let to = s[1] as? Int, let text = s[2] as? String else { return nil }
            return Commentary.Section(fromVerse: from, toVerse: to, text: text)
        }
        let intro = c["i"] as? String ?? ""
        if intro.isEmpty && sections.isEmpty { return nil }
        return Commentary.Chapter(intro: intro, sections: sections)
    }
}

enum Commentary {
    static let name = "Matthew Henry"
    static let attribution = "Matthew Henry's Commentary on the Whole Bible (1706), public domain"
    struct Section: Identifiable { let fromVerse: Int; let toVerse: Int; let text: String; var id: Int { fromVerse * 1000 + toVerse } }
    struct Chapter {
        let intro: String
        let sections: [Section]
        func forVerse(_ v: Int) -> [Section] { sections.filter { v >= $0.fromVerse && v <= $0.toVerse } }
    }
}
