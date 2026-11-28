import SwiftUI

/// Android's baby log (data/BabyLog.kt, ui/screens/BabyScreen.kt): feeds with a side timer, bottles, solids, pumping,
/// sleep, diapers and growth against the WHO standards (what CDC uses under age 2). Kept on this phone only.
enum BabyLog {
    enum Sex: String, Codable, CaseIterable { case BOY, GIRL, UNSET
        var label: String { ["BOY": "Boy", "GIRL": "Girl", "UNSET": "Not set"][rawValue]! }
    }
    struct Baby: Codable, Identifiable, Equatable { var id = BabyLog.newId(); var name: String; var birth: String; var sex: Sex }
    enum Kind: String, Codable { case br, bo, so, pu, sl, di, gr
        var label: String { ["br": "Breastfeed", "bo": "Bottle", "so": "Solids", "pu": "Pumping", "sl": "Sleep", "di": "Diaper", "gr": "Growth"][rawValue]! }
        var emoji: String { ["br": "🤱", "bo": "🍼", "so": "🥣", "pu": "🫙", "sl": "😴", "di": "🧷", "gr": "📏"][rawValue]! }
    }
    enum Side: String, Codable { case L, R
        var other: Side { self == .L ? .R : .L }
        var label: String { self == .L ? "Left" : "Right" }
    }
    enum Diaper: String, Codable, CaseIterable { case w, d, b, x
        var label: String { ["w": "Wet", "d": "Dirty", "b": "Both", "x": "Dry"][rawValue]! }
        var emoji: String { ["w": "💧", "d": "💩", "b": "💧💩", "x": "⚪"][rawValue]! }
        var wet: Bool { self == .w || self == .b }
        var dirty: Bool { self == .d || self == .b }
    }
    struct Entry: Codable, Identifiable, Equatable {
        var id = BabyLog.newId()
        var babyId: String
        var kind: Kind
        var start: Date
        var end: Date?
        var leftSec = 0, rightSec = 0
        var firstSide: Side?
        var ml = 0, ml2 = 0
        var formula: Bool?
        var diaper: Diaper?
        var weightG = 0, lengthMm = 0, headMm = 0
        var note = ""
        var duration: TimeInterval { end.map { max(0, $0.timeIntervalSince(start)) } ?? 0 }
    }
    struct Timer: Codable, Equatable {
        var babyId: String
        var kind: Kind
        var start: Date
        var side: Side?
        var sideSince = Date()
        var leftS = 0.0, rightS = 0.0
        var firstSide: Side?
        func left(_ now: Date) -> Double { leftS + (side == .L ? max(0, now.timeIntervalSince(sideSince)) : 0) }
        func right(_ now: Date) -> Double { rightS + (side == .R ? max(0, now.timeIntervalSince(sideSince)) : 0) }
        func elapsed(_ now: Date) -> Double { kind == .sl ? max(0, now.timeIntervalSince(start)) : left(now) + right(now) }
    }
    static let maxTimer = 14.0 * 3600

    static func finish(_ t: Timer, now: Date = Date()) -> Entry? {
        let end = min(now, t.start.addingTimeInterval(maxTimer))
        if t.kind == .br {
            let l = Int(min(t.left(end), maxTimer)), r = Int(min(t.right(end), maxTimer))
            return l + r < 5 ? nil : Entry(babyId: t.babyId, kind: .br, start: t.start, end: end, leftSec: l, rightSec: r, firstSide: t.firstSide)
        }
        return end.timeIntervalSince(t.start) < 5 ? nil : Entry(babyId: t.babyId, kind: .sl, start: t.start, end: end)
    }
    static func nextSide(_ e: [Entry], _ baby: String) -> Side? {
        e.filter { $0.babyId == baby && $0.kind == .br && $0.firstSide != nil }.max { $0.start < $1.start }?.firstSide?.other
    }

    static func ageDays(_ birth: String) -> Int {
        guard let b = AppStore.date(fromKey: birth) else { return 0 }
        return Calendar.current.dateComponents([.day], from: b, to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }
    static func ageLabel(_ birth: String) -> String {
        let d = ageDays(birth)
        if d < 0 { return "Due soon" }
        if d == 0 { return "Born today" }
        if d < 14 { return d == 1 ? "1 day old" : "\(d) days old" }
        if d < 91 { let w = d / 7, r = d % 7; return "\(w) weeks" + (r > 0 ? ", \(r) day\(r == 1 ? "" : "s")" : "") + " old" }
        let m = Int(Double(d) / 30.4375)
        if m < 24 { return "\(m) months old" }
        let y = m / 12, rm = m % 12
        return "\(y) year\(y == 1 ? "" : "s")" + (rm > 0 ? ", \(rm) month\(rm == 1 ? "" : "s")" : "") + " old"
    }

    struct Summary { var feeds = 0, breastFeeds = 0, breastMinutes = 0, bottleMl = 0, bottles = 0, solids = 0, pumpedMl = 0, sleepMinutes = 0, naps = 0, wet = 0, dirty = 0
        var lastFeed: Date?, lastDiaper: Date?, lastWake: Date? }
    static func summary(_ entries: [Entry], _ baby: String, from: Date, to: Date) -> Summary {
        let mine = entries.filter { $0.babyId == baby || ($0.kind == .pu && $0.babyId.isEmpty) }
        let inWin = mine.filter { $0.start >= from && $0.start < to }
        let feeds = inWin.filter { [.br, .bo, .so].contains($0.kind) }
        let sleeps = mine.filter { $0.kind == .sl && ($0.end ?? .distantPast) > from && $0.start < to }
        let diapers = inWin.filter { $0.kind == .di }
        var s = Summary()
        s.feeds = feeds.count
        s.breastFeeds = feeds.filter { $0.kind == .br }.count
        s.breastMinutes = Int((Double(feeds.filter { $0.kind == .br }.map { $0.leftSec + $0.rightSec }.reduce(0, +)) / 60).rounded())
        s.bottleMl = feeds.filter { $0.kind == .bo }.map(\.ml).reduce(0, +)
        s.bottles = feeds.filter { $0.kind == .bo }.count
        s.solids = feeds.filter { $0.kind == .so }.count
        s.pumpedMl = inWin.filter { $0.kind == .pu }.map { $0.ml + $0.ml2 }.reduce(0, +)
        s.sleepMinutes = Int(sleeps.map { min($0.end!, to).timeIntervalSince(max($0.start, from)) }.reduce(0, +) / 60)
        s.naps = sleeps.count
        s.wet = diapers.filter { $0.diaper?.wet == true }.count
        s.dirty = diapers.filter { $0.diaper?.dirty == true }.count
        s.lastFeed = mine.filter { [.br, .bo, .so].contains($0.kind) }.map(\.start).max()
        s.lastDiaper = mine.filter { $0.kind == .di }.map(\.start).max()
        s.lastWake = mine.filter { $0.kind == .sl }.compactMap(\.end).max()
        return s
    }

    struct SleepGuide { let fromDays, minWake, maxWake, minH, maxH: Int; let naps: String }
    static let sleepGuides = [
        SleepGuide(fromDays: 0, minWake: 35, maxWake: 60, minH: 14, maxH: 17, naps: "Many short sleeps, day and night"),
        SleepGuide(fromDays: 28, minWake: 60, maxWake: 90, minH: 14, maxH: 17, naps: "4 to 5 naps"),
        SleepGuide(fromDays: 84, minWake: 75, maxWake: 120, minH: 12, maxH: 16, naps: "3 to 4 naps"),
        SleepGuide(fromDays: 150, minWake: 120, maxWake: 180, minH: 12, maxH: 16, naps: "3 naps"),
        SleepGuide(fromDays: 213, minWake: 150, maxWake: 210, minH: 12, maxH: 16, naps: "2 to 3 naps"),
        SleepGuide(fromDays: 304, minWake: 180, maxWake: 240, minH: 12, maxH: 16, naps: "2 naps"),
        SleepGuide(fromDays: 426, minWake: 240, maxWake: 360, minH: 11, maxH: 14, naps: "1 to 2 naps"),
        SleepGuide(fromDays: 548, minWake: 300, maxWake: 360, minH: 11, maxH: 14, naps: "1 nap"),
    ]
    static func sleepGuide(_ age: Int) -> SleepGuide { sleepGuides.last { max(0, age) >= $0.fromDays }! }

    static func flags(_ entries: [Entry], _ baby: Baby) -> [String] {
        let age = ageDays(baby.birth), now = Date()
        guard let first = entries.filter({ $0.babyId == baby.id }).map(\.start).min(), now.timeIntervalSince(first) >= 86400 else { return [] }
        let s = summary(entries, baby.id, from: now.addingTimeInterval(-86400), to: now)
        var out: [String] = []
        if (6...60).contains(age) && (1...5).contains(s.wet) {
            out.append("Only \(s.wet) wet diaper\(s.wet == 1 ? "" : "s") logged in the last 24 hours. After the first week most babies have 6 or more. If that count is right, call your baby's doctor today.")
        }
        if (0...28).contains(age) && (1...7).contains(s.feeds) {
            out.append("\(s.feeds) feed\(s.feeds == 1 ? "" : "s") logged in the last 24 hours. Newborns usually feed 8 to 12 times a day. If that count is right, talk with your baby's doctor or a lactation consultant.")
        }
        return out
    }

    // MARK: Growth (WHO Child Growth Standards, birth to 2 years)
    enum Measure: String { case WEIGHT, LENGTH, HEAD }
    private static let who: [String: [Double]] = {
        guard let u = Bundle.main.url(forResource: "who_growth", withExtension: "json"), let d = try? Data(contentsOf: u) else { return [:] }
        return (try? JSONDecoder().decode([String: [Double]].self, from: d)) ?? [:]
    }()
    static func percentile(_ m: Measure, _ sex: Sex, _ age: Int, _ value: Double) -> Double? {
        guard value > 0, sex != .UNSET, let t = who["\(m.rawValue)_\(sex == .BOY ? "BOYS" : "GIRLS")"], t.count == 75 else { return nil }
        let months = Double(age) / 30.4375
        guard months >= 0, months <= 24 else { return nil }
        let i = min(23, Int(months)), f = months - Double(i)
        func at(_ k: Int, _ j: Int) -> Double { t[k * 3 + j] }
        let l = at(i, 0) + (at(i + 1, 0) - at(i, 0)) * f, mu = at(i, 1) + (at(i + 1, 1) - at(i, 1)) * f, s = at(i, 2) + (at(i + 1, 2) - at(i, 2)) * f
        let z = abs(l) < 1e-9 ? log(value / mu) / s : (pow(value / mu, l) - 1) / (l * s)
        return normalCdf(z) * 100
    }
    static func normalCdf(_ z: Double) -> Double {
        let x = abs(z) / 2.0.squareRoot(), t = 1 / (1 + 0.3275911 * x)
        let y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
        return z >= 0 ? 0.5 * (1 + y) : 0.5 * (1 - y)
    }
    static func percentileLabel(_ p: Double) -> String {
        if p < 0.1 { return "below the 0.1st percentile" }
        if p > 99.9 { return "above the 99.9th percentile" }
        let r = min(99, max(1, Int(p.rounded())))
        let suf = (11...13).contains(r % 100) ? "th" : [1: "st", 2: "nd", 3: "rd"][r % 10] ?? "th"
        return "\(r)\(suf) percentile"
    }
    static func growthNote(_ p: Double) -> String? {
        p < 2.3 ? "Below the 2nd percentile. Many healthy babies are small, but it's worth asking your baby's doctor about."
        : p > 97.7 ? "Above the 98th percentile. Many healthy babies are big, but it's worth asking your baby's doctor about." : nil
    }

    // MARK: US units (oz, lb, in)
    static func volume(_ ml: Int) -> String { String(format: "%.1f oz", Double(ml) / 29.5735).replacingOccurrences(of: ".0 oz", with: " oz") }
    static func weight(_ g: Int) -> String { let oz = Int((Double(g) / 453.59237 * 16).rounded()); return "\(oz / 16) lb \(oz % 16) oz" }
    static func length(_ mm: Int) -> String { String(format: "%.1f in", Double(mm) / 25.4) }
    static func minutes(_ s: TimeInterval) -> String { let m = Int(s / 60); return m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min" }
    static func clock(_ s: TimeInterval) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }

    static func describe(_ e: Entry) -> String {
        switch e.kind {
        case .br:
            let parts = [e.leftSec > 0 ? "L \(e.leftSec / 60) min" : nil, e.rightSec > 0 ? "R \(e.rightSec / 60) min" : nil].compactMap { $0 }
            return "Breastfeed \(minutes(Double(e.leftSec + e.rightSec)))" + (parts.isEmpty ? "" : " (\(parts.joined(separator: ", ")))")
        case .bo: return "Bottle \(volume(e.ml))" + (e.formula.map { $0 ? " formula" : " breast milk" } ?? "")
        case .so: return "Solids" + (e.note.isEmpty ? "" : ": \(e.note)")
        case .pu: return "Pumped \(volume(e.ml + e.ml2))"
        case .sl: return e.end != nil ? "Slept \(minutes(e.duration))" : "Fell asleep"
        case .di: return "Diaper: \(e.diaper?.label.lowercased() ?? "changed")"
        case .gr:
            return "Measured: " + [e.weightG > 0 ? "weight \(weight(e.weightG))" : nil, e.lengthMm > 0 ? "length \(length(e.lengthMm))" : nil,
                                   e.headMm > 0 ? "head \(length(e.headMm))" : nil].compactMap { $0 }.joined(separator: ", ")
        }
    }
    static func growthLines(_ g: Entry, _ baby: Baby) -> [String] {
        let age = ageDays(baby.birth) - (Calendar.current.dateComponents([.day], from: g.start, to: Date()).day ?? 0)
        func p(_ m: Measure, _ v: Double) -> String { percentile(m, baby.sex, age, v).map { ", " + percentileLabel($0) } ?? "" }
        return [g.weightG > 0 ? "Weight \(weight(g.weightG))" + p(.WEIGHT, Double(g.weightG) / 1000) : nil,
                g.lengthMm > 0 ? "Length \(length(g.lengthMm))" + p(.LENGTH, Double(g.lengthMm) / 10) : nil,
                g.headMm > 0 ? "Head \(length(g.headMm))" + p(.HEAD, Double(g.headMm) / 10) : nil].compactMap { $0 }
    }
    static func report(_ entries: [Entry], _ baby: Baby, hours: Int = 24) -> String {
        let now = Date(), from = now.addingTimeInterval(Double(-hours) * 3600)
        let s = summary(entries, baby.id, from: from, to: now)
        var out = "\(baby.name.isEmpty ? "Baby" : baby.name): last \(hours) hours (\(ageLabel(baby.birth)))\n\n"
        out += "• Feeds: \(s.feeds)" + (s.breastFeeds > 0 ? " (\(s.breastFeeds) breast, \(s.breastMinutes) min)" : "") + (s.bottles > 0 ? ", \(s.bottles) bottle\(s.bottles == 1 ? "" : "s") \(volume(s.bottleMl))" : "") + "\n"
        out += "• Sleep: \(minutes(Double(s.sleepMinutes * 60)))\n• Diapers: \(s.wet) wet, \(s.dirty) dirty\n"
        if s.pumpedMl > 0 { out += "• Pumped: \(volume(s.pumpedMl))\n" }
        if let n = nextSide(entries, baby.id) { out += "• Next breastfeed: start on the \(n.label.lowercased())\n" }
        if let g = entries.filter({ $0.babyId == baby.id && $0.kind == .gr }).max(by: { $0.start < $1.start }) {
            out += "\nLatest measurements\n" + growthLines(g, baby).map { "• " + $0 }.joined(separator: "\n") + "\n"
        }
        let recent = entries.filter { $0.babyId == baby.id && $0.start >= from }.sorted { $0.start < $1.start }
        if !recent.isEmpty {
            out += "\nLog\n" + recent.map { $0.start.formatted(date: .omitted, time: .shortened) + "  " + describe($0) }.joined(separator: "\n") + "\n"
        }
        return out + "\nLogged in the HolySteps app. Not medical advice."
    }
}

/// The baby log on this phone, in a protected file.
@MainActor
final class BabyStore: ObservableObject {
    static let shared = BabyStore()
    struct Saved: Codable { var babies: [BabyLog.Baby] = []; var entries: [BabyLog.Entry] = []; var timer: BabyLog.Timer?; var current: String? }
    @Published var data = Saved() {
        didSet {
            save()
            // A shared baby's changes go to the other phones (not the ones that just came from them).
            if !applyingRemote { BabyShare.shared.record(before: oldValue, after: data) }
        }
    }
    private var applyingRemote = false
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("baby.json")

    private init() {
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: d) { data = s }
    }

    /// Changes read from the family log, applied without being sent back.
    func applyRemote(_ d: Saved) { applyingRemote = true; data = d; applyingRemote = false }

    /// Ids made by older iPhone versions (UUIDs) become Android's shape before a baby is shared.
    func makeIdsCompatible() {
        guard data.babies.contains(where: { !BabyLog.validId($0.id) }) || data.entries.contains(where: { !BabyLog.validId($0.id) || !BabyLog.validId($0.babyId) }) else { return }
        var map: [String: String] = [:]
        func fix(_ id: String) -> String {
            if BabyLog.validId(id) { return id }
            if let m = map[id] { return m }
            let n = BabyLog.newId(); map[id] = n; return n
        }
        var d = data
        d.babies = d.babies.map { var b = $0; b.id = fix(b.id); return b }
        d.entries = d.entries.map { var e = $0; e.id = fix(e.id); e.babyId = fix(e.babyId); return e }
        if var t = d.timer { t.babyId = fix(t.babyId); d.timer = t }
        d.current = d.current.map(fix)
        applyRemote(d)
    }
    private func save() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: url, options: [.atomic, .completeFileProtection]) }
    }
    var baby: BabyLog.Baby? { data.babies.first { $0.id == data.current } ?? data.babies.first }
    func add(_ e: BabyLog.Entry) { data.entries.append(e); data.entries = Array(data.entries.suffix(5000)); ActivityLog.shared.add(.tracker) }
    /// Clears this phone only: a shared baby just stops syncing here, and the other phones keep their log.
    func erase() {
        let ids = data.babies.map(\.id)
        applyRemote(Saved())
        Task { for id in ids { _ = await BabyShare.shared.leave(id, forEveryone: false) } }
    }
}

struct BabyView: View {
    @ObservedObject private var store = BabyStore.shared
    @State private var sheet: Sheet?
    @State private var now = Date()
    @State private var confirmDelete = false
    @State private var sharing = InviteInbox.waiting("baby")
    @ObservedObject private var family = BabyShare.shared
    private let tick = Foundation.Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let syncTick = Foundation.Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let sky = Color(hex: 0x38BDF8)

    enum Sheet: String, Identifiable { case addBaby, bottle, diaper, growth, solids, pump; var id: String { rawValue } }

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("🍼 BABY LOG").font(.hs(12, .bold)).foregroundStyle(HS.readable(0x38BDF8))
                    if let baby = store.baby { content(baby) } else { empty }
                    T(family.shares.isEmpty ? "🔒 Your baby's log stays on this phone. It's a log, not medical advice; call your baby's doctor with any worry."
                      : "🔒 A shared baby is encrypted on this phone before it's sent, so only phones with the invite code can read it. It's a log, not medical advice; call your baby's doctor with any worry.")
                        .font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .padding(20).padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(tick) { now = $0 }
        .onReceive(syncTick) { _ in if !family.shares.isEmpty { Task { await family.sync() } } }
        .task { if !family.shares.isEmpty { await family.sync() } }
        .sheet(item: $sheet) { s in BabySheet(kind: s) }
        .sheet(isPresented: $sharing) { BabyShareSheet(baby: store.baby) }
        .alert(tr("Delete the baby log?"), isPresented: $confirmDelete) {
            Button(tr("Delete"), role: .destructive) { store.erase() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("This removes every baby and entry saved on this phone. It can't be undone.") }
    }

    private var empty: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                T("Feeds, sleep, diapers and growth in a few taps").font(.hs(18, .semibold)).foregroundStyle(HS.text)
                T("A side timer for breastfeeds, bottle amounts, sleep windows for your baby's age, and growth against the WHO charts your pediatrician uses.")
                    .font(.hs(13)).foregroundStyle(HS.textSecondary)
                GoldButton(title: "Add your baby") { sheet = .addBaby }
                Button { sharing = true } label: {
                    T("Joining someone else's baby? Enter their code").font(.hs(13, .semibold)).foregroundStyle(HS.readable(0x38BDF8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func content(_ baby: BabyLog.Baby) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                D(baby.name.isEmpty ? tr("Baby") : baby.name).font(.hs(24, .bold)).foregroundStyle(HS.text)
                T(BabyLog.ageLabel(baby.birth)).font(.hs(13)).foregroundStyle(HS.textMuted)
            }
            Spacer()
            Menu {
                ForEach(store.data.babies) { b in Button(b.name.isEmpty ? tr("Baby") : b.name) { store.data.current = b.id } }
                if store.data.babies.count < 6 { Button(tr("Add a baby")) { sheet = .addBaby } }
            } label: { Image(systemName: "person.2.circle").font(.system(size: 26)).foregroundStyle(HS.gold) }
            .accessibilityLabel(tr("Switch baby"))
            Button { sharing = true } label: {
                Image(systemName: family.share(of: baby.id) != nil ? "person.2.wave.2.fill" : "square.and.arrow.up")
                    .font(.system(size: 22)).foregroundStyle(HS.readable(0x38BDF8)).frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr("Share with your partner or sitter"))
        }
        if let t = store.data.timer, t.babyId == baby.id { timerCard(t) }
        else {
            let next = BabyLog.nextSide(store.data.entries, baby.id)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                quick("heart", next.map { tr("Breastfeed") + " · " + tr($0.label) } ?? tr("Breastfeed")) {
                    let s = next ?? .L
                    store.data.timer = BabyLog.Timer(babyId: baby.id, kind: .br, start: Date(), side: s, sideSince: Date(), firstSide: s)
                }
                quick("waterbottle", tr("Bottle")) { sheet = .bottle }
                quick("moon.zzz", tr("Sleep")) { store.data.timer = BabyLog.Timer(babyId: baby.id, kind: .sl, start: Date()) }
                quick("drop", tr("Diaper")) { sheet = .diaper }
                quick("fork.knife", tr("Solids")) { sheet = .solids }
                quick("ruler", tr("Growth")) { sheet = .growth }
            }
        }
        let day = Calendar.current.startOfDay(for: now)
        let s = BabyLog.summary(store.data.entries, baby.id, from: day, to: day.addingTimeInterval(86400))
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                T("Today").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                D(tr("Feeds \(s.feeds)") + (s.bottles > 0 ? " · " + BabyLog.volume(s.bottleMl) : "") + (s.breastMinutes > 0 ? " · " + tr("\(s.breastMinutes) min breast") : ""))
                    .font(.hs(13)).foregroundStyle(HS.textSecondary)
                D(tr("Sleep") + " " + BabyLog.minutes(Double(s.sleepMinutes * 60)) + " · " + tr("Diapers \(s.wet) wet, \(s.dirty) dirty")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                if let f = s.lastFeed { D(tr("Last feed") + " " + f.formatted(date: .omitted, time: .shortened)).font(.hs(12)).foregroundStyle(HS.textMuted) }
            }
        }
        let g = BabyLog.sleepGuide(BabyLog.ageDays(baby.birth))
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                T("😴 Sleep for this age").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                D(tr("About \(g.minH) to \(g.maxH) hours in 24 · \(g.naps)")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                if let w = s.lastWake ?? BabyLog.summary(store.data.entries, baby.id, from: .distantPast, to: now).lastWake {
                    let a = w.addingTimeInterval(Double(g.minWake * 60)), b = w.addingTimeInterval(Double(g.maxWake * 60))
                    D(tr("Next sleep likely goes well between") + " " + a.formatted(date: .omitted, time: .shortened) + " – " + b.formatted(date: .omitted, time: .shortened))
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                }
            }
        }
        ForEach(BabyLog.flags(store.data.entries, baby), id: \.self) { f in
            T(f).font(.hs(13)).foregroundStyle(HS.text).padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF59E0B).opacity(0.14)))
        }
        if let gr = store.data.entries.filter({ $0.babyId == baby.id && $0.kind == .gr }).max(by: { $0.start < $1.start }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    T("📏 Latest measurements").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    ForEach(BabyLog.growthLines(gr, baby), id: \.self) { T($0).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    if baby.sex == .UNSET { T("Set your baby's sex to compare with the WHO growth charts.").font(.hs(12)).foregroundStyle(HS.textMuted) }
                    if gr.weightG > 0, let p = BabyLog.percentile(.WEIGHT, baby.sex, BabyLog.ageDays(baby.birth), Double(gr.weightG) / 1000), let note = BabyLog.growthNote(p) {
                        T(note).font(.hs(12)).foregroundStyle(HS.peach)
                    }
                }
            }
        }
        let recent = store.data.entries.filter { $0.babyId == baby.id }.sorted { $0.start > $1.start }.prefix(20)
        if !recent.isEmpty {
            SectionHeader(title: "Recent").padding(.horizontal, -20)
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recent)) { e in
                        HStack {
                            D(e.kind.emoji)
                            VStack(alignment: .leading, spacing: 1) {
                                D(tr(BabyLog.describe(e))).font(.hs(13)).foregroundStyle(HS.text)
                                D(e.start.formatted(.dateTime.weekday(.abbreviated).hour().minute().locale(I18n.shared.locale))).font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            Button { store.data.entries.removeAll { $0.id == e.id } } label: { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(HS.textMuted).frame(width: 32, height: 32) }
                                .accessibilityLabel(tr("Remove"))
                        }
                    }
                }
            }
        }
        ShareLink(item: BabyLog.report(store.data.entries, baby)) {
            T("Share the last 24 hours").font(.hs(14, .semibold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity).padding(.vertical, 13).background(Capsule().fill(HS.goldButton))
        }
        Button { confirmDelete = true } label: { T("Delete the baby log").font(.hs(12)).foregroundStyle(HS.textMuted) }
    }

    private func timerCard(_ t: BabyLog.Timer) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                T(t.kind == .br ? "Breastfeeding" : "Sleeping").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                D(BabyLog.clock(t.elapsed(now))).font(.system(size: 44, weight: .heavy).monospacedDigit()).foregroundStyle(HS.text)
                if t.kind == .br {
                    HStack(spacing: 10) {
                        ForEach([BabyLog.Side.L, .R], id: \.self) { side in
                            let on = t.side == side
                            Button {
                                var n = t; let d = Date()
                                if on { n.leftS = t.left(d); n.rightS = t.right(d); n.side = nil }
                                else { n.leftS = t.left(d); n.rightS = t.right(d); n.side = side; n.sideSince = d; n.firstSide = t.firstSide ?? side }
                                store.data.timer = n
                            } label: {
                                VStack(spacing: 2) {
                                    T(side.label).font(.hs(14, .semibold))
                                    D(BabyLog.clock(side == .L ? t.left(now) : t.right(now))).font(.hs(13).monospacedDigit())
                                    T(on ? "Pause" : "Start").font(.hs(11))
                                }
                                .foregroundStyle(on ? .white : HS.text).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(on ? sky : HS.overlay(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button { store.data.timer = nil } label: { T("Discard").font(.hs(13)).foregroundStyle(HS.textMuted).padding(10) }
                    GoldButton(title: "Done") {
                        if let e = BabyLog.finish(t) { store.add(e) }
                        store.data.timer = nil
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func quick(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) { Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(sky); D(label).font(.hs(12, .semibold)).foregroundStyle(HS.text).multilineTextAlignment(.center).lineLimit(2) }
                .frame(maxWidth: .infinity, minHeight: 74).background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(sky.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}

/// The small forms: a new baby, a bottle, a diaper, solids, pumping and growth.
private struct BabySheet: View {
    let kind: BabyView.Sheet
    @ObservedObject private var store = BabyStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var birth = Date()
    @State private var sex = BabyLog.Sex.UNSET
    @State private var oz = 3.0
    @State private var formula = false
    @State private var diaper = BabyLog.Diaper.w
    @State private var note = ""
    @State private var lb = 0
    @State private var ozW = 0
    @State private var lengthIn = 0.0
    @State private var headIn = 0.0
    @State private var when = Date()

    var body: some View {
        NavigationStack {
            Form {
                switch kind {
                case .addBaby:
                    TextField(tr("Name"), text: $name)
                    DatePicker(tr("Born"), selection: $birth, in: ...Date().addingTimeInterval(270 * 86400), displayedComponents: .date)
                    Picker(tr("Sex"), selection: $sex) { ForEach(BabyLog.Sex.allCases, id: \.self) { D(tr($0.label)).tag($0) } }
                case .bottle, .pump:
                    Stepper(value: $oz, in: 0.5...12, step: 0.5) { D(String(format: "%.1f oz", oz)) }
                    if kind == .bottle { Toggle(tr("Formula"), isOn: $formula) }
                    DatePicker(tr("Time"), selection: $when, in: ...Date())
                case .diaper:
                    Picker(tr("Diaper"), selection: $diaper) { ForEach(BabyLog.Diaper.allCases, id: \.self) { D($0.emoji + " " + tr($0.label)).tag($0) } }.pickerStyle(.inline)
                    DatePicker(tr("Time"), selection: $when, in: ...Date())
                case .solids:
                    TextField(tr("What did they eat? (optional)"), text: $note)
                    DatePicker(tr("Time"), selection: $when, in: ...Date())
                case .growth:
                    Section(tr("Weight")) {
                        Stepper(value: $lb, in: 0...40) { D("\(lb) lb") }
                        Stepper(value: $ozW, in: 0...15) { D("\(ozW) oz") }
                    }
                    Section(tr("Length and head (inches)")) {
                        Stepper(value: $lengthIn, in: 0...40, step: 0.25) { D(tr("Length") + String(format: " %.2f in", lengthIn)) }
                        Stepper(value: $headIn, in: 0...22, step: 0.25) { D(tr("Head") + String(format: " %.2f in", headIn)) }
                    }
                }
            }
            .navigationTitle(tr(title)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(tr("Save")) { save(); dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: String {
        switch kind { case .addBaby: "Add your baby"; case .bottle: "Bottle"; case .pump: "Pumping"; case .diaper: "Diaper"; case .solids: "Solids"; case .growth: "Growth" }
    }

    private func save() {
        if kind == .addBaby {
            let b = BabyLog.Baby(name: String(name.prefix(30)), birth: AppStore.dayKey(birth), sex: sex)
            store.data.babies.append(b); store.data.current = b.id; return
        }
        guard let baby = store.baby else { return }
        var e = BabyLog.Entry(babyId: baby.id, kind: .bo, start: when)
        switch kind {
        case .bottle: e.ml = Int((oz * 29.5735).rounded()); e.formula = formula
        case .pump: e.kind = .pu; e.ml = Int((oz * 29.5735).rounded())
        case .diaper: e.kind = .di; e.diaper = diaper
        case .solids: e.kind = .so; e.note = String(note.prefix(200))
        case .growth:
            e.kind = .gr; e.start = Date()
            e.weightG = Int(((Double(lb) * 16 + Double(ozW)) / 16 * 453.59237).rounded())
            e.lengthMm = Int((lengthIn * 25.4).rounded()); e.headMm = Int((headIn * 25.4).rounded())
            if e.weightG == 0 && e.lengthMm == 0 && e.headMm == 0 { return }
        case .addBaby: return
        }
        store.add(e)
    }
}
