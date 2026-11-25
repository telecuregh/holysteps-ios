import SwiftUI

/// Rewards & Achievements (Android RewardsScreen): points, level, how to earn, and badges tied to real progress.
/// Only badges the iPhone app actually tracks are shown; Android's spend-points shop is left out until Streak
/// Shields exist here.
struct RewardsView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var log = ActivityLog.shared
    @ObservedObject private var commitments = CommitmentStore.shared

    var body: some View {
        let total = Points.total
        let lvl = Points.level
        let next = Points.levels.first { $0.3 > total }
        let prev = lvl.3
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 4) {
                        T("🏆 REWARDS").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                        ItalicAccent(text: "every faithful step counts", size: 20)
                    }
                    .frame(maxWidth: .infinity)
                    GlassCard {
                        VStack(spacing: 8) {
                            T("⭐").font(.system(size: 34))
                            D(total.formatted()).font(.hs(44)).foregroundStyle(HS.text)
                            T("HolySteps Points").font(.hs(14)).foregroundStyle(HS.textSecondary)
                            HStack(spacing: 28) {
                                stat(lvl.2, tr(lvl.1), "Level")
                                stat("🔥", "\(store.prayerStreak)", "Streak")
                                stat("✓", "\(badges.filter(\.2).count)", "Badges")
                            }
                            .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                T(lvl.2).font(.system(size: 32))
                                VStack(alignment: .leading, spacing: 2) {
                                    D(tr("Level \(lvl.0)") + " · " + tr(lvl.1)).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                                    D(next.map { tr("\($0.3 - total) pts to") + " \($0.2) " + tr($0.1) } ?? tr("You've reached the top level 👑"))
                                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                            }
                            ProgressView(value: next.map { Double(total - prev) / Double(max(1, $0.3 - prev)) } ?? 1).tint(HS.goldButton)
                            HStack {
                                ForEach(Points.levels, id: \.0) { l in
                                    T(l.2).font(.system(size: 16)).opacity(total >= l.3 ? 1 : 0.25)
                                    if l.0 < Points.levels.count { Spacer(minLength: 0) }
                                }
                            }
                        }
                    }
                    SectionHeader(title: "Earn points").padding(.horizontal, -20)
                    GlassCard {
                        VStack(spacing: 10) {
                            earn("🚶", "A walk or a workout", 20)
                            earn("🎧", "A guided prayer", 20)
                            earn("📣", "A sermon or a sleep story", 15)
                            earn("🕊️", "A Freedom check-in", 15)
                            earn("📓", "A journal entry or the Bible quiz", 10)
                            earn("🎯", "A challenge check-in", 10)
                            earn("📖", "Today's verse or a health log", 5)
                            T("Each counts once a day. Levels use lifetime points.").font(.hs(11)).foregroundStyle(HS.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    SectionHeader(title: tr("Achievements") + " \(badges.filter(\.2).count)/\(badges.count)").padding(.horizontal, -20)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(badges, id: \.1) { b in
                            VStack(spacing: 6) {
                                T(b.0).font(.system(size: 28)).opacity(b.2 ? 1 : 0.3)
                                T(b.1).font(.hs(11, .semibold)).foregroundStyle(b.2 ? HS.text : HS.textMuted).multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92)
                            .background(RoundedRectangle(cornerRadius: 14).fill(b.2 ? HS.goldButton.opacity(0.14) : HS.overlay(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(b.2 ? HS.gold.opacity(0.5) : .clear, lineWidth: 1))
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(tr(b.2 ? "Unlocked" : "Locked"))
                        }
                    }
                    Spacer().frame(height: 80)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// (emoji, title, unlocked), from real progress only.
    private var badges: [(String, String, Bool)] {
        let streak = store.prayerStreak
        let memorized = (UserDefaults.standard.stringArray(forKey: "memorizedVerses") ?? []).count
        let won = commitments.commitments.filter(\.isComplete).count
        let walkDays = Set(log.days.filter { $0.value.contains(ActivityLog.Event.walk.rawValue) }.keys)
        let setDays = log.days.filter { $0.value.contains(ActivityLog.Event.workoutSet.rawValue) }.count
        return [
            ("🔥", "7-Day Streak", streak >= 7), ("💎", "30-Day Streak", streak >= 30), ("👑", "100-Day Streak", streak >= 100),
            ("🧠", "5 Verses", memorized >= 5), ("🙌", "Answered Prayer", store.prayers.contains(where: \.answered)),
            ("📓", "10 Journal Entries", store.journal.count >= 10), ("✍️", "25 Journal Entries", store.journal.count >= 25),
            ("🚶", "7-Day Walk Streak", Self.run(walkDays) >= 7), ("🏅", "30-Day Walk Streak", Self.run(walkDays) >= 30),
            ("🏋️", "First Form Coach Set", setDays >= 1),
            ("🎯", "First Challenge Won", won >= 1), ("🥇", "3 Challenges Won", won >= 3), ("🔥", "5 Challenges Won", won >= 5),
        ]
    }

    /// The longest run of consecutive days in `days` (dayKey strings).
    private static func run(_ days: Set<String>) -> Int {
        let cal = Calendar.current
        var best = 0
        for k in days {
            guard let d = AppStore.date(fromKey: k),
                  let prev = cal.date(byAdding: .day, value: -1, to: d), !days.contains(AppStore.dayKey(prev)) else { continue }
            var n = 1, cur = d
            while let nx = cal.date(byAdding: .day, value: 1, to: cur), days.contains(AppStore.dayKey(nx)) { n += 1; cur = nx }
            best = max(best, n)
        }
        return best
    }

    private func stat(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            T(emoji).font(.system(size: 18))
            D(value).font(.hs(15, .semibold)).foregroundStyle(HS.text)
            T(label).font(.hs(11)).foregroundStyle(HS.textMuted)
        }
    }

    private func earn(_ emoji: String, _ what: String, _ pts: Int) -> some View {
        HStack(spacing: 10) {
            T(emoji).font(.system(size: 18))
            T(what).font(.hs(13)).foregroundStyle(HS.text)
            Spacer()
            D("+\(pts)").font(.hs(13, .semibold)).foregroundStyle(HS.gold)
        }
    }
}
