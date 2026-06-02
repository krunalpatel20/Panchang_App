import SwiftUI
import PanchangKit

struct DayCell: View {
    let cell: MonthCell

    var body: some View {
        VStack(spacing: 3) {
            // Civil date number
            ZStack {
                if cell.isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 30, height: 30)
                }
                Text("\(cell.day)")
                    .font(.system(size: 16, weight: cell.isToday ? .bold : .regular))
                    .foregroundStyle(cell.isToday ? .white : .primary)
            }
            .frame(height: 32)

            // Indicators row: paksha dot + optional festival dot
            HStack(spacing: 3) {
                Circle()
                    .fill(pakshaColor)
                    .frame(width: 5, height: 5)
                if cell.hasFestival {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }

            // Tithi name
            Text(cell.tithiName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 68)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cell.isToday ? Color.accentColor.opacity(0.07) : Color.clear)
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to see full panchang")
    }

    private var pakshaColor: Color {
        cell.paksha == .shukla ? Color.orange.opacity(0.8) : Color.indigo.opacity(0.8)
    }

    private var accessibilityLabel: String {
        var label = "\(cell.day), \(cell.paksha.rawValue) \(cell.tithiName)"
        if cell.isToday { label += ", today" }
        if !cell.festivalNames.isEmpty { label += ", \(cell.festivalNames.joined(separator: ", "))" }
        return label
    }
}
