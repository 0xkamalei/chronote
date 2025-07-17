import SwiftUI
import Foundation

/// Simplified ActivityGroup model for MVP basic grouping functionality
/// Represents a hierarchical grouping structure for organizing activities
struct ActivityGroup: Identifiable {
    let id = UUID()
    let name: String
    let level: HierarchyLevel
    let totalDuration: TimeInterval
    let itemCount: Int
    let children: [ActivityGroup]
    let activities: [Activity]
    
    /// Hierarchy levels supported in the MVP
    enum HierarchyLevel: String, CaseIterable {
        case project = "Project"
        case subproject = "Subproject"
        case timeEntry = "Time Entry"
        case timePeriod = "Time Period"
        case appName = "App Name"
        case appTitle = "App Title"
        
        var displayName: String {
            return self.rawValue
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
    init(name: String, level: HierarchyLevel, children: [ActivityGroup] = [], activities: [Activity] = []) {
        self.name = name
        self.level = level
        self.children = children
        self.activities = activities
        
        // Calculate total duration from children and direct activities
        let childrenDuration = children.reduce(0) { $0 + $1.totalDuration }
        let activitiesDuration = activities.reduce(0) { $0 + $1.duration }
        self.totalDuration = childrenDuration + activitiesDuration
        
        // Calculate total item count
        let childrenCount = children.reduce(0) { $0 + $1.itemCount }
        self.itemCount = childrenCount + activities.count
    }
    
    /// Check if this group has any child groups or activities
    var hasChildren: Bool {
        return !children.isEmpty || !activities.isEmpty
    }
    
    /// Check if this group is empty (no duration or items)
    var isEmpty: Bool {
        return totalDuration == 0 && itemCount == 0
    }
}

// MARK: - Hashable conformance for use in Sets and as Dictionary keys
extension ActivityGroup: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ActivityGroup, rhs: ActivityGroup) -> Bool {
        lhs.id == rhs.id
    }
}