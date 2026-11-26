import SwiftUI

/// Home card for the season walk in view (Advent, New Year, Stress to Peace, Lent, Easter). Port of Android's SeasonHomeCard.
struct SeasonHomeCard: View {
    let onOpen: (SeasonWalk) -> Void
    init(onOpen: @escaping (SeasonWalk) -> Void) { self.onOpen = onOpen }
    @ObservedObject private var steps = StepsModel.shared
    @ObservedObject private var seen = SeasonSteps.shared

    var body: some View {
        let today = AppStore.dayKey()
        if let walk = SeasonWalks.current(today) {
            let p = SeasonWalks.progress(walk, history: seen.history, todaySteps: steps.today, today: today)
            Button { onOpen(walk) } label: {
                GlassCard(glow: HS.faith, warm: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        D(walk.emoji + " " + tr(walk.season).uppercased()).font(.hs(12, .bold)).foregroundStyle(HS.gold)
                        D(tr(walk.title)).font(.hs(18, .bold)).foregroundStyle(HS.text)
                        if !p.started {
                            let n = -p.dayNumber + 1
                            D(tr(walk.pitch)).font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                            D(tr("Starts \(SeasonDates.longDay(walk.start))") + " · " + tr("in \(n) days")).font(.hs(12, .semibold)).foregroundStyle(HS.textSecondary)
                        } else if p.ended {
                            D(p.arrived ? tr(walk.celebrate) : tr("The walk has ended. You covered \(Int(p.km)) of \(Int(walk.routeKm)) km.")).font(.hs(13)).foregroundStyle(HS.textMuted)
                        } else {
                            D(tr("Day \(p.dayNumber) of \(walk.dayCount)") + " · " + tr("near \(p.near.name)")).font(.hs(13)).foregroundStyle(HS.textMuted)
                            HSProgressBar(progress: p.fraction)
                            D(String(format: "%.1f / %.0f km", min(p.km, walk.routeKm), walk.routeKm)).font(.hs(12, .semibold)).foregroundStyle(HS.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .onAppear { seen.absorb(steps.stepsByDay, today: steps.today) }
            .onChange(of: steps.today) { seen.absorb(steps.stepsByDay, today: steps.today) }
        }
    }
}

struct SeasonWalkView: View {
    let walk: SeasonWalk
    @ObservedObject private var steps = StepsModel.shared
    @ObservedObject private var seen = SeasonSteps.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var selected = 0
    @State private var paywall = false
    @State private var prayed: Set<Int>
    @Environment(\.openURL) private var openURL

    init(walk: SeasonWalk) {
        self.walk = walk
        let saved = UserDefaults.standard.array(forKey: "seasonPrayed_" + walk.id) as? [Int] ?? []
        _prayed = State(initialValue: Set(saved))
    }

    private var today: String { AppStore.dayKey() }
    private var progress: SeasonProgress { SeasonWalks.progress(walk, history: seen.history, todaySteps: steps.today, today: today) }
    private func locked(_ day: Int) -> Bool { walk.freeDays > 0 && day > walk.freeDays && !account.canUse(.devotionalPlans) }

    var body: some View {
        let p = progress
        let current = min(max(p.dayNumber, 1), walk.dayCount)
        let day = selected == 0 ? current : selected
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    D(walk.emoji + " " + tr(walk.title)).font(.hs(26)).foregroundStyle(HS.text)
                    D(tr(walk.fromTo)).font(.hs(14)).foregroundStyle(HS.textMuted)
                    road(p)
                    dayPicker(current: current, shown: day)
                    reading(day: day, current: p.dayNumber)
                }
                .padding(20).padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $paywall) { PlansView(feature: .devotionalPlans) }
        .onAppear { seen.absorb(steps.stepsByDay, today: steps.today) }
        .task { await steps.refresh(); seen.absorb(steps.stepsByDay, today: steps.today) }
    }

    private func road(_ p: SeasonProgress) -> some View {
        GlassCard(glow: HS.faith) {
            VStack(alignment: .leading, spacing: 10) {
                if !p.started {
                    D(tr("Starts \(SeasonDates.longDay(walk.start))")).font(.hs(15, .bold)).foregroundStyle(HS.text)
                    D(tr(walk.pitch)).font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                } else {
                    D(String(format: "%.1f km of %.0f", min(p.km, walk.routeKm), walk.routeKm)).font(.hs(20, .bold)).foregroundStyle(HS.text)
                    HSProgressBar(progress: p.fraction)
                    if p.arrived {
                        D(tr(walk.celebrate)).font(.hs(14, .semibold)).foregroundStyle(HS.gold)
                    } else {
                        D(tr("Near \(p.near.name)") + (p.next.map { " · " + tr("next: \($0.name), \(Int($0.atKm - min(p.km, walk.routeKm))) km away") } ?? ""))
                            .font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                    }
                    if !p.ended {
                        let ahead = p.aheadKm
                        D(ahead >= 0 ? tr("You are \(String(format: "%.1f", ahead)) km ahead of the daily pace.")
                                     : tr("To stay on pace, walk about \(SeasonWalks.stepsFor(km: -ahead + walk.dailyKm).formatted()) steps today."))
                            .font(.hs(12)).foregroundStyle(HS.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                D(tr("Counted from the steps you already take. Nothing extra to turn on.")).font(.hs(11)).foregroundStyle(HS.textSubtle)
            }
        }
    }

    private func dayPicker(current: Int, shown: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...walk.dayCount, id: \.self) { n in
                        let open = progress.dayNumber >= n
                        Button { selected = n } label: {
                            D(prayed.contains(n) ? "✓" : (locked(n) ? "🔒" : "\(n)"))
                                .font(.hs(14, .bold))
                                .foregroundStyle(n == shown ? HS.onGold : (open ? HS.text : HS.textSubtle))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(n == shown ? HS.goldButton : HS.overlay(open ? 0.14 : 0.06)))
                        }
                        .id(n)
                    }
                }
            }
            .onAppear { proxy.scrollTo(current, anchor: .center) }
        }
    }

    @ViewBuilder private func reading(day n: Int, current: Int) -> some View {
        let d = walk.days[n - 1]
        if current < n {
            GlassCard {
                D(tr("Day \(n) opens \(SeasonDates.longDay(walk.dateOf(n))).")).font(.hs(14)).foregroundStyle(HS.textMuted)
            }
        } else if locked(n) {
            GlassCard(glow: HS.faith) {
                VStack(alignment: .leading, spacing: 10) {
                    D(tr("Day \(n): \(d.title)")).font(.hs(17, .bold)).foregroundStyle(HS.text)
                    D(tr("Days 1 to \(walk.freeDays) are free. The rest of the readings and prayers come with the Faith plan. Your walk and your steps count either way.")).font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                    GoldButton(title: "See the Faith plan") { paywall = true }
                }
            }
        } else {
            GlassCard(glow: HS.faith, warm: true) {
                VStack(alignment: .leading, spacing: 12) {
                    D(tr("Day \(n) of \(walk.dayCount)")).font(.hs(12, .bold)).foregroundStyle(HS.gold)
                    D(tr(d.title)).font(.hs(20, .bold)).foregroundStyle(HS.text)
                    VStack(alignment: .leading, spacing: 4) {
                        D(d.verse).font(.hs(15)).italic().foregroundStyle(HS.text).fixedSize(horizontal: false, vertical: true)
                        D("— " + d.reference + " (KJV)").font(.hs(12, .semibold)).foregroundStyle(HS.textMuted)
                    }
                    D(tr(d.reflection)).font(.hs(14)).foregroundStyle(HS.textSecondary).fixedSize(horizontal: false, vertical: true)
                    section("🙏 Pray", d.prayer)
                    section("🚶 Walk and pray", d.walk)
                    GoldButton(title: prayed.contains(n) ? "✓ I prayed today" : "I prayed today") { togglePrayed(n) }
                }
            }
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            T(title).font(.hs(12, .bold)).foregroundStyle(HS.gold)
            D(tr(text)).font(.hs(14)).foregroundStyle(HS.text).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func togglePrayed(_ n: Int) {
        if prayed.contains(n) { prayed.remove(n) } else { prayed.insert(n) }
        UserDefaults.standard.set(Array(prayed), forKey: "seasonPrayed_" + walk.id)
    }
}
