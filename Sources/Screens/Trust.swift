import SwiftUI

/// Android's TrustScreen ("Our promises to you"), keeping only what the iPhone app really does: it has no backup yet
/// and no Google Play, so those lines are left out.
struct TrustView: View {
    @Environment(\.openURL) private var openURL
    @State private var plans = false

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("How we treat you").font(.hs(24, .semibold)).foregroundStyle(HS.text)
                    T("Short and plain. The full text is in the Privacy Policy and Terms.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    card("Your data", [
                        "We do not sell your personal information. There are no ad networks in HolySteps.",
                        "Your mood check-ins, journal and prayers stay on your phone.",
                        "Sharing your cycle with your husband sends only your phase dates, never symptoms, notes or moods. You choose how long the code works.",
                    ], link: "Read the Privacy Policy") { openURL(URL(string: AppLinks.site + "/privacy")!) }
                    card("Paying", [
                        "Most of HolySteps is free for good. Safety help, including 988 and the mood check, is always free.",
                        "Plans renew each month or year until you cancel. The price you see is the price you pay.",
                        "If a plan is going to end, we tell you three days before, not after.",
                    ], link: "See plans") { plans = true }
                    card("Leaving", [
                        "Cancel any time at holysteps.org/manage. You keep your plan until the end of the time you've paid for.",
                    ], link: "Manage on holysteps.org") { openURL(URL(string: AppLinks.site + "/manage")!) }
                }
                .padding(20).padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $plans) { PlansView() }
    }

    private func card(_ title: String, _ lines: [String], link: String, _ action: @escaping () -> Void) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                T(title).font(.hs(16, .semibold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                ForEach(lines, id: \.self) { l in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(HS.gold).padding(.top, 3).accessibilityHidden(true)
                        T(l).font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                }
                Button(action: action) { D(tr(link) + " →").font(.hs(13, .semibold)).foregroundStyle(HS.gold) }.padding(.top, 2)
            }
        }
    }
}
