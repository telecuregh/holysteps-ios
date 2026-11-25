import Foundation
import WatchConnectivity

/// Tells the Apple Watch app which plans are on (prayer walks and breath prayer come with Fitness).
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()
    private var pending: [String: Any]?

    func send(fitness: Bool) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        pending = ["fitness": fitness]
        if s.delegate == nil { s.delegate = self; s.activate() } else { flush() }
    }

    private func flush() {
        let s = WCSession.default
        guard s.activationState == .activated, s.isPaired, s.isWatchAppInstalled, let p = pending else { return }
        try? s.updateApplicationContext(p)
    }

    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) { DispatchQueue.main.async { self.flush() } }
    func sessionDidBecomeInactive(_ s: WCSession) {}
    func sessionDidDeactivate(_ s: WCSession) { s.activate() }
}
