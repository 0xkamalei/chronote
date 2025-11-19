import Foundation

/// Represents a hierarchical level in the activity organization structure
enum ActivityHierarchyLevel {
    case project
    case subproject
    case timeEntry
    case timePeriod
    case appName
    case appTitle
}

/// Represents a group of activities at a specific hierarchy level
struct ActivityHierarchyGroup: Identifiable {
    let id: UUID = UUID()
    let name: String
    let level: ActivityHierarchyLevel
    let children: [ActivityHierarchyGroup]
    let activities: [Activity] // Leaf level activities

    /// Calculate total duration for this group and all children
    var totalDuration: TimeInterval {
        let ownDuration = activities.reduce(0) { $0 + $1.calculatedDuration }
        let childrenDuration = children.reduce(0) { $0 + $1.totalDuration }
        return ownDuration + childrenDuration
    }

    /// Formatted duration string
    var durationString: String {
        let totalSeconds = Int(totalDuration)
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

    /// Check if this group has children or activities
    var isEmpty: Bool {
        return children.isEmpty && activities.isEmpty
    }

    /// Determines indentation level based on hierarchy
    var indentLevel: Int {
        switch level {
        case .project:
            return 0
        case .subproject:
            return 1
        case .timeEntry:
            return 2
        case .timePeriod:
            return 3
        case .appName:
            return 4
        case .appTitle:
            return 5
        }
    }

    /// Get display icon for this level
    var levelIcon: String {
        switch level {
        case .project:
            return "folder"
        case .subproject:
            return "folder.circle"
        case .timeEntry:
            return "doc.text"
        case .timePeriod:
            return "clock"
        case .appName:
            return "app"
        case .appTitle:
            return "document"
        }
    }
}
