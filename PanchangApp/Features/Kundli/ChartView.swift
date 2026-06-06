import SwiftUI
import PanchangKit

/// Kundli chakra. North-Indian = fixed houses (lagna at top, signs rotate); South-Indian =
/// fixed signs (Pisces top-left, clockwise), planets drop into their sign cell.
struct ChartView: View {
    let positions: PlanetaryPositions
    let style: String   // "north" | "south"

    private var lagnaRashi: Int { positions.lagna.rashi }

    /// Planet abbreviations grouped by rashi (0…11).
    private var planetsByRashi: [Int: [String]] {
        var map: [Int: [String]] = [:]
        for (i, p) in positions.planets.enumerated() {
            map[p.rashi, default: []].append(Self.abbrev[i])
        }
        return map
    }
    static let abbrev = ["Su","Mo","Ma","Me","Ju","Ve","Sa","Ra","Ke"]

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if style == "south" {
                    southChart(side: side)
                } else {
                    northChart(side: side)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - South Indian (fixed signs, 4×4 grid)

    /// Sign index → (row, col) in the 4×4 grid. Pisces top-left, clockwise.
    private static let southCells: [Int: (Int, Int)] = [
        11:(0,0), 0:(0,1), 1:(0,2), 2:(0,3),
        3:(1,3), 4:(2,3), 5:(3,3),
        6:(3,2), 7:(3,1), 8:(3,0),
        9:(2,0), 10:(1,0),
    ]

    private func southChart(side: CGFloat) -> some View {
        let cell = side / 4
        return ZStack(alignment: .topLeading) {
            Rectangle().stroke(.primary, lineWidth: 1).frame(width: side, height: side)
            ForEach(0..<12, id: \.self) { sign in
                let (r, c) = Self.southCells[sign]!
                signCell(sign: sign, isLagna: sign == lagnaRashi)
                    .frame(width: cell, height: cell)
                    .overlay(Rectangle().stroke(.primary.opacity(0.4), lineWidth: 0.5))
                    .offset(x: CGFloat(c) * cell, y: CGFloat(r) * cell)
            }
            Text("Rāśi").font(.caption2).foregroundStyle(.secondary)
                .frame(width: cell * 2, height: cell * 2)
                .offset(x: cell, y: cell)
        }
    }

    private func signCell(sign: Int, isLagna: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                Text(PanchangNames.rashi[sign]).font(.system(size: 8)).foregroundStyle(.secondary)
                if isLagna { Text("Asc").font(.system(size: 8)).foregroundStyle(.orange) }
            }
            Text((planetsByRashi[sign] ?? []).joined(separator: " "))
                .font(.system(size: 11, weight: .medium))
            Spacer(minLength: 0)
        }
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isLagna ? Color.orange.opacity(0.08) : .clear)
    }

    // MARK: - North Indian (fixed houses, signs rotate from lagna)

    /// House anchor centres as fractions of the square, house 1…12.
    private static let northAnchors: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.25), CGPoint(x: 0.25, y: 0.12), CGPoint(x: 0.12, y: 0.25),
        CGPoint(x: 0.25, y: 0.50), CGPoint(x: 0.12, y: 0.75), CGPoint(x: 0.25, y: 0.88),
        CGPoint(x: 0.50, y: 0.75), CGPoint(x: 0.75, y: 0.88), CGPoint(x: 0.88, y: 0.75),
        CGPoint(x: 0.75, y: 0.50), CGPoint(x: 0.88, y: 0.25), CGPoint(x: 0.75, y: 0.12),
    ]

    private func northChart(side: CGFloat) -> some View {
        ZStack {
            Path { p in
                let s = side
                p.addRect(CGRect(x: 0, y: 0, width: s, height: s))
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: s, y: s))
                p.move(to: CGPoint(x: s, y: 0)); p.addLine(to: CGPoint(x: 0, y: s))
                p.move(to: CGPoint(x: s/2, y: 0)); p.addLine(to: CGPoint(x: s, y: s/2))
                p.addLine(to: CGPoint(x: s/2, y: s)); p.addLine(to: CGPoint(x: 0, y: s/2))
                p.addLine(to: CGPoint(x: s/2, y: 0))
            }
            .stroke(.primary, lineWidth: 1)

            ForEach(0..<12, id: \.self) { house in
                let sign = (lagnaRashi + house) % 12
                let anchor = Self.northAnchors[house]
                VStack(spacing: 1) {
                    Text("\(sign + 1)").font(.system(size: 8)).foregroundStyle(.secondary)
                    Text((planetsByRashi[sign] ?? []).joined(separator: " "))
                        .font(.system(size: 10, weight: .medium)).multilineTextAlignment(.center)
                    if house == 0 { Text("Asc").font(.system(size: 8)).foregroundStyle(.orange) }
                }
                .frame(width: side * 0.22)
                .position(x: anchor.x * side, y: anchor.y * side)
            }
        }
    }
}
