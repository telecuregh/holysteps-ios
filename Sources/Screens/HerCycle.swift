import SwiftUI
import zlib

/// Android's "Support her cycle" (ui/screens/SupportHerCycle.kt): she sends her partner a short code; his phone works
/// out her phase from it, offline. No server and no account link: the code carries only her last period start, cycle
/// and period length, whether she shares her fertile days, and an end date she chooses (7, 30 or 60 days). Symptoms,
/// notes and moods are never in it. Same code format as Android, so an iPhone and an Android phone understand each other.
enum HerCycleCode {
    struct Share: Equatable { let startEpoch: Int64; let cycleLen, periodLen: Int; let untilEpoch: Int64; let fertile: Bool }

    private static func sum(_ s: String) -> String {
        let c = s.utf8.withContiguousStorageIfAvailable { crc32(0, $0.baseAddress, uInt($0.count)) } ?? 0
        let v = String(Int(c % 1296), radix: 36)
        return v.count < 2 ? "0" + v : v
    }

    static func encode(_ s: Share) -> String {
        let body = [s.startEpoch, Int64(s.cycleLen), Int64(s.periodLen), s.untilEpoch, s.fertile ? 1 : 0].map { String($0, radix: 36) }.joined(separator: ".")
        return ("HS-" + body + "-" + sum(body)).uppercased()
    }

    static func decode(_ raw: String) -> Share? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.hasPrefix("HS-") { t.removeFirst(3) }
        guard let dash = t.lastIndex(of: "-") else { return nil }
        let body = String(t[..<dash]).lowercased(), chk = String(t[t.index(after: dash)...])
        guard sum(body).uppercased() == chk else { return nil }
        let f = body.split(separator: ".").compactMap { Int64($0, radix: 36) }
        guard f.count == 5 else { return nil }
        return Share(startEpoch: f[0], cycleLen: min(60, max(18, Int(f[1]))), periodLen: min(12, max(1, Int(f[2]))), untilEpoch: f[3], fertile: f[4] == 1)
    }

    /// Local calendar day as Android's LocalDate.toEpochDay().
    static func epochDay(_ d: Date = Date()) -> Int64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utc.date(from: c) ?? d
        return Int64((midnight.timeIntervalSince1970 / 86400).rounded(.down))
    }
    static func date(_ epoch: Int64) -> Date {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let c = utc.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(epoch) * 86400))
        return Calendar.current.date(from: c) ?? Date()
    }

    static func cycleDay(_ s: Share, _ today: Int64) -> Int {
        let n = Int64(s.cycleLen)
        return Int((((today - s.startEpoch) % n) + n) % n) + 1
    }
    static func daysToNext(_ s: Share, _ today: Int64) -> Int { s.cycleLen - cycleDay(s, today) + 1 }

    static var saved: Share? { UserDefaults.standard.string(forKey: "herCycleCode").flatMap(decode) }
    static func save(_ code: String?) { UserDefaults.standard.set(code, forKey: "herCycleCode") }

    static func tips(_ p: CyclePhase) -> [String] {
        switch p {
        case .menstrual: ["Energy is often lowest now and cramps are common. Take something off her list without being asked.",
                          "A heating pad, her favorite snack, or handling dinner says a lot.",
                          "Ask \"What would help today?\", then do that, not what you'd want.",
                          "Pray for her by name today, rest, comfort and strength."]
        case .follicular: ["Energy and mood usually rise this week. A good time for plans, projects and date nights.",
                           "Try something new together, a walk, a class, a new place.",
                           "Read a psalm of thanks together this week."]
        case .ovulation: ["Many women feel most social and confident around now. Compliment her, specifically.",
                          "Plan quality time; she may enjoy being out with friends too.",
                          "Thank God out loud for one thing you love about her."]
        case .luteal: ["In the days before her period, many women feel more tired, bloated or irritable. It's hormones, not you, stay patient.",
                       "Keep plans light, offer comfort food and a quiet night, and pick up extra chores.",
                       "Listen more than you fix.",
                       "Pray for peace and patience for both of you this week."]
        }
    }
}

private struct SmallChip: View {
    let label: String
    var on = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            D(tr(label)).font(.hs(12, .semibold)).foregroundStyle(on ? HS.text : HS.textMuted)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(on ? HS.goldButton.opacity(0.22) : HS.cardFill))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.gold.opacity(on ? 1 : 0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// On her Cycle screen: make and send a code.
struct ShareWithHusbandCard: View {
    @EnvironmentObject var store: AppStore
    @State private var fertile = false
    @State private var days = 30

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T("💞 Let your partner support you").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                T("Send him a private code. His HolySteps shows your phase, when your period is due, and how to love you well that week. Your symptoms, notes and moods are never shared.")
                    .font(.hs(11)).foregroundStyle(HS.textMuted)
                T("You choose how long the code works. A code can't be pulled back once it's sent, so pick the shortest time you're comfortable with. When it ends, he sees nothing until you send a new one.")
                    .font(.hs(11)).foregroundStyle(HS.textMuted)
                if let start = store.periodStarts.max() {
                    HStack(spacing: 6) {
                        ForEach([7, 30, 60], id: \.self) { d in SmallChip(label: "\(d) days", on: days == d) { days = d } }
                    }
                    HStack(spacing: 6) {
                        SmallChip(label: fertile ? "✓ Include fertile days" : "Include fertile days", on: fertile) { fertile.toggle() }
                        let code = HerCycleCode.encode(.init(startEpoch: HerCycleCode.epochDay(start), cycleLen: store.cycleLength, periodLen: store.periodLength,
                                                             untilEpoch: HerCycleCode.epochDay() + Int64(days), fertile: fertile))
                        ShareLink(item: tr("Here's my HolySteps cycle code. Open HolySteps → Men's Wellness → Support her cycle and paste it:") + "\n" + code) {
                            D(tr("Send code")).font(.hs(12, .semibold)).foregroundStyle(HS.text)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.gold.opacity(0.22), lineWidth: 1))
                        }
                    }
                } else {
                    T("Log your last period first.").font(.hs(12)).foregroundStyle(HS.textSecondary)
                }
            }
        }
    }
}

/// On his side: paste the code, then a daily view of her phase with tips.
struct SupportHerCycleView: View {
    @State private var share = HerCycleCode.saved
    @State private var input = ""
    @State private var bad = false

    var body: some View {
        let today = HerCycleCode.epochDay()
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("💞 MARRIAGE").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xF472B6))
                    T("Support her cycle").font(.hs(24)).foregroundStyle(HS.text)
                    T("When your partner shares her code, you'll see where she is in her cycle and simple ways to love her well. It stays on your phone.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if let s = share, s.untilEpoch >= today {
                        let day = HerCycleCode.cycleDay(s, today)
                        let phase = CyclePhase.forDay(day, periodLength: s.periodLen, cycleLength: s.cycleLen)
                        let toNext = HerCycleCode.daysToNext(s, today)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                D(phase.emoji + " " + tr(phase.label) + " · " + tr("day \(day)")).font(.hs(18, .bold)).foregroundStyle(HS.text)
                                D(tr(phase == .menstrual ? "Her period is likely now." : toNext == 1 ? "Her next period is in about 1 day." : "Her next period is in about \(toNext) days."))
                                    .font(.hs(12)).foregroundStyle(HS.textSecondary)
                                if s.fertile && (phase == .ovulation || (s.cycleLen - 19...s.cycleLen - 12).contains(day)) {
                                    T("✨ Likely fertile window").font(.hs(12)).foregroundStyle(Color(hex: 0xF59E0B))
                                }
                                T("These are predictions from her last period, every cycle varies.").font(.hs(10)).foregroundStyle(HS.textMuted)
                            }
                        }
                        SectionHeader(title: "How to love her this week").padding(.horizontal, -20)
                        ForEach(HerCycleCode.tips(phase), id: \.self) { T("• " + $0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                        Button { HerCycleCode.save(nil); share = nil; input = "" } label: {
                            D(tr("Shared until") + " " + HerCycleCode.date(s.untilEpoch).formatted(date: .numeric, time: .omitted) + " · " + tr("Remove")).font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                    } else {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                if share != nil { T("Her code ended. Ask her for a new one.").font(.hs(12)).foregroundStyle(Color(hex: 0xF59E0B)) }
                                T("Paste the code she sent you").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                TextField("HS-…", text: $input).textInputAutocapitalization(.characters).autocorrectionDisabled()
                                    .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.05)))
                                    .onChange(of: input) { _, _ in bad = false }
                                if bad { T("That code doesn't look right, copy it again from her message.").font(.hs(11)).foregroundStyle(Color(hex: 0xF43F5E)) }
                                SmallChip(label: "Connect") { connect(today) }
                                T("She makes the code in her HolySteps: Cycle → Let your partner support you.").font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func connect(_ today: Int64) {
        let up = input.uppercased()
        let code = up.range(of: #"HS-[A-Z0-9.]+-[A-Z0-9]{2}"#, options: .regularExpression).map { String(up[$0]) } ?? input
        guard let d = HerCycleCode.decode(code), d.untilEpoch >= today else { bad = true; return }
        HerCycleCode.save(code); share = d
    }
}
