import Foundation

// Android's Daily Coach (data/DailyCoach.kt). The workout library and the Scripture focus per energy zone are
// extracted to Resources/coach.json (tools/coach_dump.kt, compiled from the Android source), the men's weekly pools
// to Resources/mens.json; the rules below are ported line by line.

struct RoutineStep: Decodable, Hashable {
    let name: String
    let seconds: Int
    let cue: String
    let rest: Bool
    /// The trainer clip key when it's known (program workouts); otherwise it's matched from the name.
    var move: String? = nil

    /// The trainer clip for this step: rests show the calm breath.
    var trainerKey: String? { rest ? "BELLY_BREATH" : (move ?? TrainerClips.key(step: name, rest: false)).map { TrainerClips.sided($0, step: name) } }
    /// A right-side step of a move recorded on the left only plays mirrored.
    var trainerMirrored: Bool { !rest && trainerKey.map { TrainerClips.mirrored(step: name, key: $0) } == true }
}

struct GuidedRoutine: Decodable, Identifiable, Hashable {
    let id, title, kind, summary, equipment, caution, venue: String
    let zones: [String]
    let externalRoute: String?
    let nominalMinutes: Int
    let steps: [RoutineStep]

    var minutes: Int { steps.isEmpty ? nominalMinutes : max(1, (steps.reduce(0) { $0 + $1.seconds } + 30) / 60) }
    func fits(_ z: EnergyZone) -> Bool { zones.contains(z.key) }
    var kindLabel: String {
        ["HIIT": "HIIT", "STRENGTH": "Strength", "CARDIO": "Cardio", "CORE": "Core", "YOGA": "Yoga", "MOBILITY": "Mobility",
         "BALANCE": "Balance", "WALK": "Walk", "RESTORE": "Restore"][kind] ?? kind
    }
    var symbol: String {
        ["HIIT": "flame", "STRENGTH": "dumbbell", "CARDIO": "figure.run", "CORE": "scope", "YOGA": "figure.yoga", "MOBILITY": "figure.flexibility",
         "BALANCE": "figure.stand", "WALK": "figure.walk", "RESTORE": "moon"][kind] ?? "figure.walk"
    }

    // Spoken coaching (getReadyCue / spokenDuration / stepAnnouncement)
    var getReady: String { "Get ready. First up: \(steps.first?.name ?? "")." }
    static let tenSeconds = "Ten seconds."
    static let done = "Workout complete. Well done."
    static func spoken(_ seconds: Int) -> String {
        if seconds == 60 { return "1 minute" }
        if seconds >= 120 && seconds % 60 == 0 { return "\(seconds / 60) minutes" }
        if seconds >= 150 && seconds % 60 == 30 { return "\(seconds / 60) and a half minutes" }
        return "\(seconds) seconds"
    }
    func announcement(_ i: Int) -> String {
        let s = steps[i]
        let next = steps.dropFirst(i + 1).first { !$0.rest }
        if s.rest { return "Rest. \(Self.spoken(s.seconds)).\(next.map { " Next up: \($0.name)." } ?? "")" }
        return "\(s.name). \(Self.spoken(s.seconds)). \(s.cue)"
    }
    var packId: String { "c_\(id)" }
}

struct DevotionalFocus: Decodable, Hashable {
    let id, theme, reference, verse, reflection, prayer: String
}

extension EnergyZone {
    var key: String { switch self { case .recover: "RECOVER"; case .low: "LOW"; case .steady: "STEADY"; case .high: "HIGH" } }
    var headline: String {
        switch self {
        case .recover: "Today is for recovery, rest is part of the plan, not a break from it."
        case .low: "Go gentle today, restorative movement and grounding Scripture."
        case .steady: "A steady day, consistent, moderate effort is the win."
        case .high: "High-energy day, go bold in body and in faith."
        }
    }
    var colorHex: UInt32 { switch self { case .recover: 0xEC4899; case .low: 0x8B5CF6; case .steady: 0x3B82F6; case .high: 0x10B981 } }
    var down: EnergyZone { EnergyZone(rawValue: rawValue - 1) ?? self }
    var up: EnergyZone { EnergyZone(rawValue: rawValue + 1) ?? self }
}

/// Android's DailyCheckIn: mood, energy, clarity and peace from 1 to 5, and last night's sleep.
struct CheckIn: Codable, Equatable {
    var date: String
    var mood: Int, energy: Int, clarity: Int, peace: Int
    var sleep: String
}

final class CheckInStore: ObservableObject {
    static let shared = CheckInStore()
    @Published private(set) var all: [CheckIn] {
        didSet { if let d = try? JSONEncoder().encode(all) { UserDefaults.standard.set(d, forKey: "checkIns") } }
    }
    private init() {
        all = (UserDefaults.standard.data(forKey: "checkIns")).flatMap { try? JSONDecoder().decode([CheckIn].self, from: $0) } ?? []
    }
    var today: CheckIn? { all.last { $0.date == AppStore.dayKey() } }
    func save(_ c: CheckIn) {
        all.removeAll { $0.date == c.date }
        all.append(c)
        all = Array(all.suffix(120))
        ActivityLog.shared.add(.tracker)
    }
    func erase() { all = [] }
}

/// Workouts finished, by day and kind (Android's coachLog), so two hard days don't stack.
final class CoachLog: ObservableObject {
    static let shared = CoachLog()
    @Published private(set) var days: [String: String] { didSet { UserDefaults.standard.set(days, forKey: "coachLog") } }
    private init() { days = UserDefaults.standard.dictionary(forKey: "coachLog") as? [String: String] ?? [:] }
    func finished(_ r: GuidedRoutine) { days[AppStore.dayKey()] = r.kind; ActivityLog.shared.add(.walk) }
    var workedOutToday: Bool { days[AppStore.dayKey()] != nil }
    var yesterdayKind: String? { days[AppStore.dayKey(Date().addingTimeInterval(-86_400))] }
    func erase() { days = [:] }
}

enum Coach {
    private struct Library: Decodable { let routines: [GuidedRoutine]; let devotionals: [String: [DevotionalFocus]] }
    private static let library: Library? = {
        guard let url = Bundle.main.url(forResource: "coach", withExtension: "json"), let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Library.self, from: d)
    }()
    static var routines: [GuidedRoutine] { library?.routines ?? [] }
    static func routine(_ id: String) -> GuidedRoutine? { routines.first { $0.id == id } }

    struct MensPools: Decodable { let move, nourish, mindset: [String] }
    static let mens: [String: MensPools] = {
        guard let url = Bundle.main.url(forResource: "mens", withExtension: "json"), let d = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: MensPools].self, from: d)) ?? [:]
    }()

    struct Plan {
        let zone: EnergyZone
        let reasons: [String]
        let routine: GuidedRoutine?
        let gentler: GuidedRoutine?
        let stronger: GuidedRoutine?
        let devotional: DevotionalFocus?
        let nourish: String
        let needsCheckIn: Bool
        var stepMultiplier: Double { zone.stepMultiplier }
    }

    private static let pain = ["Cramps", "Headache", "Nausea", "Back pain", "Pelvic pain", "Racing heart"]
    private static let tired = ["Tired", "Fatigue", "Poor sleep", "Night sweats", "Hot flashes", "Joint aches", "Brain fog"]

    /// adjustedZone: today's check-in and logged symptoms on top of the rhythm.
    static func adjusted(_ base: EnergyZone, checkIn c: CheckIn?, symptoms: Set<String>) -> (EnergyZone, [String]) {
        var zone = base
        var reasons: [String] = []
        if let c {
            switch c.energy {
            case 1: zone = .recover; reasons.append("You checked in at energy 1/5, today is about recovery.")
            case 2: if zone.rawValue > EnergyZone.low.rawValue { zone = .low; reasons.append("Energy 2/5, your plan is gentler than your rhythm alone suggests.") }
            case 3: if zone.rawValue > EnergyZone.steady.rawValue { zone = .steady; reasons.append("Energy 3/5, steady beats all-out today.") }
            case 5: if zone != .high { zone = zone.up; reasons.append("Energy 5/5, we've turned it up a notch.") }
            default: break
            }
            if c.sleep == "poor" && zone.rawValue > EnergyZone.steady.rawValue { zone = .steady; reasons.append("Poor sleep logged, recovery beats intensity today.") }
            if c.mood <= 2 && zone.rawValue > EnergyZone.steady.rawValue { zone = .steady; reasons.append("Low mood today, moderate movement lifts mood without draining you.") }
        }
        if let s = symptoms.first(where: { sym in pain.contains { sym.contains($0) } }), zone.rawValue > EnergyZone.low.rawValue {
            zone = .low; reasons.append("\(Emoji.strip(s).trimmingCharacters(in: .whitespaces)) logged, swapped to gentler movement.")
        }
        if let s = symptoms.first(where: { sym in tired.contains { sym.contains($0) } }), zone.rawValue > EnergyZone.steady.rawValue {
            zone = .steady; reasons.append("\(Emoji.strip(s).trimmingCharacters(in: .whitespaces)) logged, capped at a steady effort.")
        }
        return (zone, reasons)
    }

    static func candidates(_ zone: EnergyZone, menstrual: Bool) -> [GuidedRoutine] {
        let ids: [String]
        switch zone {
        case .high: ids = ["hiit_power", "strength_builder", "tempo_intervals"]
        case .steady: ids = ["strength_builder", "steady_strength", "pilates_core", "brisk_prayer_walk"]
        case .low: ids = menstrual ? ["cramp_relief", "gentle_yoga", "easy_walk"] : ["gentle_yoga", "mobility_reset", "pilates_core", "easy_walk"]
        case .recover: ids = menstrual ? ["cramp_relief", "restorative_stretch", "easy_walk"] : ["restorative_stretch", "gentle_yoga", "easy_walk"]
        }
        return ids.compactMap(routine)
    }

    static func plan(store: AppStore, checkIn: CheckIn? = CheckInStore.shared.today, symptoms: Set<String> = CycleLog.shared.today,
                     yesterdayKind: String? = CoachLog.shared.yesterdayKind, seed: Int = PhasePlan.epochDay) -> Plan {
        let rhythm = Rhythm(store: store)
        let (base, rhythmReason) = rhythm.zone
        let (zone, adjust) = adjusted(base, checkIn: checkIn, symptoms: symptoms)
        let menstrual = !rhythm.male && rhythm.phase == .menstrual
        let cands = candidates(zone, menstrual: menstrual)
        let rotated = PhasePlan.rotation(cands.map(\.id), cands.count, seed).compactMap(routine)
        let avoid = (yesterdayKind == "HIIT" || yesterdayKind == "STRENGTH") ? yesterdayKind : nil
        let picked = rotated.first { $0.kind != avoid } ?? rotated.first
        let gentler = zone.down != zone ? candidates(zone.down, menstrual: menstrual).first { $0.id != picked?.id } : nil
        let stronger = zone.up != zone ? candidates(zone.up, menstrual: menstrual).first { $0.id != picked?.id } : nil
        let pool = library?.devotionals[zone.key] ?? []
        let devotional = pool.isEmpty ? nil : pool[((seed % pool.count) + pool.count) % pool.count]
        var reasons = [rhythmReason] + adjust
        if checkIn == nil { reasons.append("Check in (10 seconds) and today's plan adapts to how you actually feel.") }
        let nourish: String
        if rhythm.male, let p = mens[rhythm.mens.rawValue] { nourish = PhasePlan.rotation(p.nourish, 1, seed).first ?? "" }
        else if let phase = rhythm.phase, let p = PhasePlan.forPhase(phase, seed: seed) { nourish = p.mealIdea }
        else {
            nourish = switch zone {
            case .high: "Fuel the effort: protein and slow carbs a couple of hours before you train."
            case .steady: "Protein at every meal and plenty of water keep a steady day steady."
            case .low: "Warm, simple food today, soup, eggs, oats. Be kind to your body."
            case .recover: "Hydrate, eat something nourishing, and don't skip meals on a recovery day."
            }
        }
        return Plan(zone: zone, reasons: reasons, routine: picked, gentler: gentler, stronger: stronger, devotional: devotional,
                    nourish: nourish, needsCheckIn: checkIn == nil)
    }
}
