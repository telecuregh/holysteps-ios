import SwiftUI
import UserNotifications

@main
struct HolyStepsApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var i18n = I18n.shared
    @StateObject private var appearance = Appearance.shared
    @StateObject private var notifications = NotificationRouter.shared
    /// Someone who already used the app before setup existed (a name saved) skips it.
    @AppStorage("onboarded") private var onboarded = UserDefaults.standard.object(forKey: "name") != nil

    init() {
        // UI tests start each run from a fresh install's data (the arguments themselves live in their own domain).
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset"), let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        I18n.shared.warmUp()
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded { RootTabView() }
                else { OnboardingView { withAnimation { onboarded = true } } }
            }
                .environmentObject(store)
                .environmentObject(i18n)
                .environmentObject(appearance)
                .preferredColorScheme(appearance.mode.isLight ? .light : .dark)
                .task { await AccountStore.shared.start() }
                .fullScreenCover(isPresented: $notifications.ringing) { WakeRingView { notifications.ringing = false }.environmentObject(i18n) }
        }
    }
}
