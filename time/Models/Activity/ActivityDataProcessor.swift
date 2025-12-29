import Foundation

/// Utility class for processing and organizing activity data
class ActivityDataProcessor {
    // MARK: - Hierarchy Building

    /// Groups activities by project
    /// - Parameters:
    ///   - activities: List of activities to group (assumed to be filtered by time)
    ///   - projects: List of available projects
    /// - Returns: Array of ActivityGroup at .project level
    static func groupByProject(
        activities: [Activity],
        projects: [Project]
    ) -> [ActivityGroup] {
        var groups: [ActivityGroup] = []
        
        // 1. Group activities by project ID
        var activitiesByProject: [String: [Activity]] = [:]
        var unassignedActivities: [Activity] = []
        
        for activity in activities {
            if let projectId = activity.projectId {
                activitiesByProject[projectId, default: []].append(activity)
            } else {
                unassignedActivities.append(activity)
            }
        }
        
        // 2. Create groups for known projects
        for project in projects {
            if let projectActivities = activitiesByProject[project.id.uuidString] { // Assuming project.id is UUID
                let group = ActivityGroup(
                    name: project.name,
                    level: .project,
                    children: [], // Lazy load: no children initially
                    activities: projectActivities,
                    bundleId: nil
                )
                groups.append(group)
            }
        }
        
        // 3. Create group for unassigned (if any)
        if !unassignedActivities.isEmpty {
            let unassignedGroup = ActivityGroup(
                name: "Unassigned",
                level: .project,
                children: [],
                activities: unassignedActivities,
                bundleId: nil
            )
            groups.append(unassignedGroup)
        }
        
        // Optional: Sort by duration descending
        return groups.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    /// Groups activities by app
    /// - Parameter activities: List of activities to group (assumed to be filtered by project)
    /// - Returns: Array of ActivityGroup at .appName level
    static func groupByApp(activities: [Activity]) -> [ActivityGroup] {
        var groups: [ActivityGroup] = []
        
        // 1. Group by Bundle ID
        var activitiesByApp: [String: [Activity]] = [:]
        
        for activity in activities {
            activitiesByApp[activity.appBundleId, default: []].append(activity)
        }
        
        // 2. Create groups
        for (bundleId, appActivities) in activitiesByApp {
            guard let first = appActivities.first else { continue }
            
            let group = ActivityGroup(
                name: first.appName,
                level: .appName,
                children: [], // Lazy load: no children initially
                activities: appActivities,
                bundleId: bundleId
            )
            groups.append(group)
        }
        
        // Sort by duration descending
        return groups.sorted { $0.totalDuration > $1.totalDuration }
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
