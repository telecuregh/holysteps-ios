import SwiftUI

/// The fourth tab: Android's CycleScreen for women (Today, Plan, Insights, More), and a men's wellness rhythm for men.
struct CycleView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        if store.gender == "male" { MensWellnessView() } else { WomensCycleView() }
    }
}

private func prettyDate(_ d: Date) -> String { d.formatted(.dateTime.month(.abbreviated).day().locale(I18n.shared.locale)) }

struct WomensCycleView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var log = CycleLog.shared
    @State private var tab = 0
    @State private var planTab = 0
    @State private var showLog = false
    @State private var confirmDelete = false

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
            .sheet(isPresented: $showLog) { LogPeriodSheet { store.logPeriodStart($0) } }
        }
    }

    // MARK: Today

    @ViewBuilder private func today(_ r: Rhythm) -> some View {
        Spacer().frame(height: 12)
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

        if r.phase == .menstrual {
            SectionHeader(title: "Flow today").padding(.top, 8)
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    T("Day \(r.cycleDay ?? 1) of about \(store.periodLength)").font(.hs(11)).foregroundStyle(HS.textMuted)
                    HStack(spacing: 8) {
                        ForEach(CycleLog.flows, id: \.self) { f in
                            let on = log.flow[AppStore.dayKey()] == f
                            Button { log.setFlow(f) } label: {
                                T(f).font(.hs(12, on ? .semibold : .regular)).foregroundStyle(on ? HS.text : HS.textSecondary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(on ? HS.goldButton.opacity(0.22) : HS.cardFill))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Color(hex: 0xD9B49F) : Color(hex: 0xD9B49F).opacity(0.22), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
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
        if let last = store.periodStarts.max(), let day = r.cycleDay {
            let pred = CycleLogic.predict(lastStart: last, length: store.cycleLength, periodLength: store.periodLength)
            SectionHeader(title: "Predictions").padding(.top, 8)
            HStack(spacing: 12) {
                predCard("Next period", prettyDate(pred.nextPeriod), 0xF43F5E)
                predCard("Ovulation", prettyDate(pred.ovulation), 0xF59E0B)
            }
            .padding(.horizontal, 20)
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    T("Fertile window").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                    D("\(prettyDate(pred.fertileStart)) – \(prettyDate(pred.fertileEnd))").font(.hs(13)).foregroundStyle(HS.textMuted)
                    T("Predictions are estimates, not birth control.").font(.hs(11)).foregroundStyle(HS.textSubtle)
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

    private var more: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                T("🔒 Where your cycle data lives").font(.hs(15, .bold)).foregroundStyle(HS.text)
                privacyLine("On this phone only", "Your period dates, flow and symptoms are kept on this phone. HolySteps doesn't upload them.")
                privacyLine("Shared only if you choose", "Nothing about your cycle is shared with anyone.")
                Button(role: .destructive) { confirmDelete = true } label: { T("Delete my cycle data").font(.hs(13)).foregroundStyle(Color(hex: 0xFCA5A5)) }
                T("HolySteps is not a medical device. Talk to a doctor about heavy bleeding, severe pain, or missed periods.")
                    .font(.hs(11)).foregroundStyle(HS.textSubtle)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16)
        .alert(tr("Delete your cycle data?"), isPresented: $confirmDelete) {
            Button(tr("Delete"), role: .destructive) { store.periodStarts = []; store.cycleLength = 28; log.erase() }
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

/// Men's wellness: the week's rhythm (Android MensPhase: push Monday and Tuesday, build midweek, rest Friday, reset
/// at the weekend) with today's focus.
struct MensWellnessView: View {
    var body: some View {
        let today = MensPhase.today()
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenPhoto(name: "screen_wellness_men")
                        VStack(alignment: .leading, spacing: 0) {
                            T("Men's Wellness").font(.hs(28)).foregroundStyle(HS.text)
                            ItalicAccent(text: "strength, energy & rhythm", size: 19)
                        }
                        .padding(.top, 40).padding(.horizontal, 20).padding(.bottom, 12)
                        GlassCard(glow: Color(hex: 0x56B892), warm: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                T("TODAY").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                                T("\(today.emoji) \(today.label)").font(.hs(22, .bold)).foregroundStyle(HS.text)
                                T(today.tip).font(.hs(14)).foregroundStyle(HS.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        SectionHeader(title: "Your week").padding(.top, 8)
                        GlassCard {
                            VStack(spacing: 10) {
                                ForEach(0..<7, id: \.self) { i in
                                    let d = Calendar.current.date(byAdding: .day, value: i, to: startOfWeek) ?? Date()
                                    let p = MensPhase.today(d)
                                    let isToday = Calendar.current.isDateInToday(d)
                                    HStack {
                                        D(d.formatted(.dateTime.weekday(.wide).locale(I18n.shared.locale))).font(.hs(14, isToday ? .semibold : .regular))
                                            .foregroundStyle(isToday ? HS.text : HS.textMuted)
                                        Spacer()
                                        T("\(p.emoji) \(p.label)").font(.hs(13)).foregroundStyle(isToday ? HS.peach : HS.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        Spacer().frame(height: 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var startOfWeek: Date {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let wd = cal.component(.weekday, from: today)   // Sunday 1 … Saturday 7; the week starts Monday
        return cal.date(byAdding: .day, value: -((wd + 5) % 7), to: today) ?? today
    }
}
