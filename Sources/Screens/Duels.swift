import SwiftUI

/// Android's Scripture Duels (DuelsScreen.kt and the AppViewModel duel functions), on the same Firestore documents and
/// with the same matchmaking, so an iPhone and an Android phone can duel. Two searchers each name the other in the
/// queue, both tap Start, and the one with the lower uid creates the duel. Three rounds: fill in the three missing words
/// of a verse; each correct word is a point and the faster answer gets one more. Rating is Elo (K 24), kept on this phone.
@MainActor
final class DuelModel: ObservableObject {
    enum Phase { case idle, searching, paired, playing, done }
    @Published var phase = Phase.idle
    @Published var opponent = "", opponentRating = 0, opponentReady = false, iAmReady = false
    @Published var notice = ""
    @Published var duelId = ""
    @Published var duel: FSDoc?
    @Published var rounds: [FSDoc] = []
    @Published var ratingDelta: Int?
    @AppStorage("duelRating") var rating = 1000
    private var pairedUid = "", ready = false, skipUntil: [String: Int64] = [:], loop: Task<Void, Never>?, settled = Set<String>()
    var uid: String? { AccountStore.shared.uid }
    static let fresh: Int64 = 20_000, stale: Int64 = 15 * 60_000, roundsN = 3, blanks = 3

    private func queueDoc(_ name: String, duel: String = "", matched: String = "") -> [String: FSValue] {
        ["uid": .string(uid ?? ""), "displayName": .string(String(name.prefix(100))), "rating": .int(Int64(rating)), "queuedAt": .int(Firestore.nowMs),
         "duelId": .string(duel), "matchedUid": .string(matched), "pairedUid": .string(pairedUid), "ready": .bool(ready)]
    }

    func search(name: String) {
        guard let uid, phase == .idle || phase == .done else { return }
        reset(); phase = .searching
        loop = Task {
            var proposedAt: Int64 = 0, pairedSince: Int64 = 0
            while !Task.isCancelled, phase == .searching || phase == .paired {
                let now = Firestore.nowMs
                let q = ((try? await Firestore.query("duelQueue", filters: [.init(field: "queuedAt", op: "GREATER_THAN", value: .int(now - Self.fresh))], orderBy: nil, limit: 50)) ?? [])
                    .filter { $0["uid"].string != uid && !$0["uid"].string.isEmpty && now - $0["queuedAt"].int < Self.fresh }
                if ready, let inv = q.first(where: { $0["matchedUid"].string == uid && !$0["duelId"].string.isEmpty && $0["uid"].string == pairedUid }),
                   let d = try? await Firestore.get("duels/\(inv["duelId"].string)"), d["status"].string == "ACTIVE" {
                    try? await Firestore.commit([.delete("duelQueue/\(uid)")])
                    duelId = d.id; duel = d; phase = .playing; await watch(); return
                }
                var partner = q.first { $0["uid"].string == pairedUid }
                if !pairedUid.isEmpty {
                    let mutual = partner?["pairedUid"].string == uid
                    let gone = partner == nil || (!(partner?["pairedUid"].string ?? "").isEmpty && partner?["pairedUid"].string != uid)
                    let skipped = (skipUntil[pairedUid] ?? 0) > now
                    if gone || (!mutual && now - proposedAt > 9_000) || (mutual && pairedSince > 0 && now - pairedSince > 90_000) || skipped {
                        if phase == .paired && !skipped { notice = tr("\(opponent.isEmpty ? tr("Your opponent") : opponent) left. Looking for someone else…") }
                        skipUntil[pairedUid] = now + (skipped ? 60_000 : 15_000); pairedUid = ""; ready = false; partner = nil; pairedSince = 0
                    }
                }
                if pairedUid.isEmpty {
                    let free = q.filter { $0["duelId"].string.isEmpty && (skipUntil[$0["uid"].string] ?? 0) <= now }
                    let pick = free.filter { $0["pairedUid"].string == uid }.min { $0["uid"].string < $1["uid"].string }
                        ?? free.filter { $0["pairedUid"].string.isEmpty && uid < $0["uid"].string }
                            .min { abs(Int($0["rating"].int) - rating) < abs(Int($1["rating"].int) - rating) }
                    if let pick { pairedUid = pick["uid"].string; proposedAt = now; partner = pick }
                }
                let mutual = partner?["pairedUid"].string == uid
                if mutual && pairedSince == 0 { pairedSince = now }
                if !mutual { ready = false }
                phase = mutual ? .paired : .searching
                opponent = mutual ? partner?["displayName"].string ?? "" : ""
                opponentRating = mutual ? Int(partner?["rating"].int ?? 0) : 0
                opponentReady = mutual && partner?["ready"].bool == true
                iAmReady = mutual && ready
                if mutual { notice = "" }
                if let p = partner, mutual, ready, p["ready"].bool, uid < p["uid"].string {
                    let id = Firestore.newId(), opp = p["uid"].string
                    var writes: [FSWrite] = [.set("duels/\(id)", [
                        "player1Uid": .string(uid), "player1Name": .string(String(name.prefix(100))), "player2Uid": .string(opp),
                        "player2Name": .string(p["displayName"].string), "status": .string("ACTIVE"), "currentRound": .int(0),
                        "player1Score": .int(0), "player2Score": .int(0), "winnerUid": .string(""), "createdAt": .int(Firestore.nowMs), "endedBy": .string("")], mustNotExist: true)]
                    for (i, r) in Self.buildRounds().enumerated() { writes.append(.set("duels/\(id)/rounds/\(i)", r)) }
                    if (try? await Firestore.commit([writes[0]])) != nil, (try? await Firestore.commit(Array(writes.dropFirst()))) != nil {
                        duelId = id; phase = .playing
                        Task { for _ in 0..<12 { try? await Firestore.commit([.set("duelQueue/\(uid)", queueDoc(name, duel: id, matched: opp))])
                                try? await Task.sleep(nanoseconds: 5_000_000_000); if duelId != id { break } }
                            try? await Firestore.commit([.delete("duelQueue/\(uid)")]) }
                        await watch(); return
                    }
                }
                guard phase == .searching || phase == .paired else { break }
                do { try await Firestore.commit([.set("duelQueue/\(uid)", queueDoc(name))]) }
                catch FSError.denied { notice = tr("Duels are played with someone else, so they need a plan."); phase = .idle; return }
                catch {}
                try? await Task.sleep(nanoseconds: pairedUid.isEmpty ? UInt64(2_500 + Int.random(in: 0...600)) * 1_000_000 : 1_500_000_000)
            }
        }
    }

    func start() { if phase == .paired { ready = true; iAmReady = true } }
    func skip() { if !pairedUid.isEmpty { skipUntil[pairedUid] = Firestore.nowMs + 60_000 }; ready = false; opponent = ""; phase = .searching }
    func cancel() {
        loop?.cancel(); reset(); phase = .idle
        if let uid { Task { try? await Firestore.commit([.delete("duelQueue/\(uid)")]) } }
    }
    private func reset() { pairedUid = ""; ready = false; iAmReady = false; opponentReady = false; opponent = ""; notice = ""; duelId = ""; duel = nil; rounds = []; ratingDelta = nil }

    static func buildRounds() -> [[String: FSValue]] {
        let strip = CharacterSet(charactersIn: ",.;:'\"?!’‘")
        return VerseMemory.all.filter { !$0.premium }.shuffled().prefix(roundsN).map { v in
            let words = v.text.split(separator: " ").map(String.init)
            let ok = words.indices.filter { words[$0].trimmingCharacters(in: strip).count > 3 }
            let idx = (ok.count >= blanks ? ok : Array(words.indices)).shuffled().prefix(blanks).sorted()
            return ["verseId": .string(v.id), "blankedWords": .array(idx.map { .string(words[$0].trimmingCharacters(in: strip)) }),
                    "player1AnswerMs": .int(0), "player1Correct": .int(-1), "player2AnswerMs": .int(0), "player2Correct": .int(-1)]
        }
    }

    /// Follows the duel until it ends, advancing a round once both answers are in (whichever phone sees it first).
    func watch() async {
        while !Task.isCancelled, phase == .playing, !duelId.isEmpty {
            if let d = try? await Firestore.get("duels/\(duelId)") { duel = d }
            rounds = ((try? await Firestore.query("rounds", parent: "duels/\(duelId)", limit: 5)) ?? []).sorted { $0.id < $1.id }
            guard let d = duel else { break }
            if d["status"].string != "ACTIVE" { await settle(d); phase = .done; return }
            let i = Int(d["currentRound"].int)
            if i < rounds.count {
                let r = rounds[i], c1 = r["player1Correct"].int, c2 = r["player2Correct"].int
                if c1 >= 0, c2 >= 0, settled.insert("\(duelId):\(i)").inserted {
                    let t1 = r["player1AnswerMs"].int, t2 = r["player2AnswerMs"].int
                    let s1 = d["player1Score"].int + c1 + (t1 <= t2 ? 1 : 0), s2 = d["player2Score"].int + c2 + (t2 <= t1 ? 1 : 0)
                    var f: [String: FSValue] = ["player1Score": .int(s1), "player2Score": .int(s2), "currentRound": .int(Int64(i + 1))]
                    if i + 1 >= Self.roundsN {
                        f["status"] = .string("COMPLETED")
                        f["winnerUid"] = .string(s1 > s2 ? d["player1Uid"].string : s2 > s1 ? d["player2Uid"].string : "")
                    }
                    if (try? await Firestore.commit([.update("duels/\(duelId)", f)])) == nil, i + 1 < Self.roundsN { settled.remove("\(duelId):\(i)") }
                    continue
                }
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    var isP1: Bool { duel?["player1Uid"].string == uid }
    func answer(_ i: Int, _ given: [String]) async {
        guard i < rounds.count else { return }
        let want = rounds[i]["blankedWords"].array.map(\.string)
        let strip = CharacterSet(charactersIn: ",.;:?!")
        let n = zip(want, given).filter { $0.0.lowercased() == $0.1.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: strip).lowercased() }.count
        let side = isP1 ? "player1" : "player2"
        try? await Firestore.commit([.update("duels/\(duelId)/rounds/\(i)", ["\(side)AnswerMs": .int(Firestore.nowMs), "\(side)Correct": .int(Int64(n))])])
    }

    private func settle(_ d: FSDoc) async {
        guard ratingDelta == nil, d["status"].string == "COMPLETED" else { return }
        let me = isP1 ? d["player1Score"].int : d["player2Score"].int, them = isP1 ? d["player2Score"].int : d["player1Score"].int
        let result = me > them ? 1.0 : me < them ? 0.0 : 0.5
        let opp = Double(opponentRating > 0 ? opponentRating : rating)
        let expected = 1 / (1 + pow(10, (opp - Double(rating)) / 400))
        let delta = Int((24 * (result - expected)).rounded())
        rating = min(3000, max(100, rating + delta)); ratingDelta = delta
    }

    func abandon() {
        guard let uid, !duelId.isEmpty else { cancel(); return }
        let id = duelId
        Task { try? await Firestore.commit([.update("duels/\(id)", ["status": .string("ABANDONED"), "endedBy": .string(uid)])]) }
        cancel()
    }
}

struct DuelsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var m = DuelModel()
    @State private var answers = ["", "", ""]
    @State private var answered: Set<Int> = []

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("⚔️ SCRIPTURE DUELS").font(.hs(12, .bold)).foregroundStyle(HS.readable(0xD9B49F))
                    T("Fill in the missing words").font(.hs(24)).foregroundStyle(HS.text)
                    D(tr("Your rating: \(m.rating)")).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    if !m.notice.isEmpty { D(m.notice).font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    switch m.phase {
                    case .idle:
                        T("Three verses, three missing words each. Every right word is a point, and the faster answer gets one more.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                        GoldButton(title: "Find an opponent") { m.search(name: store.name) }
                    case .searching:
                        HStack { ProgressView(); T("Looking for someone to duel…").font(.hs(14)).foregroundStyle(HS.text) }
                        Button(tr("Cancel")) { m.cancel() }.buttonStyle(.bordered)
                    case .paired:
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                D(tr("Opponent found: \(m.opponent)")).font(.hs(16, .bold)).foregroundStyle(HS.text)
                                D(tr("Rating \(m.opponentRating)")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                if m.iAmReady { T(m.opponentReady ? "Starting…" : "Waiting for them to tap Start…").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                                else { GoldButton(title: "Start duel") { m.start() } }
                                Button(tr("Find someone else")) { m.skip() }.font(.hs(12))
                            }
                        }
                    case .playing: playing
                    case .done: done
                    }
                }.padding(20)
            }
        }
        .onDisappear { if m.phase == .searching || m.phase == .paired { m.cancel() } }
    }

    @ViewBuilder private var playing: some View {
        let i = Int(m.duel?["currentRound"].int ?? 0)
        let me = m.isP1 ? m.duel?["player1Score"].int ?? 0 : m.duel?["player2Score"].int ?? 0
        let them = m.isP1 ? m.duel?["player2Score"].int ?? 0 : m.duel?["player1Score"].int ?? 0
        let opp = m.isP1 ? m.duel?["player2Name"].string ?? "" : m.duel?["player1Name"].string ?? ""
        D(tr("Round \(min(i + 1, 3)) of 3 · You \(me) – \(them) \(opp)")).font(.hs(14, .semibold)).foregroundStyle(HS.text)
        if i < m.rounds.count, let v = VerseMemory.all.first(where: { $0.id == m.rounds[i]["verseId"].string }) {
            let blanks = m.rounds[i]["blankedWords"].array.map(\.string)
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    D(Self.blanked(v.text, blanks)).font(.hs(16)).foregroundStyle(HS.text)
                    D(v.ref).font(.hs(12)).foregroundStyle(HS.textMuted)
                    if answered.contains(i) { T("Answer sent. Waiting for your opponent…").font(.hs(13)).foregroundStyle(HS.textSecondary) }
                    else {
                        ForEach(0..<blanks.count, id: \.self) { k in
                            TextField(tr("Word \(k + 1)"), text: $answers[k]).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        }
                        GoldButton(title: "Send") { let a = answers; answered.insert(i); answers = ["", "", ""]; Task { await m.answer(i, a) } }
                    }
                }
            }
        } else { ProgressView() }
        Button(tr("Leave the duel"), role: .destructive) { m.abandon(); answered = [] }.font(.hs(12))
    }

    @ViewBuilder private var done: some View {
        let d = m.duel
        let st = d?["status"].string ?? ""
        let w = d?["winnerUid"].string ?? ""
        D(st == "ABANDONED" ? tr("The duel ended early.") : w.isEmpty ? tr("It's a tie!") : w == m.uid ? tr("You won! 🎉") : tr("Good duel. They won this one."))
            .font(.hs(22, .bold)).foregroundStyle(HS.text)
        if let r = m.ratingDelta { D(tr("Rating \(r >= 0 ? "+" : "")\(r) → \(m.rating)")).font(.hs(14)).foregroundStyle(HS.textSecondary) }
        GoldButton(title: "Duel again") { answered = []; m.search(name: store.name) }
    }

    /// The verse with each missing word shown as a blank, in order.
    static func blanked(_ text: String, _ blanks: [String]) -> String {
        var left = blanks, out: [String] = []
        let strip = CharacterSet(charactersIn: ",.;:'\"?!’‘")
        for w in text.split(separator: " ").map(String.init) {
            if let f = left.first, w.trimmingCharacters(in: strip) == f { out.append(w.replacingOccurrences(of: f, with: "_____")); left.removeFirst() } else { out.append(w) }
        }
        return out.joined(separator: " ")
    }
}
