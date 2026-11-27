import SwiftUI

// MARK: - Privacy promise bar

/// Mirrors Android's WomenNeedsCards.kt PrivacyPromiseBar.
struct PrivacyPromiseBar: View {
    var onMore: (() -> Void)? = nil
    var body: some View {
        Button {
            onMore?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(HS.faith)
                T("Never sold, never used for ads. Nothing is shared unless you choose to.")
                    .font(.hs(12))
                    .foregroundStyle(HS.textSecondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if onMore != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(HS.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(HS.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(HS.faith.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Peri stage card

/// Mirrors Android's WomenNeedsCards.kt PeriStageCard.
struct PeriStageCard: View {
    let starts: [Date]
    var onVitality: (() -> Void)? = nil

    private var stage: PeriStage { PeriStage.read(starts: starts) }

    var body: some View {
        let s = stage
        if s == .notEnough || s == .steady { return AnyView(EmptyView()) }
        return AnyView(
            GlassCard(glow: Color(hex: 0xC084FC)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(s == .twelveMonths ? "🌸" : "🌙")
                            .font(.system(size: 22))
                        T(s == .twelveMonths ? "Postmenopause" : s == .late ? "Late perimenopause" : "Early perimenopause")
                            .font(.hs(16, .bold))
                            .foregroundStyle(Color(hex: 0xC084FC))
                    }

                    switch s {
                    case .early:
                        T("Your cycles have been varying by 7 or more days — a common early sign of the menopause transition.")
                            .font(.hs(13))
                            .foregroundStyle(HS.textSecondary)
                        T("Hot flashes, night sweats, or mood changes? Talk to your doctor. Non-hormone options (CBT, low-dose SSRIs, gabapentin) and hormone therapy are both evidence-based choices.")
                            .font(.hs(12))
                            .foregroundStyle(HS.textMuted)
                    case .late:
                        T("You've had a gap of 60 or more days between periods — late perimenopause. Irregular cycles and symptoms may be more noticeable now.")
                            .font(.hs(13))
                            .foregroundStyle(HS.textSecondary)
                        T(PeriStage.seeADoctor)
                            .font(.hs(12, .semibold))
                            .foregroundStyle(Color(hex: 0xFCA5A5))
                    case .twelveMonths:
                        T("It has been 12 months since your last logged period — the clinical definition of menopause.")
                            .font(.hs(13))
                            .foregroundStyle(HS.textSecondary)
                        T(PeriStage.seeADoctor)
                            .font(.hs(12, .semibold))
                            .foregroundStyle(Color(hex: 0xFCA5A5))
                    default:
                        EmptyView()
                    }

                    if let v = onVitality {
                        Button(action: v) {
                            T("Open Vitality →")
                                .font(.hs(13, .semibold))
                                .foregroundStyle(Color(hex: 0xC084FC))
                        }
                        .buttonStyle(.plain)
                    }

                    T(PeriStage.source)
                        .font(.hs(10))
                        .foregroundStyle(HS.textSubtle)
                }
            }
        )
    }
}

// MARK: - Prediction range card

/// Mirrors Android's WomenNeedsCards.kt PredictionRangeCard.
struct PredictionRangeCard: View {
    let starts: [Date]
    let cycleLength: Int
    let predictedNext: Date
    let isIrregular: Bool

    private var range: PredictionRange {
        let stage = PeriStage.read(starts: starts)
        return PredictionRange.forNext(
            starts: starts,
            predictedNext: predictedNext,
            isIrregular: isIrregular,
            periStage: stage
        )
    }

    var body: some View {
        let r = range
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    T("Next period window")
                        .font(.hs(14, .semibold))
                        .foregroundStyle(HS.text)
                    Spacer()
                    confidencePill(r.confidence)
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(HS.peach)
                    if Calendar.current.isDate(r.earliest, inSameDayAs: r.latest) {
                        D(r.earliest.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.hs(15, .bold))
                            .foregroundStyle(HS.text)
                    } else {
                        D("\(r.earliest.formatted(.dateTime.month(.abbreviated).day())) – \(r.latest.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.hs(15, .bold))
                            .foregroundStyle(HS.text)
                    }
                }
                T(r.why)
                    .font(.hs(11))
                    .foregroundStyle(HS.textMuted)
            }
        }
    }

    @ViewBuilder private func confidencePill(_ c: PredictionRange.Confidence) -> some View {
        let (label, hex): (String, UInt32) = switch c {
        case .high:   ("High confidence",   0x34D399)
        case .medium: ("Moderate",          0xFBBF24)
        case .low:    ("Wide estimate",     0xF87171)
        }
        T(label)
            .font(.hs(10, .semibold))
            .foregroundStyle(Color(hex: hex))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: hex).opacity(0.15)))
    }
}

// MARK: - Pregnancy loss entry (More tab)

/// Mirrors Android's WomenNeedsCards.kt PregnancyLossEntry — the "quiet door" in the More tab.
struct PregnancyLossEntry: View {
    @ObservedObject private var loss = PregnancyLoss.shared
    @State private var showConfirm = false

    var body: some View {
        if loss.isActive { return AnyView(EmptyView()) }
        return AnyView(
            Button {
                showConfirm = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: 0xFDA4AF))
                    VStack(alignment: .leading, spacing: 2) {
                        T("Pregnancy loss support")
                            .font(.hs(14, .semibold))
                            .foregroundStyle(HS.text)
                        T("A gentle, private space. Nothing is shared.")
                            .font(.hs(12))
                            .foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(HS.textMuted)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(HS.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(hex: 0xFDA4AF).opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .alert("A safe, private space", isPresented: $showConfirm) {
                Button("Yes, open it") { loss.start() }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("This turns on a gentle healing path — only on your phone, never shared. Continue?")
            }
        )
    }
}

// MARK: - Pregnancy loss card (Today tab, when active)

/// Mirrors Android's WomenNeedsCards.kt PregnancyLossCard.
struct PregnancyLossCard: View {
    @ObservedObject private var loss = PregnancyLoss.shared
    @State private var tab = 0

    private let tabs = ["About this", "What to expect", "Care", "Faith"]

    var body: some View {
        guard loss.isActive else { return AnyView(EmptyView()) }
        return AnyView(
            GlassCard(glow: Color(hex: 0xFDA4AF), warm: true) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("🕊️").font(.system(size: 22))
                        T("Healing space").font(.hs(17, .bold)).foregroundStyle(Color(hex: 0xFDA4AF))
                        Spacer()
                        Button {
                            withAnimation { loss.pause() }
                        } label: {
                            T("Hide for now")
                                .font(.hs(11))
                                .foregroundStyle(HS.textMuted)
                        }
                        .buttonStyle(.plain)
                    }

                    T(PregnancyLoss.opening)
                        .font(.hs(12))
                        .foregroundStyle(HS.textSecondary)

                    // Mini tab bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(tabs.enumerated()), id: \.offset) { i, label in
                                Button { withAnimation { tab = i } } label: {
                                    T(label)
                                        .font(.hs(12, tab == i ? .semibold : .regular))
                                        .foregroundStyle(tab == i ? HS.text : HS.textMuted)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(tab == i ? Color(hex: 0xFDA4AF).opacity(0.22) : Color.clear)
                                        )
                                        .overlay(Capsule().strokeBorder(tab == i ? Color(hex: 0xFDA4AF).opacity(0.5) : Color.clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    switch tab {
                    case 0:
                        T(PregnancyLoss.notYourFault).font(.hs(13)).foregroundStyle(HS.text)
                        T(PregnancyLoss.grief).font(.hs(12)).foregroundStyle(HS.textMuted)
                    case 1:
                        T(PregnancyLoss.whatToExpect).font(.hs(13)).foregroundStyle(HS.text)
                        T(PregnancyLoss.tryingAgain).font(.hs(12)).foregroundStyle(HS.textMuted)
                    case 2:
                        lossAlert(icon: "phone.fill", hex: 0xFBBF24, text: PregnancyLoss.callDoctor)
                        lossAlert(icon: "cross.fill", hex: 0xF87171, text: PregnancyLoss.emergency)
                        T(PregnancyLoss.support).font(.hs(12)).foregroundStyle(HS.textMuted)
                    default:
                        T(PregnancyLoss.prayer)
                            .font(.hs(14, .medium))
                            .foregroundStyle(HS.textSecondary)
                            .italic()
                    }

                    T(PregnancyLoss.source).font(.hs(10)).foregroundStyle(HS.textSubtle)
                }
            }
        )
    }

    private func lossAlert(icon: String, hex: UInt32, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: hex))
                .frame(width: 20)
            T(text).font(.hs(12)).foregroundStyle(HS.textSecondary)
        }
    }
}

// MARK: - Paused-loss hero message (shown in the cycle day ring area)

/// Returns the subtitle string shown in Today when PregnancyLoss is active and paused, so the main
/// cycle ring can be replaced by a gentle holding message.
func lossHeroSubtitle(since: Date) -> String {
    let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: since),
                                               to: Calendar.current.startOfDay(for: Date())).day ?? 0
    if days <= 1 { return "Predictions are paused while you heal. This space is here whenever you need it." }
    return "Predictions are paused while you heal — day \(days). This space is here whenever you need it."
}

// MARK: - Cycle facts card (Insights tab)

/// Mirrors Android's WomenNeedsCards.kt CycleFactsCard.
struct CycleFactsCard: View {
    @State private var expanded: UUID? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 2) {
                T("Cycle Q&A")
                    .font(.hs(15, .bold))
                    .foregroundStyle(HS.peach)
                    .padding(.bottom, 6)

                ForEach(CycleFacts.all) { fact in
                    let isOpen = expanded == fact.id
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            expanded = isOpen ? nil : fact.id
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                T(fact.question)
                                    .font(.hs(13, .semibold))
                                    .foregroundStyle(HS.text)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HS.textMuted)
                            }
                            .padding(.vertical, 10)

                            if isOpen {
                                T(fact.answer)
                                    .font(.hs(12))
                                    .foregroundStyle(HS.textSecondary)
                                    .padding(.bottom, 4)
                                T(fact.source)
                                    .font(.hs(10))
                                    .foregroundStyle(HS.textSubtle)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if fact.id != CycleFacts.all.last?.id {
                        Divider().overlay(HS.overlay(0.12))
                    }
                }
            }
        }
    }
}
