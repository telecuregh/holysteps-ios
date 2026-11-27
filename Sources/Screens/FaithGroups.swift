import SwiftUI
import HealthKit

/// Android's Groups (FaithLeaguesScreen.kt): a family, small group or church of up to 100, joined by code. The week is
/// counted together: days prayed, acts of service, devotionals and verses. Each member's own numbers stay private
/// unless they choose to show them. The creator can set a walking goal the group does together. Same Firestore
/// documents and rules as Android.
enum GroupKind: String, CaseIterable { case FAMILY, SMALL_GROUP, CHURCH
    var label: String { switch self { case .FAMILY: "Family"; case .SMALL_GROUP: "Small Group"; case .CHURCH: "Church" } }
    var emoji: String { switch self { case .FAMILY: "👪"; case .SMALL_GROUP: "🤝"; case .CHURCH: "⛪" } }
}

enum HealthSteps {
    /// Steps from Apple Health since the start of a day (dayKey), plus walks logged by hand.
    static func since(_ key: String) async -> Int {
        guard let from = AppStore.date(fromKey: key) else { return 0 }
        var total = 0
        if HKHealthStore.isHealthDataAvailable(), let t = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let store = HKHealthStore()
            total = await withCheckedContinuation { (c: CheckedContinuation<Int, Never>) in
                store.execute(HKStatisticsQuery(quantityType: t, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: from, end: Date()),
                                                options: .cumulativeSum) { _, s, _ in c.resume(returning: Int(s?.sumQuantity()?.doubleValue(for: .count()) ?? 0)) })
            }
        }
        let manual = (UserDefaults.standard.dictionary(forKey: "manualSteps") as? [String: Int] ?? [:]).filter { $0.key >= key }.values.reduce(0, +)
        return total + manual
    }
}

struct GroupStat: Identifiable { let id, name: String; let service, prayer, devotional, verse: Int; let shared: Bool
    var score: Int { service * 3 + prayer + devotional + verse } }

@MainActor
final class FaithGroupsModel: ObservableObject {
    @Published var groups: [FSDoc] = []
    @Published var stats: [GroupStat] = []
    @Published var mission: [(name: String, steps: Int, shared: Bool, me: Bool)] = []
    @Published var loading = true
    @Published var message = ""
    @AppStorage("groupsShareMine") var shareMine = false
    var uid: String? { AccountStore.shared.uid }

    func load() async {
        guard let uid else { loading = false; return }
        groups = (try? await Firestore.query("faithLeagues", filters: [.init(field: "memberUids", op: "ARRAY_CONTAINS", value: .string(uid))], limit: 50)) ?? []
        loading = false
    }

    func create(name: String, kind: GroupKind) async {
        guard let uid else { message = tr("Still connecting. Try again in a moment."); return }
        let n = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)); guard !n.isEmpty else { return }
        let id = Firestore.newId(), code = InviteCode.make("FAITH")
        do {
            try await Firestore.commit([.set("faithLeagues/\(id)", [
                "name": .string(n), "type": .string(kind.rawValue), "memberUids": .array([.string(uid)]), "inviteCode": .string(code),
                "createdBy": .string(uid), "weekStart": .string(LeagueTiers.weekStart()), "mvpUid": .string(""), "createdAt": .int(Firestore.nowMs),
                "missionName": .string(""), "missionKm": .int(0), "missionWhy": .string(""), "missionStart": .string("")], mustNotExist: true)])
            try await InviteCode.register(code, type: "faithLeague", target: id, uid: uid)
        } catch FSError.denied { message = tr("Starting a group needs a plan."); return }
        catch { message = tr("Couldn't create the group. Check your connection and try again."); return }
        await load()
    }

    func join(_ code: String) async {
        guard let uid else { message = tr("Still connecting. Try again in a moment."); return }
        guard let inv = await InviteCode.resolve(code), inv.type == "faithLeague" else { message = tr("That code wasn't found. Check it and try again."); return }
        do { try await Firestore.commit([.update("faithLeagues/\(inv.target)", ["joinCode": .string(InviteCode.clean(code))], unions: ["memberUids": [.string(uid)]])]) }
        catch FSError.denied { message = tr("Joining a group needs a plan."); return }
        catch { message = tr("Couldn't join. Check your connection and try again."); return }
        await load()
    }

    func leave(_ g: FSDoc) async {
        guard let uid else { return }
        try? await Firestore.commit([.delete("faithLeagues/\(g.id)/weeklyStats/\(uid)")])
        try? await Firestore.commit([.delete("faithLeagues/\(g.id)/missionSteps/\(uid)")])
        do { try await Firestore.commit([.update("faithLeagues/\(g.id)", ["memberUids": .array(g["memberUids"].array.filter { $0.string != uid })])]) }
        catch { message = tr("Couldn't leave. Check your connection and try again.") }
        await load()
    }

    /// This week's own counts, from what was done on this phone since Monday. Only counts are sent, never content.
    static func myWeek() -> (prayer: Int, devotional: Int, verse: Int, service: Int) {
        let w = LeagueTiers.weekStart(), log = ActivityLog.shared.days.filter { $0.key >= w }
        let prayed = Set((UserDefaults.standard.dictionary(forKey: "prayerLog") as? [String: [Bool]] ?? [:]).filter { $0.key >= w && $0.value.contains(true) }.keys)
            .union(log.filter { $0.value.contains("prayerAudio") }.keys).count
        let dev = log.filter { $0.value.contains("sermon") || $0.value.contains("journal") }.count
        let verse = log.filter { $0.value.contains("verse") || $0.value.contains("quiz") }.count
        let service = UserDefaults.standard.string(forKey: "serviceWeek") == w ? UserDefaults.standard.integer(forKey: "serviceActs") : 0
        return (min(prayed, 7), min(dev, 7), min(verse, 7), min(service, 300))
    }
    static func logService() {
        let w = LeagueTiers.weekStart()
        let n = UserDefaults.standard.string(forKey: "serviceWeek") == w ? UserDefaults.standard.integer(forKey: "serviceActs") : 0
        UserDefaults.standard.set(w, forKey: "serviceWeek"); UserDefaults.standard.set(n + 1, forKey: "serviceActs")
    }

    func open(_ g: FSDoc, name: String) async {
        guard let uid else { return }
        let now = LeagueTiers.weekStart()
        let rows = (try? await Firestore.query("weeklyStats", parent: "faithLeagues/\(g.id)", limit: 120)) ?? []
        if g["weekStart"].string != now {
            let mvp = rows.max { ($0["serviceActs"].int * 3 + $0["prayerCount"].int) < ($1["serviceActs"].int * 3 + $1["prayerCount"].int) }?.id ?? ""
            try? await Firestore.commit([.update("faithLeagues/\(g.id)", ["weekStart": .string(now), "mvpUid": .string(mvp)])])
        }
        let w = Self.myWeek()
        try? await Firestore.commit([.set("faithLeagues/\(g.id)/weeklyStats/\(uid)", [
            "displayName": .string(String(name.prefix(100))), "serviceActs": .int(Int64(w.service)), "prayerCount": .int(Int64(w.prayer)),
            "devotionalCount": .int(Int64(w.devotional)), "verseCount": .int(Int64(w.verse)), "shared": .bool(shareMine)])])
        let fresh = (try? await Firestore.query("weeklyStats", parent: "faithLeagues/\(g.id)", limit: 120)) ?? []
        stats = fresh.map { GroupStat(id: $0.id, name: $0["displayName"].string, service: Int($0["serviceActs"].int), prayer: Int($0["prayerCount"].int),
                                      devotional: Int($0["devotionalCount"].int), verse: Int($0["verseCount"].int), shared: $0["shared"].bool) }
        let start = g["missionStart"].string
        if !start.isEmpty {
            let steps = await HealthSteps.since(start)
            let since = AppStore.date(fromKey: start).map { CycleLogic.days($0, Date()) } ?? 0
            try? await Firestore.commit([.set("faithLeagues/\(g.id)/missionSteps/\(uid)", [
                "displayName": .string(String(name.prefix(100))), "steps": .int(Int64(min(steps, 15_000 * (since + 2)))), "start": .string(start), "shared": .bool(shareMine)])])
            let ms = (try? await Firestore.query("missionSteps", parent: "faithLeagues/\(g.id)", limit: 120)) ?? []
            mission = ms.filter { $0["start"].string == start }.map { ($0["displayName"].string, Int($0["steps"].int), $0["shared"].bool, $0.id == uid) }
        } else { mission = [] }
    }

    func setMission(_ g: FSDoc, name: String, km: Int, why: String) async {
        let n = String(name.prefix(60)), w = String(why.prefix(200))
        let fields: [String: FSValue] = n.isEmpty ? ["missionName": .string(""), "missionKm": .int(0), "missionWhy": .string(""), "missionStart": .string("")]
            : ["missionName": .string(n), "missionKm": .int(Int64(max(1, min(km, 100_000)))), "missionWhy": .string(w), "missionStart": .string(AppStore.dayKey())]
        do { try await Firestore.commit([.update("faithLeagues/\(g.id)", fields)]) } catch { message = tr("Couldn't save the goal.") }
        await load()
    }
}

struct FaithGroupsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var m = FaithGroupsModel()
    @State private var joining = false
    @State private var creating = false
    @State private var code = ""
    @State private var name = ""
    @State private var kind = GroupKind.SMALL_GROUP

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("👥 GROUPS").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xD9B49F))
                    T("Grow together").font(.hs(24)).foregroundStyle(HS.text)
                    T("Your family, small group or church, together each week: days of prayer, acts of service, devotionals and verses. Your own numbers stay private unless you choose to show them.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if m.loading { ProgressView().frame(maxWidth: .infinity) }
                    else if m.groups.isEmpty { T("No groups yet").font(.hs(15, .semibold)).foregroundStyle(HS.textMuted) }
                    ForEach(m.groups) { g in
                        NavigationLink { GroupDetailView(m: m, group: g).environmentObject(store) } label: {
                            GlassCard {
                                HStack {
                                    D(GroupKind(rawValue: g["type"].string)?.emoji ?? "👥").font(.system(size: 26))
                                    VStack(alignment: .leading) {
                                        D(g["name"].string).font(.hs(15, .bold)).foregroundStyle(HS.text)
                                        D(tr("\(g["memberUids"].array.count) members")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                    }
                                    Spacer(); T("Open ›").font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    HStack {
                        Button(tr("Join with code")) { joining = true }.buttonStyle(.bordered)
                        GoldButton(title: "Create a group") { creating = true }
                    }
                    if !m.message.isEmpty { D(m.message).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }.padding(20)
            }.refreshable { await m.load() }
        }
        .task { await m.load() }
        .alert(tr("Join a group"), isPresented: $joining) {
            TextField("FAITH-…", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button(tr("Join")) { let c = code; code = ""; Task { await m.join(c) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
        .sheet(isPresented: $creating) {
            NavigationStack {
                Form {
                    TextField(tr("Like: Morning Walkers"), text: $name)
                    Picker(tr("Kind"), selection: $kind) { ForEach(GroupKind.allCases, id: \.self) { k in Text("\(k.emoji) \(tr(k.label))").tag(k) } }
                }
                .navigationTitle(tr("Create a group"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button(tr("Create")) { let n = name; name = ""; creating = false; Task { await m.create(name: n, kind: kind) } } }
                    ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { creating = false } }
                }
            }.presentationDetents([.medium])
        }
    }
}

private struct GroupDetailView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var m: FaithGroupsModel
    let group: FSDoc
    @Environment(\.dismiss) private var dismiss
    @State private var leaving = false
    @State private var goal = false
    @State private var gName = ""
    @State private var gKm = "50"
    @State private var gWhy = ""

    private var isOwner: Bool { group["createdBy"].string == m.uid }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    D(group["name"].string).font(.hs(24)).foregroundStyle(HS.text)
                    HStack {
                        D(group["inviteCode"].string).font(.system(.callout, design: .monospaced)).foregroundStyle(HS.text).textSelection(.enabled)
                        ShareLink(item: group["inviteCode"].string, message: Text(tr("Join my HolySteps group. Open Faith, then Groups, tap \"Join with code\" and enter it."))) { Image(systemName: "square.and.arrow.up") }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            T("🙏 Together this week").font(.hs(15, .bold)).foregroundStyle(HS.text)
                            HStack {
                                stat(m.stats.reduce(0) { $0 + $1.prayer }, "days of prayer")
                                stat(m.stats.reduce(0) { $0 + $1.service }, "acts of service")
                                stat(group["memberUids"].array.count, "members")
                            }
                            T("Pray, read, or log an act of service and it adds to the group's week.").font(.hs(11)).foregroundStyle(HS.textMuted)
                            Button(tr("+ I did an act of service")) { FaithGroupsModel.logService(); Task { await m.open(group, name: store.name) } }.buttonStyle(.bordered)
                        }
                    }
                    Toggle(tr("Show my numbers to my groups"), isOn: Binding(get: { m.shareMine }, set: { m.shareMine = $0; Task { await m.open(group, name: store.name) } }))
                        .font(.hs(13))
                    let mvp = group["mvpUid"].string
                    ForEach(m.stats.sorted { $0.score > $1.score }) { s in
                        HStack {
                            D(s.id == m.uid ? tr("You") : s.name).font(.hs(14, s.id == m.uid ? .bold : .regular)).foregroundStyle(HS.text)
                            if s.id == mvp { D("⭐") }
                            Spacer()
                            if s.id == m.uid { D(tr("\(s.prayer) days prayed · \(s.service) acts of service")).font(.hs(11)).foregroundStyle(HS.textMuted) }
                            else if s.shared { D(tr("\(s.prayer) days prayed · \(s.service) acts of service")).font(.hs(11)).foregroundStyle(HS.textMuted) }
                            else if s.score > 0 { T("✓ active this week").font(.hs(11)).foregroundStyle(HS.readable(0x10B981)) }
                        }.padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.text.opacity(0.04)))
                    }
                    let mName = group["missionName"].string
                    if !mName.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                T("🚶 Walking now").font(.hs(12, .bold)).foregroundStyle(HS.readable(0x10B981))
                                D(mName).font(.hs(16, .bold)).foregroundStyle(HS.text)
                                if !group["missionWhy"].string.isEmpty { D(group["missionWhy"].string).font(.hs(12)).foregroundStyle(HS.textSecondary) }
                                let km = Double(m.mission.reduce(0) { $0 + $1.steps }) * BibleWalk.strideKm, goalKm = Double(max(1, group["missionKm"].int))
                                ProgressView(value: min(1, km / goalKm)).tint(.green)
                                D(tr("\(String(format: "%.1f", km)) of \(Int(goalKm)) km together")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                if isOwner { Button(tr("End this walking goal")) { Task { await m.setMission(group, name: "", km: 0, why: ""); dismiss() } }.font(.hs(12)) }
                            }
                        }
                    } else if isOwner {
                        Button(tr("Set a walking goal for the group")) { goal = true }.buttonStyle(.bordered)
                    }
                    if !isOwner { Button(tr("Leave this group"), role: .destructive) { leaving = true }.font(.hs(13)) }
                }.padding(20)
            }.refreshable { await m.open(group, name: store.name) }
        }
        .task { await m.open(group, name: store.name) }
        .alert(tr("Leave this group?"), isPresented: $leaving) {
            Button(tr("Leave"), role: .destructive) { Task { await m.leave(group); dismiss() } }
            Button(tr("Stay"), role: .cancel) {}
        } message: { T("Your steps are taken out of the group's goal. You can join again with the code.") }
        .alert(tr("A walking goal"), isPresented: $goal) {
            TextField(tr("Like: Walk to Jerusalem"), text: $gName)
            TextField(tr("Kilometers"), text: $gKm).keyboardType(.numberPad)
            TextField(tr("Why (optional)"), text: $gWhy)
            Button(tr("Start")) { Task { await m.setMission(group, name: gName, km: Int(gKm) ?? 50, why: gWhy); dismiss() } }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("Everyone's steps from today count toward it.") }
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack { D("\(n)").font(.hs(22, .bold)).foregroundStyle(HS.text); T(label).font(.hs(10)).foregroundStyle(HS.textMuted) }.frame(maxWidth: .infinity)
    }
}
