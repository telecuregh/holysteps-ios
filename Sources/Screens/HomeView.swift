import SwiftUI
import UIKit
import AVFoundation

/// Home, as one scroll (the clarity plan): the greeting with the avatar, search and theme switch; the "Right now" pick
/// and first-week steps; today's rings; today's verse; four big tiles (Faith, Fitness, Wellness or Cycle,
/// Sleep); "This week" from day 7; and 988 and safety help at the bottom. Everything longer lives on the tabs.
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var appearance: Appearance
    @ObservedObject private var steps = StepsModel.shared
    @ObservedObject private var week = FirstWeek.shared
    @ObservedObject private var sermons = SermonWeek.shared
    @ObservedObject private var log = ActivityLog.shared
    @ObservedObject private var router = TabRouter.shared
    @ObservedObject private var devState = DevotionalState.shared
    @ObservedObject private var checkIns = CheckInStore.shared
    @ObservedObject private var learning = Learning.shared
    @State private var learned: Learning.Analysis?
    @State private var shortcutKeys: [String] = []
    @State private var showCheckIn = false
    @State private var showSearch = false
    @State private var showVerseImage = false
    @State private var showNotifications = false
    @ObservedObject private var inbox = NotificationInbox.shared
    @State private var route: HomeRoute?
    @State private var playing: Sermon?
    @State private var showGoal = false
    @Environment(\.openURL) private var openURL

    enum HomeRoute: Hashable, Identifiable {
        case sleep, recap, prayer, journal, quiz, calmCheck, walk, memory, devotional, sanctuary, faithCoach, circles, season(String), bible(String?, Int?, Int?)
        case feature(String), aboutYou
        var id: String { "\(self)" }
    }

    private var male: Bool { store.gender == "male" }
    private var name: String { store.name.isEmpty ? (male ? "Brother" : "Sister") : store.name }
    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning, {0}" : (h < 17 ? "Good afternoon, {0}" : "Good evening, {0}")
        return tr(part).replacingOccurrences(of: "{0}", with: name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Only what this person does: the one thing for right now, what they usually do about now, today's
                    // four steps, the shortcuts they use most, and today's verse. Everything else lives on the tabs.
                    hero
                    nextUp.padding(.horizontal, 16)
                    forYou.padding(.horizontal, 16)
                    SeasonHomeCard { route = .season($0.id) }.padding(.horizontal, 16)
                    dailyPlanCard.padding(.horizontal, 16)
                    shortcuts.padding(.horizontal, 16)
                    verseCard.padding(.horizontal, 16)
                    if week.dayNumber >= 7 || week.done.contains(7) { weekStrip.padding(.horizontal, 16) }
                    footer.padding(.horizontal, 16).padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .background(HSBackground())
            .toolbar(.hidden, for: .navigationBar)
            // Home's screens open full screen with their own navigation and a back button.
            .fullScreenCover(item: $route) { r in
                NavigationStack {
                    Group {
                        switch r {
                        case .sleep: SleepView()
                        case .recap: WeeklyRecapView()
                        case .prayer: PrayerJournalView(section: 0)
                        case .journal: PrayerJournalView(section: 1)
                        case .quiz: BibleQuizView()
                        case .calmCheck: CalmCheckView()
                        case .walk: WalkSetupView()
                        case .memory: VerseMemoryView()
                        case .devotional: DevotionalView()
                        case .sanctuary: AudioPrayerView()
                        case .faithCoach: FaithCoachView()
                        case .circles: CirclesView()
                        case .season(let id): if let w = SeasonWalks.all.first(where: { $0.id == id }) { SeasonWalkView(walk: w) }
                        case .bible(let b, let c, let v): BibleReaderView(startBook: b, startCh: c, startVerse: v)
                        case .feature(let title):
                            if let f = AppFeature.all(gender: store.gender).first(where: { $0.title == title }), case .view(let make) = f.target { make() }
                        case .aboutYou: AboutYouView()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { route = nil } label: { Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)) }
                                .accessibilityLabel(tr("Back"))
                        }
                    }
                }
                .environmentObject(store)
                .environmentObject(appearance)
                .environmentObject(I18n.shared)
            }
            .sheet(isPresented: $showSearch) { AppSearchView() }
            .sheet(isPresented: $showVerseImage) { VerseImageView(card: verseCardData) }
            .sheet(isPresented: $showNotifications) { NotificationsView() }
            .sheet(isPresented: $showGoal) { StepGoalSheet() }
            .sheet(isPresented: $showCheckIn) { CheckInSheet() }
            .fullScreenCover(item: $playing) { s in SermonPlayerView(sermon: s) }
            .task {
                // What's learned is on this phone: show it first, before anything waits on the network or Health.
                learned = learning.analyze(store: store)
                shortcutKeys = learning.shortcuts(gender: store.gender)
                await inbox.refresh()
                await steps.refresh()
                week.refresh(store: store, stepsToday: steps.today)
                learned = learning.analyze(store: store)
            }
            .onChange(of: learning.events.count) { learned = learning.analyze(store: store) }
            .onChange(of: checkIns.all.count) { learned = learning.analyze(store: store) }
            .onChange(of: log.days) { week.refresh(store: store, stepsToday: steps.today) }
            .onChange(of: steps.today) { week.refresh(store: store, stepsToday: steps.today) }
            .onChange(of: store.journal.count) { week.refresh(store: store, stepsToday: steps.today) }
            .onChange(of: store.periodStarts.count) { week.refresh(store: store, stepsToday: steps.today) }
        }
    }

    // MARK: Greeting

    private var hero: some View {
        let light = HS.isLight
        let ink = light ? Color(hex: 0x3A3135) : Color.white
        let chip = light ? Color.white.opacity(0.82) : Color(hex: 0x140C18).opacity(0.55)
        let chipEdge = light ? Color(hex: 0x3A3135).opacity(0.18) : Color.white.opacity(0.35)
        return ZStack(alignment: .bottom) {
            // The photo fills the width without widening the page (an image's own size never sets the layout).
            Color.clear.frame(height: 318 + safeTop).frame(maxWidth: .infinity)
                .overlay(alignment: .top) { Image(light ? "home_hero_light" : "home_hero_woman").resizable().scaledToFill() }
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.5), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            LinearGradient(stops: [.init(color: light ? Color.white.opacity(0.45) : Color.black.opacity(0.5), location: 0),
                                   .init(color: .clear, location: light ? 0.25 : 0.28)], startPoint: .top, endPoint: .bottom)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    HolyStepsMark().frame(width: 22, height: 22)
                    D("HolySteps").font(.hs(17)).foregroundStyle(light ? Color(hex: 0x3A3135) : Color.white.opacity(0.88))
                    Spacer()
                    chipButton(ink: ink, fill: chip, edge: chipEdge, label: "Search") { showSearch = true } content: {
                        Image(systemName: "magnifyingglass").font(.system(size: 15))
                    }
                    let all = ThemeMode.allCases
                    let next = all[((all.firstIndex(of: appearance.mode) ?? 0) + 1) % all.count]
                    chipButton(ink: ink, fill: chip, edge: chipEdge, label: "Switch theme") { appearance.mode = next } content: {
                        T(next.emoji).font(.system(size: 14))
                    }
                    chipButton(ink: ink, fill: chip, edge: chipEdge, label: inbox.unseen > 0 ? "Notifications, new" : "Notifications") { showNotifications = true } content: {
                        Image(systemName: "bell").font(.system(size: 15))
                            .overlay(alignment: .topTrailing) {
                                if inbox.unseen > 0 {
                                    Circle().fill(Color(hex: 0xE5484D)).frame(width: 8, height: 8)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 1)).offset(x: 3, y: -2)
                                }
                            }
                    }
                }
                .padding(.top, safeTop).padding(.leading, 20).padding(.trailing, 16)
                Spacer()
                VStack(spacing: 4) {
                    D(greeting).font(.hs(14, light ? .semibold : .regular)).tracking(0.4)
                        .foregroundStyle(light ? Color(hex: 0x2E2529) : Color.white.opacity(0.85))
                        .padding(.horizontal, light ? 14 : 0).padding(.vertical, light ? 4 : 0)
                        .background(Capsule().fill(light ? Color.white.opacity(0.85) : .clear))
                    T(male ? "Your faith, body, mind & strength" : Vitality.isOn ? "Your faith, body, mind & vitality" : "Your faith, body, mind & cycle")
                        .font(.hs(18)).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(light ? Color(hex: 0x3A3135) : Color.white.opacity(0.92))
                    ItalicAccent(text: "working together as one", size: 23)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.bottom, 10)
            }
        }
        .frame(height: 318 + safeTop)
    }

    private var safeTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0
    }

    private func chipButton<C: View>(ink: Color, fill: Color, edge: Color, label: String, action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            content().foregroundStyle(ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(fill))
                .overlay(Circle().strokeBorder(edge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr(label))
    }

    // MARK: Next up

    @ViewBuilder private var nextUp: some View {
        RightNowCard { openRightNow($0) }
        if let day = week.step {
            VStack(spacing: 12) {
                FirstWeekCard(day: day) { go(firstWeek: $0) }
                if day == 7 { FreeWeekPanel() }
            }
        }
    }

    // MARK: For you

    /// What HolySteps has learned about this person (Learning, on this phone only), kept to one small block:
    /// up to three things they usually do about now, the strongest pattern in their own days, and a reminder offer.
    /// Until there's enough to go on, how far along the learning is and a 10-second check-in to teach it.
    @ViewBuilder private var forYou: some View {
        if let a = learned ?? Optional(learning.analysisForHome(store: store)), a.on {
            let labels = Learning.labels(gender: store.gender)
            let finding = a.findings.first
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    T(a.now.isEmpty ? "For you" : "For you now").font(.hs(16, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { route = .aboutYou } label: { T("About you ›").font(.hs(12, .semibold)).foregroundStyle(HS.faith) }
                }
                if !a.now.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(a.now, id: \.id) { r in
                                if let l = labels[r.key] {
                                    Button { openLearned(r.key) } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Image(systemName: l.symbol).foregroundStyle(HS.mind)
                                                T(l.title).font(.hs(14, .semibold)).foregroundStyle(HS.text).lineLimit(1)
                                            }
                                            D(tr("Usually") + " " + RhythmsLogic.clock(r.minute)).font(.hs(11)).foregroundStyle(HS.textMuted)
                                        }
                                        .padding(12).frame(minWidth: 132, alignment: .leading)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.mind.opacity(0.14)))
                                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.mind.opacity(0.35)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                if let f = finding {
                    Button { route = .aboutYou } label: {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                D(tr("WHAT YOUR DAYS SHOW") + " · " + tr(f.confidence.label).uppercased()).font(.hs(10, .semibold)).tracking(1).foregroundStyle(HS.faith)
                                D(f.emoji + " " + tr(f.title)).font(.hs(15, .semibold)).foregroundStyle(HS.text).multilineTextAlignment(.leading)
                                D(tr(f.detail)).font(.hs(13)).foregroundStyle(HS.textSecondary).lineLimit(3).multilineTextAlignment(.leading)
                                if let tip = f.suggestion { D(tr("Try:") + " " + tr(tip)).font(.hs(13)).foregroundStyle(HS.text).multilineTextAlignment(.leading) }
                                T("Learned on this phone only · see everything ›").font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                } else if a.offer == nil && a.now.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            T("✨ Getting to know you").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            D(a.daysLearned <= 1
                              ? tr("Use HolySteps as you normally do and check in once a day. In about a week, what helps you, your routines and your best times show up right here.")
                              : tr("Day {0} of learning. Keep checking in: the more days it sees, the more it can tell you about what helps you.")
                                .replacingOccurrences(of: "{0}", with: "\(a.daysLearned)"))
                                .font(.hs(13)).foregroundStyle(HS.textSecondary)
                            HStack(spacing: 10) {
                                Button { showCheckIn = true } label: {
                                    T("Check in (10 sec)").font(.hs(14, .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.mind))
                                }
                                Button { route = .aboutYou } label: { T("About you").font(.hs(14)).foregroundStyle(HS.faith) }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let r = a.offer, let l = labels[r.key] {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            D("🔔 " + tr(l.title)).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            D(tr("You've done this around {0} on {1} of the last 28 days. Want a gentle reminder then?")
                                .replacingOccurrences(of: "{0}", with: RhythmsLogic.clock(r.minute)).replacingOccurrences(of: "{1}", with: "\(r.days)"))
                                .font(.hs(13)).foregroundStyle(HS.textSecondary)
                            HStack(spacing: 10) {
                                Button { learning.remind(r, title: l.title); learned = learning.analyze(store: store) } label: {
                                    T("Yes, remind me").font(.hs(14, .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.mind))
                                }
                                Button { learning.decline(r.id); learned = learning.analyze(store: store) } label: { T("No thanks").font(.hs(14)).foregroundStyle(HS.textMuted) }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    /// The six things this person uses most (learned on this phone; their onboarding picks until then). Same place,
    /// same order all day.
    @ViewBuilder private var shortcuts: some View {
        let labels = Learning.labels(gender: store.gender)
        let keys = (shortcutKeys.isEmpty ? learning.shortcuts(gender: store.gender) : shortcutKeys).filter { labels[$0] != nil }
        if !keys.isEmpty {
            GlassCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        T("Your shortcuts").font(.hs(13, .semibold)).foregroundStyle(HS.textMuted)
                        Spacer()
                        T("What you use most").font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(keys, id: \.self) { k in
                            if let l = labels[k] {
                                Button { openLearned(k) } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.08))
                                            Image(systemName: l.symbol).font(.system(size: 20)).foregroundStyle(HS.gold)
                                        }.frame(height: 48)
                                        T(l.title).font(.hs(11, .medium)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Opens a learned shortcut the way search would.
    private func openLearned(_ key: String) {
        if key == "move:walk" { route = .walk; return }
        let title = String(key.dropFirst("open:".count))
        Learning.shared.recordOpen(title)
        guard let f = AppFeature.all(gender: store.gender).first(where: { $0.title == title }) else { return }
        switch f.target {
        case .tab(let t, let faith): router.open(tab: t, faith: faith)
        case .sleep: route = .sleep
        case .view: route = .feature(title)
        }
    }

    private struct RingItem: Identifiable { let label: String; let value: String; let hex: UInt32; let progress: Double; var id: String { label } }

    /// Where each "Right now" pick goes. Android's guided-audio screen isn't on iPhone yet, so "audio" opens Faith → Listen.
    private func openRightNow(_ r: RightNow.Route) {
        switch r {
        case .verses: ActivityLog.shared.add(.verse); openVerse(AppContent.verseOfTheDay().ref)
        case .audio: router.open(tab: 1, faith: 3)
        case .faith: router.open(tab: 1, faith: 0)
        case .calmCheck: route = .calmCheck
        case .walk: route = .walk
        case .journal: route = .journal
        case .sleep: route = .sleep
        case .morningLight: route = .feature("Morning light")
        }
    }

    private func go(firstWeek day: Int) {
        switch day {
        case 1:
            if !log.did(.verse, on: AppStore.dayKey()) { listenToVerse() }
            else { router.open(tab: 2) }
        case 2: playing = SleepLibrary.byId(SleepLibrary.shortPrayer)
        case 3: route = .sleep
        case 4: if store.gender == "female" { router.open(tab: 3) } else { showGoal = true }
        case 5: playing = sermons.current()
        case 6: route = QuizLog.shared.log[AppStore.dayKey()] == nil ? .quiz : .journal
        default: route = .recap
        }
    }

    // MARK: Rings

    private var rings: some View {
        let goal = max(1, store.stepGoal)
        let prayers = store.prayerDoneToday.filter { $0 }.count
        let rhythm = Rhythm(store: store)
        var items: [RingItem] = [
            RingItem(label: "Steps", value: steps.today.formatted(), hex: 0x56B892, progress: min(1, Double(steps.today) / Double(goal))),
            RingItem(label: "Prayer", value: "\(prayers)/4", hex: 0x9D7FEA, progress: Double(prayers) / 4),
        ]
        if rhythm.postMeno {
            // Past menopause: the week's Vitality targets (strength, balance, active minutes), Android's vitalityProgress.
            let w = Vitality.week()
            let p = [Double(w.strengthDays) / Double(Vitality.strengthTarget), Double(w.balance) / Double(Vitality.balanceTarget),
                     Double(w.minutes) / Double(Vitality.activeMinutesTarget)].map { min(1, $0) }.reduce(0, +) / 3
            items.append(RingItem(label: "Vitality", value: tr(Vitality.focus().label), hex: 0x14B8A6, progress: p))
        } else if !male, let day = rhythm.cycleDay, let phase = rhythm.phase {
            items.append(RingItem(label: phase.label, value: tr("Day {0}").replacingOccurrences(of: "{0}", with: "\(day)"), hex: 0xE57A9E,
                                  progress: min(1, Double(day) / Double(max(1, store.cycleLength)))))
        } else if let m = steps.sleepLastNight {
            items.append(RingItem(label: "Sleep", value: "\(m / 60)h \(String(format: "%02d", m % 60))m", hex: 0x64A5E8, progress: min(1, Double(m) / 480)))
        }
        return GlassCard(warm: true) {
            VStack(spacing: 14) {
                T("TODAY'S HARMONY").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach).frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(items) { it in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().stroke(Color(hex: it.hex).opacity(0.18), lineWidth: 12)
                                Circle().stroke(HS.overlay(0.08), lineWidth: 5)
                                Circle().trim(from: 0, to: max(0.001, it.progress)).stroke(Color(hex: it.hex).opacity(0.7 + 0.3 * it.progress), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                D(it.value).font(.hs(14, .semibold)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 10)
                            }
                            .frame(width: 84, height: 84)
                            T(it.label).font(.hs(12)).foregroundStyle(HS.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: Daily Plan

    private struct PlanRow: Identifiable {
        let id: Int
        let emoji: String; let title: String; let subtitle: String; let done: Bool
        let action: () -> Void
    }

    private var dailyPlanCard: some View {
        let prayDone  = store.prayerDoneToday.contains(true)
        let devoDone  = devState.readToday
        let walkDone  = steps.today >= store.stepGoal
        let checkDone = checkIns.today != nil || store.journaledToday
        let items: [PlanRow] = [
            PlanRow(id: 0, emoji: "🙏", title: "Pray",
                    subtitle: prayDone ? "Prayer logged" : "Start with a short prayer",
                    done: prayDone, action: { router.open(tab: 1, faith: 0) }),
            PlanRow(id: 1, emoji: "📖", title: "Devotional",
                    subtitle: devoDone ? "Day \(max(1, devState.day - 1)) · done today" : "Day \(devState.day) of your plan",
                    done: devoDone, action: { route = .devotional }),
            PlanRow(id: 2, emoji: "👣", title: "Walk",
                    subtitle: walkDone ? "Goal reached · \(steps.today.formatted()) steps" : "\(steps.today.formatted()) / \(store.stepGoal.formatted()) steps",
                    done: walkDone, action: { router.open(tab: 2) }),
            PlanRow(id: 3, emoji: male ? "⚡" : "🌸", title: "Check in",
                    subtitle: checkDone ? "Logged — see your trends" : "10 seconds: mood, energy, peace",
                    done: checkDone, action: { if checkDone { route = .feature("Life & Health Trends") } else { showCheckIn = true } }),
        ]
        let doneCount = items.filter { $0.done }.count
        let perfect   = doneCount == 4
        return GlassCard {
            VStack(spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        T(perfect ? "Perfect Day complete! 🌟" : "\(doneCount) of 4 complete")
                            .font(.hs(15, .semibold)).foregroundStyle(perfect ? HS.gold : HS.text)
                        T("Finish all 4 for a Perfect Day · +50 pts")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(HS.gold.opacity(0.18), lineWidth: 6)
                        Circle().trim(from: 0, to: CGFloat(doneCount) / 4)
                            .stroke(HS.gold.opacity(0.8), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        T("\(doneCount)/4").font(.hs(12, .semibold)).foregroundStyle(HS.text)
                    }.frame(width: 48, height: 48)
                }
                ForEach(items) { item in
                    Button(action: item.action) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(item.done ? HS.body.opacity(0.18) : HS.overlay(0.06))
                                Circle().strokeBorder(item.done ? HS.body.opacity(0.6) : HS.overlay(0.15), lineWidth: 1)
                                T(item.done ? "✓" : item.emoji)
                                    .font(item.done ? .hs(13, .bold) : .hs(12))
                                    .foregroundStyle(item.done ? HS.body : HS.text)
                            }.frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                T(item.title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                T(item.subtitle).font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            if !item.done {
                                T("›").font(.hs(20)).foregroundStyle(HS.textMuted)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(item.done ? HS.body.opacity(0.08) : HS.overlay(0.04)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Verse

    private var verseCardData: VerseCard {
        let v = AppContent.verseOfTheDay()
        return VerseCard(text: v.shown, ref: tr(v.ref), translation: I18n.shared.spanish ? "RVES" : "KJV", attribution: "", label: "Today's verse")
    }

    private var verseCard: some View {
        let v = AppContent.verseOfTheDay()
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("TODAY'S VERSE").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                D("“\(v.shown)”").font(.accent(19)).foregroundStyle(HS.text).lineSpacing(5)
                HStack(spacing: 14) {
                    D("— \(tr(v.ref))").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                    Spacer(minLength: 4)
                    ShareLink(item: VerseShare.text(v.shown, tr(v.ref))) { T("Share ↗").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                        .simultaneousGesture(TapGesture().onEnded { ActivityLog.shared.add(.verse) })
                    Button { route = .memory } label: { T("Memorize →").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                        .buttonStyle(.plain)
                }
                HStack(spacing: 10) {
                    verseButton("Open", "book") { ActivityLog.shared.add(.verse); openVerse(v.ref) }
                    verseButton("Listen", "speaker.wave.2") { listenToVerse() }
                    verseButton("Image", "photo") { ActivityLog.shared.add(.verse); showVerseImage = true }
                }
            }
        }
    }

    private func verseButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { T(title) } icon: { Image(systemName: symbol) }
                .font(.hs(13, .semibold)).foregroundStyle(HS.text)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Capsule().fill(HS.overlay(0.07)))
                .overlay(Capsule().strokeBorder(HS.gold.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func openVerse(_ ref: String) {
        // "Psalm 121:1-2" → Psalms, 121, 1
        let parts = ref.split(separator: " ")
        guard let last = parts.last else { return }
        var book = parts.dropLast().joined(separator: " ")
        if book == "Psalm" { book = "Psalms" }
        let cv = last.split(separator: ":")
        let ch = Int(cv.first ?? "")
        let verse = cv.count > 1 ? Int(cv[1].split(separator: "-").first ?? "") : nil
        route = .bible(Bible.canonNames.contains(book) ? book : nil, ch, verse)
    }

    private func listenToVerse() {
        ActivityLog.shared.add(.verse)
        let v = AppContent.verseOfTheDay()
        VerseSpeaker.shared.speak("\(v.shown) \(tr(v.ref))", recording: "verse_\(v.id)_\(I18n.shared.spanish ? "es" : "en")")
    }

    // MARK: Tiles

    private var tiles: some View {
        let cycleTitle = male ? "Men" : Vitality.isOn ? "Vitality" : "Women"
        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                tile("Faith", "Pray, read and listen", "hands.sparkles.fill", 0xF3D5C0, 0xC77D92) { router.open(tab: 1, faith: 0) }
                tile("Fitness", "Steps and walks", "figure.walk", 0x56B892, 0x7FA86A) { router.open(tab: 2) }
            }
            HStack(spacing: 14) {
                tile(cycleTitle, male ? "Strength and energy" : Vitality.isOn ? "Strength, balance and this season" : "Your rhythm, day by day",
                     male ? "dumbbell" : Vitality.isOn ? "leaf" : "camera.macro", 0xE57A9E, 0xD27C86) { router.open(tab: 3) }
                tile("Sleep", "Stories and night prayers", "moon.stars", 0x64A5E8, 0x5FA3A8) { route = .sleep }
            }
        }
    }

    @ViewBuilder
    private func tile(_ title: String, _ sub: String, _ symbol: String, _ tint: UInt32, _ glow: UInt32, sleepLink: Bool = false, action: @escaping () -> Void = {}) -> some View {
        if sleepLink {
            NavigationLink { SleepView() } label: { tileFace(title, sub, symbol, tint, glow) }.buttonStyle(.plain)
        } else {
            Button(action: action) { tileFace(title, sub, symbol, tint, glow) }.buttonStyle(.plain)
        }
    }

    private func tileFace(_ title: String, _ sub: String, _ symbol: String, _ tint: UInt32, _ glow: UInt32) -> some View {
        Group {
            GlassCard(glow: Color(hex: glow)) {
                VStack(alignment: .leading, spacing: 0) {
                    IconBadge(symbol: symbol, size: 40, tint: tint)
                    T(title).font(.hs(17, .semibold)).foregroundStyle(HS.text).padding(.top, 14)
                    T(sub).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2).padding(.top, 2)
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            }
        }
    }

    // MARK: Quick Access

    private struct ShortcutItem: Identifiable {
        let id: Int; let emoji: String; let label: String; let action: () -> Void
    }

    private var quickAccess: some View {
        let items: [ShortcutItem] = [
            ShortcutItem(id: 0, emoji: "💬", label: "Faith Chat",  action: { route = .faithCoach }),
            ShortcutItem(id: 1, emoji: "🎧", label: "Sanctuary",   action: { route = .sanctuary }),
            ShortcutItem(id: 2, emoji: "🚶", label: "Prayer Walk", action: { route = .walk }),
            ShortcutItem(id: 3, emoji: "📋", label: "Prayer List", action: { route = .prayer }),
            ShortcutItem(id: 4, emoji: "📔", label: "Journal",     action: { route = .journal }),
            ShortcutItem(id: 5, emoji: "⭕", label: "Circles",     action: { route = .circles }),
        ]
        return GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                T("Quick Access").font(.hs(13, .semibold)).foregroundStyle(HS.textMuted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(items) { item in
                        Button(action: item.action) {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.08))
                                    T(item.emoji).font(.hs(22))
                                }.frame(height: 48)
                                T(item.label).font(.hs(11, .medium)).foregroundStyle(HS.text).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: This week and help

    private var weekStrip: some View {
        Button { route = .recap } label: {
            GlassCard(padding: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").font(.system(size: 20)).foregroundStyle(HS.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        T("This week").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T("Your week with God and your body").font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    D("›").font(.hs(22)).foregroundStyle(HS.gold)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "phone").font(.system(size: 13)).foregroundStyle(HS.textMuted)
            if CrisisLine.has988 {
                Button { openURL(URL(string: "tel:988")!) } label: { T("Call or text 988").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
            }
            Button { router.open(tab: 1, faith: 4) } label: { T("Safety help").font(.hs(13)).foregroundStyle(HS.textMuted) }
            Spacer()
        }
        .padding(.horizontal, 6)
    }
}

/// Reads a verse aloud in the app's language: Grace's Kokoro recording when the app ships one for it
/// (Resources/verses, made by tools/gen_verses.py), never the phone's own voice.
@MainActor
final class VerseSpeaker {
    static let shared = VerseSpeaker()
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    func speak(_ text: String, recording: String? = nil) {
        SermonPlayer.shared.stop(); MusicPlayer.shared.stop(); BibleListening.shared.stop()
        synth.stopSpeaking(at: .immediate)
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let name = recording, let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
           let p = try? AVAudioPlayer(contentsOf: url) {
            player = p
            p.play()
            return
        }
        // No recording of this verse: nothing is spoken (the phone's own voice is never used).
    }
}

/// Day 4 of the first week for men (and anyone who hasn't set a gender): a daily step goal.
struct StepGoalSheet: View {
    @AppStorage("stepGoal") private var goal = 8000
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HSSheet(title: "Your step goal") {
            VStack(spacing: 18) {
                D(goal.formatted()).font(.hs(40, .semibold)).foregroundStyle(HS.text)
                T("steps a day").font(.hs(14)).foregroundStyle(HS.textMuted)
                Stepper(tr("Daily goal"), value: $goal, in: 2000...30000, step: 500).foregroundStyle(HS.text)
                GoldButton(title: "Save") { ActivityLog.shared.add(.tracker); dismiss() }
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}

/// Android's HarmonyRingsGraphic: the day's score on a gold outer ring, with four overlapping rings for faith, body,
/// cycle and mind, and the percentage in the middle.
struct HarmonyRings: View {
    let score: Int
    let faith: Double, steps: Double, mind: Double, cycle: Double

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let outerR = cx * 0.90
                let light = HS.isLight
                let outer = Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
                ctx.stroke(outer, with: .color(light ? Color(hex: 0xD9CAC4) : Color.white.opacity(0.10)), lineWidth: 4)
                let sweep = Double(min(100, max(0, score))) / 100 * 360
                if sweep > 0 {
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: cx, y: cy), radius: outerR, startAngle: .degrees(-90), endAngle: .degrees(-90 + sweep), clockwise: false)
                    ctx.stroke(arc, with: .conicGradient(Gradient(colors: [Color(hex: 0xE8C79E), Color(hex: 0xF3D5C0), Color(hex: 0xD9A98C), Color(hex: 0xE8C79E)]),
                                                         center: CGPoint(x: cx, y: cy), angle: .degrees(0)),
                               style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
                let subR = cx * 0.40, off = cx * 0.23, stroke = 4.2
                let rings: [(CGPoint, UInt32, Double)] = [
                    (CGPoint(x: cx - off, y: cy - off), 0x9D7FEA, faith),
                    (CGPoint(x: cx + off, y: cy - off), 0x56B892, steps),
                    (CGPoint(x: cx + off, y: cy + off), 0xE57A9E, cycle),
                    (CGPoint(x: cx - off, y: cy + off), 0x64A5E8, mind),
                ]
                for (c, hex, p) in rings {
                    let a = 0.70 + 0.30 * min(1, max(0, p))
                    let circle = Path(ellipseIn: CGRect(x: c.x - subR, y: c.y - subR, width: subR * 2, height: subR * 2))
                    ctx.stroke(circle, with: .color(Color(hex: hex).opacity(0.18 * a)), lineWidth: stroke * 3)
                    ctx.stroke(circle, with: .color(Color(hex: hex).opacity(a)), lineWidth: stroke)
                }
                let inner = Path(ellipseIn: CGRect(x: cx - cx * 0.27, y: cy - cx * 0.27, width: cx * 0.54, height: cx * 0.54))
                ctx.fill(inner, with: .color(light ? Color.white.opacity(0.85) : Color(hex: 0x1C1820).opacity(0.92)))
                ctx.stroke(inner, with: .color(light ? Color(hex: 0xE2D2CC) : Color.white.opacity(0.16)), lineWidth: 1)
            }
            D("\(score)%").font(.hs(18)).foregroundStyle(HS.text).lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Today's harmony") + " \(score)%")
    }
}

/// Android's StatRing inside the glass look: a thin peach ring (gold on Light) with the value in the middle.
struct StatRing: View {
    let progress: Double
    let value: String
    var body: some View {
        ZStack {
            Circle().stroke(HS.overlay(0.10), lineWidth: 2.7)
            Circle().trim(from: 0, to: min(1, max(0, progress)))
                .stroke(HS.isLight ? Color(hex: 0xC9A14A) : Color(hex: 0xF3D5C0), style: StrokeStyle(lineWidth: 2.7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            D(value).font(.hs(16)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

/// The small pulse line on "Find Your Calm".
struct PulseWaveSpark: View {
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height, mid = h * 0.55
            var p = Path()
            p.move(to: CGPoint(x: 0, y: mid))
            for (x, y) in [(0.22, mid / h), (0.34, 0.15), (0.48, 0.90), (0.62, 0.25), (0.74, mid / h), (1.0, mid / h)] {
                p.addLine(to: CGPoint(x: w * x, y: h * y))
            }
            ctx.stroke(p, with: .color(HS.peach.opacity(0.75)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Android's HolyStepsMark: two flames in a pink → violet → blue and pink → green gradient.
struct HolyStepsMark: View {
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            func flame(_ dx: CGFloat, _ dy: CGFloat) -> Path {
                func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x + dx) * w, y: (y + dy) * h) }
                var p = Path()
                p.move(to: pt(0.40, 0.10))
                p.addCurve(to: pt(0.34, 0.54), control1: pt(0.16, 0.22), control2: pt(0.14, 0.40))
                p.addCurve(to: pt(0.38, 0.94), control1: pt(0.52, 0.66), control2: pt(0.50, 0.80))
                p.addCurve(to: pt(0.48, 0.47), control1: pt(0.64, 0.82), control2: pt(0.68, 0.62))
                p.addCurve(to: pt(0.40, 0.10), control1: pt(0.32, 0.36), control2: pt(0.30, 0.22))
                p.closeSubpath()
                return p
            }
            let left = flame(-0.08, 0.04), right = flame(0.16, -0.04)
            let lg = GraphicsContext.Shading.linearGradient(Gradient(colors: [Color(hex: 0xEFA4B8), Color(hex: 0xB28BE0), Color(hex: 0x7FA8EC)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h))
            let rg = GraphicsContext.Shading.linearGradient(Gradient(colors: [Color(hex: 0xF0A6B9), Color(hex: 0xD8A9C9), Color(hex: 0x8FD0A8)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h))
            var glow = ctx
            glow.opacity = 0.25
            glow.stroke(left, with: lg, lineWidth: w * 0.10)
            glow.stroke(right, with: rg, lineWidth: w * 0.10)
            ctx.fill(left, with: lg)
            ctx.fill(right, with: rg)
        }
        .accessibilityHidden(true)
    }
}
