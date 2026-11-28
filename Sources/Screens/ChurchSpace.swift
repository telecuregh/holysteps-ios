import SwiftUI

/// Your church on HolySteps, live from Firestore (`churches`), the same church space as Android. Join with the
/// code your pastor shares (Complete, or a seat on your church's plan; the rules check). Leaders post the week's
/// sermon notes; members read them, react and comment. Churches are created from a Church plan on holysteps.org.
struct Church: Identifiable, Equatable {
    let id: String
    var name, ownerUid, inviteCode: String
    var adminUids, memberUids: [String]
    init(_ d: FSDoc) {
        id = d.id; name = d["name"].string; ownerUid = d["ownerUid"].string; inviteCode = d["inviteCode"].string
        adminUids = d["adminUids"].array.map(\.string); memberUids = d["memberUids"].array.map(\.string)
    }
}

struct ChurchSermon: Identifiable {
    let id, title, speaker, date, passages, outline: String
}

struct ChurchComment: Identifiable { let id, uid, name, text: String }

@MainActor
final class ChurchModel: ObservableObject {
    static let shared = ChurchModel()
    @Published private(set) var churches: [Church] = []
    @Published private(set) var loading = true
    @Published var message: String?
    var uid: String? { AccountStore.shared.uid }

    func load() async {
        guard let uid else { loading = false; return }
        churches = ((try? await Firestore.query("churches", filters: [.init(field: "memberUids", op: "ARRAY_CONTAINS", value: .string(uid))], limit: 10)) ?? []).map(Church.init)
        loading = false
    }

    func join(code: String, name: String) async {
        guard let uid else { return }
        guard let inv = await InviteCode.resolve(code), inv.type == "church" else { message = tr("That code wasn't found. Check it and try again."); return }
        do {
            try await Firestore.commit([.update("churches/\(inv.target)", ["joinCode": .string(InviteCode.clean(code))], unions: ["memberUids": [.string(uid)]])])
            try await Firestore.commit([.set("churches/\(inv.target)/members/\(uid)", ["displayName": .string(String((name.isEmpty ? tr("A friend") : name).prefix(160))),
                                                                                       "joinedAt": .int(Firestore.nowMs)])])
            message = nil
        } catch FSError.denied { message = tr("Your church comes with Complete,\nor a seat on your church's own plan.") }
        catch { message = error.wallText }
        await load()
    }

    func leave(_ c: Church) async {
        guard let uid else { return }
        try? await Firestore.commit([.delete("churches/\(c.id)/members/\(uid)")])
        do { try await Firestore.commit([.update("churches/\(c.id)", ["memberUids": .array(c.memberUids.filter { $0 != uid }.map { .string($0) })])]) }
        catch { message = error.wallText }
        await load()
    }

    func sermons(_ c: Church) async -> [ChurchSermon] {
        ((try? await Firestore.query("sermons", parent: "churches/\(c.id)", orderBy: "date", limit: 30)) ?? []).map {
            ChurchSermon(id: $0.id, title: $0["title"].string, speaker: $0["speaker"].string, date: $0["date"].string,
                         passages: $0["passages"].string, outline: $0["outline"].string)
        }
    }

    func post(_ c: Church, title: String, speaker: String, date: Date, passages: String, outline: String) async -> Bool {
        guard let uid else { return false }
        let now = Firestore.nowMs
        do {
            try await Firestore.commit([.set("churches/\(c.id)/sermons/\(Firestore.newId())", [
                "title": .string(String(title.prefix(300))), "speaker": .string(String(speaker.prefix(160))), "date": .string(AppStore.dayKey(date)),
                "passages": .string(String(passages.prefix(600))), "outline": .string(String(outline.prefix(8000))),
                "createdBy": .string(uid), "createdAt": .int(now), "updatedAt": .int(now)], mustNotExist: true)])
            return true
        } catch { message = error.wallText; return false }
    }

    func deleteSermon(_ c: Church, _ s: ChurchSermon) async {
        try? await Firestore.commit([.delete("churches/\(c.id)/sermons/\(s.id)")])
    }

    func comments(_ c: Church, _ s: ChurchSermon) async -> [ChurchComment] {
        ((try? await Firestore.query("comments", parent: "churches/\(c.id)/sermons/\(s.id)", orderBy: "at", descending: false, limit: 200)) ?? []).map {
            ChurchComment(id: $0.id, uid: $0["uid"].string, name: $0["name"].string, text: $0["text"].string)
        }
    }

    func comment(_ c: Church, _ s: ChurchSermon, text: String, name: String) async -> Bool {
        guard let uid else { return false }
        do {
            try await Firestore.commit([.set("churches/\(c.id)/sermons/\(s.id)/comments/\(Firestore.newId())", [
                "uid": .string(uid), "name": .string(String((name.isEmpty ? tr("A friend") : name).prefix(60))),
                "text": .string(String(text.prefix(1000))), "at": .int(Firestore.nowMs)], mustNotExist: true)])
            return true
        } catch { message = error.wallText; return false }
    }

    func react(_ c: Church, _ s: ChurchSermon, emoji: String) async {
        guard let uid else { return }
        try? await Firestore.commit([.set("churches/\(c.id)/sermons/\(s.id)/reactions/\(uid)", ["emoji": .string(emoji), "at": .int(Firestore.nowMs)])])
    }
}

struct ChurchTab: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = ChurchModel.shared
    @State private var joining = false
    @State private var code = ""

    var body: some View {
        VStack(spacing: 10) {
            if let m = model.message { D(m).font(.hs(12)).foregroundStyle(HS.gold).padding(.horizontal, 20).onTapGesture { model.message = nil } }
            if model.loading { ProgressView().tint(HS.gold).padding(20) }
            ForEach(model.churches) { c in
                NavigationLink { ChurchHomeView(church: c) } label: {
                    GlassCard {
                        HStack(spacing: 10) {
                            IconBadge(symbol: "building.columns", size: 36, tint: 0xD6AA6E)
                            VStack(alignment: .leading, spacing: 2) {
                                D(c.name).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                D(tr("{0} members").replacingOccurrences(of: "{0}", with: "\(c.memberUids.count)")).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(HS.textSubtle)
                        }
                    }
                }.buttonStyle(.plain).padding(.horizontal, 20)
            }
            if !model.loading && model.churches.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            IconBadge(symbol: "building.columns", size: 36, tint: 0xD6AA6E)
                            T("My Church").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        }
                        T("Ask your pastor or admin for your church's HolySteps code to unlock your church community.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        GoldButton(title: "Enter church code") { joining = true }
                        ScanQRButton(label: "Scan your church's QR code") { c in Task { await model.join(code: c, name: store.name) } }
                        Link(destination: URL(string: "https://holysteps.org/?plan=church&mode=faith#pricing")!) {
                            T("Bring HolySteps to your church").font(.hs(13, .semibold)).foregroundStyle(HS.peach)
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .alert(tr("Enter church code"), isPresented: $joining) {
            TextField(tr("Code"), text: $code).textInputAutocapitalization(.characters)
            Button(tr("Join")) { let c = code; code = ""; Task { await model.join(code: c, name: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
    }
}

struct ChurchHomeView: View {
    let church: Church
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = ChurchModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sermons: [ChurchSermon] = []
    @State private var posting = false
    @State private var confirmLeave = false
    private var leader: Bool { church.adminUids.contains(model.uid ?? "-") }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    D(church.name).font(.hs(26, .semibold)).foregroundStyle(HS.text).padding(.top, 58)
                    D(tr("{0} members").replacingOccurrences(of: "{0}", with: "\(church.memberUids.count)")).font(.hs(13)).foregroundStyle(HS.textMuted)
                    if leader {
                        GoldButton(title: "Post this week's sermon") { posting = true }
                        ShareLink(item: InviteCode.link(church.inviteCode)) {
                            D(tr("Invite (code {0})").replacingOccurrences(of: "{0}", with: church.inviteCode)).font(.hs(14, .semibold)).foregroundStyle(HS.gold)
                        }
                        ShowQRButton(code: church.inviteCode)
                    }
                    SectionHeader(title: "Sermons").padding(.horizontal, -20)
                    if sermons.isEmpty { T("Your church's sermon notes will show here once a leader posts them.").font(.hs(13)).foregroundStyle(HS.textMuted) }
                    ForEach(sermons) { s in
                        NavigationLink { ChurchSermonView(church: church, sermon: s, leader: leader) } label: {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    D(s.title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                    D([s.speaker, s.date, s.passages].filter { !$0.isEmpty }.joined(separator: " · ")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.buttonStyle(.plain)
                    }
                    if church.ownerUid != model.uid {
                        Button { confirmLeave = true } label: { T("Leave this church").font(.hs(13)).foregroundStyle(.red.opacity(0.8)) }.padding(.top, 10)
                    }
                    Spacer().frame(height: 60)
                }.padding(.horizontal, 20)
            }
            .refreshable { sermons = await model.sermons(church) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .task { sermons = await model.sermons(church) }
        .sheet(isPresented: $posting) { PostSermonSheet(church: church) { Task { sermons = await model.sermons(church) } } }
        .confirmationDialog(tr("Leave this church?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(tr("Leave"), role: .destructive) { Task { await model.leave(church); dismiss() } }
        }
    }
}

private struct PostSermonSheet: View {
    let church: Church
    var done: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var speaker = ""
    @State private var passages = ""
    @State private var outline = ""
    @State private var date = Date()

    var body: some View {
        HSSheet(title: "Post this week's sermon") {
            VStack(alignment: .leading, spacing: 10) {
                field("Title", $title); field("Speaker", $speaker); field("Passages (e.g. John 3:1-21)", $passages)
                DatePicker(tr("Date"), selection: $date, displayedComponents: .date)
                T("Notes and outline").font(.hs(13)).foregroundStyle(HS.textMuted)
                TextEditor(text: $outline).frame(minHeight: 160).padding(8).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                GoldButton(title: "Post") { Task { if await ChurchModel.shared.post(church, title: title, speaker: speaker, date: date, passages: passages, outline: outline) { done(); dismiss() } } }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(24)
        }
    }
    private func field(_ label: String, _ b: Binding<String>) -> some View {
        TextField(tr(label), text: b).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
    }
}

struct ChurchSermonView: View {
    let church: Church
    let sermon: ChurchSermon
    let leader: Bool
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = ChurchModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [ChurchComment] = []
    @State private var draft = ""
    @State private var reacted = ""

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    D(sermon.title).font(.hs(24, .semibold)).foregroundStyle(HS.text).padding(.top, 58)
                    D([sermon.speaker, sermon.date, sermon.passages].filter { !$0.isEmpty }.joined(separator: " · ")).font(.hs(13)).foregroundStyle(HS.textMuted)
                    D(sermon.outline).font(.hs(15)).foregroundStyle(HS.text).lineSpacing(5).textSelection(.enabled)
                    HStack(spacing: 14) {
                        ForEach(["🙏", "❤️", "🙌", "🔥"], id: \.self) { e in
                            Button { reacted = e; Task { await model.react(church, sermon, emoji: e) } } label: {
                                Text(e).font(.system(size: 26)).padding(6).background(Circle().fill(reacted == e ? HS.gold.opacity(0.25) : .clear))
                            }
                        }
                    }
                    SectionHeader(title: "Comments").padding(.horizontal, -20)
                    ForEach(comments) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            D(c.name).font(.hs(12, .semibold)).foregroundStyle(HS.text)
                            D(c.text).font(.hs(14)).foregroundStyle(HS.text)
                        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                    }
                    HStack {
                        TextField(tr("Add a comment…"), text: $draft, axis: .vertical).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        Button { let t = draft; Task { if await model.comment(church, sermon, text: t, name: store.name) { draft = ""; comments = await model.comments(church, sermon) } } } label: {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 28)).foregroundStyle(HS.gold)
                        }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if leader {
                        Button(role: .destructive) { Task { await model.deleteSermon(church, sermon); dismiss() } } label: { T("Delete sermon").font(.hs(13)).foregroundStyle(.red.opacity(0.8)) }
                    }
                    Spacer().frame(height: 60)
                }.padding(.horizontal, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .task { comments = await model.comments(church, sermon) }
    }
}
