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
    @State private var showSearch = false
    @State private var showVerseImage = false
    @State private var showNotifications = false
    @ObservedObject private var inbox = NotificationInbox.shared
    @State private var route: HomeRoute?
    @State private var playing: Sermon?
    @State private var showGoal = false
    @Environment(\.openURL) private var openURL

    enum HomeRoute: Hashable, Identifiable {
        case sleep, recap, prayer, journal, quiz, calmCheck, walk, memory, season(String), bible(String?, Int?, Int?)
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
                    hero
                    nextUp.padding(.horizontal, 16)
                    SeasonHomeCard { route = .season($0.id) }.padding(.horizontal, 16)
                    rings.padding(.horizontal, 16)
                    verseCard.padding(.horizontal, 16)
                    tiles.padding(.horizontal, 16)
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
                        case .season(let id): if let w = SeasonWalks.all.first(where: { $0.id == id }) { SeasonWalkView(walk: w) }
                        case .bible(let b, let c, let v): BibleReaderView(startBook: b, startCh: c, startVerse: v)
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
            .fullScreenCover(item: $playing) { s in SermonPlayerView(sermon: s) }
            .task {
                await inbox.refresh()
                await steps.refresh()
                week.refresh(store: store, stepsToday: steps.today)
            }
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
                    T(male ? "Your faith, body, mind & strength" : "Your faith, body, mind & cycle")
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

    private struct RingItem: Identifiable { let label: String; let value: String; let hex: UInt32; let progress: Double; var id: String { label } }

    /// Where each "Right now" pick goes. Android's guided-audio screen isn't on iPhone yet, so "audio" opens Faith → Listen.
    private func openRightNow(_ r: RightNow.Route) {
        switch r {
        case .verses: ActivityLog.shared.add(.verse); openVerse(AppContent.verseOfTheDay().ref)
        case .audio: router.open(tab: 1, faith: 2)
        case .faith: router.open(tab: 1, faith: 0)
        case .calmCheck: route = .calmCheck
        case .walk: route = .walk
        case .journal: route = .journal
        case .sleep, .morningLight: route = .sleep
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
        if !male, let day = rhythm.cycleDay, let phase = rhythm.phase {
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
        let cycleTitle = male ? "Wellness" : "Cycle"
        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                tile("Faith", "Pray, read and listen", "hands.sparkles.fill", 0xF3D5C0, 0xC77D92) { router.open(tab: 1, faith: 0) }
                tile("Fitness", "Steps and walks", "figure.walk", 0x56B892, 0x7FA86A) { router.open(tab: 2) }
            }
            HStack(spacing: 14) {
                tile(cycleTitle, male ? "Strength and energy" : "Your rhythm, day by day", male ? "dumbbell" : "camera.macro", 0xE57A9E, 0xD27C86) { router.open(tab: 3) }
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
            Button { router.open(tab: 1, faith: 3) } label: { T("Safety help").font(.hs(13)).foregroundStyle(HS.textMuted) }
            Spacer()
        }
        .padding(.horizontal, 6)
    }
}

/// Reads a verse aloud in the app's language: Grace's Kokoro recording when the app ships one for it
/// (Resources/verses, made by tools/gen_verses.py), otherwise the phone's own voice.
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
        let u = AVSpeechUtterance(string: Narration.spoken(text))
        u.voice = AVSpeechSynthesisVoice(language: I18n.shared.speechLanguage)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synth.speak(u)
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
