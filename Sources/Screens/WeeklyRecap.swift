import SwiftUI
import UserNotifications

/// "Your week": a recap built on this phone from what the app already has (prayer log, Bible reading, journal,
/// listening, steps, sleep and the cycle). Nothing new is stored or sent anywhere.
struct WeeklyRecap {
    struct Insight: Identifiable, Hashable {
        let text: String
        /// Mentions steps, sleep or the cycle: left off the shared card unless the person opts in.
        let health: Bool
        var id: String { text }
    }

    let from: Date, to: Date
    let insights: [Insight]
    let streakDays: Int
    let streakLine: String
    let suggestion: String

    static func build(store: AppStore, steps: [String: Int], sleep: [String: Int], today: Date = Date()) -> WeeklyRecap {
        let cal = Calendar.current
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: today)) }
        let keys = days.map { AppStore.dayKey($0) }
        let log = ActivityLog.shared
        let prayed = Set(keys.filter { store.prayerLog[$0]?.contains(true) == true })
        var out: [Insight] = []

        // Prayer
        if !prayed.isEmpty { out.append(Insight(text: "You prayed \(prayed.count) of 7 days.", health: false)) }

        // Walking and prayer
        let withP = keys.filter { prayed.contains($0) }.compactMap { steps[$0] }, without = keys.filter { !prayed.contains($0) }.compactMap { steps[$0] }
        if withP.count >= 2, without.count >= 2 {
            let a = Double(withP.reduce(0, +)) / Double(withP.count), b = Double(without.reduce(0, +)) / Double(without.count)
            if a > b * 1.1 { out.append(Insight(text: "You walked more on the days you prayed.", health: true)) }
        }

        // Sleep after a wind-down (listened the evening before the morning you woke)
        let nights = keys.compactMap { k -> (String, Int)? in sleep[k].map { (k, $0) } }.filter { $0.1 >= 120 }
        if let best = nights.max(by: { $0.1 < $1.1 }), nights.count >= 3,
           let morning = AppStore.date(fromKey: best.0), let eve = cal.date(byAdding: .day, value: -1, to: morning) {
            let ek = AppStore.dayKey(eve)
            if log.did(.sleepStory, on: ek) || log.did(.prayerAudio, on: ek) {
                out.append(Insight(text: "Your longest sleep followed your evening wind-down.", health: true))
            }
        }

        // Best walking day
        if let best = keys.compactMap({ k in steps[k].map { (k, $0) } }).max(by: { $0.1 < $1.1 }), best.1 >= 1000,
           let d = AppStore.date(fromKey: best.0) {
            let day = d.formatted(.dateTime.weekday(.wide).locale(I18n.shared.locale))
            out.append(Insight(text: "Your best walking day was \(day): \(best.1.formatted()) steps.", health: true))
        }

        // Listening, reading and writing
        let listened = keys.filter { log.did(.sleepStory, on: $0) || log.did(.prayerAudio, on: $0) }.count
        if listened > 0 { out.append(Insight(text: listened == 1 ? "You listened to a sleep story or night prayer on 1 night." : "You listened to a sleep story or night prayer on \(listened) nights.", health: false)) }
        let read = keys.filter { store.readDays.contains($0) }.count
        if read > 0 { out.append(Insight(text: read == 1 ? "You opened the Bible on 1 day." : "You opened the Bible on \(read) days.", health: false)) }
        let wrote = store.journal.filter { keys.contains(AppStore.dayKey($0.created)) }.count
        if wrote > 0 { out.append(Insight(text: wrote == 1 ? "You wrote 1 journal entry." : "You wrote \(wrote) journal entries.", health: false)) }

        // The cycle
        if store.gender == "female", Rhythm(store: store, date: today).phase != nil {
            var counts: [CyclePhase: Int] = [:]
            for d in days { if let p = Rhythm(store: store, date: d).phase { counts[p, default: 0] += 1 } }
            if let top = counts.max(by: { $0.value < $1.value })?.key {
                let line: String = switch top {
                case .menstrual: "Most of this week was your period. Rest counts as part of the plan."
                case .follicular: "Most of this week was your follicular phase, when energy often rises."
                case .ovulation: "This week included ovulation, when many women feel their strongest."
                case .luteal: "Most of this week was your luteal phase. Gentler days are normal."
                }
                out.append(Insight(text: line, health: true))
            }
        }

        let n = prayed.count
        let streakLine = n == 7 ? "7 of 7 days. A full week." : (n == 6 ? "6 of 7 days. One missed day is fine."
            : (n > 0 ? "\(n) of 7 days. Every day you came back counts." : "A new week is a fresh start."))

        let avgSteps = steps.isEmpty ? nil : steps.values.reduce(0, +) / max(1, steps.count)
        let suggestion: String
        if n < 4 { suggestion = "Next week, try one short prayer each morning." }
        else if let a = avgSteps, a < store.stepGoal / 2 { suggestion = "Next week, add a 10-minute walk after one meal a day." }
        else if listened == 0 { suggestion = "Next week, try a sleep story on a night you feel restless." }
        else { suggestion = "Next week, keep the same rhythm. It's working." }

        return WeeklyRecap(from: days.first ?? today, to: days.last ?? today, insights: Array(out.prefix(5)), streakDays: n,
                           streakLine: streakLine, suggestion: suggestion)
    }

    var dates: String {
        let f = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(I18n.shared.locale)
        return "\(from.formatted(f)) – \(to.formatted(f))"
    }
}

/// The weekly reminder: one notification on the chosen day (Sunday evening unless changed).
enum RecapReminder {
    static let id = "weeklyRecap"
    static var on: Bool { UserDefaults.standard.object(forKey: "recapOn") as? Bool ?? true }
    /// 1 = Sunday … 7 = Saturday.
    static var weekday: Int { let w = UserDefaults.standard.integer(forKey: "recapWeekday"); return (1...7).contains(w) ? w : 1 }

    static func apply(on: Bool, weekday: Int) async {
        UserDefaults.standard.set(on, forKey: "recapOn")
        UserDefaults.standard.set(weekday, forKey: "recapWeekday")
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [id])
        guard on, (try? await c.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = tr("Your week is ready")
        content.body = tr("See your week with God and your body.")
        let t = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 19, minute: 0, weekday: weekday), repeats: true)
        try? await c.add(UNNotificationRequest(identifier: id, content: content, trigger: t))
    }
}

struct WeeklyRecapView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var steps = StepsModel.shared
    @State private var includeHealth = false
    @State private var remind = RecapReminder.on
    @State private var weekday = RecapReminder.weekday
    @State private var shareImage: Image?

    var body: some View {
        let recap = WeeklyRecap.build(store: store, steps: steps.stepsByDay, sleep: steps.sleepByDay)
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        T("Your week").font(.hs(28)).foregroundStyle(HS.text)
                        D(recap.dates).font(.hs(14)).foregroundStyle(HS.textMuted)
                        ItalicAccent(text: "with God and your body")
                    }
                    RecapCard(recap: recap, includeHealth: true)
                    if FirstWeek.shared.dayNumber >= 6 && FirstWeek.shared.dayNumber <= 8 && !FirstWeek.shared.dismissed { FreeWeekPanel() }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            T("Share").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            Toggle(isOn: $includeHealth) {
                                VStack(alignment: .leading, spacing: 2) {
                                    T("Include steps, sleep and cycle").font(.hs(14)).foregroundStyle(HS.text)
                                    T("Off: the card shows only your faith week.").font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                            }
                            .tint(HS.goldButton)
                            if let shareImage {
                                ShareLink(item: shareImage, preview: SharePreview(tr("Your week"), image: shareImage)) {
                                    T("Share as a card").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Capsule().fill(HS.goldButton))
                                }
                            }
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $remind) { T("Remind me each week").font(.hs(14, .semibold)).foregroundStyle(HS.text) }.tint(HS.goldButton)
                            if remind {
                                Picker(tr("Day"), selection: $weekday) {
                                    ForEach(1...7, id: \.self) { d in D(Calendar.current.standaloneWeekdaySymbols[d - 1].localizedCapitalized).tag(d) }
                                }
                                .tint(HS.gold)
                                T("In the evening, at 7 PM.").font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ActivityLog.shared.add(.recap)
            await steps.refresh()
            render(recap: WeeklyRecap.build(store: store, steps: steps.stepsByDay, sleep: steps.sleepByDay))
            await RecapReminder.apply(on: remind, weekday: weekday)
        }
        .onChange(of: includeHealth) { render(recap: recap) }
        .onChange(of: remind) { let r = remind, w = weekday; Task { await RecapReminder.apply(on: r, weekday: w) } }
        .onChange(of: weekday) { let r = remind, w = weekday; Task { await RecapReminder.apply(on: r, weekday: w) } }
    }

    @MainActor private func render(recap: WeeklyRecap) {
        let card = RecapCard(recap: recap, includeHealth: includeHealth)
            .padding(24).frame(width: 390)
            .background(LinearGradient(colors: [Color(hex: 0x1A1226), Color(hex: 0x120D1A), Color(hex: 0x0B0810)], startPoint: .top, endPoint: .bottom))
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: card)
        r.scale = 3
        if let ui = r.uiImage { shareImage = Image(uiImage: ui) }
    }
}

/// The recap itself: insights, the streak told with grace, and one suggestion.
struct RecapCard: View {
    let recap: WeeklyRecap
    let includeHealth: Bool

    var body: some View {
        GlassCard(warm: true) {
            VStack(alignment: .leading, spacing: 12) {
                T("YOUR WEEK").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                D(recap.dates).font(.hs(13)).foregroundStyle(HS.textMuted)
                let shown = recap.insights.filter { includeHealth || !$0.health }
                if shown.isEmpty {
                    T("A quiet week. That's all right. Next week is a fresh start.").font(.hs(15)).foregroundStyle(HS.text)
                }
                ForEach(shown) { i in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(HS.goldButton).frame(width: 6, height: 6).padding(.top, 8)
                        T(i.text).font(.hs(15)).foregroundStyle(HS.text).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider().overlay(HS.gold.opacity(0.3))
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Capsule().fill(i < recap.streakDays ? HS.goldButton : HS.overlay(0.12)).frame(height: 6)
                    }
                }
                T(recap.streakLine).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                T(recap.suggestion).font(.accent(17)).foregroundStyle(HS.italic)
                HStack(spacing: 6) {
                    HolyStepsMark().frame(width: 16, height: 16)
                    D("HolySteps").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
            }
        }
    }
}
