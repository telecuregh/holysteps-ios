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
        let cycle = gender == "male" ? "Men" : "Women"
        var list: [AppFeature] = [
            AppFeature(title: "Read the Bible", symbol: "book", words: "bible scripture chapter verse translation read", target: .view { AnyView(BibleReaderView()) }),
            AppFeature(title: "Highlights and notes", symbol: "highlighter", words: "highlight note bookmark", target: .view { AnyView(HighlightsView()) }),
            AppFeature(title: "Bible Reading Plan", symbol: "calendar", words: "plan year reading", target: .view { AnyView(BiblePlanView()) }),
            AppFeature(title: "Devotional Plans", symbol: "book.closed", words: "devotional devotion plan", target: .view { AnyView(DevotionalView()) }),
            AppFeature(title: "Bible Quiz", symbol: "questionmark.circle", words: "quiz trivia game question", target: .view { AnyView(BibleQuizView()) }),
            AppFeature(title: "Prayer List", symbol: "checklist", words: "prayer pray request answered", target: .view { AnyView(PrayerJournalView(section: 0)) }),
            AppFeature(title: "Faith Journal", symbol: "square.and.pencil", words: "journal write diary gratitude", target: .view { AnyView(PrayerJournalView(section: 1)) }),
            AppFeature(title: "Prayer Log", symbol: "hands.sparkles", words: "prayer log morning evening streak", target: .tab(1, faith: 0)),
            AppFeature(title: "This week's sermon", symbol: "mic", words: "sermon preach message church week", target: .tab(1, faith: 3)),
            AppFeature(title: "Sermons library", symbol: "mic", words: "sermon library all", target: .view { AnyView(SermonLibraryView()) }),
            AppFeature(title: "Sermons for what you're facing", symbol: "mic", words: "sermon grief anxiety fear facing topic", target: .view { AnyView(SermonTopicsView()) }),
            AppFeature(title: "True stories", symbol: "heart.text.square", words: "true story stories hope came through testimony", target: .view { AnyView(TrueStoriesView()) }),
            AppFeature(title: "Pray about…", symbol: "hands.sparkles", words: "pray about guide sick healing grief job exams money marriage children travel", target: .view { AnyView(PrayAboutView()) }),
            AppFeature(title: "Fasting", symbol: "leaf", words: "fast fasting pray hunger", target: .view { AnyView(FastingView()) }),
            AppFeature(title: "Sermon notes", symbol: "note.text", words: "sermon notes church preacher passages takeaway", target: .view { AnyView(SermonNotesView()) }),
            AppFeature(title: "Your practice", symbol: "building.columns", words: "tradition practice rosary catholic orthodox jesus prayer protestant acts saint", target: .view { AnyView(TraditionPracticeView()) }),
            AppFeature(title: "Faith Chat", symbol: "bubble.left.and.text.bubble.right", words: "faith chat ask anything ai question bible prayer coach companion", target: .view { AnyView(FaithCoachView()) }),
            AppFeature(title: "Adaptive Coach", symbol: "brain.head.profile", words: "adaptive coach plan sleep stress today ai personal trainer", target: .view { AnyView(AdaptiveCoachView()) }),
            AppFeature(title: "Form Coach", symbol: "camera", words: "form coach camera reps squats push-ups lunges curls sit-ups posture", target: .view { AnyView(FormCoachPickerView()) }),
            AppFeature(title: "Strength log", symbol: "dumbbell", words: "strength lift weights sets reps bench squat deadlift gym", target: .view { AnyView(StrengthLogView()) }),
            AppFeature(title: "Mind tracks", symbol: "brain", words: "mind tracks stress pressure anger purpose comparison boundaries mental load", target: .view { AnyView(MindTracksView()) }),
            AppFeature(title: "Morning light", symbol: "sun.max", words: "morning light sunlight daylight outside wake sleep lux circadian", target: .view { AnyView(MorningLightView()) }),
            AppFeature(title: "My reminders", symbol: "bell.badge", words: "reminders water drink move stand bed bedtime self care notification", target: .view { AnyView(MyRemindersView()) }),
            AppFeature(title: "Health helper", symbol: "cross.case", words: "health helper medicine pill taken mood take it easy doctor summary pdf headache", target: .view { AnyView(HealthHelperView()) }),
            AppFeature(title: "Life & Health Trends", symbol: "chart.xyaxis.line", words: "trends mood energy sleep steps chart heatmap patterns insights", target: .view { AnyView(TrendsView()) }),
            AppFeature(title: "About you", symbol: "person.text.rectangle", words: "about you learned patterns routines rhythms insights habits", target: .view { AnyView(AboutYouView()) }),
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
            AppFeature(title: "Crisis help (988)", symbol: "phone", words: "crisis help 988 suicide emergency safety", target: .tab(1, faith: 4)),
            AppFeature(title: "Body basics", symbol: "heart", words: "water blood pressure weight glucose habits medicine pill reminder", target: .view { AnyView(BodyBasicsView()) }),
            AppFeature(title: "Checkups & self-checks", symbol: "stethoscope", words: "checkup screening vaccine doctor exam self-check", target: .view { AnyView(CheckupsView(women: gender != "male")) }),
            AppFeature(title: "Mood check-in", symbol: "brain.head.profile", words: "mood depression anxiety check phq feeling", target: .view { AnyView(MoodCheckView()) }),
            AppFeature(title: "Walk through the Bible", symbol: "book", words: "walk bible chapter kilometer steps genesis revelation", target: .view { AnyView(BibleWalkView()) }),
            AppFeature(title: "How HolySteps works", symbol: "questionmark.circle", words: "help how works explain privacy features", target: .view { AnyView(HowItWorksView()) }),
            AppFeature(title: "Kids profiles", symbol: "figure.and.child.holdinghands", words: "kids children child son daughter bedtime family", target: .view { AnyView(KidsProfilesView()) }),
            AppFeature(title: "Groups", symbol: "person.3", words: "group family small group church together prayer service", target: .view { AnyView(FaithGroupsView()) }),
            AppFeature(title: "Reading together", symbol: "book", words: "reading plan friends together bible group", target: .view { AnyView(ReadingTogetherView()) }),
            AppFeature(title: "Weekly league", symbol: "trophy", words: "league leaderboard steps compete rank", target: .view { AnyView(LeaguesView()) }),
            AppFeature(title: "Scripture duels", symbol: "bolt", words: "duel verse game compete memory", target: .view { AnyView(DuelsView()) }),
            AppFeature(title: "Safety circle", symbol: "shield", words: "safety sos emergency walk share location circle family", target: .view { AnyView(SafetyCircleView()) }),
            AppFeature(title: "Partner coaching", symbol: "heart.circle", words: "partner husband wife spouse coaching support tip invite code", target: .view { AnyView(PartnerCoachingView()) }),
            AppFeature(title: "Headache diary", symbol: "bolt.heart", words: "headache migraine diary", target: .view { AnyView(HeadacheView()) }),
            // Every screen Android's search lists (FeatureSearch.kt), with Android's names, so search and "Your shortcuts"
            // find and learn the same things on both phones.
            AppFeature(title: "Prayer Walk", symbol: "figure.walk", words: "prayer walk pray walking", target: .view { AnyView(PrayerWalkFeatureView()) }),
            AppFeature(title: "Verse Memory", symbol: "brain", words: "verse memory memorize scripture flashcard", target: .view { AnyView(VerseMemoryView()) }),
            AppFeature(title: "Prayer garden", symbol: "leaf", words: "garden prayer flower bloom answered grow", target: .view { AnyView(PrayerGardenView()) }),
            AppFeature(title: "Audio Sanctuary", symbol: "headphones", words: "audio sanctuary guided prayer meditation listen calm", target: .view { AnyView(AudioPrayerView()) }),
            AppFeature(title: "Spatial Sanctuary", symbol: "ear", words: "spatial sanctuary rain creek bell headphones", target: .view { AnyView(SpatialSanctuaryView()) }),
            AppFeature(title: "Breath prayer", symbol: "wind", words: "breath prayer breathe haptic calm", target: .view { AnyView(BreathPrayerView()) }),
            AppFeature(title: "Prayer Wall", symbol: "rectangle.3.group.bubble", words: "prayer wall testimony requests community", target: .view { AnyView(PrayerWallView()) }),
            AppFeature(title: "Habit Circles", symbol: "person.3", words: "habit circle friends streak accountability together", target: .view { AnyView(CirclesView()) }),
            AppFeature(title: "Family Faith Relay", symbol: "flame", words: "family relay baton faith together", target: .view { AnyView(FamilyRelayView()) }),
            AppFeature(title: "My church", symbol: "building.columns", words: "church congregation pastor sermon members", target: .view { AnyView(ChurchTab()) }),
            AppFeature(title: "Live rooms", symbol: "dot.radiowaves.left.and.right", words: "live room voice pray together", target: .view { AnyView(LiveRoomsView()) }),
            AppFeature(title: "Wake-up alarm", symbol: "alarm", words: "alarm wake morning scripture", target: .view { AnyView(WakeAlarmView()) }),
            AppFeature(title: "Calm Check", symbol: "heart.text.square", words: "calm check stress heart rate camera", target: .view { AnyView(CalmCheckView()) }),
            AppFeature(title: "Breathing Pace", symbol: "lungs", words: "breathing pace breath rate", target: .view { AnyView(BreathPaceView()) }),
            AppFeature(title: "Temperature & fever", symbol: "thermometer", words: "temperature fever thermometer", target: .view { AnyView(TemperatureView()) }),
            AppFeature(title: "Rewards", symbol: "star", words: "rewards points badges achievements", target: .view { AnyView(RewardsView()) }),
            AppFeature(title: "Backup & restore", symbol: "externaldrive", words: "backup restore export save phone", target: .view { AnyView(BackupView()) }),
            AppFeature(title: "Rings & watches", symbol: "applewatch", words: "watch ring oura health wearable heart rate sleep", target: .view { AnyView(RingsWatchesView()) }),
            AppFeature(title: "Freedom", symbol: "lock.open", words: "freedom habit urge recovery block sites", target: .view { AnyView(FreedomView()) }),
            AppFeature(title: "Baby tracker", symbol: "figure.and.child.holdinghands", words: "baby feed diaper sleep newborn", target: .view { AnyView(BabyView()) }),
            AppFeature(title: "Challenges", symbol: "flag", words: "commitment pledge goal challenge", target: .view { AnyView(CommitmentsView()) }),
            AppFeature(title: "Workout programs", symbol: "list.bullet.rectangle", words: "program plan weeks workout", target: .view { AnyView(ProgramsView()) }),
            AppFeature(title: "Workouts", symbol: "figure.strengthtraining.traditional", words: "workout exercise routine guided", target: .view { AnyView(WorkoutLibraryView()) }),
            AppFeature(title: "Activity statistics", symbol: "chart.bar", words: "statistics walks history distance minutes", target: .view { AnyView(WalkHistoryView()) }),
            AppFeature(title: "Body & energy", symbol: "bolt", words: "body energy readiness recovery", target: .view { AnyView(Gated(feature: .bodyEnergy) { BodyEnergyView() }) }),
            AppFeature(title: "Trust and privacy", symbol: "lock.shield", words: "privacy trust data security", target: .view { AnyView(TrustView()) }),
        ]
        if gender != "male" {
            list += [
                AppFeature(title: "Cycle Circles", symbol: "person.3", words: "circle support group endometriosis pcos ttc community women", target: .view { AnyView(CycleCirclesView()) }),
                AppFeature(title: "Skin journal", symbol: "face.smiling", words: "skin acne breakout photo journal selfie", target: .view { AnyView(CycleLockGate { SkinJournalView() }) }),
                AppFeature(title: "Bring your data", symbol: "square.and.arrow.down", words: "import flo clue transfer move period history", target: .view { AnyView(CycleLockGate { BringDataView() }) }),
                AppFeature(title: "Mood and tests", symbol: "face.smiling", words: "mood pregnancy test period", target: .view { AnyView(CycleLockGate { CycleMoodTestsView() }) }),
                AppFeature(title: "Symptom severity", symbol: "chart.line.uptrend.xyaxis", words: "pms pmdd pcos endometriosis pain severity period", target: .view { AnyView(CycleLockGate { SeverityView() }) }),
                AppFeature(title: "Pregnancy tools", symbol: "figure.and.child.holdinghands", words: "pregnancy kick counter contraction timer appointment", target: .view { AnyView(CycleLockGate { PregnancyToolsView() }) }),
                AppFeature(title: "New parents", symbol: "heart.circle", words: "postpartum new mom baby blues depression after birth", target: .view { AnyView(PostpartumView()) }),
            ]
        }
        if gender == "male" {
            list += [
                AppFeature(title: "Men's wellness", symbol: "heart", words: "men health screening testosterone prostate", target: .view { AnyView(MensWellnessView()) }),
                AppFeature(title: "Support her cycle", symbol: "heart.circle", words: "wife partner cycle support husband", target: .view { AnyView(SupportHerCycleView()) }),
            ]
            list.removeAll { $0.words.contains("period") }
        }
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
        case .view(let make): NavigationLink { make().onAppear { Learning.shared.recordOpen(f.title) } } label: { label }
        case .sleep: Button { Learning.shared.recordOpen(f.title); sleep = true } label: { label }
        case .tab(let t, let faith): Button { Learning.shared.recordOpen(f.title); router.open(tab: t, faith: faith); dismiss() } label: { label }
        }
    }
}
