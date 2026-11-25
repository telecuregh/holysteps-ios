import SwiftUI
import AVFoundation

/// Today's coach on the Fitness tab: the energy zone and why, today's workout (with a gentler and a stronger
/// option), the Scripture focus, what to eat, and the 10-second check-in that adapts it.
struct DailyCoachCard: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var checkIns = CheckInStore.shared
    @ObservedObject private var cycle = CycleLog.shared
    @State private var showCheckIn = false
    @State private var playing: GuidedRoutine?

    var body: some View {
        let plan = Coach.plan(store: store)
        GlassCard(glow: Color(hex: plan.zone.colorHex)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    T("YOUR COACH TODAY").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                    Spacer()
                    T(plan.zone.label).font(.hs(12, .semibold)).foregroundStyle(HS.readable(plan.zone.colorHex))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: plan.zone.colorHex).opacity(0.16)))
                }
                T(plan.zone.headline).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                ForEach(plan.reasons.prefix(3), id: \.self) { T($0).font(.hs(12)).foregroundStyle(HS.textMuted) }
                if plan.needsCheckIn {
                    Button { showCheckIn = true } label: {
                        T("Check in · 10 seconds").font(.hs(13, .semibold)).foregroundStyle(HS.onGold)
                            .padding(.horizontal, 16).padding(.vertical, 9).background(Capsule().fill(HS.goldButton))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { showCheckIn = true } label: { T("Change today's check-in").font(.hs(12)).foregroundStyle(HS.gold) }.buttonStyle(.plain)
                }
                if let r = plan.routine {
                    Divider().overlay(HS.gold.opacity(0.25))
                    routineRow(r, big: true)
                    HStack(spacing: 8) {
                        if let g = plan.gentler { chip("Gentler: \(tr(g.title))") { playing = g } }
                        if let s = plan.stronger { chip("Stronger: \(tr(s.title))") { playing = s } }
                    }
                }
                if let d = plan.devotional {
                    Divider().overlay(HS.gold.opacity(0.25))
                    T(d.theme.uppercased()).font(.hs(10, .semibold)).tracking(1.2).foregroundStyle(HS.textMuted)
                    D("“\(d.verse)”").font(.accent(16)).foregroundStyle(HS.text)
                    D("— \(d.reference)").font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                    T(d.reflection).font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                if !plan.nourish.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "fork.knife").font(.system(size: 12)).foregroundStyle(HS.body).padding(.top, 2)
                        T(plan.nourish).font(.hs(12)).foregroundStyle(HS.textSecondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showCheckIn) { CheckInSheet() }
        .fullScreenCover(item: $playing) { RoutinePlayerView(routine: $0) }
    }

    private func routineRow(_ r: GuidedRoutine, big: Bool) -> some View {
        Button { playing = r } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: r.symbol, size: 40, tint: 0x56B892)
                VStack(alignment: .leading, spacing: 2) {
                    T(r.title).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                    T("\(r.kindLabel) · \(r.minutes) min").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                Spacer()
                GoldPlayBadge(size: 34)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chip(_ s: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            D(s).font(.hs(11)).foregroundStyle(HS.textSecondary).lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(HS.overlay(0.06)))
        }
        .buttonStyle(.plain)
    }
}

/// The 10-second check-in: mood, energy, peace, and how you slept.
struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mood = 3
    @State private var energy = 3
    @State private var peace = 3
    @State private var clarity = 3
    @State private var sleep = ""

    var body: some View {
        HSSheet(title: "How are you today?") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    scale("Mood", $mood, ["😞", "😕", "😐", "🙂", "😄"])
                    scale("Energy", $energy, ["🪫", "😪", "🙂", "💪", "⚡"])
                    scale("Peace", $peace, ["🌪️", "😟", "😌", "🕊️", "✨"])
                    VStack(alignment: .leading, spacing: 8) {
                        T("How did you sleep?").font(.hs(13, .semibold)).foregroundStyle(HS.textSecondary)
                        HStack(spacing: 8) {
                            ForEach([("poor", "Poor"), ("okay", "Okay"), ("great", "Great")], id: \.0) { key, label in
                                let on = sleep == key
                                Button { sleep = on ? "" : key } label: {
                                    T(label).font(.hs(13, on ? .semibold : .regular)).foregroundStyle(on ? HS.text : HS.textSecondary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(on ? HS.goldButton.opacity(0.22) : HS.overlay(0.04)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    GoldButton(title: "Save check-in") {
                        CheckInStore.shared.save(CheckIn(date: AppStore.dayKey(), mood: mood, energy: energy, clarity: clarity, peace: peace, sleep: sleep))
                        dismiss()
                    }
                    T("Your check-ins stay on this phone.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if let c = CheckInStore.shared.today { mood = c.mood; energy = c.energy; peace = c.peace; clarity = c.clarity; sleep = c.sleep }
        }
    }

    private func scale(_ title: String, _ value: Binding<Int>, _ faces: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                T(title).font(.hs(13, .semibold)).foregroundStyle(HS.textSecondary)
                Spacer()
                D("\(value.wrappedValue)/5").font(.hs(12)).foregroundStyle(HS.textMuted)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    let on = value.wrappedValue == i
                    Button { value.wrappedValue = i } label: {
                        Text(faces[i - 1]).font(.system(size: 22))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(on ? HS.goldButton.opacity(0.25) : HS.overlay(0.04)))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? Color(hex: 0xD9B49F) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tr(title)) \(i)")
                }
            }
        }
    }
}

/// The workout library (Train): every guided routine, filtered by place.
struct WorkoutLibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var venue = 0
    @State private var playing: GuidedRoutine?

    var body: some View {
        let female = store.gender == "female"
        let all = Coach.routines.filter { $0.externalRoute == nil && ($0.id != "cramp_relief" || female) && $0.id != "wake_stretch" }
        let shown: [GuidedRoutine] = switch venue {
        case 1: all.filter { $0.venue == "INDOOR" || $0.venue == "EITHER" }
        case 2: all.filter { $0.venue == "OUTDOOR" || $0.venue == "EITHER" }
        default: all
        }
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("Workouts").font(.hs(26)).foregroundStyle(HS.text).padding(.horizontal, 20)
                    SubTabs(tabs: ["All", "Indoor", "Outdoor"], selected: $venue)
                    ForEach(shown) { r in
                        Button { playing = r } label: {
                            GlassCard(padding: 14) {
                                HStack(spacing: 12) {
                                    IconBadge(symbol: r.symbol, size: 38, tint: 0x56B892)
                                    VStack(alignment: .leading, spacing: 2) {
                                        T(r.title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                        T("\(r.kindLabel) · \(r.minutes) min · \(r.equipment)").font(.hs(11)).foregroundStyle(HS.textMuted).lineLimit(1)
                                        T(r.summary).font(.hs(12)).foregroundStyle(HS.textSecondary).lineLimit(2)
                                    }
                                    Spacer(minLength: 4)
                                    GoldPlayBadge(size: 32)
                                }
                            }
                        }
                        .buttonStyle(.plain).padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playing) { RoutinePlayerView(routine: $0) }
    }
}

/// Android's routine player: one timed step at a time, the coach's voice (Grace's recording when the workout has one,
/// otherwise the phone's voice), "Ten seconds" before each change, pause, skip and back.
@MainActor
final class RoutineRunner: ObservableObject {
    @Published var index = 0
    @Published var left = 0
    @Published var paused = false { didSet { if paused != oldValue { liveUpdate() } } }
    @Published var finished = false
    let routine: GuidedRoutine
    /// The Lock Screen card shows for Fitness-plan workouts.
    private var live: Bool { AccountStore.shared.canUse(.walkPlus) }
    private var task: Task<Void, Never>?
    private var pack: VoicePacks.Pack?
    private let clip = ClipPlayer()
    private let synth = AVSpeechSynthesizer()

    init(routine: GuidedRoutine) { self.routine = routine; left = routine.steps.first?.seconds ?? 0 }

    func start() {
        SermonPlayer.shared.stop(); MusicPlayer.shared.stop(); BibleListening.shared.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.isIdleTimerDisabled = true
        task = Task {
            if !I18n.shared.spanish { pack = await VoicePacks.shared.ensure(voice: "af_heart", packId: routine.packId) }
            await say(routine.getReady)
            await run(from: 0)
        }
    }

    private func run(from start: Int) async {
        var i = start
        while i < routine.steps.count, !Task.isCancelled {
            index = i
            let step = routine.steps[i]
            left = step.seconds
            if live {
                if i == start && !liveStarted { liveStarted = true; LiveActivities.start(.workout, title: tr(routine.title), liveState()) }
                else { liveUpdate() }
            }
            await say(routine.announcement(i))
            while left > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if paused { continue }
                left -= 1
                if left == 10 && step.seconds > 20 { await say(GuidedRoutine.tenSeconds) }
            }
            i += 1
        }
        if Task.isCancelled { return }
        finished = true
        if live { LiveActivities.end(.init(headline: tr("Workout complete. Well done."), detail: tr(routine.title), endsAt: nil, since: nil, progress: 1, paused: false)) }
        CoachLog.shared.finished(routine)
        await say(GuidedRoutine.done)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func jump(_ to: Int) {
        guard (0..<routine.steps.count).contains(to) else { return }
        task?.cancel(); clip.stop(); synth.stopSpeaking(at: .immediate)
        paused = false
        task = Task { await run(from: to) }
    }

    func stop() {
        task?.cancel(); clip.stop(); synth.stopSpeaking(at: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
        if !finished { LiveActivities.end() }
    }

    // MARK: Live Activity

    private var liveStarted = false

    private func liveState() -> HolyStepsActivityAttributes.ContentState {
        let s = routine.steps[min(index, routine.steps.count - 1)]
        let next = routine.steps.dropFirst(index + 1).first { !$0.rest }
        let detail = (s.rest ? tr("Rest") : tr("Step \(index + 1) of \(routine.steps.count)")) + (next.map { " · " + tr("Next: \($0.name)") } ?? "")
        return .init(headline: tr(s.rest ? "Rest" : s.name), detail: detail, endsAt: paused ? nil : Date().addingTimeInterval(TimeInterval(left)),
                     since: nil, progress: Double(index) / Double(max(1, routine.steps.count)), paused: paused)
    }

    private func liveUpdate() { if live && liveStarted && !finished { LiveActivities.update(liveState()) } }

    private func say(_ text: String) async {
        if let data = pack?.audio(for: text) { _ = await clip.play(data); return }
        let u = AVSpeechUtterance(string: Narration.spoken(tr(text)))
        u.voice = AVSpeechSynthesisVoice(language: I18n.shared.speechLanguage)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synth.speak(u)
        // Let the line finish (roughly) before the timer starts talking over it.
        let words = Double(text.split(separator: " ").count)
        try? await Task.sleep(nanoseconds: UInt64(min(12, words / 2.6 + 0.6) * 1_000_000_000))
    }
}

struct RoutinePlayerView: View {
    @StateObject private var runner: RoutineRunner
    @ObservedObject private var media = TrainerMedia.shared
    @Environment(\.dismiss) private var dismiss
    private let onFinish: (() -> Void)?
    init(routine: GuidedRoutine, onFinish: (() -> Void)? = nil) {
        _runner = StateObject(wrappedValue: RoutineRunner(routine: routine))
        self.onFinish = onFinish
    }

    var body: some View {
        let r = runner.routine
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1226), Color(hex: 0x0B0810)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Button { runner.stop(); dismiss() } label: { Image(systemName: "xmark").font(.system(size: 18)).foregroundStyle(.white).frame(width: 44, height: 44) }
                        .accessibilityLabel(tr("Close"))
                    Spacer()
                    T(r.title).font(.hs(15, .semibold)).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                if !r.caution.isEmpty && runner.index == 0 {
                    T(r.caution).font(.hs(11)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                }
                Spacer()
                if runner.finished {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Color(hex: 0x56B892))
                    T("Workout complete. Well done.").font(.hs(22, .semibold)).foregroundStyle(.white)
                    GoldButton(title: onFinish == nil ? "Done" : "Save my day") { onFinish?(); dismiss() }.frame(width: 200)
                } else if r.steps.indices.contains(runner.index) {
                    let s = r.steps[runner.index]
                    T(s.rest ? "Rest" : "Step \(runner.index + 1) of \(r.steps.count)").font(.hs(12)).foregroundStyle(.white.opacity(0.6))
                    T(s.name).font(.hs(28, .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
                    // Step 0 shows the routine's intro clip (big play button) when one is available.
                    // All other steps (and step 0 when there's no intro clip) show TrainerMotion.
                    if runner.index == 0, let demo = media.clip(r.id) {
                        TrainerCard(clip: demo).frame(maxWidth: 320)
                    } else if let key = s.trainerKey {
                        TrainerMotion(moveKey: key, moveName: s.name, animate: !runner.paused && !s.rest, mirrored: s.trainerMirrored)
                            .aspectRatio(864.0 / 470.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .id(runner.index)          // each move gets its own player
                    }
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 8)
                        Circle().trim(from: 0, to: CGFloat(runner.left) / CGFloat(max(1, s.seconds)))
                            .stroke(s.rest ? Color(hex: 0x64A5E8) : Color(hex: 0xF3D5C0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90)).animation(.linear(duration: 1), value: runner.left)
                        D("\(runner.left)").font(.hs(44)).foregroundStyle(.white)
                    }
                    .frame(width: 140, height: 140)
                    T(s.cue).font(.hs(15)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).padding(.horizontal, 24)
                    if let next = r.steps.dropFirst(runner.index + 1).first(where: { !$0.rest }) {
                        T("Next up: \(next.name)").font(.hs(12)).foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                if !runner.finished {
                    HStack(spacing: 40) {
                        control("backward.fill", "Previous") { runner.jump(runner.index - 1) }
                        control(runner.paused ? "play.fill" : "pause.fill", runner.paused ? "Resume" : "Pause") { runner.paused.toggle() }
                        control("forward.fill", "Next") { runner.jump(runner.index + 1) }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
        .onAppear { runner.start() }
        .task { await TrainerLoops.shared.prefetch(runner.routine.steps) }
        .task { await media.refresh() }
        .onDisappear { runner.stop() }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 24)).foregroundStyle(.white)
                .frame(width: 64, height: 64).background(Circle().fill(Color.white.opacity(0.1)))
        }
        .accessibilityLabel(tr(label))
    }
}
