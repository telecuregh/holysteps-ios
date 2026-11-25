import SwiftUI
import UserNotifications

/// Android's OnboardingScreen (the Faith flow): welcome, who are you, name, season, last period, cycle details,
/// cycle goal, faith walk, tradition, activity, goals, reminder and the plan that's ready.
enum Profile {
    static let faithStages: [(String, String, String, String)] = [
        ("NEW", "🌱", "New to faith", "I'm just starting to explore"),
        ("RETURNING", "🕊️", "Coming back", "I'm returning to God after time away"),
        ("GROWING", "🌿", "Growing", "I believe and want to go deeper"),
        ("ROOTED", "🌳", "Rooted", "Faith is central to my daily life"),
    ]
    static let traditions: [(String, String, String, String)] = [
        ("CATHOLIC", "✝️", "Catholic", "Daily Rosary mystery, saints, and the Hail Mary / Glory Be."),
        ("PROTESTANT", "📖", "Protestant", "Scripture-first prayer with the ACTS model, Adoration, Confession, Thanksgiving, Supplication."),
        ("ORTHODOX", "☦️", "Orthodox", "The Jesus Prayer, the Trisagion, and the saints of the Church."),
        ("NON_DENOMINATIONAL", "🙏", "Non-denominational", "A simple, broadly Christian daily walk with God."),
    ]
    static let cycleGoals: [(String, String, String)] = [
        ("TRACK", "📅", "Track my period"), ("SYMPTOMS", "🌊", "Manage symptoms & mood"), ("CONCEIVE", "👶", "Trying to conceive"),
        ("PREGNANT", "🤰", "I'm pregnant"), ("POSTPARTUM", "🍼", "Just had a baby"), ("WELLNESS", "🌸", "Understand my body"),
    ]
    static let lifeStages: [(String, String, String, String, String)] = [
        ("CYCLING", "🌸", "I have periods", "Regular or irregular, your plan syncs to your cycle", "season_cycling"),
        ("PERIMENOPAUSE", "🌗", "My periods are changing", "Perimenopause, cycles shifting, maybe hot flashes or poorer sleep", "season_perimenopause"),
        ("POSTMENOPAUSE", "🌿", "My periods have stopped", "Menopause, 12 months or more without a period. No cycle tracking; a plan built for this season instead", "season_postmenopause"),
    ]
    static let regularity: [(String, String, String)] = [
        ("REGULAR", "📆", "Regular, about the same each month"), ("IRREGULAR", "🌀", "Irregular, it varies a lot"), ("UNSURE", "🤷‍♀️", "I'm not sure"),
    ]
    static let reminders: [(String, String, String, Int, Int)] = [
        ("MORNING", "🌅", "Morning · 7:00 AM", 7, 0), ("MIDDAY", "☀️", "Midday · 12:30 PM", 12, 30),
        ("EVENING", "🌙", "Evening · 8:00 PM", 20, 0), ("OFF", "🔕", "No reminders", -1, 0),
    ]
    static let freedomGoal = "🔓 Break free from a habit"
    static func goals(male: Bool) -> [String] {
        male ? ["🙏 Deepen my prayer life", "📖 Read the Bible consistently", "💪 Build discipline in faith and fitness",
                "👨‍👩‍👧 Lead my family with faith", "🤝 Find accountability with other men", "⚔️ Become the man God called me to be", freedomGoal]
             : ["🙏 Deepen my prayer life", "📖 Read the Bible consistently", "🌸 Understand my body and wellness",
                "💪 Build daily faith habits", "🕊️ Find peace from anxiety", "✨ Walk in my God-given purpose", freedomGoal]
    }

    static var onboarded: Bool { UserDefaults.standard.bool(forKey: "onboarded") }
    static var lifeStage: String { UserDefaults.standard.string(forKey: "lifeStage") ?? "CYCLING" }
    static var faithStage: String { UserDefaults.standard.string(forKey: "faithStage") ?? "GROWING" }
    static var tradition: String { UserDefaults.standard.string(forKey: "faithTradition") ?? "NON_DENOMINATIONAL" }
    static var cycleGoal: String { UserDefaults.standard.string(forKey: "cycleGoal") ?? "WELLNESS" }
    static var goals: [String] { UserDefaults.standard.stringArray(forKey: "goals") ?? [] }

    /// Plans.kt fittingPlans: their body plan, Faith, and Fitness when the goals or step goal point there.
    static func fittingPlans(male: Bool?, goals: [String], stepGoal: Int) -> [Plan] {
        let g = goals.joined(separator: " ").lowercased()
        func has(_ w: String...) -> Bool { w.contains { g.contains($0) } }
        var out: [Plan] = []
        if male == false { out.append(.cycle) } else if male == true { out.append(.wellness) }
        out.append(.faith)
        if has("walk", "stronger", "fitter", "discipline", "fitness") || stepGoal >= 10_000 { out.append(.fitness) }
        return out
    }

    /// The daily reminder chosen in setup: one local notification a day.
    static func scheduleDaily(_ key: String) async {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["daily"])
        guard let r = reminders.first(where: { $0.0 == key }), r.3 >= 0 else { return }
        guard (try? await c.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = tr("Time with God")
        content.body = tr("Your verse and today's prayer are ready.")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: r.3, minute: r.4), repeats: true)
        try? await c.add(UNNotificationRequest(identifier: "daily", content: content, trigger: trigger))
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    let onDone: () -> Void

    enum Step: CaseIterable { case welcome, gender, name, lifeStage, periodStart, cycleDetails, cycleGoal, faith, tradition, activity, goals, reminder, ready }

    @State private var step = Step.welcome
    @State private var forward = true
    @State private var gender: String?
    @State private var name = ""
    @State private var lifeStage: String?
    @State private var lastPeriod: Date?
    @State private var periodAnswered = false
    @State private var cycleLen = 28
    @State private var periodLen = 5
    @State private var regularity = "REGULAR"
    @State private var cycleGoal: String?
    @State private var faithStage: String?
    @State private var tradition: String?
    @State private var stepGoal = 8000
    @State private var goals: [String] = []
    @State private var reminder = "MORNING"

    private var isFemale: Bool { gender == "female" }
    private var postMenopause: Bool { isFemale && lifeStage == "POSTMENOPAUSE" }
    private var flow: [Step] {
        let cycleSteps: [Step] = [.periodStart, .cycleDetails, .cycleGoal]
        return Step.allCases.filter {
            if !isFemale { return !cycleSteps.contains($0) && $0 != .lifeStage }
            if postMenopause { return !cycleSteps.contains($0) }
            return true
        }
    }

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 0) {
                if step != .welcome {
                    HStack(spacing: 10) {
                        Button { move(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 18)).foregroundStyle(HS.textMuted).frame(width: 40, height: 40) }
                            .accessibilityLabel(tr("Back"))
                        GeometryReader { g in
                            let i = Double(flow.firstIndex(of: step) ?? 0), n = Double(max(1, flow.count - 1))
                            ZStack(alignment: .leading) {
                                Capsule().fill(HS.overlay(0.1))
                                Capsule().fill(LinearGradient(colors: [HS.faith, HS.peach, HS.body], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: g.size.width * i / n)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
                content
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity), removal: .opacity))
            }
        }
    }

    private func move(_ d: Int) {
        guard let i = flow.firstIndex(of: step), flow.indices.contains(i + d) else { return }
        forward = d > 0
        withAnimation(.easeInOut(duration: 0.3)) { step = flow[i + d] }
    }
    private func next() { move(1) }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .gender:
            Scaffold(title: "Who are you?", subtitle: "We'll personalize your devotionals, wellness tracking, and prayer content just for you.",
                     enabled: gender != nil, next: next) {
                genderCard("female", "🌸", "I'm a Woman", "Women's devotionals, cycle wellness tracking, and faith for every phase of life.", 0xEC4899)
                genderCard("male", "⚔️", "I'm a Man", "Men's devotionals, purpose-driven wellness, and faith for the man God called you to be.", 0x3B82F6)
            }
        case .name:
            Scaffold(title: "What's your name?", subtitle: "We'll use it to greet you each day, \(gender == "male" ? "brother" : "sister").",
                     button: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip" : "Continue", next: next) {
                TextField(tr("Your first name"), text: $name)
                    .font(.hs(18)).multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.overlay(0.12), lineWidth: 1))
                    .onChange(of: name) { _, v in if v.count > 30 { name = String(v.prefix(30)) } }
            }
        case .lifeStage:
            Scaffold(title: "Which season\nare you in?", subtitle: "Your plan changes with it, and you can update it anytime in Profile.",
                     enabled: lifeStage != nil, next: next) {
                ForEach(Profile.lifeStages, id: \.0) { s in
                    let sel = lifeStage == s.0
                    Button { lifeStage = s.0 } label: {
                        HStack(spacing: 0) {
                            Image(s.4).resizable().scaledToFill().frame(width: 84, height: 104).clipped().accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                D(s.1 + " " + tr(s.2)).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                T(s.3).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            .padding(.horizontal, 14)
                            Spacer(minLength: 0)
                        }
                        .background(sel ? HS.goldButton.opacity(0.20) : HS.cardFill)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HS.gold.opacity(sel ? 1 : 0.22), lineWidth: sel ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sel ? .isSelected : [])
                }
            }
        case .periodStart: periodStart
        case .cycleDetails:
            Scaffold(title: "Tell us about\nyour cycle", subtitle: "Not sure? Keep the defaults, HolySteps learns your real cycle length each time you log a period.", next: next) {
                stepper("Cycle length", "From the first day of one period to the next", $cycleLen, 21...45)
                stepper("Period length", "How many days you usually bleed", $periodLen, 2...10)
                T("How regular is it?").font(.hs(15, .semibold)).foregroundStyle(HS.text).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                ForEach(Profile.regularity, id: \.0) { r in option(r.1, r.2, "", regularity == r.0) { regularity = r.0 } }
            }
        case .cycleGoal:
            choice("What matters most\nfor your cycle?", "We'll shape your insights and daily tips around this.",
                   Profile.cycleGoals.map { ($0.0, $0.1, $0.2, "") }, $cycleGoal)
        case .faith:
            choice("Where are you\nin your faith walk?", "No wrong answers, devotionals will meet you right here.",
                   Profile.faithStages, $faithStage)
        case .tradition:
            choice("Which tradition\nfeels like home?", "Your Rosary, Jesus Prayer, or scripture-first content will follow this, change it anytime in Profile.",
                   Profile.traditions, $tradition)
        case .activity:
            let levels: [(String, String, String, Int)] = [("🪑", "Getting started", "5,000 steps a day", 5000), ("🚶", "Lightly active", "8,000 steps a day", 8000),
                                                         ("🏃", "Active", "10,000 steps a day", 10000), ("⚡", "Very active", "12,500 steps a day", 12500)]
            Scaffold(title: "How active are you\nright now?", subtitle: "This sets your daily step goal. You can change it anytime.", next: next) {
                ForEach(levels, id: \.3) { l in option(l.0, l.1, l.2, stepGoal == l.3) { stepGoal = l.3 } }
            }
        case .goals:
            Scaffold(title: "What are your goals?", subtitle: "Choose all that matter to you.", enabled: !goals.isEmpty, next: next) {
                ForEach(Profile.goals(male: gender == "male"), id: \.self) { g in
                    let emoji = String(g.prefix { $0 != " " })
                    option(emoji, String(g.dropFirst(emoji.count + 1)), "", goals.contains(g)) {
                        if let i = goals.firstIndex(of: g) { goals.remove(at: i) } else { goals.append(g) }
                    }
                }
            }
        case .reminder:
            Scaffold(title: "When should we\nnudge you to pray?",
                     subtitle: "A gentle daily reminder with your verse and streak. People with a reminder are far more likely to build the habit.", next: next) {
                ForEach(Profile.reminders, id: \.0) { r in option(r.1, r.2, "", reminder == r.0) { reminder = r.0 } }
            }
        case .ready: ready
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    Image("welcome_path").resizable().scaledToFill().frame(height: 190).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true).padding(.top, 20)
                    D("HolySteps").font(.hs(34, .light)).foregroundStyle(HS.text).padding(.top, 6)
                    ItalicAccent(text: "working together as one", size: 21)
                    T("Walk in faith, track your wellness,\ngrow in God every day.").font(.hs(15)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                    ForEach(["🎧  A new sermon every week, through the whole Bible", "🙏  Guided prayer, morning to night",
                             "📝  Prayer list, watch God answer", "📓  Faith Journal", "🌸  Cycle-synced faith & wellness"], id: \.self) { f in
                        T(f).font(.hs(14)).foregroundStyle(HS.text).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.22), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 28)
            }
            GoldButton(title: "Get Started", action: next).padding(.horizontal, 28).padding(.top, 8)
            T("Takes about 1 minute").font(.hs(12)).foregroundStyle(HS.textSubtle).padding(.top, 8).padding(.bottom, 20)
        }
    }

    private var periodStart: some View {
        let cal = Calendar.current
        let days = (0..<45).compactMap { cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: Date())) }
        return Scaffold(title: "When did your last\nperiod start?",
                        subtitle: "Pick the first day of your most recent period. This powers your phase, predictions, and daily tips.",
                        enabled: periodAnswered, next: next) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                        let sel = lastPeriod.map { cal.isDate($0, inSameDayAs: d) } ?? false
                        Button { lastPeriod = d; periodAnswered = true } label: {
                            VStack(spacing: 2) {
                                D(i == 0 ? tr("Today") : d.formatted(.dateTime.weekday(.abbreviated).locale(I18n.shared.locale))).font(.hs(11))
                                    .foregroundStyle(sel ? HS.readable(0xEC4899) : HS.textMuted)
                                D("\(cal.component(.day, from: d))").font(.hs(20, .bold)).foregroundStyle(HS.text)
                                D(d.formatted(.dateTime.month(.abbreviated).locale(I18n.shared.locale))).font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                            .frame(width: 62).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(sel ? HS.goldButton.opacity(0.24) : HS.cardFill))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(sel ? 1 : 0.22), lineWidth: sel ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            T("← swipe for earlier dates").font(.hs(11)).foregroundStyle(HS.textSubtle)
            option("🤔", "I don't remember", "You can log it later from the Cycle tab", periodAnswered && lastPeriod == nil) { lastPeriod = nil; periodAnswered = true }
                .padding(.top, 12)
            if let lp = lastPeriod {
                let ago = cal.dateComponents([.day], from: lp, to: cal.startOfDay(for: Date())).day ?? 0
                D(ago == 0 ? tr("Started today, we'll take gentle care of you 🌹")
                  : tr(ago == 1 ? "That's 1 day ago, you're on cycle day 2" : "That's \(ago) days ago, you're on cycle day \(ago + 1)"))
                    .font(.hs(13, .semibold)).foregroundStyle(HS.readable(0xEC4899)).multilineTextAlignment(.center).padding(.top, 10)
            }
        }
    }

    private var ready: some View {
        let first = name.trimmingCharacters(in: .whitespaces)
        let reminderText = reminder == "OFF" ? tr("off") : tr((Profile.reminders.first { $0.0 == reminder }?.2 ?? "").components(separatedBy: " ·").first ?? "").lowercased()
        let stage = Profile.faithStages.first { $0.0 == (faithStage ?? "GROWING") }!
        let trad = Profile.traditions.first { $0.0 == (tradition ?? "NON_DENOMINATIONAL") }!
        let fits = Profile.fittingPlans(male: gender.map { $0 == "male" }, goals: goals, stepGoal: stepGoal)
        return Scaffold(title: first.isEmpty ? "Your plan is ready ✨" : "\(first), your plan\nis ready ✨",
                        subtitle: "Here's how HolySteps will walk with you every day.", button: "Start My Journey 🙏", next: finish) {
            Image("welcome_shoes").resizable().scaledToFill().frame(height: 150).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true).padding(.bottom, 6)
            planRow("🙏", "Daily prayer", tr("4 guided moments · reminder") + " " + reminderText)
            planRow("📖", "Devotional plan", gender == "male" ? "30 days of strength for men" : "30 days of strength for women")
            planRow("👣", "Step goal", tr("\(stepGoal.formatted()) steps a day"))
            planRow(stage.1, "Your faith walk", stage.2)
            planRow(trad.1, "Your tradition", trad.2)
            if postMenopause {
                planRow("🌿", "Vitality plan", "Strength, balance and heart days built for this season, no cycle tracking")
            } else if isFemale {
                if let lp = lastPeriod {
                    let day = CycleLogic.cycleDay(lastStart: lp, length: cycleLen)
                    let phase = CyclePhase.forDay(day, periodLength: periodLen, cycleLength: cycleLen)
                    planRow(phase.emoji, tr("You're in your \(phase.label) phase"), tr("Cycle day \(day) · next period in about \(max(1, cycleLen - day + 1)) days"))
                } else {
                    planRow("🌸", "Cycle tracking", "Log your period anytime to unlock predictions")
                }
                if lifeStage == "PERIMENOPAUSE" { planRow("🌗", "Perimenopause support", "Track hot flashes, sleep and changing cycles alongside your plan") }
            }
            planRow("🧭", "Daily coach", "A workout, a word and a moment of calm, tuned to how you feel each day")
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    T("👑 Plans made for you").font(.hs(14, .bold)).foregroundStyle(HS.text)
                    T("From your answers. Everything above is yours free; these add more.").font(.hs(12)).foregroundStyle(HS.textMuted)
                    ForEach(fits) { p in
                        HStack {
                            D(p.emoji).frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                D(tr(p == .cycle && lifeStage != nil && lifeStage != "CYCLING" ? "For women" : p.name)).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                T(p.tagline).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            if let y = StorePrices.shared.item("\(p.rawValue)_yearly") { D(y.priceText + tr("/yr")).font(.hs(12, .semibold)).foregroundStyle(HS.gold) }
                        }
                    }
                    if fits.count >= 2, let c = StorePrices.shared.item("complete_yearly") {
                        let apart = fits.compactMap { StorePrices.shared.item("\($0.rawValue)_yearly")?.price }.reduce(0, +)
                        D(apart > c.price ? tr("Or all four as Complete for \(c.priceText)/yr, less than these \(fits.count) on their own.")
                          : tr("Or all four as Complete for \(c.priceText)/yr, just \(String(format: "$%.2f", c.price - apart)) more than these \(fits.count)."))
                            .font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                    }
                    T("Nothing is charged now. You can try them right after this, or anytime in Profile.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
            }
            .padding(.top, 6)
        }
    }

    private func finish() {
        let ud = UserDefaults.standard
        let first = name.trimmingCharacters(in: .whitespaces)
        store.name = first.isEmpty ? (gender == "male" ? "Brother" : "Sister") : first
        store.gender = gender ?? ""
        store.cycleLength = cycleLen
        store.periodLength = periodLen
        if !postMenopause, let lp = lastPeriod, isFemale { store.periodStarts = [lp] }
        ud.set(stepGoal, forKey: "stepGoal")
        ud.set(isFemale ? (lifeStage ?? "CYCLING") : "CYCLING", forKey: "lifeStage")
        ud.set(faithStage ?? "GROWING", forKey: "faithStage")
        ud.set(tradition ?? "NON_DENOMINATIONAL", forKey: "faithTradition")
        ud.set(cycleGoal ?? "WELLNESS", forKey: "cycleGoal")
        ud.set(regularity, forKey: "cycleRegularity")
        ud.set(goals, forKey: "goals")
        ud.set(reminder, forKey: "reminderTime")
        ud.set(true, forKey: "onboarded")
        let r = reminder
        Task { await Profile.scheduleDaily(r) }
        onDone()
    }

    // MARK: Pieces

    private func genderCard(_ key: String, _ emoji: String, _ title: String, _ desc: String, _ hex: UInt32) -> some View {
        let sel = gender == key
        return Button { gender = key } label: {
            GlassCard {
                HStack(spacing: 16) {
                    D(emoji).font(.system(size: 28)).frame(width: 60, height: 60)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: hex).opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(sel ? HS.gold : Color(hex: hex).opacity(0.35), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        T(title).font(.hs(17, .bold)).foregroundStyle(HS.text)
                        T(desc).font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                    Spacer(minLength: 0)
                    if sel { Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)).foregroundStyle(HS.gold) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(sel ? HS.gold : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? .isSelected : [])
    }

    private func option(_ emoji: String, _ title: String, _ desc: String, _ sel: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                D(emoji).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    T(title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    if !desc.isEmpty { T(desc).font(.hs(12)).foregroundStyle(HS.textMuted) }
                }
                Spacer(minLength: 0)
                if sel { Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(HS.gold) }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(sel ? HS.goldButton.opacity(0.22) : HS.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HS.gold.opacity(sel ? 1 : 0.22), lineWidth: sel ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? .isSelected : [])
    }

    private func choice(_ title: String, _ sub: String, _ options: [(String, String, String, String)], _ sel: Binding<String?>) -> some View {
        Scaffold(title: title, subtitle: sub, enabled: sel.wrappedValue != nil, next: next) {
            ForEach(options, id: \.0) { o in option(o.1, o.2, o.3, sel.wrappedValue == o.0) { sel.wrappedValue = o.0 } }
        }
    }

    private func stepper(_ title: String, _ desc: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                T(title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                T(desc).font(.hs(11)).foregroundStyle(HS.textMuted)
            }
            Spacer()
            round("minus", value.wrappedValue > range.lowerBound) { value.wrappedValue -= 1 }
            VStack(spacing: 0) {
                D("\(value.wrappedValue)").font(.hs(22, .bold)).foregroundStyle(HS.readable(0xEC4899))
                T("days").font(.hs(10)).foregroundStyle(HS.textMuted)
            }
            .frame(width: 58)
            round("plus", value.wrappedValue < range.upperBound) { value.wrappedValue += 1 }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HS.gold.opacity(0.24), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { d in
            if d == .increment, value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            if d == .decrement, value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
        }
    }

    private func round(_ symbol: String, _ enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(enabled ? HS.text : HS.textSubtle)
                .frame(width: 36, height: 36).background(Circle().fill(enabled ? HS.goldButton.opacity(0.24) : HS.overlay(0.04)))
        }
        .buttonStyle(.plain).disabled(!enabled)
    }

    private func planRow(_ emoji: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 14) {
            D(emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 1) {
                D(tr(title)).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                D(tr(desc)).font(.hs(12)).foregroundStyle(HS.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.22), lineWidth: 1))
    }
}

/// Android's StepScaffold: title, subtitle, the step's content scrolling, and the button pinned at the bottom.
private struct Scaffold<Content: View>: View {
    let title: String
    let subtitle: String
    var button = "Continue"
    var enabled = true
    let next: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    T(title).font(.hs(26, .bold)).foregroundStyle(HS.text).multilineTextAlignment(.center).padding(.top, 24)
                    T(subtitle).font(.hs(15)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center).padding(.bottom, 18)
                    content()
                }
                .padding(.horizontal, 28).padding(.bottom, 16)
            }
            GoldButton(title: button, action: next).disabled(!enabled).opacity(enabled ? 1 : 0.45)
                .padding(.horizontal, 28).padding(.bottom, 24)
        }
    }
}
