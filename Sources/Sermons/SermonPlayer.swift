import Foundation
import AVFoundation
import MediaPlayer

/// Plays a sermon paragraph by paragraph: the preacher's recording (holysteps.org/voice) where the line was
/// recorded, otherwise the iPhone's own voice, with the words shown as captions. Works with the screen off and
/// shows on the Lock Screen. (Joel's recordings need sign-in and come with accounts in phase 2.)
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
        BibleListening.shared.stop()
        stopPlayback()
        sermon = s
        segments = s.segments
        captions = segments.map { if case .speech(let t) = $0 { return tr(t) } else { return "" } }
        index = max(0, min(start, max(0, segments.count - 1)))
        finished = false
        paused = false
        pack = nil
        loading = true
        activateSession()
        task = Task { await run(s) }
    }

    func toggle() { playing ? pause() : resume() }

    func pause() {
        guard active, playing else { return }
        paused = true
        playing = false
        clip.pause()
        if synth.isSpeaking { synth.pauseSpeaking(at: .word) }
        updateNowPlaying()
    }

    func resume() {
        guard let s = sermon else { return }
        if finished { play(s); return }
        activateSession()
        paused = false
        playing = true
        clip.resume()
        if synth.isPaused { synth.continueSpeaking() }
        updateNowPlaying()
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
        sermon = nil
        captions = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopPlayback() {
        task?.cancel()
        task = nil
        clip.stop()
        synth.stopSpeaking(at: .immediate)
        finishSpeaking()
        playing = false
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: The loop

    private func run(_ s: Sermon, keepPack: Bool = false) async {
        if !(keepPack && pack != nil) && !I18n.shared.spanish {
            // The preacher's recordings are in English; in Spanish the phone reads the translated words.
            pack = await VoicePacks.shared.ensure(voice: VoicePacks.preacher, packId: s.packId)
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
                    reader = tr("Preacher")
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
        playing = false
        SermonWeek.shared.markHeard(s.id)
        updateNowPlaying()
    }

    private func speak(_ text: String) async {
        let u = AVSpeechUtterance(string: Narration.spoken(text))
        u.voice = AVSpeechSynthesisVoice(language: I18n.shared.speechLanguage)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        u.postUtteranceDelay = 0.35
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            speaking = c
            synth.speak(u)
        }
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
