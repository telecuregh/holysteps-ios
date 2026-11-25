import Foundation
import Security
import CryptoKit
import UIKit
import UserNotifications

// Phase 2: the account and its plans, as Android does it (firebase/FirebaseAuthManager.kt, data/Plans.kt,
// data/WebStore.kt, data/WebCheckout.kt).
//
// Identity is Firebase anonymous sign-in: one stable account ID per install, no email or password. This talks to
// Firebase over its REST API (Identity Toolkit and Firestore) instead of bundling the Firebase SDK; the API key and
// project come from GoogleService-Info.plist at run time. Without that file the app runs without an account and
// every plan feature stays open (development builds).

enum FirebaseConfig {
    static let values: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let d = try? Data(contentsOf: url),
              let p = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any] else { return nil }
        return p
    }()
    static var apiKey: String? { values?["API_KEY"] as? String }
    static var projectId: String? { values?["PROJECT_ID"] as? String }
    static var isConfigured: Bool { apiKey != nil && projectId != nil }
}

/// The refresh token lives in the Keychain (this device only).
enum Keychain {
    static func set(_ value: String?, for key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecAttrService as String: "com.holysteps.app"]
        SecItemDelete(q as CFDictionary)
        guard let value, let d = value.data(using: .utf8) else { return }
        var add = q
        add[kSecValueData as String] = d
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecAttrService as String: "com.holysteps.app",
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
}

/// The four plans (Plans.kt Plan).
enum Plan: String, CaseIterable, Identifiable {
    case faith, fitness, cycle, wellness
    var id: String { rawValue }
    var name: String { ["faith": "Faith", "fitness": "Fitness", "cycle": "Cycle", "wellness": "Wellness"][rawValue]! }
    var emoji: String { ["faith": "🕊️", "fitness": "👣", "cycle": "🌸", "wellness": "💚"][rawValue]! }
    var tagline: String {
        switch self {
        case .faith: "Pray, rest and grow in the Word"
        case .fitness: "Move with purpose"
        case .cycle: "For women — know your body and your season"
        case .wellness: "For men — strength and health for every stage"
        }
    }
    var features: [String] {
        switch self {
        case .faith: ["Prayer walk map: a short prayer for each place you pass", "Bible sleep stories, night prayers and kids' bedtime stories",
                      "The full Audio Sanctuary: every prayer journey and soundscape",
                      "A new recorded sermon every week, through all 66 books of the Bible, and sermons for what you're facing",
                      "Every devotional plan, with each day's full reflection and challenge", "Verse images to share",
                      "Every Bible journey for your walks", "Every Scripture memory verse",
                      "Every hymn and worship song, and all your own music", "Family Faith Relay"]
        case .fitness: ["Adaptive Coach that learns your week", "Camera Form Coach for your reps", "Guided walk plans, with month and year statistics",
                        "Walk check: a coaching note on every walk", "Commitment challenges, backed by your card if you like", "Sleep and heart insights from your ring or watch",
                        "Calm check, sleep sounds and breathing insights: what calms you most and how your nights compare", "A safety circle of up to 10 people"]
        case .cycle: ["Every cycle phase insight", "Skin journal patterns through your cycle", "Cycle report to share with your doctor", "Partner coaching",
                      "Life and Health Trends with 90-day charts", "Weekly whole-person report: what really helps you",
                      "The baby tracker: feeds, sleep, diapers, growth charts, milestones and white noise",
                      "Body & energy: a daily log for menopause, arthritis, thyroid or chronic pain"]
        case .wellness: ["Your whole men's health plan: every move, meal and mindset idea, each day", "Partner coaching: deeper guidance to support your partner through every phase",
                         "Life and Health Trends with 90-day charts", "Weekly whole-person report: what really helps you",
                         "Calm check, sleep sounds and breathing insights: what calms you most and how your nights compare",
                         "The baby tracker: feeds, sleep, diapers, growth charts, milestones and white noise",
                         "Body & energy: a daily log for menopause, arthritis, thyroid or chronic pain"]
        }
    }
    static let everyPlanPerks = ["Unlimited faith chat", "Host live rooms and group walks", "Lead up to 3 habit circles",
                                 "Your whole journal, not just the last 7 days", "Start groups of your own"]
}

/// Everything the app can lock (Plans.kt Feature): opens with one of its plans (all four when needsAll), or an
/// older tier from minTier up.
enum Feature: String {
    case bibleJourneys, versesPremium, sanctuaryFull, bibleAudio, devotionalPlans, familyRelay, prayerWalkMap
    case adaptiveCoach, formCoach, walkPlus, walkAiCheck, realStakes, wearableInsights
    case cycleInsights, partnerCoaching, trends, mensHealth, aiUnlimited, liveRooms, habitTemplates
    case babyTracker, bodyEnergy, hymns, bibleNotes, journalHistory, createGroup, church
    case freedomShield, faithCoach, spiritStress

    var minTier: Int {
        switch self {
        case .bibleJourneys, .versesPremium, .devotionalPlans, .prayerWalkMap, .wearableInsights, .mensHealth,
             .babyTracker, .bodyEnergy, .hymns, .bibleNotes, .journalHistory, .createGroup, .faithCoach, .spiritStress: 1
        case .aiUnlimited, .liveRooms: 2
        case .sanctuaryFull, .bibleAudio: 3
        case .adaptiveCoach, .formCoach, .walkPlus: 4
        case .cycleInsights, .trends: 5
        case .familyRelay, .realStakes, .partnerCoaching, .habitTemplates, .church, .freedomShield: 6
        case .walkAiCheck: 7
        }
    }
    var plans: Set<Plan> {
        switch self {
        case .spiritStress: [.faith, .wellness]
        case .bibleJourneys, .versesPremium, .sanctuaryFull, .bibleAudio, .devotionalPlans, .familyRelay, .prayerWalkMap, .hymns, .bibleNotes, .faithCoach: [.faith]
        case .adaptiveCoach, .formCoach, .walkPlus, .walkAiCheck, .realStakes: [.fitness]
        case .wearableInsights: [.fitness, .wellness]
        case .cycleInsights: [.cycle]
        case .partnerCoaching, .trends, .babyTracker, .bodyEnergy: [.cycle, .wellness]
        case .mensHealth: [.wellness]
        case .aiUnlimited, .liveRooms, .habitTemplates, .journalHistory, .createGroup, .church, .freedomShield: Set(Plan.allCases)
        }
    }
    var needsAll: Bool { self == .habitTemplates || self == .church || self == .freedomShield }
    /// Free for everyone, like the big Bible apps: the whole Bible to read and hear, with highlights and notes.
    var freeLikeBibleApps: Bool { self == .bibleAudio || self == .bibleNotes }
    /// Android's paywall reason line for this feature.
    var lockMessage: String {
        switch self {
        case .bibleJourneys: "Every Bible journey is part of the Faith plan."
        case .versesPremium: "Verse images are part of the Faith plan.\nReading, highlights and notes stay free."
        case .sanctuaryFull: "The full Sanctuary, every journey and soundscape,\nis part of the Faith plan."
        case .bibleAudio: "Listening to the Bible, any chapter read aloud,\nis part of the Faith plan."
        case .devotionalPlans: "Devotional plans are part of the Faith plan."
        case .familyRelay: "Family Faith Relay is part of the Faith plan."
        case .prayerWalkMap: "The Prayer walk map is part of the Faith plan:\na short prayer for each place you pass."
        case .hymns: "Every hymn and worship song\nis part of the Faith plan."
        case .bibleNotes: "Verse images are part of the Faith plan.\nReading, highlights and notes stay free."
        case .adaptiveCoach: "The Adaptive Coach is part of the Fitness plan:\nit learns your sleep, stress and week."
        case .formCoach: "The Camera Form Coach is part of the Fitness plan."
        case .walkPlus: "Guided walk plans and month and year statistics\nare part of the Fitness plan."
        case .walkAiCheck: "A written check on every walk\nis part of the Fitness plan."
        case .realStakes: "Commitment challenges are part of the Fitness plan."
        case .wearableInsights: "Sleep and heart insights from your ring or watch\ncome with the Fitness or Wellness plan. Steps stay free."
        case .cycleInsights: "Every cycle phase insight and your doctor report\nare part of the Cycle plan."
        case .partnerCoaching: "Partner coaching is part of the Cycle and Wellness plans."
        case .trends: "Your full Life and Health Trends\ncome with the Cycle or Wellness plan."
        case .mensHealth: "The men's health plan is part of the Wellness plan."
        case .babyTracker: "The baby tracker comes with the Cycle or Wellness plan:\nfeeds, sleep, diapers, growth and milestones."
        case .bodyEnergy: "The body & energy log comes with the Cycle or Wellness plan:\nyour energy, pain and rest days."
        case .aiUnlimited: "Unlimited faith guidance"
        case .liveRooms: "Hosting live rooms and group walks\ncomes with every plan. Joining is free."
        case .habitTemplates: "Custom habit circles come with Complete."
        case .journalHistory: "Your older entries are safe.\nEvery plan opens your whole journal."
        case .createGroup: "Groups, duels, circles and posting on the prayer wall\ncome with any plan."
        case .church: "Your church comes with Complete,\nor a seat on your church's own plan."
        case .freedomShield: "Freedom Shield, real app and website blocking\nwith a partner's code, comes with Complete."
        case .spiritStress: "See how prayer days compare for stress and mood\nwith the Faith or Wellness plan."
        case .faithCoach: "Your private faith coach on this iPhone\nis part of the Faith plan."
        }
    }
    /// Which plan the paywall points at (null = Complete).
    var suggestedPlan: Plan? {
        switch self {
        case .spiritStress: .faith
        case .bibleJourneys, .versesPremium, .sanctuaryFull, .bibleAudio, .devotionalPlans, .familyRelay, .prayerWalkMap, .hymns, .bibleNotes, .faithCoach: .faith
        case .adaptiveCoach, .formCoach, .walkPlus, .walkAiCheck, .realStakes: .fitness
        case .cycleInsights, .partnerCoaching: .cycle
        case .mensHealth: .wellness
        case .wearableInsights, .trends, .babyTracker, .bodyEnergy: nil
        default: nil
        }
    }
}

/// The plan fields of /users/{uid}.
struct AccountDoc: Equatable {
    var isPremium = false, adminGrantedPremium = false
    var redeemedLicenseCode = ""
    var subscriptionTier = 0
    var premiumExpiresAt: Int64 = 0, playExpiresAt: Int64 = 0
    var faithEndsAt: Int64 = 0, fitnessEndsAt: Int64 = 0, cycleEndsAt: Int64 = 0, wellnessEndsAt: Int64 = 0
    var trialUsedAt: Int64 = 0
    var banned = false

    func endsAt(_ p: Plan) -> Int64 {
        switch p { case .faith: faithEndsAt; case .fitness: fitnessEndsAt; case .cycle: cycleEndsAt; case .wellness: wellnessEndsAt }
    }
    /// WebStore.runningTier: the older tier this account uses now (license, grant or older Play subscription), or 0.
    func runningTier(now: Int64) -> Int {
        let tier = (1...7).contains(subscriptionTier) ? subscriptionTier : 7
        let lifetime = isPremium && adminGrantedPremium && premiumExpiresAt == 0
        let term = isPremium && !redeemedLicenseCode.isEmpty && premiumExpiresAt > now
        if lifetime || term { return tier }
        if isPremium && !adminGrantedPremium && playExpiresAt > now { return tier }
        return 0
    }
    func running(now: Int64) -> Set<Plan> { Set(Plan.allCases.filter { endsAt($0) > now }) }
}

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published private(set) var uid: String? = UserDefaults.standard.string(forKey: "accountUid")
    @Published private(set) var doc: AccountDoc?
    @Published private(set) var status = ""
    private var idToken: String?
    private var idTokenExpires = Date.distantPast
    private let session = URLSession(configuration: .ephemeral)

    var configured: Bool { FirebaseConfig.isConfigured }
    var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    // MARK: What this person can use

    func canUse(_ f: Feature) -> Bool {
        guard configured else { return true }          // no Firebase file: a development build, everything open
        if f.freeLikeBibleApps { return true }
        guard let doc else { return false }
        if doc.runningTier(now: now) >= f.minTier { return true }
        let running = doc.running(now: now)
        return f.needsAll ? running.isSuperset(of: Plan.allCases) : !f.plans.isDisjoint(with: running)
    }

    var runningPlans: Set<Plan> { doc?.running(now: now) ?? [] }
    var hasAnyPlan: Bool { (doc?.runningTier(now: now) ?? 0) > 0 || !runningPlans.isEmpty }
    var trialOpen: Bool { configured && doc != nil && (doc?.trialUsedAt ?? 0) == 0 && !hasAnyPlan }

    var planName: String {
        guard configured else { return "Development build" }
        let running = runningPlans
        if running.isSuperset(of: Plan.allCases) { return "Complete" }
        if !running.isEmpty { return Plan.allCases.filter { running.contains($0) }.map(\.name).joined(separator: " + ") }
        let tier = doc?.runningTier(now: now) ?? 0
        if tier > 0 { return ["Basic", "Plus", "Faith", "Fit", "Wellness", "Family", "Maximum"][tier - 1] }
        return "Free"
    }

    /// The latest end date among the running plans (for "Renews or ends on …").
    var latestEnd: Date? {
        guard let doc else { return nil }
        let ends = Plan.allCases.map { doc.endsAt($0) }.filter { $0 > now }
        return ends.max().map { Date(timeIntervalSince1970: Double($0) / 1000) }
    }

    // MARK: Sign-in (anonymous, like Android)

    func start() async {
        guard configured else { return }
        if Keychain.get("refreshToken") == nil { await signUp() }
        await refreshAccount()
    }

    private func endpoint(_ base: String) -> URL? {
        guard let key = FirebaseConfig.apiKey else { return nil }
        return URL(string: "\(base)?key=\(key)")
    }

    private func request(_ url: URL, json: [String: Any]? = nil, form: String? = nil, token: String? = nil, method: String = "POST") -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 20
        r.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        if let json { r.httpBody = try? JSONSerialization.data(withJSONObject: json); r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let form { r.httpBody = form.data(using: .utf8); r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return r
    }

    private func signUp() async {
        guard let url = endpoint("https://identitytoolkit.googleapis.com/v1/accounts:signUp") else { return }
        guard let (data, resp) = try? await session.data(for: request(url, json: ["returnSecureToken": true])),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = j["idToken"] as? String, let refresh = j["refreshToken"] as? String, let local = j["localId"] as? String else {
            status = tr("Couldn't connect — check your internet connection."); return
        }
        Keychain.set(refresh, for: "refreshToken")
        setToken(id, expiresIn: j["expiresIn"] as? String)
        uid = local
        UserDefaults.standard.set(local, forKey: "accountUid")
        status = ""
    }

    private func setToken(_ t: String, expiresIn: String?) {
        idToken = t
        idTokenExpires = Date().addingTimeInterval((Double(expiresIn ?? "3600") ?? 3600) - 120)
    }

    /// A fresh ID token for HolySteps' server and Firestore (refreshed a couple of minutes before it runs out).
    func token(force: Bool = false) async -> String? {
        if !force, let idToken, Date() < idTokenExpires { return idToken }
        guard let refresh = Keychain.get("refreshToken"),
              let url = endpoint("https://securetoken.googleapis.com/v1/token") else { return nil }
        let form = "grant_type=refresh_token&refresh_token=\(refresh.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? refresh)"
        guard let (data, resp) = try? await session.data(for: request(url, form: form)),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if (resp as? HTTPURLResponse)?.statusCode != 200 {
            // The account was removed (for example a deletion request): start a fresh one.
            if (resp as? HTTPURLResponse)?.statusCode == 400 { Keychain.set(nil, for: "refreshToken"); await signUp(); return idToken }
            return nil
        }
        if let id = j["id_token"] as? String { setToken(id, expiresIn: j["expires_in"] as? String) }
        if let r = j["refresh_token"] as? String { Keychain.set(r, for: "refreshToken") }
        if let u = j["user_id"] as? String, u != uid { uid = u; UserDefaults.standard.set(u, forKey: "accountUid") }
        return idToken
    }

    /// Reads /users/{uid} from Firestore (only this account can read its own document).
    func refreshAccount() async {
        guard configured, let project = FirebaseConfig.projectId, let uid, let tok = await token(),
              let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/users/\(uid)") else { return }
        guard let (data, resp) = try? await session.data(for: request(url, token: tok, method: "GET")) else { return }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { doc = AccountDoc(); return }
        guard code == 200, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let f = j["fields"] as? [String: [String: Any]] else { return }
        func int(_ k: String) -> Int64 {
            if let s = f[k]?["integerValue"] as? String { return Int64(s) ?? 0 }
            if let d = f[k]?["doubleValue"] as? Double { return Int64(d) }
            return 0
        }
        func bool(_ k: String) -> Bool { f[k]?["booleanValue"] as? Bool ?? false }
        func str(_ k: String) -> String { f[k]?["stringValue"] as? String ?? "" }
        doc = AccountDoc(isPremium: bool("isPremium"), adminGrantedPremium: bool("adminGrantedPremium"), redeemedLicenseCode: str("redeemedLicenseCode"),
                         subscriptionTier: Int(int("subscriptionTier")), premiumExpiresAt: int("premiumExpiresAt"), playExpiresAt: int("playExpiresAt"),
                         faithEndsAt: int("faithEndsAt"), fitnessEndsAt: int("fitnessEndsAt"), cycleEndsAt: int("cycleEndsAt"),
                         wellnessEndsAt: int("wellnessEndsAt"), trialUsedAt: int("trialUsedAt"), banned: bool("banned"))
        scheduleEndingNotice()
    }

    /// "If a plan is going to end, we tell you three days before": one local reminder, three days before the latest end.
    private func scheduleEndingNotice() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["planEnding"])
        guard let end = latestEnd else { return }
        let when = end.addingTimeInterval(-3 * 86400)
        guard when > Date() else { return }
        let n = UNMutableNotificationContent()
        n.title = tr("Your plan ends in 3 days")
        n.body = tr("It ends on") + " " + end.formatted(date: .long, time: .omitted) + ". " + tr("Renew or manage it on holysteps.org.")
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when)
        c.add(UNNotificationRequest(identifier: "planEnding", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    // MARK: HolySteps' own server (holysteps.org/holysteps/api)

    static let site = "https://holysteps.org"

    struct Reply { let status: Int; let json: [String: Any] }

    private func post(_ path: String, _ body: [String: Any]) async -> Reply? {
        for attempt in 0..<2 {
            guard let tok = await token(force: attempt == 1), let url = URL(string: Self.site + path) else { return nil }
            guard let (data, resp) = try? await session.data(for: request(url, json: body, token: tok)) else { return nil }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 && attempt == 0 { continue }
            return Reply(status: code, json: (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:])
        }
        return nil
    }

    /// The address to pay on, tied to this account so the plan switches on here by itself (WebCheckout.start).
    func checkoutURL(planId: String, gift: Bool = false) async -> (URL, String?) {
        let plain = URL(string: "\(Self.site)/?plan=\(planId)&mode=faith\(gift ? "&gift=1" : "")#pricing")!
        guard configured else { return (plain, nil) }
        guard let r = await post("/holysteps/api/checkout/link", ["planId": planId, "mode": "faith", "gift": gift]) else {
            return (plain, tr("Couldn't reach HolySteps, so your code will come by email."))
        }
        if (200..<300).contains(r.status), let s = r.json["url"] as? String, let u = URL(string: s), u.scheme == "https", u.host == "holysteps.org" {
            return (u, nil)
        }
        return (plain, (r.json["error"] as? String) ?? tr("Your code will come by email."))
    }

    /// A stable, private id for this phone (so a free week is given once per phone), never the raw identifier.
    private var deviceHash: String {
        let raw = (UIDevice.current.identifierForVendor?.uuidString ?? uid ?? "") + "holysteps"
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func startTrial() async -> String? {
        guard let r = await post("/holysteps/api/trial/start", ["device": deviceHash]) else { return tr("Couldn't reach HolySteps. Try again in a moment.") }
        if (200..<300).contains(r.status) { await refreshAccount(); return nil }
        return (r.json["error"] as? String) ?? tr("Your free week isn't available.")
    }

    /// Redeems a license key (POST /holysteps/api/license/redeem). Nil on success, otherwise why not.
    func redeem(_ code: String) async -> String? {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return tr("Enter your code.") }
        guard let r = await post("/holysteps/api/license/redeem", ["code": clean]) else { return tr("You're offline. Connect and try again.") }
        if (200..<300).contains(r.status), r.json["applied"] as? Bool == true { await refreshAccount(); return nil }
        switch r.json["reason"] as? String ?? "" {
        case "not_found": return tr("That code wasn't found. Check it and try again.")
        case "used_up", "full": return tr("That code has been used as many times as it allows.")
        case "expired": return tr("That code has expired.")
        case "revoked": return tr("That code is no longer valid.")
        default: return (r.json["error"] as? String) ?? tr("Couldn't redeem right now. Try again in a moment.")
        }
    }
}

/// The website's price list (/api/holysteps/plans), with the store's own prices until it answers.
struct StoreItem: Identifiable, Decodable {
    let id: String
    let kind: String
    let name: String
    let plans: [String]
    let seats: Int
    let period: String
    let price: Double
    let listPrice: Double
    let percentOff: Double
    var priceText: String { String(format: "$%.2f", price) }
    var per: String { period == "month" ? tr("/month") : period == "year" ? tr("/year") : tr(" for 2 years") }
}

@MainActor
final class StorePrices: ObservableObject {
    static let shared = StorePrices()
    @Published private(set) var items: [StoreItem] = StorePrices.defaults

    static let defaults: [StoreItem] = {
        func s(_ id: String, _ kind: String, _ name: String, _ plans: [String], _ period: String, _ price: Double, _ seats: Int = 1) -> StoreItem {
            StoreItem(id: id, kind: kind, name: name, plans: plans, seats: seats, period: period, price: price, listPrice: price, percentOff: 0)
        }
        let all = ["faith", "fitness", "cycle", "wellness"]
        let single: [String: (Double, Double)] = ["faith": (10, 60), "fitness": (10, 60), "cycle": (10, 30), "wellness": (10, 35)]
        return all.flatMap { p in [s("\(p)_monthly", "plan", Plan(rawValue: p)!.name, [p], "month", single[p]!.0),
                                   s("\(p)_yearly", "plan", Plan(rawValue: p)!.name, [p], "year", single[p]!.1)] } + [
            s("complete_monthly", "complete", "Complete", all, "month", 15), s("complete_yearly", "complete", "Complete", all, "year", 100),
            s("complete_2yr", "complete", "Complete", all, "2years", 180),
            s("couple_yearly", "family", "Couple", ["faith", "cycle", "wellness"], "year", 89.99, 2), s("family_yearly", "family", "Family", all, "year", 140, 6),
        ]
    }()

    func item(_ id: String) -> StoreItem? { items.first { $0.id == id } }

    func refresh() async {
        guard let url = URL(string: "https://holysteps.org/api/holysteps/plans"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        struct Wrap: Decodable { let plans: [StoreItem] }
        if let w = try? JSONDecoder().decode(Wrap.self, from: data), !w.plans.isEmpty { items = w.plans }
    }
}
