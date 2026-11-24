import Foundation

/// Cross-references from OpenBible.info (CC BY), bundled as Resources/xref.txt.gz.
/// Each line: "bookIdx.ch.v<TAB>target;target;…", a target being "b.c.v" or a range "b.c.v-c.v" / "b.c.v-b.c.v".
enum CrossRefs {
    static let attribution = "Cross-references: OpenBible.info, CC BY"

    struct Ref: Identifiable, Hashable {
        let book: String
        let ch: Int
        let v: Int
        let endBook: String?
        let endCh: Int?
        let endV: Int?
        var id: String { "\(book)|\(ch)|\(v)|\(endCh ?? 0)|\(endV ?? 0)" }
        var isRange: Bool { endV != nil }

        func label(_ name: (String) -> String = Bible.englishDisplay) -> String {
            let start = "\(name(book)) \(ch):\(v)"
            guard let endCh, let endV else { return start }
            if let endBook, endBook != book { return "\(start) – \(name(endBook)) \(endCh):\(endV)" }
            return endCh == ch ? "\(start)–\(endV)" : "\(start)–\(endCh):\(endV)"
        }
    }

    private static var table: [String: String]?
    private static let lock = NSLock()

    private static func load() -> [String: String] {
        lock.lock(); defer { lock.unlock() }
        if let table { return table }
        var m: [String: String] = [:]
        if let data = Bundle.main.resourceData("xref.txt.gz"), let text = String(data: data, encoding: .utf8) {
            m.reserveCapacity(30_000)
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                guard let tab = line.firstIndex(of: "\t") else { continue }
                m[String(line[..<tab])] = String(line[line.index(after: tab)...])
            }
        }
        table = m
        return m
    }

    static func parseTarget(_ s: Substring) -> Ref? {
        let halves = s.split(separator: "-", maxSplits: 1)
        let a = halves[0].split(separator: ".").compactMap { Int($0) }
        guard a.count == 3, a[0] >= 0, a[0] < Bible.canon.count else { return nil }
        let book = Bible.canonNames[a[0]]
        var endBook: String?, endCh: Int?, endV: Int?
        if halves.count == 2 {
            let b = halves[1].split(separator: ".").compactMap { Int($0) }
            if b.count == 3, b[0] >= 0, b[0] < Bible.canon.count { endBook = Bible.canonNames[b[0]]; endCh = b[1]; endV = b[2] }
            else if b.count == 2 { endBook = book; endCh = b[0]; endV = b[1] }
        }
        return Ref(book: book, ch: a[1], v: a[2], endBook: endBook, endCh: endCh, endV: endV)
    }

    /// The verse's cross-references, most-voted first.
    static func forVerse(book: String, ch: Int, v: Int) -> [Ref] {
        let idx = Bible.canonIndex(book)
        guard idx >= 0, let raw = load()["\(idx).\(ch).\(v)"] else { return [] }
        return raw.split(separator: ";").compactMap(parseTarget)
    }
}

/// Offline Bible places from OpenBible.info geocoding data (CC BY 4.0), bundled as Resources/places.json.gz.
enum BiblePlaces {
    static let attribution = "Places: OpenBible.info, CC BY"

    struct Place: Identifiable, Hashable {
        let name: String
        let lat: Double
        let lon: Double
        var id: String { "\(name)|\(lat)|\(lon)" }
    }

    private static var cache: [String: [Place]]?
    private static let lock = NSLock()

    private static func load() -> [String: [Place]] {
        lock.lock(); defer { lock.unlock() }
        if let cache { return cache }
        var m: [String: [Place]] = [:]
        if let data = Bundle.main.resourceData("places.json.gz"),
           let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let chapters = o["chapters"] as? [String: [[String: Any]]] {
            for (k, arr) in chapters {
                m[k] = arr.compactMap { p in
                    guard let n = p["n"] as? String, let la = (p["la"] as? NSNumber)?.doubleValue, let lo = (p["lo"] as? NSNumber)?.doubleValue else { return nil }
                    return Place(name: n, lat: la, lon: lo)
                }
            }
        }
        cache = m
        return m
    }

    static func forChapter(book: String, ch: Int) -> [Place] {
        let idx = Bible.canonIndex(book)
        guard idx >= 0 else { return [] }
        return load()["\(idx).\(ch)"] ?? []
    }
}

/// A one-year plan through the whole Bible in canonical order: 1,189 chapters over 365 days (3 or 4 a day).
enum BiblePlan {
    static let days = 365
    static let chapters: [(book: String, ch: Int)] = Bible.canon.flatMap { b in (1...b.chapters).map { (b.name, $0) } }
    static var totalChapters: Int { chapters.count }

    /// Day 1…365 (later days wrap) to its chapters.
    static func chapters(day: Int) -> [(book: String, ch: Int)] {
        let d = ((day - 1) % days + days) % days + 1
        let from = (d - 1) * chapters.count / days
        let to = d * chapters.count / days
        return Array(chapters[from..<to])
    }

    /// "Genesis 1-3", "Psalms 119", or "Genesis 50 – Exodus 2" when a day crosses into the next book.
    static func reading(day: Int) -> String {
        let ch = chapters(day: day)
        guard let first = ch.first, let last = ch.last else { return "" }
        if first.book != last.book { return "\(first.book) \(first.ch) – \(last.book) \(last.ch)" }
        if first.ch == last.ch { return "\(first.book) \(first.ch)" }
        return "\(first.book) \(first.ch)-\(last.ch)"
    }
}

/// Text as it should be spoken: brackets for added words dropped, LORD → Lord, dashes inside names become hyphens.
enum Spoken {
    static func verse(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        t = t.replacingOccurrences(of: #"(?<=\p{L})[–‐](?=\p{L})"#, with: "-", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\bLORD\b"#, with: "Lord", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\bGOD\b"#, with: "God", options: .regularExpression)
        t = t.replacingOccurrences(of: "…", with: "...")
        return t
    }
}
