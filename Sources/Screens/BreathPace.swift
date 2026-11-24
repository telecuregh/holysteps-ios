import SwiftUI
import CoreMotion
import UIKit

/// Android's breathing pace (data/BreathPace.kt, ui/screens/BreathPaceScreen.kt): the phone rests on the chest or
/// belly for a minute and each breath tilts it a little; the tilt along its main direction is smoothed and its
/// rises counted. For relaxation only, not a medical device.
enum BreathPace {
    static let seconds = 60
    static let rate = 25.0
    struct Sample { let t: Double; let x, y, z: Double }      // t in seconds, acceleration in m/s² (as Android)
    enum Result { case reading(Double), failed(String) }

    static func resample(_ s: [Sample]) -> [[Double]] {
        guard s.count >= 2 else { return [] }
        var out: [[Double]] = [], j = 0, t = s.first!.t
        while t <= s.last!.t {
            while j < s.count - 2 && s[j + 1].t < t { j += 1 }
            let a = s[j], b = s[j + 1], span = b.t - a.t
            let f = span <= 0 ? 0 : min(1, max(0, (t - a.t) / span))
            out.append([a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f])
            t += 1 / rate
        }
        return out
    }

    private static func movingAverage(_ x: [Double], _ w: Int) -> [Double] {
        var out = [Double](repeating: 0, count: x.count), sum = 0.0
        for i in x.indices { sum += x[i]; if i >= w { sum -= x[i - w] }; out[i] = sum / Double(min(i + 1, w)) }
        return x.indices.map { out[min($0 + w / 2, x.count - 1)] }
    }

    private static func mainAxis(_ v: [[Double]], _ mean: [Double]) -> [Double] {
        var c = [[Double]](repeating: [0, 0, 0], count: 3)
        for p in v { for i in 0..<3 { for k in 0..<3 { c[i][k] += (p[i] - mean[i]) * (p[k] - mean[k]) } } }
        var a = [1.0, 1.0, 1.0]
        for _ in 0..<30 {
            let n = (0..<3).map { i in (0..<3).map { c[i][$0] * a[$0] }.reduce(0, +) }
            let len = n.map { $0 * $0 }.reduce(0, +).squareRoot()
            if len <= 1e-12 { return a }
            a = n.map { $0 / len }
        }
        return a
    }

    static func analyze(_ samples: [Sample]) -> Result {
        let v = resample(samples)
        if Double(v.count) < rate * 30 { return .failed("The reading was too short. Lie still for the whole minute.") }
        let mean = (0..<3).map { i in v.map { $0[i] }.reduce(0, +) / Double(v.count) }
        let axis = mainAxis(v, mean)
        let raw = v.map { p in (0..<3).map { (p[$0] - mean[$0]) * axis[$0] }.reduce(0, +) }
        let smooth = movingAverage(raw, Int(rate * 0.8))
        let trend = movingAverage(smooth, Int(rate * 12))
        let y = smooth.indices.map { smooth[$0] - trend[$0] }
        let sd = (y.map { $0 * $0 }.reduce(0, +) / Double(y.count)).squareRoot()
        if sd < 0.004 { return .failed("No breathing movement came through. Rest the phone flat on your chest or belly, screen up.") }
        if sd > 0.6 { return .failed("Too much movement. Lie back, rest the phone on your chest and keep still.") }
        let band = 0.3 * sd, minGap = Int(rate * 1.5)
        var rises: [Int] = [], low = false
        for i in y.indices {
            if y[i] < -band { low = true }
            else if low && y[i] > band {
                if rises.isEmpty || i - rises.last! >= minGap { rises.append(i) }
                low = false
            }
        }
        if rises.count < 3 { return .failed("Too few breaths came through. Rest the phone on your chest and breathe normally.") }
        let gaps = (1..<rises.count).map { Double(rises[$0] - rises[$0 - 1]) / rate }
        let perMinute = 60 / (gaps.reduce(0, +) / Double(gaps.count))
        if !(3...40).contains(perMinute) { return .failed("That reading didn't look right. Please try again, lying still.") }
        return .reading((perMinute * 10).rounded() / 10)
    }

    static func words(_ pm: Double) -> String {
        switch pm {
        case ...8: "Slow and deep: the pace that calms your body most."
        case ...12: "Relaxed and steady."
        case ...20: "A normal resting pace. Slowing down to about six a minute for a few minutes can calm you further."
        default: "Quick and shallow. A few minutes of slow breathing can help you settle."
        }
    }

    struct Reading: Codable { let at: Date; let perMinute: Double }
    static var log: [Reading] {
        guard let d = UserDefaults.standard.data(forKey: "breathReadings") else { return [] }
        return (try? JSONDecoder().decode([Reading].self, from: d)) ?? []
    }
    static func add(_ r: Reading) {
        if let d = try? JSONEncoder().encode(Array((log + [r]).suffix(120))) { UserDefaults.standard.set(d, forKey: "breathReadings") }
    }
    static func weekChange() -> (Double, Double)? {
        let now = Date(), w = 7 * 86400.0
        let a = log.filter { now.timeIntervalSince($0.at) <= w }.map(\.perMinute)
        let b = log.filter { (w + 1...2 * w).contains(now.timeIntervalSince($0.at)) }.map(\.perMinute)
        guard !a.isEmpty, !b.isEmpty else { return nil }
        return (a.reduce(0, +) / Double(a.count), b.reduce(0, +) / Double(b.count))
    }
}

struct BreathPaceView: View {
    @ObservedObject private var account = AccountStore.shared
    @State private var phase = 0          // 0 ready, 1 countdown, 2 measuring, 3 done, 4 failed
    @State private var count = 5
    @State private var elapsed = 0.0
    @State private var result = 0.0
    @State private var reason = ""
    private static let motionManager = CMMotionManager()
    private var motion: CMMotionManager { Self.motionManager }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("🌬️ BREATHING PACE").font(.hs(11, .semibold)).foregroundStyle(HS.peach).tracking(1.4)
                            T("How fast are you breathing?").font(.hs(26, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                            ItalicAccent(text: "slow the tide, settle the mind", size: 18)
                            T("Lie back and rest your phone on your chest or belly, screen up. Breathe normally for one minute; the phone feels each breath rise and fall. It buzzes when it's done.")
                                .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        }
                    }
                    card
                    let list = BreathPace.log
                    if !list.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                T("Your recent pace").font(.hs(14, .bold)).foregroundStyle(HS.text)
                                D(list.suffix(8).map { String(format: "%.0f", $0.perMinute) }.joined(separator: " · ") + " " + tr("breaths a minute"))
                                    .font(.hs(13)).foregroundStyle(HS.textSecondary)
                                if let ch = BreathPace.weekChange(), account.canUse(.wearableInsights) {
                                    D(tr("This week \(String(format: "%.1f", ch.0)), last week \(String(format: "%.1f", ch.1)).")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                                }
                            }
                        }
                    }
                    T("For relaxation and awareness only, not a medical device. If you're short of breath, have chest pain or breathing feels hard, get medical help.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stop() }
    }

    @ViewBuilder private var card: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                switch phase {
                case 1:
                    D(tr("Lie back… starting in \(count)")).font(.hs(20, .bold)).foregroundStyle(HS.text).frame(maxWidth: .infinity)
                case 2:
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().stroke(Color(hex: 0x7DD3FC).opacity(0.15), lineWidth: 8)
                            Circle().trim(from: 0, to: min(1, elapsed / Double(BreathPace.seconds))).stroke(Color(hex: 0x7DD3FC), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                            D("\(max(0, BreathPace.seconds - Int(elapsed)))").font(.system(size: 38, weight: .heavy)).foregroundStyle(HS.text)
                        }
                        .frame(width: 140, height: 140)
                        T("Breathe normally and stay still.").font(.hs(14)).foregroundStyle(HS.textSecondary)
                        Button { stop(); phase = 0 } label: { T("Cancel").font(.hs(13)).foregroundStyle(HS.textMuted) }
                    }
                    .frame(maxWidth: .infinity)
                case 3:
                    D(tr("\(String(format: "%.0f", result)) breaths a minute")).font(.hs(26, .bold)).foregroundStyle(HS.text)
                    T(BreathPace.words(result)).font(.hs(14)).foregroundStyle(HS.text)
                    Button { phase = 0 } label: { T("Check again").font(.hs(13)).foregroundStyle(HS.textMuted) }
                case 4:
                    T(reason).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    GoldButton(title: "Try again") { phase = 0 }
                default:
                    if !motion.isAccelerometerAvailable { T("This phone can't follow your breathing.").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    else {
                        T("You'll have 5 seconds to lie back before it starts.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        GoldButton(title: "Start") { countdown() }
                    }
                }
            }
        }
    }

    private func countdown() {
        count = 5; phase = 1
        Task { @MainActor in
            while count > 0 { try? await Task.sleep(nanoseconds: 1_000_000_000); guard phase == 1 else { return }; count -= 1 }
            measure()
        }
    }

    private func measure() {
        phase = 2; elapsed = 0
        UIApplication.shared.isIdleTimerDisabled = true
        var samples: [BreathPace.Sample] = []
        var start: Double = 0
        motion.accelerometerUpdateInterval = 1 / 50
        motion.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data, phase == 2 else { return }
            if start == 0 { start = a.timestamp }
            let t = a.timestamp - start
            samples.append(.init(t: t, x: a.acceleration.x * 9.81, y: a.acceleration.y * 9.81, z: a.acceleration.z * 9.81))
            elapsed = t
            if t >= Double(BreathPace.seconds) {
                stop()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                switch BreathPace.analyze(samples) {
                case .reading(let pm): BreathPace.add(.init(at: Date(), perMinute: pm)); result = pm; phase = 3
                case .failed(let why): reason = why; phase = 4
                }
            }
        }
    }

    private func stop() {
        motion.stopAccelerometerUpdates()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
