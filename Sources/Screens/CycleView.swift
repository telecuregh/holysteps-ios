import SwiftUI

/// The fourth tab: Android's CycleScreen for women (Today, Plan, Insights, More), and a men's wellness rhythm for men.
struct CycleView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        if store.gender == "male" { MensWellnessView() } else { CycleLockGate { WomensCycleView() } }
    }
}

private func prettyDate(_ d: Date) -> String { d.formatted(.dateTime.month(.abbreviated).day().locale(I18n.shared.locale)) }

struct WomensCycleView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var log = CycleLog.shared
    @ObservedObject private var preg = PregnancyMode.shared
    @ObservedObject private var loss = PregnancyLoss.shared
    @State private var tab = 0
    @State private var planTab = 0
    @State private var showLog = false
    @State private var confirmDelete = false
    @State private var showPrivacyMore = false

    var body: some View {
        let rhythm = Rhythm(store: store)
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenPhoto(name: "screen_cycle")
                        VStack(alignment: .leading, spacing: 0) {
                            T("Cycle").font(.hs(28)).foregroundStyle(HS.text)
                            ItalicAccent(text: "your rhythm & season", size: 19)
                        }
                        .padding(.top, 40).padding(.horizontal, 20).padding(.bottom, 12)
                        SubTabs(tabs: ["Today", "Plan", "Insights", "More"], selected: $tab)
                        switch tab {
                        case 0: today(rhythm)
                        case 1: plan(rhythm)
                        case 2: insights(rhythm)
                        default: more
                        }
                        Spacer().frame(height: 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLog) { LogPeriodSheet { d in store.logPeriodStart(d); loss.periodLogged() } }
            .sheet(isPresented: $showPrivacyMore) { CyclePrivacySheet() }
        }
    }

    // MARK: Today

    @ViewBuilder private func today(_ r: Rhythm) -> some View {
        Spacer().frame(height: 12)
        // Privacy promise bar — always visible at the top
        PrivacyPromiseBar { showPrivacyMore = true }
            .padding(.horizontal, 20).padding(.bottom, 8)
        // Pregnancy-loss healing card (when active and not hidden)
        if loss.isActive && !loss.paused {
            PregnancyLossCard().padding(.horizontal, 20).padding(.bottom, 8)
        }
        if loss.isActive && loss.paused {
            GlassCard { Button("Return to healing space") { loss.resume() }
                .font(.hs(13, .semibold)).foregroundStyle(Color(hex: 0xFDA4AF))
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
        }
        if !preg.on && UserDefaults.standard.string(forKey: "cycleGoal") == "PREGNANT" {
            PregnancySettings().padding(.horizontal, 20).padding(.bottom, 12)
        }
        if preg.on {
            // Pregnancy: there is no cycle to predict, so the week replaces the cycle ring.
            PregnancyCard().padding(.horizontal, 20)
            CoverCard(emoji: "🤰", title: "Pregnancy tools", subtitle: "Kick counter, contraction timer and appointments", tint: 0xF472B6) { PregnancyToolsView() }
                .padding(.horizontal, 20).padding(.top, 12)
        } else if loss.isActive {
            GlassCard(glow: Color(hex: 0xFDA4AF), warm: true) {
                VStack(spacing: 10) {
                    Text("🕊️").font(.system(size: 40))
                    if let since = loss.since {
                        T(lossHeroSubtitle(since: since))
                            .font(.hs(14, .medium)).foregroundStyle(HS.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Button { showLog = true } label: {
                        T("Log period start").font(.hs(14, .bold)).foregroundStyle(HS.onGold)
                            .padding(.horizontal, 20).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        } else {
        GlassCard(glow: Color(hex: 0xE57A9E), warm: true) {
            VStack(spacing: 0) {
                if let day = r.cycleDay, let phase = r.phase, let last = store.periodStarts.max() {
                    let pred = CycleLogic.predict(lastStart: last, length: store.cycleLength, periodLength: store.periodLength)
                    ZStack {
                        Circle().stroke(HS.overlay(0.10), lineWidth: 6.3)
                        Circle().trim(from: 0, to: max(0.001, min(1, Double(day) / Double(max(1, store.cycleLength)))))
                            .stroke(HS.isLight ? HS.cycle : Color(hex: 0xF3D5C0), style: StrokeStyle(lineWidth: 6.3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            T("Day \(day)").font(.hs(30)).foregroundStyle(HS.text)
                            T(phase == .menstrual ? "period · of \(store.cycleLength)" : "of \(store.cycleLength)").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    .frame(width: 150, height: 150)
                    T("\(phase.emoji) \(tr(phase.label)) phase").font(.hs(20, .bold)).foregroundStyle(HS.peach).padding(.top, 10)
                    T(pred.daysLate == 1 ? "Period is 1 day late. Log it when it starts"
                      : pred.daysLate > 1 ? "Period is \(pred.daysLate) days late. Log it when it starts" + (pred.daysLate >= 7 ? ", or consider a pregnancy test" : "")
                      : pred.daysUntil == 0 ? "Period expected today" : pred.daysUntil == 1 ? "Period expected tomorrow" : "Next period in \(pred.daysUntil) days")
                        .font(.hs(14)).foregroundStyle(HS.textSecondary).multilineTextAlignment(.center)
                } else {
                    Image(systemName: "camera.macro").font(.system(size: 46)).foregroundStyle(HS.cycle)
                    T("Let's set up your cycle").font(.hs(20, .bold)).foregroundStyle(HS.text).padding(.top, 8)
                    T("Log the first day of your last period to unlock your phase, predictions, and daily wellness plan.")
                        .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                }
                Button { showLog = true } label: {
                    T(store.periodStarts.isEmpty ? "Log my last period" : "Log period start").font(.hs(15, .bold)).foregroundStyle(HS.onGold)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
                }
                .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        }

        if r.phase == .menstrual && !preg.on {
            SectionHeader(title: "Flow today").padding(.top, 8)
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    T("Day \(r.cycleDay ?? 1) of about \(store.periodLength)").font(.hs(11)).foregroundStyle(HS.textMuted)
                    FlowBandPicker(selected: log.flow[AppStore.dayKey()]) { f in log.setFlow(f) }
                }
            }
            .padding(.horizontal, 20)
            PeriodProductsCard(periodDay: r.cycleDay ?? 1).padding(.horizontal, 20).padding(.top, 12)
        }

        SectionHeader(title: "How do you feel today?").padding(.top, 8)
        let selected = log.today
        T(selected.isEmpty ? "Tap everything that applies — first log of the day earns +5 pts" : "✓ \(selected.count) logged for today · saved to your history")
            .font(.hs(12)).foregroundStyle(selected.isEmpty ? HS.textMuted : HS.body).padding(.horizontal, 20)
        VStack(spacing: 0) {
            ForEach(0..<(CycleLog.common.count / 2), id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(CycleLog.common[(row * 2)...(row * 2 + 1)], id: \.self) { s in
                        let on = selected.contains(s)
                        Button { log.toggle(s) } label: {
                            D((on ? "✓ " : "") + tr(s)).font(.hs(12)).foregroundStyle(on ? HS.text : HS.textSecondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 11).padding(.horizontal, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(on ? HS.goldButton.opacity(0.22) : HS.cardFill))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Color(hex: 0xD9B49F) : Color(hex: 0xD9B49F).opacity(0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 20).padding(.top, 8)
        let tips = selected.sorted().compactMap { CycleLog.relief($0) }
        if !tips.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    T("Care for today").font(.hs(14, .bold)).foregroundStyle(HS.peach)
                    ForEach(tips, id: \.self) { T($0).font(.hs(12)).foregroundStyle(HS.textSecondary) }
                }
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        if !preg.on {
            PeriStageCard(starts: store.periodStarts).padding(.horizontal, 20).padding(.top, 12)
            BirthControlCard().padding(.horizontal, 20).padding(.top, 12)
            let ov = store.periodStarts.max().map { CycleLogic.predict(lastStart: $0, length: store.cycleLength, periodLength: store.periodLength).ovulation }
            FertilitySignsCard(predictedOvulation: ov).padding(.horizontal, 20).padding(.top, 12)
        }
    }

    // MARK: Plan

    @ViewBuilder private func plan(_ r: Rhythm) -> some View {
        let phase = r.phase ?? .follicular
        if let p = PhasePlan.forPhase(phase) {
            SectionHeader(title: "Your \(phase.label) plan").padding(.top, 8)
            GlassCard(glow: Color(hex: 0xE57A9E)) {
                VStack(alignment: .leading, spacing: 12) {
                    T(p.whyFeel).font(.hs(12, .medium)).foregroundStyle(HS.textMuted)
                    HStack(spacing: 8) {
                        ForEach(Array(["🏃 Move", "🥗 Nourish", "🧠 Mind"].enumerated()), id: \.offset) { i, label in
                            Button { planTab = i } label: {
                                T(label).font(.hs(12, .semibold)).foregroundStyle(planTab == i ? HS.peach : HS.text)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(planTab == i ? HS.goldButton.opacity(0.25) : HS.overlay(0.04)))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(planTab == i ? Color(hex: 0xD9B49F) : .clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    switch planTab {
                    case 0:
                        T(p.move).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        bullets(p.moveIdeas)
                        Button { TabRouter.shared.open(tab: 2) } label: { T("Start a walk →").font(.hs(13, .semibold)).foregroundStyle(HS.faith) }
                    case 1:
                        T("Eat more").font(.hs(11, .bold)).foregroundStyle(HS.peach)
                        bullets(p.eatMore)
                        T("Ease up on").font(.hs(11, .bold)).foregroundStyle(HS.textMuted)
                        bullets(p.limitFoods)
                        T("🍽️ Try: \(p.mealIdea)").font(.hs(12)).foregroundStyle(HS.text)
                    default:
                        T(p.mind).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        T("Reflect on").font(.hs(11, .bold)).foregroundStyle(HS.peach)
                        bullets(p.journalPrompts)
                        T("💡 \(p.mindsetTip)").font(.hs(12, .medium)).foregroundStyle(HS.text)
                    }
                }
            }
            .padding(.horizontal, 20)
            if r.phase == nil {
                T("Log your last period and this plan follows your cycle.").font(.hs(12)).foregroundStyle(HS.textMuted).padding(.horizontal, 20).padding(.top, 8)
            }
        }
    }

    private func bullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    D("•").font(.hs(14, .bold)).foregroundStyle(HS.peach)
                    T(item).font(.hs(13)).foregroundStyle(HS.text)
                }
            }
        }
    }

    // MARK: Insights

    @ViewBuilder private func insights(_ r: Rhythm) -> some View {
        FirstCycleReportCard().padding(.horizontal, 20).padding(.top, 8)
        if let last = store.periodStarts.max(), let day = r.cycleDay {
            let pred = CycleLogic.predict(lastStart: last, length: store.cycleLength, periodLength: store.periodLength)
            SectionHeader(title: "Predictions").padding(.top, 8)
            HStack(spacing: 12) {
                predCard("Next period", prettyDate(pred.nextPeriod), 0xF43F5E)
                predCard("Ovulation", prettyDate(pred.ovulation), 0xF59E0B)
            }
            .padding(.horizontal, 20)
            // Confidence-aware prediction window
            let isIrregular = CycleLogic.cycleLengths(store.periodStarts).suffix(6).map { Double($0) }.reduce(0, +) / max(1, Double(min(6, CycleLogic.cycleLengths(store.periodStarts).count))) != Double(store.cycleLength)
            PredictionRangeCard(starts: store.periodStarts, cycleLength: store.cycleLength, predictedNext: pred.nextPeriod, isIrregular: isIrregular)
                .padding(.horizontal, 20).padding(.top, 8)
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    T("Fertile window").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                    D("\(prettyDate(pred.fertileStart)) – \(prettyDate(pred.fertileEnd))").font(.hs(13)).foregroundStyle(HS.textMuted)
                    T("Estimates only, and not a method of birth control: no day is safe. HolySteps can't tell you which days are. Talk with a doctor, or learn natural family planning from a certified instructor.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
            }
            .padding(.horizontal, 20).padding(.top, 12)
            SectionHeader(title: "Your cycle map").padding(.top, 8)
            cycleStrip(today: day)
            SectionHeader(title: "Period history").padding(.top, 8)
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    let lens = CycleLogic.cycleLengths(store.periodStarts)
                    T(lens.isEmpty ? "Cycle length: \(store.cycleLength) days" : "Average cycle: \(store.cycleLength) days · from \(lens.count) logged cycles")
                        .font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    ForEach(store.periodStarts.sorted(by: >), id: \.self) { d in
                        HStack {
                            D(d.formatted(.dateTime.month(.wide).day().year().locale(I18n.shared.locale))).font(.hs(14)).foregroundStyle(HS.textSecondary)
                            Spacer()
                            Button { store.removePeriodStart(d) } label: { Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(HS.textMuted).frame(width: 32, height: 32) }
                                .accessibilityLabel(tr("Remove"))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        } else {
            GlassCard {
                T("Log your last period to see predictions, your fertile window and your cycle map.").font(.hs(13)).foregroundStyle(HS.textMuted)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        // Cycle Q&A facts card
        SectionHeader(title: "Cycle Q&A").padding(.top, 8)
        CycleFactsCard().padding(.horizontal, 20)
        let recent = log.symptoms.sorted { $0.key > $1.key }.prefix(7)
        if !recent.isEmpty {
            SectionHeader(title: "Recent logs").padding(.top, 8)
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(recent), id: \.key) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            D(AppStore.date(fromKey: entry.key).map(prettyDate) ?? entry.key).font(.hs(11)).foregroundStyle(HS.textMuted)
                            D(entry.value.map { tr($0) }.joined(separator: " · ")).font(.hs(13)).foregroundStyle(HS.text)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func predCard(_ label: String, _ value: String, _ hex: UInt32) -> some View {
        GlassCard(glow: Color(hex: hex)) {
            VStack(alignment: .leading, spacing: 2) {
                T(label).font(.hs(11)).foregroundStyle(HS.textMuted)
                D(value).font(.hs(16, .bold)).foregroundStyle(HS.readable(hex))
            }
        }
    }

    private func cycleStrip(today: Int) -> some View {
        let len = store.cycleLength
        return VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...max(1, len), id: \.self) { d in
                    let c = Color(hex: CyclePhase.forDay(d, periodLength: store.periodLength, cycleLength: len).colorHex)
                    RoundedRectangle(cornerRadius: 3).fill(d == today ? c : c.opacity(0.4))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(d == today ? HS.faith : .clear, lineWidth: 1))
                        .frame(height: d == today ? 34 : 22)
                }
            }
            HStack {
                ForEach([CyclePhase.menstrual, .follicular, .ovulation, .luteal], id: \.self) { p in
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: p.colorHex)).frame(width: 8, height: 8)
                        T(p.label).font(.hs(10)).foregroundStyle(HS.textMuted)
                    }
                    if p != .luteal { Spacer() }
                }
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Day \(today) of \(len)"))
    }

    // MARK: More

    @ViewBuilder private var more: some View {
        PregnancySettings().padding(.horizontal, 20).padding(.top, 16)
        ShareWithHusbandCard().padding(.horizontal, 20).padding(.top, 12)
        BodyEnergyEntryCard().padding(.horizontal, 20).padding(.top, 12)
        NewParentsEntryCard().padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "🤕", title: "Headache diary", subtitle: "Log headaches and see what goes with yours") { HeadacheView() }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "❤️", title: "Body basics", subtitle: "Water, health numbers, habits and medicine reminders", tint: 0xF472B6) { BodyBasicsView().environmentObject(store) }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "🩺", title: "Checkups & self-checks", subtitle: "Screenings and vaccines for your age, and monthly self-checks", tint: 0xF472B6) { CheckupsView(women: true) }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "🧠", title: "Mood check-in", subtitle: "A private 1-minute check, with 988 one tap away", tint: 0xA78BFA) { MoodCheckView() }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "🌸", title: "Mood and tests", subtitle: "A daily mood scale and a pregnancy-test log", tint: 0xF472B6) { CycleMoodTestsView() }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "📈", title: "Symptom severity", subtitle: "For PMS, PMDD, PCOS or endometriosis: rate pain and mood daily", tint: 0xF472B6) { SeverityView().environmentObject(store) }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "🤰", title: "Pregnancy tools", subtitle: "Kick counter, contraction timer and appointments", tint: 0xF472B6) { PregnancyToolsView() }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "📥", title: "Bring your data", subtitle: "Move your period history from Flo, Clue or Apple Health", tint: 0xF472B6) { BringDataView().environmentObject(store) }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "💞", title: "Partner coaching", subtitle: "Your husband gets a daily tip on how to support you, never your data", tint: 0xF472B6) { PartnerCoachingView().environmentObject(store) }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "🌸", title: "Cycle Circles", subtitle: "Small private support circles, up to 12 women, by invitation", tint: 0xF472B6) { CycleCirclesView().environmentObject(store) }
            .padding(.horizontal, 20).padding(.top, 12)
        CoverCard(emoji: "🪞", title: "Skin journal", subtitle: "A private photo a day, and how your skin follows your cycle", tint: 0xF472B6) { SkinJournalView().environmentObject(store) }
            .padding(.horizontal, 20).padding(.top, 12)
        // Pregnancy-loss entry — quiet door, only shown when not already active
        PregnancyLossEntry().padding(.horizontal, 20).padding(.top, 12)
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                T("🔒 Where your cycle data lives").font(.hs(15, .bold)).foregroundStyle(HS.text)
                privacyLine("On this phone only", "Your period dates, flow and symptoms are kept on this phone. HolySteps doesn't upload them.")
                privacyLine("Shared only if you choose", "Nothing about your cycle is shared with anyone.")
                CycleLockSettings()
                HealthImportButton()
                CycleExportButton()
                DoctorSummaryButton()
                Button(role: .destructive) { confirmDelete = true } label: { T("Delete my cycle data").font(.hs(13)).foregroundStyle(Color(hex: 0xFCA5A5)) }
                T("HolySteps is not a medical device. Talk to a doctor about heavy bleeding, severe pain, or missed periods.")
                    .font(.hs(11)).foregroundStyle(HS.textSubtle)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16)
        .alert(tr("Delete your cycle data?"), isPresented: $confirmDelete) {
            Button(tr("Delete"), role: .destructive) { store.periodStarts = []; store.cycleLength = 28; log.erase()
                CycleMoodTests.shared.erase(); SeverityLog.shared.erase(); PregTools.shared.erase()
                FertilitySigns.shared.erase(); PeriodProducts.shared.erase(); BirthControl.shared.erase(); PregnancyMode.shared.end() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("This removes every period date, flow and symptom log from this phone. It can't be undone.") }
    }

    private func privacyLine(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            T(title).font(.hs(13, .semibold)).foregroundStyle(HS.text)
            T(body).font(.hs(12)).foregroundStyle(HS.textMuted)
        }
    }
}

/// Android's LogPeriodDialog: pick the day it started (up to today).
struct LogPeriodSheet: View {
    let onLog: (Date) -> Void
    @State private var date = Date()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HSSheet(title: "When did it start?") {
            VStack(spacing: 18) {
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical).labelsHidden().tint(HS.goldButton)
                GoldButton(title: "Log period start") { onLog(date); dismiss() }
            }
            .padding(20)
        }
        .presentationDetents([.large])
    }
}

/// Stepped horizontal track picker for menstrual flow: Spotting → Light → Medium → Heavy.
/// Circles grow in size and fill with the rose accent when selected; labels sit underneath.
struct FlowBandPicker: View {
    let selected: String?
    let onSelect: (String) -> Void
    private let flows = CycleLog.flows           // ["Spotting", "Light", "Medium", "Heavy"]
    private let dotSizes: [CGFloat] = [13, 17, 21, 26]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(flows.enumerated()), id: \.offset) { i, f in
                let on = selected == f
                Button { onSelect(f) } label: {
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(on ? Color(hex: 0xD9B49F) : Color(hex: 0xD9B49F).opacity(0.18))
                                .frame(width: dotSizes[i], height: dotSizes[i])
                                .shadow(color: on ? Color(hex: 0xD9B49F).opacity(0.5) : .clear, radius: 4)
                            if on {
                                Circle()
                                    .strokeBorder(Color(hex: 0xEDC9AE), lineWidth: 1.5)
                                    .frame(width: dotSizes[i] + 4, height: dotSizes[i] + 4)
                            }
                        }
                        .frame(width: 32, height: 32)
                        T(f)
                            .font(.hs(10, on ? .semibold : .regular))
                            .foregroundStyle(on ? HS.text : HS.textMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .top) {
            Rectangle()
                .fill(Color(hex: 0xD9B49F).opacity(0.28))
                .frame(height: 2)
                .padding(.horizontal, 28)
                .padding(.top, 15)
        }
    }
}

/// Android's MensHealthScreen: the week's rhythm (push Monday and Tuesday, build midweek, rest Friday, reset at the
/// weekend), today's energy and focus, and the phase's move and nourish plan (the whole plan comes with Wellness).
struct MensWellnessView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var checkIns = CheckInStore.shared
    @ObservedObject private var account = AccountStore.shared
    @ObservedObject private var steps = StepsModel.shared
    @State private var tab = 0
    @State private var planTab = 0
    @State private var energy = 0
    @State private var focus: Set<String> = []
    @State private var paywall = false

    private static let colors: [MensPhase: UInt32] = [.peak: 0x10B981, .build: 0xF59E0B, .rest: 0x8B5CF6, .reset: 0xF43F5E]

    var body: some View {
        let phase = MensPhase.today()
        let color = HS.readable(Self.colors[phase] ?? 0x10B981)
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenPhoto(name: ScreenPhoto.daily("screen_wellness_men")).id("top")
                        VStack(alignment: .leading, spacing: 4) {
                            T("⚡ Men's Wellness").font(.hs(13, .bold)).foregroundStyle(color)
                            D(tr(greeting) + ", " + (store.name.isEmpty ? tr("Brother") : store.name)).font(.hs(22, .bold)).foregroundStyle(HS.text)
                            D(Date().formatted(.dateTime.weekday(.wide).locale(I18n.shared.locale))).font(.hs(13)).foregroundStyle(HS.textMuted)
                        }
                        .padding(.top, 40).padding(.horizontal, 20).padding(.bottom, 12)
                        SubTabs(tabs: ["Today", "Plan"], selected: $tab).padding(.bottom, 16)
                        if tab == 0 { today(phase, color) } else { plan(phase, color) }
                        CoverCard(emoji: "❤️", title: "Body basics", subtitle: "Water, health numbers, habits and medicine reminders", tint: 0x8B5CF6) { BodyBasicsView().environmentObject(store) }
                            .padding(.horizontal, 20).padding(.top, 16)
                        CoverCard(emoji: "🛡️", title: "Checkups & self-checks", subtitle: "What's due for your age, vaccines and monthly self-checks", tint: 0x8B5CF6) { CheckupsView(women: false) }
                            .padding(.horizontal, 20).padding(.top, 16)
                        CoverCard(emoji: "🧠", title: "Mood check-in", subtitle: "A private 1-minute check, with 988 one tap away", tint: 0xA78BFA) { MoodCheckView() }
                            .padding(.horizontal, 20).padding(.top, 12)

                        // ── HEALTH SCREENINGS ──────────────────────────────
                        MensTabSectionHeader(emoji: "🩺", title: "Health Screenings", subtitle: "Most men skip these. Your age-based checklist.")
                            .padding(.top, 24)
                        CoverCard(emoji: "🏴", title: "Testicular self-exam", subtitle: "Monthly reminder. Most common cancer in men 15–35. 2 minutes.", tint: 0x10B981) { MensScreeningDetailView(item: "testicular") }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🔬", title: "PSA + Prostate", subtitle: "Start at 40 (Black men) or 50. Log your last test and when to recheck.", tint: 0x10B981) { MensScreeningDetailView(item: "psa") }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🩻", title: "Colorectal screening", subtitle: "Colonoscopy at 45. Earlier if family history. Catches cancer before symptoms.", tint: 0x10B981) { MensScreeningDetailView(item: "colorectal") }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "☀️", title: "Skin mole check", subtitle: "Annual. ABCDE: Asymmetry, Border, Color, Diameter, Evolving.", tint: 0xF59E0B) { MensScreeningDetailView(item: "skin") }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🩸", title: "BP · Cholesterol · A1c", subtitle: "Log your numbers and when to recheck. Heart disease is the #1 killer of men.", tint: 0xF43F5E) { MensVitalsLogView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "⚡", title: "Testosterone awareness", subtitle: "Symptoms of low T and when to test. Best tested in the morning.", tint: 0xF59E0B) { MensScreeningDetailView(item: "testosterone") }
                            .padding(.horizontal, 20).padding(.top, 8)

                        // ── MENTAL HEALTH ──────────────────────────────────
                        MensTabSectionHeader(emoji: "🧠", title: "Mental Health", subtitle: "6 million men get depression yearly. Most never say it.")
                            .padding(.top, 24)
                        CoverCard(emoji: "😔", title: "Depression check", subtitle: "Men show depression as anger and risk-taking. PHQ-9 built for men.", tint: 0x8B5CF6) { MensDepressionCheckView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🔥", title: "Anger journal", subtitle: "Log triggers privately. Anger is often depression in disguise.", tint: 0xF43F5E) { MensAngerJournalView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🕊️", title: "Grief support", subtitle: "Men process loss through action and silence, not tears. Find your path.", tint: 0x8B5CF6) { MensGriefView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        if account.runningPlans.contains(.faith) {
                            CoverCard(emoji: "🔒", title: "Pornography recovery", subtitle: "Private, encrypted. Accountability tracking, scripture support, milestones.", tint: 0xA78BFA) { MensIntegrityJournalView() }
                                .padding(.horizontal, 20).padding(.top, 8)
                        }

                        // ── RELATIONSHIPS & IDENTITY ───────────────────────
                        MensTabSectionHeader(emoji: "🤝", title: "Relationships & Identity", subtitle: "Who you are when no one is watching.")
                            .padding(.top, 24)
                        CoverCard(emoji: "💍", title: "Marriage check-in", subtitle: "Weekly prompt across 5 areas: connection, conflict, intimacy, teamwork, fun.", tint: 0xF472B6) { MensMarriageCheckInView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "👨‍👦", title: "Fatherhood coaching", subtitle: "What your kid needs from you at their exact age and stage.", tint: 0xF59E0B) { MensFatherhoodView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🤜", title: "Brotherhood", subtitle: "Men's friendships drop after 30. Build your 2–3 close connections.", tint: 0x10B981) { MensBrotherhoodView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🧭", title: "Purpose & calling", subtitle: "Identity audit for career transitions, job loss, or a season of waiting.", tint: 0x8B5CF6) { MensPurposeView() }
                            .padding(.horizontal, 20).padding(.top, 8)

                        // ── PHYSICAL SPECIFICS ─────────────────────────────
                        MensTabSectionHeader(emoji: "💪", title: "Physical Health", subtitle: "Things apps never tell men about their own bodies.")
                            .padding(.top, 24)
                        CoverCard(emoji: "🌡️", title: "Fertility health", subtitle: "Sperm quality and the lifestyle factors you can actually control.", tint: 0x10B981) { MensFertilityView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "😴", title: "Sleep apnea risk", subtitle: "Men are 2–3x more likely. Log snoring, gasping, fatigue. Know your risk.", tint: 0x8B5CF6) { MensSleepApneaView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "🦴", title: "Back pain & posture", subtitle: "#1 reason men miss work. Daily posture check and stretch reminders.", tint: 0xF59E0B) { MensBackPainView() }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "👂", title: "Hearing protection", subtitle: "Men lose hearing earlier from noise. Reminders and check schedule.", tint: 0xF59E0B) { MensScreeningDetailView(item: "hearing") }
                            .padding(.horizontal, 20).padding(.top, 8)
                        CoverCard(emoji: "❤️", title: "ED as a heart warning", subtitle: "Often the first sign of cardiovascular disease — 3–5 years before an event.", tint: 0xF43F5E) { MensEDHeartView() }
                            .padding(.horizontal, 20).padding(.top, 8)

                        // ── FAITH-SPECIFIC ─────────────────────────────────
                        if account.runningPlans.contains(.faith) {
                            MensTabSectionHeader(emoji: "✝️", title: "Faith & Integrity", subtitle: "Built for men of faith. No other app touches this.")
                                .padding(.top, 24)
                            CoverCard(emoji: "🤝", title: "Accountability partner", subtitle: "Weekly spiritual check-in with another man. Iron sharpens iron.", tint: 0x10B981) { MensAccountabilityView() }
                                .padding(.horizontal, 20).padding(.top, 8)
                            CoverCard(emoji: "⏳", title: "Fasting tracker", subtitle: "Track fast type, purpose, and duration. Tied to your weekly rhythm.", tint: 0x8B5CF6) { MensFastingView() }
                                .padding(.horizontal, 20).padding(.top, 8)
                            CoverCard(emoji: "🔐", title: "Sexual integrity journal", subtitle: "Private and encrypted. Struggles, victories, prayer, progress.", tint: 0xA78BFA) { MensIntegrityJournalView() }
                                .padding(.horizontal, 20).padding(.top, 8)
                            CoverCard(emoji: "📖", title: "Biblical identity", subtitle: "Who am I in Christ — especially in hard seasons. Daily prompt.", tint: 0xF59E0B) { MensBiblicalIdentityView() }
                                .padding(.horizontal, 20).padding(.top, 8)
                        }

                        Spacer().frame(height: 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .onChange(of: tab) { _, _ in withAnimation { proxy.scrollTo("top", anchor: .top) } }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $paywall) { PlansView(feature: .mensHealth) }
            .onAppear { if energy == 0, let c = checkIns.today { energy = min(5, max(1, c.energy - 1)) } }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    }

    @ViewBuilder private func today(_ phase: MensPhase, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                D(phase.emoji).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 1) {
                    T(phase.label).font(.hs(18, .bold)).foregroundStyle(color)
                    T("Today's Energy Mode").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
            }
            T(phase.tip).font(.hs(14)).foregroundStyle(HS.text.opacity(0.85))
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let d = Calendar.current.date(byAdding: .day, value: i, to: startOfWeek) ?? Date()
                    let p = MensPhase.today(d), on = Calendar.current.isDateInToday(d)
                    let c = HS.readable(Self.colors[p] ?? 0x10B981)
                    VStack(spacing: 4) {
                        D(String(d.formatted(.dateTime.weekday(.narrow).locale(I18n.shared.locale)))).font(.hs(10, on ? .bold : .regular)).foregroundStyle(on ? HS.text : HS.textMuted)
                        Capsule().fill(on ? c : c.opacity(0.3)).frame(height: 6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [color.opacity(0.25), color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(color.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 20)

        VStack(alignment: .leading, spacing: 10) {
            T("⚡ Energy Today").font(.hs(12, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8)
            HStack(spacing: 8) {
                ForEach(Array([("🪫", "Low"), ("😐", "OK"), ("💪", "Good"), ("⚡", "Peak"), ("🔥", "On Fire")].enumerated()), id: \.offset) { i, e in
                    let sel = energy == i + 1
                    Button { energy = i + 1 } label: {
                        VStack(spacing: 2) { D(e.0).font(.system(size: 18)); T(e.1).font(.hs(9, .medium)).foregroundStyle(HS.textMuted) }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(sel ? color.opacity(0.2) : HS.overlay(0.03)))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(sel ? color.opacity(0.5) : HS.overlay(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(sel ? .isSelected : [])
                }
            }
            T("🎯 Today's Focus").font(.hs(12, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8).padding(.top, 10)
            ForEach(Self.focusOptions(phase), id: \.self) { item in
                let sel = focus.contains(item)
                Button { if sel { focus.remove(item) } else { focus.insert(item) } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: sel ? "checkmark.circle.fill" : "circle").foregroundStyle(sel ? color : HS.textMuted)
                        T(item).font(.hs(14)).foregroundStyle(sel ? HS.text : HS.text.opacity(0.7))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(sel ? color.opacity(0.12) : HS.overlay(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(sel ? color.opacity(0.4) : HS.overlay(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            if energy > 0 || checkIns.today != nil {
                Button { save() } label: {
                    T(checkIns.today != nil ? "✓ Checked in today · Update" : "Save Today's Check-in").font(.hs(15, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15).background(RoundedRectangle(cornerRadius: 14).fill(color))
                }
                .disabled(energy == 0).padding(.top, 12)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    @ViewBuilder private func plan(_ phase: MensPhase, _ color: Color) -> some View {
        let pools = Coach.mens[phase.rawValue]
        let seed = PhasePlan.epochDay
        let full = account.canUse(.mensHealth)
        let ideas = planTab == 0 ? PhasePlan.rotation(pools?.move ?? [], 4, seed) : PhasePlan.rotation(pools?.nourish ?? [], 3, seed)
        VStack(alignment: .leading, spacing: 10) {
            D(tr("Your \(phase.label) plan")).font(.hs(12, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(Array(["🏃 Move", "🥗 Nourish"].enumerated()), id: \.offset) { i, l in
                        Button { planTab = i } label: {
                            T(l).font(.hs(12, .semibold)).foregroundStyle(HS.text).frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 10).fill(planTab == i ? color.opacity(0.35) : HS.overlay(0.04)))
                        }.buttonStyle(.plain)
                    }
                }
                ForEach(full ? ideas : Array(ideas.prefix(1)), id: \.self) { idea in
                    HStack(alignment: .top, spacing: 8) { D("•").font(.hs(14, .bold)).foregroundStyle(color); T(idea).font(.hs(13)).foregroundStyle(HS.text) }
                }
                if full, let tip = PhasePlan.rotation(pools?.mindset ?? [], 1, seed).first {
                    D("💡 " + tr(tip)).font(.hs(12, .medium)).foregroundStyle(HS.text).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.05)))
                } else if !full {
                    Button { paywall = true } label: {
                        T("👑 See your whole plan: every move, meal and mindset idea, each day. Comes with Wellness.").font(.hs(12, .semibold)).foregroundStyle(HS.text)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.18)))
                    }.buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.3), lineWidth: 1))

            BodyEnergyEntryCard().padding(.top, 10)
            CoverCard(emoji: "💞", title: "Support her cycle", subtitle: "Your partner's phase and how to love her well this week", tint: 0xF472B6) { SupportHerCycleView() }
            CoverCard(emoji: "🤕", title: "Headache diary", subtitle: "Log headaches and see what goes with yours") { HeadacheView() }
            CoverCard(emoji: "💌", title: "Partner coaching", subtitle: "Enter her code to get her daily tip on how to support her", tint: 0xF472B6) { PartnerCoachingView().environmentObject(store) }
            NewParentsEntryCard(title: "New dad, or a baby on the way?", subtitle: "Postpartum depression in moms and dads, how to care for her, and for yourself")
            HStack(spacing: 12) {
                stat("👟", "Steps", steps.today.formatted(), color)
                stat("🙏", "Prayer streak", "\(store.prayerStreak)d", color)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
    }

    private func stat(_ emoji: String, _ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            D(emoji).font(.system(size: 20))
            D(value).font(.hs(18, .bold)).foregroundStyle(color)
            T(label).font(.hs(11)).foregroundStyle(HS.textMuted)
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(HS.overlay(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.overlay(0.07), lineWidth: 1))
    }

    private func save() {
        var c = checkIns.today ?? CheckIn(date: AppStore.dayKey(), mood: 3, energy: 3, clarity: 3, peace: 3, sleep: "")
        c.energy = min(5, energy + 1)
        checkIns.save(c)
    }

    static func focusOptions(_ p: MensPhase) -> [String] {
        switch p {
        case .peak: ["Hit my step goal — no excuses", "One hard conversation I've been avoiding", "Deep work block — 90 minutes, no distractions", "Train with intensity today"]
        case .build: ["Consistent, steady pace on all tasks", "Invest in a relationship that matters", "Build a habit — repeat yesterday's discipline", "Morning routine + evening wind-down"]
        case .rest: ["Active recovery — walk, stretch, breathe", "Listen more than I speak today", "Journal — what this week taught me", "Be fully present with family or friends"]
        case .reset: ["Full rest — no striving today", "Reflect on the week: wins and lessons", "Recharge — music, time outdoors, gratitude", "Plan next week with priorities first"]
        }
    }

    private var startOfWeek: Date {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let wd = cal.component(.weekday, from: today)   // Sunday 1 … Saturday 7; the week starts Monday
        return cal.date(byAdding: .day, value: -((wd + 5) % 7), to: today) ?? today
    }
}


/// A small challenge for new trackers: log how you feel for 14 days and your first cycle report is ready. The 30-day
/// summary to share with a doctor is free for everyone; every phase insight and the 90-day report come with the Cycle plan.
private struct FirstCycleReportCard: View {
    static let days = 14
    @EnvironmentObject var store: AppStore
    @ObservedObject private var log = CycleLog.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var paywall = false

    private var logged: Int { log.symptoms.filter { !$0.value.isEmpty }.count }

    /// Plain text, built on this phone, shared only with the app the person picks.
    private var summary: String {
        var out = ["My cycle summary (last 30 days), from HolySteps"]
        let df = DateFormatter(); df.dateStyle = .medium
        if let last = store.periodStarts.max() { out.append("Last period start: " + df.string(from: last)) }
        let lens = CycleLogic.cycleLengths(store.periodStarts)
        if !lens.isEmpty { out.append("Average cycle length: \(lens.reduce(0, +) / lens.count) days (\(lens.count) cycles)") }
        let cutoff = AppStore.dayKey(Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())
        var counts: [String: Int] = [:]
        var days = 0
        for (k, v) in log.symptoms where k >= cutoff && !v.isEmpty { days += 1; for s in v { counts[s, default: 0] += 1 } }
        out.append("Days logged: \(days)")
        let top = counts.sorted { $0.value > $1.value }.prefix(6).map { "\($0.key) (\($0.value) days)" }
        if !top.isEmpty { out.append("Most logged: " + top.joined(separator: ", ")) }
        out.append("Made with HolySteps. This is not a diagnosis.")
        return out.joined(separator: "\n")
    }

    var body: some View {
        let ready = logged >= Self.days
        let hasPlan = account.canUse(.cycleInsights)
        GlassCard(glow: Color(hex: 0xE57A9E)) {
            VStack(alignment: .leading, spacing: 8) {
                T("🌸 YOUR FIRST CYCLE REPORT").font(.hs(12, .bold)).foregroundStyle(HS.gold)
                if !ready {
                    D(tr("Log how you feel for \(Self.days) days")).font(.hs(17, .bold)).foregroundStyle(HS.text)
                    D(tr("\(logged) of \(Self.days) days logged. When you get there, you can share a summary with your doctor and see which patterns show up in your cycle."))
                        .font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                    HSProgressBar(progress: Double(logged) / Double(Self.days))
                } else {
                    T("Your first report is ready").font(.hs(17, .bold)).foregroundStyle(HS.text)
                    D(tr("You logged \(logged) days. Share a summary with your doctor, made on your phone, shared only with the app you pick.") + (hasPlan ? "" : " " + tr("The Cycle plan adds every phase insight and a 90-day report.")))
                        .font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                    ShareLink(item: summary) {
                        T("Share my cycle summary").font(.hs(16, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(HS.goldButton))
                    }
                    if !hasPlan {
                        Button { paywall = true } label: {
                            T("See every pattern with the Cycle plan").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $paywall) { PlansView(feature: .cycleInsights) }
    }
}

// MARK: - Cycle privacy detail sheet

struct CyclePrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HSSheet(title: "Your data, your phone") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    privRow(icon: "lock.fill", title: "Stored only on this device",
                            body: "Period dates, flow, symptoms and loss records never leave your phone. HolySteps doesn't upload them to any server.")
                    privRow(icon: "hand.raised.fill", title: "Never sold, never used for ads",
                            body: "Your cycle data is not monetized. It never reaches advertisers, data brokers, or analytics platforms.")
                    privRow(icon: "person.2.slash", title: "Shared only when you choose",
                            body: "Partner Coaching sends only a phase-level tip to your partner — never raw dates or symptoms. Cycle Circles share nothing automatically.")
                    privRow(icon: "heart.fill", title: "Loss records are always private",
                            body: "Pregnancy loss data is fully isolated. It is never sent to your partner, circle, or any AI feature — including the HolySteps coach.")
                    privRow(icon: "brain", title: "AI never sees health data",
                            body: "The HolySteps coach does not receive your period dates, symptoms, or loss history unless you explicitly paste them into chat.")
                    Text("HolySteps is not a medical device. Talk to your doctor about heavy bleeding, severe pain, or missed periods.")
                        .font(.hs(11))
                        .foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
        .presentationDetents([.large])
    }

    private func privRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(HS.faith)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                Text(body).font(.hs(12)).foregroundStyle(HS.textMuted)
            }
        }
    }
}
