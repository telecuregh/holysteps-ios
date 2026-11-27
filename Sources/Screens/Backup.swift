import SwiftUI
import CryptoKit
import CommonCrypto

/// Android's encrypted backup (Backup.kt, Vault.kt), on the same server with the same keys: everything HolySteps keeps
/// on this iPhone is sealed here with a key made from the person's recovery code (PBKDF2-SHA256, 120,000 rounds), and
/// the server keeps only unreadable bytes. Without the code nobody, including us, can open it. Not included: things
/// tied to this phone or account (sign-in, purchases, step counts from Apple Health) and skin journal photos.
/// An iPhone backup restores on an iPhone; Android keeps its own format.
enum Backup {
    static let api = "https://holysteps.org/holysteps/api"
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    static let recoveryBytes = 15

    static func base32(_ b: [UInt8]) -> String {
        var out = "", buf = 0, bits = 0
        for x in b { buf = (buf << 8) | Int(x); bits += 8; while bits >= 5 { out.append(alphabet[(buf >> (bits - 5)) & 31]); bits -= 5 }; buf &= (1 << bits) - 1 }
        if bits > 0 { out.append(alphabet[(buf << (5 - bits)) & 31]) }
        return out
    }
    /// Reads the code the way people type it: any case, spaces or dashes, O for 0 and I or L for 1.
    static func normalize(_ text: String) -> String? {
        let clean = text.uppercased().filter { !$0.isWhitespace && $0 != "-" }.map { c -> Character in c == "O" ? "0" : (c == "I" || c == "L") ? "1" : c }
        guard clean.count == (recoveryBytes * 8 + 4) / 5 else { return nil }
        var out: [UInt8] = [], buf = 0, bits = 0
        for c in clean {
            guard let v = alphabet.firstIndex(of: c) else { return nil }
            buf = (buf << 5) | v; bits += 5
            if bits >= 8 { if out.count < recoveryBytes { out.append(UInt8((buf >> (bits - 8)) & 0xFF)) }; bits -= 8 }
            buf &= (1 << bits) - 1
        }
        return out.count == recoveryBytes ? base32(out) : nil
    }
    static func newCode() -> String { base32((0..<recoveryBytes).map { _ in UInt8.random(in: 0...255) }) }
    static func grouped(_ c: String) -> String { stride(from: 0, to: c.count, by: 4).map { i in String(Array(c)[i..<min(i + 4, c.count)]) }.joined(separator: "-") }

    struct Keys { let lookup, secret: String; let key: SymmetricKey }
    static func keys(_ code: String) -> Keys {
        var out = [UInt8](repeating: 0, count: 64)
        let salt = Array("HolySteps backup v1".utf8)
        _ = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), code, code.utf8.count, salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 120_000, &out, 64)
        let hex = { (b: ArraySlice<UInt8>) in b.map { String(format: "%02x", $0) }.joined() }
        return Keys(lookup: hex(out[32..<48]), secret: SHA256.hash(data: Data(out[48..<64])).map { String(format: "%02x", $0) }.joined(), key: SymmetricKey(data: Data(out[0..<32])))
    }
    private static let magic: [UInt8] = [0x48, 0x53, 0x56, 1]
    static func seal(_ key: SymmetricKey, _ plain: Data, context: String) -> Data? {
        guard let b = try? AES.GCM.seal(plain, using: key, authenticating: Data(context.utf8)) else { return nil }
        return Data(magic) + Data(b.nonce) + b.ciphertext + b.tag
    }
    static func open(_ key: SymmetricKey, _ d: Data, context: String) -> Data? {
        guard d.count >= 32, Array(d.prefix(4)) == magic, let n = try? AES.GCM.Nonce(data: d.subdata(in: 4..<16)),
              let box = try? AES.GCM.SealedBox(nonce: n, ciphertext: d.subdata(in: 16..<(d.count - 16)), tag: d.suffix(16)) else { return nil }
        return try? AES.GCM.open(box, using: key, authenticating: Data(context.utf8))
    }

    /// Settings that belong to this phone or this account, so they're neither saved nor restored.
    static func isDeviceKey(_ k: String) -> Bool {
        let exact: Set<String> = ["accountUid", "healthAsked", "lastBackupAt", "lastBackupError", "legalSyncedVersion"]
        let prefixes = ["Apple", "NS", "AK", "com.apple", "WebKit", "INNext", "PK", "MSV", "plan", "purchase", "trial", "steps", "stepCache"]
        return exact.contains(k) || prefixes.contains { k.hasPrefix($0) }
    }

    static func snapshot() throws -> Data {
        let all = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        let mine = all.filter { !isDeviceKey($0.key) }
        let plist = try PropertyListSerialization.data(fromPropertyList: mine, format: .binary, options: 0)
        let body: [String: Any] = ["v": 1, "platform": "ios", "createdAt": Int64(Date().timeIntervalSince1970 * 1000), "defaults": plist.base64EncodedString()]
        return try JSONSerialization.data(withJSONObject: body)
    }

    enum Failure: Error, LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
    }

    private static func request(_ method: String, _ k: Keys, body: Data? = nil) async throws -> (Int, Data) {
        guard let url = URL(string: "\(api)/backup/\(k.lookup)") else { throw Failure.message("Bad address.") }
        var r = URLRequest(url: url, timeoutInterval: 60); r.httpMethod = method
        r.setValue(k.secret, forHTTPHeaderField: "X-Backup-Auth")
        if let tok = await AccountStore.shared.token() { r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization") }
        if let body { r.httpBody = body; r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type") }
        let (d, resp) = try await URLSession.shared.data(for: r)
        return ((resp as? HTTPURLResponse)?.statusCode ?? 0, d)
    }
    private static func serverError(_ d: Data) -> String {
        ((try? JSONSerialization.jsonObject(with: d)) as? [String: Any])?["error"] as? String ?? "The backup server didn't answer. Try again later."
    }

    static var code: String? { get { Keychain.get("backupCode") } set { Keychain.set(newValue, for: "backupCode") } }

    @discardableResult
    static func backUpNow() async -> Bool {
        guard let code else { return false }
        let k = keys(code)
        do {
            let plain = try (snapshot() as NSData).compressed(using: .zlib) as Data
            guard let sealed = seal(k.key, plain, context: "holysteps-backup-ios-v1:\(k.lookup)") else { throw Failure.message("Couldn't seal the backup.") }
            let (st, d) = try await request("PUT", k, body: sealed)
            guard (200..<300).contains(st) else { throw Failure.message(serverError(d)) }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackupAt"); UserDefaults.standard.removeObject(forKey: "lastBackupError")
            return true
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: "lastBackupError"); return false
        }
    }

    /// Once a day at most, when the app leaves the screen.
    static func maybeAuto() {
        guard code != nil, Date().timeIntervalSince1970 - UserDefaults.standard.double(forKey: "lastBackupAt") > 86_400 else { return }
        Task { await backUpNow() }
    }

    static func turnOff() async {
        if let c = code { _ = try? await request("DELETE", keys(c)) }
        code = nil; UserDefaults.standard.removeObject(forKey: "lastBackupAt")
    }

    /// Downloads and opens the backup for this code, then replaces this phone's HolySteps data with it.
    static func restore(_ input: String) async -> String? {
        guard let c = normalize(input) else { return "That recovery code isn't complete. It has 24 letters and numbers." }
        let k = keys(c)
        guard let (st, d) = try? await request("GET", k) else { return "Couldn't reach the backup server. Check your connection." }
        if st == 404 { return "No backup found for that recovery code. Check it and try again." }
        guard (200..<300).contains(st) else { return serverError(d) }
        if open(k.key, d, context: "holysteps-backup-v1:\(k.lookup)") != nil {
            return "That backup was made on an Android phone. It can be restored on Android; on iPhone, start fresh and turn backup on here."
        }
        guard let z = open(k.key, d, context: "holysteps-backup-ios-v1:\(k.lookup)"),
              let plain = try? (z as NSData).decompressed(using: .zlib) as Data,
              let j = try? JSONSerialization.jsonObject(with: plain) as? [String: Any],
              let b64 = j["defaults"] as? String, let pd = Data(base64Encoded: b64),
              let dict = try? PropertyListSerialization.propertyList(from: pd, format: nil) as? [String: Any] else { return "That backup couldn't be opened with this code." }
        if (j["v"] as? Int ?? 1) > 1 { return "That backup was made by a newer HolySteps. Update the app and try again." }
        let ud = UserDefaults.standard
        for (key, _) in ud.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:] where !isDeviceKey(key) { ud.removeObject(forKey: key) }
        for (key, v) in dict where !isDeviceKey(key) { ud.set(v, forKey: key) }
        code = c
        return nil
    }
}

struct BackupView: View {
    @State private var code = Backup.code
    @State private var busy = false
    @State private var restoring = false
    @State private var input = ""
    @State private var message = ""
    @State private var confirmOff = false
    @State private var restored = false

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🔐 Encrypted backup").font(.hs(24)).foregroundStyle(HS.text)
                    T("Your prayers, journal, cycle dates, highlights and settings, sealed on this iPhone with a recovery code only you hold. Our server keeps unreadable bytes; without the code nobody, including us, can open them. Skin journal photos and your sign-in aren't included.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if let c = code {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                T("Your recovery code").font(.hs(14, .bold)).foregroundStyle(HS.text)
                                D(Backup.grouped(c)).font(.system(.title3, design: .monospaced)).foregroundStyle(HS.text).textSelection(.enabled)
                                T("Write it down and keep it somewhere safe. It's the only way to open your backup on a new iPhone. We can't recover it for you.")
                                    .font(.hs(12)).foregroundStyle(HS.textMuted)
                                let last = UserDefaults.standard.double(forKey: "lastBackupAt")
                                D(last > 0 ? tr("Last backup: \(Date(timeIntervalSince1970: last).formatted(date: .abbreviated, time: .shortened))") : tr("Not backed up yet"))
                                    .font(.hs(12)).foregroundStyle(HS.textSecondary)
                                if let e = UserDefaults.standard.string(forKey: "lastBackupError") { D(e).font(.hs(12)).foregroundStyle(HS.readable(0xF43F5E)) }
                                HStack {
                                    GoldButton(title: busy ? "Backing up…" : "Back up now") { run { message = await Backup.backUpNow() ? tr("Backed up.") : (UserDefaults.standard.string(forKey: "lastBackupError") ?? "") } }
                                    Button(tr("Turn off"), role: .destructive) { confirmOff = true }.buttonStyle(.bordered)
                                }
                            }
                        }
                    } else {
                        GoldButton(title: "Turn on backup") {
                            let c = Backup.newCode(); Backup.code = c; code = c
                            run { message = await Backup.backUpNow() ? tr("Backed up. Write your recovery code down now.") : (UserDefaults.standard.string(forKey: "lastBackupError") ?? "") }
                        }
                    }
                    Button(tr("Restore from a recovery code")) { restoring = true }.buttonStyle(.bordered)
                    if !message.isEmpty { D(message).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    T("HolySteps backs up once a day when you leave the app, if backup is on.").font(.hs(11)).foregroundStyle(HS.textMuted)
                }.padding(20)
            }
        }
        .alert(tr("Restore your backup?"), isPresented: $restoring) {
            TextField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $input).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button(tr("Restore"), role: .destructive) { let i = input; input = ""; run { if let e = await Backup.restore(i) { message = tr(e) } else { code = Backup.code; restored = true } } }
            Button(tr("Cancel"), role: .cancel) { input = "" }
        } message: { T("This replaces what HolySteps has on this iPhone with the backup.") }
        .alert(tr("Turn off backup?"), isPresented: $confirmOff) {
            Button(tr("Turn off and delete it"), role: .destructive) { run { await Backup.turnOff(); code = nil; message = tr("Backup is off, and the copy on our server was deleted.") } }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("The backup on our server is deleted, and your recovery code stops working.") }
        .alert(tr("Restored"), isPresented: $restored) { Button(tr("OK")) {} } message: { T("Close HolySteps and open it again to see everything.") }
    }

    private func run(_ f: @escaping () async -> Void) { busy = true; Task { await f(); busy = false } }
}
