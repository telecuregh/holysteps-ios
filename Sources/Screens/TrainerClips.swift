import SwiftUI
import AVFoundation
import AVKit
import CryptoKit

// Coach Kojo and Coach Amara on every exercise step, ported from Android: data/TrainerMedia.kt,
// ui/screens/TrainerMediaViews.kt, data/Programs.kt (photo, PHOTO_BASE) and ui/art/Moves.kt (motionForStep, PHOTO_KEYS,
// UNRECORDED_MOVES, recordedVideoKey).

/// Adds the account's sign-in to requests for holysteps.org, which serves trainer media only to signed-in accounts
/// (Android addHolyStepsSignIn). Without a token (offline, not signed in yet) the request goes without it.
enum HolyStepsSignIn {
    static func authorize(_ req: inout URLRequest) async {
        guard let host = req.url?.host?.lowercased(), host == "holysteps.org" || host.hasSuffix(".holysteps.org") else { return }
        let token: String? = await withTaskGroup(of: String?.self) { g in
            g.addTask { await AccountStore.shared.token() }
            g.addTask { try? await Task.sleep(nanoseconds: 10_000_000_000); return nil }
            let first = await g.next() ?? nil
            g.cancelAll()
            return first
        }
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    }
}

enum TrainerClips {
    static let base = "https://holysteps.org/holysteps/trainers"

    /// Keyword rules, first match wins (order matters: "squat jump" before "squat", "side plank" before "plank").
    /// When a rule's second list isn't empty, the name must also contain one of those words.
    private static let rules: [([String], [String], String)] = [
        (["squat jump"], [], "SQUAT_JUMP"),
        (["mountain climber"], [], "MOUNTAIN_CLIMBER"),
        (["skater"], [], "SKATER"),
        (["incline push", "counter push"], [], "INCLINE_PUSH_UP"),
        (["push-up", "push up"], [], "PUSH_UP"),
        (["shoulder tap"], [], "SHOULDER_TAPS"),
        (["side plank"], [], "SIDE_PLANK_LEFT"),
        (["plank"], [], "PLANK"),
        (["reverse lunge"], [], "LUNGE_LEFT"),
        (["low lunge"], [], "LOW_LUNGE"),
        (["world's greatest", "worlds greatest"], [], "WORLDS_GREATEST"),
        (["bridge with march", "bridge march"], [], "GLUTE_BRIDGE"),
        (["bridge"], [], "GLUTE_BRIDGE"),
        (["row"], [], "ROW"),
        (["farmer"], [], "FARMER_CARRY"),
        (["sit-to-stand", "squat to chair"], [], "SIT_TO_STAND"),
        (["supported squat"], [], "SUPPORTED_SQUAT"),
        (["squat"], [], "SQUAT"),
        (["step-up", "step up"], [], "STEP_UP"),
        (["calf"], [], "CALF_RAISE"),
        (["bird dog"], [], "BIRD_DOG"),
        (["dead bug"], [], "DEAD_BUG"),
        (["hundred"], [], "HUNDRED"),
        (["single-leg stretch"], [], "SINGLE_LEG_STRETCH"),
        (["side-lying"], [], "SIDE_LYING_LEG_LIFT"),
        (["swimming"], [], "SWIMMING"),
        (["cat-cow", "cat cow"], [], "CAT_COW"),
        (["child"], [], "CHILDS_POSE"),
        (["puppy"], [], "PUPPY_POSE"),
        (["forward fold"], ["seated"], "SEATED_FOLD"),
        (["forward fold"], [], "FORWARD_FOLD"),
        (["open book"], [], "SUPINE_TWIST"),
        (["twist"], ["supine", "lying", "reclined", "on your back", "floor"], "SUPINE_TWIST"),
        (["twist"], [], "TORSO_TWIST"),
        (["butterfly"], [], "RECLINED_BUTTERFLY"),
        (["legs up"], [], "LEGS_UP_WALL"),
        (["knees-to-chest", "knees to chest"], [], "KNEES_TO_CHEST"),
        (["figure-4", "figure 4"], [], "FIGURE_FOUR"),
        (["breath", "breathing", "rest"], [], "BELLY_BREATH"),
        (["quad stretch"], [], "QUAD_STRETCH"),
        (["chest opener"], [], "CHEST_OPENER"),
        (["hamstring"], [], "HAMSTRING_SWEEP"),
        (["ankle"], [], "ANKLE_CIRCLES"),
        (["single-leg stand"], [], "SINGLE_LEG_STAND"),
        (["heel-to-toe"], [], "HEEL_TO_TOE"),
        (["tandem"], [], "TANDEM_STANCE"),
        (["side leg raise"], [], "SIDE_LEG_RAISE"),
        (["clock reach"], [], "CLOCK_REACH"),
        (["arm circle"], [], "ARM_CIRCLES"),
        (["hip circle"], [], "HIP_CIRCLES"),
        (["neck"], [], "NECK_ROLLS"),
        (["shoulder roll"], [], "SHOULDER_ROLLS"),
        (["march"], [], "MARCH"),
        (["fast effort", "run"], [], "RUN"),
        (["brisk effort", "walk", "easy pace"], [], "WALK"),
        (["stretch"], [], "QUAD_STRETCH"),
    ]
    /// Moves with no clip on the server (Android's UNRECORDED_MOVES); no workout uses them.
    private static let unrecorded: Set<String> = ["ANKLE_CIRCLES", "CAT_COW", "CHEST_OPENER", "CLOCK_REACH", "FIGURE_FOUR", "HAMSTRING_SWEEP", "HEEL_TO_TOE", "KNEES_TO_CHEST", "LEGS_UP_WALL", "PUPPY_POSE", "QUAD_STRETCH", "RECLINED_BUTTERFLY", "SEATED_FOLD", "SHOULDER_ROLLS", "SIDE_LEG_RAISE", "SINGLE_LEG_STAND", "SUPINE_TWIST", "TANDEM_STANCE"]

    /// The trainer key for a step (rests use BELLY_BREATH), or nil when that move has no recording.
    static func key(step name: String, rest: Bool) -> String? {
        if rest { return "BELLY_BREATH" }
        let n = name.lowercased()
        let k = rules.first { r in r.0.contains { n.contains($0) } && (r.1.isEmpty || r.1.contains { n.contains($0) }) }?.2 ?? "MARCH"
        return k == "NONE" || unrecorded.contains(k) ? nil : k
    }
    static func isUnrecorded(_ key: String) -> Bool { unrecorded.contains(key) }

    /// Coach Kojo for men, Coach Amara for everyone else (Android Programs.photo).
    static var isMale: Bool { UserDefaults.standard.string(forKey: "gender") == "male" }
    static var trainerName: String { isMale ? "Kojo" : "Amara" }
    static func photo(_ key: String, male: Bool = isMale) -> URL? { URL(string: "\(base)/\(male ? "man_3d" : "woman_3d")/\(key).jpg") }
    static func loop(forPhoto url: URL) -> URL { url.deletingPathExtension().appendingPathExtension("mp4") }
}

// MARK: - Safe URLs (Android safeMediaUrl)

enum SafeMedia {
    static let photoExt: Set<String> = ["jpg", "jpeg", "png", "webp"]
    static let videoExt: Set<String> = ["mp4", "webm", "m3u8"]

    static func url(_ raw: String?, allowed: Set<String>) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw.count <= 500,
              let c = URLComponents(string: raw), c.scheme?.lowercased() == "https",
              c.user == nil, c.password == nil, c.port == nil,
              let host = c.host?.lowercased(), host.contains("."),
              !host.hasSuffix(".local"), !host.hasSuffix(".internal"), !host.hasSuffix(".localhost"), host != "localhost",
              !isIP(host), let u = c.url else { return nil }
        guard allowed.contains(u.pathExtension.lowercased()) else { return nil }
        return u
    }
    private static func isIP(_ h: String) -> Bool {
        if h.hasPrefix("[") || h.contains(":") { return true }
        let parts = h.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { Int($0) != nil }
    }
}

// MARK: - Catalog (Android TrainerMedia): demo videos per workout or walk plan id

struct TrainerClip: Equatable {
    let routineId, trainer, title, credit: String
    let photo, video: URL?
}

@MainActor
final class TrainerMedia: ObservableObject {
    static let shared = TrainerMedia()
    static let endpoint = URL(string: "https://holysteps.org/holysteps/api/trainer-media")!
    @Published private(set) var clips: [String: TrainerClip] = [:]
    private var lastFetch = Date.distantPast
    private var fetching = false

    private var file: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("trainer-media.json")
    }

    private init() {
        if let d = try? Data(contentsOf: file) { clips = Self.parse(d) }
        if let a = try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date { lastFetch = a }
    }

    func clip(_ id: String) -> TrainerClip? { clips[id] }

    /// Refreshes at most every 6 hours (or now with `force`); silent when offline.
    func refresh(force: Bool = false) async {
        guard !fetching, force || Date().timeIntervalSince(lastFetch) > 6 * 3600 else { return }
        fetching = true; defer { fetching = false }
        var req = URLRequest(url: Self.endpoint, timeoutInterval: 10)
        req.setValue("HolySteps-iOS", forHTTPHeaderField: "User-Agent")
        await HolyStepsSignIn.authorize(&req)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8; cfg.timeoutIntervalForResource = 10
        let session = URLSession(configuration: cfg, delegate: NoRedirects(), delegateQueue: nil)
        guard let (data, resp) = try? await session.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              data.count <= 512 * 1024 else { return }
        let parsed = Self.parse(data)
        try? data.write(to: file, options: .atomic)
        lastFetch = Date()
        clips = parsed
    }

    nonisolated static func parse(_ data: Data) -> [String: TrainerClip] {
        guard data.count <= 512 * 1024, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = o["items"] as? [[String: Any]] else { return [:] }
        let idOK = try! NSRegularExpression(pattern: "^[a-z0-9_]{1,40}$")
        func clean(_ v: Any?, _ max: Int) -> String {
            let s = (v as? String ?? "").unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
            return String(s).trimmingCharacters(in: .whitespaces).prefix(max).description
        }
        var out: [String: TrainerClip] = [:]
        for it in items.prefix(200) {
            let id = clean(it["routineId"], 40)
            guard idOK.firstMatch(in: id, range: NSRange(location: 0, length: (id as NSString).length)) != nil else { continue }
            let photo = SafeMedia.url(it["photo"] as? String, allowed: SafeMedia.photoExt)
            let video = SafeMedia.url(it["video"] as? String, allowed: SafeMedia.videoExt)
            guard photo != nil || video != nil else { continue }
            out[id] = TrainerClip(routineId: id, trainer: clean(it["trainer"], 80), title: clean(it["title"], 80),
                                  credit: clean(it["credit"], 160), photo: photo, video: video)
        }
        return out
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ s: URLSession, task: URLSessionTask, willPerformHTTPRedirection r: HTTPURLResponse, newRequest: URLRequest) async -> URLRequest? { nil }
}

// MARK: - Trainer photos (disk cache, signed-in download)

actor TrainerPhotos {
    static let shared = TrainerPhotos()
    private let memory = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private var dir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("trainer-img", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private func local(_ url: URL) -> URL { dir.appendingPathComponent(TrainerLoops.name(url, ext: "img")) }

    func cached(_ url: URL) -> UIImage? {
        if let m = memory.object(forKey: url as NSURL) { return m }
        guard let d = try? Data(contentsOf: local(url)), let img = UIImage(data: d) else { return nil }
        memory.setObject(img, forKey: url as NSURL)
        return img
    }

    func image(_ url: URL) async -> UIImage? {
        if let c = cached(url) { return c }
        if let t = inFlight[url] { return await t.value }
        let dest = local(url)
        let t = Task<UIImage?, Never> {
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.setValue("HolySteps-iOS", forHTTPHeaderField: "User-Agent")
            await HolyStepsSignIn.authorize(&req)
            guard let (d, r) = try? await URLSession.shared.data(for: req), (r as? HTTPURLResponse)?.statusCode == 200,
                  d.count < 8 * 1024 * 1024, let img = UIImage(data: d) else { return nil }
            try? d.write(to: dest, options: .atomic)
            return img
        }
        inFlight[url] = t
        let img = await t.value
        inFlight[url] = nil
        if let img { memory.setObject(img, forKey: url as NSURL) }
        return img
    }
}

// MARK: - Looping clips (Android TrainerLoops)

actor TrainerLoops {
    static let shared = TrainerLoops()
    static let maxBytes = 12 * 1024 * 1024
    static let budget: Int64 = 150 * 1024 * 1024
    private var inFlight: [URL: Task<URL?, Never>] = [:]
    private var failedAt: [URL: Date] = [:]

    nonisolated static func name(_ url: URL, ext: String) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined().prefix(40) + "." + ext
    }
    private var dir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("trainer-loop", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// The cached clip, if it's on the phone (and marks it as recently used).
    func cached(_ url: URL) -> URL? {
        let f = dir.appendingPathComponent(Self.name(url, ext: "mp4"))
        guard let size = (try? FileManager.default.attributesOfItem(atPath: f.path)[.size] as? NSNumber)?.intValue, size > 0 else { return nil }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: f.path)
        return f
    }

    /// The clip on the phone, downloading it if needed. nil when the server has none or it can't be had right now.
    func load(_ raw: URL) async -> URL? {
        guard let url = SafeMedia.url(raw.absoluteString, allowed: ["mp4"]) else { return nil }
        if let c = cached(url) { return c }
        if let t = inFlight[url] { return await t.value }
        if let f = failedAt[url], Date().timeIntervalSince(f) < 120 { return nil }
        let dest = dir.appendingPathComponent(Self.name(url, ext: "mp4"))
        let t = Task<URL?, Never> { await Self.download(url, to: dest) }
        inFlight[url] = t
        let out = await t.value
        inFlight[url] = nil
        if out == nil { failedAt[url] = Date() } else { failedAt[url] = nil; trim() }
        return out
    }

    private static func download(_ url: URL, to dest: URL) async -> URL? {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue("HolySteps-iOS", forHTTPHeaderField: "User-Agent")
        await HolyStepsSignIn.authorize(&req)
        guard let (tmp, resp) = try? await URLSession.shared.download(for: req), let http = resp as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        defer { try? FileManager.default.removeItem(at: tmp) }
        let size = (try? FileManager.default.attributesOfItem(atPath: tmp.path)[.size] as? NSNumber)?.intValue ?? 0
        let expected = http.expectedContentLength
        guard size > 10_000, size <= maxBytes, expected <= 0 || Int64(size) == expected else { return nil }
        guard let h = try? FileHandle(forReadingFrom: tmp) else { return nil }
        let head = (try? h.read(upToCount: 12)) ?? Data()
        try? h.close()
        guard head.count >= 8, String(data: head.subdata(in: 4..<8), encoding: .ascii) == "ftyp" else { return nil }
        let part = dest.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: part)
        do {
            try FileManager.default.copyItem(at: tmp, to: part)
            if FileManager.default.fileExists(atPath: dest.path) { _ = try FileManager.default.replaceItemAt(dest, withItemAt: part) }
            else { try FileManager.default.moveItem(at: part, to: dest) }
        } catch { try? FileManager.default.removeItem(at: part); return nil }
        return dest
    }

    /// A cached clip that wouldn't play is removed so it downloads again.
    func discard(_ url: URL) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(Self.name(url, ext: "mp4")))
    }

    /// Keeps the folder under 150 MB, removing the least recently used clips first.
    private func trim() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard var files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys).filter({ $0.pathExtension == "mp4" }) else { return }
        func info(_ u: URL) -> (Date, Int64) {
            let v = try? u.resourceValues(forKeys: Set(keys))
            return (v?.contentModificationDate ?? .distantPast, Int64(v?.fileSize ?? 0))
        }
        var total = files.reduce(Int64(0)) { $0 + info($1).1 }
        files.sort { info($0).0 < info($1).0 }
        for f in files where total > Self.budget {
            total -= info(f).1
            try? fm.removeItem(at: f)
        }
    }

    /// Downloads a workout's clips ahead of time (Android prefetchTrainerLoops); rests use BELLY_BREATH.
    func prefetch(_ steps: [RoutineStep]) async {
        var seen = Set<URL>()
        for s in steps {
            guard let k = TrainerClips.key(step: s.name, rest: s.rest), let p = TrainerClips.photo(k) else { continue }
            let u = TrainerClips.loop(forPhoto: p)
            guard seen.insert(u).inserted else { continue }
            _ = await TrainerPhotos.shared.image(p)
            _ = await load(u)
        }
    }
}

// MARK: - TrainerMotion: the trainer doing the move

/// Cached clip → plays at once. Otherwise the photo shows while the clip downloads, then the clip takes over (the photo
/// stays underneath until the first frame draws). No clip on the server → the photo. No photo, no network, nothing
/// cached → a plain card. Silent, looping, paused with the workout, on rest steps and when the app is in the background.
struct TrainerMotion: View {
    let moveKey: String
    let moveName: String
    let animate: Bool
    @Environment(\.scenePhase) private var scene
    @State private var photo: UIImage?
    @State private var clip: URL?
    @State private var photoTried = false
    @State private var firstFrame = false

    var body: some View {
        ZStack {
            Color(hex: 0xECEBEE)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .accessibilityLabel(tr("Trainer") + " " + TrainerClips.trainerName)
            } else if photoTried && clip == nil {
                VStack(spacing: 6) {
                    D(tr(moveName)).font(.hs(16, .semibold)).foregroundStyle(Color(hex: 0x2A2230))
                    T("Your trainer's video shows when you're back online.").font(.hs(12)).foregroundStyle(Color(hex: 0x5A5260))
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            if let clip {
                LoopingVideo(url: clip, playing: animate && scene == .active, firstFrame: $firstFrame)
                    .opacity(firstFrame ? 1 : 0)
                    .accessibilityLabel(tr("Trainer") + " " + TrainerClips.trainerName)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task(id: moveKey) { await load() }
    }

    private func load() async {
        photo = nil; clip = nil; photoTried = false; firstFrame = false
        guard let p = TrainerClips.photo(moveKey) else { photoTried = true; return }
        let loopURL = TrainerClips.loop(forPhoto: p)
        photo = await TrainerPhotos.shared.cached(p)
        if let c = await TrainerLoops.shared.cached(loopURL) { clip = c; return }
        async let img = TrainerPhotos.shared.image(p)
        async let file = TrainerLoops.shared.load(loopURL)
        if photo == nil { photo = await img }
        photoTried = true
        if let f = await file { clip = f }
    }
}

/// One AVQueuePlayer per move (a reused player left the last move's final frame frozen on Android).
private struct LoopingVideo: UIViewRepresentable {
    let url: URL
    let playing: Bool
    @Binding var firstFrame: Bool

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var looper: AVPlayerLooper?
        var ready: NSKeyValueObservation?
        var failed: NSKeyValueObservation?
        var current: URL?
    }

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.videoGravity = .resizeAspectFill
        v.backgroundColor = .clear
        load(url, into: v)
        return v
    }

    func updateUIView(_ v: PlayerView, context: Context) {
        if v.current != url { load(url, into: v) }
        let p = v.playerLayer.player
        if playing { p?.play() } else { p?.pause() }
    }

    static func dismantleUIView(_ v: PlayerView, coordinator: ()) {
        v.playerLayer.player?.pause()
        v.ready = nil; v.failed = nil; v.looper = nil
        v.playerLayer.player = nil
    }

    private func load(_ url: URL, into v: PlayerView) {
        let q = AVQueuePlayer()
        q.isMuted = true                         // the coach's voice and the user's music keep playing
        q.preventsDisplaySleepDuringVideoPlayback = false
        let item = AVPlayerItem(url: url)
        v.looper = AVPlayerLooper(player: q, templateItem: item)
        v.playerLayer.player = q
        v.current = url
        let binding = $firstFrame
        v.ready = v.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { layer, _ in
            if layer.isReadyForDisplay { DispatchQueue.main.async { binding.wrappedValue = true } }
        }
        v.failed = q.observe(\.currentItem?.status, options: [.new]) { player, _ in
            if player.currentItem?.status == .failed {
                // A damaged cached clip: remove it so it downloads again; the photo stays on screen.
                Task { await TrainerLoops.shared.discardFile(url) }
            }
        }
        if playing { q.play() }
    }
}

extension TrainerLoops {
    /// Removes a cached file that failed to play (by its local path).
    func discardFile(_ local: URL) { try? FileManager.default.removeItem(at: local) }
}

// MARK: - TrainerCard (walk plans and the workout's opening screen)

struct TrainerCard: View {
    let clip: TrainerClip
    @State private var photo: UIImage?
    @State private var playing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { if clip.video != nil { playing = true } } label: {
                ZStack {
                    Color(hex: 0x1F1147)
                    if let photo { Image(uiImage: photo).resizable().scaledToFill() }
                    if clip.video != nil {
                        Circle().fill(.black.opacity(0.45)).frame(width: 56, height: 56)
                            .overlay(Image(systemName: "play.fill").font(.system(size: 22)).foregroundStyle(.white))
                            .accessibilityLabel(tr("Watch the trainer"))
                    }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(clip.video == nil)
            .accessibilityLabel(tr("Trainer") + " " + (clip.trainer.isEmpty ? TrainerClips.trainerName : clip.trainer))
            let who = clip.trainer.isEmpty ? tr("Your trainer") : clip.trainer
            D(clip.video != nil ? tr("Watch \(who) demonstrate this") : tr("With \(who)")).font(.hs(13, .semibold)).foregroundStyle(HS.text)
            if !clip.credit.isEmpty { D(clip.credit).font(.hs(11)).foregroundStyle(HS.textMuted) }
        }
        .task(id: clip.photo) { if let p = clip.photo { photo = await TrainerPhotos.shared.image(p) } }
        .fullScreenCover(isPresented: $playing) { if let v = clip.video { TrainerVideoPlayer(url: v) } }
    }
}

struct TrainerVideoPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var player: AVPlayer?
    @State private var failed = false
    @State private var watch: NSKeyValueObservation?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if failed {
                VStack(spacing: 10) {
                    T("This video could not be played here.").font(.hs(16, .semibold)).foregroundStyle(.white)
                    T("Check your connection, or open it in your browser.").font(.hs(13)).foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 12) {
                        Button(tr("Try again")) { start() }.buttonStyle(.borderedProminent)
                        Button(tr("Open in browser")) { openURL(url) }.buttonStyle(.bordered)
                    }
                }
                .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let player {
                VideoPlayer(player: player).ignoresSafeArea()
            }
            Button { player?.pause(); dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.5)))
            }
            .accessibilityLabel(tr("Close")).padding(12)
        }
        .onAppear { start() }
        .onDisappear { player?.pause() }
    }

    private func start() {
        failed = false
        Task {
            var req = URLRequest(url: url)
            await HolyStepsSignIn.authorize(&req)
            let headers = req.allHTTPHeaderFields ?? [:]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let item = AVPlayerItem(asset: asset)
            let p = AVPlayer(playerItem: item)
            watch = item.observe(\.status, options: [.new]) { it, _ in
                if it.status == .failed { DispatchQueue.main.async { failed = true } }
            }
            player = p
            p.play()
        }
    }
}
