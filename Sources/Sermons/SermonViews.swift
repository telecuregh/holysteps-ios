import SwiftUI
import UserNotifications

// MARK: - Look

extension Sermon {
    /// The sermon's scene as a sky gradient (Android's SceneKind).
    var sky: [Color] {
        switch scene {
        case "DAWN": return [Color(hex: 0x3B2A4A), Color(hex: 0x8C5A63), Color(hex: 0xE0A57C)]
        case "DAY": return [Color(hex: 0x1E3A5F), Color(hex: 0x3D6E9E), Color(hex: 0x86B3D1)]
        case "DUSK": return [Color(hex: 0x1A1226), Color(hex: 0x4A2E4F), Color(hex: 0xA25E5E)]
        case "NIGHT": return [Color(hex: 0x0B0810), Color(hex: 0x141B33), Color(hex: 0x23305A)]
        case "OCEAN": return [Color(hex: 0x0E1F33), Color(hex: 0x15435E), Color(hex: 0x2F7A8C)]
        case "RAIN": return [Color(hex: 0x15181F), Color(hex: 0x2A3340), Color(hex: 0x4A5666)]
        case "FOREST": return [Color(hex: 0x0E1A14), Color(hex: 0x1F3A2A), Color(hex: 0x3F6B4C)]
        case "MEADOW": return [Color(hex: 0x1F2E1E), Color(hex: 0x4E6B3A), Color(hex: 0xB7A55E)]
        case "MOUNTAIN": return [Color(hex: 0x141824), Color(hex: 0x35405A), Color(hex: 0x7C8AA8)]
        default: return [HS.bgTop, HS.bgMid, HS.bgBottom]
        }
    }
}

// MARK: - The weekly sermon on the Faith tab

struct SermonCard: View {
    @ObservedObject private var week = SermonWeek.shared
    @ObservedObject private var player = SermonPlayer.shared
    @State private var open: Sermon?
    @State private var settings = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    T("THIS WEEK'S SERMON").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                    Spacer()
                    Button { settings = true } label: { Image(systemName: "gearshape").foregroundStyle(HS.textMuted) }
                        .accessibilityLabel(tr("Sermon day"))
                }
                if let s = week.current() {
                    Button { open = s } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                T(s.title).font(.hs(20, .semibold)).foregroundStyle(HS.text)
                                    .multilineTextAlignment(.leading)
                                T(s.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
                                D(s.minutesLabel + (week.heard.contains(s.id) ? " · ✓ " + tr("Heard") : ""))
                                    .font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            Image(systemName: player.sermon == s && player.playing ? "waveform.circle.fill" : "play.circle.fill")
                                .font(.hs(40)).foregroundStyle(HS.goldButton)
                        }
                    }
                    .accessibilityHint(tr("Listen now"))
                    let n = week.daysUntilNext
                    T(n == 0 ? "A new sermon every \(SermonWeekLogic.dayName(week.day))" : (n == 1 ? "New sermon tomorrow" : "New sermon in \(n) days"))
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                HStack(spacing: 8) {
                    NavigationLink { SermonTopicsView() } label: { pill("💬", tr("What you're facing")) }
                    NavigationLink { BibleSermonsView() } label: { pill("📖", tr("Through the Bible")) }
                    NavigationLink { SermonLibraryView() } label: { pill("🎙", tr("All sermons")) }
                }
                if let s = player.sermon, player.active, s != week.current() {
                    Button { open = s } label: {
                        HStack {
                            Image(systemName: player.playing ? "speaker.wave.2.fill" : "pause.fill").foregroundStyle(HS.goldButton)
                            T("Now playing: \(tr(s.title))").font(.hs(12)).foregroundStyle(HS.text).lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
        .sheet(isPresented: $settings) { SermonSettingsView() }
        .task {
            // Ask once for the weekly reminder (it's on by default, as on Android), then keep the next weeks scheduled.
            if !UserDefaults.standard.bool(forKey: "sermonAskedNotify") {
                UserDefaults.standard.set(true, forKey: "sermonAskedNotify")
                if week.remind { SermonReminder.requestPermission() }
            } else {
                SermonReminder.schedule()
            }
        }
    }

    private func pill(_ icon: String, _ s: String) -> some View {
        VStack(spacing: 3) {
            D(icon).font(.hs(16))
            D(s).font(.hs(11, .semibold)).foregroundStyle(HS.text).lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, 4).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
    }
}

struct SermonSettingsView: View {
    @ObservedObject private var week = SermonWeek.shared

    var body: some View {
        HSSheet(title: tr("Weekly sermon"), doneLabel: "Done") {
            Form {
                Section {
                    Picker(tr("Sermon day"), selection: $week.day) {
                        ForEach(1...7, id: \.self) { d in D(tr(SermonWeekLogic.dayName(d))).tag(d) }
                    }
                    Toggle(tr("Remind me on my sermon day"), isOn: $week.remind).tint(HS.goldButton)
                } footer: {
                    T("A new sermon comes each week on your sermon day. The reminder comes at 9 AM.")
                }
                .listRowBackground(HS.card)
            }
            .scrollContentBackground(.hidden)
        }
        .onChange(of: week.remind) { _, on in if on { SermonReminder.requestPermission() } }
    }
}

// MARK: - The player

struct SermonPlayerView: View {
    let sermon: Sermon
    @ObservedObject private var player = SermonPlayer.shared
    @Environment(\.dismiss) private var dismiss

    private var isThis: Bool { player.sermon == sermon }

    var body: some View {
        ZStack {
            LinearGradient(colors: sermon.sky, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.down").font(.hs(20)).foregroundStyle(.white).padding(10) }
                        .accessibilityLabel(tr("Close"))
                    Spacer()
                    if isThis {
                        Button { player.stop(); dismiss() } label: { T("Stop").font(.hs(14)).foregroundStyle(.white.opacity(0.8)).padding(10) }
                    }
                }
                .padding(.horizontal, 8)
                VStack(spacing: 4) {
                    T(sermon.title).font(.hs(26, .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
                    T(sermon.subtitle).font(.hs(13)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24).padding(.bottom, 12)
                transcript
                controls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if !isThis { player.play(sermon) } }
    }

    private var transcript: some View {
        let captions = isThis ? player.captions : sermon.segments.map { if case .speech(let t) = $0 { return tr(t) } else { return "" } }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(captions.enumerated()), id: \.offset) { i, c in
                        if !c.isEmpty {
                            let now = isThis && i == player.index
                            Button { player.jump(to: i) } label: {
                                D(c)
                                    .font(.hs(now ? 20 : 17, now ? .semibold : .regular))
                                    .foregroundStyle(.white.opacity(now ? 1 : 0.55))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .id(i)
                            .accessibilityHint(tr("Play from here"))
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .onChange(of: player.index) { _, i in withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(i, anchor: .center) } }
            .onAppear { if isThis { proxy.scrollTo(player.index, anchor: .center) } }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            ProgressView(value: isThis ? player.progress : 0).tint(HS.goldButton)
            HStack(spacing: 40) {
                Button { player.skip(-1) } label: { Image(systemName: "backward.end.fill").font(.hs(22)) }
                    .accessibilityLabel(tr("Previous paragraph"))
                Button { isThis ? player.toggle() : player.play(sermon) } label: {
                    if isThis && player.loading { ProgressView().frame(width: 64, height: 64) }
                    else {
                        Image(systemName: isThis && player.playing ? "pause.circle.fill" : "play.circle.fill").font(.hs(64))
                    }
                }
                .accessibilityLabel(tr(isThis && player.playing ? "Pause" : "Play"))
                Button { player.skip(1) } label: { Image(systemName: "forward.end.fill").font(.hs(22)) }
                    .accessibilityLabel(tr("Next paragraph"))
            }
            .foregroundStyle(.white)
            HStack {
                D(sermon.minutesLabel).font(.hs(11))
                Spacer()
                if isThis && !player.reader.isEmpty { D("🎙 " + player.reader).font(.hs(11)) }
                if isThis && player.finished { T("✓ Finished").font(.hs(11)) }
            }
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 24)
        .background(Color.black.opacity(0.25))
    }
}

// MARK: - Sermons for what you're facing

private struct SermonTopic: Identifiable {
    let name: String
    let feels: String
    let sermonId: String
    let group: String
    var crisisNote = false
    var id: String { sermonId }
}

private let topicGroups = ["Anxiety and fear", "Low and heavy days", "Stress, anger and rest", "Grief, loss and loneliness",
                           "The past and healing", "Body, self and new seasons"]

private let topics: [SermonTopic] = [
    SermonTopic(name: "Anxiety and worry", feels: "Your mind won't stop racing", sermonId: "facing_01", group: "Anxiety and fear"),
    SermonTopic(name: "Panic attacks", feels: "Your heart races and you can't catch your breath", sermonId: "facing_19", group: "Anxiety and fear"),
    SermonTopic(name: "Fear", feels: "The future scares you", sermonId: "facing_10", group: "Anxiety and fear"),
    SermonTopic(name: "Overthinking", feels: "You can't stop replaying it", sermonId: "facing_11", group: "Anxiety and fear"),
    SermonTopic(name: "Depression", feels: "Heavy days that don't lift", sermonId: "facing_02", group: "Low and heavy days", crisisNote: true),
    SermonTopic(name: "Hopelessness", feels: "It's hard to see a way forward", sermonId: "facing_03", group: "Low and heavy days", crisisNote: true),
    SermonTopic(name: "Low self-worth", feels: "You don't feel like enough", sermonId: "facing_07", group: "Low and heavy days"),
    SermonTopic(name: "Burnout", feels: "You're running on empty", sermonId: "facing_08", group: "Low and heavy days"),
    SermonTopic(name: "Stress and overwhelm", feels: "Everything is too much right now", sermonId: "facing_09", group: "Stress, anger and rest"),
    SermonTopic(name: "Anger", feels: "Your temper is taking over", sermonId: "facing_12", group: "Stress, anger and rest"),
    SermonTopic(name: "Trouble sleeping", feels: "Your mind won't let you rest", sermonId: "facing_13", group: "Stress, anger and rest"),
    SermonTopic(name: "Grief", feels: "You lost someone you love", sermonId: "facing_04", group: "Grief, loss and loneliness"),
    SermonTopic(name: "Heartbreak", feels: "Someone you loved hurt you or left", sermonId: "facing_16", group: "Grief, loss and loneliness"),
    SermonTopic(name: "Loneliness", feels: "You feel alone, even around people", sermonId: "facing_05", group: "Grief, loss and loneliness"),
    SermonTopic(name: "Trauma and painful memories", feels: "The past keeps coming back", sermonId: "facing_14", group: "The past and healing"),
    SermonTopic(name: "Shame and guilt", feels: "You want to hide from everyone", sermonId: "joel_genesis_hiding", group: "The past and healing"),
    SermonTopic(name: "Addiction", feels: "Something has a hold on you", sermonId: "facing_15", group: "The past and healing"),
    SermonTopic(name: "Living with pain or illness", feels: "Your body hurts and it won't stop", sermonId: "facing_18", group: "Body, self and new seasons"),
    SermonTopic(name: "Comparison", feels: "Everyone else seems further ahead", sermonId: "facing_17", group: "Body, self and new seasons"),
    SermonTopic(name: "After having a baby", feels: "You're exhausted and don't feel like yourself", sermonId: "facing_20", group: "Body, self and new seasons", crisisNote: true),
]

/// 988 where it works (and when the country can't be told: HolySteps' home market is the US), else a directory.
enum CrisisLine {
    static let directory = URL(string: "https://findahelpline.com")!
    static var has988: Bool {
        let r = Locale.current.region?.identifier.uppercased() ?? ""
        return r.isEmpty || ["US", "PR", "GU", "VI", "AS", "MP"].contains(r)
    }
}

struct CrisisCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T("Thinking about ending your life?").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                T(CrisisLine.has988 ? "Call or text 988 now. It's free, open all day and night, and you can talk to someone right away."
                  : "Call your local emergency number now, or find a free crisis line in your country.")
                    .font(.hs(13)).foregroundStyle(HS.textSecondary)
                HStack(spacing: 10) {
                    if CrisisLine.has988 {
                        Link(destination: URL(string: "tel:988")!) { linkLabel("Call 988", filled: true) }
                        Link(destination: URL(string: "sms:988")!) { linkLabel("Text 988", filled: false) }
                    } else {
                        Link(destination: CrisisLine.directory) { linkLabel("Find a helpline", filled: true) }
                    }
                }
            }
        }
    }

    private func linkLabel(_ s: String, filled: Bool) -> some View {
        T(s).font(.hs(14, .semibold)).foregroundStyle(filled ? HS.onGold : HS.text)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12).fill(filled ? HS.goldButton : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HS.gold.opacity(filled ? 0 : 0.5), lineWidth: 1))
    }
}

/// Picks what plays for a facing topic: Joel's recording needs sign-in (phase 2), so the preacher's narrated weekly
/// sermon on the same topic plays when there is one; otherwise the phone reads Joel's script.
private func playable(for topic: SermonTopic) -> Sermon? {
    if let n = topic.sermonId.split(separator: "_").last.map(String.init), topic.sermonId.hasPrefix("facing_"),
       let weekly = SermonLibrary.weeklyForFacing[n], let s = SermonLibrary.sermon(weekly) { return s }
    return SermonLibrary.sermon(topic.sermonId)
}

struct SermonTopicsView: View {
    @State private var chosen: SermonTopic?
    @State private var open: Sermon?

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("SERMONS FOR WHAT YOU'RE FACING").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                            T("What are you going through?").font(.hs(24, .light)).foregroundStyle(HS.text)
                            ItalicAccent(text: "you're not the only one", size: 18)
                            T("Pick what's on your heart and listen to a sermon about it, with what the Bible says and how real people got through it.")
                                .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        }
                    }
                    CrisisCard()
                    ForEach(topicGroups, id: \.self) { g in
                        T(g.uppercased()).font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach).padding(.top, 10).padding(.leading, 4)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(topics.filter { $0.group == g }) { t in
                            Button { chosen = t } label: { row(t.name, t.feels) }
                        }
                    }
                    T("More for hard seasons").font(.hs(16, .semibold)).foregroundStyle(HS.text).padding(.top, 14)
                    ForEach(SermonLibrary.seasons) { s in
                        Button { open = s } label: { row(s.title, s.subtitle) }
                    }
                    T("Sermons can bring comfort and hope, but they don't replace care from a doctor or counselor. If what you're feeling lasts more than two weeks or gets in the way of daily life, please talk to one.")
                        .font(.hs(12)).foregroundStyle(HS.textMuted).padding(.vertical, 12)
                }
                .padding(20)
            }
        }
        .navigationTitle(tr("What you're facing"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $chosen) { t in
            let s = playable(for: t)
            var message = tr(t.name) + "\n" + tr(s?.subtitle ?? "") + "\n" + tr("About \(s?.minutesLabel ?? "")")
            if t.crisisNote {
                message += "\n\n" + tr(CrisisLine.has988 ? "If you're thinking about ending your life, please call or text 988 first."
                                        : "If you're thinking about ending your life, please call your local emergency number first.")
            }
            return Alert(title: D(tr(s?.title ?? t.name)), message: D(message),
                         primaryButton: .default(D(tr("Listen now"))) { open = s },
                         secondaryButton: .cancel(D(tr("Choose another"))))
        }
        .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
    }

    private func row(_ title: String, _ sub: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                T(title).font(.hs(16, .semibold)).foregroundStyle(HS.text).multilineTextAlignment(.leading)
                T(sub).font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(HS.gold)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(HS.card.opacity(0.8)))
    }
}

// MARK: - Through the Bible, and every sermon

struct BibleSermonsView: View {
    @ObservedObject private var week = SermonWeek.shared
    @State private var open: Sermon?

    var body: some View {
        let released = week.booksReleased
        ZStack {
            HSBackground()
            List {
                T("One sermon through each book of the Bible, Genesis to Revelation. A new book comes out each week on your sermon day.")
                    .font(.hs(13)).foregroundStyle(HS.textSecondary).listRowBackground(Color.clear)
                ForEach(Array(SermonLibrary.books.enumerated()), id: \.element.id) { i, s in
                    let out = i < released
                    Button { if out { open = s } } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    T(s.title).font(.hs(16, .semibold)).foregroundStyle(out ? HS.text : HS.textMuted)
                                    if i == released - 1 { T("New").font(.hs(11, .bold)).foregroundStyle(HS.onGold)
                                        .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(HS.goldButton)) }
                                }
                                T(s.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            if out { Image(systemName: week.heard.contains(s.id) ? "checkmark.circle.fill" : "play.circle").foregroundStyle(HS.goldButton) }
                            else { T(i == released ? "Next week" : "Coming").font(.hs(11)).foregroundStyle(HS.textMuted) }
                        }
                    }
                    .disabled(!out)
                    .listRowBackground(HS.card.opacity(0.65))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Through the Bible"))
        .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
    }
}

struct SermonLibraryView: View {
    @ObservedObject private var week = SermonWeek.shared
    @State private var open: Sermon?
    @State private var query = ""

    var body: some View {
        let list = SermonLibrary.narratedWeekly.filter {
            query.isEmpty || tr($0.title).localizedCaseInsensitiveContains(query) || tr($0.subtitle).localizedCaseInsensitiveContains(query)
        }
        ZStack {
            HSBackground()
            List(list) { s in
                Button { open = s } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            T(s.title).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                            T(s.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        D(s.minutesLabel).font(.hs(11)).foregroundStyle(HS.textMuted)
                        if week.heard.contains(s.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(HS.body) }
                    }
                }
                .listRowBackground(HS.card.opacity(0.65))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("All sermons"))
        .searchable(text: $query, prompt: D(tr("Search sermons")))
        .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
    }
}

// MARK: - Reminder

/// A reminder at 9 AM on the sermon day, naming that week's sermon. The next eight weeks are scheduled ahead (each
/// with its own sermon), and rescheduled whenever the app opens or the day changes.
enum SermonReminder {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            if ok { Task { @MainActor in schedule() } }
        }
    }

    @MainActor
    static func schedule() {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<8).map { "sermon-week-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let week = SermonWeek.shared
        guard week.remind else { return }
        let cal = Calendar.current
        var date = cal.startOfDay(for: Date())
        var made = 0
        for _ in 0..<70 where made < 8 {
            let epoch = SermonWeekLogic.today(date)
            if SermonWeekLogic.isSermonDay(epoch, week.day),
               let fire = cal.date(bySettingHour: SermonWeek.remindHour, minute: 0, second: 0, of: date), fire > Date(),
               let s = week.current(epoch) {
                let c = UNMutableNotificationContent()
                c.title = tr("This week's sermon is ready 🎙️")
                c.body = tr(s.title) + " · " + s.minutesLabel
                c.sound = .default
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                center.add(UNNotificationRequest(identifier: ids[made], content: c,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                made += 1
            }
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
        }
    }
}

/// Android's WeeklySermonCard (FaithScreen.kt): this week's sermon, when the next comes, and the sermon-day picker.
struct WeeklySermonCard: View {
    var more = false
    @ObservedObject private var week = SermonWeek.shared
    @State private var open: Sermon?
    @State private var picking = false

    var body: some View {
        let today = SermonWeekLogic.today()
        let isDay = SermonWeekLogic.isSermonDay(today, week.day)
        let dayName = tr(SermonWeekLogic.dayName(week.day))
        let next = SermonWeekLogic.daysUntil(today, week.day)
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: isDay ? "New sermon today" : "This week's sermon")
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    if let s = week.current() {
                        Button { open = s } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 0) {
                                    T(s.title).font(.hs(17, .semibold)).foregroundStyle(HS.text).multilineTextAlignment(.leading)
                                    Spacer().frame(height: 4)
                                    T(s.subtitle).font(.hs(13)).lineSpacing(5).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
                                    Spacer().frame(height: 6)
                                    D(tr("Listen") + " · " + s.minutesLabel).font(.hs(13, .semibold)).foregroundStyle(HS.peach)
                                }
                                Spacer(minLength: 0)
                                GoldPlayBadge(size: 38)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(height: 8)
                    D(I18n.shared.spanish
                      ? (isDay ? "Un sermón nuevo cada \(dayName)" : "Un sermón nuevo cada \(dayName) · el próximo en \(next) \(next == 1 ? "día" : "días")")
                      : (isDay ? "A new sermon every \(dayName)" : "A new sermon every \(dayName) · next in \(next) \(next == 1 ? "day" : "days")"))
                        .font(.hs(12)).foregroundStyle(HS.textSubtle)
                    Button { picking.toggle() } label: {
                        T(picking ? "Done" : "Change sermon day").font(.hs(13)).foregroundStyle(HS.peach).frame(minHeight: 44)
                    }
                    if picking {
                        T("Which day do you want your sermon?").font(.hs(13)).foregroundStyle(HS.textMuted)
                        Spacer().frame(height: 6)
                        let short = I18n.shared.spanish ? ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"] : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                        HStack(spacing: 4) {
                            ForEach(1...7, id: \.self) { d in
                                let on = d == week.day
                                Button { week.day = d } label: {
                                    D(short[d - 1]).font(.hs(12, on ? .bold : .regular)).foregroundStyle(on ? HS.onGold : HS.text)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(on ? HS.goldButton : Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tr(SermonWeekLogic.dayName(d)))
                            }
                        }
                        Spacer().frame(height: 8)
                        Toggle(isOn: $week.remind) {
                            D(I18n.shared.spanish ? "Recordármelo el \(dayName) por la mañana" : "Remind me on \(dayName) morning")
                                .font(.hs(14)).foregroundStyle(HS.text)
                        }
                        .tint(HS.goldButton)
                        .frame(minHeight: 44)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
        .task {
            if !UserDefaults.standard.bool(forKey: "sermonAskedNotify") {
                UserDefaults.standard.set(true, forKey: "sermonAskedNotify")
                if week.remind { SermonReminder.requestPermission() }
            } else {
                SermonReminder.schedule()
            }
        }
        .onChange(of: week.remind) { _, on in if on { SermonReminder.requestPermission() } }
    }
}
