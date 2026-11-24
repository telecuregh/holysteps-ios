import SwiftUI
import AVFoundation

/// Android's calm check (data/CalmCheck.kt, ui/screens/CalmCheckScreen.kt): heart rate and beat-to-beat variability
/// (RMSSD) from a fingertip over the back camera with the light on, for 30 seconds. Wellness only, not a medical
/// device; everything is worked out and kept on this phone. Measuring is free; the history insight comes with a plan.
enum CalmSignal {
    static let seconds = 30
    static let rate = 30.0

    struct Sample { let t: Double; let value: Double }   // t in seconds
    enum Result { case reading(bpm: Int, rmssd: Int), failed(String) }

    static func fingerOn(luma: Double, red: Double) -> Bool { luma >= 35 && red >= 12 }

    static func resample(_ samples: [Sample]) -> [Double] {
        guard samples.count >= 2 else { return [] }
        let s = samples.sorted { $0.t < $1.t }
        let t0 = s.first!.t, n = Int((s.last!.t - t0) * rate)
        guard n >= 2 else { return [] }
        var out = [Double](repeating: 0, count: n), j = 0
        for i in 0..<n {
            let t = t0 + Double(i) / rate
            while j < s.count - 2 && s[j + 1].t < t { j += 1 }
            let a = s[j], b = s[j + 1], span = b.t - a.t
            out[i] = span <= 0 ? a.value : a.value + (b.value - a.value) * min(1, max(0, (t - a.t) / span))
        }
        return out
    }

    private static func movingAverage(_ x: [Double], _ window: Int) -> [Double] {
        let w = max(1, window)
        var out = [Double](repeating: 0, count: x.count), sum = 0.0
        for i in x.indices {
            sum += x[i]
            if i >= w { sum -= x[i - w] }
            out[i] = sum / Double(min(i + 1, w))
        }
        let half = w / 2
        return x.indices.map { out[min($0 + half, x.count - 1)] }
    }

    private static func peakPosition(_ y: [Double], _ i: Int) -> Double {
        guard i > 0, i < y.count - 1 else { return Double(i) }
        let a = y[i - 1], b = y[i], c = y[i + 1], bend = a - 2 * b + c
        return bend < 0 ? Double(i) + min(0.5, max(-0.5, 0.5 * (a - c) / bend)) : Double(i)
    }

    static func analyze(_ samples: [Sample]) -> Result {
        let x = resample(samples)
        if Double(x.count) < rate * 15 { return .failed("The reading was too short. Hold still for the full 30 seconds.") }
        let trend = movingAverage(x, Int(rate))
        let smooth = movingAverage(x.indices.map { x[$0] - trend[$0] }, 5)
        let y = smooth.map { -$0 }
        let mean = y.reduce(0, +) / Double(y.count)
        let sd = (y.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(y.count)).squareRoot()
        if sd < 1e-6 { return .failed("No pulse could be seen. Cover the camera and flash completely with your fingertip.") }
        let minGap = Int(rate / 3), edge = Int(rate / 2)
        var peaks: [Int] = []
        for i in edge..<(y.count - edge) where y[i] > y[i - 1] && y[i] >= y[i + 1] && y[i] - mean > 0.3 * sd {
            if let last = peaks.last, i - last < minGap { if y[i] > y[last] { peaks[peaks.count - 1] = i } } else { peaks.append(i) }
        }
        if peaks.count < 8 { return .failed("Not enough heartbeats came through. Press a little more gently and keep very still.") }
        let at = peaks.map { peakPosition(y, $0) }
        let ibis = (1..<at.count).map { (at[$0] - at[$0 - 1]) * 1000 / rate }
        let plausible = ibis.filter { (333...1500).contains($0) }
        if plausible.count < 6 { return .failed("The pulse was unclear. Keep your finger still and try again.") }
        let median = plausible.sorted()[plausible.count / 2]
        let ok = ibis.map { (333...1500).contains($0) && abs($0 - median) <= 0.25 * median }
        let kept = ibis.indices.filter { ok[$0] }.map { ibis[$0] }
        let quality = Double(kept.count) / Double(ibis.count)
        if kept.count < 6 || quality < 0.6 { return .failed("Too much movement to read your pulse. Rest your hand on something and try again.") }
        let diffs = (1..<ibis.count).filter { ok[$0] && ok[$0 - 1] }.map { ibis[$0] - ibis[$0 - 1] }
        let rmssd = diffs.count >= 3 ? (diffs.map { $0 * $0 }.reduce(0, +) / Double(diffs.count)).squareRoot() : 0
        let bpm = Int((60_000 / kept.sorted()[kept.count / 2]).rounded())
        if !(35...200).contains(bpm) { return .failed("That reading didn't look right. Please try again.") }
        return .reading(bpm: bpm, rmssd: min(300, max(0, Int(rmssd.rounded()))))
    }

    static func words(rmssd: Int) -> String {
        switch rmssd {
        case 50...: "Your body looks settled and rested."
        case 25...: "Your body looks fairly calm."
        case 1...: "Your body looks a little stirred up. A few slow breaths can help."
        default: "Your heart rate came through clearly."
        }
    }
}

struct CalmReading: Codable, Identifiable {
    var id: Date { at }
    let at: Date
    let bpm: Int
    let rmssd: Int
}

enum CalmLog {
    static var all: [CalmReading] {
        guard let d = UserDefaults.standard.data(forKey: "calmChecks") else { return [] }
        return (try? JSONDecoder().decode([CalmReading].self, from: d)) ?? []
    }
    static func add(_ r: CalmReading) {
        let list = Array((all + [r]).suffix(200))
        if let d = try? JSONEncoder().encode(list) { UserDefaults.standard.set(d, forKey: "calmChecks") }
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: "calmChecks") }
    static func restingAverage(days: Int = 7) -> Int? {
        let from = Date().addingTimeInterval(Double(-days) * 86400)
        let r = all.filter { $0.at >= from }
        return r.count < 2 ? nil : Int((Double(r.map(\.bpm).reduce(0, +)) / Double(r.count)).rounded())
    }
}

/// Reads the fingertip's color from the back camera, with the light on. No picture is kept.
final class PulseCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var fingerOn = false
    @Published var progress = 0.0
    @Published var error: String?
    @Published var result: CalmSignal.Result?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "pulse")
    private var device: AVCaptureDevice?
    private var samples: [CalmSignal.Sample] = []
    private var start: Double = 0
    private var frames = 0

    func begin() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async {
                guard ok else { self.error = "Allow the camera in Settings to take a calm check."; return }
                self.configure()
            }
        }
    }

    private func configure() {
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: dev) else { error = "This phone has no back camera to read your pulse."; return }
        device = dev
        session.beginConfiguration()
        session.sessionPreset = .low
        if session.canAddInput(input) { session.addInput(input) }
        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
        queue.async {
            self.session.startRunning()
            if dev.hasTorch, (try? dev.lockForConfiguration()) != nil {
                try? dev.setTorchModeOn(level: min(1, AVCaptureDevice.maxAvailableTorchLevel))
                if let r = dev.activeFormat.videoSupportedFrameRateRanges.first, r.maxFrameRate >= 30 {
                    dev.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                    dev.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                }
                dev.unlockForConfiguration()
            } else {
                DispatchQueue.main.async { self.error = "This phone has no flash. Try in bright light with your finger over the camera." }
            }
        }
    }

    func stop() {
        queue.async {
            if let d = self.device, d.hasTorch, (try? d.lockForConfiguration()) != nil { d.torchMode = .off; d.unlockForConfiguration() }
            self.session.stopRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let px = CMSampleBufferGetImageBuffer(buffer) else { return }
        CVPixelBufferLockBaseAddress(px, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(px, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(px) else { return }
        let w = CVPixelBufferGetWidth(px), h = CVPixelBufferGetHeight(px), row = CVPixelBufferGetBytesPerRow(px)
        let p = base.assumingMemoryBound(to: UInt8.self)
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for y in stride(from: 0, to: h, by: 4) {
            for x in stride(from: 0, to: w, by: 4) {
                let o = y * row + x * 4
                b += Double(p[o]); g += Double(p[o + 1]); r += Double(p[o + 2]); n += 1
            }
        }
        guard n > 0 else { return }
        r /= n; g /= n; b /= n
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        let cr = 0.5 * r - 0.4187 * g - 0.0813 * b          // red above neutral, as Android's Cr
        let t = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        let on = CalmSignal.fingerOn(luma: luma, red: cr)
        frames += 1
        if !on { samples.removeAll(); start = 0 } else {
            if start == 0 { start = t }
            samples.append(.init(t: t, value: r))
        }
        let prog = on && start > 0 ? min(1, (t - start) / Double(CalmSignal.seconds)) : 0
        let done = prog >= 1
        let snapshot = done ? samples : []
        DispatchQueue.main.async {
            self.fingerOn = on
            self.progress = prog
            if done, self.result == nil {
                self.result = CalmSignal.analyze(snapshot)
                self.stop()
            }
        }
        if done { samples.removeAll(); start = 0 }
    }
}

struct CalmCheckView: View {
    @ObservedObject private var account = AccountStore.shared
    @State private var phase = 0             // 0 ready, 1 measuring, 2 done
    @State private var camera = PulseCamera()
    @State private var reading: CalmReading?
    @State private var failed: String?
    @State private var paywall = false
    @State private var confirmClear = false
    @State private var refresh = 0

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenPhoto(name: ScreenPhoto.daily("screen_calm"))
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("💓 CALM CHECK").font(.hs(11, .semibold)).foregroundStyle(HS.peach).tracking(1.4)
                            T("How calm are you?").font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                            ItalicAccent(text: "quiet breath, steady heart", size: 18)
                            T("Rest your fingertip gently over the back camera and the flash, and keep still for 30 seconds. Your phone reads your heart rate and how much it varies from beat to beat, a sign of how settled your body is.")
                                .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    switch phase {
                    case 1: MeasureCard(camera: camera) { cancel() } onResult: { finish($0) }
                    case 2: if let reading { resultCard(reading) }
                    default: readyCard
                    }
                    if let failed {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                T("We couldn't get a clear reading").font(.hs(15, .bold)).foregroundStyle(HS.text)
                                T(failed).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    history.id(refresh)
                    T("Calm check is for your own reflection and wellness. It is not a medical device and does not diagnose or monitor any condition. Readings stay on this phone. If you feel unwell, chest pain or a racing heart that won't settle, contact a doctor or emergency services.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted).padding(.horizontal, 20)
                    Spacer().frame(height: 60)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $paywall) { PlansView(feature: .wearableInsights) }
        .onDisappear { camera.stop() }
    }

    private var readyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T("Before you start").font(.hs(15, .bold)).foregroundStyle(HS.text)
                ForEach(["Sit down and rest your hand on a table or your knee.",
                         "Cover the camera and the flash with the pad of one finger. Press lightly; pressing hard stops the blood flow.",
                         "Breathe normally and stay still until the circle fills."], id: \.self) { T("• " + $0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                GoldButton(title: "Start the calm check") { failed = nil; camera = PulseCamera(); phase = 1; camera.begin() }.padding(.top, 4)
                T("The camera is used only to see your fingertip's color. No pictures are taken or saved.").font(.hs(11)).foregroundStyle(HS.textMuted)
            }
        }
        .padding(.horizontal, 20)
    }

    private func resultCard(_ r: CalmReading) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    D("💓").font(.system(size: 28)).frame(width: 64, height: 64).background(Circle().fill(Color(hex: 0x2DD4BF).opacity(0.18)))
                    VStack(alignment: .leading, spacing: 2) {
                        D("\(r.bpm) bpm").font(.hs(28, .bold)).foregroundStyle(HS.text)
                        if r.rmssd > 0 { D(tr("Variability \(r.rmssd) ms")).font(.hs(13, .semibold)).foregroundStyle(HS.readable(0x2DD4BF)) }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tr("Heart rate \(r.bpm) beats a minute") + (r.rmssd > 0 ? ", " + tr("variability \(r.rmssd) milliseconds") : ""))
                }
                T(CalmSignal.words(rmssd: r.rmssd)).font(.hs(14)).foregroundStyle(HS.text)
                HStack {
                    Button { phase = 0 } label: { T("Done").font(.hs(14, .semibold)).foregroundStyle(HS.onGold).padding(.horizontal, 20).padding(.vertical, 10).background(Capsule().fill(HS.goldButton)) }
                    Button { failed = nil; camera = PulseCamera(); phase = 1; camera.begin() } label: { T("Check again").font(.hs(13)).foregroundStyle(HS.textMuted).padding(8) }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var history: some View {
        let list = CalmLog.all
        if !list.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    T("✨ What brings you peace most").font(.hs(15, .bold)).foregroundStyle(HS.text)
                    if !account.canUse(.wearableInsights) {
                        T("Take a calm check before and after your sessions, and we'll show which prayers and sessions slow your heart the most, and how your calm changes week to week.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        Button { paywall = true } label: { T("See plans").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                    } else {
                        if let avg = CalmLog.restingAverage() { D(tr("Your resting average this week: \(avg) bpm.")).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                        T("Recent checks").font(.hs(13, .semibold)).foregroundStyle(HS.text).padding(.top, 4)
                        ForEach(list.suffix(7).reversed()) { r in
                            HStack {
                                D(r.at.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(I18n.shared.locale))).font(.hs(12)).foregroundStyle(HS.textMuted)
                                Spacer()
                                D("\(r.bpm) bpm" + (r.rmssd > 0 ? " · \(r.rmssd) ms" : "")).font(.hs(12, .semibold)).foregroundStyle(HS.text)
                            }
                        }
                        Button { if confirmClear { CalmLog.clear(); confirmClear = false; refresh += 1 } else { confirmClear = true } } label: {
                            T(confirmClear ? "Tap again to delete all calm checks (this can't be undone)" : "Clear my calm checks").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func cancel() { camera.stop(); phase = 0 }

    private func finish(_ r: CalmSignal.Result) {
        switch r {
        case .reading(let bpm, let rmssd):
            let reading = CalmReading(at: Date(), bpm: bpm, rmssd: rmssd)
            CalmLog.add(reading)
            self.reading = reading
            phase = 2
            refresh += 1
        case .failed(let why):
            failed = why
            phase = 0
        }
    }
}

private struct MeasureCard: View {
    @ObservedObject var camera: PulseCamera
    let onCancel: () -> Void
    let onResult: (CalmSignal.Result) -> Void

    var body: some View {
        let left = max(0, CalmSignal.seconds - Int(camera.progress * Double(CalmSignal.seconds)))
        GlassCard {
            VStack(spacing: 12) {
                ZStack {
                    Circle().stroke(Color(hex: 0x2DD4BF).opacity(0.15), lineWidth: 8)
                    Circle().trim(from: 0, to: camera.progress).stroke(Color(hex: 0x2DD4BF), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    D(camera.fingerOn ? "\(left)" : "☝️").font(.system(size: camera.fingerOn ? 40 : 44, weight: .heavy)).foregroundStyle(HS.text)
                }
                .frame(width: 150, height: 150)
                D(tr(camera.error ?? (camera.fingerOn ? "Reading your pulse… stay still and breathe normally." : "Cover the camera and flash with your fingertip.")))
                    .font(.hs(14)).foregroundStyle(camera.error != nil ? Color(hex: 0xFBBF24) : HS.textSecondary).multilineTextAlignment(.center)
                Button(action: onCancel) { T("Cancel").font(.hs(13)).foregroundStyle(HS.textMuted).padding(8) }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .onChange(of: camera.result != nil) { _, done in if done, let r = camera.result { onResult(r) } }
    }
}
