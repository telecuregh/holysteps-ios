import SwiftUI
import UIKit

/// Android's HomeScreen (ui/screens/HomeScreen.kt), daytime layout: the hero with the logo and three glass chips, the
/// greeting and "working together as one", Today's Harmony with the four rings, the 2 × 2 pillar grid, the streak card,
/// and the Today / You / Explore sections.
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var appearance: Appearance
    @ObservedObject private var steps = StepsModel.shared
    @ObservedObject private var devotional = DevotionalState.shared
    @ObservedObject private var router = TabRouter.shared
    @State private var homeTab = 0
    @State private var showWaiting = false
    @State private var openPrayer = false

    private var male: Bool { store.gender == "male" }
    private var name: String { store.name.isEmpty ? (male ? "Brother" : "Sister") : store.name }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning, {0}" : (h < 17 ? "Good afternoon, {0}" : "Good evening, {0}")
        return tr(part).replacingOccurrences(of: "{0}", with: name)
    }

    var body: some View {
        let rhythm = Rhythm(store: store)
        let zone = rhythm.zone
        let goal = max(1, Int((Double(store.stepGoal) * zone.zone.stepMultiplier).rounded()))
        let stepProgress = min(1, Double(steps.today) / Double(goal))
        let prayers = store.prayerDoneToday
        let faithProgress = Double(prayers.filter { $0 }.count) / 4
        let checkedIn = male ? false : store.journaledToday
        let mindProgress = (checkedIn ? 0.5 : 0) + (store.journaledToday ? 0.5 : 0)
        let cycleProgress: Double = male ? 0 : (rhythm.cycleDay.map { min(1, Double($0) / Double(max(1, store.cycleLength))) } ?? 0)
        let score = Rhythm.dailyScore(prayers: prayers, devotional: devotional.readToday, journaled: store.journaledToday,
                                      steps: steps.today, stepGoal: store.stepGoal, zone: zone.zone, checkedIn: checkedIn)
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    harmonyCard(score: score, faith: faithProgress, body: stepProgress, mind: mindProgress, cycle: cycleProgress,
                                goal: goal, rhythm: rhythm, zone: zone.zone)
                        .padding(.horizontal, 16).padding(.top, 6)
                    pillars(rhythm: rhythm, zone: zone.zone).padding(.horizontal, 16).padding(.top, 14)
                    if store.prayerStreak == 0 || !prayers.contains(true) { streakCard.padding(.horizontal, 20).padding(.top, 16) }
                    SubTabs(tabs: ["Today", "You", "Explore"], selected: $homeTab).padding(.top, 14)
                    Group {
                        switch homeTab {
                        case 0: todaySection(goal: goal, zone: zone)
                        case 1: youSection(rhythm: rhythm, zone: zone)
                        default: exploreSection
                        }
                    }
                    .padding(.top, 14)
                    Spacer(minLength: 24)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $openPrayer) { PrayerJournalView(section: 0) }
            .sheet(isPresented: $showWaiting) { waitingSheet }
            .task { await steps.refresh() }
        }
    }

    // MARK: Hero

    private var hero: some View {
        let light = HS.isLight
        let ink = light ? Color(hex: 0x3A3135) : Color.white
        let chip = light ? Color.white.opacity(0.82) : Color(hex: 0x140C18).opacity(0.55)
        let chipEdge = light ? Color(hex: 0x3A3135).opacity(0.18) : Color.white.opacity(0.35)
        return ZStack(alignment: .bottom) {
            // The photo (home_hero_woman / home_hero_light) fades into the page; it goes here once the art is added.
            if let photo = UIImage(named: light ? "home_hero_light" : "home_hero_woman") {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(height: 318, alignment: .top).clipped()
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.5), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            }
            LinearGradient(stops: [.init(color: light ? Color.white.opacity(0.45) : Color.black.opacity(0.5), location: 0),
                                   .init(color: .clear, location: light ? 0.25 : 0.28)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                HStack {
                    HolyStepsMark().frame(width: 26, height: 26)
                    D("HolySteps").font(.hs(19, .regular)).foregroundStyle(light ? Color(hex: 0x3A3135) : Color.white.opacity(0.88))
                    Spacer()
                    HStack(spacing: 8) {
                        chipButton(ink: ink, fill: chip, edge: chipEdge, label: "Search") { router.tab = 1 } content: {
                            Image(systemName: "magnifyingglass").font(.system(size: 17))
                        }
                        let all = ThemeMode.allCases
                        let next = all[(all.firstIndex(of: appearance.mode)! + 1) % all.count]
                        chipButton(ink: ink, fill: chip, edge: chipEdge, label: "Switch theme") { appearance.mode = next } content: {
                            T(next.emoji).font(.system(size: 16))
                        }
                        chipButton(ink: ink, fill: chip, edge: chipEdge, label: "Waiting for you today") { showWaiting = true } content: {
                            Image(systemName: "bell").font(.system(size: 18))
                                .overlay(alignment: .topTrailing) {
                                    if !waiting.isEmpty { Circle().fill(HS.goldButton).frame(width: 8, height: 8).offset(x: 3, y: -2) }
                                }
                        }
                    }
                }
                .padding(.top, 44 + safeTop).padding(.leading, 20).padding(.trailing, 16)
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
                .frame(width: 38, height: 38)
                .background(Circle().fill(fill))
                .overlay(Circle().strokeBorder(edge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr(label))
    }

    // MARK: Today's Harmony

    private func harmonyCard(score: Int, faith: Double, body: Double, mind: Double, cycle: Double, goal: Int, rhythm: Rhythm, zone: EnergyZone) -> some View {
        Button { homeTab = 1 } label: {
            GlassCard(warm: true) {
                VStack(spacing: 14) {
                    T("TODAY'S HARMONY").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach).frame(maxWidth: .infinity)
                    HStack(spacing: 18) {
                        HarmonyRings(score: score, faith: faith, body: body, mind: mind, cycle: cycle).frame(width: 124, height: 124)
                        VStack(alignment: .leading, spacing: 0) {
                            T("Step Progress").font(.hs(14)).foregroundStyle(HS.textSecondary)
                            HStack(alignment: .lastTextBaseline, spacing: 0) {
                                D(steps.today.formatted()).font(.hs(18, .semibold)).foregroundStyle(HS.text)
                                D(" " + tr("/ {0} steps").replacingOccurrences(of: "{0}", with: goal.formatted())).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            .padding(.top, 2)
                            HSProgressBar(progress: body).padding(.top, 8)
                            T("Current Season").font(.hs(14)).foregroundStyle(HS.textSecondary).padding(.top, 14)
                            season(rhythm: rhythm, zone: zone).padding(.top, 2)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func season(rhythm: Rhythm, zone: EnergyZone) -> some View {
        if male {
            D("\(tr(rhythm.mens.label)) · \(tr(zone.label))").font(.hs(15, .semibold)).foregroundStyle(HS.peach).lineLimit(2)
        } else if let day = rhythm.cycleDay, let phase = rhythm.phase {
            // "Day 14" stands out; the phase and energy follow in regular weight.
            VStack(alignment: .leading, spacing: 0) {
                D(tr("Day {0}").replacingOccurrences(of: "{0}", with: "\(day)")).font(.hs(15, .semibold))
                D("(\(tr(phase.label + " Phase"))) - \(tr(zone.label))").font(.hs(13)).lineLimit(1).truncationMode(.tail)
            }
            .foregroundStyle(HS.peach)
        } else {
            Button { router.tab = 3 } label: { T("Set up your cycle ›").font(.hs(15, .semibold)).foregroundStyle(HS.peach) }.buttonStyle(.plain)
        }
    }

    // MARK: Pillars

    private func pillars(rhythm: Rhythm, zone: EnergyZone) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                pillar(symbol: "hands.sparkles.fill", tint: 0xF3D5C0, glow: 0xC77D92, title: "Grow in the Word", action: { router.tab = 1 }) {
                    HStack(alignment: .bottom, spacing: 8) {
                        T("Prayer walk: The Road to Emmaus").font(.hs(13)).foregroundStyle(HS.textMuted).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                        GoldPlayBadge(size: 30)
                    }
                }
                pillar(symbol: "figure.run", tint: 0x56B892, glow: 0x7FA86A, title: "Move with Purpose", action: { router.tab = 2 }) {
                    HStack(alignment: .bottom, spacing: 6) {
                        T(zone.label).font(.hs(13)).foregroundStyle(HS.textMuted).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                        D(milesText(steps.today)).font(.hs(12, .medium)).foregroundStyle(HS.peach).lineLimit(1)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 14) {
                pillar(symbol: "figure.mind.and.body", tint: 0x64A5E8, glow: 0x5FA3A8, title: "Find Your Calm", action: { router.tab = 1 }) {
                    HStack(alignment: .bottom, spacing: 6) {
                        VStack(alignment: .leading, spacing: 0) {
                            T("Camera calm check").font(.hs(13)).foregroundStyle(HS.textMuted).lineLimit(1)
                            T("Tap to check pulse").font(.hs(12)).foregroundStyle(HS.textSecondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        PulseWaveSpark().frame(width: 34, height: 20)
                    }
                }
                pillar(symbol: "camera.macro", tint: 0xE57A9E, glow: 0xD27C86, title: "Know Your Season", action: { router.tab = 3 }) {
                    VStack(alignment: .leading, spacing: 0) {
                        D("\(tr("Energy:")) \(tr(zone.label))").font(.hs(13)).foregroundStyle(HS.textMuted).lineLimit(1)
                        D("\(tr("Focus:")) \(tr(male ? rhythm.mens.label : (rhythm.phase.map { $0.label + " Phase" } ?? "Steady day")))")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary).lineLimit(1)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pillar<C: View>(symbol: String, tint: UInt32, glow: UInt32, title: String, action: @escaping () -> Void, @ViewBuilder detail: () -> C) -> some View {
        Button(action: action) {
            GlassCard(glow: Color(hex: glow)) {
                VStack(alignment: .leading, spacing: 0) {
                    IconBadge(symbol: symbol, size: 36, tint: tint)
                    T(title).font(.hs(15, .medium)).tracking(-0.1).foregroundStyle(HS.text).lineLimit(1).padding(.top, 12)
                    detail().padding(.top, 4)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    /// US settings: distance in miles (Android's compactText with a 0.762 m step, STEP_LENGTH_KM).
    private func milesText(_ steps: Int) -> String {
        let mi = Double(steps) * 0.000762 / 1.609344
        return String(format: "%.1f mi", mi)
    }

    // MARK: Streak

    private var streakCard: some View {
        Button { openPrayer = true } label: {
            GlassCard {
                HStack(spacing: 12) {
                    IconBadge(symbol: store.prayerStreak > 0 ? "flame" : "sun.max", size: 38, tint: 0xF3D5C0)
                    VStack(alignment: .leading, spacing: 2) {
                        T(store.prayerStreak > 0 ? "Keep your \(store.prayerStreak)-day streak alive" : "Start a prayer streak today")
                            .font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        T(store.prayerStreak > 0 ? "One prayer today keeps it going" : "Hit 3 days for a +15 bonus, 7 days for +50")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer(minLength: 4)
                    T("Pray →").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Today

    private struct PlanItem: Identifiable {
        let emoji: String, title: String, sub: String, done: Bool, tab: Int
        var id: String { title }
    }

    private func planItems(goal: Int) -> [PlanItem] {
        let prayed = store.prayerDoneToday.contains(true)
        let dayShown = devotional.readToday ? max(1, devotional.day - 1) : devotional.day
        return [
            PlanItem(emoji: "🙏", title: "Pray", sub: prayed ? "Prayer logged" : "Start with a short prayer", done: prayed, tab: 1),
            PlanItem(emoji: "📖", title: "Devotional", sub: devotional.readToday ? "Read today" : "Day \(dayShown) of your plan", done: devotional.readToday, tab: 1),
            PlanItem(emoji: "👣", title: "Walk", sub: "\(steps.today.formatted()) / \(goal.formatted()) steps", done: steps.today >= goal, tab: 2),
            PlanItem(emoji: male ? "⚡" : "🌸", title: "Check in", sub: store.journaledToday ? "Logged — see your trends" : "10 seconds: mood, energy, peace",
                     done: store.journaledToday, tab: 3),
        ]
    }

    private var waiting: [PlanItem] { planItems(goal: store.stepGoal).filter { !$0.done } }

    private func todaySection(goal: Int, zone: (zone: EnergyZone, reason: String)) -> some View {
        let items = planItems(goal: goal)
        let done = items.filter(\.done).count
        let verse = AppContent.verseOfTheDay()
        let hour = Calendar.current.component(.hour, from: Date())
        return VStack(alignment: .leading, spacing: 0) {
            Button { homeTab = 1 } label: {
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            T("About you").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                            T("How you are today, what you're going through, and what we've noticed").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        D("›").font(.hs(22)).foregroundStyle(HS.gold)
                    }
                }
            }
            .buttonStyle(.plain).padding(.horizontal, 20)
            SectionHeader(title: "Today's Walk with God").padding(.top, 4)
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            T(done == 4 ? "Perfect Day complete!" : "\(done) of 4 complete").font(.hs(15, .semibold)).foregroundStyle(done == 4 ? HS.gold : HS.text)
                            T("Finish all 4 for a Perfect Day · +50 pts").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        StatRing(progress: Double(done) / 4, value: "\(done)/4").frame(width: 48, height: 48)
                    }
                    T(zone.zone.label).font(.hs(13, .semibold)).foregroundStyle(HS.text).padding(.top, 10)
                    T(zone.reason).font(.hs(12)).foregroundStyle(HS.textMuted)
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            Button { router.tab = item.tab } label: { planRow(item.emoji, item.title, item.sub, done: item.done) }.buttonStyle(.plain)
                        }
                        if hour >= 19 || hour < 4 {
                            Button { router.tab = 1 } label: { planRow("😴", "Bedtime", "Bible sleep stories, night prayers and kids' stories", done: false) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            SectionHeader(title: "Today's Verse").padding(.top, 8)
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    D("“\(verse.shown)”").font(.accent(15)).foregroundStyle(HS.text).lineSpacing(6)
                    HStack {
                        D("— \(tr(verse.ref))").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                        Spacer()
                        ShareLink(item: "\"\(verse.shown)\" — \(tr(verse.ref))") { T("Share →").font(.hs(12)).foregroundStyle(HS.gold) }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func planRow(_ emoji: String, _ title: String, _ sub: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(done ? HS.body : HS.overlay(0.06))
                Circle().strokeBorder(done ? HS.body : HS.overlay(0.15), lineWidth: 1)
                if done { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(HS.onGold) }
                else { T(emoji).font(.system(size: 12)).foregroundStyle(HS.text) }
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                T(title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                T(sub).font(.hs(11)).foregroundStyle(HS.textMuted)
            }
            Spacer()
            if !done { D("›").font(.hs(20)).foregroundStyle(HS.textMuted) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(done ? HS.body.opacity(0.14) : HS.overlay(0.04)))
        .contentShape(Rectangle())
    }

    // MARK: You

    private func youSection(rhythm: Rhythm, zone: (zone: EnergyZone, reason: String)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Your insights")
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    T(zone.zone.label).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T(zone.reason).font(.hs(13)).foregroundStyle(HS.textMuted)
                    InsightBubble(text: store.prayerStreak > 0 ? "You've prayed \(store.prayerStreak) days in a row." : "Start with a short prayer — it lifts everything else today.")
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Explore

    private var exploreSection: some View {
        ToolSection(title: "Shortcuts", items: [
            ToolItem(symbol: "headphones", color: HS.mind, title: "Sanctuary", sub: "Guided sessions", action: { router.tab = 1 }),
            ToolItem(symbol: "figure.walk", color: HS.body, title: "Prayer Walk", sub: "Walk with purpose", action: { router.tab = 2 }),
            ToolItem(symbol: "checklist", color: HS.peach, title: "Prayer List", sub: "What you're holding", destination: AnyView(PrayerJournalView(section: 0))),
            ToolItem(symbol: "book", color: HS.body, title: "Journal", sub: "Write it down", destination: AnyView(PrayerJournalView(section: 1))),
        ])
    }

    // MARK: Waiting

    private var waitingSheet: some View {
        HSSheet(title: waiting.isEmpty ? "All caught up" : "Waiting for you today") {
            VStack(alignment: .leading, spacing: 4) {
                if waiting.isEmpty { T("Everything on today's plan is done. Well done.").font(.hs(14)).foregroundStyle(HS.textMuted) }
                ForEach(waiting) { w in
                    Button { showWaiting = false; router.tab = w.tab } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                T("\(w.emoji) \(w.title)").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                T(w.sub).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            D("›").font(.hs(20)).foregroundStyle(HS.textMuted)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 4).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(20)
        }
        .presentationDetents([.medium])
    }
}

/// Android's HarmonyRingsGraphic: the day's score on a gold outer ring, with four overlapping rings for faith, body,
/// cycle and mind, and the percentage in the middle.
struct HarmonyRings: View {
    let score: Int
    let faith: Double, body: Double, mind: Double, cycle: Double

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
                    (CGPoint(x: cx + off, y: cy - off), 0x56B892, body),
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
