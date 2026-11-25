import Foundation

struct Verse: Identifiable {
    let id: Int
    let ref: String
    let text: String
    /// The same verse in the Reina-Valera 1909 (RVES), shown when the app is in Spanish.
    let es: String
    var shown: String { I18n.shared.spanish ? es : text }
}

/// A small set of public-domain verses (KJV, with the Reina-Valera 1909 in Spanish) for the daily verse. The full Bible reader is a later step.
enum AppContent {
    static let verses: [Verse] = DailyVerses.all.map { Verse(id: $0.id, ref: $0.ref, text: $0.text, es: $0.es) }

    static func verseOfTheDay(_ date: Date = Date()) -> Verse {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return verses[day % verses.count]
    }

    static let prayerPrompts = [
        "Thank God for three things from today.",
        "Pray for someone who is struggling right now.",
        "Ask for peace over what you cannot control.",
        "Pray for your family by name.",
        "Confess something you have been carrying, and receive grace."
    ]
}
