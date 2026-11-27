import SwiftUI

// MARK: - Model

enum ActivityKind: String, CaseIterable, Identifiable {
    case prayerWalk = "PRAYER_WALK"
    case bibleStudy  = "BIBLE_STUDY"
    case workout     = "WORKOUT"
    case other       = "OTHER"
    var id: String { rawValue }
    var emoji: String { switch self { case .prayerWalk: "🚶"; case .bibleStudy: "📖"; case .workout: "💪"; case .other: "🌿" } }
    var label: String { switch self { case .prayerWalk: tr("Prayer walk"); case .bibleStudy: tr("Bible study"); case .workout: tr("Workout"); case .other: tr("Activity") } }
}

struct ActivityInvite: Identifiable, Equatable {
    let id: String
    let uid, displayName, kind, note, locationHint: String
    let scheduledAt, createdAt, expiresAt: Int64
    var joinCount: Int64
    var joins: [String]

    init(_ d: FSDoc) {
        id = d.id; uid = d["uid"].string; displayName = d["displayName"].string
        kind = d["kind"].string; note = d["note"].string; locationHint = d["locationHint"].string
        scheduledAt = d["scheduledAt"].int; createdAt = d["createdAt"].int; expiresAt = d["expiresAt"].int
        joinCount = d["joinCount"].int; joins = d["joins"].array.map(\.string)
    }

    var activityKind: ActivityKind { ActivityKind(rawValue: kind) ?? .other }
    var title: String { activityKind.emoji + " " + activityKind.label }
    var isExpired: Bool { Firestore.nowMs > expiresAt }
    var scheduledDate: Date? { scheduledAt > 0 ? Date(timeIntervalSince1970: Double(scheduledAt) / 1000) : nil }
    var who: String { displayName.isEmpty ? tr("Someone") : displayName }
}

// MARK: - Follow

/// Lightweight follow: uid → uid.  No health data ever crosses this link.
/// Firestore: follows/{myUid}/following/{theirUid}  (presence document, no data)
@MainActor
final class FollowModel: ObservableObject {
    static let shared = FollowModel()
    @Published private(set) var following: Set<String> = []

    private var uid: String? { AccountStore.shared.uid }

    func load() async {
        guard let uid else { return }
        let docs = (try? await Firestore.query("following", parent: "follows/\(uid)", limit: 500)) ?? []
        following = Set(docs.map(\.id))
    }

    func toggle(_ theirUid: String) async {
        guard let uid, uid != theirUid else { return }
        let on = following.contains(theirUid)
        if on { following.remove(theirUid) } else { following.insert(theirUid) }
        do {
            try await Firestore.commit([
                on ? .delete("follows/\(uid)/following/\(theirUid)")
                   : .set("follows/\(uid)/following/\(theirUid)", ["since": .int(Firestore.nowMs)])
            ])
        } catch {
            if on { following.insert(theirUid) } else { following.remove(theirUid) }
        }
    }

    func isFollowing(_ theirUid: String) -> Bool { following.contains(theirUid) }
}

// MARK: - Activity Model

@MainActor
final class ActivityModel: ObservableObject {
    static let shared = ActivityModel()

    @Published private(set) var invites: [ActivityInvite] = []
    @Published private(set) var loading = true
    @Published private(set) var failed  = false
    @Published var message: String?

    private var uid: String? { AccountStore.shared.uid }

    func load() async {
        do {
            let docs = try await Firestore.query("activity_invites", orderBy: "createdAt", descending: true, limit: 100)
            let now  = Firestore.nowMs
            invites  = docs.map(ActivityInvite.init).filter { $0.expiresAt > now }
            failed   = false
        } catch { failed = invites.isEmpty }
        loading = false
    }

    func post(kind: ActivityKind, note: String, locationHint: String, scheduledAt: Int64, name: String) async -> Bool {
        guard let uid else { message = tr("Couldn't reach HolySteps. Try again."); return false }
        let n = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        guard !n.isEmpty else { return false }
        let now     = Firestore.nowMs
        let id      = Firestore.newId()
        let expire  = now + 86_400_000   // 24 h
        let fields: [String: FSValue] = [
            "uid": .string(uid), "displayName": .string(String(name.prefix(60))),
            "kind": .string(kind.rawValue), "note": .string(n),
            "locationHint": .string(String(locationHint.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))),
            "scheduledAt": .int(scheduledAt), "createdAt": .int(now), "expiresAt": .int(expire),
            "joinCount": .int(0), "joins": .array([]),
        ]
        do {
            try await Firestore.commit([.set("activity_invites/\(id)", fields, mustNotExist: true)])
            await load(); return true
        } catch { message = tr("Couldn't post — check your connection."); return false }
    }

    func toggleJoin(_ invite: ActivityInvite) async {
        guard let uid, uid != invite.uid else { return }
        let on = invite.joins.contains(uid)
        if let i = invites.firstIndex(of: invite) {
            if on { invites[i].joins.removeAll { $0 == uid }; invites[i].joinCount -= 1 }
            else  { invites[i].joins.append(uid); invites[i].joinCount += 1 }
        }
        do {
            let delta: Int64 = on ? -1 : 1
            let newJoins = on
                ? invite.joins.filter { $0 != uid }.map { FSValue.string($0) }
                : (invite.joins + [uid]).map { FSValue.string($0) }
            try await Firestore.commit([.update("activity_invites/\(invite.id)",
                ["joins": .array(newJoins)], increments: ["joinCount": delta])])
        } catch { await load() }
    }

    func delete(_ invite: ActivityInvite) async {
        try? await Firestore.commit([.delete("activity_invites/\(invite.id)")])
        await load()
    }
}

// MARK: - Activities View

struct ActivityBoardView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model   = ActivityModel.shared
    @ObservedObject private var follow  = FollowModel.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var filterFollowing  = false
    @State private var composing        = false
    @State private var paywall          = false
    @State private var deletingInvite: ActivityInvite?

    private var uid: String { AccountStore.shared.uid ?? "" }

    private var visible: [ActivityInvite] {
        let list = model.invites.filter { !$0.isExpired }
        if filterFollowing { return list.filter { follow.isFollowing($0.uid) || $0.uid == uid } }
        return list
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    T("🚶 WALK TOGETHER").font(.hs(11, .semibold)).tracking(0.8).foregroundStyle(HS.faith)
                    T("Invite people to move with you").font(.hs(17, .semibold)).foregroundStyle(HS.text)
                }
                Spacer()
                Button { if account.hasAnyPlan { composing = true } else { paywall = true } } label: {
                    T("+ Invite").font(.hs(13, .semibold)).foregroundStyle(HS.onGold)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(HS.goldButton))
                }
            }
            .padding(.horizontal, 20)

            // Filter toggle
            HStack(spacing: 8) {
                filterChip("Everyone", selected: !filterFollowing) { filterFollowing = false }
                filterChip("Following", selected: filterFollowing)  { filterFollowing = true }
                Spacer()
            }
            .padding(.horizontal, 20)

            if let m = model.message {
                D(m).font(.hs(12)).foregroundStyle(HS.gold).padding(.horizontal, 20)
                    .onTapGesture { model.message = nil }
            }

            if model.loading && model.invites.isEmpty {
                ProgressView().tint(HS.gold).padding(30)
            } else if model.failed {
                VStack(spacing: 8) {
                    T("Couldn't connect — check your internet connection.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    Button { Task { await model.load() } } label: { T("Try again").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                }.padding(30)
            } else if visible.isEmpty {
                emptyState
            } else {
                ForEach(visible) { inv in inviteCard(inv) }
            }
        }
        .task { await model.load(); await follow.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $composing) { ComposeActivitySheet() }
        .sheet(isPresented: $paywall) { PlansView(feature: .createGroup) }
        .alert(tr("Remove your invite?"), isPresented: Binding(get: { deletingInvite != nil }, set: { if !$0 { deletingInvite = nil } })) {
            Button(tr("Remove"), role: .destructive) { if let inv = deletingInvite { Task { await model.delete(inv) } }; deletingInvite = nil }
            Button(tr("Cancel"), role: .cancel) { deletingInvite = nil }
        }
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            T(tr(label)).font(.hs(13, .semibold)).foregroundStyle(selected ? HS.onGold : HS.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(selected ? HS.goldButton : HS.overlay(0.06)))
        }.buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🚶").font(.system(size: 44))
            T("No invites yet").font(.hs(16, .semibold)).foregroundStyle(HS.text)
            T(filterFollowing
                ? "No one you follow has posted an invite.\nTry switching to Everyone."
                : "Be the first to invite someone for a walk,\na Bible study or a workout.")
                .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
            if filterFollowing {
                Button { filterFollowing = false } label: {
                    T("See everyone").font(.hs(13, .semibold)).foregroundStyle(HS.faith)
                }.buttonStyle(.plain)
            }
        }.padding(30)
    }

    private func inviteCard(_ inv: ActivityInvite) -> some View {
        let isMine    = inv.uid == uid
        let joined    = inv.joins.contains(uid)
        let isFollowed = follow.isFollowing(inv.uid)

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Top row
                HStack(spacing: 8) {
                    Circle().fill(LinearGradient(colors: [HS.faith.opacity(0.6), HS.peach.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .overlay(Text(String(inv.who.prefix(1))).font(.hs(14, .semibold)).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            D(inv.who).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                            if !isMine {
                                Button {
                                    Task { await follow.toggle(inv.uid) }
                                } label: {
                                    T(isFollowed ? tr("Following") : tr("Follow")).font(.hs(10, .semibold))
                                        .foregroundStyle(isFollowed ? HS.textMuted : HS.faith)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Capsule().stroke(isFollowed ? HS.textMuted : HS.faith, lineWidth: 1))
                                }.buttonStyle(.plain)
                            }
                        }
                        HStack(spacing: 4) {
                            Text(inv.activityKind.emoji)
                            D(inv.activityKind.label).font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                    }
                    Spacer()
                    Menu {
                        if isMine {
                            Button(tr("Remove invite"), role: .destructive) { deletingInvite = inv }
                        }
                        // non-owner: nothing (no report needed; invites expire and are benign)
                    } label: { Image(systemName: "ellipsis").foregroundStyle(HS.textMuted).frame(width: 28, height: 28) }
                }

                // Note
                D(inv.note).font(.hs(14)).foregroundStyle(HS.text).lineSpacing(4)

                // Meta: time + place
                HStack(spacing: 14) {
                    if let date = inv.scheduledDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(HS.textMuted)
                            D(date.formatted(.dateTime.weekday(.abbreviated).hour().minute())).font(.hs(12)).foregroundStyle(HS.textSecondary)
                        }
                    }
                    if !inv.locationHint.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin").font(.system(size: 11)).foregroundStyle(HS.textMuted)
                            D(inv.locationHint).font(.hs(12)).foregroundStyle(HS.textSecondary)
                        }
                    }
                    Spacer()
                    // Expires label
                    let minsLeft = max(0, (inv.expiresAt - Firestore.nowMs) / 60_000)
                    if minsLeft < 60 {
                        D(tr("\(minsLeft)m left")).font(.hs(10)).foregroundStyle(HS.textMuted)
                    }
                }

                // Join row
                HStack(spacing: 10) {
                    if !isMine {
                        Button {
                            if account.hasAnyPlan { Task { await model.toggleJoin(inv) } } else { paywall = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: joined ? "checkmark.circle.fill" : "figure.walk")
                                    .font(.system(size: 13))
                                T(joined ? tr("I'm in!") : tr("Join")).font(.hs(13, .semibold))
                            }
                            .foregroundStyle(joined ? HS.body : HS.faith)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(joined ? HS.body.opacity(0.12) : HS.faith.opacity(0.1)))
                        }.buttonStyle(.plain)
                    }
                    if inv.joinCount > 0 {
                        D(inv.joinCount == 1 ? tr("1 person joining") : tr("\(inv.joinCount) people joining"))
                            .font(.hs(12)).foregroundStyle(HS.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Compose Sheet

struct ComposeActivitySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ActivityKind  = .prayerWalk
    @State private var note: String        = ""
    @State private var locationHint        = ""
    @State private var hasTime             = false
    @State private var scheduledDate       = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var sending             = false

    var body: some View {
        HSSheet(title: tr("Plan an activity")) {
            VStack(alignment: .leading, spacing: 16) {
                // Activity type
                VStack(alignment: .leading, spacing: 8) {
                    T("WHAT ARE YOU PLANNING?").font(.hs(10, .semibold)).tracking(1).foregroundStyle(HS.textMuted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ActivityKind.allCases) { k in
                                Button { kind = k } label: {
                                    HStack(spacing: 4) {
                                        Text(k.emoji)
                                        T(tr(k.label)).font(.hs(13, .semibold))
                                    }
                                    .foregroundStyle(kind == k ? HS.onGold : HS.textSecondary)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Capsule().fill(kind == k ? HS.goldButton : HS.overlay(0.08)))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Note
                VStack(alignment: .leading, spacing: 6) {
                    T("DETAILS (required)").font(.hs(10, .semibold)).tracking(1).foregroundStyle(HS.textMuted)
                    TextEditor(text: $note).font(.hs(14))
                        .frame(minHeight: 90, maxHeight: 160).padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        .onChange(of: note) { _, t in if t.count > 280 { note = String(t.prefix(280)) } }
                    D("\(note.count)/280").font(.hs(10)).foregroundStyle(HS.textMuted).frame(maxWidth: .infinity, alignment: .trailing)
                }

                // When
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $hasTime.animation()) {
                        T("SET A TIME (optional)").font(.hs(10, .semibold)).tracking(1).foregroundStyle(HS.textMuted)
                    }.tint(HS.gold)
                    if hasTime {
                        DatePicker("", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact).labelsHidden()
                            .colorScheme(.dark)
                    }
                }

                // Where
                VStack(alignment: .leading, spacing: 6) {
                    T("NEIGHBORHOOD / AREA (optional)").font(.hs(10, .semibold)).tracking(1).foregroundStyle(HS.textMuted)
                    TextField(tr("e.g. Downtown, Eastside"), text: $locationHint)
                        .font(.hs(14)).padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        .onChange(of: locationHint) { _, t in if t.count > 80 { locationHint = String(t.prefix(80)) } }
                    D("Your exact location is never shared.").font(.hs(10)).foregroundStyle(HS.textMuted)
                }

                GoldButton(title: tr("Post invite")) {
                    sending = true
                    let ms = hasTime ? Int64(scheduledDate.timeIntervalSince1970 * 1000) : 0
                    Task {
                        if await ActivityModel.shared.post(kind: kind, note: note, locationHint: locationHint, scheduledAt: ms, name: store.name) {
                            dismiss()
                        }
                        sending = false
                    }
                }
                .disabled(sending || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let m = ActivityModel.shared.message {
                    D(m).font(.hs(12)).foregroundStyle(HS.gold)
                }

                D("Your invite disappears automatically after 24 hours.").font(.hs(11)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            .padding(24)
        }
    }
}
