import SwiftUI

/// HolySteps' AI chat on its own server (Android's AiProxy): the AI keys live there, never in the app.
@MainActor
enum AIProxy {
    enum Failure: Error { case busy(String), unavailable(String) }
    private static let url = URL(string: "https://holysteps.org/holysteps/api/ai/chat")!

    /// One reply for `system` and `user`, or nil when it can't be reached.
    static func chat(system: String, user: String) async throws -> String? {
        try await chat(system: system, conversation: [(mine: true, text: user)])
    }

    /// One reply to a conversation (mine = the person's turns), the last 10 turns at most, as Android's AiProxy.chat.
    static func chat(system: String, conversation: [(mine: Bool, text: String)]) async throws -> String? {
        let turns = conversation.suffix(10).filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !turns.isEmpty else { return nil }
        let spanish = I18n.shared.spanish
        let sys = String(system.prefix(8000 - 300)) + (spanish
            ? "\n\nIMPORTANT: The user reads this app in Spanish. Always reply in natural, warm Latin American Spanish (tú form), whatever language the instructions above are written in. Quote Scripture from the Reina-Valera 1909 wording when you quote it."
            : "")
        let msgs = turns.map { ["role": $0.mine ? "user" : "assistant", "content": String($0.text.prefix(6000))] }
        let body = try JSONSerialization.data(withJSONObject: ["system": sys, "messages": msgs] as [String: Any])
        for attempt in 0..<2 {
            guard let tok = await AccountStore.shared.token(force: attempt == 1) else { return nil }
            var req = URLRequest(url: url, timeoutInterval: 60)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.httpBody = body
            guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
            let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200: return (j?["reply"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            case 401: continue
            case 429: throw Failure.busy((j?["error"] as? String) ?? tr("You're going a little fast. Try again in a minute."))
            case 502, 503: throw Failure.unavailable((j?["error"] as? String) ?? tr("The service didn't answer. Try again in a moment."))
            default: return nil
            }
        }
        return nil
    }

    /// The English translations the app carries: the only ones the AI may quote word for word (Android's SCRIPTURE_SOURCES).
    static var scriptureSources: String { Bible.known.filter { $0.lang == "en" }.map(\.id).joined(separator: ", ") }

    /// Android's Experts.accuracy(faith = true): the rules every HolySteps AI answer follows first.
    static var accuracy: String { """
    Accuracy rules (these come first):
    - Be accurate before you are confident. If you aren't sure, say so plainly. Never invent facts, numbers, studies, quotes, names or sources.
    - Follow current mainstream guidance (CDC, WHO, ACOG, AAP, ACSM, AASM, American Heart Association, USPSTF). Give honest ranges rather than false precision, and say when experts disagree.
    - Never diagnose. Say clearly when something needs a doctor, and how soon. Never tell anyone to start, stop or change a prescribed medicine or dose; that's for their doctor or pharmacist. For over-the-counter medicine, follow the label or a pharmacist.
    - Emergencies: chest pain, trouble breathing, fainting, signs of stroke, heavy bleeding, or thoughts of suicide or self-harm: tell them to call 911 now (or 988, the Suicide & Crisis Lifeline, call or text, in the US; or their local emergency number).
    - Scripture: quote a verse word for word only when you are certain of the exact wording, and name the translation. Quote only from the translations this app carries (\(scriptureSources), or the older public one in the user's language, such as Reina-Valera 1909). Never quote the NIV, ESV, NLT, NKJV or another modern translation word for word, even if asked: give the reference and paraphrase. Otherwise give the reference and say it in your own words, clearly as a paraphrase. Only cite references that exist. Never present a saying as Bible that isn't ("God helps those who help themselves", "God won't give you more than you can handle", "cleanliness is next to godliness").
    - Keep what the text says apart from interpretation, and where Christians honestly differ (traditions, secondary doctrines), say so kindly instead of picking a side, unless their tradition is given above.
    - Faith and medical care go together: never suggest prayer instead of treatment, therapy or medicine.
    """ }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

/// Android's Adaptive Coach (WalkScreen AdaptiveCoachCard, AppViewModel.refreshAdaptiveCoachNote): one short plan for
/// today, written from real signals (rhythm, steps, today's plan and check-in). With the Fitness plan it also uses
/// how you slept, what you told the coach is weighing on you, and the tone of your latest journal entry (never quoted).
/// Cached for the day; when the AI can't be reached, a plain fallback is shown and not cached.
@MainActor
final class AdaptiveCoachModel: ObservableObject {
    static let shared = AdaptiveCoachModel()
    struct Stressor: Codable, Identifiable { var id = UUID().uuidString; let text: String; var at = Date() }

    @Published private(set) var note = UserDefaults.standard.string(forKey: "coachNote") ?? ""
    @Published private(set) var noteDate = UserDefaults.standard.string(forKey: "coachNoteDate") ?? ""
    @Published private(set) var loading = false
    @Published private(set) var sleepToday: String = {
        UserDefaults.standard.string(forKey: "coachSleepDate") == AppStore.dayKey() ? (UserDefaults.standard.string(forKey: "coachSleep") ?? "") : ""
    }()
    @Published private(set) var stressors: [Stressor] = (UserDefaults.standard.data(forKey: "coachStressors"))
        .flatMap { try? JSONDecoder().decode([Stressor].self, from: $0) } ?? []

    func logSleep(_ q: String, store: AppStore) {
        sleepToday = q
        UserDefaults.standard.set(q, forKey: "coachSleep"); UserDefaults.standard.set(AppStore.dayKey(), forKey: "coachSleepDate")
        Task { await refresh(store: store, force: true) }
    }

    func addStressor(_ text: String, store: AppStore) {
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
        guard !t.isEmpty else { return }
        stressors = Array((stressors + [Stressor(text: t)]).suffix(8)); saveStressors()
        Task { await refresh(store: store, force: true) }
    }

    func removeStressor(_ id: String) { stressors.removeAll { $0.id == id }; saveStressors() }
    private func saveStressors() { if let d = try? JSONEncoder().encode(stressors) { UserDefaults.standard.set(d, forKey: "coachStressors") } }

    func refresh(store: AppStore, force: Bool = false) async {
        let today = AppStore.dayKey()
        if !force && noteDate == today && !note.isEmpty { return }
        let plan = Coach.plan(store: store)
        let rhythm = Rhythm(store: store)
        let fallback = Self.fallback(plan.zone, rhythm.zone.reason)
        let deep = AccountStore.shared.canUse(.adaptiveCoach)
        let check = CheckInStore.shared.today
        let goal = UserDefaults.standard.integer(forKey: "stepGoal").nonZero ?? 8000
        var s = "Today's real signals for this user:\n"
        s += "- Body rhythm: \(rhythm.zone.reason)\n"
        s += "- Steps so far: \(StepsModel.shared.today) of a \(goal) daily goal\n"
        s += "- Today's coach plan: \(plan.zone.label)\(plan.routine.map { " — workout \"\($0.title)\" (\($0.nominalMinutes) min)" } ?? "")\(plan.devotional.map { ", scripture \($0.reference)" } ?? "")\n"
        if let c = check {
            s += "- Today's check-in (1-5): mood \(c.mood), energy \(c.energy), mental clarity \(c.clarity), spiritual peace \(c.peace)\(c.sleep.isEmpty ? "" : ", sleep \(c.sleep)")\n"
        } else { s += "- No check-in yet today\n" }
        if deep {
            if !sleepToday.isEmpty { s += "- Sleep quality logged today: \(sleepToday)\n" }
            let recent = stressors.suffix(3).map(\.text)
            if !recent.isEmpty { s += "- Stressors the user has personally named to their coach recently: \(recent.joined(separator: "; "))\n" }
            if let j = store.journal.max(by: { $0.created < $1.created })?.text, !j.isEmpty {
                s += "- Their most recent journal entry, for emotional tone ONLY, never quote it: \(j.prefix(1200))\n"
            }
        }
        s += "Write today's coaching plan grounded in at least one concrete signal above."
        let depth = deep
            ? "- You have this user's personal context (named stressors, sleep, journal tone) when given — weave in the MOST relevant one specifically. Don't list every signal; pick what matters most today."
            : "- Keep it to body rhythm and today's plan — don't invent personal context you weren't given."
        let system = """
        You are the HolySteps Adaptive Coach — a performance coach who writes exactly ONE short, specific plan for today, never a generic script.
        Rules:
        - 3-5 sentences, under 100 words total.
        - Reference at least one concrete real signal you were given — be specific, not vague ("your legs want a rest day", not "take care of yourself").
        \(depth)
        - Never diagnose or give medical advice; if something sounds like it needs a doctor, say so plainly and move on.
        - On a low or rest day, frame recovery as strategy, not failure.
        - Never quote journal text back to them verbatim; let it inform tone only.
        - End with one concrete, doable action for today.
        Tone: direct, warm, competent — like a real coach who actually looked at your data, not a push notification.

        \(AIProxy.accuracy)
        """
        loading = true
        defer { loading = false }
        if let reply = try? await AIProxy.chat(system: system, user: s) {
            note = reply; noteDate = today
            UserDefaults.standard.set(reply, forKey: "coachNote"); UserDefaults.standard.set(today, forKey: "coachNoteDate")
        } else {
            note = fallback   // not cached, so the next visit tries again
        }
    }

    private static func fallback(_ zone: EnergyZone, _ reason: String) -> String {
        let opener = switch zone {
        case .high: tr("You're in a strong rhythm today")
        case .steady: tr("Solid, steady pace today")
        case .low: tr("Ease up a little today")
        case .recover: tr("Today is a recovery day, and that's strategy, not failure")
        }
        return "\(opener). \(tr(reason))"
    }
}

private extension Int { var nonZero: Int? { self == 0 ? nil : self } }

struct AdaptiveCoachView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var coach = AdaptiveCoachModel.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var stressor = ""
    @State private var paywall = false

    var body: some View {
        let deep = account.canUse(.adaptiveCoach)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard(warm: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        T("🧠 FITNESS").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                        T("Adaptive Coach").font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                        T("Tell the coach how you slept and what's weighing on you; it shapes today's plan.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "safari").foregroundStyle(HS.peach)
                            T("Your Coach").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            if deep { T("Deep plan").font(.hs(11, .semibold)).foregroundStyle(HS.gold) }
                            if coach.loading { ProgressView().controlSize(.small) }
                        }
                        if coach.loading && coach.note.isEmpty {
                            T("Reading today's signals…").font(.hs(13)).foregroundStyle(HS.textMuted)
                        } else {
                            D(coach.note.isEmpty ? tr("Tap below to tell your coach what's on your mind, or just check back after your first log today.") : coach.note)
                                .font(.hs(13)).foregroundStyle(coach.loading ? HS.textMuted : HS.textSecondary)
                        }
                        if !deep {
                            Button { paywall = true } label: {
                                T("Unlock deep personalization — stressors, sleep & journal tone →").font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(HS.goldButton.opacity(0.16)))
                            }
                            .buttonStyle(.plain)
                        }
                        T("How did you sleep?").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted)
                        HStack(spacing: 8) {
                            ForEach([("poor", "😴 Poor"), ("okay", "😐 Okay"), ("great", "😊 Great")], id: \.0) { key, label in
                                let on = coach.sleepToday == key
                                Button { coach.logSleep(key, store: store) } label: {
                                    T(label).font(.hs(12, on ? .semibold : .regular)).foregroundStyle(on ? HS.gold : HS.textSecondary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(on ? HS.goldButton.opacity(0.22) : HS.overlay(0.04)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                        T("What's weighing on you today?").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted)
                        HStack {
                            TextField(tr("exam next week, new job stress…"), text: $stressor).textFieldStyle(.roundedBorder)
                                .onChange(of: stressor) { if stressor.count > 140 { stressor = String(stressor.prefix(140)) } }
                            Button {
                                if deep { coach.addStressor(stressor, store: store); stressor = "" } else { paywall = true }
                            } label: { T(deep ? "Tell coach" : "Tell coach 👑").font(.hs(12, .semibold)).foregroundStyle(stressor.isEmpty ? HS.textMuted : HS.gold) }
                            .disabled(stressor.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        ForEach(coach.stressors.suffix(3).reversed()) { s in
                            HStack {
                                D(s.text).font(.hs(12)).foregroundStyle(HS.textSecondary).lineLimit(1)
                                Spacer()
                                Button { coach.removeStressor(s.id) } label: { Image(systemName: "xmark").font(.caption).foregroundStyle(HS.textMuted) }
                                    .accessibilityLabel(tr("Remove"))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.04)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                T("The coach never diagnoses. If something feels wrong with your body, talk to your doctor.").font(.hs(11)).foregroundStyle(HS.textMuted)
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Adaptive Coach"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await coach.refresh(store: store) }
        .sheet(isPresented: $paywall) { PlansView(feature: .adaptiveCoach) }
    }
}
