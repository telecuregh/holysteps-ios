import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Free quota (3 questions / day for non-subscribers)

enum FreeAiQuota {
    private static let countKey = "freeAiQueriesLeft"
    private static let dateKey  = "freeAiQueriesDate"
    static let daily = 3

    /// Questions remaining today (non-subscribers). Always 0 for subscribers.
    static var queriesLeft: Int {
        let today = todayString()
        if UserDefaults.standard.string(forKey: dateKey) != today {
            // New day — reset
            UserDefaults.standard.set(daily, forKey: countKey)
            UserDefaults.standard.set(today, forKey: dateKey)
        }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    /// Decrement the counter after a successful send.
    static func consume() {
        let _ = queriesLeft          // ensures today's date is set
        let n = max(0, UserDefaults.standard.integer(forKey: countKey) - 1)
        UserDefaults.standard.set(n, forKey: countKey)
    }

    private static func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Faith coach engine

/// A private faith coach that runs on Apple's on-device model (iOS 26, Apple Intelligence iPhones).
/// Nothing typed here leaves the phone. Shown only where the model is ready; part of the Faith plan.
enum FaithCoach {
    static var available: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static var instructions: String {
        let lang = I18n.shared.locale.language.languageCode?.identifier == "es" ? "Spanish" : "US English"
        return """
        You are a warm, humble Christian faith coach inside the HolySteps app. Reply in \(lang).
        Encourage the person from Scripture: quote one or two relevant Bible verses with their references (KJV wording), \
        tie them to the person's real situation, and end with one small, practical step and a one-sentence prayer they can pray.
        Keep replies under 180 words. Never claim to be a pastor, doctor or counselor, and never diagnose.
        If the person mentions wanting to hurt themselves or someone else, or being in danger, tell them gently to call or text 988 \
        (or 911 in an emergency) right now and to reach a trusted person, before anything else.
        """
    }
}

struct FaithCoachMessage: Identifiable, Equatable {
    let id = UUID()
    let mine: Bool
    var text: String
}

struct FaithCoachView: View {
    @ObservedObject private var account = AccountStore.shared
    @State private var messages: [FaithCoachMessage] = []
    @State private var draft = ""
    @State private var thinking = false
    @State private var paywall = false
    @State private var session: AnyObject?
    @State private var queriesLeft = FreeAiQuota.queriesLeft

    @EnvironmentObject private var store: AppStore

    private var starters: [String] {
        switch store.gender {
        case "female":
            return ["How can I deepen my prayer life?",
                    "What does the Bible say about strength for women?",
                    "I'm feeling overwhelmed — help me find peace in scripture"]
        case "male":
            return ["How can I be a man of God?",
                    "What does the Bible say about purpose and strength?",
                    "I'm struggling with discipline — what does scripture say?"]
        default:
            return ["How can I deepen my prayer life?",
                    "What does the Bible say about strength?",
                    "Help me find peace in scripture"]
        }
    }

    private var isPaid: Bool { account.hasAnyPlan }

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    T("Faith coach").font(.hs(28, .semibold)).foregroundStyle(HS.text)
                    if isPaid {
                        T("Unlimited faith guidance").font(.hs(12)).foregroundStyle(HS.gold)
                    } else {
                        T("\(queriesLeft) free question\(queriesLeft == 1 ? "" : "s") remaining today")
                            .font(.hs(12)).foregroundStyle(queriesLeft > 0 ? HS.textMuted : HS.error)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 58).padding(.bottom, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            T(FaithCoach.available
                                ? "Private. Your questions are answered on this iPhone."
                                : "Your questions are answered by a secure AI and are not shared with others.")
                                .font(.hs(13)).foregroundStyle(HS.textMuted)
                            if messages.isEmpty {
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
                                    D(m.text).font(.hs(15)).foregroundStyle(m.mine ? HS.onGold : HS.text).padding(12)
                                        .background(RoundedRectangle(cornerRadius: 16).fill(m.mine ? HS.goldButton : HS.cardFill))
                                        .textSelection(.enabled)
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
                    TextField(tr("What's on your heart?"), text: $draft, axis: .vertical)
                        .lineLimit(1...4).font(.hs(15)).padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
                    Button { send(draft) } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                            .foregroundStyle((!isPaid && queriesLeft <= 0) ? HS.textMuted : HS.gold)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thinking)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .sheet(isPresented: $paywall) { PlansView(feature: .faithCoach) }
        .onAppear { queriesLeft = FreeAiQuota.queriesLeft }
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        // Paid users: unlimited. Free users: 3 questions per day.
        if !isPaid {
            guard queriesLeft > 0 else { paywall = true; return }
        }
        draft = ""
        let priorMessages = messages          // snapshot before the new user bubble
        messages.append(.init(mine: true, text: text))
        thinking = true
        if !isPaid {
            FreeAiQuota.consume()
            queriesLeft = FreeAiQuota.queriesLeft
        }
        Task {
            let reply = await ask(text, history: priorMessages)
            thinking = false
            messages.append(.init(mine: false, text: reply))
        }
    }

    // Try Apple Intelligence (iOS 26+), fall back to Gemini cloud on older devices.
    private func ask(_ text: String, history: [FaithCoachMessage]) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                let s = (session as? LanguageModelSession) ?? LanguageModelSession(instructions: FaithCoach.instructions)
                session = s
                if let reply = try? await s.respond(to: text).content, !reply.isEmpty {
                    return reply
                }
                session = nil   // reset so next call rebuilds it; fall through to cloud
            }
        }
        #endif
        return await askCloud(text, history: history)
    }

    // Gemini OpenAI-compatible endpoint — same provider Android uses, works on all iOS versions.
    private func askCloud(_ text: String, history: [FaithCoachMessage]) async -> String {
        guard
            let key  = Bundle.main.infoDictionary?["GeminiApiKey"]  as? String, !key.isEmpty,
            let base = Bundle.main.infoDictionary?["GeminiBaseUrl"] as? String, !base.isEmpty
        else {
            return tr("Faith guidance will be available soon. Meanwhile: \"Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.\" — Phil 4:6")
        }
        let normalizedBase = base.hasSuffix("/") ? base : "\(base)/"
        guard let url = URL(string: "\(normalizedBase)chat/completions") else {
            return tr("Could not reach the faith coach right now. Please try again.")
        }

        // Build messages: system + prior conversation (last 10 turns) + current user message
        var msgs: [[String: String]] = [["role": "system", "content": FaithCoach.instructions]]
        for m in history.suffix(10) {
            msgs.append(["role": m.mine ? "user" : "assistant", "content": m.text])
        }
        msgs.append(["role": "user", "content": text])

        let bodyObj: [String: Any] = [
            "model": "gemini-3.1-flash-lite",
            "messages": msgs,
            "max_tokens": 400,
            "temperature": 0.7
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyObj) else {
            return tr("Could not reach the faith coach right now. Please try again.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = bodyData
        req.timeoutInterval = 30

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let first   = choices.first,
               let msg     = first["message"] as? [String: Any],
               let content = msg["content"] as? String,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch { }

        return tr("I'm having trouble connecting right now. Please try again in a moment. 🙏")
    }
}
