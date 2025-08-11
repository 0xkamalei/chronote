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
        "com.vivaldi.Vivaldi-snapshot",
    ]

    /// Determines if an activity represents a browser application
    /// - Parameter activity: The activity to check
    /// - Returns: True if the activity is from a browser application
    static func isBrowserActivity(_ activity: Activity) -> Bool {
        return browserBundleIds.contains(activity.appBundleId)
    }

    // MARK: - Hierarchy Building (merged from ActivityHierarchyBuilder)

    /// Builds the complete hierarchy from processed activity data
    /// - Parameters:
    ///   - activities: Array of activities to organize
    ///   - timeEntries: Array of time entries for project associations
    ///   - projects: Array of available projects
    /// - Returns: Array of ActivityHierarchyGroup representing the root level of the hierarchy
    static func buildHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry],
        projects: [Project]
    ) -> [ActivityHierarchyGroup] {
        // Step 1: Create project associations using existing logic
        let projectGroups = ActivityDataProcessor.createProjectActivityGroups(
            activities,
            timeEntries: timeEntries,
            projects: projects
        )

        // Step 2: Build hierarchy for each project group
        var hierarchyGroups: [ActivityHierarchyGroup] = []

        for projectGroup in projectGroups {
            let projectHierarchy = buildProjectHierarchy(projectGroup: projectGroup, projects: projects)
            hierarchyGroups.append(projectHierarchy)
        }

        return hierarchyGroups
    }

    /// Builds the hierarchy for a single project group
    private static func buildProjectHierarchy(
        projectGroup: ProjectTimeEntryGroup,
        projects: [Project]
    ) -> ActivityHierarchyGroup {
        // Level 1: Project
        let projectName = projectGroup.displayName
        let projectActivities = projectGroup.activities

        // Find subprojects if this is a parent project
        let subprojects = findSubprojects(for: projectGroup.project, in: projects)
        var children: [ActivityHierarchyGroup] = []

        if !subprojects.isEmpty {
            // Level 2: Subprojects
            for subproject in subprojects {
                let subprojectHierarchy = buildSubprojectHierarchy(
                    subproject: subproject,
                    activities: projectActivities,
                    timeEntry: projectGroup.timeEntry
                )
                if !subprojectHierarchy.isEmpty {
                    children.append(contentsOf: subprojectHierarchy)
                }
            }

            // Add activities not assigned to any subproject
            let unassignedToSubproject = projectActivities // For MVP, all activities go to main project
            if !unassignedToSubproject.isEmpty {
                let timeEntryHierarchy = buildTimeEntryHierarchy(
                    activities: unassignedToSubproject,
                    timeEntry: projectGroup.timeEntry
                )
                children.append(contentsOf: timeEntryHierarchy)
            }
        } else {
            // No subprojects, go directly to time entry level
            let timeEntryHierarchy = buildTimeEntryHierarchy(
                activities: projectActivities,
                timeEntry: projectGroup.timeEntry
            )
            children.append(contentsOf: timeEntryHierarchy)
        }

        return ActivityHierarchyGroup(
            name: projectName,
            level: .project,
            children: children,
            activities: []
        )
    }

    /// Builds subproject hierarchy
    private static func buildSubprojectHierarchy(
        subproject: Project,
        activities: [Activity],
        timeEntry: TimeEntry?
    ) -> [ActivityHierarchyGroup] {
        // For MVP, we'll create a simple subproject structure
        // In a full implementation, we'd filter activities by subproject
        let subprojectActivities = activities // For MVP, all activities

        if subprojectActivities.isEmpty {
            return []
        }

        let timeEntryHierarchy = buildTimeEntryHierarchy(
            activities: subprojectActivities,
            timeEntry: timeEntry
        )

        let subprojectGroup = ActivityHierarchyGroup(
            name: subproject.name,
            level: .subproject,
            children: timeEntryHierarchy,
            activities: []
        )

        return [subprojectGroup]
    }

    /// Builds time entry level hierarchy
    private static func buildTimeEntryHierarchy(
        activities: [Activity],
        timeEntry: TimeEntry?
    ) -> [ActivityHierarchyGroup] {
        if let timeEntry = timeEntry {
            // Level 3: Time Entry
            let timePeriodHierarchy = buildTimePeriodHierarchy(activities: activities)

            let timeEntryGroup = ActivityHierarchyGroup(
                name: timeEntry.title,
                level: .timeEntry,
                children: timePeriodHierarchy,
                activities: []
            )

            return [timeEntryGroup]
        } else {
            // No time entry, go directly to time periods
            return buildTimePeriodHierarchy(activities: activities)
        }
    }

    /// Builds time period level hierarchy with segmentation logic
    private static func buildTimePeriodHierarchy(activities: [Activity]) -> [ActivityHierarchyGroup] {
        // Level 4: Time Period - Segment activities into meaningful time periods
        let timePeriods = segmentActivitiesIntoTimePeriods(activities)
        var timePeriodGroups: [ActivityHierarchyGroup] = []

        for (periodName, periodActivities) in timePeriods {
            let appNameHierarchy = buildAppNameHierarchy(activities: periodActivities)

            let timePeriodGroup = ActivityHierarchyGroup(
                name: periodName,
                level: .timePeriod,
                children: appNameHierarchy,
                activities: []
            )

            timePeriodGroups.append(timePeriodGroup)
        }

        return timePeriodGroups
    }

    /// Builds app name level hierarchy
    private static func buildAppNameHierarchy(activities: [Activity]) -> [ActivityHierarchyGroup] {
        // Level 5: App Name - Group by application
        let activitiesByApp = Dictionary(grouping: activities) { $0.appName }
        var appNameGroups: [ActivityHierarchyGroup] = []

        for (appName, appActivities) in activitiesByApp {
            let appTitleHierarchy = buildAppTitleHierarchy(activities: appActivities)

            let appNameGroup = ActivityHierarchyGroup(
                name: appName,
                level: .appName,
                children: appTitleHierarchy,
                activities: []
            )

            appNameGroups.append(appNameGroup)
        }

        return appNameGroups.sorted { $0.totalDuration > $1.totalDuration }
    }

    /// Builds app title level hierarchy with grouping logic
    private static func buildAppTitleHierarchy(activities: [Activity]) -> [ActivityHierarchyGroup] {
        // Level 6: App Title - Group activities with the same app title under single entries
        let activitiesByTitle = groupActivitiesByAppTitle(activities)
        var appTitleGroups: [ActivityHierarchyGroup] = []

        for (titleKey, titleActivities) in activitiesByTitle {
            let appTitleGroup = ActivityHierarchyGroup(
                name: titleKey,
                level: .appTitle,
                children: [],
                activities: titleActivities
            )

            appTitleGroups.append(appTitleGroup)
        }

        return appTitleGroups.sorted { $0.totalDuration > $1.totalDuration }
    }

    /// Finds subprojects for a given parent project
    private static func findSubprojects(for parentProject: Project?, in projects: [Project]) -> [Project] {
        guard let parentProject = parentProject else { return [] }

        return projects.filter { $0.parentID == parentProject.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Segments activities into meaningful time periods
    private static func segmentActivitiesIntoTimePeriods(_ activities: [Activity]) -> [String: [Activity]] {
        var periods: [String: [Activity]] = [:]

        for activity in activities {
            let periodName = determineTimePeriod(for: activity.startTime)

            if periods[periodName] == nil {
                periods[periodName] = []
            }
            periods[periodName]?.append(activity)
        }

        return periods
    }

    /// Determines the time period name for a given date
    private static func determineTimePeriod(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 0 ..< 6:
            return "Late Night (12AM-6AM)"
        case 6 ..< 9:
            return "Early Morning (6AM-9AM)"
        case 9 ..< 12:
            return "Morning (9AM-12PM)"
        case 12 ..< 14:
            return "Lunch Time (12PM-2PM)"
        case 14 ..< 17:
            return "Afternoon (2PM-5PM)"
        case 17 ..< 20:
            return "Evening (5PM-8PM)"
        case 20 ..< 24:
            return "Night (8PM-12AM)"
        default:
            return "Unknown Period"
        }
    }

    /// Groups activities by app title, handling cases where activities have the same title
    private static func groupActivitiesByAppTitle(_ activities: [Activity]) -> [String: [Activity]] {
        var titleGroups: [String: [Activity]] = [:]

        for activity in activities {
            let titleKey = activity.appTitle ?? "No Title"

            if titleGroups[titleKey] == nil {
                titleGroups[titleKey] = []
            }
            titleGroups[titleKey]?.append(activity)
        }

        return titleGroups
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
            "com.github.atom",
        ]
        return codingBundleIds.contains(activity.appBundleId)
    }

    private static func isCommunication(_ activity: Activity) -> Bool {
        let communicationBundleIds: Set<String> = [
            "com.tinyspeck.slackmacgap",
            "com.hnc.Discord",
            "ru.keepcoder.Telegram",
            "com.tencent.xinWeChat",
            "com.skype.skype",
        ]
        return communicationBundleIds.contains(activity.appBundleId)
    }

    private static func isProductivity(_ activity: Activity) -> Bool {
        let productivityBundleIds: Set<String> = [
            "com.apple.iCal",
            "com.apple.finder",
            "info.danieldrescher.timing",
            "com.apple.AppStore",
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

        // Only process completed activities (those with endTime)
        let completedActivities = activities.filter { $0.endTime != nil }

        for activity in completedActivities {
            guard let activityEndTime = activity.endTime else { continue }

            var overlappingEntries: [(timeEntry: TimeEntry, overlapDuration: TimeInterval)] = []

            for timeEntry in timeEntries {
                let overlapDuration = calculateTemporalOverlap(
                    activityStart: activity.startTime,
                    activityEnd: activityEndTime,
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
    static func createProjectActivityGroups(_ activities: [Activity], timeEntries: [TimeEntry], projects: [Project]) -> [ProjectTimeEntryGroup] {
        let projectsById = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let activityMatches = matchActivitiesToTimeEntries(activities, timeEntries)

        var groups: [ProjectTimeEntryGroup] = []
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
            groups.append(ProjectTimeEntryGroup.assigned(
                project: projectData.project,
                timeEntry: projectData.timeEntry,
                activities: projectData.activities
            ))
        }

        // Create group for unassigned activities
        let unassignedActivities = activities.filter { !assignedActivities.contains($0.id) }
        if !unassignedActivities.isEmpty {
            groups.append(ProjectTimeEntryGroup.unassigned(activities: unassignedActivities))
        }

        return groups
    }

    /// Calculates total duration for a list of activities with overlap detection
    /// - Parameter activities: Array of activities
    /// - Returns: Total duration accounting for overlaps (only for completed activities)
    static func calculateTotalDurationForActivities(_ activities: [Activity]) -> TimeInterval {
        // Only process completed activities (those with endTime)
        let completedActivities = activities.filter { $0.endTime != nil }
        let sortedActivities = completedActivities.sorted { $0.startTime < $1.startTime }

        var totalDuration: TimeInterval = 0
        var lastEndTime: Date?

        for activity in sortedActivities {
            guard let activityEndTime = activity.endTime else { continue }

            if let lastEnd = lastEndTime, activity.startTime < lastEnd {
                // There's an overlap, only count the non-overlapping portion
                let overlapEnd = min(activityEndTime, lastEnd)
                let nonOverlappingStart = max(overlapEnd, activity.startTime)

                if nonOverlappingStart < activityEndTime {
                    let nonOverlappingDuration = activityEndTime.timeIntervalSince(nonOverlappingStart)
                    totalDuration += nonOverlappingDuration
                    lastEndTime = activityEndTime
                }
            } else {
                // No overlap, add full duration
                totalDuration += activity.duration // Use stored duration for completed activities
                lastEndTime = activityEndTime
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
