import SwiftUI

/// Android's weekly Leagues (LeaguesScreen.kt, AppViewModel.loadLeague/syncLeagueProgress): each week you're placed
/// with up to 20 people at your tier, ranked by steps plus 1,500 a day for active days. At the week's end the top 3
/// move up and the bottom 3 move down. Same Firestore documents and rules as Android, so both phones share leagues.
enum LeagueTiers {
    static let names = [1: "Cedar of Lebanon", 2: "Olive Tree", 3: "Fig Tree", 4: "Lily of the Field", 5: "Mustard Seed", 6: "Good Soil"]
    static let emoji = [1: "🌲", 2: "🫒", 3: "🍃", 4: "🌸", 5: "🌱", 6: "🌾"]
    static let start = 5, capacity = 20, promote = 3, demote = 3
    static func name(_ t: Int) -> String { names[min(max(t, 1), 6)] ?? "Mustard Seed" }
    /// This week's Monday, as this phone's calendar sees it.
    static func weekStart(_ d: Date = Date()) -> String {
        var c = Calendar(identifier: .gregorian); c.firstWeekday = 2
        return AppStore.dayKey(c.dateInterval(of: .weekOfYear, for: d)?.start ?? d)
    }
}

struct LeagueStanding: Identifiable { let id, name: String; let steps, active: Int; var score: Int { steps + active * 1500 } }

@MainActor
final class LeagueModel: ObservableObject {
    @AppStorage("leagueTier") var tier = LeagueTiers.start
    @AppStorage("leagueId") var leagueId = ""
    @AppStorage("leagueWeek") var week = ""
    @Published var standings: [LeagueStanding] = []
    @Published var loading = true
    @Published var result = ""
    var uid: String? { AccountStore.shared.uid }

    func load(name: String) async {
        guard let uid else { loading = false; return }
        let now = LeagueTiers.weekStart()
        if !week.isEmpty, week != now, !leagueId.isEmpty {
            let rows = (try? await Firestore.query("members", parent: "leagues/\(leagueId)", limit: 30)) ?? []
            let ranked = rows.sorted { $0["steps"].int + $0["workouts"].int * 1500 > $1["steps"].int + $1["workouts"].int * 1500 }
            if let r = ranked.firstIndex(where: { $0.id == uid }) {
                if r < LeagueTiers.promote && tier > 1 { tier -= 1; result = tr("Promoted to \(tr(LeagueTiers.name(tier)))! Keep it up.") }
                else if ranked.count > LeagueTiers.demote && r >= ranked.count - LeagueTiers.demote && tier < 6 {
                    tier += 1; result = tr("Moved to \(tr(LeagueTiers.name(tier))) this week. Every step still counts.")
                }
            }
        }
        if week != now || leagueId.isEmpty { leagueId = await findOrCreate(uid: uid, week: now); week = now }
        await sync(name: name)
        await refresh()
    }

    private func findOrCreate(uid: String, week: String) async -> String {
        let docs = (try? await Firestore.query("leagues", filters: [.init(field: "tier", op: "EQUAL", value: .int(Int64(tier))),
                                                                     .init(field: "weekStart", op: "EQUAL", value: .string(week))],
                                               orderBy: "createdAt", limit: 15)) ?? []
        for d in docs {
            let m = d["memberUids"].array.map(\.string)
            if m.contains(uid) { return d.id }
            if m.count < LeagueTiers.capacity,
               (try? await Firestore.commit([.update("leagues/\(d.id)", [:], unions: ["memberUids": [.string(uid)]])])) != nil { return d.id }
        }
        let id = Firestore.newId()
        do {
            try await Firestore.commit([.set("leagues/\(id)", ["tier": .int(Int64(tier)), "weekStart": .string(week),
                                                               "memberUids": .array([.string(uid)]), "createdAt": .int(Firestore.nowMs)], mustNotExist: true)])
            return id
        } catch { return "" }
    }

    /// This week's steps (Apple Health plus walks logged by hand) and days at half the goal or more, never more than the
    /// rules take for an unsigned phone (15,000 a day for the days gone by).
    func sync(name: String) async {
        guard let uid, !leagueId.isEmpty else { return }
        let s = StepsModel.shared
        let days = s.stepsByDay.filter { $0.key >= week }
        let steps = days.values.reduce(0, +)
        let goal = max(1, UserDefaults.standard.integer(forKey: "stepGoal") == 0 ? 8000 : UserDefaults.standard.integer(forKey: "stepGoal"))
        let active = min(7, days.values.filter { $0 >= goal / 2 }.count)
        let since = AppStore.date(fromKey: week).map { CycleLogic.days($0, Date()) } ?? 0
        let capped = min(steps, 15_000 * min(since + 2, 8))
        try? await Firestore.commit([.set("leagues/\(leagueId)/members/\(uid)", [
            "displayName": .string(String(name.prefix(100))), "steps": .int(Int64(capped)), "workouts": .int(Int64(active)), "joinedAt": .int(Firestore.nowMs)])])
    }

    func refresh() async {
        guard !leagueId.isEmpty else { loading = false; return }
        let rows = (try? await Firestore.query("members", parent: "leagues/\(leagueId)", limit: 30)) ?? []
        standings = rows.map { LeagueStanding(id: $0.id, name: $0["displayName"].string, steps: Int($0["steps"].int), active: Int($0["workouts"].int)) }
            .sorted { $0.score > $1.score }
        loading = false
    }
}

struct LeaguesView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var m = LeagueModel()

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("🏆 WEEKLY LEAGUE").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xD9B49F))
                    D("\(LeagueTiers.emoji[m.tier] ?? "🌱") " + tr(LeagueTiers.name(m.tier))).font(.hs(26)).foregroundStyle(HS.text)
                    T("Up to 20 walkers at your level, Monday to Sunday. Steps count, plus 1,500 for each day you reach half your step goal. The top 3 move up and the bottom 3 move down.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if !m.result.isEmpty { D(m.result).font(.hs(14, .semibold)).foregroundStyle(HS.readable(0x10B981)) }
                    HStack(spacing: 4) {
                        ForEach((1...6).reversed(), id: \.self) { t in
                            D(LeagueTiers.emoji[t] ?? "").font(.system(size: t == m.tier ? 26 : 16)).opacity(t == m.tier ? 1 : 0.45).frame(maxWidth: .infinity)
                        }
                    }
                    if m.loading { ProgressView().frame(maxWidth: .infinity) }
                    else if AccountStore.shared.uid == nil { T("Sign in to join this week's league.").font(.hs(13)).foregroundStyle(HS.textMuted) }
                    ForEach(Array(m.standings.enumerated()), id: \.element.id) { i, s in
                        let me = s.id == m.uid
                        let zone: UInt32 = i < LeagueTiers.promote ? 0x10B981 : (m.standings.count > LeagueTiers.demote && i >= m.standings.count - LeagueTiers.demote ? 0xF43F5E : 0xA8A29E)
                        HStack {
                            D("\(i + 1)").font(.hs(14, .bold)).foregroundStyle(HS.readable(zone)).frame(width: 26)
                            D(me ? tr("You") : (s.name.isEmpty ? tr("A walker") : s.name)).font(.hs(14, me ? .bold : .regular)).foregroundStyle(HS.text)
                            Spacer()
                            VStack(alignment: .trailing) {
                                D(s.steps.formatted() + " " + tr("steps")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                                D(tr("\(s.active) active days")).font(.hs(10)).foregroundStyle(HS.textMuted)
                            }
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(me ? Color(hex: 0xD9B49F).opacity(0.15) : HS.text.opacity(0.04)))
                    }
                    T("Steps come from Apple Health. Each day counts up to 15,000 steps here.").font(.hs(11)).foregroundStyle(HS.textMuted)
                }.padding(20)
            }.refreshable { await m.sync(name: store.name); await m.refresh() }
        }
        .task { await m.load(name: store.name) }
    }
}
