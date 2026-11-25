import ActivityKit
import WidgetKit
import SwiftUI

/// The Live Activity in Navy Glass: a walk's time and distance, a workout's current move and countdown, a sermon.
struct HolyStepsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HolyStepsActivityAttributes.self) { ctx in
            LockScreenCard(attributes: ctx.attributes, state: ctx.state)
                .activityBackgroundTint(NavyGlass.navy)
                .activitySystemActionForegroundColor(NavyGlass.gold)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: Self.symbol(ctx.attributes.kind)).font(.title2).foregroundStyle(NavyGlass.gold).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Clock(state: ctx.state).font(.title3.monospacedDigit()).foregroundStyle(NavyGlass.ink).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(ctx.state.headline).font(.headline).foregroundStyle(NavyGlass.ink).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(ctx.state.detail).font(.caption).foregroundStyle(NavyGlass.ink.opacity(0.75)).lineLimit(1)
                        ProgressView(value: ctx.state.progress).tint(NavyGlass.gold)
                    }
                }
            } compactLeading: {
                Image(systemName: Self.symbol(ctx.attributes.kind)).foregroundStyle(NavyGlass.gold)
            } compactTrailing: {
                Clock(state: ctx.state).font(.caption.monospacedDigit()).foregroundStyle(NavyGlass.ink).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: Self.symbol(ctx.attributes.kind)).foregroundStyle(NavyGlass.gold)
            }
            .keylineTint(NavyGlass.gold)
        }
    }

    static func symbol(_ k: HolyStepsActivityAttributes.Kind) -> String {
        switch k { case .walk: "figure.walk"; case .workout: "figure.strengthtraining.traditional"; case .sermon: "book.closed" }
    }
}

private struct Clock: View {
    let state: HolyStepsActivityAttributes.ContentState
    var body: some View {
        if state.paused {
            Image(systemName: "pause.fill")
        } else if let end = state.endsAt, end > Date() {
            Text(timerInterval: Date()...end, countsDown: true)
        } else if let since = state.since {
            Text(since, style: .timer)
        } else {
            Image(systemName: "waveform")
        }
    }
}

private struct LockScreenCard: View {
    let attributes: HolyStepsActivityAttributes
    let state: HolyStepsActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: HolyStepsLiveActivity.symbol(attributes.kind)).font(.title2).foregroundStyle(NavyGlass.gold)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(NavyGlass.gold.opacity(0.6), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.title.uppercased()).font(.custom("Inter-SemiBold", size: 10)).tracking(2).foregroundStyle(NavyGlass.gold).lineLimit(1)
                Text(state.headline).font(.custom("PlayfairDisplay-Italic", size: 20)).foregroundStyle(NavyGlass.ink).lineLimit(1)
                Text(state.detail).font(.custom("Inter-Medium", size: 12)).foregroundStyle(NavyGlass.ink.opacity(0.75)).lineLimit(1)
                ProgressView(value: state.progress).tint(NavyGlass.gold)
            }
            Clock(state: state).font(.title2.monospacedDigit()).foregroundStyle(NavyGlass.ink).frame(minWidth: 60, alignment: .trailing)
        }
        .padding(16)
    }
}
