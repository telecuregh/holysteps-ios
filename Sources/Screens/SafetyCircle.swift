import SwiftUI
import CoreLocation
import UserNotifications

/// Android's Walk Safety (Safety.kt, SafetyManager.kt, SafetyScreens.kt), on the same server (holysteps.org/holysteps/api/
/// safety) and Firestore documents, so iPhones and Android phones can share one circle. A circle is a few people who see
/// each other's live walks, get each other's SOS, and are told when a safe-walk timer runs out unanswered. Who is in a
/// circle is only changed by the server. The location is sent only while you choose to share, and SOS is never a
/// replacement for calling 911.
@MainActor
final class SafetyModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = SafetyModel()
    @AppStorage("safetyCircleId") var circleId = ""
    @AppStorage("safetyOwner") var owner = ""
    @AppStorage("safetySharing") var sharing = false
    @AppStorage("safetyShareStarted") var startedAt = 0.0
    @AppStorage("safetyShareUntil") var shareUntil = 0.0
    @AppStorage("safetyDueAt") var dueAt = 0.0
    @AppStorage("safetySos") var sosActive = false
    @AppStorage("safetyEmergency") var emergency = "911"
    @Published var members: [FSDoc] = []
    @Published var walks: [FSDoc] = []
    @Published var alerts: [FSDoc] = []
    @Published var message = ""
    @Published var inviteCode = ""
    @Published var sosCountdown: Int?
    private let loc = CLLocationManager()
    private var last: CLLocation?, lastSent = 0.0, distance = 0.0, seenAlerts = Set<String>()
    private let api = URL(string: "https://holysteps.org/holysteps/api/safety")!
    var uid: String? { AccountStore.shared.uid }
    var inCircle: Bool { !circleId.isEmpty }

    override private init() {
        super.init()
        loc.delegate = self; loc.desiredAccuracy = kCLLocationAccuracyNearestTenMeters; loc.distanceFilter = 6
        loc.activityType = .fitness; loc.pausesLocationUpdatesAutomatically = false
    }

    // MARK: Server

    @discardableResult
    func call(_ body: [String: Any]) async -> [String: Any]? {
        guard let tok = await AccountStore.shared.token() else { message = tr("Sign in to use Walk Safety."); return nil }
        var r = URLRequest(url: api, timeoutInterval: 20); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (d, resp) = try? await URLSession.shared.data(for: r) else { message = tr("You're offline. Try again when you're back online."); return nil }
        let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:]
        guard let st = (resp as? HTTPURLResponse)?.statusCode, (200..<300).contains(st) else { message = j["error"] as? String ?? tr("Something went wrong. Try again."); return nil }
        return j
    }

    func refresh() async {
        guard let uid else { return }
        let c = (try? await Firestore.query("safetyCircles", filters: [.init(field: "memberUids", op: "ARRAY_CONTAINS", value: .string(uid))], limit: 1))?.first
        circleId = c?.id ?? ""; owner = c?["ownerUid"].string ?? ""
        guard let c else { members = []; walks = []; alerts = []; if sharing { stopLocal() }; return }
        members = (try? await Firestore.query("members", parent: "safetyCircles/\(c.id)", limit: 12)) ?? []
        walks = ((try? await Firestore.query("walks", parent: "safetyCircles/\(c.id)", limit: 12)) ?? []).filter { $0.id != uid }
        let since = Firestore.nowMs - 3 * 86_400_000
        alerts = ((try? await Firestore.query("alerts", parent: "safetyCircles/\(c.id)", limit: 40)) ?? [])
            .filter { $0["at"].int > since }.sorted { $0["at"].int > $1["at"].int }
        // An SOS or missed check-in from someone else that arrived while HolySteps is open: say so right away.
        for a in alerts where a["fromUid"].string != uid && ["SOS", "OVERDUE"].contains(a["kind"].string) && !seenAlerts.contains(a.id) {
            seenAlerts.insert(a.id)
            if Firestore.nowMs - a["at"].int < 10 * 60_000 {
                let n = UNMutableNotificationContent()
                n.title = a["kind"].string == "SOS" ? tr("\(a["name"].string) sent an SOS") : tr("\(a["name"].string) hasn't checked in")
                n.body = tr("Open HolySteps to see where they are. If they may be in danger, call \(emergency).")
                n.sound = .default; n.interruptionLevel = .timeSensitive
                try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: a.id, content: n, trigger: nil))
            }
        }
    }

    func create(name: String) async { if let r = await call(["action": "create", "name": name]), r["circleId"] != nil { await refresh() } }
    func invite() async { if let r = await call(["action": "invite"]) { inviteCode = r["code"] as? String ?? "" } }
    func join(_ code: String, name: String) async {
        if await call(["action": "join", "code": code.trimmingCharacters(in: .whitespaces).uppercased(), "name": name]) != nil { await refresh() }
    }
    func leave() async { if sharing { await stop(tell: false) }; if await call(["action": "leave"]) != nil { circleId = ""; owner = ""; await refresh() } }
    func remove(_ uid: String) async { if await call(["action": "remove", "uid": uid]) != nil { await refresh() } }

    // MARK: Live walk

    func start(hours: Int, dueMinutes: Int, name: String) async {
        guard inCircle, !sharing else { return }
        let now = Date().timeIntervalSince1970 * 1000
        sharing = true; startedAt = now; shareUntil = now + Double(min(max(hours, 1), 8)) * 3_600_000
        dueAt = dueMinutes > 0 ? now + Double(dueMinutes) * 60_000 : 0; distance = 0; last = nil; lastSent = 0
        myName = name
        loc.requestWhenInUseAuthorization(); loc.allowsBackgroundLocationUpdates = true; loc.showsBackgroundLocationIndicator = true
        loc.startUpdatingLocation()
        if dueAt > 0 { await call(["action": "due", "dueAt": Int64(dueAt)]); scheduleCheckIn() }
        await call(["action": "alert", "kind": "START", "rid": UUID().uuidString])
    }
    private var myName = ""

    func stop(tell: Bool, checkin: Bool = false) async {
        let hadDue = dueAt > 0
        stopLocal()
        if let uid, inCircle { try? await Firestore.commit([.delete("safetyCircles/\(circleId)/walks/\(uid)")]) }
        if hadDue || checkin { var b: [String: Any] = ["action": "due", "dueAt": 0]; if checkin { b["checkin"] = true }; await call(b) }
        if tell && !sosActive { await call(["action": "alert", "kind": "ARRIVED", "rid": UUID().uuidString]) }
    }
    private func stopLocal() {
        loc.stopUpdatingLocation(); loc.allowsBackgroundLocationUpdates = false
        sharing = false; startedAt = 0; shareUntil = 0; dueAt = 0
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["safetyCheckIn"])
    }

    /// The safe-walk timer: a reminder on this phone when it's up. The server tells the circle 3 minutes later if no answer.
    private func scheduleCheckIn() {
        guard dueAt > 0 else { return }
        let n = UNMutableNotificationContent()
        n.title = tr("Are you OK?"); n.body = tr("Your safe-walk timer is up. Open HolySteps and tap I'm OK, or your circle is told in 3 minutes.")
        n.sound = .default; n.interruptionLevel = .timeSensitive
        let t = max(1, dueAt / 1000 - Date().timeIntervalSince1970)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "safetyCheckIn", content: n, trigger: UNTimeIntervalNotificationTrigger(timeInterval: t, repeats: false)))
    }
    func extend(_ minutes: Int) async {
        dueAt = max(dueAt, Date().timeIntervalSince1970 * 1000) + Double(minutes) * 60_000
        await call(["action": "due", "dueAt": Int64(dueAt), "checkin": true]); scheduleCheckIn()
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations ls: [CLLocation]) {
        guard let l = ls.last, l.horizontalAccuracy >= 0, l.horizontalAccuracy < 200 else { return }
        Task { @MainActor in await self.publish(l) }
    }

    private func publish(_ l: CLLocation, force: Bool = false) async {
        guard sharing, inCircle, let uid else { return }
        let now = Date().timeIntervalSince1970 * 1000
        if shareUntil > 0, now > shareUntil { await stop(tell: true); return }
        if let p = last { distance += l.distance(from: p) }
        let moved = last.map { l.distance(from: $0) } ?? .infinity
        last = l
        guard force || now - lastSent >= 30_000 || (now - lastSent >= 8_000 && moved >= 6) else { return }
        lastSent = now
        let name = myName.isEmpty ? (members.first { $0.id == uid }?["displayName"].string ?? "Me") : myName
        try? await Firestore.commit([.set("safetyCircles/\(circleId)/walks/\(uid)", [
            "displayName": .string(String(name.prefix(80))), "activity": .string("WALK"), "lat": .double(l.coordinate.latitude), "lng": .double(l.coordinate.longitude),
            "accuracy": .double(max(0, l.horizontalAccuracy)), "speedMps": .double(min(120, max(0, l.speed))), "distanceM": .double(min(1_000_000, distance)),
            "startedAt": .int(Int64(startedAt)), "updatedAt": .int(Int64(now)), "shareUntil": .int(Int64(shareUntil)), "dueAt": .int(Int64(dueAt)), "sos": .bool(sosActive)])])
    }

    // MARK: SOS

    func beginSos() {
        guard inCircle, sosCountdown == nil else { if !inCircle { message = tr("Make or join a circle first, so someone gets your SOS.") }; return }
        Task {
            for s in stride(from: 5, through: 1, by: -1) { sosCountdown = s; try? await Task.sleep(nanoseconds: 1_000_000_000); if sosCountdown == nil { return } }
            sosCountdown = nil; sosActive = true
            if dueAt > 0 { dueAt = 0; UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["safetyCheckIn"]) }
            loc.requestWhenInUseAuthorization()
            let p = loc.location
            var body: [String: Any] = ["action": "alert", "kind": "SOS", "rid": UUID().uuidString]
            if let p { body["lat"] = p.coordinate.latitude; body["lng"] = p.coordinate.longitude }
            if let r = await call(body) {
                let n = r["members"] as? Int ?? 0
                message = tr("SOS sent to \(n) \(n == 1 ? "person" : "people") in your circle. If you're in danger, call \(emergency) now.")
            } else { message = tr("Your SOS couldn't be sent: ") + message + " " + tr("Call \(emergency) if you're in danger.") }
            if let p { await publish(p, force: true) }
        }
    }
    func cancelSos() { sosCountdown = nil }
    func imSafe() async {
        sosActive = false
        await call(["action": "alert", "kind": "SAFE", "rid": UUID().uuidString, "checkin": true])
        if let p = last { await publish(p, force: true) }
    }
}

struct SafetyCircleView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var s = SafetyModel.shared
    @Environment(\.openURL) private var openURL
    @State private var joining = false
    @State private var code = ""
    @State private var hours = 2
    @State private var due = 0
    @State private var leaving = false
    private let tick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🛡️ SAFETY CIRCLE").font(.hs(12, .bold)).foregroundStyle(HS.readable(0x60A5FA))
                    T("Walk with people watching out for you").font(.hs(22)).foregroundStyle(HS.text)
                    T("A few people you trust see your live walk while you share it, get your SOS, and are told if you don't check in on time. Nothing is shared unless you start it.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    sosButton
                    if s.sosActive {
                        GoldButton(title: "I'm safe now") { Task { await s.imSafe() } }
                    }
                    Button { openURL(URL(string: "tel://\(s.emergency)")!) } label: { Label(tr("Call \(s.emergency)"), systemImage: "phone.fill") }.buttonStyle(.bordered).tint(.red)
                    if !s.message.isEmpty { D(s.message).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    if s.inCircle { circle } else {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                T("Start a circle, or join one with a code someone sent you.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                                HStack {
                                    GoldButton(title: "Start a circle") { Task { await s.create(name: store.name) } }
                                    Button(tr("Join with code")) { joining = true }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    T("On iPhone, alerts from your circle show while HolySteps is open or running in the background. For an emergency, always call 911.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }.padding(20)
            }.refreshable { await s.refresh() }
        }
        .task { await s.refresh() }
        .onReceive(tick) { _ in Task { await s.refresh() } }
        .alert(tr("Join a safety circle"), isPresented: $joining) {
            TextField(tr("Code"), text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button(tr("Join")) { let c = code; code = ""; Task { await s.join(c, name: store.name) } }
            Button(tr("Cancel"), role: .cancel) { code = "" }
        }
        .alert(tr("Leave your circle?"), isPresented: $leaving) {
            Button(tr("Leave"), role: .destructive) { Task { await s.leave() } }
            Button(tr("Stay"), role: .cancel) {}
        }
    }

    @ViewBuilder private var sosButton: some View {
        if let c = s.sosCountdown {
            Button { s.cancelSos() } label: {
                D(tr("Sending SOS in \(c)… tap to cancel")).font(.hs(17, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.orange))
            }.buttonStyle(.plain)
        } else {
            Button { s.beginSos() } label: {
                T("🆘 SOS").font(.hs(22, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.red))
            }.buttonStyle(.plain)
            .accessibilityHint(tr("Sends an SOS with your location to your circle after 5 seconds"))
        }
    }

    @ViewBuilder private var circle: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if s.sharing {
                    T("📍 Sharing your walk").font(.hs(15, .bold)).foregroundStyle(HS.readable(0x10B981))
                    if s.dueAt > 0 {
                        D(tr("Check in by \(Date(timeIntervalSince1970: s.dueAt / 1000).formatted(date: .omitted, time: .shortened))")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                        HStack {
                            Button(tr("I'm OK, 15 more min")) { Task { await s.extend(15) } }.buttonStyle(.bordered)
                        }
                    }
                    GoldButton(title: "I've arrived, stop sharing") { Task { await s.stop(tell: true, checkin: s.dueAt > 0) } }
                } else {
                    T("Share a walk").font(.hs(15, .bold)).foregroundStyle(HS.text)
                    Picker(tr("Share for"), selection: $hours) { ForEach([1, 2, 4, 8], id: \.self) { Text(tr("\($0) h")).tag($0) } }.pickerStyle(.segmented)
                    Picker(tr("Safe-walk timer"), selection: $due) {
                        ForEach([0, 30, 45, 60, 90, 120], id: \.self) { Text($0 == 0 ? tr("No timer") : tr("\($0) min")).tag($0) }
                    }
                    GoldButton(title: "Start sharing") { Task { await s.start(hours: hours, dueMinutes: due, name: store.name) } }
                }
            }
        }
        if !s.walks.isEmpty {
            T("Walking now").font(.hs(13, .bold)).foregroundStyle(HS.textMuted)
            ForEach(s.walks) { w in
                let age = Firestore.nowMs - w["updatedAt"].int, ended = w["shareUntil"].int > 0 && w["shareUntil"].int < Firestore.nowMs
                Button {
                    openURL(URL(string: "http://maps.apple.com/?ll=\(w["lat"].double),\(w["lng"].double)&q=\(w["displayName"].string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!)
                } label: {
                    HStack {
                        D(w["sos"].bool ? "🆘" : "🚶")
                        VStack(alignment: .leading) {
                            D(w["displayName"].string).font(.hs(14, .bold)).foregroundStyle(HS.text)
                            D(ended ? tr("Stopped sharing") : age < 90_000 ? tr("Live · \(String(format: "%.1f", w["distanceM"].double / 1000)) km") : tr("Last seen \(age / 60_000) min ago"))
                                .font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer(); Image(systemName: "map").foregroundStyle(HS.textMuted)
                    }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(w["sos"].bool ? Color.red.opacity(0.15) : HS.text.opacity(0.04)))
                }.buttonStyle(.plain)
            }
        }
        if !s.alerts.isEmpty {
            T("Recent").font(.hs(13, .bold)).foregroundStyle(HS.textMuted)
            ForEach(s.alerts.prefix(10)) { a in
                let k = a["kind"].string
                let what = ["SOS": "sent an SOS", "SAFE": "is safe now", "OVERDUE": "didn't check in on time", "START": "started a walk", "ARRIVED": "finished their walk", "CHECKIN": "checked in", "JOINED": "joined the circle"][k] ?? k
                HStack {
                    D(tr("\(a["name"].string) \(tr(what))")).font(.hs(13, k == "SOS" || k == "OVERDUE" ? .bold : .regular)).foregroundStyle(k == "SOS" ? Color.red : HS.text)
                    Spacer()
                    D(Date(timeIntervalSince1970: Double(a["at"].int) / 1000).formatted(date: .omitted, time: .shortened)).font(.hs(11)).foregroundStyle(HS.textMuted)
                }
            }
        }
        T(tr("Your circle · \(s.members.count)")).font(.hs(13, .bold)).foregroundStyle(HS.textMuted)
        ForEach(s.members) { mem in
            HStack {
                D(mem.id == s.uid ? tr("You") : mem["displayName"].string).font(.hs(14)).foregroundStyle(HS.text)
                if mem.id == s.owner { T("· started it").font(.hs(11)).foregroundStyle(HS.textMuted) }
                Spacer()
                if s.owner == s.uid && mem.id != s.uid { Button(tr("Remove")) { Task { await s.remove(mem.id) } }.font(.hs(12)) }
            }
        }
        HStack {
            Button(tr("Invite someone")) { Task { await s.invite() } }.buttonStyle(.bordered)
            Button(tr("Leave circle"), role: .destructive) { leaving = true }.font(.hs(12))
        }
        if !s.inviteCode.isEmpty {
            HStack {
                D(s.inviteCode).font(.system(.title3, design: .monospaced)).foregroundStyle(HS.text).textSelection(.enabled)
                ShareLink(item: s.inviteCode, message: Text(tr("Join my HolySteps safety circle: open Profile, then Safety circle, tap Join with code and enter it."))) { Image(systemName: "square.and.arrow.up") }
            }
            T("The code works once and expires soon.").font(.hs(11)).foregroundStyle(HS.textMuted)
        }
    }
}
