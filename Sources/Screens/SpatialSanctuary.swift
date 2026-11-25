import SwiftUI
import AVFoundation
import CoreMotion

/// Spatial Sanctuary: a prayer room you can hear around you. Rain above, a creek to one side, wind that moves,
/// crickets behind and a far-off chapel bell, made live on the phone and placed in 3D. With AirPods the room stays
/// put when you turn your head. Part of the Faith plan (sanctuaryFull). Nothing is downloaded.
enum SoundLayer: String, CaseIterable, Identifiable {
    case rain, creek, wind, crickets, bells, choir
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rain: "Rain"; case .creek: "Creek"; case .wind: "Wind"
        case .crickets: "Crickets"; case .bells: "Chapel bell"; case .choir: "Soft choir"
        }
    }
    var symbol: String {
        switch self {
        case .rain: "cloud.rain"; case .creek: "water.waves"; case .wind: "wind"
        case .crickets: "moon.stars"; case .bells: "bell"; case .choir: "music.note"
        }
    }
    /// Where it sits around the listener, in meters (x right, y up, z behind).
    var position: AVAudio3DPoint {
        switch self {
        case .rain: AVAudio3DPoint(x: 0, y: 3, z: 0)
        case .creek: AVAudio3DPoint(x: -3, y: -0.5, z: -2)
        case .wind: AVAudio3DPoint(x: 4, y: 1, z: 0)
        case .crickets: AVAudio3DPoint(x: 2, y: 0, z: 4)
        case .bells: AVAudio3DPoint(x: 0, y: 2, z: -12)
        case .choir: AVAudio3DPoint(x: 0, y: 0.5, z: -4)
        }
    }
}

/// One synthesized sound; render() runs on the audio thread and never allocates.
final class SoundVoice {
    let layer: SoundLayer
    var gain: Float = 0           // target loudness, set from the main thread
    private var level: Float = 0  // smoothed
    private var seed: UInt32 = 22_222
    private var lp: Float = 0, lp2: Float = 0, brown: Float = 0
    private var t: Double = 0
    private var drop: Float = 0
    private var bellAge: Double = 99, nextBell: Double = 6
    private let sr: Double

    init(_ layer: SoundLayer, sampleRate: Double) { self.layer = layer; self.sr = sampleRate; seed = UInt32(layer.rawValue.count * 7919 + 13) }

    @inline(__always) private func noise() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(Int32(bitPattern: seed)) / Float(Int32.max)
    }

    func render(_ out: UnsafeMutablePointer<Float>, _ n: Int) {
        let dt = 1 / sr
        for i in 0..<n {
            level += (gain - level) * 0.0005
            var s: Float = 0
            switch layer {
            case .rain:
                let w = noise()
                lp += (w - lp) * 0.35
                if noise() > 0.9993 { drop = 0.9 }
                drop *= 0.994
                s = lp * 0.28 + w * drop * 0.25
            case .creek:
                brown = (brown + noise() * 0.04) * 0.995
                lp += (noise() - lp) * 0.12
                let wobble = Float(0.6 + 0.4 * sin(t * 2 * .pi * 0.31) * sin(t * 2 * .pi * 0.07))
                s = (brown * 1.6 + lp * 0.18) * wobble
            case .wind:
                lp += (noise() - lp) * 0.02
                lp2 += (lp - lp2) * 0.05
                let gust = Float(0.45 + 0.55 * max(0, sin(t * 2 * .pi * 0.06)))
                s = lp2 * 3.2 * gust
            case .crickets:
                let cycle = t.truncatingRemainder(dividingBy: 1.3)
                let pulse = cycle.truncatingRemainder(dividingBy: 0.11)
                let on = cycle < 0.33 && pulse < 0.05
                s = on ? Float(sin(t * 2 * .pi * 4700)) * 0.12 * Float(sin(.pi * pulse / 0.05)) : 0
            case .bells:
                bellAge += dt
                nextBell -= dt
                if nextBell <= 0 { bellAge = 0; nextBell = 22 + Double(abs(noise())) * 18 }
                if bellAge < 9 {
                    let f = 392.0
                    let w = bellAge * 2 * .pi * f
                    let b = sin(w) * exp(-bellAge / 2.6) * 0.5 + sin(w * 2) * exp(-bellAge / 1.8) * 0.25
                        + sin(w * 2.76) * exp(-bellAge / 1.2) * 0.18 + sin(w * 5.4) * exp(-bellAge / 0.6) * 0.1
                    s = Float(b) * 0.5
                }
            case .choir:
                let breath = 0.75 + 0.25 * sin(t * 2 * .pi * 0.09)
                let chord = sin(t * 2 * .pi * 110) * 0.4 + sin(t * 2 * .pi * 164.81) * 0.3 + sin(t * 2 * .pi * 220.5) * 0.22 + sin(t * 2 * .pi * 277.18) * 0.12
                lp += (Float(chord) - lp) * 0.2
                s = lp * Float(breath) * 0.32
            }
            out[i] = s * level
            t += dt
        }
    }
}

@MainActor
final class SanctuaryEngine: ObservableObject {
    static let shared = SanctuaryEngine()
    @Published private(set) var playing = false
    @Published var mix: [SoundLayer: Double] = [.rain: 0.7, .creek: 0.5, .wind: 0.3, .crickets: 0, .bells: 0.4, .choir: 0.3] { didSet { push() } }
    @Published private(set) var headTracking = false

    private let engine = AVAudioEngine()
    private let env = AVAudioEnvironmentNode()
    private var voices: [SoundLayer: SoundVoice] = [:]
    private var nodes: [SoundLayer: AVAudioSourceNode] = [:]
    private let motion = CMHeadphoneMotionManager()
    private var drift: Timer?
    private var built = false

    private func build() {
        guard !built else { return }
        built = true
        let sr = 44_100.0
        let mono = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        engine.attach(env)
        env.renderingAlgorithm = .HRTFHQ
        env.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        env.distanceAttenuationParameters.referenceDistance = 2
        env.distanceAttenuationParameters.maximumDistance = 40
        env.reverbParameters.enable = true
        env.reverbParameters.loadFactoryReverbPreset(.cathedral)
        env.reverbParameters.level = -12
        for layer in SoundLayer.allCases {
            let v = SoundVoice(layer, sampleRate: sr)
            voices[layer] = v
            let src = Self.sourceNode(v, mono)
            nodes[layer] = src
            engine.attach(src)
            engine.connect(src, to: env, format: mono)
            src.renderingAlgorithm = .HRTFHQ
            src.position = layer.position
            src.reverbBlend = layer == .bells ? 0.6 : 0.25
        }
        engine.connect(env, to: engine.mainMixerNode, format: nil)
    }

    nonisolated private static func sourceNode(_ v: SoundVoice, _ format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frames, abl -> OSStatus in
            let list = UnsafeMutableAudioBufferListPointer(abl)
            if let p = list[0].mData?.assumingMemoryBound(to: Float.self) { v.render(p, Int(frames)) }
            return noErr
        }
    }

    func toggle() { playing ? stop() : start() }

    func start() {
        build()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        push()
        do { try engine.start() } catch { return }
        playing = true
        startHeadTracking()
        drift = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            let a = Date().timeIntervalSinceReferenceDate * 0.04
            let p = AVAudio3DPoint(x: Float(4 * cos(a)), y: 1, z: Float(4 * sin(a)))
            Task { @MainActor in self?.nodes[.wind]?.position = p }
        }
    }

    func stop() {
        drift?.invalidate(); drift = nil
        motion.stopDeviceMotionUpdates()
        engine.pause()
        playing = false; headTracking = false
    }

    private func push() { for (l, v) in voices { v.gain = Float(mix[l] ?? 0) * 0.9 } }

    private func startHeadTracking() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let a = m?.attitude else { return }
            self.headTracking = true
            let deg = 180 / Double.pi
            self.env.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: Float(-a.yaw * deg), pitch: Float(a.pitch * deg), roll: Float(-a.roll * deg))
        }
    }
}

struct SpatialSanctuaryView: View {
    @ObservedObject private var room = SanctuaryEngine.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var paywall = false

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Spatial Sanctuary").font(.hs(28, .semibold)).foregroundStyle(HS.text).padding(.top, 58)
                    T("A quiet place to pray, all around you. Best with AirPods or headphones; the room stays still when you turn your head.")
                        .font(.hs(14)).foregroundStyle(HS.textSecondary)
                    Button { account.canUse(.sanctuaryFull) ? room.toggle() : (paywall = true) } label: {
                        HStack {
                            Image(systemName: room.playing ? "pause.fill" : "play.fill")
                            T(room.playing ? "Pause" : "Enter the sanctuary").font(.hs(16, .semibold))
                        }
                        .foregroundStyle(HS.onGold).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(HS.goldButton))
                    }
                    if room.headTracking { T("Head tracking is on").font(.hs(12)).foregroundStyle(HS.gold) }
                    GlassCard {
                        VStack(spacing: 14) {
                            ForEach(SoundLayer.allCases) { l in
                                HStack(spacing: 12) {
                                    Image(systemName: l.symbol).frame(width: 24).foregroundStyle(HS.gold)
                                    T(l.title).font(.hs(14)).foregroundStyle(HS.text).frame(width: 96, alignment: .leading)
                                    Slider(value: Binding(get: { room.mix[l] ?? 0 }, set: { room.mix[l] = $0 }), in: 0...1).tint(HS.gold)
                                }
                            }
                        }
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .sheet(isPresented: $paywall) { PlansView(feature: .sanctuaryFull) }
    }
}
