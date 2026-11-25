import WidgetKit
import SwiftUI

/// Today's verse on the Home Screen and Lock Screen, in the Navy Glass design (the same as the shared verse image).
/// It changes at midnight, in step with the app's daily verse; Spanish when the phone is in Spanish. Tapping it opens
/// the app. Works offline: the verses are part of the widget.
struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: DailyVerse
}

struct VerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry { VerseEntry(date: Date(), verse: DailyVerses.forDay()) }
    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let entries = (0..<3).compactMap { d -> VerseEntry? in
            guard let day = cal.date(byAdding: .day, value: d, to: start) else { return nil }
            return VerseEntry(date: d == 0 ? Date() : day, verse: DailyVerses.forDay(day))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private var spanish: Bool { (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es") }
private func text(_ v: DailyVerse) -> String { spanish ? v.es : v.text }
private func ref(_ v: DailyVerse) -> String { spanish ? DailyVerses.spanishRef(v.ref) : v.ref }
private var header: String { spanish ? "VERSÍCULO DE HOY" : "TODAY'S VERSE" }

struct VerseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(ref(entry.verse)).font(.caption2.weight(.semibold)).widgetAccentable()
                Text(text(entry.verse)).font(.caption).lineLimit(3)
            }
            .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            Text("\(ref(entry.verse)) · \(text(entry.verse))")
                .containerBackground(.clear, for: .widget)
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                Text(header).font(.custom("Inter-SemiBold", size: 8)).tracking(2).foregroundStyle(NavyGlass.gold)
                Text("“\(text(entry.verse))”").font(.custom("PlayfairDisplay-Italic", size: 15))
                    .foregroundStyle(NavyGlass.ink).minimumScaleFactor(0.55)
                Spacer(minLength: 0)
                Text(ref(entry.verse)).font(.custom("Inter-SemiBold", size: 11)).foregroundStyle(NavyGlass.gold).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) { NavyGlassBackground() }
        case .systemMedium:
            NavyGlassVerseCard(header: header, text: text(entry.verse), ref: ref(entry.verse), scale: 0.5, verseSize: 34)
                .containerBackground(for: .widget) { NavyGlassBackground() }
        default:
            NavyGlassVerseCard(header: header, text: text(entry.verse), ref: ref(entry.verse), scale: 0.62, verseSize: 40)
                .frame(maxHeight: .infinity)
                .containerBackground(for: .widget) { NavyGlassBackground() }
        }
    }
}

struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HolyStepsVerse", provider: VerseProvider()) { VerseWidgetView(entry: $0) }
            .configurationDisplayName(spanish ? "Versículo de hoy" : "Today's verse")
            .description(spanish ? "El versículo del día de HolySteps." : "HolySteps' verse of the day.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
            .contentMarginsDisabled()
    }
}

@main
struct HolyStepsWidgets: WidgetBundle {
    var body: some Widget {
        VerseWidget()
        HolyStepsLiveActivity()
    }
}
