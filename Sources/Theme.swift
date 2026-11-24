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
    static let faith = Color(hex: 0x9D7FEA)
    static let body = Color(hex: 0x56B892)
    static let mind = Color(hex: 0x64A5E8)
    static let cycle = Color(hex: 0xE57A9E)
}

struct HSBackground: View {
    var body: some View {
        LinearGradient(colors: [HS.bgTop, HS.bgMid, HS.bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(HS.card.opacity(0.65)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(HS.gold.opacity(0.24), lineWidth: 1))
    }
}

struct GoldButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
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
        Text(text)
            .font(.system(size: 30, weight: .regular, design: .serif))
            .foregroundStyle(HS.text)
    }
}
