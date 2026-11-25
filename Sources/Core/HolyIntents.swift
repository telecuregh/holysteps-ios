import AppIntents
import SwiftUI

/// Siri, Shortcuts, Spotlight and the Action button. "Hey Siri, today's verse in HolySteps" answers without opening
/// the app; the others open HolySteps straight to the right screen.
enum QuickRoute: String, Identifiable {
    case prayerWalk, breathPrayer, faithCoach, sanctuary
    var id: String { rawValue }
}

@MainActor
private func open(_ route: QuickRoute) { TabRouter.shared.quick = route }

struct TodayVerseIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's verse"
    static let description = IntentDescription("Hear today's Bible verse from HolySteps.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let v = DailyVerses.forDay()
        let es = I18n.shared.language == "es"
        let line = es ? "\(v.es) \(DailyVerses.spanishRef(v.ref))" : "\(v.text) \(v.ref)"
        return .result(dialog: "\(line)")
    }
}

struct StartPrayerWalkIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a prayer walk"
    static let description = IntentDescription("Open HolySteps ready to start a walk.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { open(.prayerWalk); return .result() }
}

struct BreathPrayerIntent: AppIntent {
    static let title: LocalizedStringResource = "Breath prayer"
    static let description = IntentDescription("Breathe and pray with gentle haptics.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { open(.breathPrayer); return .result() }
}

struct SanctuaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Spatial Sanctuary"
    static let description = IntentDescription("Open a quiet place to pray, with sound all around you.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { open(.sanctuary); return .result() }
}

struct FaithCoachIntent: AppIntent {
    static let title: LocalizedStringResource = "Talk to my faith coach"
    static let description = IntentDescription("Open the private faith coach.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        if FaithCoach.available { open(.faithCoach) } else { TabRouter.shared.open(tab: 1) }
        return .result()
    }
}

struct PrayIntent: AppIntent {
    static let title: LocalizedStringResource = "Pray"
    static let description = IntentDescription("Open your prayers in HolySteps.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { TabRouter.shared.open(tab: 1, faith: 0); return .result() }
}

struct HolyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TodayVerseIntent(), phrases: ["Today's verse in \(.applicationName)", "Read me a verse in \(.applicationName)"],
                    shortTitle: "Today's verse", systemImageName: "book")
        AppShortcut(intent: StartPrayerWalkIntent(), phrases: ["Start a prayer walk in \(.applicationName)", "Start a \(.applicationName) walk"],
                    shortTitle: "Prayer walk", systemImageName: "figure.walk")
        AppShortcut(intent: BreathPrayerIntent(), phrases: ["Breath prayer in \(.applicationName)", "Breathe with \(.applicationName)"],
                    shortTitle: "Breath prayer", systemImageName: "wind")
        AppShortcut(intent: SanctuaryIntent(), phrases: ["Open the sanctuary in \(.applicationName)"],
                    shortTitle: "Sanctuary", systemImageName: "headphones")
        AppShortcut(intent: FaithCoachIntent(), phrases: ["Talk to my faith coach in \(.applicationName)"],
                    shortTitle: "Faith coach", systemImageName: "sparkles")
        AppShortcut(intent: PrayIntent(), phrases: ["Pray with \(.applicationName)", "Open my prayers in \(.applicationName)"],
                    shortTitle: "Pray", systemImageName: "hands.sparkles")
    }
}

/// Shows the screen a shortcut asked for, over whatever tab is open.
struct QuickRouteScreen: View {
    let route: QuickRoute
    var body: some View {
        NavigationStack {
            switch route {
            case .prayerWalk: WalkSetupView()
            case .breathPrayer: BreathPrayerView()
            case .faithCoach: FaithCoachView()
            case .sanctuary: SpatialSanctuaryView()
            }
        }
    }
}
