import SwiftUI

/// Habit circles and friend streaks, live from Firestore (`habitCircles`), the same circles as Android.
/// Up to 20 people share one daily habit; the group streak grows on days most of the circle (60%, never fewer
/// than two) checks in. Where the phone can see the habit happen (steps, prayer, reading, a workout) the
/// check-in is verified ✓. A friend streak (two people, pray or read) is free; other circles need a plan,
/// and your own custom habit comes with Complete.
enum HabitProof: String, CaseIterable {
    case MANUAL, STEP_GOAL, PRAYER, WORKOUT, SCRIPTURE, CHECKIN, SANCTUARY, PRAY_AND_MOVE, PRAY_OR_READ
    var needs: String {
        switch self {
        case .MANUAL: "Check in when you've done it"
        case .STEP_GOAL: "Reach your daily step goal"
        case .PRAYER: "Log a prayer in HolySteps"
        case .WORKOUT: "Finish a guided workout or walk"
        case .SCRIPTURE: "Read today's word or devotional"
        case .CHECKIN: "Do your daily check-in with a gratitude"
        case .SANCTUARY: "Finish a Sanctuary session"
        case .PRAY_AND_MOVE: "Log a prayer and move (workout, walk, or 2,000+ steps)"
        case .PRAY_OR_READ: "Pray or read the Bible in HolySteps"
        }
    }
}

struct HabitTemplate: Identifiable {
    let id, title, emoji, habit: String
    let days: Int
    let proof: HabitProof
    let blurb: String
    var premium = false

    static let friendStreak = HabitTemplate(id: "friend_streak", title: "Friend streak", emoji: "🔥", habit: "Pray or read the Bible every day, both of you",
                                            days: 0, proof: .PRAY_OR_READ, blurb: "Keep a streak alive together. It only grows on days you both show up.")
    static let all = [
        HabitTemplate(id: "morning_prayer_move", title: "30 Days of Morning Prayer & Movement", emoji: "🌅", habit: "Pray, then move for 10+ minutes", days: 30, proof: .PRAY_AND_MOVE, blurb: "Start every day with God and your body, together."),
        HabitTemplate(id: "step_squad", title: "Step Goal Squad", emoji: "👟", habit: "Hit your daily step goal", days: 30, proof: .STEP_GOAL, blurb: "Everyone walks, everyone counts, verified by your step counter."),
        HabitTemplate(id: "daily_word", title: "Daily Word Together", emoji: "📖", habit: "Read today's Scripture", days: 21, proof: .SCRIPTURE, blurb: "One passage a day, read side by side."),
        HabitTemplate(id: "move_every_day", title: "Move Every Day", emoji: "💪", habit: "Finish any workout or walk", days: 30, proof: .WORKOUT, blurb: "Any guided workout or prayer walk counts."),
        HabitTemplate(id: "gratitude_circle", title: "Gratitude Circle", emoji: "🙏", habit: "Check in with one gratitude", days: 21, proof: .CHECKIN, blurb: "Name one good gift every day."),
        HabitTemplate(id: "evening_peace", title: "Evening Peace", emoji: "🌙", habit: "Finish a Sanctuary session", days: 14, proof: .SANCTUARY, blurb: "Wind down together with guided audio."),
        HabitTemplate(id: "custom", title: "Your own habit", emoji: "✨", habit: "", days: 30, proof: .MANUAL, blurb: "Name any daily habit and invite your people.", premium: true),
    ]
}

struct HabitCircle: Identifiable, Equatable {
    let id: String
    var name, templateId, habit, emoji, proof, startDate, inviteCode, ownerUid: String
    var days: Int
    var memberUids: [String]
    init(_ d: FSDoc) {
        id = d.id; name = d["name"].string; templateId = d["templateId"].string; habit = d["habit"].string
        emoji = d["emoji"].string; proof = d["proof"].string; startDate = d["startDate"].string
        inviteCode = d["inviteCode"].string; ownerUid = d["ownerUid"].string; days = Int(d["days"].int)
        memberUids = d["memberUids"].array.map(\.string)
    }
    var proofType: HabitProof { HabitProof(rawValue: proof) ?? .MANUAL }
    var isFriendStreak: Bool { templateId == "friend_streak" }
}

struct HabitCheckin: Hashable { let uid, name, date: String; let verified: Bool; let note: String }
struct HabitCheer: Hashable { let fromUid, fromName, toUid, emoji, date: String }

enum InviteCode {
    static func make(_ prefix: String) -> String {
        let a = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return prefix + "-" + String((0..<10).map { _ in a.randomElement()! })
    }
    /// Accepts a bare code or a holysteps.org/join link.
    static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = t.range(of: "/", options: .backwards) { t = String(t[r.upperBound...]) }
        if let q = t.range(of: "code=") { t = String(t[q.upperBound...]) }
        return t.uppercased()
    }
    static func register(_ code: String, type: String, target: String, uid: String) async throws {
        try await Firestore.commit([.set("inviteCodes/\(code)", ["type": .string(type), "targetId": .string(target),
                                                                  "createdBy": .string(uid), "createdAt": .int(Firestore.nowMs)], mustNotExist: true)])
    }
    static func resolve(_ code: String) async -> (type: String, target: String)? {
        let c = clean(code)
        guard !c.isEmpty, !c.contains("/"), c.count <= 40, let d = try? await Firestore.get("inviteCodes/\(c)") else { return nil }
        return (d["type"].string, d["targetId"].string)
    }
    static func link(_ code: String) -> URL { URL(string: "https://holysteps.org/join/\(code)")! }
}

enum CircleMath {
    static func threshold(_ members: Int) -> Int { members <= 1 ? 1 : min(members, max(2, Int((Double(members) * 0.6).rounded(.up)))) }
    static func shift(_ day: String, _ n: Int) -> String {
        guard let d = AppStore.date(fromKey: day) else { return day }
        return AppStore.dayKey(Calendar.current.date(byAdding: .day, value: n, to: d) ?? d)
    }
    static func streak(_ c: [HabitCheckin], members: Int, today: String) -> Int {
        let by = Dictionary(grouping: c, by: \.date).mapValues { Set($0.map(\.uid)).count }
        let need = threshold(members)
        var day = (by[today] ?? 0) >= need ? today : shift(today, -1)
        var n = 0
        while (by[day] ?? 0) >= need { n += 1; day = shift(day, -1) }
        return n
    }
    static func dayNumber(_ start: String, _ today: String) -> Int? {
        guard let a = AppStore.date(fromKey: start), let b = AppStore.date(fromKey: today), today >= start else { return nil }
        return (Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0) + 1
    }

    /// Whether the phone saw today's habit happen (nil: the app can't tell, so it's on your honor).
    @MainActor static func proofMet(_ p: HabitProof) -> Bool? {
        let today = AppStore.dayKey()
        let log = ActivityLog.shared
        let prayed = ((UserDefaults.standard.dictionary(forKey: "prayerLog") as? [String: [Bool]])?[today] ?? []).contains(true)
        let read = (UserDefaults.standard.stringArray(forKey: "readDays") ?? []).contains(today) || log.did(.verse, on: today)
        let steps = StepsModel.shared.stepsByDay[today] ?? 0
        let goal = max(1, UserDefaults.standard.integer(forKey: "stepGoal") > 0 ? UserDefaults.standard.integer(forKey: "stepGoal") : 8000)
        let moved = log.did(.workoutSet, on: today) || log.did(.walk, on: today)
        switch p {
        case .MANUAL: return nil
        case .STEP_GOAL: return steps >= goal
        case .PRAYER: return prayed
        case .WORKOUT: return moved
        case .SCRIPTURE: return read
        case .CHECKIN: return log.did(.journal, on: today)
        case .SANCTUARY: return log.did(.prayerAudio, on: today) || log.did(.sleepStory, on: today)
        case .PRAY_AND_MOVE: return prayed && (moved || steps >= 2000)
        case .PRAY_OR_READ: return prayed || read
        }
    }
}

@MainActor
final class CirclesModel: ObservableObject {
    static let shared = CirclesModel()
    @Published private(set) var circles: [HabitCircle] = []
    @Published private(set) var loading = true
    @Published var message: String?

    var uid: String? { AccountStore.shared.uid }

    func load() async {
        guard let uid else { loading = false; return }
        let docs = (try? await Firestore.query("habitCircles", filters: [.init(field: "memberUids", op: "ARRAY_CONTAINS", value: .string(uid))], limit: 50)) ?? []
        circles = docs.map(HabitCircle.init).sorted { $0.name < $1.name }
        loading = false
    }

    func create(_ t: HabitTemplate, name: String, habit: String, displayName: String) async -> HabitCircle? {
        guard let uid else { message = tr("Couldn't reach HolySteps. Try again in a moment."); return nil }
        let id = Firestore.newId(), code = InviteCode.make(t.id == "friend_streak" ? "FRIEND" : "HABIT"), now = Firestore.nowMs
        let fields: [String: FSValue] = [
            "name": .string(String((name.isEmpty ? tr(t.title) : name).prefix(240))), "templateId": .string(t.id),
            "habit": .string(String((habit.isEmpty ? tr(t.habit) : habit).prefix(320))), "emoji": .string(t.emoji),
            "proof": .string(t.proof.rawValue), "days": .int(Int64(t.days)), "startDate": .string(AppStore.dayKey()),
            "memberUids": .array([.string(uid)]), "inviteCode": .string(code), "ownerUid": .string(uid), "createdAt": .int(now),
        ]
        do {
            try await Firestore.commit([.set("habitCircles/\(id)", fields, mustNotExist: true)])
            try await Firestore.commit([.set("habitCircles/\(id)/members/\(uid)", ["displayName": .string(member(displayName)), "joinedAt": .int(now), "figure": .int(Int64.random(in: 0...7))])])
            try await InviteCode.register(code, type: "habitCircle", target: id, uid: uid)
        } catch { message = error.wallText; return nil }
        await load()
        return circles.first { $0.id == id }
    }

    private func member(_ n: String) -> String { String((n.isEmpty ? tr("A friend") : n).prefix(160)) }

    func join(code: String, displayName: String) async -> Bool {
        guard let uid else { return false }
        guard let inv = await InviteCode.resolve(code), inv.type == "habitCircle" else { message = tr("That code wasn't found. Check it and try again."); return false }
        let already = (try? await Firestore.get("habitCircles/\(inv.target)"))?.fields["memberUids"]?.array.map(\.string).contains(uid) ?? false
        do {
            if !already {
                try await Firestore.commit([.update("habitCircles/\(inv.target)", ["joinCode": .string(InviteCode.clean(code))], unions: ["memberUids": [.string(uid)]])])
            }
            try await Firestore.commit([.set("habitCircles/\(inv.target)/members/\(uid)", ["displayName": .string(member(displayName)), "joinedAt": .int(Firestore.nowMs), "figure": .int(Int64.random(in: 0...7))])])
        } catch FSError.denied { message = tr("That circle is full, or joining it needs a plan."); return false }
        catch { message = error.wallText; return false }
        await load()
        return true
    }

    func leave(_ c: HabitCircle) async {
        guard let uid else { return }
        do {
            try? await Firestore.commit([.delete("habitCircles/\(c.id)/members/\(uid)")])
            try await Firestore.commit([.update("habitCircles/\(c.id)", ["memberUids": .array(c.memberUids.filter { $0 != uid }.map { .string($0) })])])
        } catch { message = error.wallText }
        await load()
    }

    // Detail

    func members(_ c: HabitCircle) async -> [String: String] {
        let d = (try? await Firestore.query("members", parent: "habitCircles/\(c.id)", limit: 25)) ?? []
        return Dictionary(uniqueKeysWithValues: d.map { ($0.id, $0["displayName"].string) })
    }

    func checkins(_ c: HabitCircle) async -> [HabitCheckin] {
        let since = CircleMath.shift(AppStore.dayKey(), -120)
        let d = (try? await Firestore.query("checkins", parent: "habitCircles/\(c.id)", filters: [.init(field: "date", op: "GREATER_THAN_OR_EQUAL", value: .string(since))], limit: 3000)) ?? []
        return d.map { HabitCheckin(uid: $0["uid"].string, name: $0["name"].string, date: $0["date"].string, verified: $0["verified"].bool, note: $0["note"].string) }
    }

    func cheers(_ c: HabitCircle) async -> [HabitCheer] {
        let d = (try? await Firestore.query("cheers", parent: "habitCircles/\(c.id)", filters: [.init(field: "date", op: "EQUAL", value: .string(AppStore.dayKey()))], limit: 400)) ?? []
        return d.map { HabitCheer(fromUid: $0["fromUid"].string, fromName: $0["fromName"].string, toUid: $0["toUid"].string, emoji: $0["emoji"].string, date: $0["date"].string) }
    }

    func checkIn(_ c: HabitCircle, name: String, note: String) async -> Bool {
        guard let uid else { return false }
        let today = AppStore.dayKey()
        let verified = CircleMath.proofMet(c.proofType) == true
        do {
            try await Firestore.commit([.set("habitCircles/\(c.id)/checkins/\(today)_\(uid)", [
                "uid": .string(uid), "name": .string(member(name)), "date": .string(today), "verified": .bool(verified),
                "note": .string(String(note.prefix(600))), "createdAt": .int(Firestore.nowMs)], mustNotExist: true)])
            return true
        } catch { message = error.wallText; return false }
    }

    func cheer(_ c: HabitCircle, to: String, emoji: String, name: String) async {
        guard let uid, to != uid else { return }
        let today = AppStore.dayKey()
        try? await Firestore.commit([.set("habitCircles/\(c.id)/cheers/\(today)_\(uid)_\(to)", [
            "fromUid": .string(uid), "fromName": .string(member(name)), "toUid": .string(to), "emoji": .string(emoji),
            "date": .string(today), "createdAt": .int(Firestore.nowMs)])])
    }
}

struct CirclesView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = CirclesModel.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var creating = false
    @State private var joining = false
    @State private var code = ""
    @State private var paywall: Feature?

    var body: some View {
        VStack(spacing: 10) {
            if let m = model.message { D(m).font(.hs(12)).foregroundStyle(HS.gold).padding(.horizontal, 20).onTapGesture { model.message = nil } }
            if model.loading { ProgressView().tint(HS.gold).padding(20) }
            ForEach(model.circles) { c in
                NavigationLink { CircleDetailView(circle: c) } label: {
                    GlassCard {
                        HStack(spacing: 12) {
                            Text(c.emoji.isEmpty ? "✨" : c.emoji).font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 2) {
                                D(c.name).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                D(tr(c.memberUids.count == 1 ? "1 member" : "{0} members").replacingOccurrences(of: "{0}", with: "\(c.memberUids.count)"))
                                    .font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(HS.textSubtle)
                        }
                    }
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
            }
            if !model.loading && model.circles.isEmpty {
                T("Start a circle with friends, or join one with a code someone shared with you.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    .multilineTextAlignment(.center).padding(.horizontal, 30).padding(.vertical, 8)
            }
            row("plus.circle", "Start a circle", "Pick a habit and invite your people") { creating = true }
            row("ticket", "Join with a code", "Paste the code or link a friend sent") { joining = true }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $creating) { NewCircleSheet() }
        .sheet(item: $paywall) { PlansView(feature: $0) }
        .alert(tr("Join with a code"), isPresented: $joining) {
            TextField(tr("Code"), text: $code).textInputAutocapitalization(.characters)
            Button(tr("Join")) { let c = code; code = ""; Task { _ = await model.join(code: c, displayName: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
    }

    private func row(_ symbol: String, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: 12) {
                    IconBadge(symbol: symbol, size: 32, tint: 0x9D7FEA)
                    VStack(alignment: .leading, spacing: 2) {
                        T(title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T(sub).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(HS.textSubtle)
                }
            }
        }
        .buttonStyle(.plain).padding(.horizontal, 20)
    }
}

extension Feature: Identifiable { var id: String { rawValue } }

private struct NewCircleSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var model = CirclesModel.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var pick: HabitTemplate?
    @State private var name = ""
    @State private var habit = ""
    @State private var busy = false
    @State private var made: HabitCircle?
    @State private var paywall: Feature?

    var body: some View {
        HSSheet(title: "Start a circle") {
            VStack(alignment: .leading, spacing: 12) {
                if let made {
                    T("Your circle is ready. Send the invite to your people.").font(.hs(14)).foregroundStyle(HS.text)
                    D(made.inviteCode).font(.hs(22, .semibold).monospaced()).foregroundStyle(HS.gold)
                    ShareLink(item: InviteCode.link(made.inviteCode), message: Text(tr("Join my HolySteps circle: {0}").replacingOccurrences(of: "{0}", with: made.name))) {
                        T("Share invite").font(.hs(15, .semibold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity).padding(.vertical, 13).background(Capsule().fill(HS.goldButton))
                    }
                } else if let t = pick {
                    D(t.emoji + " " + tr(t.title)).font(.hs(17, .semibold)).foregroundStyle(HS.text)
                    T(t.blurb).font(.hs(13)).foregroundStyle(HS.textMuted)
                    TextField(tr("Circle name"), text: $name).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                    if t.id == "custom" {
                        TextField(tr("The daily habit"), text: $habit).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                    }
                    T(t.proof.needs).font(.hs(12)).foregroundStyle(HS.textSecondary)
                    GoldButton(title: "Create") {
                        busy = true
                        Task { made = await model.create(t, name: name, habit: habit, displayName: store.name); busy = false }
                    }
                    .disabled(busy || (t.id == "custom" && habit.trimmingCharacters(in: .whitespaces).isEmpty))
                    if let m = model.message { D(m).font(.hs(12)).foregroundStyle(HS.gold) }
                } else {
                    ForEach([HabitTemplate.friendStreak] + HabitTemplate.all) { t in
                        Button { choose(t) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(t.emoji).font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    T(t.title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                    T(t.blurb).font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                                Spacer()
                                if locked(t) { Image(systemName: "lock.fill").foregroundStyle(HS.gold) }
                            }
                            .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $paywall) { PlansView(feature: $0) }
    }

    private func locked(_ t: HabitTemplate) -> Bool {
        if t.id == "friend_streak" { return false }
        if t.premium { return !account.canUse(.habitTemplates) }
        return !account.hasAnyPlan
    }
    private func choose(_ t: HabitTemplate) {
        if locked(t) { paywall = t.premium ? .habitTemplates : .createGroup } else { pick = t }
    }
}

struct CircleDetailView: View {
    let circle: HabitCircle
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = CirclesModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var names: [String: String] = [:]
    @State private var checkins: [HabitCheckin] = []
    @State private var cheers: [HabitCheer] = []
    @State private var note = ""
    @State private var confirmLeave = false

    private var today: String { AppStore.dayKey() }
    private var me: String { model.uid ?? "" }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    D((circle.emoji.isEmpty ? "" : circle.emoji + " ") + circle.name).font(.hs(24, .semibold)).foregroundStyle(HS.text).padding(.top, 58)
                    D(circle.habit).font(.hs(14)).foregroundStyle(HS.textSecondary)
                    HStack(spacing: 10) {
                        stat("\(CircleMath.streak(checkins, members: circle.memberUids.count, today: today))", "Group streak")
                        if let n = CircleMath.dayNumber(circle.startDate, today), circle.days > 0 {
                            stat("\(min(n, circle.days))/\(circle.days)", "Day")
                        }
                        stat("\(Set(checkins.filter { $0.date == today }.map(\.uid)).count)/\(circle.memberUids.count)", "Today")
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            if checkins.contains(where: { $0.uid == me && $0.date == today }) {
                                T("You checked in today ✓").font(.hs(15, .semibold)).foregroundStyle(HS.body)
                            } else {
                                T(circle.proofType.needs).font(.hs(13)).foregroundStyle(HS.textSecondary)
                                if let met = CircleMath.proofMet(circle.proofType) {
                                    T(met ? "HolySteps saw it today, so your check-in is verified ✓" : "Not seen yet today. You can still check in on your honor.")
                                        .font(.hs(12)).foregroundStyle(met ? HS.body : HS.textMuted)
                                }
                                TextField(tr("A note for the circle (optional)"), text: $note).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                                GoldButton(title: "Check in") { Task { if await model.checkIn(circle, name: store.name, note: note) { note = ""; await reload() } } }
                            }
                        }
                    }
                    SectionHeader(title: "Members").padding(.horizontal, -20)
                    ForEach(circle.memberUids, id: \.self) { uid in
                        let done = checkins.first { $0.uid == uid && $0.date == today }
                        HStack {
                            D(names[uid].flatMap { $0.isEmpty ? nil : $0 } ?? tr("A friend")).font(.hs(14)).foregroundStyle(HS.text)
                            if uid == circle.ownerUid { T("Leader").font(.hs(10)).foregroundStyle(HS.gold) }
                            Spacer()
                            if let done { Text(done.verified ? "✓" : "✔︎").foregroundStyle(HS.body) }
                            let got = cheers.filter { $0.toUid == uid }.map(\.emoji).joined()
                            if !got.isEmpty { Text(got).font(.system(size: 13)) }
                            if uid != me {
                                Menu { ForEach(["👏", "🔥", "🙏", "💪", "❤️"], id: \.self) { e in Button(e) { Task { await model.cheer(circle, to: uid, emoji: e, name: store.name); await reload() } } } }
                                label: { T("Cheer").font(.hs(12, .semibold)).foregroundStyle(HS.peach) }
                            }
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        if let n = done?.note, !n.isEmpty { D("“\(n)”").font(.hs(12)).foregroundStyle(HS.textMuted).padding(.leading, 12) }
                    }
                    ShareLink(item: InviteCode.link(circle.inviteCode), message: Text(tr("Join my HolySteps circle: {0}").replacingOccurrences(of: "{0}", with: circle.name))) {
                        HStack { Image(systemName: "square.and.arrow.up"); D(tr("Invite (code {0})").replacingOccurrences(of: "{0}", with: circle.inviteCode)).font(.hs(14, .semibold)) }
                            .foregroundStyle(HS.gold)
                    }
                    Button(role: .destructive) { confirmLeave = true } label: { T("Leave circle").font(.hs(13)).foregroundStyle(.red.opacity(0.8)) }
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 20)
            }
            .refreshable { await reload() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .task { await reload() }
        .confirmationDialog(tr("Leave this circle?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(tr("Leave"), role: .destructive) { Task { await model.leave(circle); dismiss() } }
        }
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(spacing: 2) { D(v).font(.hs(20, .semibold)).foregroundStyle(HS.gold); T(label).font(.hs(11)).foregroundStyle(HS.textMuted) }
            .frame(maxWidth: .infinity).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
    }

    private func reload() async {
        async let n = model.members(circle)
        async let c = model.checkins(circle)
        async let h = model.cheers(circle)
        names = await n; checkins = await c; cheers = await h
    }
}
