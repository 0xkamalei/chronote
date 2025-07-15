
import SwiftUI

struct DateNavigatorView: View {
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @State private var isDatePickerExpanded: Bool = false

    private var dateRangeText: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedStart = calendar.startOfDay(for: selectedDateRange.startDate)

        if let preset = selectedPreset {
            return preset.rawValue
        }

        if calendar.isDate(selectedStart, inSameDayAs: today) && calendar.isDate(selectedDateRange.endDate, inSameDayAs: Date()) {
            return "Today"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), calendar.isDate(selectedStart, inSameDayAs: yesterday) {
            return "Yesterday"
        }

        formatter.dateStyle = .short
        let startString = formatter.string(from: selectedDateRange.startDate)
        let endString = formatter.string(from: selectedDateRange.endDate)

        if calendar.isDate(selectedDateRange.startDate, inSameDayAs: selectedDateRange.endDate) {
            return startString
        } else {
            return "\(startString) - \(endString)"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                adjustDateRange(by: -1)
            }) {
                Image(systemName: "chevron.left")
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button(action: {
                isDatePickerExpanded.toggle()
            }) {
                Text(dateRangeText)
                    .frame(minWidth: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isDatePickerExpanded, arrowEdge: .bottom) {
                TimePickerView(isPresented: $isDatePickerExpanded, selectedDateRange: $selectedDateRange, selectedPreset: $selectedPreset)
            }

            Button(action: {
                adjustDateRange(by: 1)
            }) {
                Image(systemName: "chevron.right")
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }

    private func adjustDateRange(by value: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component
        var amount = value

        let referenceDate = selectedDateRange.startDate
        
        if let preset = selectedPreset {
            switch preset {
            case .today, .yesterday:
                component = .day
            case .thisWeek, .lastWeek:
                component = .weekOfYear
            case .thisMonth, .lastMonth:
                component = .month
            case .thisQuarter:
                component = .month
                amount *= 3
            case .thisYear:
                component = .year
            default: // For "Past X Days"
                let dayCount = calendar.dateComponents([.day], from: selectedDateRange.startDate, to: selectedDateRange.endDate).day ?? 0
                component = .day
                amount *= (dayCount + 1)
            }
        } else {
            // Handle custom date ranges
            let dayDifference = calendar.dateComponents([.day], from: selectedDateRange.startDate, to: selectedDateRange.endDate).day ?? 0
            component = .day
            amount *= (dayDifference + 1)
        }

        if let newStartDate = calendar.date(byAdding: component, value: amount, to: referenceDate) {
            let newEndDate: Date
            if let preset = selectedPreset, preset.isFixedDuration {
                 let duration = calendar.dateComponents([.day], from: selectedDateRange.startDate, to: selectedDateRange.endDate)
                 newEndDate = calendar.date(byAdding: duration, to: newStartDate)!
            } else if selectedPreset == nil {
                 let duration = calendar.dateComponents([.day], from: selectedDateRange.startDate, to: selectedDateRange.endDate)
                 newEndDate = calendar.date(byAdding: duration, to: newStartDate)!
            }
            else {
                newEndDate = Date()
            }
            selectedDateRange = AppDateRange(startDate: newStartDate, endDate: newEndDate)
        }
        
        selectedPreset = nil
    }
}

extension AppDateRangePreset {
    var isFixedDuration: Bool {
        switch self {
        case .past7Days, .past15Days, .past30Days, .past90Days, .past365Days, .lastWeek, .lastMonth:
            return true
        default:
            return false
        }
    }
}
