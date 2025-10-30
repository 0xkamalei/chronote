import Foundation
import SwiftData

/// Statistical analysis result for activity data
struct ActivityStatistics {
    let totalDuration: TimeInterval
    let averageSessionLength: TimeInterval
    let sessionCount: Int
    let productivityScore: Double
    let focusScore: Double
    let mostActiveHour: Int
    let mostActiveDay: String
    let topApplications: [(name: String, duration: TimeInterval, percentage: Double)]
    let dailyAverages: [String: TimeInterval] // Day of week -> average duration
    let hourlyDistribution: [Int: TimeInterval] // Hour -> total duration
}

/// Productivity insights for a given time period
struct ProductivityInsights {
    let period: DateInterval
    let totalProductiveTime: TimeInterval
    let totalDistractionTime: TimeInterval
    let productivityRatio: Double
    let focusSessionCount: Int
    let averageFocusSessionLength: TimeInterval
    let longestFocusSession: TimeInterval
    let mostProductiveHours: [Int]
    let trends: ProductivityTrends
}

/// Trend analysis for productivity patterns
struct ProductivityTrends {
    let weeklyTrend: TrendDirection
    let dailyConsistency: Double // 0-1, higher is more consistent
    let peakProductivityHour: Int
    let productivityVariance: Double
}

/// Direction of trend analysis
enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

/// Time period aggregation options
enum AggregationPeriod {
    case hourly
    case daily
    case weekly
    case monthly
    case yearly
}

// MARK: - Data Conflict Resolution Types

/// Represents a conflict between overlapping time entries or activities
struct DataConflict {
    let id: UUID
    let type: ConflictType
    let items: [ConflictItem]
    let overlapDuration: TimeInterval
    let severity: ConflictSeverity
    let suggestedResolution: ConflictResolution
    let detectedAt: Date

    init(type: ConflictType, items: [ConflictItem], overlapDuration: TimeInterval) {
        id = UUID()
        self.type = type
        self.items = items
        self.overlapDuration = overlapDuration
        severity = ConflictSeverity.from(overlapDuration: overlapDuration, itemCount: items.count)
        suggestedResolution = ConflictResolution.suggest(for: type, items: items)
        detectedAt = Date()
    }
}

/// Types of data conflicts that can occur
enum ConflictType {
    case overlappingTimeEntries
    case overlappingActivities
    case activityTimeEntryMismatch
    case duplicateEntries
    case invalidDuration
    case futureTimestamp
}

/// Represents an item involved in a conflict
enum ConflictItem {
    case activity(Activity)
    case timeEntry(TimeEntry)

    var startTime: Date {
        switch self {
        case let .activity(activity):
            return activity.startTime
        case let .timeEntry(timeEntry):
            return timeEntry.startTime
        }
    }

    var endTime: Date {
        switch self {
        case let .activity(activity):
            return activity.endTime ?? Date()
        case let .timeEntry(timeEntry):
            return timeEntry.endTime
        }
    }

    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    var id: UUID {
        switch self {
        case let .activity(activity):
            return activity.id
        case let .timeEntry(timeEntry):
            return timeEntry.id
        }
    }
}

/// Severity levels for conflicts
enum ConflictSeverity: Int {
    case low = 1 // < 5 minutes overlap
    case medium = 2 // 5-30 minutes overlap
    case high = 3 // > 30 minutes overlap or critical data issues

    static func from(overlapDuration: TimeInterval, itemCount: Int) -> ConflictSeverity {
        if overlapDuration > 1800 || itemCount > 3 { // 30 minutes
            return .high
        } else if overlapDuration > 300 { // 5 minutes
            return .medium
        } else {
            return .low
        }
    }
}

/// Suggested resolution strategies for conflicts
enum ConflictResolution {
    case mergeItems
    case keepFirst
    case keepLast
    case keepLongest
    case splitOverlap
    case manualReview
    case deleteInvalid

    static func suggest(for type: ConflictType, items: [ConflictItem]) -> ConflictResolution {
        switch type {
        case .overlappingTimeEntries:
            return items.count == 2 ? .mergeItems : .manualReview
        case .overlappingActivities:
            return .keepLongest
        case .activityTimeEntryMismatch:
            return .manualReview
        case .duplicateEntries:
            return .keepFirst
        case .invalidDuration, .futureTimestamp:
            return .deleteInvalid
        }
    }
}

/// Result of conflict resolution operation
struct ConflictResolutionResult {
    let conflictId: UUID
    let resolution: ConflictResolution
    let success: Bool
    let modifiedItems: [ConflictItem]
    let deletedItems: [ConflictItem]
    let error: Error?
    let resolvedAt: Date

    init(conflictId: UUID, resolution: ConflictResolution, success: Bool, modifiedItems: [ConflictItem] = [], deletedItems: [ConflictItem] = [], error: Error? = nil) {
        self.conflictId = conflictId
        self.resolution = resolution
        self.success = success
        self.modifiedItems = modifiedItems
        self.deletedItems = deletedItems
        self.error = error
        resolvedAt = Date()
    }
}

/// Data validation result
struct DataValidationResult {
    let isValid: Bool
    let conflicts: [DataConflict]
    let warnings: [DataWarning]
    let repairedItems: Int
    let validatedAt: Date

    init(isValid: Bool, conflicts: [DataConflict], warnings: [DataWarning] = [], repairedItems: Int = 0) {
        self.isValid = isValid
        self.conflicts = conflicts
        self.warnings = warnings
        self.repairedItems = repairedItems
        validatedAt = Date()
    }
}

/// Data warning for non-critical issues
struct DataWarning {
    let id: UUID
    let type: WarningType
    let message: String
    let item: ConflictItem?
    let detectedAt: Date

    init(type: WarningType, message: String, item: ConflictItem? = nil) {
        id = UUID()
        self.type = type
        self.message = message
        self.item = item
        detectedAt = Date()
    }
}

/// Types of data warnings
enum WarningType {
    case shortDuration
    case longDuration
    case unusualTimestamp
    case missingContext
    case performanceImpact
}

/// Utility class for processing and organizing activity data
class ActivityDataProcessor {
    // MARK: - Hierarchy Building (Public)

    /// Builds the complete hierarchy from processed activity data and time entries
    static func buildHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry],
        projects: [Project],
        includeTimeEntries: Bool = true
    ) -> [ActivityHierarchyGroup] {
        let projectGroups = createProjectActivityGroups(
            activities,
            timeEntries: includeTimeEntries ? timeEntries : [],
            projects: projects
        )

        var hierarchyGroups: [ActivityHierarchyGroup] = []
        for projectGroup in projectGroups {
            let projectHierarchy = buildProjectHierarchy(projectGroup: projectGroup, projects: projects)
            hierarchyGroups.append(projectHierarchy)
        }
        return hierarchyGroups
    }

    // MARK: - Project Association (Public)

    /// Creates project activity groups from activities, time entries, and projects
    static func createProjectActivityGroups(_ activities: [Activity], timeEntries: [TimeEntry], projects: [Project]) -> [ProjectTimeEntryGroup] {
        let projectsById = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let activityMatches = matchActivitiesToTimeEntries(activities, timeEntries)

        var groups: [ProjectTimeEntryGroup] = []
        var assignedActivities: Set<UUID> = []
        var processedTimeEntries: Set<UUID> = []

        // Group activities by project through time entry matching
        var activitiesByProject: [String: (project: Project, timeEntry: TimeEntry?, activities: [Activity])] = [:]
        for activity in activities {
            if let matches = activityMatches[activity.id], let bestMatch = matches.first {
                let timeEntry = bestMatch.timeEntry
                if let projectId = timeEntry.projectId, let project = projectsById[projectId] {
                    assignedActivities.insert(activity.id)
                    processedTimeEntries.insert(timeEntry.id)
                    if activitiesByProject[projectId] == nil {
                        activitiesByProject[projectId] = (project: project, timeEntry: timeEntry, activities: [])
                    }
                    activitiesByProject[projectId]?.activities.append(activity)
                }
            }
        }

        // Group time entries by project
        var timeEntriesByProject: [String: [TimeEntry]] = [:]
        for timeEntry in timeEntries {
            if let projectId = timeEntry.projectId, let project = projectsById[projectId] {
                if timeEntriesByProject[projectId] == nil {
                    timeEntriesByProject[projectId] = []
                }
                timeEntriesByProject[projectId]?.append(timeEntry)
            }
        }

        // Create groups for projects with activities and/or time entries
        var allProjectIds = Set(activitiesByProject.keys)
        allProjectIds.formUnion(Set(timeEntriesByProject.keys))

        for projectId in allProjectIds {
            let project = projectsById[projectId]!
            let projectActivities = activitiesByProject[projectId]?.activities ?? []
            let projectTimeEntries = timeEntriesByProject[projectId] ?? []
            let representativeTimeEntry = activitiesByProject[projectId]?.timeEntry

            groups.append(ProjectTimeEntryGroup.assigned(
                project: project,
                timeEntry: representativeTimeEntry,
                activities: projectActivities,
                timeEntries: projectTimeEntries
            ))
        }

        // Handle unassigned activities and time entries
        let unassignedActivities = activities.filter { !assignedActivities.contains($0.id) }
        let unassignedTimeEntries = timeEntries.filter { $0.projectId == nil }

        if !unassignedActivities.isEmpty || !unassignedTimeEntries.isEmpty {
            groups.append(ProjectTimeEntryGroup.unassigned(
                activities: unassignedActivities,
                timeEntries: unassignedTimeEntries
            ))
        }

        return groups
    }

    /// Matches activities to time entries based on temporal overlap
    static func matchActivitiesToTimeEntries(_ activities: [Activity], _ timeEntries: [TimeEntry]) -> [UUID: [(timeEntry: TimeEntry, overlapDuration: TimeInterval)]] {
        var matches: [UUID: [(timeEntry: TimeEntry, overlapDuration: TimeInterval)]] = [:]
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
                overlappingEntries.sort { $0.overlapDuration > $1.overlapDuration }
                matches[activity.id] = overlappingEntries
            }
        }
        return matches
    }

    /// Calculates the temporal overlap between an activity and a time entry
    static func calculateTemporalOverlap(activityStart: Date, activityEnd: Date, entryStart: Date, entryEnd: Date) -> TimeInterval {
        let overlapStart = max(activityStart, entryStart)
        let overlapEnd = min(activityEnd, entryEnd)
        if overlapStart < overlapEnd {
            return overlapEnd.timeIntervalSince(overlapStart)
        }
        return 0
    }

    // MARK: - Duration & Formatting (Public)

    /// Calculates total duration for a list of activities with overlap detection
    static func calculateTotalDurationForActivities(_ activities: [Activity]) -> TimeInterval {
        let completedActivities = activities.filter { $0.endTime != nil }
        let sortedActivities = completedActivities.sorted { $0.startTime < $1.startTime }

        var totalDuration: TimeInterval = 0
        var lastEndTime: Date?
        for activity in sortedActivities {
            guard let activityEndTime = activity.endTime else { continue }
            if let lastEnd = lastEndTime, activity.startTime < lastEnd {
                let overlapEnd = min(activityEndTime, lastEnd)
                let nonOverlappingStart = max(overlapEnd, activity.startTime)
                if nonOverlappingStart < activityEndTime {
                    let nonOverlappingDuration = activityEndTime.timeIntervalSince(nonOverlappingStart)
                    totalDuration += nonOverlappingDuration
                    lastEndTime = activityEndTime
                }
            } else {
                totalDuration += activity.duration
                lastEndTime = activityEndTime
            }
        }
        return totalDuration
    }

    /// Calculates the total duration for a collection of activities
    static func totalDuration(for activities: [Activity]) -> TimeInterval {
        return activities.reduce(0) { $0 + $1.duration }
    }

    /// Formats duration as a human-readable string
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        if totalMinutes < 1 {
            return "<1m"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            if minutes > 0 { return "\(hours)h \(minutes)m" } else { return "\(hours)h" }
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Categorization & Grouping (Public)

    /// Determines if an activity represents a browser application
    static func isBrowserActivity(_ activity: Activity) -> Bool {
        return browserBundleIds.contains(activity.appBundleId)
    }

    /// Extracts website information from browser activity titles
    static func extractWebsiteInfo(from activity: Activity) -> String {
        guard isBrowserActivity(activity) else { return activity.appName }
        return activity.appTitle ?? activity.appName
    }

    /// Groups browser activities by application name
    static func groupBrowserActivities(_ activities: [Activity]) -> [String: [Activity]] {
        let browserActivities = activities.filter { isBrowserActivity($0) }
        return Dictionary(grouping: browserActivities) { $0.appName }
    }

    /// Gets non-browser activities
    static func getNonBrowserActivities(_ activities: [Activity]) -> [Activity] {
        return activities.filter { !isBrowserActivity($0) }
    }

    /// Groups activities by category (application type)
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

    // MARK: - Sorting (Public)

    /// Sorts activities chronologically (most recent first)
    static func sortActivitiesChronologically(_ activities: [Activity]) -> [Activity] {
        return activities.sorted { $0.startTime > $1.startTime }
    }

    /// Sorts activities by duration (longest first)
    static func sortActivitiesByDuration(_ activities: [Activity]) -> [Activity] {
        return activities.sorted { $0.duration > $1.duration }
    }

    /// Sorts activities by app name alphabetically
    static func sortActivitiesByAppName(_ activities: [Activity]) -> [Activity] {
        return activities.sorted { $0.appName < $1.appName }
    }

    // MARK: - Private Helpers (Hierarchy)

    /// Builds the hierarchy for a single project group
    private static func buildProjectHierarchy(
        projectGroup: ProjectTimeEntryGroup,
        projects: [Project]
    ) -> ActivityHierarchyGroup {
        let projectName = projectGroup.displayName
        let projectActivities = projectGroup.activities
        let projectTimeEntries = projectGroup.timeEntries
        let subprojects = findSubprojects(for: projectGroup.project, in: projects)
        var children: [ActivityHierarchyGroup] = []

        if !subprojects.isEmpty {
            for subproject in subprojects {
                let subprojectHierarchy = buildSubprojectHierarchy(
                    subproject: subproject,
                    activities: projectActivities,
                    timeEntries: projectTimeEntries,
                    timeEntry: projectGroup.timeEntry
                )
                if !subprojectHierarchy.isEmpty { children.append(contentsOf: subprojectHierarchy) }
            }
            let unassignedToSubproject = projectActivities
            let unassignedTimeEntries = projectTimeEntries
            if !unassignedToSubproject.isEmpty || !unassignedTimeEntries.isEmpty {
                let timeEntryHierarchy = buildTimeEntryHierarchy(
                    activities: unassignedToSubproject,
                    timeEntries: unassignedTimeEntries,
                    timeEntry: projectGroup.timeEntry
                )
                children.append(contentsOf: timeEntryHierarchy)
            }
        } else {
            let timeEntryHierarchy = buildTimeEntryHierarchy(
                activities: projectActivities,
                timeEntries: projectTimeEntries,
                timeEntry: projectGroup.timeEntry
            )
            children.append(contentsOf: timeEntryHierarchy)
        }

        return ActivityHierarchyGroup(
            name: projectName,
            level: .project,
            children: children,
            activities: [],
            timeEntries: []
        )
    }

    /// Builds subproject hierarchy
    private static func buildSubprojectHierarchy(
        subproject: Project,
        activities: [Activity],
        timeEntries: [TimeEntry],
        timeEntry: TimeEntry?
    ) -> [ActivityHierarchyGroup] {
        let subprojectActivities = activities
        let subprojectTimeEntries = timeEntries
        if subprojectActivities.isEmpty, subprojectTimeEntries.isEmpty { return [] }

        let timeEntryHierarchy = buildTimeEntryHierarchy(
            activities: subprojectActivities,
            timeEntries: subprojectTimeEntries,
            timeEntry: timeEntry
        )
        let subprojectGroup = ActivityHierarchyGroup(
            name: subproject.name,
            level: .subproject,
            children: timeEntryHierarchy,
            activities: [],
            timeEntries: []
        )
        return [subprojectGroup]
    }

    /// Builds time entry level hierarchy
    private static func buildTimeEntryHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry],
        timeEntry: TimeEntry?
    ) -> [ActivityHierarchyGroup] {
        // Group time entries by their individual entries for display
        var timeEntryGroups: [ActivityHierarchyGroup] = []

        // Create individual time entry groups
        for entry in timeEntries {
            let timePeriodHierarchy = buildTimePeriodHierarchy(activities: [], timeEntries: [])
            let entryGroup = ActivityHierarchyGroup(
                name: entry.title,
                level: .timeEntry,
                children: timePeriodHierarchy,
                activities: [],
                timeEntries: [entry]
            )
            timeEntryGroups.append(entryGroup)
        }

        // Handle activities - either group under a representative time entry or create time periods
        if !activities.isEmpty {
            if let timeEntry = timeEntry {
                let timePeriodHierarchy = buildTimePeriodHierarchy(activities: activities, timeEntries: [])
                let activityTimeEntryGroup = ActivityHierarchyGroup(
                    name: timeEntry.title,
                    level: .timeEntry,
                    children: timePeriodHierarchy,
                    activities: [],
                    timeEntries: []
                )
                timeEntryGroups.append(activityTimeEntryGroup)
            } else {
                let timePeriodHierarchy = buildTimePeriodHierarchy(activities: activities, timeEntries: [])
                timeEntryGroups.append(contentsOf: timePeriodHierarchy)
            }
        }

        return timeEntryGroups
    }

    /// Builds time period level hierarchy with segmentation logic
    private static func buildTimePeriodHierarchy(activities: [Activity], timeEntries: [TimeEntry] = []) -> [ActivityHierarchyGroup] {
        let timePeriods = segmentActivitiesIntoTimePeriods(activities)
        let timeEntryPeriods = segmentTimeEntriesIntoTimePeriods(timeEntries)

        // Combine all period names
        var allPeriodNames = Set(timePeriods.keys)
        allPeriodNames.formUnion(Set(timeEntryPeriods.keys))

        var timePeriodGroups: [ActivityHierarchyGroup] = []
        for periodName in allPeriodNames {
            let periodActivities = timePeriods[periodName] ?? []
            let periodTimeEntries = timeEntryPeriods[periodName] ?? []

            if !periodActivities.isEmpty || !periodTimeEntries.isEmpty {
                let appNameHierarchy = buildAppNameHierarchy(activities: periodActivities, timeEntries: periodTimeEntries)
                let timePeriodGroup = ActivityHierarchyGroup(
                    name: periodName,
                    level: .timePeriod,
                    children: appNameHierarchy,
                    activities: [],
                    timeEntries: []
                )
                timePeriodGroups.append(timePeriodGroup)
            }
        }
        return timePeriodGroups
    }

    /// Builds app name level hierarchy
    private static func buildAppNameHierarchy(activities: [Activity], timeEntries: [TimeEntry] = []) -> [ActivityHierarchyGroup] {
        let activitiesByApp = Dictionary(grouping: activities) { $0.appName }
        var appNameGroups: [ActivityHierarchyGroup] = []

        // Handle activities grouped by app
        for (appName, appActivities) in activitiesByApp {
            let appTitleHierarchy = buildAppTitleHierarchy(activities: appActivities, timeEntries: [])
            let appNameGroup = ActivityHierarchyGroup(
                name: appName,
                level: .appName,
                children: appTitleHierarchy,
                activities: [],
                timeEntries: []
            )
            appNameGroups.append(appNameGroup)
        }

        // Handle time entries as separate items (they don't have app names)
        if !timeEntries.isEmpty {
            let timeEntryTitleHierarchy = buildAppTitleHierarchy(activities: [], timeEntries: timeEntries)
            let timeEntryGroup = ActivityHierarchyGroup(
                name: "Manual Time Entries",
                level: .appName,
                children: timeEntryTitleHierarchy,
                activities: [],
                timeEntries: []
            )
            appNameGroups.append(timeEntryGroup)
        }

        return appNameGroups.sorted { $0.totalDuration > $1.totalDuration }
    }

    /// Builds app title level hierarchy with grouping logic
    private static func buildAppTitleHierarchy(activities: [Activity], timeEntries: [TimeEntry] = []) -> [ActivityHierarchyGroup] {
        let activitiesByTitle = groupActivitiesByAppTitle(activities)
        var appTitleGroups: [ActivityHierarchyGroup] = []

        // Handle activities grouped by title
        for (titleKey, titleActivities) in activitiesByTitle {
            let appTitleGroup = ActivityHierarchyGroup(
                name: titleKey,
                level: .appTitle,
                children: [],
                activities: titleActivities,
                timeEntries: []
            )
            appTitleGroups.append(appTitleGroup)
        }

        // Handle time entries individually
        for timeEntry in timeEntries {
            let timeEntryGroup = ActivityHierarchyGroup(
                name: timeEntry.title,
                level: .appTitle,
                children: [],
                activities: [],
                timeEntries: [timeEntry]
            )
            appTitleGroups.append(timeEntryGroup)
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
            if periods[periodName] == nil { periods[periodName] = [] }
            periods[periodName]?.append(activity)
        }
        return periods
    }

    /// Segments time entries into meaningful time periods
    private static func segmentTimeEntriesIntoTimePeriods(_ timeEntries: [TimeEntry]) -> [String: [TimeEntry]] {
        var periods: [String: [TimeEntry]] = [:]
        for timeEntry in timeEntries {
            let periodName = determineTimePeriod(for: timeEntry.startTime)
            if periods[periodName] == nil { periods[periodName] = [] }
            periods[periodName]?.append(timeEntry)
        }
        return periods
    }

    /// Determines the time period name for a given date
    private static func determineTimePeriod(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 0 ..< 6: return "Late Night (12AM-6AM)"
        case 6 ..< 9: return "Early Morning (6AM-9AM)"
        case 9 ..< 12: return "Morning (9AM-12PM)"
        case 12 ..< 14: return "Lunch Time (12PM-2PM)"
        case 14 ..< 17: return "Afternoon (2PM-5PM)"
        case 17 ..< 20: return "Evening (5PM-8PM)"
        case 20 ..< 24: return "Night (8PM-12AM)"
        default: return "Unknown Period"
        }
    }

    /// Groups activities by app title, handling cases where activities have the same title
    private static func groupActivitiesByAppTitle(_ activities: [Activity]) -> [String: [Activity]] {
        var titleGroups: [String: [Activity]] = [:]
        for activity in activities {
            let titleKey = activity.appTitle ?? "No Title"
            if titleGroups[titleKey] == nil { titleGroups[titleKey] = [] }
            titleGroups[titleKey]?.append(activity)
        }
        return titleGroups
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

    // MARK: - Deprecated

    /// Identifies activities that are not assigned to any project
    static func getUnassignedActivities(_ activities: [Activity]) -> [Activity] {
        return activities
    }

    // MARK: - Data Conflict Resolution (Public)

    /// Detects conflicts in activities and time entries
    static func detectConflicts(activities: [Activity], timeEntries: [TimeEntry]) -> [DataConflict] {
        var conflicts: [DataConflict] = []

        // Detect overlapping time entries
        conflicts.append(contentsOf: detectOverlappingTimeEntries(timeEntries))

        // Detect overlapping activities
        conflicts.append(contentsOf: detectOverlappingActivities(activities))

        // Detect activity-time entry mismatches
        conflicts.append(contentsOf: detectActivityTimeEntryMismatches(activities: activities, timeEntries: timeEntries))

        // Detect duplicate entries
        conflicts.append(contentsOf: detectDuplicateEntries(activities: activities, timeEntries: timeEntries))

        // Detect invalid durations and timestamps
        conflicts.append(contentsOf: detectInvalidData(activities: activities, timeEntries: timeEntries))

        return conflicts.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }

    /// Validates data integrity and returns validation result
    static func validateDataIntegrity(activities: [Activity], timeEntries: [TimeEntry]) -> DataValidationResult {
        let conflicts = detectConflicts(activities: activities, timeEntries: timeEntries)
        let warnings = detectDataWarnings(activities: activities, timeEntries: timeEntries)
        let isValid = conflicts.isEmpty

        return DataValidationResult(
            isValid: isValid,
            conflicts: conflicts,
            warnings: warnings
        )
    }

    /// Automatically resolves conflicts where possible
    static func resolveConflictsAutomatically(
        conflicts: [DataConflict],
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> [ConflictResolutionResult] {
        var results: [ConflictResolutionResult] = []

        for conflict in conflicts {
            let result = resolveConflict(
                conflict,
                activities: &activities,
                timeEntries: &timeEntries
            )
            results.append(result)
        }

        return results
    }

    /// Repairs data integrity issues
    static func repairDataIntegrity(activities: inout [Activity], timeEntries: inout [TimeEntry]) -> DataValidationResult {
        var repairedCount = 0

        // Repair time entries
        for timeEntry in timeEntries {
            let wasValid = timeEntry.isValid
            timeEntry.repairDataIntegrity()
            if !wasValid && timeEntry.isValid {
                repairedCount += 1
            }
        }

        // Repair activities
        for activity in activities {
            do {
                try activity.validateContextData()
            } catch {
                // Clear invalid context data
                activity.contextData = nil
                repairedCount += 1
            }

            // Fix negative durations
            if activity.duration < 0 {
                activity.duration = abs(activity.duration)
                repairedCount += 1
            }

            // Fix activities with end time before start time
            if let endTime = activity.endTime, endTime < activity.startTime {
                activity.endTime = activity.startTime.addingTimeInterval(60) // Minimum 1 minute
                activity.duration = 60
                repairedCount += 1
            }
        }

        // Re-validate after repairs
        let validationResult = validateDataIntegrity(activities: activities, timeEntries: timeEntries)
        return DataValidationResult(
            isValid: validationResult.isValid,
            conflicts: validationResult.conflicts,
            warnings: validationResult.warnings,
            repairedItems: repairedCount
        )
    }

    // MARK: - Private Conflict Detection Methods

    /// Detects overlapping time entries
    private static func detectOverlappingTimeEntries(_ timeEntries: [TimeEntry]) -> [DataConflict] {
        var conflicts: [DataConflict] = []
        let sortedEntries = timeEntries.sorted { $0.startTime < $1.startTime }

        for i in 0 ..< sortedEntries.count {
            for j in (i + 1) ..< sortedEntries.count {
                let entry1 = sortedEntries[i]
                let entry2 = sortedEntries[j]

                if entry1.overlaps(with: entry2) {
                    let overlapDuration = entry1.overlapDuration(with: entry2)
                    let conflict = DataConflict(
                        type: .overlappingTimeEntries,
                        items: [.timeEntry(entry1), .timeEntry(entry2)],
                        overlapDuration: overlapDuration
                    )
                    conflicts.append(conflict)
                }
            }
        }

        return conflicts
    }

    /// Detects overlapping activities
    private static func detectOverlappingActivities(_ activities: [Activity]) -> [DataConflict] {
        var conflicts: [DataConflict] = []
        let completedActivities = activities.filter { $0.endTime != nil }
        let sortedActivities = completedActivities.sorted { $0.startTime < $1.startTime }

        for i in 0 ..< sortedActivities.count {
            for j in (i + 1) ..< sortedActivities.count {
                let activity1 = sortedActivities[i]
                let activity2 = sortedActivities[j]

                guard let end1 = activity1.endTime, let end2 = activity2.endTime else { continue }

                // Check for overlap
                if activity1.startTime < end2, end1 > activity2.startTime {
                    let overlapStart = max(activity1.startTime, activity2.startTime)
                    let overlapEnd = min(end1, end2)
                    let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)

                    if overlapDuration > 0 {
                        let conflict = DataConflict(
                            type: .overlappingActivities,
                            items: [.activity(activity1), .activity(activity2)],
                            overlapDuration: overlapDuration
                        )
                        conflicts.append(conflict)
                    }
                }
            }
        }

        return conflicts
    }

    /// Detects mismatches between activities and time entries
    private static func detectActivityTimeEntryMismatches(activities: [Activity], timeEntries: [TimeEntry]) -> [DataConflict] {
        var conflicts: [DataConflict] = []
        let activityMatches = matchActivitiesToTimeEntries(activities, timeEntries)

        for (activityId, matches) in activityMatches {
            guard let activity = activities.first(where: { $0.id == activityId }),
                  let bestMatch = matches.first else { continue }

            let timeEntry = bestMatch.timeEntry
            let overlapDuration = bestMatch.overlapDuration

            // Check if overlap is significantly less than either duration
            let activityDuration = activity.duration
            let timeEntryDuration = timeEntry.duration
            let minDuration = min(activityDuration, timeEntryDuration)

            if overlapDuration < minDuration * 0.5 { // Less than 50% overlap
                let conflict = DataConflict(
                    type: .activityTimeEntryMismatch,
                    items: [.activity(activity), .timeEntry(timeEntry)],
                    overlapDuration: overlapDuration
                )
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    /// Detects duplicate entries
    private static func detectDuplicateEntries(activities: [Activity], timeEntries: [TimeEntry]) -> [DataConflict] {
        var conflicts: [DataConflict] = []

        // Check for duplicate time entries
        let timeEntryGroups = Dictionary(grouping: timeEntries) { entry in
            "\(entry.startTime.timeIntervalSince1970)_\(entry.endTime.timeIntervalSince1970)_\(entry.title)"
        }

        for (_, entries) in timeEntryGroups where entries.count > 1 {
            let conflict = DataConflict(
                type: .duplicateEntries,
                items: entries.map { .timeEntry($0) },
                overlapDuration: entries.first?.duration ?? 0
            )
            conflicts.append(conflict)
        }

        // Check for duplicate activities
        let activityGroups = Dictionary(grouping: activities) { activity in
            "\(activity.startTime.timeIntervalSince1970)_\(activity.endTime?.timeIntervalSince1970 ?? 0)_\(activity.appBundleId)"
        }

        for (_, activities) in activityGroups where activities.count > 1 {
            let conflict = DataConflict(
                type: .duplicateEntries,
                items: activities.map { .activity($0) },
                overlapDuration: activities.first?.duration ?? 0
            )
            conflicts.append(conflict)
        }

        return conflicts
    }

    /// Detects invalid data (durations, timestamps)
    private static func detectInvalidData(activities: [Activity], timeEntries: [TimeEntry]) -> [DataConflict] {
        var conflicts: [DataConflict] = []
        let now = Date()
        let futureThreshold = now.addingTimeInterval(3600) // 1 hour in future

        // Check time entries for invalid data
        for timeEntry in timeEntries {
            // Invalid duration
            if timeEntry.duration <= 0 || timeEntry.calculatedDuration <= 0 {
                let conflict = DataConflict(
                    type: .invalidDuration,
                    items: [.timeEntry(timeEntry)],
                    overlapDuration: 0
                )
                conflicts.append(conflict)
            }

            // Future timestamps
            if timeEntry.startTime > futureThreshold || timeEntry.endTime > futureThreshold {
                let conflict = DataConflict(
                    type: .futureTimestamp,
                    items: [.timeEntry(timeEntry)],
                    overlapDuration: 0
                )
                conflicts.append(conflict)
            }
        }

        // Check activities for invalid data
        for activity in activities {
            // Invalid duration
            if activity.duration <= 0 {
                let conflict = DataConflict(
                    type: .invalidDuration,
                    items: [.activity(activity)],
                    overlapDuration: 0
                )
                conflicts.append(conflict)
            }

            // Future timestamps
            if activity.startTime > futureThreshold {
                let conflict = DataConflict(
                    type: .futureTimestamp,
                    items: [.activity(activity)],
                    overlapDuration: 0
                )
                conflicts.append(conflict)
            }

            if let endTime = activity.endTime, endTime > futureThreshold {
                let conflict = DataConflict(
                    type: .futureTimestamp,
                    items: [.activity(activity)],
                    overlapDuration: 0
                )
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    /// Detects data warnings for non-critical issues
    private static func detectDataWarnings(activities: [Activity], timeEntries: [TimeEntry]) -> [DataWarning] {
        var warnings: [DataWarning] = []

        // Check for very short durations
        for timeEntry in timeEntries where timeEntry.duration < 60 {
            warnings.append(DataWarning(
                type: .shortDuration,
                message: "Time entry has very short duration (\(Int(timeEntry.duration))s)",
                item: .timeEntry(timeEntry)
            ))
        }

        // Check for very long durations
        for timeEntry in timeEntries where timeEntry.duration > 8 * 3600 { // 8 hours
            warnings.append(DataWarning(
                type: .longDuration,
                message: "Time entry has very long duration (\(formatDuration(timeEntry.duration)))",
                item: .timeEntry(timeEntry)
            ))
        }

        // Check for activities without context
        for activity in activities where activity.windowTitle == nil && activity.url == nil {
            warnings.append(DataWarning(
                type: .missingContext,
                message: "Activity lacks context information (window title, URL)",
                item: .activity(activity)
            ))
        }

        return warnings
    }

    /// Resolves a single conflict
    private static func resolveConflict(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        switch conflict.suggestedResolution {
        case .mergeItems:
            return mergeConflictItems(conflict, activities: &activities, timeEntries: &timeEntries)
        case .keepFirst:
            return keepFirstItem(conflict, activities: &activities, timeEntries: &timeEntries)
        case .keepLast:
            return keepLastItem(conflict, activities: &activities, timeEntries: &timeEntries)
        case .keepLongest:
            return keepLongestItem(conflict, activities: &activities, timeEntries: &timeEntries)
        case .splitOverlap:
            return splitOverlappingItems(conflict, activities: &activities, timeEntries: &timeEntries)
        case .deleteInvalid:
            return deleteInvalidItems(conflict, activities: &activities, timeEntries: &timeEntries)
        case .manualReview:
            return ConflictResolutionResult(
                conflictId: conflict.id,
                resolution: .manualReview,
                success: false,
                error: ConflictResolutionError.requiresManualReview
            )
        }
    }

    // MARK: - Private Conflict Resolution Methods

    private static func mergeConflictItems(
        _ conflict: DataConflict,
        activities _: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        guard conflict.items.count == 2 else {
            return ConflictResolutionResult(
                conflictId: conflict.id,
                resolution: .mergeItems,
                success: false,
                error: ConflictResolutionError.cannotMergeMultipleItems
            )
        }

        let item1 = conflict.items[0]
        let item2 = conflict.items[1]

        // Only merge time entries for now
        if case let .timeEntry(entry1) = item1, case let .timeEntry(entry2) = item2 {
            let mergedStartTime = min(entry1.startTime, entry2.startTime)
            let mergedEndTime = max(entry1.endTime, entry2.endTime)
            let mergedTitle = "\(entry1.title) + \(entry2.title)"

            // Create merged entry
            let mergedEntry = TimeEntry(
                projectId: entry1.projectId ?? entry2.projectId,
                title: mergedTitle,
                notes: [entry1.notes, entry2.notes].compactMap { $0 }.joined(separator: "; "),
                startTime: mergedStartTime,
                endTime: mergedEndTime
            )

            // Remove original entries and add merged one
            timeEntries.removeAll { $0.id == entry1.id || $0.id == entry2.id }
            timeEntries.append(mergedEntry)

            return ConflictResolutionResult(
                conflictId: conflict.id,
                resolution: .mergeItems,
                success: true,
                modifiedItems: [.timeEntry(mergedEntry)],
                deletedItems: [item1, item2]
            )
        }

        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .mergeItems,
            success: false,
            error: ConflictResolutionError.unsupportedMergeOperation
        )
    }

    private static func keepFirstItem(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        let sortedItems = conflict.items.sorted { $0.startTime < $1.startTime }
        let itemToKeep = sortedItems.first!
        let itemsToDelete = Array(sortedItems.dropFirst())

        // Remove items to delete
        for item in itemsToDelete {
            switch item {
            case let .activity(activity):
                activities.removeAll { $0.id == activity.id }
            case let .timeEntry(timeEntry):
                timeEntries.removeAll { $0.id == timeEntry.id }
            }
        }

        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .keepFirst,
            success: true,
            modifiedItems: [itemToKeep],
            deletedItems: itemsToDelete
        )
    }

    private static func keepLastItem(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        let sortedItems = conflict.items.sorted { $0.startTime < $1.startTime }
        let itemToKeep = sortedItems.last!
        let itemsToDelete = Array(sortedItems.dropLast())

        // Remove items to delete
        for item in itemsToDelete {
            switch item {
            case let .activity(activity):
                activities.removeAll { $0.id == activity.id }
            case let .timeEntry(timeEntry):
                timeEntries.removeAll { $0.id == timeEntry.id }
            }
        }

        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .keepLast,
            success: true,
            modifiedItems: [itemToKeep],
            deletedItems: itemsToDelete
        )
    }

    private static func keepLongestItem(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        let sortedItems = conflict.items.sorted { $0.duration > $1.duration }
        let itemToKeep = sortedItems.first!
        let itemsToDelete = Array(sortedItems.dropFirst())

        // Remove items to delete
        for item in itemsToDelete {
            switch item {
            case let .activity(activity):
                activities.removeAll { $0.id == activity.id }
            case let .timeEntry(timeEntry):
                timeEntries.removeAll { $0.id == timeEntry.id }
            }
        }

        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .keepLongest,
            success: true,
            modifiedItems: [itemToKeep],
            deletedItems: itemsToDelete
        )
    }

    private static func splitOverlappingItems(
        _ conflict: DataConflict,
        activities _: inout [Activity],
        timeEntries _: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        // This is a complex operation that would require creating new items
        // For now, return as requiring manual review
        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .splitOverlap,
            success: false,
            error: ConflictResolutionError.requiresManualReview
        )
    }

    private static func deleteInvalidItems(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        var deletedItems: [ConflictItem] = []

        for item in conflict.items {
            switch item {
            case let .activity(activity):
                if activity.duration <= 0 || activity.startTime > Date().addingTimeInterval(3600) {
                    activities.removeAll { $0.id == activity.id }
                    deletedItems.append(item)
                }
            case let .timeEntry(timeEntry):
                if timeEntry.duration <= 0 || !timeEntry.isValid {
                    timeEntries.removeAll { $0.id == timeEntry.id }
                    deletedItems.append(item)
                }
            }
        }

        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .deleteInvalid,
            success: true,
            deletedItems: deletedItems
        )
    }

    // MARK: - Constants

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
}

// MARK: - Conflict Resolution Errors

enum ConflictResolutionError: LocalizedError {
    case requiresManualReview
    case cannotMergeMultipleItems
    case unsupportedMergeOperation
    case dataIntegrityViolation

    var errorDescription: String? {
        switch self {
        case .requiresManualReview:
            return "This conflict requires manual review and resolution"
        case .cannotMergeMultipleItems:
            return "Cannot automatically merge more than two items"
        case .unsupportedMergeOperation:
            return "This type of merge operation is not supported"
        case .dataIntegrityViolation:
            return "Resolution would violate data integrity constraints"
        }
    }
}
