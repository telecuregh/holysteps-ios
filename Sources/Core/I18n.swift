import Foundation
import SwiftUI

/// The app's languages, ported from the Android app's I18n.kt. English text stays in the code; the Spanish table
/// (Resources/es.json.gz, the same file Android ships) maps each English line to its translation. Text built from
/// parts ("Hi {0}, {1} steps today") is stored as a template and matched at run time, and each part is translated too.
/// Strings that exist only in the iOS app are in Resources/ios_es.json.
final class I18n: ObservableObject {
    enum Choice: String, CaseIterable, Identifiable {
        case system, en, es
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "Automatic"
            case .en: return "English"
            case .es: return "Español"
            }
        }
    }

    static let shared = I18n()
    private static let key = "hs_lang"

    /// "en" or "es": the language the app shows.
    @Published private(set) var language: String = "en"
    var spanish: Bool { language == "es" }

    private var table: Table?
    private let lock = NSLock()
    private var cache: [String: String] = [:]

    private init() {
        language = I18n.resolve(choice, phoneLang: Locale.preferredLanguages.first ?? "en")
    }

    var choice: Choice {
        Choice(rawValue: UserDefaults.standard.string(forKey: I18n.key) ?? "") ?? .system
    }

    func setChoice(_ c: Choice) {
        UserDefaults.standard.set(c.rawValue, forKey: I18n.key)
        lock.lock(); cache.removeAll(); lock.unlock()
        language = I18n.resolve(c, phoneLang: Locale.preferredLanguages.first ?? "en")
    }

    static func resolve(_ c: Choice, phoneLang: String) -> String {
        switch c {
        case .en: return "en"
        case .es: return "es"
        case .system: return phoneLang.lowercased().hasPrefix("es") ? "es" : "en"
        }
    }

    /// The phone's language code to choose a Bible by: Spanish when the app is in Spanish.
    var bibleLang: String {
        spanish ? "es" : (Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en")
    }

    /// The locale for dates and numbers: US English or US Spanish.
    var locale: Locale { Locale(identifier: spanish ? "es_US" : "en_US") }

    /// The voice to read prompts in.
    var speechLanguage: String { spanish ? "es-US" : "en-US" }

    private func ensureTable() -> Table {
        lock.lock(); defer { lock.unlock() }
        if let t = table { return t }
        var exactJSON: [String: String] = [:]
        if let data = Bundle.main.resourceData("es.json.gz"),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] { exactJSON = obj }
        if let data = Bundle.main.resourceData("ios_es.json"),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for (k, v) in obj { exactJSON[k] = v }
        }
        let t = Table.parse(exactJSON)
        table = t
        return t
    }

    /// Loads the Spanish table off the main thread so the first Spanish screen doesn't wait for it.
    func warmUp() {
        guard spanish else { return }
        DispatchQueue.global(qos: .userInitiated).async { _ = self.ensureTable() }
    }

    /// The text in the app's language. English, unknown text (names, numbers) and blanks come back unchanged.
    func tr(_ s: String) -> String {
        if language == "en" || s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
        lock.lock()
        if let hit = cache[s] { lock.unlock(); return hit }
        lock.unlock()
        let t = ensureTable()
        let out = t.translate(s, depth: 0)
        lock.lock()
        if cache.count < 20_000 { cache[s] = out }
        lock.unlock()
        return out
    }

    // MARK: - Table

    final class Table {
        struct Tpl {
            let en: String
            let es: String
            let regex: NSRegularExpression
            let literal: Int
        }

        private let exact: [String: String]
        private let templates: [Tpl]
        private let byPrefix: [String: [Tpl]]
        private lazy var upper: [String: String] = {
            var m: [String: String] = [:]
            m.reserveCapacity(exact.count)
            for (en, es) in exact where m[en.uppercased()] == nil { m[en.uppercased()] = es.uppercased() }
            return m
        }()

        static let ph = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
        private static let boundaries = [" · ", " — ", " – ", " • ", ". "]
        private static let separators = ["\n", " · ", " — ", " – ", " • ", " | ", ": ", ". ", ", "]
        private static let reference = try! NSRegularExpression(
            pattern: #"^((?:[1-3] )?[A-Z][a-z]+(?: of [A-Z][a-z]+| [A-Z][a-z]+)?) (\d+(?::\d+)?(?:[–-]\d+(?::\d+)?)?(?:, ?\d+(?:[–-]\d+)?)*)(.*)$"#,
            options: [.dotMatchesLineSeparators])
        private static let leadingNumber = try! NSRegularExpression(
            pattern: #"^([\d.,:/+%×x-]+\s*)(\D.*)$"#, options: [.dotMatchesLineSeparators])

        private static func key(_ en: String) -> String { en.hasPrefix("{") ? "" : String(en.prefix(2)) }

        init(exact: [String: String], templates: [Tpl]) {
            self.exact = exact
            self.templates = templates
            self.byPrefix = Dictionary(grouping: templates, by: { Table.key($0.en) })
        }

        static func parse(_ obj: [String: String]) -> Table {
            var exact: [String: String] = [:]
            exact.reserveCapacity(obj.count)
            var tpls: [Tpl] = []
            for (en, es) in obj {
                let ns = en as NSString
                let matches = ph.matches(in: en, range: NSRange(location: 0, length: ns.length))
                if matches.isEmpty { exact[en] = es; continue }
                let literal = ph.stringByReplacingMatches(in: en, range: NSRange(location: 0, length: ns.length), withTemplate: "")
                    .filter { $0.isLetter }.count
                if literal < 2 { continue }   // "{0} {1}" would match anything
                var pattern = "^"
                var last = 0
                for m in matches {
                    pattern += NSRegularExpression.escapedPattern(for: ns.substring(with: NSRange(location: last, length: m.range.location - last)))
                    pattern += "(.+?)"
                    last = m.range.location + m.range.length
                }
                pattern += NSRegularExpression.escapedPattern(for: ns.substring(from: last)) + "$"
                if let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                    tpls.append(Tpl(en: en, es: es, regex: re, literal: literal))
                }
            }
            // Most specific first, so "Walked {0} km today" wins over "Walked {0}".
            tpls.sort { $0.literal > $1.literal }
            return Table(exact: exact, templates: tpls)
        }

        private static func fullMatch(_ re: NSRegularExpression, _ s: String) -> [String]? {
            let ns = s as NSString
            guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
                  m.range.location == 0, m.range.length == ns.length else { return nil }
            return (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }

        func translate(_ s: String, depth: Int) -> String {
            if let hit = exact[s] { return hit }
            // Keep surrounding spaces: "  Done  ".
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count != s.count && !trimmed.isEmpty {
                let inner = translate(trimmed, depth: depth)
                if inner != trimmed, let r = s.range(of: trimmed) {
                    return String(s[s.startIndex..<r.lowerBound]) + inner + String(s[r.upperBound...])
                }
                return s
            }
            // A quoted line: translate inside the quotes.
            if s.count > 2, let open = s.first, let close = s.last,
               (open == "\"" && close == "\"") || (open == "\u{201C}" && close == "\u{201D}") {
                let inner = String(s.dropFirst().dropLast())
                let done = translate(inner, depth: depth)
                if done != inner { return String(open) + done + String(close) }
            }
            if depth > 3 { return s }
            for list in [byPrefix[Table.key(s)] ?? [], byPrefix[""] ?? []] {
                for t in list {
                    guard let groups = Table.fullMatch(t.regex, s) else { continue }
                    let parts = Array(groups.dropFirst())
                    // A short pattern like "{0} and {1}" must not swallow whole sentences or "A · B" parts.
                    if parts.contains(where: { g in Table.boundaries.contains(where: { g.contains($0) }) }) { continue }
                    let done = parts.map { translate($0, depth: depth + 1) }
                    let es = t.es as NSString
                    var out = ""
                    var last = 0
                    for m in Table.ph.matches(in: t.es, range: NSRange(location: 0, length: es.length)) {
                        out += es.substring(with: NSRange(location: last, length: m.range.location - last))
                        let idx = Int(es.substring(with: m.range(at: 1))) ?? -1
                        out += (idx >= 0 && idx < done.count) ? done[idx] : es.substring(with: m.range)
                        last = m.range.location + m.range.length
                    }
                    out += es.substring(from: last)
                    return out
                }
            }
            // Text joined from known pieces: lines, "A · B", "A — B", "A: B", "A, B" and "3 steps".
            if depth < 3 {
                for sep in Table.separators where s.contains(sep) {
                    let parts = s.components(separatedBy: sep)
                    let done = parts.map { $0.trimmingCharacters(in: .whitespaces).isEmpty ? $0 : translate($0, depth: depth + 1) }
                    if done != parts { return done.joined(separator: sep) }
                }
                // Scripture references: "1 Corinthians 10:13" → "1 Corintios 10:13".
                if let g = Table.fullMatch(Table.reference, s), let book = exact[g[1]] {
                    return book + " " + g[2] + translate(g[3], depth: depth + 1)
                }
                if let g = Table.fullMatch(Table.leadingNumber, s) {
                    let rest = translate(g[2], depth: depth + 1)
                    if rest != g[2] { return g[1] + rest }
                }
            }
            // SHOUTED labels ("TODAY").
            if s.count > 1 && s == s.uppercased() && s != s.lowercased(), let hit = upper[s] { return hit }
            return s
        }
    }
}

/// Short form used across the app.
func tr(_ s: String) -> String { I18n.shared.tr(s) }

/// A Text in the app's language.
func T(_ s: String) -> Text { Text(verbatim: tr(s)) }
