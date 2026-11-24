import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum HS {
    // Matches the Android "Harmony" dark theme.
    static let bgTop = Color(hex: 0x1A1226)
    static let bgMid = Color(hex: 0x120D1A)
    static let bgBottom = Color(hex: 0x0B0810)
    static let card = Color(hex: 0x1C1524)
    static let gold = Color(hex: 0xD9B49F)
    static let goldButton = Color(hex: 0xD8B27A)
    static let onGold = Color(hex: 0x1A1208)
    static let peach = Color(hex: 0xF3D5C0)
    static let text = Color(hex: 0xFAF6F2)
    static let textSecondary = Color(hex: 0xE6DDD5)
    static let textMuted = Color(hex: 0xC4B9B0)
    static let textSubtle = Color(hex: 0x9F948B)
    /// Android's HarmonyCardFill (0xA61C1524): frosted plum-charcoal glass.
    static let cardFill = Color(hex: 0x1C1524, alpha: Double(0xA6) / 255)
    static let cardSheen = Color(hex: 0xF7E3D4, alpha: Double(0x18) / 255)
    /// Android's SolidSurface for dialogs and sheets.
    static let solidSurface = Color(hex: 0x191322)
    static let faith = Color(hex: 0x9D7FEA)
    static let body = Color(hex: 0x56B892)
    static let mind = Color(hex: 0x64A5E8)
    static let cycle = Color(hex: 0xE57A9E)
}

/// Android's Harmony backdrop (SkyGlass, dark): the plum gradient, a soft glow near the top and a warm peach-rose
/// haze toward the middle.
struct HSBackground: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [HS.bgTop, HS.bgMid, HS.bgBottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(hex: 0x9B7785, alpha: Double(0x2E) / 255), .clear],
                               center: UnitPoint(x: 0.5, y: 0.16), startRadius: 0, endRadius: g.size.width * 0.85)
                RadialGradient(colors: [Color(hex: 0x7E5A52, alpha: Double(0x47) / 255), .clear],
                               center: UnitPoint(x: 0.5, y: 0.44), startRadius: 0, endRadius: g.size.width * 0.95)
            }
        }
        .ignoresSafeArea()
    }
}

extension Font {
    /// Android's Harmony type: Inter for all text (Text.kt harmonyAndLinenType). Inter ships Regular, Medium, SemiBold
    /// and Bold, so lighter weights read as Regular and heavier ones as Bold, as they do on Android.
    static func hs(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium: name = "Inter-Medium"
        case .semibold: name = "Inter-SemiBold"
        case .bold, .heavy, .black: name = "Inter-Bold"
        default: name = "Inter-Regular"
        }
        return .custom(name, size: size)
    }

    /// Italic text on Android is Playfair Display italic (HarmonySerif).
    static func accent(_ size: CGFloat) -> Font { .custom("PlayfairDisplay-Italic", size: size) }
}

/// Android's HarmonyItalicAccent: the Playfair Display italic accent line in soft peach.
struct ItalicAccent: View {
    let text: String
    var size: CGFloat = 18
    var body: some View {
        D(tr(text)).font(.accent(size)).foregroundStyle(HS.peach)
    }
}

struct GoldButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            D(tr(title))
                .font(.hs(16, .semibold))
                .foregroundStyle(HS.onGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(HS.goldButton))
        }
    }
}

struct ScreenTitle: View {
    let text: String
    var body: some View {
        D(tr(text))
            .font(.hs(30, .regular))
            .foregroundStyle(HS.text)
    }
}
