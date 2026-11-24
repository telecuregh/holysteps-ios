import SwiftUI

/// Android's Body & energy (data/BodyEnergy.kt, ui/screens/BodyEnergyScreen.kt): one daily log for perimenopause and
/// menopause, arthritis, thyroid conditions and chronic pain. A flare or an empty day becomes a rest day (no step
/// goal); a low day eases the goal. Everything stays on the phone; it never diagnoses.
enum BodyEnergy {
    struct Condition: Identifiable, Hashable {
        let id, label, short, emoji: String
        let symptoms: [(String, String)]
        static func == (a: Condition, b: Condition) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }
    static let conditions: [Condition] = [
        Condition(id: "menopause", label: "Perimenopause or menopause", short: "Menopause", emoji: "🌸", symptoms: [
            ("hot_flash", "Hot flashes"), ("night_sweat", "Night sweats"), ("poor_sleep", "Poor sleep"), ("brain_fog", "Brain fog"),
            ("joint_ache", "Joint aches"), ("low_mood", "Low mood"), ("anxious", "Anxious"), ("racing_heart", "Racing heart"),
            ("headache", "Headache"), ("irregular_period", "Irregular period"), ("dryness", "Dryness")]),
        Condition(id: "arthritis", label: "Arthritis or autoimmune (RA, OA, lupus, psoriatic)", short: "Arthritis", emoji: "🦴", symptoms: [
            ("joint_pain", "Joint pain"), ("swelling", "Swelling"), ("stiffness", "Stiffness"), ("fatigue", "Fatigue"), ("hands", "Hands"),
            ("knees", "Knees"), ("hips", "Hips"), ("feet", "Feet or ankles"), ("back", "Back"), ("rash", "Rash"), ("low_fever", "Feeling feverish")]),
        Condition(id: "thyroid", label: "Thyroid (underactive or overactive)", short: "Thyroid", emoji: "🦋", symptoms: [
            ("tired", "Tired"), ("cold", "Feeling cold"), ("hot", "Feeling hot"), ("racing_heart", "Racing heart"), ("brain_fog", "Brain fog"),
            ("shaky", "Shaky"), ("low_mood", "Low mood"), ("hair", "Hair shedding"), ("constipation", "Constipation"), ("weight", "Weight change")]),
        Condition(id: "chronic_pain", label: "Chronic pain, fibromyalgia or ME/CFS", short: "Chronic pain", emoji: "🔋", symptoms: [
            ("widespread_pain", "Widespread pain"), ("crash", "Crash after activity"), ("brain_fog", "Brain fog"),
            ("unrefreshing_sleep", "Unrefreshing sleep"), ("headache", "Headache"), ("dizzy_standing", "Dizzy on standing"), ("sore_muscles", "Sore muscles")]),
    ]

    struct Day: Codable, Equatable {
        var date: String
        var energy = 0, pain = 0, sleep = 0, mood = 0
        var flare = false
        var symptoms: [String] = []
        var hotFlashes = -1, stiffMinutes = -1
        var dose: Bool?
        var note = ""
        var rated: Bool { energy > 0 || pain > 0 || sleep > 0 || mood > 0 || flare }
    }

    static let energyLabels = ["Empty", "Low", "Okay", "Good", "Full of energy"]
    static let painLabels = ["None", "Mild", "Moderate", "Bad", "Severe"]
    static let sleepLabels = ["Awful", "Poor", "Okay", "Good", "Great"]
    static let moodLabels = ["Very low", "Low", "Okay", "Good", "Great"]

    struct Adjust { let multiplier: Double; let rest: Bool; let reasons: [String] }
    static func isRest(_ d: Day?) -> Bool { guard let d else { return false }; return d.flare || d.energy == 1 || d.pain == 5 }
    static func adjust(_ d: Day?) -> Adjust {
        guard let d, d.rated else { return Adjust(multiplier: 1, rest: false, reasons: []) }
        if d.flare { return Adjust(multiplier: 0, rest: true, reasons: ["A flare day. Rest is the plan today, and your streak is safe."]) }
        if d.pain == 5 { return Adjust(multiplier: 0, rest: true, reasons: ["Severe pain this morning. Rest today; your streak is safe."]) }
        if d.energy == 1 { return Adjust(multiplier: 0, rest: true, reasons: ["Your energy is empty today. Rest is the plan, and your streak is safe."]) }
        var m = 1.0, r: [String] = []
        if d.energy == 2 { m *= 0.6; r.append("Low energy today: your goal is 40% lower.") }
        if d.energy == 3 { m *= 0.85; r.append("Okay energy today: your goal is 15% lower.") }
        if d.pain == 4 && m > 0.6 { m = 0.6; r.append("Bad pain today: your goal is 40% lower.") }
        if d.sleep == 1 && m > 0.85 { m = 0.85; r.append("An awful night: your goal is 15% lower.") }
        return Adjust(multiplier: m, rest: false, reasons: r)
    }

    // MARK: Storage (on this phone)

    static var chosen: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "bodyConditions") ?? []) }
        set { UserDefaults.standard.set(conditions.map(\.id).filter { newValue.contains($0) }, forKey: "bodyConditions") }
    }
    static var days: [Day] {
        get { UserDefaults.standard.data(forKey: "bodyDays").flatMap { try? JSONDecoder().decode([Day].self, from: $0) } ?? [] }
        set { if let d = try? JSONEncoder().encode(Array(newValue.sorted { $0.date < $1.date }.suffix(730))) { UserDefaults.standard.set(d, forKey: "bodyDays") } }
    }
    static func today(_ key: String = AppStore.dayKey()) -> Day? { days.last { $0.date == key } }
    static func save(_ d: Day) { var all = days; all.removeAll { $0.date == d.date }; all.append(d); days = all; ActivityLog.shared.add(.tracker) }
    /// How today's log changes the step goal (no change when the tracker is off or today isn't logged).
    static var todayAdjust: Adjust { chosen.isEmpty ? adjust(nil) : adjust(today()) }

    // MARK: Trends and patterns

    static func plus(_ key: String, _ n: Int) -> String {
        guard let d = AppStore.date(fromKey: key), let r = Calendar.current.date(byAdding: .day, value: n, to: d) else { return key }
        return AppStore.dayKey(r)
    }
    static func window(_ n: Int, today: String = AppStore.dayKey()) -> [Day] {
        let from = plus(today, -(n - 1))
        return days.filter { $0.date >= from && $0.date <= today }
    }
    static func avg(_ w: [Day], _ sel: (Day) -> Int) -> Double? {
        let v = w.map(sel).filter { $0 > 0 }
        return v.isEmpty ? nil : Double(v.reduce(0, +)) / Double(v.count)
    }
    static func one(_ v: Double) -> String { String(format: "%.1f", v) }
    static func series(_ n: Int, _ sel: (Day) -> Int) -> [Int] {
        let by = Dictionary(days.map { ($0.date, $0) }, uniquingKeysWith: { $1 }), today = AppStore.dayKey()
        return (0..<n).reversed().map { by[plus(today, -$0)].map(sel) ?? 0 }
    }

    static func patterns(steps: [String: Int]) -> [String] {
        var out: [String] = []
        let today = AppStore.dayKey()
        let past = days.filter { $0.date <= today }
        let by = Dictionary(past.map { ($0.date, $0) }, uniquingKeysWith: { $1 })
        func mean(_ a: [Int]) -> Double { Double(a.reduce(0, +)) / Double(max(1, a.count)) }

        let pairs = past.filter { $0.hotFlashes >= 0 }.compactMap { d -> (Int, Int)? in
            let next = by[plus(d.date, 1)]?.sleep ?? 0
            return next > 0 ? (d.hotFlashes, next) : nil
        }
        let many = pairs.filter { $0.0 >= 4 }.map(\.1), few = pairs.filter { $0.0 < 4 }.map(\.1)
        if many.count >= 3 && few.count >= 3, abs(mean(many) - mean(few)) >= 0.5 {
            out.append("After days with 4 or more hot flashes, you rated your sleep \(one(mean(many))) out of 5, vs \(one(mean(few))) after calmer days.")
        }

        let walked = steps.filter { $0.key < today && $0.value > 0 }
        let sorted = walked.values.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        if median > 0 {
            var big = 0, bigFlare = 0, other = 0, otherFlare = 0
            for (date, s) in walked {
                let next = [1, 2].map { by[plus(date, $0)] }
                if next.allSatisfy({ $0 == nil || !$0!.rated }) { continue }
                let flared = next.contains { $0 != nil && ($0!.flare || $0!.pain >= 4) }
                if Double(s) > Double(median) * 1.3 { big += 1; if flared { bigFlare += 1 } } else { other += 1; if flared { otherFlare += 1 } }
            }
            if big >= 3 && other >= 3 {
                let a = Double(bigFlare) * 100 / Double(big), b = Double(otherFlare) * 100 / Double(other)
                if a - b >= 15 { out.append("A flare or bad pain followed \(Int(a.rounded()))% of your big walking days within 2 days, vs \(Int(b.rounded()))% of steadier days. Spreading steps out may help.") }
                else if b - a >= 15 { out.append("Your bigger walking days weren't followed by more flares (\(Int(a.rounded()))% vs \(Int(b.rounded()))% after steadier days).") }
            }
            var more: [Int] = [], less: [Int] = []
            for (date, s) in walked {
                let e = by[plus(date, 1)]?.energy ?? 0
                if e <= 0 { continue }
                if s >= median { more.append(e) } else { less.append(e) }
            }
            if more.count >= 4 && less.count >= 4, abs(mean(more) - mean(less)) >= 0.4 {
                out.append("The day after walking \(median.formatted()) steps or more, your energy was \(one(mean(more))) out of 5, vs \(one(mean(less))) after quieter days.")
            }
        }
        let good = past.filter { $0.sleep >= 4 && $0.energy > 0 }.map(\.energy)
        let poor = past.filter { (1...2).contains($0.sleep) && $0.energy > 0 }.map(\.energy)
        if good.count >= 3 && poor.count >= 3, mean(good) - mean(poor) >= 0.5 {
            out.append("After a good night your energy was \(one(mean(good))) out of 5, vs \(one(mean(poor))) after a poor one. Protecting sleep may be your best lever.")
        }
        return out
    }

    static func report(name: String, steps: [String: Int]) -> String {
        let n = 30, today = AppStore.dayKey(), from = plus(today, -(n - 1))
        let w = window(n).filter { $0.rated || $0.hotFlashes >= 0 || $0.stiffMinutes >= 0 || $0.dose != nil }
        let chosenC = conditions.filter { chosen.contains($0.id) }
        func f(_ v: Double?) -> String { v.map { one($0) + " / 5" } ?? "not logged" }
        var s = "Body & energy log" + (name.isEmpty ? "" : " for \(name)") + "\n\(from) to \(today) (\(w.count) of \(n) days logged)\n"
        if !chosenC.isEmpty { s += "Tracking: " + chosenC.map(\.short).joined(separator: ", ") + "\n" }
        s += "\nAverages (energy, sleep and mood 1 = very low … 5 = great; pain 1 = none … 5 = severe)\n"
        s += "• Energy: \(f(avg(w, \.energy)))\n• Pain: \(f(avg(w, \.pain)))\n• Sleep: \(f(avg(w, \.sleep)))\n• Mood: \(f(avg(w, \.mood)))\n• Flare days: \(w.filter(\.flare).count)\n"
        let hf = w.filter { $0.hotFlashes >= 0 }.map(\.hotFlashes)
        if !hf.isEmpty { s += "• Hot flashes: \(one(Double(hf.reduce(0, +)) / Double(hf.count))) a day on average\n" }
        let st = w.filter { $0.stiffMinutes >= 0 }.map(\.stiffMinutes)
        if !st.isEmpty { s += "• Morning stiffness: \(Int((Double(st.reduce(0, +)) / Double(st.count)).rounded())) minutes on average\n" }
        let dl = w.filter { $0.dose != nil }
        if !dl.isEmpty { s += "• Daily dose: taken on \(dl.filter { $0.dose == true }.count) of \(dl.count) days logged\n" }
        let walked = (0..<n).compactMap { steps[plus(today, -$0)] }.filter { $0 > 0 }
        if !walked.isEmpty { s += "• Steps: \((walked.reduce(0, +) / walked.count).formatted()) a day on average (\(walked.count) days with steps)\n" }
        let labels = Dictionary(chosenC.flatMap(\.symptoms), uniquingKeysWith: { a, _ in a })
        let counts = Dictionary(grouping: w.flatMap(\.symptoms).filter { labels[$0] != nil }, by: { $0 }).mapValues(\.count)
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(5)
        if !counts.isEmpty { s += "\nMost logged symptoms\n" + counts.map { "• \(labels[$0.key]!): \($0.value) day\($0.value == 1 ? "" : "s")" }.joined(separator: "\n") + "\n" }
        let pats = patterns(steps: steps)
        if !pats.isEmpty { s += "\nPatterns in this log\n" + pats.map { "• " + $0 }.joined(separator: "\n") + "\n" }
        let notes = window(n).filter { !$0.note.isEmpty }.suffix(10)
        if !notes.isEmpty { s += "\nNotes\n" + notes.map { "• \($0.date): \($0.note)" }.joined(separator: "\n") + "\n" }
        return s + "\nLogged by the person in the HolySteps app. Not a medical record or a diagnosis."
    }

    static func tips(_ id: String) -> [String] {
        switch id {
        case "menopause": ["Slow, paced breathing (in 5, out 5) as a hot flash starts can take the edge off. It's in Breath pace.",
                           "Layers you can take off, a cool bedroom and a fan by the bed help with night sweats.",
                           "Strength work twice a week protects bones and muscle, which both thin after menopause. Walking counts toward bones too.",
                           "Morning daylight and a steady bedtime help sleep that hot flashes keep breaking.",
                           "Hormone therapy and non-hormone treatments both help many women. Ask your doctor which suits you; bring this log."]
        case "arthritis": ["Gentle movement keeps joints working: short walks spread through the day are often easier than one long one.",
                           "A warm shower or a warm pack eases morning stiffness before you set out.",
                           "On a flare day, rest the sore joints and move them gently through their range a few times.",
                           "Cushioned, supportive shoes and flat routes ease knees, hips and feet.",
                           "If one joint suddenly becomes hot, red and very swollen, especially with a fever, get medical help the same day."]
        case "thyroid": ["Take your tablet the way your prescription label says. Many thyroid tablets are taken on an empty stomach, 30 to 60 minutes before breakfast, and apart from calcium or iron.",
                         "Taking it at the same time every day keeps your levels steady.",
                         "Tiredness, feeling cold, a racing heart or shakiness that's new or worse is worth a blood test; ask your doctor.",
                         "Walking helps energy and mood with an underactive thyroid. With an overactive one, keep walks easy until your doctor says your levels are settled."]
        default: ["Pacing helps most: keep good days close to your usual so they don't turn into a crash a day or two later.",
                  "Break walks into short pieces with rests in between, and stop before you feel spent.",
                  "A flare is a rest day, not a failure. Your streak stays safe."]
        }
    }
    static let urgent = ["Chest pain, trouble breathing, or fainting: call emergency services.",
                         "A sudden, severe headache, weakness on one side, or trouble speaking: call emergency services.",
                         "A hot, red, very swollen joint with a fever: see a doctor the same day.",
                         "Pain, tiredness or low mood that's getting worse week by week: book a visit with your doctor."]
    static let verses: [(String, String)] = [
        ("Isaiah 40:31", "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint."),
        ("2 Corinthians 12:9", "And he said unto me, My grace is sufficient for thee: for my strength is made perfect in weakness."),
        ("Matthew 11:28", "Come unto me, all ye that labour and are heavy laden, and I will give you rest."),
        ("Psalm 73:26", "My flesh and my heart faileth: but God is the strength of my heart, and my portion for ever."),
        ("Psalm 139:14", "I will praise thee; for I am fearfully and wonderfully made: marvellous are thy works; and that my soul knoweth right well."),
        ("Isaiah 46:4", "And even to your old age I am he; and even to hoar hairs will I carry you: I have made, and I will bear; even I will carry, and deliver you."),
        ("Psalm 4:8", "I will both lay me down in peace, and sleep: for thou, LORD, only makest me dwell in safety."),
        ("Lamentations 3:22-23", "It is of the LORD's mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness."),
    ]
    static let prayers = ["Lord, You know this body better than I do. Give me strength for what today asks, and peace to rest when it asks for rest.",
                          "Father, on the days I can't do much, remind me that Your love for me isn't measured in steps.",
                          "Jesus, You touched the sick and gave rest to the weary. Be near me in the pain, and guide the hands of those who care for me."]
    /// Java's String.hashCode, so each day picks the same verse and prayer as Android.
    static func javaHash(_ s: String) -> Int32 { s.utf16.reduce(Int32(0)) { $0 &* 31 &+ Int32($1) } }
    static func pick<T>(_ list: [T], _ h: Int32) -> T { list[Int((Int(h) % list.count + list.count) % list.count)] }
}

struct BodyEnergyView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var steps = StepsModel.shared
    @State private var chosen = BodyEnergy.chosen
    @State private var editing = false
    @State private var day = BodyEnergy.today() ?? BodyEnergy.Day(date: AppStore.dayKey())
    @State private var saved = BodyEnergy.today() != nil
    @State private var confirmDelete = false
    private let teal = Color(hex: 0x14B8A6)

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🔋 BODY & ENERGY").font(.hs(11, .semibold)).foregroundStyle(HS.readable(0x14B8A6)).tracking(1.4)
                    T("How your body is today").font(.hs(24)).foregroundStyle(HS.text)
                    if chosen.isEmpty || editing { picker } else { tracker }
                }
                .padding(20).padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(tr("Delete your Body & energy log?"), isPresented: $confirmDelete) {
            Button(tr("Delete"), role: .destructive) { BodyEnergy.days = []; day = .init(date: AppStore.dayKey()); saved = false }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("This removes every day you've logged on this phone. It can't be undone.") }
    }

    @ViewBuilder private var picker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T("What are you living with?").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                T("Pick any that apply. You can change this any time.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                ForEach(BodyEnergy.conditions) { c in
                    let on = chosen.contains(c.id)
                    Button { if on { chosen.remove(c.id) } else { chosen.insert(c.id) } } label: {
                        HStack {
                            D(c.emoji); T(c.label).font(.hs(14)).foregroundStyle(HS.text)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? teal : HS.textMuted)
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(on ? teal.opacity(0.14) : HS.overlay(0.03)))
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                }
                GoldButton(title: "Save") { BodyEnergy.chosen = chosen; editing = false }.disabled(chosen.isEmpty).opacity(chosen.isEmpty ? 0.5 : 1)
                if editing { Button { chosen = BodyEnergy.chosen; editing = false } label: { T("Cancel").font(.hs(13)).foregroundStyle(HS.textMuted) } }
            }
        }
        if BodyEnergy.chosen.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    T("How it works").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                    ForEach(["A five-second check each day: energy, pain, sleep, mood, and whether it's a flare.",
                             "A flare or an empty day becomes a rest day: no step goal, and your walking streak is safe.",
                             "A low day eases your goal, so you're never pushed into a crash.",
                             "Over time you see your own patterns, and can share a 30-day summary with your doctor.",
                             "It stays on this phone. It's a log, not medical advice."], id: \.self) { T("✓ " + $0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }
            }
        }
    }

    @ViewBuilder private var tracker: some View {
        let conds = BodyEnergy.conditions.filter { chosen.contains($0.id) }
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                scale("Energy", BodyEnergy.energyLabels, $day.energy)
                scale("Pain", BodyEnergy.painLabels, $day.pain)
                scale("Sleep last night", BodyEnergy.sleepLabels, $day.sleep)
                scale("Mood", BodyEnergy.moodLabels, $day.mood)
                Toggle(isOn: $day.flare) {
                    VStack(alignment: .leading, spacing: 1) {
                        T("🔥 It's a flare day").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        T("Rest is the plan: no step goal, streak safe").font(.hs(12)).foregroundStyle(HS.textSecondary)
                    }
                }
                .tint(teal)
                T("Anything else today?").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                let syms = conds.flatMap(\.symptoms).reduce(into: [(String, String)]()) { acc, s in if !acc.contains(where: { $0.0 == s.0 }) { acc.append(s) } }
                FlowChips(items: syms.map { ($0.0, tr($0.1)) }, selected: Set(day.symptoms)) { id in
                    if let i = day.symptoms.firstIndex(of: id) { day.symptoms.remove(at: i) } else { day.symptoms.append(id) }
                }
                if chosen.contains("menopause") {
                    Stepper(value: Binding(get: { max(0, day.hotFlashes) }, set: { day.hotFlashes = min(60, $0) }), in: 0...60) {
                        D(tr("Hot flashes today") + ": \(max(0, day.hotFlashes))").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    }
                }
                if chosen.contains("arthritis") {
                    Stepper(value: Binding(get: { max(0, day.stiffMinutes) }, set: { day.stiffMinutes = min(600, $0) }), in: 0...600, step: 5) {
                        D(tr("Morning stiffness") + ": " + tr("\(max(0, day.stiffMinutes)) min")).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    }
                }
                if chosen.contains("thyroid") {
                    Toggle(isOn: Binding(get: { day.dose == true }, set: { day.dose = $0 })) { T("I took today's dose").font(.hs(13, .semibold)).foregroundStyle(HS.text) }.tint(teal)
                }
                TextField(tr("A note (optional)"), text: $day.note, axis: .vertical).lineLimit(1...3).font(.hs(14))
                    .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.04)))
                    .onChange(of: day.note) { _, v in if v.count > 240 { day.note = String(v.prefix(240)) } }
                GoldButton(title: saved ? "Update today" : "Save today") {
                    BodyEnergy.save(day); saved = true
                }
            }
        }
        let adj = BodyEnergy.adjust(saved ? BodyEnergy.today() : nil)
        if saved {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    T(adj.rest ? "Today is a rest day" : adj.multiplier < 1 ? "Today's goal is gentler" : "A normal day for your goal").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    ForEach(adj.reasons, id: \.self) { T($0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    if !adj.rest { D(tr("Today's step goal: \(Int(Double(store.stepGoal) * adj.multiplier).formatted())")).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }
            }
        }
        if chosen.contains("menopause") {
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    T("🌬️ A hot flash starting?").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T("Slow, paced breathing (in 5, out 5) can take the edge off.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    NavigationLink { BreathPaceView() } label: { T("Open Breath pace").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                }
            }
        }
        SectionHeader(title: "Your last 30 days").padding(.horizontal, -20)
        trend
        let pats = BodyEnergy.patterns(steps: steps.stepsByDay)
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                T("🔎 Your patterns").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                if pats.isEmpty { T("Keep logging. Patterns show up here once there are enough days to compare (usually 2 to 3 weeks).").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                ForEach(pats, id: \.self) { T("• " + $0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
            }
        }
        ShareLink(item: BodyEnergy.report(name: store.name, steps: steps.stepsByDay)) {
            T("Share 30 days with my doctor").font(.hs(14, .semibold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Capsule().fill(HS.goldButton))
        }
        SectionHeader(title: "Caring for your body").padding(.horizontal, -20)
        ForEach(conds) { c in
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    D(c.emoji + " " + tr(c.short)).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    ForEach(BodyEnergy.tips(c.id), id: \.self) { T("• " + $0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }
            }
        }
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                T("🚨 Get help").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                ForEach(BodyEnergy.urgent, id: \.self) { T("! " + $0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
            }
        }
        let h = BodyEnergy.javaHash(AppStore.dayKey())
        let verse = BodyEnergy.pick(BodyEnergy.verses, h)
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                D(verse.1).font(.accent(16)).foregroundStyle(HS.italic)
                D("— " + verse.0 + " (KJV)").font(.hs(12)).foregroundStyle(HS.textMuted)
                D("🙏 " + tr(BodyEnergy.pick(BodyEnergy.prayers, h / 7))).font(.hs(13)).foregroundStyle(HS.textSecondary).padding(.top, 4)
            }
        }
        HStack(spacing: 8) {
            Button { editing = true } label: { T("Change conditions").font(.hs(13, .semibold)).foregroundStyle(teal).frame(maxWidth: .infinity).padding(.vertical, 11).overlay(Capsule().strokeBorder(teal.opacity(0.5))) }
            Button { confirmDelete = true } label: { T("Delete my log").font(.hs(13, .semibold)).foregroundStyle(Color(hex: 0xF87171)).frame(maxWidth: .infinity).padding(.vertical, 11).overlay(Capsule().strokeBorder(Color(hex: 0xF87171).opacity(0.5))) }
        }
        T("Everything here stays on this phone. HolySteps doesn't diagnose or treat anything; talk with your doctor about your care.").font(.hs(11)).foregroundStyle(HS.textMuted)
    }

    private var trend: some View {
        let w = BodyEnergy.window(30).filter(\.rated)
        func f(_ v: Double?) -> String { v.map(BodyEnergy.one) ?? "–" }
        return GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                if w.isEmpty { T("Nothing logged yet. Your trends appear here after a few days.").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                else {
                    T("Energy").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    bars(BodyEnergy.series(30, \.energy), teal)
                    T("Pain").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    bars(BodyEnergy.series(30, \.pain), Color(hex: 0xF87171))
                    D(tr("Logged \(w.count) of 30 days · flare days \(w.filter(\.flare).count)")).font(.hs(12)).foregroundStyle(HS.textSecondary)
                    D(tr("Average energy \(f(BodyEnergy.avg(w, \.energy))) · pain \(f(BodyEnergy.avg(w, \.pain))) · sleep \(f(BodyEnergy.avg(w, \.sleep))) · mood \(f(BodyEnergy.avg(w, \.mood)))"))
                        .font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
            }
        }
    }

    private func bars(_ v: [Int], _ c: Color) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(v.enumerated()), id: \.offset) { _, x in
                RoundedRectangle(cornerRadius: 2).fill(x > 0 ? c : HS.overlay(0.08)).frame(height: x > 0 ? CGFloat(x) * 8 : 3).frame(maxWidth: .infinity)
            }
        }
        .frame(height: 40, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func scale(_ title: String, _ labels: [String], _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                T(title).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                Spacer()
                if value.wrappedValue > 0 { T(labels[value.wrappedValue - 1]).font(.hs(12)).foregroundStyle(HS.readable(0x14B8A6)) }
            }
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    let on = value.wrappedValue == i
                    Button { value.wrappedValue = on ? 0 : i } label: {
                        D("\(i)").font(.hs(14, .semibold)).foregroundStyle(on ? .white : HS.text).frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(on ? teal : HS.overlay(0.05)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr(title) + ": " + tr(labels[i - 1]))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// Wrapping chips (symptoms and similar).
struct FlowChips: View {
    let items: [(String, String)]
    let selected: Set<String>
    let onTap: (String) -> Void
    var body: some View {
        ChipLayout(spacing: 6) {
            ForEach(items, id: \.0) { id, label in
                let on = selected.contains(id)
                Button { onTap(id) } label: {
                    D(label).font(.hs(12, .medium)).foregroundStyle(on ? .white : HS.text).padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(on ? Color(hex: 0x14B8A6) : HS.overlay(0.06)))
                }
                .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

struct ChipLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > w, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += sz.width + spacing; row = max(row, sz.height)
        }
        return CGSize(width: w, height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > b.maxX, x > b.minX { x = b.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; row = max(row, sz.height)
        }
    }
}

/// Android's BodyEnergyEntryCard: opens the Body & energy log (part of the Cycle or Wellness plan).
struct BodyEnergyEntryCard: View {
    @State private var open = false
    var body: some View {
        let on = !BodyEnergy.chosen.isEmpty
        let day = BodyEnergy.today()
        Button { open = true } label: {
            HStack(spacing: 10) {
                D("🔋").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    T(on ? "Body & energy" : "Living with menopause, arthritis, thyroid or chronic pain?").font(.hs(15, .bold)).foregroundStyle(HS.text)
                    D(tr(!on ? "A daily check that turns flare days into rest days and shows your patterns."
                         : day?.rated == true ? (BodyEnergy.todayAdjust.rest ? "Logged ✓ · a rest day for your body" : "Logged ✓ · energy \(day!.energy > 0 ? "\(day!.energy)" : "–")/5")
                         : "How is your body today? Five seconds to log.")).font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x14B8A6).opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0x14B8A6).opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $open) {
            NavigationStack {
                Gated(feature: .bodyEnergy) { BodyEnergyView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(HSBackground())
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Close")) { open = false } } }
            }
        }
    }
}
