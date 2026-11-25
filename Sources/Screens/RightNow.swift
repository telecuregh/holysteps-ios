import SwiftUI

/// Android's RightNowCard: one suggestion that fits the time of day and how many minutes the person has (3, 10 or
/// 20). The choice is remembered on this phone only. HolySteps on iPhone is the Faith edition, so the faith picks
/// are used; each opens a screen the app already has.
enum RightNow {
    enum Route { case verses, audio, faith, calmCheck, walk, journal, sleep, morningLight }
    struct Pick { let emoji, title, subtitle: String; let route: Route }

    /// 0 morning (5-11), 1 midday (11-17), 2 evening (17-21), 3 night (21-5).
    static func part(_ hour: Int) -> Int {
        switch hour { case 5...10: 0; case 11...16: 1; case 17...20: 2; default: 3 }
    }

    static func pick(hour: Int, minutes: Int, faith: Bool = true) -> Pick {
        let m = minutes <= 3 ? 3 : minutes <= 10 ? 10 : 20
        switch part(hour) {
        case 0:
            if m == 3 { return faith ? Pick(emoji: "📖", title: "Today's verse", subtitle: "Read it and make it yours", route: .verses)
                                     : Pick(emoji: "🌤", title: "Morning light", subtitle: "Start the day with daylight", route: .morningLight) }
            if m == 10 { return faith ? Pick(emoji: "🙏", title: "Start the day in prayer", subtitle: "A short guided prayer", route: .audio)
                                      : Pick(emoji: "🧘", title: "A short guided session", subtitle: "Settle in before the day", route: .audio) }
            return faith ? Pick(emoji: "✝️", title: "This week's sermon", subtitle: "Listen while you get ready", route: .faith)
                         : Pick(emoji: "🎧", title: "A longer guided session", subtitle: "Take your time", route: .audio)
        case 1:
            if m == 3 { return Pick(emoji: "🫶", title: "A calm check", subtitle: "Two minutes to reset", route: .calmCheck) }
            if m == 10 { return Pick(emoji: "🚶", title: "A walk", subtitle: "Walk and clear your head", route: .walk) }
            return faith ? Pick(emoji: "🎧", title: "A prayer walk or sermon", subtitle: "Listen as you move", route: .audio)
                         : Pick(emoji: "🚶", title: "A longer walk", subtitle: "Steps count automatically", route: .walk)
        case 2:
            if m == 3 { return Pick(emoji: "📝", title: "Write it down", subtitle: "One line about your day", route: .journal) }
            if m == 10 { return Pick(emoji: "🚶", title: "A walk after work", subtitle: "Let the day go", route: .walk) }
            return faith ? Pick(emoji: "✝️", title: "A sermon for the evening", subtitle: "Settle in and listen", route: .faith)
                         : Pick(emoji: "🎧", title: "A guided session", subtitle: "Unwind properly", route: .audio)
        default:
            if m == 3 { return Pick(emoji: "🌙", title: "Wind down", subtitle: "A short calm before sleep", route: .sleep) }
            if m == 10 { return Pick(emoji: "🌙", title: "Night prayer and sounds", subtitle: "Slow your mind", route: .sleep) }
            return Pick(emoji: "😴", title: "A sleep story", subtitle: "Drift off to a long story", route: .sleep)
        }
    }

    static func greeting(_ hour: Int) -> String {
        ["Good morning", "Right now", "Good evening", "Before you sleep"][part(hour)]
    }
}

struct RightNowCard: View {
    let onOpen: (RightNow.Route) -> Void
    @AppStorage("right_now.minutes") private var minutes = 10
    private let hour = Calendar.current.component(.hour, from: Date())

    var body: some View {
        let pick = RightNow.pick(hour: hour, minutes: minutes)
        VStack(alignment: .leading, spacing: 10) {
            T(RightNow.greeting(hour)).font(.hs(18, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    T("How long do you have?").font(.hs(12)).foregroundStyle(HS.textMuted)
                    HStack(spacing: 8) {
                        ForEach([3, 10, 20], id: \.self) { m in
                            let on = m == minutes
                            Button { minutes = m } label: {
                                D(tr("\(m) min")).font(.hs(13, on ? .semibold : .regular)).foregroundStyle(on ? HS.text : HS.textMuted)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Capsule().fill(on ? HS.text.opacity(0.18) : HS.textMuted.opacity(0.10)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.top, 8).padding(.bottom, 10)
                    Button { onOpen(pick.route) } label: {
                        HStack(spacing: 12) {
                            T(pick.emoji).font(.system(size: 22)).foregroundStyle(HS.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                T(pick.title).font(.hs(15, .semibold)).foregroundStyle(HS.text).lineLimit(1)
                                T(pick.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.system(size: 15)).foregroundStyle(HS.textMuted)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
