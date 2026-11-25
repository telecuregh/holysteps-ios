import SwiftUI
import MapKit
import CoreLocation
import CoreMotion
import AVFoundation

// Android's live walk (data/WalkCoach.kt, WalkRecorder.kt; ui/screens/WalkLiveScreens.kt, WalkSummaryScreens.kt):
// plans with warm-up and cool-down, pace bands, a one-line coach, calories from the 2024 Compendium of Physical
// Activities, the route on a map, and the finished walks kept on the phone.

enum PaceBand: Int, CaseIterable, Codable {
    case stroll, easy, moderate, brisk, power
    var label: String { ["Stroll", "Easy", "Moderate", "Brisk", "Power"][rawValue] }
    var minKmh: Double { [0, 3.2, 4.0, 5.6, 7.0][rawValue] }
    var minCadence: Int { [0, 90, 100, 120, 130][rawValue] }
    var color: Color { Color(hex: [0x9F948B, 0x64A5E8, 0x56B892, 0xF3D5C0, 0xE57A9E][rawValue]) }
    var counts: Bool { rawValue >= PaceBand.moderate.rawValue }
    static func from(kmh: Double) -> PaceBand { allCases.last { kmh >= $0.minKmh } ?? .stroll }
    static func from(cadence: Int) -> PaceBand { allCases.last { cadence >= $0.minCadence } ?? .stroll }
}

struct WalkPhase { enum Kind: String { case warmUp = "Warm-up", main = "Main", recover = "Recover", coolDown = "Cool-down" }
    let kind: Kind; let seconds: Int; let target: PaceBand; let cue: String }

struct WalkPlan: Identifiable {
    let id, title, emoji, about: String
    let phases: [WalkPhase]
    var isFree: Bool { phases.isEmpty }
    var minutes: Int { Int((Double(phases.reduce(0) { $0 + $1.seconds }) / 60).rounded()) }
    func withoutWarmCool() -> WalkPlan {
        WalkPlan(id: id, title: title, emoji: emoji, about: about, phases: phases.filter { $0.kind != .warmUp && $0.kind != .coolDown })
    }
    /// (phase index, phase, seconds left in it, plan finished)
    func cursor(_ elapsed: Int) -> (Int, WalkPhase?, Int, Bool) {
        guard !phases.isEmpty else { return (0, nil, 0, false) }
        var start = 0
        for (i, p) in phases.enumerated() {
            let end = start + p.seconds
            if elapsed < end { return (i, p, end - elapsed, false) }
            start = end
        }
        return (phases.count - 1, phases.last, 0, true)
    }

    static let warmCue = "Start slow. Roll your shoulders, swing your arms, and let your breathing build."
    static let coolCue = "Ease off gradually. Breathe deep, and stretch your calves and hips when you stop."
    static func cue(_ b: PaceBand) -> String {
        switch b {
        case .power: "Drive your arms and push off each step. You should only manage short sentences."
        case .brisk: "Quicker, shorter steps. Arms bent, posture tall, eyes ahead."
        case .moderate: "A pace where you can talk, but not sing. Steady rhythm."
        default: "Relaxed and easy. Breathe through your nose if you can."
        }
    }
    static let recoverCue = "Let your breathing settle. Easy steps."
    private static func warm(_ s: Int) -> WalkPhase { WalkPhase(kind: .warmUp, seconds: s, target: .easy, cue: warmCue) }
    private static func cool(_ s: Int) -> WalkPhase { WalkPhase(kind: .coolDown, seconds: s, target: .easy, cue: coolCue) }
    private static func main(_ s: Int, _ b: PaceBand) -> WalkPhase { WalkPhase(kind: .main, seconds: s, target: b, cue: cue(b)) }
    private static func recover(_ s: Int, _ b: PaceBand = .easy) -> WalkPhase { WalkPhase(kind: .recover, seconds: s, target: b, cue: recoverCue) }

    /// Guided plans past Easy 20 come with the Fitness plan (Feature.WALK_PLUS).
    var plus: Bool { id != "free" && id != "easy_20" }
    static let free = WalkPlan(id: "free", title: "Free walk", emoji: "🧭", about: "No plan, no targets. Just walk at your own pace.", phases: [])
    static let all: [WalkPlan] = [
        free,
        WalkPlan(id: "easy_20", title: "Easy 20", emoji: "🌿", about: "A gentle start: 3 min warm-up, 14 min easy, 3 min cool-down.",
                 phases: [warm(180), main(840, .easy), cool(180)]),
        WalkPlan(id: "steady_30", title: "Steady 30", emoji: "🚶", about: "5 min warm-up, 20 min at a moderate pace, 5 min cool-down.",
                 phases: [warm(300), main(1200, .moderate), cool(300)]),
        WalkPlan(id: "brisk_30", title: "Brisk 30", emoji: "⚡", about: "5 min warm-up, 20 min brisk, 5 min cool-down.",
                 phases: [warm(300), main(1200, .brisk), cool(300)]),
        WalkPlan(id: "intervals_30", title: "Brisk Intervals 30", emoji: "⏱️", about: "4 rounds of 3 min brisk and 2 min easy, with warm-up and cool-down.",
                 phases: [warm(300)] + (1...4).flatMap { _ in [main(180, .brisk), recover(120)] } + [cool(300)]),
        WalkPlan(id: "long_45", title: "Long & Moderate 45", emoji: "🏞️", about: "5 min warm-up, 35 min moderate, 5 min cool-down. Builds endurance.",
                 phases: [warm(300), main(2100, .moderate), cool(300)]),
        WalkPlan(id: "power_25", title: "Power Intervals 25", emoji: "🔥", about: "5 rounds of 2 min power and 1 min moderate, with warm-up and cool-down.",
                 phases: [warm(300)] + (1...5).flatMap { _ in [main(120, .power), recover(60, .moderate)] } + [cool(300)]),
    ]
    static func byId(_ id: String) -> WalkPlan { all.first { $0.id == id } ?? free }
}

/// coachLine: one short line for right now.
func walkCoachLine(_ phase: WalkPhase?, _ band: PaceBand?) -> String {
    guard let phase else {
        switch band {
        case nil: return "Walk when you're ready."
        case .stroll: return "Easy stroll. Pick it up whenever you like."
        case .easy: return "Nice easy pace."
        case .moderate: return "Moderate pace. This counts toward your weekly active minutes."
        case .brisk: return "Brisk. Great for your heart."
        case .power: return "Power pace. Each minute here counts as two active minutes."
        }
    }
    guard let band else { return "Start moving when you're ready. \(phase.cue)" }
    let diff = band.rawValue - phase.target.rawValue
    switch phase.kind {
    case .warmUp, .coolDown: return diff > 1 ? "A little fast for a \(phase.kind.rawValue.lowercased()). Ease off." : phase.cue
    case .recover: return diff > 1 ? "Recovery time. Ease off and breathe." : phase.cue
    case .main:
        if diff < 0 { return "Pick it up to \(phase.target.label.lowercased()). \(phase.cue)" }
        if diff > 1 { return "Ease back to \(phase.target.label.lowercased()). You'll last longer." }
        return "On target. \(phase.cue)"
    }
}

/// WalkEnergy: METs for walking at a speed on level ground (2024 Adult Compendium, read off the line between rows).
enum WalkEnergy {
    static let walking: [(Double, Double)] = [(2.41, 2.3), (3.54, 2.8), (4.02, 3.0), (4.99, 3.8), (5.95, 4.8), (6.76, 5.5), (7.56, 7.0), (8.45, 8.5)]
    static let treadmill: [(Double, Double)] = [(1.20, 2.1), (1.61, 2.3), (2.49, 2.8), (3.54, 3.0), (4.35, 3.5), (5.15, 3.8), (5.95, 4.8), (6.76, 5.8), (7.56, 6.8), (8.45, 8.3)]
    static let stillMet = 1.5
    static func between(_ t: [(Double, Double)], _ x: Double) -> Double {
        if x.isNaN || x <= t[0].0 { return t[0].1 }
        for i in 1..<t.count where x <= t[i].0 {
            let (x0, y0) = t[i - 1], (x1, y1) = t[i]
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
        }
        return t[t.count - 1].1
    }
    static func met(kmh: Double, treadmill tm: Bool) -> Double { between(tm ? treadmill : walking, kmh) }
}

struct RoutePoint: Codable, Hashable { let lat: Double; let lon: Double; let band: Int; let seg: Int }

struct WalkRecord: Codable, Identifiable, Hashable {
    let id: String
    let start: Date, end: Date
    let outdoor: Bool
    let planId: String
    let activeSec: Int, stillSec: Int
    let distanceM: Int, steps: Int
    let bandSec: [Int]
    let avgKmh: Double
    let kcal: Int
    let route: [RoutePoint]
    var activeMinutes: Int { (bandSec.enumerated().reduce(0) { $0 + ($1.offset >= 2 ? $1.element * ($1.offset == 4 ? 2 : 1) : 0) }) / 60 }
}

final class WalkStore: ObservableObject {
    static let shared = WalkStore()
    @Published private(set) var walks: [WalkRecord] = []
    private var url: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("walks.json") }
    private init() {
        if let d = try? Data(contentsOf: url), let w = try? JSONDecoder().decode([WalkRecord].self, from: d) { walks = w }
    }
    func add(_ r: WalkRecord) {
        walks.insert(r, at: 0)
        walks = Array(walks.prefix(300))
        save()
    }
    func remove(_ id: String) { walks.removeAll { $0.id == id }; save() }
    func erase() { walks = []; save() }
    private func save() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(walks) { try? d.write(to: url, options: [.atomic, .completeFileProtection]) }
    }
    /// Moderate-or-harder minutes this week (Monday to today); power minutes count double.
    var weekActiveMinutes: Int {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let monday = cal.date(byAdding: .day, value: -((cal.component(.weekday, from: today) + 5) % 7), to: today) ?? today
        return walks.filter { $0.start >= monday }.reduce(0) { $0 + $1.activeMinutes }
    }
}

/// Records one walk: the route and distance outdoors, steps and pace from the phone, time in each pace band.
@MainActor
final class WalkRecorder: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WalkRecorder()

    @Published private(set) var started = false
    @Published var paused = false
    @Published private(set) var outdoor = true
    @Published private(set) var plan = WalkPlan.free
    @Published private(set) var activeSec = 0
    @Published private(set) var distanceM = 0.0
    @Published private(set) var steps = 0
    @Published private(set) var speedKmh: Double?
    @Published private(set) var band: PaceBand?
    @Published private(set) var route: [RoutePoint] = []
    @Published private(set) var kcal = 0.0
    @Published private(set) var bandSec = [0, 0, 0, 0, 0]
    @Published private(set) var stillSec = 0
    @Published private(set) var weakSignal = false
    @Published var finished: WalkRecord?

    private let location = CLLocationManager()
    private let pedometer = CMPedometer()
    private var timer: Timer?
    private var lastFix: CLLocation?
    private var samples: [(Date, Double)] = []       // (time, total meters), for speed over the last 15 s
    private var segment = 0
    private var pedometerSteps = 0, pedometerBase = 0
    private var pedometerDistance = 0.0, pedometerBaseDistance = 0.0
    private var cadence: Int?
    private var startDate = Date()
    private var lastCue = ""
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        location.delegate = self
        location.activityType = .fitness
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 3
    }

    var cursor: (Int, WalkPhase?, Int, Bool) { plan.cursor(activeSec) }

    func start(outdoor o: Bool, plan p: WalkPlan) {
        guard !started else { return }
        SermonPlayer.shared.stop(); BibleListening.shared.stop()
        outdoor = o; plan = p; started = true; paused = false
        activeSec = 0; distanceM = 0; steps = 0; speedKmh = nil; band = nil; route = []; kcal = 0; bandSec = [0, 0, 0, 0, 0]; stillSec = 0
        samples = []; lastFix = nil; segment = 0; pedometerSteps = 0; pedometerBase = 0; pedometerDistance = 0; pedometerBaseDistance = 0
        startDate = Date(); finished = nil
        if o {
            location.requestWhenInUseAuthorization()
            location.allowsBackgroundLocationUpdates = true
            location.showsBackgroundLocationIndicator = true
            location.startUpdatingLocation()
        }
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let data else { return }
                Task { @MainActor in self?.onPedometer(data) }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        UIApplication.shared.isIdleTimerDisabled = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
    }

    private func onPedometer(_ d: CMPedometerData) {
        let total = d.numberOfSteps.intValue
        let dist = d.distance?.doubleValue ?? 0
        if paused { pedometerBase = total - pedometerSteps; pedometerBaseDistance = dist - pedometerDistance; return }
        pedometerSteps = total - pedometerBase
        pedometerDistance = dist - pedometerBaseDistance
        steps = pedometerSteps
        cadence = d.currentCadence.map { Int(($0.doubleValue * 60).rounded()) }
        if !outdoor { distanceM = pedometerDistance > 0 ? pedometerDistance : Double(steps) * 0.70 }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in locations.forEach { self.onFix($0) } }
    }

    private func onFix(_ f: CLLocation) {
        guard started, outdoor, !paused else { return }
        weakSignal = f.horizontalAccuracy > 35
        guard f.horizontalAccuracy >= 0, f.horizontalAccuracy <= 35 else { return }
        if let prev = lastFix {
            let d = f.distance(from: prev)
            let dt = f.timestamp.timeIntervalSince(prev.timestamp)
            if dt > 0, d / dt > 7 { lastFix = f; return }      // faster than any walk: a GPS jump
            distanceM += d
        }
        lastFix = f
        samples.append((f.timestamp, distanceM))
        samples.removeAll { f.timestamp.timeIntervalSince($0.0) > 15 }
        if let first = samples.first, f.timestamp.timeIntervalSince(first.0) >= 5 {
            speedKmh = (distanceM - first.1) / f.timestamp.timeIntervalSince(first.0) * 3.6
        }
        if let last = route.last, CLLocation(latitude: last.lat, longitude: last.lon).distance(from: f) < 4, last.seg == segment { return }
        route.append(RoutePoint(lat: f.coordinate.latitude, lon: f.coordinate.longitude, band: band?.rawValue ?? -1, seg: segment))
    }

    private func tick() {
        guard started, !paused else { return }
        activeSec += 1
        if outdoor, let s = speedKmh, let last = lastFix, Date().timeIntervalSince(last.timestamp) < 10 {
            band = s < 1 && (cadence ?? 0) < 20 ? nil : PaceBand.from(kmh: s)
        } else if let c = cadence, c >= 20 {
            band = PaceBand.from(cadence: c)
            speedKmh = outdoor ? speedKmh : Double(c) * 0.70 * 60 / 1000
        } else { band = nil }
        if let b = band { bandSec[b.rawValue] += 1 } else { stillSec += 1 }
        let kg = 70.0
        let met = band.map { WalkEnergy.met(kmh: speedKmh ?? $0.minKmh + 0.4, treadmill: !outdoor) } ?? WalkEnergy.stillMet
        kcal += met * kg / 3600
        // Speak the coach line when it changes (the plan's phases, and gentle pace nudges), at most every 20 seconds.
        let line = walkCoachLine(cursor.1, band)
        if line != lastCue && (activeSec % 20 == 0 || cursor.2 == (cursor.1?.seconds ?? -1) - 1) {
            lastCue = line
            let u = AVSpeechUtterance(string: tr(line))
            u.voice = AVSpeechSynthesisVoice(language: I18n.shared.speechLanguage)
            synth.speak(u)
        }
    }

    func togglePause() {
        paused.toggle()
        if !paused { segment += 1; lastFix = nil; samples = [] }
    }

    func finish() {
        guard started else { return }
        stop()
        let avg = activeSec > 0 ? distanceM / Double(activeSec) * 3.6 : 0
        let r = WalkRecord(id: UUID().uuidString, start: startDate, end: Date(), outdoor: outdoor, planId: plan.id, activeSec: activeSec,
                           stillSec: stillSec, distanceM: Int(distanceM.rounded()), steps: steps, bandSec: bandSec, avgKmh: avg,
                           kcal: Int(kcal.rounded()), route: route)
        if activeSec >= 60 { WalkStore.shared.add(r); ActivityLog.shared.add(.walk) }
        finished = r
    }

    func discard() { stop(); finished = nil }

    private func stop() {
        started = false
        timer?.invalidate(); timer = nil
        location.stopUpdatingLocation()
        location.allowsBackgroundLocationUpdates = false
        pedometer.stopUpdates()
        synth.stopSpeaking(at: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

// MARK: - Screens

func milesText(_ m: Double) -> String { String(format: "%.2f", m / 1609.344) }
func clock(_ s: Int) -> String { s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60) }
func paceText(_ kmh: Double?) -> String {
    guard let kmh, kmh > 0.5 else { return "—" }
    let minPerMile = 60 / (kmh / 1.609344)
    return String(format: "%d:%02d", Int(minPerMile), Int((minPerMile - floor(minPerMile)) * 60))
}

/// Start a Walk: outdoor or indoor, a plan, warm-up and cool-down, then the live screen.
struct WalkSetupView: View {
    @ObservedObject private var rec = WalkRecorder.shared
    @Environment(\.dismiss) private var dismiss
    @State private var outdoor = true
    @State private var planId = "free"
    @State private var warmCool = true
    @State private var paywall = false
    @ObservedObject private var account = AccountStore.shared
    @ObservedObject private var media = TrainerMedia.shared

    var body: some View {
        ZStack {
            HSBackground()
            if rec.started { WalkRecordingView() }
            else if let done = rec.finished { WalkSummaryView(record: done) { rec.finished = nil; dismiss() } }
            else { setup }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(rec.started ? .hidden : .automatic, for: .navigationBar)
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                T("Start a Walk").font(.hs(26)).foregroundStyle(HS.text)
                ItalicAccent(text: "Every step strengthens body and spirit", size: 17)
                SubTabs(tabs: ["Outdoor", "Indoor"], selected: Binding(get: { outdoor ? 0 : 1 }, set: { outdoor = $0 == 0 })).padding(.horizontal, -20)
                T(outdoor ? "Your route is drawn on the map as you go." : "For a treadmill or walking indoors: steps and pace, no map.")
                    .font(.hs(12)).foregroundStyle(HS.textMuted)
                SectionHeader(title: "Plan").padding(.horizontal, -20)
                ForEach(WalkPlan.all) { p in
                    let on = planId == p.id
                    let locked = p.plus && !account.canUse(.walkPlus)
                    Button { if locked { paywall = true } else { planId = p.id } } label: {
                        HStack(spacing: 12) {
                            T(p.emoji).font(.system(size: 18)).frame(width: 36, height: 36).background(Circle().fill(HS.overlay(0.06)))
                            VStack(alignment: .leading, spacing: 2) {
                                T(p.isFree ? p.title : "\(p.title) · \(p.minutes) min").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                T(p.about).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            if locked { T("👑 Fitness plan").font(.hs(10, .semibold)).foregroundStyle(HS.gold) }
                            if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(HS.goldButton) }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(on ? HS.goldButton.opacity(0.16) : HS.cardFill))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? Color(hex: 0xD9B49F) : Color(hex: 0xD9B49F).opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                if let demo = media.clip(planId) { TrainerCard(clip: demo) }
                if !WalkPlan.byId(planId).isFree {
                    Toggle(isOn: $warmCool) { T("Warm-up and cool-down").font(.hs(14)).foregroundStyle(HS.text) }.tint(HS.goldButton)
                }
                GoldButton(title: "Start walking") {
                    let p = WalkPlan.byId(planId)
                    rec.start(outdoor: outdoor, plan: warmCool ? p : p.withoutWarmCool())
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
        .sheet(isPresented: $paywall) { PlansView(feature: .walkPlus) }
        .task { await media.refresh() }
    }
}

struct WalkRecordingView: View {
    @ObservedObject private var rec = WalkRecorder.shared
    @State private var confirmEnd = false

    var body: some View {
        let cur = rec.cursor
        VStack(spacing: 0) {
            if rec.outdoor {
                WalkMapView(route: rec.route, follow: true).frame(maxHeight: .infinity).ignoresSafeArea(edges: .top)
            } else {
                Spacer()
                Image(systemName: "figure.walk.treadmill").font(.system(size: 80)).foregroundStyle(HS.body)
                Spacer()
            }
            VStack(spacing: 12) {
                if let p = cur.1 {
                    HStack {
                        T(p.kind.rawValue).font(.hs(12, .semibold)).foregroundStyle(p.target.color)
                        Spacer()
                        D(clock(cur.2)).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                }
                T(walkCoachLine(cur.1, rec.band)).font(.hs(14)).foregroundStyle(HS.text).multilineTextAlignment(.center)
                HStack {
                    tile("Time", clock(rec.activeSec), "")
                    tile("Distance", milesText(rec.distanceM), "mi")
                    tile("Pace", paceText(rec.speedKmh), "min/mi")
                }
                HStack {
                    tile("Steps", rec.steps.formatted(), "")
                    tile("Calories", "\(Int(rec.kcal))", "kcal")
                    tile("Pace band", rec.band?.label ?? "Still", "")
                }
                if rec.weakSignal && rec.outdoor { T("Finding your location…").font(.hs(11)).foregroundStyle(HS.textMuted) }
                HStack(spacing: 14) {
                    Button { rec.togglePause() } label: {
                        T(rec.paused ? "Resume" : "Pause").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(HS.overlay(0.1)))
                    }
                    Button { confirmEnd = true } label: {
                        T("Finish").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(HS.goldButton))
                    }
                }
            }
            .padding(20)
            .background(HS.solidSurface.opacity(0.96).ignoresSafeArea(edges: .bottom))
        }
        .confirmationDialog(tr("Finish this walk?"), isPresented: $confirmEnd, titleVisibility: .visible) {
            Button(tr("Finish and save")) { rec.finish() }
            Button(tr("Discard"), role: .destructive) { rec.discard() }
        }
    }

    private func tile(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            D(value).font(.hs(20, .semibold)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.6)
            T(unit.isEmpty ? label : "\(label) (\(unit))").font(.hs(10)).foregroundStyle(HS.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WalkSummaryView: View {
    let record: WalkRecord
    var onDone: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                T(record.activeSec >= 60 ? "Walk saved" : "Walk").font(.hs(26)).foregroundStyle(HS.text)
                D(record.start.formatted(.dateTime.weekday(.wide).month().day().hour().minute().locale(I18n.shared.locale)))
                    .font(.hs(13)).foregroundStyle(HS.textMuted)
                if record.route.count >= 2 {
                    WalkMapView(route: record.route, follow: false).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 18))
                }
                HStack(spacing: 10) {
                    stat(milesText(Double(record.distanceM)), "mi")
                    stat(clock(record.activeSec), "time")
                    stat(record.steps.formatted(), "steps")
                    stat("\(record.kcal)", "kcal")
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        T("Time at each pace").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        ForEach(PaceBand.allCases, id: \.self) { b in
                            let s = record.bandSec[b.rawValue]
                            if s > 0 {
                                HStack {
                                    Circle().fill(b.color).frame(width: 8, height: 8)
                                    T(b.label).font(.hs(13)).foregroundStyle(HS.textSecondary)
                                    Spacer()
                                    D(clock(s)).font(.hs(13)).foregroundStyle(HS.text)
                                }
                            }
                        }
                        T("\(record.activeMinutes) active minutes toward your 150 this week").font(.hs(12)).foregroundStyle(HS.body)
                    }
                }
                if let onDone { GoldButton(title: "Done", action: onDone) }
            }
            .padding(20)
        }
    }

    private func stat(_ v: String, _ unit: String) -> some View {
        GlassCard(padding: 10) {
            VStack(spacing: 2) {
                D(v).font(.hs(16, .semibold)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.6)
                T(unit).font(.hs(10)).foregroundStyle(HS.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// The route on Apple Maps, colored by pace, with no line across a pause.
struct WalkMapView: View {
    let route: [RoutePoint]
    let follow: Bool
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $camera) {
            if follow { UserAnnotation() }
            ForEach(segments.indices, id: \.self) { i in
                MapPolyline(coordinates: segments[i].map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
                    .stroke(Color(hex: 0xD8B27A), lineWidth: 5)
            }
            if let first = route.first, !follow {
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)) {
                    Circle().fill(Color(hex: 0x56B892)).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.hybrid(pointsOfInterest: .excludingAll))
        .onAppear { if !follow { camera = .automatic } }
        .accessibilityLabel(tr("Map of your walk"))
    }

    private var segments: [[RoutePoint]] {
        Dictionary(grouping: route, by: \.seg).sorted { $0.key < $1.key }.map(\.value).filter { $0.count >= 2 }
    }
}

/// Progress › your walks, newest first.
struct WalkHistoryView: View {
    @ObservedObject private var store = WalkStore.shared
    var body: some View {
        ZStack {
            HSBackground()
            if store.walks.isEmpty {
                T("Your walks will show here. Start one from Today.").font(.hs(14)).foregroundStyle(HS.textMuted).padding(30)
            } else {
                List {
                    ForEach(store.walks) { w in
                        NavigationLink { ZStack { HSBackground(); WalkSummaryView(record: w) } } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                D(w.start.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute().locale(I18n.shared.locale)))
                                    .font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                D("\(milesText(Double(w.distanceM))) mi · \(clock(w.activeSec)) · \(w.steps.formatted()) \(tr("steps"))")
                                    .font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                        }
                        .listRowBackground(HS.cardFill)
                    }
                    .onDelete { idx in idx.map { store.walks[$0].id }.forEach(store.remove) }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(D(tr("Your walks")))
    }
}
