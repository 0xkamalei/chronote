import Foundation
import SwiftUI

/// Simplified ActivityGroup model for MVP basic grouping functionality
/// Represents a hierarchical grouping structure for organizing activities and time entries
struct ActivityHierarchyGroup: Identifiable {
    let id = UUID()
    let name: String
    let level: HierarchyLevel
    let totalDuration: TimeInterval
    let itemCount: Int
    let children: [ActivityHierarchyGroup]
    let activities: [Activity]
    let timeEntries: [TimeEntry]

    /// Hierarchy levels supported in the MVP
    enum HierarchyLevel: String, CaseIterable {
        case project = "Project"
        case subproject = "Subproject"
        case timeEntry = "Time Entry"
        case timePeriod = "Time Period"
        case appName = "App Name"
        case appTitle = "App Title"

        var displayName: String {
            return rawValue
        }
    }

    /// Computed property for formatted duration display
    var durationString: String {
        let totalMinutes = Int(totalDuration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m 0s"
        }
    }

    /// Initialize an ActivityGroup with basic properties
    init(name: String, level: HierarchyLevel, children: [ActivityHierarchyGroup] = [], activities: [Activity] = [], timeEntries: [TimeEntry] = []) {
        self.name = name
        self.level = level
        self.children = children
        self.activities = activities
        self.timeEntries = timeEntries

        let childrenDuration = children.reduce(0) { $0 + $1.totalDuration }
        let activitiesDuration = activities.reduce(0) { $0 + $1.duration }
        let timeEntriesDuration = timeEntries.reduce(0) { $0 + $1.duration }
        totalDuration = childrenDuration + activitiesDuration + timeEntriesDuration

        let childrenCount = children.reduce(0) { $0 + $1.itemCount }
        itemCount = childrenCount + activities.count + timeEntries.count
    }

    /// Check if this group has any child groups, activities, or time entries
    var hasChildren: Bool {
        return !children.isEmpty || !activities.isEmpty || !timeEntries.isEmpty
    }

    /// Check if this group is empty (no duration or items)
    var isEmpty: Bool {
        return totalDuration == 0 && itemCount == 0
    }

    /// Check if this group contains only time entries (no activities)
    var hasOnlyTimeEntries: Bool {
        return activities.isEmpty && !timeEntries.isEmpty
    }

    /// Check if this group contains only activities (no time entries)
    var hasOnlyActivities: Bool {
        return !activities.isEmpty && timeEntries.isEmpty
    }

    /// Check if this group contains both activities and time entries
    var hasMixedContent: Bool {
        return !activities.isEmpty && !timeEntries.isEmpty
    }
}

// MARK: - Hashable conformance for use in Sets and as Dictionary keys

extension ActivityHierarchyGroup: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ActivityHierarchyGroup, rhs: ActivityHierarchyGroup) -> Bool {
        lhs.id == rhs.id
    }
}
