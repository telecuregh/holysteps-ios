import Foundation
import AVFoundation
import MediaPlayer

/// Something the music player can play.
struct MusicItem: Identifiable, Hashable {
    enum Source: Hashable {
        /// A song bundled with the app (Resources/music/<id>.m4a).
        case bundled(String)
        /// One of the person's own files, kept as a security-scoped bookmark (never copied or uploaded).
        case own(Data)
        /// A recording from the HolySteps content library, streamed.
        case remote(URL)
    }
    let id: String
    let title: String
    let subtitle: String
    let source: Source
}

/// Plays worship music: a queue with next/previous, shuffle, repeat one, a sleep timer, background play and Lock
/// Screen controls (Android's MusicPlayer).
@MainActor
final class MusicPlayer: ObservableObject {
    static let shared = MusicPlayer()

    @Published private(set) var queue: [MusicItem] = []
    @Published private(set) var order: [Int] = []
    @Published private(set) var position = 0
    @Published private(set) var playing = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var repeatOne = false
    @Published private(set) var shuffle = false
    @Published private(set) var sleepEndsAt: Date?
    @Published private(set) var error: String?

    var current: MusicItem? { order.indices.contains(position) && queue.indices.contains(order[position]) ? queue[order[position]] : nil }
    var active: Bool { current != nil }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var scoped: URL?
    private var sleepTimer: Timer?

    private init() {
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        rc.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in if self?.active == true { self?.toggle() } }; return .success }
        rc.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in if self?.active == true { self?.next() } }; return .success }
        rc.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in if self?.active == true { self?.previous() } }; return .success }
        rc.changePlaybackPositionCommand.addTarget { [weak self] e in
            guard let e = e as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in if self?.active == true { self?.seek(e.positionTime) } }
            return .success
        }
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let began = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in if began { self?.pause() } }
        }
        // Unplugged headphones pause the music.
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] n in
            let reason = (n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init)
            Task { @MainActor in if reason == .oldDeviceUnavailable { self?.pause() } }
        }
    }

    func play(_ items: [MusicItem], start: Int = 0, shuffle: Bool = false) {
        guard !items.isEmpty else { return }
        SermonPlayer.shared.stop()
        BibleListening.shared.stop()
        queue = items
        self.shuffle = shuffle
        order = buildOrder(items.count, first: max(0, min(start, items.count - 1)), shuffle: shuffle)
        position = 0
        load()
    }

    func isCurrent(_ item: MusicItem) -> Bool { current?.id == item.id }

    func toggle() { playing ? pause() : resume() }
    func pause() { guard active else { return }; player?.pause(); playing = false; nowPlaying() }
    func resume() {
        guard active else { return }
        activate()
        player?.play(); playing = true; nowPlaying()
    }

    func next() { advance() }

    func previous() {
        if elapsed > 3 { seek(0); return }
        position = (position - 1 + order.count) % max(1, order.count)
        load()
    }

    func seek(_ t: Double) {
        player?.seek(to: CMTime(seconds: max(0, t), preferredTimescale: 600))
        elapsed = t
        nowPlaying()
    }

    func setShuffle(_ on: Bool) {
        guard !queue.isEmpty else { shuffle = on; return }
        let cur = order.indices.contains(position) ? order[position] : 0
        shuffle = on
        order = buildOrder(queue.count, first: cur, shuffle: on)
        position = 0
    }

    /// Minutes, or 0 for off.
    func setSleepTimer(_ minutes: Int) {
        sleepTimer?.invalidate(); sleepTimer = nil; sleepEndsAt = nil
        guard minutes > 0 else { return }
        sleepEndsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }

    func stop() {
        release()
        queue = []; order = []; position = 0; playing = false; elapsed = 0; duration = 0
        sleepTimer?.invalidate(); sleepTimer = nil; sleepEndsAt = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Internals

    private func buildOrder(_ n: Int, first: Int, shuffle: Bool) -> [Int] {
        let rest = (0..<n).filter { $0 != first }
        return [first] + (shuffle ? rest.shuffled() : rest)
    }

    private func activate() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func url(for item: MusicItem) -> URL? {
        switch item.source {
        case .bundled(let id): return Bundle.main.url(forResource: id, withExtension: "m4a")
        case .remote(let u): return u
        case .own(let bookmark):
            var stale = false
            guard let u = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else { return nil }
            if u.startAccessingSecurityScopedResource() { scoped = u }
            return u
        }
    }

    private func release() {
        if let o = timeObserver { player?.removeTimeObserver(o) }
        timeObserver = nil
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
        endObserver = nil
        player?.pause()
        player = nil
        scoped?.stopAccessingSecurityScopedResource()
        scoped = nil
    }

    private func load() {
        release()
        error = nil
        guard let item = current, let u = url(for: item) else {
            error = tr("This song can't be played.")
            if queue.count > 1 { advance() } else { playing = false }
            return
        }
        activate()
        let av = AVPlayerItem(url: u)
        let p = AVPlayer(playerItem: av)
        player = p
        elapsed = 0
        duration = 0
        timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = t.seconds
                if let d = self.player?.currentItem?.duration.seconds, d.isFinite, d > 0, d != self.duration {
                    self.duration = d
                    self.nowPlaying()
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: av, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.ended() }
        }
        p.play()
        playing = true
        nowPlaying()
    }

    private func ended() {
        if repeatOne { seek(0); player?.play(); return }
        advance()
    }

    private func advance() {
        guard !order.isEmpty else { return }
        position = (position + 1) % order.count
        load()
    }

    private func nowPlaying() {
        guard let item = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: tr(item.title),
            MPMediaItemPropertyArtist: "HolySteps",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
