import Foundation

/// Utility class for processing and organizing activity data
class ActivityDataProcessor {
    
    // MARK: - Browser Detection
    
    /// Known browser bundle identifiers for grouping
    private static let browserBundleIds: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "com.operasoftware.Opera",
        "com.brave.Browser",
        "com.vivaldi.Vivaldi-snapshot"
    ]
    
    /// Determines if an activity represents a browser application
    /// - Parameter activity: The activity to check
    /// - Returns: True if the activity is from a browser application
    static func isBrowserActivity(_ activity: Activity) -> Bool {
        return browserBundleIds.contains(activity.appBundleId)
    }
    
    // MARK: - Duration Calculations
    
    /// Calculates the total duration for a collection of activities
    /// - Parameter activities: Array of activities to sum
    /// - Returns: Total duration in seconds
    static func totalDuration(for activities: [Activity]) -> TimeInterval {
        return activities.reduce(0) { $0 + $1.duration }
    }
    
    /// Formats duration as a human-readable string
    /// - Parameter duration: Duration in seconds
    /// - Returns: Formatted string (e.g., "1h 23m", "45m", "<1m")
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        
        if totalMinutes < 1 {
            return "<1m"
        }
        
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Activity Grouping
    
    /// Groups browser activities by application name
    /// - Parameter activities: Array of activities to group
    /// - Returns: Dictionary with app names as keys and arrays of activities as values
    static func groupBrowserActivities(_ activities: [Activity]) -> [String: [Activity]] {
        let browserActivities = activities.filter { isBrowserActivity($0) }
        return Dictionary(grouping: browserActivities) { $0.appName }
    }
    
    /// Gets non-browser activities
    /// - Parameter activities: Array of activities to filter
    /// - Returns: Array of non-browser activities
    static func getNonBrowserActivities(_ activities: [Activity]) -> [Activity] {
        return activities.filter { !isBrowserActivity($0) }
    }
    
    /// Extracts website information from browser activity titles
    /// - Parameter activity: Browser activity
    /// - Returns: Website URL or title, or app name if no title available
    static func extractWebsiteInfo(from activity: Activity) -> String {
        guard isBrowserActivity(activity) else { return activity.appName }
        return activity.appTitle ?? activity.appName
    }
    
    // MARK: - Sorting Logic
    
    /// Sorts activities based on the specified sort mode
    /// - Parameters:
    ///   - activities: Array of activities to sort
    ///   - sortMode: The sorting mode to apply
    /// - Returns: Sorted array of activities
    static func sortActivities(_ activities: [Activity], by sortMode: ActivitiesView.SortMode) -> [Activity] {
        switch sortMode {
        case .chronological:
            return activities.sorted { $0.startTime > $1.startTime }
        case .unfiled:
            // Sort by duration descending for unfiled mode
            return activities.sorted { $0.duration > $1.duration }
        case .category:
            // Sort by app name for category mode
            return activities.sorted { $0.appName < $1.appName }
        }
    }
    
    /// Groups activities by category (application type)
    /// - Parameter activities: Array of activities to categorize
    /// - Returns: Dictionary with category names as keys and arrays of activities as values
    static func groupActivitiesByCategory(_ activities: [Activity]) -> [String: [Activity]] {
        return Dictionary(grouping: activities) { activity in
            if isBrowserActivity(activity) {
                return "Browsers"
            } else if isCodeEditor(activity) {
                return "Development"
            } else if isCommunication(activity) {
                return "Communication"
            } else if isProductivity(activity) {
                return "Productivity"
            } else {
                return "Other"
            }
        }
    }
    
    // MARK: - Private Category Helpers
    
    private static func isCodeEditor(_ activity: Activity) -> Bool {
        let codingBundleIds: Set<String> = [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.sublimetext.4",
            "com.jetbrains.intellij",
            "com.github.atom"
        ]
        return codingBundleIds.contains(activity.appBundleId)
    }
    
    private static func isCommunication(_ activity: Activity) -> Bool {
        let communicationBundleIds: Set<String> = [
            "com.tinyspeck.slackmacgap",
            "com.hnc.Discord",
            "ru.keepcoder.Telegram",
            "com.tencent.xinWeChat",
            "com.skype.skype"
        ]
        return communicationBundleIds.contains(activity.appBundleId)
    }
    
    private static func isProductivity(_ activity: Activity) -> Bool {
        let productivityBundleIds: Set<String> = [
            "com.apple.iCal",
            "com.apple.finder",
            "info.danieldrescher.timing",
            "com.apple.AppStore"
        ]
        return productivityBundleIds.contains(activity.appBundleId)
    }
    
    // MARK: - Unassigned Activities
    
    /// Identifies activities that are not assigned to any project
    /// Note: This is a placeholder implementation as project assignment logic
    /// would depend on the actual project-activity relationship structure
    /// - Parameter activities: Array of activities to check
    /// - Returns: Array of unassigned activities
    static func getUnassignedActivities(_ activities: [Activity]) -> [Activity] {
        // For now, return all activities as unassigned since there's no
        // project assignment field in the Activity model
        // This would need to be updated when project assignment is implemented
        return activities
    }
}