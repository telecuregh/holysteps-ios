import SwiftUI
import HealthKit

@MainActor
final class StepsModel: ObservableObject {
    static let shared = StepsModel()
    @Published var today: Int = 0
    @Published var week: [(day: String, steps: Int)] = []
    @Published var available = HKHealthStore.isHealthDataAvailable()
    @Published var asked = UserDefaults.standard.bool(forKey: "healthAsked") { didSet { UserDefaults.standard.set(asked, forKey: "healthAsked") } }
    /// Walks logged by hand (Android's "Log a Walk": 100 steps a minute), per day.
    @Published private(set) var manual: [String: Int] = UserDefaults.standard.dictionary(forKey: "manualSteps") as? [String: Int] ?? [:]

    func logWalk(minutes: Int) {
        let k = AppStore.dayKey()
        manual[k, default: 0] += min(120, max(0, minutes)) * 100
        UserDefaults.standard.set(manual, forKey: "manualSteps")
        ActivityLog.shared.add(.walk)
        today += min(120, max(0, minutes)) * 100
        stepsByDay[k] = today
        if !week.isEmpty { week[week.count - 1].steps = today }
    }
    private let health = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let sleepType = HKCategoryType(.sleepAnalysis)
    /// Steps per day and minutes asleep per night (keyed by the morning you woke), for the last 7 days.
    @Published var stepsByDay: [String: Int] = [:]
    @Published var sleepByDay: [String: Int] = [:]
    var sleepLastNight: Int? { sleepByDay[AppStore.dayKey()].flatMap { $0 >= 60 ? $0 : nil } }

    func request() async {
        guard available else { return }
        do {
            try await health.requestAuthorization(toShare: [], read: [stepType, sleepType])
            asked = true
            await refresh()
        } catch { asked = true }
    }

    func refresh() async {
        guard available else {
            let k = AppStore.dayKey(); today = manual[k] ?? 0; stepsByDay[k] = today; return
        }
        let cal = Calendar.current
        var rows: [(String, Int)] = []
        let f = DateFormatter(); f.locale = I18n.shared.locale; f.dateFormat = "EEE"
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let start = cal.startOfDay(for: d)
            let end = offset == 0 ? Date() : (cal.date(byAdding: .day, value: 1, to: start) ?? Date())
            rows.append((f.string(from: d), await steps(from: start, to: end)))
        }
        // Add any walks logged by hand.
        for i in rows.indices {
            if let d = cal.date(byAdding: .day, value: -(rows.count - 1 - i), to: Date()) { rows[i].1 += manual[AppStore.dayKey(d)] ?? 0 }
        }
        week = rows.map { (day: $0.0, steps: $0.1) }
        today = rows.last?.1 ?? 0
        var byDay: [String: Int] = [:], sleep: [String: Int] = [:]
        for offset in 0...6 {
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let key = AppStore.dayKey(d)
            byDay[key] = rows.count > 6 - offset ? rows[6 - offset].1 : 0
            // The night before that morning: 6 PM to noon.
            let morning = cal.startOfDay(for: d)
            let from = morning.addingTimeInterval(-6 * 3600), to = morning.addingTimeInterval(12 * 3600)
            let m = await asleepMinutes(from: from, to: min(to, Date()))
            if m > 0 { sleep[key] = m }
        }
        stepsByDay = byDay
        sleepByDay = sleep
    }

    private func asleepMinutes(from: Date, to: Date) async -> Int {
        guard to > from else { return 0 }
        return await withCheckedContinuation { cont in
            let p = HKQuery.predicateForSamples(withStart: from, end: to)
            let q = HKSampleQuery(sampleType: sleepType, predicate: p, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue]
                // Merge overlapping samples (a watch and the phone can both record the same night).
                let spans = (samples as? [HKCategorySample] ?? []).filter { asleep.contains($0.value) }
                    .map { (max($0.startDate, from), min($0.endDate, to)) }.sorted { $0.0 < $1.0 }
                var total: TimeInterval = 0
                var cur: (Date, Date)?
                for s in spans {
                    if let c = cur, s.0 <= c.1 { cur = (c.0, max(c.1, s.1)) }
                    else { if let c = cur { total += c.1.timeIntervalSince(c.0) }; cur = s }
                }
                if let c = cur { total += c.1.timeIntervalSince(c.0) }
                cont.resume(returning: Int(total / 60))
            }
            health.execute(q)
        }
    }

    private func steps(from: Date, to: Date) async -> Int {
        await withCheckedContinuation { cont in
            let p = HKQuery.predicateForSamples(withStart: from, end: to)
            let q = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: p, options: .cumulativeSum) { _, r, _ in
                cont.resume(returning: Int(r?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
            }
            health.execute(q)
        }
    }
}

/// Android's WalkScreen (the Fitness tab): the photo, "Move with Purpose", and Today, Train and Progress. Live walks
/// with the map, the Form Coach, leagues and circles come with the health and community phases; until then they are
/// left out rather than shown empty.
struct FitnessView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var checkIns = CheckInStore.shared
    @ObservedObject private var model = StepsModel.shared
    @ObservedObject private var router = TabRouter.shared
    @AppStorage("stepGoal") private var goal = 8000
    @State private var tab = 0
    @State private var showManual = false
    @State private var showGoal = false
    @State private var music = false

    private var streak: Int {
        var n = 0
        for offset in 0..<7 {
            guard let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { break }
            let s = model.stepsByDay[AppStore.dayKey(d)] ?? 0
            if s >= goal { n += 1 } else if offset > 0 { break }
        }
        return n
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenPhoto(name: "screen_fitness")
                        header
                        SubTabs(tabs: ["Today", "Train", "Progress"], selected: $tab)
                        Spacer().frame(height: 16)
                        switch tab {
                        case 0: today
                        case 1: train
                        default: progress
                        }
                        Spacer().frame(height: 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showManual) { ManualWalkSheet { model.logWalk(minutes: $0) } }
            .sheet(isPresented: $showGoal) { StepGoalSheet() }
            .navigationDestination(isPresented: $music) { MusicView(tab: 0) }
            .task { await model.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    IconBadge(symbol: "figure.run", size: 30, tint: 0x56B892)
                    T("Fitness").font(.hs(13, .semibold)).tracking(0.6).foregroundStyle(HS.readable(0x3E6A4C, dark: 0x56B892))
                }
                Spacer()
                T("\(streak)-day goal streak").font(.hs(12, .semibold)).foregroundStyle(HS.gold)
            }
            Spacer().frame(height: 10)
            T("Move with Purpose").font(.hs(26)).foregroundStyle(HS.text)
            ItalicAccent(text: "Every step strengthens body and spirit", size: 17)
        }
        .padding(.top, 44).padding(.horizontal, 20).padding(.bottom, 14)
    }

    // MARK: Today

    /// Android's todayStepTarget: the goal scaled to today's energy (high 115 %, steady 100 %, gentle 80 %, rest 60 %).
    private var dayTarget: Int { max(1, Int((Double(goal) * Coach.plan(store: store).stepMultiplier * max(0.0001, BodyEnergy.todayAdjust.multiplier)).rounded())) }

    @ViewBuilder private var today: some View {
        let target = dayTarget
        let progress = min(1, Double(model.today) / Double(max(1, target)))
        let km = Double(model.today) * 0.70 / 1000
        let kcal = Int((km * 70 * 0.78).rounded())
        GlassCard {
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(HS.overlay(0.10), lineWidth: 6.3)
                    Circle().trim(from: 0, to: max(0.001, progress))
                        .stroke(HS.isLight ? HS.body : Color(hex: 0xF3D5C0), style: StrokeStyle(lineWidth: 6.3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        D(model.today.formatted()).font(.hs(40)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.5)
                        T("steps today").font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                }
                .frame(width: 168, height: 168)
                T(target < goal ? "Goal today: \(target.formatted()) steps (a gentler day; usually \(goal.formatted()))" : "Goal: \(goal.formatted()) steps")
                    .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center).padding(.top, 12)
                T(progress >= 1 ? "Goal reached! +20 pts earned"
                  : (progress >= 0.75 ? "So close, \((target - model.today).formatted()) more steps to your goal"
                     : "\((target - model.today).formatted()) steps to your goal · +20 pts when you hit it"))
                    .font(.hs(13, .semibold)).foregroundStyle(progress >= 1 ? HS.body : HS.gold)
                    .multilineTextAlignment(.center).padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        HStack(spacing: 12) {
            statCard("flame", "\(kcal)", "kcal", 0xF3D5C0)
            statCard("mappin", String(format: "%.2f", km / 1.609344), "mi", 0x64A5E8)
            statCard("timer", minutesText(model.today), "walking", 0x56B892)
        }
        .padding(.horizontal, 20).padding(.top, 14)
        T("Calories are the total your body used while walking, including what it burns at rest.")
            .font(.hs(11)).foregroundStyle(HS.textSubtle).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 8)
        T("Calories and distance are for an average adult.")
            .font(.hs(11)).foregroundStyle(HS.textSubtle).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 4)
        if model.available && !model.asked {
            Button { Task { await model.request() } } label: {
                GlassCard {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "figure.walk", size: 36, tint: 0xF3D5C0)
                        VStack(alignment: .leading, spacing: 2) {
                            T("Count your steps").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                            T("Allow HolySteps to read your steps from Apple Health. Until then, use \"Log a Walk\" under Train.")
                                .font(.hs(12)).foregroundStyle(HS.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain).padding(.horizontal, 20).padding(.top, 12)
        }
        NavigationLink { WalkSetupView() } label: {
            GlassCard {
                HStack(spacing: 12) {
                    IconBadge(symbol: "figure.walk", size: 40, tint: 0x56B892)
                    VStack(alignment: .leading, spacing: 3) {
                        T("Start a Walk").font(.hs(17, .semibold)).foregroundStyle(HS.text)
                        T("Live map, pace coaching, warm-up and cool-down. Outdoor or indoor. Earn up to +40 pts.")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer(minLength: 10)
                    GoldPlayBadge(size: 38)
                }
            }
        }
        .buttonStyle(.plain).padding(.horizontal, 20).padding(.top, 14)
        DailyCoachCard().padding(.horizontal, 20).padding(.top, 14)
        SectionHeader(title: "For the walk").padding(.top, 10)
        Button { music = true } label: {
            GlassCard {
                HStack(spacing: 12) {
                    IconBadge(symbol: "headphones", size: 36, tint: 0xF3D5C0)
                    VStack(alignment: .leading, spacing: 2) {
                        T("Music for your walk").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T("Gospel songs to walk with").font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    GoldPlayBadge(size: 32)
                }
            }
        }
        .buttonStyle(.plain).padding(.horizontal, 20)
        NavigationLink { PrayerWalkFeatureView() } label: {
            GlassCard {
                HStack(spacing: 12) {
                    IconBadge(symbol: "map.fill", size: 36, tint: 0x56B892)
                    VStack(alignment: .leading, spacing: 2) {
                        T("Prayer Walk Map").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T("Pray for your neighborhood as you walk").font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(HS.textMuted)
                }
            }
        }
        .buttonStyle(.plain).padding(.horizontal, 20)
    }

    private func minutesText(_ steps: Int) -> String {
        let m = max(0, steps / 100)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m) min"
    }

    private func statCard(_ symbol: String, _ value: String, _ unit: String, _ hex: UInt32) -> some View {
        GlassCard(padding: 12) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(HS.readable(hex))
                D(value).font(.hs(17, .semibold)).foregroundStyle(HS.readable(hex)).lineLimit(1).minimumScaleFactor(0.7)
                T(unit).font(.hs(11)).foregroundStyle(HS.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Train

    private var train: some View {
        VStack(spacing: 0) {
            ToolSection(title: "Challenges", items: [
                ToolItem(symbol: "trophy", color: HS.gold, title: "My challenges", sub: "Active fitness and faith commitments",
                         destination: AnyView(CommitmentsView())),
            ])
            ToolSection(title: "Train", items: [
                ToolItem(symbol: "figure.strengthtraining.traditional", color: HS.body, title: "Workouts", sub: "\(Coach.routines.count - 1) guided sessions with a coach's voice",
                         destination: AnyView(WorkoutLibraryView())),
                ToolItem(symbol: "plus", color: HS.mind, title: "Log a Walk", sub: "Walked without your phone? Add it", action: { showManual = true }),
                ToolItem(symbol: "target", color: HS.body, title: "Step goal", sub: "\(goal.formatted()) steps a day", action: { showGoal = true }),
                ToolItem(symbol: "music.note", color: HS.peach, title: "Walking music", sub: "Gospel songs to walk with", destination: AnyView(MusicView(tab: 0))),
            ])
        }
    }

    // MARK: Progress

    @ViewBuilder private var progress: some View {
        let week = model.week
        let total = week.map(\.steps).reduce(0, +)
        let goalDays = week.filter { $0.steps >= goal }.count
        ToolSection(title: "Your data", items: [
            ToolItem(symbol: "list.bullet", color: HS.body, title: "Your walks", sub: "\(WalkStore.shared.walks.count) saved",
                     destination: AnyView(WalkHistoryView())),
            ToolItem(symbol: "chart.bar", color: HS.peach, title: "Active minutes", sub: "\(WalkStore.shared.weekActiveMinutes) of 150 this week"),
        ])
        SectionHeader(title: "This Week").padding(.top, 10)
        HStack(spacing: 12) {
            statCard("shoeprints.fill", total.formatted(), "steps", 0x56B892)
            statCard("target", "\(goalDays)/7", "goal days", 0x9D7FEA)
            statCard("chart.line.uptrend.xyaxis", (week.isEmpty ? 0 : total / 7).formatted(), "daily avg", 0x64A5E8)
        }
        .padding(.horizontal, 20)
        GlassCard {
            let maxV = Double(max(week.map(\.steps).max() ?? 0, goal))
            HStack(alignment: .bottom) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    let isToday = i == week.count - 1
                    let hit = d.steps >= goal
                    VStack(spacing: 4) {
                        if hit { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(HS.body) }
                        UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                            .fill(hit ? HS.body : (isToday ? Color(hex: 0xF3D5C0) : HS.body.opacity(0.35)))
                            .frame(width: 26, height: max(4, min(80, Double(d.steps) / maxV * 80)))
                        D(isToday ? tr("Today") : d.day).font(.hs(10)).foregroundStyle(isToday ? HS.text : HS.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110, alignment: .bottom)
        }
        .padding(.horizontal, 20).padding(.top, 14)
        InsightBubble(text: insight(goalDays)).padding(.horizontal, 20).padding(.top, 18)
    }

    private func insight(_ goalDays: Int) -> String {
        let pct = model.today * 100 / max(1, goal)
        if pct >= 100 { return "You've crushed your goal today!" }
        if goalDays >= 5 { return "\(goalDays) goal days this week, that's real discipline. Keep showing up." }
        if pct >= 50 { return "Halfway there! A 15-minute walk after a meal is an easy way to finish." }
        return "Start with just 10 minutes. Short walks add up fast."
    }
}

/// Android's ManualWalkDialog: minutes walked, counted as 100 steps a minute.
struct ManualWalkSheet: View {
    let onLog: (Int) -> Void
    @State private var minutes = 20
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HSSheet(title: "Log a walk") {
            VStack(spacing: 14) {
                T("\(minutes) min").font(.hs(30, .semibold)).foregroundStyle(HS.gold)
                T("≈ \((minutes * 100).formatted()) steps").font(.hs(13)).foregroundStyle(HS.textMuted)
                Stepper(tr("Minutes"), value: $minutes, in: 5...120, step: 5).foregroundStyle(HS.text)
                GoldButton(title: "Log walk") { onLog(minutes); dismiss() }
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}
