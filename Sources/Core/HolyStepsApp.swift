import SwiftUI

@main
struct HolyStepsApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var i18n = I18n.shared

    init() { I18n.shared.warmUp() }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(i18n)
                .preferredColorScheme(.dark)
        }
    }
}
