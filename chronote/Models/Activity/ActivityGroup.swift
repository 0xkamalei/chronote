import Foundation

/// Represents a grouping level for activities
enum ActivityGroupLevel {
    case project
    case appName
    case domain
    case appContext
    case detail
}

/// Represents a group of activities
struct ActivityGroup: Identifiable {
    let id: String
    let name: String
    let level: ActivityGroupLevel
    let children: [ActivityGroup]? // Kept for structure, but typically empty in lazy loading
    let activities: [Activity] // The activities belonging to this group
    let bundleId: String? // App bundle identifier for icon lookup

    /// Calculate total duration for this group
    var totalDuration: TimeInterval {
        // Since we aggregate all activities into the group, we can just sum them.
        // If children are present (old model), we'd sum them too, but for lazy load we rely on 'activities' being populated.
        return activities.reduce(0) { $0 + $1.calculatedDuration }
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

    /// Check if this group has activities
    var isEmpty: Bool {
        return activities.isEmpty
    }

    /// Get display icon for this level
    var levelIcon: String {
        switch level {
        case .project:
            return "folder"
        case .appName:
            return "app"
        case .domain:
            return "globe"
        case .appContext:
            return "document"
        case .detail:
            return "clock"
        }
    }
    
    /// Initializer
    init(id: String? = nil, name: String, level: ActivityGroupLevel, children: [ActivityGroup]? = nil, activities: [Activity], bundleId: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.level = level
        self.children = children
        self.activities = activities
        self.bundleId = bundleId
    }
}
