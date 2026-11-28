import Foundation
import Combine

/// Tracks lightweight engagement counts used for progressive feature disclosure.
/// Rules (matches the strategy in PlansView / CycleView):
///   - Circles card visible after 5 mood checks
///   - Severity card visible after 3 period logs
///   - Partner coaching card visible after 7 period logs
/// All counts are stored on-device in UserDefaults.
@MainActor
final class EngagementStore: ObservableObject {
    static let shared = EngagementStore()

    // Keys
    private enum Key {
        static let moodChecks   = "eng_moodCheckCount"
        static let periodLogs   = "eng_periodLogCount"
        static let audioPlays   = "eng_audioPlayCount"
        static let appOpens     = "eng_appOpenCount"
    }

    // MARK: Counts

    @Published private(set) var moodCheckCount: Int
    @Published private(set) var periodLogCount:  Int
    @Published private(set) var audioPlayCount:  Int

    init() {
        let ud = UserDefaults.standard
        moodCheckCount = ud.integer(forKey: Key.moodChecks)
        periodLogCount  = ud.integer(forKey: Key.periodLogs)
        audioPlayCount  = ud.integer(forKey: Key.audioPlays)
        // bump app-open counter
        let opens = ud.integer(forKey: Key.appOpens) + 1
        ud.set(opens, forKey: Key.appOpens)
    }

    // MARK: Incrementors — call from the relevant views

    func recordMoodCheck() {
        moodCheckCount += 1
        UserDefaults.standard.set(moodCheckCount, forKey: Key.moodChecks)
    }

    func recordPeriodLog() {
        periodLogCount += 1
        UserDefaults.standard.set(periodLogCount, forKey: Key.periodLogs)
    }

    func recordAudioPlay() {
        audioPlayCount += 1
        UserDefaults.standard.set(audioPlayCount, forKey: Key.audioPlays)
    }

    // MARK: Unlock gates (progressive disclosure)

    /// Show Cycle Circles entry after 5 mood check-ins.
    var circlesUnlocked: Bool { moodCheckCount >= 5 }

    /// Show Symptom Severity card right away (it's also behind the plan gate itself).
    var severityUnlocked: Bool { periodLogCount >= 3 }

    /// Show Partner Coaching card after 7 period logs (they're invested).
    var partnerCoachingUnlocked: Bool { periodLogCount >= 7 }

    /// Show Skin Journal after 10 period logs.
    var skinJournalUnlocked: Bool { periodLogCount >= 10 }

    // MARK: Persona (opening intent set during onboarding)

    enum Persona: String {
        case cycle, mensHealth, faith, fitness, unset
    }

    static var persona: Persona {
        Persona(rawValue: UserDefaults.standard.string(forKey: "hsPersona") ?? "") ?? .unset
    }

    static func setPersona(_ p: Persona) {
        UserDefaults.standard.set(p.rawValue, forKey: "hsPersona")
    }

    /// Everything picked in "What brings you here?", in the order chosen (several are allowed).
    static var personas: [Persona] {
        let saved = (UserDefaults.standard.string(forKey: "hsPersonas") ?? "").split(separator: ",").compactMap { Persona(rawValue: String($0)) }
        return saved.isEmpty ? (persona == .unset ? [] : [persona]) : saved
    }

    /// Saves every pick; the first one is the persona that decides the opening tab.
    static func setPersonas(_ list: [Persona]) {
        let clean = list.filter { $0 != .unset }
        UserDefaults.standard.set(clean.map(\.rawValue).joined(separator: ","), forKey: "hsPersonas")
        setPersona(clean.first ?? .unset)
    }

    /// The tab index to open first based on persona (matches RootTabView tab order).
    static var openingTabIndex: Int {
        switch persona {
        // RootTabView order: 0 Home, 1 Faith, 2 Fitness, 3 Women/Men, 4 Profile
        case .cycle, .mensHealth: return 3   // Women / Men tab (gender-routed)
        case .fitness:            return 2   // Fitness tab
        case .faith:              return 1   // Faith tab
        case .unset:              return 0   // Home
        }
    }
}
