import SwiftUI
import PanchangKit

/// Vimshottari mahadasha timeline. The current mahadasha is highlighted and expands to show
/// its antardashas.
struct DashaTimelineView: View {
    let dasha: VimshottariDasha

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(dasha.mahadashas) { md in
                DisclosureGroup(isExpanded: .constant(md.isCurrent)) {
                    if md.isCurrent {
                        ForEach(dasha.currentAntardashas) { ad in
                            HStack {
                                Text(ad.planet)
                                    .font(.caption)
                                    .foregroundStyle(ad.isCurrent ? Color.accentColor : .secondary)
                                    .fontWeight(ad.isCurrent ? .semibold : .regular)
                                Spacer()
                                Text("\(Self.f(ad.start)) – \(Self.f(ad.end))")
                                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .padding(.leading, 12).padding(.vertical, 2)
                        }
                    }
                } label: {
                    HStack {
                        Text(md.planet)
                            .fontWeight(md.isCurrent ? .bold : .regular)
                            .foregroundStyle(md.isCurrent ? Color.accentColor : .primary)
                        Spacer()
                        Text("\(Self.year(md.start)) – \(Self.year(md.end))")
                            .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .disabled(!md.isCurrent)
            }
        }
    }

    private static func f(_ d: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "dd MMM yyyy"; return fmt.string(from: d)
    }
    private static func year(_ d: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy"; return fmt.string(from: d)
    }
}
