import SwiftUI

/// Shows the day's content heartbeat — all resolved entries in priority order.
struct HeartbeatListView: View {
    let items: [ResolvedContent]

    var body: some View {
        List(items) { item in
            NavigationLink(destination: FestivalDetailView(content: item, mood: .ordinary)) {
                HeartbeatRow(item: item)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Today's Festivals")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Row

private struct HeartbeatRow: View {
    let item: ResolvedContent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.entry.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if item.entry.tier == 1 {
                    TierBadge()
                }
            }

            Text(item.voice.morning.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tier badge

private struct TierBadge: View {
    var body: some View {
        Text("Major")
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Palette.festival.opacity(0.15), in: Capsule())
            .foregroundStyle(Palette.festival)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HeartbeatListView(items: [.fixture])
    }
}
