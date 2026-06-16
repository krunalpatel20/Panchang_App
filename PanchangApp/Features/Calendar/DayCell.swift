import SwiftUI
import PanchangKit

struct DayCell: View {
    let cell: MonthCell

    var body: some View {
        VStack(spacing: 2) {
            // Date number — today gets accent fill, festival days get type-tinted fill
            ZStack {
                Circle()
                    .fill(dateFill)
                    .frame(width: 30, height: 30)
                Text("\(cell.day)")
                    .font(.system(size: 16, weight: cell.isToday ? .bold : .regular))
                    .foregroundStyle(dateTextColor)
            }
            .frame(height: 32)

            // Tithi — paksha initial + name
            Text(tithiLabel)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

            // Festival name(s) — colored by type, empty spacer when none
            if cell.hasFestival {
                Text(cell.festivals.map(\.name).joined(separator: " · "))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(festivalColor ?? .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
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
        case .festival:    return .orange
        case .vrat:        return .indigo
        case .observance:  return .teal
        case nil:          return nil
        }
    }

    private var dateFill: Color {
        if cell.isToday { return Color.accentColor }
        if let c = festivalColor { return c.opacity(0.18) }
        return .clear
    }

    private var dateTextColor: Color {
        if cell.isToday { return .white }
        if festivalColor != nil { return festivalColor! }
        return .primary
    }

    private var cellBackground: Color {
        cell.isToday ? Color.accentColor.opacity(0.06) : .clear
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
