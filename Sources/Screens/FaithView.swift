import SwiftUI

/// The Faith tab, laid out like Android's FaithScreen.kt: the header with the stats pill, then sub-tabs (Today, Pray,
/// Bible, Listen, Mind). Together joins with community features (phase 4).
struct FaithView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var bible = BibleState.shared
    @ObservedObject private var router = TabRouter.shared
    @State private var image: VerseCard?

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ScreenPhoto(name: "screen_faith").id("top")
                            header
                            Spacer().frame(height: 4)
                            // At most four sections: praying lives in Today.
                            SubTabs(tabs: ["Today", "Bible", "Listen", "Mind"], selected: $router.faithTab)
                            Spacer().frame(height: 16)
                            switch router.faithTab {
                            case 0:
                                today
                                Spacer().frame(height: 16)
                                pray
                            case 1: bibleTab
                            case 2: listen
                            default: mind
                            }
                            Spacer().frame(height: 100)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .onChange(of: router.faithTab) { _, _ in proxy.scrollTo("top", anchor: .top) }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: Binding(get: { image != nil }, set: { if !$0 { image = nil } })) {
                if let c = image { VerseImageView(card: c) }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                IconBadge(symbol: "hands.sparkles", size: 30, tint: 0x9D7FEA)
                T("Faith").font(.hs(13, .semibold)).tracking(0.6).foregroundStyle(HS.peach)
            }
            Spacer().frame(height: 10)
            T("Daily Devotion").font(.hs(26)).foregroundStyle(HS.text)
            ItalicAccent(text: "Grow closer to God, one day at a time", size: 17)
            Spacer().frame(height: 12)
            FaithStatsPill(prayerDays: store.prayerStreak, bibleDay: max(0, bible.readingDay - 1), points: Points.total)
        }
        .padding(.top, 44).padding(.horizontal, 20).padding(.bottom, 14)
    }

    // MARK: Today

    @ViewBuilder private var today: some View {
        QuizRow()
        Spacer().frame(height: 16)
        SectionHeader(title: "Today's Scripture")
        let verse = AppContent.verseOfTheDay()
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                D("\"\(verse.shown)\"").font(.accent(16)).lineSpacing(10).foregroundStyle(HS.text)
                Spacer().frame(height: 12)
                HStack {
                    D("— " + tr(verse.ref)).font(.hs(13, .semibold)).foregroundStyle(HS.peach)
                    Spacer()
                    Button { image = VerseCard(text: verse.shown, ref: tr(verse.ref), translation: "", attribution: "") } label: {
                        T("Share as image").font(.hs(13)).foregroundStyle(HS.peach).frame(minHeight: 44)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        Spacer().frame(height: 16)
        WeeklySermonCard(more: false)
        Spacer().frame(height: 16)
        SectionHeader(title: "Prayer Log")
        prayerLog
        Spacer().frame(height: 16)
        SectionHeader(title: "Bible Reading Plan")
        readingPlan
        Spacer().frame(height: 16)
        SectionHeader(title: "Prayer Streak")
        prayerWeek
        Spacer().frame(height: 16)
        InsightBubble(text: "\"The Lord is near to all who call on him, to all who call on him in truth.\" — Psalm 145:18")
    }

    private var prayerLog: some View {
        let prayers = [("Morning Prayer", "Start the day with God"), ("Gratitude", "Thank God for 3 things"),
                       ("Intercession", "Pray for others"), ("Evening Prayer", "Close the day with reflection")]
        let done = store.prayerDoneToday
        return VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { r in
                HStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { c in
                        let i = r * 2 + c
                        Button { store.togglePrayer(i) } label: {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        IconBadge(symbol: done[i] ? "checkmark.circle" : "hands.sparkles", size: 32, tint: 0x9D7FEA)
                                        Spacer()
                                        if done[i] { T("Done").font(.hs(11, .semibold)).foregroundStyle(HS.body) }
                                    }
                                    Spacer().frame(height: 10)
                                    T(prayers[i].0).font(.hs(14, .semibold)).foregroundStyle(done[i] ? HS.peach : HS.text)
                                    Spacer().frame(height: 2)
                                    T(prayers[i].1).font(.hs(12)).lineSpacing(2).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(tr(done[i] ? "Prayed" : "Mark as prayed"))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
    }

    private var readingPlan: some View {
        let day = bible.shownDay
        let readings = BiblePlan.chapters(day: day)
        let read = bible.bibleReadToday
        return GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    NavigationLink { BibleReaderView(startBook: readings.first?.book, startCh: readings.first?.ch) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            T(read ? "Day \(day) · done today" : "Day \(day)").font(.hs(12, .semibold)).foregroundStyle(HS.peach)
                            T(BiblePlan.reading(day: day)).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                            T("Whole Bible in a year • \(readings.count) \(readings.count == 1 ? "chapter" : "chapters") · tap to read")
                                .font(.hs(12)).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button { bible.completeBibleReading(store: store) } label: {
                        Image(systemName: read ? "checkmark" : "book")
                            .font(.system(size: 17, weight: read ? .bold : .regular))
                            .foregroundStyle(read ? HS.onGold : HS.peach)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(read ? HS.goldButton : HS.cardFill))
                            .overlay(Circle().strokeBorder(read ? .clear : HS.gold.opacity(0.35), lineWidth: 1))
                    }
                    .accessibilityLabel(tr(read ? "Completed" : "Mark read"))
                }
                Spacer().frame(height: 12)
                HSProgressBar(progress: Double(day) / 365)
                Spacer().frame(height: 6)
                T("\(day) of 365 days").font(.hs(11)).foregroundStyle(HS.textMuted)
            }
        }
        .padding(.horizontal, 20)
    }

    private var prayerWeek: some View {
        let cal = Calendar.current
        let f = DateFormatter(); f.locale = I18n.shared.locale; f.dateFormat = "EEEEE"
        let days = store.prayerDays.union(store.readDays)
        return GlassCard {
            HStack(spacing: 8) {
                ForEach((0...6).reversed(), id: \.self) { ago in
                    let date = cal.date(byAdding: .day, value: -ago, to: Date()) ?? Date()
                    let filled = days.contains(AppStore.dayKey(date))
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(filled ? HS.goldButton.opacity(0.25) : HS.overlay(0.05))
                            RoundedRectangle(cornerRadius: 10).strokeBorder(ago == 0 ? HS.peach : (filled ? HS.gold.opacity(0.45) : HS.overlay(0.10)), lineWidth: 1)
                            if filled { Image(systemName: "flame").font(.system(size: 14)).foregroundStyle(HS.peach) }
                            else { D("○").font(.hs(14)).foregroundStyle(HS.textMuted) }
                        }
                        .frame(height: 36)
                        D(ago == 0 ? tr("Today") : f.string(from: date)).font(.hs(10)).foregroundStyle(HS.textMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Other tabs

    @ViewBuilder private var pray: some View {
        let answered = store.prayers.filter(\.answered).count
        PrayerGardenCard().padding(.top, 12)
        ToolSection(title: "Ways to pray", items: [
            ToolItem(symbol: "checklist", color: HS.peach, title: "Prayer List", sub: "\(store.prayers.count - answered) praying · \(answered) answered",
                     destination: AnyView(PrayerJournalView(section: 0))),
        ], visible: 8)
    }

    @ViewBuilder private var bibleTab: some View {
        let dev = DevotionalState.shared
        ToolSection(title: "Read", items: [
            ToolItem(symbol: "book", color: HS.peach, title: "Read the Bible", sub: "37 translations in 30 languages · works offline", badge: "New",
                     destination: AnyView(BibleReaderView())),
            ToolItem(symbol: "book", color: HS.faith, title: "Devotional Plans",
                     sub: dev.readToday ? "Day \(max(1, dev.day - 1)) · done today" : "Day \(dev.day) · continue",
                     badge: dev.readToday ? "✓" : nil, destination: AnyView(DevotionalView())),
            ToolItem(symbol: "highlighter", color: HS.body, title: "Highlights and notes", sub: "\(bible.highlights.count) saved",
                     destination: AnyView(HighlightsView())),
            ToolItem(symbol: "brain.head.profile", color: HS.gold, title: "Verse Memory", sub: "\(VerseMemory.mastered.count) of \(VerseMemory.all.count) mastered",
                     destination: AnyView(VerseMemoryView())),
        ])
        Spacer().frame(height: 16)
        ToolSection(title: "Reflect", items: [
            ToolItem(symbol: "book.closed", color: HS.body, title: "Faith Journal", sub: "\(store.journal.count) entries",
                     destination: AnyView(PrayerJournalView(section: 1))),
        ])
    }

    @ViewBuilder private var listen: some View {
        WeeklySermonCard(more: true)
        Spacer().frame(height: 16)
        ToolSection(title: "Audio", items: [
            ToolItem(symbol: "music.note", color: HS.peach, title: "Hymns", sub: "Sung hymns and country gospel", destination: AnyView(MusicView(tab: 1))),
            ToolItem(symbol: "music.note", color: HS.peach, title: "Gospel songs", sub: "Songs on Bible passages, and your own music", destination: AnyView(MusicView(tab: 0))),
        ])
    }

    @ViewBuilder private var mind: some View {
        CrisisCard().padding(.horizontal, 20)
        Spacer().frame(height: 16)
        ToolSection(title: "Support", items: [
            ToolItem(symbol: "hands.sparkles", color: HS.faith, title: "Sermons for what you're facing", sub: "Anxiety, grief, loneliness, anger and more",
                     destination: AnyView(SermonTopicsView())),
            ToolItem(symbol: "book", color: HS.faith, title: "Sermons through the Bible", sub: "A new book every week, Genesis to Revelation",
                     destination: AnyView(BibleSermonsView())),
        ])
        ToolSection(title: "Calm", items: [
            ToolItem(symbol: "heart.text.square", color: HS.mind, title: "Calm check", sub: "Your heart rate and calm in 30 seconds",
                     destination: AnyView(CalmCheckView())),
            ToolItem(symbol: "wind", color: HS.mind, title: "Breathing pace", sub: "How fast you breathe, in one minute",
                     destination: AnyView(BreathPaceView())),
        ])
    }
}

/// Prayer, Bible and Points in one thin pill, each with a small ring (Android's FaithStatsPill).
struct FaithStatsPill: View {
    let prayerDays: Int
    let bibleDay: Int
    let points: Int

    var body: some View {
        let items: [(String, String, Color, Double)] = [
            ("\(prayerDays)", "Prayer", Color(hex: 0xC77D92), Double(min(prayerDays, 7)) / 7),
            ("\(bibleDay)", "Bible", Color(hex: 0x7FA86A), Double(min(bibleDay, 365)) / 365),
            ("\(points)", "Points", Color(hex: 0xD6AA6E), Double(points % 100) / 100),
        ]
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                if i > 0 { Rectangle().fill(HS.gold.opacity(0.35)).frame(width: 1, height: 14) }
                HStack(spacing: 0) {
                    ZStack {
                        Circle().stroke(it.2.opacity(0.3), lineWidth: 2)
                        Circle().trim(from: 0, to: it.3).stroke(it.2, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
                        Circle().fill(it.2).frame(width: 4, height: 4)
                    }
                    .frame(width: 13, height: 13)
                    Spacer().frame(width: 6)
                    D(it.0).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    Spacer().frame(width: 3)
                    T(it.1).font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 32)
        .background(Capsule().fill(HS.overlay(0.06)))
        .overlay(Capsule().strokeBorder(HS.gold.opacity(0.45), lineWidth: 1))
    }
}

/// The prayer list and the journal.
struct PrayerJournalView: View {
    @EnvironmentObject var store: AppStore
    @State var section = 0
    @State private var draft = ""
    @State private var paywall = false
    @ObservedObject private var account = AccountStore.shared

    /// Android's visibleJournal: the last 7 days are free; any plan opens the whole journal (nothing is deleted).
    private var visibleJournal: [JournalEntry] {
        if account.canUse(.journalHistory) { return store.journal }
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        return store.journal.filter { $0.created >= cutoff }
    }

    var body: some View {
        ZStack {
            HSBackground()
            VStack(alignment: .leading, spacing: 14) {
                SubTabs(tabs: ["Prayer list", "Journal"], selected: $section).padding(.horizontal, -20)
                HStack {
                    TextField(tr(section == 0 ? "Add a prayer request" : "Write a reflection"), text: $draft, axis: .vertical)
                        .font(.hs(15))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.overlay(0.10), lineWidth: 1))
                    Button { add() } label: {
                        T("Add").font(.hs(14, .semibold)).foregroundStyle(HS.onGold).padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Capsule().fill(HS.goldButton))
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                List {
                    if section == 0 {
                        ForEach($store.prayers) { $p in
                            HStack {
                                Button { p.answered.toggle() } label: {
                                    Image(systemName: p.answered ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(p.answered ? HS.body : HS.textMuted)
                                }
                                .buttonStyle(.plain)
                                D(p.text).font(.hs(15)).foregroundStyle(HS.text).strikethrough(p.answered)
                            }
                            .listRowBackground(HS.cardFill)
                        }
                        .onDelete { store.prayers.remove(atOffsets: $0) }
                    } else {
                        let visible = visibleJournal
                        ForEach(visible) { e in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.created, style: .date).font(.hs(12)).foregroundStyle(HS.peach)
                                D(e.text).font(.hs(15)).foregroundStyle(HS.text)
                            }
                            .listRowBackground(HS.cardFill)
                        }
                        .onDelete { offs in let ids = offs.map { visible[$0].id }; store.journal.removeAll { ids.contains($0.id) } }
                        let hidden = store.journal.count - visible.count
                        if hidden > 0 {
                            Button { paywall = true } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    D(hidden == 1 ? tr("👑 1 older entry") : tr("👑 \(hidden) older entries")).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                    T("Free shows your last 7 days. Everything you wrote is safe on this phone, and any plan opens your whole journal.")
                                        .font(.hs(13)).foregroundStyle(HS.textMuted)
                                }
                            }
                            .listRowBackground(HS.goldButton.opacity(0.16))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .padding(20)
        }
        .sheet(isPresented: $paywall) { PlansView(feature: .journalHistory) }
        .navigationTitle(tr(section == 0 ? "Prayer List" : "Faith Journal"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if section == 0 { store.prayers.insert(PrayerItem(text: t), at: 0) }
        else { store.journal.insert(JournalEntry(text: t), at: 0) }
        draft = ""
    }
}
