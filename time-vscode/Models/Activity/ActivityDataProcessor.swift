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
    
    /// Sorts activities chronologically (most recent first)
    /// - Parameter activities: Array of activities to sort
    /// - Returns: Sorted array of activities
    static func sortActivitiesChronologically(_ activities: [Activity]) -> [Activity] {
        return activities.sorted { $0.startTime > $1.startTime }
    }
    
    /// Sorts activities by duration (longest first)
    /// - Parameter activities: Array of activities to sort
    /// - Returns: Sorted array of activities
    static func sortActivitiesByDuration(_ activities: [Activity]) -> [Activity] {
        return activities.sorted { $0.duration > $1.duration }
    }
    
    /// Sorts activities by app name alphabetically
    /// - Parameter activities: Array of activities to sort
    /// - Returns: Sorted array of activities
    static func sortActivitiesByAppName(_ activities: [Activity]) -> [Activity] {
        return activities.sorted { $0.appName < $1.appName }
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
    
    // MARK: - Project Assignment Logic
    
    /// Matches activities to time entries based on temporal overlap
    /// - Parameters:
    ///   - activities: Array of activities to match
    ///   - timeEntries: Array of time entries to match against
    /// - Returns: Dictionary mapping activity IDs to arrays of overlapping time entries with overlap durations
    static func matchActivitiesToTimeEntries(_ activities: [Activity], _ timeEntries: [TimeEntry]) -> [UUID: [(timeEntry: TimeEntry, overlapDuration: TimeInterval)]] {
        var matches: [UUID: [(timeEntry: TimeEntry, overlapDuration: TimeInterval)]] = [:]
        
        for activity in activities {
            var overlappingEntries: [(timeEntry: TimeEntry, overlapDuration: TimeInterval)] = []
            
            for timeEntry in timeEntries {
                let overlapDuration = calculateTemporalOverlap(
                    activityStart: activity.startTime,
                    activityEnd: activity.endTime,
                    entryStart: timeEntry.startTime,
                    entryEnd: timeEntry.endTime
                )
                
                if overlapDuration > 0 {
                    overlappingEntries.append((timeEntry: timeEntry, overlapDuration: overlapDuration))
                }
            }
            
            if !overlappingEntries.isEmpty {
                // Sort by overlap duration descending to prioritize best matches
                overlappingEntries.sort { $0.overlapDuration > $1.overlapDuration }
                matches[activity.id] = overlappingEntries
            }
        }
        
        return matches
    }
    
    /// Calculates the temporal overlap between an activity and a time entry
    /// - Parameters:
    ///   - activityStart: Activity start time
    ///   - activityEnd: Activity end time
    ///   - entryStart: Time entry start time
    ///   - entryEnd: Time entry end time
    /// - Returns: Overlap duration in seconds, 0 if no overlap
    static func calculateTemporalOverlap(activityStart: Date, activityEnd: Date, entryStart: Date, entryEnd: Date) -> TimeInterval {
        let overlapStart = max(activityStart, entryStart)
        let overlapEnd = min(activityEnd, entryEnd)
        
        if overlapStart < overlapEnd {
            return overlapEnd.timeIntervalSince(overlapStart)
        }
        
        return 0
    }
    

    
    /// Creates project activity groups from activities, time entries, and projects
    /// - Parameters:
    ///   - activities: Array of activities to group
    ///   - timeEntries: Array of time entries with project associations
    ///   - projects: Array of available projects
    /// - Returns: Array of project activity groups
    static func createProjectActivityGroups(_ activities: [Activity], timeEntries: [TimeEntry], projects: [Project]) -> [ProjectActivityGroup] {
        let projectsById = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let activityMatches = matchActivitiesToTimeEntries(activities, timeEntries)
        
        var groups: [ProjectActivityGroup] = []
        var assignedActivities: Set<UUID> = []
        
        // Group activities by their assigned projects
        var activitiesByProject: [String: (project: Project, timeEntry: TimeEntry?, activities: [Activity])] = [:]
        
        for activity in activities {
            if let matches = activityMatches[activity.id], let bestMatch = matches.first {
                let timeEntry = bestMatch.timeEntry
                
                if let projectId = timeEntry.projectId, let project = projectsById[projectId] {
                    // Activity is assigned to a project
                    assignedActivities.insert(activity.id)
                    
                    if activitiesByProject[projectId] == nil {
                        activitiesByProject[projectId] = (project: project, timeEntry: timeEntry, activities: [])
                    }
                    activitiesByProject[projectId]?.activities.append(activity)
                }
            }
        }
        
        // Create groups for assigned activities
        for (_, projectData) in activitiesByProject {
            groups.append(ProjectActivityGroup.assigned(
                project: projectData.project,
                timeEntry: projectData.timeEntry,
                activities: projectData.activities
            ))
        }
        
        // Create group for unassigned activities
        let unassignedActivities = activities.filter { !assignedActivities.contains($0.id) }
        if !unassignedActivities.isEmpty {
            groups.append(ProjectActivityGroup.unassigned(activities: unassignedActivities))
        }
        
        return groups
    }
    
    /// Calculates total duration for a list of activities with overlap detection
    /// - Parameter activities: Array of activities
    /// - Returns: Total duration accounting for overlaps
    static func calculateTotalDurationForActivities(_ activities: [Activity]) -> TimeInterval {
        let sortedActivities = activities.sorted { $0.startTime < $1.startTime }
        
        var totalDuration: TimeInterval = 0
        var lastEndTime: Date?
        
        for activity in sortedActivities {
            if let lastEnd = lastEndTime, activity.startTime < lastEnd {
                // There's an overlap, only count the non-overlapping portion
                let overlapEnd = min(activity.endTime, lastEnd)
                let nonOverlappingStart = max(overlapEnd, activity.startTime)
                
                if nonOverlappingStart < activity.endTime {
                    let nonOverlappingDuration = activity.endTime.timeIntervalSince(nonOverlappingStart)
                    totalDuration += nonOverlappingDuration
                    lastEndTime = activity.endTime
                }
            } else {
                // No overlap, add full duration
                totalDuration += activity.duration
                lastEndTime = activity.endTime
            }
        }
        
        return totalDuration
    }
    
    // MARK: - Unassigned Activities
    
    /// Identifies activities that are not assigned to any project
    /// - Parameter activities: Array of activities to check
    /// - Returns: Array of unassigned activities
    static func getUnassignedActivities(_ activities: [Activity]) -> [Activity] {
        // This method is now deprecated in favor of the new project assignment logic
        // Use assignActivitiesToProjects and separateAssignedAndUnassignedActivities instead
        return activities
    }
}