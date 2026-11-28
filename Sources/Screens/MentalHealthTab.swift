import SwiftUI

/// The "Mental Health" sub-tab on the Women's (Cycle) and Men's screens (Android: the same tab on CycleScreen and
/// MensHealthScreen). It names the area plainly and opens the Grace-read library, the private mood check and the
/// 988 crisis line, so nobody has to dig through "More" to find them.
struct MentalHealthTab: View {
    let men: Bool
    private var tint: UInt32 { men ? 0x8B5CF6 : 0xF472B6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                T(men ? "🧠 Men's Mental Health" : "💜 Women's Mental Health").font(.hs(20, .bold)).foregroundStyle(HS.text)
                T(men ? "Spoken guidance for depression, anger, grief, anxiety, burnout and recovery. Read by Grace. Private, on your phone."
                      : "Spoken guidance for anxiety, PMS/PMDD, postpartum, grief, burnout and self-worth. Read by Grace. Private, on your phone.")
                    .font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.top, 16)

            if men {
                CoverCard(emoji: "🎧", title: "Listen now", subtitle: "Everyday sessions and talks, read by Grace", tint: tint) { MensMindView() }
                    .padding(.horizontal, 20).padding(.top, 14)
            } else {
                CoverCard(emoji: "🎧", title: "Listen now", subtitle: "Everyday sessions and talks, read by Grace", tint: tint) { WomenMindView() }
                    .padding(.horizontal, 20).padding(.top, 14)
            }
            CoverCard(emoji: "🧠", title: "Mood check-in", subtitle: "A private 1-minute check, with 988 one tap away", tint: 0xA78BFA) { MoodCheckView() }
                .padding(.horizontal, 20).padding(.top, 12)

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    T("Need to talk to someone now?").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T("In the US, call or text 988 any time for the Suicide & Crisis Lifeline. In an emergency, call 911.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        if let call = URL(string: "tel:988") { Link(destination: call) { Label(tr("Call 988"), systemImage: "phone.fill") } }
                        if let text = URL(string: "sms:988") { Link(destination: text) { Label(tr("Text 988"), systemImage: "message.fill") } }
                    }
                    .font(.hs(14, .semibold)).foregroundStyle(HS.readable(tint))
                }
            }
            .padding(.horizontal, 20).padding(.top, 12)

            T("Not medical advice. HolySteps doesn't diagnose or treat any condition.")
                .font(.hs(11)).foregroundStyle(HS.textMuted).padding(.horizontal, 20).padding(.top, 12)
        }
    }
}
