import SwiftUI
import UserNotifications

// MARK: - Section header (used in MensWellnessView body)

struct MensTabSectionHeader: View {
    let emoji: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                D(emoji).font(.system(size: 18))
                T(title).font(.hs(16, .bold)).foregroundStyle(HS.text)
            }
            T(subtitle).font(.hs(12)).foregroundStyle(HS.textMuted)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Men's notification helper (mirrors WomenReminders, discreet)

enum MensReminders {
    static func schedule(id: String, at date: Date, repeatsMonthly: Bool = false) {
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let n = UNMutableNotificationContent()
            n.title = tr("HolySteps reminder")
            n.body = tr("Tap to see your Men tab.")
            n.sound = .default
            n.threadIdentifier = "wellness"
            n.userInfo = ["route": "wellness"]
            var comps: DateComponents
            if repeatsMonthly {
                comps = Calendar.current.dateComponents([.day, .hour, .minute], from: date)
            } else {
                comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            }
            let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeatsMonthly)
            c.add(UNNotificationRequest(identifier: id, content: n, trigger: trig))
        }
    }
    static func cancel(_ ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - Generic screening detail (testicular, psa, colorectal, skin, hearing, testosterone)

struct MensScreeningDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: String

    private struct Info { let emoji, title, body, whenText, howText, reminderKey: String }

    private var info: Info {
        switch item {
        case "testicular":
            return Info(emoji: "🏴", title: "Testicular self-exam",
                        body: "Testicular cancer is the most common cancer in men aged 15–35. When caught early it has a 99% survival rate.",
                        whenText: "Once a month, ideally after a warm shower when tissue is relaxed.",
                        howText: "Roll each testicle gently between your thumb and fingers. Feel for any hard lumps, swelling, or changes in size or shape. See a doctor promptly if you find anything unusual.",
                        reminderKey: "men_remind_testicular")
        case "psa":
            return Info(emoji: "🔬", title: "PSA + Prostate screening",
                        body: "Prostate cancer is the second-leading cause of cancer death in US men. PSA blood test plus digital rectal exam.",
                        whenText: "Talk to your doctor at 40 if you are Black or have a first-degree relative with prostate cancer; at 50 otherwise.",
                        howText: "PSA is a blood test. A rising number matters as much as a single high number. Ask your doctor about your personal risk and testing interval.",
                        reminderKey: "men_remind_psa")
        case "colorectal":
            return Info(emoji: "🩻", title: "Colorectal cancer screening",
                        body: "Colorectal cancer is the third most common cancer in US men. Most begin as polyps that can be found and removed early.",
                        whenText: "Colonoscopy at 45. Sooner if family history. If your colonoscopy is normal, the next one is usually in 10 years.",
                        howText: "Alternatives include stool-based tests (FIT test, Cologuard) every 1–3 years. Talk to your doctor about which fits your situation.",
                        reminderKey: "men_remind_colorectal")
        case "skin":
            return Info(emoji: "☀️", title: "Skin mole check",
                        body: "Men are more likely than women to develop and die from melanoma, partly because they check less often.",
                        whenText: "Full-body check once a year. Use a full-length mirror and a hand mirror for hard-to-see spots.",
                        howText: "ABCDE: Asymmetry, Border irregularity, Color variation, Diameter larger than a pencil eraser, Evolving (changing). See a dermatologist for any spot that fits.",
                        reminderKey: "men_remind_skin")
        case "testosterone":
            return Info(emoji: "⚡", title: "Testosterone awareness",
                        body: "Low testosterone affects 1 in 4 men over 30. Symptoms are often mistaken for laziness or stress.",
                        whenText: "If you have symptoms, ask your doctor for a morning blood test (testosterone is highest 7–10 AM).",
                        howText: "Symptoms: persistent fatigue, low drive, mood changes, difficulty building muscle, poor sleep. Lifestyle factors that affect T: sleep quality, body fat, alcohol, chronic stress.",
                        reminderKey: "men_remind_t")
        case "hearing":
            return Info(emoji: "👂", title: "Hearing protection",
                        body: "Men are twice as likely to have hearing loss as women. Noise-induced hearing loss is permanent but preventable.",
                        whenText: "Annual hearing check if you work around loud equipment. Baseline audiogram before 50.",
                        howText: "85 dB is the threshold for damage. Use earplugs or earmuffs for lawn mowers, concerts, power tools, and shooting. The '60/60 rule' for headphones: max 60% volume for no more than 60 minutes at a time.",
                        reminderKey: "men_remind_hearing")
        default:
            return Info(emoji: "🩺", title: "Health screening",
                        body: "Regular screenings catch problems before symptoms appear.",
                        whenText: "Talk to your doctor about your personal schedule.",
                        howText: "Bring a list of questions and your medication list to every appointment.",
                        reminderKey: "men_remind_generic")
        }
    }

    @State private var reminderSet = false

    var body: some View {
        let i = info
        HSSheet(title: i.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    D(i.emoji).font(.system(size: 48)).frame(maxWidth: .infinity, alignment: .center)
                    T(i.body).font(.hs(14)).foregroundStyle(HS.text)
                    detailRow(icon: "calendar", label: "When", text: i.whenText)
                    detailRow(icon: "checkmark.circle", label: "How", text: i.howText)
                    Button {
                        var d = Date(); d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
                        MensReminders.schedule(id: i.reminderKey, at: d, repeatsMonthly: false)
                        reminderSet = true
                    } label: {
                        HStack {
                            Image(systemName: reminderSet ? "checkmark.circle.fill" : "bell.badge")
                            T(reminderSet ? "Reminder set" : "Set a reminder").font(.hs(15, .semibold))
                        }
                        .foregroundStyle(HS.onGold).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(HS.goldButton))
                    }
                    .padding(.top, 8)
                    T("HolySteps is not a medical device. Talk to your doctor about all screening decisions.")
                        .font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }

    private func detailRow(icon: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(HS.faith).frame(width: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                T(label).font(.hs(12, .semibold)).foregroundStyle(HS.textMuted)
                T(text).font(.hs(13)).foregroundStyle(HS.text)
            }
        }
    }
}

// MARK: - Vitals log (BP / Cholesterol / A1c)

private let vitalsKey = "mens_vitals_v1"
private struct VitalsEntry: Codable { var date: String; var bp: String; var cholesterol: String; var a1c: String; var nextCheck: String }

struct MensVitalsLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [VitalsEntry] = {
        guard let d = UserDefaults.standard.data(forKey: vitalsKey),
              let v = try? JSONDecoder().decode([VitalsEntry].self, from: d) else { return [] }
        return v
    }()
    @State private var bp = ""; @State private var chol = ""; @State private var a1c = ""; @State private var next = ""

    var body: some View {
        HSSheet(title: "BP · Cholesterol · A1c") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Log your last results and when to recheck. Heart disease is the #1 killer of men in the US.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    Group {
                        HSField("Blood pressure (e.g. 120/80)", text: $bp)
                        HSField("Total cholesterol (e.g. 185 mg/dL)", text: $chol)
                        HSField("A1c (e.g. 5.4%)", text: $a1c)
                        HSField("Next check due (e.g. June 2027)", text: $next)
                    }
                    Button { save() } label: {
                        T("Save").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(HS.goldButton))
                    }
                    if !entries.isEmpty {
                        T("HISTORY").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8).padding(.top, 8)
                        ForEach(entries.reversed(), id: \.date) { e in
                            VStack(alignment: .leading, spacing: 4) {
                                T(e.date).font(.hs(11)).foregroundStyle(HS.textMuted)
                                if !e.bp.isEmpty { T("BP: \(e.bp)").font(.hs(13)).foregroundStyle(HS.text) }
                                if !e.cholesterol.isEmpty { T("Cholesterol: \(e.cholesterol)").font(.hs(13)).foregroundStyle(HS.text) }
                                if !e.a1c.isEmpty { T("A1c: \(e.a1c)").font(.hs(13)).foregroundStyle(HS.text) }
                                if !e.nextCheck.isEmpty { T("Next check: \(e.nextCheck)").font(.hs(12)).foregroundStyle(HS.textMuted) }
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.04)))
                        }
                    }
                    T("Not medical advice. These are personal notes to bring to your doctor.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
    private func save() {
        let e = VitalsEntry(date: AppStore.dayKey(), bp: bp, cholesterol: chol, a1c: a1c, nextCheck: next)
        entries.append(e)
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: vitalsKey) }
        bp = ""; chol = ""; a1c = ""; next = ""
    }
}

// MARK: - Depression check (PHQ-9 phrased for men)

struct MensDepressionCheckView: View {
    @Environment(\.dismiss) private var dismiss
    private let questions = [
        "Little interest or pleasure in doing things you used to enjoy",
        "Feeling down, irritable, angry, or hopeless",
        "Trouble falling or staying asleep, or sleeping too much",
        "Feeling tired or having little energy",
        "Poor appetite, or overeating",
        "Feeling bad about yourself — like you've failed or let people down",
        "Trouble concentrating on work, TV, or reading",
        "Moving or speaking more slowly — or more restless and agitated — than usual",
        "Thoughts that you would be better off dead, or of hurting yourself"
    ]
    private let options = [("Not at all", 0), ("Several days", 1), ("More than half", 2), ("Nearly every day", 3)]
    @State private var answers: [Int] = Array(repeating: -1, count: 9)
    @State private var showResult = false

    private var score: Int { answers.filter { $0 >= 0 }.reduce(0, +) }
    private var severity: (String, String, Color) {
        switch score {
        case 0...4:  return ("Minimal", "No action needed. Keep checking in.", HS.faith)
        case 5...9:  return ("Mild", "Consider talking to someone you trust.", HS.gold)
        case 10...14: return ("Moderate", "Consider speaking with your doctor.", Color(hex: 0xF59E0B))
        case 15...19: return ("Moderately severe", "Please reach out to your doctor soon.", Color(hex: 0xF43F5E))
        default:     return ("Severe", "Please call 988 or see a doctor today.", Color(hex: 0xF43F5E))
        }
    }

    var body: some View {
        HSSheet(title: "Depression check") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    T("Over the past 2 weeks, how often have you been bothered by each of the following?").font(.hs(13)).foregroundStyle(HS.textMuted)
                    ForEach(questions.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            T(questions[i]).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            HStack(spacing: 6) {
                                ForEach(options, id: \.0) { opt in
                                    let sel = answers[i] == opt.1
                                    Button { answers[i] = opt.1; if answers.allSatisfy({ $0 >= 0 }) { showResult = true } } label: {
                                        T(opt.0).font(.hs(10, .medium)).foregroundStyle(sel ? HS.onGold : HS.text).multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(sel ? HS.goldButton : HS.overlay(0.05)))
                                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(sel ? HS.gold : HS.overlay(0.1), lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if showResult {
                        let (label, advice, color) = severity
                        VStack(alignment: .leading, spacing: 6) {
                            T("Score: \(score) — \(label)").font(.hs(16, .bold)).foregroundStyle(color)
                            T(advice).font(.hs(13)).foregroundStyle(HS.text)
                            if score >= 15 {
                                Button { } label: {
                                    T("Call or text 988 now").font(.hs(15, .bold)).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                                        .background(Capsule().fill(Color(hex: 0xF43F5E)))
                                }
                            }
                        }
                        .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.3), lineWidth: 1))
                    }
                    T("PHQ-9 is a validated screening tool, not a diagnosis. Talk to your doctor about your score.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Anger journal

private let angerKey = "mens_anger_v1"
private struct AngerEntry: Codable { var date: String; var trigger: String; var intensity: Int; var reflection: String }

struct MensAngerJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [AngerEntry] = {
        guard let d = UserDefaults.standard.data(forKey: angerKey),
              let v = try? JSONDecoder().decode([AngerEntry].self, from: d) else { return [] }
        return v
    }()
    @State private var trigger = ""; @State private var intensity = 3; @State private var reflection = ""

    var body: some View {
        HSSheet(title: "Anger journal") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Anger is often depression in disguise. Logging triggers reveals what actually needs healing.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    HSField("What triggered you?", text: $trigger)
                    VStack(alignment: .leading, spacing: 6) {
                        T("Intensity: \(intensity)/10").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                        Slider(value: Binding(get: { Double(intensity) }, set: { intensity = Int($0) }), in: 1...10, step: 1)
                            .tint(HS.faith)
                    }
                    HSField("What was underneath it? (Optional)", text: $reflection)
                    Button { save() } label: {
                        T("Save entry").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(HS.goldButton))
                    }
                    if !entries.isEmpty {
                        T("RECENT").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8).padding(.top, 8)
                        ForEach(entries.suffix(5).reversed(), id: \.date) { e in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack { T(e.date).font(.hs(11)).foregroundStyle(HS.textMuted); Spacer(); T("\(e.intensity)/10").font(.hs(12, .bold)).foregroundStyle(HS.faith) }
                                T(e.trigger).font(.hs(13)).foregroundStyle(HS.text)
                                if !e.reflection.isEmpty { T(e.reflection).font(.hs(12)).foregroundStyle(HS.textMuted) }
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.04)))
                        }
                    }
                    T("All entries stay on your device. Nothing is shared.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
    private func save() {
        let e = AngerEntry(date: AppStore.dayKey(), trigger: trigger, intensity: intensity, reflection: reflection)
        entries.append(e)
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: angerKey) }
        trigger = ""; reflection = ""; intensity = 3
    }
}

// MARK: - Grief support

struct MensGriefView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    private let stages = [
        ("1. Feel it", "Men are often told grief is weakness. It is not. The body carries what the mind refuses."),
        ("2. Name it", "Name what you lost — the person, the relationship, the future you expected, the version of yourself you were with them."),
        ("3. Act", "Men process through doing. Build something. Run. Create. Serve. The movement is not avoidance — it's how you grieve."),
        ("4. Talk", "Find one man you trust. You don't need to be eloquent. 'I'm not okay' is enough."),
        ("5. Receive", "Let others carry things for a season. Grief is not a problem to solve alone.")
    ]

    var body: some View {
        HSSheet(title: "Grief support") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    T("Men process loss differently — often through action and silence rather than tears. Both are valid.").font(.hs(14)).foregroundStyle(HS.text)
                    ForEach(stages, id: \.0) { stage in
                        VStack(alignment: .leading, spacing: 4) {
                            T(stage.0).font(.hs(14, .bold)).foregroundStyle(HS.faith)
                            T(stage.1).font(.hs(13)).foregroundStyle(HS.text)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.overlay(0.04)))
                    }
                    if store.faithMode {
                        VStack(alignment: .leading, spacing: 8) {
                            T("Scripture for grief").font(.hs(14, .bold)).foregroundStyle(HS.faith)
                            ForEach(["\"The Lord is close to the brokenhearted.\" — Psalm 34:18",
                                     "\"He heals the brokenhearted and binds up their wounds.\" — Psalm 147:3",
                                     "\"Jesus wept.\" — John 11:35"], id: \.self) {
                                T($0).italic().font(.hs(13)).foregroundStyle(HS.text)
                            }
                        }
                        .padding(14).background(RoundedRectangle(cornerRadius: 14).fill(HS.faith.opacity(0.08)))
                    }
                    T("If grief feels unmanageable, please reach out to a counselor or call 988.")
                        .font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Sexual integrity journal (private, encrypted with device passcode)

private let integrityKey = "mens_integrity_v1"
private struct IntegrityEntry: Codable { var date: String; var streak: Int; var note: String; var prayer: String }

struct MensIntegrityJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [IntegrityEntry] = {
        guard let d = UserDefaults.standard.data(forKey: integrityKey),
              let v = try? JSONDecoder().decode([IntegrityEntry].self, from: d) else { return [] }
        return v
    }()
    @State private var note = ""; @State private var prayer = ""
    private var streak: Int { entries.last?.streak ?? 0 }

    var body: some View {
        HSSheet(title: "Sexual integrity") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            T("Current streak").font(.hs(12)).foregroundStyle(HS.textMuted)
                            T("\(streak) days").font(.hs(28, .bold)).foregroundStyle(HS.faith)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            T("Best").font(.hs(12)).foregroundStyle(HS.textMuted)
                            T("\(entries.map(\.streak).max() ?? 0) days").font(.hs(16, .bold)).foregroundStyle(HS.gold)
                        }
                    }
                    .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(HS.faith.opacity(0.08)))
                    HSField("Today's note (private)", text: $note)
                    HSField("Prayer / scripture (optional)", text: $prayer)
                    HStack(spacing: 10) {
                        Button { logDay(victory: true) } label: {
                            T("✓ Victory today").font(.hs(14, .semibold)).foregroundStyle(HS.onGold)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Capsule().fill(HS.goldButton))
                        }
                        Button { logDay(victory: false) } label: {
                            T("Reset streak").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Capsule().fill(HS.overlay(0.08)))
                        }
                    }
                    T("All entries are private. This journal never leaves your device and is never shared with AI, partners, or circles.")
                        .font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
    private func logDay(victory: Bool) {
        let newStreak = victory ? streak + 1 : 0
        let e = IntegrityEntry(date: AppStore.dayKey(), streak: newStreak, note: note, prayer: prayer)
        entries.append(e)
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: integrityKey) }
        note = ""; prayer = ""
    }
}

// MARK: - Marriage check-in

private let marriageKey = "mens_marriage_v1"
private struct MarriageCheckIn: Codable { var date: String; var areas: [String: Int]; var note: String }

struct MensMarriageCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    private let areas = ["Connection", "Conflict", "Intimacy", "Teamwork", "Fun"]
    @State private var ratings: [String: Int] = [:]
    @State private var note = ""
    @State private var history: [MarriageCheckIn] = {
        guard let d = UserDefaults.standard.data(forKey: marriageKey),
              let v = try? JSONDecoder().decode([MarriageCheckIn].self, from: d) else { return [] }
        return v
    }()

    var body: some View {
        HSSheet(title: "Marriage check-in") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Rate your marriage this week in each area (1 = needs work, 5 = thriving).").font(.hs(13)).foregroundStyle(HS.textMuted)
                    ForEach(areas, id: \.self) { area in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { T(area).font(.hs(14, .semibold)).foregroundStyle(HS.text); Spacer(); T("\(ratings[area] ?? 0)/5").font(.hs(13, .bold)).foregroundStyle(HS.faith) }
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { n in
                                    Button { ratings[area] = n } label: {
                                        Circle().fill(n <= (ratings[area] ?? 0) ? HS.faith : HS.overlay(0.08)).frame(width: 36, height: 36)
                                            .overlay(T("\(n)").font(.hs(14, .semibold)).foregroundStyle(n <= (ratings[area] ?? 0) ? HS.onGold : HS.textMuted))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    HSField("One thing I'll do for us this week (optional)", text: $note)
                    Button { save() } label: {
                        T("Save check-in").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(HS.goldButton))
                    }
                    if !history.isEmpty {
                        T("LAST CHECK-IN").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8).padding(.top, 8)
                        if let last = history.last {
                            VStack(alignment: .leading, spacing: 4) {
                                T(last.date).font(.hs(11)).foregroundStyle(HS.textMuted)
                                ForEach(areas, id: \.self) { a in
                                    HStack { T(a).font(.hs(13)).foregroundStyle(HS.text); Spacer(); T("\(last.areas[a] ?? 0)/5").font(.hs(13, .bold)).foregroundStyle(HS.faith) }
                                }
                                if !last.note.isEmpty { T(last.note).font(.hs(12)).foregroundStyle(HS.textMuted) }
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.04)))
                        }
                    }
                }
                .padding(20)
            }
        }
    }
    private func save() {
        let c = MarriageCheckIn(date: AppStore.dayKey(), areas: ratings, note: note)
        history.append(c)
        if let d = try? JSONEncoder().encode(history) { UserDefaults.standard.set(d, forKey: marriageKey) }
        ratings = [:]; note = ""
    }
}

// MARK: - Fatherhood coaching

struct MensFatherhoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore

    private let stages: [(String, String, [String])] = [
        ("👶", "0–12 months", ["Hold your baby skin-to-skin. It literally lowers their cortisol.", "Talk to them constantly — narrate your day. Brain wiring depends on it.", "Take one overnight shift per week so your partner can sleep.", "Learn one soothing technique: the 5 S's (swaddle, side, shush, swing, suck)."]),
        ("🧸", "1–3 years", ["Get on the floor. Toddlers learn through play with their fathers specifically.", "Read to them every day. 15 minutes builds more vocabulary than any app.", "Be consistent with 'no'. Toddlers test limits to feel safe.", "Manage your anger. They are watching every reaction you have."]),
        ("🎒", "4–8 years", ["Be at things — games, concerts, school events. Presence outweighs presents.", "Teach them to lose gracefully by modeling it yourself.", "Have one-on-one time weekly. Even 20 minutes alone is powerful.", "Tell them what you believe. They need your worldview, not just rules."]),
        ("📱", "9–12 years", ["Know their friends by name. The peer group shapes them more than you know.", "Talk while doing something else — car rides, cooking, walks. Eye contact feels interrogatory at this age.", "Start honest conversations about bodies, attraction, and what it means to be a man.", "Let them fail in safe ways. Rescue less."]),
        ("🎓", "13–18 years", ["Shift from authority to advisor. Fight for the relationship over the rule.", "Be curious, not interrogating. Ask about their music, friends, opinions.", "Talk about sex, pornography, and relationships directly — once a year minimum.", "Tell them you are proud of who they are, not just what they do."])
    ]

    var body: some View {
        HSSheet(title: "Fatherhood coaching") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    T("Research-backed guidance for each stage of your child's development. What they actually need from their father right now.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    ForEach(stages, id: \.0) { stage in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) { D(stage.0).font(.system(size: 24)); T(stage.1).font(.hs(16, .bold)).foregroundStyle(HS.text) }
                            ForEach(stage.2, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    D("•").font(.hs(14, .bold)).foregroundStyle(HS.faith)
                                    T(tip).font(.hs(13)).foregroundStyle(HS.text)
                                }
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(HS.overlay(0.04)))
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Brotherhood (accountability partner matching)

struct MensBrotherhoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    private let tips = [
        ("🤜", "Start with one man", "You don't need a group. One honest friendship with another man is enough to change your life."),
        ("📅", "Make it regular", "Coffee, a walk, a call — same time, every week. Irregular meetings die."),
        ("❓", "Ask real questions", "Not 'how are you' but 'what's the hardest thing in your life right now?' Men rise to the question asked."),
        ("🔒", "Keep confidences", "Nothing shared in that friendship leaves. Trust is the whole product."),
        ("✝️", "Pray together", "If faith is part of it, start and end with prayer. It levels pride fast.")
    ]

    var body: some View {
        HSSheet(title: "Brotherhood") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    T("Men's close friendships decline sharply after 30. By 45, many men have no close male friend at all. This costs lives.").font(.hs(14)).foregroundStyle(HS.text)
                    ForEach(tips, id: \.0) { tip in
                        HStack(alignment: .top, spacing: 12) {
                            D(tip.0).font(.system(size: 24)).frame(width: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                T(tip.1).font(.hs(14, .bold)).foregroundStyle(HS.text)
                                T(tip.2).font(.hs(13)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
                    if store.faithMode {
                        T("\"As iron sharpens iron, so one person sharpens another.\" — Proverbs 27:17")
                            .italic().font(.hs(14)).foregroundStyle(HS.faith)
                            .padding(14).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 14).fill(HS.faith.opacity(0.08)))
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Purpose & calling audit

struct MensPurposeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    private let questions = [
        "What would I do if money were not a factor?",
        "What do people consistently come to me for?",
        "What breaks my heart about the world?",
        "What am I doing when I feel most alive?",
        "What do I want written on my grave?"
    ]
    @State private var answers: [String] = Array(repeating: "", count: 5)

    var body: some View {
        HSSheet(title: "Purpose & calling") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    T("Identity crises hit hardest at career transitions, job loss, and retirement. These five questions are your anchor.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    ForEach(questions.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            T(questions[i]).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            TextEditor(text: $answers[i])
                                .font(.hs(13))
                                .foregroundStyle(HS.text)
                                .frame(minHeight: 60)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.05)))
                        }
                    }
                    if store.faithMode {
                        T("\"For we are God's handiwork, created in Christ Jesus to do good works, which God prepared in advance for us to do.\" — Ephesians 2:10")
                            .italic().font(.hs(13)).foregroundStyle(HS.faith)
                            .padding(14).background(RoundedRectangle(cornerRadius: 14).fill(HS.faith.opacity(0.08)))
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Fertility health

struct MensFertilityView: View {
    @Environment(\.dismiss) private var dismiss
    private let factors: [(String, String, String)] = [
        ("🌡️", "Heat", "Sperm production drops with sustained heat. Avoid hot tubs, saunas, and laptops on your lap for extended periods."),
        ("🍺", "Alcohol", "More than 14 drinks/week is associated with lower sperm count and motility."),
        ("😤", "Chronic stress", "Elevated cortisol suppresses testosterone and sperm quality. Stress management is fertility care."),
        ("🚬", "Smoking", "Smoking reduces sperm count, motility, and increases DNA damage in sperm."),
        ("🏋️", "Steroid use", "Anabolic steroids shut down natural testosterone and sperm production — often for years."),
        ("💊", "Supplements", "Zinc, vitamin D, CoQ10, and folate have evidence for supporting sperm quality. Talk to your doctor.")
    ]

    var body: some View {
        HSSheet(title: "Fertility health") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    T("Male factor is involved in roughly 50% of infertility cases. Most apps only talk to women about this.").font(.hs(14)).foregroundStyle(HS.text)
                    ForEach(factors, id: \.1) { f in
                        HStack(alignment: .top, spacing: 12) {
                            D(f.0).font(.system(size: 24)).frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                T(f.1).font(.hs(14, .bold)).foregroundStyle(HS.text)
                                T(f.2).font(.hs(13)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
                    T("Not medical advice. If you have been trying to conceive for 12 months without success (6 months if your partner is over 35), ask your doctor for a semen analysis.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Sleep apnea risk

private let sleepApneaKey = "mens_sleep_apnea_v1"
private struct SleepLog: Codable { var date: String; var snoring: Bool; var gasping: Bool; var fatigue: Int }

struct MensSleepApneaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var snoring = false; @State private var gasping = false; @State private var fatigue = 3
    @State private var logs: [SleepLog] = {
        guard let d = UserDefaults.standard.data(forKey: sleepApneaKey),
              let v = try? JSONDecoder().decode([SleepLog].self, from: d) else { return [] }
        return v
    }()

    private var riskScore: Int {
        let s = snoring ? 1 : 0; let g = gasping ? 2 : 0; let f = fatigue >= 4 ? 1 : 0
        return s + g + f
    }
    private var riskLabel: (String, Color) {
        switch riskScore { case 0: return ("Low", HS.faith); case 1: return ("Moderate", HS.gold); default: return ("High — talk to your doctor", Color(hex: 0xF43F5E)) }
    }

    var body: some View {
        HSSheet(title: "Sleep apnea risk") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Men are 2–3x more likely than women to have sleep apnea. Untreated, it raises heart disease and diabetes risk.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    Toggle("My partner says I snore", isOn: $snoring).tint(HS.faith)
                    Toggle("I wake gasping or my partner reports I stop breathing", isOn: $gasping).tint(HS.faith)
                    VStack(alignment: .leading, spacing: 6) {
                        T("Daytime fatigue: \(fatigue)/5").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                        Slider(value: Binding(get: { Double(fatigue) }, set: { fatigue = Int($0) }), in: 1...5, step: 1).tint(HS.faith)
                    }
                    let (label, color) = riskLabel
                    HStack { T("Risk level:").font(.hs(14, .semibold)).foregroundStyle(HS.text); T(label).font(.hs(14, .bold)).foregroundStyle(color) }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.1)))
                    Button { saveLog() } label: {
                        T("Log tonight").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(HS.goldButton))
                    }
                    T("Not a diagnosis. If you have high risk or symptoms, ask your doctor about a sleep study.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
    private func saveLog() {
        let l = SleepLog(date: AppStore.dayKey(), snoring: snoring, gasping: gasping, fatigue: fatigue)
        logs.append(l)
        if let d = try? JSONEncoder().encode(logs) { UserDefaults.standard.set(d, forKey: sleepApneaKey) }
    }
}

// MARK: - Back pain & posture

private let backKey = "mens_back_v1"
private struct BackEntry: Codable { var date: String; var pain: Int; var trigger: String }

struct MensBackPainView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pain = 0
    @State private var trigger = ""
    @State private var history: [BackEntry] = {
        guard let d = UserDefaults.standard.data(forKey: backKey),
              let v = try? JSONDecoder().decode([BackEntry].self, from: d) else { return [] }
        return v
    }()
    private let stretches = ["Cat-cow (10 reps)", "Child's pose (30 s)", "Hip flexor lunge (30 s each side)", "Glute bridge (15 reps)", "Doorway chest stretch (30 s)"]

    var body: some View {
        HSSheet(title: "Back pain & posture") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Back pain is the #1 reason men miss work. Daily 5-minute stretching prevents most of it.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    VStack(alignment: .leading, spacing: 6) {
                        T("Pain today: \(pain)/10").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                        Slider(value: Binding(get: { Double(pain) }, set: { pain = Int($0) }), in: 0...10, step: 1).tint(HS.faith)
                    }
                    HSField("Likely trigger (lifting, sitting, sleeping position...)", text: $trigger)
                    Button { saveEntry() } label: {
                        T("Log").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(HS.goldButton))
                    }
                    T("TODAY'S STRETCHES").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8).padding(.top, 8)
                    ForEach(stretches, id: \.self) { s in
                        HStack(spacing: 8) { D("•").font(.hs(14, .bold)).foregroundStyle(HS.faith); T(s).font(.hs(13)).foregroundStyle(HS.text) }
                    }
                    T("See a doctor if: pain radiates down your leg, numbness or tingling, bowel/bladder changes, or pain after a fall.").font(.hs(11)).foregroundStyle(HS.textSubtle).padding(.top, 4)
                }
                .padding(20)
            }
        }
    }
    private func saveEntry() {
        let e = BackEntry(date: AppStore.dayKey(), pain: pain, trigger: trigger)
        history.append(e)
        if let d = try? JSONEncoder().encode(history) { UserDefaults.standard.set(d, forKey: backKey) }
        pain = 0; trigger = ""
    }
}

// MARK: - ED as heart warning

struct MensEDHeartView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HSSheet(title: "ED as a heart warning") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("❤️").font(.system(size: 48)).frame(maxWidth: .infinity, alignment: .center)
                    T("Erectile dysfunction (ED) is often the first visible sign of cardiovascular disease — typically appearing 3–5 years before a heart attack or stroke.").font(.hs(14)).foregroundStyle(HS.text)
                    T("Why?").font(.hs(16, .bold)).foregroundStyle(HS.faith)
                    T("The penile arteries are smaller than coronary arteries. Atherosclerosis (plaque buildup) shows up there first. ED is essentially a warning light on the cardiovascular dashboard.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    T("What to do").font(.hs(16, .bold)).foregroundStyle(HS.faith)
                    ForEach([
                        "Tell your doctor. Don't just ask for a pill — ask for a cardiac workup.",
                        "Check blood pressure, cholesterol, blood sugar, and BMI.",
                        "Exercise is the most evidence-based treatment for mild ED. 30 minutes of cardio, 5 days a week.",
                        "Quit smoking. Vascular damage from smoking is the single largest reversible cause of ED.",
                        "Sleep matters. Testosterone is made during deep sleep. Poor sleep = low T = ED."
                    ], id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            D("•").font(.hs(14, .bold)).foregroundStyle(HS.faith)
                            T(tip).font(.hs(13)).foregroundStyle(HS.text)
                        }
                    }
                    T("Not a diagnosis. ED has many causes. Talk to your doctor — without embarrassment. This is a medical conversation.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Accountability partner

struct MensAccountabilityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    private let questions = ["How is my walk with God this week?", "Have I been honest in my relationships?", "Is there any sin I need to confess?", "Am I caring for my body and my mind?", "What do I need prayer for?"]

    var body: some View {
        HSSheet(title: "Accountability partner") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    T("Iron sharpens iron. Weekly questions to ask your accountability partner — or to bring to any trusted man.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    VStack(alignment: .leading, spacing: 10) {
                        T("WEEKLY QUESTIONS").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8)
                        ForEach(questions.indices, id: \.self) { i in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1).").font(.hs(14, .bold)).foregroundStyle(HS.faith)
                                T(questions[i]).font(.hs(14)).foregroundStyle(HS.text)
                            }
                        }
                    }
                    .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(HS.faith.opacity(0.08)))
                    T("\"As iron sharpens iron, so one person sharpens another.\" — Proverbs 27:17").italic().font(.hs(13)).foregroundStyle(HS.faith)
                    ShareLink(item: questions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"),
                              subject: Text("Accountability questions")) {
                        T("Share questions with your partner").font(.hs(15, .semibold)).foregroundStyle(HS.onGold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(HS.goldButton))
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Fasting tracker

private let fastingKey = "mens_fasting_v1"
private struct FastEntry: Codable { var date: String; var type: String; var hours: Int; var intention: String; var completed: Bool }

struct MensFastingView: View {
    @Environment(\.dismiss) private var dismiss
    private let types = ["Intermittent (16:8)", "24-hour", "Water only", "Daniel fast", "Full fast"]
    @State private var selectedType = "Intermittent (16:8)"; @State private var hours = 16; @State private var intention = ""
    @State private var history: [FastEntry] = {
        guard let d = UserDefaults.standard.data(forKey: fastingKey),
              let v = try? JSONDecoder().decode([FastEntry].self, from: d) else { return [] }
        return v
    }()

    var body: some View {
        HSSheet(title: "Fasting tracker") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Log your fast type, duration, and intention. Tied to your weekly rhythm.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    VStack(alignment: .leading, spacing: 6) {
                        T("Fast type").font(.hs(13, .semibold)).foregroundStyle(HS.textMuted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(types, id: \.self) { t in
                                    Button { selectedType = t } label: {
                                        T(t).font(.hs(12, .semibold)).foregroundStyle(selectedType == t ? HS.onGold : HS.text)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(Capsule().fill(selectedType == t ? HS.goldButton : HS.overlay(0.07)))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        T("Duration: \(hours) hours").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                        Slider(value: Binding(get: { Double(hours) }, set: { hours = Int($0) }), in: 12...72, step: 1).tint(HS.faith)
                    }
                    HSField("Purpose / intention (optional)", text: $intention)
                    HStack(spacing: 10) {
                        Button { save(completed: true) } label: {
                            T("✓ Complete").font(.hs(14, .semibold)).foregroundStyle(HS.onGold)
                                .frame(maxWidth: .infinity).padding(.vertical, 12).background(Capsule().fill(HS.goldButton))
                        }
                        Button { save(completed: false) } label: {
                            T("Log start").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 12).background(Capsule().fill(HS.overlay(0.08)))
                        }
                    }
                    if !history.isEmpty {
                        T("HISTORY").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8).padding(.top, 8)
                        ForEach(history.suffix(5).reversed(), id: \.date) { e in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    T(e.type).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                    T("\(e.hours)h · \(e.date)").font(.hs(11)).foregroundStyle(HS.textMuted)
                                }
                                Spacer()
                                T(e.completed ? "✓" : "·").font(.hs(16, .bold)).foregroundStyle(e.completed ? HS.faith : HS.textMuted)
                            }
                            .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.04)))
                        }
                    }
                }
                .padding(20)
            }
        }
    }
    private func save(completed: Bool) {
        let e = FastEntry(date: AppStore.dayKey(), type: selectedType, hours: hours, intention: intention, completed: completed)
        history.append(e)
        if let d = try? JSONEncoder().encode(history) { UserDefaults.standard.set(d, forKey: fastingKey) }
        intention = ""
    }
}

// MARK: - Biblical identity

struct MensBiblicalIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    private let prompts: [(String, String, String)] = [
        ("Career loss", "\"For I know the plans I have for you,\" declares the LORD, \"plans to prosper you and not to harm you.\" — Jer 29:11", "God's plan doesn't depend on your job title. What He has called you to cannot be lost in a layoff."),
        ("Failure", "\"Though he falls, he will not be hurled headlong, for the LORD is the one who holds his hand.\" — Ps 37:24", "Your worst failure is not the last word about you. You are not defined by what went wrong."),
        ("Shame", "\"There is therefore now no condemnation for those who are in Christ Jesus.\" — Rom 8:1", "Shame says 'I am what I did.' The Gospel says 'You are what Christ did.' Both cannot be true."),
        ("Waiting", "\"Those who wait on the LORD shall renew their strength.\" — Is 40:31", "Waiting is not wasted. The season before breakthrough is always a season of formation."),
        ("Strength", "\"Be strong and courageous. Do not be afraid; do not be discouraged, for the LORD your God will be with you wherever you go.\" — Josh 1:9", "God does not call the equipped. He equips the called. Your inadequacy is the perfect context for His power.")
    ]
    @State private var index = 0

    var body: some View {
        HSSheet(title: "Biblical identity") {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let p = prompts[index]
                        T(p.0.uppercased()).font(.hs(11, .semibold)).foregroundStyle(HS.textMuted).tracking(0.8)
                        T(p.1).italic().font(.hs(14)).foregroundStyle(HS.faith)
                        T(p.2).font(.hs(16)).foregroundStyle(HS.text).lineSpacing(4)
                    }
                    .padding(24)
                }
                HStack(spacing: 12) {
                    Button { index = (index - 1 + prompts.count) % prompts.count } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(HS.faith)
                            .frame(width: 48, height: 48).background(Circle().fill(HS.overlay(0.07)))
                    }
                    T("\(index + 1) / \(prompts.count)").font(.hs(13)).foregroundStyle(HS.textMuted).frame(maxWidth: .infinity, alignment: .center)
                    Button { index = (index + 1) % prompts.count } label: {
                        Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold)).foregroundStyle(HS.faith)
                            .frame(width: 48, height: 48).background(Circle().fill(HS.overlay(0.07)))
                    }
                }
                .padding(20).background(HS.overlay(0.03))
            }
        }
    }
}

// MARK: - HSField helper (reusable text field matching app style)

private struct HSField: View {
    let placeholder: String
    @Binding var text: String
    init(_ placeholder: String, text: Binding<String>) { self.placeholder = placeholder; _text = text }
    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.hs(14)).foregroundStyle(HS.text)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.overlay(0.1), lineWidth: 1))
    }
}
