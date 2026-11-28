import SwiftUI

/// Family Faith Relay, live from Firestore (`familyRelays`), shared with Android. The family passes one baton a day:
/// whoever holds it prays, reads the Bible and walks a little, then passes it on, and the family streak grows.
/// Starting a relay comes with the Faith plan; joining takes any plan (firestore.rules).
struct FamilyRelay: Identifiable {
    let id: String
    var name, inviteCode, createdBy, lastBatonPassDate: String
    var memberUids, memberNames: [String]
    var currentHolderIndex, streakDays: Int
    init(_ d: FSDoc) {
        id = d.id; name = d["name"].string; inviteCode = d["inviteCode"].string; createdBy = d["createdBy"].string
        lastBatonPassDate = d["lastBatonPassDate"].string
        memberUids = d["memberUids"].array.map(\.string); memberNames = d["memberNames"].array.map(\.string)
        currentHolderIndex = Int(d["currentHolderIndex"].int); streakDays = Int(d["streakDays"].int)
    }
    var holderUid: String { memberUids.isEmpty ? "" : memberUids[((currentHolderIndex % memberUids.count) + memberUids.count) % memberUids.count] }
    func name(_ uid: String) -> String {
        guard let i = memberUids.firstIndex(of: uid), i < memberNames.count, !memberNames[i].isEmpty else { return tr("A family member") }
        return memberNames[i]
    }
    /// The streak still stands if the baton moved today or yesterday.
    var liveStreak: Int {
        let today = AppStore.dayKey()
        return lastBatonPassDate == today || lastBatonPassDate == CircleMath.shift(today, -1) ? streakDays : 0
    }
}

struct BatonPass: Identifiable { let id, name: String; let steps: Int64; let at: Int64 }

@MainActor
final class RelayModel: ObservableObject {
    static let shared = RelayModel()
    @Published private(set) var relays: [FamilyRelay] = []
    @Published private(set) var log: [BatonPass] = []
    @Published private(set) var loading = true
    @Published var message: String?
    var uid: String? { AccountStore.shared.uid }

    func load() async {
        guard let uid else { loading = false; return }
        relays = ((try? await Firestore.query("familyRelays", filters: [.init(field: "memberUids", op: "ARRAY_CONTAINS", value: .string(uid))], limit: 5)) ?? []).map(FamilyRelay.init)
        if let r = relays.first {
            log = ((try? await Firestore.query("batonLog", parent: "familyRelays/\(r.id)", orderBy: "passedAt", limit: 14)) ?? []).map {
                BatonPass(id: $0.id, name: $0["displayName"].string, steps: $0["stepsContributed"].int, at: $0["passedAt"].int)
            }
        }
        loading = false
    }

    func create(name: String, me: String) async {
        guard let uid else { return }
        let id = Firestore.newId(), code = InviteCode.make("RELAY")
        do {
            try await Firestore.commit([.set("familyRelays/\(id)", [
                "name": .string(String((name.isEmpty ? tr("Our family") : name).prefix(100))), "memberUids": .array([.string(uid)]),
                "memberNames": .array([.string(String((me.isEmpty ? tr("A family member") : me).prefix(100)))]), "inviteCode": .string(code),
                "createdBy": .string(uid), "currentHolderIndex": .int(0), "streakDays": .int(0), "lastBatonPassAt": .int(0),
                "lastBatonPassDate": .string(""), "createdAt": .int(Firestore.nowMs)], mustNotExist: true)])
            try await InviteCode.register(code, type: "familyRelay", target: id, uid: uid)
        } catch { message = error.wallText }
        await load()
    }

    func join(code: String, me: String) async {
        guard let uid else { return }
        guard let inv = await InviteCode.resolve(code), inv.type == "familyRelay" else { message = tr("That code wasn't found. Check it and try again."); return }
        do {
            try await Firestore.commit([.update("familyRelays/\(inv.target)", ["joinCode": .string(InviteCode.clean(code))],
                                                unions: ["memberUids": [.string(uid)], "memberNames": [.string(String((me.isEmpty ? tr("A family member") : me).prefix(100)))]])])
        } catch { message = error.wallText }
        await load()
    }

    static var checklist: [(String, Bool)] {
        let today = AppStore.dayKey()
        let prayed = ((UserDefaults.standard.dictionary(forKey: "prayerLog") as? [String: [Bool]])?[today] ?? []).contains(true)
        let read = (UserDefaults.standard.stringArray(forKey: "readDays") ?? []).contains(today)
        let steps = StepsModel.shared.stepsByDay[today] ?? 0
        return [("Pray today", prayed), ("Read the Bible today", read), ("Walk a few steps", steps > 0)]
    }

    func pass(_ r: FamilyRelay, me: String) async {
        guard let uid else { return }
        guard Self.checklist.allSatisfy(\.1) else { message = tr("Finish today's prayer, Bible reading and a few steps first."); return }
        let today = AppStore.dayKey()
        let consecutive = r.lastBatonPassDate.isEmpty || r.lastBatonPassDate == today || r.lastBatonPassDate == CircleMath.shift(today, -1)
        let streak = consecutive ? r.streakDays + 1 : 1
        let now = Firestore.nowMs
        do {
            try await Firestore.commit([
                .set("familyRelays/\(r.id)/batonLog/\(Firestore.newId())", ["uid": .string(uid), "displayName": .string(String(me.prefix(100))),
                     "stepsContributed": .int(Int64(StepsModel.shared.stepsByDay[today] ?? 0)), "faithComplete": .bool(true), "passedAt": .int(now)]),
                .update("familyRelays/\(r.id)", ["currentHolderIndex": .int(Int64((r.currentHolderIndex + 1) % max(1, r.memberUids.count))),
                     "streakDays": .int(Int64(streak)), "lastBatonPassAt": .int(now), "lastBatonPassDate": .string(today)]),
            ])
            Points.award(15)
        } catch { message = error.wallText }
        await load()
    }

    func leave(_ r: FamilyRelay) async {
        guard let uid, let i = r.memberUids.firstIndex(of: uid) else { return }
        var uids = r.memberUids, names = r.memberNames
        uids.remove(at: i); if i < names.count { names.remove(at: i) }
        do {
            try await Firestore.commit([.update("familyRelays/\(r.id)", ["memberUids": .array(uids.map { .string($0) }), "memberNames": .array(names.map { .string($0) }),
                                                                          "currentHolderIndex": .int(Int64(min(r.currentHolderIndex, max(0, uids.count - 1))))])])
        } catch { message = error.wallText }
        await load()
    }
}

/// Android's FamilyRelayScreen.
struct FamilyRelayView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = RelayModel.shared
    @State private var name = ""
    @State private var joining = false
    @State private var code = ""

    var body: some View {
        ZStack { HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        D(tr("Family Relay")).font(.hs(28)).foregroundStyle(HS.text)
                        ItalicAccent(text: "One streak. The whole family.", size: 15)
                    }
                    .padding(.horizontal, 20).padding(.top, 58)
                    if let m = model.message { D(m).font(.hs(12)).foregroundStyle(HS.gold).padding(.horizontal, 20).padding(.top, 10).onTapGesture { model.message = nil } }
                    if model.loading { ProgressView().tint(HS.gold).frame(maxWidth: .infinity).padding(30) }
                    else if let r = model.relays.first { relay(r) }
                    else { start }
                    Spacer().frame(height: 100)
                }
            }
            .refreshable { await model.load() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .task { await model.load() }
        .alert(tr("Join with a code"), isPresented: $joining) {
            TextField(tr("Code"), text: $code).textInputAutocapitalization(.characters)
            Button(tr("Join")) { let c = code; code = ""; Task { await model.join(code: c, me: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
    }

    private var start: some View {
        VStack(spacing: 12) {
            Gated(feature: .familyRelay) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        T("Start your family's relay").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                        T("Each day the one holding the baton prays, reads and walks, then passes it on. Miss a day and the streak starts over.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        TextField(tr("Family name"), text: $name).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                        GoldButton(title: "Start the relay") { Task { await model.create(name: name, me: store.name) } }
                    }
                }.padding(.horizontal, 20)
            }
            Button { joining = true } label: { T("Join with a code").font(.hs(14, .semibold)).foregroundStyle(HS.peach) }
            ScanQRButton(label: "Scan a relay QR code") { c in Task { await model.join(code: c, me: store.name) } }
        }
        .padding(.top, 20)
    }

    private func relay(_ r: FamilyRelay) -> some View {
        let myTurn = r.holderUid == model.uid
        let passedToday = r.lastBatonPassDate == AppStore.dayKey()
        return VStack(spacing: 14) {
            GlassCard(glow: HS.gold) {
                VStack(spacing: 8) {
                    D(r.name).font(.hs(13, .semibold)).tracking(0.8).foregroundStyle(HS.peach)
                    D("\(r.liveStreak)").font(.hs(48, .bold)).foregroundStyle(HS.text).monospacedDigit()
                    T(r.liveStreak == 1 ? "day" : "days straight").font(.hs(14)).foregroundStyle(HS.textMuted)
                    D(myTurn ? tr("🕯️ You hold the baton") : tr("🕯️ {0} holds the baton").replacingOccurrences(of: "{0}", with: r.name(r.holderUid)))
                        .font(.hs(14, .semibold)).foregroundStyle(HS.gold)
                }.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20).padding(.top, 20)

            if myTurn && !passedToday {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(RelayModel.checklist, id: \.0) { item, done in
                            HStack { Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? HS.body : HS.textMuted); T(item).font(.hs(14)).foregroundStyle(HS.text) }
                        }
                        GoldButton(title: "Pass the baton") { Task { await model.pass(r, me: store.name) } }
                            .disabled(!RelayModel.checklist.allSatisfy(\.1))
                    }
                }.padding(.horizontal, 20)
            }

            SectionHeader(title: "Family members").padding(.top, 6)
            ForEach(r.memberUids, id: \.self) { uid in
                GlassCard {
                    HStack(spacing: 12) {
                        Circle().fill(uid == r.holderUid ? HS.goldButton.opacity(0.3) : HS.overlay(0.06)).frame(width: 36, height: 36)
                            .overlay(Text(uid == r.holderUid ? "🕯️" : String(r.name(uid).prefix(1))).font(.hs(14, .semibold)).foregroundStyle(HS.text))
                        D(uid == model.uid ? tr("You") : r.name(uid)).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        Spacer()
                    }
                }.padding(.horizontal, 20)
            }

            if !model.log.isEmpty {
                SectionHeader(title: "Recent passes").padding(.top, 6)
                ForEach(model.log) { p in
                    HStack {
                        D(p.name).font(.hs(13)).foregroundStyle(HS.text)
                        Spacer()
                        D(Date(timeIntervalSince1970: Double(p.at) / 1000).formatted(.relative(presentation: .named).locale(I18n.shared.locale))).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }.padding(.horizontal, 24)
                }
            }

            ShareLink(item: InviteCode.link(r.inviteCode), message: Text(tr("Join our family's HolySteps relay: {0}").replacingOccurrences(of: "{0}", with: r.name))) {
                D(tr("Invite (code {0})").replacingOccurrences(of: "{0}", with: r.inviteCode)).font(.hs(14, .semibold)).foregroundStyle(HS.gold)
            }.padding(.top, 8)
            ShowQRButton(code: r.inviteCode)
            if r.createdBy != model.uid {
                Button { Task { await model.leave(r) } } label: { T("Leave the relay").font(.hs(13)).foregroundStyle(.red.opacity(0.8)) }
            }
        }
    }
}
