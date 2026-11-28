import SwiftUI
import CryptoKit
import Compression

/// Android's shared baby log (data/BabyShare.kt, data/Vault.kt), on the same server log and the same encryption, so an
/// iPhone and an Android phone can log into one baby. Each shared baby has a family: an id and a key made from the
/// invite code, which only the people who were given it have. Every change (a feed, a diaper, a growth measurement, the
/// baby's name) is sealed on the phone (AES-256-GCM) and added to the family's log on holysteps.org; the other phones
/// read the log and apply it. The server only ever sees unreadable bytes. Running timers stay on each phone (the
/// finished feed or sleep is shared), and pumping isn't shared: it's the parent's own.
enum FamilyCrypto {
    static let idBytes = 10, keyBytes = 16
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")   // Crockford base32

    struct Keys { let fid: String; let secret: String; let key: SymmetricKey; let invite: String }

    static func base32(_ bytes: [UInt8]) -> String {
        var out = "", buffer = 0, bits = 0
        for b in bytes {
            buffer = (buffer << 8) | Int(b); bits += 8
            while bits >= 5 { out.append(alphabet[(buffer >> (bits - 5)) & 31]); bits -= 5 }
            buffer &= (1 << bits) - 1
        }
        if bits > 0 { out.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return out
    }

    /// Reads base32 the way people type it: any case, with spaces or dashes, O for 0 and I or L for 1.
    static func unbase32(_ text: String, bytes: Int) -> [UInt8]? {
        let clean = text.uppercased().filter { !$0.isWhitespace && $0 != "-" }.map { c -> Character in
            switch c { case "O": "0"; case "I", "L": "1"; default: c }
        }
        guard clean.count == (bytes * 8 + 4) / 5 else { return nil }
        var out: [UInt8] = [], buffer = 0, bits = 0
        for c in clean {
            guard let v = alphabet.firstIndex(of: c) else { return nil }
            buffer = (buffer << 5) | v; bits += 5
            if bits >= 8 { if out.count < bytes { out.append(UInt8((buffer >> (bits - 8)) & 0xFF)) }; bits -= 8 }
            buffer &= (1 << bits) - 1
        }
        return out.count == bytes ? out : nil
    }

    static func grouped(_ code: String) -> String {
        stride(from: 0, to: code.count, by: 4).map { i -> String in
            let a = code.index(code.startIndex, offsetBy: i), b = code.index(a, offsetBy: min(4, code.count - i))
            return String(code[a..<b])
        }.joined(separator: "-")
    }

    private static func hex(_ d: some Sequence<UInt8>) -> String { d.map { String(format: "%02x", $0) }.joined() }
    private static func hmac(_ key: [UInt8], _ label: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(label.utf8), using: SymmetricKey(data: Data(key))))
    }

    private static func from(_ raw: [UInt8]) -> Keys {
        let id = Array(raw[0..<idBytes]), k = Array(raw[idBytes...])
        return Keys(fid: hex(id), secret: hex(hmac(k, "holysteps family auth v1")), key: SymmetricKey(data: hmac(k, "holysteps family enc v1")), invite: base32(raw))
    }

    static func newFamily() -> Keys {
        let raw = SymmetricKey(size: SymmetricKeySize(bitCount: (idBytes + keyBytes) * 8)).withUnsafeBytes { Array($0) }
        return from(raw)
    }

    static func fromInvite(_ invite: String) -> Keys? { unbase32(invite, bytes: idBytes + keyBytes).map(from) }

    private static let magic: [UInt8] = [0x48, 0x53, 0x56, 1]   // "HSV" 1, as Vault.seal
    static func seal(_ key: SymmetricKey, _ plain: Data, context: String) -> Data? {
        guard let box = try? AES.GCM.seal(plain, using: key, authenticating: Data(context.utf8)) else { return nil }
        return Data(magic) + Data(box.nonce) + box.ciphertext + box.tag
    }
    static func open(_ key: SymmetricKey, _ d: Data, context: String) -> Data? {
        guard d.count >= 4 + 12 + 16, Array(d.prefix(4)) == magic,
              let nonce = try? AES.GCM.Nonce(data: d.subdata(in: 4..<16)),
              let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: d.subdata(in: 16..<(d.count - 16)), tag: d.suffix(16)) else { return nil }
        return try? AES.GCM.open(box, using: key, authenticating: Data(context.utf8))
    }

    // GZIP, as Java's GZIPOutputStream writes it: a 10-byte header, raw DEFLATE, then CRC-32 and the length.
    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }
    static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in d { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }
    static func gzip(_ d: Data) -> Data? {
        guard let deflated = try? (d as NSData).compressed(using: .zlib) as Data else { return nil }
        var out = Data([0x1f, 0x8b, 0x08, 0, 0, 0, 0, 0, 0, 0xff])
        out.append(deflated)
        var crc = crc32(d).littleEndian, size = UInt32(truncatingIfNeeded: d.count).littleEndian
        out.append(Data(bytes: &crc, count: 4)); out.append(Data(bytes: &size, count: 4))
        return out
    }
    static func gunzip(_ d: Data, max: Int = 1_000_000) -> Data? {
        let b = [UInt8](d)
        guard b.count > 18, b[0] == 0x1f, b[1] == 0x8b, b[2] == 8 else { return nil }
        let flags = b[3]
        var i = 10
        if flags & 4 != 0 { guard i + 2 <= b.count else { return nil }; i += 2 + Int(b[i]) + Int(b[i + 1]) << 8 }
        if flags & 8 != 0 { while i < b.count && b[i] != 0 { i += 1 }; i += 1 }
        if flags & 16 != 0 { while i < b.count && b[i] != 0 { i += 1 }; i += 1 }
        if flags & 2 != 0 { i += 2 }
        guard i < b.count - 8 else { return nil }
        guard let out = try? (Data(b[i..<(b.count - 8)]) as NSData).decompressed(using: .zlib) as Data, out.count <= max else { return nil }
        return out
    }
}

extension BabyLog {
    /// Android's id shape (BabyLog.newId): letters and digits only, so both apps accept the other's ids.
    static func newId(_ now: Date = Date()) -> String {
        String(Int64(now.timeIntervalSince1970 * 1000), radix: 36) + String(Int.random(in: 0..<1_000_000) & 0xFFFFF, radix: 36)
    }
    static func validId(_ s: String) -> Bool { s.range(of: "^[A-Za-z0-9]{1,24}$", options: .regularExpression) != nil }
    static func clean(_ s: String, _ max: Int) -> String {
        String(s.replacingOccurrences(of: "[|~^\\r\\n\\t]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces).prefix(max))
    }

    /// One entry as Android writes it: kind~id~baby~start~end~leftSec~rightSec~firstSide~ml~ml2~milk~diaper~weightG~lengthMm~headMm~note
    static func row(_ e: Entry) -> String {
        let ms = { (d: Date) in String(Int64(d.timeIntervalSince1970 * 1000)) }
        return [e.kind.rawValue, e.id, e.babyId, ms(e.start), e.end.map(ms) ?? "0", "\(e.leftSec)", "\(e.rightSec)", e.firstSide?.rawValue ?? "",
                "\(e.ml)", "\(e.ml2)", e.formula.map { $0 ? "fo" : "bm" } ?? "", e.diaper?.rawValue ?? "",
                "\(e.weightG)", "\(e.lengthMm)", "\(e.headMm)", clean(e.note, 200)].joined(separator: "~")
    }

    static func entry(fromRow row: String) -> Entry? {
        let p = row.components(separatedBy: "~")
        guard p.count >= 5, let kind = Kind(rawValue: p[0]), validId(p[1]), p[2].isEmpty || validId(p[2]),
              let start = Int64(p[3]), start > 0 else { return nil }
        func i(_ k: Int, _ max: Int) -> Int { k < p.count ? min(max, Swift.max(0, Int(p[k]) ?? 0)) : 0 }
        let end = Int64(p[4]).flatMap { $0 >= start ? $0 : nil }
        var e = Entry(id: p[1], babyId: p[2], kind: kind, start: Date(timeIntervalSince1970: Double(start) / 1000),
                      end: end.flatMap { $0 > 0 ? Date(timeIntervalSince1970: Double($0) / 1000) : nil })
        e.leftSec = i(5, 86_400); e.rightSec = i(6, 86_400)
        e.firstSide = p.count > 7 ? Side(rawValue: p[7]) : nil
        e.ml = i(8, 2000); e.ml2 = i(9, 2000)
        e.formula = p.count > 10 ? (p[10] == "fo" ? true : p[10] == "bm" ? false : nil) : nil
        e.diaper = p.count > 11 ? Diaper(rawValue: p[11]) : nil
        e.weightG = i(12, 40_000); e.lengthMm = i(13, 1_500); e.headMm = i(14, 700)
        e.note = p.count > 15 ? clean(p[15...].joined(separator: " "), 200) : ""
        return e
    }
}

@MainActor
final class BabyShare: ObservableObject {
    static let shared = BabyShare()
    struct Share: Codable, Equatable { var babyId: String; var fid: String; var lastSeq: Int64; var since: Int64 }
    struct Pending: Codable, Equatable { var fid: String; var oid: String; var op: String }
    private struct Saved: Codable { var shares: [Share] = []; var outbox: [Pending] = [] }

    @Published private(set) var shares: [Share] = []
    @Published private(set) var outbox: [Pending] = []
    @Published private(set) var syncing = false
    @Published private(set) var message = ""

    static let api = "https://holysteps.org/holysteps/api"
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("baby_share.json")
    private var soon: Task<Void, Never>?
    private var running = false

    private init() {
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: d) { shares = s.shares; outbox = s.outbox }
    }
    private func persist() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(Saved(shares: shares, outbox: Array(outbox.suffix(20_000)))) {
            try? d.write(to: url, options: [.atomic, .completeFileProtection])
        }
    }

    func share(of babyId: String) -> Share? { shares.first { $0.babyId == babyId } }
    /// The invite for a shared baby (to add another phone). Kept in the Keychain on this phone only.
    func invite(of babyId: String) -> String? { share(of: babyId).flatMap { Keychain.get("babyFamily.\($0.fid)") } }
    private func keys(_ s: Share) -> FamilyCrypto.Keys? { Keychain.get("babyFamily.\(s.fid)").flatMap(FamilyCrypto.fromInvite) }

    // MARK: Ops

    private func pending(_ fid: String, _ op: [String: Any]) -> Pending? {
        guard let d = try? JSONSerialization.data(withJSONObject: op), let s = String(data: d, encoding: .utf8) else { return nil }
        return Pending(fid: fid, oid: BabyLog.newId(), op: s)
    }
    private func opBaby(_ b: BabyLog.Baby) -> [String: Any] { ["t": "baby", "id": b.id, "name": b.name, "birth": b.birth, "sex": b.sex.rawValue] }
    private func opPut(_ e: BabyLog.Entry) -> [String: Any] { ["t": "put", "e": BabyLog.row(e)] }
    private func opDel(_ id: String) -> [String: Any] { ["t": "del", "id": id] }

    /// Every local change to a shared baby becomes a sealed change for the others (BabyShare.diff). Pumping stays here.
    func record(before: BabyStore.Saved, after: BabyStore.Saved) {
        guard !shares.isEmpty else { return }
        var out: [Pending] = []
        for s in shares {
            let id = s.babyId
            let b0 = before.babies.first { $0.id == id }, b1 = after.babies.first { $0.id == id }
            if let b1, b1 != b0, let p = pending(s.fid, opBaby(b1)) { out.append(p) }
            let e0 = Dictionary(before.entries.filter { $0.babyId == id && $0.kind != .pu }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let e1 = Dictionary(after.entries.filter { $0.babyId == id && $0.kind != .pu }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for (eid, e) in e1 where e0[eid] != e { if let p = pending(s.fid, opPut(e)) { out.append(p) } }
            for eid in e0.keys where e1[eid] == nil { if let p = pending(s.fid, opDel(eid)) { out.append(p) } }
        }
        guard !out.isEmpty else { return }
        outbox += out
        persist()
        syncSoon()
    }

    /// Applies changes from the other phones (for the shared baby only).
    private func apply(_ ops: [[String: Any]], babyId: String) {
        let store = BabyStore.shared
        var d = store.data
        var entries = Dictionary(d.entries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for op in ops {
            switch op["t"] as? String ?? "" {
            case "baby":
                guard op["id"] as? String == babyId, let birth = op["birth"] as? String,
                      birth.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else { continue }
                let b = BabyLog.Baby(id: babyId, name: BabyLog.clean(op["name"] as? String ?? "", 40), birth: birth,
                                     sex: BabyLog.Sex(rawValue: op["sex"] as? String ?? "") ?? .UNSET)
                if let i = d.babies.firstIndex(where: { $0.id == babyId }) { d.babies[i] = b } else if d.babies.count < 6 { d.babies.append(b) }
            case "put":
                if let e = (op["e"] as? String).flatMap(BabyLog.entry(fromRow:)), e.babyId == babyId { entries[e.id] = e }
            case "del":
                if let id = op["id"] as? String, entries[id]?.babyId == babyId { entries.removeValue(forKey: id) }
            default: break   // milestones and anything newer: kept on the phones that have them
            }
        }
        d.entries = Array(entries.values.sorted { $0.start < $1.start }.suffix(5000))
        store.applyRemote(d)
    }

    private func sealEvent(_ k: FamilyCrypto.Keys, _ ops: [String]) -> Data? {
        let list = ops.compactMap { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) }
        guard let json = try? JSONSerialization.data(withJSONObject: ["v": 1, "ops": list]), let z = FamilyCrypto.gzip(json) else { return nil }
        return FamilyCrypto.seal(k.key, z, context: "holysteps-family-v1:\(k.fid)")
    }
    private func openEvent(_ k: FamilyCrypto.Keys, _ blob: Data) -> [[String: Any]]? {
        guard let z = FamilyCrypto.open(k.key, blob, context: "holysteps-family-v1:\(k.fid)"), let plain = FamilyCrypto.gunzip(z),
              let o = try? JSONSerialization.jsonObject(with: plain) as? [String: Any] else { return nil }
        return o["ops"] as? [[String: Any]]
    }

    /// Packs ops into events of a few kilobytes each, in order (the server takes events up to 6 KB).
    private func pack(_ ops: [Pending]) -> [[Pending]] {
        var out: [[Pending]] = [], cur: [Pending] = [], size = 0
        for p in ops {
            if !cur.isEmpty && size + p.op.count > 3_500 { out.append(cur); cur = []; size = 0 }
            cur.append(p); size += p.op.count + 1
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    // MARK: Server

    private struct Reply { let code: Int; let body: Data
        var ok: Bool { (200..<300).contains(code) }
        var error: String {
            (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? String
                ?? (code == 0 ? tr("Couldn't reach HolySteps. Check your connection and try again.") : tr("Something went wrong. Try again."))
        }
    }

    private func request(_ method: String, _ path: String, _ k: FamilyCrypto.Keys, body: Data? = nil) async -> Reply {
        guard let tok = await AccountStore.shared.token(), let u = URL(string: Self.api + path) else {
            return Reply(code: 401, body: Data(#"{"error":"Not signed in yet. Check your connection and try again."}"#.utf8))
        }
        var r = URLRequest(url: u, timeoutInterval: 30)
        r.httpMethod = method
        r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        r.setValue(k.secret, forHTTPHeaderField: "X-Family-Auth")
        if let body { r.httpBody = body; r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type") }
        guard let res = try? await URLSession.shared.data(for: r) else { return Reply(code: 0, body: Data()) }
        return Reply(code: (res.1 as? HTTPURLResponse)?.statusCode ?? 0, body: res.0)
    }

    /// Every event after `since`, opened, and the newest sequence number.
    private func read(_ k: FamilyCrypto.Keys, since: Int64) async -> (ops: [[String: Any]], last: Int64, code: Int, error: String?) {
        var ops: [[String: Any]] = [], last = since
        while true {
            let r = await request("GET", "/family/\(k.fid)/events?since=\(last)", k)
            if !r.ok { return (ops, last, r.code, r.error) }
            guard let page = try? JSONSerialization.jsonObject(with: r.body) as? [String: Any] else { break }
            for e in page["events"] as? [[String: Any]] ?? [] {
                last = max(last, (e["seq"] as? NSNumber)?.int64Value ?? last)
                if let b64 = e["data"] as? String, let blob = Data(base64Encoded: b64), let o = openEvent(k, blob) { ops += o }
            }
            if (page["more"] as? Bool) != true { break }
        }
        return (ops, last, 200, nil)
    }

    // MARK: Starting, joining and leaving

    /// Shares a baby: makes a new family and sends the baby and everything logged so far. Returns an error, or nil.
    func start(_ babyId: String) async -> String? {
        let store = BabyStore.shared
        store.makeIdsCompatible()
        guard let baby = store.data.babies.first(where: { $0.id == babyId }) else { return tr("Couldn't share.") }
        let k = FamilyCrypto.newFamily()
        Keychain.set(k.invite, for: "babyFamily.\(k.fid)")
        var ops: [Pending] = []
        if let p = pending(k.fid, opBaby(baby)) { ops.append(p) }
        for e in store.data.entries where e.babyId == babyId && e.kind != .pu { if let p = pending(k.fid, opPut(e)) { ops.append(p) } }
        shares.removeAll { $0.babyId == babyId }
        shares.append(Share(babyId: babyId, fid: k.fid, lastSeq: 0, since: Firestore.nowMs))
        outbox += ops
        persist()
        if let problem = await sync() { return problem + " " + tr("It will finish when you're back online.") }
        return nil
    }

    /// Joins a baby someone else shared, with their invite code. Returns an error, or nil.
    func join(_ input: String) async -> String? {
        let code = InviteCode.clean(input).replacingOccurrences(of: "-", with: "")
        guard let k = FamilyCrypto.fromInvite(code) else { return tr("That isn't a complete invite code.") }
        if shares.contains(where: { $0.fid == k.fid }) { return tr("This baby is already shared on this phone.") }
        let r = await read(k, since: 0)
        if r.code == 404 { return tr("Nothing is shared with that code. Check it, or ask for a new one.") }
        if let e = r.error { return e }
        guard let babyId = r.ops.last(where: { $0["t"] as? String == "baby" })?["id"] as? String, BabyLog.validId(babyId) else {
            return tr("That code couldn't be opened. Ask for the invite again.")
        }
        let store = BabyStore.shared
        if store.data.babies.count >= 6 && !store.data.babies.contains(where: { $0.id == babyId }) {
            return tr("This phone already has 6 babies. Remove one first.")
        }
        Keychain.set(k.invite, for: "babyFamily.\(k.fid)")
        apply(r.ops, babyId: babyId)
        shares.removeAll { $0.babyId == babyId }
        shares.append(Share(babyId: babyId, fid: k.fid, lastSeq: r.last, since: Firestore.nowMs))
        persist()
        store.data.current = babyId
        return nil
    }

    /// Stops sharing on this phone (the baby and its log stay here), or for everyone (the shared log is deleted).
    func leave(_ babyId: String, forEveryone: Bool) async -> String? {
        guard let s = share(of: babyId) else { return nil }
        if forEveryone, let k = keys(s) {
            let r = await request("DELETE", "/family/\(k.fid)", k)
            if !r.ok && r.code != 404 { return r.error }
        }
        drop(s)
        return nil
    }

    private func drop(_ s: Share) {
        shares.removeAll { $0.fid == s.fid }
        outbox.removeAll { $0.fid == s.fid }
        Keychain.set(nil, for: "babyFamily.\(s.fid)")
        persist()
    }

    // MARK: Sync

    func syncSoon() {
        soon?.cancel()
        soon = Task { try? await Task.sleep(nanoseconds: 2_000_000_000); if !Task.isCancelled { _ = await sync() } }
    }

    /// Sends what's waiting and reads what's new, for every shared baby. Returns a problem in plain words, or nil.
    @discardableResult func sync() async -> String? {
        guard !shares.isEmpty, !running else { return nil }
        running = true; syncing = true
        defer { running = false; syncing = false }
        var problem: String?
        for s in shares {
            guard let k = keys(s) else { continue }
            for batch in pack(outbox.filter { $0.fid == s.fid }) {
                guard let blob = sealEvent(k, batch.map(\.op)) else { continue }
                let r = await request("POST", "/family/\(k.fid)/events", k, body: blob)
                if r.code == 404 && s.lastSeq > 0 { drop(s); problem = tr("Sharing was turned off from another phone. Everything logged so far stays on this phone."); break }
                if !r.ok { problem = r.error; break }
                let sent = Set(batch.map(\.oid))
                outbox.removeAll { $0.fid == s.fid && sent.contains($0.oid) }
                persist()
            }
            if problem != nil { continue }
            guard let cur = share(of: s.babyId) else { continue }
            let r = await read(k, since: cur.lastSeq)
            if r.code == 404 { drop(s); problem = tr("Sharing was turned off from another phone. Everything logged so far stays on this phone."); continue }
            if r.last > cur.lastSeq {
                apply(r.ops, babyId: s.babyId)
                if let i = shares.firstIndex(where: { $0.fid == s.fid }) { shares[i].lastSeq = r.last; persist() }
            }
            if let e = r.error { problem = e }
        }
        message = problem ?? ""
        return problem
    }
}

/// Android's ShareDialog: share a baby with a partner or sitter, show the invite, or join one with a code.
struct BabyShareSheet: View {
    let baby: BabyLog.Baby?
    @ObservedObject private var share = BabyShare.shared
    @ObservedObject private var store = BabyStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var busy = false
    @State private var error = ""
    @State private var confirmEnd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let baby, share.share(of: baby.id) != nil, let invite = share.invite(of: baby.id) {
                        T("Everyone with this code logs into the same baby. It's end-to-end encrypted: only phones with the code can read it.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        Text(FamilyCrypto.grouped(invite)).font(.system(size: 14, design: .monospaced)).foregroundStyle(HS.text)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity).textSelection(.enabled)
                        ShareLink(item: InviteCode.link(invite, kind: "baby"),
                                  message: Text(tr("Join {0} in HolySteps: open the baby tracker, tap Share, then Join, and enter this code:").replacingOccurrences(of: "{0}", with: baby.name.isEmpty ? tr("our baby") : baby.name)
                                                + "\n\n" + FamilyCrypto.grouped(invite) + "\n\n" + tr("Keep it private: anyone with it can see and add to the baby's log."))) {
                            T("Send the invite").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                                .frame(maxWidth: .infinity).padding(.vertical, 13).background(Capsule().fill(HS.goldButton))
                        }
                        ShowQRButton(code: invite, kind: "baby")
                        T(share.syncing ? "Syncing…" : !share.message.isEmpty ? share.message
                          : share.outbox.contains { $0.fid == share.share(of: baby.id)?.fid } ? "Some changes are waiting to be sent." : "Up to date.")
                            .font(.hs(12)).foregroundStyle(share.message.isEmpty ? HS.textSecondary : Color(hex: 0xF87171))
                        HStack(spacing: 10) {
                            pill("Sync now") { Task { await share.sync() } }
                            pill("Leave") { Task { busy = true; _ = await share.leave(baby.id, forEveryone: false); busy = false; dismiss() } }
                        }
                        Button { confirmEnd = true } label: { T("Stop sharing for everyone").font(.hs(12, .semibold)).foregroundStyle(Color(hex: 0xF87171)) }
                            .buttonStyle(.plain)
                    } else {
                        if let baby {
                            T("Both parents (and a sitter or grandparent) log into the same baby, from their own phones. End-to-end encrypted: only phones with the invite code can read it, not even us.")
                                .font(.hs(13)).foregroundStyle(HS.textSecondary)
                            GoldButton(title: busy ? "Sharing…" : tr("Share") + " " + (baby.name.isEmpty ? tr("this baby") : baby.name)) {
                                guard !busy else { return }
                                busy = true; error = ""
                                Task { if let e = await share.start(baby.id) { error = e }; busy = false }
                            }
                            .padding(.bottom, 8)
                        }
                        T("Joining someone else's baby?").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        TextField(tr("Invite code"), text: $code)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .font(.system(size: 15, design: .monospaced)).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                            .onChange(of: code) { _, v in if v.count > 80 { code = String(v.prefix(80)) } }
                        GoldButton(title: busy ? "Joining…" : "Join") {
                            guard !busy, !code.isEmpty else { return }
                            busy = true; error = ""
                            Task {
                                if let e = await share.join(code) { error = e; busy = false } else { busy = false; dismiss() }
                            }
                        }
                    }
                    if !error.isEmpty { D(error).font(.hs(12)).foregroundStyle(Color(hex: 0xF87171)) }
                }
                .padding(20)
            }
            .navigationTitle(baby.flatMap { share.share(of: $0.id) != nil ? tr("Shared") + " " + ($0.name.isEmpty ? tr("baby") : $0.name) : nil } ?? tr("Share with your partner or sitter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("Done")) { dismiss() }.disabled(busy) } }
            .onAppear { let c = InviteInbox.take("baby"); if !c.isEmpty { code = c } }
            .alert(tr("Stop sharing for everyone?"), isPresented: $confirmEnd) {
                Button(tr("Stop for everyone"), role: .destructive) {
                    guard let baby else { return }
                    Task { busy = true; if let e = await share.leave(baby.id, forEveryone: true) { error = e } else { dismiss() }; busy = false }
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: { T("The shared log is deleted from our server and the other phones stop getting updates. Everything already logged stays on each phone.") }
        }
        .presentationDetents([.medium, .large])
    }

    private func pill(_ label: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            T(label).font(.hs(13, .semibold)).foregroundStyle(HS.readable(0x38BDF8))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Capsule().strokeBorder(Color(hex: 0x38BDF8).opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}
