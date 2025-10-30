import Foundation

/// Represents a group of activities and time entries associated with a project
struct ProjectTimeEntryGroup {
    let project: Project?
    let timeEntry: TimeEntry?
    let activities: [Activity]
    let timeEntries: [TimeEntry]

    /// Total duration of all activities and time entries in this group
    var totalDuration: TimeInterval {
        let activitiesDuration = activities.reduce(0) { $0 + $1.duration }
        let timeEntriesDuration = timeEntries.reduce(0) { $0 + $1.duration }
        return activitiesDuration + timeEntriesDuration
    }

    /// Formatted total duration string
    var totalDurationString: String {
        return ActivityDataProcessor.formatDuration(totalDuration)
    }

    /// Number of activities in this group
    var activityCount: Int {
        return activities.count
    }
    
    /// Number of time entries in this group
    var timeEntryCount: Int {
        return timeEntries.count
    }
    
    /// Total number of items (activities + time entries) in this group
    var totalItemCount: Int {
        return activities.count + timeEntries.count
    }

    /// Indicates whether this group is assigned to a project
    var isAssigned: Bool {
        return project != nil
    }

    /// Group identifier for UI purposes
    var groupId: String {
        if let project = project {
            return project.id
        } else if let timeEntry = timeEntry {
            return "timeEntry_\(timeEntry.id)"
        } else {
            return "unassigned"
        }
    }

    /// Display name for this group
    var displayName: String {
        if let project = project {
            return project.name
        } else if let timeEntry = timeEntry {
            return timeEntry.title
        } else {
            return "Unassigned"
        }
    }
}

// MARK: - Convenience Initializers

extension ProjectTimeEntryGroup {
    /// Creates a group for assigned activities and time entries (with project)
    static func assigned(project: Project, timeEntry: TimeEntry?, activities: [Activity], timeEntries: [TimeEntry] = []) -> ProjectTimeEntryGroup {
        return ProjectTimeEntryGroup(
            project: project,
            timeEntry: timeEntry,
            activities: activities,
            timeEntries: timeEntries
        )
    }

    /// Creates a group for unassigned activities and time entries
    static func unassigned(activities: [Activity], timeEntries: [TimeEntry] = []) -> ProjectTimeEntryGroup {
        return ProjectTimeEntryGroup(
            project: nil,
            timeEntry: nil,
            activities: activities,
            timeEntries: timeEntries
        )
    }

    /// Creates a group for activities with time entry but no project
    static func timeEntryOnly(timeEntry: TimeEntry, activities: [Activity], timeEntries: [TimeEntry] = []) -> ProjectTimeEntryGroup {
        return ProjectTimeEntryGroup(
            project: nil,
            timeEntry: timeEntry,
            activities: activities,
            timeEntries: timeEntries
        )
    }
    
    /// Creates a group specifically for project-assigned time entries
    static func projectTimeEntries(project: Project, timeEntries: [TimeEntry]) -> ProjectTimeEntryGroup {
        return ProjectTimeEntryGroup(
            project: project,
            timeEntry: nil,
            activities: [],
            timeEntries: timeEntries
        )
    }
}
