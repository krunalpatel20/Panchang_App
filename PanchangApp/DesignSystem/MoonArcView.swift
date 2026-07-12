import SwiftUI

/// The signature graphic: a thin semicircular arc for the lunar month, ticks at the
/// quarter points, and a glowing marker at today's phase (0 = new … 0.5 = full … 1 = new).
struct MoonArcView: View {
    let phase: Double
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 100, size.height / 60)
            let ox = (size.width - 100 * scale) / 2
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: ox + x * scale, y: y * scale)
            }
            let cx = 50.0, cy = 50.0, r = 38.0

            var arc = Path()
            arc.addArc(center: pt(cx, cy), radius: r * scale,
                       startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            context.stroke(arc, with: .color(Palette.hairline), lineWidth: 1.2 * scale)

            for t in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let a = Double.pi * (1 - t)
                var tick = Path()
                tick.move(to: pt(cx - (r - 3) * cos(a), cy - (r - 3) * sin(a)))
                tick.addLine(to: pt(cx - (r + 3) * cos(a), cy - (r + 3) * sin(a)))
                context.stroke(tick, with: .color(Palette.hairline), lineWidth: 1 * scale)
            }

            let a = Double.pi * (1 - min(max(phase, 0), 1))
            let marker = pt(cx - r * cos(a), cy - r * sin(a))
            let glow = Path(ellipseIn: CGRect(x: marker.x - 9 * scale, y: marker.y - 9 * scale,
                                              width: 18 * scale, height: 18 * scale))
            context.fill(glow, with: .color(accent.opacity(0.14)))
            let dot = Path(ellipseIn: CGRect(x: marker.x - 4.5 * scale, y: marker.y - 4.5 * scale,
                                             width: 9 * scale, height: 9 * scale))
            context.fill(dot, with: .color(accent))
        }
    }
}
