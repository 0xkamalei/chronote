import SwiftUI

struct TimePickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isUpdatingPresets: Bool = false

    init(isPresented: Binding<Bool>, selectedDateRange: Binding<AppDateRange>, selectedPreset: Binding<AppDateRangePreset?>) {
        _isPresented = isPresented
        _selectedDateRange = selectedDateRange
        _selectedPreset = selectedPreset
        let calendar = Calendar.current
        let range = selectedDateRange.wrappedValue
        _startDate = State(initialValue: range.displayStartDate(calendar: calendar))
        _endDate = State(initialValue: range.displayEndDate(calendar: calendar))
    }

    var body: some View {
        let pastDayPresets: [AppDateRangePreset] = [.past7Days, .past15Days, .past30Days, .past90Days, .past365Days]
        let currentPeriodPresets: [AppDateRangePreset] = [.today, .thisWeek, .thisMonth, .thisQuarter, .thisYear]
        let previousPeriodPresets: [AppDateRangePreset] = [.yesterday, .lastWeek, .lastMonth]

        HStack(alignment: .top, spacing: 0) {
            // 左侧预设列表 - Past X Days
            VStack(alignment: .leading, spacing: 2) {
                ForEach(pastDayPresets, id: \.self) { preset in
                    PresetButton(title: preset.rawValue, preset: preset, selectedPreset: $selectedPreset) {
                        updateDateRange(for: preset)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: 110)

            Divider()

            // 中间预设列表 - This/Last Period
            VStack(alignment: .leading, spacing: 2) {
                ForEach(currentPeriodPresets, id: \.self) { preset in
                    PresetButton(title: preset.rawValue, preset: preset, selectedPreset: $selectedPreset) {
                        updateDateRange(for: preset)
                    }
                }
                Divider().padding(.vertical, 2)
                ForEach(previousPeriodPresets, id: \.self) { preset in
                    PresetButton(title: preset.rawValue, preset: preset, selectedPreset: $selectedPreset) {
                        updateDateRange(for: preset)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: 110)

            Divider()

            // 右侧日期选择器
            VStack(alignment: .center, spacing: 4) {
                // 日期范围显示
                HStack(spacing: 4) {
                    Text(formatDate(startDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Text("–")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(formatDate(endDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.top, 4)

                HStack(spacing: 4) {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .clipped()
                        .onChange(of: startDate) { _, newValue in
                            guard !isUpdatingPresets else { return }
                            let normalizedStart = Calendar.current.startOfDay(for: newValue)
                            if normalizedStart > endDate {
                                endDate = normalizedStart
                            }
                            syncSelectedDateRangeFromPicker()
                        }

                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .clipped()
                        .onChange(of: endDate) { _, newValue in
                            guard !isUpdatingPresets else { return }
                            let normalizedEnd = Calendar.current.startOfDay(for: newValue)
                            if normalizedEnd < startDate {
                                startDate = normalizedEnd
                            }
                            syncSelectedDateRangeFromPicker()
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .padding(.top, 8)
    }

    private func updateDateRange(for preset: AppDateRangePreset) {
        isUpdatingPresets = true
        let range = preset.dateRange
        let calendar = Calendar.current
        startDate = range.displayStartDate(calendar: calendar)
        endDate = range.displayEndDate(calendar: calendar)
        selectedDateRange = range
        
        DispatchQueue.main.async {
            isUpdatingPresets = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private func syncSelectedDateRangeFromPicker() {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEndInclusive = calendar.startOfDay(for: endDate)
        let normalizedExclusiveEnd = calendar.date(byAdding: .day, value: 1, to: normalizedEndInclusive) ?? normalizedEndInclusive
        selectedDateRange = AppDateRange(startDate: normalizedStart, endDate: normalizedExclusiveEnd)
        selectedPreset = nil
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
                .frame(height: 18)
                .padding(.horizontal, 6)
                .background(selectedPreset == preset ? Color.accentColor : Color.clear)
                .foregroundColor(selectedPreset == preset ? .white : .primary)
                .cornerRadius(4)
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
            // 今天：00:00 到 明天 00:00
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDayRange = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return AppDateRange(startDate: startOfDay, endDate: endOfDayRange)
        case .thisWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let startOfWeek = calendar.date(from: components)!
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            return AppDateRange(startDate: startOfWeek, endDate: endOfWeek)
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return AppDateRange(startDate: startOfMonth, endDate: endOfMonth)
        case .thisQuarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3 + 1
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let startOfQuarter = calendar.date(byAdding: .month, value: (quarter - 1) * 3, to: startOfYear)!
            let endOfQuarter = calendar.date(byAdding: .month, value: 3, to: startOfQuarter)!
            return AppDateRange(startDate: startOfQuarter, endDate: endOfQuarter)
        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!
            return AppDateRange(startDate: startOfYear, endDate: endOfYear)
        case .yesterday:
            // 昨天：昨天 00:00 到 今天 00:00
            let today = calendar.startOfDay(for: now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            return AppDateRange(startDate: yesterday, endDate: today)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeek))!
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            return AppDateRange(startDate: startOfWeek, endDate: endOfWeek)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return AppDateRange(startDate: startOfMonth, endDate: endOfMonth)
        case .past7Days:
            let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: now)!)
            let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return AppDateRange(startDate: startDate, endDate: endDate)
        case .past15Days:
            let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -14, to: now)!)
            let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return AppDateRange(startDate: startDate, endDate: endDate)
        case .past30Days:
            let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -29, to: now)!)
            let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return AppDateRange(startDate: startDate, endDate: endDate)
        case .past90Days:
            let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -89, to: now)!)
            let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return AppDateRange(startDate: startDate, endDate: endDate)
        case .past365Days:
            let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -364, to: now)!)
            let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return AppDateRange(startDate: startDate, endDate: endDate)
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
