import SwiftUI
import UserNotifications

/// Android's Fasting (FastingCard, FastAlarm.kt): pick a 12, 16 or 24-hour fast, watch it, and pray through it.
/// Same rules: a "your fast is complete" notification at the goal, a fast nobody ended is closed as completed 12 hours
/// after its goal, a start in the future (clock changed) is cleared, and ending early doesn't count as completed.
enum FastLogic {
    static let autoCloseAfterGoal: TimeInterval = 12 * 3600
    static func goalAt(_ start: Date, _ hours: Int) -> Date { start.addingTimeInterval(Double(max(1, hours)) * 3600) }
    static func expired(_ start: Date, _ hours: Int, now: Date) -> Bool { now >= goalAt(start, hours).addingTimeInterval(autoCloseAfterGoal) }
    static func invalid(_ start: Date, now: Date) -> Bool { start > now.addingTimeInterval(5 * 60) }
}

final class FastStore: ObservableObject {
    static let shared = FastStore()
    private let d = UserDefaults.standard
    @Published private(set) var start: Date?
    @Published private(set) var goalHours: Int
    @Published private(set) var completed: Int

    private init() {
        let t = d.double(forKey: "fastStart")
        start = t > 0 ? Date(timeIntervalSince1970: t) : nil
        goalHours = max(1, d.integer(forKey: "fastGoalHours"))
        completed = d.integer(forKey: "fastsCompleted")
    }

    func begin(_ hours: Int) {
        let now = Date()
        start = now; goalHours = hours
        d.set(now.timeIntervalSince1970, forKey: "fastStart"); d.set(hours, forKey: "fastGoalHours")
        schedule(now, hours)
    }

    /// Ends the fast. Reaching the goal counts as completed and earns points (2 per hour, 10 to 100, as Android).
    @discardableResult func end(now: Date = Date()) -> Bool {
        guard let s = start else { return false }
        let reached = now >= FastLogic.goalAt(s, goalHours)
        clear()
        if reached { complete() }
        return reached
    }

    /// Closes a forgotten fast as completed at its goal, and clears one that starts in the future.
    func tidy(now: Date = Date()) {
        guard let s = start else { return }
        if FastLogic.invalid(s, now: now) { clear(); return }
        if FastLogic.expired(s, goalHours, now: now) { clear(); complete() }
    }

    private func complete() {
        completed += 1; d.set(completed, forKey: "fastsCompleted")
        Points.award(min(100, max(10, goalHours * 2)))
    }

    private func clear() {
        start = nil; d.set(0, forKey: "fastStart")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["fast.done"])
    }

    private func schedule(_ start: Date, _ hours: Int) {
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let n = UNMutableNotificationContent()
            n.title = tr("Your fast is complete")
            n.body = tr("You reached your goal. Break your fast gently and give thanks.")
            n.userInfo = ["route": "feature:Fasting"]
            let secs = max(60, FastLogic.goalAt(start, hours).timeIntervalSinceNow)
            c.add(UNNotificationRequest(identifier: "fast.done", content: n, trigger: UNTimeIntervalNotificationTrigger(timeInterval: secs, repeats: false)))
        }
    }
}

struct FastingView: View {
    @ObservedObject private var fast = FastStore.shared
    @State private var now = Date()
    @State private var confirmEnd = false
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let elapsed = fast.start.map { max(0, now.timeIntervalSince($0) / 3600) } ?? 0
        let goal = Double(fast.goalHours)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard(warm: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        T("🕊️ FAITH").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                        T("Fasting").font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                        T("Set a fast, track it, and pray through it.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        if fast.start == nil {
                            T("Fast and pray").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            T("\"When you fast… your Father, who sees what is done in secret, will reward you.\" — Matthew 6:17-18")
                                .font(.hs(12)).italic().foregroundStyle(HS.textMuted)
                            HStack(spacing: 10) {
                                ForEach([12, 16, 24], id: \.self) { h in
                                    Button { fast.begin(h); now = Date() } label: {
                                        VStack(spacing: 2) {
                                            D("\(h)h").font(.hs(15, .semibold)).foregroundStyle(HS.gold)
                                            T("fast").font(.hs(10)).foregroundStyle(HS.textMuted)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton.opacity(0.16)))
                                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.35)))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(tr("Start a \(h)-hour fast"))
                                }
                            }
                            if fast.completed > 0 {
                                D(tr("{0} fasts completed").replacingOccurrences(of: "{0}", with: "\(fast.completed)")).font(.hs(12)).foregroundStyle(HS.gold)
                            }
                            T("Skip fasting if you are pregnant, nursing, diabetic, or have a history of disordered eating. Talk to your doctor first.")
                                .font(.hs(11)).foregroundStyle(HS.textMuted)
                        } else {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().stroke(HS.overlay(0.12), lineWidth: 8)
                                    Circle().trim(from: 0, to: min(1, elapsed / goal)).stroke(HS.peach, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    VStack(spacing: 0) {
                                        D(String(format: "%.1fh", elapsed)).font(.hs(15, .bold)).foregroundStyle(HS.text)
                                        D(tr("of") + " \(fast.goalHours)h").font(.hs(10)).foregroundStyle(HS.textMuted)
                                    }
                                }
                                .frame(width: 76, height: 76)
                                .accessibilityElement(children: .combine)
                                VStack(alignment: .leading, spacing: 4) {
                                    T(elapsed >= goal ? "Goal reached!" : "Fasting in progress").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                    D(elapsed >= goal ? tr("Break your fast gently and give thanks.")
                                      : tr("When hunger comes, turn it into prayer. {0} hours to go.").replacingOccurrences(of: "{0}", with: String(format: "%.1f", goal - elapsed)))
                                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                            }
                            Button { if elapsed >= goal { fast.end() } else { confirmEnd = true } } label: {
                                T(elapsed >= goal ? "Complete fast" : "End fast early").font(.hs(14, .semibold))
                                    .foregroundStyle(elapsed >= goal ? HS.onGold : HS.text)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(elapsed >= goal ? AnyShapeStyle(HS.goldButton) : AnyShapeStyle(HS.overlay(0.12))))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Fasting"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fast.tidy(); now = Date() }
        .onReceive(tick) { now = $0; fast.tidy(now: $0) }
        .alert(tr("End your fast early?"), isPresented: $confirmEnd) {
            Button(tr("End fast")) { fast.end() }
            Button(tr("Keep going"), role: .cancel) {}
        } message: {
            D(tr("You're {0} hours in. Ending now won't count as a completed fast.").replacingOccurrences(of: "{0}", with: String(format: "%.1f", elapsed)))
        }
    }
}
