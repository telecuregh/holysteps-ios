import SwiftUI

/// Android's Freedom tab / habit-breaking track (data/FreedomJourney.kt, ui/screens/FreedomScreen.kt).
/// Shows a streak counter, a daily check-in and a resource library for people who chose
/// "Break free from a habit" on onboarding (or who navigate here from Profile).
/// All data stays on device; no network calls.

// MARK: - Data

private let stories: [(symbol: String, title: String, body: String)] = [
    ("figure.walk", "One day at a time",
     "You don't have to beat the whole thing today. You just have to get through today. That's enough."),
    ("heart", "God's strength, not yours",
     "\"I can do all things through Christ who strengthens me.\" You are not fighting this alone."),
    ("moon.stars", "What to do at night",
     "The hardest hours are often late at night. Have a plan: go for a walk, text a friend, pray out loud, read Psalm 23."),
    ("sunrise", "Start fresh every morning",
     "Every morning is a reset. Yesterday's stumble doesn't define today. His mercies are new every morning."),
    ("person.2", "Tell one person",
     "Accountability is not weakness. It's wisdom. Tell one trusted person what you're fighting. Let them pray with you."),
    ("book", "What to read",
     "Start with Romans 7-8. Paul wrote about the same fight. Then Psalm 51 on forgiveness. Then James 1:12-15 on how temptation works."),
    ("hand.raised", "When the urge hits",
     "STOP, Pray, Call someone, Change location. The urge peaks in about 20 minutes and then fades. Outlast it."),
]

// MARK: - Store

final class FreedomStore: ObservableObject {
    static let shared = FreedomStore()
    private let ud = UserDefaults.standard
    private let dayKey = "freedom.checkInDay"
    private let streakKey = "freedom.streak"
    private let startKey = "freedom.startDay"
    private let noteKey = "freedom.note"

    @Published var streak: Int
    @Published var checkedInToday: Bool
    @Published var note: String

    init() {
        let today = AppStore.dayKey()
        let saved = UserDefaults.standard.string(forKey: "freedom.checkInDay") ?? ""
        streak = UserDefaults.standard.integer(forKey: "freedom.streak")
        checkedInToday = saved == today
        note = UserDefaults.standard.string(forKey: "freedom.note") ?? ""
        if UserDefaults.standard.string(forKey: "freedom.startDay") == nil {
            UserDefaults.standard.set(today, forKey: "freedom.startDay")
        }
    }

    func checkIn() {
        let today = AppStore.dayKey()
        guard ud.string(forKey: dayKey) != today else { return }
        streak += 1
        ud.set(streak, forKey: streakKey)
        ud.set(today, forKey: dayKey)
        checkedInToday = true
        ActivityLog.shared.add(.freedomCheckIn)
    }

    func reset() {
        streak = 0
        ud.set(0, forKey: streakKey)
        ud.removeObject(forKey: dayKey)
        ud.set(AppStore.dayKey(), forKey: startKey)
        checkedInToday = false
    }

    func saveNote(_ s: String) {
        note = s
        ud.set(s, forKey: noteKey)
    }
}

// MARK: - Main view

struct FreedomView: View {
    @ObservedObject private var freedom = FreedomStore.shared
    @State private var showReset = false
    @State private var editNote = false
    @State private var draft = ""

    var body: some View {
        ZStack { HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                    D(tr("Freedom")).font(.hs(28)).foregroundStyle(HS.text)
                    ItalicAccent(text: "Breaking free, one day at a time", size: 15)
                }
                        .padding(.horizontal, 20).padding(.top, 58)
                    streakCard
                    if !freedom.checkedInToday { checkInCard }
                    noteSection
                    SectionHeader(title: "Support").padding(.top, 10)
                    if FreedomShield.available { FreedomShieldCard().padding(.horizontal, 20) }
                    supportSection
                    SectionHeader(title: "Wisdom for the fight").padding(.top, 10)
                    storiesSection
                    Spacer().frame(height: 100)
                }
            }
        }
        .navigationTitle(tr("Freedom"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .confirmationDialog(tr("Reset streak?"), isPresented: $showReset, titleVisibility: .visible) {
            Button(tr("Reset to day 0"), role: .destructive) { freedom.reset() }
            Button(tr("Cancel"), role: .cancel) { }
        } message: { T("If you slipped, that's okay. God's grace is bigger. Reset and start again today.") }
        .sheet(isPresented: $editNote) {
            HSSheet(title: "My commitment") {
                VStack(spacing: 16) {
                    TextEditor(text: $draft)
                        .font(.hs(14))
                        .frame(minHeight: 100, maxHeight: 200)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HS.cardFill))
                    GoldButton(title: "Save") { freedom.saveNote(draft); editNote = false }
                }
                .padding(24)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Streak

    private var streakCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(HS.goldButton.opacity(0.15))
                        Image(systemName: freedom.streak >= 7 ? "flame.fill" : "flame")
                            .font(.system(size: 32)).foregroundStyle(HS.peach)
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        D("\(freedom.streak)").font(.hs(38, .bold)).foregroundStyle(HS.text).monospacedDigit()
                        T(freedom.streak == 1 ? "day free" : "days free")
                            .font(.hs(14)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        milestone("7", freedom.streak >= 7)
                        milestone("30", freedom.streak >= 30)
                        milestone("90", freedom.streak >= 90)
                    }
                }
                if freedom.streak > 0 {
                    HStack {
                        T(freedom.streak >= 90 ? "90 days is a new life. Keep going." :
                          freedom.streak >= 30 ? "30 days. The habit is losing its grip." :
                          freedom.streak >= 7  ? "One week. Your brain is already changing." :
                          "Every day adds up. Keep going.")
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                        Spacer()
                        Button { showReset = true } label: {
                            T("I slipped").font(.hs(12)).foregroundStyle(HS.textSubtle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    private func milestone(_ days: String, _ done: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(done ? HS.body : HS.textSubtle)
            T("\(days)d").font(.hs(11)).foregroundStyle(done ? HS.text : HS.textSubtle)
        }
    }

    // MARK: Check-in

    private var checkInCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                T("I stayed free today").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                T("Tap to log today and add to your streak.")
                    .font(.hs(13)).foregroundStyle(HS.textMuted).multilineTextAlignment(.center)
                GoldButton(title: "I made it today") { freedom.checkIn() }
            }
        }
        .padding(.horizontal, 20).padding(.top, 14)
    }

    // MARK: Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "My commitment").padding(.top, 10)
            Button { draft = freedom.note; editNote = true } label: {
                GlassCard {
                    HStack {
                        T(freedom.note.isEmpty ? "Write why you want to be free. Read it when it's hard." : freedom.note)
                            .font(.hs(13)).foregroundStyle(freedom.note.isEmpty ? HS.textMuted : HS.text)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(HS.peach)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    // MARK: Support

    private var supportSection: some View {
        ToolSection(title: "", items: [
            ToolItem(symbol: "phone", color: HS.mind, title: "SAMHSA Helpline",
                     sub: "Free, confidential, 24/7. 1-800-662-4357",
                     action: { UIApplication.shared.open(URL(string: "tel://18006624357")!) }),
            ToolItem(symbol: "message", color: HS.faith, title: "Crisis text line",
                     sub: "Text HOME to 741741", action: { UIApplication.shared.open(URL(string: "sms:741741&body=HOME")!) }),
            ToolItem(symbol: "person.2", color: HS.peach, title: "Find a local group",
                     sub: "AA, NA, Celebrate Recovery and more",
                     action: { UIApplication.shared.open(URL(string: "https://www.celebraterecovery.com/resources/find-a-group")!) }),
        ])
    }

    // MARK: Stories

    private var storiesSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(stories.enumerated()), id: \.offset) { _, s in
                GlassCard {
                    HStack(alignment: .top, spacing: 12) {
                        IconBadge(symbol: s.symbol, size: 32, tint: 0x9D7FEA)
                        VStack(alignment: .leading, spacing: 4) {
                            T(s.title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            T(s.body).font(.hs(13)).foregroundStyle(HS.textSecondary).lineSpacing(4)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
