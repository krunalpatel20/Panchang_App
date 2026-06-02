import SwiftUI
import SwiftData
import PanchangKit

struct CalendarView: View {
    @State private var vm = CalendarViewModel()
    @Query private var savedLocations: [SavedLocation]
    @Query private var prefsQuery: [Preferences]

    private let weekdaySymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var activeLocation: GeoLocation {
        if let loc = savedLocations.first(where: { $0.isActive }) {
            return GeoLocation(latitude: loc.latitude, longitude: loc.longitude,
                               timeZoneIdentifier: loc.timeZoneIdentifier)
        }
        return GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
    }

    private var config: CalendarConfig {
        prefsQuery.first?.calendarPreset == "north_indian" ? .northIndian : .gujaratiWestern
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                Divider()
                if vm.isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else {
                    grid
                }
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .sheet(isPresented: $vm.showDatePicker) { datepickerSheet }
            .onAppear { vm.loadCells(location: activeLocation, config: config) }
            .onChange(of: savedLocations.first(where: { $0.isActive })?.name) { _, _ in
                vm.loadCells(location: activeLocation, config: config)
            }
            .onChange(of: prefsQuery.first?.calendarPreset) { _, _ in
                vm.loadCells(location: activeLocation, config: config)
            }
            .navigationDestination(for: MonthCell.self) { cell in
                DayDetailView(year: cell.year, month: cell.month, day: cell.day,
                              location: activeLocation, config: config)
            }
        }
    }

    // MARK: - Subviews

    private var monthHeader: some View {
        HStack {
            Button { vm.goToPreviousMonth(location: activeLocation, config: config) } label: {
                Image(systemName: "chevron.left").fontWeight(.semibold).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Button { vm.showDatePicker = true } label: {
                Text(monthTitle).font(.title3.weight(.semibold))
            }
            .accessibilityLabel("Jump to date")

            Spacer()

            Button { vm.goToNextMonth(location: activeLocation, config: config) } label: {
                Image(systemName: "chevron.right").fontWeight(.semibold).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 4)
    }

    private var grid: some View {
        let leadingBlanks = leadingBlankCount()
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 68) }
                ForEach(vm.cells) { cell in
                    NavigationLink(value: cell) { DayCell(cell: cell) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4).padding(.bottom, 12)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { vm.jumpTo(date: Date(), location: activeLocation, config: config) } label: {
                Text("Today")
            }
        }
    }

    private var datepickerSheet: some View {
        NavigationStack {
            DatePicker("Select date", selection: $vm.pickerDate,
                       in: datePickerRange, displayedComponents: .date)
                .datePickerStyle(.graphical).padding()
                .navigationTitle("Jump to Date").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") {
                            vm.showDatePicker = false
                            vm.jumpTo(date: vm.pickerDate, location: activeLocation, config: config)
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { vm.showDatePicker = false }
                    }
                }
        }
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        var comps = DateComponents()
        comps.year = vm.displayedYear; comps.month = vm.displayedMonth; comps.day = 1
        return fmt.string(from: Calendar.current.date(from: comps) ?? Date())
    }

    private func leadingBlankCount() -> Int {
        var comps = DateComponents()
        comps.year = vm.displayedYear; comps.month = vm.displayedMonth; comps.day = 1
        guard let firstDay = Calendar.current.date(from: comps) else { return 0 }
        return Calendar.current.component(.weekday, from: firstDay) - 1
    }

    private var datePickerRange: ClosedRange<Date> {
        let cal = Calendar(identifier: .gregorian)
        return cal.date(from: DateComponents(year: 1900, month: 1, day: 1))!
            ... cal.date(from: DateComponents(year: 2100, month: 12, day: 31))!
    }
}
