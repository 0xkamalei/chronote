import Foundation

/// Utility class for processing and organizing activity data
class ActivityDataProcessor {
    // MARK: - Hierarchy Building

    /// Builds the complete hierarchy from activities and time entries
    /// - Parameters:
    ///   - activities: Array of activities to organize
    ///   - timeEntries: Array of time entries for project associations
    ///   - projects: Array of available projects
    /// - Returns: Array of ActivityHierarchyGroup representing the root level
    static func buildHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry],
        projects: [Project]
    ) -> [ActivityHierarchyGroup] {
        var hierarchyGroups: [ActivityHierarchyGroup] = []

        // Group 1: Unassigned activities (no time entry)
        let unassignedActivities = activities.filter { activity in
            guard let endTime = activity.endTime else { return true }
            return !timeEntries.contains { timeEntry in
                timeEntry.startTime <= activity.startTime && endTime <= timeEntry.endTime
            }
        }

        if !unassignedActivities.isEmpty {
            let unassignedGroup = ActivityHierarchyGroup(
                name: "Unassigned",
                level: .project,
                children: buildTimelineHierarchy(activities: unassignedActivities, timeEntries: []),
                activities: []
            )
            hierarchyGroups.append(unassignedGroup)
        }

        // Group 2: By projects
        let projectGroups = buildProjectHierarchy(
            activities: activities,
            timeEntries: timeEntries,
            projects: projects
        )
        hierarchyGroups.append(contentsOf: projectGroups)

        return hierarchyGroups
    }

    // MARK: - Project Level

    private static func buildProjectHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry],
        projects: [Project]
    ) -> [ActivityHierarchyGroup] {
        var projectGroups: [ActivityHierarchyGroup] = []

        for project in projects {
            // Get all time entries for this project
            let projectTimeEntries = timeEntries.filter { $0.projectId == project.id }

            // Get activities for this project's time entries
            let projectActivities = activities.filter { activity in
                guard let endTime = activity.endTime else { return false }
                return projectTimeEntries.contains { timeEntry in
                    timeEntry.startTime <= activity.startTime && endTime <= timeEntry.endTime
                }
            }

            if !projectActivities.isEmpty {
                let projectChildren = buildTimeEntryHierarchy(
                    activities: projectActivities,
                    timeEntries: projectTimeEntries
                )

                let projectGroup = ActivityHierarchyGroup(
                    name: project.name,
                    level: .project,
                    children: projectChildren,
                    activities: []
                )

                projectGroups.append(projectGroup)
            }
        }

        return projectGroups
    }

    // MARK: - TimeEntry Level

    private static func buildTimeEntryHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry]
    ) -> [ActivityHierarchyGroup] {
        var timeEntryGroups: [ActivityHierarchyGroup] = []

        for timeEntry in timeEntries {
            let entryActivities = activities.filter { activity in
                guard let endTime = activity.endTime else { return false }
                return timeEntry.startTime <= activity.startTime && endTime <= timeEntry.endTime
            }

            if !entryActivities.isEmpty {
                let timelineHierarchy = buildTimelineHierarchy(
                    activities: entryActivities,
                    timeEntries: []
                )

                let timeEntryGroup = ActivityHierarchyGroup(
                    name: timeEntry.title,
                    level: .timeEntry,
                    children: timelineHierarchy,
                    activities: []
                )

                timeEntryGroups.append(timeEntryGroup)
            }
        }

        // Add unassigned activities in this time frame
        if !timeEntries.isEmpty {
            let timelineHierarchy = buildTimelineHierarchy(activities: activities, timeEntries: timeEntries)
            if !timelineHierarchy.isEmpty {
                timeEntryGroups.append(contentsOf: timelineHierarchy)
            }
        }

        return timeEntryGroups
    }

    // MARK: - App-Based Hierarchy

    /// Builds a simplified hierarchy grouped only by App
    static func buildAppHierarchy(activities: [Activity]) -> [ActivityHierarchyGroup] {
        let appGroups = Dictionary(grouping: activities) { $0.appBundleId }
        var appHierarchy: [ActivityHierarchyGroup] = []

        for (bundleId, bundleActivities) in appGroups {
            let appName = bundleActivities.first?.appName ?? bundleId
            
            // Group by window title
            let titleGroups = Dictionary(grouping: bundleActivities) { $0.appTitle ?? "General" }
            var titleHierarchy: [ActivityHierarchyGroup] = []

            for (title, titleActivities) in titleGroups {
                let titleGroup = ActivityHierarchyGroup(
                    name: title,
                    level: .appTitle,
                    children: [],
                    activities: titleActivities.sorted { $0.startTime > $1.startTime }
                )
                titleHierarchy.append(titleGroup)
            }

            let appGroup = ActivityHierarchyGroup(
                name: appName,
                level: .appName,
                children: titleHierarchy.sorted { $0.totalDuration > $1.totalDuration },
                activities: []
            )

            appHierarchy.append(appGroup)
        }

        return appHierarchy.sorted { $0.totalDuration > $1.totalDuration }
    }

    // MARK: - Timeline Hierarchy (Time Period -> App -> Title)

    private static func buildTimelineHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry]
    ) -> [ActivityHierarchyGroup] {
        // Group by app bundle ID (aggregation)
        let appGroups = Dictionary(grouping: activities) { $0.appBundleId }
        var appHierarchy: [ActivityHierarchyGroup] = []

        for (bundleId, bundleActivities) in appGroups.sorted(by: { $0.key < $1.key }) {
            // Get app name (should be same for all activities with same bundle ID)
            let appName = bundleActivities.first?.appName ?? bundleId

            // Group by app title
            let titleGroups = Dictionary(grouping: bundleActivities) { $0.appTitle ?? "General" }
            var titleHierarchy: [ActivityHierarchyGroup] = []

            for (title, titleActivities) in titleGroups.sorted(by: { $0.key < $1.key }) {
                let titleGroup = ActivityHierarchyGroup(
                    name: title,
                    level: .appTitle,
                    children: [],
                    activities: titleActivities.sorted { $0.startTime < $1.startTime }
                )
                titleHierarchy.append(titleGroup)
            }

            let appGroup = ActivityHierarchyGroup(
                name: appName,
                level: .appName,
                children: titleHierarchy,
                activities: []
            )

            appHierarchy.append(appGroup)
        }

        // Sort by total duration (descending)
        return appHierarchy.sorted { $0.totalDuration > $1.totalDuration }
    }

    // MARK: - Utility Methods

    /// Calculate total duration for activities
    static func calculateTotalDuration(for activities: [Activity]) -> TimeInterval {
        activities.reduce(0) { $0 + $1.calculatedDuration }
    }

    /// Format duration as human-readable string
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Check if bundle ID is a browser
    static func isBrowserApp(_ bundleId: String) -> Bool {
        let browsers = [
            "com.google.Chrome",
            "com.apple.Safari",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "com.operasoftware.Opera",
            "com.brave.Browser",
        ]
        return browsers.contains(bundleId)
    }

    // MARK: - Activity Matching

    /// Matches activities to time entries based on time overlap
    /// - Parameters:
    ///   - activities: List of activities to match
    ///   - timeEntries: List of time entries to match against
    /// - Returns: Dictionary mapping Activity ID to list of matches, sorted by overlap duration (descending)
    static func matchActivitiesToTimeEntries(_ activities: [Activity], _ timeEntries: [TimeEntry]) -> [UUID: [ActivityMatch]] {
        var results: [UUID: [ActivityMatch]] = [:]

        for activity in activities {
            // ongoing activity (nil endTime) should be ignored
            guard let activityEnd = activity.endTime else { continue }
            
            var matches: [ActivityMatch] = []

            for entry in timeEntries {
                // Calculate overlap
                let start = max(activity.startTime, entry.startTime)
                let end = min(activityEnd, entry.endTime)

                // edge-touching intervals (end == start) count as no overlap
                if start < end {
                    let overlap = end.timeIntervalSince(start)
                    matches.append(ActivityMatch(timeEntry: entry, overlapDuration: overlap))
                }
            }

            if !matches.isEmpty {
                // Sort by overlap duration desc
                matches.sort { $0.overlapDuration > $1.overlapDuration }
                results[activity.id] = matches
            }
        }

        return results
    }
}

/// Represents a match between an activity and a time entry
struct ActivityMatch {
    let timeEntry: TimeEntry
    let overlapDuration: TimeInterval
}
