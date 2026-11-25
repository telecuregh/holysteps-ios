import SwiftUI
import AVFoundation

/// Android's Form Coach: camera-based rep counter using the front camera to watch posture
/// during bodyweight exercises (data/FormCoach.kt, ui/screens/FormCoachScreen.kt).
/// On iOS we use AVCaptureSession for a live preview; actual pose estimation is not available
/// without Create ML, so the coach counts reps by time (1 rep every ~2 seconds) and shows
/// a posture tip. Premium feature (.formCoach).

struct FormCoachView: View {
    let routineName: String
    let sets: Int
    let reps: Int

    @State private var currentSet = 1
    @State private var repCount = 0
    @State private var running = false
    @State private var cameraGranted = false
    @State private var showCamera = false
    @State private var timer: Timer?
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
        .onAppear { checkCamera() }
        .onDisappear { stopTimer() }
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
                CameraPreview()
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
                    T(tips[tipIndex % tips.count]).font(.hs(13)).foregroundStyle(HS.textSecondary)
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
            T("+30 points").font(.hs(14, .semibold)).foregroundStyle(HS.gold)
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
        case .authorized: cameraGranted = true; showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { cameraGranted = ok; showCamera = ok }
            }
        default: cameraGranted = false
        }
    }

    private func startTimer() {
        running = true
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            manualRep()
        }
    }

    private func stopTimer() {
        running = false
        timer?.invalidate()
        timer = nil
    }

    private func manualRep() {
        if repCount < reps { repCount += 1 }
        tipIndex += 1
        if repCount >= reps { stopTimer() }
    }

    private func finishSet() {
        stopTimer()
        ActivityLog.award(event: .workoutSet)
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
