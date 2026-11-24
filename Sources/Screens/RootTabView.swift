import SwiftUI
import UIKit

struct RootTabView: View {
    @EnvironmentObject var i18n: I18n

    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(HS.bgMid)
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        TabView {
            HomeView().tabItem { Label(tr("Home"), systemImage: "house.fill") }
            FaithView().tabItem { Label(tr("Faith"), systemImage: "cross") }
            FitnessView().tabItem { Label(tr("Fitness"), systemImage: "figure.walk") }
            CycleView().tabItem { Label(tr("Cycle"), systemImage: "moon.stars") }
            ProfileView().tabItem { Label(tr("Profile"), systemImage: "person") }
        }
        .tint(HS.goldButton)
        .environment(\.locale, i18n.locale)
        .id(i18n.language)   // redraw every screen in the new language
    }
}
