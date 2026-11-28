import SwiftUI

/// Android's Reading together (Together.kt ReadingPlans, ReadingGroups screens): friends read the same Bible plan from
/// the same start day, tick off each day, and leave short reflections on it. Up to 50 readers, joined by code. Same
/// Firestore documents and rules as Android.
enum ReadingPlans {
    struct Plan: Identifiable { let id, title, emoji, blurb: String; let days: Int; let books: [String]
        var chapters: [(book: String, ch: Int)] { books.flatMap { b in (1...max(1, ReadingPlans.chapters(b))).map { (b, $0) } } }
    }
    static func chapters(_ book: String) -> Int { Bible.canon.first { $0.name == book }?.chapters ?? 0 }
    private static var ot: [String] { Bible.canon.prefix(39).map(\.name) }
    private static var nt: [String] { Bible.canon.dropFirst(39).map(\.name) }
    static var all: [Plan] { [
        .init(id: "john_21", title: "The Gospel of John", emoji: "✝️", blurb: "One chapter a day for 21 days", days: 21, books: ["John"]),
        .init(id: "mark_16", title: "The Gospel of Mark", emoji: "🦁", blurb: "The fastest Gospel, a chapter a day", days: 16, books: ["Mark"]),
        .init(id: "proverbs_31", title: "Proverbs in a month", emoji: "🦉", blurb: "A chapter of wisdom for each day of the month", days: 31, books: ["Proverbs"]),
        .init(id: "psalms_30", title: "Psalms in 30 days", emoji: "🎶", blurb: "Five psalms a day", days: 30, books: ["Psalms"]),
        .init(id: "romans_16", title: "Romans", emoji: "📜", blurb: "The gospel explained, a chapter a day", days: 16, books: ["Romans"]),
        .init(id: "acts_28", title: "Acts", emoji: "🔥", blurb: "The early church, a chapter a day", days: 28, books: ["Acts"]),
        .init(id: "gospels_30", title: "The four Gospels", emoji: "🕊️", blurb: "Matthew, Mark, Luke and John in 30 days", days: 30, books: ["Matthew", "Mark", "Luke", "John"]),
        .init(id: "nt_90", title: "The New Testament in 90 days", emoji: "📖", blurb: "About three chapters a day", days: 90, books: nt),
        .init(id: "bible_365", title: "The whole Bible in a year", emoji: "🌍", blurb: "About three chapters a day, Genesis to Revelation", days: 365, books: ot + nt),
    ] }
    static func byId(_ id: String) -> Plan? { all.first { $0.id == id } }
    static func readings(_ p: Plan, day: Int) -> [(book: String, ch: Int)] {
        guard (1...p.days).contains(day) else { return [] }
        let a = p.chapters
        return Array(a[((day - 1) * a.count / p.days)..<(day * a.count / p.days)])
    }
    static func label(_ r: [(book: String, ch: Int)]) -> String {
        guard let a = r.first, let b = r.last else { return "" }
        let one = { (c: (book: String, ch: Int)) in "\(c.book == "Psalms" ? "Psalm" : c.book) \(c.ch)" }
        if r.count == 1 { return one(a) }
        return a.book == b.book ? "\(a.book) \(a.ch)–\(b.ch)" : "\(one(a)) – \(one(b))"
    }
    static func dayNumber(start: String) -> Int {
        guard let s = AppStore.date(fromKey: start) else { return 0 }
        let d = CycleLogic.days(s, Date()); return d < 0 ? 0 : d + 1
    }
}

@MainActor
final class ReadingTogetherModel: ObservableObject {
    @Published var groups: [FSDoc] = []
    @Published var members: [FSDoc] = []
    @Published var notes: [FSDoc] = []
    @Published var loading = true
    @Published var message = ""
    var uid: String? { AccountStore.shared.uid }

    func load() async {
        guard let uid else { loading = false; return }
        groups = (try? await Firestore.query("readingGroups", filters: [.init(field: "memberUids", op: "ARRAY_CONTAINS", value: .string(uid))], limit: 50)) ?? []
        loading = false
    }

    func create(_ plan: ReadingPlans.Plan, name: String, displayName: String) async {
        guard let uid = await AccountStore.shared.ensureUid() else { message = AccountStore.shared.notConnectedMessage; return }
        let id = Firestore.newId(), code = InviteCode.make("READ"), now = Firestore.nowMs
        let n = String((name.trimmingCharacters(in: .whitespaces).isEmpty ? plan.title : name).prefix(240))
        do {
            try await Firestore.commit([.set("readingGroups/\(id)", ["name": .string(n), "planId": .string(plan.id), "startDate": .string(AppStore.dayKey()),
                "memberUids": .array([.string(uid)]), "inviteCode": .string(code), "ownerUid": .string(uid), "createdAt": .int(now)], mustNotExist: true)])
            try await Firestore.commit([.set("readingGroups/\(id)/members/\(uid)", ["displayName": .string(String(displayName.prefix(160))), "joinedAt": .int(now), "done": .array([]), "updatedAt": .int(now)])])
            try await InviteCode.register(code, type: "readingGroup", target: id, uid: uid)
        } catch FSError.denied { message = tr("Starting a reading group needs a plan."); return }
        catch { message = error.togetherText(tr("Couldn't start the group. Check your connection and try again.")); return }
        await load()
    }

    func join(_ code: String, displayName: String) async {
        guard let uid = await AccountStore.shared.ensureUid() else { message = AccountStore.shared.notConnectedMessage; return }
        guard let inv = await InviteCode.resolve(code), inv.type == "readingGroup" else { message = tr("That code wasn't found. Check it and try again."); return }
        do {
            try await Firestore.commit([.update("readingGroups/\(inv.target)", ["joinCode": .string(InviteCode.clean(code))], unions: ["memberUids": [.string(uid)]])])
            let old = try? await Firestore.get("readingGroups/\(inv.target)/members/\(uid)")
            let now = Firestore.nowMs
            try await Firestore.commit([.set("readingGroups/\(inv.target)/members/\(uid)", ["displayName": .string(String(displayName.prefix(160))),
                "joinedAt": .int(old.map { $0["joinedAt"].int } ?? now), "done": .array(old?["done"].array ?? []), "updatedAt": .int(now)])])
        } catch FSError.denied { message = tr("Joining a reading group needs a plan."); return }
        catch { message = error.togetherText(tr("Couldn't join. Check your connection and try again."), denied: TogetherText.codeRefused); return }
        await load()
    }

    func open(_ g: FSDoc, day: Int) async {
        members = (try? await Firestore.query("members", parent: "readingGroups/\(g.id)", limit: 60)) ?? []
        notes = ((try? await Firestore.query("notes", parent: "readingGroups/\(g.id)", filters: [.init(field: "day", op: "EQUAL", value: .int(Int64(day)))], limit: 200)) ?? [])
            .sorted { $0["createdAt"].int > $1["createdAt"].int }
    }

    func myDone(_ g: FSDoc) -> [Int] { members.first { $0.id == uid }?["done"].array.map { Int($0.int) } ?? [] }

    func toggle(_ g: FSDoc, day: Int, displayName: String, days: Int) async {
        guard let uid else { return }
        var d = Set(myDone(g)); if d.contains(day) { d.remove(day) } else { d.insert(day) }
        let clean = d.filter { (1...days).contains($0) }.sorted()
        let me = members.first { $0.id == uid }
        try? await Firestore.commit([.set("readingGroups/\(g.id)/members/\(uid)", ["displayName": .string(String(displayName.prefix(160))),
            "joinedAt": .int(me?["joinedAt"].int ?? Firestore.nowMs), "done": .array(clean.map { .int(Int64($0)) }), "updatedAt": .int(Firestore.nowMs)])])
        await open(g, day: day)
    }

    func note(_ g: FSDoc, day: Int, text: String, displayName: String) async {
        guard let uid else { return }
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000)); guard !t.isEmpty else { return }
        do { try await Firestore.commit([.set("readingGroups/\(g.id)/notes/\(Firestore.newId())", ["uid": .string(uid), "name": .string(String(displayName.prefix(160))),
            "day": .int(Int64(day)), "text": .string(t), "createdAt": .int(Firestore.nowMs)], mustNotExist: true)]) }
        catch { message = tr("Couldn't post your reflection.") }
        await open(g, day: day)
    }

    func deleteNote(_ g: FSDoc, _ n: FSDoc, day: Int) async {
        try? await Firestore.commit([.delete("readingGroups/\(g.id)/notes/\(n.id)")]); await open(g, day: day)
    }

    func leave(_ g: FSDoc) async {
        guard let uid else { return }
        try? await Firestore.commit([.delete("readingGroups/\(g.id)/members/\(uid)")])
        try? await Firestore.commit([.update("readingGroups/\(g.id)", ["memberUids": .array(g["memberUids"].array.filter { $0.string != uid })])])
        await load()
    }
}

struct ReadingTogetherView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var m = ReadingTogetherModel()
    @State private var picking = false
    @State private var joining = false
    @State private var code = ""

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("📖 READING TOGETHER").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xD9B49F))
                    T("Read the Bible with friends").font(.hs(24)).foregroundStyle(HS.text)
                    T("Pick a plan, invite friends with a code, and read the same chapters each day. Tick off your day and share a short reflection.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if m.loading { ProgressView().frame(maxWidth: .infinity) }
                    ForEach(m.groups) { g in
                        let p = ReadingPlans.byId(g["planId"].string)
                        NavigationLink { ReadingGroupView(m: m, group: g).environmentObject(store) } label: {
                            GlassCard {
                                HStack {
                                    D(p?.emoji ?? "📖").font(.system(size: 26))
                                    VStack(alignment: .leading) {
                                        D(g["name"].string).font(.hs(15, .bold)).foregroundStyle(HS.text)
                                        D(tr("Day \(min(ReadingPlans.dayNumber(start: g["startDate"].string), p?.days ?? 1)) of \(p?.days ?? 0) · \(g["memberUids"].array.count) readers"))
                                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    HStack {
                        Button(tr("Join with code")) { joining = true }.buttonStyle(.bordered)
                        ScanQRButton(label: "Scan") { c in Task { await m.join(c, displayName: store.name) } }
                        GoldButton(title: "Start a reading group") { picking = true }
                    }
                    if !m.message.isEmpty { D(m.message).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }.padding(20)
            }.refreshable { await m.load() }
        }
        .task { await m.load() }
        .alert(tr("Join a reading group"), isPresented: $joining) {
            TextField("READ-…", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button(tr("Join")) { let c = code; code = ""; Task { await m.join(c, displayName: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
        .sheet(isPresented: $picking) {
            NavigationStack {
                List(ReadingPlans.all) { p in
                    Button { picking = false; Task { await m.create(p, name: "", displayName: store.name) } } label: {
                        HStack { D(p.emoji); VStack(alignment: .leading) { T(p.title).font(.hs(15, .semibold)); T(p.blurb).font(.hs(12)).foregroundStyle(.secondary) } }
                    }
                }
                .navigationTitle(tr("Pick a plan"))
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { picking = false } } }
            }
        }
    }
}

private struct ReadingGroupView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var m: ReadingTogetherModel
    let group: FSDoc
    @Environment(\.dismiss) private var dismiss
    @State private var day = 1
    @State private var text = ""
    @State private var read: (String, Int)?

    var body: some View {
        let plan = ReadingPlans.byId(group["planId"].string)
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    D(group["name"].string).font(.hs(24)).foregroundStyle(HS.text)
                    HStack {
                        D(group["inviteCode"].string).font(.system(.callout, design: .monospaced)).foregroundStyle(HS.text).textSelection(.enabled)
                        ShareLink(item: group["inviteCode"].string, message: Text(tr("Read the Bible with me on HolySteps. Open Faith, then Reading together, tap \"Join with code\" and enter it."))) { Image(systemName: "square.and.arrow.up") }
                        ShowQRButton(code: group["inviteCode"].string, label: "QR")
                    }
                    if let plan {
                        Stepper(tr("Day \(day) of \(plan.days)"), value: $day, in: 1...plan.days).font(.hs(14, .semibold))
                        let r = ReadingPlans.readings(plan, day: day)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                D(ReadingPlans.label(r)).font(.hs(17, .bold)).foregroundStyle(HS.text)
                                if let f = r.first { GoldButton(title: "Read it") { read = (f.book, f.ch) } }
                                let done = m.myDone(group).contains(day)
                                Button(done ? tr("✓ Done for today") : tr("Mark this day done")) { Task { await m.toggle(group, day: day, displayName: store.name, days: plan.days) } }
                                    .buttonStyle(.bordered).tint(done ? .green : .accentColor)
                            }
                        }
                        T("Readers").font(.hs(13, .bold)).foregroundStyle(HS.textMuted)
                        ForEach(m.members) { mem in
                            let n = mem["done"].array.count
                            HStack { D(mem.id == m.uid ? tr("You") : mem["displayName"].string).font(.hs(14)).foregroundStyle(HS.text); Spacer()
                                D(tr("\(n) of \(plan.days) days")).font(.hs(12)).foregroundStyle(HS.textMuted) }
                        }
                        T("Reflections on this day").font(.hs(13, .bold)).foregroundStyle(HS.textMuted)
                        TextField(tr("What stood out to you?"), text: $text, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                        Button(tr("Share")) { let t = text; text = ""; Task { await m.note(group, day: day, text: t, displayName: store.name) } }.buttonStyle(.bordered)
                        ForEach(m.notes) { n in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { D(n["name"].string).font(.hs(12, .bold)).foregroundStyle(HS.textSecondary); Spacer()
                                    if n["uid"].string == m.uid || group["ownerUid"].string == m.uid { Button(tr("Delete")) { Task { await m.deleteNote(group, n, day: day) } }.font(.hs(11)) } }
                                D(n["text"].string).font(.hs(13)).foregroundStyle(HS.text)
                            }.padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.text.opacity(0.04)))
                        }
                    }
                    if group["ownerUid"].string != m.uid { Button(tr("Leave this group"), role: .destructive) { Task { await m.leave(group); dismiss() } }.font(.hs(12)) }
                }.padding(20)
            }
        }
        .task {
            day = max(1, min(ReadingPlans.dayNumber(start: group["startDate"].string), plan?.days ?? 1))
            await m.open(group, day: day)
        }
        .onChange(of: day) { _, d in Task { await m.open(group, day: d) } }
        .sheet(item: Binding(get: { read.map { ReadRef(book: $0.0, ch: $0.1) } }, set: { read = $0.map { ($0.book, $0.ch) } })) { r in
            NavigationStack { BibleReaderView(startBook: r.book, startCh: r.ch) }
        }
    }
}

private struct ReadRef: Identifiable { let book: String; let ch: Int; var id: String { "\(book)\(ch)" } }
