import SwiftUI
import UserNotifications
import AVFoundation

/// Android's wake-up alarm (data/WakeAlarm.kt, WakeAlarmScreen.kt): at the chosen time, on the chosen days, the
/// alarm rings, and when it's opened the narrator prays, reads a verse or gives a pep talk (a new script each
/// morning). On iPhone the ring is a notification with its sound (apps can't take over the lock screen), then the
/// narrator speaks in the app.
enum WakeAlarm {
    enum Style: String, CaseIterable { case PRAYER, SCRIPTURE, MOTIVATION, ROTATE
        var label: String { ["PRAYER": "Morning prayer", "SCRIPTURE": "Scripture", "MOTIVATION": "Motivation", "ROTATE": "Surprise me"][rawValue]! }
        var emoji: String { ["PRAYER": "🙏", "SCRIPTURE": "📖", "MOTIVATION": "🔥", "ROTATE": "✨"][rawValue]! }
        var blurb: String {
            ["PRAYER": "The narrator prays over your day with you", "SCRIPTURE": "A verse read aloud, with a word for today",
             "MOTIVATION": "A short pep talk to get you up and moving", "ROTATE": "A different style each morning"][rawValue]!
        }
    }
    private static let scripts: [String: [[String]]] = {
        guard let u = Bundle.main.url(forResource: "wake", withExtension: "json"), let d = try? Data(contentsOf: u) else { return [:] }
        return (try? JSONDecoder().decode([String: [[String]]].self, from: d)) ?? [:]
    }()
    static func lines(_ style: Style, epochDay: Int = PhasePlan.epochDay) -> (Style, [String]) {
        let r: [Style] = [.PRAYER, .SCRIPTURE, .MOTIVATION]
        let s = style == .ROTATE ? r[((epochDay % 3) + 3) % 3] : style
        let lib = scripts[s.rawValue] ?? []
        guard !lib.isEmpty else { return (s, []) }
        var l = lib[((epochDay % lib.count) + lib.count) % lib.count]
        let hour = Calendar.current.component(.hour, from: Date())
        if !(3...11).contains(hour), l.count > 1, l[0].hasPrefix("Good morning") { l.removeFirst() }
        return (s, l)
    }

    static var on: Bool { UserDefaults.standard.bool(forKey: "wakeOn") }
    static var minutes: Int { (UserDefaults.standard.object(forKey: "wakeMinutes") as? Int) ?? 6 * 60 + 30 }
    static var days: Set<Int> { Set((UserDefaults.standard.array(forKey: "wakeDays") as? [Int]) ?? [2, 3, 4, 5, 6]) }   // Calendar weekdays, Sunday = 1
    static var style: Style { Style(rawValue: UserDefaults.standard.string(forKey: "wakeStyle") ?? "") ?? .PRAYER }
    static var snooze: Int { (UserDefaults.standard.object(forKey: "wakeSnooze") as? Int) ?? 9 }

    static func schedule() async -> Bool {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: (1...7).map { "wake\($0)" } + ["wakeSnooze"])
        guard on else { return true }
        guard (try? await c.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        for d in days {
            let n = UNMutableNotificationContent()
            n.title = tr("Good morning")
            n.body = tr("Tap to start your morning with the narrator.")
            n.sound = .default
            n.interruptionLevel = .timeSensitive
            n.userInfo = ["wake": true]
            let t = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60, weekday: d), repeats: true)
            try? await c.add(UNNotificationRequest(identifier: "wake\(d)", content: n, trigger: t))
        }
        return true
    }

    static func snoozeNow() {
        let n = UNMutableNotificationContent()
        n.title = tr("Good morning"); n.body = tr("Snooze is over. Tap to start your morning."); n.sound = .default; n.userInfo = ["wake": true]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "wakeSnooze", content: n,
                                                                     trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(snooze * 60), repeats: false)))
    }

    static var timeLabel: String {
        let d = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}

/// Speaks this morning's wake-up (the "wake" voice pack when it's on holysteps.org, otherwise the phone's voice).
@MainActor
final class WakeSpeaker: ObservableObject {
    static let shared = WakeSpeaker()
    @Published var playing = false
    @Published var line = ""
    private let synth = AVSpeechSynthesizer()
    private let clip = ClipPlayer()
    private var task: Task<Void, Never>?

    func play(_ style: WakeAlarm.Style = WakeAlarm.style) {
        stop()
        let (_, lines) = WakeAlarm.lines(style)
        guard !lines.isEmpty else { return }
        SermonPlayer.shared.stop(); MusicPlayer.shared.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        playing = true
        task = Task {
            // Grace wakes you, in English or Spanish; the phone's own voice is never used.
            let pack = await VoicePacks.shared.ensure(voice: I18n.shared.spanish ? "es_heart" : "af_heart", packId: "wake")
            for l in lines where !Task.isCancelled {
                line = tr(l)
                if let d = (I18n.shared.spanish ? pack?.audio(for: tr(l)) : nil) ?? pack?.audio(for: l) { _ = await clip.play(d) }
                else {
                    let words = Double(l.split(separator: " ").count)
                    let secs: Double = min(14, words / 2.5 + 0.8)
                    try? await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000))
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
            playing = false
        }
    }
    func stop() { task?.cancel(); clip.stop(); synth.stopSpeaking(at: .immediate); playing = false; line = "" }
}

struct WakeAlarmView: View {
    @State private var on = WakeAlarm.on
    @State private var time = Calendar.current.date(bySettingHour: WakeAlarm.minutes / 60, minute: WakeAlarm.minutes % 60, second: 0, of: Date()) ?? Date()
    @State private var days = WakeAlarm.days
    @State private var style = WakeAlarm.style
    @State private var snooze = WakeAlarm.snooze
    @State private var denied = false
    @ObservedObject private var speaker = WakeSpeaker.shared
    private let dawn = Color(hex: 0xF59E0B)

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("⏰ WAKE-UP ALARM").font(.hs(11, .semibold)).foregroundStyle(HS.peach).tracking(1.4)
                    T("Wake up with God").font(.hs(24)).foregroundStyle(HS.text)
                    T("At your time, the alarm rings. Open it and the narrator prays over your day, reads a verse, or gets you moving.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $on) { T("Alarm on").font(.hs(15, .semibold)) }.tint(HS.goldButton)
                            DatePicker(tr("Time"), selection: $time, displayedComponents: .hourAndMinute).font(.hs(15))
                            HStack(spacing: 6) {
                                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { d in
                                    let sel = days.contains(d)
                                    Button { if sel { days.remove(d) } else { days.insert(d) } } label: {
                                        D(Calendar.current.veryShortWeekdaySymbols[d - 1]).font(.hs(13, .semibold)).foregroundStyle(sel ? HS.onGold : HS.text)
                                            .frame(maxWidth: .infinity).padding(.vertical, 9).background(Circle().fill(sel ? HS.goldButton : HS.overlay(0.06)))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Calendar.current.weekdaySymbols[d - 1]).accessibilityAddTraits(sel ? .isSelected : [])
                                }
                            }
                        }
                    }
                    SectionHeader(title: "How to wake you").padding(.horizontal, -20)
                    ForEach(WakeAlarm.Style.allCases, id: \.self) { s in
                        Button { style = s } label: {
                            HStack(spacing: 12) {
                                D(s.emoji).font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) { T(s.label).font(.hs(15, .semibold)).foregroundStyle(HS.text); T(s.blurb).font(.hs(12)).foregroundStyle(HS.textMuted) }
                                Spacer()
                                if style == s { Image(systemName: "checkmark").foregroundStyle(dawn) }
                            }
                            .padding(14).background(RoundedRectangle(cornerRadius: 14).fill(style == s ? dawn.opacity(0.14) : HS.cardFill))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        T("Snooze").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        Spacer()
                        Picker("", selection: $snooze) { ForEach([5, 9, 10, 15], id: \.self) { D(tr("\($0) min")).tag($0) } }.pickerStyle(.segmented).frame(width: 220)
                    }
                    Button { speaker.playing ? speaker.stop() : speaker.play(style) } label: {
                        T(speaker.playing ? "Stop" : "▶  Try it now").font(.hs(15, .semibold)).foregroundStyle(HS.text).frame(maxWidth: .infinity).padding(.vertical, 13)
                            .overlay(Capsule().strokeBorder(HS.gold.opacity(0.5)))
                    }
                    if speaker.playing { D(speaker.line).font(.accent(16)).foregroundStyle(HS.italic) }
                    if denied { T("Turn on notifications for HolySteps in Settings so the alarm can ring.").font(.hs(12)).foregroundStyle(dawn) }
                    T("Keep your iPhone's sound on. Focus or Do Not Disturb can silence it unless HolySteps is allowed.").font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .padding(20).padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: on) { _, _ in save() }
        .onChange(of: time) { _, _ in save() }
        .onChange(of: days) { _, _ in save() }
        .onChange(of: style) { _, _ in save() }
        .onChange(of: snooze) { _, _ in save() }
        .onDisappear { speaker.stop() }
    }

    private func save() {
        let ud = UserDefaults.standard, c = Calendar.current.dateComponents([.hour, .minute], from: time)
        ud.set(on, forKey: "wakeOn"); ud.set((c.hour ?? 6) * 60 + (c.minute ?? 30), forKey: "wakeMinutes")
        ud.set(Array(days), forKey: "wakeDays"); ud.set(style.rawValue, forKey: "wakeStyle"); ud.set(snooze, forKey: "wakeSnooze")
        Task { let ok = await WakeAlarm.schedule(); await MainActor.run { denied = !ok; if !ok { on = false } } }
    }
}

/// Shown when the app opens from the alarm: the narrator starts, with Snooze and I'm up.
struct WakeRingView: View {
    @ObservedObject private var speaker = WakeSpeaker.shared
    let onClose: () -> Void
    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 18) {
                Spacer()
                D(Date().formatted(date: .omitted, time: .shortened)).font(.system(size: 64, weight: .light)).foregroundStyle(HS.text)
                T("Good morning").font(.hs(24)).foregroundStyle(HS.text)
                D(speaker.line).font(.accent(19)).foregroundStyle(HS.italic).multilineTextAlignment(.center).padding(.horizontal, 28).frame(minHeight: 120)
                Spacer()
                GoldButton(title: "I'm up") { speaker.stop(); onClose() }.padding(.horizontal, 28)
                Button { speaker.stop(); WakeAlarm.snoozeNow(); onClose() } label: { D(tr("Snooze \(WakeAlarm.snooze) min")).font(.hs(15)).foregroundStyle(HS.textSecondary) }
                    .padding(.bottom, 30)
            }
        }
        .onAppear { speaker.play() }
    }
}

/// Opens the wake-up screen when the alarm notification is tapped, and lets alarms show while the app is open.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationRouter()
    @Published var ringing = false

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if info["wake"] as? Bool == true { await MainActor.run { ringing = true } }
        // A tapped reminder opens its screen (Android's open_route).
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier, let route = info["route"] as? String {
            await MainActor.run { TabRouter.shared.open(route: route) }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if notification.request.content.userInfo["wake"] as? Bool == true { await MainActor.run { ringing = true } }
        return [.banner, .sound, .list]
    }
}
