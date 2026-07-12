import SwiftUI
import PanchangKit

struct DayCell: View {
    let cell: MonthCell

    var body: some View {
        VStack(spacing: 2) {
            // Date number — today gets an accent ring, festival days get a type-tinted fill
            ZStack {
                Circle()
                    .fill(dateFill)
                    .frame(width: 30, height: 30)
                if cell.isToday {
                    Circle()
                        .strokeBorder(Palette.accent, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }
                Text("\(cell.day)")
                    .font(.dataSans)
                    .fontWeight(cell.isToday ? .bold : .regular)
                    .foregroundStyle(dateTextColor)
            }
            .frame(height: 32)

            // Tithi — paksha initial + name, moon-phase glyph for Purnima/Amavasya
            HStack(spacing: 2) {
                Text(tithiLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let moonGlyph {
                    Image(systemName: moonGlyph)
                        .font(.system(size: 8))
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .frame(maxWidth: .infinity)

            // Festival name(s)
            if cell.hasFestival {
                Text(cell.festivals.map(\.name).joined(separator: " · "))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(festivalColor ?? Palette.inkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 72)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cellBackground)
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to see full panchang")
    }

    // MARK: - Colors

    private var festivalColor: Color? {
        switch cell.topFestivalType {
        case .festival:    return Palette.festival
        case .vrat:        return Palette.auspicious
        case .observance:  return Palette.inkMuted
        case nil:          return nil
        }
    }

    private var dateFill: Color {
        if cell.isToday { return .clear }
        if let c = festivalColor { return c.opacity(0.10) }
        return .clear
    }

    private var dateTextColor: Color {
        if cell.isToday { return Palette.accent }
        if festivalColor != nil { return festivalColor! }
        return Palette.inkStrong
    }

    private var cellBackground: Color {
        cell.isToday ? Palette.accent.opacity(0.06) : .clear
    }

    /// SF Symbol for full/new moon days, nil otherwise.
    private var moonGlyph: String? {
        switch cell.tithiName {
        case "Purnima": return "moonphase.full.circle"
        case "Amavasya": return "moonphase.new.circle"
        default: return nil
        }
    }

    // MARK: - Labels

    private var tithiLabel: String {
        let prefix = cell.paksha == .shukla ? "S" : "K"
        return "\(prefix)· \(cell.tithiName)"
    }

    private var accessibilityLabel: String {
        var parts = ["\(cell.day)", "\(cell.paksha.rawValue) \(cell.tithiName)"]
        if cell.isToday { parts.append("today") }
        parts.append(contentsOf: cell.festivalNames)
        return parts.joined(separator: ", ")
    }
}
