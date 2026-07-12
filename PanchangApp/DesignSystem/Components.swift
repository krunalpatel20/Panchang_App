import SwiftUI

/// The tracked-caption section header used on every non-form screen —
/// "COMING UP", "WHAT IT IS", "THE FOOD", etc.
struct EditorialSectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.trackedCaption)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Palette.inkFaint)
    }
}

/// `Divider().overlay(Palette.hairline)` — the one rule style used everywhere.
struct HairlineDivider: View {
    var opacity: Double = 1

    var body: some View {
        Divider().overlay(Palette.hairline.opacity(opacity))
    }
}

/// A solid center with a soft halo — keys auspicious/inauspicious/neutral rows
/// without reaching for an SF Symbol. Echoes the moon-arc marker motif.
struct AccentDot: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.14)).frame(width: 14, height: 14)
            Circle().fill(color).frame(width: 6, height: 6)
        }
        .accessibilityHidden(true)
    }
}

/// A single almanac data row: label, value, optional trailing detail, optional
/// leading `AccentDot`. Deliberately no SF Symbol leading icons — the
/// icon-per-row look is the single biggest "settings screen" signal.
struct AlmanacRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var dotColor: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let dotColor {
                AccentDot(color: dotColor)
            }
            Text(label)
                .font(.bodySans())
                .foregroundStyle(Palette.inkStrong)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.dataSans)
                    .foregroundStyle(Palette.inkSecondary)
                if let detail {
                    Text(detail)
                        .font(.tagSans)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(value)\(detail.map { ", \($0)" } ?? "")"))
    }
}

/// The italic-serif "go deeper" / "Full panchang" link, parameterized by color
/// so callers can pass the current `DayMood.accent` or a muted default.
struct QuietLink: View {
    let label: String
    var color: Color = Palette.inkMuted

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 15, design: .serif))
                .italic()
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(color)
    }
}
