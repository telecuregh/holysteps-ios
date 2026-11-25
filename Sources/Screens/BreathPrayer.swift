import SwiftUI
import CoreHaptics
import UIKit

/// Haptic breath prayer: the phone breathes with you. A rising buzz while you breathe in, soft taps while you hold,
/// a fading buzz while you breathe out, each half carrying a short line of Scripture. Works with the screen off
/// in your hand or eyes closed. Free for everyone. For relaxation only.
struct BreathPattern: Identifiable, Hashable {
    let id: String
    let name: String
    let inhale: Double, hold: Double, exhale: Double, rest: Double
    var cycle: Double { inhale + hold + exhale + rest }

    static let all = [
        BreathPattern(id: "calm", name: "Calm (4 · 2 · 6)", inhale: 4, hold: 2, exhale: 6, rest: 0),
        BreathPattern(id: "box", name: "Box (4 · 4 · 4 · 4)", inhale: 4, hold: 4, exhale: 4, rest: 4),
        BreathPattern(id: "sleep", name: "Sleep (4 · 7 · 8)", inhale: 4, hold: 7, exhale: 8, rest: 0),
    ]
}

struct BreathLine: Hashable { let inn: String; let out: String; let ref: String }

enum BreathLines {
    static let all = [
        BreathLine(inn: "Be still", out: "and know that I am God", ref: "Psalm 46:10"),
        BreathLine(inn: "The Lord is my shepherd", out: "I shall not want", ref: "Psalm 23:1"),
        BreathLine(inn: "Come unto me", out: "and I will give you rest", ref: "Matthew 11:28"),
        BreathLine(inn: "My peace I give", out: "let not your heart be troubled", ref: "John 14:27"),
        BreathLine(inn: "In quietness", out: "shall be your strength", ref: "Isaiah 30:15"),
    ]
}

@MainActor
final class BreathHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    var supported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    func start(_ p: BreathPattern) {
        guard supported else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = false
            e.resetHandler = { [weak self] in Task { @MainActor in self?.restart(p) } }
            try e.start()
            engine = e
            let pl = try e.makeAdvancedPlayer(with: pattern(p))
            pl.loopEnabled = true
            pl.loopEnd = p.cycle
            try pl.start(atTime: CHHapticTimeImmediate)
            player = pl
        } catch { stop() }
    }

    private func restart(_ p: BreathPattern) { stop(); start(p) }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine?.stop()
        engine = nil
    }

    private func pattern(_ p: BreathPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        func continuous(_ t: Double, _ d: Double) {
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)], relativeTime: t, duration: d))
        }
        // Breathe in: intensity rises from a whisper to medium.
        continuous(0, p.inhale)
        curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.08), .init(relativeTime: p.inhale, value: 0.6)], relativeTime: 0))
        // Hold: one gentle tap each second.
        var t = p.inhale
        while t < p.inhale + p.hold - 0.01 {
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)], relativeTime: t + 0.5))
            t += 1
        }
        // Breathe out: intensity falls back to nothing.
        let out = p.inhale + p.hold
        continuous(out, p.exhale)
        curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.5), .init(relativeTime: p.exhale, value: 0.02)], relativeTime: out))
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }
}

struct BreathPrayerView: View {
    @State private var pattern = BreathPattern.all[0]
    @State private var minutes = 3
    @State private var running = false
    @State private var started = Date()
    @State private var lineIndex = Int.random(in: 0..<BreathLines.all.count)
    @State private var haptics = BreathHaptics()
    @State private var done = false

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 18) {
                T("Breath prayer").font(.hs(28, .semibold)).foregroundStyle(HS.text).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 58)
                if running { session } else { setup }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .onDisappear { haptics.stop(); UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 16) {
            T(haptics.supported ? "Hold your phone, close your eyes, and breathe with the gentle buzz. It rises as you breathe in and fades as you breathe out." : "Breathe with the circle: in as it grows, out as it shrinks.")
                .font(.hs(14)).foregroundStyle(HS.textSecondary)
            if done { T("Well done. Carry this peace into your day.").font(.hs(15, .semibold)).foregroundStyle(HS.gold) }
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(BreathPattern.all) { p in
                        Button { pattern = p } label: {
                            HStack {
                                T(p.name).font(.hs(15)).foregroundStyle(HS.text)
                                Spacer()
                                if pattern == p { Image(systemName: "checkmark").foregroundStyle(HS.gold) }
                            }
                        }.buttonStyle(.plain)
                    }
                    Picker("", selection: $minutes) {
                        ForEach([1, 3, 5, 10], id: \.self) { m in D(tr("{0} min").replacingOccurrences(of: "{0}", with: "\(m)")).tag(m) }
                    }.pickerStyle(.segmented)
                }
            }
            GoldButton(title: "Begin") { begin() }
        }
    }

    private var session: some View {
        TimelineView(.animation) { ctx in
            let e = ctx.date.timeIntervalSince(started)
            let phase = e.truncatingRemainder(dividingBy: pattern.cycle)
            let line = BreathLines.all[(lineIndex + Int(e / pattern.cycle)) % BreathLines.all.count]
            let (label, scale): (String, Double) = {
                if phase < pattern.inhale { return ("Breathe in", 0.55 + 0.45 * phase / pattern.inhale) }
                if phase < pattern.inhale + pattern.hold { return ("Hold", 1) }
                if phase < pattern.inhale + pattern.hold + pattern.exhale {
                    return ("Breathe out", 1 - 0.45 * (phase - pattern.inhale - pattern.hold) / pattern.exhale)
                }
                return ("Rest", 0.55)
            }()
            let left = max(0, Double(minutes * 60) - e)
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(RadialGradient(colors: [HS.gold.opacity(0.55), HS.faith.opacity(0.12)], center: .center, startRadius: 0, endRadius: 150))
                        .frame(width: 280, height: 280).scaleEffect(scale)
                    VStack(spacing: 6) {
                        T(label).font(.hs(22, .semibold)).foregroundStyle(HS.text)
                        T(label == "Breathe out" || label == "Rest" ? line.out : line.inn).font(.accent(20)).foregroundStyle(HS.textSecondary).multilineTextAlignment(.center)
                    }.padding(30)
                }
                .frame(height: 300)
                D(line.ref).font(.hs(12)).foregroundStyle(HS.textMuted)
                D(String(format: "%d:%02d", Int(left) / 60, Int(left) % 60)).font(.hs(15).monospacedDigit()).foregroundStyle(HS.textMuted)
                Button { finish() } label: { T("End").font(.hs(15, .semibold)).foregroundStyle(HS.gold) }
            }
            .frame(maxWidth: .infinity)
            .onChange(of: left == 0) { _, end in if end { finish() } }
        }
    }

    private func begin() {
        done = false; started = Date(); running = true
        UIApplication.shared.isIdleTimerDisabled = true
        haptics.start(pattern)
    }

    private func finish() {
        haptics.stop(); running = false; done = true
        UIApplication.shared.isIdleTimerDisabled = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
