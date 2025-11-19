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

        for project in projects where project.parentID == nil {
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
                let projectChildren = buildSubprojectHierarchy(
                    activities: projectActivities,
                    timeEntries: projectTimeEntries,
                    projects: projects,
                    parentProject: project
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

    // MARK: - Subproject Level

    private static func buildSubprojectHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry],
        projects: [Project],
        parentProject: Project
    ) -> [ActivityHierarchyGroup] {
        var subprojectGroups: [ActivityHierarchyGroup] = []

        // Direct children of current project
        let subprojects = projects.filter { $0.parentID == parentProject.id }

        if subprojects.isEmpty {
            // No subprojects, go directly to time entries
            return buildTimeEntryHierarchy(activities: activities, timeEntries: timeEntries)
        }

        for subproject in subprojects {
            let subprojectTimeEntries = timeEntries.filter { $0.projectId == subproject.id }
            let subprojectActivities = activities.filter { activity in
                guard let endTime = activity.endTime else { return false }
                return subprojectTimeEntries.contains { timeEntry in
                    timeEntry.startTime <= activity.startTime && endTime <= timeEntry.endTime
                }
            }

            if !subprojectActivities.isEmpty {
                let subprojectChildren = buildTimeEntryHierarchy(
                    activities: subprojectActivities,
                    timeEntries: subprojectTimeEntries
                )

                let subprojectGroup = ActivityHierarchyGroup(
                    name: subproject.name,
                    level: .subproject,
                    children: subprojectChildren,
                    activities: []
                )

                subprojectGroups.append(subprojectGroup)
            }
        }

        return subprojectGroups
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

            // Group by app name (same as bundle activities app name)
            let titleGroups = Dictionary(grouping: bundleActivities) { $0.appName }
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
}
