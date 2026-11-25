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

    private var circles: some View { CirclesView() }

    private var liveRooms: some View { LiveRoomsView() }

    private var church: some View { ChurchTab() }
}

