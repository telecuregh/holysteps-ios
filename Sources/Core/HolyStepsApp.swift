import SwiftUI
import UserNotifications
import WidgetKit

@main
struct HolyStepsApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var i18n = I18n.shared
    @StateObject private var appearance = Appearance.shared
    @StateObject private var notifications = NotificationRouter.shared
    @Environment(\.scenePhase) private var phase
    /// Someone who already used the app before setup existed (a name saved) skips it.
    @AppStorage("onboarded") private var onboarded = UserDefaults.standard.object(forKey: "name") != nil
    /// The Terms and Privacy Policy version accepted on this phone (see Legal); a new version asks again.
    @AppStorage("legalAcceptedVersion") private var legalAccepted = ""

    init() {
        // UI tests start each run from a fresh install's data (the arguments themselves live in their own domain).
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset"), let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        I18n.shared.warmUp()
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        SelfCare.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if legalAccepted != Legal.version { ConsentGateView { legalAccepted = Legal.version } }
                else if onboarded { RootTabView() }
                else { OnboardingView { withAnimation { onboarded = true } } }
            }
                .environmentObject(store)
                .environmentObject(i18n)
                .environmentObject(appearance)
                .preferredColorScheme(appearance.mode.isLight ? .light : .dark)
                .task { await AccountStore.shared.start(); await Legal.syncIfNeeded(); await ProfileSync.run(store: store) }
                // Invite links: the join page's "Open in HolySteps" (holysteps://join?c=…), as on Android.
                .onOpenURL { url in
                    guard url.host == "join" || url.path.hasPrefix("/join") else { return }
                    TabRouter.shared.quick = .invite(InviteInbox.parse(url))
                }
                .fullScreenCover(isPresented: $notifications.ringing) { WakeRingView { notifications.ringing = false }.environmentObject(i18n) }
                .onChange(of: phase) { _, p in
                    if p != .active { shareWithWidgets() }
                    if p == .background { Backup.maybeAuto() }
                    if p == .active { Task { await ProfileSync.run(store: store) } }
                }
        }
    }

    /// What the widgets show (steps, prayer, streak, Faith plan), handed over each time the app goes to the background.
    @MainActor private func shareWithWidgets() {
        let days = store.prayerDays.union(store.readDays)
        var streak = 0
        var d = Date()
        if !days.contains(AppStore.dayKey(d)) { d = d.addingTimeInterval(-86400) }
        while days.contains(AppStore.dayKey(d)) { streak += 1; d = d.addingTimeInterval(-86400) }
        SharedState.save(steps: StepsModel.shared.stepsByDay[AppStore.dayKey()] ?? 0, goal: store.stepGoal,
                         prayedToday: store.prayerDays.contains(AppStore.dayKey()), streak: streak,
                         faith: AccountStore.shared.canUse(.devotionalPlans))
        WidgetCenter.shared.reloadAllTimelines()
        WatchLink.shared.send(fitness: AccountStore.shared.canUse(.walkPlus))
    }
}
