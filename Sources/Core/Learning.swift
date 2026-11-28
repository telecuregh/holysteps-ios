import Foundation
import UserNotifications

// Android's Rhythms.kt and WholeYou.kt, on the iPhone: what HolySteps learns about a person's days, on this phone only,
// so Home can put what they usually do at the top when they usually do it and show what their own days say helps.
//
// Same rules as Android:
//  - A routine is something done on at least 6 of the last 28 days around the same time (Lally et al. 2010: time of
//    day is the most common habit cue). Times wrap at midnight, so the usual time and its spread are circular statistics.
//  - Adaptive screens help only when they're predictable (Gajos et al. 2008), so nothing on Home moves: "For you" is its
//    own small block, at most three shortcuts.
//  - A reminder is offered at most once a day, never again once declined, and only when the person says yes.
//  - A pattern ("your mood is higher on days you prayed") needs 5+ days on each side, a difference big enough to
//    matter, and the same direction in the earlier and later half of their history. It never claims cause or diagnoses.
// Nothing here leaves the phone. Learning can be turned off and everything erased.

enum RhythmsLogic {
    static let dayMin = 1440
    static let windowDays = 28
    static let minDays = 6
    static let maxSpread = 90

    struct Event: Codable, Equatable { let key: String; let ms: Int64 }

    enum Pattern: String, Codable {
        case everyDay, weekdays, weekends
        var label: String { switch self { case .everyDay: "most days"; case .weekdays: "on weekdays"; case .weekends: "on weekends" } }
    }

    struct Routine: Equatable {
        let key: String, minute: Int, spreadMin: Int, days: Int, pattern: Pattern, consistency: Double
        var id: String { "\(key)@\(minute / 60)" }
    }

    private static func rad(_ m: Int) -> Double { Double(m) * 2 * .pi / Double(dayMin) }

    static func circularMean(_ mins: [Int]) -> (Int, Double) {
        guard !mins.isEmpty else { return (0, 0) }
        let s = mins.reduce(0.0) { $0 + sin(rad($1)) } / Double(mins.count)
        let c = mins.reduce(0.0) { $0 + cos(rad($1)) } / Double(mins.count)
        let r = (s * s + c * c).squareRoot()
        let m = (Int((atan2(s, c) * Double(dayMin) / (2 * .pi)).rounded()) + dayMin) % dayMin
        return (m, r)
    }

    static func spreadMin(_ r: Double) -> Int {
        r >= 0.999999 ? 0 : Int(((-2 * log(max(r, 1e-9))).squareRoot() * Double(dayMin) / (2 * .pi)).rounded())
    }

    static func circDist(_ a: Int, _ b: Int) -> Int { let d = abs(a - b) % dayMin; return min(d, dayMin - d) }

    private static let cal = Calendar.current
    static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }
    static func dayKey(_ ms: Int64) -> String { AppStore.dayKey(date(ms)) }
    static func minuteOf(_ ms: Int64) -> Int { let c = cal.dateComponents([.hour, .minute], from: date(ms)); return (c.hour ?? 0) * 60 + (c.minute ?? 0) }
    static func weekend(_ d: Date) -> Bool { cal.isDateInWeekend(d) }

    /// The routines in `events`: for each kind, the times of day it clusters around (Android's RhythmsLogic.routines).
    static func routines(_ events: [Event], now: Date = Date()) -> [Routine] {
        let today = cal.startOfDay(for: now)
        guard let from = cal.date(byAdding: .day, value: -(windowDays - 1), to: today) else { return [] }
        var out: [Routine] = []
        for (key, list) in Dictionary(grouping: events, by: \.key) {
            let recent = list.map { (day: cal.startOfDay(for: date($0.ms)), min: minuteOf($0.ms)) }.filter { $0.day >= from && $0.day <= today }
            guard Set(recent.map { $0.day }).count >= minDays else { continue }
            let perHour = (0..<24).map { h in Set(recent.filter { $0.min / 60 == h }.map { $0.day }).count }
            let smooth = (0..<24).map { h in Double(perHour[(h + 23) % 24]) * 0.5 + Double(perHour[h]) + Double(perHour[(h + 1) % 24]) * 0.5 }
            let peaks = (0..<24).filter { h in smooth[h] > 0 && smooth[h] >= smooth[(h + 23) % 24] && smooth[h] >= smooth[(h + 1) % 24] }
                .sorted { smooth[$0] > smooth[$1] }
            var found: [Routine] = []
            for h in peaks {
                let center = h * 60 + 30
                if found.contains(where: { circDist($0.minute, center) < 180 }) { continue }
                let nearest = Dictionary(grouping: recent.filter { circDist($0.min, center) <= 120 }, by: { $0.day })
                    .compactMap { $0.value.min { circDist($0.min, center) < circDist($1.min, center) } }
                guard nearest.count >= minDays else { continue }
                let (mean, r) = circularMean(nearest.map { $0.min })
                let sd = spreadMin(r)
                guard sd <= maxSpread else { continue }
                // 20 weekdays and 8 weekend days in the window: compare rates, not counts.
                let wkd = Double(nearest.filter { !weekend($0.day) }.count) / 20, wke = Double(nearest.filter { weekend($0.day) }.count) / 8
                let pattern: Pattern = wke < 0.2 * wkd ? .weekdays : (wkd < 0.2 * wke ? .weekends : .everyDay)
                found.append(Routine(key: key, minute: mean, spreadMin: sd, days: nearest.count, pattern: pattern, consistency: r))
            }
            out += found
        }
        return out.sorted { $0.minute < $1.minute }
    }

    static func applies(_ p: Pattern, _ d: Date) -> Bool {
        switch p { case .everyDay: true; case .weekdays: !weekend(d); case .weekends: weekend(d) }
    }

    static func doneToday(_ r: Routine, _ events: [Event], now: Date = Date()) -> Bool {
        let today = AppStore.dayKey(now)
        return events.contains { $0.key == r.key && dayKey($0.ms) == today && circDist(minuteOf($0.ms), r.minute) <= 180 }
    }

    /// Due within the next 30 minutes or started in the last hour (or its own spread), applies today, not done yet.
    static func now(_ rs: [Routine], _ events: [Event], hidden: Set<String>, now: Date = Date(), max: Int = 3) -> [Routine] {
        let m = minuteOf(Int64(now.timeIntervalSince1970 * 1000))
        return rs.filter { r in
            guard !hidden.contains(r.id), applies(r.pattern, now), !doneToday(r, events, now: now) else { return false }
            let ahead = ((r.minute - m) % dayMin + dayMin) % dayMin
            return ahead <= 30 || dayMin - ahead <= Swift.max(60, r.spreadMin)
        }
        .sorted { $0.consistency * Double($0.days) > $1.consistency * Double($1.days) }
        .prefix(max).map { $0 }
    }

    static func daysLearned(_ events: [Event]) -> Int { Set(events.map { dayKey($0.ms) }).count }

    static func clock(_ min: Int) -> String {
        let h = (min / 60) % 24, m = min % 60
        return "\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", m)) \(h < 12 ? "AM" : "PM")"
    }
}

/// What gets learned, the settings, and the reminders. Stored in UserDefaults on this phone only.
final class Learning: ObservableObject {
    static let shared = Learning()

    struct Label { let title: String; let symbol: String }
    struct Settings: Codable {
        var on = true
        var hidden: Set<String> = []
        var declined: Set<String> = []
        var reminders: Set<String> = []
        var lastOfferDate = ""
    }

    @Published private(set) var events: [RhythmsLogic.Event] = []
    @Published private(set) var settings = Settings()

    private let keepDays = 120, maxEvents = 6000
    private let defaults = UserDefaults.standard

    private init() {
        if let d = defaults.data(forKey: "learnEvents"), let e = try? JSONDecoder().decode([RhythmsLogic.Event].self, from: d) { events = e }
        if let d = defaults.data(forKey: "learnSettings"), let s = try? JSONDecoder().decode(Settings.self, from: d) { settings = s }
    }

    private func saveEvents() {
        let cut = Int64((Date().timeIntervalSince1970 - Double(keepDays) * 86_400) * 1000)
        events = Array(events.filter { $0.ms >= cut }.sorted { $0.ms < $1.ms }.suffix(maxEvents))
        if let d = try? JSONEncoder().encode(events) { defaults.set(d, forKey: "learnEvents") }
    }
    private func saveSettings() { if let d = try? JSONEncoder().encode(settings) { defaults.set(d, forKey: "learnSettings") } }

    /// The parts of the app worth learning: everything in search, plus walks.
    static func labels(gender: String) -> [String: Label] {
        var m: [String: Label] = [:]
        for f in AppFeature.all(gender: gender) where m["open:\(f.title)"] == nil { m["open:\(f.title)"] = Label(title: f.title, symbol: f.symbol) }
        m["move:walk"] = Label(title: "Walk", symbol: "figure.walk")
        return m
    }

    /// Something done or opened. The same thing again within 15 minutes is the same visit.
    func record(_ key: String, at date: Date = Date()) {
        guard settings.on else { return }
        let ms = Int64(date.timeIntervalSince1970 * 1000)
        if events.contains(where: { $0.key == key && abs($0.ms - ms) < 15 * 60_000 }) { return }
        events.append(.init(key: key, ms: ms))
        saveEvents()
    }

    /// A screen opened from Faith, search or Home, by its name in search.
    func recordOpen(_ title: String) { record("open:\(title)") }

    /// What ActivityLog counts, as the screens people use to do it.
    func record(_ e: ActivityLog.Event) {
        switch e {
        case .sermon: recordOpen("This week's sermon")
        case .journal: recordOpen("Faith Journal")
        case .quiz: recordOpen("Bible Quiz")
        case .tracker: recordOpen("Mood check-in")
        case .sleepStory: recordOpen("Sleep stories")
        case .prayerAudio: recordOpen("Prayer Log")
        default: break
        }
    }

    /// Everything to learn from: what was opened or done, plus walks of 10 minutes or more (read where they live).
    func allEvents() -> [RhythmsLogic.Event] {
        events + WalkStore.shared.walks.filter { $0.activeSec >= 600 }.map { .init(key: "move:walk", ms: Int64($0.start.timeIntervalSince1970 * 1000)) }
    }

    struct Analysis {
        let on: Bool
        let daysLearned: Int
        let routines: [RhythmsLogic.Routine]
        let now: [RhythmsLogic.Routine]
        let findings: [WholeYou.Finding]
        let offer: RhythmsLogic.Routine?
    }

    @MainActor func analyze(store: AppStore) -> Analysis {
        let ev = allEvents()
        let labels = Learning.labels(gender: store.gender)
        let rs = RhythmsLogic.routines(ev.filter { labels[$0.key] != nil }).filter { !settings.hidden.contains($0.id) }
        let today = AppStore.dayKey()
        let offer = settings.on && settings.lastOfferDate != today
            ? rs.filter { $0.days >= 10 && !settings.declined.contains($0.id) && !settings.reminders.contains($0.id) }
                .max { $0.consistency * Double($0.days) < $1.consistency * Double($1.days) }
            : nil
        return Analysis(on: settings.on, daysLearned: RhythmsLogic.daysLearned(ev), routines: rs,
                        now: settings.on ? RhythmsLogic.now(rs, ev, hidden: settings.hidden) : [],
                        findings: settings.on ? WholeYou.findings(WholeYou.rows(store: store)).filter { $0.lever } : [],
                        offer: offer)
    }

    func decline(_ id: String) { settings.declined.insert(id); settings.lastOfferDate = AppStore.dayKey(); saveSettings(); objectWillChange.send() }
    func hide(_ id: String) { settings.hidden.insert(id); saveSettings(); cancel(id) }
    func setOn(_ on: Bool) { settings.on = on; saveSettings() }
    func eraseAll() {
        events = []; defaults.removeObject(forKey: "learnEvents")
        let ids = settings.reminders
        ids.forEach { cancel($0) }
        settings = Settings(); saveSettings()
    }

    /// The person said yes: a gentle local notification at that time on the days it applies.
    func remind(_ r: RhythmsLogic.Routine, title: String) {
        settings.reminders.insert(r.id); settings.lastOfferDate = AppStore.dayKey(); saveSettings()
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let weekdays: [Int] = switch r.pattern { case .everyDay: [0]; case .weekdays: [2, 3, 4, 5, 6]; case .weekends: [1, 7] }
            for wd in weekdays {
                let content = UNMutableNotificationContent()
                content.title = tr(title)
                content.body = tr("You usually do this about now.")
                var dc = DateComponents(); dc.hour = r.minute / 60; dc.minute = r.minute % 60
                if wd > 0 { dc.weekday = wd }
                c.add(UNNotificationRequest(identifier: "rhythm.\(r.id).\(wd)", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
            }
        }
        objectWillChange.send()
    }

    private func cancel(_ id: String) {
        settings.reminders.remove(id); saveSettings()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (0...7).map { "rhythm.\(id).\($0)" })
    }
}

/// Android's WholeYou: one row per day from what the person logs across the app, and tested questions that join
/// those areas up ("what goes with my better days?"). Never claims cause, never diagnoses.
enum WholeYou {
    struct Row {
        let date: String
        var steps: Int? = nil
        var morningWalk = false
        var workout = false
        var prayed = false
        var calm = false
        var journaled = false
        var mood: Int? = nil, energy: Int? = nil, peace: Int? = nil
        var sleepRated: Int? = nil
        var sleepMin: Int? = nil
        var phase: CyclePhase? = nil
        var premenstrual = false
        var sleptWell: Bool? { sleepMin.map { $0 >= 420 } ?? sleepRated.flatMap { $0 == 2 ? nil : $0 == 3 } }
    }

    enum Confidence { case strong, clear; var label: String { self == .strong ? "Strong pattern" : "Clear pattern" } }

    struct Finding: Identifiable {
        let id: String, emoji: String, title: String, detail: String, evidence: String
        let confidence: Confidence
        let suggestion: String?
        let lever: Bool
        let score: Double
    }

    /// Steps and watch sleep only come 7 days at a time from Health, so they're kept here for 120 days.
    @MainActor static func keepHistory() {
        let d = UserDefaults.standard, cut = AppStore.dayKey(Date().addingTimeInterval(-120 * 86_400))
        var steps = d.dictionary(forKey: "wyStepHistory") as? [String: Int] ?? [:]
        var sleep = d.dictionary(forKey: "wySleepHistory") as? [String: Int] ?? [:]
        for (k, v) in StepsModel.shared.stepsByDay where v > 0 && k != AppStore.dayKey() { steps[k] = v }
        for (k, v) in StepsModel.shared.sleepByDay where (60...960).contains(v) { sleep[k] = v }
        d.set(steps.filter { $0.key >= cut }, forKey: "wyStepHistory")
        d.set(sleep.filter { $0.key >= cut }, forKey: "wySleepHistory")
    }

    @MainActor static func rows(store: AppStore, days: Int = 90) -> [Row] {
        keepHistory()
        let d = UserDefaults.standard
        let steps = d.dictionary(forKey: "wyStepHistory") as? [String: Int] ?? [:]
        let sleep = d.dictionary(forKey: "wySleepHistory") as? [String: Int] ?? [:]
        let cal = Calendar.current
        let morning = Set(WalkStore.shared.walks.filter { cal.component(.hour, from: $0.start) < 12 && $0.activeSec >= 600 }.map { AppStore.dayKey($0.start) })
        let workouts = Set(CoachLog.shared.days.keys)
        let log = ActivityLog.shared
        let journal = Set(store.journal.map { AppStore.dayKey($0.created) })
        let prayed = store.prayerDays
        let checks = Dictionary(CheckInStore.shared.all.map { ($0.date, $0) }, uniquingKeysWith: { _, b in b })
        let starts = store.periodStarts.sorted()
        let tracksCycle = store.gender != "male" && !starts.isEmpty
        let today = Date()
        return (0..<days).reversed().compactMap { back -> Row? in
            guard let day = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
            let k = AppStore.dayKey(day)
            let c = checks[k]
            var r = Row(date: k)
            r.steps = steps[k]
            r.morningWalk = morning.contains(k)
            r.workout = workouts.contains(k)
            r.prayed = prayed.contains(k)
            r.calm = log.did(.prayerAudio, on: k) || log.did(.sleepStory, on: k)
            r.journaled = journal.contains(k)
            r.mood = c.map(\.mood).flatMap { (1...5).contains($0) ? $0 : nil }
            r.energy = c.map(\.energy).flatMap { (1...5).contains($0) ? $0 : nil }
            r.peace = c.map(\.peace).flatMap { (1...5).contains($0) ? $0 : nil }
            r.sleepRated = switch c?.sleep ?? "" { case "great": 3; case "okay": 2; case "poor": 1; default: nil }
            r.sleepMin = sleep[k]
            if tracksCycle, let start = starts.last(where: { cal.startOfDay(for: $0) <= cal.startOfDay(for: day) }) {
                let n = (cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: day)).day ?? 0) + 1
                if n <= store.cycleLength + 10 {
                    r.phase = CyclePhase.forDay(n, periodLength: store.periodLength, cycleLength: store.cycleLength)
                    // Android's CareSignals.isPremenstrual: the last five days before the next period.
                    r.premenstrual = n > store.cycleLength - 5 && n <= store.cycleLength
                }
            }
            return r
        }
    }

    private enum Kind { case scale, minutes, steps }
    private struct Outcome { let label: String, kind: Kind, higherIsBetter: Bool, area: String, get: (Row) -> Double? }
    private struct Factor { let with: String, without: String, lever: Bool, tip: String?, get: (Row) -> Bool? }
    private struct Q { let id: String, factor: Factor, lag: Int, outcome: Outcome }

    private static let mood = Outcome(label: "mood", kind: .scale, higherIsBetter: true, area: "Mood") { $0.mood.map { Double($0) } }
    private static let energy = Outcome(label: "energy", kind: .scale, higherIsBetter: true, area: "Energy") { $0.energy.map { Double($0) } }
    private static let peace = Outcome(label: "sense of peace", kind: .scale, higherIsBetter: true, area: "Faith") { $0.peace.map { Double($0) } }
    private static let sleepMin = Outcome(label: "sleep", kind: .minutes, higherIsBetter: true, area: "Sleep") { $0.sleepMin.map { Double($0) } }
    private static let sleepRated = Outcome(label: "sleep rating", kind: .scale, higherIsBetter: true, area: "Sleep") { $0.sleepRated.map { Double($0) } }
    private static let stepsOut = Outcome(label: "steps", kind: .steps, higherIsBetter: true, area: "Steps") { r -> Double? in
        guard let n = r.steps, n > 0 else { return nil }
        return Double(n)
    }

    private static func questions(_ rows: [Row]) -> [Q] {
        let s = rows.compactMap { $0.steps }.filter { $0 > 0 }.sorted()
        let hi = s.count >= 15 ? s[s.count * 2 / 3] : Int.max, lo = s.count >= 15 ? s[s.count / 3] : Int.min
        let activeGet: (Row) -> Bool? = { r in
            guard let n = r.steps else { return nil }
            if n >= hi { return true }
            if n <= lo { return false }
            return nil
        }
        let walkTip = "Add one extra walk on the days you usually move least."
        let active = Factor(with: "more active days", without: "less active days", lever: true, tip: walkTip, get: activeGet)
        let activePrev = Factor(with: "the day after a more active day", without: "the day after a less active day", lever: true, tip: walkTip, get: activeGet)
        let morning = Factor(with: "nights after a walk before noon", without: "nights after days without one", lever: true,
                             tip: "Try a walk before noon on two more days this week.") { $0.morningWalk }
        let workTip = "Keep two or three workouts a week, with rest days between."
        let workout = Factor(with: "the day after a workout", without: "the day after no workout", lever: true, tip: workTip) { $0.workout }
        let workoutSame = Factor(with: "workout days", without: "days without one", lever: true, tip: workTip) { $0.workout }
        let prayed = Factor(with: "days you prayed", without: "days you didn't", lever: true,
                            tip: "Keep a few minutes with God early in the day, before it fills up.") { $0.prayed }
        let calm = Factor(with: "days with a calm or prayer session", without: "days without one", lever: true,
                          tip: "Try a 10-minute calm session on a busy day this week.") { $0.calm }
        let journalNext = Factor(with: "the day after you journaled", without: "the day after you didn't", lever: true,
                                 tip: "Write a few lines on the evenings that feel heavy.") { $0.journaled }
        let slept = Factor(with: "days after a good night's sleep", without: "days after a short or poor night", lever: true,
                           tip: "Protect your bedtime: same time each night, screens down 30 minutes before.") { $0.sleptWell }
        let pre = Factor(with: "the days before your period", without: "the rest of your cycle", lever: false,
                         tip: "Plan lighter days and an earlier night for the days before your period.") { $0.phase == nil ? nil : $0.premenstrual }
        return [
            Q(id: "active_mood", factor: active, lag: 0, outcome: mood), Q(id: "active_energy_next", factor: activePrev, lag: 1, outcome: energy),
            Q(id: "active_sleep", factor: activePrev, lag: 1, outcome: sleepMin), Q(id: "active_sleep_rated", factor: activePrev, lag: 1, outcome: sleepRated),
            Q(id: "morning_sleep", factor: morning, lag: 1, outcome: sleepMin), Q(id: "morning_sleep_rated", factor: morning, lag: 1, outcome: sleepRated),
            Q(id: "workout_energy", factor: workout, lag: 1, outcome: energy), Q(id: "workout_mood", factor: workoutSame, lag: 0, outcome: mood),
            Q(id: "prayed_mood", factor: prayed, lag: 0, outcome: mood), Q(id: "prayed_peace", factor: prayed, lag: 0, outcome: peace),
            Q(id: "calm_mood", factor: calm, lag: 0, outcome: mood),
            Q(id: "journal_mood_next", factor: journalNext, lag: 1, outcome: mood),
            Q(id: "sleep_mood", factor: slept, lag: 0, outcome: mood), Q(id: "sleep_energy", factor: slept, lag: 0, outcome: energy),
            Q(id: "sleep_steps", factor: slept, lag: 0, outcome: stepsOut),
            Q(id: "pre_mood", factor: pre, lag: 0, outcome: mood), Q(id: "pre_energy", factor: pre, lag: 0, outcome: energy),
            Q(id: "pre_sleep", factor: pre, lag: 0, outcome: sleepRated),
        ]
    }

    private static func threshold(_ k: Kind) -> Double { switch k { case .scale: 0.5; case .minutes: 25; case .steps: 0.15 } }
    private static func avg(_ x: [Double]) -> Double { x.reduce(0, +) / Double(max(1, x.count)) }
    private static func effect(_ k: Kind, _ yes: [Double], _ no: [Double]) -> Double {
        let a = avg(yes), c = avg(no)
        return k == .steps ? (c <= 0 ? 0 : (a - c) / c) : a - c
    }

    static let minEach = 5

    static func findings(_ rows: [Row]) -> [Finding] {
        guard rows.count >= 14 else { return [] }
        let byDate = Dictionary(rows.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let cal = Calendar.current
        func shifted(_ key: String, _ by: Int) -> String? {
            let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
            guard let d = f.date(from: key), let s = cal.date(byAdding: .day, value: by, to: d) else { return nil }
            return AppStore.dayKey(s)
        }
        var out: [Finding] = []
        for q in questions(rows) {
            let pairs: [(String, Bool, Double)] = rows.compactMap { r in
                let src = q.lag == 0 ? r : shifted(r.date, -q.lag).flatMap { byDate[$0] }
                guard let src, let f = q.factor.get(src), let o = q.outcome.get(r) else { return nil }
                return (r.date, f, o)
            }
            let yes = pairs.filter { $0.1 }.map { $0.2 }, no = pairs.filter { !$0.1 }.map { $0.2 }
            guard yes.count >= minEach, no.count >= minEach else { continue }
            let k = q.outcome.kind, e = effect(k, yes, no), t = threshold(k)
            guard abs(e) >= t else { continue }
            // Both halves of their history must point the same way.
            let sorted = pairs.sorted { $0.0 < $1.0 }, mid = sorted[sorted.count / 2].0
            let halvesOk = [pairs.filter { $0.0 < mid }, pairs.filter { $0.0 >= mid }].allSatisfy { h in
                let y = h.filter { $0.1 }.map { $0.2 }, n = h.filter { !$0.1 }.map { $0.2 }
                guard y.count >= 2, n.count >= 2 else { return false }
                let he = effect(k, y, n)
                return he * e > 0 && abs(he) >= t * 0.4
            }
            guard halvesOk else { continue }
            let strong = yes.count >= 10 && no.count >= 10 && abs(e) >= t * 1.5
            let better = (e > 0) == q.outcome.higherIsBetter
            out.append(describe(q, yes, no, e, strong, better))
        }
        // The same thing said two ways (a watch number and a rating): keep the stronger one.
        return Dictionary(grouping: out) { $0.id.replacingOccurrences(of: "_rated", with: "") }
            .compactMap { $0.value.max { $0.score < $1.score } }
            .sorted { $0.score > $1.score }
    }

    private static func fmt(_ k: Kind, _ v: Double) -> String {
        switch k {
        case .scale: String(format: "%.1f", v)
        case .minutes: "\(Int(v) / 60)h \(String(format: "%02d", Int(v) % 60))m"
        case .steps: Int(v).formatted()
        }
    }

    private static func describe(_ q: Q, _ yes: [Double], _ no: [Double], _ e: Double, _ strong: Bool, _ better: Bool) -> Finding {
        let k = q.outcome.kind, a = fmt(k, avg(yes)), c = fmt(k, avg(no)), area = q.outcome.area
        let title = "\(area): \(e > 0 ? "higher" : "lower") on \(q.factor.with)"
        let detail = k == .steps ? "You average \(a) steps on \(q.factor.with), vs \(c) on \(q.factor.without)."
            : "Your \(q.outcome.label) averages \(a) on \(q.factor.with), vs \(c) on \(q.factor.without)."
        let emoji = switch area { case "Mood": "🙂"; case "Energy": "⚡"; case "Faith": "🕊️"; case "Sleep": "🌙"; case "Steps": "👣"; default: "🔎" }
        let tip: String? = (q.factor.lever && better) || (!q.factor.lever && !better) ? q.factor.tip : nil
        let size = abs(e) / threshold(k)
        return Finding(id: q.id, emoji: emoji, title: title, detail: detail,
                       evidence: "From \(yes.count) and \(no.count) of your days, and it held in both your earlier and later weeks.",
                       confidence: strong ? .strong : .clear, suggestion: tip, lever: q.factor.lever && better,
                       score: size * (strong ? 1.5 : 1) * Double(min(20, min(yes.count, no.count))) / 20 + (q.factor.lever && better ? 0.3 : 0))
    }
}
