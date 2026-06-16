import SwiftUI

/// Compact food-layer card. Embeddable in FestivalDetailView or used standalone.
struct FoodView: View {
    let food: FoodNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("In the Kitchen", systemImage: "fork.knife")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(food.note)
                .font(.body)
                .foregroundStyle(.primary)

            if let url = food.recipeLink {
                Link(destination: url) {
                    Label("See recipe", systemImage: "arrow.up.right")
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    FoodView(food: FoodNote(
        note: "On Ekadashi, avoid grains. Sabudana khichdi, fruits, and milk-based dishes are traditional fasting foods.",
        recipeLink: URL(string: "https://example.com/sabudana-khichdi")
    ))
    .padding()
}
