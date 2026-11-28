import SwiftUI
import UserNotifications

/// Android's SelfCareReminders and MyRemindersScreen: drink water and stand up and move (every 1–3 hours between two
/// times of day) and wind down for bed (once a night). Off until turned on. The water reminder's "I drank one" adds a
/// glass to today's Food & water. Medicine reminders are their own thing, in Health helper.
enum SelfCare {
    static let waterGoal = 8
    static let drankAction = "DRANK"
    static let waterCategory = "WATER"

    enum Kind: String, CaseIterable, Identifiable {
        case water, move, bed
        var id: String { rawValue }
        var repeats: Bool { self != .bed }
        var title: String { switch self { case .water: "💧 Drink water"; case .move: "🚶 Stand up and move"; case .bed: "🌙 Wind down for bed" } }
        var blurb: String {
            switch self {
            case .water: "A glass of water every few hours. Tap \"I drank one\" on the reminder to count it."
            case .move: "A short walk or stretch when you've been sitting."
            case .bed: "One reminder each night to put the phone away and rest."
            }
        }
        var defaults: Setting {
            switch self {
            case .water: Setting(on: false, every: 2, start: 9, end: 21)
            case .move: Setting(on: false, every: 2, start: 10, end: 18)
            case .bed: Setting(on: false, every: 0, start: 22, end: 22)
            }
        }
    }

    struct Setting: Equatable { var on: Bool; var every: Int; var start: Int; var end: Int }

    static func setting(_ k: Kind) -> Setting {
        let p = (UserDefaults.standard.string(forKey: "selfcare_\(k.rawValue)") ?? "").split(separator: "|").compactMap { Int($0) }
        guard p.count == 4 else { return k.defaults }
        return Setting(on: p[0] == 1, every: min(3, max(1, p[1])), start: min(23, max(0, p[2])), end: min(23, max(0, p[3])))
    }

    static func save(_ k: Kind, _ s: Setting) {
        UserDefaults.standard.set("\(s.on ? 1 : 0)|\(s.every)|\(s.start)|\(s.end)", forKey: "selfcare_\(k.rawValue)")
        schedule(k, s)
    }

    /// The hours it fires each day.
    static func hours(_ k: Kind, _ s: Setting) -> [Int] {
        k.repeats ? Array(stride(from: s.start, through: max(s.start, s.end), by: min(3, max(1, s.every)))) : [s.start]
    }

    /// One repeating daily notification per hour (iOS repeats them by itself, so nothing needs re-arming).
    static func schedule(_ k: Kind, _ s: Setting) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: (0...23).map { "selfcare.\(k.rawValue).\($0)" })
        guard s.on else { return }
        for h in hours(k, s) {
            let n = UNMutableNotificationContent()
            switch k {
            case .water:
                n.title = tr("💧 Time for a glass of water")
                n.body = tr("A glass now keeps you on track for {0} today.").replacingOccurrences(of: "{0}", with: "\(waterGoal)")
                n.categoryIdentifier = waterCategory
                n.userInfo = ["route": "feature:Body basics"]
            case .move:
                n.title = tr("🚶 Stand up and move")
                n.body = tr("A minute of walking or stretching helps your back, your mood and your focus.")
                n.userInfo = ["route": "feature:My reminders"]
            case .bed:
                n.title = tr("🌙 Time to wind down")
                n.body = tr("Put the phone away, pray, and rest. \"He giveth his beloved sleep.\" Psalm 127:2")
                n.userInfo = ["route": "feature:My reminders"]
            }
            n.sound = .default
            c.add(UNNotificationRequest(identifier: "selfcare.\(k.rawValue).\(h)", content: n,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: h, minute: 0), repeats: true)))
        }
    }

    /// The "I drank one" button on the water reminder (registered when the app starts).
    static func registerCategories() {
        let drank = UNNotificationAction(identifier: drankAction, title: tr("I drank one"), options: [])
        var set: Set<UNNotificationCategory> = [UNNotificationCategory(identifier: waterCategory, actions: [drank], intentIdentifiers: [])]
        HealthHelper.registerCategory(into: &set)
        UNUserNotificationCenter.current().setNotificationCategories(set)
    }

    static func hourLabel(_ h: Int) -> String { h == 0 ? "12 AM" : h < 12 ? "\(h) AM" : h == 12 ? "12 PM" : "\(h - 12) PM" }
}

struct MyRemindersView: View {
    @State private var settings: [SelfCare.Kind: SelfCare.Setting] = Dictionary(uniqueKeysWithValues: SelfCare.Kind.allCases.map { ($0, SelfCare.setting($0)) })
    @State private var blocked = false

    private func update(_ k: SelfCare.Kind, _ s: SelfCare.Setting) { settings[k] = s; SelfCare.save(k, s) }

    private func turnOn(_ k: SelfCare.Kind, _ s: SelfCare.Setting) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { if ok { var t = s; t.on = true; update(k, t) } else { blocked = true } }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    T("My reminders").font(.hs(26, .semibold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    T("Gentle nudges for the things that matter most. Each one is off until you turn it on.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    if blocked {
                        T("Notifications are off for HolySteps. Turn them on in Settings → HolySteps → Notifications.")
                            .font(.hs(12)).foregroundStyle(HS.gold).padding(.top, 6)
                    }
                }
                ForEach(SelfCare.Kind.allCases) { k in
                    let s = settings[k] ?? k.defaults
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding(get: { s.on }, set: { on in if on { turnOn(k, s) } else { var t = s; t.on = false; update(k, t) } })) {
                                VStack(alignment: .leading, spacing: 2) {
                                    T(k.title).font(.hs(16, .bold)).foregroundStyle(HS.text)
                                    T(k.blurb).font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                            }
                            .tint(HS.goldButton)
                            if s.on {
                                if k.repeats {
                                    T("How often").font(.hs(12)).foregroundStyle(HS.textMuted)
                                    HStack(spacing: 6) {
                                        ForEach(1...3, id: \.self) { h in
                                            Button { var t = s; t.every = h; update(k, t) } label: {
                                                T(h == 1 ? "Every hour" : "Every \(h) hours").font(.hs(12, .semibold))
                                                    .foregroundStyle(s.every == h ? HS.onGold : HS.text)
                                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                                    .background(RoundedRectangle(cornerRadius: 10).fill(s.every == h ? HS.goldButton : HS.cardFill))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    stepper("From", s.start) { h in var t = s; t.start = h; t.end = max(h, s.end); update(k, t) }
                                    stepper("Until", s.end) { h in var t = s; t.end = h; t.start = min(h, s.start); update(k, t) }
                                } else {
                                    stepper("At", s.start) { h in var t = s; t.start = h; t.end = h; update(k, t) }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                NavigationLink { HealthHelperView() } label: {
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                T("💊 Medicine reminders").font(.hs(16, .bold)).foregroundStyle(HS.text)
                                T("Each medicine at its own times, with a Taken button. Set them up in Health helper.").font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            Text("→").font(.hs(18)).foregroundStyle(HS.peach)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("My reminders"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepper(_ label: String, _ hour: Int, _ change: @escaping (Int) -> Void) -> some View {
        HStack {
            T(label).font(.hs(13)).foregroundStyle(HS.textMuted)
            Spacer()
            Button { change((hour + 23) % 24) } label: { Text("−").font(.hs(20)).foregroundStyle(HS.text).frame(width: 44, height: 36) }
                .accessibilityLabel(tr("Earlier"))
            D(SelfCare.hourLabel(hour)).font(.hs(15, .semibold)).foregroundStyle(HS.text).frame(width: 64)
            Button { change((hour + 1) % 24) } label: { Text("+").font(.hs(20)).foregroundStyle(HS.text).frame(width: 44, height: 36) }
                .accessibilityLabel(tr("Later"))
        }
        .buttonStyle(.plain)
    }
}
