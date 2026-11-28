import SwiftUI
import AVFoundation

/// Android's Form Coach: camera-based rep counter using the front camera to watch posture
/// during bodyweight exercises (data/FormCoach.kt, ui/screens/FormCoachScreen.kt).
/// Vision body pose (PoseCoach.swift) counts the reps from the front camera and gives form cues;
/// the Rep button still counts by hand. Premium feature (.formCoach).

struct FormCoachView: View {
    let routineName: String
    let sets: Int
    let reps: Int

    @State private var currentSet = 1
    @State private var repCount = 0
    @State private var running = false
    @State private var cameraGranted = false
    @State private var showCamera = false
    @StateObject private var tracker = PoseTracker()
    @State private var done = false
    @ObservedObject private var account = AccountStore.shared
    @Environment(\.dismiss) private var dismiss

    private let tips = [
        "Keep your core tight throughout the movement.",
        "Breathe out on the effort, in on the return.",
        "Move through the full range of motion.",
        "Keep your neck neutral, look straight ahead.",
        "Slow down on the way back for more benefit.",
        "Quality over speed. Control the movement.",
    ]
    @State private var tipIndex = 0

    var body: some View {
        ZStack {
            HSBackground()
            if done {
                doneView
            } else {
                VStack(spacing: 0) {
                    header
                    cameraArea
                    controls
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            tracker.onRep = { manualRep() }
            checkCamera()
        }
        .onDisappear { stopTimer(); tracker.stop() }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17)).foregroundStyle(HS.text)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                Spacer()
                VStack {
                    T(routineName).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T("Set \(currentSet) of \(sets)").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            Divider().opacity(0.3)
        }
        .padding(.top, 60)
    }

    // MARK: Camera area

    private var cameraArea: some View {
        ZStack {
            if showCamera && cameraGranted {
                PoseCameraView(tracker: tracker)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(HS.overlay(0.08))
                    .frame(height: 320)
                    .padding(.horizontal, 20)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill").font(.system(size: 32)).foregroundStyle(HS.textMuted)
                            if !cameraGranted {
                                T("Allow camera access in Settings to see your form")
                                    .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                Button { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } label: {
                                    T("Open Settings").font(.hs(13, .semibold)).foregroundStyle(HS.peach)
                                }
                            } else {
                                T("Camera ready").font(.hs(13)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
            }
            VStack {
                if showCamera && cameraGranted && running && !tracker.seen {
                    T("Step back so your whole body is in view").font(.hs(13, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(.black.opacity(0.5))).padding(.top, 12)
                }
                Spacer()
                // Rep counter overlay
                VStack(spacing: 2) {
                    D("\(repCount)").font(.hs(56, .bold)).foregroundStyle(.white).monospacedDigit()
                        .shadow(color: .black.opacity(0.5), radius: 4)
                    T("of \(reps) reps").font(.hs(14)).foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
                .padding(.bottom, 20)
            }
            .frame(height: 320)
        }
        .padding(.top, 20)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 16) {
            GlassCard {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb").font(.system(size: 14)).foregroundStyle(HS.gold)
                    T(tracker.cue ?? tips[tipIndex % tips.count]).font(.hs(13)).foregroundStyle(tracker.cue == nil ? HS.textSecondary : HS.gold)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20)

            HStack(spacing: 12) {
                Button { manualRep() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                        T("Rep").font(.hs(15, .semibold))
                    }
                    .foregroundStyle(HS.onGold)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(HS.goldButton))
                }
                .buttonStyle(.plain)

                Button {
                    if running { stopTimer() } else { startTimer() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: running ? "pause.fill" : "play.fill").font(.system(size: 15))
                        T(running ? "Pause" : "Auto count").font(.hs(14))
                    }
                    .foregroundStyle(HS.text)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(HS.overlay(0.08)))
                    .overlay(Capsule().strokeBorder(HS.overlay(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Button { finishSet() } label: {
                T(currentSet >= sets ? "Finish workout" : "Done with set \(currentSet)")
                    .font(.hs(14)).foregroundStyle(HS.peach)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(HS.body)
            T("Workout complete!").font(.hs(26, .bold)).foregroundStyle(HS.text)
            T("\(sets) sets of \(reps) reps")
                .font(.hs(16)).foregroundStyle(HS.textMuted)
            T("+20 points, once a day").font(.hs(14, .semibold)).foregroundStyle(HS.gold)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Capsule().fill(HS.goldButton.opacity(0.15)))
            Spacer()
            GoldButton(title: "Done") { dismiss() }
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: Logic

    private func checkCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraGranted = true; showCamera = true; tracker.start(PoseMove.from(routineName))
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { cameraGranted = ok; showCamera = ok; if ok { tracker.start(PoseMove.from(routineName)) } }
            }
        default: cameraGranted = false
        }
    }

    private func startTimer() { running = true; tracker.counting = true }

    private func stopTimer() { running = false; tracker.counting = false }

    private func manualRep() {
        if repCount < reps { repCount += 1 }
        tipIndex += 1
        if repCount >= reps { stopTimer() }
    }

    private func finishSet() {
        stopTimer()
        ActivityLog.shared.add(.workoutSet)
        let d = UserDefaults.standard
        d.set(d.integer(forKey: "formCoachSets") + 1, forKey: "formCoachSets")
        d.set(d.integer(forKey: "formCoachReps") + repCount, forKey: "formCoachReps")
        if currentSet >= sets {
            done = true
        } else {
            currentSet += 1
            repCount = 0
        }
    }
}

/// A simple live camera preview using AVCaptureSession (front camera).
struct CameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.start()
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        private var session: AVCaptureSession?
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        func start() {
            let s = AVCaptureSession()
            s.sessionPreset = .medium
            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: dev) else { return }
            s.addInput(input)
            previewLayer.session = s
            previewLayer.videoGravity = .resizeAspectFill
            session = s
            DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
        }
    }
}

/// Android's FormCoachExercisePicker: the five exercises the camera can count, with how to set the phone up.
/// Locked behind the Fitness plan like Android (Feature.FORM_COACH).
struct FormCoachPickerView: View {
    struct Exercise: Identifiable { let id: String; let emoji: String; let instructions: String }
    static let exercises = [
        Exercise(id: "Squats", emoji: "🏋️", instructions: "Stand sideways-on to the phone, about 6 feet back, full body in frame."),
        Exercise(id: "Push-ups", emoji: "💪", instructions: "Set the phone low and sideways-on, full body in frame."),
        Exercise(id: "Lunges", emoji: "🦵", instructions: "Stand sideways-on to the phone, about 6 feet back, full body in frame."),
        Exercise(id: "Bicep Curls", emoji: "💪", instructions: "Stand facing the phone slightly sideways, holding a weight (or just your arm), full body in frame."),
        Exercise(id: "Sit-ups", emoji: "🔥", instructions: "Lie down sideways-on to the phone, far enough back that your knees and shoulders are both in frame."),
    ]
    @ObservedObject private var account = AccountStore.shared
    @AppStorage("formCoachSets") private var sets = 0
    @AppStorage("formCoachReps") private var reps = 0
    @State private var paywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    T("📷 CAMERA FORM COACH").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                    T(account.canUse(.formCoach) ? "Pick an exercise" : "See your form in real time").font(.hs(24, .light)).foregroundStyle(HS.text)
                        .accessibilityAddTraits(.isHeader)
                    T("move with mindful form").font(.custom("PlayfairDisplay-Italic", size: 18)).foregroundStyle(HS.peach)
                    if sets > 0 { D("\(sets) \(tr(sets == 1 ? "set" : "sets")) · \(reps) \(tr(reps == 1 ? "rep" : "reps")) \(tr("all-time"))").font(.hs(12)).foregroundStyle(HS.textMuted) }
                }
                if !account.canUse(.formCoach) {
                    GlassCard(warm: true) {
                        VStack(spacing: 12) {
                            Text("📷").font(.system(size: 48))
                            T("Your phone's camera counts reps and checks your depth on squats and push-ups — entirely on your device.")
                                .font(.hs(14)).foregroundStyle(HS.textSecondary).multilineTextAlignment(.center)
                            GoldButton(title: "Get the Fitness plan") { paywall = true }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(Self.exercises) { ex in
                        NavigationLink {
                            FormCoachView(routineName: ex.id, sets: 3, reps: 10)
                        } label: {
                            HStack(spacing: 16) {
                                Text(ex.emoji).font(.system(size: 32))
                                VStack(alignment: .leading, spacing: 4) {
                                    T(ex.id).font(.hs(17, .bold)).foregroundStyle(HS.text)
                                    T(ex.instructions).font(.hs(12)).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(HS.textMuted)
                            }
                            .padding(18)
                            .background(RoundedRectangle(cornerRadius: 18).fill(HS.cardFill))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(HS.gold.opacity(0.24), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("🔒").font(.system(size: 14))
                    T("On-device only — every frame is analyzed on your phone and discarded immediately. Nothing is recorded, saved, or uploaded.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .padding(12)
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Form Coach"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $paywall) { PlansView(feature: .formCoach) }
    }
}
