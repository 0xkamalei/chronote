import SwiftUI

struct TimePickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?

    @State private var startDate: Date
    @State private var endDate: Date

    init(isPresented: Binding<Bool>, selectedDateRange: Binding<AppDateRange>, selectedPreset: Binding<AppDateRangePreset?>) {
        _isPresented = isPresented
        _selectedDateRange = selectedDateRange
        _selectedPreset = selectedPreset
        _startDate = State(initialValue: selectedDateRange.wrappedValue.startDate)
        _endDate = State(initialValue: selectedDateRange.wrappedValue.endDate)
    }

    var body: some View {
        let pastDayPresets: [AppDateRangePreset] = [.past7Days, .past15Days, .past30Days, .past90Days, .past365Days]
        let currentPeriodPresets: [AppDateRangePreset] = [.today, .thisWeek, .thisMonth, .thisQuarter, .thisYear]
        let previousPeriodPresets: [AppDateRangePreset] = [.yesterday, .lastWeek, .lastMonth]

        HStack(alignment: .top, spacing: 0) {
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

            VStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: startDate) { _, newValue in
                            DispatchQueue.main.async {
                                selectedDateRange = AppDateRange(startDate: newValue, endDate: endDate)
                                selectedPreset = nil
                            }
                        }

                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: endDate) { _, newValue in
                            DispatchQueue.main.async {
                                selectedDateRange = AppDateRange(startDate: startDate, endDate: newValue)
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
                                selectedDateRange = AppDateRange(startDate: newValue, endDate: endDate)
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
                                selectedDateRange = AppDateRange(startDate: startDate, endDate: newValue)
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

    private func updateDateRange(for preset: AppDateRangePreset) {
        let range = preset.dateRange
        startDate = range.startDate
        endDate = range.endDate
        selectedDateRange = range
    }
}

struct PresetButton: View {
    let title: String
    let preset: AppDateRangePreset
    @Binding var selectedPreset: AppDateRangePreset?
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

extension AppDateRangePreset {
    var dateRange: AppDateRange {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .today: 
            return AppDateRange(startDate: calendar.startOfDay(for: now), endDate: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!.addingTimeInterval(-1))
        case .thisWeek: 
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let startOfWeek = calendar.date(from: components)!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!.addingTimeInterval(-1)
            return AppDateRange(startDate: startOfWeek, endDate: endOfWeek)
        case .thisMonth: 
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!.addingTimeInterval(-1)
            return AppDateRange(startDate: startOfMonth, endDate: endOfMonth)
        case .thisQuarter: 
            let quarter = (calendar.component(.month, from: now) - 1) / 3 + 1
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let startOfQuarter = calendar.date(byAdding: .month, value: (quarter - 1) * 3, to: startOfYear)!
            let endOfQuarter = calendar.date(byAdding: .month, value: 3, to: startOfQuarter)!.addingTimeInterval(-1)
            return AppDateRange(startDate: startOfQuarter, endDate: endOfQuarter)
        case .thisYear: 
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!.addingTimeInterval(-1)
            return AppDateRange(startDate: startOfYear, endDate: endOfYear)
        case .yesterday: let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return AppDateRange(startDate: calendar.startOfDay(for: yesterday), endDate: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: yesterday))!)
        case .lastWeek: let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeek))!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            return AppDateRange(startDate: startOfWeek, endDate: endOfWeek)
        case .lastMonth: let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return AppDateRange(startDate: startOfMonth, endDate: endOfMonth)
        case .past7Days: return AppDateRange(startDate: calendar.date(byAdding: .day, value: -7, to: now)!, endDate: now)
        case .past15Days: return AppDateRange(startDate: calendar.date(byAdding: .day, value: -15, to: now)!, endDate: now)
        case .past30Days: return AppDateRange(startDate: calendar.date(byAdding: .day, value: -30, to: now)!, endDate: now)
        case .past90Days: return AppDateRange(startDate: calendar.date(byAdding: .day, value: -90, to: now)!, endDate: now)
        case .past365Days: return AppDateRange(startDate: calendar.date(byAdding: .day, value: -365, to: now)!, endDate: now)
        }
    }
}

struct TimePickerView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var dateRange = AppDateRange(startDate: Date(), endDate: Date())
        @State private var selectedPreset: AppDateRangePreset?

        var body: some View {
            TimePickerView(isPresented: $isPresented, selectedDateRange: $dateRange, selectedPreset: $selectedPreset)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
