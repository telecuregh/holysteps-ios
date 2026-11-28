import SwiftUI
import HealthKit
import UserNotifications

// Body basics on iOS, matching Android (data/BodyBasics.kt, data/HealthHelper.kt): food & water, know your numbers
// (with the pregnancy blood-pressure rules), habits, medicine and vitamin reminders, and bringing period history and
// waking temperatures in from Apple Health. Kept on this phone; information, never a diagnosis.

// MARK: - Store

final class BodyStore: ObservableObject {
    static let shared = BodyStore()
    private let d = UserDefaults.standard

    /// date -> [water glasses (8 oz), protein servings]
    @Published private(set) var food: [String: [Int]] { didSet { d.set(food, forKey: "bodyFood") } }
    /// date -> [drinks, late caffeine 0/1, late screens 0/1, smoked 0/1]
    @Published private(set) var habits: [String: [Int]] { didSet { d.set(habits, forKey: "bodyHabits") } }
    /// [date, kind, value, value2]
    @Published private(set) var readings: [[String]] { didSet { d.set(readings, forKey: "bodyReadings") } }
    @Published var heightIn: Int { didSet { d.set(heightIn, forKey: "bodyHeightIn") } }

    private init() {
        food = d.dictionary(forKey: "bodyFood") as? [String: [Int]] ?? [:]
        habits = d.dictionary(forKey: "bodyHabits") as? [String: [Int]] ?? [:]
        readings = d.array(forKey: "bodyReadings") as? [[String]] ?? []
        heightIn = d.integer(forKey: "bodyHeightIn")
    }

    var today: [Int] { food[AppStore.dayKey()] ?? [0, 0] }
    func add(water: Int = 0, protein: Int = 0) {
        var t = today
        t[0] = min(30, max(0, t[0] + water)); t[1] = min(20, max(0, t[1] + protein))
        food[AppStore.dayKey()] = t
    }
    var habitsToday: [Int] { habits[AppStore.dayKey()] ?? [0, 0, 0, 0] }
    func setHabit(_ i: Int, _ v: Int) { var h = habitsToday; h[i] = max(0, min(20, v)); habits[AppStore.dayKey()] = h }
    func addReading(_ kind: NumberKind, _ v: Double, _ v2: Double?) {
        readings.append([AppStore.dayKey(), kind.rawValue, String(v), v2.map { String($0) } ?? ""])
    }
    func removeReading(_ i: Int) { if readings.indices.contains(i) { readings.remove(at: i) } }
}

enum NumberKind: String, CaseIterable, Identifiable {
    case weight, waist, bp, rhr, chol, ldl, hdl, glucose, a1c
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weight: return "Weight"; case .waist: return "Waist"; case .bp: return "Blood pressure"; case .rhr: return "Resting heart rate"
        case .chol: return "Total cholesterol"; case .ldl: return "LDL cholesterol"; case .hdl: return "HDL cholesterol"
        case .glucose: return "Fasting blood sugar"; case .a1c: return "A1C"
        }
    }
    var unit: String {
        switch self { case .weight: return "lb"; case .waist: return "in"; case .bp: return "mmHg"; case .rhr: return "bpm"; case .a1c: return "%"; default: return "mg/dL" }
    }
}

enum Numbers {
    enum Band { case good, watch, high, urgent }
    struct Verdict { let band: Band; let words: String }

    /// [perinatal]: pregnant, or gave birth within the last year: blood pressure follows the pregnancy rules (ACOG, AHA,
    /// CDC Hear Her): 160/110 or higher needs a call now, 140/90 or higher a call today.
    static func judge(_ k: NumberKind, _ v: Double, _ v2: Double?, male: Bool, heightIn: Int, perinatal: Bool) -> Verdict? {
        switch k {
        case .bp:
            let s = v, dia = v2 ?? 0
            if perinatal && (s >= 160 || dia >= 110) { return .init(band: .urgent, words: "Very high for pregnancy or after birth. Call your doctor, midwife or labor and delivery now. Call 911 if you also have a severe headache, vision changes, chest pain, trouble breathing, confusion or a seizure.") }
            if perinatal && (s >= 140 || dia >= 90) { return .init(band: .high, words: "High for pregnancy or after birth. Call your doctor or midwife today, and sooner if you have a headache, vision changes, belly pain or swelling of the face or hands.") }
            if s > 180 || dia > 120 { return .init(band: .urgent, words: "Very high. If you also have chest pain, shortness of breath, weakness or trouble speaking, call 911. Otherwise, wait a few minutes, check again, and call your doctor today.") }
            if s >= 140 || dia >= 90 { return .init(band: .high, words: "High (stage 2). See your doctor soon.") }
            if s >= 130 || dia >= 80 { return .init(band: .high, words: "High (stage 1). Worth talking to your doctor.") }
            if s >= 120 { return .init(band: .watch, words: "Elevated. Walking, less salt and less alcohol help.") }
            return .init(band: .good, words: "Normal.")
        case .rhr:
            if v > 100 { return .init(band: .high, words: "Above the usual range (60 to 100). Mention it to your doctor if it stays there.") }
            if v < 50 { return .init(band: .watch, words: "Low. Common in fit people; see a doctor if you feel dizzy or faint.") }
            return .init(band: .good, words: "In the usual range.")
        case .chol: return v >= 240 ? .init(band: .high, words: "High.") : v >= 200 ? .init(band: .watch, words: "Borderline high.") : .init(band: .good, words: "Desirable.")
        case .ldl:
            if v >= 190 { return .init(band: .high, words: "Very high. Talk to your doctor.") }
            if v >= 160 { return .init(band: .high, words: "High.") }
            if v >= 130 { return .init(band: .watch, words: "Borderline high.") }
            if v >= 100 { return .init(band: .watch, words: "Near optimal.") }
            return .init(band: .good, words: "Optimal.")
        case .hdl:
            if v >= 60 { return .init(band: .good, words: "Good: this is the protective kind.") }
            if v < (male ? 40 : 50) { return .init(band: .watch, words: "Low. Exercise is one of the best ways to raise it.") }
            return .init(band: .good, words: "Fine.")
        case .glucose: return v >= 126 ? .init(band: .high, words: "In the diabetes range. See your doctor.") : v >= 100 ? .init(band: .watch, words: "In the prediabetes range. Walking after meals helps.") : .init(band: .good, words: "Normal.")
        case .a1c: return v >= 6.5 ? .init(band: .high, words: "In the diabetes range. See your doctor.") : v >= 5.7 ? .init(band: .watch, words: "In the prediabetes range.") : .init(band: .good, words: "Normal.")
        case .waist:
            let lim: Double = male ? 40 : 35
            return v > lim ? .init(band: .watch, words: "Above \(Int(lim)) inches, which raises heart and diabetes risk.") : .init(band: .good, words: "In a healthy range.")
        case .weight:
            guard (40...90).contains(heightIn), v > 0 else { return nil }
            let b = 703 * v / Double(heightIn * heightIn), t = String(format: "%.1f", b)
            if b >= 30 { return .init(band: .watch, words: "BMI \(t) (obesity range).") }
            if b >= 25 { return .init(band: .watch, words: "BMI \(t) (overweight range).") }
            if b < 18.5 { return .init(band: .watch, words: "BMI \(t) (underweight range).") }
            return .init(band: .good, words: "BMI \(t) (healthy range).")
        }
    }
}

// MARK: - Medicines

final class Medicines: ObservableObject {
    static let shared = Medicines()
    struct Med: Codable, Identifiable, Equatable { var id = UUID().uuidString; var name: String; var minutes: [Int] }
    @Published private(set) var meds: [Med] { didSet { save() } }
    /// date -> [med id] taken that day (one entry per dose)
    @Published private(set) var taken: [String: [String]] { didSet { UserDefaults.standard.set(taken, forKey: "medTaken") } }

    private init() {
        meds = (UserDefaults.standard.data(forKey: "medList")).flatMap { try? JSONDecoder().decode([Med].self, from: $0) } ?? []
        taken = UserDefaults.standard.dictionary(forKey: "medTaken") as? [String: [String]] ?? [:]
    }
    private func save() { UserDefaults.standard.set(try? JSONEncoder().encode(meds), forKey: "medList"); reschedule() }

    func upsert(_ m: Med) { if let i = meds.firstIndex(where: { $0.id == m.id }) { meds[i] = m } else { meds.append(m) } }
    func delete(_ id: String) { meds.removeAll { $0.id == id } }
    func takenCount(_ id: String) -> Int { (taken[AppStore.dayKey()] ?? []).filter { $0 == id }.count }
    func markTaken(_ id: String) { taken[AppStore.dayKey(), default: []].append(id) }
    func undoTaken(_ id: String) {
        var t = taken[AppStore.dayKey()] ?? []
        if let i = t.lastIndex(of: id) { t.remove(at: i) }
        taken[AppStore.dayKey()] = t
    }

    /// One repeating reminder per medicine time. The name never shows on the lock screen.
    func reschedule() {
        let c = UNUserNotificationCenter.current()
        c.getPendingNotificationRequests { reqs in
            c.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix("med-") })
            for m in self.meds {
                for mins in m.minutes {
                    let n = UNMutableNotificationContent()
                    n.title = tr("HolySteps reminder")
                    n.body = tr("Time for your \(timeText(mins)) medicine.")
                    n.sound = .default
                    var dc = DateComponents(); dc.hour = mins / 60; dc.minute = mins % 60
                    c.add(UNNotificationRequest(identifier: "med-\(m.id)-\(mins)", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
                }
            }
        }
        if !meds.isEmpty { c.requestAuthorization(options: [.alert, .sound]) { _, _ in } }
    }
}

// MARK: - Apple Health import (periods and waking temperatures)

enum HealthCycleImport {
    private static let health = HKHealthStore()

    /// Reads menstrual flow (5 years) and basal body temperature (120 days). Periods are marked days in a row with a
    /// one-day gap allowed; temperatures fill only days that have none yet. Returns (periods added, temps added).
    static func run(store: AppStore) async -> (Int, Int)? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let flow = HKCategoryType(.menstrualFlow), bbt = HKQuantityType(.basalBodyTemperature)
        do { try await health.requestAuthorization(toShare: [], read: [flow, bbt]) } catch { return nil }
        let flowDays = await samples(flow, days: 5 * 366).compactMap { s -> Date? in
            guard let c = s as? HKCategorySample, c.value != HKCategoryValueMenstrualFlow.none.rawValue else { return nil }
            return Calendar.current.startOfDay(for: c.startDate)
        }
        let days = Array(Set(flowDays)).sorted()
        var starts: [Date] = []
        var prev: Date?
        for day in days {
            if let p = prev, CycleLogic.days(p, day) <= 2 { prev = day; continue }
            starts.append(day); prev = day
        }
        var added = 0
        for st in starts where !store.periodStarts.contains(where: { abs(CycleLogic.days($0, st)) < 10 }) {
            store.logPeriodStart(st); added += 1
        }
        var temps = 0
        let fs = FertilitySigns.shared
        let tSamples = await samples(bbt, days: 120).compactMap { $0 as? HKQuantitySample }.sorted { $0.startDate < $1.startDate }
        for s in tSamples {
            let k = AppStore.dayKey(s.startDate)
            let f = s.quantity.doubleValue(for: .degreeFahrenheit())
            if fs.bbt[k] == nil && (94.0...101.5).contains(f) { fs.setTemp(f, day: k); temps += 1 }
        }
        return (added, temps)
    }

    private static func samples(_ t: HKSampleType, days: Int) async -> [HKSample] {
        await withCheckedContinuation { cont in
            let p = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-Double(days) * 86400), end: Date())
            let q = HKSampleQuery(sampleType: t, predicate: p, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, r, _ in cont.resume(returning: r ?? []) }
            health.execute(q)
        }
    }
}

struct HealthImportButton: View {
    @EnvironmentObject var store: AppStore
    @State private var msg = ""
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                busy = true
                Task { @MainActor in
                    let r = await HealthCycleImport.run(store: store)
                    busy = false
                    if let (p, t) = r {
                        msg = p + t == 0 ? tr("Apple Health had nothing new. Turn on sharing in your other app (Flo, Clue, a ring or watch) first.")
                            : tr("Added \(p) periods and \(t) days of temperature.")
                    } else { msg = tr("Apple Health isn't available or wasn't allowed.") }
                }
            } label: { T(busy ? "Reading Apple Health…" : "🔗 Bring periods and temperature from Apple Health").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
            .disabled(busy)
            if !msg.isEmpty { D(msg).font(.hs(11)).foregroundStyle(HS.textMuted) }
        }
    }
}

// MARK: - Screen

struct BodyBasicsView: View {
    /// One part on its own (Android has a screen for each); nil shows all four.
    enum Part { case food, numbers, habits, medicines }
    var part: Part? = nil
    @EnvironmentObject var store: AppStore
    @ObservedObject private var b = BodyStore.shared
    @ObservedObject private var meds = Medicines.shared
    @ObservedObject private var preg = PregnancyMode.shared
    @State private var kind: NumberKind = .bp
    @State private var v1 = ""
    @State private var v2 = ""
    @State private var editing: Medicines.Med?

    var body: some View {
        let t = b.today
        let male = store.gender == "male"
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("❤️ BODY").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF472B6))
                    T(heading).font(.hs(24)).foregroundStyle(HS.text)
                    T(intro).font(.hs(13)).foregroundStyle(HS.textSecondary)

                    if show(.food) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            T("💧 Food & water today").font(.hs(15, .bold)).foregroundStyle(HS.text)
                            stepper(tr("Water"), t[0], tr("of 8 glasses (8 oz)")) { b.add(water: $0) }
                            stepper(tr("Protein"), t[1], tr("servings (palm-sized)")) { b.add(protein: $0) }
                            T("Most adults do well with water through the day, a palm of protein at each meal, and half the plate vegetables and fruit (MyPlate).").font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                    }
                    }

                    if show(.numbers) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            T("📋 Know your numbers").font(.hs(15, .bold)).foregroundStyle(HS.text)
                            Picker(tr("Number"), selection: $kind) { ForEach(NumberKind.allCases) { Text(tr($0.label)).tag($0) } }
                            HStack {
                                TextField(kind == .bp ? tr("Top (120)") : kind.unit, text: $v1).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                                if kind == .bp { TextField(tr("Bottom (80)"), text: $v2).keyboardType(.numberPad).textFieldStyle(.roundedBorder) }
                                Button {
                                    if let x = Double(v1), x > 0 { b.addReading(kind, x, kind == .bp ? Double(v2) : nil); v1 = ""; v2 = "" }
                                } label: { T("Save").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                            }
                            if kind == .weight {
                                Stepper(value: $b.heightIn, in: 0...90) { D(b.heightIn > 0 ? tr("Height \(b.heightIn / 12) ft \(b.heightIn % 12) in") : tr("Add your height for BMI")).font(.hs(12)) }
                            }
                            ForEach(Array(b.readings.enumerated().reversed().prefix(8)), id: \.offset) { i, r in
                                if let k = NumberKind(rawValue: r[safe: 1] ?? ""), let x = Double(r[safe: 2] ?? "") {
                                    let y = Double(r[safe: 3] ?? "")
                                    let v = Numbers.judge(k, x, y, male: male, heightIn: b.heightIn, perinatal: preg.on || UserDefaults.standard.string(forKey: "cycleGoal") == "POSTPARTUM")
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            D("\(r.first ?? "") · \(tr(k.label)): \(k == .bp ? "\(Int(x))/\(Int(y ?? 0))" : String(format: x.rounded() == x ? "%.0f" : "%.1f", x)) \(k.unit)").font(.hs(12, .semibold)).foregroundStyle(HS.text)
                                            Spacer()
                                            Button { b.removeReading(i) } label: { Image(systemName: "xmark").font(.caption).foregroundStyle(HS.textMuted) }
                                        }
                                        if let v { T(v.words).font(.hs(11)).foregroundStyle(v.band == .urgent ? Color(hex: 0xF87171) : v.band == .high ? Color(hex: 0xF59E0B) : HS.textSecondary) }
                                    }
                                }
                            }
                            T("Ranges from the American Heart Association, the ADA and NIH. Your doctor knows your full picture.").font(.hs(10)).foregroundStyle(HS.textSubtle)
                        }
                    }
                    }

                    if show(.habits) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            T("🍷 Habits today").font(.hs(15, .bold)).foregroundStyle(HS.text)
                            let h = b.habitsToday
                            stepper(tr("Alcoholic drinks"), h[0], "") { b.setHabit(0, h[0] + $0) }
                            ForEach([(1, "Caffeine after 2 PM"), (2, "Screens in the last hour before bed"), (3, "Smoked or vaped")], id: \.0) { i, l in
                                Toggle(isOn: Binding(get: { h[i] == 1 }, set: { b.setHabit(i, $0 ? 1 : 0) })) { T(l).font(.hs(12)).foregroundStyle(HS.textSecondary) }.tint(HS.gold)
                            }
                            T("Want to quit smoking or vaping? Call 1-800-QUIT-NOW (free).").font(.hs(10)).foregroundStyle(HS.textSubtle)
                        }
                    }
                    }

                    if show(.medicines) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                T("💊 Medicine and vitamin reminders").font(.hs(15, .bold)).foregroundStyle(HS.text)
                                Spacer()
                                Button { editing = Medicines.Med(name: "", minutes: [9 * 60]) } label: { Image(systemName: "plus.circle").foregroundStyle(HS.gold) }
                            }
                            if meds.meds.isEmpty { T("Add a medicine or vitamin to get a private reminder at the times you take it.").font(.hs(12)).foregroundStyle(HS.textMuted) }
                            ForEach(meds.meds) { m in
                                let n = meds.takenCount(m.id)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        D(m.name).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                        D(m.minutes.sorted().map { timeText($0) }.joined(separator: " · ")).font(.hs(11)).foregroundStyle(HS.textMuted)
                                    }
                                    Spacer()
                                    if n >= m.minutes.count {
                                        Button { meds.undoTaken(m.id) } label: { T("✓ Taken").font(.hs(12, .bold)).foregroundStyle(Color(hex: 0x34D399)) }
                                    } else {
                                        Button { meds.markTaken(m.id) } label: { D(tr("Taken") + (m.minutes.count > 1 ? " \(n + 1)/\(m.minutes.count)" : "")).font(.hs(12, .semibold)).foregroundStyle(HS.gold) }
                                    }
                                    Button { editing = m } label: { Image(systemName: "pencil").foregroundStyle(HS.textMuted) }
                                }
                            }
                            T("Reminders never show the medicine's name on the lock screen. Ask your pharmacist before changing how you take a medicine.").font(.hs(10)).foregroundStyle(HS.textSubtle)
                        }
                    }
                    }
                }.padding(20)
            }
        }
        .sheet(item: $editing) { m in MedicineEditor(med: m) { editing = nil } }
    }

    private func show(_ p: Part) -> Bool { part == nil || part == p }

    private var heading: String {
        switch part {
        case .food: "Food & water"
        case .numbers: "Know your numbers"
        case .habits: "Habits"
        case .medicines: "Medicines & supplements"
        case nil: "Body basics"
        }
    }

    private var intro: String {
        switch part {
        case .food: "Water, protein and real food, today. Information, not a diagnosis."
        case .numbers: "Blood pressure, weight and your other health numbers, with the usual ranges. Information, not a diagnosis."
        case .habits: "Drinks, caffeine, screens and smoking, today."
        case .medicines: "Private reminders for pills, vitamins and supplements."
        case nil: "Water, food, your health numbers, habits and medicine reminders. Information, not a diagnosis."
        }
    }

    private func stepper(_ label: String, _ v: Int, _ unit: String, _ change: @escaping (Int) -> Void) -> some View {
        HStack {
            D(label).font(.hs(13, .semibold)).foregroundStyle(HS.text)
            Spacer()
            Button { change(-1) } label: { Image(systemName: "minus.circle").foregroundStyle(HS.textMuted) }
            D("\(v) \(unit)").font(.hs(13)).foregroundStyle(HS.textSecondary).frame(minWidth: 70)
            Button { change(1) } label: { Image(systemName: "plus.circle.fill").foregroundStyle(HS.gold) }
        }
    }
}

private func timeText(_ m: Int) -> String {
    let d = Calendar.current.date(byAdding: .minute, value: m, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    return d.formatted(date: .omitted, time: .shortened)
}

private struct MedicineEditor: View {
    @State var med: Medicines.Med
    let done: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                TextField(tr("Name (e.g. Vitamin D)"), text: $med.name)
                ForEach(med.minutes.indices, id: \.self) { i in
                    DatePicker(tr("Time \(i + 1)"), selection: Binding(
                        get: { Calendar.current.date(byAdding: .minute, value: med.minutes[i], to: Calendar.current.startOfDay(for: Date())) ?? Date() },
                        set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); med.minutes[i] = (c.hour ?? 9) * 60 + (c.minute ?? 0) }),
                               displayedComponents: .hourAndMinute)
                }
                if med.minutes.count < 6 { Button(tr("Add another time")) { med.minutes.append(21 * 60) } }
                if med.minutes.count > 1 { Button(tr("Remove last time"), role: .destructive) { med.minutes.removeLast() } }
                if Medicines.shared.meds.contains(where: { $0.id == med.id }) {
                    Button(tr("Delete this reminder"), role: .destructive) { Medicines.shared.delete(med.id); done() }
                }
            }
            .navigationTitle(D(tr("Medicine")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { done() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Save")) {
                        let n = med.name.trimmingCharacters(in: .whitespaces)
                        if !n.isEmpty { med.name = String(n.prefix(40)); Medicines.shared.upsert(med) }
                        done()
                    }
                }
            }
        }
    }
}
