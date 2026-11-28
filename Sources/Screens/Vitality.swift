import SwiftUI

/// Android's data/LifeStage.kt Vitality content. A woman past menopause has no cycle to track, so her Women tab
/// becomes Vitality: a weekly training rhythm built on the US Physical Activity Guidelines for adults
/// (muscle-strengthening on 2+ days, about 150 minutes of moderate activity a week, balance work for fall
/// prevention, and a real rest day), menopause symptoms with plain care and when to see a doctor, and a faith
/// track for this season. General wellness guidance only; it never diagnoses.
enum Vitality {
    enum Focus: String, CaseIterable {
        case strength, cardio, balance, intervals, nature, restore
        var label: String {
            switch self { case .strength: "Strength"; case .cardio: "Heart"; case .balance: "Balance"
                          case .intervals: "Intervals"; case .nature: "Outdoors"; case .restore: "Restore" }
        }
        var emoji: String {
            switch self { case .strength: "🏋️"; case .cardio: "❤️"; case .balance: "🦩"
                          case .intervals: "⚡"; case .nature: "🌳"; case .restore: "🌙" }
        }
        var description: String {
            switch self {
            case .strength: "Strength day — muscle and bone respond to regular, progressive loading."
            case .cardio: "Heart day — a steady brisk walk or ride counts toward your 150 weekly minutes."
            case .balance: "Balance day — short balance drills are one of the best ways to prevent falls."
            case .intervals: "Interval day — short bursts of brisk effort with easy recovery between."
            case .nature: "Outdoor day — a longer, easy walk in daylight helps sleep, mood and bones."
            case .restore: "Rest day — gentle stretching and real rest so you recover and come back stronger."
            }
        }
        /// DailyCoach.kt baseZone for this focus.
        var zone: EnergyZone {
            switch self { case .strength, .cardio, .nature: .steady; case .intervals: .high; case .balance: .low; case .restore: .recover }
        }
        /// DailyCoach.kt routineCandidates: the day's planned workouts, in order.
        var routines: [String] {
            switch self {
            case .strength: ["bone_strength", "steady_strength"]
            case .cardio: ["heart_walk", "gentle_intervals"]
            case .balance: ["balance_drills", "mobility_reset"]
            case .intervals: ["gentle_intervals", "heart_walk"]
            case .nature: ["brisk_prayer_walk", "easy_walk"]
            case .restore: ["restorative_stretch", "gentle_yoga"]
            }
        }
    }

    /// Monday and Thursday strength, Tuesday heart, Wednesday balance, Friday intervals, Saturday outdoors, Sunday rest.
    static func focus(_ date: Date = Date()) -> Focus {
        switch Calendar.current.component(.weekday, from: date) {
        case 2, 5: .strength
        case 3: .cardio
        case 4: .balance
        case 6: .intervals
        case 7: .nature
        default: .restore
        }
    }

    static var isOn: Bool {
        UserDefaults.standard.string(forKey: "gender") != "male" && UserDefaults.standard.string(forKey: "lifeStage") == "POSTMENOPAUSE"
    }

    static let strengthTarget = 2      // muscle-strengthening days a week
    static let balanceTarget = 3       // balance sessions a week
    static let activeMinutesTarget = 150

    static let bleeding = "🩸 Bleeding or spotting"
    static let symptoms = ["🔥 Hot flashes", "💦 Night sweats", "🌙 Poor sleep", "🦴 Joint aches",
                           "🌫️ Brain fog", "😰 Anxious", "😢 Low mood", "😤 Irritable",
                           "😴 Fatigue", "🤕 Headache", "💓 Racing heart", "🚻 Bladder leaks",
                           "🌵 Dryness / discomfort", "⚖️ Weight changes", "✨ Feeling good", "😊 Calm & steady"]

    /// Practical, non-diagnostic care for a logged symptom; every warning sign says plainly when to see a doctor.
    static func care(_ s: String) -> String? {
        if s.contains("Bleeding") { return "Any bleeding after menopause should be checked by a doctor — it's usually something simple, but it always needs a look. Please call your doctor's office this week." }
        if s.contains("Hot flashes") { return "Dress in layers, keep cold water nearby, and notice triggers (alcohol, caffeine, spicy food, hot drinks, stress). Slow breathing — about 6 breaths a minute — can take the edge off. If they're disrupting life, ask your doctor about treatment options." }
        if s.contains("Night sweats") { return "Keep the bedroom cool, use breathable sheets, and have a change of nightclothes ready. Skipping alcohol in the evening often helps." }
        if s.contains("Poor sleep") { return "Same wake time every day, daylight early, caffeine before noon only, and a cool dark room. A sleep story or calm session tonight can help you wind down." }
        if s.contains("Joint aches") { return "Gentle movement usually helps more than rest — try today's mobility or a warm shower first. See your doctor if a joint is swollen, red, or hot." }
        if s.contains("Brain fog") { return "Very common in this transition and often improves. Sleep, movement, and writing things down help. Talk to your doctor if it's getting steadily worse." }
        if s.contains("Racing heart") { return "Palpitations can come with hot flashes, but get new or frequent ones checked. Chest pain, fainting, or shortness of breath means call 911." }
        if s.contains("Bladder leaks") { return "Very common and very treatable: daily pelvic floor exercises help most women within a few months. A pelvic floor physical therapist can make a big difference." }
        if s.contains("Dryness") { return "Common, and nothing to be embarrassed about — over-the-counter moisturizers help, and your doctor has effective treatments." }
        if s.contains("Low mood") || s.contains("Anxious") { return "Hormone shifts can affect mood. Reach out to someone you trust and get outside today. If it lasts two weeks or more, talk to your doctor — and if you ever feel unsafe, call or text 988." }
        if s.contains("Fatigue") { return "Short daylight walks and protein at breakfast help steady energy. Fatigue that doesn't lift with rest is worth a check-up (thyroid and iron are easy tests)." }
        if s.contains("Weight changes") { return "Muscle loss slows metabolism in this season — strength training twice a week and protein at every meal are the two biggest levers." }
        return nil
    }

    struct Pillar { let title, emoji, why: String; let tips: [String] }
    static let pillars: [Pillar] = [
        Pillar(title: "Bone strength", emoji: "🦴", why: "Bone loss speeds up in the years around menopause as estrogen falls. Loading your bones is how you push back.",
               tips: ["Strength-train twice a week — your bones respond to load, not just movement.",
                      "Weight-bearing beats seated: walking, stairs, and step-ups all count.",
                      "Calcium from food first — yogurt, milk, sardines, tofu, leafy greens.",
                      "Vitamin D matters for absorbing calcium — ask your doctor whether you need a test.",
                      "Protein at every meal helps protect the muscle that protects your bones.",
                      "Ask your doctor if a bone density scan (DEXA) is right for you."]),
        Pillar(title: "Heart health", emoji: "❤️", why: "Heart disease risk rises after menopause. Regular moderate activity is one of the most protective habits there is.",
               tips: ["Aim for 150 minutes of brisk activity a week — 30 minutes, 5 days, or whatever fits.",
                      "Brisk means you can talk but not sing.",
                      "Know your numbers: blood pressure, cholesterol, and blood sugar.",
                      "Fill half your plate with vegetables and fruit.",
                      "Swap one salty snack for nuts or fruit today."]),
        Pillar(title: "Balance & mobility", emoji: "🦩", why: "Balance is a skill that fades without practice — and practicing it is one of the best ways to prevent falls.",
               tips: ["Stand on one foot while brushing your teeth (hold the counter).",
                      "Walk heel-to-toe down the hallway once a day.",
                      "Rise from a chair without using your hands — slowly.",
                      "Keep floors clear and add night lights on the path to the bathroom.",
                      "Ankle circles and calf raises keep the base of your balance strong."]),
        Pillar(title: "Sleep", emoji: "🌙", why: "Night sweats and early waking are common. A few habits make a real difference.",
               tips: ["Keep the bedroom cool — around 65°F is a good starting point.",
                      "Same wake-up time every day, even after a rough night.",
                      "Get daylight within an hour of waking.",
                      "Caffeine before noon only; skip alcohol in the evening.",
                      "Can't sleep after 20 minutes? Get up, read something calm, and try again."]),
        Pillar(title: "Mind & purpose", emoji: "🧠", why: "This season brings wisdom worth sharing. Purpose and connection are good for the brain and the heart.",
               tips: ["Learn something new this week — a language, an instrument, a recipe.",
                      "Call a friend instead of texting.",
                      "Who could you encourage or mentor this month?",
                      "Write down one thing you know now that you wish you'd known at 30.",
                      "Volunteer an hour — service is good medicine."]),
    ]

    static let nourish = [
        "Protein at breakfast — eggs, Greek yogurt, or cottage cheese — steadies energy all morning.",
        "Add a calcium food to lunch: yogurt, cheese, tofu, or a glass of milk.",
        "Salmon or sardines twice a week give you protein, omega-3s, and vitamin D.",
        "Beans and lentils: fiber, protein, and they keep blood sugar steady.",
        "A handful of nuts beats chips — heart-healthy fats and protein.",
        "Leafy greens tonight — kale, collards, or bok choy bring calcium too.",
        "Drink water through the day; hot flashes and night sweats use up fluid.",
        "Go easy on alcohol — it worsens hot flashes and sleep for many women.",
    ]

    /// Wisdom Season. Quotations are the World English Bible (public domain); `paraphrase` lines summarize a
    /// passage and are never shown in quotation marks.
    struct Wisdom { let reference, verse, reflection, prompt: String; var paraphrase = false }
    static let wisdom: [Wisdom] = [
        Wisdom(reference: "Psalm 92:14", verse: "They will still produce fruit in old age. They will be full of sap and green,",
               reflection: "God does not retire you. The fruit of this season — patience, perspective, a steady faith tested by years — is fruit younger believers are hungry for.",
               prompt: "What fruit is God growing in me in this season?"),
        Wisdom(reference: "Isaiah 46:4", verse: "Even to old age I am he, and even to gray hairs I will carry you. I have made, and I will bear. Yes, I will carry, and will deliver.",
               reflection: "The God who carried you through every earlier season has not changed His grip. Your body is changing; His faithfulness isn't.",
               prompt: "Where has God carried me that I can thank Him for today?"),
        Wisdom(reference: "Psalm 71:18", verse: "Yes, even when I am old and gray-haired, God, don't forsake me, until I have declared your strength to the next generation, your might to everyone who is to come.",
               reflection: "Your story of God's faithfulness is meant to be passed on. Someone younger needs to hear how you got through.",
               prompt: "Who in the next generation could I share my story with this week?"),
        Wisdom(reference: "Proverbs 31:25", verse: "Strength and dignity are her clothing. She laughs at the time to come.",
               reflection: "Not fear of the future — laughter. Strength and dignity aren't about a younger body; they're what you wear when you trust God with what's ahead.",
               prompt: "What about the future can I hand to God today so I can laugh instead of worry?"),
        Wisdom(reference: "2 Corinthians 4:16", verse: "Therefore we don't faint, but though our outward person is decaying, yet our inward person is renewed day by day.",
               reflection: "Paul is honest that the body ages. He's just as honest that the inner life can grow stronger every single day.",
               prompt: "How has my inner life grown even as my body has changed?"),
        Wisdom(reference: "Ecclesiastes 3:1", verse: "For everything there is a season, and a time for every purpose under heaven:",
               reflection: "This season has its own purposes — not a lesser version of the last one. Ask God what this one is for.",
               prompt: "What might God's purpose be for this particular season of my life?"),
        Wisdom(reference: "Titus 2:3–5", verse: "Older women are called to teach what is good and to encourage the younger women.",
               reflection: "Scripture gives the women of this season a calling: to encourage and train the next generation. Your experience is a ministry.",
               prompt: "Is there a younger woman I could encourage, pray for, or invite for coffee?", paraphrase: true),
        Wisdom(reference: "Luke 2:36–38", verse: "Anna, a prophetess of great age, never left the temple, serving God with fasting and prayer night and day.",
               reflection: "Anna was among the first to recognize Jesus — after decades of faithful prayer. Long faithfulness sees what others miss.",
               prompt: "What have I been faithfully praying about for years — and can I keep going?", paraphrase: true),
    ]
    /// Android's vitalityWeek: strength days, balance sessions and active minutes this week (Monday to today).
    /// Workouts finished in HolySteps count, and so do recorded walks.
    static func week(today: Date = Date()) -> (strengthDays: Int, balance: Int, minutes: Int) {
        let cal = Calendar.current
        let back = (cal.component(.weekday, from: today) + 5) % 7      // days since Monday
        let monday = cal.startOfDay(for: cal.date(byAdding: .day, value: -back, to: today) ?? today)
        let keys = Set((0...back).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }.map { AppStore.dayKey($0) })
        var strength = Set<String>(), balance = 0, minutes = 0
        for (day, list) in CoachLog.shared.sessions where keys.contains(day) {
            for entry in list {
                let parts = entry.split(separator: ":"), kind = String(parts.first ?? ""), mins = Int(parts.last ?? "") ?? 0
                if kind == "STRENGTH" { strength.insert(day) }
                if kind == "BALANCE" || kind == "YOGA" { balance += 1 }
                if ["CARDIO", "WALK", "HIIT", "STRENGTH"].contains(kind) { minutes += mins }
            }
        }
        minutes += WalkStore.shared.walks.filter { $0.start >= monday }.reduce(0) { $0 + $1.activeSec / 60 }
        return (strength.count, balance, minutes)
    }
}

/// Android's VitalityScreen: the Women tab for a woman past menopause.
struct VitalityView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var log = CycleLog.shared
    @ObservedObject private var checkIns = CheckInStore.shared
    @ObservedObject private var coach = CoachLog.shared
    @State private var energy = 0
    @State private var open: Set<String> = []
    @State private var showProfile = false

    var body: some View {
        let focus = Vitality.focus()
        let day = PhasePlan.epochDay
        let wisdomList = Vitality.wisdom
        let wisdom = wisdomList[((day % wisdomList.count) + wisdomList.count) % wisdomList.count]
        let nourish = Vitality.nourish[((day % Vitality.nourish.count) + Vitality.nourish.count) % Vitality.nourish.count]
        let week = Vitality.week()
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(focus)
                        VStack(alignment: .leading, spacing: 12) {
                            CoverCard(emoji: "📊", title: "About you", subtitle: "What all of it says about you", tint: 0x38BDF8) { AboutYouView().environmentObject(store) }
                            CoverCard(emoji: "🤕", title: "Headache diary", subtitle: "Log headaches and see what goes with yours") { HeadacheView() }
                        }
                        .padding(.horizontal, 20).padding(.top, 12)
                        ToolSection(title: "Track your body", items: [
                            ToolItem(symbol: "fork.knife", color: HS.body, title: "Food & water", sub: "Water, protein and real food", destination: AnyView(BodyBasicsView(part: .food).environmentObject(store))),
                            ToolItem(symbol: "dumbbell", color: HS.peach, title: "Strength log", sub: "Strength keeps bones and muscle strong", destination: AnyView(StrengthLogView())),
                            ToolItem(symbol: "heart.text.square", color: HS.cycle, title: "Know your numbers", sub: "Blood pressure, cholesterol and check-ups", destination: AnyView(BodyBasicsView(part: .numbers).environmentObject(store))),
                            ToolItem(symbol: "checklist", color: HS.faith, title: "Habits", sub: "Drinks, caffeine, screens and smoking", destination: AnyView(BodyBasicsView(part: .habits).environmentObject(store))),
                        ])
                        .padding(.top, 12)
                        DailyCoachCard().padding(.horizontal, 20).padding(.top, 14)
                        thisWeek(week)
                        symptoms()
                        energyToday()
                        pillars()
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                T("Nourish today").font(.hs(13, .semibold)).foregroundStyle(HS.body)
                                T(nourish).font(.hs(13)).foregroundStyle(HS.text)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20).padding(.top, 14)
                        BodyEnergyEntryCard().padding(.horizontal, 20).padding(.top, 14)
                        NewParentsEntryCard(title: "A new baby in the family?", subtitle: "How to really help new parents, and the signs of postpartum depression to watch for")
                            .padding(.horizontal, 20).padding(.top, 14)
                        wisdomCard(wisdom)
                        HStack(spacing: 10) {
                            shortcut("📈", "Trends") { AnyView(TrendsView().environmentObject(store)) }
                            shortcut("🤝", "Circles") { AnyView(CirclesView()) }
                            shortcut("🎧", "Sanctuary") { AnyView(AudioPrayerView()) }
                        }
                        .padding(.horizontal, 20).padding(.top, 14)
                        T("General wellness guidance, not medical advice. For new or worsening symptoms — and always for any bleeding after menopause — talk with your doctor. In an emergency call 911.")
                            .font(.hs(11)).foregroundStyle(HS.textMuted).padding(.horizontal, 20).padding(.top, 14)
                        NavigationLink { ProfileView() } label: {
                            T("Life stage changed? Update it in Profile").font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                        .padding(.horizontal, 20).padding(.top, 6)
                        Spacer().frame(height: 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { if energy == 0, let c = checkIns.today { energy = min(5, max(1, c.energy - 1)) } }
        }
    }

    private func hero(_ focus: Vitality.Focus) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear.frame(height: 250).frame(maxWidth: .infinity)
                .overlay { Image(ScreenPhoto.daily("screen_cycle")).resizable().scaledToFill() }
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                T("VITALITY").font(.hs(11, .semibold)).tracking(1.5).foregroundStyle(HS.gold)
                T("\(focus.label) day").font(.hs(26)).foregroundStyle(.white)
                T(focus.description).font(.accent(14)).foregroundStyle(HS.peach)
            }
            .padding(20)
            .frame(maxWidth: 300, alignment: .leading)
        }
        .frame(height: 250)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func thisWeek(_ w: (strengthDays: Int, balance: Int, minutes: Int)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            T("This week").font(.hs(16, .semibold)).foregroundStyle(HS.text)
            T("Targets from the US Physical Activity Guidelines for adults.").font(.hs(11)).foregroundStyle(HS.textMuted)
            HStack(spacing: 10) {
                ring("🏋️", "Strength days", w.strengthDays, Vitality.strengthTarget, HS.peach)
                ring("🦩", "Balance", w.balance, Vitality.balanceTarget, HS.faith)
                ring("❤️", "Active min", w.minutes, Vitality.activeMinutesTarget, HS.body)
            }
            T("Workouts and walks you finish in HolySteps count automatically.").font(.hs(11)).foregroundStyle(HS.textMuted)
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    private func ring(_ emoji: String, _ label: String, _ value: Int, _ target: Int, _ color: Color) -> some View {
        let frac = min(1, Double(value) / Double(max(1, target)))
        return GlassCard {
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(HS.overlay(0.10), lineWidth: 6)
                    Circle().trim(from: 0, to: max(0.001, frac)).stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                    D(frac >= 1 ? "✓" : emoji).font(.system(size: frac >= 1 ? 20 : 18)).foregroundStyle(color)
                }
                .frame(width: 62, height: 62)
                D("\(value) / \(target)").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                T(label).font(.hs(11)).foregroundStyle(HS.textMuted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func symptoms() -> some View {
        let all = Vitality.symptoms + [Vitality.bleeding]
        let chosen = log.today
        VStack(alignment: .leading, spacing: 8) {
            T("How's your body today?").font(.hs(16, .semibold)).foregroundStyle(HS.text)
            ForEach(0..<((all.count + 1) / 2), id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(Array(all[(row * 2)..<min(all.count, row * 2 + 2)]), id: \.self) { s in
                        let on = chosen.contains(s)
                        Button { log.toggle(s) } label: {
                            D((on ? "✓ " : "") + tr(s)).font(.hs(12)).foregroundStyle(on ? HS.text : HS.textSecondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 11).padding(.horizontal, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(on ? HS.goldButton.opacity(0.22) : HS.cardFill))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: 0xD9B49F).opacity(on ? 1 : 0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    if all.count % 2 == 1 && row == all.count / 2 { Spacer().frame(maxWidth: .infinity) }
                }
            }
            if chosen.contains(Vitality.bleeding), let warn = Vitality.care(Vitality.bleeding) {
                T("⚠️ " + warn).font(.hs(13)).foregroundStyle(.white)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x7F1D1D).opacity(0.85)))
            }
            ForEach(all.filter { chosen.contains($0) && $0 != Vitality.bleeding }, id: \.self) { s in
                if let c = Vitality.care(s) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            D(tr(s)).font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                            T(c).font(.hs(12)).foregroundStyle(HS.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    @ViewBuilder private func energyToday() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            T("Energy today").font(.hs(16, .semibold)).foregroundStyle(HS.text)
            HStack(spacing: 8) {
                ForEach(Array([("🪫", "Low"), ("😐", "OK"), ("💪", "Good"), ("⚡", "Peak"), ("🔥", "On Fire")].enumerated()), id: \.offset) { i, e in
                    let sel = energy == i + 1
                    Button { energy = i + 1 } label: {
                        VStack(spacing: 2) { D(e.0).font(.system(size: 18)); T(e.1).font(.hs(10, .medium)).foregroundStyle(sel ? HS.gold : HS.textMuted) }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 14).fill(sel ? HS.goldButton.opacity(0.22) : HS.cardFill))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0xD9B49F).opacity(sel ? 0.6 : 0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(sel ? .isSelected : [])
                }
            }
            Button {
                var c = checkIns.today ?? CheckIn(date: AppStore.dayKey(), mood: 3, energy: 3, clarity: 3, peace: 3, sleep: "")
                c.energy = min(5, energy + 1)
                checkIns.save(c)
            } label: {
                T(checkIns.today != nil ? "Checked in today · Update" : energy == 0 ? "Pick your energy to check in" : "Save today's check-in · +5pts")
                    .font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
            }
            .buttonStyle(.plain).disabled(energy == 0).opacity(energy == 0 ? 0.6 : 1)
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    @ViewBuilder private func pillars() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            T("Your vitality pillars").font(.hs(16, .semibold)).foregroundStyle(HS.text)
            ForEach(Vitality.pillars, id: \.title) { p in
                let isOpen = open.contains(p.title)
                Button { withAnimation { if isOpen { open.remove(p.title) } else { open.insert(p.title) } } } label: {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                D(p.emoji).font(.system(size: 20))
                                T(p.title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                Spacer()
                                D(isOpen ? "▲" : "▼").font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                            if isOpen {
                                T(p.why).font(.hs(12)).foregroundStyle(HS.textSecondary)
                                ForEach(p.tips, id: \.self) { t in
                                    HStack(alignment: .top, spacing: 6) { D("•").foregroundStyle(HS.gold); T(t).font(.hs(12)).foregroundStyle(HS.text) }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    @ViewBuilder private func wisdomCard(_ w: Vitality.Wisdom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                Color.clear.frame(height: 130).frame(maxWidth: .infinity)
                    .overlay { Image(ScreenPhoto.daily("screen_faith")).resizable().scaledToFill() }
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.62)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    T("WISDOM SEASON").font(.hs(11, .semibold)).tracking(1.5).foregroundStyle(HS.gold)
                    T("Your fruitful years").font(.hs(18, .semibold)).foregroundStyle(.white)
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    if w.paraphrase {
                        T(w.verse).font(.hs(15)).foregroundStyle(HS.text)
                        if !w.reference.isEmpty { D(tr("— based on") + " " + w.reference).font(.hs(12)).foregroundStyle(HS.textMuted) }
                    } else {
                        // Scripture is shown exactly as written (WEB), in quotation marks.
                        D("“\(w.verse)”").font(.accent(15)).foregroundStyle(HS.text)
                        D("— \(w.reference) (WEB)").font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    T(w.reflection).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    T("✍️ " + w.prompt).font(.hs(13)).foregroundStyle(HS.text)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.goldButton.opacity(0.14)))
                    NavigationLink { PrayerJournalView(section: 1) } label: {
                        T("Write about it in your journal ›").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    private func shortcut(_ emoji: String, _ label: String, _ dest: @escaping () -> AnyView) -> some View {
        NavigationLink { dest() } label: {
            GlassCard {
                VStack(spacing: 4) {
                    D(emoji).font(.system(size: 18))
                    T(label).font(.hs(12, .semibold)).foregroundStyle(HS.text)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}
