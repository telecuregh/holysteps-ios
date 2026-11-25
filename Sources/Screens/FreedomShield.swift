import SwiftUI
import CryptoKit
import FamilyControls
import ManagedSettings

/// Freedom Shield: real Screen Time blocking of the apps and websites the person chooses,
/// plus Apple's adult-content web filter. Turning it off needs a partner's 6-digit code
/// (stored only as a salted SHA-256 hash) or a 24-hour wait. Everything stays on device.
/// Hidden until Apple approves the Family Controls distribution entitlement (HSScreenTimeEnabled).
@MainActor
final class FreedomShield: ObservableObject {
    static let shared = FreedomShield()
    static var available: Bool { Bundle.main.object(forInfoDictionaryKey: "HSScreenTimeEnabled") as? Bool ?? false }

    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("holysteps.freedom"))
    private let d = UserDefaults.standard

    @Published var selection = FamilyActivitySelection()
    @Published private(set) var on = false
    @Published private(set) var authorized = false
    @Published private(set) var unlockAt: Date?
    @Published var filterAdult = true

    var hasCode: Bool { d.string(forKey: "shieldCodeHash") != nil }
    var picked: Int { selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count }

    private init() {
        if let data = d.data(forKey: "shieldSelection"), let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { selection = s }
        on = d.bool(forKey: "shieldOn")
        filterAdult = d.object(forKey: "shieldAdult") as? Bool ?? true
        unlockAt = d.object(forKey: "shieldUnlockAt") as? Date
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        checkTimedUnlock()
    }

    func authorize() async {
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) } catch {}
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func saveSelection() {
        if let data = try? JSONEncoder().encode(selection) { d.set(data, forKey: "shieldSelection") }
        d.set(filterAdult, forKey: "shieldAdult")
        if on { apply() }
    }

    func setCode(_ code: String) { d.set(hash(code), forKey: "shieldCodeHash") }
    func check(_ code: String) -> Bool { d.string(forKey: "shieldCodeHash") == hash(code) }

    func turnOn() { on = true; d.set(true, forKey: "shieldOn"); cancelTimedUnlock(); apply() }

    /// Off with the partner's code (or right away when no code was ever set).
    func turnOff(code: String?) -> Bool {
        if hasCode, !(code.map(check) ?? false) { return false }
        clear(); return true
    }

    func startTimedUnlock() {
        let t = Date().addingTimeInterval(24 * 3600)
        unlockAt = t; d.set(t, forKey: "shieldUnlockAt")
    }
    func cancelTimedUnlock() { unlockAt = nil; d.removeObject(forKey: "shieldUnlockAt") }

    func checkTimedUnlock() {
        if let t = unlockAt, t <= Date() { clear() }
    }

    private func clear() {
        on = false; d.set(false, forKey: "shieldOn"); cancelTimedUnlock()
        store.clearAllSettings()
    }

    private func apply() {
        guard authorized else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.webContent.blockedByFilter = filterAdult ? .auto() : nil
    }

    private func hash(_ code: String) -> String {
        let salt = d.string(forKey: "shieldSalt") ?? { let s = UUID().uuidString; d.set(s, forKey: "shieldSalt"); return s }()
        return SHA256.hash(data: Data((salt + code).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Entry card on the Freedom screen.
struct FreedomShieldCard: View {
    @ObservedObject private var shield = FreedomShield.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var open = false
    @State private var paywall = false

    var body: some View {
        Button { account.canUse(.freedomShield) ? (open = true) : (paywall = true) } label: {
            GlassCard(padding: 14) {
                HStack(spacing: 12) {
                    Image(systemName: shield.on ? "lock.shield.fill" : "shield").font(.system(size: 22)).foregroundStyle(HS.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        T("Freedom Shield").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T(account.canUse(.freedomShield) ? (shield.on ? "On. Your chosen apps and sites are blocked." : "Block the apps and sites that pull you back.") : Feature.freedomShield.lockMessage)
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    Image(systemName: account.canUse(.freedomShield) ? "chevron.right" : "lock.fill").foregroundStyle(HS.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) { FreedomShieldView() }
        .sheet(isPresented: $paywall) { PlansView(feature: .freedomShield) }
    }
}

struct FreedomShieldView: View {
    @ObservedObject private var shield = FreedomShield.shared
    @State private var picking = false
    @State private var code = ""
    @State private var newCode = ""
    @State private var wrong = false

    var body: some View {
        HSSheet(title: "Freedom Shield") {
            VStack(alignment: .leading, spacing: 16) {
                T("Choose the apps and websites that pull you back. While the shield is on, they won't open. To turn it off, your accountability partner types their code, or you wait 24 hours.")
                    .font(.hs(14)).foregroundStyle(HS.textSecondary)

                if !shield.authorized {
                    GoldButton(title: "Allow Screen Time") { Task { await shield.authorize() } }
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button { picking = true } label: {
                                HStack {
                                    T("Apps and websites").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                    Spacer()
                                    D(shield.picked == 0 ? tr("Choose") : tr("{0} chosen").replacingOccurrences(of: "{0}", with: "\(shield.picked)")).font(.hs(13)).foregroundStyle(HS.gold)
                                }
                            }
                            Toggle(isOn: $shield.filterAdult) { T("Block adult websites").font(.hs(14)).foregroundStyle(HS.text) }
                                .tint(HS.gold)
                                .onChange(of: shield.filterAdult) { _, _ in shield.saveSelection() }
                        }
                    }
                    .familyActivityPicker(isPresented: $picking, selection: $shield.selection)
                    .onChange(of: picking) { _, p in if !p { shield.saveSelection() } }

                    if !shield.hasCode {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                T("Partner's code").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                T("Hand your phone to your accountability partner and let them type a 6-digit code only they know.").font(.hs(12)).foregroundStyle(HS.textMuted)
                                SecureField(tr("6 digits"), text: $newCode).keyboardType(.numberPad).textContentType(.oneTimeCode)
                                    .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                                GoldButton(title: "Save code") { shield.setCode(newCode); newCode = "" }
                                    .disabled(newCode.count != 6 || !newCode.allSatisfy(\.isNumber))
                            }
                        }
                    }

                    if shield.on {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                T("Turn off").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                if shield.hasCode {
                                    SecureField(tr("Partner's code"), text: $code).keyboardType(.numberPad)
                                        .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.cardFill))
                                    if wrong { T("That code isn't right.").font(.hs(12)).foregroundStyle(.red) }
                                }
                                Button { wrong = !shield.turnOff(code: code); code = "" } label: {
                                    T("Turn off with code").font(.hs(15, .semibold)).foregroundStyle(HS.gold)
                                }
                                if let t = shield.unlockAt {
                                    D(tr("Turns off on its own at {0}").replacingOccurrences(of: "{0}", with: t.formatted(.dateTime.month().day().hour().minute().locale(I18n.shared.locale)))).font(.hs(12)).foregroundStyle(HS.textMuted)
                                    Button { shield.cancelTimedUnlock() } label: { T("Keep it on").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                                } else if shield.hasCode {
                                    Button { shield.startTimedUnlock() } label: { T("Lost the code? Turn off in 24 hours").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                                }
                            }
                        }
                    } else {
                        GoldButton(title: "Turn on the shield") { shield.saveSelection(); shield.turnOn() }
                            .disabled(shield.picked == 0 && !shield.filterAdult)
                    }
                }
            }
            .padding(24)
        }
        .onAppear { shield.checkTimedUnlock() }
    }
}
