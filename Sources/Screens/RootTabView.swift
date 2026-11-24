import SwiftUI

/// The five tabs with Android's Harmony tab bar (navigation/Navigation.kt HolyStepsTabBar): icons only, on a plum
/// gradient with a hairline gold edge; the chosen tab glows violet behind a peach icon, with a gold line above it.
/// Each tab keeps its own navigation, and the bar stays on every screen, as on Android.
struct RootTabView: View {
    @EnvironmentObject var i18n: I18n
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var appearance: Appearance
    @ObservedObject private var router = TabRouter.shared
    private var tab: Int { router.tab }

    private var tabs: [(label: String, symbol: String)] {
        [("Home", "house.fill"), ("Faith", "cross"), ("Fitness", "figure.run"),
         (store.gender == "male" ? "Wellness" : "Cycle", store.gender == "male" ? "dumbbell" : "arrow.triangle.2.circlepath"),
         ("Profile", "person")]
    }

    var body: some View {
        // The screens sit above the bar, never under it (Android's Scaffold gives them the bar's height as padding).
        VStack(spacing: 0) {
            ZStack {
                HSBackground()
                ForEach(0..<5, id: \.self) { i in
                    page(i)
                        .opacity(tab == i ? 1 : 0)
                        .allowsHitTesting(tab == i)
                        .accessibilityHidden(tab != i)
                }
                // Pearl mutes the page's colors (Android draws its content through a 0.6 saturation filter).
                .saturation(HS.isPearl ? 0.6 : 1)
            }
            .frame(maxHeight: .infinity)
            NowPlayingBar()
            bar
        }
        .background(HS.bgBottom.ignoresSafeArea())
        .environment(\.locale, i18n.locale)
        .environment(\.font, .hs(16))
        .id("\(i18n.language)-\(appearance.mode.rawValue)")   // redraw every screen in the new language or look
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
        let light = HS.isLight
        let labelled = HS.isPearl   // Pearl keeps its labelled bar; Dark and Light are icons only.
        return HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                let on = tab == i
                Button { router.tab = i } label: {
                    Group {
                        if labelled {
                            VStack(spacing: 4) {
                                icon(t.symbol, size: 22)
                                    .frame(width: 64, height: 32)
                                    .background(Capsule().fill(on ? Color(hex: 0xEAE3D8) : .clear))
                                T(t.label).font(.hs(11, on ? .semibold : .medium)).lineLimit(1)
                            }
                            .foregroundStyle(on ? Color(hex: 0x1F1B16) : HS.textMuted)
                            .frame(height: 56)
                        } else {
                            ZStack {
                                if on {
                                    Circle().fill(RadialGradient(colors: [Color(hex: 0x9D7FEA).opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 28))
                                        .frame(width: 56, height: 56)
                                    Rectangle().fill(HS.goldButton.opacity(0.8)).frame(width: 56 * 0.7, height: 1.5).offset(y: -28 - 12 + 0.75)
                                }
                                icon(t.symbol, size: 24)
                                    .foregroundStyle(on ? (light ? Color(hex: 0xC79A5E) : HS.peach) : HS.textMuted)
                            }
                            .frame(width: 56, height: 56)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr(t.label))
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, 12).padding(.bottom, 4)
        .background(barFill.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(labelled ? Color(hex: 0xE4DCCF) : (light ? Color.white.opacity(0.9) : HS.gold.opacity(0.24))).frame(height: 1)
        }
    }

    private var barFill: LinearGradient {
        switch appearance.mode {
        case .dark: LinearGradient(colors: [HS.bgMid.opacity(0.88), HS.bgBottom.opacity(0.96)], startPoint: .top, endPoint: .bottom)
        case .light: LinearGradient(colors: [Color(hex: 0xFBF6F4, alpha: Double(0xE6) / 255), Color(hex: 0xF3EAE8, alpha: Double(0xF2) / 255)], startPoint: .top, endPoint: .bottom)
        case .pearl: LinearGradient(colors: [Color(hex: 0xFBF8F3)], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private func icon(_ symbol: String, size: CGFloat) -> some View {
        if symbol == "cross" { CrossShape().stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round)).frame(width: size + 2, height: size + 2) }
        else { Image(systemName: symbol).font(.system(size: size, weight: .regular)) }
    }
}

/// Which tab is showing, so a card on one tab can open another (Android's onNavigate to a top-level route).
final class TabRouter: ObservableObject {
    static let shared = TabRouter()
    @Published var tab = 0
    /// Faith's section: 0 Today, 1 Bible, 2 Listen, 3 Mind.
    @Published var faithTab = 0

    func open(tab: Int, faith: Int? = nil) { if let faith { faithTab = faith }; self.tab = tab }
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
