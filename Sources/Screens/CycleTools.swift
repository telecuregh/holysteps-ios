import SwiftUI
import LocalAuthentication
import UIKit

// The Cycle tools that match the Android app: the Cycle lock and discreet icon, the mood scale and pregnancy-test log,
// pregnancy tools (kick counter, contraction timer, appointments), symptom-severity ratings, and a CSV export.
// Everything is kept on this phone (UserDefaults, protected by iOS Data Protection) and nothing is uploaded.
// None of it is a medical device or a diagnosis; the wording follows the same sources as Android
// (ACOG, CDC Hear Her, Count the Kicks, hospital 5-1-1 guidance, IAPMD / DRSP for PMDD).

// MARK: - Cycle lock


final class CycleLock: ObservableObject {
    static let shared = CycleLock()
    /// How long the Cycle screens stay open after the person leaves them.
    static let grace: TimeInterval = 120
    static let discreetIconName = "AppIconNotes"

    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "cycleLockOn"); if !enabled { unlockedAt = nil } } }
    @Published var discreetIcon: Bool = UIApplication.shared.alternateIconName == CycleLock.discreetIconName
    private var unlockedAt: Date?

    private init() { enabled = UserDefaults.standard.bool(forKey: "cycleLockOn") }

    var isUnlocked: Bool { if let t = unlockedAt { return Date().timeIntervalSince(t) < Self.grace }; return false }
    func markUnlocked() { unlockedAt = Date() }
    /// The grace period starts when the person leaves, not when they unlocked.
    func markLeft() { if unlockedAt != nil { unlockedAt = Date() } }

    /// Face ID, Touch ID or the passcode: the phone's own lock. HolySteps never stores a PIN.
    static var deviceSecure: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    func authenticate(_ done: @escaping (Bool, String) -> Void) {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { done(true, ""); return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: tr("Unlock your cycle")) { ok, e in
            DispatchQueue.main.async { done(ok, ok ? "" : (e?.localizedDescription ?? "")) }
        }
    }

    func setDiscreetIcon(_ on: Bool) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(on ? Self.discreetIconName : nil) { [weak self] err in
            DispatchQueue.main.async { if err == nil { self?.discreetIcon = on } }
        }
    }
}

/// Wraps the Cycle screens: with the lock on it asks for Face ID first, and covers the screen in the app switcher.
struct CycleLockGate<Content: View>: View {
    @ObservedObject private var lock = CycleLock.shared
    @Environment(\.scenePhase) private var phase
    @State private var open = false
    @State private var error = ""
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if !lock.enabled || open || lock.isUnlocked {
                content()
                    .overlay { if lock.enabled && phase != .active { privacyCover } }
                    .onAppear { if lock.enabled { open = true } }
            } else {
                lockScreen
            }
        }
        .onChange(of: phase) { _, p in
            guard lock.enabled else { return }
            if p == .background { lock.markLeft() }
            if p == .active && !lock.isUnlocked { open = false }
        }
        .onDisappear { if lock.enabled && open { lock.markLeft() } }
    }

    private var privacyCover: some View {
        ZStack { HSBackground(); Text("🔒").font(.system(size: 44)) }.ignoresSafeArea()
    }

    private var lockScreen: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 12) {
                Text("🔒").font(.system(size: 44))
                T("Your cycle is locked").font(.hs(20, .bold)).foregroundStyle(HS.text)
                T("Use Face ID, Touch ID or your passcode to open it.").font(.hs(14)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                if !error.isEmpty { D(error).font(.hs(12)).foregroundStyle(HS.textMuted) }
                GoldButton(title: tr("Unlock")) { unlock() }.padding(.top, 8)
            }.padding(28)
        }
        .task { unlock() }
    }

    private func unlock() {
        lock.authenticate { ok, msg in
            if ok { lock.markUnlocked(); open = true } else { error = msg }
        }
    }
}

/// The two switches for the privacy card on the Cycle tab.
struct CycleLockSettings: View {
    @ObservedObject private var lock = CycleLock.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { lock.enabled }, set: { want in if !want || CycleLock.deviceSecure { lock.enabled = want } })) {
                VStack(alignment: .leading, spacing: 2) {
                    T("Lock the Cycle tab").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                    T(CycleLock.deviceSecure ? "Asks for Face ID, Touch ID or your passcode, and hides this screen in the app switcher."
                                             : "Set a passcode on your iPhone first (Settings, Face ID & Passcode) so there is something to ask for.")
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                }
            }
            if UIApplication.shared.supportsAlternateIcons {
                Toggle(isOn: Binding(get: { lock.discreetIcon }, set: { lock.setDiscreetIcon($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        T("Discreet home-screen icon").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        T("Shows a plain notepad icon on your home screen. The name under it still says HolySteps, as iPhone requires.")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                }
            }
        }
        .tint(HS.gold)
    }
}

// MARK: - Small shared pieces

private struct Pill: View {
    let label: String
    var on = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            D(label).font(.hs(13, .semibold)).foregroundStyle(on ? HS.text : HS.textMuted)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(HS.gold.opacity(on ? 0.25 : 0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.gold.opacity(on ? 0.9 : 0.25), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

private func mmss(_ s: TimeInterval) -> String { let t = max(0, Int(s)); return String(format: "%d:%02d", t / 60, t % 60) }

private func toolHeader(_ kicker: String, _ title: String, _ sub: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        T(kicker).font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF472B6))
        T(title).font(.hs(24)).foregroundStyle(HS.text)
        T(sub).font(.hs(13)).foregroundStyle(HS.textSecondary)
    }
}

private func call988() { if let u = URL(string: "tel:988") { UIApplication.shared.open(u) } }

// MARK: - Mood scale and pregnancy-test log


final class CycleMoodTests: ObservableObject {
    static let shared = CycleMoodTests()
    static let moods = [("😞", "Very low"), ("😕", "Low"), ("😐", "Okay"), ("🙂", "Good"), ("😄", "Great")]
    static let results = ["Negative", "Positive", "Faint line", "Invalid"]

    @Published private(set) var mood: [String: Int] { didSet { UserDefaults.standard.set(mood, forKey: "cycleMood") } }
    /// [date, result], oldest first.
    @Published private(set) var tests: [[String]] { didSet { UserDefaults.standard.set(tests, forKey: "pregnancyTests") } }

    private init() {
        mood = UserDefaults.standard.dictionary(forKey: "cycleMood") as? [String: Int] ?? [:]
        tests = UserDefaults.standard.array(forKey: "pregnancyTests") as? [[String]] ?? []
    }
    func setMood(_ v: Int) { mood[AppStore.dayKey()] = v; ActivityLog.shared.add(.tracker) }
    func addTest(_ r: String) { tests.append([AppStore.dayKey(), r]) }
    func undoTest() { if !tests.isEmpty { tests.removeLast() } }
    func erase() { mood = [:]; tests = [] }

    /// The last 7 days average 2 or under, with at least 4 entries.
    var lowWeek: Bool {
        let cut = AppStore.dayKey(Date().addingTimeInterval(-6 * 86400))
        let w = mood.filter { $0.key >= cut }.map(\.value)
        return w.count >= 4 && Double(w.reduce(0, +)) / Double(w.count) <= 2
    }

    static func guidance(_ r: String) -> String {
        switch r {
        case "Positive": return "A positive home test is very likely right. Call a doctor or clinic to confirm and start prenatal care. Turn on Pregnancy mode in the More tab of Cycle for your week-by-week updates, kick counter, contraction timer and appointments."
        case "Faint line": return "Any line, even a faint one, usually means pregnant, if it showed within the time on the box. Test again in 2 to 3 days with first-morning urine, and see a doctor to confirm."
        case "Invalid": return "An invalid test can't be read. Use a new test and follow the box instructions."
        default: return "Testing early can miss a pregnancy. If your period hasn't come, test again in a few days with first-morning urine. If it is still missing, see a doctor."
        }
    }
}

struct CycleMoodTestsView: View {
    @ObservedObject private var log = CycleMoodTests.shared
    var body: some View {
        let today = log.mood[AppStore.dayKey()]
        let recent = log.mood.sorted { $0.key < $1.key }.suffix(14)
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    toolHeader("🌸 CYCLE", "Mood and tests", "Two quick logs that help you and your doctor see patterns. Private: they stay on your phone.")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            T("How is your mood today?").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            HStack(spacing: 6) {
                                ForEach(0..<5, id: \.self) { i in Pill(label: CycleMoodTests.moods[i].0, on: today == i + 1) { log.setMood(i + 1) } }
                            }
                            if let t = today { T("Today: \(CycleMoodTests.moods[t - 1].1)").font(.hs(11)).foregroundStyle(HS.textMuted) }
                            if recent.count >= 2 {
                                HStack(alignment: .bottom, spacing: 3) {
                                    ForEach(Array(recent), id: \.key) { e in
                                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF472B6).opacity(0.25 + Double(e.value) * 0.15))
                                            .frame(height: CGFloat(8 + e.value * 8))
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if log.lowWeek {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                T("A low week").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                T("Your mood has been low most days this week. If it keeps up, or it gets heavy before your period each month, tell your doctor. If you are in crisis, call or text 988 any time.")
                                    .font(.hs(12)).foregroundStyle(HS.textSecondary)
                                Button(action: call988) { T("📞 Call or text 988").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                            }
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            T("Pregnancy test log").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            T("Log the result you read, so you remember the dates.").font(.hs(11)).foregroundStyle(HS.textMuted)
                            HStack(spacing: 6) { ForEach(CycleMoodTests.results.prefix(2), id: \.self) { r in Pill(label: tr(r)) { log.addTest(r) } } }
                            HStack(spacing: 6) { ForEach(CycleMoodTests.results.suffix(2), id: \.self) { r in Pill(label: tr(r)) { log.addTest(r) } } }
                            ForEach(Array(log.tests.suffix(5).reversed().enumerated()), id: \.offset) { _, t in
                                D("\(t.first ?? "") · \(tr(t.last ?? ""))").font(.hs(12)).foregroundStyle(HS.textSecondary)
                            }
                            if !log.tests.isEmpty {
                                Button { log.undoTest() } label: { T("Undo last").font(.hs(11)).foregroundStyle(HS.gold) }
                                T(CycleMoodTests.guidance(log.tests.last?.last ?? "")).font(.hs(12)).foregroundStyle(HS.textSecondary)
                            }
                        }
                    }
                    T("General information, not a medical device or a diagnosis.").font(.hs(10)).foregroundStyle(HS.textSubtle)
                }.padding(20)
            }
        }
    }
}

// MARK: - Pregnancy tools


final class PregTools: ObservableObject {
    static let shared = PregTools()
    private let d = UserDefaults.standard

    /// [date, minutes to reach 10 movements], last 30.
    @Published private(set) var kicks: [[String]] { didSet { d.set(kicks, forKey: "pregKicks") } }
    @Published var kickStart: Double { didSet { d.set(kickStart, forKey: "pregKickStart") } }
    @Published var kickCount: Int { didSet { d.set(kickCount, forKey: "pregKickCount") } }
    /// [start, end] seconds since 1970, kept 12 hours.
    @Published private(set) var contractions: [[Double]] { didSet { d.set(contractions, forKey: "pregContractions") } }
    @Published var contractionStart: Double { didSet { d.set(contractionStart, forKey: "pregContractionStart") } }
    @Published var firstBirth: Bool { didSet { d.set(firstBirth, forKey: "pregFirstBirth") } }
    /// [date, note], sorted by date.
    @Published private(set) var appointments: [[String]] { didSet { d.set(appointments, forKey: "pregAppointments") } }

    private init() {
        kicks = d.array(forKey: "pregKicks") as? [[String]] ?? []
        var ks = d.double(forKey: "pregKickStart")
        // A count left open for hours (forgotten, or yesterday's) is dropped rather than shown as an overdue warning.
        if ks > 0 && Date().timeIntervalSince1970 - ks > 3 * 3600 { ks = 0 }
        kickStart = ks
        kickCount = ks > 0 ? d.integer(forKey: "pregKickCount") : 0
        let cut = Date().timeIntervalSince1970 - 12 * 3600
        contractions = (d.array(forKey: "pregContractions") as? [[Double]] ?? []).filter { ($0.first ?? 0) >= cut }
        let cs = d.double(forKey: "pregContractionStart")
        contractionStart = cs > 0 && Date().timeIntervalSince1970 - cs < 1800 ? cs : 0
        firstBirth = d.object(forKey: "pregFirstBirth") as? Bool ?? true
        appointments = d.array(forKey: "pregAppointments") as? [[String]] ?? []
    }

    func startKicks() { kickStart = Date().timeIntervalSince1970; kickCount = 0 }
    func cancelKicks() { kickStart = 0; kickCount = 0 }
    func addKick() {
        kickCount += 1
        if kickCount >= 10 {
            let mins = max(1, Int((Date().timeIntervalSince1970 - kickStart) / 60))
            kicks = Array((kicks + [[AppStore.dayKey(), String(mins)]]).suffix(30))
            kickStart = 0; kickCount = 0
        }
    }
    var slowerThanUsual: Bool {
        let m = kicks.compactMap { Int($0.last ?? "") }
        guard m.count >= 3, let last = m.last else { return false }
        let prev = m.dropLast().suffix(7)
        let avg = Double(prev.reduce(0, +)) / Double(prev.count)
        return Double(last) > avg * 2 && last > 30
    }

    func startContraction() { contractionStart = Date().timeIntervalSince1970 }
    func endContraction() {
        contractions = Array((contractions + [[contractionStart, Date().timeIntervalSince1970]]).suffix(200))
        contractionStart = 0
    }
    func clearContractions() { contractions = [] }

    /// First birth: about 5 minutes apart, about a minute long, for an hour (5-1-1). After a previous birth, hospitals say
    /// to come in at about 5 to 7 minutes apart. Measured start to start.
    var callNow: Bool {
        let maxGap = firstBirth ? 6.0 : 7.0
        guard contractions.count >= 6, let lastEnd = contractions.last?.last else { return false }
        let hourAgo = lastEnd - 3600
        let w = contractions.filter { ($0.first ?? 0) >= hourAgo }
        guard w.count >= 6, let first = w.first?.first, first <= hourAgo + 600 else { return false }
        let gaps = zip(w, w.dropFirst()).map { (($1.first ?? 0) - ($0.first ?? 0)) / 60 }
        let lens = w.map { ($0.last ?? 0) - ($0.first ?? 0) }
        return gaps.allSatisfy { $0 <= maxGap } && lens.reduce(0, +) / Double(lens.count) >= 45
    }

    func addAppointment(_ date: Date, _ note: String) {
        appointments = (appointments + [[AppStore.dayKey(date), String(note.prefix(60))]]).sorted { ($0.first ?? "") < ($1.first ?? "") }
    }
    func removeAppointment(_ i: Int) { if appointments.indices.contains(i) { appointments.remove(at: i) } }
    func erase() { kicks = []; kickStart = 0; kickCount = 0; contractions = []; contractionStart = 0; appointments = [] }
}

struct PregnancyToolsView: View {
    @ObservedObject private var p = PregTools.shared
    @State private var date = Date().addingTimeInterval(7 * 86400)
    @State private var note = ""

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    toolHeader("🤰 PREGNANCY", "Pregnancy tools", "A kick counter, a contraction timer and your appointments. Private: they stay on your phone.")
                    TimelineView(.periodic(from: .now, by: 1)) { tl in
                        let now = tl.date.timeIntervalSince1970
                        VStack(spacing: 14) { kickCard(now); contractionCard(now) }
                    }
                    appointmentsCard
                    T("General information, not a medical device or a diagnosis. Your doctor or midwife's instructions come first. In an emergency call 911.")
                        .font(.hs(10)).foregroundStyle(HS.textSubtle)
                }.padding(20)
            }
        }
    }

    private func kickCard(_ now: Double) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("Kick counter").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                T("Start around 28 weeks, or earlier if your provider asks. Count at about the same time each day, when your baby is usually active. Tap once for each kick, roll, swish or jab (not hiccups), and stop at 10.")
                    .font(.hs(11)).foregroundStyle(HS.textMuted)
                if p.kickStart == 0 {
                    GoldButton(title: tr("Start counting")) { p.startKicks() }
                } else {
                    D("\(p.kickCount) / 10 · \(mmss(now - p.kickStart))").font(.hs(26, .bold)).foregroundStyle(HS.text)
                    HStack(spacing: 8) {
                        Pill(label: tr("＋ Movement"), on: true) { p.addKick() }
                        Pill(label: tr("Cancel")) { p.cancelKicks() }
                    }
                    if now - p.kickStart > 2 * 3600 {
                        T("Fewer than 10 movements in 2 hours. Call your provider or labor and delivery now. Don't wait.")
                            .font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    }
                }
                ForEach(Array(p.kicks.suffix(5).reversed().enumerated()), id: \.offset) { _, k in
                    D(tr("\(k.first ?? "") · 10 movements in \(k.last ?? "") min")).font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                if p.slowerThanUsual {
                    T("That was slower than your usual. If baby's movement seems less than normal, call your provider. Don't wait until the next day.")
                        .font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                T("What matters most is a change from your baby's usual pattern. Weaker, slower or fewer movements than normal, or none you can feel, are a reason to call your provider or go in now, whatever the count says. Kick counting helps you notice; it can't promise that everything is fine.")
                    .font(.hs(10)).foregroundStyle(HS.textMuted)
            }
        }
    }

    private func contractionCard(_ now: Double) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("Contraction timer").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                T("Tap when one starts and again when it ends. Time apart is counted from the start of one to the start of the next.")
                    .font(.hs(11)).foregroundStyle(HS.textMuted)
                HStack(spacing: 8) {
                    Pill(label: tr("First baby"), on: p.firstBirth) { p.firstBirth = true }
                    Pill(label: tr("I've given birth before"), on: !p.firstBirth) { p.firstBirth = false }
                }
                if p.contractionStart == 0 {
                    GoldButton(title: tr("Contraction started")) { p.startContraction() }
                } else {
                    D(tr("Lasting \(mmss(now - p.contractionStart))")).font(.hs(24, .bold)).foregroundStyle(HS.text)
                    GoldButton(title: tr("Contraction ended")) { p.endContraction() }
                }
                let all = p.contractions
                ForEach(Array(all.suffix(6).enumerated().reversed()), id: \.offset) { pair in
                    let i = all.count - min(6, all.count) + pair.offset
                    let c = pair.element
                    let gap = i > 0 ? " · " + tr("\(mmss((c.first ?? 0) - (all[i - 1].first ?? 0))) since the last began") : ""
                    D(tr("\(mmss((c.last ?? 0) - (c.first ?? 0))) long") + gap).font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                if p.callNow {
                    T(p.firstBirth
                      ? "Your contractions have been about 5 minutes apart and about a minute long for an hour (the 5-1-1 pattern). Call your provider or head to the hospital now."
                      : "Your contractions have been regular, about 7 minutes apart or closer, for an hour. After a previous birth labor can move fast: call your provider or head to the hospital now.")
                        .font(.hs(13, .semibold)).foregroundStyle(HS.text)
                }
                if !all.isEmpty { Button { p.clearContractions() } label: { T("Clear").font(.hs(11)).foregroundStyle(HS.gold) } }
                T("Call right away, whatever the timer says, if your water breaks, you have bleeding, the baby moves less, you have constant severe pain, or you are before 37 weeks and having regular contractions. If you've given birth before, live far from the hospital, or had a C-section, your provider may want you in sooner. Follow their numbers. In an emergency call 911.")
                    .font(.hs(10)).foregroundStyle(HS.textMuted)
            }
        }
    }

    private var appointmentsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("Appointments").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                let today = AppStore.dayKey()
                ForEach(Array(p.appointments.enumerated()), id: \.offset) { i, a in
                    HStack {
                        D("\((a.first ?? "") < today ? "✓ " : "")\(a.first ?? "") · \(a.last ?? "")").font(.hs(13))
                            .foregroundStyle((a.first ?? "") < today ? HS.textMuted : HS.text)
                        Spacer()
                        Button { p.removeAppointment(i) } label: { T("Remove").font(.hs(11)).foregroundStyle(HS.gold) }
                    }
                }
                DatePicker(tr("Date"), selection: $date, displayedComponents: .date).font(.hs(13))
                TextField(tr("What is it? (anatomy scan, glucose test)"), text: $note).textFieldStyle(.roundedBorder)
                GoldButton(title: tr("Add appointment")) {
                    let n = note.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty { p.addAppointment(date, n); note = "" }
                }
            }
        }
    }
}

// MARK: - Symptom severity (for PMS, PMDD, PCOS or endometriosis)


final class SeverityLog: ObservableObject {
    static let shared = SeverityLog()
    static let items = ["Irritability", "Anxiety", "Low mood", "Fatigue"]
    /// date -> [pain 0-10, irritability 0-3, anxiety 0-3, low mood 0-3, fatigue 0-3]
    @Published private(set) var log: [String: [Int]] { didSet { UserDefaults.standard.set(log, forKey: "severityLog") } }
    private init() { log = UserDefaults.standard.dictionary(forKey: "severityLog") as? [String: [Int]] ?? [:] }
    func save(_ v: [Int]) { log[AppStore.dayKey()] = v; ActivityLog.shared.add(.tracker) }
    func erase() { log = [:] }

    /// Average on days 1-7 before a later logged period start vs the rest, when there are 3+ days of each.
    func compare(_ idx: Int, starts: [String]) -> (Double, Double)? {
        var before: [Double] = [], rest: [Double] = []
        for (d, v) in log where v.count > idx {
            guard let next = starts.filter({ $0 > d }).min(),
                  let a = AppStore.date(fromKey: d), let b = AppStore.date(fromKey: next) else { continue }
            let gap = CycleLogic.days(a, b)
            if (1...7).contains(gap) { before.append(Double(v[idx])) } else { rest.append(Double(v[idx])) }
        }
        guard before.count >= 3, rest.count >= 3 else { return nil }
        return (before.reduce(0, +) / Double(before.count), rest.reduce(0, +) / Double(rest.count))
    }
}

struct SeverityView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var s = SeverityLog.shared
    @State private var v: [Int] = SeverityLog.shared.log[AppStore.dayKey()] ?? [0, 0, 0, 0, 0]

    var body: some View {
        let labels = [tr("Pain (0 none, 10 worst)")] + SeverityLog.items.map { tr("\($0) (0 none, 3 severe)") }
        let starts = store.periodStarts.map { AppStore.dayKey($0) }
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    toolHeader("🌸 CYCLE", "Symptom severity", "Rate today in 30 seconds. After a couple of cycles you can see whether the week before your period is different. Private: it stays on your phone.")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(0..<5, id: \.self) { i in
                                D(labels[i]).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 5) {
                                        ForEach(0...(i == 0 ? 10 : 3), id: \.self) { n in
                                            Button { v[i] = n } label: {
                                                D("\(n)").font(.hs(13, .semibold)).foregroundStyle(v[i] == n ? HS.text : HS.textMuted)
                                                    .frame(width: 34, height: 34)
                                                    .background(RoundedRectangle(cornerRadius: 10).fill(HS.gold.opacity(v[i] == n ? 0.25 : 0.06)))
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            GoldButton(title: tr(s.log[AppStore.dayKey()] == nil ? "Save today" : "Update today")) { s.save(v) }
                            D(tr("\(s.log.count) days logged")).font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                    }
                    if v[3] == 3 || v[2] == 3 {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                T("You don't have to get through this alone").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                T("If you're having thoughts of hurting yourself or that life isn't worth living, call or text 988 now. It's free and open 24/7. In danger right now, call 911. If days like this come before your period, tell your doctor: there is treatment that helps.")
                                    .font(.hs(12)).foregroundStyle(HS.textSecondary)
                                Button(action: call988) { T("📞 Call or text 988").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                            }
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("The week before your period").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            let rows: [(String, Int, Int)] = [("Pain", 0, 10)] + SeverityLog.items.enumerated().map { ($0.element, $0.offset + 1, 3) }
                            let found = rows.compactMap { r in s.compare(r.1, starts: starts).map { (r, $0) } }
                            if found.isEmpty {
                                T("Needs at least 3 rated days in the week before a logged period, and 3 other days. Keep rating each day, ideally for 2 full cycles.")
                                    .font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            ForEach(found, id: \.0.0) { r, c in
                                let higher = c.0 >= c.1 + Double(r.2) * 0.2
                                D(tr(r.0) + ": " + String(format: "%.1f", c.0) + " " + tr("the week before") + ", " + String(format: "%.1f", c.1) + " " + tr("the rest of the cycle") + " (" + tr("out of \(r.2)") + ")" + (higher ? " · " + tr("higher before your period") : ""))
                                    .font(.hs(12)).foregroundStyle(higher ? HS.text : HS.textSecondary)
                            }
                            T("This is a record to show your doctor, not a diagnosis. Severe pain, symptoms that disrupt work or relationships, or any thoughts of hurting yourself are reasons to get care. In a crisis call or text 988.")
                                .font(.hs(10)).foregroundStyle(HS.textSubtle)
                        }
                    }
                }.padding(20)
            }
        }
    }
}

// MARK: - CSV export

enum CycleExport {
    private static func cell(_ v: String) -> String {
        v.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : v
    }

    static func csv(_ store: AppStore) -> String {
        var rows: [(String, String, String)] = []
        for d in store.periodStarts { rows.append((AppStore.dayKey(d), "period_start", "")) }
        for (d, f) in CycleLog.shared.flow { rows.append((d, "flow", f)) }
        for (d, s) in CycleLog.shared.symptoms { rows.append((d, "symptoms", s.sorted().joined(separator: "; "))) }
        for (d, m) in CycleMoodTests.shared.mood { rows.append((d, "mood_1to5", String(m))) }
        for (d, t) in FertilitySigns.shared.bbt { rows.append((d, "basal_temperature_f", String(format: "%.1f", t))) }
        for (d, m) in FertilitySigns.shared.mucusDay where FertilitySigns.mucus.indices.contains(m) { rows.append((d, "cervical_mucus", FertilitySigns.mucus[m].0)) }
        for d in FertilitySigns.shared.lhPositive { rows.append((d, "ovulation_test", "positive")) }
        for t in CycleMoodTests.shared.tests { rows.append((t.first ?? "", "pregnancy_test", t.last ?? "")) }
        for (d, v) in SeverityLog.shared.log where v.count == 5 {
            rows.append((d, "severity", "pain \(v[0])/10; irritability \(v[1])/3; anxiety \(v[2])/3; low mood \(v[3])/3; fatigue \(v[4])/3"))
        }
        let body = rows.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { "\($0.0),\($0.1),\(cell($0.2))" }.joined(separator: "\n")
        return "date,type,detail\n" + body + "\n"
    }

    /// Written to a temporary file that is only readable while the phone is unlocked.
    static func file(_ store: AppStore) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("holysteps-cycle-\(AppStore.dayKey()).csv")
        do {
            try Data(csv(store).utf8).write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch { return nil }
    }
}

struct CycleExportButton: View {
    @EnvironmentObject var store: AppStore
    @State private var url: URL?
    var body: some View {
        Group {
            if let url {
                ShareLink(item: url) { T("Share my spreadsheet (CSV)").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
            } else {
                Button { url = CycleExport.file(store) } label: { T("Spreadsheet (CSV)").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
            }
        }
    }
}
