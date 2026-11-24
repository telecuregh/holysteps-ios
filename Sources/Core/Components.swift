import SwiftUI

// Ported from Android's ui/components/Components.kt, SubTabs.kt and ToolGrid.kt (Harmony dark).

/// Android's GlassCard in Harmony: see-through frosted glass — a faint white veil over the page, a sheen from the
/// top-left, an optional colored corner glow, and a hairline edge that is brighter at the top. Radius 20, padding 16.
struct GlassCard<Content: View>: View {
    var glow: Color? = nil
    /// The warm, brighter glass used for the main card on a screen.
    var warm = false
    var padding: CGFloat = 16
    let content: Content

    init(glow: Color? = nil, warm: Bool = false, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.glow = glow; self.warm = warm; self.padding = padding; self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HS.isPearl ? 22 : 20, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { g in
                    let w = g.size.width
                    switch HS.mode {
                    case .pearl:
                        // Pearl: plain frosted white (bgSurface C2FFFFFF) with a bright white edge.
                        HS.cardFill
                    case .light:
                        // Harmony Light: white frosted glass over the blush page, with a vivid colored corner glow.
                        ZStack {
                            Color.white.opacity(warm ? 0.34 : 0.40)
                            if warm {
                                RadialGradient(colors: [Color(hex: 0xE2B48A).opacity(0.55), .clear], center: UnitPoint(x: 0.75, y: 0.95), startRadius: 0, endRadius: w * 0.6)
                                RadialGradient(colors: [Color(hex: 0xCDAFD2).opacity(0.50), .clear], center: UnitPoint(x: 0.15, y: 0.3), startRadius: 0, endRadius: w * 0.5)
                            }
                            if let glow {
                                RadialGradient(colors: [glow.opacity(0.80), .clear], center: UnitPoint(x: 0.12, y: 0.10), startRadius: 0, endRadius: w * 0.85)
                            }
                            LinearGradient(colors: [Color.white.opacity(0.30), .clear], startPoint: .topLeading, endPoint: UnitPoint(x: 0.5, y: 0.7))
                        }
                    case .dark:
                        ZStack {
                            Color.white.opacity(warm ? 0.08 : 0.065)
                            if warm {
                                RadialGradient(colors: [Color(hex: 0xC89A6E).opacity(0.30), .clear], center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: w * 0.75)
                                RadialGradient(colors: [Color(hex: 0xB98A7A).opacity(0.22), .clear], center: UnitPoint(x: 0.18, y: 0.75), startRadius: 0, endRadius: w * 0.45)
                            }
                            if let glow {
                                RadialGradient(colors: [glow.opacity(0.45), .clear], center: UnitPoint(x: 0.12, y: 0.08), startRadius: 0, endRadius: w * 0.85)
                            }
                            LinearGradient(colors: [Color.white.opacity(0.07), .clear], startPoint: .topLeading, endPoint: UnitPoint(x: 0.6, y: 0.8))
                        }
                    }
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: edge, startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }

    private var edge: [Color] {
        switch HS.mode {
        case .pearl: [Color.white.opacity(0.95)]
        case .light: warm ? [Color(hex: 0xE8CFC4), Color(hex: 0xD9B49F).opacity(0.7)] : [Color.white.opacity(0.95), Color(hex: 0xE6D6D6)]
        case .dark: warm ? [Color(hex: 0xD9B49F).opacity(0.55), Color(hex: 0xD9B49F).opacity(0.22)] : [Color.white.opacity(0.22), Color.white.opacity(0.07)]
        }
    }
}

/// Android's HarmonyIconBadge: a dark glass circle with the icon in warm gold.
struct IconBadge: View {
    let symbol: String
    var size: CGFloat = 36
    /// The color the badge stands for. Harmony Dark draws every badge in gold and leaves the color to the card's glow;
    /// Light fills a deep circle of it with a white icon; Pearl tints it softly.
    var tint: UInt32 = 0xD8B27A
    var body: some View {
        ZStack {
            switch HS.mode {
            case .dark:
                Circle().fill(RadialGradient(colors: [Color.white.opacity(0.10), Color.black.opacity(0.30)], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                Image(systemName: symbol).font(.system(size: size * 0.42, weight: .regular)).foregroundStyle(Color(hex: 0xE8C79E))
            case .light:
                let deep = HS.lightReadable(tint)
                Circle().fill(RadialGradient(colors: [deep.opacity(0.85), deep], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                Image(systemName: symbol).font(.system(size: size * 0.42, weight: .regular)).foregroundStyle(.white)
            case .pearl:
                let c = Color(hex: tint)
                Circle().fill(RadialGradient(colors: [c.opacity(0.28), c.opacity(0.08)], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().strokeBorder(c.opacity(0.35), lineWidth: 1)
                Image(systemName: symbol).font(.system(size: size * 0.42, weight: .regular)).foregroundStyle(HS.readable(tint))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Android's GoldPlayBadge.
struct GoldPlayBadge: View {
    var symbol = "play.fill"
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: 0xF1D7A8), HS.goldButton, Color(hex: 0xB98C52)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            Image(systemName: symbol).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(HS.onGold)
        }
        .frame(width: size, height: size)
    }
}

/// Android's SectionHeader: a 16 semibold title, with an optional action on the right.
struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: () -> Void = {}
    var body: some View {
        HStack {
            T(title).font(.hs(16, .semibold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
            Spacer()
            if let action { Button(action: onAction) { T(action).font(.hs(13)).foregroundStyle(HS.peach) } }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }
}

/// Android's ProgressBar in Harmony: 6 high, a violet → peach → green fill on a faint track.
struct HSProgressBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(HS.overlay(0.10))
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [HS.faith, HS.peach, HS.body], startPoint: .leading, endPoint: .trailing))
                    .frame(width: g.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 6)
        .accessibilityValue(D("\(Int(progress * 100))%"))
    }
}

/// Android's InsightBubble.
struct InsightBubble: View {
    let text: String
    var body: some View {
        T(text).font(.hs(13)).lineSpacing(7).foregroundStyle(HS.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HS.gold.opacity(0.28), lineWidth: 1))
            .padding(.horizontal, 20)
    }
}

/// Android's SubTabs: up to four share the row evenly; more scroll sideways.
struct SubTabs: View {
    let tabs: [String]
    @Binding var selected: Int

    var body: some View {
        let scrolls = tabs.count > 4
        Group {
            if scrolls {
                ScrollView(.horizontal, showsIndicators: false) { row(scrolls: true) }
            } else {
                row(scrolls: false)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16).fill(HS.isLight ? Color(hex: 0xEAE3D8) : HS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HS.isLight ? .clear : HS.gold.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func row(scrolls: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, label in
                let on = i == selected
                Button { selected = i } label: {
                    T(label).font(.hs(13, on ? .semibold : .medium)).lineLimit(1)
                        .foregroundStyle(on ? (HS.isLight ? HS.text : HS.peach) : HS.textMuted)
                        .padding(.horizontal, scrolls ? 12 : 4).padding(.vertical, 10)
                        .frame(minHeight: 40)
                        .frame(maxWidth: scrolls ? nil : .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(on ? (HS.isLight ? Color(hex: 0xFBF8F3) : HS.goldButton.opacity(0.22)) : .clear))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on && !HS.isLight ? HS.gold.opacity(0.35) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

/// One feature in a section: icon, a short name, one line of status, and an optional small badge.
struct ToolItem: Identifiable {
    let symbol: String
    let color: Color
    let title: String
    let sub: String
    var badge: String? = nil
    var destination: AnyView? = nil
    var action: (() -> Void)? = nil
    var id: String { title }
}

/// Android's ToolSection: a titled two-column grid of compact tiles; longer groups show the first few and "See all".
struct ToolSection: View {
    let title: String
    let items: [ToolItem]
    var subtitle: String? = nil
    var visible = 6
    @State private var all = false

    var body: some View {
        if !items.isEmpty {
            let shown = all || items.count <= visible ? items : Array(items.prefix(visible - visible % 2))
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        T(title).font(.hs(18, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                        if let subtitle { T(subtitle).font(.hs(12)).foregroundStyle(HS.textMuted) }
                    }
                    Spacer()
                    if items.count > visible {
                        Button { all.toggle() } label: {
                            T(all ? "Show less" : "See all \(items.count)").font(.hs(13, .semibold)).foregroundStyle(HS.faith).padding(6)
                        }
                    }
                }
                ForEach(0..<((shown.count + 1) / 2), id: \.self) { r in
                    HStack(alignment: .top, spacing: 10) {
                        ToolTile(item: shown[r * 2])
                        if r * 2 + 1 < shown.count { ToolTile(item: shown[r * 2 + 1]) } else { Color.clear.frame(maxWidth: .infinity) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct ToolTile: View {
    let item: ToolItem

    private var face: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: item.symbol).font(.system(size: 17)).foregroundStyle(item.color)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11).fill(item.color.opacity(0.15)))
                Spacer()
                if let b = item.badge {
                    D(b).font(.hs(10, .bold)).lineLimit(1).foregroundStyle(item.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(item.color.opacity(0.12)))
                }
            }
            Spacer().frame(height: 10)
            T(item.title).font(.hs(14, .semibold)).lineSpacing(2).lineLimit(2).foregroundStyle(HS.text).multilineTextAlignment(.leading)
            Spacer().frame(height: 2)
            T(item.sub).font(.hs(12)).lineSpacing(2).lineLimit(2).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HS.overlay(0.07), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    var body: some View {
        if let d = item.destination {
            NavigationLink { d } label: { face }.buttonStyle(.plain)
        } else {
            Button { item.action?() } label: { face }.buttonStyle(.plain)
        }
    }
}
