import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Panchang",
                systemImage: "sun.horizon",
                description: Text("Today's panchang will appear here.")
            )
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
}
