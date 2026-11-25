import SwiftUI

/// Android's Together tab (ui/screens/TogetherScreen.kt, ui/screens/community/*):
/// Prayer wall, Circles, Live Rooms and Church directory.
/// Community features need Firebase (GoogleService-Info.plist). Without the plist every
/// feature is unlocked locally (see Account.swift no-plist rule), but all data is
/// placeholder; real data loads once Firebase is connected.

// MARK: - Prayer Wall (local + Firebase)

private struct WallPost: Identifiable {
    let id: String
    let initials: String
    let age: String    // "2h", "1d", "3d"
    let request: String
    var prayedCount: Int
    var iPrayed: Bool
}

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

    // MARK: Prayer Wall

    private let wallPosts: [WallPost] = [
        WallPost(id: "1", initials: "A", age: "2h", request: "Please pray for my job interview tomorrow.", prayedCount: 14, iPrayed: false),
        WallPost(id: "2", initials: "M", age: "5h", request: "My father is in the hospital. Believing God for healing.", prayedCount: 31, iPrayed: false),
        WallPost(id: "3", initials: "S", age: "1d", request: "Pray for my marriage. We're going through a rough season.", prayedCount: 8, iPrayed: true),
        WallPost(id: "4", initials: "J", age: "2d", request: "Starting a new business next week. Praying for God's guidance.", prayedCount: 22, iPrayed: false),
        WallPost(id: "5", initials: "R", age: "3d", request: "Struggling with anxiety. Need peace that passes understanding.", prayedCount: 47, iPrayed: true),
    ]
    @State private var prayedIds: Set<String> = []
    @State private var showPostPrayer = false
    @State private var prayerDraft = ""

    private var prayerWall: some View {
        VStack(spacing: 0) {
            Button { showPostPrayer = true } label: {
                GlassCard {
                    HStack(spacing: 10) {
                        Circle().fill(HS.goldButton.opacity(0.3)).frame(width: 36, height: 36)
                            .overlay(Image(systemName: "hands.sparkles").font(.system(size: 14)).foregroundStyle(HS.peach))
                        T("Share a prayer request with the community...")
                            .font(.hs(14)).foregroundStyle(HS.textMuted)
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .sheet(isPresented: $showPostPrayer) {
                HSSheet(title: "Prayer request") {
                    VStack(spacing: 16) {
                        TextEditor(text: $prayerDraft)
                            .font(.hs(14))
                            .frame(minHeight: 100, maxHeight: 180)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        T("Posted anonymously with just your initials.")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                        GoldButton(title: "Post request") { showPostPrayer = false; prayerDraft = "" }
                    }
                    .padding(24)
                }
                .presentationDetents([.medium])
            }

            Spacer().frame(height: 14)
            ForEach(wallPosts) { post in
                wallCard(post)
            }
        }
    }

    private func wallCard(_ post: WallPost) -> some View {
        let prayed = prayedIds.contains(post.id) || post.iPrayed
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(LinearGradient(colors: [HS.peach.opacity(0.6), HS.faith.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .overlay(T(post.initials).font(.hs(13, .semibold)).foregroundStyle(.white))
                    T("Anonymous").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    Spacer()
                    T(post.age).font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                T(post.request).font(.hs(14)).foregroundStyle(HS.text).lineSpacing(4)
                HStack(spacing: 6) {
                    Button {
                        if !prayed { prayedIds.insert(post.id) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: prayed ? "hands.sparkles.fill" : "hands.sparkles")
                                .font(.system(size: 13))
                                .foregroundStyle(prayed ? HS.peach : HS.textMuted)
                            T(prayed ? "Prayed" : "Pray")
                                .font(.hs(13, .semibold))
                                .foregroundStyle(prayed ? HS.peach : HS.textMuted)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(prayed ? HS.peach.opacity(0.12) : HS.overlay(0.06)))
                    }
                    .buttonStyle(.plain)
                    T("\(post.prayedCount + (prayedIds.contains(post.id) ? 1 : 0)) praying")
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10)
    }

    // MARK: Circles

    private var circles: some View {
        VStack(spacing: 10) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        IconBadge(symbol: "person.3", size: 32, tint: 0x64A5E8)
                        VStack(alignment: .leading, spacing: 2) {
                            T("My Accountability Circle").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            T("3 members").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        T("Active").font(.hs(11, .semibold)).foregroundStyle(HS.body)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(HS.body.opacity(0.12)))
                    }
                    T("A private group where members check in daily and pray for each other.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    HStack(spacing: -6) {
                        ForEach(["A", "M", "J"], id: \.self) { l in
                            Circle().fill(HS.goldButton.opacity(0.4)).frame(width: 28, height: 28)
                                .overlay(T(l).font(.hs(12, .semibold)).foregroundStyle(HS.text))
                                .overlay(Circle().strokeBorder(HS.bgTop, lineWidth: 1))
                        }
                        T("+1 more").font(.hs(11)).foregroundStyle(HS.textMuted).padding(.leading, 10)
                    }
                }
            }
            .padding(.horizontal, 20)

            GlassCard {
                HStack(spacing: 12) {
                    IconBadge(symbol: "plus.circle", size: 32, tint: 0x9D7FEA)
                    VStack(alignment: .leading, spacing: 2) {
                        T("Create a circle").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T("Invite friends for private prayer and accountability")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(HS.textSubtle)
                }
            }
            .padding(.horizontal, 20)

            SectionHeader(title: "Find a circle").padding(.top, 6)
            ForEach([
                ("Men's morning prayer", "12 members", "sword.fill"),
                ("New moms in faith", "8 members", "heart"),
                ("Young adults 20s", "24 members", "person.2"),
            ], id: \.0) { name, count, sym in
                GlassCard {
                    HStack(spacing: 12) {
                        IconBadge(symbol: sym, size: 30, tint: 0xF3D5C0)
                        VStack(alignment: .leading, spacing: 2) {
                            T(name).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            T(count).font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        T("Join").font(.hs(13, .semibold)).foregroundStyle(HS.peach)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6)
            }
        }
    }

    // MARK: Live Rooms

    private var liveRooms: some View {
        VStack(spacing: 10) {
            GlassCard(glow: Color(hex: 0xF43F5E)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: 0xF43F5E)).frame(width: 8, height: 8)
                            T("LIVE").font(.hs(11, .semibold)).tracking(1.2).foregroundStyle(Color(hex: 0xF43F5E))
                        }
                        Spacer()
                        T("32 listening").font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                    T("Morning prayer with Pastor James").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                    T("Join a live prayer session and pray together in real time.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    GoldButton(title: "Join now") { }
                }
            }
            .padding(.horizontal, 20)

            SectionHeader(title: "Upcoming").padding(.top, 6)
            ForEach([
                ("Evening worship", "Tonight at 8 PM", "music.note"),
                ("Women's Bible study", "Thursday 7 PM", "book"),
                ("Prayer for healing", "Sunday 9 AM", "hands.sparkles"),
            ], id: \.0) { name, time, sym in
                GlassCard {
                    HStack(spacing: 12) {
                        IconBadge(symbol: sym, size: 32, tint: 0x9D7FEA)
                        VStack(alignment: .leading, spacing: 2) {
                            T(name).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            T(time).font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        T("Remind me").font(.hs(12)).foregroundStyle(HS.peach)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6)
            }
        }
    }

    // MARK: Church

    private var church: some View {
        VStack(spacing: 10) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        IconBadge(symbol: "building.columns", size: 36, tint: 0xD6AA6E)
                        VStack(alignment: .leading, spacing: 2) {
                            T("My Church").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            T("Not connected yet").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                    }
                    T("Ask your pastor or admin for your church's HolySteps code to unlock your church community.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    GoldButton(title: "Enter church code") { }
                }
            }
            .padding(.horizontal, 20)

            SectionHeader(title: "Find a church").padding(.top, 6)
            GlassCard {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(HS.textMuted)
                    T("Search churches on HolySteps").font(.hs(14)).foregroundStyle(HS.textMuted)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 20)

            ForEach([
                ("Grace Community Church", "2.1 mi away", "50 members on HolySteps"),
                ("First Baptist", "3.4 mi away", "120 members on HolySteps"),
            ], id: \.0) { name, dist, members in
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        T(name).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        HStack {
                            T(dist).font(.hs(12)).foregroundStyle(HS.textMuted)
                            Text("·").foregroundStyle(HS.textSubtle)
                            T(members).font(.hs(12)).foregroundStyle(HS.textMuted)
                            Spacer()
                            T("View").font(.hs(12, .semibold)).foregroundStyle(HS.peach)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6)
            }
        }
    }
}

// MARK: - Family Relay

/// Android's FamilyRelayScreen: shared streak visible to opted-in family members.
struct FamilyRelayView: View {
    @ObservedObject private var account = AccountStore.shared

    var body: some View {
        ZStack { HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                    D(tr("Family Relay")).font(.hs(28)).foregroundStyle(HS.text)
                    ItalicAccent(text: "One streak. The whole family.", size: 15)
                }
                        .padding(.horizontal, 20).padding(.top, 24)

                    Gated(feature: .familyRelay) {
                        familyContent
                    }

                    Spacer().frame(height: 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var familyContent: some View {
        VStack(spacing: 14) {
            GlassCard(glow: HS.gold) {
                VStack(spacing: 10) {
                    T("Family streak").font(.hs(13, .semibold)).tracking(0.8).foregroundStyle(HS.peach)
                    D("12").font(.hs(48, .bold)).foregroundStyle(HS.text).monospacedDigit()
                    T("days straight").font(.hs(14)).foregroundStyle(HS.textMuted)
                    HSProgressBar(progress: 12.0 / 30).padding(.top, 4)
                    T("12 of 30 days").font(.hs(11)).foregroundStyle(HS.textMuted)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20)

            SectionHeader(title: "Family members").padding(.top, 6)
            ForEach([
                ("You", "✓ today", true),
                ("Mom", "✓ today", true),
                ("Dad", "Not yet today", false),
            ], id: \.0) { name, status, done in
                GlassCard {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(done ? HS.goldButton.opacity(0.3) : HS.overlay(0.06))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: done ? "checkmark" : "circle")
                                    .font(.system(size: 14, weight: done ? .bold : .regular))
                                    .foregroundStyle(done ? HS.peach : HS.textMuted)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            T(name).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            T(status).font(.hs(12)).foregroundStyle(done ? HS.body : HS.textMuted)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6)
            }

            GlassCard {
                HStack(spacing: 12) {
                    IconBadge(symbol: "plus.circle", size: 32, tint: 0x56B892)
                    T("Invite a family member").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(HS.textSubtle)
                }
            }
            .padding(.horizontal, 20).padding(.top, 6)
        }
    }
}
