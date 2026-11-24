import SwiftUI

/// The first-week path: one small step a day for the seven days of the free week. A day is done when its action is
/// done; a missed day never resets anything, the card just offers that day again. Kept on this phone.
final class FirstWeek: ObservableObject {
    static let shared = FirstWeek()
    private let d = UserDefaults.standard

    @Published private(set) var start: String { didSet { d.set(start, forKey: "firstWeekStart") } }
    @Published private(set) var done: Set<Int> { didSet { d.set(Array(done), forKey: "firstWeekDone") } }
    @Published private(set) var dismissed: Bool { didSet { d.set(dismissed, forKey: "firstWeekDismissed") } }

    private init() {
        if let s = d.string(forKey: "firstWeekStart") {
            start = s
            dismissed = d.bool(forKey: "firstWeekDismissed")
        } else {
            start = AppStore.dayKey()
            // Only for new people: a phone that already held HolySteps data skips the path.
            let existing = ["name", "prayerLog", "readDays", "bibleLastBook", "journal"].contains { d.object(forKey: $0) != nil }
            dismissed = existing
            d.set(start, forKey: "firstWeekStart")
            d.set(existing, forKey: "firstWeekDismissed")
        }
        done = Set((d.array(forKey: "firstWeekDone") as? [Int]) ?? [])
    }

    var startDate: Date { AppStore.date(fromKey: start) ?? Date() }
    /// 1 on the first day, 7 on the last day of the free week.
    var dayNumber: Int { (Calendar.current.dateComponents([.day], from: startDate, to: Calendar.current.startOfDay(for: Date())).day ?? 0) + 1 }
    var trialEnds: Date { Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? Date() }
    var active: Bool { !dismissed && dayNumber <= 7 && done.count < 7 }
    /// The step to offer today: the earliest one not done yet, up to today's day.
    var step: Int? { active ? (1...min(7, max(1, dayNumber))).first { !done.contains($0) } : nil }

    func dismiss() { dismissed = true }

    /// Marks every step whose action has been done since the path started.
    @MainActor func refresh(store: AppStore, stepsToday: Int) {
        guard !dismissed else { return }
        let log = ActivityLog.shared
        var now = done
        if log.didSince(.verse, start) && (log.didSince(.walk, start) || stepsToday >= 1000) { now.insert(1) }
        if log.didSince(.prayerAudio, start) { now.insert(2) }
        if log.didSince(.sleepStory, start) { now.insert(3) }
        let tracked = store.gender == "female" ? (!store.periodStarts.isEmpty || log.didSince(.tracker, start)) : log.didSince(.tracker, start)
        if tracked { now.insert(4) }
        if log.didSince(.sermon, start) { now.insert(5) }
        if store.journal.contains(where: { AppStore.dayKey($0.created) >= start }) || QuizLog.shared.log.keys.contains(where: { $0 >= start }) { now.insert(6) }
        if log.didSince(.recap, start) { now.insert(7) }
        if now != done { done = now }
    }

    func eraseAll() { done = []; dismissed = true }

    struct Step { let title: String; let detail: String; let minutes: String }

    static func step(_ day: Int, gender: String) -> Step {
        switch day {
        case 1: Step(title: "Today's verse and a 10-minute walk", detail: "Read or listen to today's verse, then take a short walk.", minutes: "About 12 min")
        case 2: Step(title: "One short prayer", detail: "A guided prayer, read aloud for you.", minutes: "About 3 min")
        case 3: Step(title: "A sleep story tonight", detail: "Set a bedtime reminder, then listen in bed.", minutes: "1 min now")
        case 4:
            gender == "female" ? Step(title: "Add your cycle", detail: "Log the day your last period started.", minutes: "1 min")
                : Step(title: "Set your step goal", detail: "Pick a daily step goal that fits you.", minutes: "1 min")
        case 5: Step(title: "This week's sermon", detail: "A short sermon for this week.", minutes: "About 5 min")
        case 6: Step(title: "One line or one quiz", detail: "Write one line in your journal, or play today's Bible quiz.", minutes: "2 min")
        default: Step(title: "Your week with God and your body", detail: "See your first weekly recap.", minutes: "2 min")
        }
    }
}

/// "Your first week" on Home: today's step and a row of seven dots.
struct FirstWeekCard: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var week = FirstWeek.shared
    let day: Int
    let onGo: (Int) -> Void
    @State private var confirmHide = false

    var body: some View {
        let s = FirstWeek.step(day, gender: store.gender)
        GlassCard(warm: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    T("YOUR FIRST WEEK").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                    Spacer()
                    Button { confirmHide = true } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(HS.textMuted).frame(width: 30, height: 30) }
                        .accessibilityLabel(tr("Hide your first week"))
                }
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { d in
                        let on = week.done.contains(d)
                        Circle().fill(on ? HS.goldButton : (d == day ? HS.peach.opacity(0.35) : HS.overlay(0.10)))
                            .overlay(Circle().strokeBorder(d == day ? HS.goldButton : .clear, lineWidth: 1))
                            .frame(width: 12, height: 12)
                    }
                    Spacer()
                    T("\(week.done.count) of 7").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tr("\(week.done.count) of 7 days done"))
                T("Day \(day)").font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                T(s.title).font(.hs(17, .semibold)).foregroundStyle(HS.text)
                T(s.detail).font(.hs(13)).foregroundStyle(HS.textMuted)
                HStack {
                    T(s.minutes).font(.hs(12)).foregroundStyle(HS.textSubtle)
                    Spacer()
                    GoldButton(title: day == 7 ? "Open your week" : "Start") { onGo(day) }.frame(width: 150)
                }
            }
        }
        .confirmationDialog(tr("Hide your first week?"), isPresented: $confirmHide, titleVisibility: .visible) {
            Button(tr("Hide it"), role: .destructive) { week.dismiss() }
        } message: { T("You can still find every part of the app from Home and the tabs.") }
    }
}

/// Day 7 and the trial screen: what the free plan keeps, what the paid plans add, and when the free week ends.
struct FreeWeekPanel: View {
    @ObservedObject private var week = FirstWeek.shared
    @Environment(\.openURL) private var openURL

    static let keeps = ["The whole Bible, today's verse and your prayer log", "Steps, walks and your cycle dates",
                        "One sleep story, one kids' story and one night prayer", "This week's sermon",
                        "Writing in your journal (the last 7 days stay open)", "988 and safety help, always"]
    static let adds = ["Every sleep story, night prayer and kids' bedtime story", "Listen to any Bible chapter",
                       "Every hymn and worship song", "Devotional plans, verse images and your whole journal",
                       "Cycle insights, trends and the men's health plan"]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("Your free week").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                D(tr("Ends {0}").replacingOccurrences(of: "{0}", with: week.trialEnds.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(I18n.shared.locale))))
                    .font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                T("The free plan keeps").font(.hs(13, .semibold)).foregroundStyle(HS.textSecondary).padding(.top, 4)
                ForEach(Self.keeps, id: \.self) { line($0, "checkmark") }
                T("The paid plans add").font(.hs(13, .semibold)).foregroundStyle(HS.textSecondary).padding(.top, 4)
                ForEach(Self.adds, id: \.self) { line($0, "plus") }
                T("Nothing is charged in the app. If you choose a plan, you pick it and pay on holysteps.org.")
                    .font(.hs(12)).foregroundStyle(HS.textMuted).padding(.top, 4)
                Button { openURL(URL(string: AppLinks.site + "/plans")!) } label: {
                    T("See plans on holysteps.org →").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                }
            }
        }
    }

    private func line(_ s: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(HS.body).frame(width: 14).padding(.top, 3)
            T(s).font(.hs(13)).foregroundStyle(HS.text)
        }
    }
}
