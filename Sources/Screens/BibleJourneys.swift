import SwiftUI

/// Android's Bible Journeys (data/AppState.kt BIBLE_JOURNEYS, ui/screens/SignatureScreens.kt JourneysScreen): your real
/// steps carry you along a real biblical route, and each stop unlocks its story. A journey starts from your step count
/// the moment you pick it; switching starts the new one from your current count. Stops passed pay 10 points each and
/// finishing pays 100 (data/StepRewards.kt journeyAward). Story text and references are as on Android; Grace reads
/// each stop, and the stop's chapter opens in the Bible reader.
struct JourneyStop: Hashable { let atKm: Double; let name, story, reference: String }

struct BibleJourney: Identifiable, Hashable {
    let id, title, emoji, subtitle: String
    let distanceKm: Double
    let premium: Bool
    let stops: [JourneyStop]
    /// Average stride ≈ 0.762 m.
    var totalSteps: Int { Int(distanceKm * 1000 / 0.762) }
}

enum BibleJourneys {
    static let stepKm = 0.000762

    static let all: [BibleJourney] = [
        BibleJourney(id: "emmaus", title: "Road to Emmaus", emoji: "🛤️", subtitle: "Walk with the risen Christ · Luke 24", distanceKm: 11, premium: false, stops: [
            JourneyStop(atKm: 0, name: "Jerusalem", story: "Two disciples leave the city, hearts heavy after the crucifixion.", reference: "Luke 24:13"),
            JourneyStop(atKm: 3, name: "A Stranger Joins", story: "Jesus draws near and walks with them, though they do not recognize Him.", reference: "Luke 24:15-16"),
            JourneyStop(atKm: 6, name: "Scripture Opened", story: "Beginning with Moses, He explains everything written about Himself.", reference: "Luke 24:27"),
            JourneyStop(atKm: 9, name: "Hearts Burning", story: "\"Were not our hearts burning within us while He talked with us?\"", reference: "Luke 24:32"),
            JourneyStop(atKm: 11, name: "Emmaus", story: "He breaks the bread — and their eyes are opened. He is risen!", reference: "Luke 24:30-31"),
        ]),
        BibleJourney(id: "nazareth_bethlehem", title: "Nazareth to Bethlehem", emoji: "⭐", subtitle: "Mary & Joseph's journey · Luke 2", distanceKm: 145, premium: false, stops: [
            JourneyStop(atKm: 0, name: "Nazareth", story: "A decree goes out from Caesar. Joseph and a pregnant Mary set out.", reference: "Luke 2:1-5"),
            JourneyStop(atKm: 35, name: "Jezreel Valley", story: "Where Gideon once trusted God with only 300 men.", reference: "Judges 7:7"),
            JourneyStop(atKm: 75, name: "Jordan Valley", story: "The river where Jesus would one day be baptized.", reference: "Matthew 3:16"),
            JourneyStop(atKm: 120, name: "Jerusalem", story: "The holy city, just a few miles from the promised birthplace.", reference: "Micah 5:2"),
            JourneyStop(atKm: 145, name: "Bethlehem", story: "No room at the inn — and the Savior is born in a manger.", reference: "Luke 2:7"),
        ]),
        BibleJourney(id: "exodus", title: "The Exodus", emoji: "🌊", subtitle: "Egypt to Mount Sinai · Exodus 12–19", distanceKm: 400, premium: true, stops: [
            JourneyStop(atKm: 0, name: "Rameses, Egypt", story: "Israel leaves Egypt after 430 years — free at last.", reference: "Exodus 12:37"),
            JourneyStop(atKm: 60, name: "The Red Sea", story: "The waters part. Israel walks through on dry ground.", reference: "Exodus 14:21-22"),
            JourneyStop(atKm: 130, name: "Marah", story: "Bitter water is made sweet. \"I am the Lord who heals you.\"", reference: "Exodus 15:26"),
            JourneyStop(atKm: 180, name: "Elim", story: "Twelve springs and seventy palm trees — rest after hardship.", reference: "Exodus 15:27"),
            JourneyStop(atKm: 280, name: "Wilderness of Sin", story: "Manna from heaven, new every morning.", reference: "Exodus 16:4"),
            JourneyStop(atKm: 350, name: "Rephidim", story: "Moses' hands are held up and Israel prevails.", reference: "Exodus 17:12"),
            JourneyStop(atKm: 400, name: "Mount Sinai", story: "God meets His people and gives His covenant.", reference: "Exodus 19:20"),
        ]),
        BibleJourney(id: "paul_first", title: "Paul's First Mission", emoji: "⛵", subtitle: "Antioch through Asia Minor · Acts 13–14", distanceKm: 1100, premium: true, stops: [
            JourneyStop(atKm: 0, name: "Antioch", story: "The Spirit says, \"Set apart for me Barnabas and Saul.\"", reference: "Acts 13:2"),
            JourneyStop(atKm: 200, name: "Cyprus", story: "The proconsul believes after Elymas is struck blind.", reference: "Acts 13:12"),
            JourneyStop(atKm: 450, name: "Pisidian Antioch", story: "Paul preaches and the word spreads through the region.", reference: "Acts 13:49"),
            JourneyStop(atKm: 650, name: "Iconium", story: "Signs and wonders done through their hands.", reference: "Acts 14:3"),
            JourneyStop(atKm: 800, name: "Lystra", story: "Paul is stoned, gets up, and goes back into the city.", reference: "Acts 14:19-20"),
            JourneyStop(atKm: 1100, name: "Back to Antioch", story: "They report all God has done — a door of faith opened.", reference: "Acts 14:27"),
        ]),
    ]

    static func byId(_ id: String) -> BibleJourney { all.first { $0.id == id } ?? all[0] }

    /// The words Grace reads for a stop (Android's stopNarration; her recordings are in the "stories" pack).
    static func narration(_ s: JourneyStop) -> String {
        "\(s.name). \(s.story) \(s.reference.replacingOccurrences(of: "-", with: " to ").replacingOccurrences(of: ":", with: ", verse "))."
    }

    /// "Luke 24:32" → ("Luke", 24) for the reader; nil when the reference isn't one chapter.
    static func chapter(_ reference: String) -> (String, Int)? {
        let r = reference.trimmingCharacters(in: .whitespaces)
        guard let sp = r.lastIndex(of: " ") else { return nil }
        let book = String(r[..<sp]), rest = r[r.index(after: sp)...]
        guard let ch = Int(rest.split(separator: ":").first ?? "") , (1...150).contains(ch) else { return nil }
        return (book == "Psalm" ? "Psalms" : book, ch)
    }
}

@MainActor
final class JourneyStore: ObservableObject {
    static let shared = JourneyStore()
    private let d = UserDefaults.standard
    @Published private(set) var activeId: String
    @Published private(set) var stepsDone = 0
    @Published private(set) var seen: Set<String>
    @Published private(set) var completed: Set<String>
    private var start: Date

    private init() {
        activeId = d.string(forKey: "journeyId") ?? "emmaus"
        seen = Set(d.stringArray(forKey: "journeyStopsSeen") ?? [])
        completed = Set(d.stringArray(forKey: "completedJourneys") ?? [])
        if let t = d.object(forKey: "journeyStart") as? Double { start = Date(timeIntervalSince1970: t) }
        else { start = Date(); d.set(start.timeIntervalSince1970, forKey: "journeyStart") }
    }

    var active: BibleJourney { BibleJourneys.byId(activeId) }
    var km: Double { Double(stepsDone) * BibleJourneys.stepKm }

    /// Recounts the steps since this journey began and pays for any stops newly passed.
    func refresh() async {
        let before = stepsDone
        let now = await StepsModel.shared.stepsSince(start)
        stepsDone = max(0, now)
        let j = active
        guard !completed.contains(j.id), stepsDone > before else { return }
        let beforeKm = Double(before) * BibleJourneys.stepKm, afterKm = km
        let crossed = j.stops.filter { $0.atKm > 0 && $0.atKm > beforeKm && $0.atKm <= afterKm }
        guard !crossed.isEmpty, let last = j.stops.last else { return }
        let finishes = crossed.contains(last)
        // The first count after a restart can land past stops already paid for, so a stop is paid once ever.
        let paidKey = "journeyPaid"
        var paid = Set(d.stringArray(forKey: paidKey) ?? [])
        var points = 0
        for (i, s) in j.stops.enumerated() where crossed.contains(s) && s != last {
            if paid.insert("\(j.id):\(i)").inserted { points += 10 }
        }
        if finishes { completed.insert(j.id); d.set(Array(completed), forKey: "completedJourneys"); points += 100 }
        d.set(Array(paid), forKey: paidKey)
        Points.award(points)
    }

    /// Stops passed but not yet shown, as "journeyId:index" (the starting point never pops up).
    var unseen: [(String, JourneyStop)] {
        active.stops.enumerated().map { ("\(activeId):\($0.offset)", $0.element) }
            .filter { $0.1.atKm > 0 && km >= $0.1.atKm && !seen.contains($0.0) }
    }

    func markSeen(_ keys: [String]) {
        seen.formUnion(keys)
        d.set(Array(seen), forKey: "journeyStopsSeen")
    }

    /// Starts (or restarts) a journey from the current step count. Returns false when it needs the Faith plan.
    func start(_ j: BibleJourney) -> Bool {
        if j.premium && !AccountStore.shared.canUse(.bibleJourneys) { return false }
        activeId = j.id
        start = Date()
        stepsDone = 0
        d.set(j.id, forKey: "journeyId")
        d.set(start.timeIntervalSince1970, forKey: "journeyStart")
        return true
    }
}

struct JourneysView: View {
    @StateObject private var store = JourneyStore.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var paywall = false
    @State private var reached: (String, JourneyStop)?
    @State private var reading: JourneyStop?
    @State private var speaking: String?
    @State private var listenFailed = false
    private var usesKm: Bool { UserDefaults.standard.string(forKey: "distanceUnit") == "km" }

    var body: some View {
        let active = store.active
        let km = store.km
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        T("🛤️ Bible Journeys").font(.hs(13, .bold)).foregroundStyle(HS.body)
                        T("Walk where they walked").font(.hs(24, .bold)).foregroundStyle(HS.text)
                        T("Your real steps carry you along real biblical routes. Every stop unlocks its story.")
                            .font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                    .padding(.horizontal, 20).padding(.top, 58).padding(.bottom, 16)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                D(active.emoji).font(.system(size: 30))
                                VStack(alignment: .leading, spacing: 2) {
                                    T("Now walking").font(.hs(11, .bold)).foregroundStyle(HS.body)
                                    T(active.title).font(.hs(17, .bold)).foregroundStyle(HS.text)
                                    D("\(dist(min(km, active.distanceKm))) " + tr("of") + " \(dist(active.distanceKm)) · \(store.stepsDone.formatted()) " + tr("steps"))
                                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                            }
                            track(active, km)
                            ForEach(Array(active.stops.enumerated()), id: \.offset) { _, stop in
                                stopRow(stop, km)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    SectionHeader(title: "Choose a journey").padding(.top, 12)
                    ForEach(BibleJourneys.all) { j in journeyRow(j, active: j.id == active.id) }

                    T("Switching journeys starts the new one from your current step count.")
                        .font(.hs(11)).foregroundStyle(HS.textSubtle).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 12)
                    Spacer().frame(height: 100)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .task { await store.refresh(); reached = store.unseen.last }
        .sheet(isPresented: $paywall) { PlansView(feature: .bibleJourneys) }
        .onDisappear { GraceVoice.stop() }
        .alert(tr("Grace's recording couldn't be loaded. Check your connection and try again."), isPresented: $listenFailed) { Button(tr("OK")) {} }
        .alert(tr("📍 You reached") + " \(reached?.1.name ?? "")", isPresented: Binding(get: { reached != nil }, set: { if !$0 { reached = nil } })) {
            if let r = reached, BibleJourneys.chapter(r.1.reference) != nil {
                Button(tr("📖 Read the chapter")) { store.markSeen(store.unseen.map(\.0)); reading = r.1; reached = nil }
            }
            Button(tr("Keep walking"), role: .cancel) { store.markSeen(store.unseen.map(\.0)); reached = nil }
        } message: {
            if let r = reached { D(tr(r.1.story) + "\n" + r.1.reference) }
        }
        .navigationDestination(item: $reading) { s in
            let c = BibleJourneys.chapter(s.reference)
            BibleReaderView(startBook: c?.0, startCh: c?.1)
        }
    }

    private func dist(_ km: Double) -> String {
        usesKm ? (km < 10 ? String(format: "%.1f km", km) : "\(Int(km.rounded())) km")
            : { let mi = km * 0.621371; return mi < 10 ? String(format: "%.1f mi", mi) : "\(Int(mi.rounded())) mi" }()
    }

    private func track(_ j: BibleJourney, _ km: Double) -> some View {
        let progress = min(1, max(0, km / j.distanceKm))
        return VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                GeometryReader { g in
                    Capsule().fill(HS.overlay(0.10)).frame(height: 6)
                    Capsule().fill(HS.body).frame(width: g.size.width * progress, height: 6)
                }
                .frame(height: 6)
                HStack {
                    ForEach(Array(j.stops.enumerated()), id: \.offset) { i, s in
                        let on = km >= s.atKm
                        RoundedRectangle(cornerRadius: 7).fill(on ? HS.goldButton : Color(hex: 0x241B30))
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(on ? HS.peach : HS.overlay(0.2), lineWidth: 2))
                            .frame(width: 14, height: 14)
                        if i < j.stops.count - 1 { Spacer(minLength: 0) }
                    }
                }
            }
            .frame(height: 22)
            HStack {
                T(j.stops.first?.name ?? "").font(.hs(10)).foregroundStyle(HS.textMuted)
                Spacer()
                T(j.stops.last?.name ?? "").font(.hs(10)).foregroundStyle(HS.textMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Int(progress * 100))%"))
    }

    private func stopRow(_ s: JourneyStop, _ km: Double) -> some View {
        let on = km >= s.atKm
        return HStack(alignment: .top, spacing: 12) {
            D(on ? "✓" : "🔒").font(.hs(11)).foregroundStyle(.white)
                .frame(width: 26, height: 26).background(Circle().fill(on ? HS.body : HS.overlay(0.06)))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    T(s.name).font(.hs(14, .semibold)).foregroundStyle(on ? HS.text : HS.textMuted)
                    Spacer()
                    D(dist(s.atKm)).font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                if on {
                    T(s.story).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    HStack(spacing: 12) {
                        D(s.reference).font(.hs(11, .semibold)).foregroundStyle(HS.faith)
                        Button { listen(s) } label: {
                            T(speaking == s.name ? "⏹ Stop" : "🔊 Listen").font(.hs(12, .semibold)).foregroundStyle(HS.body)
                        }
                        .buttonStyle(.plain)
                        if BibleJourneys.chapter(s.reference) != nil {
                            Button { reading = s } label: { T("📖 Read the chapter").font(.hs(12, .semibold)).foregroundStyle(HS.body) }
                                .buttonStyle(.plain)
                        }
                    }
                } else {
                    D(tr("Walk") + " \(dist(s.atKm - km)) " + tr("more to unlock")).font(.hs(12)).foregroundStyle(HS.textSubtle)
                }
            }
        }
        .padding(.vertical, 6)
    }

    /// Grace reads the stop; the phone's own voice is never used.
    private func listen(_ s: JourneyStop) {
        if speaking == s.name { GraceVoice.stop(); speaking = nil; return }
        GraceVoice.stop()
        speaking = s.name
        Task {
            let ok = await GraceVoice.say(BibleJourneys.narration(s), pack: "stories")
            if speaking == s.name { speaking = nil }
            if !ok { listenFailed = true }
        }
    }

    private func journeyRow(_ j: BibleJourney, active: Bool) -> some View {
        let done = store.completed.contains(j.id)
        let locked = j.premium && !account.canUse(.bibleJourneys)
        return Button {
            guard !active else { return }
            if store.start(j) { Task { await store.refresh() } } else { paywall = true }
        } label: {
            HStack(spacing: 12) {
                D(j.emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    T(j.title).font(.hs(14, .bold)).foregroundStyle(HS.text)
                    T(j.subtitle).font(.hs(11)).foregroundStyle(HS.textMuted)
                    D("\(dist(j.distanceKm)) · ≈ \(j.totalSteps.formatted()) " + tr("steps") + " · \(j.stops.count) " + tr("stops"))
                        .font(.hs(11)).foregroundStyle(HS.textSubtle)
                }
                Spacer()
                T(active ? "Active" : done ? "✓ Done" : locked ? "👑 Premium" : "Start")
                    .font(.hs(12, .bold)).foregroundStyle(active || done ? HS.body : locked ? HS.gold : HS.faith)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(active ? HS.body.opacity(0.12) : HS.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(active ? HS.body : HS.overlay(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}
