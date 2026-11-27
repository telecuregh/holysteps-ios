import SwiftUI

/// Search on Home: finds any part of the app by its name (and a few other words people use for it).
struct AppFeature: Identifiable {
    enum Target { case tab(Int, faith: Int?), view(() -> AnyView), sleep }
    let title: String
    let symbol: String
    let words: String
    let target: Target
    var id: String { title }

    static func all(gender: String) -> [AppFeature] {
        let cycle = gender == "male" ? "Wellness" : "Cycle"
        var list: [AppFeature] = [
            AppFeature(title: "Read the Bible", symbol: "book", words: "bible scripture chapter verse translation read", target: .view { AnyView(BibleReaderView()) }),
            AppFeature(title: "Highlights and notes", symbol: "highlighter", words: "highlight note bookmark", target: .view { AnyView(HighlightsView()) }),
            AppFeature(title: "Bible Reading Plan", symbol: "calendar", words: "plan year reading", target: .view { AnyView(BiblePlanView()) }),
            AppFeature(title: "Devotional Plans", symbol: "book.closed", words: "devotional devotion plan", target: .view { AnyView(DevotionalView()) }),
            AppFeature(title: "Bible Quiz", symbol: "questionmark.circle", words: "quiz trivia game question", target: .view { AnyView(BibleQuizView()) }),
            AppFeature(title: "Prayer List", symbol: "checklist", words: "prayer pray request answered", target: .view { AnyView(PrayerJournalView(section: 0)) }),
            AppFeature(title: "Faith Journal", symbol: "square.and.pencil", words: "journal write diary gratitude", target: .view { AnyView(PrayerJournalView(section: 1)) }),
            AppFeature(title: "Prayer Log", symbol: "hands.sparkles", words: "prayer log morning evening streak", target: .tab(1, faith: 0)),
            AppFeature(title: "This week's sermon", symbol: "mic", words: "sermon preach message church week", target: .tab(1, faith: 2)),
            AppFeature(title: "Sermons library", symbol: "mic", words: "sermon library all", target: .view { AnyView(SermonLibraryView()) }),
            AppFeature(title: "Sermons for what you're facing", symbol: "mic", words: "sermon grief anxiety fear facing topic", target: .view { AnyView(SermonTopicsView()) }),
            AppFeature(title: "Sermons through the Bible", symbol: "mic", words: "sermon book bible season", target: .view { AnyView(BibleSermonsView()) }),
            AppFeature(title: "Hymns", symbol: "music.note", words: "hymn music song", target: .view { AnyView(MusicView(tab: 1)) }),
            AppFeature(title: "Gospel songs", symbol: "music.note", words: "gospel worship music song my music", target: .view { AnyView(MusicView(tab: 0)) }),
            AppFeature(title: "Sleep stories", symbol: "moon.stars", words: "sleep story bedtime night kids prayer rest", target: .sleep),
            AppFeature(title: "Bedtime reminder", symbol: "bell", words: "bedtime reminder sleep notification", target: .sleep),
            AppFeature(title: "Your week", symbol: "calendar.badge.clock", words: "weekly recap week summary insights", target: .view { AnyView(WeeklyRecapView()) }),
            AppFeature(title: "Steps", symbol: "figure.walk", words: "steps walk walking fitness goal", target: .tab(2, faith: nil)),
            AppFeature(title: cycle, symbol: gender == "male" ? "dumbbell" : "arrow.triangle.2.circlepath",
                       words: gender == "male" ? "wellness health strength" : "cycle period phase", target: .tab(3, faith: nil)),
            AppFeature(title: "Profile and settings", symbol: "person", words: "profile settings name language spanish theme appearance dark light pearl erase",
                       target: .tab(4, faith: nil)),
            AppFeature(title: "Crisis help (988)", symbol: "phone", words: "crisis help 988 suicide emergency safety", target: .tab(1, faith: 3)),
            AppFeature(title: "Body basics", symbol: "heart", words: "water blood pressure weight glucose habits medicine pill reminder", target: .view { AnyView(BodyBasicsView()) }),
            AppFeature(title: "Checkups & self-checks", symbol: "stethoscope", words: "checkup screening vaccine doctor exam self-check", target: .view { AnyView(CheckupsView(women: gender != "male")) }),
            AppFeature(title: "Mood check-in", symbol: "brain.head.profile", words: "mood depression anxiety check phq feeling", target: .view { AnyView(MoodCheckView()) }),
            AppFeature(title: "Walk through the Bible", symbol: "book", words: "walk bible chapter kilometer steps genesis revelation", target: .view { AnyView(BibleWalkView()) }),
            AppFeature(title: "How HolySteps works", symbol: "questionmark.circle", words: "help how works explain privacy features", target: .view { AnyView(HowItWorksView()) }),
            AppFeature(title: "Partner coaching", symbol: "heart.circle", words: "partner husband wife spouse coaching support tip invite code", target: .view { AnyView(PartnerCoachingView()) }),
            AppFeature(title: "Headache diary", symbol: "bolt.heart", words: "headache migraine diary", target: .view { AnyView(HeadacheView()) }),
        ]
        if gender != "male" {
            list += [
                AppFeature(title: "Cycle Circles", symbol: "person.3", words: "circle support group endometriosis pcos ttc community women", target: .view { AnyView(CycleCirclesView()) }),
                AppFeature(title: "Skin journal", symbol: "face.smiling", words: "skin acne breakout photo journal selfie", target: .view { AnyView(CycleLockGate { SkinJournalView() }) }),
                AppFeature(title: "Bring your data", symbol: "square.and.arrow.down", words: "import flo clue transfer move period history", target: .view { AnyView(CycleLockGate { BringDataView() }) }),
                AppFeature(title: "Mood and tests", symbol: "face.smiling", words: "mood pregnancy test period", target: .view { AnyView(CycleLockGate { CycleMoodTestsView() }) }),
                AppFeature(title: "Symptom severity", symbol: "chart.line.uptrend.xyaxis", words: "pms pmdd pcos endometriosis pain severity period", target: .view { AnyView(CycleLockGate { SeverityView() }) }),
                AppFeature(title: "Pregnancy tools", symbol: "figure.and.child.holdinghands", words: "pregnancy kick counter contraction timer appointment", target: .view { AnyView(CycleLockGate { PregnancyToolsView() }) }),
            ]
        }
        if gender == "male" { list.removeAll { $0.words.contains("period") } }
        return list
    }
}

struct AppSearchView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var router = TabRouter.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var sleep = false

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = AppFeature.all(gender: store.gender)
        let found = q.isEmpty ? all : all.filter { f in
            (tr(f.title) + " " + f.title + " " + f.words).lowercased().contains(q) ||
            q.split(separator: " ").allSatisfy { (tr(f.title) + " " + f.words).lowercased().contains($0) }
        }
        NavigationStack {
            ZStack {
                HS.solidSurface.ignoresSafeArea()
                List {
                    if found.isEmpty {
                        T("Nothing by that name yet. Try another word.").font(.hs(14)).foregroundStyle(HS.textMuted).listRowBackground(Color.clear)
                    }
                    ForEach(found) { f in
                        row(f).listRowBackground(HS.cardFill)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Find anything in HolySteps"))
            .navigationTitle(D(tr("Search")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Close")) { dismiss() } } }
            .navigationDestination(isPresented: $sleep) { SleepView() }
        }
    }

    @ViewBuilder private func row(_ f: AppFeature) -> some View {
        let label = HStack(spacing: 12) {
            Image(systemName: f.symbol).foregroundStyle(HS.gold).frame(width: 24)
            T(f.title).font(.hs(15)).foregroundStyle(HS.text)
        }
        switch f.target {
        case .view(let make): NavigationLink { make() } label: { label }
        case .sleep: Button { sleep = true } label: { label }
        case .tab(let t, let faith): Button { router.open(tab: t, faith: faith); dismiss() } label: { label }
        }
    }
}
