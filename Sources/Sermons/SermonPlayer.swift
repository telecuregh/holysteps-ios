import Foundation
import AVFoundation
import MediaPlayer

/// Plays a sermon paragraph by paragraph: the preacher's recording (holysteps.org/voice) where the line was
/// recorded, otherwise the iPhone's own voice, with the words shown as captions. Works with the screen off and
/// shows on the Lock Screen. Sermons Joel recorded play his whole recording, with the script as captions.
@MainActor
final class SermonPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SermonPlayer()

    @Published private(set) var sermon: Sermon?
    /// What's said, paragraph by paragraph, in the app's language ("" for a pause).
    @Published private(set) var captions: [String] = []
    @Published private(set) var index = 0
    @Published private(set) var playing = false
    @Published private(set) var loading = false
    @Published private(set) var finished = false
    /// "Preacher" when the recording is playing this line, "Your phone's voice" otherwise.
    @Published private(set) var reader = ""

    var active: Bool { sermon != nil }
    var progress: Double { captions.isEmpty ? 0 : Double(index) / Double(captions.count) }

    private var segments: [Sermon.Segment] = []
    private var task: Task<Void, Never>?
    private let clip = ClipPlayer()
    private let synth = AVSpeechSynthesizer()
    private var speaking: CheckedContinuation<Void, Never>?
    private var pack: VoicePacks.Pack?
    private var paused = false
    /// Joel's full recording, when the sermon has one (bundled, or on holysteps.org for signed-in accounts).
    private var recording: AVPlayer?

    override private init() {
        super.init()
        synth.delegate = self
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        rc.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        rc.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(1) }; return .success }
        rc.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(-1) }; return .success }
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let began = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in if began { self?.pause() } }
        }
    }

    // MARK: Control

    func play(_ s: Sermon, from start: Int = 0) {
        MusicPlayer.shared.stop()
        BibleListening.shared.stop()
        stopPlayback()
        sermon = s
        // Listening counts the moment it starts (a sleep story is meant to be fallen asleep to).
        ActivityLog.shared.add(s.group == .sleep ? (s.kind == "night" ? .prayerAudio : .sleepStory) : s.group == .mind ? .sleepStory : .sermon)
        segments = s.segments
        captions = segments.map { if case .speech(let t) = $0 { return tr(t) } else { return "" } }
        index = max(0, min(start, max(0, segments.count - 1)))
        finished = false
        paused = false
        pack = nil
        loading = true
        activateSession()
        task = Task { await run(s) }
        LiveActivities.start(.sermon, title: tr(s.group == .sleep ? "Sleep" : s.group == .mind ? "Story" : "Sermon"), liveState(s))
    }

    /// The Lock Screen card: the sermon's title and how far along it is.
    private func liveState(_ s: Sermon) -> HolyStepsActivityAttributes.ContentState {
        .init(headline: tr(s.title), detail: paused ? tr("Paused") : tr("Listening"), endsAt: nil, since: nil,
              progress: Double(index) / Double(max(1, segments.count)), paused: paused)
    }

    func toggle() { playing ? pause() : resume() }

    func pause() {
        guard active, playing else { return }
        paused = true
        playing = false
        clip.pause()
        recording?.pause()
        if synth.isSpeaking { synth.pauseSpeaking(at: .word) }
        updateNowPlaying()
        if let s = sermon { LiveActivities.update(liveState(s)) }
    }

    func resume() {
        guard let s = sermon else { return }
        if finished { play(s); return }
        activateSession()
        paused = false
        playing = true
        clip.resume()
        recording?.play()
        if synth.isPaused { synth.continueSpeaking() }
        updateNowPlaying()
        if let s = sermon { LiveActivities.update(liveState(s)) }
    }

    /// Moves a paragraph forward or back.
    func skip(_ by: Int) { jump(to: index + by) }

    func jump(to i: Int) {
        guard let s = sermon else { return }
        let target = max(0, min(i, segments.count - 1))
        let wasPaused = paused
        stopPlayback()
        index = target
        finished = false
        paused = wasPaused
        task = Task { await run(s, keepPack: true) }
    }

    func stop() {
        stopPlayback()
        if sermon != nil { LiveActivities.end() }
        sermon = nil
        captions = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopPlayback() {
        task?.cancel()
        task = nil
        clip.stop()
        recording?.pause()
        recording = nil
        synth.stopSpeaking(at: .immediate)
        finishSpeaking()
        playing = false
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: The loop

    /// One of the sermon's recorded takes, a different one each time it's played (Android's recordedTakes).
    private func take(_ s: Sermon) -> URL? {
        guard !s.recorded.isEmpty, !I18n.shared.spanish else { return nil }
        let k = "sermonTake.\(s.id)"
        let n = UserDefaults.standard.integer(forKey: k)
        let raw = s.recorded[n % s.recorded.count]
        if raw.hasPrefix("bundle:") {
            let name = String(raw.dropFirst(7))
            let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
            return Bundle.main.url(forResource: base, withExtension: ext) ?? Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "sermon_audio")
        }
        guard let u = URL(string: raw), u.scheme == "https", u.host == "holysteps.org" else { return nil }
        return u
    }

    /// How far through the captions a point in the recording is, by the length of each paragraph.
    private func captionIndex(at fraction: Double) -> Int {
        let w = segments.map { seg -> Double in
            switch seg { case .speech(let t): Double(t.split(whereSeparator: \.isWhitespace).count); case .pause(let n): Double(n) * 2.25 }
        }
        let total = max(1, w.reduce(0, +))
        var acc = 0.0
        for (i, x) in w.enumerated() { acc += x; if acc / total >= fraction { return i } }
        return max(0, w.count - 1)
    }
    private func fraction(at index: Int) -> Double {
        let w = segments.map { seg -> Double in
            switch seg { case .speech(let t): Double(t.split(whereSeparator: \.isWhitespace).count); case .pause(let n): Double(n) * 2.25 }
        }
        let total = max(1, w.reduce(0, +))
        return w.prefix(index).reduce(0, +) / total
    }

    /// Plays Joel's recording from the current paragraph. False when it can't be had (offline, not signed in).
    private func runRecording(_ s: Sermon, _ url: URL) async -> Bool {
        var options: [String: Any] = [:]
        if !url.isFileURL {
            var req = URLRequest(url: url)
            await HolyStepsSignIn.authorize(&req)
            if let h = req.allHTTPHeaderFields { options["AVURLAssetHTTPHeaderFieldsKey"] = h }
        }
        let asset = AVURLAsset(url: url, options: options)
        guard let duration = try? await asset.load(.duration), duration.seconds > 1, !Task.isCancelled else { return false }
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        recording = player
        let start = fraction(at: index) * duration.seconds
        if start > 1 { await player.seek(to: CMTime(seconds: start, preferredTimescale: 600)) }
        loading = false
        reader = "Joel"
        playing = !paused
        if !paused { player.play() }
        updateNowPlaying()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled || recording !== player { return true }
            if item.status == .failed { recording = nil; return false }
            let t = player.currentTime().seconds
            let i = captionIndex(at: t / duration.seconds)
            if i != index { index = i; updateNowPlaying() }
            if t >= duration.seconds - 0.4 { break }
        }
        if Task.isCancelled { return true }
        recording = nil
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "sermonTake.\(s.id)") + 1, forKey: "sermonTake.\(s.id)")
        index = max(0, segments.count - 1)
        finished = true
        LiveActivities.end()
        playing = false
        if s.group != .sleep && s.group != .mind { SermonWeek.shared.markHeard(s.id) }
        updateNowPlaying()
        return true
    }

    private func run(_ s: Sermon, keepPack: Bool = false) async {
        if let url = take(s), await runRecording(s, url) { return }
        if Task.isCancelled { return }
        if !(keepPack && pack != nil) && !I18n.shared.spanish {
            // The preacher's recordings are in English; in Spanish the phone reads the translated words.
            pack = await VoicePacks.shared.ensure(voice: s.voice ?? VoicePacks.preacher, packId: s.packId)
        }
        if Task.isCancelled { return }
        loading = false
        playing = !paused
        updateNowPlaying()
        while index < segments.count {
            while paused && !Task.isCancelled { try? await Task.sleep(nanoseconds: 200_000_000) }
            if Task.isCancelled { return }
            switch segments[index] {
            case .speech(let text):
                if !I18n.shared.spanish, let data = pack?.audio(for: text) {
                    reader = s.voice == nil ? tr("Preacher") : "Grace"
                    _ = await clip.play(data)
                } else {
                    reader = tr("Your phone's voice")
                    await speak(captions[index])
                }
            case .pause(let n):
                var left = Double(n)
                while left > 0 && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    if !paused { left -= 0.25 }
                }
            }
            if Task.isCancelled { return }
            while paused && !Task.isCancelled { try? await Task.sleep(nanoseconds: 200_000_000) }
            if Task.isCancelled { return }
            if index + 1 >= segments.count { break }
            index += 1
            updateNowPlaying()
        }
        finished = true
        LiveActivities.end()
        playing = false
        if s.group != .sleep && s.group != .mind { SermonWeek.shared.markHeard(s.id) }
        updateNowPlaying()
    }

    private func speak(_ text: String) async {
        // A line with no recording is never read by the phone's voice: the caption stays up for a calm reading pace.
        let words = Double(text.split(separator: " ").count)
        try? await Task.sleep(nanoseconds: UInt64(min(14, words / 2.6 + 0.8) * 1_000_000_000))
    }

    private func finishSpeaking() {
        let c = speaking
        speaking = nil
        c?.resume()
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.finishSpeaking() }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.finishSpeaking() }
    }

    private func updateNowPlaying() {
        guard let s = sermon else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: tr(s.title),
            MPMediaItemPropertyArtist: "HolySteps · " + tr("Sermon"),
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
    }
}
