import Foundation
import ActivityKit

/// Starts, updates and ends HolySteps' Live Activity (Lock Screen and Dynamic Island). One at a time; quietly does
/// nothing when Live Activities are off in Settings.
@MainActor
enum LiveActivities {
    private static var current: Activity<HolyStepsActivityAttributes>?

    static func start(_ kind: HolyStepsActivityAttributes.Kind, title: String, _ state: HolyStepsActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let content = ActivityContent(state: state, staleDate: nil)
        current = try? Activity.request(attributes: HolyStepsActivityAttributes(kind: kind, title: title), content: content, pushType: nil)
    }

    static func update(_ state: HolyStepsActivityAttributes.ContentState) {
        guard let a = current else { return }
        Task { await a.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Ends it; a finished activity stays on the Lock Screen a little while with its last words.
    static func end(_ final: HolyStepsActivityAttributes.ContentState? = nil) {
        guard let a = current else { return }
        current = nil
        Task {
            await a.end(final.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: final == nil ? .immediate : .after(Date().addingTimeInterval(15 * 60)))
        }
    }
}
