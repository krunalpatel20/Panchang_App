import SwiftUI

/// Full deep-dive view for a resolved content entry. Pure display — data passed in.
struct FestivalDetailView: View {
    let content: ResolvedContent

    var body: some View {
        List {
            deepDiveSections
            foodSection
            if let action = content.action {
                actionSection(action)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(content.entry.id.replacing("_", with: " ").capitalized)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Deep dive sections

    @ViewBuilder
    private var deepDiveSections: some View {
        let dive = content.voice.deepDive

        Section("What It Is") {
            Text(dive.whatItIs)
                .font(.body)
                .foregroundStyle(.primary)
        }

        Section("Mythology") {
            Text(dive.mythology)
                .font(.body)
                .foregroundStyle(.primary)
        }

        Section("History") {
            Text(dive.history)
                .font(.body)
                .foregroundStyle(.primary)
        }

        Section("Regional") {
            Text(dive.regional)
                .font(.body)
                .foregroundStyle(.primary)
        }

        Section("What To Do") {
            Text(dive.whatToDo)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Food section

    private var foodSection: some View {
        Section {
            FoodView(food: content.voice.food)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    // MARK: - Action section

    private func actionSection(_ action: ContentAction) -> some View {
        Section {
            Button {
                handleAction(action)
            } label: {
                Label(action.label, systemImage: actionSystemImage(for: action.kind))
                    .font(.body.weight(.medium))
            }
        }
    }

    // MARK: - Action handling

    private func handleAction(_ action: ContentAction) {
        switch action.kind {
        case .call:
            if let number = action.payload,
               let url = URL(string: "tel://\(number.filter { $0.isNumber })") {
                UIApplication.shared.open(url)
            }
        case .openMaps:
            if let address = action.payload,
               let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "maps://?q=\(encoded)") {
                UIApplication.shared.open(url)
            }
        case .note:
            if let text = action.payload {
                UIPasteboard.general.string = text
            }
        case .addReminder:
            // Placeholder: reminder scheduling wired at integration time
            break
        }
    }

    private func actionSystemImage(for kind: ContentAction.Kind) -> String {
        switch kind {
        case .call: return "phone"
        case .addReminder: return "bell.badge"
        case .openMaps: return "map"
        case .note: return "doc.on.clipboard"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FestivalDetailView(content: .fixture)
    }
}

// MARK: - Fixture

extension ResolvedContent {
    static var fixture: ResolvedContent {
        let dive = DeepDive(
            whatItIs: "Ekadashi is the eleventh day of each lunar fortnight, observed twice a month across both paksha cycles. It is one of the most widely observed fasting days in the Hindu calendar.",
            mythology: "According to the Padma Purana, a demon named Mura terrorised the gods. Vishnu fought him for a thousand years, then rested in a cave. A divine power emerged from his body, slew Mura, and was named Ekadashi — the eleventh — by Vishnu himself.",
            history: "References to Ekadashi fasting appear in the Vishnu Purana and the Bhagavata Purana. The practice of marking the eleventh tithi as a day of austerity dates back at least two millennia.",
            regional: "In Maharashtra, Ashadhi and Kartiki Ekadashi draw hundreds of thousands of Varkari pilgrims to Pandharpur. In Gujarat, devotees visit Vishnu temples at dawn. In South India, Vaikunta Ekadashi in Margazhi month is especially sacred.",
            whatToDo: "Fast from grains and beans. Spend time in prayer, chanting the Vishnu Sahasranama or the Hare Krishna mahamantra. Visit a Vishnu or Vithoba temple if possible. Break fast at the correct time the next day (Dwadashi)."
        )
        let food = FoodNote(
            note: "Grains, lentils, and most beans are avoided. Sabudana (tapioca) khichdi, sendha namak (rock salt), fruits, milk, yoghurt, and nuts are all permitted fasting foods.",
            recipeLink: URL(string: "https://example.com/sabudana-khichdi")
        )
        let voice = VoiceLayers(
            advance: VoiceLayer(text: "Ekadashi arrives in two days.", daysBefore: 2),
            eve: VoiceLayer(text: "Tomorrow is Ekadashi — prepare your fast.", daysBefore: nil),
            morning: VoiceLayer(text: "Today is Ekadashi. A good day for fasting, prayer, and stillness.", daysBefore: nil),
            deepDive: dive,
            food: food
        )
        let entry = ContentEntry(
            id: "ekadashi",
            kind: .tithi,
            tier: 2,
            match: ContentMatch(anchor: .tithi, tithi: 11, paksha: nil, masaIndex: nil),
            variants: [],
            voice: voice,
            triggers: [],
            action: ContentAction(kind: .note, label: "Copy fast-break time", payload: "Break Ekadashi fast between sunrise and 09:24 AM on Dwadashi."),
            regions: [],
            audioScript: nil,
            almanacBlurb: nil
        )
        return ResolvedContent(entry: entry, voice: voice, triggers: [], action: entry.action, date: Date())
    }
}
