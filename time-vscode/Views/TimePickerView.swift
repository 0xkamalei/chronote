import SwiftUI

struct TimePickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedDateRange: DateRange
    @Binding var selectedPreset: DateRangePreset?

    @State private var startDate: Date
    @State private var endDate: Date

    init(isPresented: Binding<Bool>, selectedDateRange: Binding<DateRange>, selectedPreset: Binding<DateRangePreset?>) {
        _isPresented = isPresented
        _selectedDateRange = selectedDateRange
        _selectedPreset = selectedPreset
        _startDate = State(initialValue: selectedDateRange.wrappedValue.startDate)
        _endDate = State(initialValue: selectedDateRange.wrappedValue.endDate)
    }

    var body: some View {
        let pastDayPresets: [DateRangePreset] = [.past7Days, .past15Days, .past30Days, .past90Days, .past365Days]
        let currentPeriodPresets: [DateRangePreset] = [.today, .thisWeek, .thisMonth, .thisQuarter, .thisYear]
        let previousPeriodPresets: [DateRangePreset] = [.yesterday, .lastWeek, .lastMonth]

        HStack(alignment: .top, spacing: 0) {
            // Column 1: Past Presets
            VStack(alignment: .leading, spacing: 4) {
                ForEach(pastDayPresets, id: \.self) { preset in
                    PresetButton(title: preset.rawValue, preset: preset, selectedPreset: $selectedPreset) {
                        updateDateRange(for: preset)
                    }
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 120)

            Divider()

            // Column 2: Current & Previous Presets
            VStack(alignment: .leading, spacing: 4) {
                ForEach(currentPeriodPresets, id: \.self) { preset in
                    PresetButton(title: preset.rawValue, preset: preset, selectedPreset: $selectedPreset) {
                        updateDateRange(for: preset)
                    }
                }
                Divider().padding(.vertical, 4)
                ForEach(previousPeriodPresets, id: \.self) { preset in
                    PresetButton(title: preset.rawValue, preset: preset, selectedPreset: $selectedPreset) {
                        updateDateRange(for: preset)
                    }
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 120)

            Divider()

            // Column 3: Date Pickers
            VStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: startDate) { _, newValue in
                            DispatchQueue.main.async {
                                selectedDateRange = DateRange(startDate: newValue, endDate: endDate)
                                selectedPreset = nil
                            }
                        }
                    
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: endDate) { _, newValue in
                            DispatchQueue.main.async {
                                selectedDateRange = DateRange(startDate: startDate, endDate: newValue)
                                selectedPreset = nil
                            }
                        }
                }
                
                HStack(spacing: 8) {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .scaleEffect(0.9)
                        .clipped()
                        .onChange(of: startDate) { _, newValue in
                            DispatchQueue.main.async {
                                selectedDateRange = DateRange(startDate: newValue, endDate: endDate)
                                selectedPreset = nil
                            }
                        }
                    
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .scaleEffect(0.9)
                        .clipped()
                        .onChange(of: endDate) { _, newValue in
                            DispatchQueue.main.async {
                                selectedDateRange = DateRange(startDate: startDate, endDate: newValue)
                                selectedPreset = nil
                            }
                        }
                }
                Spacer()
            }
            .padding(12)
        }
        .padding(.vertical, 4)
    }

    private func updateDateRange(for preset: DateRangePreset) {
        let range = preset.dateRange
        startDate = range.startDate
        endDate = range.endDate
        selectedDateRange = range
    }
}

// Custom button for presets to reduce repetition
struct PresetButton: View {
    let title: String
    let preset: DateRangePreset
    @Binding var selectedPreset: DateRangePreset?
    let action: () -> Void

    var body: some View {
        Button(action: {
            selectedPreset = preset
            action()
        }) {
            Text(title)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 16)
                .padding(.horizontal, 6)
                .background(selectedPreset == preset ? Color.accentColor : Color.clear)
                .foregroundColor(selectedPreset == preset ? .white : .primary)
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}

struct DateRange: Hashable {
    var startDate: Date
    var endDate: Date
}

enum DateRangePreset: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisQuarter = "This Quarter"
    case thisYear = "This Year"
    case yesterday = "Yesterday"
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    case past7Days = "Past 7 Days"
    case past15Days = "Past 15 Days"
    case past30Days = "Past 30 Days"
    case past90Days = "Past 90 Days"
    case past365Days = "Past 365 Days"

    var dateRange: DateRange {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .today: return DateRange(startDate: calendar.startOfDay(for: now), endDate: now)
        case .thisWeek: return DateRange(startDate: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!, endDate: now)
        case .thisMonth: return DateRange(startDate: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!, endDate: now)
        case .thisQuarter: let quarter = (calendar.component(.month, from: now) - 1) / 3 + 1
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let startOfQuarter = calendar.date(byAdding: .month, value: (quarter - 1) * 3, to: startOfMonth)!
            return DateRange(startDate: startOfQuarter, endDate: now)
        case .thisYear: return DateRange(startDate: calendar.date(from: calendar.dateComponents([.year], from: now))!, endDate: now)
        case .yesterday: let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return DateRange(startDate: calendar.startOfDay(for: yesterday), endDate: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: yesterday))!)
        case .lastWeek: let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeek))!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            return DateRange(startDate: startOfWeek, endDate: endOfWeek)
        case .lastMonth: let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return DateRange(startDate: startOfMonth, endDate: endOfMonth)
        case .past7Days: return DateRange(startDate: calendar.date(byAdding: .day, value: -7, to: now)!, endDate: now)
        case .past15Days: return DateRange(startDate: calendar.date(byAdding: .day, value: -15, to: now)!, endDate: now)
        case .past30Days: return DateRange(startDate: calendar.date(byAdding: .day, value: -30, to: now)!, endDate: now)
        case .past90Days: return DateRange(startDate: calendar.date(byAdding: .day, value: -90, to: now)!, endDate: now)
        case .past365Days: return DateRange(startDate: calendar.date(byAdding: .day, value: -365, to: now)!, endDate: now)
        }
    }
}

struct TimePickerView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var dateRange = DateRange(startDate: Date(), endDate: Date())
        @State private var selectedPreset: DateRangePreset?

        var body: some View {
            TimePickerView(isPresented: $isPresented, selectedDateRange: $dateRange, selectedPreset: $selectedPreset)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
