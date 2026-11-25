import SwiftUI
import HealthKit
import WatchKit
import WatchConnectivity

/// HolySteps on Apple Watch: today's verse, a prayer walk recorded as a workout (time, steps, heart rate,
/// distance, saved to Apple Health), and a breath prayer you feel on your wrist. The walk and breath prayer
/// come with the Fitness plan; the iPhone tells the watch which plans are on. Nothing leaves your devices.
@main
struct HolyStepsWatchApp: App {
    var body: some Scene { WindowGroup { WatchHome() } }
}

private var spanish: Bool { (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es") }
private func L(_ en: String, _ es: String) -> String { spanish ? es : en }

final class WatchPlans: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchPlans()
    @Published var fitness = UserDefaults.standard.bool(forKey: "fitness")

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    private func apply(_ c: [String: Any]) {
        guard let f = c["fitness"] as? Bool else { return }
        DispatchQueue.main.async { self.fitness = f; UserDefaults.standard.set(f, forKey: "fitness") }
    }
    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) { apply(s.receivedApplicationContext) }
    func session(_ s: WCSession, didReceiveApplicationContext c: [String: Any]) { apply(c) }
}

struct WatchHome: View {
    @ObservedObject private var plans = WatchPlans.shared
    var body: some View {
        NavigationStack {
            List {
                NavigationLink { VerseScreen() } label: { Label(L("Today's verse", "Versículo de hoy"), systemImage: "book") }
                if plans.fitness {
                    NavigationLink { WalkScreen() } label: { Label(L("Prayer walk", "Caminata de oración"), systemImage: "figure.walk") }
                    NavigationLink { BreatheScreen() } label: { Label(L("Breath prayer", "Oración de respiración"), systemImage: "wind") }
                } else {
                    Text(L("Prayer walks and breath prayer come with the Fitness plan. Open HolySteps on your iPhone.",
                           "Las caminatas de oración y la oración de respiración vienen con el plan Fitness. Abre HolySteps en tu iPhone."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("HolySteps")
        }
        .onAppear { plans.activate() }
    }
}

struct VerseScreen: View {
    var body: some View {
        let v = DailyVerses.forDay()
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("“\(spanish ? v.es : v.text)”").font(.body.italic())
                Text(spanish ? DailyVerses.spanishRef(v.ref) : v.ref).font(.footnote.weight(.semibold)).foregroundStyle(NavyGlass.gold)
            }
        }
    }
}

final class WalkSession: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    @Published var running = false, paused = false, saved = false
    @Published var start: Date?
    @Published var steps = 0, heart = 0
    @Published var meters = 0.0

    func begin() {
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.stepCount), HKQuantityType(.heartRate), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned)]
        health.requestAuthorization(toShare: share, read: read) { ok, _ in
            guard ok else { return }
            DispatchQueue.main.async { self.startSession() }
        }
    }

    private func startSession() {
        let c = HKWorkoutConfiguration()
        c.activityType = .walking
        c.locationType = .outdoor
        guard let s = try? HKWorkoutSession(healthStore: health, configuration: c) else { return }
        let b = s.associatedWorkoutBuilder()
        b.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: c)
        s.delegate = self; b.delegate = self
        session = s; builder = b
        let now = Date()
        s.startActivity(with: now)
        b.beginCollection(withStart: now) { _, _ in }
        start = now; running = true; saved = false
        WKInterfaceDevice.current().play(.start)
    }

    func togglePause() { paused ? session?.resume() : session?.pause(); paused.toggle() }

    func end() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            self.builder?.addMetadata([HKMetadataKeyWorkoutBrandName: "HolySteps prayer walk"]) { _, _ in
                self.builder?.finishWorkout { _, _ in DispatchQueue.main.async { self.saved = true } }
            }
        }
        running = false
        WKInterfaceDevice.current().play(.success)
    }

    func workoutBuilder(_ b: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        let s = b.statistics(for: HKQuantityType(.stepCount))?.sumQuantity()?.doubleValue(for: .count()) ?? 0
        let h = b.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
        let d = b.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
        DispatchQueue.main.async { self.steps = Int(s); self.heart = Int(h); self.meters = d }
    }
    func workoutBuilderDidCollectEvent(_ b: HKLiveWorkoutBuilder) {}
    func workoutSession(_ s: HKWorkoutSession, didChangeTo to: HKWorkoutSessionState, from: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ s: HKWorkoutSession, didFailWithError error: Error) { DispatchQueue.main.async { self.running = false } }
}

struct WalkScreen: View {
    @StateObject private var walk = WalkSession()
    var body: some View {
        VStack(spacing: 6) {
            if walk.running, let start = walk.start {
                TimelineView(.periodic(from: start, by: 1)) { ctx in
                    let t = Int(ctx.date.timeIntervalSince(start))
                    Text(String(format: "%d:%02d", t / 60, t % 60)).font(.title2.monospacedDigit().weight(.semibold))
                }
                HStack {
                    Label("\(walk.steps)", systemImage: "shoeprints.fill")
                    if walk.heart > 0 { Label("\(walk.heart)", systemImage: "heart.fill").foregroundStyle(.red) }
                }.font(.footnote)
                Text(Measurement(value: walk.meters, unit: UnitLength.meters).converted(to: .miles).formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(2)))))
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button(walk.paused ? L("Resume", "Seguir") : L("Pause", "Pausa")) { walk.togglePause() }
                    Button(L("End", "Terminar"), role: .destructive) { walk.end() }
                }
            } else {
                if walk.saved { Text(L("Saved to Apple Health. Well walked!", "Guardado en Salud. ¡Bien caminado!")).font(.footnote).multilineTextAlignment(.center) }
                Button { walk.begin() } label: { Label(L("Start walking", "Empezar"), systemImage: "play.fill") }.tint(NavyGlass.gold)
                Text(L("Pray as you walk: for someone you love, for your church, for your city.", "Ora mientras caminas: por alguien que amas, por tu iglesia, por tu ciudad."))
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }
}

/// In 4 seconds, out 6, with a tap on the wrist at each turn.
struct BreatheScreen: View {
    @State private var on = false
    @State private var inhale = false
    @State private var count = 0
    private let lines = [("Be still", "and know that I am God", "Estad quietos", "y conoced que yo soy Dios"),
                         ("The Lord is my shepherd", "I shall not want", "Jehová es mi pastor", "nada me faltará")]

    var body: some View {
        let l = lines[(count / 2) % lines.count]
        VStack(spacing: 8) {
            Circle().fill(NavyGlass.gold.opacity(0.5)).frame(width: inhale ? 110 : 55, height: inhale ? 110 : 55)
                .animation(.easeInOut(duration: inhale ? 4 : 6), value: inhale)
            Text(inhale ? (spanish ? l.2 : l.0) : (spanish ? l.3 : l.1)).font(.footnote).multilineTextAlignment(.center)
            Button(on ? L("End", "Terminar") : L("Begin", "Empezar")) { on.toggle(); if on { step() } }
        }
    }

    private func step() {
        guard on else { return }
        inhale.toggle(); count += 1
        WKInterfaceDevice.current().play(inhale ? .directionUp : .directionDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + (inhale ? 4 : 6)) { step() }
    }
}
