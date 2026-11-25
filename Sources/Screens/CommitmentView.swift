import SwiftUI

/// Android's real-stakes commitment challenges (data/Challenges.kt, ui/screens/ChallengesScreen.kt).
/// User picks a challenge (steps, walks, scripture, prayer) and a duration.
/// Card stakes are optional and paid on holysteps.org; this file handles the on-device tracking.

// MARK: - Model

enum ChallengeKind: String, Codable, CaseIterable {
    case steps, walks, scripture, prayer, sleep
    var title: String {
        switch self {
        case .steps:     return "Step streak"
        case .walks:     return "Daily walks"
        case .scripture: return "Read the Bible"
        case .prayer:    return "Prayer streak"
        case .sleep:     return "Sleep stories"
        }
    }
    var symbol: String {
        switch self {
        case .steps: return "figure.walk"
        case .walks: return "map"
        case .scripture: return "book"
        case .prayer: return "hands.sparkles"
        case .sleep: return "moon.stars"
        }
    }
    var description: String {
        switch self {
        case .steps:     return "Hit your step goal every day"
        case .walks:     return "Log at least one walk a day"
        case .scripture: return "Read your Bible reading plan daily"
        case .prayer:    return "Pray through your prayer list daily"
        case .sleep:     return "Listen to a sleep story each night"
        }
    }
}

struct Commitment: Codable, Identifiable {
    let id: String
    let kind: ChallengeKind
    let days: Int
    let startDay: String
    var daysHit: Set<String>
    var active: Bool

    init(kind: ChallengeKind, days: Int) {
        self.id = UUID().uuidString
        self.kind = kind
        self.days = days
        self.startDay = AppStore.dayKey()
        self.daysHit = []
        self.active = true
    }

    var progress: Int { daysHit.count }
    var streak: Int {
        var s = 0
        let cal = Calendar.current
        var date = Date()
        while true {
            let key = AppStore.dayKey(date)
            if daysHit.contains(key) { s += 1 }
            else { break }
            date = cal.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return s
    }
    var isComplete: Bool { daysHit.count >= days }
}

// MARK: - Store

final class CommitmentStore: ObservableObject {
    static let shared = CommitmentStore()
    private let key = "commitments.v1"
    @Published var commitments: [Commitment] = []

    init() { load() }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let v = try? JSONDecoder().decode([Commitment].self, from: d) else { return }
        commitments = v
    }
    private func save() {
        if let d = try? JSONEncoder().encode(commitments) { UserDefaults.standard.set(d, forKey: key) }
    }

    func add(_ c: Commitment) { commitments.append(c); save() }
    func checkIn(_ id: String) {
        guard let i = commitments.firstIndex(where: { $0.id == id }) else { return }
        commitments[i].daysHit.insert(AppStore.dayKey())
        if commitments[i].isComplete { commitments[i].active = false }
        save()
        ActivityLog.shared.add(.commitmentCheckIn)
    }
    func remove(_ id: String) { commitments.removeAll { $0.id == id }; save() }
}

// MARK: - Views

struct CommitmentsView: View {
    @ObservedObject private var store = CommitmentStore.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var showAdd = false

    var body: some View {
        ZStack { HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                    D(tr("Challenges")).font(.hs(28)).foregroundStyle(HS.text)
                    ItalicAccent(text: "Commit to a streak. Earn points when you finish.", size: 15)
                }
                        .padding(.horizontal, 20).padding(.top, 24)
                    if store.commitments.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.commitments) { c in
                            commitmentCard(c)
                        }
                    }
                    addButton
                    Spacer().frame(height: 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) { AddCommitmentSheet() }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "flag.checkered").font(.system(size: 32)).foregroundStyle(HS.peach)
                T("No active challenges").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                T("Pick a challenge below and commit to it. Finish it to earn 100 points.")
                    .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    @ViewBuilder
    private func commitmentCard(_ c: Commitment) -> some View {
        let pct = Double(c.progress) / Double(c.days)
        let today = AppStore.dayKey()
        let doneToday = c.daysHit.contains(today)
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconBadge(symbol: c.kind.symbol, size: 36, tint: 0xF3D5C0)
                    VStack(alignment: .leading, spacing: 2) {
                        T(c.kind.title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T("\(c.progress)/\(c.days) days").font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    if c.isComplete {
                        T("Done!").font(.hs(13, .semibold)).foregroundStyle(HS.body)
                    } else if !c.active {
                        T("Ended").font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                }
                HSProgressBar(progress: pct)
                HStack {
                    if !c.isComplete && c.active {
                        if doneToday {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(HS.body)
                                T("Done today").font(.hs(13)).foregroundStyle(HS.body)
                            }
                        } else {
                            GoldButton(title: "Check in today") { store.checkIn(c.id) }
                        }
                    }
                    Spacer()
                    Button { store.remove(c.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(HS.textSubtle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10)
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
            GlassCard {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle").font(.system(size: 22)).foregroundStyle(HS.peach)
                    T("New challenge").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20).padding(.top, 14)
    }
}

struct AddCommitmentSheet: View {
    @ObservedObject private var store = CommitmentStore.shared
    @State private var kind = ChallengeKind.steps
    @State private var days = 21
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HSSheet(title: "New challenge") {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    T("What are you committing to?").font(.hs(13, .semibold)).foregroundStyle(HS.textMuted)
                    ForEach(ChallengeKind.allCases, id: \.self) { k in
                        Button { kind = k } label: {
                            HStack(spacing: 12) {
                                IconBadge(symbol: k.symbol, size: 30, tint: kind == k ? 0xF3D5C0 : 0x4A4060)
                                VStack(alignment: .leading, spacing: 2) {
                                    T(k.title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                    T(k.description).font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                                Spacer()
                                if kind == k { Image(systemName: "checkmark").foregroundStyle(HS.peach) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    T("How many days?").font(.hs(13, .semibold)).foregroundStyle(HS.textMuted)
                    HStack(spacing: 8) {
                        ForEach([7, 14, 21, 30, 40], id: \.self) { d in
                            Button { days = d } label: {
                                T("\(d)").font(.hs(14, .semibold))
                                    .foregroundStyle(days == d ? HS.onGold : HS.text)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(Capsule().fill(days == d ? HS.goldButton : HS.overlay(0.07)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                GoldButton(title: "Start \(days)-day challenge") {
                    store.add(Commitment(kind: kind, days: days))
                    dismiss()
                }
            }
            .padding(24)
        }
        .presentationDetents([.large])
    }
}
