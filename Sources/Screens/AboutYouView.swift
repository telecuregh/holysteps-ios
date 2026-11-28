import SwiftUI

/// Android's About You and Your rhythms pages in one: everything HolySteps has learned about this person's days, on
/// this phone only, with every control to change it (turn learning off, hide a routine, erase everything).
struct AboutYouView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var learning = Learning.shared
    @State private var findings: [WholeYou.Finding] = []
    @State private var analysis: Learning.Analysis?
    @State private var confirmErase = false

    var body: some View {
        let labels = Learning.labels(gender: store.gender)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard(warm: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        T("ABOUT YOU").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                        T("What HolySteps has learned").font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                        T("From what you do and log in the app: your check-ins, prayer, walks, journal, sleep and cycle. It's worked out on this iPhone and never leaves it.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        if let a = analysis {
                            D(tr("Learning for {0} days").replacingOccurrences(of: "{0}", with: "\(a.daysLearned)"))
                                .font(.hs(12, .semibold)).foregroundStyle(HS.faith)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Toggle(isOn: Binding(get: { learning.settings.on }, set: { learning.setOn($0); reload() })) {
                    T("Learn from how I use HolySteps").font(.hs(15)).foregroundStyle(HS.text)
                }
                .tint(HS.faith)

                section("WHAT YOUR DAYS SHOW")
                if findings.isEmpty {
                    T("Nothing clear yet. A pattern shows up once there are at least 5 days on each side and it holds in both your earlier and later weeks, so check in each day and it will come.")
                        .font(.hs(13)).foregroundStyle(HS.textMuted)
                }
                ForEach(findings) { f in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            D(tr(f.confidence.label).uppercased()).font(.hs(10, .semibold)).tracking(1).foregroundStyle(HS.faith)
                            D(f.emoji + " " + tr(f.title)).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            D(tr(f.detail)).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            if let tip = f.suggestion { D(tr("Try:") + " " + tr(tip)).font(.hs(13)).foregroundStyle(HS.text) }
                            D(tr(f.evidence)).font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                section("YOUR ROUTINES")
                if let a = analysis, a.routines.isEmpty {
                    T("A routine shows up once you've done something on 6 of the last 28 days at about the same time.")
                        .font(.hs(13)).foregroundStyle(HS.textMuted)
                }
                ForEach(analysis?.routines ?? [], id: \.id) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            T(labels[r.key]?.title ?? r.key).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            D(tr("Usually around {0}, {1}").replacingOccurrences(of: "{0}", with: RhythmsLogic.clock(r.minute))
                                .replacingOccurrences(of: "{1}", with: tr(r.pattern.label)) + " · " +
                              tr("{0} of the last 28 days").replacingOccurrences(of: "{0}", with: "\(r.days)"))
                                .font(.hs(12)).foregroundStyle(HS.textMuted)
                            if learning.settings.reminders.contains(r.id) { T("🔔 Reminder on").font(.hs(11)).foregroundStyle(HS.faith) }
                        }
                        Spacer()
                        Button { learning.hide(r.id); reload() } label: { T("Hide").font(.hs(13)).foregroundStyle(HS.textMuted) }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                }

                Button(role: .destructive) { confirmErase = true } label: {
                    T("Erase everything learned").font(.hs(14, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .padding(.top, 10)
                T("HolySteps notices patterns; it doesn't know why they happen and it never diagnoses. If something worries you, talk to your doctor.")
                    .font(.hs(12)).foregroundStyle(HS.textMuted)
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("About you"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .confirmationDialog(tr("Erase everything learned?"), isPresented: $confirmErase, titleVisibility: .visible) {
            Button(tr("Erase"), role: .destructive) { learning.eraseAll(); reload() }
        } message: {
            T("Your routines, reminders and usage history on this iPhone are deleted. Your check-ins, journal and other logs stay.")
        }
    }

    private func section(_ s: String) -> some View {
        T(s).font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach).padding(.top, 8).accessibilityAddTraits(.isHeader)
    }

    @MainActor private func reload() {
        analysis = learning.analyze(store: store)
        findings = learning.settings.on ? WholeYou.findings(WholeYou.rows(store: store)) : []
    }
}
