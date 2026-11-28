import SwiftUI
import UIKit
import UserNotifications

/// Android's HealthHelper (HealthHelper.kt, HealthHelperScreens.kt): things learned from the person's own days, kept on
/// this phone. It never diagnoses anything.
///  - Take it easy: a few rough days in a row (short or poor sleep, low energy, far fewer steps) → suggest an easy day.
///  - What helps you: what goes with their better days, from their own check-ins.
///  - Headache patterns: what tends to come before their logged headaches.
///  - Low-mood watch: low check-ins for a week or more → a gentle card, and real help if it keeps going. Never a
///    notification, never sent anywhere.
///  - Medicine and vitamin reminders with a Taken button, and a summary for the doctor.
enum HealthHelper {
    static var moodWatch: Bool {
        get { UserDefaults.standard.object(forKey: "hhMoodWatch") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hhMoodWatch") }
    }
    static var takeEasy: Bool {
        get { UserDefaults.standard.object(forKey: "hhTakeEasy") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hhTakeEasy") }
    }

    struct Easy { let reasons: [String]; let days: Int }

    /// A day is rough when: under 6 hours asleep (or the check-in says "poor"), energy 1–2, or under half their usual
    /// steps. Two or more rough days in the last three (including today or yesterday) → take it easy.
    static func takeItEasy(today: String, steps: [String: Int], checkIns: [CheckIn], sleep: [String: Int]) -> Easy? {
        let past = (8...28).compactMap { steps[Trends.shift(today, -$0)] }.filter { $0 > 0 }.sorted()
        let usual = past.count >= 7 ? past[past.count / 2] : nil
        let byDate = Dictionary(checkIns.map { ($0.date, $0) }, uniquingKeysWith: { $1 })
        var reasons: [String] = [], rough = 0, recent = false
        for back in 0...2 {
            let d = Trends.shift(today, -back)
            var r: [String] = []
            let c = byDate[d]
            if let s = sleep[d], (1..<360).contains(s) { r.append("Short or poor sleep") } else if c?.sleep == "poor" { r.append("Short or poor sleep") }
            if let c, (1...2).contains(c.energy) { r.append("Low energy") }
            if back > 0, let u = usual, u >= 2000, let s = steps[d], s < u / 2 { r.append("Far fewer steps than usual") }
            if !r.isEmpty { rough += 1; r.forEach { if !reasons.contains($0) { reasons.append($0) } }; if back <= 1 { recent = true } }
        }
        return rough >= 2 && recent ? Easy(reasons: reasons, days: rough) : nil
    }

    enum MoodLevel { case none, gentle, help }

    /// GENTLE: 4+ low check-ins (mood 1–2) in the last 7 days. HELP: 8+ in the last 14, or a 1 on 3+ days of the last 7.
    static func moodLevel(_ checkIns: [CheckIn], today: String) -> MoodLevel {
        let last7 = Set((0...6).map { Trends.shift(today, -$0) }), last14 = Set((0...13).map { Trends.shift(today, -$0) })
        let low7 = checkIns.filter { last7.contains($0.date) && (1...2).contains($0.mood) }.count
        let low14 = checkIns.filter { last14.contains($0.date) && (1...2).contains($0.mood) }.count
        let veryLow7 = checkIns.filter { last7.contains($0.date) && $0.mood == 1 }.count
        if low14 >= 8 || veryLow7 >= 3 { return .help }
        return low7 >= 4 ? .gentle : .none
    }

    /// The "Taken" button on a medicine reminder (the name never shows on the lock screen).
    static let medCategory = "MED"
    static let takenAction = "MED_TAKEN"
    static func registerCategory(into set: inout Set<UNNotificationCategory>) {
        set.insert(UNNotificationCategory(identifier: medCategory, actions: [UNNotificationAction(identifier: takenAction, title: tr("Taken"), options: [])], intentIdentifiers: []))
    }

    /// A one- or two-page PDF for the doctor: steps, sleep, check-ins, headaches and medicines (plus the cycle for women),
    /// over the last [days] days. Made on this phone; the person chooses who gets it.
    @MainActor static func summaryPDF(store: AppStore, days: Int, steps: [String: Int], sleep: [String: Int]) -> URL? {
        let today = AppStore.dayKey(), from = Trends.shift(today, -days)
        var sections: [(String, [String])] = []
        let s = steps.filter { $0.key > from && $0.value > 0 }.map(\.value)
        var activity: [String] = []
        if !s.isEmpty { activity.append(tr("Steps: about {0} a day on {1} days with steps").replacingOccurrences(of: "{0}", with: (s.reduce(0, +) / s.count).formatted()).replacingOccurrences(of: "{1}", with: "\(s.count)")) }
        let sl = sleep.filter { $0.key > from }.map(\.value)
        if !sl.isEmpty { activity.append(tr("Sleep: {0} a night on average ({1} nights from Apple Health)").replacingOccurrences(of: "{0}", with: MorningLight.hm(sl.reduce(0, +) / sl.count)).replacingOccurrences(of: "{1}", with: "\(sl.count)")) }
        if !activity.isEmpty { sections.append(("Activity and sleep", activity)) }
        let ci = CheckInStore.shared.all.filter { $0.date > from }
        if !ci.isEmpty {
            sections.append(("Daily check-ins", [tr("{0} check-ins. Averages out of 5: mood {1}, energy {2}, clarity {3}, peace {4}")
                .replacingOccurrences(of: "{0}", with: "\(ci.count)")
                .replacingOccurrences(of: "{1}", with: Trends.fmt1(Double(ci.map(\.mood).reduce(0, +)) / Double(ci.count)))
                .replacingOccurrences(of: "{2}", with: Trends.fmt1(Double(ci.map(\.energy).reduce(0, +)) / Double(ci.count)))
                .replacingOccurrences(of: "{3}", with: Trends.fmt1(Double(ci.map(\.clarity).reduce(0, +)) / Double(ci.count)))
                .replacingOccurrences(of: "{4}", with: Trends.fmt1(Double(ci.map(\.peace).reduce(0, +)) / Double(ci.count)))]))
        }
        let h = Headache.entries.filter { $0.date > from }
        if !h.isEmpty {
            let mig = h.filter(\.migraine).count
            sections.append(("Headaches", [tr("{0} headache days ({1} migraine), average pain {2} out of 10")
                .replacingOccurrences(of: "{0}", with: "\(h.count)").replacingOccurrences(of: "{1}", with: "\(mig)")
                .replacingOccurrences(of: "{2}", with: Trends.fmt1(Double(h.map(\.pain).reduce(0, +)) / Double(h.count)))]))
        }
        let meds = Medicines.shared.meds
        if !meds.isEmpty { sections.append(("Medicines and vitamins", meds.map { "\($0.name): " + $0.minutes.map(timeText).joined(separator: ", ") })) }
        if store.gender == "female" { sections += DoctorSummary.summaryLines(store) }

        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 54
            func draw(_ text: String, size: CGFloat, bold: Bool = false, gap: CGFloat = 6) {
                let attr: [NSAttributedString.Key: Any] = [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size), .foregroundColor: UIColor.black]
                let rect = (text as NSString).boundingRect(with: CGSize(width: 504, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attr, context: nil)
                if y + rect.height > 740 { ctx.beginPage(); y = 54 }
                (text as NSString).draw(with: CGRect(x: 54, y: y, width: 504, height: rect.height), options: .usesLineFragmentOrigin, attributes: attr, context: nil)
                y += rect.height + gap
            }
            draw(tr("Health summary for my doctor"), size: 20, bold: true, gap: 4)
            draw(tr("The last {0} days, made {1} by the HolySteps app from what I logged. It is not a diagnosis.")
                .replacingOccurrences(of: "{0}", with: "\(days)").replacingOccurrences(of: "{1}", with: Date().formatted(date: .long, time: .omitted)), size: 10, gap: 14)
            if sections.isEmpty { draw(tr("Nothing logged in these days yet."), size: 11) }
            for (title, lines) in sections {
                draw(tr(title), size: 14, bold: true, gap: 4)
                for l in lines { draw("• " + l, size: 11, gap: 3) }
                y += 8
            }
            draw(tr("Notes:"), size: 12, bold: true, gap: 60)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("holysteps-health-summary-\(days)d-\(today).pdf")
        do { try data.write(to: url, options: [.atomic, .completeFileProtection]); return url } catch { return nil }
    }
}

struct HealthHelperView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var checkIns = CheckInStore.shared
    @ObservedObject private var meds = Medicines.shared
    @Environment(\.openURL) private var openURL
    @State private var steps: [String: Int] = [:]
    @State private var sleep: [String: Int] = [:]
    @State private var patterns: [TrendInsight] = []
    @State private var moodWatch = HealthHelper.moodWatch
    @State private var takeEasy = HealthHelper.takeEasy
    @State private var pdf: URL?
    @State private var checkIn = false
    @State private var confirmClear = false

    private let teal = Color(hex: 0x2DD4BF)

    var body: some View {
        let today = AppStore.dayKey()
        let easy = takeEasy ? HealthHelper.takeItEasy(today: today, steps: steps, checkIns: checkIns.all, sleep: sleep) : nil
        let mood = moodWatch ? HealthHelper.moodLevel(checkIns.all, today: today) : .none
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    T("🩺 Health helper").font(.hs(26, .heavy)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    T("Learned from your own days, kept on this phone. It never diagnoses anything: for anything that worries you, see your doctor.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                }
                NavigationLink { AboutYouView() } label: {
                    card {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                T("🧩 Whole you").font(.hs(15, .bold)).foregroundStyle(HS.text)
                                T("What your sleep, steps, prayer, mood, cycle and more say about you, together").font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            Text("›").font(.hs(20)).foregroundStyle(HS.textMuted)
                        }
                    }
                }
                .buttonStyle(.plain)

                if mood == .help {
                    card(tint: Color(hex: 0xF59E0B)) {
                        T("💛 You've had a heavy couple of weeks").font(.hs(16, .bold)).foregroundStyle(HS.text)
                        T("Many of your check-ins have been low. That's worth talking about with someone: a friend, your pastor, or your doctor or a counselor. Depression is common and it gets better with help.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        T("If you ever feel you might hurt yourself, call or text 988 (Suicide & Crisis Lifeline, US) any time, or your local emergency number.")
                            .font(.hs(12)).foregroundStyle(HS.textSecondary)
                        HStack(spacing: 10) {
                            Button { if let u = URL(string: "tel:988") { openURL(u) } } label: { T("Call 988").font(.hs(14, .semibold)) }.buttonStyle(.borderedProminent).tint(Color(hex: 0xF59E0B))
                            Button { if let u = URL(string: "sms:988") { openURL(u) } } label: { T("Text 988").font(.hs(14, .semibold)) }.buttonStyle(.bordered)
                        }
                    }
                } else if mood == .gentle {
                    card(tint: Color(hex: 0xF59E0B)) {
                        T("🌤️ A few low days this week").font(.hs(16, .bold)).foregroundStyle(HS.text)
                        T("Be gentle with yourself. A short walk, some daylight, a call with a friend, and a little time with God can help.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                }

                card(tint: easy != nil ? Color(hex: 0xF59E0B) : nil) {
                    if let easy {
                        T("🛋️ Take it easy today").font(.hs(16, .bold)).foregroundStyle(HS.text)
                        T("Your last few days look rough:").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        ForEach(easy.reasons, id: \.self) { D("•  " + tr($0)).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                        T("An easy walk, water and an early night will help more than pushing hard. If you feel unwell, rest, and see a doctor if it doesn't pass.")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    } else {
                        T("✅ Your body looks steady").font(.hs(16, .bold)).foregroundStyle(HS.text)
                        T("The helper watches your sleep, energy and steps, and tells you when a few rough days in a row mean it's time to ease off.")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                }

                card {
                    T("🔎 What helps you").font(.hs(16, .bold)).foregroundStyle(HS.text)
                    if patterns.isEmpty {
                        T("Do the 10-second check-in on most days. After two or three weeks, the helper shows what goes with your better days.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    } else {
                        ForEach(patterns.prefix(3)) { p in D(p.text).font(.hs(13)).foregroundStyle(HS.text) }
                        T("From your own days. A pattern isn't proof, but it's a good thing to try more of.").font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                    Button { checkIn = true } label: { T("Check in now").font(.hs(14, .semibold)).foregroundStyle(teal) }.frame(minHeight: 44)
                }

                let links = Headache.links(sleepByDay: sleep, steps: steps) { _ in nil }
                let n = Headache.entries.count
                card {
                    T("🧠 Headache patterns").font(.hs(16, .bold)).foregroundStyle(HS.text)
                    if !links.isEmpty {
                        T("What has often come before your headaches:").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        ForEach(links, id: \.label) { l in
                            D("•  " + tr(l.label) + ": " + tr("{0}% of those days had a headache, vs {1}% of other days")
                                .replacingOccurrences(of: "{0}", with: "\(l.withRate)").replacingOccurrences(of: "{1}", with: "\(l.withoutRate)"))
                                .font(.hs(13)).foregroundStyle(HS.textSecondary)
                        }
                        T("Worth mentioning to your doctor. The summary below includes it.").font(.hs(11)).foregroundStyle(HS.textMuted)
                    } else if n < 4 {
                        T("Log each headache. After 4 or more, the helper looks at what tends to come before them: sleep, steps, low days and your cycle.")
                            .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    } else {
                        D(tr("No clear pattern yet in your {0} headaches. Keep logging; patterns often show after a few more.").replacingOccurrences(of: "{0}", with: "\(n)"))
                            .font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                    NavigationLink { HeadacheView() } label: { T("Log a headache").font(.hs(14, .semibold)).foregroundStyle(teal) }.frame(minHeight: 44)
                }

                card {
                    T("💊 Medicine and vitamin reminders").font(.hs(16, .bold)).foregroundStyle(HS.text)
                    T("Names stay on this phone and off the lock screen. Tap Taken in the reminder or here.").font(.hs(12)).foregroundStyle(HS.textMuted)
                    ForEach(meds.meds) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                D(m.name).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                D(m.minutes.map(timeText).joined(separator: " · ")).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            if meds.takenCount(m.id) >= max(1, m.minutes.count) {
                                T("✓ Taken").font(.hs(13, .bold)).foregroundStyle(Color(hex: 0x10B981))
                            } else {
                                Button { meds.markTaken(m.id) } label: { T("Taken").font(.hs(13, .semibold)) }.buttonStyle(.bordered)
                            }
                        }
                    }
                    NavigationLink { BodyBasicsView(part: .medicines) } label: {
                        T(meds.meds.isEmpty ? "+ Add a medicine or vitamin" : "Add or change medicines").font(.hs(14, .semibold)).foregroundStyle(teal)
                    }
                    .frame(minHeight: 44)
                }

                card {
                    T("🔔 Helpful reminders").font(.hs(16, .bold)).foregroundStyle(HS.text)
                    Toggle(isOn: $takeEasy) {
                        VStack(alignment: .leading, spacing: 2) {
                            T("Take it easy").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            T("Tell me when a few rough days in a row mean it's time to ease off").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    .tint(HS.goldButton)
                    .onChange(of: takeEasy) { HealthHelper.takeEasy = takeEasy }
                    Toggle(isOn: $moodWatch) {
                        VStack(alignment: .leading, spacing: 2) {
                            T("Low-mood watch").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            T("A gentle card here after a run of low check-ins. Never a notification, never sent anywhere").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    .tint(HS.goldButton)
                    .onChange(of: moodWatch) { HealthHelper.moodWatch = moodWatch }
                    NavigationLink { MyRemindersView() } label: { T("Water, move and bedtime reminders ›").font(.hs(14, .semibold)).foregroundStyle(teal) }
                        .frame(minHeight: 44)
                }

                card {
                    T("📄 Summary for your doctor").font(.hs(16, .bold)).foregroundStyle(HS.text)
                    T("A one- or two-page PDF of your steps, sleep, check-ins, headaches, medicines and cycle, with room for notes. Made on this phone; you choose who gets it.")
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                    HStack(spacing: 10) {
                        Button { pdf = HealthHelper.summaryPDF(store: store, days: 30, steps: steps, sleep: sleep) } label: { T("Last 30 days").font(.hs(14, .semibold)) }
                            .buttonStyle(.borderedProminent).tint(teal)
                        Button { pdf = HealthHelper.summaryPDF(store: store, days: 90, steps: steps, sleep: sleep) } label: { T("Last 90 days").font(.hs(14, .semibold)) }
                            .buttonStyle(.bordered)
                    }
                    if let pdf {
                        ShareLink(item: pdf) { T("Share the summary (PDF)").font(.hs(14, .semibold)).foregroundStyle(HS.gold) }.frame(minHeight: 44)
                    }
                }

                Button { confirmClear = true } label: { T("Clear the health helper").font(.hs(13)).foregroundStyle(HS.textMuted) }
                    .frame(minHeight: 44)
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Health helper"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $checkIn) { CheckInSheet() }
        .alert(tr("Clear the health helper?"), isPresented: $confirmClear) {
            Button(tr("Clear"), role: .destructive) {
                meds.meds.forEach { meds.delete($0.id) }
                HealthHelper.moodWatch = true; HealthHelper.takeEasy = true; moodWatch = true; takeEasy = true
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("Your medicines, their reminders and the helper's settings are removed from this phone. Your check-ins and other logs stay.") }
        .task {
            steps = await StepsModel.shared.stepsPerDay(days: 90)
            sleep = await StepsModel.shared.sleepNights(days: 90)
            patterns = Trends.patterns(store: store, steps: steps)
        }
    }

    private func card<C: View>(tint: Color? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(tint.map { $0.opacity(0.14) } ?? HS.cardFill))
    }
}
