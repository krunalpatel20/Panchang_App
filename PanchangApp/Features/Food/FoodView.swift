import SwiftUI

/// The one visually distinct block in the deep dive — a hairline-bordered card
/// with the food note and, if present, a quiet recipe link. Embeddable in
/// FestivalDetailView or used standalone.
struct FoodView: View {
    let food: FoodNote
    var accent: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeader("THE FOOD")
                .accessibilityAddTraits(.isHeader)

            Text(food.note)
                .font(.bodyProse)
                .foregroundStyle(Palette.inkStrong)
                .lineSpacing(6)

            if let url = food.recipeLink {
                Link(destination: url) {
                    QuietLink(label: "See recipe", color: accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }
}

#Preview {
    FoodView(food: FoodNote(
        note: "On Ekadashi, avoid grains. Sabudana khichdi, fruits, and milk-based dishes are traditional fasting foods.",
        recipeLink: URL(string: "https://example.com/sabudana-khichdi")
    ))
    .padding()
    .background(Palette.paper)
}
