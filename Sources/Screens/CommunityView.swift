import SwiftUI

/// Android's Together tab (ui/screens/TogetherScreen.kt, ui/screens/community/*):
/// Prayer wall, Circles, Live Rooms and Church directory.
/// Community features need Firebase (GoogleService-Info.plist). Without the plist every
/// feature is unlocked locally (see Account.swift no-plist rule), but all data is
/// placeholder; real data loads once Firebase is connected.

// MARK: - Community View

struct CommunityView: View {
    @State private var tab = 0
    @ObservedObject private var router = TabRouter.shared

    var body: some View {
        NavigationStack {
            ZStack { HSBackground()
                VStack(alignment: .leading, spacing: 0) {
                    header
                    SubTabs(tabs: ["Wall", "Circles", "Live", "Church"], selected: $tab)
                        .padding(.top, 4)
                    Spacer().frame(height: 12)
                    ScrollView {
                        switch tab {
                        case 0: prayerWall
                        case 1: circles
                        case 2: liveRooms
                        default: church
                        }
                        Spacer().frame(height: 100)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                IconBadge(symbol: "person.3", size: 30, tint: 0x64A5E8)
                T("Together").font(.hs(13, .semibold)).tracking(0.6).foregroundStyle(HS.peach)
            }
            Spacer().frame(height: 10)
            T("Community").font(.hs(26)).foregroundStyle(HS.text)
            ItalicAccent(text: "Better together in faith", size: 17)
        }
        .padding(.top, 60).padding(.horizontal, 20).padding(.bottom, 14)
    }

    private var prayerWall: some View { PrayerWallView() }

    private var circles: some View { CirclesView() }

    private var liveRooms: some View { LiveRoomsView() }

    private var church: some View { ChurchTab() }
}

