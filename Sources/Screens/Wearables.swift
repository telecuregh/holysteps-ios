import SwiftUI
import HealthKit

/// Rings & watches (Android's HealthConnectScreens.kt, through Apple Health instead of Health Connect). Oura, Apple
/// Watch, Garmin, Samsung, Ultrahuman, Fitbit and others write to Apple Health; HolySteps reads from there, only with
/// permission, and never writes. Steps: Apple Health already counts a ring's and the phone's steps once, so walking
/// with only the ring on still counts and nothing is doubled.
@MainActor
final class WearableModel: ObservableObject {
    static let shared = WearableModel()
    private let health = HKHealthStore()
    private static let onKey = "wearableOn", syncKey = "wearableSync"

    @Published var on = UserDefaults.standard.bool(forKey: onKey) { didSet { UserDefaults.standard.set(on, forKey: Self.onKey) } }
    @Published private(set) var lastSync = UserDefaults.standard.object(forKey: syncKey) as? Date
    @Published private(set) var sources: [String] = []
    @Published private(set) var restingHR: Int?
    @Published private(set) var restingHRUsual: Int?
    @Published private(set) var hrv: Int?
    @Published private(set) var hrvUsual: Int?
    @Published private(set) var sleepMinutes: Int?
    @Published private(set) var workouts: [Workout] = []
    @Published private(set) var loading = false

    struct Workout: Identifiable { let id: UUID; let name: String; let start: Date; let minutes: Int; let source: String }

    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    var hasData: Bool { restingHR != nil || hrv != nil || sleepMinutes != nil || !workouts.isEmpty }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.restingHeartRate), HKQuantityType(.heartRateVariabilitySDNN), HKQuantityType(.heartRate),
         HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()]
    }

    func connect() async {
        guard available else { return }
        do { try await health.requestAuthorization(toShare: [], read: readTypes) } catch { return }
        on = true
        await refresh()
        await StepsModel.shared.refresh()
    }

    /// Forgets what was read; the Health permission itself is changed in Settings › Health.
    func disconnect() {
        on = false
        sources = []; restingHR = nil; restingHRUsual = nil; hrv = nil; hrvUsual = nil; sleepMinutes = nil; workouts = []
        lastSync = nil; UserDefaults.standard.removeObject(forKey: Self.syncKey)
    }

    func refresh() async {
        guard on, available, !loading else { return }
        loading = true; defer { loading = false }
        let now = Date(), cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let dayAgo = now.addingTimeInterval(-36 * 3600)
        async let rhrNow = latest(.restingHeartRate, unit: .count().unitDivided(by: .minute()), since: dayAgo)
        async let rhrWeek = average(.restingHeartRate, unit: .count().unitDivided(by: .minute()), from: weekAgo, to: dayAgo)
        async let hrvNow = latest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), since: dayAgo)
        async let hrvWeek = average(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: weekAgo, to: dayAgo)
        async let w = recentWorkouts(since: weekAgo)
        async let src = wearableSources(since: weekAgo)
        restingHR = await rhrNow.map { Int($0.rounded()) }
        restingHRUsual = await rhrWeek.map { Int($0.rounded()) }
        hrv = await hrvNow.map { Int($0.rounded()) }
        hrvUsual = await hrvWeek.map { Int($0.rounded()) }
        workouts = await w
        sources = await src
        await StepsModel.shared.refresh()
        sleepMinutes = StepsModel.shared.sleepLastNight
        lastSync = Date(); UserDefaults.standard.set(lastSync, forKey: Self.syncKey)
    }

    /// Android's walk advice from the ring's numbers: better / usual / off.
    var advice: String? {
        guard let r = restingHR, let ru = restingHRUsual else { return nil }
        var score = 0
        if r <= ru - 2 { score += 1 } else if r >= ru + 4 { score -= 1 }
        if let h = hrv, let hu = hrvUsual, hu > 0 {
            if Double(h) >= Double(hu) * 1.08 { score += 1 } else if Double(h) <= Double(hu) * 0.85 { score -= 1 }
        }
        if let s = sleepMinutes, s < 330 { score -= 1 }
        switch score {
        case 1...: return "Your heart numbers look better than usual. A normal or slightly longer walk is a good fit."
        case ..<0: return "Your heart numbers are off from your usual. An easy walk or extra rest is a good fit today."
        default: return "Your sleep and heart numbers look like your usual. A normal walk is a good fit."
        }
    }

    // MARK: Queries

    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async -> Double? {
        await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: HKQuantityType(id), predicate: HKQuery.predicateForSamples(withStart: since, end: Date()),
                                  limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, s, _ in
                cont.resume(returning: (s?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
            }
            health.execute(q)
        }
    }

    private func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async -> Double? {
        await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: HKQuantityType(id), quantitySamplePredicate: HKQuery.predicateForSamples(withStart: from, end: to),
                                      options: .discreteAverage) { _, r, _ in
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: unit))
            }
            health.execute(q)
        }
    }

    private func recentWorkouts(since: Date) async -> [Workout] {
        await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: HKQuery.predicateForSamples(withStart: since, end: Date()),
                                  limit: 5, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, s, _ in
                let out = (s as? [HKWorkout] ?? []).map {
                    Workout(id: $0.uuid, name: Self.name($0.workoutActivityType), start: $0.startDate,
                            minutes: Int(($0.duration / 60).rounded()), source: $0.sourceRevision.source.name)
                }
                cont.resume(returning: out)
            }
            health.execute(q)
        }
    }

    /// The ring and watch apps writing heart or sleep data (the phone itself isn't listed).
    private func wearableSources(since: Date) async -> [String] {
        var names = Set<String>()
        for t in [HKQuantityType(.heartRate), HKQuantityType(.restingHeartRate)] as [HKSampleType] + [HKCategoryType(.sleepAnalysis)] {
            let n: Set<String> = await withCheckedContinuation { cont in
                let q = HKSourceQuery(sampleType: t, samplePredicate: HKQuery.predicateForSamples(withStart: since, end: Date())) { _, s, _ in
                    cont.resume(returning: Set((s ?? []).filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }.map(\.name)))
                }
                health.execute(q)
            }
            names.formUnion(n)
        }
        return names.sorted()
    }

    private static func name(_ t: HKWorkoutActivityType) -> String {
        switch t {
        case .walking: "Walk"; case .running: "Run"; case .cycling: "Ride"; case .hiking: "Hike"; case .swimming: "Swim"
        case .yoga: "Yoga"; case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength"
        case .highIntensityIntervalTraining: "HIIT"; case .pilates: "Pilates"; case .dance: "Dance"; case .elliptical: "Elliptical"
        case .rowing: "Rowing"; case .coreTraining: "Core"; case .flexibility: "Stretching"
        default: "Workout"
        }
    }
}

/// Profile › Rings & watches.
struct RingsWatchesView: View {
    @ObservedObject private var wear = WearableModel.shared
    @Environment(\.openURL) private var openURL
    @State private var confirmOff = false

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("Rings & watches").font(.hs(26)).foregroundStyle(HS.text)
                    ItalicAccent(text: "Your wearable, in HolySteps", size: 16)
                    if !wear.available {
                        GlassCard { T("Apple Health isn't available on this device.").font(.hs(14)).foregroundStyle(HS.textMuted) }
                    } else if !wear.on {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                T("Connect your ring or watch").font(.hs(17, .semibold)).foregroundStyle(HS.text)
                                T("Oura, Apple Watch, Garmin, Samsung Galaxy Ring, Ultrahuman, Fitbit and others share their data with Apple Health on your iPhone. HolySteps reads it from there, with your permission.")
                                    .font(.hs(13)).foregroundStyle(HS.textSecondary)
                                T("First, in your ring or watch app, turn on sharing with Apple Health. Then allow HolySteps to read it.")
                                    .font(.hs(13)).foregroundStyle(HS.textSecondary)
                                GoldButton(title: "Connect with Apple Health") { Task { await wear.connect() } }
                                T("HolySteps only reads. It never writes to Apple Health or changes your data there.").font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                        }
                    } else {
                        connected
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await wear.refresh() }
        .alert(tr("Disconnect your ring and watch?"), isPresented: $confirmOff) {
            Button(tr("Disconnect"), role: .destructive) { wear.disconnect() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            T("HolySteps will stop reading from Apple Health and forget the last numbers it read. Steps already counted stay counted. To remove the permission too, go to Settings › Health › Data Access & Devices › HolySteps.")
        }
    }

    private var connected: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x56B892))
                        T("Connected").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    }
                    if wear.sources.isEmpty {
                        T("No data yet. Check sharing with Apple Health is on in your ring or watch app.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    } else {
                        D(tr("Data from") + " " + wear.sources.joined(separator: ", ")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    T("Steps from your ring or watch and your iPhone are counted once, never twice.").font(.hs(12)).foregroundStyle(HS.textMuted)
                    if let s = wear.lastSync {
                        D(tr("Updated") + " " + s.formatted(.relative(presentation: .named).locale(I18n.shared.locale))).font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                    HStack(spacing: 10) {
                        GoldButton(title: wear.loading ? "Updating…" : "Update now") { Task { await wear.refresh() } }
                        Button(tr("Disconnect")) { confirmOff = true }.font(.hs(14, .semibold)).foregroundStyle(HS.textMuted)
                    }
                }
            }
            WearableSummaryCard()
            if !wear.workouts.isEmpty {
                SectionHeader(title: "Recent workouts").padding(.horizontal, -20)
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(wear.workouts) { w in
                            HStack {
                                D(tr(w.name)).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                Spacer()
                                D(tr("\(w.minutes) min") + " · " + w.start.formatted(.dateTime.weekday(.abbreviated).hour().minute().locale(I18n.shared.locale)))
                                    .font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
                }
            }
            Button { openURL(URL(string: "x-apple-health://")!) } label: {
                T("Open Apple Health").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
            }
        }
    }
}

/// "From your ring & watch": last night's sleep, resting heart rate and HRV against the usual, and the walk advice.
/// Shown on Fitness when connected; an invitation to connect otherwise.
struct WearableSummaryCard: View {
    @ObservedObject private var wear = WearableModel.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var paywall = false
    var compact = false

    var body: some View {
        if wear.on && wear.hasData && !account.canUse(.wearableInsights) {
            Button { paywall = true } label: {
                GlassCard(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill").foregroundStyle(HS.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            T("From your ring & watch").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            T(Feature.wearableInsights.lockMessage).font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $paywall) { PlansView(feature: .wearableInsights) }
        } else if wear.on && wear.hasData {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    T("From your ring & watch").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    HStack(spacing: 10) {
                        if let s = wear.sleepMinutes { metric("\(s / 60)h \(s % 60)m", "Sleep", nil) }
                        if let r = wear.restingHR { metric("\(r)", "Resting heart rate", wear.restingHRUsual.map { tr("usual \($0)") }) }
                        if let h = wear.hrv { metric("\(h) ms", "HRV", wear.hrvUsual.map { tr("usual \($0)") }) }
                    }
                    if let a = wear.advice { T(a).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                }
            }
        } else if !wear.on && compact && wear.available {
            NavigationLink { RingsWatchesView() } label: {
                GlassCard(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "applewatch").font(.system(size: 20)).foregroundStyle(HS.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            T("Connect your ring or watch").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            T("Oura, Apple Watch, Garmin and more, through Apple Health.").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        D("›").font(.hs(22)).foregroundStyle(HS.gold)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func metric(_ value: String, _ label: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            D(value).font(.hs(18, .semibold)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.7)
            T(label).font(.hs(11)).foregroundStyle(HS.textMuted).lineLimit(1).minimumScaleFactor(0.8)
            if let sub { D(sub).font(.hs(10)).foregroundStyle(HS.textMuted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.06)))
    }
}
