import SwiftUI
import EventKit

/// Full deep-dive view for a resolved content entry. Pure display — data passed in.
struct FestivalDetailView: View {
    let content: ResolvedContent
    var mood: DayMood = .ordinary

    @State private var reminderAlert: ReminderAlert?

    private struct ReminderAlert: Identifiable {
        let id = UUID()
        let message: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                deepDiveSections
                FoodView(food: content.voice.food, accent: mood.accent)
                    .padding(.bottom, 28)
                if let action = content.action {
                    actionLink(action)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(content.entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $reminderAlert) { alert in
            Alert(title: Text("Reminders"), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.entry.name)
                .font(.titleSerif)
                .foregroundStyle(Palette.ink)
            if let tagline = content.entry.tagline {
                Text(tagline)
                    .font(.tagSans)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(.bottom, 26)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Deep dive sections

    @ViewBuilder
    private var deepDiveSections: some View {
        let dive = content.voice.deepDive

        sectionBlock(title: "WHAT IT IS", text: dive.whatItIs)
        sectionBlock(title: "MYTHOLOGY", text: dive.mythology)
        sectionBlock(title: "HISTORY", text: dive.history)
        sectionBlock(title: "REGIONAL", text: dive.regional)
        sectionBlock(title: "WHAT TO DO", text: dive.whatToDo)
    }

    private func sectionBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeader(title)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.bodyProse)
                .foregroundStyle(Palette.inkStrong)
                .lineSpacing(6)
        }
        .padding(.bottom, 28)
    }

    // MARK: - Action link

    private func actionLink(_ action: ContentAction) -> some View {
        Button {
            Task { await handleAction(action) }
        } label: {
            QuietLink(label: action.label, color: mood.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 14)
    }

    // MARK: - Action handling

    private func handleAction(_ action: ContentAction) async {
        switch action.kind {
        case .call:
            if let number = action.payload,
               let url = URL(string: "tel://\(number.filter { $0.isNumber })") {
                await UIApplication.shared.open(url)
            }
        case .openMaps:
            if let address = action.payload,
               let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "maps://?q=\(encoded)") {
                await UIApplication.shared.open(url)
            }
        case .note:
            if let text = action.payload {
                UIPasteboard.general.string = text
            }
        case .addReminder:
            await addReminder(notes: action.payload)
        }
    }

    private func addReminder(notes: String?) async {
        let store = EKEventStore()
        do {
            guard try await store.requestFullAccessToReminders() else {
                reminderAlert = ReminderAlert(message: "Reminders access was denied. Enable it in Settings to add reminders from here.")
                return
            }
        } catch {
            reminderAlert = ReminderAlert(message: "Couldn't request Reminders access: \(error.localizedDescription)")
            return
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = content.entry.name
        reminder.notes = notes
        reminder.calendar = store.defaultCalendarForNewReminders()

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: content.date)
        comps.hour = 7
        reminder.dueDateComponents = comps
        reminder.addAlarm(EKAlarm(absoluteDate: Calendar.current.date(from: comps) ?? content.date))

        do {
            try store.save(reminder, commit: true)
            reminderAlert = ReminderAlert(message: "Added to Reminders.")
        } catch {
            reminderAlert = ReminderAlert(message: "Couldn't save the reminder: \(error.localizedDescription)")
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
            advance2: nil,
            eve: VoiceLayer(text: "Tomorrow is Ekadashi — prepare your fast.", daysBefore: nil),
            morning: VoiceLayer(text: "Today is Ekadashi. A good day for fasting, prayer, and stillness.", daysBefore: nil),
            offsets: nil,
            deepDive: dive,
            food: food
        )
        let entry = ContentEntry(
            id: "ekadashi",
            kind: .tithi,
            tier: 2,
            name: "Ekadashi",
            tagline: "the monthly fast",
            festivalType: "vrat",
            match: ContentMatch(anchor: .tithi, tithi: 11, paksha: nil, masaIndex: nil, rashiIndex: nil),
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
