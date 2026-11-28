import SwiftUI

/// Android's Strength log (BodyBasicsScreens.kt StrengthLogScreen, BodyBasics.kt Strength): log sets, reps and
/// weight, see your bests, and what to aim for next time (double progression: 8 to 12 reps, then add weight).
struct LiftSet: Codable, Equatable { var reps: Int; var lb: Double }
struct Lift: Codable, Identifiable, Equatable {
    var id: Double { atMs }
    let exercise: String, date: String, atMs: Double
    let sets: [LiftSet]
}

enum Strength {
    static let common = ["Bench press", "Squat", "Deadlift", "Overhead press", "Barbell row", "Pull-up", "Push-up",
                         "Dumbbell curl", "Lunge", "Leg press", "Lat pulldown", "Plank (seconds)"]
    static let repLow = 8, repHigh = 12

    /// Estimated one-rep max (Epley). Bodyweight moves (0 lb) use reps, so a best is still a best.
    static func estMax(_ s: LiftSet) -> Double { s.lb <= 0 ? Double(s.reps) : s.lb * (1 + Double(s.reps) / 30) }

    /// True when `lift` beat every earlier session of the same exercise.
    static func isBest(_ history: [Lift], _ lift: Lift) -> Bool {
        let before = history.filter { $0.exercise.caseInsensitiveCompare(lift.exercise) == .orderedSame && $0.atMs < lift.atMs }
        guard let prev = before.flatMap(\.sets).map(estMax).max() else { return false }
        return (lift.sets.map(estMax).max() ?? 0) > prev
    }

    /// Next session's target from the last one: every set at the top of the range means add weight; else add reps.
    static func nextTarget(_ history: [Lift], _ exercise: String) -> String? {
        guard let last = history.filter({ $0.exercise.caseInsensitiveCompare(exercise) == .orderedSame }).max(by: { $0.atMs < $1.atMs }),
              let top = last.sets.max(by: { $0.lb < $1.lb }) else { return nil }
        if top.lb <= 0 {
            return tr("Last time: {0} reps. Next: try one more rep on each set.").replacingOccurrences(of: "{0}", with: last.sets.map { "\($0.reps)" }.joined(separator: ", "))
        }
        let e = exercise.lowercased()
        let small = ["curl", "raise", "press", "fly"].contains { e.contains($0) } && !e.contains("leg") && !e.contains("bench")
        let step = small ? 2.5 : 5.0
        let atWeight = last.sets.filter { $0.lb == top.lb }
        if atWeight.allSatisfy({ $0.reps >= repHigh }) {
            return tr("You hit {0} reps on every set at {1}. Next: {2} for {3} reps.")
                .replacingOccurrences(of: "{0}", with: "\(repHigh)").replacingOccurrences(of: "{1}", with: fmtLb(top.lb))
                .replacingOccurrences(of: "{2}", with: fmtLb(top.lb + step)).replacingOccurrences(of: "{3}", with: "\(repLow)")
        }
        return tr("Next: stay at {0} and add a rep, working up to {1} on every set.")
            .replacingOccurrences(of: "{0}", with: fmtLb(top.lb)).replacingOccurrences(of: "{1}", with: "\(repHigh)")
    }

    static func fmtLb(_ lb: Double) -> String { lb.rounded() == lb ? "\(Int(lb)) lb" : String(format: "%.1f lb", lb) }
}

final class LiftStore: ObservableObject {
    static let shared = LiftStore()
    @Published private(set) var lifts: [Lift] = []
    private init() {
        if let d = UserDefaults.standard.data(forKey: "strengthLifts"), let l = try? JSONDecoder().decode([Lift].self, from: d) { lifts = l }
    }
    func add(_ exercise: String, _ sets: [LiftSet]) -> Lift {
        let l = Lift(exercise: exercise, date: AppStore.dayKey(), atMs: Date().timeIntervalSince1970 * 1000, sets: sets)
        lifts.append(l); save(); return l
    }
    func remove(_ atMs: Double) { lifts.removeAll { $0.atMs == atMs }; save() }
    private func save() {
        lifts = Array(lifts.suffix(1000))
        if let d = try? JSONEncoder().encode(lifts) { UserDefaults.standard.set(d, forKey: "strengthLifts") }
    }
}

struct StrengthLogView: View {
    @ObservedObject private var store = LiftStore.shared
    @State private var exercise = ""
    @State private var custom = ""
    @State private var sets: [(reps: String, lb: String)] = [("", "")]
    @State private var justBest: String?

    private var name: String { exercise.isEmpty ? custom.trimmingCharacters(in: .whitespaces) : exercise }
    private var parsed: [LiftSet] {
        sets.compactMap { s in Int(s.reps).flatMap { (1...500).contains($0) ? LiftSet(reps: $0, lb: Double(s.lb) ?? 0) : nil } }
    }

    var body: some View {
        let lifts = store.lifts
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard(warm: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        T("🏋️ FITNESS").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                        T("Strength log").font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                        T("Log sets, reps and weight. You'll see your bests and what to aim for next time.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        T("Exercise").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        let recent = Array(NSOrderedSet(array: lifts.sorted { $0.atMs > $1.atMs }.map(\.exercise)).array.prefix(4)) as? [String] ?? []
                        let choices = Array(NSOrderedSet(array: recent + Strength.common).array) as? [String] ?? Strength.common
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(choices, id: \.self) { e in
                                Button { exercise = exercise == e ? "" : e; custom = "" } label: {
                                    T(e).font(.hs(13, exercise == e ? .semibold : .regular)).foregroundStyle(exercise == e ? HS.onGold : HS.text)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(exercise == e ? AnyShapeStyle(HS.body) : AnyShapeStyle(HS.cardFill)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(exercise == e ? .isSelected : [])
                            }
                        }
                        TextField(tr("Or type another exercise"), text: $custom).textFieldStyle(.roundedBorder)
                            .onChange(of: custom) { if custom.count > 40 { custom = String(custom.prefix(40)) }; if !custom.isEmpty { exercise = "" } }
                        if !name.isEmpty, let next = Strength.nextTarget(lifts, name) {
                            D(next).font(.hs(14, .semibold)).foregroundStyle(HS.body)
                        }
                        ForEach(sets.indices, id: \.self) { i in
                            HStack(spacing: 8) {
                                D(tr("Set") + " \(i + 1)").font(.hs(13)).foregroundStyle(HS.textMuted).frame(width: 52, alignment: .leading)
                                TextField(tr("Reps"), text: Binding(get: { sets[i].reps }, set: { sets[i].reps = String($0.filter(\.isNumber).prefix(3)) }))
                                    .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                                TextField(tr("lb (0 = body)"), text: Binding(get: { sets[i].lb }, set: { sets[i].lb = String($0.prefix(6)) }))
                                    .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                            }
                        }
                        Button { if let last = sets.last { sets.append(last) } } label: { T("+ Add a set").font(.hs(14, .semibold)).foregroundStyle(HS.faith) }
                        Button {
                            let saved = store.add(name, parsed)
                            justBest = Strength.isBest(store.lifts, saved) ? tr("New best on") + " \(name)!" : nil
                            if let l = parsed.last { sets = [(String(l.reps), l.lb > 0 ? Strength.fmtLb(l.lb).replacingOccurrences(of: " lb", with: "") : "")] }
                        } label: {
                            T("Save").font(.hs(15, .semibold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity, minHeight: 46)
                                .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
                        }
                        .buttonStyle(.plain)
                        .disabled(name.isEmpty || parsed.isEmpty).opacity(name.isEmpty || parsed.isEmpty ? 0.5 : 1)
                        if let b = justBest { D("🏆 " + b).font(.hs(15, .bold)).foregroundStyle(HS.gold) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                let byExercise = Dictionary(grouping: lifts, by: \.exercise)
                if !byExercise.isEmpty {
                    T("Your bests").font(.hs(15, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    ForEach(byExercise.sorted { ($0.value.map(\.atMs).max() ?? 0) > ($1.value.map(\.atMs).max() ?? 0) }, id: \.key) { ex, list in
                        if let top = list.flatMap(\.sets).max(by: { Strength.estMax($0) < Strength.estMax($1) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    D(ex).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                    D(tr("Best:") + " " + (top.lb > 0 ? "\(top.reps) × \(Strength.fmtLb(top.lb))" : "\(top.reps) " + tr("reps"))).font(.hs(13)).foregroundStyle(HS.textMuted)
                                }
                                Spacer()
                                D("\(list.count) " + tr(list.count == 1 ? "session" : "sessions")).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        }
                    }
                    T("Recent").font(.hs(15, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    ForEach(lifts.sorted { $0.atMs > $1.atMs }.prefix(10)) { l in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                D("\(l.exercise) · \(SermonNotesStore.dayLabel(l.date))").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                D(l.sets.map { $0.lb > 0 ? "\($0.reps)×\(Strength.fmtLb($0.lb))" : "\($0.reps)" }.joined(separator: "  ")).font(.hs(13)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            Button(tr("Delete")) { store.remove(l.atMs) }.font(.hs(13)).foregroundStyle(HS.textMuted)
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                    }
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Strength log"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
