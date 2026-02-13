import Foundation

struct AppDateRange: Equatable {
    let startDate: Date
    let endDate: Date
    
    var start: Date { startDate }
    var end: Date { endDate }
}

extension AppDateRange {
    /// UI should display an inclusive date range while queries use [start, end).
    func displayStartDate(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: startDate)
    }

    /// Convert exclusive end date to inclusive display date.
    func displayEndDate(calendar: Calendar = .current) -> Date {
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedExclusiveEnd = calendar.startOfDay(for: endDate)

        guard normalizedExclusiveEnd > normalizedStart else {
            return normalizedStart
        }

        return calendar.date(byAdding: .day, value: -1, to: normalizedExclusiveEnd) ?? normalizedStart
    }

    /// Normalized range used by data queries and timeline filtering.
    func toDateInterval(calendar: Calendar = .current) -> DateInterval {
        let normalizedStart = displayStartDate(calendar: calendar)
        let normalizedDisplayEnd = max(displayEndDate(calendar: calendar), normalizedStart)
        let normalizedExclusiveEnd = calendar.date(byAdding: .day, value: 1, to: normalizedDisplayEnd) ?? normalizedDisplayEnd
        return DateInterval(start: normalizedStart, end: normalizedExclusiveEnd)
    }

    var displayedDayCount: Int {
        let calendar = Calendar.current
        let start = displayStartDate(calendar: calendar)
        let end = displayEndDate(calendar: calendar)
        let diff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, diff + 1)
    }

    var isSingleDay: Bool {
        displayedDayCount == 1
    }
}

enum AppDateRangePreset: String, CaseIterable {
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
}
