import SwiftUI

/// The five tabs with Android's Harmony tab bar (navigation/Navigation.kt HolyStepsTabBar): icons only, on a plum
/// gradient with a hairline gold edge; the chosen tab glows violet behind a peach icon, with a gold line above it.
/// Each tab keeps its own navigation, and the bar stays on every screen, as on Android.
struct RootTabView: View {
    @EnvironmentObject var i18n: I18n
    @EnvironmentObject var store: AppStore
    @State private var tab = 0

    private var tabs: [(label: String, symbol: String)] {
        [("Home", "house.fill"), ("Faith", "cross"), ("Fitness", "figure.run"),
         (store.gender == "male" ? "Wellness" : "Cycle", store.gender == "male" ? "dumbbell" : "arrow.triangle.2.circlepath"),
         ("Profile", "person")]
    }

    var body: some View {
        ZStack {
            HSBackground()
            ForEach(0..<5, id: \.self) { i in
                page(i)
                    .opacity(tab == i ? 1 : 0)
                    .allowsHitTesting(tab == i)
                    .accessibilityHidden(tab != i)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                NowPlayingBar()
                bar
            }
        }
        .environment(\.locale, i18n.locale)
        .environment(\.font, .hs(16))
        .id(i18n.language)   // redraw every screen in the new language
    }

    @ViewBuilder
    private func page(_ i: Int) -> some View {
        switch i {
        case 0: HomeView()
        case 1: FaithView()
        case 2: FitnessView()
        case 3: CycleView()
        default: ProfileView()
        }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                let on = tab == i
                Button { tab = i } label: {
                    ZStack {
                        if on {
                            Circle().fill(RadialGradient(colors: [HS.faith.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 28))
                                .frame(width: 56, height: 56)
                            Rectangle().fill(HS.goldButton.opacity(0.8)).frame(width: 56 * 0.7, height: 1.5).offset(y: -28 - 12 + 0.75)
                        }
                        Group {
                            if t.symbol == "cross" { CrossShape().stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round)).frame(width: 26, height: 26) }
                            else { Image(systemName: t.symbol).font(.system(size: 24, weight: .regular)) }
                        }
                        .foregroundStyle(on ? HS.peach : HS.textMuted)
                    }
                    .frame(width: 56, height: 56)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr(t.label))
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, 12).padding(.bottom, 4)
        .background(
            LinearGradient(colors: [HS.bgMid.opacity(0.88), HS.bgBottom.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) { Rectangle().fill(HS.gold.opacity(0.24)).frame(height: 1) }
    }
}

/// The thin outline cross Android draws for the Faith tab ("M12,3 L12,21 M6.5,8.5 L17.5,8.5" on a 24 grid).
struct CrossShape: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 12 * s, y: r.minY + 3 * s)); p.addLine(to: CGPoint(x: r.minX + 12 * s, y: r.minY + 21 * s))
        p.move(to: CGPoint(x: r.minX + 6.5 * s, y: r.minY + 8.5 * s)); p.addLine(to: CGPoint(x: r.minX + 17.5 * s, y: r.minY + 8.5 * s))
        return p
    }
}

/// Android's GlobalNowPlayingBar: what's playing anywhere in the app, with a stop button, above the tab bar.
struct NowPlayingBar: View {
    @ObservedObject private var sermon = SermonPlayer.shared
    @ObservedObject private var bible = BibleListening.shared
    @ObservedObject private var music = MusicPlayer.shared

    var body: some View {
        let item: (symbol: String, label: String, stop: () -> Void)? = {
            if sermon.active && sermon.playing { return ("mic", tr(sermon.sermon?.title ?? "Audio"), { sermon.stop() }) }
            if bible.active && bible.playing { return ("book", bible.title.isEmpty ? tr("Bible") : bible.title, { bible.stop() }) }
            if music.active && music.playing { return ("headphones", tr(music.current?.title ?? "Music"), { music.stop() }) }
            return nil
        }()
        if let item {
            HStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 17)).foregroundStyle(HS.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    T("Now playing").font(.hs(10)).foregroundStyle(HS.textMuted)
                    D(item.label).font(.hs(13)).foregroundStyle(HS.text).lineLimit(1)
                }
                Spacer()
                Button(action: item.stop) {
                    Image(systemName: "stop.circle.fill").font(.system(size: 24)).foregroundStyle(HS.peach).frame(width: 44, height: 44)
                }
                .accessibilityLabel(tr("Stop audio"))
            }
            .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 6)
            .background(HS.cardFill)
            .overlay(alignment: .bottom) { Rectangle().fill(HS.gold.opacity(0.25)).frame(height: 1) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
