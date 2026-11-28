import Foundation
import AVFoundation
import MediaPlayer

/// Plays the Bible aloud, verse by verse, from any chapter on, in the translation's language using the iPhone's own
/// voice. Keeps going into the next chapter, follows a sleep timer and a speed setting, pauses for calls, and shows
/// on the Lock Screen. (Android's narrator recordings come later; they need the voice-pack format.)
@MainActor
final class BibleListening: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = BibleListening()

    static let sleepChoices = [0, 15, 30, 45, 60, -1]
    static let speeds: [Float] = [0.75, 0.9, 1.0, 1.15, 1.3, 1.5]

    static func sleepLabel(_ m: Int) -> String {
        switch m { case 0: return tr("Off"); case -1: return tr("End of chapter"); default: return "\(m) min" }
    }
    static func speedLabel(_ s: Float) -> String {
        if s == 1.0 { return "1×" }
        var str = String(format: "%.2f", s)
        while str.hasSuffix("0") { str.removeLast() }
        if str.hasSuffix(".") { str.removeLast() }
        return str + "×"
    }

    @Published private(set) var active = false
    @Published private(set) var playing = false
    @Published private(set) var loading = false
    @Published private(set) var translation = ""
    @Published private(set) var lang = "en"
    @Published private(set) var book = ""
    @Published private(set) var bookTitle = ""
    @Published private(set) var ch = 0
    /// The verse being read (1-based); 0 before the first.
    @Published private(set) var verse = 0
    @Published private(set) var verseCount = 0
    @Published var speed: Float = 1.0 { didSet { UserDefaults.standard.set(speed, forKey: "bibleListenSpeed") } }
    @Published private(set) var sleepMinutes = 0
    /// Android's Repeat: off, the same verse again, or the chapter again from verse 1. Kept across stop and start.
    enum RepeatMode: String { case off, verse, chapter
        var label: String { ["off": "Repeat: off", "verse": "Repeat: verse", "chapter": "Repeat: chapter"][rawValue]! }
        var next: RepeatMode { self == .off ? .verse : self == .verse ? .chapter : .off }
    }
    @Published var repeatMode: RepeatMode = RepeatMode(rawValue: UserDefaults.standard.string(forKey: "bibleRepeat") ?? "") ?? .off {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: "bibleRepeat") }
    }
    func cycleRepeat() { repeatMode = repeatMode.next }
    @Published private(set) var sleepEndsAt: Date?
    @Published private(set) var error: String?
    /// Who is reading: "Grace", "Michael" or "your phone's voice".
    @Published private(set) var reader = ""
    /// The narrator chosen for the recorded chapters: a VoicePacks narrator id, or "device".
    /// A narrator set to the phone's voice in an older version moves to Grace: the phone's voice is no longer offered.
    @Published var narrator: String = UserDefaults.standard.string(forKey: "bibleNarrator").flatMap { $0 == VoicePacks.deviceVoice ? nil : $0 } ?? "af_heart" {
        didSet { UserDefaults.standard.set(narrator, forKey: "bibleNarrator") }
    }

    var title: String { book.isEmpty ? "" : "\(bookTitle.isEmpty ? book : bookTitle) \(ch)" }

    private let synth = AVSpeechSynthesizer()
    private var text: Bible.Text?
    private var verses: [String] = []
    private var sleepTimer: Timer?
    private var stopAfterChapter = false
    /// Bumped on every new start so a late delegate callback from an earlier utterance is ignored.
    private var generation = 0
    private var current: AVSpeechUtterance?
    private let clips = ClipPlayer()
    private var pack: VoicePacks.Pack?
    private var clipPlaying = false

    override private init() {
        super.init()
        synth.delegate = self
        let s = UserDefaults.standard.float(forKey: "bibleListenSpeed")
        if s > 0 { speed = s }
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        rc.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        rc.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.nextVerse() }; return .success }
    }

    // MARK: Control

    /// Starts reading `book` `ch` of `translation` from `fromVerse`.
    func play(translation: String, lang: String, book: String, ch: Int, fromVerse: Int = 1) {
        SermonPlayer.shared.stop()
        MusicPlayer.shared.stop()
        generation += 1
        let gen = generation
        synth.stopSpeaking(at: .immediate)
        self.translation = translation
        self.lang = lang.isEmpty ? "en" : lang
        self.book = book
        self.ch = ch
        active = true; loading = true; playing = false; error = nil
        stopAfterChapter = false
        Task {
            do {
                let t = try await BibleRepository.shared.load(translation)
                guard gen == generation else { return }
                text = t
                await beginChapter(book: book, ch: ch, from: fromVerse, gen: gen)
            } catch {
                guard gen == generation else { return }
                self.error = error.localizedDescription
                loading = false
            }
        }
    }

    /// Loads the narrator's recording when this chapter has one, then starts reading.
    private func beginChapter(book: String, ch: Int, from: Int, gen: Int) async {
        pack = nil
        if VoicePacks.mayBeRecorded(translation: translation) {
            loading = true
            pack = await VoicePacks.shared.ensure(voice: VoicePacks.bibleVoice(narrator: narrator, translation: translation),
                                                  packId: VoicePacks.biblePackId(translation: translation, book: book, ch: ch))
        }
        guard gen == generation else { return }
        // Grace reads the whole Bible in English and Spanish; the phone's own voice is never used for it. If her
        // recording can't be had (offline and not downloaded yet), say so instead of switching voices.
        if pack == nil {
            error = tr(VoicePacks.mayBeRecorded(translation: translation)
                       ? "Grace's recording couldn't be loaded. Check your connection and try again."
                       : "Grace hasn't recorded this translation yet. Choose an English or Spanish Bible to hear her.")
            loading = false; playing = false
            return
        }
        reader = pack != nil ? "Grace" : tr("Your phone's voice")
        startChapter(book: book, ch: ch, from: from)
    }

    private func startChapter(book: String, ch: Int, from: Int) {
        guard let t = text else { return }
        self.book = book; self.ch = ch
        bookTitle = t.display(book)
        verses = t.chapter(book, ch)
        verseCount = verses.count
        loading = false
        guard !verses.isEmpty else { stop(); return }
        activateSession()
        speak(max(1, min(from, verses.count)))
    }

    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio, options: [])
        try? s.setActive(true)
    }

    private func voice() -> AVSpeechSynthesisVoice? {
        let wanted: String
        switch lang {
        case "en": wanted = "en-US"
        case "es": wanted = "es-US"
        case "pt": wanted = "pt-BR"
        case "zh": wanted = "zh-CN"
        default: wanted = lang
        }
        return AVSpeechSynthesisVoice(language: wanted)
            ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix(lang) }
    }

    private func speak(_ v: Int) {
        verse = v
        // Grace's recordings are keyed by the verse as printed; names like "Beer–sheba" keep their dash there.
        if let data = pack?.audio(for: Spoken.verse(verses[v - 1])) ?? pack?.audio(for: verses[v - 1]) {
            let gen = generation
            playing = true
            clipPlaying = true
            updateNowPlaying()
            Task {
                let ok = await clips.play(data, rate: speed)
                guard gen == generation, active else { return }
                clipPlaying = false
                _ = ok
                // The breath between verses (1.2 s at normal speed), as in the Android player.
                try? await Task.sleep(nanoseconds: UInt64(1_200_000_000 / Double(max(0.5, speed))))
                guard gen == generation, active, playing else { return }
                finished(v)
            }
            return
        }
        // No recording of this verse: never the phone's voice.
        stop()
    }

    func pause() {
        guard active else { return }
        if synth.isSpeaking { synth.pauseSpeaking(at: .word) }
        if clipPlaying { clips.pause() }
        playing = false
        updateNowPlaying()
    }

    func resume() {
        guard active else { return }
        activateSession()
        if clipPlaying { clips.resume(); playing = true }
        else if synth.isPaused { synth.continueSpeaking(); playing = true }
        else if verse >= 1 && verse <= verses.count { speak(verse) }
        updateNowPlaying()
    }

    func toggle() { playing ? pause() : resume() }

    func nextVerse() {
        guard active else { return }
        generation += 1
        synth.stopSpeaking(at: .immediate)
        clipPlaying = false
        clips.stop()
        advance(after: verse)
    }

    func stop() {
        generation += 1
        synth.stopSpeaking(at: .immediate)
        sleepTimer?.invalidate(); sleepTimer = nil
        clipPlaying = false
        clips.stop()
        active = false; playing = false; loading = false
        sleepMinutes = 0; sleepEndsAt = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func setSpeed(_ s: Float) {
        speed = s
        if playing && verse > 0 {      // apply from the current verse
            generation += 1
            synth.stopSpeaking(at: .immediate)
            clipPlaying = false
            clips.stop()
            speak(verse)
        }
    }

    func setSleep(_ minutes: Int) {
        sleepTimer?.invalidate(); sleepTimer = nil
        sleepMinutes = minutes
        stopAfterChapter = minutes == -1
        sleepEndsAt = nil
        if minutes > 0 {
            let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
            sleepEndsAt = end
            sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
        }
    }

    // MARK: Moving on

    /// A verse finished on its own: Repeat decides what comes next (the sleep timer still stops everything).
    private func finished(_ v: Int) {
        if repeatMode == .verse { speak(v); return }
        if repeatMode == .chapter && v >= verses.count {
            ChapterHeard.post(book: book, ch: ch)
            if stopAfterChapter { stop(); return }
            speak(1); return
        }
        advance(after: v)
    }

    private func advance(after v: Int) {
        if v < verses.count { speak(v + 1); return }
        // End of the chapter.
        ChapterHeard.post(book: book, ch: ch)
        if stopAfterChapter { stop(); return }
        guard let t = text, let bi = t.bookIndex(book) else { stop(); return }
        let gen = generation
        if ch < t.chapters(book) { let b = book, c = ch + 1; Task { await beginChapter(book: b, ch: c, from: 1, gen: gen) } }
        else if bi + 1 < t.books.count { let b = t.books[bi + 1].name; Task { await beginChapter(book: b, ch: 1, from: 1, gen: gen) } }
        else { stop() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.active, utterance === self.current else { return }
            self.finished(self.verse)
        }
    }

    @objc private func interrupted(_ n: Notification) {
        guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        Task { @MainActor in
            if type == .began { self.pause() }
            else if let o = n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                    AVAudioSession.InterruptionOptions(rawValue: o).contains(.shouldResume) { self.resume() }
        }
    }

    private func updateNowPlaying() {
        guard active else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "HolySteps · \(translation)",
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
    }
}

/// Hearing a chapter through to its last verse counts as reading it.
enum ChapterHeard {
    static let name = Notification.Name("hsChapterHeard")
    static func post(book: String, ch: Int) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["book": book, "ch": ch])
    }
}
