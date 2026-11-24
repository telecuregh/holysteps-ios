import Foundation

// Ported from Android's data/AppState.kt (CyclePhase, MensPhase, computeDailyScore) and data/DailyCoach.kt (EnergyZone,
// baseZone). The full Daily Coach (routines, check-in adjustments, pacing) comes with the health phase; until then the
// day's energy is the rhythm's base zone, as Android shows it before any check-in.

enum CyclePhase: String {
    case menstrual, follicular, ovulation, luteal
    var label: String {
        switch self { case .menstrual: "Menstrual"; case .follicular: "Follicular"; case .ovulation: "Ovulation"; case .luteal: "Luteal" }
    }
    var emoji: String { switch self { case .menstrual: "🌹"; case .follicular: "🌱"; case .ovulation: "✨"; case .luteal: "🌙" } }
    var colorHex: UInt32 { switch self { case .menstrual: 0xF43F5E; case .follicular: 0x10B981; case .ovulation: 0xF59E0B; case .luteal: 0x8B5CF6 } }

    /// Ovulation is anchored about 14 days before the next period (cyclePhaseFor).
    static func forDay(_ day: Int, periodLength: Int, cycleLength: Int) -> CyclePhase {
        let ov = max(cycleLength - 14, periodLength + 2)
        if day <= periodLength { return .menstrual }
        if day < ov - 1 { return .follicular }
        if day <= ov + 1 { return .ovulation }
        return .luteal
    }
}

enum MensPhase: String {
    case peak, build, rest, reset
    var label: String { switch self { case .peak: "Peak Drive"; case .build: "Build Mode"; case .rest: "Active Rest"; case .reset: "Reset Day" } }
    var emoji: String { switch self { case .peak: "⚡"; case .build: "💪"; case .rest: "🌙"; case .reset: "🔄" } }
    var tip: String {
        switch self {
        case .peak: "Push day in your week: go hard on steps, heavy workouts and your biggest tasks."
        case .build: "Great energy for consistency. Build your step streak and repeat yesterday's habits."
        case .rest: "Recovery time. Focus on gentle walks, mobility work, and good sleep."
        case .reset: "Full reset. Prioritize sleep, time with people you love, and planning the week."
        }
    }
    /// Monday and Tuesday push, Wednesday and Thursday build, Friday rests, the weekend resets.
    static func today(_ date: Date = Date()) -> MensPhase {
        switch Calendar(identifier: .gregorian).component(.weekday, from: date) {
        case 2, 3: .peak
        case 4, 5: .build
        case 6: .rest
        default: .reset
        }
    }
}

enum EnergyZone: Int {
    case recover, low, steady, high
    var label: String { switch self { case .recover: "Rest & restore"; case .low: "Gentle day"; case .steady: "Steady day"; case .high: "High-energy day" } }
    var stepMultiplier: Double { switch self { case .high: 1.15; case .steady: 1.0; case .low: 0.8; case .recover: 0.6 } }
}

struct Rhythm {
    let male: Bool
    let cycleDay: Int?
    let cycleLength: Int
    let phase: CyclePhase?
    let mens: MensPhase

    init(store: AppStore, date: Date = Date()) {
        male = store.gender == "male"
        cycleLength = store.cycleLength
        mens = MensPhase.today(date)
        if let last = store.periodStarts.max() {
            let d = CycleLogic.cycleDay(lastStart: last, length: cycleLength, today: date)
            cycleDay = d
            phase = CyclePhase.forDay(d, periodLength: store.periodLength, cycleLength: cycleLength)
        } else { cycleDay = nil; phase = nil }
    }

    /// DailyCoach.kt baseZone: the energy the rhythm calls for today, and the reason.
    var zone: (zone: EnergyZone, reason: String) {
        if male {
            let z: EnergyZone = switch mens { case .peak: .high; case .build: .steady; case .rest: .low; case .reset: .recover }
            return (z, "\(mens.emoji) \(mens.label) — \(mens.tip)")
        }
        guard let phase, let day = cycleDay else {
            return (.steady, "🌸 Log your last period and this plan syncs to your cycle. Until then, a steady day.")
        }
        let left = cycleLength - day + 1
        switch phase {
        case .menstrual:
            return day <= 2 ? (.recover, "🌹 Period day \(day): hormones are at their lowest. Gentle movement and heat can ease cramps.")
                : (.low, "🌹 Period day \(day): energy is usually still building back — keep it gentle.")
        case .follicular: return (.high, "🌱 Follicular phase (day \(day)): rising estrogen, and many women feel more energetic.")
        case .ovulation: return (.high, "✨ Around ovulation (day \(day)): many women feel their strongest this week.")
        case .luteal:
            if left <= 0 { return (.low, "🌙 Your period is due: energy often dips around now, so gentler training usually feels better.") }
            if left <= 5 { return (.low, "🌙 Late luteal (\(left) day\(left == 1 ? "" : "s") before your period): energy often dips — gentler training usually feels better.") }
            return (.steady, "🌙 Luteal phase (day \(day)): progesterone is up, and many find steady, moderate effort feels best.")
        }
    }

    /// Android computeDailyScore: spiritual 40 %, physical 35 %, rhythm 25 %.
    static func dailyScore(prayers: [Bool], devotional: Bool, journaled: Bool, steps: Int, stepGoal: Int, zone: EnergyZone, checkedIn: Bool) -> Int {
        var spiritual = Int(Double(prayers.filter { $0 }.count) / Double(max(prayers.count, 1)) * 55)
        if devotional { spiritual += 25 }
        if journaled { spiritual += 20 }
        spiritual = min(100, spiritual)
        let goal = max(1, Double(stepGoal) * zone.stepMultiplier)
        let physical = min(100, max(0, Int(Double(steps) / goal * 100)))
        let rhythm = checkedIn ? 90 : 40
        return min(100, max(0, Int(Double(spiritual) * 0.40 + Double(physical) * 0.35 + Double(rhythm) * 0.25)))
    }
}
