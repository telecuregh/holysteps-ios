import SwiftUI

/// Android's temperature check (data/TempLog.kt, TemperatureScreen.kt): a reading from a real thermometer and what it
/// means for the person it was taken for, using the published rules (AAP, Mayo Clinic, CDC Hear Her). HolySteps never
/// estimates a temperature. Not a diagnosis; readings stay on this phone.
enum TempLog {
    enum Site: String, Codable, CaseIterable { case RECTAL, FOREHEAD, EAR, ORAL, ARMPIT, OTHER
        var label: String { ["RECTAL": "Rectal", "FOREHEAD": "Forehead", "EAR": "Ear", "ORAL": "Mouth", "ARMPIT": "Armpit", "OTHER": "Other"][rawValue]! }
        var feverF: Double { self == .ORAL ? 100.0 : self == .ARMPIT ? 99.0 : 100.4 }
    }
    enum Age: String, Codable, CaseIterable { case UNDER_3M, M3_6, M6_24, Y2_PLUS, ADULT
        var label: String { ["UNDER_3M": "Baby under 3 months", "M3_6": "Baby 3 to 6 months", "M6_24": "6 months to 2 years", "Y2_PLUS": "Child 2 years and older", "ADULT": "Teen or adult"][rawValue]! }
    }
    enum Level { case check, normal, fever, callDoctor, callNow }
    struct Entry: Codable, Equatable { var at: Date; var f: Double; var site: Site; var age: Age; var who = "me" }
    struct Advice { let level: Level; let title: String; let lines: [String] }

    static func fmt(_ f: Double) -> String { String(format: "%.1f°F", f) }
    static func isFever(_ e: Entry) -> Bool { e.f >= e.site.feverF }
    static func feverHours(_ e: Entry, _ history: [Entry]) -> Double {
        guard isFever(e) else { return 0 }
        let mine = history.filter { $0.who == e.who && $0.at <= e.at && $0.at >= e.at.addingTimeInterval(-7 * 86400) }.sorted { $0.at < $1.at }
        var start = e.at
        for h in mine.reversed() { if isFever(h) { start = min(start, h.at) } else { break } }
        return e.at.timeIntervalSince(start) / 3600
    }
    private static func over104(_ e: Entry, _ history: [Entry]) -> Int {
        (history + [e]).filter { $0.who == e.who && $0.f > 104 && $0.at >= e.at.addingTimeInterval(-3 * 86400) && $0.at <= e.at }
            .reduce(into: [Entry]()) { if !$0.contains($1) { $0.append($1) } }.count
    }

    static func assess(_ e: Entry, _ history: [Entry], pregnantOrRecentBirth: Bool) -> Advice {
        guard (90...110).contains(e.f) else {
            return Advice(level: .check, title: "Check that reading", lines: ["\(fmt(e.f)) is outside what a body temperature can be. Take it again and check the °F or °C setting."])
        }
        let fever = isFever(e), hours = feverHours(e, history), baby = e.age != .ADULT
        let emergency = baby ? "Call 911 for trouble breathing, blue or gray lips, a seizure, or if your child is very hard to wake."
            : "Get emergency care for trouble breathing, chest pain, confusion, a seizure, a stiff neck with a severe headache, or a rash that doesn't fade when pressed."
        let how = baby ? "How your child looks and acts matters as much as the number. A child who is playing and drinking is usually less worrying than one who is limp or won't drink."
            : "Rest and drink plenty. How you feel matters as much as the number."
        if e.age == .UNDER_3M && e.f < 97.5 && (e.site == .RECTAL || e.site == .FOREHEAD) {
            return Advice(level: .callNow, title: "Low temperature: call the doctor now", lines: [
                "Under 97.5°F is low for a young baby and can be a sign of infection.",
                "Hold your baby skin-to-skin, add a layer and a hat, and call your baby's doctor now, day or night.", emergency])
        }
        if e.age == .ADULT && e.f < 95 {
            return Advice(level: .callNow, title: "Very low: get emergency care", lines: ["A body temperature under 95°F is hypothermia, a medical emergency. Call 911, and warm up slowly with dry clothes and blankets."])
        }
        if !fever {
            var l = ["A fever \(e.site.label.lowercased()) starts at \(fmt(e.site.feverF))."]
            if e.site == .ARMPIT && e.f >= 98.6 && baby { l.append("Armpit readings run lower than rectal ones. If your child seems unwell, check with a rectal or forehead thermometer.") }
            return Advice(level: .normal, title: "No fever", lines: l)
        }
        if pregnantOrRecentBirth && e.age == .ADULT && e.who == "me" {
            return Advice(level: .callNow, title: "Get medical care right away", lines: [
                "A fever of 100.4°F or higher during pregnancy or in the year after giving birth is one of the CDC's urgent warning signs.",
                "Call your doctor or midwife now, or go to urgent care, and say you're pregnant or had a baby in the last year.", emergency])
        }
        switch e.age {
        case .UNDER_3M:
            return e.site == .ARMPIT
                ? Advice(level: .callDoctor, title: "Re-check now", lines: ["An armpit reading over 99°F in a baby under 3 months needs a rectal check right away.",
                                                                            "If the rectal temperature is 100.4°F or higher, call the doctor now, day or night.", emergency])
                : Advice(level: .callNow, title: "Call the doctor now", lines: ["Any fever of 100.4°F or more in a baby under 3 months needs a doctor now, day or night, even if your baby seems fine.",
                                                                                 "Don't give fever medicine before talking to the doctor.", emergency])
        case .M3_6:
            if e.f >= 101 || hours > 24 { return Advice(level: .callDoctor, title: "Call your baby's doctor", lines: [e.f >= 101 ? "For a baby 3 to 6 months old, 101°F or higher is a reason to call." : "This fever has lasted more than 24 hours.", how, emergency]) }
        case .M6_24:
            if e.f >= 103 || hours > 24 || over104(e, history) >= 2 { return Advice(level: .callDoctor, title: "Call your child's doctor", lines: [e.f >= 103 ? "For a child 6 months or older, 103°F or higher is a reason to call." : "Under age 2, a fever lasting more than 24 hours is a reason to call.", how, emergency]) }
        case .Y2_PLUS:
            if hours > 72 || over104(e, history) >= 2 { return Advice(level: .callDoctor, title: "Call your child's doctor", lines: [hours > 72 ? "This fever has lasted more than 3 days." : "The fever has gone above 104°F more than once.", how, emergency]) }
        case .ADULT:
            if e.f >= 103 || hours > 72 { return Advice(level: .callDoctor, title: "Call your doctor", lines: [e.f >= 103 ? "For an adult, 103°F or higher is a reason to call your doctor." : "This fever has lasted more than 3 days.", how, emergency]) }
        }
        let until = (e.age == .M3_6 || e.age == .M6_24) ? "more than 24 hours" : "more than 3 days"
        return Advice(level: .fever, title: "Fever", lines: ["A fever is the body fighting an infection. Check again in a few hours; call the doctor if it lasts \(until).", how, emergency])
    }

    static var entries: [Entry] {
        get { UserDefaults.standard.data(forKey: "tempLog").flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? [] }
        set { if let d = try? JSONEncoder().encode(Array(newValue.suffix(300))) { UserDefaults.standard.set(d, forKey: "tempLog") } }
    }
}

struct TemperatureView: View {
    @State private var text = ""
    @State private var celsius = false
    @State private var site = TempLog.Site.FOREHEAD
    @State private var age = TempLog.Age.ADULT
    @State private var who = ""
    @State private var pregnant = UserDefaults.standard.bool(forKey: "tempPregnant")
    @State private var advice: TempLog.Advice?
    @State private var refresh = 0
    @FocusState private var typing: Bool

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🌡️ TEMPERATURE").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF97316))
                    T("Fever check").font(.hs(24)).foregroundStyle(HS.text)
                    T("Type a reading from a real thermometer. A phone can't take your temperature by itself.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                TextField(celsius ? "37.0" : "98.6", text: $text).keyboardType(.decimalPad).focused($typing)
                                    .font(.hs(28, .bold)).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(HS.overlay(0.05)))
                                Picker("", selection: $celsius) { D("°F").tag(false); D("°C").tag(true) }.pickerStyle(.segmented).frame(width: 110)
                            }
                            Picker(tr("Where it was taken"), selection: $site) { ForEach(TempLog.Site.allCases, id: \.self) { D(tr($0.label)).tag($0) } }
                            Picker(tr("Who it's for"), selection: $age) { ForEach(TempLog.Age.allCases, id: \.self) { D(tr($0.label)).tag($0) } }
                            TextField(tr("Name (optional, to follow each person's fever)"), text: $who).font(.hs(14))
                            if age == .ADULT && who.trimmingCharacters(in: .whitespaces).isEmpty {
                                Toggle(tr("I'm pregnant, or gave birth in the last year"), isOn: $pregnant).font(.hs(13)).tint(HS.goldButton)
                                    .onChange(of: pregnant) { _, v in UserDefaults.standard.set(v, forKey: "tempPregnant") }
                            }
                            GoldButton(title: "Check") { check() }
                        }
                    }
                    if let a = advice { adviceCard(a) }
                    history.id(refresh)
                    T("Not a diagnosis. How the person looks and acts matters as much as the number. Readings stay on this phone.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .padding(20).padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func check() {
        typing = false
        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")) else { return }
        let f = celsius ? v * 9 / 5 + 32 : v
        let name = who.trimmingCharacters(in: .whitespaces)
        let e = TempLog.Entry(at: Date(), f: f, site: site, age: age, who: name.isEmpty ? "me" : name)
        let history = TempLog.entries
        advice = TempLog.assess(e, history, pregnantOrRecentBirth: pregnant)
        if (90...110).contains(f) { TempLog.entries = history + [e]; refresh += 1; ActivityLog.shared.add(.tracker) }
    }

    private func adviceCard(_ a: TempLog.Advice) -> some View {
        let c: Color = switch a.level { case .callNow: Color(hex: 0xEF4444); case .callDoctor: Color(hex: 0xF59E0B); case .fever: Color(hex: 0xF97316); case .normal: Color(hex: 0x10B981); case .check: HS.faith }
        return VStack(alignment: .leading, spacing: 6) {
            T(a.title).font(.hs(17, .bold)).foregroundStyle(HS.text)
            ForEach(a.lines, id: \.self) { T("• " + $0).font(.hs(13)).foregroundStyle(HS.text) }
            if a.level == .callNow { Link(destination: URL(string: "tel:911")!) { T("Call 911").font(.hs(13, .semibold)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(c)) } }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(c.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(c.opacity(0.45)))
    }

    @ViewBuilder private var history: some View {
        let all = TempLog.entries.suffix(10).reversed()
        if !all.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    T("Recent readings").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                    ForEach(Array(all.enumerated()), id: \.offset) { _, e in
                        HStack {
                            D(e.at.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(I18n.shared.locale))).font(.hs(12)).foregroundStyle(HS.textMuted)
                            Spacer()
                            D((e.who == "me" ? "" : e.who + " · ") + TempLog.fmt(e.f) + " · " + tr(e.site.label)).font(.hs(12, .semibold))
                                .foregroundStyle(TempLog.isFever(e) ? Color(hex: 0xF97316) : HS.text)
                        }
                    }
                    Button { TempLog.entries = []; refresh += 1 } label: { T("Clear readings").font(.hs(12)).foregroundStyle(HS.textMuted) }
                }
            }
        }
    }
}
