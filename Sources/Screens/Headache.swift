import SwiftUI

/// Android's headache and migraine diary (data/HeadacheTracker.kt, HeadacheScreens.kt): what it felt like, what
/// helped, what the person thinks set it off, and what goes with their headaches over time (sleep, steps, the period
/// window). One entry per day; kept on this phone.
enum Headache {
    static let whereList = ["One side", "Both sides", "Forehead", "Behind the eyes", "Temples", "Back of the head", "Neck and shoulders"]
    static let symptoms = ["Aura (vision changes)", "Nausea", "Vomiting", "Light hurts", "Sound hurts", "Smells bother me",
                           "Dizziness", "Tingling or numbness", "Stiff neck", "Tired or foggy"]
    static let triggers = ["Stress", "Too little sleep", "Too much sleep", "Skipped a meal", "Not enough water", "Caffeine",
                           "Missed my usual caffeine", "Alcohol", "Screens", "Bright light", "Loud noise", "Strong smell", "Weather change",
                           "Period", "Hard workout", "Travel", "Certain food", "Posture or neck"]
    static let started = ["Woke up with it", "Morning", "Afternoon", "Evening", "Night"]
    static let lasted = ["Under 1 hour", "1–4 hours", "4–12 hours", "12–24 hours", "Over a day", "Still going"]
    static let relief = ["No relief", "A little", "Mostly", "Fully gone"]

    struct Entry: Codable, Equatable {
        var date: String
        var migraine = false
        var pain = 5
        var started = "", lasted = ""
        var where_: [String] = [], symptoms: [String] = [], triggers: [String] = []
        var medicine = ""
        var tookMeds = false
        var relief = -1
        var note = ""
    }
    static var entries: [Entry] {
        get { UserDefaults.standard.data(forKey: "headaches").flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? [] }
        set {
            let cut = AppStore.dayKey(Date().addingTimeInterval(-730 * 86400))
            if let d = try? JSONEncoder().encode(newValue.filter { $0.date >= cut }.sorted { $0.date < $1.date }) { UserDefaults.standard.set(d, forKey: "headaches") }
        }
    }
    static func save(_ e: Entry) { entries = entries.filter { $0.date != e.date } + [e]; ActivityLog.shared.add(.tracker) }

    static func namedTriggers() -> [(String, Int)] {
        Dictionary(grouping: entries.flatMap(\.triggers), by: { $0 }).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    struct Link { let emoji, label, tip: String; let withRate, withoutRate: Int }
    /// Android's links(): headache days against the days around them, factor by factor (5+ days each side, a clearly higher rate).
    static func links(sleepByDay: [String: Int], steps: [String: Int], periodWindow: @escaping (String) -> Bool?) -> [Link] {
        let all = entries
        guard let first = all.map(\.date).min(), let start = AppStore.date(fromKey: first) else { return [] }
        let hd = Set(all.map(\.date)), today = AppStore.dayKey()
        var dates: [String] = []
        var d = start
        while AppStore.dayKey(d) <= today { dates.append(AppStore.dayKey(d)); d = d.addingTimeInterval(86400) }
        guard dates.count >= 14, hd.count >= 3 else { return [] }
        let stepVals = dates.compactMap { steps[$0] }.filter { $0 > 0 }.sorted()
        let lowSteps = stepVals.count >= 14 ? stepVals[stepVals.count / 4] : nil
        func prev(_ k: String) -> String { BodyEnergy.plus(k, -1) }
        let factors: [(String, String, String, (String) -> Bool?)] = [
            ("😴", "Days after a short or poor night", "Keep the same bedtime every night, even on weekends.", { k in sleepByDay[k].map { $0 < 360 } }),
            ("🩸", "Your period window", "Plan gentler days and keep your treatment ready around your period.", periodWindow),
            ("🛋️", "Days after you barely moved", "A short walk most days can help.", { k in lowSteps.flatMap { lo in steps[prev(k)].flatMap { $0 > 0 ? $0 <= lo : nil } } }),
        ]
        var out: [Link] = []
        for f in factors {
            let w = dates.filter { f.3($0) == true }, wo = dates.filter { f.3($0) == false }
            guard w.count >= 5, wo.count >= 5 else { continue }
            let wr = w.filter { hd.contains($0) }.count * 100 / w.count, wor = wo.filter { hd.contains($0) }.count * 100 / wo.count
            if wr - wor >= 15 && wr >= 20 { out.append(Link(emoji: f.0, label: f.1, tip: f.2, withRate: wr, withoutRate: wor)) }
        }
        return out.sorted { $0.withRate - $0.withoutRate > $1.withRate - $1.withoutRate }
    }
}

struct HeadacheView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var steps = StepsModel.shared
    @State private var editing: Headache.Entry?
    @State private var refresh = 0

    var body: some View {
        let all = Headache.entries
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🤕 HEADACHES").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF43F5E))
                    T("Headache diary").font(.hs(24)).foregroundStyle(HS.text)
                    T("Log a headache or migraine in a few taps. Over time you'll see what goes with yours.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    GoldButton(title: Headache.entries.contains { $0.date == AppStore.dayKey() } ? "Edit today's headache" : "Log a headache") {
                        editing = Headache.entries.first { $0.date == AppStore.dayKey() } ?? Headache.Entry(date: AppStore.dayKey())
                    }
                    let monthAgo = AppStore.dayKey(Date().addingTimeInterval(-29 * 86400))
                    let month = all.filter { $0.date >= monthAgo }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            D(tr(month.count == 1 ? "Last 30 days: 1 headache day" : "Last 30 days: \(month.count) headache days") + (month.contains(where: \.migraine) ? " · " + tr("\(month.filter(\.migraine).count) migraines") : ""))
                                .font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            if !month.isEmpty {
                                D(tr("Average pain \(String(format: "%.1f", Double(month.map(\.pain).reduce(0, +)) / Double(month.count))) out of 10")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            }
                            if month.count >= 15 { T("15 or more headache days a month is worth talking to your doctor about.").font(.hs(12)).foregroundStyle(HS.peach) }
                        }
                    }
                    let links = Headache.links(sleepByDay: steps.sleepByDay, steps: steps.stepsByDay) { k in periodWindow(k) }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("🔎 What goes with your headaches").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            if links.isEmpty { T("Keep logging. Patterns show up after about two weeks and a few headaches.").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                            ForEach(links, id: \.label) { l in
                                VStack(alignment: .leading, spacing: 2) {
                                    D(l.emoji + " " + tr(l.label) + ": " + tr("headaches on \(l.withRate)% vs \(l.withoutRate)%")).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                    T(l.tip).font(.hs(12)).foregroundStyle(HS.textSecondary)
                                }
                            }
                            let named = Headache.namedTriggers().prefix(5)
                            if !named.isEmpty {
                                D(tr("Triggers you named most:") + " " + named.map { tr($0.0) + " (\($0.1))" }.joined(separator: ", ")).font(.hs(12)).foregroundStyle(HS.textSecondary).padding(.top, 4)
                            }
                        }
                    }
                    if !all.isEmpty {
                        SectionHeader(title: "Your log").padding(.horizontal, -20)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(all.suffix(20).reversed(), id: \.date) { e in
                                    Button { editing = e } label: {
                                        HStack {
                                            D(e.migraine ? "⚡" : "🤕")
                                            VStack(alignment: .leading, spacing: 1) {
                                                D((AppStore.date(fromKey: e.date)?.formatted(.dateTime.month(.abbreviated).day().locale(I18n.shared.locale)) ?? e.date) + " · " + tr("pain \(e.pain)/10"))
                                                    .font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                                if !e.triggers.isEmpty { D(e.triggers.map { tr($0) }.joined(separator: ", ")).font(.hs(11)).foregroundStyle(HS.textMuted).lineLimit(1) }
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    T("Not medical advice. Call 911 for a sudden, severe \"worst ever\" headache, or one with weakness, confusion, trouble speaking, vision loss, a stiff neck with fever, or after a head injury. If you're pregnant or gave birth in the last year, a headache that won't go away or comes with vision changes or swelling can be preeclampsia: get care right away.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .padding(20).padding(.bottom, 40).id(refresh)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(get: { editing.map { IdentifiedHeadache(e: $0) } }, set: { editing = $0?.e })) { h in
            HeadacheSheet(entry: h.e) { Headache.save($0); refresh += 1 } onDelete: { d in Headache.entries = Headache.entries.filter { $0.date != d }; refresh += 1 }
        }
    }

    /// True in the 2 days before and first 3 days of a period (as Android's menstrual-migraine window), nil with no periods logged.
    private func periodWindow(_ key: String) -> Bool? {
        guard store.gender != "male", !store.periodStarts.isEmpty, let d = AppStore.date(fromKey: key) else { return nil }
        return store.periodStarts.contains { s in
            let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: s), to: d).day ?? 99
            return (-2...2).contains(diff)
        }
    }
}

private struct IdentifiedHeadache: Identifiable { let e: Headache.Entry; var id: String { e.date } }

private struct HeadacheSheet: View {
    @State var entry: Headache.Entry
    let onSave: (Headache.Entry) -> Void
    let onDelete: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $entry.migraine) { D("🤕 " + tr("Headache")).tag(false); D("⚡ " + tr("Migraine")).tag(true) }.pickerStyle(.segmented)
                    label("How bad? \(entry.pain)/10")
                    Slider(value: Binding(get: { Double(entry.pain) }, set: { entry.pain = Int($0) }), in: 1...10, step: 1).tint(Color(hex: 0xF43F5E))
                    label("When did it start?")
                    one(Headache.started, $entry.started)
                    label("How long did it last?")
                    one(Headache.lasted, $entry.lasted)
                    label("Where?")
                    many(Headache.whereList, $entry.where_)
                    label("Anything else?")
                    many(Headache.symptoms, $entry.symptoms)
                    label("What do you think set it off?")
                    many(Headache.triggers, $entry.triggers)
                    Toggle(tr("I took medicine"), isOn: $entry.tookMeds).font(.hs(14)).tint(HS.goldButton)
                    if entry.tookMeds {
                        TextField(tr("Which one (optional)"), text: $entry.medicine).font(.hs(14)).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.05)))
                        label("Did it help?")
                        FlowChips(items: Headache.relief.indices.map { ("\($0)", tr(Headache.relief[$0])) }, selected: [ "\(entry.relief)" ]) { entry.relief = Int($0) ?? -1 }
                    }
                    TextField(tr("Note (optional)"), text: $entry.note, axis: .vertical).font(.hs(14)).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.05)))
                    if entry.pain >= 9 || entry.symptoms.contains("Tingling or numbness") {
                        T("If this came on suddenly, is the worst of your life, or comes with weakness, confusion or trouble speaking, call 911.")
                            .font(.hs(12)).foregroundStyle(HS.readable(0xF43F5E))
                    }
                    if Headache.entries.contains(where: { $0.date == entry.date }) {
                        Button(role: .destructive) { onDelete(entry.date); dismiss() } label: { T("Delete this day").font(.hs(13)).foregroundStyle(Color(hex: 0xF87171)) }
                    }
                }
                .padding(20)
            }
            .background(HSBackground())
            .navigationTitle(tr("Log a headache")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Save")) { var e = entry; e.medicine = String(e.medicine.prefix(60)); e.note = String(e.note.prefix(300)); if !e.tookMeds { e.relief = -1 }; onSave(e); dismiss() }
                }
            }
        }
    }

    private func label(_ s: String) -> some View { D(tr(s)).font(.hs(13, .semibold)).foregroundStyle(HS.text).padding(.top, 4) }
    private func one(_ list: [String], _ b: Binding<String>) -> some View {
        FlowChips(items: list.map { ($0, tr($0)) }, selected: [b.wrappedValue]) { b.wrappedValue = b.wrappedValue == $0 ? "" : $0 }
    }
    private func many(_ list: [String], _ b: Binding<[String]>) -> some View {
        FlowChips(items: list.map { ($0, tr($0)) }, selected: Set(b.wrappedValue)) { v in
            if let i = b.wrappedValue.firstIndex(of: v) { b.wrappedValue.remove(at: i) } else { b.wrappedValue.append(v) }
        }
    }
}

/// A card that opens a screen full-screen with its own navigation (used where the tab has no navigation stack).
struct CoverCard<Dest: View>: View {
    let emoji: String
    let title: String
    let subtitle: String
    var tint: UInt32 = 0xF43F5E
    @ViewBuilder var destination: () -> Dest
    @State private var open = false
    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 10) {
                D(emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    T(title).font(.hs(15, .bold)).foregroundStyle(HS.text)
                    T(subtitle).font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: tint).opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: tint).opacity(0.3), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $open) {
            NavigationStack {
                destination().toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Close")) { open = false } } }
            }
        }
    }
}
