import SwiftUI

/// Android's Together tab (ui/screens/TogetherScreen.kt, ui/screens/community/*):
/// Prayer wall, Circles, Live Rooms and Church directory.
/// Every tab is live from Firestore and HolySteps' server, shared with Android (see CommunityWall,
/// HabitCircles, LiveRooms and ChurchSpace). Nothing here is sample data.

// MARK: - Community View

struct CommunityView: View {
    @State private var tab = 0
    @ObservedObject private var router = TabRouter.shared

    /// Shown inside Faith's Together tab, under Faith's own header, in its scroll and navigation.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SubTabs(tabs: ["Wall", "Circles", "Live", "Church"], selected: $tab)
            Spacer().frame(height: 12)
            switch tab {
            case 0: prayerWall
            case 1: circles
            case 2: liveRooms
            default: church
            }
        }
    }

    private var prayerWall: some View { PrayerWallView() }

    private var circles: some View {
        VStack(alignment: .leading, spacing: 10) {
            TogetherLinks()
            CirclesView()
        }
    }

    private var liveRooms: some View { LiveRoomsView() }

    private var church: some View { ChurchTab() }
}



/// Android's other "together" features: groups, reading plans with friends, weekly leagues and Scripture duels.
struct TogetherLinks: View {
    var body: some View {
        VStack(spacing: 8) {
            row("👥", "Groups", "Your family, small group or church, week by week") { FaithGroupsView() }
            row("📖", "Reading together", "Read a Bible plan with friends") { ReadingTogetherView() }
            row("🏆", "Weekly league", "Walk with people at your level") { LeaguesView() }
            row("⚔️", "Scripture duels", "Fill in the missing words against someone") { DuelsView() }
        }.padding(.horizontal, 20)
    }
    private func row<D: View>(_ e: String, _ t: String, _ sub: String, @ViewBuilder _ dest: @escaping () -> D) -> some View {
        NavigationLink { dest() } label: {
            HStack(spacing: 10) {
                D(e).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) { T(t).font(.hs(15, .bold)).foregroundStyle(HS.text); T(sub).font(.hs(12)).foregroundStyle(HS.textSecondary) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
            }.padding(12).background(RoundedRectangle(cornerRadius: 14).fill(HS.text.opacity(0.05)))
        }.buttonStyle(.plain)
    }
}
