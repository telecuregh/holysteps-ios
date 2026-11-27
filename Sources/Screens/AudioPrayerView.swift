import SwiftUI
import AVFoundation

// MARK: - Data

struct AudioPrayerSession: Identifiable {
    let id: String
    let title: String
    let durationSeconds: Int
    let category: String
    let script: String

    var durationLabel: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
    }
}

let audioPrayerSessions: [AudioPrayerSession] = [
    AudioPrayerSession(
        id: "morning_awakening",
        title: "Morning Awakening",
        durationSeconds: 420,
        category: "Morning",
        script: """
Good morning. Before the day begins — before notifications, before demands, before the rush — take a breath.

Breathe in slowly. Hold it. Release.

You have been given another day. That alone is grace.

Let's begin with gratitude. In your mind, name three things — just three — that you are thankful for right now. They can be small. A roof. A heartbeat. Someone who loves you.

Now, bring God into this moment. The Lord your God is with you wherever you go. He did not start paying attention to you when you woke up — He watched over you through the night. He is already here.

Speak this over your day: I am held by a God who does not sleep. Whatever I face today, I do not face it alone.

Take one more breath. And step into this day — not in fear, but in faith.

Amen.
"""
    ),
    AudioPrayerSession(
        id: "evening_surrender",
        title: "Evening Surrender",
        durationSeconds: 540,
        category: "Evening",
        script: """
The day is done. Set it down.

Whatever you carried today — the conversations that went wrong, the worries you couldn't shake, the tasks left undone — you do not have to carry them into the night.

He gives sleep to those He loves. That includes you.

Take a slow breath. With every exhale, release one thing. A fear. A regret. A person you're worried about. Give it to God — not because you've figured it out, but because He can hold it and you cannot.

Cast all your anxiety on Him, because He cares for you. That is not a suggestion. That is a promise.

Close your eyes if you haven't already. Let your breathing slow.

You were enough today. Not perfect — but enough. And tomorrow, His mercies will be new.

Rest now. You are not alone in the dark.

Goodnight.
"""
    ),
    AudioPrayerSession(
        id: "deep_sleep_peace",
        title: "Deep Sleep Peace",
        durationSeconds: 720,
        category: "Sleep",
        script: """
Let everything go still.

Your body has worked hard today. It deserves rest. Your mind has processed a thousand things. Let it grow quiet now.

Breathe in slowly — four counts. Hold — four counts. Out — four counts.

Again.

You are safe. The God who set the stars in place has not forgotten your name. He does not slumber or sleep — which means you can.

Picture a still lake. No wind. The water perfectly calm. That is the peace He offers you right now — a peace that passes all understanding.

You don't need to solve anything tonight. You don't need to plan. You don't need to worry. Those burdens belong to morning — and even then, they belong to Him.

Let your thoughts drift like leaves on that still water, slowly, slowly carried away.

Breathe in. And out.

You are held. You are loved. You are allowed to rest.

Sleep well.
"""
    ),
    AudioPrayerSession(
        id: "anxiety_anchor",
        title: "Anxiety Anchor",
        durationSeconds: 480,
        category: "Crisis",
        script: """
If your heart is racing right now, I want you to know: you're not alone, and this will pass.

Take the slowest breath you can manage. Hold it. Let it go.

Anxiety tells you that something is out of control, that disaster is near, that you need to fix this right now. But anxiety lies.

Here is what is true: God has not abandoned you. He has seen every hard day before this one, and He has not let you go yet.

Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.

Pray it out loud if you can. Tell God exactly what you're afraid of. He already knows — but telling Him is how you release it.

Name five things you can see. Four you can touch. Three you can hear. Two you can smell. One you can taste.

You are here. You are breathing. You are not alone.

The anchor holds.
"""
    ),
    AudioPrayerSession(
        id: "midday_reset",
        title: "Midday Reset",
        durationSeconds: 300,
        category: "Morning",
        script: """
Pause. Right here, right now — just for five minutes.

You're in the middle of your day. Maybe it's going well. Maybe it's hard. Either way, take a breath.

Lord, I pause to acknowledge You in the middle of my day. You are still here. I may have rushed past You this morning, but You are still here.

What do you need right now? Rest? Courage? Patience? Clarity? Ask for it. He is not too busy for a midday prayer.

Breathe in what you need. Breathe out what's draining you.

You can keep going. He will keep you.

Back to it — but differently now. With Him.
"""
    ),
    AudioPrayerSession(
        id: "gratitude_practice",
        title: "Gratitude Practice",
        durationSeconds: 360,
        category: "Evening",
        script: """
Gratitude is not pretending everything is fine. It is choosing to notice what is good, even when things are hard.

Think back over your day. Where did grace show up? A parking spot. A kind word. A problem that didn't become a crisis. A meal. A message from a friend.

These things are not accidents. Every good and perfect gift is from above.

Say it: God, thank You for — and finish the sentence. Say it again. And again. Five times. Ten if you can.

Now think of someone in your life. Someone you love, or someone who is struggling. Pray for them by name.

Gratitude opens the hands. It reminds us that we are receivers, not self-made.

End today grateful. Tomorrow will be better for it.

Amen.
"""
    ),
    AudioPrayerSession(
        id: "forgiveness_healing",
        title: "Forgiveness & Healing",
        durationSeconds: 600,
        category: "Crisis",
        script: """
There is something you're carrying. Someone who hurt you. Something you did that you haven't forgiven yourself for. Something that left a mark.

This is a safe space to bring it.

Forgiveness does not mean what happened was okay. It means you are choosing not to let it hold you hostage anymore.

Is there a person you need to forgive? Not for their sake — for yours. Unforgiveness is a wound that keeps bleeding. Forgiveness is not excusing. It is releasing.

Say it, even if you don't feel it yet: I choose to forgive. I release this to You, God. I cannot carry it, and I will not.

If you need to forgive yourself — that may be harder. But hear this: there is now no condemnation for those who are in Christ Jesus. That means you. The shame does not get the last word.

Healing is not instant. But it starts with a choice.

Breathe. You are on your way.

Rest in that freedom.
"""
    ),
]

// MARK: - Screen

struct AudioPrayerView: View {
    @State private var activeSession: AudioPrayerSession?
    @State private var completed: Set<String> = {
        let raw = UserDefaults.standard.stringArray(forKey: "audioPrayerCompleted") ?? []
        return Set(raw)
    }()
    @State private var selectedCategory = "All"

    private let categories = ["All", "Morning", "Evening", "Sleep", "Crisis"]

    private var filtered: [AudioPrayerSession] {
        selectedCategory == "All" ? audioPrayerSessions
            : audioPrayerSessions.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ZStack {
            HSBackground()
            if let session = activeSession {
                AudioPlayerView(
                    session: session,
                    isCompleted: completed.contains(session.id),
                    onComplete: {
                        completed.insert(session.id)
                        UserDefaults.standard.set(Array(completed), forKey: "audioPrayerCompleted")
                        ActivityLog.shared.add(.prayerAudio)
                    },
                    onClose: { activeSession = nil }
                )
            } else {
                listView
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
    }

    private var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    T("Guided Prayer").font(.hs(28, .semibold)).foregroundStyle(HS.text)
                    T("Spoken guidance for morning, evening, sleep and hard moments")
                        .font(.hs(13)).foregroundStyle(HS.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 58).padding(.bottom, 16)

                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button(cat) { selectedCategory = cat }
                                .font(.hs(13, .medium))
                                .foregroundStyle(selectedCategory == cat ? HS.onGold : HS.textMuted)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(
                                    Capsule().fill(selectedCategory == cat ? HS.goldButton : HS.cardFill)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)

                // Session cards
                VStack(spacing: 12) {
                    ForEach(filtered) { session in
                        AudioSessionCard(
                            session: session,
                            isCompleted: completed.contains(session.id),
                            onTap: { activeSession = session }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Session card

private struct AudioSessionCard: View {
    let session: AudioPrayerSession
    let isCompleted: Bool
    let onTap: () -> Void

    private var catColor: Color {
        switch session.category {
        case "Morning": return HS.gold
        case "Evening": return Color(hex: 0x8B5CF6)
        case "Sleep": return Color(hex: 0x3B82F6)
        default: return HS.error
        }
    }
    private var catEmoji: String {
        switch session.category {
        case "Morning": return "☀️"
        case "Evening": return "🌙"
        case "Sleep": return "💤"
        default: return "🌊"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Emoji badge
                T(catEmoji).font(.system(size: 28))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(catColor.opacity(0.15)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        T(session.title).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                        Spacer()
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(HS.goldButton).font(.system(size: 16))
                        }
                    }
                    HStack(spacing: 6) {
                        T(session.category).font(.hs(12, .medium)).foregroundStyle(catColor)
                        T("·").font(.hs(12)).foregroundStyle(HS.textMuted)
                        T(session.durationLabel).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Player

private struct AudioPlayerView: View {
    let session: AudioPrayerSession
    let isCompleted: Bool
    let onComplete: () -> Void
    let onClose: () -> Void

    @State private var isPlaying = false
    @State private var elapsed = 0
    @State private var finished = false
    @StateObject private var tts = TTSController()

    private var progress: Double { Double(elapsed) / Double(session.durationSeconds) }
    private var elapsedLabel: String { "\(elapsed / 60):\(String(format: "%02d", elapsed % 60))" }
    private var totalLabel: String { "\(session.durationSeconds / 60):00" }

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    Button(action: {
                        tts.stop()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(HS.textMuted)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 58)

                Spacer()

                // Pulse circle
                ZStack {
                    Circle().fill(HS.goldButton.opacity(0.15))
                        .frame(width: isPlaying ? 160 : 140, height: isPlaying ? 160 : 140)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPlaying)
                    Circle().fill(HS.goldButton.opacity(0.3))
                        .frame(width: isPlaying ? 130 : 120, height: isPlaying ? 130 : 120)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.3), value: isPlaying)
                    Circle().fill(HS.goldButton)
                        .frame(width: 100, height: 100)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32)).foregroundStyle(HS.onGold)
                }
                .onTapGesture { togglePlay() }
                .padding(.bottom, 32)

                // Title
                T(session.title).font(.hs(22, .semibold)).foregroundStyle(HS.text)
                    .padding(.bottom, 4)
                T(session.category).font(.hs(14)).foregroundStyle(HS.goldButton)
                    .padding(.bottom, 32)

                // Progress bar
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(HS.goldButton)
                        .background(HS.cardFill, in: Capsule())
                    HStack {
                        T(elapsedLabel).font(.hs(12)).foregroundStyle(HS.textMuted)
                        Spacer()
                        T(totalLabel).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Script preview (first 2 lines)
                let preview = session.script.components(separatedBy: "\n").prefix(2).joined(separator: " ")
                T(preview).font(.hs(13)).foregroundStyle(HS.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 32).padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { tts.stop() }
        .onChange(of: tts.didFinish) { _, done in
            if done && !finished {
                finished = true
                isPlaying = false
                if !isCompleted { onComplete() }
            }
        }
        // Timer for progress bar (runs alongside TTS)
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while isPlaying && elapsed < session.durationSeconds {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if isPlaying { elapsed = min(elapsed + 1, session.durationSeconds) }
            }
        }
    }

    private func togglePlay() {
        if isPlaying {
            tts.pause()
            isPlaying = false
        } else {
            if finished || elapsed == 0 {
                elapsed = 0
                finished = false
                tts.speak(session.script)
            } else {
                tts.resume()
            }
            isPlaying = true
        }
    }
}

// MARK: - TTS controller (AVSpeechSynthesizer wrapper)

@MainActor
final class TTSController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var didFinish = false
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        didFinish = false
        let utt = AVSpeechUtterance(string: text)
        utt.rate = 0.47          // slightly slower than default for a calm prayer pace
        utt.pitchMultiplier = 0.95
        utt.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.siri_female_en-US_premium")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utt)
    }

    func pause() { synth.pauseSpeaking(at: .word) }
    func resume() { synth.continueSpeaking() }
    func stop() { synth.stopSpeaking(at: .immediate) }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.didFinish = true }
    }
}
