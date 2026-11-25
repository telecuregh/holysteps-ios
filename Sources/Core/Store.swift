import Foundation
import SwiftUI

struct PrayerItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var created = Date()
    var answered = false
    /// The prayer garden (Android PrayerRequest): who it's for, the different days it was prayed, and its bed.
    var forWhom = ""
    var daysPrayed = 0
    var lastPrayedDay = ""
    var testimony = ""
    var bed = 0

    init(text: String, forWhom: String = "", bed: Int = 0) { self.text = text; self.forWhom = forWhom; self.bed = bed }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        answered = try c.decodeIfPresent(Bool.self, forKey: .answered) ?? false
        forWhom = try c.decodeIfPresent(String.self, forKey: .forWhom) ?? ""
        daysPrayed = try c.decodeIfPresent(Int.self, forKey: .daysPrayed) ?? 0
        lastPrayedDay = try c.decodeIfPresent(String.self, forKey: .lastPrayedDay) ?? ""
        testimony = try c.decodeIfPresent(String.self, forKey: .testimony) ?? ""
        bed = try c.decodeIfPresent(Int.self, forKey: .bed) ?? 0
    }
}

struct JournalEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var created = Date()
}

/// Everything is stored on the phone (UserDefaults). Nothing is uploaded.
final class AppStore: ObservableObject {
    @Published var name: String { didSet { UserDefaults.standard.set(name, forKey: "name") } }
    /// "female", "male" or "" (not set): picks the devotional plans, and later the health tools.
    @Published var gender: String { didSet { UserDefaults.standard.set(gender, forKey: "gender") } }
    @Published var prayers: [PrayerItem] { didSet { save(prayers, "prayers") } }
    @Published var journal: [JournalEntry] { didSet { save(journal, "journal") } }
    @Published var periodStarts: [Date] { didSet { save(periodStarts, "periodStarts") } }
    @Published var readDays: Set<String> { didSet { UserDefaults.standard.set(Array(readDays), forKey: "readDays") } }
    /// Faith → Today's prayer log (Morning, Gratitude, Intercession, Evening), and the days anything was prayed.
    @Published var prayerLog: [String: [Bool]] { didSet { UserDefaults.standard.set(prayerLog.filter { $0.key >= AppStore.dayKey(Date().addingTimeInterval(-40 * 86400)) }, forKey: "prayerLog") } }

    /// Android UserProfile defaults: a 28-day cycle with a 5-day period, and 8,000 steps a day.
    @Published var cycleLength: Int { didSet { UserDefaults.standard.set(cycleLength, forKey: "cycleLength") } }
    @Published var periodLength: Int { didSet { UserDefaults.standard.set(periodLength, forKey: "periodLength") } }
    var stepGoal: Int { let g = UserDefaults.standard.integer(forKey: "stepGoal"); return g > 0 ? g : 8000 }
    var journaledToday: Bool { journal.contains { Calendar.current.isDateInToday($0.created) } }

    var prayerDoneToday: [Bool] { prayerLog[AppStore.dayKey()] ?? [false, false, false, false] }
    var prayerDays: Set<String> { Set(prayerLog.filter { $0.value.contains(true) }.keys) }
    /// Days in a row with a prayer, ending today (or yesterday while today is open).
    var prayerStreak: Int {
        let cal = Calendar.current
        var day = Date()
        let days = prayerDays
        if !days.contains(AppStore.dayKey(day)) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var n = 0
        while days.contains(AppStore.dayKey(day)) { n += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        return n
    }
    func togglePrayer(_ i: Int) {
        var today = prayerDoneToday
        guard today.indices.contains(i) else { return }
        today[i].toggle()
        let award = "\(AppStore.dayKey())-\(i)"
        if today[i], UserDefaults.standard.string(forKey: "prayerAwarded\(i)") != award {
            UserDefaults.standard.set(award, forKey: "prayerAwarded\(i)"); Points.award(10)
        }
        prayerLog[AppStore.dayKey()] = today
    }

    init() {
        let d = UserDefaults.standard
        name = d.string(forKey: "name") ?? ""
        gender = d.string(forKey: "gender") ?? ""
        prayers = AppStore.load("prayers") ?? []
        journal = AppStore.load("journal") ?? []
        periodStarts = AppStore.load("periodStarts") ?? []
        readDays = Set(d.stringArray(forKey: "readDays") ?? [])
        prayerLog = d.dictionary(forKey: "prayerLog") as? [String: [Bool]] ?? [:]
        cycleLength = d.integer(forKey: "cycleLength") > 0 ? d.integer(forKey: "cycleLength") : 28
        periodLength = d.integer(forKey: "periodLength") > 0 ? d.integer(forKey: "periodLength") : 5
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// The start of the day a dayKey names, in the phone's time zone.
    static func date(fromKey key: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: key).map { Calendar.current.startOfDay(for: $0) }
    }

    var readStreak: Int {
        var count = 0
        var day = Date()
        let cal = Calendar.current
        if !readDays.contains(AppStore.dayKey(day)) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        while readDays.contains(AppStore.dayKey(day)) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    /// Android's logPeriodStart: keep the last 24 starts and learn the cycle length from them.
    func logPeriodStart(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        var starts = periodStarts.map { Calendar.current.startOfDay(for: $0) }
        if !starts.contains(day) { starts.append(day) }
        starts = Array(Set(starts)).sorted().suffix(24)
        periodStarts = starts
        cycleLength = CycleLogic.predictedLength(starts, fallback: cycleLength)
        ActivityLog.shared.add(.tracker)
    }

    func removePeriodStart(_ date: Date) {
        periodStarts.removeAll { Calendar.current.isDate($0, inSameDayAs: date) }
    }

    // MARK: Cycle estimate (average of logged starts; a rough estimate only)
    var averageCycleLength: Int? {
        let s = periodStarts.sorted()
        guard s.count >= 2 else { return nil }
        let gaps = zip(s.dropFirst(), s).map { Calendar.current.dateComponents([.day], from: $1, to: $0).day ?? 0 }
            .filter { $0 >= 18 && $0 <= 60 }
        guard !gaps.isEmpty else { return nil }
        return Int((Double(gaps.reduce(0, +)) / Double(gaps.count)).rounded())
    }

    var nextPeriodEstimate: Date? {
        guard let last = periodStarts.max(), let len = averageCycleLength else { return nil }
        return Calendar.current.date(byAdding: .day, value: len, to: last)
    }
}
