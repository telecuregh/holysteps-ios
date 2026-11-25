import Foundation

/// The few things the widgets show from the app: today's steps, whether you prayed, your prayer streak, and
/// whether the Faith plan is on (StandBy's Night Watch comes with Faith). Kept in the app group on this phone only.
enum SharedState {
    static let group = "group.com.holysteps.app"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static var steps: Int { defaults.integer(forKey: "w.steps") }
    static var stepGoal: Int { max(1, defaults.integer(forKey: "w.goal")) }
    static var prayedToday: Bool { defaults.string(forKey: "w.prayedDay") == dayKey(Date()) }
    static var streak: Int { defaults.integer(forKey: "w.streak") }
    static var faith: Bool { defaults.bool(forKey: "w.faith") }

    static func save(steps: Int, goal: Int, prayedToday: Bool, streak: Int, faith: Bool) {
        let d = defaults
        d.set(steps, forKey: "w.steps"); d.set(goal, forKey: "w.goal"); d.set(streak, forKey: "w.streak"); d.set(faith, forKey: "w.faith")
        if prayedToday { d.set(dayKey(Date()), forKey: "w.prayedDay") }
    }

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
