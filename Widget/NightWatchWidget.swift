import WidgetKit
import SwiftUI

/// Night Watch, made for StandBy (iPhone on its side while charging): today's verse large enough to read from the
/// nightstand, with your prayer and steps for the day. In StandBy's night mode the system tints it red.
/// Comes with the Faith plan; without it, the widget says so and opens the app.
struct NightEntry: TimelineEntry {
    let date: Date
    let verse: DailyVerse
    let steps: Int, goal: Int, prayed: Bool, streak: Int, faith: Bool
}

struct NightProvider: TimelineProvider {
    private func entry(_ date: Date) -> NightEntry {
        NightEntry(date: date, verse: DailyVerses.forDay(date), steps: SharedState.steps, goal: SharedState.stepGoal,
                   prayed: SharedState.prayedToday, streak: SharedState.streak, faith: SharedState.faith)
    }
    func placeholder(in context: Context) -> NightEntry {
        NightEntry(date: Date(), verse: DailyVerses.forDay(), steps: 6200, goal: 8000, prayed: true, streak: 5, faith: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (NightEntry) -> Void) { completion(context.isPreview ? placeholder(in: context) : entry(Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NightEntry>) -> Void) {
        let next = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry(Date()), entry(next)], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

private var spanish: Bool { (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es") }

struct NightWatchView: View {
    let entry: NightEntry

    var body: some View {
        Group {
            if entry.faith {
                VStack(alignment: .leading, spacing: 6) {
                    Text("“\(spanish ? entry.verse.es : entry.verse.text)”")
                        .font(.custom("PlayfairDisplay-Italic", size: 17)).foregroundStyle(NavyGlass.ink)
                        .minimumScaleFactor(0.5)
                    Text(spanish ? DailyVerses.spanishRef(entry.verse.ref) : entry.verse.ref)
                        .font(.custom("Inter-SemiBold", size: 10)).foregroundStyle(NavyGlass.gold).lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        Label(entry.prayed ? (spanish ? "Oraste" : "Prayed") : (spanish ? "Ora" : "Pray"),
                              systemImage: entry.prayed ? "checkmark.circle.fill" : "hands.sparkles")
                        if entry.streak > 1 { Text("🔥\(entry.streak)") }
                        Spacer(minLength: 0)
                        Label("\(entry.steps.formatted())", systemImage: "figure.walk")
                    }
                    .font(.custom("Inter-Medium", size: 10)).foregroundStyle(NavyGlass.ink.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.7)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "moon.stars").font(.title2).foregroundStyle(NavyGlass.gold)
                    Text(spanish ? "Vigilia nocturna" : "Night Watch").font(.custom("Inter-SemiBold", size: 14)).foregroundStyle(NavyGlass.ink)
                    Text(spanish ? "Viene con el plan Fe. Toca para abrir HolySteps." : "Comes with the Faith plan. Tap to open HolySteps.")
                        .font(.custom("Inter-Medium", size: 11)).foregroundStyle(NavyGlass.ink.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { NavyGlassBackground() }
    }
}

struct NightWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NightWatch", provider: NightProvider()) { NightWatchView(entry: $0) }
            .configurationDisplayName(spanish ? "Vigilia nocturna" : "Night Watch")
            .description(spanish ? "Para StandBy: el versículo de hoy, tu oración y tus pasos." : "For StandBy: today's verse, your prayer and your steps.")
            .supportedFamilies([.systemSmall])
    }
}
