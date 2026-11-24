import SwiftUI
import UserNotifications

/// Android's faith sleep library (data/SleepStories*.kt, extracted to Resources/sleep.json.gz by tools/sleep2json.py):
/// Bible sleep stories, kids' Bible stories and night prayers, read by Grace. 40 of the 99 have Grace's recording on
/// holysteps.org; the rest are read by the phone's voice.
enum SleepLibrary {
    private struct Item: Decodable { let id, kind, title, subtitle, script: String; let free: Bool }

    private static let items: [Item] = {
        guard let data = Bundle.main.resourceData("sleep.json.gz") else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }()
    static let freeIds: Set<String> = Set(items.filter(\.free).map(\.id))

    static let all: [Sermon] = {
        items.map {
            Sermon(id: $0.id, group: .sleep, title: $0.title, subtitle: $0.subtitle, scene: "NIGHT", recorded: [], script: $0.script,
                   voice: "af_heart", kind: $0.kind)
        }
    }()

    /// Free for everyone; the rest of the library comes with the Faith plan (Feature.SANCTUARY_FULL).
    @MainActor static func locked(_ s: Sermon) -> Bool { !freeIds.contains(s.id) && !AccountStore.shared.canUse(.sanctuaryFull) }

    static func list(_ kind: String) -> [Sermon] { all.filter { $0.kind == kind } }
    static func byId(_ id: String) -> Sermon? { all.first { $0.id == id } }
    /// The free taste of each kind on Android (SleepLibrary.FREE_IDS).
    static let firstStory = "story_david_stars"
    static let shortPrayer = "night_psalm4"
}

/// The bedtime reminder: one local notification a day at the chosen time.
enum BedtimeReminder {
    static let id = "bedtime"
    static var on: Bool { UserDefaults.standard.bool(forKey: "bedtimeOn") }
    static var minutes: Int { let m = UserDefaults.standard.object(forKey: "bedtimeMinutes") as? Int; return m ?? 21 * 60 + 30 }

    static func set(on: Bool, minutes: Int) async -> Bool {
        UserDefaults.standard.set(on, forKey: "bedtimeOn")
        UserDefaults.standard.set(minutes, forKey: "bedtimeMinutes")
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [id])
        guard on else { return true }
        guard (try? await c.requestAuthorization(options: [.alert, .sound])) == true else {
            UserDefaults.standard.set(false, forKey: "bedtimeOn"); return false
        }
        let content = UNMutableNotificationContent()
        content.title = tr("Time to wind down")
        content.body = tr("A Bible sleep story is ready when you are.")
        let t = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60), repeats: true)
        try? await c.add(UNNotificationRequest(identifier: id, content: content, trigger: t))
        return true
    }
}

/// The Sleep screen (Android SleepScreen): last night, the bedtime reminder, and the three kinds of sleep audio.
struct SleepView: View {
    @ObservedObject private var steps = StepsModel.shared
    @State private var open: Sermon?
    @State private var reminderOn = BedtimeReminder.on
    @State private var bedtime = Calendar.current.date(bySettingHour: BedtimeReminder.minutes / 60, minute: BedtimeReminder.minutes % 60, second: 0, of: Date()) ?? Date()

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenPhoto(name: "screen_sleep")
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            IconBadge(symbol: "moon.stars", size: 30, tint: 0x64A5E8)
                            T("Sleep").font(.hs(14, .medium)).foregroundStyle(HS.textMuted)
                        }
                        T("Rest well tonight").font(.hs(26)).foregroundStyle(HS.text)
                        ItalicAccent(text: "In peace I will lie down and sleep")
                    }
                    .padding(.horizontal, 20).padding(.top, 8)

                    SectionHeader(title: "Tonight").padding(.top, 8)
                    GlassCard(warm: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let m = steps.sleepLastNight {
                                HStack {
                                    T("Last night").font(.hs(14)).foregroundStyle(HS.textSecondary)
                                    Spacer()
                                    D("\(m / 60)h \(String(format: "%02d", m % 60))m").font(.hs(18, .semibold)).foregroundStyle(HS.text)
                                }
                            }
                            Toggle(isOn: $reminderOn) { T("Bedtime reminder").font(.hs(15, .semibold)).foregroundStyle(HS.text) }
                                .tint(HS.goldButton)
                            if reminderOn {
                                DatePicker(tr("Remind me at"), selection: $bedtime, displayedComponents: .hourAndMinute)
                                    .font(.hs(14)).foregroundStyle(HS.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .onChange(of: reminderOn) { save() }
                    .onChange(of: bedtime) { save() }

                    section("Bible sleep stories", "story")
                    section("Kids' Bible stories", "kids")
                    section("Night prayers", "night")
                }
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
        .task { await steps.refresh() }
    }

    private func save() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        let on = reminderOn
        Task { let ok = await BedtimeReminder.set(on: on, minutes: (c.hour ?? 21) * 60 + (c.minute ?? 30)); if !ok { reminderOn = false } }
    }

    @ViewBuilder
    private func section(_ title: String, _ kind: String) -> some View {
        let items = SleepLibrary.list(kind)
        if !items.isEmpty {
            SleepSection(title: title, items: items) { open = $0 }
        }
    }
}

private struct SleepSection: View {
    let title: String
    let items: [Sermon]
    let onPlay: (Sermon) -> Void
    @State private var all = false
    @State private var paywall = false
    @ObservedObject private var account = AccountStore.shared

    var body: some View {
        let shown = all ? items : Array(items.prefix(4))
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title, action: items.count > 4 ? (all ? "Show less" : "See all \(items.count)") : nil) { all.toggle() }
                .padding(.top, 8)
            VStack(spacing: 10) {
                ForEach(shown) { s in
                    let locked = SleepLibrary.locked(s)
                    Button { if locked { paywall = true } else { onPlay(s) } } label: {
                        GlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    T(s.title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                    T(s.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                                    D(tr(s.minutesLabel)).font(.hs(11)).foregroundStyle(HS.textSubtle)
                                }
                                Spacer(minLength: 6)
                                if locked { D("👑").font(.system(size: 18)).accessibilityLabel(tr("Part of the Faith plan")) } else { GoldPlayBadge(size: 32) }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $paywall) { PlansView(feature: .sanctuaryFull) }
    }
}
