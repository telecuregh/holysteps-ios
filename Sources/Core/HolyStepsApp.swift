import SwiftUI

@main
struct HolyStepsApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var i18n = I18n.shared
    @StateObject private var appearance = Appearance.shared
    /// Someone who already used the app before setup existed (a name saved) skips it.
    @AppStorage("onboarded") private var onboarded = UserDefaults.standard.object(forKey: "name") != nil

    init() { I18n.shared.warmUp() }

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
        }
    }
}
