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
    @Published private(set) var sleepEndsAt: Date?
    @Published private(set) var error: String?

    var title: String { book.isEmpty ? "" : "\(bookTitle.isEmpty ? book : bookTitle) \(ch)" }

    private let synth = AVSpeechSynthesizer()
    private var text: Bible.Text?
    private var verses: [String] = []
    private var sleepTimer: Timer?
    private var stopAfterChapter = false
    /// Bumped on every new start so a late delegate callback from an earlier utterance is ignored.
    private var generation = 0
    private var current: AVSpeechUtterance?

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
                startChapter(book: book, ch: ch, from: fromVerse)
            } catch {
                guard gen == generation else { return }
                self.error = error.localizedDescription
                loading = false
            }
        }
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
        let u = AVSpeechUtterance(string: Spoken.verse(verses[v - 1]))
        u.voice = voice()
        u.rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * speed)
        u.postUtteranceDelay = 0.25
        current = u
        playing = true
        synth.speak(u)
        updateNowPlaying()
    }

    func pause() {
        guard active else { return }
        if synth.isSpeaking { synth.pauseSpeaking(at: .word) }
        playing = false
        updateNowPlaying()
    }

    func resume() {
        guard active else { return }
        activateSession()
        if synth.isPaused { synth.continueSpeaking(); playing = true }
        else if verse >= 1 && verse <= verses.count { speak(verse) }
        updateNowPlaying()
    }

    func toggle() { playing ? pause() : resume() }

    func nextVerse() {
        guard active else { return }
        generation += 1
        synth.stopSpeaking(at: .immediate)
        advance(after: verse)
    }

    func stop() {
        generation += 1
        synth.stopSpeaking(at: .immediate)
        sleepTimer?.invalidate(); sleepTimer = nil
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

    private func advance(after v: Int) {
        if v < verses.count { speak(v + 1); return }
        // End of the chapter.
        ChapterHeard.post(book: book, ch: ch)
        if stopAfterChapter { stop(); return }
        guard let t = text, let bi = t.bookIndex(book) else { stop(); return }
        if ch < t.chapters(book) { startChapter(book: book, ch: ch + 1, from: 1) }
        else if bi + 1 < t.books.count { startChapter(book: t.books[bi + 1].name, ch: 1, from: 1) }
        else { stop() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.active, utterance === self.current else { return }
            self.advance(after: self.verse)
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
