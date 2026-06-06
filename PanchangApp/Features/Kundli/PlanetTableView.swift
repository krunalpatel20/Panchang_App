import SwiftUI
import PanchangKit

/// A table of the nine grahas plus lagna: sign, degrees-in-sign, nakshatra, retrograde marker.
struct PlanetTableView: View {
    let positions: PlanetaryPositions

    var body: some View {
        VStack(spacing: 0) {
            row(positions.lagna, isLagna: true)
            Divider()
            ForEach(positions.planets) { planet in
                row(planet, isLagna: false)
                if planet.id != positions.planets.last?.id { Divider() }
            }
        }
    }

    private func row(_ p: PlanetaryPositions.Planet, isLagna: Bool) -> some View {
        HStack {
            Text(p.name)
                .fontWeight(isLagna ? .semibold : .regular)
                .frame(width: 78, alignment: .leading)
            Text(p.rashiName)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(Self.degreesInSign(p.longitude))
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
            Spacer()
            if p.isRetrograde {
                Text("℞").foregroundStyle(.orange).help("Retrograde")
            }
            Text(isLagna ? "—" : PanchangNames.nakshatra[p.nakshatra])
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(p.name), \(p.rashiName), \(Self.degreesInSign(p.longitude))\(p.isRetrograde ? ", retrograde" : "")")
    }

    /// Degrees within the current sign, formatted as `12°34′`.
    static func degreesInSign(_ longitude: Double) -> String {
        let inSign = longitude.truncatingRemainder(dividingBy: 30)
        let deg = Int(inSign)
        let min = Int((inSign - Double(deg)) * 60)
        return String(format: "%d°%02d′", deg, min)
    }
}
