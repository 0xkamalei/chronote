import Foundation

/// Represents a group of activities associated with a project and time entry
struct ProjectActivityGroup {
    let project: Project?
    let timeEntry: TimeEntry?
    let activities: [Activity]
    
    /// Total duration of all activities in this group
    var totalDuration: TimeInterval {
        return activities.reduce(0) { $0 + $1.duration }
    }
    
    /// Formatted total duration string
    var totalDurationString: String {
        return ActivityDataProcessor.formatDuration(totalDuration)
    }
    
    /// Number of activities in this group
    var activityCount: Int {
        return activities.count
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
extension ProjectActivityGroup {
    /// Creates a group for assigned activities (with project and time entry)
    static func assigned(project: Project, timeEntry: TimeEntry?, activities: [Activity]) -> ProjectActivityGroup {
        return ProjectActivityGroup(
            project: project,
            timeEntry: timeEntry,
            activities: activities
        )
    }
    
    /// Creates a group for unassigned activities
    static func unassigned(activities: [Activity]) -> ProjectActivityGroup {
        return ProjectActivityGroup(
            project: nil,
            timeEntry: nil,
            activities: activities
        )
    }
    
    /// Creates a group for activities with time entry but no project
    static func timeEntryOnly(timeEntry: TimeEntry, activities: [Activity]) -> ProjectActivityGroup {
        return ProjectActivityGroup(
            project: nil,
            timeEntry: timeEntry,
            activities: activities
        )
    }
}