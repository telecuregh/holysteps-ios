import SwiftUI
import UIKit

// Checkups, vaccines, monthly self-checks, warning signs and the private mood check-in, for men and for women.
// Ported from Android (data/MenCare.kt, ui/screens/MenCareScreens.kt) with the same rules and sources:
// USPSTF statements (no new ones since mid-2025), ACS prostate guideline (Nov 2026), CDC adult immunization schedule
// (back to the 2025 schedule while ACIP votes after June 11, 2025 are stayed, AAP v. Kennedy, Mar 2026).
// Information, not a diagnosis. Kept on this phone.

enum CheckupRules {
    static let version = "Nov 2026"

    struct Profile { let age: Int; let smoked, heavySmoker, higherProstateRisk, boneRisk: Bool }
    struct Rule: Identifiable {
        let id, emoji, title, what: String
        /// Years between checks; 0 = once in life.
        let every: (Profile) -> Int
        let applies: (Profile) -> Bool
        let source: String
        var vaccine = false
        var note: String? = nil
    }

    static let men: [Rule] = [
        Rule(id: "bp", emoji: "❤️", title: "Blood pressure", what: "A quick cuff reading at a clinic, pharmacy or at home.", every: { $0.age >= 40 ? 1 : 3 }, applies: { $0.age >= 18 }, source: "USPSTF 2021 (A)"),
        Rule(id: "chol", emoji: "🩸", title: "Cholesterol & heart risk", what: "A lipid blood test and a talk about whether a statin fits your 10-year risk.", every: { _ in 5 }, applies: { (40...75).contains($0.age) }, source: "USPSTF 2022 (B)"),
        Rule(id: "sugar", emoji: "🍬", title: "Blood sugar (diabetes)", what: "An A1C or fasting glucose test.", every: { _ in 3 }, applies: { (35...70).contains($0.age) }, source: "USPSTF 2021 (B, if overweight) · ADA: everyone 35+"),
        Rule(id: "colon", emoji: "🔎", title: "Colon cancer screening", what: "Colonoscopy every 10 years, or a yearly FIT stool test, or a stool DNA test every 1–3 years. Ask which fits you.", every: { _ in 10 }, applies: { (45...75).contains($0.age) }, source: "USPSTF 2021 (A at 50–75, B at 45–49)", note: "Did a FIT instead? Mark it done each year — this reminder still counts colonoscopy's 10 years."),
        Rule(id: "psa", emoji: "🧔", title: "Prostate (PSA) — talk with your doctor", what: "A PSA blood test is your choice after talking over the benefits and harms.", every: { $0.higherProstateRisk ? 1 : 2 }, applies: { $0.higherProstateRisk ? (45...69).contains($0.age) : (50...69).contains($0.age) }, source: "ACS Nov 2026: every 2 yrs at 50–69, yearly from 45 if higher risk · USPSTF 2018: individual choice at 55–69", note: "At 70–74 it's an individual decision; after 75 most men don't need it."),
        Rule(id: "lung", emoji: "🫁", title: "Lung cancer CT", what: "A yearly low-dose CT scan.", every: { _ in 1 }, applies: { $0.heavySmoker && (50...80).contains($0.age) }, source: "USPSTF 2021 (B): 20+ pack-years, smoke now or quit within 15 years"),
        Rule(id: "aaa", emoji: "🫀", title: "Aorta ultrasound (AAA)", what: "One painless belly ultrasound.", every: { _ in 0 }, applies: { $0.smoked && (65...75).contains($0.age) }, source: "USPSTF 2019 (B): men 65–75 who ever smoked"),
        Rule(id: "hepc", emoji: "🧪", title: "Hepatitis C test", what: "A one-time blood test.", every: { _ in 0 }, applies: { (18...79).contains($0.age) }, source: "USPSTF 2020 (B)"),
        Rule(id: "hiv", emoji: "🧪", title: "HIV test", what: "A one-time blood test (more often if at risk).", every: { _ in 0 }, applies: { (15...65).contains($0.age) }, source: "USPSTF 2019 (A)"),
    ] + vaccines

    static let vaccines: [Rule] = [
        Rule(id: "flu", emoji: "💉", title: "Flu shot", what: "Every fall.", every: { _ in 1 }, applies: { $0.age >= 18 }, source: "CDC adult schedule", vaccine: true, note: "At 65+, ask for a high-dose, recombinant or adjuvanted flu shot."),
        Rule(id: "covid", emoji: "💉", title: "COVID-19 shot", what: "Federal guidance is changing — ask your doctor or pharmacist what's right for you this year.", every: { _ in 1 }, applies: { $0.age >= 18 }, source: "Guidance in flux (FDA label vs AAFP 2026–27)", vaccine: true),
        Rule(id: "tdap", emoji: "💉", title: "Tetanus booster (Td/Tdap)", what: "Every 10 years, and Tdap once as an adult.", every: { _ in 10 }, applies: { $0.age >= 19 }, source: "CDC adult schedule", vaccine: true),
        Rule(id: "shingles", emoji: "💉", title: "Shingles (Shingrix)", what: "Two doses, 2–6 months apart.", every: { _ in 0 }, applies: { $0.age >= 50 }, source: "CDC adult schedule", vaccine: true),
        Rule(id: "pneumo", emoji: "💉", title: "Pneumonia (pneumococcal)", what: "One dose of PCV20 or PCV21 (or PCV15 then PPSV23).", every: { _ in 0 }, applies: { $0.age >= 50 }, source: "CDC adult schedule", vaccine: true),
        Rule(id: "hpv", emoji: "💉", title: "HPV", what: "Routine through 26; at 27–45 talk it over with your doctor.", every: { _ in 0 }, applies: { (19...45).contains($0.age) }, source: "CDC adult schedule", vaccine: true),
        Rule(id: "hepb", emoji: "💉", title: "Hepatitis B", what: "A 2- or 3-dose series if you never had it.", every: { _ in 0 }, applies: { (19...59).contains($0.age) }, source: "CDC adult schedule", vaccine: true),
        Rule(id: "rsv", emoji: "💉", title: "RSV", what: "One dose at 75+, or 50–74 if you have heart or lung disease, diabetes or another risk.", every: { _ in 0 }, applies: { $0.age >= 75 }, source: "CDC adult schedule", vaccine: true, note: "50–74 with a chronic condition? Ask about it too."),
    ]

    static var women: [Rule] {
        let shared = men.filter { ["bp", "chol", "sugar", "colon", "lung", "hepc", "hiv"].contains($0.id) }
        let own: [Rule] = [
            Rule(id: "w_breast", emoji: "🎗️", title: "Mammogram", what: "A breast X-ray (2D or 3D) every 2 years.", every: { _ in 2 }, applies: { (40...74).contains($0.age) }, source: "USPSTF 2024 (B): every 2 years, ages 40–74", note: "A mother or sister with breast cancer, or told you have dense breasts? Ask your doctor what else fits you."),
            Rule(id: "w_cervix", emoji: "🌸", title: "Cervical cancer screening", what: "Ages 21–29: a Pap test every 3 years. Ages 30–65: an HPV test every 5 years (you can collect it yourself where offered), or a Pap every 3 years.", every: { $0.age < 30 ? 3 : 5 }, applies: { (21...65).contains($0.age) }, source: "USPSTF: Pap 21–29, HPV test 30–65 (clinician- or self-collected)", note: "Had a hysterectomy that removed the cervix (not for cancer)? You likely don't need this. Ask your doctor."),
            Rule(id: "w_bone", emoji: "🦴", title: "Bone density (DXA scan)", what: "A quick, painless scan that checks for osteoporosis.", every: { _ in 0 }, applies: { $0.age >= 65 || ($0.boneRisk && $0.age >= 45) }, source: "USPSTF Jan 2025 (B): women 65+, and younger after menopause if at risk", note: "Your doctor will tell you when to repeat it."),
            Rule(id: "w_sti", emoji: "🧪", title: "Chlamydia & gonorrhea test", what: "A urine test or swab once a year if you're sexually active.", every: { _ in 1 }, applies: { (15...24).contains($0.age) }, source: "USPSTF 2021 (B): sexually active women 24 and younger", note: "25 or older with a new or more than one partner? It's worth it too."),
        ]
        let vax = vaccines.map { r -> Rule in
            var x = r
            switch r.id {
            case "tdap": x.note = "Pregnant? Get a Tdap shot in every pregnancy, at 27–36 weeks."
            case "rsv": x.note = "Pregnant between September and January? An RSV shot at 32–36 weeks protects your baby."
            default: break
            }
            return x
        }
        return shared + own + vax
    }

    enum Status { case due, soon, ok }
    static func nextDue(_ r: Rule, _ p: Profile, done: Date?) -> Date? {
        guard let done else { return Date() }
        let y = r.every(p)
        return y == 0 ? nil : CycleLogic.plus(done, y * 365)
    }
    static func status(_ next: Date?) -> Status {
        guard let next else { return .ok }
        if next <= Date() { return .due }
        if next <= Date().addingTimeInterval(60 * 86400) { return .soon }
        return .ok
    }
}

final class CheckupStore: ObservableObject {
    static let shared = CheckupStore()
    private let d = UserDefaults.standard
    @Published var birthYear: Int { didSet { d.set(birthYear, forKey: "checkupBirthYear") } }
    @Published var flags: Set<String> { didSet { d.set(Array(flags), forKey: "checkupFlags") } }
    @Published private(set) var done: [String: Double] { didSet { d.set(done, forKey: "checkupDone") } }
    @Published private(set) var selfChecks: [String: Double] { didSet { d.set(selfChecks, forKey: "checkupSelf") } }
    /// [epoch seconds, PHQ score] (the PHQ-2 score when the short screen was negative), last 52.
    @Published private(set) var moods: [[Double]] { didSet { d.set(moods, forKey: "checkupMoods") } }

    private init() {
        birthYear = d.integer(forKey: "checkupBirthYear")
        flags = Set(d.stringArray(forKey: "checkupFlags") ?? [])
        done = d.dictionary(forKey: "checkupDone") as? [String: Double] ?? [:]
        selfChecks = d.dictionary(forKey: "checkupSelf") as? [String: Double] ?? [:]
        moods = d.array(forKey: "checkupMoods") as? [[Double]] ?? []
    }

    var profile: CheckupRules.Profile? {
        guard birthYear > 1900 else { return nil }
        return .init(age: Calendar.current.component(.year, from: Date()) - birthYear, smoked: flags.contains("smoked"),
                     heavySmoker: flags.contains("heavy"), higherProstateRisk: flags.contains("prostate"), boneRisk: flags.contains("bone"))
    }
    func toggle(_ f: String) { if flags.contains(f) { flags.remove(f) } else { flags.insert(f) } }
    func doneDate(_ id: String) -> Date? { done[id].map { Date(timeIntervalSince1970: $0) } }
    func markDone(_ id: String) { done[id] = Date().timeIntervalSince1970 }
    func clear(_ id: String) { done[id] = nil }
    func selfCheckThisMonth(_ id: String) -> Bool {
        guard let t = selfChecks[id] else { return false }
        return Calendar.current.isDate(Date(timeIntervalSince1970: t), equalTo: Date(), toGranularity: .month)
    }
    func markSelfCheck(_ id: String) { selfChecks[id] = Date().timeIntervalSince1970 }
    func saveMood(_ s: Int) { moods = Array((moods + [[Date().timeIntervalSince1970, Double(s)]]).suffix(52)) }
}

private func dial(_ s: String) { if let u = URL(string: s) { UIApplication.shared.open(u) } }

struct CrisisBox: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T("You don't have to carry this alone").font(.hs(15, .bold)).foregroundStyle(Color(hex: 0xF87171))
                T("If you're thinking about hurting yourself, reach out right now. The 988 Suicide & Crisis Lifeline is free, private and open 24/7 — call or text. In danger right now? Call 911.")
                    .font(.hs(12)).foregroundStyle(HS.textSecondary)
                HStack(spacing: 14) {
                    Button { dial("tel:988") } label: { T("📞 Call 988").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                    Button { dial("sms:988") } label: { T("💬 Text 988").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                    Button { dial("tel:911") } label: { T("📞 911").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                }
                T("Veterans: call 988 and press 1, or text 838255.").font(.hs(11)).foregroundStyle(HS.textMuted)
            }
        }
    }
}

private struct Expand: View {
    let emoji, title: String
    let lines: [String]
    @State private var open = false
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Button { withAnimation { open.toggle() } } label: {
                    HStack { D(emoji); T(title).font(.hs(14, .semibold)).foregroundStyle(HS.text); Spacer(); Image(systemName: open ? "chevron.up" : "chevron.down").foregroundStyle(HS.textMuted) }
                }.buttonStyle(.plain)
                if open { ForEach(lines, id: \.self) { T($0).font(.hs(12)).foregroundStyle(HS.textSecondary) } }
            }
        }
    }
}

struct CheckupsView: View {
    let women: Bool
    @ObservedObject private var s = CheckupStore.shared
    @State private var year = ""

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        T(women ? "🌸 WOMEN'S HEALTH" : "🛡️ MEN'S HEALTH").font(.hs(12, .bold)).foregroundStyle(HS.readable(women ? 0xF472B6 : 0x8B5CF6))
                        T("Checkups & self-checks").font(.hs(24)).foregroundStyle(HS.text)
                        T("What's due for your age, private on your phone. Information, not a diagnosis — your doctor knows your full picture.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                T("Year you were born").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                TextField("1985", text: $year).keyboardType(.numberPad).textFieldStyle(.roundedBorder).frame(width: 80)
                                Button { if let y = Int(year), (1900...Calendar.current.component(.year, from: Date())).contains(y) { s.birthYear = y } } label: { T("Save").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }
                            }
                            let opts: [(String, String)] = women
                                ? [("smoked", "I've ever smoked"), ("heavy", "20+ pack-years, smoking now or quit within 15 years"), ("bone", "Past menopause with a risk for weak bones")]
                                : [("smoked", "I've ever smoked"), ("heavy", "20+ pack-years, smoking now or quit within 15 years"), ("prostate", "Black, or a father or brother had prostate cancer")]
                            ForEach(opts, id: \.0) { k, l in
                                Toggle(isOn: Binding(get: { s.flags.contains(k) }, set: { _ in s.toggle(k) })) { T(l).font(.hs(12)).foregroundStyle(HS.textSecondary) }.tint(HS.gold)
                            }
                        }
                    }
                    if let p = s.profile {
                        let rules = (women ? CheckupRules.women : CheckupRules.men).filter { $0.applies(p) }
                        ForEach([false, true], id: \.self) { vax in
                            SectionHeader(title: vax ? "Vaccines" : "Checkups")
                            ForEach(rules.filter { $0.vaccine == vax }) { r in ruleRow(r, p) }
                        }
                    } else {
                        T("Add the year you were born to see what's due.").font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                    SectionHeader(title: "Monthly self-checks")
                    let checks: [(String, String, String)] = women
                        ? [("breast", "🎗️ Know your breasts", "Get to know how your breasts normally look and feel, so you notice a change. See a doctor for a new lump, skin dimpling or puckering, nipple changes or discharge, redness, or swelling in the breast or armpit."),
                           ("skin", "🔆 Skin check", "Head to toe, with a mirror for your back. ABCDE: Asymmetry, uneven Border, more than one Color, Diameter bigger than a pencil eraser, Evolving (changing). See a doctor for a spot that changes, bleeds or won't heal.")]
                        : [("testes", "🥚 Testicular check", "After a warm shower, roll each testicle gently between thumb and fingers. Most common at ages 15–35. See a doctor for a lump (often painless), swelling, heaviness or a dull ache. Caught early, it's almost always curable."),
                           ("skin", "🔆 Skin check", "Head to toe, with a mirror or your wife's help for your back. ABCDE: Asymmetry, uneven Border, more than one Color, Diameter bigger than a pencil eraser, Evolving (changing). Men are more likely than women to die of melanoma — get any changing spot looked at.")]
                    ForEach(checks, id: \.0) { id, title, body in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    T(title).font(.hs(14, .semibold)).foregroundStyle(HS.text); Spacer()
                                    if s.selfCheckThisMonth(id) { T("✓ This month").font(.hs(11)).foregroundStyle(Color(hex: 0x34D399)) }
                                    else { Button { s.markSelfCheck(id) } label: { T("Done").font(.hs(12, .semibold)).foregroundStyle(HS.gold) } }
                                }
                                T(body).font(.hs(12)).foregroundStyle(HS.textSecondary)
                            }
                        }
                    }
                    SectionHeader(title: "Know the warning signs")
                    if women {
                        Expand(emoji: "❤️", title: "Heart attack signs in women", lines: [
                            "Chest pain or pressure is still the most common sign, but women more often also have shortness of breath, nausea or vomiting, a cold sweat, lightheadedness, or pain in the back, jaw, neck or arm.",
                            "Some feel unusual tiredness for days before. Don't wait it out: call 911.", "Source: American Heart Association"])
                        Expand(emoji: "🧠", title: "When stress is more than stress", lines: [
                            "Feeling down, empty or on edge most days for two weeks or more, losing interest in things you enjoy, or sleep and appetite changes can be depression. After a baby, and around menopause, it's more common.",
                            "It's treatable. Take the private check-in, and talk to your doctor — or someone you trust.", "Thinking about ending your life? Call or text 988 now."])
                    } else {
                        Expand(emoji: "😴", title: "Snoring & sleep apnea", lines: [
                            "Talk to your doctor if you have loud snoring with pauses, choking or gasping in sleep; feel sleepy during the day or doze off driving; wake with headaches; get up often at night to urinate; or have high blood pressure.",
                            "Sleep apnea is common in men and treatable. A phone or tracker can't diagnose it — a sleep test can.", "Source: American Academy of Sleep Medicine"])
                        Expand(emoji: "❤️", title: "Erection trouble can be a heart signal", lines: [
                            "Erection problems often show up 3–5 years before heart disease, because the same small blood vessels are affected.",
                            "It's common and nothing to be ashamed of. Mention it at your next checkup and ask for a heart-risk check (blood pressure, cholesterol, blood sugar).",
                            "Skip online pill sellers — a doctor can treat both the cause and the symptom safely.", "Sources: peer-reviewed reviews; ACC 2024"])
                        Expand(emoji: "🔋", title: "Low testosterone", lines: [
                            "Possible signs: low sex drive, fewer morning erections, low energy, low mood, losing muscle, gaining belly fat.",
                            "Only a doctor can diagnose it — it takes symptoms plus repeated early-morning blood tests. Sleep, weight, alcohol and some medicines can lower it, and fixing those often helps.",
                            "Be careful with \"T-booster\" supplements: they aren't FDA-approved to treat low testosterone."])
                        Expand(emoji: "🧠", title: "When stress is more than stress", lines: [
                            "In men, depression often looks like anger, irritability, working nonstop, risk-taking, drinking more, or aches with no clear cause.",
                            "It's treatable. Take the private check-in, and talk to your doctor — or someone you trust.",
                            "Thinking about ending your life? Call or text 988 now. Veterans: dial 988 then press 1."])
                    }
                    CoverCard(emoji: "🧠", title: "Take the 1-minute mood check-in", subtitle: "Private, with 988 one tap away", tint: 0xA78BFA) { MoodCheckView() }
                    D(tr("Guidance as of \(CheckupRules.version).")).font(.hs(10)).foregroundStyle(HS.textSubtle)
                }.padding(20)
            }
        }
        .onAppear { if s.birthYear > 0 { year = String(s.birthYear) } }
    }

    private func ruleRow(_ r: CheckupRules.Rule, _ p: CheckupRules.Profile) -> some View {
        let next = CheckupRules.nextDue(r, p, done: s.doneDate(r.id))
        let st = CheckupRules.status(next)
        return GlassCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    D("\(r.emoji) \(tr(r.title))").font(.hs(14, .semibold)).foregroundStyle(HS.text); Spacer()
                    T(st == .due ? "Due" : st == .soon ? "Soon" : "Up to date").font(.hs(11, .bold))
                        .foregroundStyle(st == .due ? Color(hex: 0xF59E0B) : st == .soon ? HS.peach : Color(hex: 0x34D399))
                }
                T(r.what).font(.hs(12)).foregroundStyle(HS.textSecondary)
                if let n = r.note { T(n).font(.hs(11)).foregroundStyle(HS.textMuted) }
                HStack {
                    if let dd = s.doneDate(r.id) {
                        D(tr("Done \(dd.formatted(date: .numeric, time: .omitted))") + (next.map { " · " + tr("next \($0.formatted(date: .numeric, time: .omitted))") } ?? "")).font(.hs(11)).foregroundStyle(HS.textMuted)
                        Spacer()
                        Button { s.clear(r.id) } label: { T("Undo").font(.hs(11)).foregroundStyle(HS.gold) }
                    } else {
                        Spacer()
                        Button { s.markDone(r.id) } label: { T("Mark done today").font(.hs(12, .semibold)).foregroundStyle(HS.gold) }
                    }
                }
                D(r.source).font(.hs(10)).foregroundStyle(HS.textSubtle)
            }
        }
    }
}

/// PHQ-2, then PHQ-9 if it's positive. Any answer above "Not at all" on item 9 shows the crisis box at once.
struct MoodCheckView: View {
    static let items = [
        "Little interest or pleasure in doing things",
        "Feeling down, depressed, or hopeless",
        "Trouble falling or staying asleep, or sleeping too much",
        "Feeling tired or having little energy",
        "Poor appetite or overeating",
        "Feeling bad about yourself — or that you are a failure or have let yourself or your family down",
        "Trouble concentrating on things, such as reading or watching TV",
        "Moving or speaking so slowly that other people could have noticed — or being so fidgety or restless that you've been moving more than usual",
        "Thoughts that you would be better off dead, or of hurting yourself in some way",
    ]
    static let answers = ["Not at all", "Several days", "More than half the days", "Nearly every day"]
    static func band(_ s: Int) -> String { s <= 4 ? "Minimal" : s <= 9 ? "Mild" : s <= 14 ? "Moderate" : s <= 19 ? "Moderately severe" : "Severe" }

    @ObservedObject private var store = CheckupStore.shared
    @State private var a: [Int?] = Array(repeating: nil, count: 9)
    @State private var full = false
    @State private var saved: Int?

    var body: some View {
        let shown = full ? 9 : 2
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("🧠 MIND").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xA78BFA))
                    T("Mood check-in").font(.hs(24)).foregroundStyle(HS.text)
                    T("Over the last 2 weeks, how often have you been bothered by the following? Private — it stays on your phone.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if let last = store.moods.last, last.count == 2 {
                        D(tr("Last check-in \(Date(timeIntervalSince1970: last[0]).formatted(date: .abbreviated, time: .omitted)): \(tr(Self.band(Int(last[1])))) (\(Int(last[1])))")).font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                    ForEach(0..<shown, id: \.self) { i in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                D("\(i + 1). " + tr(Self.items[i])).font(.hs(13, .semibold)).foregroundStyle(HS.text)
                                ForEach(0..<4, id: \.self) { v in
                                    Button { a[i] = v; saved = nil } label: {
                                        HStack { Image(systemName: a[i] == v ? "largecircle.fill.circle" : "circle"); T(Self.answers[v]).font(.hs(12)) }
                                            .foregroundStyle(a[i] == v ? HS.text : HS.textMuted)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        if i == 8 && (a[8] ?? 0) > 0 { CrisisBox() }
                    }
                    let answered = (0..<shown).allSatisfy { a[$0] != nil }
                    if answered && saved == nil {
                        let v = a.map { $0 ?? 0 }
                        if !full && v[0] + v[1] >= 3 {
                            T("Thanks for being honest. A few more questions will give a clearer picture.").font(.hs(12)).foregroundStyle(HS.textSecondary)
                            GoldButton(title: tr("Continue (7 more)")) { full = true }
                        } else {
                            GoldButton(title: tr("See my result")) { let sc = full ? v.reduce(0, +) : v[0] + v[1]; store.saveMood(sc); saved = sc }
                        }
                    }
                    if let sc = saved {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                if !full {
                                    T("✓ Doing okay").font(.hs(15, .bold)).foregroundStyle(Color(hex: 0x34D399))
                                    T("Nothing here points to depression right now. Check in again next month — or any time things feel heavy.").font(.hs(12)).foregroundStyle(HS.textSecondary)
                                } else {
                                    D("\(tr(Self.band(sc))) · \(sc) " + tr("of 27")).font(.hs(15, .bold)).foregroundStyle(sc >= 10 ? Color(hex: 0xF59E0B) : HS.text)
                                    T(sc >= 20 ? "This is a lot to carry. Please see a doctor or counselor this week — depression at this level responds well to treatment."
                                      : sc >= 10 ? "Scores like this are worth taking to a doctor or counselor. Book a visit, and tell someone you trust."
                                      : sc >= 5 ? "Some mild symptoms. Sleep, movement, sunlight and time with people help. If it lasts or grows, talk to your doctor."
                                      : "Few symptoms right now. Keep doing what's working.").font(.hs(12)).foregroundStyle(HS.textSecondary)
                                    T("This is a screening, not a diagnosis (PHQ-9).").font(.hs(10)).foregroundStyle(HS.textMuted)
                                }
                            }
                        }
                        if full && sc >= 10 && (a[8] ?? 0) == 0 { CrisisBox() }
                    }
                }.padding(20)
            }
        }
    }
}
