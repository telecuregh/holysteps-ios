import SwiftUI
import Charts

/// Android's Wellbeing.kt analytics and TrendsScreen: every insight comes from the person's own logged days, carries
/// the number of days behind it, and only shows when there's enough data and a real difference (3+ days on each side,
/// 0.4+ points on the 1–5 scale). No invented statistics.
enum WellMetric: CaseIterable, Identifiable {
    case mood, energy, clarity, peace
    var id: Self { self }
    var label: String { switch self { case .mood: "Mood"; case .energy: "Energy"; case .clarity: "Clarity"; case .peace: "Peace" } }
    var emoji: String { switch self { case .mood: "😊"; case .energy: "⚡"; case .clarity: "🧠"; case .peace: "🕊️" } }
    var color: Color { switch self { case .mood: Color(hex: 0xF59E0B); case .energy: Color(hex: 0x10B981); case .clarity: Color(hex: 0x3B82F6); case .peace: Color(hex: 0xA78BFA) } }
    func value(_ c: CheckIn) -> Int { switch self { case .mood: c.mood; case .energy: c.energy; case .clarity: c.clarity; case .peace: c.peace } }
}

struct TrendInsight: Identifiable {
    let id = UUID()
    let text: String
    let metric: WellMetric
    let delta: Double
}

/// What happened each day, from the rest of the app.
struct DaySignals { var prayed = false; var stepGoalMet: Bool?; var workedOut = false; var listened = false }

enum Trends {
    static func fmt1(_ d: Double) -> String { String(format: "%.1f", (d * 10).rounded() / 10) }
    static func wellbeing(_ c: CheckIn) -> Double { Double(c.mood + c.energy + c.clarity + c.peace) / 4 }
    private static func avg(_ l: [CheckIn], _ m: WellMetric) -> Double { l.isEmpty ? 0 : Double(l.map(m.value).reduce(0, +)) / Double(l.count) }

    static func shift(_ day: String, _ n: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        guard let d = f.date(from: day) else { return day }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        return f.string(from: cal.date(byAdding: .day, value: n, to: d) ?? d)
    }
    static func lastDates(_ end: String, _ count: Int) -> [String] { (0..<count).reversed().map { shift(end, -$0) } }

    /// Android's computeTrendInsights.
    static func insights(_ checkIns: [CheckIn], _ signals: [String: DaySignals], minPerGroup: Int = 3, minDelta: Double = 0.4) -> [TrendInsight] {
        guard checkIns.count >= minPerGroup * 2 else { return [] }
        var found: [TrendInsight] = []
        func compare(_ withLabel: String, _ withoutLabel: String, _ metrics: [WellMetric], _ pred: (CheckIn) -> Bool?) {
            let grouped = checkIns.compactMap { c in pred(c).map { ($0, c) } }
            let yes = grouped.filter(\.0).map(\.1), no = grouped.filter { !$0.0 }.map(\.1)
            guard yes.count >= minPerGroup, no.count >= minPerGroup else { return }
            for m in metrics {
                let a = avg(yes, m), b = avg(no, m), d = a - b
                guard abs(d) >= minDelta else { continue }
                let text = tr("{e} Your {m} averages {a} on days {w} vs {b} on days {wo} — {d} points {dir} ({n1} vs {n2} days).")
                    .replacingOccurrences(of: "{e}", with: m.emoji).replacingOccurrences(of: "{m}", with: tr(m.label).lowercased())
                    .replacingOccurrences(of: "{a}", with: fmt1(a)).replacingOccurrences(of: "{w}", with: tr(withLabel))
                    .replacingOccurrences(of: "{b}", with: fmt1(b)).replacingOccurrences(of: "{wo}", with: tr(withoutLabel))
                    .replacingOccurrences(of: "{d}", with: fmt1(abs(d))).replacingOccurrences(of: "{dir}", with: tr(d > 0 ? "higher" : "lower"))
                    .replacingOccurrences(of: "{n1}", with: "\(yes.count)").replacingOccurrences(of: "{n2}", with: "\(no.count)")
                found.append(TrendInsight(text: text, metric: m, delta: d))
            }
        }
        compare("you prayed", "you didn't", [.peace, .mood]) { signals[$0.date]?.prayed }
        compare("you hit your step goal", "you didn't", [.energy, .mood]) { signals[$0.date]?.stepGoalMet }
        compare("you worked out", "you rested", [.energy, .mood, .clarity]) { signals[$0.date]?.workedOut }
        compare("you used Sanctuary", "you didn't", [.peace]) { signals[$0.date]?.listened }
        compare("you slept well", "you slept poorly", [.energy, .clarity, .mood]) { c in c.sleep == "great" ? true : c.sleep == "poor" ? false : nil }
        return found.sorted { abs($0.delta) > abs($1.delta) }
    }

    /// Android's HealthHelper.extraPatterns: a walk before noon and the next night's sleep, a workout and next-day energy.
    static func extraPatterns(_ checkIns: [CheckIn], morningWalkDays: Set<String>, stepDays: Set<String>, workoutDays: Set<String>) -> [TrendInsight] {
        var out: [TrendInsight] = []
        func score(_ s: String) -> Double? { s == "great" ? 3 : s == "okay" ? 2 : s == "poor" ? 1 : nil }
        let sleepPairs: [(Bool, Double)] = checkIns.compactMap { c in
            guard let s = score(c.sleep) else { return nil }
            let prev = shift(c.date, -1)
            guard stepDays.contains(prev) || morningWalkDays.contains(prev) else { return nil }
            return (morningWalkDays.contains(prev), s)
        }
        let yes = sleepPairs.filter(\.0).map(\.1), no = sleepPairs.filter { !$0.0 }.map(\.1)
        if yes.count >= 3, no.count >= 3 {
            let a = yes.reduce(0, +) / Double(yes.count), b = no.reduce(0, +) / Double(no.count)
            let gy = yes.filter { $0 >= 3 }.count * 100 / yes.count, gn = no.filter { $0 >= 3 }.count * 100 / no.count
            if abs(a - b) >= 0.35 {
                out.append(TrendInsight(text: a > b
                    ? tr("🌙 You rate your sleep \"great\" {0}% of the time after a walk before noon, and {1}% after days without one ({2} vs {3} nights).")
                        .replacingOccurrences(of: "{0}", with: "\(gy)").replacingOccurrences(of: "{1}", with: "\(gn)")
                        .replacingOccurrences(of: "{2}", with: "\(yes.count)").replacingOccurrences(of: "{3}", with: "\(no.count)")
                    : tr("🌙 Your sleep has been rated a little lower after morning walks ({0}% \"great\" vs {1}%). Try walking later in the day and see.")
                        .replacingOccurrences(of: "{0}", with: "\(gy)").replacingOccurrences(of: "{1}", with: "\(gn)"),
                    metric: .energy, delta: a - b))
            }
        }
        let energyPairs: [(Bool, Double)] = checkIns.compactMap { c in
            let prev = shift(c.date, -1)
            guard (1...5).contains(c.energy), stepDays.contains(prev) else { return nil }
            return (workoutDays.contains(prev), Double(c.energy))
        }
        let ey = energyPairs.filter(\.0).map(\.1), en = energyPairs.filter { !$0.0 }.map(\.1)
        if ey.count >= 3, en.count >= 3 {
            let a = ey.reduce(0, +) / Double(ey.count), b = en.reduce(0, +) / Double(en.count)
            if abs(a - b) >= 0.4 {
                out.append(TrendInsight(text: tr("⚡ The day after a workout your energy averages {0}, vs {1} otherwise ({2} vs {3} days).")
                    .replacingOccurrences(of: "{0}", with: fmt1(a)).replacingOccurrences(of: "{1}", with: fmt1(b))
                    .replacingOccurrences(of: "{2}", with: "\(ey.count)").replacingOccurrences(of: "{3}", with: "\(en.count)"), metric: .energy, delta: a - b))
            }
        }
        return out
    }

    /// Everything the trends and the health helper compare against, for the given days.
    @MainActor static func signals(store: AppStore, steps: [String: Int], dates: [String]) -> [String: DaySignals] {
        let log = ActivityLog.shared.days
        let workouts = Set(CoachLog.shared.days.keys).union(log.filter { $0.value.contains(ActivityLog.Event.workoutSet.rawValue) }.keys)
        let listened = Set(log.filter { $0.value.contains(ActivityLog.Event.prayerAudio.rawValue) }.keys)
        var out: [String: DaySignals] = [:]
        for d in dates {
            out[d] = DaySignals(prayed: store.prayerDays.contains(d), stepGoalMet: steps[d].map { $0 >= store.stepGoal },
                                workedOut: workouts.contains(d), listened: listened.contains(d))
        }
        return out
    }

    /// Both kinds of findings, biggest difference first (Android's HealthToday.patterns).
    @MainActor static func patterns(store: AppStore, steps: [String: Int]) -> [TrendInsight] {
        let checkIns = CheckInStore.shared.all
        let sig = signals(store: store, steps: steps, dates: checkIns.map(\.date))
        let morning = Set(WalkStore.shared.walks.filter { Calendar.current.component(.hour, from: $0.start) < 12 && $0.activeSec >= 600 }.map { AppStore.dayKey($0.start) })
        let workouts = Set(CoachLog.shared.days.keys)
        return (insights(checkIns, sig) + extraPatterns(checkIns, morningWalkDays: morning, stepDays: Set(steps.filter { $0.value > 0 }.keys), workoutDays: workouts))
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    static func streak(_ checkIns: [CheckIn], today: String) -> Int {
        let dates = Set(checkIns.map(\.date))
        var d = dates.contains(today) ? today : shift(today, -1), n = 0
        while dates.contains(d) { n += 1; d = shift(d, -1) }
        return n
    }

    static func wellbeingColor(_ v: Double) -> Color {
        let t = min(1, max(0, (v - 1) / 4))
        func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ f: Double) -> Color {
            Color(red: (a.0 + (b.0 - a.0) * f) / 255, green: (a.1 + (b.1 - a.1) * f) / 255, blue: (a.2 + (b.2 - a.2) * f) / 255)
        }
        let low = (124.0, 58.0, 237.0), mid = (245.0, 158.0, 11.0), high = (16.0, 185.0, 129.0)
        return t < 0.5 ? mix(low, mid, t * 2) : mix(mid, high, (t - 0.5) * 2)
    }
}

struct TrendsView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var checkIns = CheckInStore.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var range = 7
    @State private var steps: [String: Int] = [:]
    @State private var enabled = Set(WellMetric.allCases)
    @State private var paywall = false
    @State private var checkIn = false
    @State private var insights: [TrendInsight] = []

    private var premium: Bool { account.canUse(.trends) }

    var body: some View {
        let today = AppStore.dayKey()
        let dates = Trends.lastDates(today, range)
        let inRange = checkIns.all.filter { Set(dates).contains($0.date) }
        let prevDates = Set(Trends.lastDates(Trends.shift(today, -range), range))
        let prev = checkIns.all.filter { prevDates.contains($0.date) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    T("Life & Health Trends").font(.hs(24, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    T("How your body, mind and faith move together").font(.hs(13)).foregroundStyle(HS.textSecondary)
                }
                HStack(spacing: 8) {
                    ForEach([7, 30, 90], id: \.self) { r in
                        let locked = r > 7 && !premium
                        Button { if locked { paywall = true } else { range = r } } label: {
                            D("\(r) " + tr("days") + (locked ? " 👑" : "")).font(.hs(13, .semibold))
                                .foregroundStyle(range == r ? HS.onGold : HS.text)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(Capsule().fill(range == r ? HS.goldButton : HS.overlay(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if checkIns.all.isEmpty {
                    card {
                        T("Your trends start with one check-in").font(.hs(16, .bold)).foregroundStyle(HS.text)
                        T("Log mood, energy, clarity and peace each day. After a few days you'll see charts, your best days, and how prayer, sleep and movement actually affect you.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        GoldButton(title: "Check in now") { checkIn = true }
                    }
                } else {
                    kpis(inRange: inRange, prev: prev, range: range, today: today)
                    card {
                        D(tr("This {0} vs the one before").replacingOccurrences(of: "{0}", with: tr(range == 7 ? "week" : range == 30 ? "month" : "quarter")))
                            .font(.hs(15, .bold)).foregroundStyle(HS.text)
                        HStack(spacing: 8) {
                            ForEach(WellMetric.allCases) { m in
                                let now = inRange.isEmpty ? nil : Double(inRange.map(m.value).reduce(0, +)) / Double(inRange.count)
                                let before = prev.isEmpty ? nil : Double(prev.map(m.value).reduce(0, +)) / Double(prev.count)
                                let d = now.flatMap { n in before.map { n - $0 } }
                                VStack(spacing: 2) {
                                    Text(m.emoji).font(.system(size: 18))
                                    Text(now.map(Trends.fmt1) ?? "—").font(.hs(16, .bold)).foregroundStyle(HS.text)
                                    D(d == nil ? tr(m.label) : abs(d!) < 0.05 ? "= " + tr(m.label) : (d! > 0 ? "▲ " : "▼ ") + Trends.fmt1(abs(d!)))
                                        .font(.hs(11, .semibold)).foregroundStyle(d == nil || abs(d!) < 0.05 ? HS.textMuted : d! > 0 ? Color(hex: 0x10B981) : Color(hex: 0xFB7185))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(m.color.opacity(0.12)))
                            }
                        }
                    }
                    card {
                        T("Daily ratings").font(.hs(15, .bold)).foregroundStyle(HS.text)
                        HStack(spacing: 6) {
                            ForEach(WellMetric.allCases) { m in
                                let on = enabled.contains(m)
                                Button { if on && enabled.count > 1 { enabled.remove(m) } else { enabled.insert(m) } } label: {
                                    HStack(spacing: 4) {
                                        Circle().fill(on ? m.color : HS.overlay(0.2)).frame(width: 8, height: 8)
                                        T(m.label).font(.hs(11)).foregroundStyle(on ? HS.text : HS.textMuted)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(Capsule().fill(on ? m.color.opacity(0.2) : HS.overlay(0.04)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Chart {
                            ForEach(WellMetric.allCases.filter { enabled.contains($0) }) { m in
                                ForEach(inRange, id: \.date) { c in
                                    LineMark(x: .value("Day", c.date), y: .value(m.label, m.value(c)), series: .value("Metric", m.label))
                                        .foregroundStyle(m.color)
                                    PointMark(x: .value("Day", c.date), y: .value(m.label, m.value(c))).foregroundStyle(m.color).symbolSize(16)
                                }
                            }
                        }
                        .chartYScale(domain: 1...5)
                        .chartXAxis(.hidden)
                        .frame(height: 170)
                        .accessibilityLabel(tr("Daily ratings chart"))
                    }
                    card {
                        T("Your last 5 weeks").font(.hs(15, .bold)).foregroundStyle(HS.text)
                        T("Each square is one day's overall wellbeing.").font(.hs(11)).foregroundStyle(HS.textMuted)
                        let days = Trends.lastDates(today, 35)
                        let byDate = Dictionary(checkIns.all.map { ($0.date, $0) }, uniquingKeysWith: { $1 })
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                            ForEach(days, id: \.self) { d in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(byDate[d].map { Trends.wellbeingColor(Trends.wellbeing($0)) } ?? HS.overlay(0.06))
                                    .frame(height: 22)
                                    .accessibilityLabel(byDate[d].map { "\(d): " + Trends.fmt1(Trends.wellbeing($0)) } ?? "\(d): " + tr("no check-in"))
                            }
                        }
                    }
                    if dates.contains(where: { (steps[$0] ?? 0) > 0 }) {
                        card {
                            T("Steps & energy").font(.hs(15, .bold)).foregroundStyle(HS.text)
                            T("Bars are steps; the line is your energy rating.").font(.hs(11)).foregroundStyle(HS.textMuted)
                            let maxSteps = Double(max(1, dates.compactMap { steps[$0] }.max() ?? 1))
                            Chart {
                                ForEach(dates, id: \.self) { d in
                                    BarMark(x: .value("Day", d), y: .value("Steps", Double(steps[d] ?? 0) / maxSteps * 5)).foregroundStyle(Color(hex: 0x56B892).opacity(0.5))
                                }
                                ForEach(inRange, id: \.date) { c in
                                    LineMark(x: .value("Day", c.date), y: .value("Energy", c.energy)).foregroundStyle(WellMetric.energy.color)
                                }
                            }
                            .chartYScale(domain: 0...5)
                            .chartXAxis(.hidden).chartYAxis(.hidden)
                            .frame(height: 130)
                        }
                    }
                    card {
                        T("What your data says").font(.hs(15, .bold)).foregroundStyle(HS.text)
                        if insights.isEmpty {
                            D(tr("Insights appear once there are at least 3 days with and 3 days without a habit (like prayer, a workout, or good sleep) and a real difference between them.")
                              + " " + tr("{0} check-ins so far.").replacingOccurrences(of: "{0}", with: "\(checkIns.all.count)"))
                                .font(.hs(12)).foregroundStyle(HS.textSecondary)
                        } else {
                            ForEach(premium ? insights : Array(insights.prefix(1))) { i in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(i.metric.color).frame(width: 8, height: 8).padding(.top, 5)
                                    D(i.text).font(.hs(13)).foregroundStyle(HS.text)
                                }
                            }
                            if !premium && insights.count > 1 {
                                Button { paywall = true } label: {
                                    D("👑 " + tr("{0} more insights with a plan →").replacingOccurrences(of: "{0}", with: "\(insights.count - 1)"))
                                        .font(.hs(13, .bold)).foregroundStyle(HS.gold).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(HS.goldButton.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                            }
                            T("Based only on your own logged days. Patterns, not proof — but worth noticing.").font(.hs(10)).foregroundStyle(HS.textMuted)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Trends"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $paywall) { PlansView(feature: .trends) }
        .sheet(isPresented: $checkIn) { CheckInSheet() }
        .task {
            steps = await StepsModel.shared.stepsPerDay(days: 90)
            insights = Trends.patterns(store: store, steps: steps)
        }
        .onChange(of: checkIns.all.count) { insights = Trends.patterns(store: store, steps: steps) }
    }

    private func kpis(inRange: [CheckIn], prev: [CheckIn], range: Int, today: String) -> some View {
        let now = inRange.isEmpty ? nil : inRange.map(Trends.wellbeing).reduce(0, +) / Double(inRange.count)
        let before = prev.isEmpty ? nil : prev.map(Trends.wellbeing).reduce(0, +) / Double(prev.count)
        return HStack(spacing: 10) {
            kpi("🔥", "\(Trends.streak(checkIns.all, today: today))", "day streak", nil)
            kpi("📅", "\(inRange.count)/\(range)", "days logged", nil)
            kpi("✨", now.map(Trends.fmt1) ?? "—", "wellbeing", now.flatMap { n in before.map { n - $0 } })
        }
    }

    private func kpi(_ emoji: String, _ value: String, _ label: String, _ delta: Double?) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 18))
            Text(value).font(.hs(18, .bold)).foregroundStyle(HS.text)
            T(label).font(.hs(11)).foregroundStyle(HS.textMuted)
            if let delta, abs(delta) >= 0.05 {
                D((delta > 0 ? "▲ " : "▼ ") + Trends.fmt1(abs(delta))).font(.hs(10, .semibold)).foregroundStyle(delta > 0 ? Color(hex: 0x10B981) : Color(hex: 0xFB7185))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
    }
}
