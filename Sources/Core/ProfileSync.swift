import Foundation

/// Android's upsertPublicProfile: the account's own profile on the server (users/{uid}: name, prayer streak, steps,
/// when it was last used and the app version) and the only part other people can read (publicProfiles/{uid}: name and
/// duel rating). The admin console lists people from users/{uid}, so this is how it knows an iPhone account's name.
/// Only the fields firestore.rules lets the app write; plans and everything the server owns are left untouched.
@MainActor
enum ProfileSync {
    private static var running = false

    /// At most every few hours, unless the name just changed.
    static func run(store: AppStore, force: Bool = false) async {
        let d = UserDefaults.standard
        let last = d.double(forKey: "profileSyncAt")
        let name = store.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || Date().timeIntervalSince1970 - last > 3 * 3600 || d.string(forKey: "profileSyncName") != name, !running else { return }
        running = true
        defer { running = false }
        guard let uid = await AccountStore.shared.ensureUid() else { return }
        let pub = try? await Firestore.get("publicProfiles/\(uid)")
        let serverName = (pub?["displayName"].string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // The name typed in the app; else the account's existing name (a fresh install has none saved yet); else a tag
        // from the account id, as Android does.
        var shown = name.isEmpty ? serverName : name
        if shown.isEmpty {
            let tag = String(uid.filter { $0.isLetter || $0.isNumber }.suffix(4)).uppercased()
            shown = "Believer" + (tag.isEmpty ? String(Int.random(in: 1000...9999)) : tag)
        }
        shown = String(shown.prefix(100))
        let version = "iOS " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        let fields: [String: FSValue] = [
            "displayName": .string(shown),
            "prayerStreak": .int(Int64(min(100_000, max(0, store.prayerStreak)))),
            "weeklySteps": .int(Int64(min(1_000_000_000, max(0, StepsModel.shared.week.reduce(0) { $0 + $1.steps })))),
            "lastActiveAt": .int(Firestore.nowMs),
            "appVersion": .string(String(version.prefix(32))),
        ]
        do { try await Firestore.commit([.merge("users/\(uid)", fields)]) } catch { return }
        // The rating stays as the server has it (it can only move by one duel's worth per write).
        let rating = pub.map { $0["duelRating"].int } ?? Int64(min(3000, max(100, d.integer(forKey: "duelRating") == 0 ? 1000 : d.integer(forKey: "duelRating"))))
        try? await Firestore.commit([.merge("publicProfiles/\(uid)", ["displayName": .string(shown), "duelRating": .int(rating)])])
        d.set(Date().timeIntervalSince1970, forKey: "profileSyncAt")
        d.set(name, forKey: "profileSyncName")
    }
}
