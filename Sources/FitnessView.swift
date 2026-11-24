import SwiftUI
import HealthKit

@MainActor
final class StepsModel: ObservableObject {
    @Published var today: Int = 0
    @Published var week: [(day: String, steps: Int)] = []
    @Published var available = HKHealthStore.isHealthDataAvailable()
    @Published var asked = false
    private let health = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    func request() async {
        guard available else { return }
        do {
            try await health.requestAuthorization(toShare: [], read: [stepType])
            asked = true
            await refresh()
        } catch { asked = true }
    }

    func refresh() async {
        guard available else { return }
        let cal = Calendar.current
        var rows: [(String, Int)] = []
        let f = DateFormatter(); f.dateFormat = "EEE"
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let start = cal.startOfDay(for: d)
            let end = offset == 0 ? Date() : (cal.date(byAdding: .day, value: 1, to: start) ?? Date())
            rows.append((f.string(from: d), await steps(from: start, to: end)))
        }
        week = rows.map { (day: $0.0, steps: $0.1) }
        today = rows.last?.1 ?? 0
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

struct FitnessView: View {
    @StateObject private var model = StepsModel()
    @AppStorage("stepGoal") private var goal = 8000

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenTitle(text: "Fitness")
                        GlassCard {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle().stroke(HS.body.opacity(0.2), lineWidth: 14)
                                    Circle().trim(from: 0, to: min(1, Double(model.today) / Double(max(goal, 1))))
                                        .stroke(HS.body, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    VStack {
                                        Text("\(model.today)").font(.system(size: 34, weight: .semibold)).foregroundStyle(HS.text)
                                        Text("of \(goal) steps").font(.footnote).foregroundStyle(HS.textMuted)
                                    }
                                }
                                .frame(width: 170, height: 170)
                                .frame(maxWidth: .infinity)
                                Stepper("Daily goal: \(goal)", value: $goal, in: 2000...30000, step: 500)
                                    .foregroundStyle(HS.textSecondary)
                            }
                        }
                        if !model.week.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last 7 days").font(.subheadline).foregroundStyle(HS.textMuted)
                                    HStack(alignment: .bottom, spacing: 10) {
                                        ForEach(Array(model.week.enumerated()), id: \.offset) { _, r in
                                            VStack(spacing: 4) {
                                                RoundedRectangle(cornerRadius: 5).fill(HS.body)
                                                    .frame(height: max(4, 90 * CGFloat(min(1, Double(r.steps) / Double(max(goal, 1))))))
                                                Text(r.day).font(.caption2).foregroundStyle(HS.textMuted)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(height: 110, alignment: .bottom)
                                }
                            }
                        }
                        if model.available && !model.asked {
                            GoldButton(title: "Connect Apple Health") { Task { await model.request() } }
                        } else if !model.available {
                            Text("Apple Health isn't available on this device.").font(.footnote).foregroundStyle(HS.textMuted)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { if model.available { await model.refresh() } }
        }
    }
}
