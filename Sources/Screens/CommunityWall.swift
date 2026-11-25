import SwiftUI

/// The Testimony & Prayer Wall, live from Firestore (`testimonies`), shared with Android. Reading is free; posting,
/// praying along and commenting come with any plan (firestore.rules hasAnyPlan). Posts carry a wall key, never the
/// account id; anonymous posts carry no name. Three reports hide a post for everyone but its author.
struct WallPost: Identifiable, Equatable {
    let id: String
    var authorKey, authorName, type, text, answeredNote: String
    var anonymous, answered, flagged: Bool
    var createdAt, prayingCount, commentCount, reportCount: Int64

    init(_ d: FSDoc) {
        id = d.id
        authorKey = d["authorKey"].string; authorName = d["authorName"].string; type = d["type"].string
        text = d["text"].string; answeredNote = d["answeredNote"].string
        anonymous = d["anonymous"].bool; answered = d["answered"].bool; flagged = d["flagged"].bool
        createdAt = d["createdAt"].int; prayingCount = d["prayingCount"].int
        commentCount = d["commentCount"].int; reportCount = d["reportCount"].int
    }
    var who: String { anonymous ? tr("Anonymous") : (authorName.isEmpty ? tr("A believer") : authorName) }
    var date: Date { Date(timeIntervalSince1970: Double(createdAt) / 1000) }
}

struct WallComment: Identifiable {
    let id: String
    let authorKey, who, text: String
    let createdAt: Int64
}

enum WallType: String, CaseIterable, Identifiable {
    case TESTIMONY, PRAYER_REQUEST, DISCUSSION
    var id: String { rawValue }
    var label: String { switch self { case .TESTIMONY: "🎉 Testimony"; case .PRAYER_REQUEST: "🙏 Prayer Request"; case .DISCUSSION: "💬 Today's question" } }
}

enum DailyQuestion {
    static let all = [
        "Where did you see God at work this week?", "What verse has carried you through a hard time?",
        "What are you thankful for today?", "Who taught you to pray, and what did they teach you?",
        "What is one prayer God answered in a way you didn't expect?", "What helps you rest in God when you're anxious?",
        "Which Bible story speaks to your life right now?", "How do you make time with God in a busy day?",
        "What does forgiveness look like for you this season?", "What song draws you closer to God?",
        "Who could you encourage today, and how?", "What is God teaching you through waiting?",
        "What is one small act of kindness that changed your day?", "How has your faith grown this year?",
    ]
    static func dayOf(_ ms: Int64) -> Int { Int(ms / 86_400_000) }
    static func forDay(_ day: Int) -> String { all[((day % all.count) + all.count) % all.count] }
    static var today: String { forDay(dayOf(Firestore.nowMs)) }
    static func isToday(_ ms: Int64) -> Bool { dayOf(ms) == dayOf(Firestore.nowMs) }
}

@MainActor
final class WallModel: ObservableObject {
    static let shared = WallModel()
    @Published private(set) var posts: [WallPost] = []
    @Published private(set) var loading = true
    @Published private(set) var failed = false
    @Published private(set) var mine: Set<String> = []
    @Published private(set) var praying: Set<String> = []
    @Published var hidden: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "wallHidden") ?? []) {
        didSet { UserDefaults.standard.set(Array(hidden), forKey: "wallHidden") }
    }
    @Published var message: String?

    private var uid: String? { AccountStore.shared.uid }

    func load() async {
        do {
            let docs = try await Firestore.query("testimonies", orderBy: "createdAt", limit: 100)
            posts = docs.map(WallPost.init)
            failed = false
            if let uid {
                async let o = try? Firestore.query("testimonyOwners", filters: [.init(field: "uid", op: "EQUAL", value: .string(uid))], limit: 500)
                async let p = try? Firestore.query("posts", parent: "testimonyPraying/\(uid)", limit: 500)
                mine = Set((await o ?? []).map(\.id))
                praying = Set((await p ?? []).map(\.id))
            }
        } catch { failed = posts.isEmpty }
        loading = false
    }

    func visible(_ filter: Int) -> [WallPost] {
        posts.filter { p in
            !hidden.contains(p.authorKey) && (mine.contains(p.id) || p.reportCount < 3) && {
                switch filter {
                case 1: p.type == "DISCUSSION" && DailyQuestion.isToday(p.createdAt)
                case 2: p.type == "TESTIMONY"
                case 3: p.type == "PRAYER_REQUEST"
                case 4: mine.contains(p.id)
                default: true
                }
            }()
        }
    }

    private func wallKey(anonymous: Bool) -> String {
        func random(_ prefix: String) -> String { prefix + (0..<8).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined() }
        if anonymous { return random("a") }
        if let k = UserDefaults.standard.string(forKey: "wallKey"), (8...40).contains(k.count) { return k }
        let k = random("n"); UserDefaults.standard.set(k, forKey: "wallKey"); return k
    }

    private static let heavy = ["suicide", "kill myself", "end my life", "self harm", "self-harm", "hurt myself", "want to die", "suicidio", "quitarme la vida", "hacerme daño"]

    func post(type: WallType, text: String, anonymous: Bool, name: String) async -> Bool {
        guard let uid else { message = tr("Couldn't reach HolySteps. Try again in a moment."); return false }
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))
        guard !t.isEmpty else { return false }
        let id = Firestore.newId(), now = Firestore.nowMs
        let flagged = type == .PRAYER_REQUEST && Self.heavy.contains { t.lowercased().contains($0) }
        let fields: [String: FSValue] = [
            "authorKey": .string(wallKey(anonymous: anonymous)), "authorName": .string(anonymous ? "" : String(name.prefix(100))),
            "anonymous": .bool(anonymous), "type": .string(type.rawValue), "text": .string(t), "createdAt": .int(now),
            "prayingCount": .int(0), "commentCount": .int(0), "lastCommentId": .string(""), "reportCount": .int(0),
            "flagged": .bool(flagged), "answered": .bool(false), "answeredNote": .string(""),
        ]
        do {
            try await Firestore.commit([.set("testimonies/\(id)", fields, mustNotExist: true),
                                        .set("testimonyOwners/\(id)", ["uid": .string(uid), "createdAt": .int(now)], mustNotExist: true)])
            await load(); return true
        } catch { message = error.wallText; return false }
    }

    func togglePraying(_ p: WallPost) async {
        guard let uid else { return }
        let on = praying.contains(p.id)
        // Show it at once; the server confirms or the reload puts it back.
        if on { praying.remove(p.id) } else { praying.insert(p.id) }
        if let i = posts.firstIndex(of: p) { posts[i].prayingCount += on ? -1 : 1 }
        do {
            try await Firestore.commit([
                on ? .delete("testimonyPraying/\(uid)/posts/\(p.id)")
                   : .set("testimonyPraying/\(uid)/posts/\(p.id)", ["createdAt": .int(Firestore.nowMs)]),
                .update("testimonies/\(p.id)", [:], increments: ["prayingCount": on ? -1 : 1]),
            ])
            if !on { PrayerNudge.prayedOnWall() }
        } catch { message = error.wallText; await load() }
    }

    func delete(_ p: WallPost) async {
        do { try await Firestore.commit([.delete("testimonies/\(p.id)"), .delete("testimonyOwners/\(p.id)")]) }
        catch { try? await Firestore.commit([.delete("testimonies/\(p.id)")]) }
        await load()
    }

    func markAnswered(_ p: WallPost, note: String) async {
        do { try await Firestore.commit([.update("testimonies/\(p.id)", ["answered": .bool(true), "answeredNote": .string(String(note.prefix(300)))])]) }
        catch { message = error.wallText }
        await load()
    }

    func report(_ p: WallPost) async {
        guard let uid else { return }
        let mineReport = FSWrite.set("testimonies/\(p.id)/reports/\(uid)", ["createdAt": .int(Firestore.nowMs)])
        do { try await Firestore.commit([mineReport, .update("testimonies/\(p.id)", [:], increments: ["reportCount": 1])]) }
        catch { try? await Firestore.commit([mineReport]) }   // newer accounts: the report still reaches the team
        message = tr("Thanks. The HolySteps team will look at it.")
        await load()
    }

    // MARK: Comments

    func comments(_ postId: String) async -> [WallComment] {
        let docs = (try? await Firestore.query("comments", parent: "testimonies/\(postId)", orderBy: "createdAt", descending: false, limit: 200)) ?? []
        return docs.map { d in
            let anon = d["anonymous"].bool, name = d["authorName"].string
            return WallComment(id: d.id, authorKey: d["authorKey"].string,
                               who: anon ? tr("Anonymous") : (name.isEmpty ? tr("A believer") : name), text: d["text"].string, createdAt: d["createdAt"].int)
        }
    }

    func myComments(_ postId: String) async -> Set<String> {
        guard let uid else { return [] }
        let d = (try? await Firestore.query("commentOwners", filters: [.init(field: "uid", op: "EQUAL", value: .string(uid)),
                                                                       .init(field: "postId", op: "EQUAL", value: .string(postId))], limit: 200)) ?? []
        return Set(d.map(\.id))
    }

    func addComment(_ postId: String, text: String, anonymous: Bool, name: String) async -> Bool {
        guard let uid else { return false }
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !t.isEmpty else { return false }
        let cid = Firestore.newId()
        do {
            try await Firestore.commit([
                .set("testimonies/\(postId)/comments/\(cid)", ["authorKey": .string(wallKey(anonymous: anonymous)),
                     "authorName": .string(anonymous ? "" : String(name.prefix(100))), "anonymous": .bool(anonymous),
                     "text": .string(t), "createdAt": .int(Firestore.nowMs)], mustNotExist: true),
                .set("commentOwners/\(cid)", ["uid": .string(uid), "postId": .string(postId)], mustNotExist: true),
                .update("testimonies/\(postId)", ["lastCommentId": .string(cid)], increments: ["commentCount": 1]),
            ])
            if let i = posts.firstIndex(where: { $0.id == postId }) { posts[i].commentCount += 1 }
            return true
        } catch { message = error.wallText; return false }
    }

    func deleteComment(_ postId: String, _ cid: String, mineComment: Bool) async {
        var w: [FSWrite] = [.delete("testimonies/\(postId)/comments/\(cid)")]
        if mineComment { w.append(.delete("commentOwners/\(cid)")) }
        w.append(.update("testimonies/\(postId)", ["lastCommentId": .string(cid)], increments: ["commentCount": -1]))
        do { try await Firestore.commit(w); if let i = posts.firstIndex(where: { $0.id == postId }) { posts[i].commentCount -= 1 } }
        catch { message = error.wallText }
    }
}

/// Prayer points for praying along on the wall (once a day counts).
enum PrayerNudge {
    static func prayedOnWall() {
        let k = "wallPrayed-" + AppStore.dayKey()
        if !UserDefaults.standard.bool(forKey: k) { UserDefaults.standard.set(true, forKey: k); Points.award(5) }
    }
}

extension Error {
    var wallText: String {
        switch self as? FSError {
        case .denied: tr("Posting, praying along and comments come with any plan.")
        case .notSignedIn: tr("Couldn't reach HolySteps. Try again in a moment.")
        default: tr("Couldn't connect — check your internet connection.")
        }
    }
}

struct PrayerWallView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var wall = WallModel.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var filter = 0
    @State private var composing: WallType?
    @State private var open: WallPost?
    @State private var answering: WallPost?
    @State private var paywall = false
    @State private var blocking: WallPost?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    T("🕊️ TESTIMONY & PRAYER WALL").font(.hs(11, .semibold)).tracking(0.8).foregroundStyle(HS.gold)
                    T("Share what God is doing").font(.hs(17, .semibold)).foregroundStyle(HS.text)
                }
                Spacer()
                Button { compose(.TESTIMONY) } label: {
                    T("+ Share").font(.hs(13, .semibold)).foregroundStyle(HS.onGold).padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(HS.goldButton))
                }
            }
            .padding(.horizontal, 20)

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    T("💬 TODAY'S QUESTION").font(.hs(11, .semibold)).tracking(1).foregroundStyle(HS.peach)
                    T(DailyQuestion.today).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    HStack {
                        let n = wall.posts.filter { $0.type == "DISCUSSION" && DailyQuestion.isToday($0.createdAt) }.count
                        if n > 0 { D(tr("{0} answers").replacingOccurrences(of: "{0}", with: "\(n)")).font(.hs(12)).foregroundStyle(HS.textMuted) }
                        Spacer()
                        Button { compose(.DISCUSSION) } label: {
                            T("Answer").font(.hs(13, .semibold)).foregroundStyle(HS.onGold).padding(.horizontal, 14).padding(.vertical, 7).background(Capsule().fill(HS.goldButton))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(["All", "Today's question", "Testimonies", "Prayer Requests", "Mine"].enumerated()), id: \.offset) { i, f in
                        Button { filter = i } label: {
                            T(f).font(.hs(13, .semibold)).foregroundStyle(filter == i ? HS.onGold : HS.textSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(filter == i ? HS.goldButton : HS.overlay(0.06)))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
            }

            if let m = wall.message {
                D(m).font(.hs(12)).foregroundStyle(HS.gold).padding(.horizontal, 20)
                    .onTapGesture { wall.message = nil }
            }

            let list = wall.visible(filter)
            if wall.loading && wall.posts.isEmpty {
                ProgressView().tint(HS.gold).padding(30)
            } else if wall.failed {
                VStack(spacing: 8) {
                    T("Couldn't connect — check your internet connection.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    Button { Task { await wall.load() } } label: { T("Try again").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                }.padding(30)
            } else if list.isEmpty {
                VStack(spacing: 8) {
                    Text("🕊️").font(.system(size: 44))
                    T("No posts yet").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                    T("Be the first to share a testimony or a prayer request.").font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                }.padding(30)
            } else {
                ForEach(list) { card($0) }
            }
        }
        .task { await wall.load() }
        .refreshable { await wall.load() }
        .sheet(item: $composing) { t in ComposeWallSheet(type: t) }
        .sheet(item: $open) { p in WallCommentsSheet(post: p) }
        .sheet(item: $answering) { p in WallAnsweredSheet(post: p) }
        .sheet(isPresented: $paywall) { PlansView(feature: .createGroup) }
        .alert(tr("Block this person?"), isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } })) {
            Button(tr("Block"), role: .destructive) { if let b = blocking { wall.hidden.insert(b.authorKey) }; blocking = nil }
            Button(tr("Cancel"), role: .cancel) { blocking = nil }
        } message: { T("You won't see their posts or comments anymore. They aren't told.") }
    }

    private func compose(_ t: WallType) { if account.hasAnyPlan { composing = t } else { paywall = true } }

    private func card(_ p: WallPost) -> some View {
        let isMine = wall.mine.contains(p.id), praying = wall.praying.contains(p.id)
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(LinearGradient(colors: [HS.peach.opacity(0.6), HS.faith.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .overlay(Text(String(p.who.prefix(1))).font(.hs(13, .semibold)).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 1) {
                        D(p.who).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                        D(tr(WallType(rawValue: p.type)?.label ?? "")).font(.hs(10)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    D(p.date.formatted(.relative(presentation: .named).locale(I18n.shared.locale))).font(.hs(11)).foregroundStyle(HS.textMuted)
                    Menu {
                        if isMine {
                            Button(tr("Delete"), role: .destructive) { Task { await wall.delete(p) } }
                        } else {
                            Button(tr("Report")) { Task { await wall.report(p) } }
                            Button(tr("Block this person")) { blocking = p }
                        }
                    } label: { Image(systemName: "ellipsis").foregroundStyle(HS.textMuted).frame(width: 28, height: 28) }
                }
                if p.type == "DISCUSSION" {
                    D("Q: " + tr(DailyQuestion.forDay(DailyQuestion.dayOf(p.createdAt)))).font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                }
                D(p.text).font(.hs(14)).foregroundStyle(HS.text).lineSpacing(4)
                if p.answered {
                    VStack(alignment: .leading, spacing: 2) {
                        T("🙌 Answered").font(.hs(11, .semibold)).foregroundStyle(HS.body)
                        if !p.answeredNote.isEmpty { D(p.answeredNote).font(.hs(13)).foregroundStyle(HS.text) }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(HS.body.opacity(0.1)))
                }
                if p.flagged && p.type == "PRAYER_REQUEST" {
                    T("If you're going through something heavy right now, please also talk to someone today: a friend, a pastor, or a counselor. In the US, you can call or text 988 (Suicide & Crisis Lifeline), free and available 24/7.")
                        .font(.hs(11)).foregroundStyle(HS.text).padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                }
                HStack(spacing: 10) {
                    Button { if account.hasAnyPlan { Task { await wall.togglePraying(p) } } else { paywall = true } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: praying ? "hands.sparkles.fill" : "hands.sparkles").font(.system(size: 13))
                            T(praying ? "Praying" : "Pray").font(.hs(13, .semibold))
                            if p.prayingCount > 0 { D("\(p.prayingCount)").font(.hs(12)) }
                        }
                        .foregroundStyle(praying ? HS.peach : HS.textMuted)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(praying ? HS.peach.opacity(0.12) : HS.overlay(0.06)))
                    }.buttonStyle(.plain)
                    Button { open = p } label: {
                        HStack(spacing: 4) { Text("💬"); D(p.commentCount > 0 ? "\(p.commentCount)" : tr("Comment")).font(.hs(12)) }
                            .foregroundStyle(HS.textMuted)
                    }.buttonStyle(.plain)
                    Spacer()
                    if isMine && p.type == "PRAYER_REQUEST" && !p.answered {
                        Button { answering = p } label: { T("Mark answered").font(.hs(11, .semibold)).foregroundStyle(HS.body) }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct ComposeWallSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var type: WallType
    @State private var text = ""
    @State private var anonymous = false
    @State private var sending = false

    var body: some View {
        HSSheet(title: type == .DISCUSSION ? "Today's question" : "Share with the community") {
            VStack(alignment: .leading, spacing: 14) {
                if type == .DISCUSSION {
                    T(DailyQuestion.today).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                } else {
                    Picker("", selection: $type) {
                        T("🎉 Testimony").tag(WallType.TESTIMONY)
                        T("🙏 Prayer Request").tag(WallType.PRAYER_REQUEST)
                    }.pickerStyle(.segmented)
                }
                TextEditor(text: $text).font(.hs(14)).frame(minHeight: 120, maxHeight: 220).padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                    .onChange(of: text) { _, t in if t.count > 600 { text = String(t.prefix(600)) } }
                D("\(text.count)/600").font(.hs(10)).foregroundStyle(HS.textMuted).frame(maxWidth: .infinity, alignment: .trailing)
                Toggle(isOn: $anonymous) { T("Post anonymously").font(.hs(13)).foregroundStyle(HS.textSecondary) }.tint(HS.gold)
                GoldButton(title: "Share") {
                    sending = true
                    Task {
                        if await WallModel.shared.post(type: type, text: text, anonymous: anonymous, name: store.name) { dismiss() }
                        sending = false
                    }
                }
                .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let m = WallModel.shared.message { D(m).font(.hs(12)).foregroundStyle(HS.gold) }
            }
            .padding(24)
        }
    }
}

private struct WallAnsweredSheet: View {
    let post: WallPost
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    var body: some View {
        HSSheet(title: "Mark as answered 🙌") {
            VStack(alignment: .leading, spacing: 12) {
                T("Want to share how God answered this? (optional)").font(.hs(13)).foregroundStyle(HS.textMuted)
                TextEditor(text: $note).font(.hs(14)).frame(minHeight: 90).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                GoldButton(title: "Mark answered") { Task { await WallModel.shared.markAnswered(post, note: note); dismiss() } }
            }.padding(24)
        }
        .presentationDetents([.medium])
    }
}

private struct WallCommentsSheet: View {
    let post: WallPost
    @EnvironmentObject var store: AppStore
    @ObservedObject private var account = AccountStore.shared
    @ObservedObject private var wall = WallModel.shared
    @State private var comments: [WallComment] = []
    @State private var mineIds: Set<String> = []
    @State private var draft = ""
    @State private var anonymous = false
    @State private var loading = true

    var body: some View {
        HSSheet(title: "Comments") {
            VStack(alignment: .leading, spacing: 12) {
                D(post.text).font(.hs(14)).foregroundStyle(HS.textSecondary).lineLimit(4)
                if loading { ProgressView().tint(HS.gold) }
                else if comments.filter({ !wall.hidden.contains($0.authorKey) }).isEmpty {
                    T("No comments yet.").font(.hs(12)).foregroundStyle(HS.textMuted).padding(.vertical, 12)
                }
                ForEach(comments.filter { !wall.hidden.contains($0.authorKey) }) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            D(c.who).font(.hs(12, .semibold)).foregroundStyle(HS.text)
                            Spacer()
                            if mineIds.contains(c.id) || wall.mine.contains(post.id) {
                                Button { Task { await wall.deleteComment(post.id, c.id, mineComment: mineIds.contains(c.id)); await reload() } } label: {
                                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(HS.textMuted)
                                }
                            }
                        }
                        D(c.text).font(.hs(14)).foregroundStyle(HS.text)
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                }
                if account.hasAnyPlan {
                    HStack {
                        TextField(tr("Add a comment…"), text: $draft, axis: .vertical).font(.hs(14)).padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        Button {
                            let t = draft
                            Task { if await wall.addComment(post.id, text: t, anonymous: anonymous, name: store.name) { draft = ""; await reload() } }
                        } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 28)).foregroundStyle(HS.gold) }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Toggle(isOn: $anonymous) { T("Comment anonymously").font(.hs(12)).foregroundStyle(HS.textSecondary) }.tint(HS.gold)
                } else {
                    T("Groups, duels, circles and posting on the prayer wall\ncome with any plan.").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
            }
            .padding(24)
        }
        .task { await reload() }
    }

    private func reload() async {
        async let c = wall.comments(post.id)
        async let m = wall.myComments(post.id)
        comments = await c; mineIds = await m; loading = false
    }
}
