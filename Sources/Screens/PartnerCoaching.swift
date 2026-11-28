import SwiftUI
import CryptoKit

/// Android's Active Partner Coaching (PartnerCoachingScreen.kt, AppViewModel partner functions, PairCrypto.kt), same
/// Firestore documents and the same end-to-end sealing, so an iPhone and an Android phone can be paired.
/// She invites; whoever enters the code waits as ACCEPTED until she confirms it's her partner. Each day her phone writes one
/// supportive tip, sealed with a key made from the secret in the invite: Firestore holds only the sealed box. She can pause
/// or revoke at any time, and the rules cut his access the moment the link stops being ACTIVE.
enum PairCrypto {
    static let secretChars = 16
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let magic: [UInt8] = [0x48, 0x53, 0x56, 1]   // "HSV" 1, as Vault.seal

    static func newSecret() -> String {
        var g = SystemRandomNumberGenerator()
        return String((0..<secretChars).map { _ in alphabet[Int.random(in: 0..<alphabet.count, using: &g)] })
    }
    static func invite(_ code: String, _ secret: String) -> String { "\(code)-\(secret)" }

    /// The Firestore code and the secret from what the partner typed, or nil if it isn't a whole invite.
    static func split(_ input: String, prefix: String) -> (code: String, secret: String)? {
        let clean = String(input.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" })
        let re = try! NSRegularExpression(pattern: "^(\(prefix)-[A-Z2-9]{10})-?([A-Z2-9]{\(secretChars)})$")
        guard let m = re.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
              let a = Range(m.range(at: 1), in: clean), let b = Range(m.range(at: 2), in: clean) else { return nil }
        return (String(clean[a]), String(clean[b]))
    }

    static func key(_ secret: String, docId: String) -> SymmetricKey {
        let root = Data(SHA256.hash(data: Data("holysteps-pair-v1|\(secret)".utf8)))
        let mac = HMAC<SHA256>.authenticationCode(for: Data("pair|\(docId)".utf8), using: SymmetricKey(data: root))
        return SymmetricKey(data: Data(mac))
    }

    static func seal(_ key: SymmetricKey, _ obj: [String: Any], context: String) -> String? {
        guard let plain = try? JSONSerialization.data(withJSONObject: obj),
              let box = try? AES.GCM.seal(plain, using: key, authenticating: Data(context.utf8)) else { return nil }
        return (Data(magic) + Data(box.nonce) + box.ciphertext + box.tag).base64EncodedString()
    }

    /// Nil when it wasn't sealed with this key for this context (an old invite, a wrong key, or tampering).
    static func open(_ key: SymmetricKey, _ b64: String, context: String) -> [String: Any]? {
        guard let d = Data(base64Encoded: b64), d.count >= 4 + 12 + 16, Array(d.prefix(4)) == magic,
              let nonce = try? AES.GCM.Nonce(data: d.subdata(in: 4..<16)),
              let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: d.subdata(in: 16..<(d.count - 16)), tag: d.suffix(16)),
              let plain = try? AES.GCM.open(box, using: key, authenticating: Data(context.utf8)) else { return nil }
        return try? JSONSerialization.jsonObject(with: plain) as? [String: Any]
    }
}

/// The pairing secrets, kept only on this phone (Android: PairKeys).
enum PairKeys {
    private static let k = "pairKeys"
    static func put(_ docId: String, _ secret: String) {
        var m = UserDefaults.standard.dictionary(forKey: k) as? [String: String] ?? [:]; m[docId] = secret
        UserDefaults.standard.set(m, forKey: k)
    }
    static func secret(_ docId: String) -> String? { (UserDefaults.standard.dictionary(forKey: k) as? [String: String])?[docId] }
    static func key(_ docId: String) -> SymmetricKey? { secret(docId).map { PairCrypto.key($0, docId: docId) } }
}

struct PartnerTip: Equatable {
    var text: String, phase: String, at: Int64, share: Bool, daysToPeriod: Int, fertile: String, pregWeek: Int
}

@MainActor
final class PartnerCoachingModel: ObservableObject {
    @Published var linkId = ""
    @Published var link: FSDoc?
    @Published var isOwner = false
    @Published var loading = true
    @Published var today: PartnerTip?
    @Published var history: [PartnerTip] = []
    @Published var notice = ""
    @AppStorage("partnerSharePredictions") var sharePredictions = false
    weak var store: AppStore?

    var status: String { link?["status"].string.uppercased() ?? "" }

    func load() async {
        guard let uid = AccountStore.shared.uid else { loading = false; return }
        async let a = try? Firestore.query("partnerLinks", filters: [.init(field: "ownerUid", op: "EQUAL", value: .string(uid))], limit: 20)
        async let b = try? Firestore.query("partnerLinks", filters: [.init(field: "partnerUid", op: "EQUAL", value: .string(uid))], limit: 20)
        let all = ((await a) ?? []) + ((await b) ?? [])
        let live = all.filter { $0["status"].string.uppercased() != "REVOKED" }
            .sorted { $0["updatedAt"].int > $1["updatedAt"].int }.first
        link = live; linkId = live?.id ?? ""; isOwner = live?["ownerUid"].string == uid
        loading = false
        await loadTips()
    }

    private func context(_ day: String) -> String { "holysteps-tip-v1|\(linkId)|\(day)" }

    private func tip(from d: FSDoc, key: SymmetricKey) -> PartnerTip? {
        guard let o = PairCrypto.open(key, d["box"].string, context: context(d.id)) else { return nil }
        return PartnerTip(text: o["tipText"] as? String ?? "", phase: o["cyclePhaseLabel"] as? String ?? "", at: d["generatedAt"].int,
                          share: o["sharePredictions"] as? Bool ?? false, daysToPeriod: o["daysToPeriod"] as? Int ?? -1,
                          fertile: o["fertileLevel"] as? String ?? "", pregWeek: o["pregnancyWeek"] as? Int ?? 0)
    }

    func loadTips() async {
        guard !linkId.isEmpty, let key = PairKeys.key(linkId), isOwner || status == "ACTIVE" else { today = nil; history = []; return }
        let docs = (try? await Firestore.query("dailyTips", parent: "partnerLinks/\(linkId)", orderBy: "generatedAt", limit: 14)) ?? []
        let tips = docs.compactMap { d in tip(from: d, key: key).map { (d.id, $0) } }
        today = tips.first { $0.0 == AppStore.dayKey() }?.1
        history = tips.map(\.1).filter { $0 != today }
    }

    @Published var inviting = false

    /// Makes the invitation and returns the whole code to send (code and secret), or nil with `notice` saying why.
    /// Android's createPartnerLink: inviting needs the plan (entering a code is free), and the screen shows the
    /// invitation at once instead of waiting for a search to find it again.
    func invite(name: String) async -> String? {
        guard !inviting else { return nil }
        notice = ""
        guard let uid = await AccountStore.shared.ensureUid() else { notice = AccountStore.shared.notConnectedMessage; return nil }
        inviting = true
        defer { inviting = false }
        let id = Firestore.newId(), code = InviteCode.make("LINK"), now = Firestore.nowMs
        let fields: [String: FSValue] = [
            "ownerUid": .string(uid), "ownerName": .string(String(name.prefix(100))), "partnerUid": .string(""), "partnerName": .string(""),
            "status": .string("PENDING"), "inviteCode": .string(code), "createdAt": .int(now), "updatedAt": .int(now)]
        do {
            try await Firestore.commit([.set("partnerLinks/\(id)", fields, mustNotExist: true)])
            try await InviteCode.register(code, type: "partnerLink", target: id, uid: uid)
        } catch {
            notice = error.togetherText(tr("Couldn't create the invitation. Check your connection and try again."))
            return nil
        }
        let secret = PairCrypto.newSecret()        // stays on the two phones; it seals the tips
        PairKeys.put(id, secret)
        link = (try? await Firestore.get("partnerLinks/\(id)")) ?? FSDoc(path: "partnerLinks/\(id)", fields: fields)
        linkId = id; isOwner = true; loading = false
        return PairCrypto.invite(code, secret)
    }

    func accept(_ input: String, name: String) async {
        guard let uid = await AccountStore.shared.ensureUid() else { notice = AccountStore.shared.notConnectedMessage; return }
        guard let (code, secret) = PairCrypto.split(InviteCode.clean(input), prefix: "LINK") else {
            notice = tr("That code isn't complete. Ask your partner to send the whole code again."); return
        }
        guard let inv = await InviteCode.resolve(code), inv.type == "partnerLink" else { notice = tr("That code wasn't found. Check it and try again."); return }
        do {
            try await Firestore.commit([.update("partnerLinks/\(inv.target)", ["partnerUid": .string(uid), "partnerName": .string(String(name.prefix(100))),
                                                                              "status": .string("ACCEPTED"), "updatedAt": .int(Firestore.nowMs)])])
            PairKeys.put(inv.target, secret)
            await load()
        } catch { notice = tr("That code has already been used, or it was turned off.") }
    }

    func set(_ s: String) async {
        guard !linkId.isEmpty else { return }
        try? await Firestore.commit([.update("partnerLinks/\(linkId)", ["status": .string(s), "updatedAt": .int(Firestore.nowMs)])])
        await load()
        if s == "ACTIVE" { await shareToday() }
    }

    /// Today's tip, made on her phone from her own cycle state. Only this sentence, a phase label and (if she chose)
    /// coarse numbers are sealed and sent. Never symptoms, moods or dates.
    func shareToday() async {
        guard isOwner, status == "ACTIVE", let key = PairKeys.key(linkId), let s = store else { return }
        guard s.gender != "male" else { return }
        let r = Rhythm(store: s)
        let preg = PregnancyMode.shared
        let text: String, label: String
        if let p = r.phase { text = PartnerTips.forPhase(p, loggedToday: !CycleLog.shared.today.isEmpty); label = p.rawValue.uppercased() }
        else { text = PartnerTips.pick(PartnerTips.general); label = "" }
        var days = -1, fertile = ""
        if sharePredictions, !preg.on, let last = s.periodStarts.max() {
            let p = CycleLogic.predict(lastStart: last, length: s.cycleLength, periodLength: s.periodLength)
            if p.daysLate == 0 { days = max(0, p.daysUntil) }
            fertile = PartnerTips.fertility(offset: CycleLogic.days(p.ovulation, Date()))
        }
        let obj: [String: Any] = ["tipText": text, "cyclePhaseLabel": label, "sharePredictions": sharePredictions,
                                  "daysToPeriod": days, "fertileLevel": fertile, "pregnancyWeek": sharePredictions ? (preg.week ?? 0) : 0]
        let day = AppStore.dayKey()
        guard let box = PairCrypto.seal(key, obj, context: context(day)) else { return }
        try? await Firestore.commit([.set("partnerLinks/\(linkId)/dailyTips/\(day)", ["box": .string(box), "generatedAt": .int(Firestore.nowMs)])])
        await loadTips()
    }
}

enum PartnerTips {
    static func pick(_ pool: [String]) -> String { pool[((PhasePlan.epochDay % pool.count) + pool.count) % pool.count] }
    /// Fertility.levelAt: days from the estimated ovulation day.
    static func fertility(offset: Int) -> String {
        switch offset { case -2, -1, 0: "PEAK"; case -3: "HIGH"; case -5, -4, 1: "MEDIUM"; default: "LOW" }
    }
    static let general = [
        "Ask her how her day is really going — and put your phone down while she answers.",
        "Take one thing off her plate today without being asked.",
        "Suggest a short walk together after dinner.",
        "Pray for her by name today, and tell her you did.",
        "Notice something she did well this week and say it out loud.",
    ]
    static func forPhase(_ p: CyclePhase, loggedToday: Bool) -> String {
        let pool: [String] = switch p {
        case .menstrual: [
            "She's in her period this week — extra patience, a warm meal, or taking one thing off her plate goes a long way.",
            "Low energy is normal for her right now — the most helpful thing might just be not needing anything extra from her today.",
            "Cramps and fatigue are common this week — a heating pad, her favorite snack, or just handling dinner can mean more than you'd think.",
            "She might want quiet and rest more than plans this week — checking in before assuming she's up for something helps.",
            "A little extra softness goes a long way this week — she's running on less energy than usual, even if she doesn't say so."]
        case .follicular: [
            "Her energy is rising this week — a good time to plan something together or back a new idea she's excited about.",
            "She's likely feeling more up for new things this week — a good window to try something different together.",
            "Motivation tends to climb for her this week — encouraging a goal she's working on will land well right now.",
            "She may have more energy for social plans this week — a good time to suggest a date or see friends together.",
            "This is often her clearest, most energized stretch — a good week to tackle something you've been putting off together."]
        case .ovulation: [
            "She's at her peak energy and confidence this week — a good week for a real conversation or a date.",
            "This is typically her highest-energy week — a great time for something active together, or just more connection.",
            "Confidence tends to run high for her this week — a good time to really listen if she brings something up.",
            "She may feel more social and outgoing this week — a good week to plan something fun together.",
            "This week often brings her best mood and energy of the month — worth making the most of together."]
        case .luteal: [
            "She may be more inward or sensitive this week — low-key plans, extra grace, and fewer surprises help.",
            "Patience may run a little lower for her this week — that's hormonal, not personal, so extra grace helps.",
            "She might want more downtime this week — checking in instead of planning something big is usually appreciated.",
            "Cravings or mood swings are common this week — a little extra kindness (and maybe chocolate) goes a long way.",
            "She may need more reassurance than usual this week — small, consistent gestures matter more than big ones right now."]
        }
        return pick(pool) + (loggedToday ? " She logged how she's feeling today, so a simple \"how are you doing?\" will mean a lot." : "")
    }
}

struct PartnerCoachingView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var m = PartnerCoachingModel()
    @State private var askCode = false
    @ObservedObject private var account = AccountStore.shared
    @State private var paywall = false
    /// The invitation just made, offered straight away in the share sheet (as on Android).
    @State private var shareNow: SharedInvite?
    struct SharedInvite: Identifiable { let code: String; var id: String { code } }
    /// Filled in when this screen was opened from an invite link (JoinInviteView).
    @State private var code = InviteInbox.take("LINK")

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("💞 PARTNER COACHING").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF472B6))
                    T("Support, without the data").font(.hs(24)).foregroundStyle(HS.text)
                    if m.loading { ProgressView().frame(maxWidth: .infinity).padding(40) }
                    else if m.link == nil { empty }
                    else if m.isOwner { owner }
                    else { partner }
                    if !m.notice.isEmpty && m.link != nil { D(m.notice).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }.padding(20)
            }
            .refreshable { await m.load() }
        }
        .task { m.store = store; await m.load(); await m.shareToday() }
        .sheet(isPresented: $paywall) { PlansView(feature: .partnerCoaching) }
        .sheet(item: $shareNow) { inv in
            ActivitySheet(items: [tr("Here's my HolySteps partner code. Open HolySteps, go to Partner coaching, tap \"I have a code\" and enter it.") + "\n\n" + inv.code,
                                  InviteCode.link(inv.code)])
                .presentationDetents([.medium, .large])
        }
        .alert(tr("Enter her invite code"), isPresented: $askCode) {
            TextField("LINK-…", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button(tr("Join")) { let c = code; code = ""; Task { await m.accept(c, name: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
    }

    private var empty: some View {
        GlassCard {
            VStack(spacing: 10) {
                D("💞").font(.system(size: 44))
                T(store.gender == "male" ? "Connect with your partner" : "Invite your partner in").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                T("She shares a daily tip on how to support her — never her raw symptoms, mood, or dates. She can pause or revoke it anytime.")
                    .font(.hs(13)).foregroundStyle(HS.textSecondary).multilineTextAlignment(.center)
                if store.gender != "male" {
                    GoldButton(title: m.inviting ? "Making your invitation…" : "Invite my partner") {
                        guard !m.inviting else { return }
                        // Entering a code is free; inviting needs the plan (Android shows the paywall the same way).
                        guard account.canUse(.partnerCoaching) else { paywall = true; return }
                        Task { if let code = await m.invite(name: store.name) { shareNow = SharedInvite(code: code) } }
                    }
                    .disabled(m.inviting)
                    .padding(.top, 4)
                }
                HStack(spacing: 18) {
                    Button(tr("I have a code")) { askCode = true }.foregroundStyle(HS.readable(0xA78BFA))
                    ScanQRButton(label: "Scan") { c in Task { await m.accept(c, name: store.name) } }
                }
                if !m.notice.isEmpty {
                    D(m.notice).font(.hs(13)).foregroundStyle(Color(hex: 0xF59E0B)).multilineTextAlignment(.center)
                }
                if store.gender != "male" && !account.canUse(.partnerCoaching) {
                    T("Entering a partner's code is free. Inviting your partner needs a paid plan.")
                        .font(.hs(12)).foregroundStyle(HS.textSubtle).multilineTextAlignment(.center)
                }
            }.frame(maxWidth: .infinity)
        }
    }

    private var inviteText: String? {
        guard let code = m.link?["inviteCode"].string, let s = PairKeys.secret(m.linkId) else { return nil }
        return PairCrypto.invite(code, s)
    }

    private var owner: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    let (label, color): (String, UInt32) = switch m.status {
                    case "PENDING": ("Waiting for your partner to enter the code", 0xA8A29E)
                    case "ACCEPTED": ("Someone entered your code", 0xF59E0B)
                    case "ACTIVE": ("Sharing is active", 0x10B981)
                    case "PAUSED": ("Sharing is paused", 0xF59E0B)
                    default: ("Revoked", 0xA8A29E)
                    }
                    T(label).font(.hs(14, .bold)).foregroundStyle(HS.readable(color))
                    if m.status == "PENDING" {
                        if let inv = inviteText {
                            D(inv).font(.system(.body, design: .monospaced)).foregroundStyle(HS.text).textSelection(.enabled)
                            ShareLink(item: inv, message: Text(tr("Here's my HolySteps partner code. Open HolySteps, go to Partner coaching, tap \"I have a code\" and enter it."))) {
                                Label(tr("Share code"), systemImage: "square.and.arrow.up")
                            }
                            ShowQRButton(code: inv, label: "Show QR code to scan")
                        } else {
                            T("This invitation was made on another phone. Revoke it and invite again from here.").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    } else if m.status == "ACCEPTED" {
                        let who = m.link?["partnerName"].string ?? ""
                        D(tr("\(who.isEmpty ? tr("Someone") : who) entered your code. Is this your partner? Nothing is shared until you allow it."))
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        HStack {
                            Button(tr("Yes, allow")) { Task { await m.set("ACTIVE") } }.buttonStyle(.bordered).tint(.green)
                            Button(tr("Not my partner")) { Task { await m.set("REVOKED") } }.buttonStyle(.bordered).tint(.red)
                        }
                    } else if let n = m.link?["partnerName"].string, !n.isEmpty {
                        D(tr("Connected with \(n)")).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                }
            }
            HStack {
                if m.status == "ACTIVE" { Button(tr("Pause sharing")) { Task { await m.set("PAUSED") } }.buttonStyle(.bordered) }
                if m.status == "PAUSED" { Button(tr("Resume sharing")) { Task { await m.set("ACTIVE") } }.buttonStyle(.bordered) }
                Button(tr("Revoke")) { Task { await m.set("REVOKED") } }.buttonStyle(.bordered).tint(.red)
            }
            Toggle(isOn: Binding(get: { m.sharePredictions }, set: { v in m.sharePredictions = v; Task { await m.shareToday() } })) {
                VStack(alignment: .leading, spacing: 2) {
                    T("Share my predictions").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                    T("Read-only: days until your period, today's fertility level, or your pregnancy week.").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
            }
            T("Only a short supportive note and a general phase label are sent, plus your predictions if you turn that on. Never your symptoms, mood, or exact dates. It's sealed on your phone so only your partner's phone can read it.")
                .font(.hs(11)).foregroundStyle(HS.textMuted)
        }
    }

    private var partner: some View {
        VStack(alignment: .leading, spacing: 12) {
            if m.status == "ACCEPTED" {
                T("Code accepted. Waiting for her to confirm it's you. Tips start once she does.").font(.hs(14)).foregroundStyle(HS.textSecondary)
            } else if m.status != "ACTIVE" {
                T("She has paused sharing for now.").font(.hs(14)).foregroundStyle(HS.textSecondary)
            } else if let t = m.today {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        T("Today's tip 💞").font(.hs(13, .bold)).foregroundStyle(HS.readable(0xF472B6))
                        D(tr(t.text)).font(.hs(15)).foregroundStyle(HS.text)
                        if t.share {
                            if t.daysToPeriod >= 0 { D(t.daysToPeriod == 0 ? tr("🌹 Her period is due about today") : tr("🌹 Period in about \(t.daysToPeriod) day\(t.daysToPeriod == 1 ? "" : "s")")).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                            if !t.fertile.isEmpty { D(tr("🌿 Fertility today: \(t.fertile.lowercased().capitalized)")).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                            if t.pregWeek > 0 { D(tr("🤰 Week \(t.pregWeek) of pregnancy: baby is about the size of \(PregnancyMode.week(t.pregWeek).size)")).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                        }
                    }
                }
            } else {
                T("No tip yet today — check back soon.").font(.hs(13)).foregroundStyle(HS.textMuted)
            }
            if m.status == "ACTIVE" && !m.history.isEmpty {
                T("Recent tips").font(.hs(12, .semibold)).foregroundStyle(HS.textMuted)
                ForEach(Array(m.history.enumerated()), id: \.offset) { _, t in
                    HStack(alignment: .top) {
                        D(tr(t.text)).font(.hs(12)).foregroundStyle(HS.textSecondary)
                        Spacer()
                        D(Date(timeIntervalSince1970: Double(t.at) / 1000).formatted(.dateTime.month(.abbreviated).day())).font(.hs(10)).foregroundStyle(HS.textMuted)
                    }
                }
            }
        }
    }
}


/// The system share sheet, opened by the app itself (ShareLink only opens from a tap on it).
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
