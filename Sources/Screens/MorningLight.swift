import SwiftUI
import AVFoundation

/// Android's MorningLight (MorningLight.kt, MorningLightScreen.kt): daylight soon after waking sets the body clock, so
/// sleep comes easier that night. The light level says how long to stay out; Apple Health's sleep shows whether it
/// helps. iPhones don't let apps read the light sensor, so the back camera's exposure is used as a light meter instead.
enum MorningLight {
    static func isMorning(_ hour: Int) -> Bool { (5...10).contains(hour) }

    enum Level: CaseIterable {
        case indoor, dim, bright, sun
        var label: String { switch self { case .indoor: "Indoor light"; case .dim: "Dim daylight"; case .bright: "Bright daylight"; case .sun: "Full sun" } }
        var emoji: String { switch self { case .indoor: "💡"; case .dim: "🌥️"; case .bright: "⛅"; case .sun: "☀️" } }
        var minutes: Int { switch self { case .indoor: 0; case .dim: 30; case .bright: 15; case .sun: 10 } }
        var advice: String {
            switch self {
            case .indoor: "Even a bright room is far dimmer than outdoors. Step outside, or stand right by a window."
            case .dim: "Overcast or shade. About 30 minutes outside gives you a good morning dose."
            case .bright: "Bright outside. About 15 minutes is enough."
            case .sun: "Full sun. About 10 minutes does it. Don't look straight at the sun."
            }
        }
    }

    /// Indoor rooms are under ~1,000 lux; overcast days 1,000–10,000; bright days 10,000–30,000; sun above.
    static func level(_ lux: Double) -> Level {
        switch lux { case ..<1_000: .indoor; case ..<10_000: .dim; case ..<30_000: .bright; default: .sun }
    }

    static var days: Set<String> { Set(UserDefaults.standard.stringArray(forKey: "morningLightDays") ?? []) }
    static func note() {
        var d = days; d.insert(AppStore.dayKey())
        UserDefaults.standard.set(Array(d.sorted().suffix(120)), forKey: "morningLightDays")
    }

    private static func plus(_ day: String, _ n: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: day), let e = Calendar.current.date(byAdding: .day, value: n, to: d) else { return day }
        return f.string(from: e)
    }

    /// The morning a light day helps is the night after it, which Apple Health records on the next day.
    static func wakeDaysAfter(_ light: Set<String>) -> Set<String> { Set(light.map { plus($0, 1) }) }

    /// Mornings in a row with light, counting back from today (or yesterday, if today's isn't done yet).
    static func streak(_ light: Set<String>, today: String) -> Int {
        var d = light.contains(today) ? today : plus(today, -1), n = 0
        while light.contains(d) { n += 1; d = plus(d, -1) }
        return n
    }

    struct Insight { let withMin: Int; let withoutMin: Int; var diffMin: Int { withMin - withoutMin } }

    /// Android's SleepLibrary.insight: sleep after light mornings against other nights, 30 days, at least 3 of each.
    static func insight(sleep: [String: Int], wakeDays: Set<String>, today: String) -> Insight? {
        let from = plus(today, -30)
        let nights = sleep.filter { $0.key > from && $0.key <= today && (120...960).contains($0.value) }
        let with = nights.filter { wakeDays.contains($0.key) }.map(\.value), without = nights.filter { !wakeDays.contains($0.key) }.map(\.value)
        guard with.count >= 3, without.count >= 3 else { return nil }
        return Insight(withMin: with.reduce(0, +) / with.count, withoutMin: without.reduce(0, +) / without.count)
    }

    static func hm(_ m: Int) -> String { "\(m / 60)h \(String(format: "%02d", m % 60))m" }
}

/// The back camera as a light meter: from its automatic exposure, EV100 = log2(N²/t) − log2(ISO/100), and
/// illuminance ≈ 2.5 × 2^EV100 lux. Rough, but plenty to tell a room from shade from sun. Nothing is recorded.
final class LightMeter: NSObject, ObservableObject {
    @Published private(set) var lux: Double?
    @Published private(set) var denied = false
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "light-meter")
    private var device: AVCaptureDevice?
    private var timer: Timer?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in DispatchQueue.main.async { if ok { self.run() } else { self.denied = true } } }
        default: denied = true
        }
    }

    private func run() {
        queue.async { [self] in
            if session.inputs.isEmpty {
                session.beginConfiguration()
                session.sessionPreset = .low
                guard let d = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: d), session.canAddInput(input) else { session.commitConfiguration(); return }
                session.addInput(input)
                let out = AVCaptureVideoDataOutput()
                if session.canAddOutput(out) { session.addOutput(out) }
                session.commitConfiguration()
                device = d
            }
            session.startRunning()
        }
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in self?.read() }
        }
    }

    private func read() {
        guard let d = device else { return }
        let t = CMTimeGetSeconds(d.exposureDuration), iso = Double(d.iso), n = Double(d.lensAperture)
        guard t > 0, iso > 0, n > 0 else { return }
        let ev100 = log2(n * n / t) - log2(iso / 100)
        lux = 2.5 * pow(2, ev100)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }
}

struct MorningLightView: View {
    @StateObject private var meter = LightMeter()
    @State private var measuring = false
    @State private var days = MorningLight.days
    @State private var timerLeft = -1
    @State private var insight: MorningLight.Insight?
    @State private var hasSleep = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let today = AppStore.dayKey()
        let done = days.contains(today)
        let streak = MorningLight.streak(days, today: today)
        let level = meter.lux.map(MorningLight.level)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    T("☀️ MORNING LIGHT").font(.hs(12, .bold)).foregroundStyle(Color(hex: 0xFCD34D))
                    T("Greet the morning").font(.hs(26, .heavy)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    D(tr("Daylight soon after you wake sets your body clock, so you feel more awake now and sleep comes easier tonight.") + " "
                      + tr("\"This is the day the Lord has made\" (Psalm 118:24)."))
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        if meter.denied {
                            T("Without the camera, go by eye: about 10 minutes in sun, 30 on a cloudy day.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        } else if !measuring {
                            T("Your iPhone's camera can measure how bright it is. Nothing is recorded.").font(.hs(12)).foregroundStyle(HS.textMuted)
                            Button { measuring = true; meter.start() } label: {
                                T("Measure the light").font(.hs(14, .semibold)).foregroundStyle(HS.peach)
                            }
                            .frame(minHeight: 44)
                        } else {
                            T("Point the back camera at the sky (not at the sun).").font(.hs(12)).foregroundStyle(HS.textMuted)
                            D(level.map { "\($0.emoji) \(tr($0.label)) · \(Int(meter.lux ?? 0).formatted()) lux" } ?? tr("Reading the light…"))
                                .font(.hs(22, .heavy)).foregroundStyle(HS.text)
                                .accessibilityAddTraits(.updatesFrequently)
                            if let level { T(level.advice).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                        }
                        Divider().overlay(HS.overlay(0.1)).padding(.vertical, 4)
                        if done {
                            D(tr("✓ Morning light done today") + (streak > 1 ? " · " + tr("{0} mornings in a row").replacingOccurrences(of: "{0}", with: "\(streak)") : ""))
                                .font(.hs(14, .semibold)).foregroundStyle(Color(hex: 0xFCD34D))
                        } else if timerLeft > 0 {
                            D(tr("Stay out:") + " \(timerLeft / 60):\(String(format: "%02d", timerLeft % 60))").font(.hs(18, .bold)).foregroundStyle(HS.text)
                            Button { timerLeft = -1 } label: { T("Walking counts too. Stop anytime").font(.hs(12)).foregroundStyle(HS.textMuted) }
                        } else {
                            let mins = (level?.minutes).flatMap { $0 > 0 ? $0 : nil } ?? 20
                            HStack(spacing: 10) {
                                Button { timerLeft = mins * 60 } label: {
                                    D(tr("Start {0} minutes outside").replacingOccurrences(of: "{0}", with: "\(mins)"))
                                        .font(.hs(13, .bold)).foregroundStyle(Color(hex: 0x422006))
                                        .padding(.horizontal, 18).padding(.vertical, 10).background(Capsule().fill(Color(hex: 0xFCD34D)))
                                }
                                Button { MorningLight.note(); days = MorningLight.days } label: { T("I already did").font(.hs(13)).foregroundStyle(HS.textMuted) }
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        T("⌚ Does it help you sleep?").font(.hs(14, .bold)).foregroundStyle(HS.text)
                        D(insightText).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Morning light"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(tick) { _ in
            guard timerLeft > 0 else { return }
            timerLeft -= 1
            if timerLeft == 0 { MorningLight.note(); days = MorningLight.days; timerLeft = -1 }
        }
        .onDisappear { meter.stop() }
        .task {
            let sleep = await StepsModel.shared.sleepNights(days: 31)
            hasSleep = !sleep.isEmpty
            insight = MorningLight.insight(sleep: sleep, wakeDays: MorningLight.wakeDaysAfter(days), today: AppStore.dayKey())
        }
    }

    private var insightText: String {
        if let i = insight, i.diffMin >= 10 {
            return tr("After mornings with light you slept {0}, about {1} minutes more than other nights.")
                .replacingOccurrences(of: "{0}", with: MorningLight.hm(i.withMin)).replacingOccurrences(of: "{1}", with: "\(i.diffMin)")
        }
        if let i = insight {
            return tr("After mornings with light you slept {0}, compared with {1} on other nights.")
                .replacingOccurrences(of: "{0}", with: MorningLight.hm(i.withMin)).replacingOccurrences(of: "{1}", with: MorningLight.hm(i.withoutMin))
        }
        return hasSleep ? tr("Get morning light on a few days and Apple Health will show whether you sleep better after them.")
                        : tr("Wear your Apple Watch to bed, or let HolySteps read sleep from Apple Health, to see whether you sleep better after mornings with light.")
    }
}
