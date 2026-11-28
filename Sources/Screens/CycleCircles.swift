import SwiftUI

/// Android's Cycle Circles (CycleCirclesScreen.kt): small private support groups (up to 12) joined by invite code, with
/// the same Firestore documents and rules. Posts that mention suicide or self-harm are flagged for the moderator and
/// show crisis help to everyone right away; the circle's moderator can hide or delete posts, and anyone can report one.
enum CircleSafety {
    static let rules = "Circle rules: be kind, keep others' stories private, and share experiences, not medical advice. Members aren't doctors and moderators aren't online all the time, so for anything urgent call your doctor, and in a crisis call or text 988 or call 911. Don't post names, phone numbers, addresses or photos that could identify anyone."
    static let crisis = "If you or someone here is thinking about suicide or self-harm, call or text 988 now (24/7). New or expecting moms can also call or text 1-833-TLC-MAMA (1-833-852-6262). In danger right now, call 911."
    private static let keywords = ["kill myself", "suicide", "self harm", "self-harm", "want to die", "end it all",
                                   "suicid", "matarme", "quitarme la vida", "me quiero morir", "quiero morirme", "quiero morir",
                                   "hacerme daño", "lastimarme", "autolesi", "acabar con todo", "no quiero vivir"]
    static func needsFlag(_ text: String) -> Bool { let l = text.lowercased(); return keywords.contains { l.contains($0) } }
}

struct CirclePost: Identifiable, Equatable { let id, authorUid, authorName, text: String; let at: Int64; let flagged, hidden: Bool }

@MainActor
final class CycleCirclesModel: ObservableObject {
    @Published var circles: [FSDoc] = []
    @Published var posts: [CirclePost] = []
    @Published var loading = true
    @Published var message = ""
    var uid: String? { AccountStore.shared.uid }

    func load() async {
        guard let uid else { loading = false; return }
        circles = (try? await Firestore.query("cycleCircles", filters: [.init(field: "memberUids", op: "ARRAY_CONTAINS", value: .string(uid))], limit: 50)) ?? []
        loading = false
    }

    func create(name: String, displayName: String) async -> Bool {
        guard let uid = await AccountStore.shared.ensureUid() else { message = AccountStore.shared.notConnectedMessage; return false }
        let n = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !n.isEmpty else { return false }
        let id = Firestore.newId(), code = InviteCode.make("CIRCLE")
        do {
            try await Firestore.commit([.set("cycleCircles/\(id)", [
                "name": .string(n), "memberUids": .array([.string(uid)]), "memberNames": .array([.string(String(displayName.prefix(100)))]),
                "inviteCode": .string(code), "moderatorUid": .string(uid), "createdAt": .int(Firestore.nowMs)], mustNotExist: true)])
            try await InviteCode.register(code, type: "cycleCircle", target: id, uid: uid)
        } catch { message = error.togetherText(tr("Couldn't start the circle. Check your connection and try again.")); return false }
        await load(); return true
    }

    func join(code: String, displayName: String) async {
        guard let uid = await AccountStore.shared.ensureUid() else { message = AccountStore.shared.notConnectedMessage; return }
        guard let inv = await InviteCode.resolve(code), inv.type == "cycleCircle" else { message = tr("That code wasn't found. Check it and try again."); return }
        do {
            try await Firestore.commit([.update("cycleCircles/\(inv.target)", ["joinCode": .string(InviteCode.clean(code))],
                                                unions: ["memberUids": [.string(uid)], "memberNames": [.string(String(displayName.prefix(100)))]])])
        } catch FSError.denied { message = tr("That circle is full (12 members), or joining it needs a plan."); return }
        catch { message = error.togetherText(tr("Couldn't join. Check your connection and try again."), denied: TogetherText.codeRefused); return }
        await load()
    }

    func loadPosts(_ circle: String) async {
        let docs = (try? await Firestore.query("posts", parent: "cycleCircles/\(circle)", orderBy: "createdAt", limit: 100)) ?? []
        posts = docs.map { CirclePost(id: $0.id, authorUid: $0["authorUid"].string, authorName: $0["authorName"].string, text: $0["text"].string,
                                      at: $0["createdAt"].int, flagged: $0["flagged"].bool, hidden: $0["hidden"].bool) }
    }

    func post(_ circle: String, text: String, name: String, anonymous: Bool) async -> Bool {
        guard let uid else { return false }
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))
        guard !t.isEmpty else { return false }
        do {
            try await Firestore.commit([.set("cycleCircles/\(circle)/posts/\(Firestore.newId())", [
                "authorUid": .string(uid), "authorName": .string(anonymous ? "A member" : String(name.prefix(100))), "text": .string(t),
                "createdAt": .int(Firestore.nowMs), "flagged": .bool(CircleSafety.needsFlag(t)), "hidden": .bool(false)], mustNotExist: true)])
        } catch { message = error.togetherText(tr("Couldn't post. Check your connection and try again."), denied: tr("Couldn't post in this circle.")); return false }
        await loadPosts(circle); return true
    }

    func moderate(_ circle: String, _ p: CirclePost, hide: Bool) async {
        try? await Firestore.commit([.update("cycleCircles/\(circle)/posts/\(p.id)", ["flagged": .bool(p.flagged), "hidden": .bool(hide)])])
        await loadPosts(circle)
    }

    func delete(_ circle: String, _ p: CirclePost) async {
        try? await Firestore.commit([.delete("cycleCircles/\(circle)/posts/\(p.id)")])
        await loadPosts(circle)
    }

    func report(_ circle: String, _ p: CirclePost, reason: String) async {
        guard let uid else { return }
        do {
            try await Firestore.commit([.createStamped("contentReports/\(Firestore.newId())", [
                "reporterUid": .string(uid), "kind": .string("circlePost"), "reason": .string(reason),
                "refPath": .string("cycleCircles/\(circle)/posts/\(p.id)"), "authorUid": .string(p.authorUid),
                "excerpt": .string(String(p.text.prefix(8000))), "details": .string(""), "status": .string("open")], serverTime: ["createdAt"])])
            message = tr("Thank you. The HolySteps team will look at it.")
        } catch { message = tr("Couldn't send the report. Check your connection and try again.") }
    }
}

struct CycleCirclesView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var m = CycleCirclesModel()
    @State private var joining = false
    @State private var creating = false
    /// Filled in when this screen was opened from an invite link (JoinInviteView).
    @State private var code = InviteInbox.take("CIRCLE")
    @State private var name = ""

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🌸 CYCLE CIRCLES").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF472B6))
                    T("Support from women who get it").font(.hs(24)).foregroundStyle(HS.text)
                    T("Small private circles, up to 12 women, by invitation. Share what helps with endometriosis, PCOS, trying to conceive, pregnancy or perimenopause.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if m.loading { ProgressView().frame(maxWidth: .infinity) }
                    ForEach(m.circles) { c in
                        NavigationLink { CircleFeedView(m: m, circle: c).environmentObject(store) } label: {
                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        D(c["name"].string).font(.hs(15, .bold)).foregroundStyle(HS.text)
                                        D(tr("\(c["memberUids"].array.count) members")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    HStack {
                        Button(tr("Join with code")) { joining = true }.buttonStyle(.bordered)
                        GoldButton(title: "Start a circle") { creating = true }
                    }
                    ScanQRButton(label: "Scan a circle's QR code") { c in Task { await m.join(code: c, displayName: store.name) } }
                    if !m.message.isEmpty { D(m.message).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    T(CircleSafety.rules).font(.hs(11)).foregroundStyle(HS.textMuted)
                }.padding(20)
            }.refreshable { await m.load() }
        }
        .task { await m.load() }
        .alert(tr("Join a circle"), isPresented: $joining) {
            TextField("CIRCLE-…", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button(tr("Join")) { let c = code; code = ""; Task { await m.join(code: c, displayName: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
        .alert(tr("Start a circle"), isPresented: $creating) {
            TextField(tr("Circle name"), text: $name)
            Button(tr("Start")) { let n = name; name = ""; Task { _ = await m.create(name: n, displayName: store.name) } }
            Button(tr("Cancel"), role: .cancel) { name = "" }
        } message: { T("You'll be its moderator. Share the code with the women you invite.") }
    }
}

private struct CircleFeedView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var m: CycleCirclesModel
    let circle: FSDoc
    @State private var text = ""
    @State private var anonymous = false
    @State private var reporting: CirclePost?

    private var isMod: Bool { circle["moderatorUid"].string == m.uid }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    D(circle["name"].string).font(.hs(22)).foregroundStyle(HS.text)
                    if isMod {
                        let code = circle["inviteCode"].string
                        HStack {
                            D(code).font(.system(.callout, design: .monospaced)).foregroundStyle(HS.text).textSelection(.enabled)
                            ShareLink(item: code, message: Text(tr("Join my HolySteps Cycle Circle. Open Cycle, then Cycle Circles, tap \"Join with code\" and enter it."))) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            ShowQRButton(code: code, label: "QR")
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(tr("Share something with the circle"), text: $text, axis: .vertical).lineLimit(2...6)
                                .onChange(of: text) { _, v in if v.count > 600 { text = String(v.prefix(600)) } }
                            Toggle(tr("Post as \"A member\""), isOn: $anonymous).font(.hs(12))
                            if CircleSafety.needsFlag(text) { T(CircleSafety.crisis).font(.hs(12)).foregroundStyle(HS.readable(0xF43F5E)) }
                            GoldButton(title: "Post") { let t = text; Task { if await m.post(circle.id, text: t, name: store.name, anonymous: anonymous) { text = "" } } }
                        }
                    }
                    ForEach(m.posts.filter { !$0.hidden || isMod || $0.authorUid == m.uid }) { p in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    D(p.authorName.isEmpty ? tr("A member") : p.authorName).font(.hs(12, .bold)).foregroundStyle(HS.textSecondary)
                                    Spacer()
                                    D(Date(timeIntervalSince1970: Double(p.at) / 1000).formatted(.dateTime.month(.abbreviated).day())).font(.hs(10)).foregroundStyle(HS.textMuted)
                                }
                                D(p.hidden ? tr("(Hidden)") + " " + p.text : p.text).font(.hs(13)).foregroundStyle(p.hidden ? HS.textMuted : HS.text)
                                if p.flagged {
                                    T("⚠️ Flagged for moderator review").font(.hs(10)).foregroundStyle(HS.readable(0xF59E0B))
                                    T(CircleSafety.crisis).font(.hs(11)).foregroundStyle(HS.textSecondary)
                                }
                                HStack(spacing: 14) {
                                    if p.authorUid != m.uid { Button(tr("Report")) { reporting = p } }
                                    if isMod { Button(tr(p.hidden ? "Unhide" : "Hide")) { Task { await m.moderate(circle.id, p, hide: !p.hidden) } } }
                                    if isMod || p.authorUid == m.uid { Button(tr("Delete"), role: .destructive) { Task { await m.delete(circle.id, p) } } }
                                }.font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
                    if !m.message.isEmpty { D(m.message).font(.hs(12)).foregroundStyle(HS.textSecondary) }
                    T(CircleSafety.rules).font(.hs(10)).foregroundStyle(HS.textMuted)
                }.padding(20)
            }.refreshable { await m.loadPosts(circle.id) }
        }
        .task { await m.loadPosts(circle.id) }
        .confirmationDialog(tr("Report this post"), isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }), titleVisibility: .visible) {
            ForEach([("selfharm", "Someone may be in danger"), ("harassment", "Bullying or harassment"), ("advice", "Harmful medical advice"),
                     ("sexual", "Sexual content"), ("hate", "Hate"), ("spam", "Spam"), ("other", "Something else")], id: \.0) { r in
                Button(tr(r.1)) { if let p = reporting { Task { await m.report(circle.id, p, reason: r.0) } }; reporting = nil }
            }
        } message: { T("It goes to the HolySteps team and the circle's moderator can remove it. They aren't told who reported it.") }
    }
}
