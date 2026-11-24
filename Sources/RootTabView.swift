import SwiftUI
import UIKit

struct RootTabView: View {
    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(HS.bgMid)
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house.fill") }
            FaithView().tabItem { Label("Faith", systemImage: "cross") }
            FitnessView().tabItem { Label("Fitness", systemImage: "figure.walk") }
            CycleView().tabItem { Label("Cycle", systemImage: "moon.stars") }
            ProfileView().tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(HS.goldButton)
    }
}
