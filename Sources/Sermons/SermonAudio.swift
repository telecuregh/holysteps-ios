import Foundation
import AVFoundation
import CommonCrypto
import UniformTypeIdentifiers

/// Joel's recorded sermons, the same protected way as Android's SermonAudio.kt (holysteps-admin sermonAudio.ts):
///  1. Signed in, the app asks GET /holysteps/api/content/sermon/{file} and gets that file's own AES-256-CTR key and a
///     download link that works for an hour. The server checks the plan; a free account gets only this week's book.
///  2. The download is the recording encrypted with that key. It's kept in Application Support (excluded from
///     backups), and the key in the Keychain, so it plays offline afterwards but the saved file is useless elsewhere.
///  3. Playing decrypts only the bytes AVPlayer asks for (an AVAssetResourceLoader), so no plain copy is ever written.
enum SermonAudio {
    private static let host = "holysteps.org"
    private static let api = "https://holysteps.org/holysteps/api/content/sermon/"
    private static let fileRe = try! NSRegularExpression(pattern: #"^[a-z0-9_]{1,60}\.[0-9a-f]{12}\.mp3$"#)

    enum Problem { case offline, signIn, notAllowed, failed, notFound }
    enum Result { case ready(AVURLAsset, CTRLoader), failed(Problem) }

    /// The file name in one of HolySteps' own recording links.
    static func fileOf(_ url: URL) -> String? {
        guard url.scheme == "https", url.host == host, url.path.hasPrefix("/sermon-audio/"), url.query == nil else { return nil }
        let f = String(url.path.dropFirst("/sermon-audio/".count))
        return fileRe.firstMatch(in: f, range: NSRange(f.startIndex..., in: f)) == nil ? nil : f
    }

    private static var dir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("sermon-audio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: d.path) {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            var u = d; var v = URLResourceValues(); v.isExcludedFromBackup = true; try? u.setResourceValues(v)
        }
        return d
    }

    /// The recording ready to play: the saved copy, or downloaded (encrypted) first.
    static func prepare(_ file: String) async -> Result {
        if let r = saved(file) { return r }
        guard let token = await AccountStore.shared.token() else { return .failed(.signIn) }
        guard let url = URL(string: api + file) else { return .failed(.failed) }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return .failed(.offline) }
        switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 401: return .failed(.signIn)
        case 402, 403: return .failed(.notAllowed)
        case 404: return .failed(.notFound)
        default: return .failed(.failed)
        }
        guard let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let name = j["file"] as? String, fileRe.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil,
              let key = (j["key"] as? String).flatMap({ Data(base64Encoded: $0) }), key.count == 32,
              let iv = (j["iv"] as? String).flatMap({ Data(base64Encoded: $0) }), iv.count == 16,
              let link = (j["url"] as? String).flatMap(URL.init(string:)), link.scheme == "https", link.host == host
        else { return .failed(.failed) }
        guard let (tmp, dresp) = try? await URLSession.shared.download(from: link),
              (dresp as? HTTPURLResponse)?.statusCode == 200 else { return .failed(.failed) }
        let out = dir.appendingPathComponent(name + ".enc")
        try? FileManager.default.removeItem(at: out)
        do { try FileManager.default.moveItem(at: tmp, to: out) } catch { return .failed(.failed) }
        Keychain.set((key + iv).base64EncodedString(), for: "sermonKey.\(name)")
        return saved(name) ?? .failed(.failed)
    }

    private static func saved(_ file: String) -> Result? {
        let f = dir.appendingPathComponent(file + ".enc")
        guard FileManager.default.fileExists(atPath: f.path),
              let raw = Keychain.get("sermonKey.\(file)").flatMap({ Data(base64Encoded: $0) }), raw.count == 48,
              let loader = CTRLoader(file: f, key: raw.prefix(32), iv: raw.suffix(16)),
              let u = URL(string: "hsaudio://sermon/\(file)") else { return nil }
        let asset = AVURLAsset(url: u)
        asset.resourceLoader.setDelegate(loader, queue: loader.queue)
        return .ready(asset, loader)
    }

    /// Words for the person when Joel's recording can't play (the captions still go on).
    static func message(_ p: Problem) -> String {
        switch p {
        case .notAllowed: tr("Joel's recorded sermons come with the Faith plan.")
        case .signIn: tr("Sign-in is still connecting, so Joel's recording isn't available yet.")
        case .offline: tr("You're offline, so Joel's recording can't download right now.")
        case .notFound, .failed: tr("Joel's recording couldn't be loaded right now.")
        }
    }
}

/// Serves an AES-256-CTR file to AVPlayer, decrypting just the bytes it asks for (Android's CtrSource).
final class CTRLoader: NSObject, AVAssetResourceLoaderDelegate {
    let queue = DispatchQueue(label: "holysteps.sermon-audio")
    private let handle: FileHandle
    private let size: Int64
    private let key: Data, iv: Data

    init?(file: URL, key: Data, iv: Data) {
        guard let h = try? FileHandle(forReadingFrom: file),
              let n = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? NSNumber, n.int64Value > 0 else { return nil }
        handle = h; size = n.int64Value; self.key = key; self.iv = iv
    }
    deinit { try? handle.close() }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource req: AVAssetResourceLoadingRequest) -> Bool {
        if let info = req.contentInformationRequest {
            info.contentType = UTType.mp3.identifier
            info.contentLength = size
            info.isByteRangeAccessSupported = true
        }
        if let d = req.dataRequest {
            let start = d.currentOffset != 0 ? d.currentOffset : d.requestedOffset
            let want = d.requestsAllDataToEndOfResource ? size - start : Int64(d.requestedLength) - (start - d.requestedOffset)
            var at = start, left = max(0, min(want, size - start))
            while left > 0 && !req.isCancelled {
                let n = Int(min(left, 256 * 1024))
                guard let chunk = read(at: at, count: n) else { req.finishLoading(with: NSError(domain: "SermonAudio", code: 1)); return true }
                d.respond(with: chunk)
                at += Int64(chunk.count); left -= Int64(chunk.count)
                if chunk.count < n { break }
            }
        }
        req.finishLoading()
        return true
    }

    /// Plain bytes [at, at+count) of the recording.
    private func read(at: Int64, count: Int) -> Data? {
        let block = at / 16, skip = Int(at % 16)
        do { try handle.seek(toOffset: UInt64(block * 16)) } catch { return nil }
        guard let enc = try? handle.read(upToCount: count + skip), !enc.isEmpty else { return nil }
        guard let plain = ctr(enc, counter: counter(advancedBy: block)) else { return nil }
        return plain.count > skip ? plain.subdata(in: skip..<min(plain.count, skip + count)) : Data()
    }

    /// The IV advanced by `blocks` (a 128-bit big-endian add, as Node's aes-256-ctr counts).
    private func counter(advancedBy blocks: Int64) -> Data {
        var c = [UInt8](iv), carry = UInt64(blocks)
        var i = 15
        while i >= 0 && carry > 0 {
            let sum = UInt64(c[i]) + (carry & 0xFF)
            c[i] = UInt8(sum & 0xFF)
            carry = (carry >> 8) + (sum >> 8)
            i -= 1
        }
        return Data(c)
    }

    private func ctr(_ input: Data, counter: Data) -> Data? {
        var ref: CCCryptorRef?
        let made = key.withUnsafeBytes { k in counter.withUnsafeBytes { c in
            CCCryptorCreateWithMode(CCOperation(kCCDecrypt), CCMode(kCCModeCTR), CCAlgorithm(kCCAlgorithmAES), CCPadding(ccNoPadding),
                                    c.baseAddress, k.baseAddress, key.count, nil, 0, 0, CCModeOptions(kCCModeOptionCTR_BE), &ref)
        } }
        guard made == kCCSuccess, let ref else { return nil }
        defer { CCCryptorRelease(ref) }
        var out = Data(count: input.count)
        var moved = 0
        let st = out.withUnsafeMutableBytes { o in input.withUnsafeBytes { i in
            CCCryptorUpdate(ref, i.baseAddress, input.count, o.baseAddress, input.count, &moved)
        } }
        guard st == kCCSuccess else { return nil }
        return out.prefix(moved)
    }
}
