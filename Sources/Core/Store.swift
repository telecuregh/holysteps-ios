import Foundation
import SwiftUI

struct PrayerItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var created = Date()
    var answered = false
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

    init() {
        let d = UserDefaults.standard
        name = d.string(forKey: "name") ?? ""
        gender = d.string(forKey: "gender") ?? ""
        prayers = AppStore.load("prayers") ?? []
        journal = AppStore.load("journal") ?? []
        periodStarts = AppStore.load("periodStarts") ?? []
        readDays = Set(d.stringArray(forKey: "readDays") ?? [])
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
