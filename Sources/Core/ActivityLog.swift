import Foundation

/// What was done on each day, kept only on this phone: the first-week path and the weekly recap read it.
/// Only the kind of activity and the day are kept (no content, no times).
final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()

    enum Event: String, CaseIterable {
        case verse, walk, prayerAudio, sleepStory, sermon, journal, quiz, tracker, recap
    }

    @Published private(set) var days: [String: [String]] {
        didSet { UserDefaults.standard.set(days, forKey: "activityLog") }
    }

    private init() {
        days = UserDefaults.standard.dictionary(forKey: "activityLog") as? [String: [String]] ?? [:]
    }

    func add(_ e: Event, on date: Date = Date()) {
        let k = AppStore.dayKey(date)
        var list = days[k] ?? []
        guard !list.contains(e.rawValue) else { return }
        list.append(e.rawValue)
        days[k] = list
        // Keep about three months.
        let cutoff = AppStore.dayKey(Date().addingTimeInterval(-92 * 86400))
        days = days.filter { $0.key >= cutoff }
    }

    func did(_ e: Event, on dayKey: String) -> Bool { days[dayKey]?.contains(e.rawValue) == true }

    /// Any day from `fromKey` on (inclusive).
    func didSince(_ e: Event, _ fromKey: String) -> Bool { days.contains { $0.key >= fromKey && $0.value.contains(e.rawValue) } }

    func erase() { days = [:] }
}
