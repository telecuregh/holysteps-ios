import SwiftUI
import UserNotifications
import UIKit

// The women's health tools that match Android (data/CycleSigns.kt, data/WomenCare.kt, data/Fertility.kt,
// data/DoctorSummary.kt). Kept on this phone, never uploaded. Not a medical device and not birth control.
// Sources: FDA (tampons 4-8 h, never over 8; cups/discs up to 12 h); CDC heavy menstrual bleeding signs; CDC U.S. SPR
// 2024 missed pill / patch / ring / shot rules; product labels for IUD and implant years (Nexplanon up to 5 years,
// FDA January 2026); symptothermal "three over six" temperature rule (Sensiplan); ACOG due date at 40 weeks 0 days;
// CDC Hear Her urgent maternal warning signs.

// MARK: - Private reminders

enum WomenReminders {
    /// The lock screen only ever says "HolySteps reminder": what someone uses or takes is their business.
    static func schedule(id: String, at date: Date, repeatsDaily: Bool = false) {
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let n = UNMutableNotificationContent()
            n.title = tr("HolySteps reminder")
            n.body = tr("Tap to see your Cycle tab.")
            n.sound = .default
            n.threadIdentifier = "cycle"
            n.userInfo = ["route": "cycle"]
            let comps = repeatsDaily
                ? Calendar.current.dateComponents([.hour, .minute], from: date)
                : Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeatsDaily)
            c.add(UNNotificationRequest(identifier: id, content: n, trigger: trig))
        }
    }
    static func cancel(_ ids: [String]) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids) }
}

private struct Chip: View {
    let label: String
    var on = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            D(label).font(.hs(12, .semibold)).foregroundStyle(on ? HS.text : HS.textMuted)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(HS.gold.opacity(on ? 0.25 : 0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.gold.opacity(on ? 0.9 : 0.25), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

private func short(_ d: Date) -> String { d.formatted(.dateTime.month(.abbreviated).day().locale(I18n.shared.locale)) }

// MARK: - Fertility signs

final class FertilitySigns: ObservableObject {
    static let shared = FertilitySigns()
    static let mucus: [(String, Int)] = [("Dry", 0), ("Sticky", 1), ("Creamy", 2), ("Watery", 3), ("Egg white (stretchy)", 4)]

    /// date -> waking temperature °F (94-101.5)
    @Published private(set) var bbt: [String: Double] { didSet { UserDefaults.standard.set(bbt, forKey: "signsBBT") } }
    /// date -> mucus index 0-4
    @Published private(set) var mucusDay: [String: Int] { didSet { UserDefaults.standard.set(mucusDay, forKey: "signsMucus") } }
    @Published private(set) var lhPositive: Set<String> { didSet { UserDefaults.standard.set(Array(lhPositive), forKey: "signsLH") } }

    private init() {
        bbt = UserDefaults.standard.dictionary(forKey: "signsBBT") as? [String: Double] ?? [:]
        mucusDay = UserDefaults.standard.dictionary(forKey: "signsMucus") as? [String: Int] ?? [:]
        lhPositive = Set(UserDefaults.standard.stringArray(forKey: "signsLH") ?? [])
    }

    func setTemp(_ f: Double?, day: String = AppStore.dayKey()) {
        if let f, (94.0...101.5).contains(f) { bbt[day] = (f * 10).rounded() / 10 } else { bbt[day] = nil }
    }
    func setMucus(_ i: Int?) { mucusDay[AppStore.dayKey()] = i }
    func toggleLH() { let k = AppStore.dayKey(); if lhPositive.contains(k) { lhPositive.remove(k) } else { lhPositive.insert(k) } }
    func erase() { bbt = [:]; mucusDay = [:]; lhPositive = [] }

    enum Source: String { case lh = "your ovulation test", bbt = "your temperature shift", mucus = "your mucus peak", calendar = "your cycle dates" }

    private static func k(_ d: Date) -> String { AppStore.dayKey(d) }

    /// Three readings in a row above the highest of the six before them, the third at least 0.36 °F (0.2 °C) above it.
    func bbtShift(from: String, to: String) -> String? {
        let t = bbt.filter { $0.key >= from && $0.key <= to }.sorted { $0.key < $1.key }
        guard t.count >= 9 else { return nil }
        for i in 6...(t.count - 3) {
            let cover = t[(i - 6)..<i].map(\.value).max() ?? 0
            if (0...2).allSatisfy({ t[i + $0].value > cover }) && t[i + 2].value >= cover + 0.36 { return t[i].key }
        }
        return nil
    }

    /// The best ovulation estimate near [predicted]: a positive LH test beats a temperature shift, which beats the mucus peak.
    func ovulation(predicted: Date) -> (Date, Source) {
        let pk = Self.k(predicted)
        let near = lhPositive.filter { d in
            guard let x = AppStore.date(fromKey: d) else { return false }
            return (-7...5).contains(CycleLogic.days(predicted, x))
        }.max()
        if let near, let d = AppStore.date(fromKey: near) { return (CycleLogic.plus(d, 1), .lh) }
        let from = Self.k(CycleLogic.plus(predicted, -10)), to = Self.k(CycleLogic.plus(predicted, 8))
        if let first = bbtShift(from: from, to: to), let d = AppStore.date(fromKey: first) { return (CycleLogic.plus(d, -1), .bbt) }
        let inWin = mucusDay.filter { $0.key >= from && $0.key <= to }
        if let best = inWin.values.max(), best >= 3, let day = inWin.filter({ $0.value == best }).keys.max(),
           let d = AppStore.date(fromKey: day) { return (d, .mucus) }
        _ = pk
        return (predicted, .calendar)
    }
}

struct FertilitySignsCard: View {
    @ObservedObject private var s = FertilitySigns.shared
    let predictedOvulation: Date?
    @State private var temp = ""

    var body: some View {
        let today = AppStore.dayKey()
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("🌡️ Fertility signs today").font(.hs(15, .bold)).foregroundStyle(HS.text)
                T("Temperature on waking, before getting up. Your signs sharpen the ovulation estimate.").font(.hs(12)).foregroundStyle(HS.textMuted)
                HStack {
                    TextField("°F", text: $temp).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width: 90)
                    Button { s.setTemp(Double(temp.replacingOccurrences(of: ",", with: "."))) } label: { T("Save temp").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                    if let t = s.bbt[today] { D(String(format: "%.1f °F", t)).font(.hs(12)).foregroundStyle(HS.textMuted) }
                }
                T("Cervical mucus").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0..<FertilitySigns.mucus.count, id: \.self) { i in
                            let on = s.mucusDay[today] == i
                            Chip(label: tr(FertilitySigns.mucus[i].0), on: on) { s.setMucus(on ? nil : i) }
                        }
                    }
                }
                Button { s.toggleLH() } label: {
                    T(s.lhPositive.contains(today) ? "✓ Positive ovulation test today (tap to undo)" : "🧪 Got a positive ovulation test today? Tap to log it")
                        .font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                }
                if let p = predictedOvulation {
                    let (ov, src) = s.ovulation(predicted: p)
                    D(tr("Ovulation estimate: \(short(ov)), from \(tr(src.rawValue)).")).font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                T("Not a method of birth control. Cycles shift, sperm can live up to 5 days, and no day is fully safe.").font(.hs(10)).foregroundStyle(HS.textSubtle)
            }
        }
        .onAppear { if let t = s.bbt[today] { temp = String(format: "%.1f", t) } }
    }
}

// MARK: - Birth control

enum BcMethod: String, CaseIterable, Identifiable {
    case none = "NONE", combined = "COMBINED", minipill = "MINIPILL", drosp = "DROSP", patch = "PATCH", ring = "RING", shot = "SHOT", iud = "IUD", implant = "IMPLANT"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"; case .combined: return "Combined pill"; case .minipill: return "Progestin-only pill"
        case .drosp: return "Drospirenone pill (Slynd)"; case .patch: return "Patch"; case .ring: return "Ring"
        case .shot: return "Shot (Depo-Provera)"; case .iud: return "IUD"; case .implant: return "Implant"
        }
    }
    var isPill: Bool { self == .combined || self == .minipill || self == .drosp }
}

final class BirthControl: ObservableObject {
    static let shared = BirthControl()
    private let d = UserDefaults.standard
    @Published var method: BcMethod { didSet { d.set(method.rawValue, forKey: "bcMethod"); reschedule() } }
    @Published var start: Date? { didSet { d.set(start?.timeIntervalSince1970 ?? 0, forKey: "bcStart"); reschedule() } }
    /// Reminder time, minutes after midnight.
    @Published var minute: Int { didSet { d.set(minute, forKey: "bcMinute"); reschedule() } }
    @Published var activeDays: Int { didSet { d.set(activeDays, forKey: "bcActive") } }
    @Published var years: Int { didSet { d.set(years, forKey: "bcYears"); reschedule() } }
    @Published private(set) var takenDay: String { didSet { d.set(takenDay, forKey: "bcTaken") } }

    private init() {
        method = BcMethod(rawValue: d.string(forKey: "bcMethod") ?? "") ?? .none
        let s = d.double(forKey: "bcStart"); start = s > 0 ? Date(timeIntervalSince1970: s) : nil
        minute = d.object(forKey: "bcMinute") as? Int ?? 21 * 60
        activeDays = d.object(forKey: "bcActive") as? Int ?? 21
        years = d.object(forKey: "bcYears") as? Int ?? 8
        takenDay = d.string(forKey: "bcTaken") ?? ""
    }

    var takenToday: Bool { takenDay == AppStore.dayKey() }
    func markTaken() { takenDay = AppStore.dayKey() }
    func undoTaken() { takenDay = AppStore.dayKey(Date().addingTimeInterval(-86400)) }

    /// 1-based day in a 28-day pack or patch/ring cycle.
    func cycleDay(_ day: Date = Date()) -> Int? {
        guard let start else { return nil }
        let n = CycleLogic.days(start, day)
        return ((n % 28) + 28) % 28 + 1
    }
    func pillActive(_ dday: Int) -> Bool {
        switch method { case .combined: return dday <= activeDays; case .drosp: return dday <= 24; default: return true }
    }

    var todayTask: String? {
        let today = Date()
        switch method {
        case .none: return nil
        case .combined, .drosp:
            guard let dd = cycleDay() else { return "Take today's pill" }
            return pillActive(dd) ? "Take today's pill (day \(dd) of 28)" : "Inactive pill today (day \(dd) of 28). Keep the habit."
        case .minipill: return "Take today's pill, at the same time every day"
        case .patch:
            switch cycleDay() { case 1: return "Put on a new patch"; case 8, 15: return "Change your patch today"; case 22: return "Take off your patch: patch-free week"; default: return nil }
        case .ring:
            switch cycleDay() { case 1: return "Insert a new ring"; case 22: return "Remove your ring: ring-free week"; default: return nil }
        case .shot:
            guard let start else { return nil }
            let n = CycleLogic.days(start, today)
            return n == 84 ? "Your next shot is due in a week. Book it." : n == 91 ? "Your shot is due today" : n == 105 ? "Your shot is 2 weeks late. Get it this week." : nil
        case .iud, .implant:
            guard let start else { return nil }
            let due = CycleLogic.plus(start, years * 365), n = CycleLogic.days(today, due)
            return n == 30 ? "Your \(method.label) is due to be replaced in 30 days" : n == 0 ? "Your \(method.label) is due to be replaced today" : nil
        }
    }

    var nextLine: String? {
        guard let start else { return nil }
        let today = Date(), dd = cycleDay() ?? 1
        switch method {
        case .patch:
            let next = [1, 8, 15, 22, 29].first { $0 > dd } ?? 29
            return "Next: \(next == 22 ? "patch off" : "new patch") \(short(CycleLogic.plus(today, next - dd)))"
        case .ring: return dd < 22 ? "Ring out \(short(CycleLogic.plus(today, 22 - dd)))" : "New ring in \(short(CycleLogic.plus(today, 29 - dd)))"
        case .shot: return "Next shot due \(short(CycleLogic.plus(start, 91))) (on time up to \(short(CycleLogic.plus(start, 105))))"
        case .iud, .implant: return "Replace by \(CycleLogic.plus(start, years * 365).formatted(date: .numeric, time: .omitted))"
        default: return nil
        }
    }

    /// Hours since today's active pill was due, when it isn't marked taken (yesterday's untaken pill counts from its time).
    var hoursLate: Double {
        guard method.isPill, !takenToday else { return 0 }
        let cal = Calendar.current
        let dueToday = cal.date(byAdding: .minute, value: minute, to: cal.startOfDay(for: Date())) ?? Date()
        var due = dueToday
        if takenDay != AppStore.dayKey(Date().addingTimeInterval(-86400)) && !takenDay.isEmpty { due = dueToday.addingTimeInterval(-86400) }
        if let dd = cycleDay(due), !pillActive(dd) { return 0 }
        return max(0, Date().timeIntervalSince(due) / 3600)
    }

    var missedHelp: String? {
        let h = hoursLate
        switch method {
        case .combined:
            if h <= 0 { return nil }
            return h < 48 ? "Take the missed pill now, even if that means two today, then keep going as usual. No backup is needed."
                : "Two or more pills missed: take the most recent missed pill now and throw away the other missed ones. Keep going as usual. Use condoms or avoid sex until you've taken 7 active pills in a row. If this happened in the last week of active pills, skip the inactive pills and start a new pack. If it was the first week and you had sex without a condom in the last 5 days, ask about emergency contraception."
        case .minipill:
            return h > 3 ? "More than 3 hours late counts as missed: take one pill now and the next at your usual time. Use condoms or avoid sex for the next 2 days. If you had sex without a condom, ask about emergency contraception." : nil
        case .drosp:
            if h <= 0 { return nil }
            return h < 48 ? "Take the missed pill now, then keep going as usual. No backup is needed."
                : "Two or more missed (48 hours or more): take the last missed pill now and keep going with the pack. Use condoms or avoid sex until you've taken 7 active pills in a row. If this was the first week and you had sex without a condom, ask about emergency contraception."
        default: return nil
        }
    }

    var lateHelp: String? {
        switch method {
        case .patch: return "Patch late or fell off for less than 48 hours: put on a new one now, no backup needed. 48 hours or more: put one on now and use condoms for 7 days."
        case .ring: return "Ring out or late for less than 48 hours: put it in now, no backup needed. 48 hours or more: put it in now and use condoms for 7 days."
        case .shot: return "The shot works for up to 15 weeks. Later than that, you can still get it if pregnancy is ruled out. Use condoms for 7 days after."
        default: return nil
        }
    }

    func reschedule() {
        WomenReminders.cancel(["bc-daily"])
        guard method != .none else { return }
        let cal = Calendar.current
        let at = cal.date(byAdding: .minute, value: minute, to: cal.startOfDay(for: Date())) ?? Date()
        WomenReminders.schedule(id: "bc-daily", at: at, repeatsDaily: true)
    }
    func erase() { method = .none; start = nil; takenDay = "" }
}

struct BirthControlCard: View {
    @ObservedObject private var bc = BirthControl.shared
    @State private var editing = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    T("💊 Birth control").font(.hs(15, .bold)).foregroundStyle(HS.text)
                    Spacer()
                    Button { editing.toggle() } label: { T(editing ? "Done" : (bc.method == .none ? "Set up" : "Change")).font(.hs(12, .semibold)).foregroundStyle(HS.gold) }
                }
                if editing {
                    Picker(tr("Method"), selection: $bc.method) { ForEach(BcMethod.allCases) { m in Text(tr(m.label)).tag(m) } }
                    if bc.method != .none && bc.method != .minipill {
                        DatePicker(tr(bc.method.isPill || bc.method == .patch || bc.method == .ring ? "Pack or cycle started" : "Date you got it"),
                                   selection: Binding(get: { bc.start ?? Date() }, set: { bc.start = $0 }), displayedComponents: .date)
                    }
                    if bc.method != .none {
                        DatePicker(tr("Reminder time"), selection: Binding(
                            get: { Calendar.current.date(byAdding: .minute, value: bc.minute, to: Calendar.current.startOfDay(for: Date())) ?? Date() },
                            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); bc.minute = (c.hour ?? 21) * 60 + (c.minute ?? 0) }),
                                   displayedComponents: .hourAndMinute)
                    }
                    if bc.method == .combined {
                        Picker(tr("Active pills"), selection: $bc.activeDays) { Text("21/7").tag(21); Text("24/4").tag(24); Text(tr("28 active")).tag(28) }.pickerStyle(.segmented)
                    }
                    if bc.method == .iud || bc.method == .implant {
                        Stepper(value: $bc.years, in: 3...12) { D(tr("Lasts \(bc.years) years")).font(.hs(13)) }
                        T("Check your device: Mirena and Liletta 8 years, Kyleena 5, Skyla 3, Paragard 10 to 12; Nexplanon up to 5 (FDA label, 2026).")
                            .font(.hs(10)).foregroundStyle(HS.textSubtle)
                    }
                } else if bc.method == .none {
                    T("Pill, patch, ring, shot, IUD or implant: get a private reminder and help if you miss one.").font(.hs(12)).foregroundStyle(HS.textMuted)
                } else {
                    if let t = bc.todayTask { T(t).font(.hs(14, .semibold)).foregroundStyle(HS.text) }
                    if bc.method.isPill {
                        Button { bc.takenToday ? bc.undoTaken() : bc.markTaken() } label: {
                            T(bc.takenToday ? "✓ Taken today (tap to undo)" : "Mark today's pill taken").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                        }
                        if let help = bc.missedHelp { T(help).font(.hs(12)).foregroundStyle(HS.textSecondary) }
                    }
                    if let n = bc.nextLine { D(tr(n)).font(.hs(12)).foregroundStyle(HS.textMuted) }
                    if let late = bc.lateHelp { T(late).font(.hs(11)).foregroundStyle(HS.textMuted) }
                }
                T("Missed-pill and late-method help follows the CDC's 2024 guidance. Your doctor or pharmacist can tell you what fits your pill.").font(.hs(10)).foregroundStyle(HS.textSubtle)
            }
        }
        .onChange(of: bc.method) { _, m in if m == .implant && bc.years == 8 { bc.years = 5 } }
    }
}

// MARK: - Period products and the heavy-bleeding check

final class PeriodProducts: ObservableObject {
    static let shared = PeriodProducts()
    static let all: [(id: String, label: String, emoji: String)] = [("pad", "Pad", "🩹"), ("tampon", "Tampon", "🌸"), ("cup", "Cup", "🍷"), ("disc", "Disc", "💿"), ("underwear", "Period underwear", "🩲")]
    static func collects(_ p: String) -> Bool { p == "cup" || p == "disc" }
    /// FDA: tampons 8 hours at most; cups and discs 12. Pads and period underwear: at least every 8.
    static func maxHours(_ p: String) -> Int { collects(p) ? 12 : 8 }
    static func defaultHours(_ p: String) -> Int { ["tampon": 4, "pad": 4, "cup": 8, "disc": 8][p] ?? 6 }

    private let d = UserDefaults.standard
    @Published var using: Set<String> { didSet { d.set(Array(using), forKey: "ppUsing") } }
    @Published var hours: [String: Int] { didSet { d.set(hours, forKey: "ppHours") } }
    /// [product, epoch seconds, fill], last two days
    @Published private(set) var changes: [[String]] { didSet { d.set(changes, forKey: "ppChanges") } }
    /// day -> flags ("clots", "double", "night")
    @Published private(set) var flags: [String: [String]] { didSet { d.set(flags, forKey: "ppFlags") } }

    private init() {
        using = Set(d.stringArray(forKey: "ppUsing") ?? [])
        hours = d.dictionary(forKey: "ppHours") as? [String: Int] ?? [:]
        let cut = Date().timeIntervalSince1970 - 48 * 3600
        changes = (d.array(forKey: "ppChanges") as? [[String]] ?? []).filter { (Double($0[safe: 1] ?? "") ?? 0) >= cut }
        flags = d.dictionary(forKey: "ppFlags") as? [String: [String]] ?? [:]
    }

    func hoursFor(_ p: String) -> Int { min(Self.maxHours(p), hours[p] ?? Self.defaultHours(p)) }
    func toggle(_ p: String) {
        if using.contains(p) { using.remove(p); WomenReminders.cancel(["pp-\(p)"]) } else {
            using.insert(p)
            // A tampon can't be worn with a cup or disc.
            if p == "tampon" { using.subtract(["cup", "disc"]) }
            if Self.collects(p) { using.remove("tampon") }
        }
    }
    func logChange(_ p: String, fill: String = "") {
        let now = Date()
        changes.append([p, String(now.timeIntervalSince1970), fill])
        if (0...4).contains(Calendar.current.component(.hour, from: now)) { setFlag("night", true) }
        WomenReminders.cancel(["pp-\(p)"])
        WomenReminders.schedule(id: "pp-\(p)", at: now.addingTimeInterval(Double(hoursFor(p)) * 3600))
    }
    func undoLast() { if !changes.isEmpty { changes.removeLast() } }
    func flag(_ k: String) -> Bool { flags[AppStore.dayKey()]?.contains(k) ?? false }
    func setFlag(_ k: String, _ on: Bool) {
        var f = Set(flags[AppStore.dayKey()] ?? [])
        if on { f.insert(k) } else { f.remove(k) }
        flags[AppStore.dayKey()] = Array(f)
    }
    func last(_ p: String) -> Date? { changes.filter { $0.first == p }.compactMap { Double($0[safe: 1] ?? "") }.max().map { Date(timeIntervalSince1970: $0) } }
    var todayCount: Int { changes.filter { Calendar.current.isDateInToday(Date(timeIntervalSince1970: Double($0[safe: 1] ?? "") ?? 0)) }.count }

    /// The CDC heavy menstrual bleeding signs this log can show. [periodDay] is 1 on the first day of bleeding.
    func heavySigns(periodDay: Int) -> [String] {
        var out: [String] = []
        let absorb = changes.filter { !Self.collects($0.first ?? "") }.compactMap { Double($0[safe: 1] ?? "") }.sorted()
        var run = 1
        for i in absorb.indices.dropFirst() {
            run = absorb[i] - absorb[i - 1] <= 75 * 60 ? run + 1 : 1
            if run >= 3 { out.append("Soaking a pad or tampon about every hour for several hours"); break }
        }
        let full = changes.filter { Self.collects($0.first ?? "") && $0[safe: 2] == "Full" }.compactMap { Double($0[safe: 1] ?? "") }.sorted()
        if zip(full, full.dropFirst()).contains(where: { $1 - $0 <= 2 * 3600 }) { out.append("A full cup or disc within 2 hours, more than once") }
        if flag("clots") { out.append("Clots the size of a quarter or larger") }
        if flag("double") { out.append("Needing two products at once to control the flow") }
        if flag("night") { out.append("Waking at night to change") }
        if periodDay > 7 { out.append("Bleeding longer than 7 days") }
        return out
    }
    func erase() { using = []; hours = [:]; changes = []; flags = [:]; WomenReminders.cancel(Self.all.map { "pp-\($0.id)" }) }
}


struct PeriodProductsCard: View {
    @ObservedObject private var pp = PeriodProducts.shared
    let periodDay: Int
    @State private var fillFor: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("What are you using today?").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                T("Pick all that apply. A pad as backup with a cup or tampon is fine.").font(.hs(11)).foregroundStyle(HS.textMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(PeriodProducts.all, id: \.id) { p in Chip(label: "\(p.emoji) \(tr(p.label))", on: pp.using.contains(p.id)) { pp.toggle(p.id) } } }
                }
                ForEach(PeriodProducts.all.filter { pp.using.contains($0.id) }, id: \.id) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            D("\(p.emoji) \(tr(p.label))").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                            Spacer()
                            Button {
                                if PeriodProducts.collects(p.id) { fillFor = p.id } else { pp.logChange(p.id) }
                            } label: { T(PeriodProducts.collects(p.id) ? "Emptied" : "Changed").font(.hs(12, .semibold)).foregroundStyle(HS.gold) }
                        }
                        if fillFor == p.id {
                            HStack(spacing: 6) { ForEach(["¼", "½", "¾", "Full"], id: \.self) { f in Chip(label: f) { pp.logChange(p.id, fill: f); fillFor = nil } } }
                        }
                        if let l = pp.last(p.id) {
                            let due = l.addingTimeInterval(Double(pp.hoursFor(p.id)) * 3600)
                            D(tr("Last \(l.formatted(date: .omitted, time: .shortened)) · next by \(due.formatted(date: .omitted, time: .shortened))")).font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                        HStack(spacing: 5) {
                            ForEach([2, 3, 4, 6, 8, 10, 12].filter { $0 <= PeriodProducts.maxHours(p.id) }, id: \.self) { h in
                                Chip(label: "\(h)h", on: pp.hoursFor(p.id) == h) { pp.hours[p.id] = h }
                            }
                        }
                    }
                }
                if pp.using.contains("tampon") { T("Never leave a tampon in longer than 8 hours, and use the lowest absorbency you need (FDA).").font(.hs(11)).foregroundStyle(HS.textMuted) }
                if pp.using.contains("cup") || pp.using.contains("disc") { T("Empty a cup or disc at least every 12 hours. If you have an IUD, ask your doctor before using one.").font(.hs(11)).foregroundStyle(HS.textMuted) }
                if !pp.changes.isEmpty { Button { pp.undoLast() } label: { T("Undo last").font(.hs(11)).foregroundStyle(HS.gold) } }
                T("Anything else today?").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted)
                HStack(spacing: 6) {
                    ForEach([("clots", "Clots"), ("double", "Doubled up"), ("night", "Changed at night")], id: \.0) { k, l in
                        Chip(label: tr(l), on: pp.flag(k)) { pp.setFlag(k, !pp.flag(k)) }
                    }
                }
                let signs = pp.heavySigns(periodDay: periodDay)
                if !signs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        T("Signs of heavy bleeding").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                        ForEach(signs, id: \.self) { D("• " + tr($0)).font(.hs(12)).foregroundStyle(HS.textSecondary) }
                        T("The CDC lists these as signs of heavy menstrual bleeding. Talk to your doctor: it's common, treatable, and can cause low iron. If you soak a pad or tampon every hour for 2 hours or more, or feel faint or dizzy, get care today.")
                            .font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                }
                T("Toxic shock is rare but serious: sudden high fever, vomiting, a sunburn-like rash, dizziness or fainting while using a tampon, cup or disc. Remove it and get emergency care.")
                    .font(.hs(10)).foregroundStyle(HS.textSubtle)
            }
        }
    }
}

// MARK: - Pregnancy mode

final class PregnancyMode: ObservableObject {
    static let shared = PregnancyMode()
    @Published var due: Date? { didSet { UserDefaults.standard.set(due?.timeIntervalSince1970 ?? 0, forKey: "pregnancyDue") } }
    private init() { let t = UserDefaults.standard.double(forKey: "pregnancyDue"); due = t > 0 ? Date(timeIntervalSince1970: t) : nil }
    var on: Bool { due != nil }
    static func dueFromLastPeriod(_ lmp: Date) -> Date { CycleLogic.plus(lmp, 280) }

    /// Completed weeks pregnant (ACOG: the due date is 40 weeks 0 days); the first six days count as week 1.
    var week: Int? {
        guard let due else { return nil }
        let daysIn = 280 - CycleLogic.days(Date(), due)
        guard (0...(43 * 7 - 1)).contains(daysIn) else { return nil }
        return min(42, max(1, daysIn / 7))
    }
    func end() { due = nil }

    struct Week { let size, baby, you: String }
    static func week(_ w: Int) -> Week {
        let t: [Int: (String, String, String)] = [
            4: ("a poppy seed", "The embryo has just settled into the womb.", "A missed period and a positive test. Book your first prenatal visit."),
            5: ("a sesame seed", "The heart is starting to form.", "Tiredness and tender breasts are common."),
            6: ("a lentil", "A tiny heartbeat may show on an ultrasound.", "Morning sickness often starts now. Small, frequent meals help."),
            7: ("a blueberry", "Arms and legs are budding.", "You may need the bathroom more often."),
            8: ("a raspberry", "Fingers and toes are forming.", "Nausea and fatigue may peak around now."),
            9: ("a cherry", "All the main organs have started to form.", "Mood swings are normal; be gentle with yourself."),
            10: ("a strawberry", "Baby can bend arms and legs.", "Your first prenatal tests may be around now."),
            11: ("a fig", "Baby's head is almost half its length.", "Energy may start to return soon."),
            12: ("a lime", "Reflexes are developing.", "The chance of miscarriage drops a lot after this week."),
            13: ("a lemon", "Fingerprints are forming.", "Welcome to the second trimester."),
            14: ("a peach", "Baby can make faces.", "Many people feel better and more energetic now."),
            15: ("an apple", "Baby is sensing light.", "Gentle exercise like walking is great for you both."),
            16: ("an avocado", "Baby's bones are hardening from soft cartilage.", "You may start to show."),
            17: ("a turnip", "Fat is starting to form under the skin.", "Sleeping on your side gets more comfortable now."),
            18: ("a bell pepper", "Baby can hear sounds.", "You may feel the first flutters."),
            19: ("a mango", "A protective coating covers baby's skin.", "Mild aches in the belly and back are common."),
            20: ("a banana", "Halfway there!", "The anatomy scan is often around now."),
            21: ("a carrot", "Baby is swallowing and tasting.", "Kicks get stronger."),
            22: ("a papaya", "Baby's senses are sharpening.", "Stretch marks may appear; moisturizing helps comfort."),
            23: ("a grapefruit", "Baby can hear your voice.", "Swollen ankles are common; put your feet up."),
            24: ("an ear of corn", "Lungs are developing quickly.", "The glucose screening is often between weeks 24 and 28."),
            25: ("a cauliflower", "Baby is gaining fat.", "Heartburn is common; smaller meals help."),
            26: ("a head of lettuce", "Eyes are starting to open.", "Back aches may increase; a pregnancy pillow can help."),
            27: ("a rutabaga", "Baby has sleep and wake cycles.", "The Tdap vaccine is recommended between weeks 27 and 36 of every pregnancy."),
            28: ("an eggplant", "Baby can blink.", "Start counting kicks once a day, as your doctor advises."),
            29: ("a butternut squash", "Muscles and lungs keep maturing.", "You may feel short of breath; slow down and rest."),
            30: ("a cabbage", "Baby is about 3 pounds.", "Sleep may get harder; extra pillows help."),
            31: ("a coconut", "Baby can turn their head.", "Practice contractions (Braxton Hicks) may start."),
            32: ("a jicama", "Toenails and fingernails have grown.", "Visits may get more frequent. From September to January, ask about the RSV vaccine (weeks 32 to 36)."),
            33: ("a pineapple", "Bones are hardening, except the skull.", "Think about your birth plan."),
            34: ("a cantaloupe", "Lungs are nearly ready.", "Pack your hospital bag."),
            35: ("a honeydew melon", "Baby is filling out.", "Group B strep testing is often weeks 36 to 37."),
            36: ("a head of romaine", "Baby may settle head down.", "Visits are now usually weekly."),
            37: ("a bunch of chard", "Baby is early term.", "Know the signs of labor and when to call."),
            38: ("a leek", "Baby is practicing breathing.", "Rest as much as you can."),
            39: ("a mini watermelon", "Baby is full term.", "Any day now."),
            40: ("a small pumpkin", "Your due date!", "Only about 1 in 20 babies arrive on the due date; you're close."),
        ]
        if w <= 3 { return Week(size: "a poppy seed", baby: "Your body is getting ready; conception happens around week 2.", you: "You may not feel anything yet. Start a prenatal vitamin with folic acid if you haven't.") }
        if let x = t[w] { return Week(size: x.0, baby: x.1, you: x.2) }
        return Week(size: "a watermelon", baby: "Baby is past the due date.", you: "Your doctor or midwife will talk with you about next steps.")
    }

    /// CDC Hear Her urgent maternal warning signs, plus regular contractions before 37 weeks (preterm labor).
    static let warning = "Get medical care right away for: a headache that won't go away or gets worse, dizziness or fainting, vision changes, a fever of 100.4°F or higher, extreme swelling of your hands or face, trouble breathing, chest pain or a racing heartbeat, severe nausea and vomiting, severe belly pain that doesn't go away, overwhelming tiredness, bleeding or fluid leaking from the vagina, a swollen, red or painful leg, regular contractions before 37 weeks, your baby moving less than usual, or thoughts of harming yourself or your baby. Call 911 for chest pain, trouble breathing, fainting or a seizure."
}

struct PregnancyCard: View {
    @ObservedObject private var p = PregnancyMode.shared
    var body: some View {
        if let w = p.week, let due = p.due {
            let wk = PregnancyMode.week(w)
            GlassCard(glow: Color(hex: 0xF472B6), warm: true) {
                VStack(alignment: .leading, spacing: 8) {
                    T("🤰 Week \(w)").font(.hs(22, .bold)).foregroundStyle(HS.text)
                    D(tr("Baby is about the size of \(tr(wk.size)).")).font(.hs(14, .semibold)).foregroundStyle(HS.peach)
                    T(wk.baby).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    T(wk.you).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    D(tr("Due \(due.formatted(date: .long, time: .omitted)) · \(w < 14 ? tr("first trimester") : w < 28 ? tr("second trimester") : tr("third trimester"))"))
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                    T(PregnancyMode.warning).font(.hs(11)).foregroundStyle(HS.textMuted)
                }
            }
        }
    }
}

struct PregnancySettings: View {
    @ObservedObject private var p = PregnancyMode.shared
    @EnvironmentObject var store: AppStore
    @State private var lmp = Date().addingTimeInterval(-60 * 86400)
    @State private var due = Date().addingTimeInterval(200 * 86400)
    @State private var useDue = false
    @State private var confirmEnd = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("🤰 Pregnancy").font(.hs(15, .bold)).foregroundStyle(HS.text)
                if p.on {
                    T("Pregnancy mode is on: the Today tab shows your week, and period predictions are paused.").font(.hs(12)).foregroundStyle(HS.textMuted)
                    Button { confirmEnd = true } label: { T("My pregnancy has ended").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                } else {
                    T("Pregnant? Turn on week-by-week updates. Your due date comes from the first day of your last period (40 weeks), or enter the date your doctor gave you.")
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                    Picker("", selection: $useDue) { T("Last period").tag(false); T("Due date").tag(true) }.pickerStyle(.segmented)
                    if useDue { DatePicker(tr("Due date"), selection: $due, displayedComponents: .date) }
                    else { DatePicker(tr("First day of last period"), selection: $lmp, in: ...Date(), displayedComponents: .date) }
                    GoldButton(title: tr("Turn on pregnancy mode")) { p.due = useDue ? due : PregnancyMode.dueFromLastPeriod(lmp) }
                }
            }
        }
        .onAppear { if let last = store.periodStarts.max() { lmp = last } }
        .alert(tr("Turn off pregnancy mode?"), isPresented: $confirmEnd) {
            Button(tr("Turn off")) { p.end() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            T("Week-by-week updates stop and period predictions come back. If you've had a loss, we're so sorry. Be gentle with yourself, and call your doctor if you have heavy bleeding, fever or severe pain.")
        }
    }
}

// MARK: - Doctor summary (PDF)

enum DoctorSummary {
    static func pdf(_ store: AppStore) -> URL? {
        let lines = summaryLines(store)
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let r = UIGraphicsPDFRenderer(bounds: page)
        let data = r.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 54
            func draw(_ s: String, size: CGFloat, bold: Bool = false, gap: CGFloat = 6) {
                let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let rect = (s as NSString).boundingRect(with: CGSize(width: 504, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attr, context: nil)
                if y + rect.height > 740 { ctx.beginPage(); y = 54 }
                (s as NSString).draw(with: CGRect(x: 54, y: y, width: 504, height: rect.height), options: .usesLineFragmentOrigin, attributes: attr, context: nil)
                y += rect.height + gap
            }
            draw(tr("Cycle summary for my doctor"), size: 20, bold: true, gap: 4)
            draw(tr("Made \(Date().formatted(date: .long, time: .omitted)) by the HolySteps app from what I logged. It is not a diagnosis."), size: 10, gap: 14)
            for (title, body) in lines {
                draw(tr(title), size: 14, bold: true, gap: 4)
                for b in body { draw("• " + b, size: 11, gap: 3) }
                y += 8
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("holysteps-doctor-summary-\(AppStore.dayKey()).pdf")
        do { try data.write(to: url, options: [.atomic, .completeFileProtection]); return url } catch { return nil }
    }

    static func summaryLines(_ store: AppStore) -> [(String, [String])] {
        var out: [(String, [String])] = []
        let starts = store.periodStarts.sorted()
        var cycle: [String] = []
        if !starts.isEmpty { cycle.append(tr("Period starts: ") + starts.suffix(12).map { $0.formatted(date: .numeric, time: .omitted) }.joined(separator: ", ")) }
        let lens = CycleLogic.cycleLengths(starts)
        if !lens.isEmpty {
            cycle.append(tr("Cycle length: average \(lens.reduce(0, +) / lens.count) days, shortest \(lens.min() ?? 0), longest \(lens.max() ?? 0) (\(lens.count) cycles)"))
        }
        cycle.append(tr("Usual period length: \(store.periodLength) days"))
        let since = AppStore.dayKey(Date().addingTimeInterval(-180 * 86400))
        let syms = CycleLog.shared.symptoms.filter { $0.key >= since }
        if !syms.isEmpty {
            var counts: [String: Int] = [:]
            syms.values.flatMap { $0 }.forEach { counts[tr($0), default: 0] += 1 }
            cycle.append(tr("Symptoms logged on \(syms.count) days. Most often: ") + counts.sorted { $0.value > $1.value }.prefix(8).map { "\($0.key) (\($0.value))" }.joined(separator: ", "))
        }
        let heavy = CycleLog.shared.flow.filter { $0.key >= since && $0.value == "Heavy" }.count
        if heavy > 0 { cycle.append(tr("Heavy flow logged on \(heavy) days")) }
        out.append(("Cycle (last 6 months)", cycle))

        let s = FertilitySigns.shared
        let temps = s.bbt.filter { $0.key >= since }.count, mucus = s.mucusDay.filter { $0.key >= since }.count, lh = s.lhPositive.filter { $0 >= since }.count
        if temps + mucus + lh > 0 { out.append(("Fertility signs", [tr("Waking temperature on \(temps) days, cervical mucus on \(mucus) days, positive ovulation tests on \(lh) days")])) }

        let bc = BirthControl.shared
        if bc.method != .none { out.append(("Birth control", [tr(bc.method.label) + (bc.start.map { " · " + tr("started \($0.formatted(date: .numeric, time: .omitted))") } ?? "")])) }

        let moods = CycleMoodTests.shared.mood.filter { $0.key >= since }
        var mood: [String] = []
        if !moods.isEmpty { mood.append(tr("Mood logged on \(moods.count) days, average \(String(format: "%.1f", Double(moods.values.reduce(0, +)) / Double(moods.count))) out of 5")) }
        let sev = SeverityLog.shared.log.filter { $0.key >= since }
        if !sev.isEmpty {
            let pain = Double(sev.values.compactMap(\.first).reduce(0, +)) / Double(sev.count)
            mood.append(tr("Symptom severity rated on \(sev.count) days, average pain \(String(format: "%.1f", pain)) out of 10"))
        }
        if !mood.isEmpty { out.append(("Mood and symptoms", mood)) }

        let tests = CycleMoodTests.shared.tests.suffix(5)
        if !tests.isEmpty { out.append(("Pregnancy tests", tests.map { "\($0.first ?? ""): \(tr($0.last ?? ""))" })) }
        if let due = PregnancyMode.shared.due { out.append(("Pregnancy", [tr("Due date \(due.formatted(date: .long, time: .omitted))")])) }
        return out
    }
}

struct DoctorSummaryButton: View {
    @EnvironmentObject var store: AppStore
    @State private var url: URL?
    var body: some View {
        if let url {
            ShareLink(item: url) { T("Share my doctor summary (PDF)").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
        } else {
            Button { url = DoctorSummary.pdf(store) } label: { T("Summary for my doctor (PDF)").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
        }
    }
}
