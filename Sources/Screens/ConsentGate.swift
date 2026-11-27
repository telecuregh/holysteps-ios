import SwiftUI

/// Shown before anything else until the current Terms of Service and Privacy Policy have been accepted, and again whenever
/// either is updated ([Legal.version] changes). Same version string and the same Firestore record (consents/{uid}) as the
/// Android app, so an account's acceptance is one fact on both phones.
enum Legal {
    static let version = "2026-11-26.1"
    static let lastUpdated = "November 26, 2026"
    private static let acceptedKey = "legalAcceptedVersion"
    private static let syncedKey = "legalSyncedVersion"

    static var accepted: Bool { UserDefaults.standard.string(forKey: acceptedKey) == version }
    static func accept() { UserDefaults.standard.set(version, forKey: acceptedKey) }

    /// Writes the acceptance to the account once it has a signed-in identity. Safe to call often.
    static func syncIfNeeded() async {
        guard accepted, UserDefaults.standard.string(forKey: syncedKey) != version,
              let uid = await AccountStore.shared.uid else { return }
        let app = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "").prefix(24)
        do {
            try await Firestore.commit([.set("consents/\(uid)", [
                "uid": .string(uid), "version": .string(version),
                "acceptedAt": .int(Firestore.nowMs), "appVersion": .string(String(app))
            ], mustNotExist: false)])
            UserDefaults.standard.set(version, forKey: syncedKey)
        } catch { /* tried again next launch */ }
    }
}

struct ConsentGateView: View {
    var onAccept: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("👣").font(.system(size: 44)).padding(.top, 60)
                T("Before you begin").font(.hs(24, .bold)).foregroundStyle(HS.text).multilineTextAlignment(.center)
                D(tr("Please read and accept the HolySteps Terms of Service and Privacy Policy. Updated \(Legal.lastUpdated)."))
                    .font(.hs(14)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(["Your health, cycle, journal and Freedom information stays on your phone unless you choose to share it.",
                             "You can delete your account and its data from Profile at any time.",
                             "HolySteps is a wellness companion with optional faith content, not medical care or a crisis service."], id: \.self) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•").foregroundStyle(HS.textMuted)
                            T(line).font(.hs(14)).foregroundStyle(HS.text)
                        }
                    }
                }.padding(.vertical, 8)
                Button { openURL(URL(string: AppLinks.site + "/terms")!) } label: {
                    T("Read the Terms of Service").font(.hs(15, .semibold)).frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.bordered)
                Button { openURL(URL(string: AppLinks.site + "/privacy")!) } label: {
                    T("Read the Privacy Policy").font(.hs(15, .semibold)).frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.bordered)
                Button { Legal.accept(); onAccept(); Task { await Legal.syncIfNeeded() } } label: {
                    T("I agree").font(.hs(16, .bold)).frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.borderedProminent).padding(.top, 8)
                T("By tapping “I agree” you confirm you are at least 13 years old, accept both documents, and agree that HolySteps may collect the health information you choose to log (such as cycle, pregnancy, mood and activity) to run the features you use, as described in the Consumer Health Data section of the Privacy Policy. You can withdraw this at any time by deleting the data or your account.")
                    .font(.hs(12)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
        }
        .background(HSBackground())
    }
}
