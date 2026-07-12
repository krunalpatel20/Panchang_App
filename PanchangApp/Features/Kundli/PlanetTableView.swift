import SwiftUI
import PanchangKit

/// A table of the nine grahas plus lagna: sign, degrees-in-sign, nakshatra, retrograde marker.
struct PlanetTableView: View {
    let positions: PlanetaryPositions

    var body: some View {
        VStack(spacing: 0) {
            row(positions.lagna, isLagna: true)
            HairlineDivider()
            ForEach(positions.planets) { planet in
                row(planet, isLagna: false)
                if planet.id != positions.planets.last?.id { HairlineDivider() }
            }
        }
    }

    private func row(_ p: PlanetaryPositions.Planet, isLagna: Bool) -> some View {
        HStack {
            Text(p.name)
                .font(.bodySans())
                .fontWeight(isLagna ? .semibold : .regular)
                .foregroundStyle(Palette.inkStrong)
                .frame(width: 78, alignment: .leading)
            Text(p.rashiName)
                .font(.bodySans())
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 84, alignment: .leading)
            Text(Self.degreesInSign(p.longitude))
                .font(.dataSans)
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 64, alignment: .trailing)
            Spacer()
            if p.isRetrograde {
                Text("℞").foregroundStyle(Palette.inauspicious).help("Retrograde")
            }
            Text(isLagna ? "—" : PanchangNames.nakshatra[p.nakshatra])
                .font(.tagSans)
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 96, alignment: .trailing)
        }
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
