import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// The Lock Screen and Dynamic Island card for a walk, a workout or a sermon (shared by the app and the widget).
struct HolyStepsActivityAttributes: ActivityAttributes {
    enum Kind: String, Codable, Hashable { case walk, workout, sermon }
    struct ContentState: Codable, Hashable {
        /// The big line: the move, "Walking", the sermon's title.
        var headline: String
        /// The small line: "Round 1 of 3 · Next: Squat", "1.2 mi · 1,840 steps", "Romans 8".
        var detail: String
        /// When the current step ends (a live countdown without updates); nil shows `clock` instead.
        var endsAt: Date?
        /// A started-at date for a counting-up clock (walks), or nil.
        var since: Date?
        var progress: Double
        var paused: Bool
    }
    let kind: Kind
    let title: String
}
#endif
