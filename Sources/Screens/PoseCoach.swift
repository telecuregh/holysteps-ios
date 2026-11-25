import SwiftUI
import AVFoundation
import Vision

/// The Form Coach's eyes: Vision finds your body in the front camera, counts each rep from the angle of the joint
/// that moves (knees for squats and lunges, elbows for push-ups, arms for jacks), and gives one plain cue when form
/// slips. On iOS 17 a 3D body pose checks how far your chest leans in squats. Every frame stays on the phone.
enum PoseMove {
    case knees, elbows, arms
    static func from(_ name: String) -> PoseMove {
        let n = name.lowercased()
        if n.contains("push") || n.contains("dip") || n.contains("press") { return .elbows }
        if n.contains("jack") || n.contains("arm") || n.contains("raise") || n.contains("overhead") { return .arms }
        return .knees
    }
    /// Below `down` counts as the bottom of a rep, back above `up` finishes it.
    var down: Double { self == .arms ? 0.35 : 100 }
    var up: Double { self == .arms ? 0.65 : 150 }
}

final class PoseTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published private(set) var cue: String?
    @Published private(set) var seen = false
    var counting = false
    var onRep: (() -> Void)?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "pose")
    private var move: PoseMove = .knees
    private var atBottom = false
    private var deepest = 180.0
    private var frame = 0
    private var request = VNDetectHumanBodyPoseRequest()

    func start(_ move: PoseMove) {
        self.move = move
        queue.async { [self] in
            guard session.inputs.isEmpty else { if !session.isRunning { session.startRunning() }; return }
            session.beginConfiguration()
            session.sessionPreset = .vga640x480
            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) else { session.commitConfiguration(); return }
            session.addInput(input)
            let out = AVCaptureVideoDataOutput()
            out.alwaysDiscardsLateVideoFrames = true
            out.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(out) { session.addOutput(out) }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() { queue.async { [self] in session.stopRunning() } }

    func captureOutput(_ output: AVCaptureOutput, didOutput sample: CMSampleBuffer, from connection: AVCaptureConnection) {
        frame += 1
        guard frame % 2 == 0 else { return }   // about 15 checks a second is plenty
        let handler = VNImageRequestHandler(cmSampleBuffer: sample, orientation: .leftMirrored)
        try? handler.perform([request])
        guard let body = request.results?.first, let points = try? body.recognizedPoints(.all) else {
            DispatchQueue.main.async { self.seen = false; self.joints = [:] }
            return
        }
        let good = points.filter { $0.value.confidence > 0.3 }.mapValues { $0.location }
        let lean = frame % 30 == 0 && move == .knees ? chestLean(sample) : nil
        let (value, formCue) = measure(good)
        DispatchQueue.main.async {
            self.seen = true
            self.joints = good
            if let lean, lean > 50 { self.cue = "Keep your chest up" }
            else if let formCue { self.cue = formCue }
            if let value, self.counting { self.track(value) }
        }
    }

    private func angle(_ a: CGPoint?, _ b: CGPoint?, _ c: CGPoint?) -> Double? {
        guard let a, let b, let c else { return nil }
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y), v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let m = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard m > 0 else { return nil }
        return Foundation.acos(Double(max(-1, min(1, dot / m)))) * 180 / .pi
    }

    private func best(_ l: Double?, _ r: Double?) -> Double? { [l, r].compactMap { $0 }.min() }

    /// The number the rep is counted from, plus a form cue when one is clear.
    private func measure(_ p: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> (Double?, String?) {
        switch move {
        case .knees:
            let k = best(angle(p[.leftHip], p[.leftKnee], p[.leftAnkle]), angle(p[.rightHip], p[.rightKnee], p[.rightAnkle]))
            return (k, nil)
        case .elbows:
            let e = best(angle(p[.leftShoulder], p[.leftElbow], p[.leftWrist]), angle(p[.rightShoulder], p[.rightElbow], p[.rightWrist]))
            let line = best(angle(p[.leftShoulder], p[.leftHip], p[.leftAnkle]), angle(p[.rightShoulder], p[.rightHip], p[.rightAnkle]))
            return (e, (line ?? 180) < 155 ? "Keep your body in a straight line" : nil)
        case .arms:
            guard let n = p[.neck], let r = p[.root] else { return (nil, nil) }
            let torso = max(0.05, n.y - r.y)
            let wrists = [p[.leftWrist], p[.rightWrist]].compactMap { $0 }
            guard !wrists.isEmpty else { return (nil, nil) }
            let high = wrists.map { ($0.y - n.y) / torso }.reduce(0, +) / Double(wrists.count)
            // 0 at the shoulders, 1 a torso above them; mapped so "down" is a low number like the angles.
            return (max(0, min(1, (high + 0.5) / 1.5)), nil)
        }
    }

    private func track(_ v: Double) {
        if move == .arms {
            if !atBottom, v > move.up { atBottom = true }
            else if atBottom, v < move.down { atBottom = false; onRep?() }
            return
        }
        if !atBottom, v < move.down { atBottom = true; deepest = v }
        else if atBottom { deepest = min(deepest, v) }
        if atBottom, v > move.up {
            atBottom = false
            onRep?()
            cue = deepest > 90 && move == .knees ? "Go a little lower if you can" : (deepest > 95 && move == .elbows ? "Lower your chest a bit more" : nil)
        }
    }

    /// The angle between your spine and straight up, from Apple's 3D body pose (iOS 17).
    private func chestLean(_ sample: CMSampleBuffer) -> Double? {
        guard #available(iOS 17.0, *) else { return nil }
        let r = VNDetectHumanBodyPose3DRequest()
        try? VNImageRequestHandler(cmSampleBuffer: sample, orientation: .leftMirrored).perform([r])
        guard let o = r.results?.first,
              let root = try? o.recognizedPoint(.root), let top = try? o.recognizedPoint(.centerShoulder) else { return nil }
        let a = root.position.columns.3, b = top.position.columns.3
        let dx = Double(b.x - a.x), dy = Double(b.y - a.y), dz = Double(b.z - a.z)
        let len = sqrt(dx * dx + dy * dy + dz * dz)
        guard len > 0.1 else { return nil }
        return acos(max(-1, min(1, dy / len))) * 180 / .pi
    }
}

/// Front camera with your skeleton drawn over it.
struct PoseCameraView: View {
    @ObservedObject var tracker: PoseTracker

    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist), (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist), (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle), (.neck, .nose),
    ]

    var body: some View {
        GeometryReader { g in
            ZStack {
                SessionPreview(session: tracker.session)
                Canvas { ctx, size in
                    // The camera image is 480×640 when upright, filled to the view like the preview.
                    let scale = max(size.width / 480, size.height / 640)
                    let w = 480 * scale, h = 640 * scale
                    let ox = (size.width - w) / 2, oy = (size.height - h) / 2
                    func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * w, y: oy + (1 - p.y) * h) }
                    var path = Path()
                    for (a, b) in Self.bones {
                        if let pa = tracker.joints[a], let pb = tracker.joints[b] { path.move(to: pt(pa)); path.addLine(to: pt(pb)) }
                    }
                    ctx.stroke(path, with: .color(HS.gold), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    for p in tracker.joints.values {
                        ctx.fill(Path(ellipseIn: CGRect(x: pt(p).x - 4, y: pt(p).y - 4, width: 8, height: 8)), with: .color(.white))
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

private struct SessionPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> Preview { let v = Preview(); v.layer2.session = session; v.layer2.videoGravity = .resizeAspectFill; return v }
    func updateUIView(_ uiView: Preview, context: Context) {}
    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var layer2: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
