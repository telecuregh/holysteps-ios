import SwiftUI

/// One prayer drawn as its own plant. `growth` is how many times the user has prayed for it; every prayer adds
/// height, leaves and then buds, so each "I prayed" visibly changes the plant. When the prayer is answered the buds
/// open into flowers. Animatable, so growth and blooming animate between steps.
struct PrayerPlant: View, Animatable {
    var growth: Double
    var bloom: Double          // 0 = still growing, 1 = answered and in full flower
    var flower: Color
    var seed: Int = 0          // varies leaf lean and flower placement a little from plant to plant

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(growth, bloom) }
        set { growth = newValue.first; bloom = newValue.second }
    }

    var body: some View {
        Canvas { ctx, size in draw(&ctx, size) }
    }

    // Everything is a smooth function of growth, so a single prayer always shows.
    private var height: Double { min(1, 0.12 + 0.11 * growth) }          // full height at 8 prayers
    private var leafPairs: Double { min(6, growth) }                       // a new pair of leaves for each prayer up to 6
    private var buds: Double { max(0, min(5, (growth - 7) * 0.7)) }        // buds from the 8th prayer, up to 5
    private var budSize: Double { min(1, 0.45 + 0.06 * max(0, growth - 7)) }

    private func draw(_ ctx: inout GraphicsContext, _ s: CGSize) {
        let w = s.width, h = s.height
        let base = CGPoint(x: w / 2, y: h * 0.93)

        // Soil mound.
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.88, width: w * 0.64, height: h * 0.1)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x5A3E2B), Color(hex: 0x2E1F16)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.88), endPoint: CGPoint(x: 0, y: h * 0.98)))
        if growth < 0.5 && bloom == 0 {
            // A seed resting in the soil.
            ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - w * 0.06, y: h * 0.865, width: w * 0.12, height: h * 0.05)),
                     with: .color(Color(hex: 0xC9A06B)))
            return
        }

        let stemTop = CGPoint(x: base.x + w * 0.04 * lean(0), y: base.y - h * 0.82 * height)
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: stemTop, control: CGPoint(x: base.x - w * 0.06 * lean(1), y: (base.y + stemTop.y) / 2))
        ctx.stroke(stem, with: .color(Color(hex: 0x4E8A3A)), style: StrokeStyle(lineWidth: max(1.5, w * 0.035 * (0.6 + 0.4 * height)), lineCap: .round))

        // Leaves, in pairs from the bottom up; the newest pair fades in.
        let pairs = Int(leafPairs.rounded(.up))
        for i in 0..<pairs {
            let fade = min(1, leafPairs - Double(i))
            guard fade > 0 else { continue }
            let t = 0.25 + 0.65 * (Double(i) + 0.5) / max(6, leafPairs)
            let p = point(on: base, stemTop, w: w, t: t)
            let len = w * (0.30 - 0.025 * Double(i)) * (0.5 + 0.5 * height) * fade
            for side in [-1.0, 1.0] {
                leaf(&ctx, at: p, angle: side * (0.95 - 0.08 * Double(i)) + 0.12 * lean(i + 2), length: len, opacity: fade)
            }
        }

        // Buds while growing; open flowers once answered.
        let heads = bloom > 0 ? max(3, Int(buds.rounded(.up))) : Int(buds.rounded(.up))
        for i in 0..<heads {
            let fade = bloom > 0 ? 1 : min(1, buds - Double(i))
            guard fade > 0 else { continue }
            let at: CGPoint
            if i == 0 { at = stemTop } else {
                let side: Double = i % 2 == 0 ? 1 : -1
                let p = point(on: base, stemTop, w: w, t: 0.62 + 0.08 * Double(i / 2))
                at = CGPoint(x: p.x + side * w * 0.2, y: p.y - h * 0.05)
                var twig = Path(); twig.move(to: p); twig.addLine(to: at)
                ctx.stroke(twig, with: .color(Color(hex: 0x4E8A3A).opacity(fade)), lineWidth: max(1, w * 0.018))
            }
            let r = w * 0.075 * budSize
            if bloom > 0 {
                flowerHead(&ctx, at: at, radius: r * (1 + 1.4 * bloom), open: bloom)
            } else {
                var bud = Path(ellipseIn: CGRect(x: at.x - r * 0.7, y: at.y - r * 1.3, width: r * 1.4, height: r * 2))
                ctx.fill(bud, with: .linearGradient(Gradient(colors: [flower.opacity(fade), Color(hex: 0x5E9C45).opacity(fade)]),
                                                    startPoint: CGPoint(x: at.x, y: at.y - r * 1.3), endPoint: CGPoint(x: at.x, y: at.y + r * 0.7)))
            }
        }
    }

    private func lean(_ i: Int) -> Double { Double(((seed &+ i &* 7919) % 9) - 4) / 4 }

    private func point(on base: CGPoint, _ top: CGPoint, w: CGFloat, t: Double) -> CGPoint {
        CGPoint(x: base.x + (top.x - base.x) * t - w * 0.03 * lean(1) * sin(.pi * t), y: base.y + (top.y - base.y) * t)
    }

    /// A leaf pointing up-and-out: `angle` 0 is straight up, positive leans right.
    private func leaf(_ ctx: inout GraphicsContext, at p: CGPoint, angle: Double, length: CGFloat, opacity: Double) {
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: -length * 0.38))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: length * 0.38))
        let shape = path.applying(CGAffineTransform(rotationAngle: CGFloat(-.pi / 2 + angle)).concatenating(CGAffineTransform(translationX: p.x, y: p.y)))
        let tip = CGPoint(x: p.x + length * CGFloat(sin(angle)), y: p.y - length * CGFloat(cos(angle)))
        ctx.fill(shape, with: .linearGradient(Gradient(colors: [Color(hex: 0x3F7A31).opacity(opacity), Color(hex: 0x7CC25A).opacity(opacity)]),
                                              startPoint: p, endPoint: tip))
    }

    private func flowerHead(_ ctx: inout GraphicsContext, at c: CGPoint, radius r: CGFloat, open: Double) {
        let petals = 6
        for k in 0..<petals {
            let a = Double(k) / Double(petals) * 2 * .pi + Double(seed % 5) * 0.2
            let pc = CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.55 * open, y: c.y + CGFloat(sin(a)) * r * 0.55 * open)
            ctx.fill(Path(ellipseIn: CGRect(x: pc.x - r * 0.5, y: pc.y - r * 0.5, width: r, height: r)),
                     with: .radialGradient(Gradient(colors: [flower.opacity(0.85), flower]), center: pc, startRadius: 0, endRadius: r * 0.5))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.25, y: c.y - r * 0.25, width: r * 0.5, height: r * 0.5)), with: .color(Color(hex: 0xF4C46A)))
    }
}
