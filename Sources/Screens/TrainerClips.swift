import SwiftUI
import AVFoundation

/// Coach Amara and Coach Kojo doing each move (ported from Android's Moves.kt motionForStep / PHOTO_KEYS /
/// recordedVideoKey and TrainerMediaViews.kt). A workout step's name is matched to a trainer clip by keyword; the
/// clips are short silent loops on holysteps.org, downloaded once and kept on the phone. Both trainers appear in every
/// workout, taking turns step by step, whatever the user's gender.
enum TrainerClips {
    static let base = URL(string: "https://holysteps.org/holysteps/trainers")!
    enum Trainer: String { case amara = "woman_3d", kojo = "man_3d" }

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

    /// The clip for a step, or nil when that move has no recording.
    static func key(step name: String, rest: Bool) -> String? {
        if rest { return "BELLY_BREATH" }
        let n = name.lowercased()
        let k = rules.first { r in r.0.contains { n.contains($0) } && (r.1.isEmpty || r.1.contains { n.contains($0) }) }?.2 ?? "MARCH"
        return k == "NONE" || unrecorded.contains(k) ? nil : k
    }

    /// Amara on even steps, Kojo on odd ones.
    static func trainer(forStep index: Int) -> Trainer { index % 2 == 0 ? .amara : .kojo }

    static func remote(_ key: String, _ t: Trainer) -> URL { base.appendingPathComponent("\(t.rawValue)/\(key).mp4") }
}

/// Downloads trainer clips once and keeps them in Caches (the system may clear them; they're fetched again).
actor TrainerClipStore {
    static let shared = TrainerClipStore()
    private var inFlight: [String: Task<URL?, Never>] = [:]

    private func dir() -> URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("trainer-loop", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// A local file for the clip, downloading it if needed; nil when it can't be had (no network, missing clip).
    func file(_ key: String, _ t: TrainerClips.Trainer) async -> URL? {
        let local = dir().appendingPathComponent("\(t.rawValue)_\(key).mp4")
        if let size = (try? FileManager.default.attributesOfItem(atPath: local.path)[.size] as? NSNumber)?.intValue, size > 0 { return local }
        let id = local.lastPathComponent
        if let running = inFlight[id] { return await running.value }
        let task = Task<URL?, Never> {
            var req = URLRequest(url: TrainerClips.remote(key, t), timeoutInterval: 30)
            req.setValue("HolySteps-iOS", forHTTPHeaderField: "User-Agent")
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200, data.count > 1000 else { return nil }
            do { try data.write(to: local, options: .atomic) } catch { return nil }
            return local
        }
        inFlight[id] = task
        let url = await task.value
        inFlight[id] = nil
        return url
    }

    /// Fetches a workout's clips ahead of time so each step starts without waiting.
    func prefetch(_ routine: GuidedRoutine) async {
        for (i, s) in routine.steps.enumerated() {
            guard let k = TrainerClips.key(step: s.name, rest: s.rest) else { continue }
            _ = await file(k, TrainerClips.trainer(forStep: i))
        }
    }
}

/// The trainer doing a move, looping silently. Shows nothing while the clip loads or if it can't be had.
struct TrainerLoop: View {
    let key: String
    let trainer: TrainerClips.Trainer
    @State private var file: URL?

    var body: some View {
        ZStack {
            if let file { LoopingVideo(url: file).transition(.opacity) }
        }
        .task(id: "\(trainer.rawValue)/\(key)") {
            file = nil
            let f = await TrainerClipStore.shared.file(key, trainer)
            withAnimation(.easeIn(duration: 0.25)) { file = f }
        }
    }
}

private struct LoopingVideo: UIViewRepresentable {
    let url: URL

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var looper: AVPlayerLooper?
        var current: URL?
    }

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .clear
        load(url, into: v)
        return v
    }

    func updateUIView(_ v: PlayerView, context: Context) { if v.current != url { load(url, into: v) } }

    static func dismantleUIView(_ v: PlayerView, coordinator: ()) {
        (v.playerLayer.player as? AVQueuePlayer)?.pause()
        v.looper = nil
        v.playerLayer.player = nil
    }

    private func load(_ url: URL, into v: PlayerView) {
        let q = AVQueuePlayer()
        q.isMuted = true                     // the coach's voice and the user's music keep playing
        q.preventsDisplaySleepDuringVideoPlayback = false
        v.looper = AVPlayerLooper(player: q, templateItem: AVPlayerItem(url: url))
        v.playerLayer.player = q
        v.current = url
        q.play()
    }
}
