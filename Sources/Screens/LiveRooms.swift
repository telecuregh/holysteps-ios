import SwiftUI
import AVFoundation
import LiveKit

/// Live Rooms: voice rooms inside your circles, the same rooms as Android. HolySteps' server
/// (holysteps.org/holysteps/api/rooms) hands out a voice pass for its own LiveKit server
/// (wss://holysteps.org/holysteps/live); the room list comes from Firestore ({circle}/liveRooms, written only by
/// the server). Joining is free; hosting needs a plan (the server checks).
struct LiveRoomInfo: Identifiable, Equatable {
    let id: String
    let circleId: String, circleName: String
    let title, kind, status, hostUid, hostName: String
    let cohostUids, speakerUids: [String]
    let openMic: Bool
    let scheduledAt, startedAt: Int64
    let participantCount: Int

    init?(_ d: FSDoc, circle: HabitCircle) {
        let s = d["status"].string
        guard s == "live" || s == "scheduled" else { return nil }
        id = d.id; circleId = circle.id; circleName = circle.name; status = s
        title = d["title"].string.isEmpty ? tr("Live room") : String(d["title"].string.prefix(80))
        kind = d["kind"].string; hostUid = d["hostUid"].string
        hostName = d["hostName"].string.isEmpty ? tr("Someone") : String(d["hostName"].string.prefix(40))
        cohostUids = d["cohostUids"].array.map(\.string); speakerUids = d["speakerUids"].array.map(\.string)
        openMic = d["openMic"].bool; scheduledAt = d["scheduledAt"].int; startedAt = d["startedAt"].int
        participantCount = Int(d["participantCount"].int)
    }
    var live: Bool { status == "live" }
    func onStage(_ uid: String) -> Bool { uid == hostUid || cohostUids.contains(uid) || speakerUids.contains(uid) }
}

enum LiveAPI {
    struct Pass { let rid, url, token, role, title: String; let openMic: Bool }
    enum Outcome { case ok([String: Any]), rejected(String, String, [String: Any]), offline }

    static func call(_ body: [String: Any]) async -> Outcome {
        for attempt in 0..<2 {
            guard let tok = await AccountStore.shared.token(force: attempt == 1),
                  let url = URL(string: "https://holysteps.org/holysteps/api/rooms") else { return .offline }
            var r = URLRequest(url: url, timeoutInterval: 20)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
            guard let (data, resp) = try? await URLSession.shared.data(for: r) else { return .offline }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            if (200..<300).contains(code) { return .ok(j) }
            if code == 401 && attempt == 0 { continue }
            if code >= 500 && (j["code"] as? String ?? "").isEmpty { return .offline }
            return .rejected(j["code"] as? String ?? "", j["error"] as? String ?? tr("Something went wrong. Try again."), j)
        }
        return .offline
    }

    static func body(_ action: String, circle: String, rid: String? = nil) -> [String: Any] {
        var b: [String: Any] = ["action": action, "gt": "habit", "gid": circle]
        if let rid { b["rid"] = rid }
        return b
    }

    /// The voice link may only go to HolySteps' own server.
    static func pass(_ j: [String: Any]) -> Pass? {
        let url = j["url"] as? String ?? "", token = j["token"] as? String ?? "", rid = j["rid"] as? String ?? ""
        guard let u = URL(string: url), u.scheme == "wss", u.host == "holysteps.org", u.path.hasPrefix("/holysteps/live"),
              token.count >= 20, !rid.isEmpty else { return nil }
        return Pass(rid: rid, url: url, token: token, role: j["role"] as? String ?? "listener",
                    title: j["title"] as? String ?? tr("Live room"), openMic: j["openMic"] as? Bool ?? false)
    }

    static func message(_ o: Outcome) -> String {
        switch o {
        case .rejected(_, let m, _): m
        case .offline: tr("Couldn't reach HolySteps. Check your connection and try again.")
        case .ok: ""
        }
    }
}

struct LivePerson: Identifiable { let id: String; let name: String; let speaking: Bool; let mic: Bool }

@MainActor
final class LiveRoomSession: ObservableObject {
    static let shared = LiveRoomSession()
    @Published private(set) var inRoom = false
    @Published private(set) var connecting = false
    @Published private(set) var title = ""
    @Published private(set) var people: [LivePerson] = []
    @Published private(set) var micOn = false
    @Published private(set) var canSpeak = false
    @Published private(set) var isHost = false
    @Published private(set) var handUp = false
    @Published var notice: String?
    private var room: Room?
    private var circleId = "", rid = ""
    private var poll: Timer?

    func join(_ r: LiveRoomInfo) async { await start(LiveAPI.body("join", circle: r.circleId, rid: r.id), circle: r.circleId) }

    func create(circle: HabitCircle, title: String, openMic: Bool) async {
        var b = LiveAPI.body("create", circle: circle.id)
        b["title"] = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)); b["kind"] = "talk"; b["openMic"] = openMic
        await start(b, circle: circle.id)
    }

    private func start(_ body: [String: Any], circle: String) async {
        if inRoom { await leave() }
        connecting = true
        defer { connecting = false }
        let o = await LiveAPI.call(body)
        guard case .ok(let j) = o else {
            if case .rejected(let code, _, _) = o, code == "plan" { notice = tr("Hosting live rooms and group walks\ncomes with every plan. Joining is free.") }
            else { notice = LiveAPI.message(o) }
            return
        }
        guard let p = LiveAPI.pass(j) else { notice = tr("Couldn't open the room's voice link."); return }
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        let r = Room()
        do { try await r.connect(url: p.url, token: p.token) }
        catch { notice = tr("Couldn't connect to the room. Check your connection and try again."); return }
        room = r; circleId = circle; rid = p.rid; title = p.title
        isHost = p.role == "host" || p.role == "cohost"
        canSpeak = p.role != "listener" || p.openMic
        inRoom = true; micOn = false; handUp = false
        refresh()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }

    private func refresh() {
        guard let room else { return }
        var list: [LivePerson] = [LivePerson(id: "me", name: tr("You"), speaking: room.localParticipant.isSpeaking, mic: micOn)]
        for p in room.remoteParticipants.values {
            list.append(LivePerson(id: p.identity?.stringValue ?? UUID().uuidString, name: (p.name ?? "").isEmpty ? tr("Someone") : p.name!,
                                   speaking: p.isSpeaking, mic: p.isMicrophoneEnabled()))
        }
        people = list
        if room.connectionState == .disconnected && inRoom { Task { await leave(ended: true) } }
    }

    func toggleMic() async {
        guard let room, canSpeak else { return }
        if !micOn {
            let ok = await AVAudioApplication.requestRecordPermission()
            guard ok else { notice = tr("Allow the microphone in Settings to speak."); return }
        }
        do { try await room.localParticipant.setMicrophone(enabled: !micOn); micOn.toggle() }
        catch { notice = tr("Couldn't turn the mic on. Try again.") }
    }

    func raiseHand() async {
        var b = LiveAPI.body("hand", circle: circleId, rid: rid); b["up"] = !handUp
        if case .ok = await LiveAPI.call(b) { handUp.toggle(); if handUp { notice = tr("Your hand is up. The host will see it.") } }
        else { notice = tr("Couldn't reach HolySteps. Check your connection and try again.") }
    }

    func react(_ e: String) async {
        guard let room, let d = try? JSONSerialization.data(withJSONObject: ["t": "r", "e": e]) else { return }
        try? await room.localParticipant.publish(data: d, options: DataPublishOptions(topic: "hs", reliable: false))
    }

    func end() async {
        _ = await LiveAPI.call(LiveAPI.body("end", circle: circleId, rid: rid))
        await leave()
    }

    func leave(ended: Bool = false) async {
        poll?.invalidate(); poll = nil
        await room?.disconnect()
        room = nil; inRoom = false; people = []; micOn = false
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        if ended { notice = tr("The room has ended.") }
    }
}

@MainActor
final class LiveListModel: ObservableObject {
    static let shared = LiveListModel()
    @Published private(set) var rooms: [LiveRoomInfo] = []
    @Published private(set) var loading = true

    func load() async {
        let circles = CirclesModel.shared
        if circles.circles.isEmpty { await circles.load() }
        var all: [LiveRoomInfo] = []
        await withTaskGroup(of: [LiveRoomInfo].self) { g in
            for c in circles.circles {
                g.addTask { ((try? await Firestore.query("liveRooms", parent: "habitCircles/\(c.id)", limit: 20)) ?? []).compactMap { LiveRoomInfo($0, circle: c) } }
            }
            for await r in g { all += r }
        }
        rooms = all.sorted { ($0.live ? 0 : 1, $0.scheduledAt) < ($1.live ? 0 : 1, $1.scheduledAt) }
        loading = false
    }
}

struct LiveRoomsView: View {
    @ObservedObject private var list = LiveListModel.shared
    @ObservedObject private var session = LiveRoomSession.shared
    @ObservedObject private var circles = CirclesModel.shared
    @State private var hosting = false
    @State private var showRoom = false

    var body: some View {
        VStack(spacing: 10) {
            if let n = session.notice { D(n).font(.hs(12)).foregroundStyle(HS.gold).padding(.horizontal, 20).onTapGesture { session.notice = nil } }
            if session.inRoom {
                Button { showRoom = true } label: {
                    GlassCard(glow: Color(hex: 0xF43F5E)) {
                        HStack { Circle().fill(Color(hex: 0xF43F5E)).frame(width: 8, height: 8); D(session.title).font(.hs(15, .semibold)).foregroundStyle(HS.text); Spacer(); T("Open").foregroundStyle(HS.peach) }
                    }
                }.buttonStyle(.plain).padding(.horizontal, 20)
            }
            if list.loading { ProgressView().tint(HS.gold).padding(20) }
            ForEach(list.rooms) { r in
                GlassCard(glow: r.live ? Color(hex: 0xF43F5E) : nil) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if r.live {
                                Circle().fill(Color(hex: 0xF43F5E)).frame(width: 8, height: 8)
                                T("LIVE").font(.hs(11, .semibold)).tracking(1.2).foregroundStyle(Color(hex: 0xF43F5E))
                            } else {
                                D(Date(timeIntervalSince1970: Double(r.scheduledAt) / 1000).formatted(.dateTime.weekday().hour().minute().locale(I18n.shared.locale)))
                                    .font(.hs(11, .semibold)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            if r.live && r.participantCount > 0 { D(tr("{0} listening").replacingOccurrences(of: "{0}", with: "\(r.participantCount)")).font(.hs(11)).foregroundStyle(HS.textMuted) }
                        }
                        D(r.title).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                        D(r.circleName + " · " + r.hostName).font(.hs(12)).foregroundStyle(HS.textSecondary)
                        if r.live {
                            GoldButton(title: "Join now") { Task { await session.join(r); if session.inRoom { showRoom = true } } }
                                .disabled(session.connecting)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            if !list.loading && list.rooms.isEmpty {
                T(circles.circles.isEmpty ? "Live rooms happen inside your circles. Join or start a circle first." : "No rooms right now in your circles.")
                    .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center).padding(.horizontal, 30)
            }
            if !circles.circles.isEmpty {
                Button { hosting = true } label: {
                    GlassCard {
                        HStack(spacing: 12) {
                            IconBadge(symbol: "mic", size: 32, tint: 0x9D7FEA)
                            VStack(alignment: .leading, spacing: 2) {
                                T("Start a live room").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                T("Pray and talk together in one of your circles").font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                        }
                    }
                }.buttonStyle(.plain).padding(.horizontal, 20)
            }
        }
        .task { await list.load() }
        .refreshable { await list.load() }
        .sheet(isPresented: $hosting) { HostRoomSheet { showRoom = session.inRoom } }
        .fullScreenCover(isPresented: $showRoom) { LiveRoomScreen() }
    }
}

private struct HostRoomSheet: View {
    var started: () -> Void
    @ObservedObject private var circles = CirclesModel.shared
    @ObservedObject private var session = LiveRoomSession.shared
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var circleId = ""
    @State private var openMic = false

    var body: some View {
        HSSheet(title: "Start a live room") {
            VStack(alignment: .leading, spacing: 12) {
                TextField(tr("Room name"), text: $title).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                Picker(tr("Circle"), selection: $circleId) { ForEach(circles.circles) { Text($0.name).tag($0.id) } }
                Toggle(isOn: $openMic) { T("Everyone can speak").font(.hs(14)) }.tint(HS.gold)
                GoldButton(title: "Go live") {
                    guard let c = circles.circles.first(where: { $0.id == circleId }) else { return }
                    Task { await session.create(circle: c, title: title, openMic: openMic); dismiss(); started() }
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).count < 2 || circleId.isEmpty || session.connecting)
                if let n = session.notice { D(n).font(.hs(12)).foregroundStyle(HS.gold) }
            }.padding(24)
        }
        .onAppear { circleId = circles.circles.first?.id ?? "" }
    }
}

struct LiveRoomScreen: View {
    @ObservedObject private var s = LiveRoomSession.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.down").font(.system(size: 18)).foregroundStyle(HS.text).frame(width: 44, height: 44) }
                    Spacer()
                    D(s.title).font(.hs(17, .semibold)).foregroundStyle(HS.text)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.top, 50)
                if let n = s.notice { D(n).font(.hs(12)).foregroundStyle(HS.gold).onTapGesture { s.notice = nil } }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 16) {
                        ForEach(s.people) { p in
                            VStack(spacing: 6) {
                                Circle().fill(HS.goldButton.opacity(0.35)).frame(width: 64, height: 64)
                                    .overlay(Text(String(p.name.prefix(1))).font(.hs(24, .semibold)).foregroundStyle(HS.text))
                                    .overlay(Circle().strokeBorder(p.speaking ? HS.gold : .clear, lineWidth: 3))
                                HStack(spacing: 3) {
                                    if !p.mic { Image(systemName: "mic.slash.fill").font(.system(size: 10)).foregroundStyle(HS.textMuted) }
                                    D(p.name).font(.hs(12)).foregroundStyle(HS.text).lineLimit(1)
                                }
                            }
                        }
                    }.padding(.horizontal, 20)
                }
                HStack(spacing: 10) {
                    ForEach(["🙏", "❤️", "🙌", "👏", "🔥"], id: \.self) { e in Button(e) { Task { await s.react(e) } }.font(.system(size: 26)) }
                }
                HStack(spacing: 12) {
                    if s.canSpeak {
                        Button { Task { await s.toggleMic() } } label: {
                            Label(tr(s.micOn ? "Mute" : "Unmute"), systemImage: s.micOn ? "mic.fill" : "mic.slash.fill").font(.hs(15, .semibold))
                                .foregroundStyle(HS.onGold).padding(.horizontal, 18).padding(.vertical, 12).background(Capsule().fill(HS.goldButton))
                        }
                    } else {
                        Button { Task { await s.raiseHand() } } label: {
                            Label(tr(s.handUp ? "Lower hand" : "Raise hand"), systemImage: "hand.raised").font(.hs(15, .semibold))
                                .foregroundStyle(HS.text).padding(.horizontal, 18).padding(.vertical, 12).background(Capsule().fill(HS.overlay(0.08)))
                        }
                    }
                    Button { Task { if s.isHost { await s.end() } else { await s.leave() }; dismiss() } } label: {
                        T(s.isHost ? "End room" : "Leave").font(.hs(15, .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 12).background(Capsule().fill(Color(hex: 0xF43F5E)))
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onChange(of: s.inRoom) { _, on in if !on { dismiss() } }
    }
}
