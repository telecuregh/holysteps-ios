import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

// QR codes for invites, the same as Android (ui/components/QrCode.kt): every invite code can be shown as a QR code
// for the other person's camera, and every "enter a code" place can scan one instead. The QR code holds the join
// link (https://holysteps.org/join?c=CODE), so even a phone without HolySteps opens a page with the code and a way to
// get the app. Codes are made and read on this phone only; camera frames are never stored or sent anywhere.

enum QR {
    /// A sharp QR image for [text], or nil if it can't be made.
    static func image(_ text: String, scale: CGFloat = 12) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// A QR code on a white card (scanners need the light quiet zone, in dark mode too).
struct QRImage: View {
    let text: String
    var size: CGFloat = 220
    var body: some View {
        if let ui = QR.image(text) {
            Image(uiImage: ui).interpolation(.none).resizable().scaledToFit()
                .frame(width: size, height: size)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                .accessibilityLabel(Text(tr("QR code for the invite")))
        }
    }
}

/// "Show QR code" for an invite code (Android: ShowQrButton / InviteCodeRow). [kind] is only for codes without a
/// prefix (safety circle, shared baby log).
struct ShowQRButton: View {
    let code: String
    var kind: String? = nil
    var label = "Show QR code"
    @State private var show = false
    var body: some View {
        Button { show = true } label: {
            Label(tr(label), systemImage: "qrcode").font(.hs(14, .semibold))
        }
        .foregroundStyle(HS.readable(0xA78BFA))
        .sheet(isPresented: $show) { QRInviteSheet(code: code, kind: kind) }
    }
}

struct QRInviteSheet: View {
    let code: String
    var kind: String? = nil
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let link = InviteCode.link(code, kind: kind)
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        T("Scan to join").font(.hs(20, .bold)).foregroundStyle(HS.text)
                        T("Any phone camera works: it opens the invite, or shows how to get HolySteps.")
                            .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                        QRImage(text: link.absoluteString)
                        D(code).font(.system(.title3, design: .monospaced).weight(.semibold)).foregroundStyle(HS.text)
                            .textSelection(.enabled).multilineTextAlignment(.center)
                        ShareLink(item: link, message: Text(tr("Join me on HolySteps! Tap to join, or open HolySteps and enter this code:") + " " + code)) {
                            Label(tr("Share invite"), systemImage: "square.and.arrow.up").font(.hs(15, .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent).tint(Color(hex: 0x7C3AED))
                    }
                    .padding(24)
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("Done")) { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}

/// "Scan QR code" for any place that takes an invite code (Android: ScanQrButton). Hands back the code inside a
/// HolySteps join link, or the scanned text as it was.
struct ScanQRButton: View {
    var label = "Scan QR code"
    let onCode: (String) -> Void
    @State private var show = false
    var body: some View {
        Button { show = true } label: {
            Label(tr(label), systemImage: "qrcode.viewfinder").font(.hs(14, .semibold))
        }
        .foregroundStyle(HS.readable(0xA78BFA))
        .sheet(isPresented: $show) {
            QRScanSheet { text in
                show = false
                onCode(InviteCode.clean(text))
            }
        }
    }
}

struct QRScanSheet: View {
    let onFound: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch access {
                case .authorized:
                    QRScannerView(onFound: onFound).ignoresSafeArea()
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.9), lineWidth: 3).frame(width: 240, height: 240)
                        Spacer()
                        T("Point the camera at the invite's QR code").font(.hs(15, .semibold)).foregroundStyle(.white)
                            .padding(.bottom, 40)
                    }
                case .notDetermined:
                    ProgressView().tint(.white)
                        .task {
                            let ok = await AVCaptureDevice.requestAccess(for: .video)
                            access = ok ? .authorized : .denied
                        }
                default:
                    VStack(spacing: 14) {
                        T("Camera access is off").font(.hs(18, .bold)).foregroundStyle(.white)
                        T("To scan a QR code, allow HolySteps to use the camera in Settings. You can also type the code instead.")
                            .font(.hs(14)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                        Button(tr("Open Settings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.buttonStyle(.borderedProminent)
                    }.padding(30)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { dismiss() }.foregroundStyle(.white) } }
        }
    }
}

/// Camera preview that reads QR codes with AVFoundation, on the phone only. Calls back once, then stops.
struct QRScannerView: UIViewControllerRepresentable {
    let onFound: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController(); c.onFound = onFound; return c
    }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onFound: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var preview: AVCaptureVideoPreviewLayer?
        private var done = false
        private let queue = DispatchQueue(label: "holysteps.qrscanner")

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            preview = layer
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
        }
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let s = session
            queue.async { if !s.isRunning { s.startRunning() } }
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            let s = session
            queue.async { if s.isRunning { s.stopRunning() } }
        }
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !done, let text = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue, !text.isEmpty else { return }
            done = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let s = session
            queue.async { s.stopRunning() }
            onFound?(text)
        }
    }
}
