import Foundation

struct AppDateRange {
    let startDate: Date
    let endDate: Date
}

enum AppDateRangePreset: String, CaseIterable {
    // Current periods
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisQuarter = "This Quarter"
    case thisYear = "This Year"
    
    // Previous periods
    case yesterday = "Yesterday"
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    
    // Past periods
    case past7Days = "Past 7 Days"
    case past15Days = "Past 15 Days"
    case past30Days = "Past 30 Days"
    case past90Days = "Past 90 Days"
    case past365Days = "Past 365 Days"
}
