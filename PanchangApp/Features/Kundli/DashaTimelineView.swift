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
                            AlmanacRow(
                                label: ad.planet,
                                value: "\(Self.f(ad.start)) – \(Self.f(ad.end))",
                                dotColor: ad.isCurrent ? Palette.accent : nil
                            )
                            .padding(.leading, 12).padding(.vertical, 2)
                        }
                    }
                } label: {
                    AlmanacRow(
                        label: md.planet,
                        value: "\(Self.year(md.start)) – \(Self.year(md.end))",
                        dotColor: md.isCurrent ? Palette.accent : nil
                    )
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
