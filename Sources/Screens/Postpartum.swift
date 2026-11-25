import SwiftUI

/// Android's new-parents screen (data/Postpartum.kt, ui/screens/PostpartumScreen.kt): mood after a baby arrives, for
/// mothers, fathers and partners, and the people helping them. The private self-check is the PHQ-9 and GAD-2; it never
/// diagnoses, and any answer above "not at all" on the self-harm question shows crisis help straight away. The text
/// comes from Android in Resources/postpartum.json. Nothing leaves the phone.
enum Postpartum {
    struct Content: Decodable {
        let PHQ9, GAD2, ANSWERS, MOM_TIPS, PARTNER_TIPS, SUPPORTER_TIPS, HOW_TO_ASK, BODY_WARNING_SIGNS, WARNING_SIGNS: [String]
        let CONDITIONS: [Cond]
        let VERSES: [String: [String]]
        let PRAYERS: [String: String]
        let COMFORT: [String]
        let FAITH_NOTE, EMERGENCY, SLEEP_NOTE: String
        struct Cond: Decodable { let title, emoji, body: String }
    }
    static let c: Content? = {
        guard let u = Bundle.main.url(forResource: "postpartum", withExtension: "json"), let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(Content.self, from: d)
    }()

    enum Role: String, CaseIterable, Codable { case MOM, PARTNER, SUPPORTER
        var emoji: String { ["MOM": "🤱", "PARTNER": "👨‍🍼", "SUPPORTER": "🤝"][rawValue]! }
        var tab: String { ["MOM": "For mom", "PARTNER": "For dad & partners", "SUPPORTER": "For family & friends"][rawValue]! }
    }

    struct Check: Codable { let date: String; let role: Role; let phq: [Int]; let gad: [Int]
        var depression: Int { phq.reduce(0, +) }
        var anxiety: Int { gad.reduce(0, +) }
        var selfHarm: Bool { phq.count > 8 && phq[8] > 0 }
    }
    enum Urgency { case crisis, today, thisWeek, watch, ok }
    struct Result { let urgency: Urgency; let level: String; let anxious: Bool; let headline: String; let advice: [String] }

    static func level(_ s: Int) -> String {
        s >= 20 ? "Severe signs" : s >= 15 ? "Moderately severe signs" : s >= 10 ? "Moderate signs" : s >= 5 ? "Mild signs" : "Few signs of depression"
    }

    static func result(_ ch: Check) -> Result {
        let lvl = level(ch.depression), anxious = ch.anxiety >= 3
        let who = ch.role == .PARTNER ? "Fathers and partners get postpartum depression too, about 1 in 10. " : ""
        if ch.selfHarm {
            return Result(urgency: .crisis, level: lvl, anxious: anxious, headline: "Please reach out right now", advice: [
                "You said you've had thoughts of being better off dead or of hurting yourself. You deserve help today, and it works.",
                "Call or text 988, or call or text 1-833-TLC-MAMA (1-833-852-6262). Both are free and open 24/7.",
                "If you might act on these thoughts, or you're worried about the baby's safety, call 911 or go to the nearest emergency room.",
                "Tell someone near you now, and ask them to stay with you."])
        }
        if ch.depression >= 20 {
            return Result(urgency: .today, level: lvl, anxious: anxious, headline: "Talk to a doctor today", advice: [
                who + "Your answers are in the range where treatment usually makes a big difference, and you shouldn't have to carry this alone.",
                "Call your doctor, midwife or OB today, or your baby's pediatrician if that's easier. Say: \"I think I have postpartum depression.\"",
                "You can call or text 1-833-TLC-MAMA (1-833-852-6262) any time to talk it through first."])
        }
        if ch.depression >= 10 {
            return Result(urgency: .thisWeek, level: lvl, anxious: anxious, headline: "Worth talking to a doctor this week", advice: [
                who + "Scores of 10 or more are where doctors usually look closer. It's common after a birth, it isn't a failure, and it's very treatable.",
                "Book a visit with your doctor, midwife or OB this week and show them this check.",
                "Postpartum Support International (1-800-944-4773) can connect you with free support groups and specialists near you."])
        }
        if anxious {
            return Result(urgency: .thisWeek, level: lvl, anxious: true, headline: "Anxiety is showing up", advice: [
                "Constant worry, racing thoughts or feeling on edge after a baby is common, and it's treatable just like depression.",
                "Mention it at your next checkup, or sooner if it's getting in the way of sleep, eating or enjoying your baby.",
                "Postpartum Support International (1-800-944-4773) has free online groups for anxious new parents."])
        }
        if ch.depression >= 5 {
            return Result(urgency: .watch, level: lvl, anxious: false, headline: "Some signs to keep an eye on", advice: [
                "Mild low mood is common in the first weeks (the \"baby blues\"). If it lasts past two weeks or gets heavier, talk to your doctor.",
                "Protect one longer stretch of sleep, eat something with protein, get outside for a short walk, and tell one person how you're really doing.",
                "Check in again in a week or two."])
        }
        return Result(urgency: .ok, level: lvl, anxious: false, headline: "You're doing okay right now", advice: [
            "Few signs of depression or anxiety in the last two weeks. Keep looking after yourself, and check in again in two weeks; postpartum depression can start any time in the first year."])
    }

    static var checks: [Check] {
        get { UserDefaults.standard.data(forKey: "ppChecks").flatMap { try? JSONDecoder().decode([Check].self, from: $0) } ?? [] }
        set { if let d = try? JSONEncoder().encode(Array(newValue.suffix(200))) { UserDefaults.standard.set(d, forKey: "ppChecks") } }
    }

    struct Helpline { let name, about, call: String; let text: String?; let web: String }
    static let help = [
        Helpline(name: "National Maternal Mental Health Hotline", about: "1-833-TLC-MAMA (1-833-852-6262). Free, confidential, 24/7 for pregnant and new moms and their families. English, Spanish and 60 more languages.",
                 call: "18338526262", text: "18338526262", web: "https://mchb.hrsa.gov/national-maternal-mental-health-hotline"),
        Helpline(name: "Postpartum Support International", about: "1-800-944-4773. Information, support and local specialists for moms, dads and partners, plus free online support groups. Not a crisis line.",
                 call: "18009444773", text: "18009444773", web: "https://www.postpartum.net"),
        Helpline(name: "988 Suicide & Crisis Lifeline", about: "If you feel hopeless or unsafe. Call or text 988, free and confidential, 24/7.", call: "988", text: "988", web: "https://988lifeline.org"),
        Helpline(name: "National Domestic Violence Hotline", about: "1-800-799-SAFE (1-800-799-7233), or text START to 88788. Free, confidential, 24/7, in English and Spanish. If someone may check your phone, call from a safe phone or use the website's quick exit.",
                 call: "18007997233", text: "88788", web: "https://www.thehotline.org"),
    ]
}

struct PostpartumView: View {
    @AppStorage("ppRole") private var roleRaw = Postpartum.Role.MOM.rawValue
    @State private var tab = 0
    @State private var checking = false
    @State private var justSaved: Postpartum.Check?
    @State private var confirmDelete = false
    @State private var refresh = 0
    @Environment(\.openURL) private var openURL
    private let rose = Color(hex: 0xF472B6), crisis = Color(hex: 0xEF4444)

    private var role: Postpartum.Role { Postpartum.Role(rawValue: roleRaw) ?? .MOM }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("👶 NEW PARENTS").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF472B6))
                    T("After the baby arrives").font(.hs(22, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(crisis)
                        T(Postpartum.c?.EMERGENCY ?? "").font(.hs(12)).foregroundStyle(HS.text)
                    }
                    .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(crisis.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(crisis.opacity(0.4)))
                    HStack(spacing: 8) {
                        ForEach(Postpartum.Role.allCases, id: \.self) { r in
                            let on = r == role
                            Button { roleRaw = r.rawValue; justSaved = nil } label: {
                                VStack(spacing: 2) { D(r.emoji).font(.system(size: 20)); T(r.tab).font(.hs(11, .semibold)).foregroundStyle(on ? HS.text : HS.textSecondary).multilineTextAlignment(.center) }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 6)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(on ? rose.opacity(0.18) : HS.cardFill))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? rose : .clear))
                            }
                            .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    SubTabs(tabs: ["Check in", "Support", "Learn"], selected: $tab).padding(.horizontal, -20)
                    switch tab {
                    case 0: checkIn
                    case 1: support
                    default: learn
                    }
                    T("🔒 Your check-ins stay on this phone. They're never uploaded. You choose if anything is shared. This is a self-check, not a diagnosis.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .padding(20).padding(.bottom, 40).id(refresh)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $checking) {
            SelfCheckSheet(role: role) { c in
                var all = Postpartum.checks; all.removeAll { $0.date == c.date && $0.role == c.role }; all.append(c)
                Postpartum.checks = all; justSaved = c; refresh += 1
                ActivityLog.shared.add(.tracker)
            }
        }
        .alert(tr("Delete your check-ins?"), isPresented: $confirmDelete) {
            Button(tr("Delete"), role: .destructive) { Postpartum.checks = []; justSaved = nil; refresh += 1 }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("This removes every mood check-in saved on this phone. It can't be undone.") }
    }

    @ViewBuilder private var checkIn: some View {
        if role != .SUPPORTER {
            let mine = Postpartum.checks.filter { $0.role == role }
            let last = mine.last
            let due = last.map { days($0.date) >= 14 } ?? true
            SectionHeader(title: role == .MOM ? "How are you, really?" : "How are you doing, Dad?").padding(.horizontal, -20)
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    T("A private 2-minute check (the PHQ-9 and GAD-2 questions many US clinics use after a birth). It shows how your answers compare and when to talk to a doctor.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if let c = justSaved ?? last { resultBlock(c, Postpartum.result(c)) }
                    if !mine.isEmpty {
                        T("Your check-ins").font(.hs(11, .semibold)).foregroundStyle(HS.textMuted)
                        ForEach(Array(mine.suffix(6).enumerated()), id: \.offset) { _, c in
                            HStack {
                                D(pretty(c.date)).font(.hs(12)).foregroundStyle(HS.textSecondary).frame(width: 110, alignment: .leading)
                                D(tr("Mood \(c.depression)/27 · Worry \(c.anxiety)/6") + (c.selfHarm ? " · ⚠️" : "")).font(.hs(12)).foregroundStyle(HS.text)
                            }
                        }
                    }
                    HStack {
                        Button { checking = true } label: {
                            T(last == nil ? "Start check-in" : due ? "Check in again" : "Check in now").font(.hs(14, .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 10).background(Capsule().fill(rose))
                        }
                        if let last, !due { D(tr("Next suggested") + " " + pretty(plus(last.date, 14))).font(.hs(11)).foregroundStyle(HS.textMuted) }
                        Spacer()
                        if !mine.isEmpty { Button { confirmDelete = true } label: { T("Delete").font(.hs(12)).foregroundStyle(HS.textMuted) } }
                    }
                }
            }
        }
        SectionHeader(title: role == .MOM ? "Body warning signs after birth" : "Her body: warning signs after birth").padding(.horizontal, -20)
        bullets(Postpartum.c?.BODY_WARNING_SIGNS ?? [], "🚨")
    }

    @ViewBuilder private var support: some View {
        NavigationLink { BabyView() } label: {
            HStack(spacing: 10) {
                D("🍼").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    T("Baby log").font(.hs(15, .bold)).foregroundStyle(HS.text)
                    T("Feeds, sleep and diapers").font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
        }
        .buttonStyle(.plain)
        NavigationLink { TemperatureView() } label: {
            HStack(spacing: 10) {
                D("🌡️").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    T("Temperature").font(.hs(15, .bold)).foregroundStyle(HS.text)
                    T("Fever check for you or your baby").font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
        }
        .buttonStyle(.plain)
        SectionHeader(title: "Free help, any time").padding(.horizontal, -20)
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Postpartum.help, id: \.name) { h in
                    VStack(alignment: .leading, spacing: 6) {
                        T(h.name).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        T(h.about).font(.hs(12)).foregroundStyle(HS.textSecondary)
                        HStack(spacing: 8) {
                            pill("Call", rose) { openURL(URL(string: "tel:\(h.call)")!) }
                            if let t = h.text { pill("Text", rose) { openURL(URL(string: "sms:\(t)")!) } }
                            pill("Website", HS.gold) { openURL(URL(string: h.web)!) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var learn: some View {
        if let c = Postpartum.c {
            SectionHeader(title: role == .MOM ? "Taking care of you" : role == .PARTNER ? "Caring for her, and for you" : "How to really help").padding(.horizontal, -20)
            bullets(role == .MOM ? c.MOM_TIPS : role == .PARTNER ? c.PARTNER_TIPS : c.SUPPORTER_TIPS, "•")
            if role != .MOM {
                SectionHeader(title: "Signs she needs more help").padding(.horizontal, -20)
                bullets(c.WARNING_SIGNS, "⚠️")
                SectionHeader(title: "How to ask").padding(.horizontal, -20)
                bullets(c.HOW_TO_ASK, "💬")
            }
            SectionHeader(title: "Baby blues, or something more?").padding(.horizontal, -20)
            ForEach(c.CONDITIONS, id: \.title) { k in
                GlassCard {
                    VStack(alignment: .leading, spacing: 4) {
                        D(k.emoji + " " + tr(k.title)).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        T(k.body).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                }
            }
            SectionHeader(title: "For your heart").padding(.horizontal, -20)
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    if let v = c.VERSES[role.rawValue] {
                        D("“" + v[0] + "”").font(.accent(14)).foregroundStyle(HS.text)
                        D("— " + v[1]).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    D("“" + c.COMFORT[0] + "”").font(.accent(13)).foregroundStyle(HS.textSecondary).padding(.top, 4)
                    D("— " + c.COMFORT[1]).font(.hs(12)).foregroundStyle(HS.textMuted)
                    T("🙏 A prayer").font(.hs(13, .semibold)).foregroundStyle(HS.faith).padding(.top, 6)
                    T(c.PRAYERS[role.rawValue] ?? "").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    T(c.FAITH_NOTE).font(.hs(12)).foregroundStyle(HS.textMuted).padding(.top, 4)
                }
            }
        }
    }

    private func resultBlock(_ c: Postpartum.Check, _ r: Postpartum.Result) -> some View {
        let tone: Color = switch r.urgency { case .crisis, .today: crisis; case .thisWeek: HS.gold; case .watch: HS.faith; case .ok: Color(hex: 0x10B981) }
        return VStack(alignment: .leading, spacing: 6) {
            T(r.headline).font(.hs(15, .bold)).foregroundStyle(HS.text)
            D(pretty(c.date) + " · " + tr("Mood \(c.depression)/27") + " (" + tr(r.level).lowercased() + ") · " + tr("Worry \(c.anxiety)/6") + (r.anxious ? " (" + tr("high") + ")" : ""))
                .font(.hs(11)).foregroundStyle(HS.textMuted)
            ForEach(r.advice, id: \.self) { T("• " + $0).font(.hs(13)).foregroundStyle(HS.text) }
            if r.urgency == .crisis || r.urgency == .today {
                HStack(spacing: 8) {
                    pill("Call 988", crisis) { openURL(URL(string: "tel:988")!) }
                    pill("Text 988", crisis) { openURL(URL(string: "sms:988")!) }
                    pill("Call TLC-MAMA", rose) { openURL(URL(string: "tel:18338526262")!) }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(tone.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tone.opacity(0.45)))
    }

    private func bullets(_ items: [String], _ mark: String) -> some View {
        GlassCard { VStack(alignment: .leading, spacing: 6) { ForEach(items, id: \.self) { T(mark + " " + $0).font(.hs(13)).foregroundStyle(HS.text) } } }
    }
    private func pill(_ label: String, _ c: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { T(label).font(.hs(12, .semibold)).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(c)) }.buttonStyle(.plain)
    }
    private func days(_ key: String) -> Int {
        guard let d = AppStore.date(fromKey: key) else { return 99 }
        return Calendar.current.dateComponents([.day], from: d, to: Calendar.current.startOfDay(for: Date())).day ?? 99
    }
    private func plus(_ key: String, _ n: Int) -> String { BodyEnergy.plus(key, n) }
    private func pretty(_ key: String) -> String {
        AppStore.date(fromKey: key)?.formatted(.dateTime.month(.abbreviated).day().year().locale(I18n.shared.locale)) ?? key
    }
}

/// Android's SelfCheckDialog: the PHQ-9 then the GAD-2, one question at a time.
struct SelfCheckSheet: View {
    let role: Postpartum.Role
    let onDone: (Postpartum.Check) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var answers = [Int](repeating: -1, count: 11)
    @State private var index = 0

    var body: some View {
        let qs = (Postpartum.c?.PHQ9 ?? []) + (Postpartum.c?.GAD2 ?? [])
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if qs.count == 11 {
                    D(tr("Question \(index + 1) of \(qs.count)")).font(.hs(12)).foregroundStyle(HS.textMuted)
                    T("Over the last 2 weeks, how often have you been bothered by:").font(.hs(14))
                    T(qs[index]).font(.hs(18, .semibold))
                    if index == 2 || index == 3 { T(Postpartum.c?.SLEEP_NOTE ?? "").font(.hs(12)).foregroundStyle(HS.textMuted) }
                    ForEach(Array((Postpartum.c?.ANSWERS ?? []).enumerated()), id: \.offset) { i, a in
                        Button {
                            answers[index] = i
                            if index < qs.count - 1 { index += 1 }
                            else {
                                onDone(Postpartum.Check(date: AppStore.dayKey(), role: role, phq: Array(answers[0..<9]), gad: Array(answers[9..<11])))
                                dismiss()
                            }
                        } label: {
                            T(a).font(.hs(15)).foregroundStyle(HS.text).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(answers[index] == i ? Color(hex: 0xF472B6).opacity(0.2) : HS.cardFill))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(HSBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { dismiss() } }
                if index > 0 { ToolbarItem(placement: .topBarLeading) { Button(tr("Back")) { index -= 1 } } }
            }
        }
    }
}

/// Android's NewParentsEntryCard.
struct NewParentsEntryCard: View {
    var title = "A new baby in your life?"
    var subtitle = "Postpartum mood, warning signs after birth, and free help any time"
    @State private var open = false
    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 10) {
                D("👶").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    T(title).font(.hs(15, .bold)).foregroundStyle(HS.text)
                    T(subtitle).font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xF472B6).opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0xF472B6).opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $open) {
            NavigationStack {
                PostpartumView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Close")) { open = false } } }
            }
        }
    }
}
