
import SwiftUI

struct DateNavigatorView: View {
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @State private var isDatePickerExpanded: Bool = false

 
    private var dateRangeText: String {
        let calendar = Calendar.current
        
        if let preset = selectedPreset {
            return preset.rawValue
        }

        let displayStartDate = selectedDateRange.displayStartDate(calendar: calendar)
        let displayEndDate = selectedDateRange.displayEndDate(calendar: calendar)

        if selectedDateRange.isSingleDay {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: displayStartDate)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let startString = formatter.string(from: displayStartDate)
        let endString = formatter.string(from: displayEndDate)
        return "\(startString) - \(endString)"
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                adjustDateRange(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            
            Divider()
                .frame(height: 16)
            
            Button {
                isDatePickerExpanded.toggle()
            } label: {
                Text(dateRangeText)
                    .font(.system(size: 12))
                    .frame(minWidth: 70)
                    .frame(height: 24)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $isDatePickerExpanded, arrowEdge: .bottom) {
                TimePickerView(
                    isPresented: $isDatePickerExpanded,
                    selectedDateRange: $selectedDateRange,
                    selectedPreset: $selectedPreset
                )
            }
            
            Divider()
                .frame(height: 16)
            
            Button {
                adjustDateRange(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
    }

    private func adjustDateRange(by value: Int) {
        let calendar = Calendar.current
        let currentRange = selectedDateRange.toDateInterval(calendar: calendar)
        let component: Calendar.Component
        var amount = value

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
                component = .day
                amount *= selectedDateRange.displayedDayCount
            }
        } else {
            component = .day
            amount *= selectedDateRange.displayedDayCount
        }

        guard
            let newStartDate = calendar.date(byAdding: component, value: amount, to: currentRange.start),
            let newEndDate = calendar.date(byAdding: component, value: amount, to: currentRange.end)
        else {
            selectedPreset = nil
            return
        }

        let newRange = AppDateRange(startDate: newStartDate, endDate: newEndDate)
        selectedDateRange = newRange
        
        let targetPresets: [AppDateRangePreset] = [.today, .yesterday]
        if let matched = targetPresets.first(where: { preset in
            let presetRange = preset.dateRange
            return abs(presetRange.startDate.timeIntervalSince(newRange.startDate)) < 1 &&
                   abs(presetRange.endDate.timeIntervalSince(newRange.endDate)) < 1
        }) {
            selectedPreset = matched
        } else {
            selectedPreset = nil
        }
    }
}
