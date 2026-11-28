import SwiftUI

/// Android's FriendStreakCard (Faith → Today): start a friend streak, join one with a code, and see each streak.
/// A streak grows only on days you both pray or read the Bible. A streak still waiting for its friend keeps its code,
/// so "Invite a friend" shares that one again instead of making another.
struct FriendStreakCard: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = CirclesModel.shared
    @State private var joining = false
    @State private var code = ""
    @State private var busy = false
    @State private var share: HabitCircle?

    private var streaks: [HabitCircle] { model.circles.filter(\.isFriendStreak) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    D("🔥").font(.hs(18))
                    T("Friend streaks").font(.hs(16, .bold)).foregroundStyle(HS.text)
                    Spacer()
                    T("Free").font(.hs(11, .bold)).foregroundStyle(HS.body)
                }
                if streaks.isEmpty {
                    T("Keep one streak with a friend. It grows only on days you both pray or read the Bible in HolySteps, so you keep each other going.")
                        .font(.hs(13)).foregroundStyle(HS.textMuted)
                }
                ForEach(streaks) { s in
                    if s.memberUids.count < 2 {
                        VStack(alignment: .leading, spacing: 3) {
                            T("Waiting for your friend to join").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            D(tr("Code") + " " + s.inviteCode).font(.hs(12)).foregroundStyle(HS.textMuted)
                            ShareLink(item: InviteCode.link(s.inviteCode), message: Text(invite(s.inviteCode))) {
                                T("Share the invite again").font(.hs(12, .semibold)).foregroundStyle(HS.peach)
                            }
                        }
                    } else {
                        NavigationLink { CircleDetailView(circle: s) } label: {
                            HStack {
                                T("Your friend streak").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(HS.gold)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let m = model.message { D(m).font(.hs(12)).foregroundStyle(HS.gold).onTapGesture { model.message = nil } }
                HStack(spacing: 8) {
                    Button { Task { await inviteFriend() } } label: {
                        T(busy ? "Making your invite…" : "Invite a friend").font(.hs(13, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
                    }
                    .buttonStyle(.plain).disabled(busy)
                    Button { joining = true } label: {
                        T("I have a code").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .task { await model.load() }
        .alert(tr("Join a friend streak"), isPresented: $joining) {
            TextField(tr("Code"), text: $code).textInputAutocapitalization(.characters)
            Button(tr("Join")) { let c = code; code = ""; Task { _ = await model.join(code: c, displayName: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        } message: { T("Type the code your friend sent you.") }
        .sheet(item: $share) { s in
            VStack(spacing: 16) {
                T("Invite your friend").font(.hs(20, .semibold))
                D(s.inviteCode).font(.hs(24, .bold)).foregroundStyle(HS.gold)
                ShareLink(item: InviteCode.link(s.inviteCode), message: Text(invite(s.inviteCode))) {
                    T("Share invite").font(.hs(15, .semibold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Capsule().fill(HS.goldButton))
                }
                ShowQRButton(code: s.inviteCode)
            }
            .padding(24)
            .presentationDetents([.medium])
        }
    }

    private func invite(_ code: String) -> String {
        tr("Keep a prayer streak with me on HolySteps! It grows on days we both pray or read the Bible. Or enter code {0}.")
            .replacingOccurrences(of: "{0}", with: code)
    }

    private func inviteFriend() async {
        guard !busy else { return }
        if let waiting = streaks.first(where: { $0.memberUids.count < 2 }) { share = waiting; return }
        busy = true
        defer { busy = false }
        if let made = await model.create(.friendStreak, name: "", habit: "", displayName: store.name) { share = made }
    }
}
