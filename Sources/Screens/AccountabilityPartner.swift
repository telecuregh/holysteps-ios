import SwiftUI
import CryptoKit

/// Android's accountability partner (data/AccountabilityPartner.kt, data/PartnerSync.kt, ui/screens/FreedomPartnerScreen.kt),
/// on the same Firestore documents and the same end-to-end sealing (PairCrypto), so an iPhone and an Android phone can
/// be partners. Strictly opt-in and strictly limited: Freedom never leaves the phone; a person shares only what they
/// switch on (the day their streak began, the date of their last check-in, and a message when they slip or the
/// protection is turned off), and every name, number and message is sealed with a key made from the secret in the
/// invite. Firestore sees only who is paired with whom, when something was written, and sealed boxes.
enum PartnerKind: String, CaseIterable {
    case ENCOURAGE, STRUGGLING, NUDGE, SLIP, PROTECTION_OFF
    var label: String {
        switch self {
        case .ENCOURAGE: "Encouragement"; case .STRUGGLING: "Asking for support"; case .NUDGE: "Checking in"
        case .SLIP: "A slip"; case .PROTECTION_OFF: "Protection turned off"
        }
    }
}

struct PartnerLink: Codable, Equatable {
    var pairId: String
    /// The full invite (code and secret), kept so the person who invited can show it again while they wait.
    var inviteCode = ""
    var secret = ""
    var myName = ""
    /// Share numbers from Freedom; false means this person only supports their partner.
    var sharesFreedom = false
    var shareStreak = false
    var shareCheckIns = false
    var alertSlips = false
    var alertProtection = false
    var seenMs: Int64 = 0
    /// Automatic alerts that couldn't be sent yet (no connection); retried until they go.
    var pending: [String] = []
}

struct PartnerShare: Equatable { var displayName: String; var updatedAt: Int64; var streakStart: Int64?; var lastCheckIn: String? }
struct PartnerMessage: Identifiable, Equatable {
    let id: String, fromUid: String, kind: PartnerKind, text: String, createdAt: Int64
}

enum PartnerText {
    static let messageMax = 200
    static let nameMax = 40
    static let encouragements = ["Praying for you 🙏", "Proud of you. Keep going.", "I'm here if you want to talk.", "One day at a time. You've got this 💪"]
    static let struggling = "I'm struggling right now. Could you pray for me, or call?"
    static let nudge = "Just checking in on you. How are you doing?"
    static let slip = "I slipped, and I'm starting again. Please pray for me."
    static let protection = "The protection on my phone was switched off."
    static func invite(_ code: String) -> String {
        "I'd like you to be my accountability partner in HolySteps. Open HolySteps, tap Profile, then Accountability partner, and enter this code: \(code)"
    }
    static func counter(_ ms: Int64) -> (String, String) {
        let days = ms / 86_400_000
        if days >= 1 { return ("\(days)", days == 1 ? "day free" : "days free") }
        let hours = ms / 3_600_000
        if hours >= 1 { return ("\(hours)", hours == 1 ? "hour free" : "hours free") }
        let m = max(0, ms / 60_000)
        return ("\(m)", m == 1 ? "minute free" : "minutes free")
    }
    static func ago(_ then: Int64, _ now: Int64) -> String {
        let m = max(0, now - then) / 60_000
        if m < 1 { return "just now" }
        if m < 60 { return "\(m) min ago" }
        if m < 1440 { return "\(m / 60) h ago" }
        return "\(m / 1440) \(m / 1440 == 1 ? "day" : "days") ago"
    }
    static func daysAgo(_ date: String) -> String? {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: date), let t = f.date(from: AppStore.dayKey()) else { return nil }
        let gap = Int((t.timeIntervalSince(d) / 86_400).rounded())
        return gap <= 0 ? "today" : gap == 1 ? "yesterday" : "\(gap) days ago"
    }
}

extension PairCrypto {
    /// A short opaque label for document ids, so an id doesn't say what kind of message it is (Android's tag).
    static func tag(_ key: SymmetricKey, _ label: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data("tag|\(label)".utf8), using: key)
        return String(Data(mac).map { String(format: "%02x", $0) }.joined().prefix(12))
    }
}

@MainActor
final class PartnerModel: ObservableObject {
    static let shared = PartnerModel()
    @Published private(set) var link: PartnerLink?
    @Published private(set) var loaded = false
    @Published private(set) var members: [String] = []
    @Published private(set) var ended = false
    @Published private(set) var shares: [String: PartnerShare] = [:]
    @Published private(set) var messages: [PartnerMessage] = []

    private let keychainKey = "freedomPartner"
    var uid: String? { AccountStore.shared.uid }

    private init() {
        // Kept in the Keychain on this phone only, like Android keeps it inside Freedom's encrypted file.
        if let s = Keychain.get(keychainKey), let d = s.data(using: .utf8) { link = try? JSONDecoder().decode(PartnerLink.self, from: d) }
    }

    private func save(_ l: PartnerLink?) {
        link = l
        Keychain.set(l.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }, for: keychainKey)
    }

    private var key: SymmetricKey? { link.flatMap { $0.secret.isEmpty ? nil : PairCrypto.key($0.secret, docId: $0.pairId) } }
    private func pairPath(_ id: String) -> String { "accountabilityPairs/\(id)" }
    private func shareContext(_ pairId: String, _ uid: String) -> String { "holysteps-share-v1|\(pairId)|\(uid)" }
    private func messageContext(_ pairId: String, _ id: String) -> String { "holysteps-msg-v1|\(pairId)|\(id)" }

    var waiting: Bool { loaded && !ended && members.count < 2 }
    var otherUid: String? { members.first { $0 != uid } }
    var unread: Int { messages.filter { $0.fromUid != uid && $0.createdAt > (link?.seenMs ?? 0) }.count }

    // MARK: Pairing

    enum Problem: Error { case notSignedIn, alreadyPaired, notFound, own, unavailable, failed }

    func invite(_ template: PartnerLink) async -> Problem? {
        guard let me = await AccountStore.shared.ensureUid() else { return .notSignedIn }
        guard link == nil else { return .alreadyPaired }
        let id = Firestore.newId(), code = InviteCode.make("PAIR")
        do {
            try await Firestore.commit([.set(pairPath(id), ["memberUids": .array([.string(me)]), "ownerUid": .string(me),
                                                           "inviteCode": .string(code), "createdAt": .int(Firestore.nowMs)], mustNotExist: true)])
            do { try await InviteCode.register(code, type: "accountabilityPair", target: id, uid: me) }
            catch { try? await Firestore.commit([.delete(pairPath(id))]); throw error }   // a pair nobody can join is no use
            let secret = PairCrypto.newSecret()
            var l = template
            l.pairId = id; l.inviteCode = PairCrypto.invite(code, secret); l.secret = secret
            save(l)
            await publish()
            await refresh()
            return nil
        } catch { return .failed }
    }

    func accept(_ typed: String, _ template: PartnerLink) async -> Problem? {
        guard let me = await AccountStore.shared.ensureUid() else { return .notSignedIn }
        guard link == nil else { return .alreadyPaired }
        guard let parts = PairCrypto.split(InviteCode.clean(typed), prefix: "PAIR") else { return .notFound }
        let lookup = parts.code, secret = parts.secret
        guard let inv = try? await Firestore.get("inviteCodes/\(lookup)"), inv["type"].string == "accountabilityPair" else { return .notFound }
        if inv["createdBy"].string == me { return .own }
        let target = inv["targetId"].string
        guard target.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else { return .notFound }
        do {
            try await Firestore.commit([.update(pairPath(target), [:], unions: ["memberUids": [.string(me)]])])
        } catch FSError.denied { return .unavailable } catch { return .failed }
        var l = template
        l.pairId = target; l.inviteCode = ""; l.secret = secret
        save(l)
        await publish()
        await refresh()
        return nil
    }

    /// Ends the partnership: this person's shared items go first; the last one out also clears the messages and the pairing.
    func leave() async -> Bool {
        guard let l = link else { return true }
        guard let me = uid else { return false }
        try? await Firestore.commit([.delete("\(pairPath(l.pairId))/shares/\(me)")])
        do {
            if let doc = try await Firestore.get(pairPath(l.pairId)) {
                let m = doc["memberUids"].array.map(\.string)
                if m.allSatisfy({ $0 == me }) {
                    let msgs = (try? await Firestore.query("messages", parent: pairPath(l.pairId), limit: 300)) ?? []
                    for chunk in stride(from: 0, to: msgs.count, by: 100) {
                        try? await Firestore.commit(msgs[chunk..<min(msgs.count, chunk + 100)].map { FSWrite.delete($0.path) })
                    }
                    try await Firestore.commit([.delete(pairPath(l.pairId))])
                } else {
                    try await Firestore.commit([.update(pairPath(l.pairId), ["memberUids": .array(m.filter { $0 != me }.map { .string($0) })])])
                }
            }
        } catch FSError.denied {
            // Already gone, or no longer a member.
        } catch { return false }
        save(nil)
        members = []; shares = [:]; messages = []; ended = false; loaded = false
        return true
    }

    // MARK: Live state

    func refresh() async {
        guard let l = link else { loaded = true; return }
        do {
            if let doc = try await Firestore.get(pairPath(l.pairId)) {
                members = doc["memberUids"].array.map(\.string); ended = false
            } else { ended = true }
        } catch FSError.denied { ended = true } catch { }
        loaded = true
        guard !ended, let k = key else { return }
        let sh = (try? await Firestore.query("shares", parent: pairPath(l.pairId), limit: 4)) ?? []
        var out: [String: PartnerShare] = [:]
        for d in sh {
            guard let o = PairCrypto.open(k, d["box"].string, context: shareContext(l.pairId, d.id)) else { continue }
            out[d.id] = PartnerShare(displayName: o["displayName"] as? String ?? "", updatedAt: d["updatedAt"].int,
                                     streakStart: (o["streakStart"] as? NSNumber)?.int64Value, lastCheckIn: (o["lastCheckIn"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        }
        shares = out
        let ms = (try? await Firestore.query("messages", parent: pairPath(l.pairId), orderBy: "createdAt", descending: true, limit: 30)) ?? []
        messages = ms.compactMap { d in
            guard let o = PairCrypto.open(k, d["box"].string, context: messageContext(l.pairId, d.id)) else { return nil }
            return PartnerMessage(id: d.id, fromUid: d["fromUid"].string, kind: PartnerKind(rawValue: o["kind"] as? String ?? "") ?? .ENCOURAGE,
                                  text: o["text"] as? String ?? "", createdAt: d["createdAt"].int)
        }
        await flushPending()
    }

    func markSeen() {
        guard var l = link, let newest = messages.map(\.createdAt).max(), newest > l.seenMs else { return }
        l.seenMs = newest; save(l)
    }

    func update(_ change: (inout PartnerLink) -> Void) {
        guard var l = link else { return }
        change(&l)
        if !l.sharesFreedom { l.shareStreak = false; l.shareCheckIns = false; l.alertSlips = false; l.alertProtection = false }
        save(l)
        Task { await publish() }
    }

    // MARK: Sharing and messages

    /// What the partner sees: the chosen name, and only the items switched on (Android's partnerShareFields).
    static func shareFields(_ l: PartnerLink) -> [String: Any] {
        var out: [String: Any] = ["displayName": String((l.myName.trimmingCharacters(in: .whitespaces).isEmpty ? "Your partner" : l.myName.trimmingCharacters(in: .whitespaces)).prefix(PartnerText.nameMax))]
        guard l.sharesFreedom else { return out }
        let d = UserDefaults.standard
        if l.shareStreak, let start = d.string(forKey: "freedom.startDay") {
            let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
            if let day = f.date(from: start) { out["streakStart"] = Int64(day.timeIntervalSince1970 * 1000) }
        }
        if l.shareCheckIns, let last = d.string(forKey: "freedom.checkInDay"), !last.isEmpty { out["lastCheckIn"] = last }
        return out
    }

    /// Replaces this person's shared document, so anything switched off disappears from it.
    func publish() async {
        guard let l = link, let me = uid, let k = key,
              let box = PairCrypto.seal(k, Self.shareFields(l), context: shareContext(l.pairId, me)) else { return }
        try? await Firestore.commit([.set("\(pairPath(l.pairId))/shares/\(me)", ["box": .string(box), "updatedAt": .int(Firestore.nowMs)])])
    }

    enum Outcome { case sent, alreadySent, failed }

    /// One message per sender, kind and hour (the document id), so a partner can't be flooded.
    func send(_ kind: PartnerKind, _ text: String) async -> Outcome {
        guard let l = link, let me = uid, let k = key else { return .failed }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PartnerText.messageMax))
        guard !clean.isEmpty else { return .failed }
        let at = Firestore.nowMs
        let id = "\(me)_\(PairCrypto.tag(k, kind.rawValue))_\(at / 3_600_000)"
        guard let box = PairCrypto.seal(k, ["kind": kind.rawValue, "text": clean], context: messageContext(l.pairId, id)) else { return .failed }
        // A second one of the same kind this hour lands on the same id, and the rules refuse to change it.
        do {
            try await Firestore.commit([.set("\(pairPath(l.pairId))/messages/\(id)", ["fromUid": .string(me), "box": .string(box), "createdAt": .int(at)])])
            return .sent
        } catch FSError.denied { return .alreadySent } catch { return .failed }
    }

    /// A slip recorded in Freedom (when "Tell them when I slip" is on).
    func slipped() {
        guard let l = link, l.sharesFreedom, l.alertSlips else { Task { await publish() }; return }
        queue(.SLIP)
    }

    /// The protection on this phone was switched off (when that alert is on).
    func protectionOff() {
        guard let l = link, l.sharesFreedom, l.alertProtection else { return }
        queue(.PROTECTION_OFF)
    }

    private func queue(_ kind: PartnerKind) {
        update { if !$0.pending.contains(kind.rawValue) { $0.pending.append(kind.rawValue) } }
        Task { await flushPending() }
    }

    private func flushPending() async {
        guard let l = link, !l.pending.isEmpty else { return }
        for raw in l.pending {
            guard let kind = PartnerKind(rawValue: raw) else { continue }
            let r = await send(kind, kind == .SLIP ? PartnerText.slip : PartnerText.protection)
            if r != .failed { update { $0.pending.removeAll { $0 == raw } } }
        }
    }
}

// MARK: - Screen

struct AccountabilityPartnerView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = PartnerModel.shared
    var body: some View {
        ZStack {
            HSBackground()
            if model.link == nil { PartnerSetupView() } else { PartnerHomeView() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
    }
}

private struct PartnerCard<C: View>: View {
    let title: String
    @ViewBuilder var content: () -> C
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T(title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PartnerBullet: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 6) { D("•").foregroundStyle(HS.faith); T(text).font(.hs(13)).foregroundStyle(HS.textSecondary) }
    }
}

private struct WhatIsShared: View {
    var body: some View {
        PartnerCard(title: "What your partner can see") {
            PartnerBullet(text: "The name you choose to give them.")
            PartnerBullet(text: "Only if you switch them on: how many days you've been free (the date your streak began), the date of your last check-in, and a message when you slip or when the protection on your phone is switched off.")
            PartnerBullet(text: "The kind words and requests for support you send each other.")
            T("Never your note, your commitment, or anything else in Freedom. If you share your streak, your partner will see it start over after a slip.")
                .font(.hs(12)).foregroundStyle(HS.textMuted)
        }
    }
}

private struct WhatTheServerKeeps: View {
    var body: some View {
        PartnerCard(title: "What HolySteps stores") {
            T("That the two of you are paired, the items above that you switched on, and your messages, sealed so that only your two phones can read them. Ending the partnership deletes your shared items and messages, and deleting your account removes them too.")
                .font(.hs(13)).foregroundStyle(HS.textSecondary)
            T("Messages show up when you open this screen. This isn't an emergency line. If you need someone now, call your trusted person, or call or text 988.")
                .font(.hs(12)).foregroundStyle(HS.textMuted)
        }
    }
}

private struct ShareToggles: View {
    @Binding var shares: Bool
    @Binding var streak: Bool
    @Binding var checkIns: Bool
    @Binding var slips: Bool
    @Binding var protection: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            T("Share numbers from").font(.hs(12)).foregroundStyle(HS.textMuted)
            HStack(spacing: 8) {
                chip("My Freedom streak", shares) { shares = true }
                chip("Nothing, I only support", !shares) { shares = false }
            }
            toggle("Days free", "They see how many days you've been free.", $streak)
            toggle("Check-ins", "They see the date of your last check-in.", $checkIns)
            toggle("Tell them when I slip", "Sends a kind, short message the moment you record a slip.", $slips)
            toggle("Tell them if protection is switched off", "Sends a message if the protection on this phone is turned off.", $protection)
        }
    }
    private func chip(_ t: String, _ on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            T(t).font(.hs(12, .semibold)).foregroundStyle(on ? HS.text : HS.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(on ? HS.goldButton.opacity(0.22) : HS.cardFill))
                .overlay(Capsule().strokeBorder(Color(hex: 0xD9B49F).opacity(on ? 1 : 0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    private func toggle(_ title: String, _ body: String, _ v: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(get: { shares && v.wrappedValue }, set: { v.wrappedValue = $0 })) {
            VStack(alignment: .leading, spacing: 2) {
                T(title).font(.hs(14, .semibold)).foregroundStyle(shares ? HS.text : HS.textMuted)
                T(body).font(.hs(12)).foregroundStyle(HS.textMuted)
            }
        }
        .tint(HS.goldButton).disabled(!shares)
    }
}

private struct PartnerSetupView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var model = PartnerModel.shared
    @State private var name = ""
    @State private var shares = true
    @State private var streak = false
    @State private var checkIns = false
    @State private var slips = false
    @State private var protection = false
    @State private var joining = false
    @State private var code = ""
    @State private var busy = false
    @State private var error = ""

    private var template: PartnerLink {
        PartnerLink(pairId: "", myName: String((name.trimmingCharacters(in: .whitespaces).isEmpty ? "Your partner" : name).prefix(PartnerText.nameMax)),
                    sharesFreedom: shares, shareStreak: shares && streak, shareCheckIns: shares && checkIns,
                    alertSlips: shares && slips, alertProtection: shares && protection)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                T("Accountability partner").font(.hs(26, .bold)).foregroundStyle(HS.text).padding(.top, 58)
                T("Two people who look out for each other. It's your choice, it's private between the two of you, and you decide exactly what is shared.")
                    .font(.hs(14)).foregroundStyle(HS.textSecondary)
                WhatIsShared()
                PartnerCard(title: "How you'll appear") {
                    TextField(tr("A first name or nickname"), text: $name)
                        .font(.hs(15)).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        .onChange(of: name) { _, v in if v.count > PartnerText.nameMax { name = String(v.prefix(PartnerText.nameMax)) } }
                }
                PartnerCard(title: "What to share (all off until you switch them on)") {
                    ShareToggles(shares: $shares, streak: $streak, checkIns: $checkIns, slips: $slips, protection: $protection)
                }
                WhatTheServerKeeps()
                if !error.isEmpty { T(error).font(.hs(13)).foregroundStyle(Color(hex: 0xF59E0B)) }
                if !joining {
                    GoldButton(title: busy ? "One moment…" : "Invite a partner") {
                        guard !busy else { return }
                        busy = true; error = ""
                        Task {
                            if let p = await model.invite(template) { error = message(p) }
                            busy = false
                        }
                    }
                    .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button { joining = true; error = "" } label: {
                        T("I have an invitation code").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().strokeBorder(HS.gold.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                } else {
                    PartnerCard(title: "Enter the code your partner gave you") {
                        TextField("PAIR-ABC2345678-…", text: $code)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .font(.system(size: 15, design: .monospaced)).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                            .onChange(of: code) { _, v in
                                let c = String(v.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(40))
                                if c != v { code = c }
                            }
                        GoldButton(title: busy ? "Joining…" : "Join") {
                            guard !busy else { return }
                            busy = true; error = ""
                            Task {
                                if let p = await model.accept(code, template) { error = message(p) }
                                busy = false
                            }
                        }
                        .disabled(busy || code.count < 8 || name.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button { joining = false; error = "" } label: { T("Back").font(.hs(14)).foregroundStyle(HS.textMuted) }
                            .buttonStyle(.plain)
                    }
                }
                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            if name.isEmpty { name = String(store.name.prefix(PartnerText.nameMax)) }
            let invited = InviteInbox.take("PAIR")
            if !invited.isEmpty { code = invited; joining = true }
        }
    }

    private func message(_ p: PartnerModel.Problem) -> String {
        switch p {
        case .notSignedIn: tr("HolySteps is still connecting your account. Try again in a moment.")
        case .alreadyPaired: tr("You already have a partner or an open invitation.")
        case .notFound: tr("That code wasn't found. Check it and try again.")
        case .own: tr("That's your own invitation. Send it to your partner instead.")
        case .unavailable: tr("That invitation isn't available any more. It may already have a partner, or it was ended.")
        case .failed: tr("Couldn't do that right now. Check your connection and try again.")
        }
    }
}

private struct PartnerHomeView: View {
    @ObservedObject private var model = PartnerModel.shared
    @State private var custom = ""
    @State private var status = ""
    @State private var confirmEnd = false
    @State private var ending = false
    @State private var name = ""
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let link = model.link ?? PartnerLink(pairId: "")
        let theirs = model.otherUid.flatMap { model.shares[$0] }
        let theirName = (theirs?.displayName).flatMap { $0.isEmpty ? nil : $0 } ?? tr("Your partner")
        let now = Firestore.nowMs
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                T("Accountability partner").font(.hs(26, .bold)).foregroundStyle(HS.text).padding(.top, 58)
                if model.ended {
                    PartnerCard(title: "This partnership has ended") {
                        T("Your partner ended it, or it's no longer available. Nothing of yours is still shared.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        GoldButton(title: "Clear this") { Task { _ = await model.leave() } }
                    }
                } else if !model.loaded {
                    ProgressView().frame(maxWidth: .infinity).padding(24)
                } else {
                    if model.waiting {
                        PartnerCard(title: "Waiting for your partner to join") {
                            T("Send them this code. It works once, for one person.").font(.hs(12)).foregroundStyle(HS.textMuted)
                            if !link.inviteCode.isEmpty {
                                Text(link.inviteCode).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(HS.text)
                                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 10).textSelection(.enabled)
                                ShareLink(item: InviteCode.link(link.inviteCode), message: Text(PartnerText.invite(link.inviteCode))) {
                                    T("Share the invitation").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                                        .frame(maxWidth: .infinity).padding(.vertical, 13).background(Capsule().fill(HS.goldButton))
                                }
                                ShowQRButton(code: link.inviteCode)
                            }
                        }
                    } else {
                        PartnerCard(title: theirName) {
                            if let start = theirs?.streakStart {
                                let c = PartnerText.counter(now - start)
                                D("\(c.0) " + tr(c.1)).font(.hs(22, .bold)).foregroundStyle(HS.body)
                                if now - start < 86_400_000 { T("Just starting again. Encouragement matters most now.").font(.hs(12)).foregroundStyle(HS.textMuted) }
                            }
                            if let last = theirs?.lastCheckIn, let label = PartnerText.daysAgo(last) {
                                D(tr("Last check-in:") + " " + tr(label)).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            }
                            if theirs?.streakStart == nil && theirs?.lastCheckIn == nil {
                                D(theirName + " " + tr("hasn't chosen to share any progress. You can still encourage them.")).font(.hs(13)).foregroundStyle(HS.textMuted)
                            }
                            if let u = theirs?.updatedAt, u > 0 { D(tr("Updated") + " " + tr(PartnerText.ago(u, now))).font(.hs(11)).foregroundStyle(HS.textMuted) }
                        }
                        PartnerCard(title: tr("Encourage") + " " + theirName) {
                            FlexibleChips(items: PartnerText.encouragements) { t in send(.ENCOURAGE, t) }
                            TextField(tr("Write your own"), text: $custom, axis: .vertical)
                                .font(.hs(14)).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                                .onChange(of: custom) { _, v in if v.count > PartnerText.messageMax { custom = String(v.prefix(PartnerText.messageMax)) } }
                            HStack(spacing: 8) {
                                small("Send") { if !custom.trimmingCharacters(in: .whitespaces).isEmpty { send(.ENCOURAGE, custom, clear: true) } }
                                small("Check in on them") { send(.NUDGE, PartnerText.nudge) }
                            }
                        }
                        PartnerCard(title: "If you need support") {
                            D(tr("Tell") + " " + theirName + " " + tr("you're struggling, so they can pray for you or call.")).font(.hs(12)).foregroundStyle(HS.textMuted)
                            Button { send(.STRUGGLING, PartnerText.struggling) } label: {
                                T("I'm struggling right now").font(.hs(15, .bold)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 13).background(Capsule().fill(Color(hex: 0xF87171)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !status.isEmpty { T(status).font(.hs(13)).foregroundStyle(status == "Sent." ? HS.body : Color(hex: 0xF59E0B)) }
                    if !model.messages.isEmpty {
                        PartnerCard(title: "Messages") {
                            ForEach(model.messages.prefix(15)) { m in
                                let mine = m.fromUid == model.uid
                                VStack(alignment: .leading, spacing: 2) {
                                    D((mine ? tr("You") : theirName) + "  ·  " + tr(PartnerText.ago(m.createdAt, now))).font(.hs(12, .semibold)).foregroundStyle(mine ? HS.faith : HS.text)
                                    if m.kind != .ENCOURAGE { T(m.kind.label.uppercased()).font(.hs(10, .bold)).tracking(1).foregroundStyle(Color(hex: 0xF87171)) }
                                    // A partner's own words are shown as written.
                                    D(m.text).font(.hs(14)).foregroundStyle(HS.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    PartnerCard(title: "What I share") {
                        TextField(tr("Name your partner sees"), text: $name)
                            .font(.hs(15)).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                            .onSubmit { model.update { $0.myName = String(name.prefix(PartnerText.nameMax)) } }
                        ShareToggles(
                            shares: Binding(get: { link.sharesFreedom }, set: { v in model.update { $0.sharesFreedom = v } }),
                            streak: Binding(get: { link.shareStreak }, set: { v in model.update { $0.shareStreak = v } }),
                            checkIns: Binding(get: { link.shareCheckIns }, set: { v in model.update { $0.shareCheckIns = v } }),
                            slips: Binding(get: { link.alertSlips }, set: { v in model.update { $0.alertSlips = v } }),
                            protection: Binding(get: { link.alertProtection }, set: { v in model.update { $0.alertProtection = v } }))
                        Divider()
                        T("What your partner sees right now").font(.hs(11)).foregroundStyle(HS.textMuted)
                        D(preview(link).joined(separator: "\n")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    WhatTheServerKeeps()
                    Button { confirmEnd = true } label: {
                        T(ending ? "Ending…" : "End this partnership").font(.hs(14, .semibold)).foregroundStyle(Color(hex: 0xF59E0B))
                    }
                    .buttonStyle(.plain).frame(maxWidth: .infinity).disabled(ending)
                    if !link.pending.isEmpty {
                        T("A message is waiting for a connection and will be sent automatically.").font(.hs(11)).foregroundStyle(HS.textMuted)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                }
                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 20)
        }
        .task { name = link.myName; await model.refresh(); model.markSeen() }
        .onReceive(timer) { _ in Task { await model.refresh(); model.markSeen() } }
        .onDisappear { if name != link.myName, !name.isEmpty { model.update { $0.myName = String(name.prefix(PartnerText.nameMax)) } } }
        .alert(tr("End this partnership?"), isPresented: $confirmEnd) {
            Button(tr("End it"), role: .destructive) {
                ending = true
                Task {
                    let ok = await model.leave()
                    ending = false
                    if !ok { status = tr("Couldn't reach the server to end it. Check your connection and try again.") }
                }
            }
            Button(tr("Keep it"), role: .cancel) {}
        } message: { T("What you've shared and the messages you sent are deleted from the server, and your partner is told it has ended.") }
    }

    private func send(_ kind: PartnerKind, _ text: String, clear: Bool = false) {
        Task {
            let r = await model.send(kind, text)
            await model.refresh()
            switch r {
            case .sent: if clear { custom = "" }; status = "Sent."
            case .alreadySent: status = tr("You've already sent one of these this hour. Try again a little later.")
            case .failed: status = tr("Couldn't send. Check your connection and try again.")
            }
        }
    }

    private func small(_ label: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            T(label).font(.hs(13, .semibold)).foregroundStyle(HS.faith)
                .padding(.horizontal, 14).padding(.vertical, 7).background(RoundedRectangle(cornerRadius: 10).fill(HS.faith.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    private func preview(_ l: PartnerLink) -> [String] {
        let f = PartnerModel.shareFields(l)
        var lines = [tr("Name:") + " \(f["displayName"] as? String ?? "")"]
        if let s = f["streakStart"] as? Int64 { let c = PartnerText.counter(Firestore.nowMs - s); lines.append("\(c.0) " + tr(c.1)) }
        if let d = f["lastCheckIn"] as? String { lines.append(tr("Last check-in:") + " " + tr(PartnerText.daysAgo(d) ?? d)) }
        if l.sharesFreedom && l.alertSlips { lines.append(tr("A message when you slip")) }
        if l.sharesFreedom && l.alertProtection { lines.append(tr("A message if protection is switched off")) }
        return lines
    }
}

/// Encouragement chips that wrap onto as many lines as they need.
private struct FlexibleChips: View {
    let items: [String]
    let tap: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { t in
                Button { tap(t) } label: {
                    T(t).font(.hs(13)).foregroundStyle(HS.text)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(HS.cardFill))
                        .overlay(Capsule().strokeBorder(Color(hex: 0xD9B49F).opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
