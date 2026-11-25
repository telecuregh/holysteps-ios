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
        Points.award(e.points)
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

extension ActivityLog.Event {
    /// Points for the first time each is done in a day (Android's award values: a walk 20, a guided prayer 20,
    /// a story or sermon 15, a journal or quiz 10, a verse or a health log 5).
    var points: Int {
        switch self {
        case .walk, .prayerAudio: 20
        case .sleepStory, .sermon: 15
        case .journal, .quiz: 10
        case .verse, .tracker: 5
        case .recap: 0
        }
    }
}

/// Lifetime points (they never go down) and Android's nine levels.
enum Points {
    static var total: Int { UserDefaults.standard.integer(forKey: "rewardPoints") }
    static func award(_ n: Int) { if n > 0 { UserDefaults.standard.set(total + n, forKey: "rewardPoints") } }
    static let levels: [(Int, String, String, Int)] = [
        (1, "Seeker", "🌱", 0), (2, "Believer", "🌿", 100), (3, "Disciple", "📖", 300), (4, "Faithful", "🕊️", 700), (5, "Steward", "🌳", 1500),
        (6, "Light", "🕯️", 3000), (7, "Shepherd", "🐑", 5500), (8, "Pillar", "🏛️", 9000), (9, "Overcomer", "👑", 14000),
    ]
    static var level: (Int, String, String, Int) { levels.last { total >= $0.3 } ?? levels[0] }
}
