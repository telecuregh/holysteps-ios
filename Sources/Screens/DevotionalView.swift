import SwiftUI

/// Devotional reading plans, ported from Android's DevotionalScreen: Women of Strength and Men of Strength (30 days)
/// and Faith Foundations (21 days), extracted to Resources/devotionals.json by tools/devotionals2json.py.
struct DevotionalPlan: Identifiable, Decodable {
    struct Day: Decodable { let day: Int; let title: String; let scripture: String; let reference: String; let body: String; let prayer: String; let challenge: String }
    let id: String
    let title: String
    let subtitle: String
    let emoji: String
    let color: String
    /// "female", "male", or nil for everyone.
    let gender: String?
    let days: [Day]

    static let all: [DevotionalPlan] = {
        guard let url = Bundle.main.url(forResource: "devotionals", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DevotionalPlan].self, from: data)) ?? []
    }()

    /// The plans for this person: their own (women's or men's) and the ones for everyone. Before a gender is set, all.
    static func plans(for gender: String) -> [DevotionalPlan] {
        all.filter { $0.gender == nil || gender.isEmpty || $0.gender == gender }
    }
}

/// Which plan the person reads and how far they are. A day completes once a day; the next opens tomorrow.
@MainActor
final class DevotionalState: ObservableObject {
    static let shared = DevotionalState()
    private let d = UserDefaults.standard

    @Published private(set) var planId: String { didSet { d.set(planId, forKey: "devotionalPlan") } }
    @Published private(set) var day: Int { didSet { d.set(day, forKey: "devotionalDay") } }
    @Published private(set) var lastDate: String { didSet { d.set(lastDate, forKey: "devotionalDate") } }

    private init() {
        planId = d.string(forKey: "devotionalPlan") ?? "women_strength_30"
        day = max(1, d.integer(forKey: "devotionalDay"))
        lastDate = d.string(forKey: "devotionalDate") ?? ""
    }

    var readToday: Bool { lastDate == AppStore.dayKey() }

    func plan(for gender: String) -> DevotionalPlan? {
        DevotionalPlan.all.first { $0.id == planId } ?? DevotionalPlan.plans(for: gender).first
    }

    /// After today's day is done it keeps showing (the next one opens tomorrow) instead of jumping ahead.
    func currentDay(_ plan: DevotionalPlan) -> Int { max(1, min(plan.days.count, readToday ? day - 1 : day)) }

    func completeDay(store: AppStore) {
        let today = AppStore.dayKey()
        guard lastDate != today else { return }
        lastDate = today
        day += 1
    }

    /// Choosing the plan you're already reading keeps your place instead of starting it over.
    func select(_ id: String) {
        guard id != planId else { return }
        planId = id
        day = 1
        lastDate = ""
    }

    func eraseAll() { planId = "women_strength_30"; day = 1; lastDate = "" }
}

struct DevotionalCard: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var state = DevotionalState.shared

    var body: some View {
        if let plan = state.plan(for: store.gender) {
            let n = state.currentDay(plan)
            NavigationLink { DevotionalView() } label: {
                GlassCard {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            T("📖 DAILY DEVOTIONAL").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                            T(plan.days[n - 1].title).font(.hs(19, .semibold)).foregroundStyle(HS.text)
                                .multilineTextAlignment(.leading)
                            D(tr(plan.title) + " · " + tr("Day \(n) of \(plan.days.count)"))
                                .font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                        Spacer()
                        Image(systemName: state.readToday ? "checkmark.circle.fill" : "chevron.right")
                            .font(.hs(state.readToday ? 22 : 16)).foregroundStyle(state.readToday ? HS.body : HS.gold)
                    }
                }
            }
        }
    }
}

struct DevotionalView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var state = DevotionalState.shared
    @State private var choosing = false
    @State private var openedAt = Date()

    var body: some View {
        ZStack {
            HSBackground()
            if let plan = state.plan(for: store.gender) {
                let n = state.currentDay(plan)
                let day = plan.days[n - 1]
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                T("📖 DAILY DEVOTIONAL").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                                T(plan.title).font(.hs(24, .light)).foregroundStyle(HS.text)
                                ItalicAccent(text: "Day \(n) of \(plan.days.count)", size: 17)
                            }
                            Spacer()
                            Button { choosing = true } label: {
                                HStack(spacing: 2) { T("Other devotionals"); Image(systemName: "chevron.right") }
                                    .font(.hs(12)).foregroundStyle(HS.gold)
                            }
                        }
                        ProgressView(value: Double(n), total: Double(plan.days.count)).tint(HS.goldButton)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                T(day.title).font(.hs(20, .semibold)).foregroundStyle(HS.text)
                                D("\"" + tr(day.scripture) + "\"").font(.accent(16)).lineSpacing(10).foregroundStyle(HS.peach)
                                D("— " + tr(day.reference)).font(.hs(13, .medium)).foregroundStyle(HS.textMuted)
                                ShareLink(item: VerseShare.text(tr(day.scripture), tr(day.reference))) {
                                    T("Share ↗").font(.hs(13))
                                }
                                .tint(HS.goldButton)
                            }
                        }
                        section("📝", "Today's Reflection") {
                            T(day.body).font(.hs(15)).foregroundStyle(HS.text.opacity(0.9)).lineSpacing(11)
                        }
                        section("🙏", "Prayer") {
                            T(day.prayer).font(.accent(14)).foregroundStyle(HS.faith.opacity(0.9)).lineSpacing(10)
                        }
                        section("⚡", "Today's Challenge") {
                            T(day.challenge).font(.hs(14)).foregroundStyle(Color(hex: 0xF59E0B)).lineSpacing(10)
                        }
                        Group {
                            if state.readToday {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                    T("Day \(n) done · the next one opens tomorrow").font(.hs(13, .semibold))
                                }
                                .foregroundStyle(HS.body)
                                .frame(maxWidth: .infinity).padding(16)
                                .background(RoundedRectangle(cornerRadius: 14).fill(HS.body.opacity(0.15)))
                            } else {
                                GoldButton(title: tr("Complete day \(n)")) { state.completeDay(store: store) }
                            }
                        }
                        // Reading the day to the bottom (after half a minute with it) completes it.
                        Color.clear.frame(height: 1).task(id: n) { await autoComplete() }
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { openedAt = Date() }
        .sheet(isPresented: $choosing) {
            HSSheet(title: tr("Other devotionals")) {
                List(DevotionalPlan.plans(for: store.gender)) { p in
                    Button { state.select(p.id); choosing = false } label: {
                        HStack(spacing: 12) {
                            D(p.emoji).font(.hs(26))
                            VStack(alignment: .leading, spacing: 2) {
                                T(p.title).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                                T(p.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                            Spacer()
                            if p.id == state.planId { T("Reading").font(.hs(12, .bold)).foregroundStyle(HS.gold) }
                        }
                    }
                    .listRowBackground(HS.card.opacity(0.65))
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    /// Cancelled if the person leaves before the half minute is up.
    private func autoComplete() async {
        guard !state.readToday else { return }
        let left = 30 - Date().timeIntervalSince(openedAt)
        if left > 0 { try? await Task.sleep(nanoseconds: UInt64(left * 1_000_000_000)) }
        if !Task.isCancelled { state.completeDay(store: store) }
    }

    private func section<C: View>(_ icon: String, _ title: String, @ViewBuilder _ content: () -> C) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    D(icon)
                    T(title).font(.hs(12, .semibold)).tracking(0.8).foregroundStyle(HS.textMuted)
                }
                content()
            }
        }
    }
}
