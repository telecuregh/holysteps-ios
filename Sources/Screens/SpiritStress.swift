import SwiftUI
import HealthKit

/// Spirit & Stress: log how you feel after you pray (saved to Apple Health as State of Mind, iOS 18),
/// then see how your heart rate variability and mood compare on days you prayed or read and days you didn't.
/// Everything is read and worked out on this iPhone. Logging is free; the comparison comes with Faith or Wellness.
/// Wellness only, not a medical device.
struct SpiritMood: Identifiable, Hashable {
    let id: Int
    let face: String
    let title: String
    let valence: Double
    static let all = [
        SpiritMood(id: 0, face: "🌧️", title: "Heavy", valence: -0.8),
        SpiritMood(id: 1, face: "☁️", title: "Unsettled", valence: -0.35),
        SpiritMood(id: 2, face: "🌤️", title: "Okay", valence: 0.05),
        SpiritMood(id: 3, face: "☀️", title: "At peace", valence: 0.55),
        SpiritMood(id: 4, face: "🌈", title: "Full of joy", valence: 0.9),
    ]
}

@MainActor
final class SpiritStressModel: ObservableObject {
    static let shared = SpiritStressModel()
    private let health = HKHealthStore()

    struct Compare { let prayed: Double; let other: Double; let prayedDays: Int; let otherDays: Int }
    @Published private(set) var hrv: Compare?
    @Published private(set) var mood: Compare?
    @Published private(set) var lastLogged: Date? = UserDefaults.standard.object(forKey: "spiritLogged") as? Date

    var canLog: Bool { if #available(iOS 18.0, *) { return HKHealthStore.isHealthDataAvailable() } else { return false } }

    func log(_ m: SpiritMood) async -> Bool {
        guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else { return false }
        let type = HKSampleType.stateOfMindType()
        do { try await health.requestAuthorization(toShare: [type], read: [type, HKQuantityType(.heartRateVariabilitySDNN)]) } catch { return false }
        let labels: [HKStateOfMind.Label] = {
            switch m.id {
            case 0: [.sad, .stressed]
            case 1: [.worried]
            case 2: [.content]
            case 3: [.peaceful, .calm]
            default: [.joyful, .grateful]
            }
        }()
        let sample = HKStateOfMind(date: Date(), kind: .momentaryEmotion, valence: m.valence, labels: labels, associations: [.spirituality])
        do { try await health.save(sample) } catch { return false }
        lastLogged = Date(); UserDefaults.standard.set(lastLogged, forKey: "spiritLogged")
        await refresh()
        return true
    }

    /// Days with prayer or Bible reading (from the app's own log) against the rest, over the last 30 days.
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let faithDays = Set(UserDefaults.standard.stringArray(forKey: "readDays") ?? [])
            .union(((UserDefaults.standard.dictionary(forKey: "prayerLog") as? [String: [Bool]]) ?? [:]).filter { $0.value.contains(true) }.keys)
        let start = Calendar.current.startOfDay(for: Date().addingTimeInterval(-30 * 86400))
        let hrvDays = await dailyHRV(from: start)
        hrv = compare(hrvDays, faithDays)
        if #available(iOS 18.0, *) { mood = compare(await dailyMood(from: start), faithDays) }
    }

    private func compare(_ days: [String: Double], _ faith: Set<String>) -> Compare? {
        let p = days.filter { faith.contains($0.key) }.map(\.value)
        let o = days.filter { !faith.contains($0.key) }.map(\.value)
        guard p.count >= 3, o.count >= 3 else { return nil }
        return Compare(prayed: p.reduce(0, +) / Double(p.count), other: o.reduce(0, +) / Double(o.count), prayedDays: p.count, otherDays: o.count)
    }

    private func dailyHRV(from start: Date) async -> [String: Double] {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: Date()),
                                                options: .discreteAverage, anchorDate: start, intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, results, _ in
                var out: [String: Double] = [:]
                results?.enumerateStatistics(from: start, to: Date()) { s, _ in
                    if let v = s.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli)) { out[AppStore.dayKey(s.startDate)] = v }
                }
                cont.resume(returning: out)
            }
            health.execute(q)
        }
    }

    @available(iOS 18.0, *)
    private func dailyMood(from start: Date) async -> [String: Double] {
        let d = HKSampleQueryDescriptor(predicates: [.stateOfMind(HKQuery.predicateForSamples(withStart: start, end: Date()))], sortDescriptors: [])
        guard let samples = try? await d.result(for: health) else { return [:] }
        var sums: [String: (Double, Int)] = [:]
        for s in samples { let k = AppStore.dayKey(s.startDate); let c = sums[k] ?? (0, 0); sums[k] = (c.0 + s.valence, c.1 + 1) }
        return sums.mapValues { $0.0 / Double($0.1) }
    }
}

/// "How do you feel now?" after praying, with the faith-and-stress comparison underneath when there's enough data.
struct SpiritStressCard: View {
    @ObservedObject private var model = SpiritStressModel.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var saved: SpiritMood?
    @State private var paywall = false

    var body: some View {
        if model.canLog {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    T("Spirit & Stress").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    if let saved {
                        D(tr("Saved to Apple Health: {0}").replacingOccurrences(of: "{0}", with: tr(saved.title))).font(.hs(13)).foregroundStyle(HS.gold)
                    } else {
                        T("How do you feel right now?").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        HStack(spacing: 6) {
                            ForEach(SpiritMood.all) { m in
                                Button { Task { if await model.log(m) { saved = m } } } label: {
                                    VStack(spacing: 4) {
                                        Text(m.face).font(.system(size: 26))
                                        T(m.title).font(.hs(10)).foregroundStyle(HS.textMuted).lineLimit(1).minimumScaleFactor(0.7)
                                    }.frame(maxWidth: .infinity)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if model.hrv != nil || model.mood != nil {
                        Divider().overlay(HS.overlay(0.1))
                        if account.canUse(.spiritStress) { insight } else {
                            Button { paywall = true } label: {
                                HStack { Image(systemName: "lock.fill").foregroundStyle(HS.gold); T(Feature.spiritStress.lockMessage).font(.hs(12)).foregroundStyle(HS.textMuted) }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .task { await model.refresh() }
            .sheet(isPresented: $paywall) { PlansView(feature: .spiritStress) }
        }
    }

    @ViewBuilder private var insight: some View {
        if let h = model.hrv {
            row(tr("Heart rate variability"), String(format: "%.0f ms", h.prayed), String(format: "%.0f ms", h.other), better: h.prayed > h.other)
        }
        if let m = model.mood {
            row(tr("Mood"), mood(m.prayed), mood(m.other), better: m.prayed > m.other)
        }
        T("Days you prayed or read the Bible, against the other days, over the last 30 days. Higher HRV usually means less stress.")
            .font(.hs(11)).foregroundStyle(HS.textMuted)
    }

    private func mood(_ v: Double) -> String { tr(SpiritMood.all.min { abs($0.valence - v) < abs($1.valence - v) }!.title) }

    private func row(_ title: String, _ prayed: String, _ other: String, better: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            D(title).font(.hs(13, .semibold)).foregroundStyle(HS.text)
            HStack {
                VStack(alignment: .leading) { T("Prayer days").font(.hs(11)).foregroundStyle(HS.textMuted); D(prayed).font(.hs(16, .semibold)).foregroundStyle(better ? HS.gold : HS.text) }
                Spacer()
                VStack(alignment: .trailing) { T("Other days").font(.hs(11)).foregroundStyle(HS.textMuted); D(other).font(.hs(16, .semibold)).foregroundStyle(HS.text) }
            }
        }
    }
}
