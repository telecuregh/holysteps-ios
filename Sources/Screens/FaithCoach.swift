import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

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

    private let starters = ["I'm anxious about tomorrow", "How do I forgive someone?", "I feel far from God", "Help me pray for my family"]

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            T("Faith coach").font(.hs(28, .semibold)).foregroundStyle(HS.text).padding(.top, 58)
                            T("Private. It runs on this iPhone, and nothing you type leaves it.").font(.hs(13)).foregroundStyle(HS.textMuted)
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
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundStyle(HS.gold)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thinking)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .sheet(isPresented: $paywall) { PlansView(feature: .faithCoach) }
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        guard account.canUse(.faithCoach) else { paywall = true; return }
        draft = ""
        messages.append(.init(mine: true, text: text))
        thinking = true
        Task {
            let reply = await ask(text)
            thinking = false
            messages.append(.init(mine: false, text: reply))
        }
    }

    private func ask(_ text: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let s = (session as? LanguageModelSession) ?? LanguageModelSession(instructions: FaithCoach.instructions)
            session = s
            do { return try await s.respond(to: text).content }
            catch {
                session = nil
                return tr("Let's try that again in a moment. Meanwhile, Philippians 4:6-7: be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.")
            }
        }
        #endif
        return ""
    }
}
