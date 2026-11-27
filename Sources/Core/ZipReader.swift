import Foundation
import Compression
import CommonCrypto

/// Reads the files inside a .zip in memory, including password-locked ones (traditional ZipCrypto and WinZip AES-128/192/256,
/// which is what Clue's "Download my data" export and most phones' "compress with password" produce). Only what the period
/// import needs: stored and deflated entries, no zip64, no split archives. Nothing is written to disk.
enum ZipReader {
    enum Failure: Error, Equatable { case notZip, needsPassword, wrongPassword, unsupported, damaged }

    struct Entry { let name: String; let data: Data }

    /// The entries whose names pass [want], each capped at [maxBytes]. Throws `.needsPassword` for a locked zip with no
    /// password and `.wrongPassword` when the password doesn't open it.
    static func entries(_ zip: Data, password: String? = nil, maxBytes: Int = 8 << 20, want: (String) -> Bool = { _ in true }) throws -> [Entry] {
        let b = [UInt8](zip)
        guard b.count >= 22, b[0] == 0x50, b[1] == 0x4B else { throw Failure.notZip }
        // End of central directory: the last "PK\5\6" within the final 64 KB + 22 bytes.
        var eocd = -1
        var i = b.count - 22
        while i >= max(0, b.count - 65_557) { if u32(b, i) == 0x06054b50 { eocd = i; break }; i -= 1 }
        guard eocd >= 0 else { throw Failure.damaged }
        let count = Int(u16(b, eocd + 10)), cdOffset = Int(u32(b, eocd + 16))
        var p = cdOffset
        var out: [Entry] = []
        for _ in 0..<count {
            guard p + 46 <= b.count, u32(b, p) == 0x02014b50 else { throw Failure.damaged }
            let flags = u16(b, p + 8), method = u16(b, p + 10), dosTime = u16(b, p + 12)
            let crc = u32(b, p + 16), csize = Int(u32(b, p + 20)), usize = Int(u32(b, p + 24))
            let nlen = Int(u16(b, p + 28)), xlen = Int(u16(b, p + 30)), clen = Int(u16(b, p + 32))
            let local = Int(u32(b, p + 42))
            guard p + 46 + nlen + xlen <= b.count else { throw Failure.damaged }
            let name = String(decoding: b[(p + 46)..<(p + 46 + nlen)], as: UTF8.self)
            let extra = Array(b[(p + 46 + nlen)..<(p + 46 + nlen + xlen)])
            p += 46 + nlen + xlen + clen
            if name.hasSuffix("/") || !want(name) || usize > maxBytes { continue }
            guard local + 30 <= b.count, u32(b, local) == 0x04034b50 else { throw Failure.damaged }
            let start = local + 30 + Int(u16(b, local + 26)) + Int(u16(b, local + 28))
            guard start + csize <= b.count else { throw Failure.damaged }
            var body = Array(b[start..<(start + csize)])
            var realMethod = method
            if flags & 1 == 1 {
                guard let password, !password.isEmpty else { throw Failure.needsPassword }
                if method == 99 {
                    guard let aes = aesExtra(extra) else { throw Failure.unsupported }
                    realMethod = aes.method
                    body = try aesDecrypt(body, password: password, strength: aes.strength)
                } else {
                    // The check byte is the CRC's high byte, or the time's when sizes follow the data (flag bit 3).
                    let check = flags & 8 != 0 ? UInt8(dosTime >> 8) : UInt8(crc >> 24)
                    body = try zipCryptoDecrypt(body, password: password, check: check)
                }
            }
            let plain: [UInt8]
            switch realMethod {
            case 0: plain = body
            case 8: plain = try inflate(body, size: usize)
            default: throw Failure.unsupported
            }
            // AES-2 entries carry no CRC (the HMAC already checked them); everything else must match.
            if crc != 0, crc32(plain) != crc { throw flags & 1 == 1 ? Failure.wrongPassword : Failure.damaged }
            out.append(Entry(name: name, data: Data(plain)))
        }
        return out
    }

    // MARK: Little-endian reads

    private static func u16(_ b: [UInt8], _ i: Int) -> UInt16 { UInt16(b[i]) | UInt16(b[i + 1]) << 8 }
    private static func u32(_ b: [UInt8], _ i: Int) -> UInt32 { UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24 }

    // MARK: Deflate

    private static func inflate(_ src: [UInt8], size: Int) throws -> [UInt8] {
        if size == 0 { return [] }
        var dst = [UInt8](repeating: 0, count: size)
        let n = src.withUnsafeBufferPointer { s in
            dst.withUnsafeMutableBufferPointer { d in
                compression_decode_buffer(d.baseAddress!, size, s.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard n == size else { throw Failure.damaged }
        return dst
    }

    // MARK: CRC-32

    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }
    static func crc32(_ b: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for x in b { c = crcTable[Int((c ^ UInt32(x)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }

    // MARK: Traditional PKWARE encryption

    private static func zipCryptoDecrypt(_ data: [UInt8], password: String, check: UInt8) throws -> [UInt8] {
        guard data.count >= 12 else { throw Failure.damaged }
        var k0: UInt32 = 305_419_896, k1: UInt32 = 591_751_049, k2: UInt32 = 878_082_192
        func crcByte(_ c: UInt32, _ x: UInt8) -> UInt32 { crcTable[Int((c ^ UInt32(x)) & 0xFF)] ^ (c >> 8) }
        func update(_ x: UInt8) {
            k0 = crcByte(k0, x)
            k1 = (k1 &+ (k0 & 0xFF)) &* 134_775_813 &+ 1
            k2 = crcByte(k2, UInt8(k1 >> 24))
        }
        func streamByte() -> UInt8 { let t = UInt16(truncatingIfNeeded: k2 | 2); return UInt8(truncatingIfNeeded: (UInt32(t) &* UInt32(t ^ 1)) >> 8) }
        for x in Array(password.utf8) { update(x) }
        var out = [UInt8](); out.reserveCapacity(data.count - 12)
        for (i, c) in data.enumerated() {
            let p = c ^ streamByte()
            update(p)
            if i == 11 { if p != check { throw Failure.wrongPassword } } else if i > 11 { out.append(p) }
        }
        return out
    }

    // MARK: WinZip AES

    private static func aesExtra(_ x: [UInt8]) -> (strength: Int, method: UInt16)? {
        var i = 0
        while i + 4 <= x.count {
            let id = UInt16(x[i]) | UInt16(x[i + 1]) << 8, len = Int(UInt16(x[i + 2]) | UInt16(x[i + 3]) << 8)
            if id == 0x9901, len >= 7, i + 4 + len <= x.count {
                return (Int(x[i + 8]), UInt16(x[i + 9]) | UInt16(x[i + 10]) << 8)
            }
            i += 4 + len
        }
        return nil
    }

    private static func aesDecrypt(_ data: [UInt8], password: String, strength: Int) throws -> [UInt8] {
        let keyLen = [1: 16, 2: 24, 3: 32][strength] ?? 0, saltLen = [1: 8, 2: 12, 3: 16][strength] ?? 0
        guard keyLen > 0, data.count >= saltLen + 2 + 10 else { throw Failure.damaged }
        let salt = Array(data[0..<saltLen]), verify = Array(data[saltLen..<(saltLen + 2)])
        let body = Array(data[(saltLen + 2)..<(data.count - 10)]), mac = Array(data[(data.count - 10)...])
        var dk = [UInt8](repeating: 0, count: 2 * keyLen + 2)
        let pw = Array(password.utf8)
        let rc = pw.withUnsafeBufferPointer { p in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), p.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: Int8.self) }, pw.count,
                                 salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1000, &dk, dk.count)
        }
        guard rc == kCCSuccess else { throw Failure.damaged }
        let encKey = Array(dk[0..<keyLen]), macKey = Array(dk[keyLen..<(2 * keyLen)])
        guard Array(dk[(2 * keyLen)...]) == verify else { throw Failure.wrongPassword }
        var hm = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), macKey, macKey.count, body, body.count, &hm)
        guard Array(hm[0..<10]) == mac else { throw Failure.wrongPassword }
        // CTR with a 16-byte little-endian counter starting at 1, as WinZip defines it.
        var out = [UInt8](repeating: 0, count: body.count)
        var counter = [UInt8](repeating: 0, count: 16)
        var block = [UInt8](repeating: 0, count: 16)
        var off = 0, n: UInt64 = 1
        while off < body.count {
            var v = n
            for j in 0..<8 { counter[j] = UInt8(v & 0xFF); v >>= 8 }
            var moved = 0
            let s = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
                            encKey, encKey.count, nil, counter, 16, &block, 16, &moved)
            guard s == kCCSuccess else { throw Failure.damaged }
            for j in 0..<min(16, body.count - off) { out[off + j] = body[off + j] ^ block[j] }
            off += 16; n += 1
        }
        return out
    }
}

/// Period history from another tracker's export (Clue, Flo and others), JSON or CSV. The same rules as Android's
/// DataImport.readPeriods: period starts with an optional end, or single days marked as period days (a one-day gap
/// allowed); predictions and pregnancy records are skipped; starts under 10 days apart are one period.
enum PeriodImport {
    struct Period: Equatable { let start: String; let days: Int }

    static func parseDay(_ raw: Any?) -> Date? {
        if let n = raw as? NSNumber, !(raw is Bool) {
            var v = n.doubleValue
            if v > 1e11 { v /= 1000 }
            return (1e9...4e9).contains(v) ? Calendar.current.startOfDay(for: Date(timeIntervalSince1970: v)) : nil
        }
        guard let s = (raw as? String)?.trimmingCharacters(in: .whitespaces), s.count >= 8 else { return nil }
        let head = String(s.prefix(10))
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current
        for fmt in ["yyyy-MM-dd", "MM/dd/yyyy", "yyyy/MM/dd", "M/d/yyyy"] {
            f.dateFormat = fmt
            if let d = f.date(from: head) ?? f.date(from: s), let y = Calendar.current.dateComponents([.year], from: d).year, (1990...2100).contains(y) {
                return Calendar.current.startOfDay(for: d)
            }
        }
        return nil
    }

    private static func low(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces).lowercased() }
    private static func periodWord(_ s: String) -> Bool { s.contains("period") || s.contains("menstru") || s.contains("bleed") }
    private static let dateKeys: Set<String> = ["date", "day", "datetime", "timestamp", "time", "start_date", "startdate", "log_date", "logged_at", "isodate"]
    private static let typeKeys: Set<String> = ["type", "category", "name", "kind", "event", "symptom", "measurement", "key"]
    private static let markKeys: Set<String> = ["period", "flow", "bleeding", "menstruation", "menstrual_flow", "period_flow", "menstrual_bleeding"]
    private static let notAMark: Set<String> = ["", "none", "no", "false", "0", "null", "spotting", "n/a"]

    private static func marked(_ v: Any?) -> Bool {
        switch v {
        case let b as Bool: return b
        case let n as NSNumber: return n.doubleValue > 0
        case let s as String: return !notAMark.contains(low(s))
        case let a as [Any]: return !a.isEmpty && !"\(a)".lowercased().contains("spotting")
        case let o as [String: Any]: return !o.isEmpty && !"\(o)".lowercased().contains("spotting")
        default: return false
        }
    }

    private static func walk(_ node: Any, path: String, days: inout Set<Date>, ranges: inout [(Date, Date?)]) {
        if let a = node as? [Any] { for x in a { walk(x, path: path, days: &days, ranges: &ranges) }; return }
        guard let o = node as? [String: Any] else { return }
        let keys = Array(o.keys)
        let skip = path.contains("predict") || path.contains("pregnan") || keys.contains { low($0).contains("predict") }
        if !skip {
            if let sk = keys.first(where: { k in let l = low(k); return l.contains("start") && (periodWord(l) || periodWord(path) || l.contains("cycle") || path.contains("cycle")) && parseDay(o[k]) != nil }),
               let start = parseDay(o[sk]) {
                let ek = keys.first { k in let l = low(k); return l.contains("end") && !l.contains("cycle") && (periodWord(l) || periodWord(path)) }
                ranges.append((start, ek.flatMap { parseDay(o[$0]) }))
            } else if let dk = keys.first(where: { dateKeys.contains(low($0)) }), let day = parseDay(o[dk]) {
                let byType = keys.contains { k in
                    guard typeKeys.contains(low(k)), let v = o[k] as? String else { return false }
                    let lv = low(v); return periodWord(lv) && !lv.contains("predict") && !"\(o)".lowercased().contains("spotting")
                }
                let byMark = keys.contains { markKeys.contains(low($0)) && marked(o[$0]) }
                if byType || byMark { days.insert(day) }
            }
        }
        for (k, v) in o where v is [Any] || v is [String: Any] { walk(v, path: path + "/" + low(k), days: &days, ranges: &ranges) }
    }

    private static func csvRows(_ t: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false
        var it = Array(t).makeIterator()
        var pending: Character? = nil
        while let ch = pending ?? it.next() {
            pending = nil
            if quoted {
                if ch == "\"" { if let n = it.next() { if n == "\"" { cell.append("\"") } else { quoted = false; pending = n } } else { quoted = false } }
                else { cell.append(ch) }
            } else if ch == "\"" { quoted = true }
            else if ch == "," { row.append(cell); cell = "" }
            else if ch == "\n" || ch == "\r" { if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }; row = []; cell = "" }
            else { cell.append(ch) }
        }
        if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }
        return rows
    }

    private static func csv(_ rows: [[String]], days: inout Set<Date>, ranges: inout [(Date, Date?)]) {
        guard let first = rows.first else { return }
        if parseDay(first.first) != nil {
            for r in rows { if let d = parseDay(r.first) { ranges.append((d, parseDay(r[safe: 1]))) } }
            return
        }
        let h = first.map(low)
        if let si = h.firstIndex(where: { $0.contains("start") || $0 == "first day" }) {
            let ei = h.firstIndex { ($0.contains("end") || $0 == "last day") && !$0.contains("cycle") }
            for r in rows.dropFirst() { if let s = parseDay(r[safe: si]) { ranges.append((s, ei.flatMap { parseDay(r[safe: $0]) })) } }
            return
        }
        guard let di = h.firstIndex(where: { $0 == "date" || $0 == "day" || $0.contains("date") }) else { return }
        let marks = h.indices.filter { $0 != di && (periodWord(h[$0]) || h[$0].contains("flow")) }
        let ti = h.firstIndex { typeKeys.contains($0) }
        for r in rows.dropFirst() {
            guard let d = parseDay(r[safe: di]) else { continue }
            let byType = ti.map { periodWord(low(r[safe: $0] ?? "")) && !low(r.joined(separator: " ")).contains("spotting") } ?? false
            let byMark = marks.contains { !notAMark.contains(low(r[safe: $0] ?? "")) }
            if byType || byMark || (marks.isEmpty && ti == nil) { days.insert(d) }
        }
    }

    static func read(_ text: String) -> [Period] {
        let t = text.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}").union(.whitespacesAndNewlines))
        var days = Set<Date>(), ranges: [(Date, Date?)] = []
        if t.hasPrefix("{") || t.hasPrefix("[") {
            guard let j = try? JSONSerialization.jsonObject(with: Data(t.utf8)) else { return [] }
            walk(j, path: "", days: &days, ranges: &ranges)
        } else { csv(csvRows(t), days: &days, ranges: &ranges) }
        var out: [(Date, Int)] = ranges.map { s, e in
            let len = e.map { $0 >= s ? min(14, max(1, CycleLogic.days(s, $0) + 1)) : 0 } ?? 0
            return (s, len)
        }
        let list = days.sorted()
        var i = 0
        while i < list.count {
            var j = i
            while j + 1 < list.count && CycleLogic.days(list[j], list[j + 1]) <= 2 { j += 1 }
            out.append((list[i], min(14, max(1, CycleLogic.days(list[i], list[j]) + 1))))
            i = j + 1
        }
        var kept: [(Date, Int)] = []
        for p in out.sorted(by: { $0.0 < $1.0 }) {
            if let last = kept.last, CycleLogic.days(last.0, p.0) < 10 {
                if p.1 > last.1 { kept[kept.count - 1].1 = p.1 }
            } else { kept.append(p) }
        }
        return kept.map { Period(start: AppStore.dayKey($0.0), days: $0.1) }
    }

    static func wanted(_ name: String) -> Bool {
        let n = name.lowercased()
        return [".json", ".csv", ".txt", ".cluedata"].contains { n.hasSuffix($0) } && !n.hasPrefix("__macosx/")
    }
}
