import SwiftUI

// MARK: - Free quota (3 questions / day without a plan, as on Android)

enum FreeAiQuota {
    private static let countKey = "freeAiQueriesLeft"
    private static let dateKey  = "freeAiQueriesDate"
    static let daily = 3

    /// Questions remaining today without a plan.
    static var queriesLeft: Int {
        let today = AppStore.dayKey()
        if UserDefaults.standard.string(forKey: dateKey) != today {
            UserDefaults.standard.set(daily, forKey: countKey)
            UserDefaults.standard.set(today, forKey: dateKey)
        }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    /// Takes one question after an answer arrives.
    static func consume() {
        _ = queriesLeft
        UserDefaults.standard.set(max(0, UserDefaults.standard.integer(forKey: countKey) - 1), forKey: countKey)
    }
}

// MARK: - Faith Chat engine

/// Android's Faith Chat (AiChatScreen, AppViewModel.sendChatMessage): the same companion prompt, the same specialist
/// briefs and accuracy rules (Experts.forQuestion), the same picture of today, through HolySteps' own server, so
/// both phones answer the same way. Someone writing about suicide or self-harm always gets the crisis line, is never
/// stopped by the daily limit and is never charged a question.
@MainActor
enum FaithCoach {
    /// Always offered, like Android (the server answers on every iPhone, not only Apple Intelligence ones).
    static var available: Bool { true }

    static let crisisWords = [
        "kill myself", "killing myself", "suicide", "suicidal", "self harm", "self-harm", "hurt myself", "hurting myself",
        "cut myself", "cutting myself", "want to die", "wanna die", "wish i was dead", "wish i were dead", "end it all",
        "end my life", "ending my life", "take my life", "taking my life", "don't want to live", "dont want to live",
        "do not want to live", "don't want to be alive", "dont want to be alive", "no reason to live", "better off dead",
        "better off without me", "overdose", "suicid",
        "matarme", "quitarme la vida", "me quiero morir", "quiero morirme", "quiero morir", "hacerme daño", "lastimarme",
        "autolesi", "acabar con todo", "no quiero vivir",
    ]

    static func looksLikeCrisis(_ text: String) -> Bool {
        let t = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        return crisisWords.contains { t.contains($0) }
    }

    static var crisisNote: String {
        tr("I'm really glad you told me. You don't have to carry this alone. Please call or text 988 right now. It's free, open all day and night, and someone will listen. If you're in danger right now, call 911.")
    }

    /// Android's buildAiSystemPrompt for the Faith flow.
    static func companionPrompt(store: AppStore) -> String {
        let stage = switch Profile.faithStage {
        case "NEW": "They are new to faith: explain simply, avoid church jargon, be welcoming."
        case "RETURNING": "They are returning to God after time away: emphasize grace and welcome, never guilt."
        case "ROOTED": "Faith is central to their life: you can go deeper into scripture and context."
        default: "They are growing in faith and want practical depth."
        }
        let name = store.name.isEmpty ? "" : "Their name is \(store.name)."
        // Freedom is private: its onboarding goal never reaches the AI.
        let goals = Profile.goals.filter { $0 != Profile.freedomGoal }
        let goalsLine = goals.isEmpty ? "" : "Their goals: \(goals.joined(separator: "; "))."
        let season: String = switch Profile.lifeStage {
        case "POSTMENOPAUSE": " She is post-menopausal: never refer to periods, cycle phases, ovulation or fertility unless she brings them up; strength, bone and heart health, sleep, and this season of life are relevant."
        case "PERIMENOPAUSE": " She is in perimenopause: her cycles may be irregular and she may have hot flashes, poor sleep or mood changes."
        default: ""
        }
        let who: String
        switch store.gender {
        case "female":
            who = "The user is a woman seeking faith-based guidance on her spiritual walk, women's health, and Christian living." + season
        case "male": who = "The user is a man seeking faith-based guidance on his spiritual walk, men's health, purpose, and Christian living."
        default: who = "The user is seeking faith-based guidance on their spiritual walk and Christian living."
        }
        let tradition = switch Profile.tradition {
        case "CATHOLIC": "They identify as Catholic. Answer from Catholic teaching and tradition — you may reference the Catechism, the saints, the Rosary, and the sacraments where relevant. Be accurate to Church teaching; if genuinely unsure of an official position, say so rather than guessing."
        case "ORTHODOX": "They identify as Eastern/Oriental Orthodox. Answer from Orthodox tradition — you may reference the Church Fathers, the Jesus Prayer, theosis, and the saints where relevant. Be accurate to Orthodox teaching; if genuinely unsure of an official position, say so rather than guessing."
        case "PROTESTANT": "They identify as Protestant. Answer scripture-first (sola scriptura) — ground guidance directly in the Bible text rather than magisterial or patristic authority, in the evangelical/Protestant tradition."
        default: "They haven't picked a specific tradition. Keep guidance broadly, mere-Christian — scripture-grounded without leaning into one denomination's distinctives unless they ask."
        }
        return """
        You are the HolySteps Faith Companion — a warm, scripture-grounded faith companion built into the HolySteps app.
        \(who)
        \(stage)
        \(tradition)
        \(name) \(goalsLine)
        Your role:
        - Answer questions about faith, the Bible, prayer, and Christian living
        - Encourage healthy habits (walking, rest, nutrition) through a faith lens
        - Ground your answers in scripture when relevant: give the reference, and quote it only when you are sure of the exact wording (name the translation)
        - Be concise — 2-4 short paragraphs max
        - Never give medical diagnoses; for health questions, encourage professional care plus prayer
        - Never be preachy or condescending; be a loving, wise friend
        - If the question is not faith or health related, gently redirect to those areas
        Tone: warm, genuine, scripture-grounded, never robotic.
        """
    }

    /// Android's coachContext: what the app knows about today, for the AI to use without reciting it.
    static func context(store: AppStore) -> String {
        let steps = StepsModel.shared
        let week = steps.week.map(\.steps)
        var lines = ["Today: \(steps.today) steps of a \(store.stepGoal)-step goal."]
        if !week.isEmpty { lines.append("Last 7 days: about \(week.reduce(0, +) / max(1, week.count)) steps a day on average.") }
        lines.append("Body rhythm today: \(Rhythm(store: store).zone.reason)")
        if AccountStore.shared.canUse(.adaptiveCoach) {
            let coach = AdaptiveCoachModel.shared
            if !coach.sleepToday.isEmpty { lines.append("Sleep last night (their own rating): \(coach.sleepToday).") }
            let named = coach.stressors.suffix(3).map { String($0.text.prefix(80)) }
            if !named.isEmpty { lines.append("What they've said is weighing on them: \(named.joined(separator: "; ")).") }
        }
        return "What you know about them right now (from the app; use it, don't recite it):\n- " + lines.joined(separator: "\n- ")
    }

    static func system(store: AppStore, question: String) -> String {
        companionPrompt(store: store) + "\n\n" + Experts.forQuestion(question) + "\n" + context(store: store)
    }
}

/// Android's Experts: the accuracy rules plus the one or two specialist briefs that fit the question.
enum Experts {
    enum Specialist: CaseIterable {
        case bible, fitness, womens, sleep, nutrition, mind, mens, kids, meds
        var words: [String] {
            switch self {
            case .bible: ["bible", "verse", "scripture", "passage", "chapter", "gospel", "psalm", "proverb", "jesus", "paul", "moses", "david",
                          "genesis", "exodus", "isaiah", "romans", "revelation", "corinthians", "meaning of", "what does", "theolog", "doctrine", "sin", "grace", "salvation",
                          "baptism", "communion", "church", "holy spirit", "trinity", "parable", "biblia", "versículo"]
            case .fitness: ["workout", "exercise", "train", "strength", "muscle", "run", "jog", "walk", "steps", "squat", "push-up", "pushup", "cardio",
                            "stretch", "knee", "back pain", "sore", "injury", "hiit", "gym", "weights", "plank", "program", "ejercicio", "entren"]
            case .womens: ["period", "cycle", "menstrua", "pms", "cramp", "ovulat", "fertil", "pregnan", "trying to conceive", "postpartum", "after birth",
                           "breastfeed", "nursing", "menopause", "perimenopause", "hot flash", "pcos", "endometriosis", "spotting", "birth control", "regla", "embaraz"]
            case .sleep: ["sleep", "insomnia", "can't sleep", "cant sleep", "tired", "fatigue", "nap", "bedtime", "wake up", "snor", "dormir", "sueño"]
            case .nutrition: ["eat", "food", "diet", "weight", "calorie", "protein", "carb", "sugar", "fast", "meal", "nutrition", "lose weight", "hydrat", "water",
                              "comida", "dieta", "ayuno"]
            case .mind: ["anxious", "anxiety", "depress", "sad", "stress", "panic", "lonely", "grief", "griev", "hopeless", "overwhelm", "worry", "angry",
                         "trauma", "therapy", "counsel", "burnout", "ansiedad", "triste"]
            case .mens: ["testosterone", "prostate", "erectile", "libido", "men's health", "mens health", "low t"]
            case .kids: ["baby", "newborn", "infant", "toddler", "my son", "my daughter", "my kid", "child", "children", "teen", "bebé"]
            case .meds: ["medication", "medicine", "pill", "dose", "dosage", "ibuprofen", "tylenol", "acetaminophen", "supplement", "vitamin", "magnesium",
                         "melatonin", "prescription", "side effect", "medicina", "pastilla"]
            }
        }
        var brief: String {
            switch self {
            case .bible: "Answer as a careful Bible teacher and pastor: give the passage's context (who wrote it, to whom, what kind of writing), what it meant then and how it applies now, and one or two cross-references that truly fit. Mention the original Hebrew or Greek only when you are sure of it."
            case .fitness: "Answer as an ACSM-certified personal trainer: adults need about 150 minutes of moderate activity a week (or 75 vigorous) plus strength work for all major muscles 2 days a week. Give frequency, time, intensity (talk test or effort 1–10) and form cues, warm-up and cool-down, and progress about 10% a week at most. Sharp pain, swelling, numbness or pain that doesn't ease in a few days: stop and see a doctor or physical therapist."
            case .womens: "Answer as a women's health nurse practitioner following ACOG: cycles of 21–35 days are typical in adults; a period that soaks a pad or tampon every hour for several hours, bleeding after menopause, severe pain, or periods that stop (and she isn't pregnant) need a doctor. In pregnancy, exercise is encouraged when her provider says it's safe (about 150 minutes a week), avoiding contact sports, falls and lying flat for long late in pregnancy. After birth, most wait for their provider's OK (often around 6 weeks) before harder exercise. Menopause means 12 months without a period; hormone therapy is a decision with her doctor."
            case .sleep: "Answer as a sleep specialist following the AASM: adults need 7 or more hours (7–9 is a good target). Keep the same wake time daily, get morning light, stop caffeine about 8 hours before bed, keep the room cool, dark and quiet, and get up after about 20 minutes awake (the basics of CBT-I, the first treatment for long-term insomnia). Loud snoring, gasping or stopping breathing in sleep, or daytime sleepiness that's dangerous (like when driving): see a doctor, as it can be sleep apnea."
            case .nutrition: "Answer as a registered dietitian following the Dietary Guidelines for Americans: mostly vegetables, fruit, whole grains, beans, lean protein and healthy fats; less added sugar, salt and ultra-processed food. Safe weight loss is about 0.5–2 lb a week; no crash diets or very low calorie plans without a doctor. Active adults often need about 1.0–1.6 g of protein per kg a day. For a spiritual fast: people who are pregnant, nursing, have diabetes, take medicines with food, or have a history of eating disorders should talk to their doctor first or choose a non-food fast. If eating or body image sounds painful, respond gently and suggest professional support (in the US, the National Alliance for Eating Disorders helpline)."
            case .mind: "Answer as a licensed counselor who is also a person of faith: listen and validate first, then offer one or two proven tools (slow breathing with a longer out-breath, the 5-4-3-2-1 grounding exercise, a short walk outside, writing it down, reaching out to someone). Encourage professional help when it lasts more than two weeks or gets in the way of daily life; depression and anxiety are treatable, and therapy and medicine are not a lack of faith. Any thought of suicide or self-harm: 988 (call or text, US) or 911 now."
            case .mens: "Answer as a men's health physician following USPSTF and AUA guidance: prostate cancer screening (PSA) is a shared decision with a doctor, mainly at ages 55–69; erectile problems can be an early sign of heart disease or diabetes and are worth a doctor visit; low testosterone needs blood tests before any treatment. Sleep, strength training, weight and alcohol all affect these."
            case .kids: "Answer as a pediatric nurse following the AAP: babies sleep alone, on their back, in a crib with nothing else in it; a fever of 100.4°F (38°C) or higher under 3 months old needs a doctor right away; no honey before age 1; no water before about 6 months; solids around 6 months. Never give medicine doses for a child: point to the label's weight chart, a pharmacist or their doctor. Children 6–17 need about 60 minutes of activity a day."
            case .meds: "Answer as a pharmacist: never suggest starting, stopping or changing a prescribed medicine; for over-the-counter medicine and supplements, follow the label, and check interactions with a pharmacist (for example, many medicines interact with grapefruit, St. John's wort or alcohol). Supplements aren't checked like medicines, so a doctor or pharmacist should know what they take."
            }
        }
    }

    /// The specialists for this question, at most two, most specific first (Android's Experts.pick).
    static func pick(_ question: String) -> [Specialist] {
        let q = " " + question.lowercased() + " "
        let priority: [Specialist] = [.mind, .kids, .womens, .meds, .mens, .sleep, .nutrition, .fitness, .bible]
        let hits = Specialist.allCases.compactMap { s -> (Specialist, Int)? in
            let n = s.words.filter { w in
                (try? NSRegularExpression(pattern: "(?<![a-záéíóúñ])" + NSRegularExpression.escapedPattern(for: w)))?
                    .firstMatch(in: q, range: NSRange(q.startIndex..., in: q)) != nil
            }.count
            return n > 0 ? (s, n) : nil
        }
        return hits.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : priority.firstIndex(of: $0.0)! < priority.firstIndex(of: $1.0)! }.prefix(2).map(\.0)
    }

    @MainActor static func forQuestion(_ question: String) -> String {
        let picked = pick(question)
        var s = AIProxy.accuracy
        if !picked.isEmpty { s += "\nFor this question:\n" + picked.map { "- \($0.brief)\n" }.joined() }
        return s
    }
}

struct FaithCoachMessage: Identifiable, Equatable, Codable {
    var id = UUID()
    let mine: Bool
    var text: String
    /// The app's own notes ("you're offline", the crisis line) are for the person, not part of the conversation.
    var local = false
}

struct FaithCoachView: View {
    @ObservedObject private var account = AccountStore.shared
    @State private var messages: [FaithCoachMessage] = Self.saved
    @State private var draft = ""
    @State private var thinking = false
    @State private var paywall = false
    @State private var queriesLeft = FreeAiQuota.queriesLeft

    @EnvironmentObject private var store: AppStore

    private static var saved: [FaithCoachMessage] {
        UserDefaults.standard.data(forKey: "faithChat").flatMap { try? JSONDecoder().decode([FaithCoachMessage].self, from: $0) } ?? []
    }
    private func save() {
        if let d = try? JSONEncoder().encode(Array(messages.suffix(20))) { UserDefaults.standard.set(d, forKey: "faithChat") }
    }

    private var starters: [String] {
        switch store.gender {
        case "female": ["How can I deepen my prayer life?", "What does the Bible say about strength for women?", "I'm feeling overwhelmed — help me find peace in scripture"]
        case "male": ["How can I be a man of God?", "What does the Bible say about purpose and strength?", "I'm struggling with discipline — what does scripture say?"]
        default: ["How can I deepen my prayer life?", "What does the Bible say about strength?", "Help me find peace in scripture"]
        }
    }

    private var unlimited: Bool { account.canUse(.aiUnlimited) }

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    T("✝️ Faith Chat").font(.hs(13, .bold)).foregroundStyle(HS.peach)
                    T("Ask Anything").font(.hs(24, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    if unlimited {
                        T("Unlimited faith guidance").font(.hs(12)).foregroundStyle(HS.body)
                    } else {
                        T(queriesLeft == 1 ? "1 free question remaining today" : "\(queriesLeft) free questions remaining today")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    T("Answers are generated and can be wrong. Weigh them against Scripture and wise people you trust.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 58).padding(.bottom, 12)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 14) {
                                    Text("🙏").font(.system(size: 48))
                                    T("Ask me about faith, prayer,\nscripture, or spiritual growth.").font(.hs(15)).foregroundStyle(HS.textMuted)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity).padding(.top, 24)
                                ForEach(starters, id: \.self) { s in
                                    Button { send(tr(s)) } label: {
                                        T(s).font(.hs(14)).foregroundStyle(HS.text).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                                    }.buttonStyle(.plain)
                                }
                            }
                            ForEach(messages) { m in
                                HStack {
                                    if m.mine { Spacer(minLength: 40) }
                                    VStack(alignment: .leading, spacing: 6) {
                                        D(m.text).font(.hs(15)).foregroundStyle(m.mine ? HS.onGold : HS.text)
                                            .textSelection(.enabled)
                                        if !m.mine && !m.local {
                                            HStack(spacing: 16) {
                                                Button { UIPasteboard.general.string = m.text } label: { T("📋 Copy").font(.hs(13)).foregroundStyle(HS.textMuted) }
                                                ShareLink(item: m.text) { T("↗ Share").font(.hs(13)).foregroundStyle(HS.textMuted) }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(m.mine ? HS.goldButton : HS.cardFill))
                                    if !m.mine { Spacer(minLength: 40) }
                                }.id(m.id)
                            }
                            if thinking { ProgressView().tint(HS.gold).padding(8) }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 12)
                    }
                    .onChange(of: messages) { _, m in if let last = m.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
                }
                HStack(spacing: 10) {
                    TextField(tr("Ask about faith, prayer, scripture…"), text: $draft, axis: .vertical)
                        .lineLimit(1...4).font(.hs(15)).padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
                    Button { send(draft) } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                            .foregroundStyle((!unlimited && queriesLeft <= 0) ? HS.textMuted : HS.gold)
                    }
                    .accessibilityLabel(tr("Send"))
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thinking)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .sheet(isPresented: $paywall) { PlansView(feature: .aiUnlimited) }
        .onAppear { queriesLeft = FreeAiQuota.queriesLeft }
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        let crisis = FaithCoach.looksLikeCrisis(text)
        if !crisis && !unlimited && queriesLeft <= 0 { paywall = true; return }
        draft = ""
        let history = messages.filter { !$0.local }
        messages.append(.init(mine: true, text: text))
        // In a crisis with no question left, answer with the crisis line now.
        if crisis && !unlimited && queriesLeft <= 0 {
            messages.append(.init(mine: false, text: FaithCoach.crisisNote, local: true)); save(); return
        }
        thinking = true
        Task {
            let system = FaithCoach.system(store: store, question: text)
            let convo: [(mine: Bool, text: String)] = history.suffix(9).map { (mine: $0.mine, text: $0.text) } + [(mine: true, text: text)]
            do {
                if let reply = try await AIProxy.chat(system: system, conversation: convo) {
                    messages.append(.init(mine: false, text: reply))
                    if !crisis && !unlimited { FreeAiQuota.consume(); queriesLeft = FreeAiQuota.queriesLeft }
                } else {
                    messages.append(.init(mine: false, text: crisis ? FaithCoach.crisisNote : tr("I'm having trouble connecting right now. Please try again in a moment. 🙏"), local: true))
                }
            } catch AIProxy.Failure.busy(let why), AIProxy.Failure.unavailable(let why) {
                messages.append(.init(mine: false, text: crisis ? FaithCoach.crisisNote : why + " " + tr("Your message is saved, so just send it again."), local: true))
            } catch {
                messages.append(.init(mine: false, text: crisis ? FaithCoach.crisisNote : tr("I'm having trouble connecting right now. Please try again in a moment. 🙏"), local: true))
            }
            thinking = false
            save()
        }
    }
}
