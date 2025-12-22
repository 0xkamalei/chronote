
import SwiftUI

struct DateNavigatorView: View {
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @State private var isDatePickerExpanded: Bool = false

    /// 获取显示文本
    /// - 有预设名称时显示预设名称
    /// - Day level显示日期格式
    /// - 其他显示日期范围
    private var dateRangeText: String {
        let calendar = Calendar.current
        
        // 如果有预设，显示预设名称
        if let preset = selectedPreset {
            return preset.rawValue
        }
        
        // 检查是否是单日范围（Day level）
        let startOfSelectedDay = calendar.startOfDay(for: selectedDateRange.startDate)
        let endOfSelectedDay = calendar.date(byAdding: .day, value: 1, to: startOfSelectedDay)!
        
        // 如果结束日期等于开始日期的下一天00:00（即单日查询），显示日期
        if calendar.isDate(selectedDateRange.endDate, equalTo: endOfSelectedDay, toGranularity: .minute) ||
           calendar.isDate(selectedDateRange.startDate, inSameDayAs: selectedDateRange.endDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: selectedDateRange.startDate)
        }
        
        // 显示日期范围
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let startString = formatter.string(from: selectedDateRange.startDate)
        let endString = formatter.string(from: selectedDateRange.endDate)
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
            // 检查是否是单日查询（Day level）
            let startOfDay = calendar.startOfDay(for: selectedDateRange.startDate)
            let endOfDayRange = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            if calendar.isDate(selectedDateRange.endDate, equalTo: endOfDayRange, toGranularity: .minute) {
                // 单日查询，按天调整
                component = .day
            } else {
                let dayDifference = calendar.dateComponents([.day], from: selectedDateRange.startDate, to: selectedDateRange.endDate).day ?? 0
                component = .day
                amount *= (dayDifference + 1)
            }
        }

        if let newStartDate = calendar.date(byAdding: component, value: amount, to: referenceDate) {
            let newEndDate: Date
            if let preset = selectedPreset, preset.isFixedDuration {
                let duration = calendar.dateComponents([.day], from: selectedDateRange.startDate, to: selectedDateRange.endDate)
                newEndDate = calendar.date(byAdding: duration, to: newStartDate)!
            } else if selectedPreset == nil {
                let duration = calendar.dateComponents([.day], from: selectedDateRange.startDate, to: selectedDateRange.endDate)
                newEndDate = calendar.date(byAdding: duration, to: newStartDate)!
            } else {
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
