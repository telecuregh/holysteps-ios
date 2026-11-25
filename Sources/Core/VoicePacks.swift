import Foundation
import CryptoKit
import AVFoundation

/// Human narration recorded with Kokoro, hosted on holysteps.org/voice (ported from Android's VoicePacks.kt).
/// Each sermon, and each of the best-loved KJV chapters, has a small "voice pack": every spoken line as its own MP3,
/// joined into one file, plus a JSON index of where each line sits. A pack is downloaded once, checked against its
/// SHA-256, kept on the phone and works offline. A line with no recording falls back to the phone's own voice.
actor VoicePacks {
    static let shared = VoicePacks()
    static let baseURL = URL(string: "https://holysteps.org/voice")!

    struct Voice: Identifiable, Hashable { let id: String; let name: String; let description: String }
    /// The narrators offered for the Bible (Grace narrates by default).
    static let narrators = [
        Voice(id: "af_heart", name: "Grace", description: "Warm and gentle · American"),
        Voice(id: "am_michael", name: "Michael", description: "Calm and steady · American"),
    ]
    /// The preacher of the weekly sermon.
    static let preacher = "am_onyx"
    static let deviceVoice = "device"

    struct Clip { let offset: Int; let length: Int; let ms: Int }

    final class Pack {
        let voice: String
        let id: String
        let file: URL
        private let clips: [String: Clip]
        private var data: Data?

        init(voice: String, id: String, file: URL, clips: [String: Clip]) {
            self.voice = voice; self.id = id; self.file = file; self.clips = clips
        }

        func has(_ text: String) -> Bool { clips[Narration.key(text)] != nil }

        /// The MP3 bytes of one line, or nil when it wasn't recorded.
        func audio(for text: String) -> Data? {
            guard let c = clips[Narration.key(text)] else { return nil }
            if data == nil { data = try? Data(contentsOf: file, options: .mappedIfSafe) }
            guard let d = data, c.offset >= 0, c.offset + c.length <= d.count else { return nil }
            return d.subdata(in: c.offset..<(c.offset + c.length))
        }
    }

    private struct Entry { let file: String; let json: String; let bytes: Int; let sha256: String }

    private var index: [String: [String: Entry]]?
    private var indexAt = Date.distantPast
    private var failedAt = Date.distantPast
    private var loaded: [String: Pack] = [:]

    private static let safeName = try! NSRegularExpression(pattern: #"^[a-z0-9_]+\.[0-9a-f]{12}\.(pack|json)$"#)
    private static func safe(_ s: String) -> Bool {
        safeName.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    private func dir(_ voice: String) -> URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("voice/\(voice)", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func get(_ url: URL, timeout: TimeInterval = 30) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue("HolySteps-iOS", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private func loadIndex() async -> [String: [String: Entry]]? {
        if let index, Date().timeIntervalSince(indexAt) < 6 * 3600 { return index }
        let cache = dir("").appendingPathComponent("index.json")
        var body: Data?
        if Date().timeIntervalSince(failedAt) > 60 {
            body = try? await get(VoicePacks.baseURL.appendingPathComponent("index.json"), timeout: 15)
            if let b = body { try? b.write(to: cache, options: .atomic); indexAt = Date() } else { failedAt = Date() }
        }
        if body == nil, let index { return index }
        guard let data = body ?? (try? Data(contentsOf: cache)),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let voices = root["voices"] as? [String: Any] else { return index }
        var out: [String: [String: Entry]] = [:]
        for (voice, v) in voices {
            guard let packs = (v as? [String: Any])?["packs"] as? [String: [String: Any]] else { continue }
            var m: [String: Entry] = [:]
            for (id, p) in packs {
                guard let file = p["file"] as? String, let json = p["json"] as? String, VoicePacks.safe(file), VoicePacks.safe(json) else { continue }
                m[id] = Entry(file: file, json: json, bytes: (p["bytes"] as? NSNumber)?.intValue ?? 0, sha256: p["sha256"] as? String ?? "")
            }
            out[voice] = m
        }
        index = out
        return out
    }

    /// The voices that have a recording of this pack, in the order given.
    func voices(having packId: String, among order: [String]) async -> [String] {
        guard let idx = await loadIndex() else { return [] }
        return order.filter { idx[$0]?[packId] != nil }
    }

    func isDownloaded(voice: String, packId: String) -> Bool {
        loaded["\(voice)/\(packId)"] != nil || localPair(voice: voice, packId: packId) != nil
    }

    /// The pack, from the phone or downloaded. Nil when there's no recording or it can't be had (the caller then uses
    /// the phone's voice).
    func ensure(voice: String, packId: String) async -> Pack? {
        let key = "\(voice)/\(packId)"
        if let p = loaded[key] { return p }
        let d = dir(voice)
        let entry = await loadIndex()?[voice]?[packId]
        if let e = entry {
            let pack = d.appendingPathComponent(e.file), json = d.appendingPathComponent(e.json)
            if let p = try? await fetch(voice: voice, packId: packId, entry: e, pack: pack, json: json) {
                loaded[key] = p
                // Older recordings of this pack are cleared off the phone.
                for f in (try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? []
                where f.hasPrefix("\(packId).") && f != e.file && f != e.json {
                    try? FileManager.default.removeItem(at: d.appendingPathComponent(f))
                }
                return p
            }
        }
        if let pair = localPair(voice: voice, packId: packId), let p = try? readPack(voice: voice, packId: packId, pack: pair.0, json: pair.1) {
            loaded[key] = p
            return p
        }
        return nil
    }

    private func localPair(voice: String, packId: String) -> (URL, URL)? {
        let d = dir(voice)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? []
        for f in files where f.hasPrefix("\(packId).") && f.hasSuffix(".pack") {
            let json = d.appendingPathComponent(String(f.dropLast(5)) + ".json")
            if FileManager.default.fileExists(atPath: json.path) { return (d.appendingPathComponent(f), json) }
        }
        return nil
    }

    private func fetch(voice: String, packId: String, entry e: Entry, pack: URL, json: URL) async throws -> Pack {
        let fm = FileManager.default
        let size = (try? fm.attributesOfItem(atPath: pack.path)[.size] as? NSNumber)?.intValue ?? -1
        if size != e.bytes {
            let data = try await get(VoicePacks.baseURL.appendingPathComponent("\(voice)/\(e.file)"), timeout: 120)
            let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if !e.sha256.isEmpty && hex.lowercased() != e.sha256.lowercased() { throw URLError(.cannotDecodeContentData) }
            try data.write(to: pack, options: .atomic)
            var v = URLResourceValues(); v.isExcludedFromBackup = true; var p = pack; try? p.setResourceValues(v)
        }
        if !fm.fileExists(atPath: json.path) {
            let body = try await get(VoicePacks.baseURL.appendingPathComponent("\(voice)/\(e.json)"))
            guard (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["clips"] != nil else { throw URLError(.cannotParseResponse) }
            try body.write(to: json, options: .atomic)
        }
        return try readPack(voice: voice, packId: packId, pack: pack, json: json)
    }

    private func readPack(voice: String, packId: String, pack: URL, json: URL) throws -> Pack {
        guard let root = try JSONSerialization.jsonObject(with: Data(contentsOf: json)) as? [String: Any],
              let clips = root["clips"] as? [String: [NSNumber]] else { throw URLError(.cannotParseResponse) }
        var m: [String: Clip] = [:]
        for (k, a) in clips where a.count >= 3 { m[k] = Clip(offset: a[0].intValue, length: a[1].intValue, ms: a[2].intValue) }
        return Pack(voice: voice, id: packId, file: pack, clips: m)
    }

    /// "Psalms", 23 → "bkjv_psalms_23". Matches the server's Bible pack names.
    static func biblePackId(book: String, ch: Int) -> String {
        let slug = book.lowercased().replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return "bkjv_\(slug)_\(ch)"
    }

    /// The KJV chapters the narrators recorded (Android's BibleAudio.RECORDED).
    static let recordedChapters: Set<String> = Set([
        ("Psalms", 23), ("John", 3), ("Psalms", 91), ("Jeremiah", 29), ("Philippians", 4), ("Romans", 8), ("Psalms", 1),
        ("Psalms", 121), ("1 Corinthians", 13), ("Isaiah", 40), ("Proverbs", 3), ("Psalms", 46), ("Matthew", 6),
        ("John", 14), ("Psalms", 139), ("Isaiah", 53), ("Psalms", 27), ("John", 15), ("Romans", 12), ("Psalms", 51),
        ("Psalms", 103), ("Hebrews", 11), ("Luke", 15),
    ].map { "\($0.0)|\($0.1)" })

    /// Any KJV chapter may have a recording: the server's index decides (`ensure` returns nil when it doesn't), so
    /// chapters recorded later play in Grace's voice without an app update.
    static func mayBeRecorded(translation: String) -> Bool { translation == "KJV" }

    static func isRecorded(translation: String, book: String, ch: Int) -> Bool {
        translation == "KJV" && recordedChapters.contains("\(book)|\(ch)")
    }
}

/// Plays one MP3 clip to its end (an AVAudioPlayer per line, like Android's MediaPlayer per clip).

@MainActor
final class ClipPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var done: CheckedContinuation<Bool, Never>?

    var isPlaying: Bool { player?.isPlaying ?? false }

    /// Plays the clip; returns false if it couldn't play. Returns when it ends or is stopped.
    func play(_ data: Data, rate: Float = 1.0) async -> Bool {
        stop()
        guard let p = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue) else { return false }
        p.delegate = self
        p.enableRate = rate != 1.0
        p.rate = rate
        player = p
        return await withCheckedContinuation { cont in
            done = cont
            if !p.play() { finish(false) }
        }
    }

    func pause() { player?.pause() }
    func resume() { player?.play() }

    func stop() {
        player?.stop()
        player = nil
        finish(false)
    }

    private func finish(_ ok: Bool) {
        let c = done
        done = nil
        c?.resume(returning: ok)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.player else { return }
            self.player = nil
            self.finish(flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard player === self.player else { return }
            self.player = nil
            self.finish(false)
        }
    }
}
