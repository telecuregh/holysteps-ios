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

/// Profile › Appearance: Android's ThemeMode. Gold, Navy and Bronze were retired there, so only these three remain.
enum ThemeMode: String, CaseIterable, Identifiable {
    case dark, light, pearl
    var id: String { rawValue }
    var label: String { switch self { case .dark: "Dark"; case .light: "Light"; case .pearl: "Pearl" } }
    var emoji: String { switch self { case .dark: "🌙"; case .light: "☀️"; case .pearl: "🤍" } }
    var isLight: Bool { self != .dark }
}

/// The chosen look, kept in UserDefaults. Changing it redraws every screen (RootTabView keys its id on it).
final class Appearance: ObservableObject {
    static let shared = Appearance()
    static let key = "themeMode"
    @Published var mode: ThemeMode {
        didSet { HS.mode = mode; UserDefaults.standard.set(mode.rawValue, forKey: Self.key) }
    }
    private init() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-themeMode"), i + 1 < args.count, let m = ThemeMode(rawValue: args[i + 1]) {
            UserDefaults.standard.set(m.rawValue, forKey: Self.key)
        }
        mode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .dark
        HS.mode = mode
    }
}

enum HS {
    static var mode: ThemeMode = .dark
    static var isLight: Bool { mode.isLight }
    static var isPearl: Bool { mode == .pearl }
    private static func pick(_ dark: UInt32, _ light: UInt32) -> Color { Color(hex: isLight ? light : dark) }

    // Dark matches the Android "Harmony" dark theme; Light and Pearl use Android's LightPalette.
    static var bgTop: Color { isPearl ? Color(hex: 0xF3F1EC) : pick(0x1A1226, 0xF6EDE6) }
    static var bgMid: Color { isPearl ? Color(hex: 0xEEEAE2) : pick(0x120D1A, 0xEFE3E0) }
    static var bgBottom: Color { isPearl ? Color(hex: 0xE9E5DC) : pick(0x0B0810, 0xDFCCD5) }
    static var card: Color { isLight ? Color.white.opacity(0.88) : Color(hex: 0x1C1524) }
    /// Edge and gold text: HarmonyGoldEdge on Dark, goldText on Light.
    static var gold: Color { pick(0xD9B49F, 0x85633A) }
    static let goldButton = Color(hex: 0xD8B27A)
    static let onGold = Color(hex: 0x1A1208)
    /// HarmonyAccent: soft peach on Dark, warm ink on Light.
    static var peach: Color { pick(0xF3D5C0, 0x3A2F33) }
    /// The Playfair italic accent line (HarmonyItalicAccent).
    static var italic: Color { pick(0xF3D5C0, 0x2E2328) }
    static var text: Color { pick(0xFAF6F2, 0x2A2226) }
    static var textSecondary: Color { pick(0xE6DDD5, 0x4A4045) }
    static var textMuted: Color { pick(0xC4B9B0, 0x6A5F64) }
    static var textSubtle: Color { pick(0x9F948B, 0x7D7277) }
    /// Card fill: HarmonyCardFill (0xA61C1524) on Dark, E0FFFFFF on Light, C2FFFFFF on Pearl.
    static var cardFill: Color {
        switch mode {
        case .dark: Color(hex: 0x1C1524, alpha: Double(0xA6) / 255)
        case .light: Color.white.opacity(Double(0xE0) / 255)
        case .pearl: Color.white.opacity(Double(0xC2) / 255)
        }
    }
    static let cardSheen = Color(hex: 0xF7E3D4, alpha: Double(0x18) / 255)
    /// Android's SolidSurface for dialogs and sheets.
    static var solidSurface: Color { pick(0x191322, 0xFBF7F5) }
    static var faith: Color { readable(0x9D7FEA) }
    static var body: Color { readable(0x56B892) }
    static var mind: Color { readable(0x64A5E8) }
    static var cycle: Color { readable(0xE57A9E) }
    /// NeutralOverlay: white on Dark; deep ink (alpha × 1.3) on Light.
    static func overlay(_ a: Double) -> Color { isLight ? Color(hex: 0x1F1B16, alpha: min(1, a * 1.3)) : Color.white.opacity(a) }

    /// Android's Color.readable(): on Light, saturated colors are darkened until they reach 5.6:1 against white.
    static func readable(_ hex: UInt32) -> Color { isLight ? lightReadable(hex) : Color(hex: hex) }
    static func readable(_ light: UInt32, dark: UInt32) -> Color { Color(hex: isLight ? light : dark) }

    static func lightReadable(_ hex: UInt32) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
        let mx = max(r, g, b), mn = min(r, g, b)
        let l0 = (mx + mn) / 2
        let s = mx == mn ? 0 : (mx - mn) / (1 - abs(2 * l0 - 1))
        func lum(_ r: Double, _ g: Double, _ b: Double) -> Double {
            func f(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
        }
        func contrast(_ r: Double, _ g: Double, _ b: Double) -> Double { 1.05 / (lum(r, g, b) + 0.05) }
        if s < 0.3 || contrast(r, g, b) >= 5.6 { return Color(hex: hex) }
        var h: Double
        let d = mx - mn
        if mx == r { h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6) }
        else if mx == g { h = 60 * ((b - r) / d + 2) }
        else { h = 60 * ((r - g) / d + 4) }
        if h < 0 { h += 360 }
        func hsl(_ l: Double) -> (Double, Double, Double) {
            let c = (1 - abs(2 * l - 1)) * s, x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1)), m = l - c / 2
            let (a, bb, cc): (Double, Double, Double)
            switch h { case ..<60: (a, bb, cc) = (c, x, 0); case ..<120: (a, bb, cc) = (x, c, 0); case ..<180: (a, bb, cc) = (0, c, x)
            case ..<240: (a, bb, cc) = (0, x, c); case ..<300: (a, bb, cc) = (x, 0, c); default: (a, bb, cc) = (c, 0, x) }
            return (a + m, bb + m, cc + m)
        }
        var l = l0
        var out = (r, g, b)
        while contrast(out.0, out.1, out.2) < 5.6 && l > 0.12 { l -= 0.02; out = hsl(l) }
        return Color(.sRGB, red: out.0, green: out.1, blue: out.2, opacity: 1)
    }
}

/// Android's Harmony backdrop (SkyGlass, dark): the plum gradient, a soft glow near the top and a warm peach-rose
/// haze toward the middle.
struct HSBackground: View {
    var body: some View {
        GeometryReader { g in
            if HS.isPearl { PearlBackdrop(size: g.size) } else {
                ZStack {
                    LinearGradient(colors: HS.isLight ? [Color(hex: 0xF6EDE6), Color(hex: 0xEFE3E0), Color(hex: 0xE8DADC), Color(hex: 0xDFCCD5)]
                                   : [HS.bgTop, HS.bgMid, HS.bgBottom], startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [HS.isLight ? Color.white.opacity(Double(0x40) / 255) : Color(hex: 0x9B7785, alpha: Double(0x2E) / 255), .clear],
                                   center: UnitPoint(x: 0.5, y: 0.16), startRadius: 0, endRadius: g.size.width * 0.85)
                    RadialGradient(colors: [HS.isLight ? Color(hex: 0xD9A6B6, alpha: Double(0x40) / 255) : Color(hex: 0x7E5A52, alpha: Double(0x47) / 255), .clear],
                                   center: UnitPoint(x: 0.5, y: 0.44), startRadius: 0, endRadius: g.size.width * 0.95)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Android's pearlBackdrop (GoldGlass.kt): warm pearl gradient, three golden glows and seven white glass panes, drawn
/// on a 390 × 844 design grid.
struct PearlBackdrop: View {
    let size: CGSize
    static let panes: [[CGPoint]] = [
        [(80, 0), (250, 0), (250, 300), (80, 240)],
        [(-20, 210), (110, 270), (110, 420), (-20, 370)],
        [(280, 230), (410, 160), (410, 420), (280, 360)],
        [(0, 430), (190, 310), (400, 420), (215, 570)],
        [(-20, 500), (90, 560), (90, 680), (-20, 660)],
        [(225, 660), (400, 540), (400, 760)],
        [(-10, 760), (210, 690), (210, 860), (-10, 860)],
    ].map { $0.map { CGPoint(x: $0.0, y: $0.1) } }

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            func x(_ v: CGFloat) -> CGFloat { v / 390 * w }
            func y(_ v: CGFloat) -> CGFloat { v / 844 * h }
            let all = Path(CGRect(origin: .zero, size: sz))
            ctx.fill(all, with: .linearGradient(Gradient(colors: [Color(hex: 0xF3F1EC), Color(hex: 0xEEEAE2), Color(hex: 0xE9E5DC)]),
                                                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            for (c, cx, cy, r) in [(0xB3F6DDA8 as UInt64, 150.0, 250.0, 0.55), (0xBFF3D598, 300, 610, 0.65), (0x99F8E6C0, 60, 700, 0.45)] {
                let col = Color(hex: UInt32(c & 0xFFFFFF), alpha: Double(c >> 24) / 255)
                ctx.fill(all, with: .radialGradient(Gradient(colors: [col, .clear]), center: CGPoint(x: x(cx), y: y(cy)), startRadius: 0, endRadius: w * r))
            }
            for pts in Self.panes {
                var p = Path()
                p.move(to: CGPoint(x: x(pts[0].x), y: y(pts[0].y)))
                for q in pts.dropFirst() { p.addLine(to: CGPoint(x: x(q.x), y: y(q.y))) }
                p.closeSubpath()
                let top = y(pts.map(\.y).min()!), bottom = y(pts.map(\.y).max()!)
                ctx.fill(p, with: .linearGradient(Gradient(colors: [Color.white.opacity(Double(0xD9) / 255), Color.white.opacity(Double(0x40) / 255)]),
                                                  startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
                ctx.stroke(p, with: .color(.white), lineWidth: 1)
            }
        }
        .frame(width: size.width, height: size.height)
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
        // Pearl keeps Android's Linen type: Fraunces for display and headline sizes, Inter for the rest.
        if HS.isPearl && size >= 24 { return .custom(weight == .semibold || weight == .bold ? "Fraunces-SemiBold" : "Fraunces-Medium", size: size) }
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
        D(tr(text)).font(.accent(size)).foregroundStyle(HS.italic)
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
