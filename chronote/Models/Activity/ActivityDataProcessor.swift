import Foundation

/// Utility class for processing and organizing activity data
class ActivityDataProcessor {
 

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
            if let projectActivities = activitiesByProject[project.id] {
                // Recursively group children by App
                let children = groupByApp(activities: projectActivities, parentId: project.id)
                
                let group = ActivityGroup(
                    id: project.id,
                    name: project.name,
                    level: .project,
                    children: children,
                    activities: projectActivities,
                    bundleId: nil
                )
                groups.append(group)
            }
        }
        
        // 3. Create group for unassigned (if any)
        if !unassignedActivities.isEmpty {
            let unassignedId = "unassigned-project"
            let children = groupByApp(activities: unassignedActivities, parentId: unassignedId)
            
            let unassignedGroup = ActivityGroup(
                id: unassignedId,
                name: "Unassigned",
                level: .project,
                children: children,
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
    static func groupByApp(activities: [Activity], parentId: String? = nil) -> [ActivityGroup]? {
        var groups: [ActivityGroup] = []
        
        // 1. Group by Bundle ID
        var activitiesByApp: [String: [Activity]] = [:]
        
        for activity in activities {
            activitiesByApp[activity.appBundleId, default: []].append(activity)
        }
        
        // 2. Create groups
        for (bundleId, appActivities) in activitiesByApp {
            guard let first = appActivities.first else { continue }
            
            let groupId = (parentId != nil) ? "\(parentId!):\(bundleId)" : bundleId
            
            // Recursively group children by Context
            let children: [ActivityGroup]?
            
            if isBrowserApp(bundleId) {
                children = groupByDomain(activities: appActivities, parentId: groupId)
            } else {
                children = groupByAppContext(activities: appActivities, parentId: groupId)
            }
            
            let group = ActivityGroup(
                id: groupId,
                name: first.appName,
                level: .appName,
                children: children,
                activities: appActivities,
                bundleId: bundleId
            )
            groups.append(group)
        }
        
        // Sort by duration descending
        return groups.isEmpty ? nil : groups.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    /// Groups activities by Domain (for Browser apps)
    /// - Parameter activities: List of activities to group (assumed to be filtered by app)
    /// - Returns: Array of ActivityGroup at .domain level
    static func groupByDomain(activities: [Activity], parentId: String) -> [ActivityGroup]? {
        var groups: [ActivityGroup] = []
        var activitiesByDomain: [String: [Activity]] = [:]
        
        for activity in activities {
            var domain = activity.domain
            
            // Fallback: Try to extract domain from webUrl if domain is missing
            if domain == nil, let urlString = activity.webUrl, let url = URL(string: urlString) {
                domain = url.host
            }
            
            let key = domain ?? "Other"
            activitiesByDomain[key, default: []].append(activity)
        }
        
        for (domain, domainActivities) in activitiesByDomain {
            // Use hash of domain to ensure unique ID
            let domainHash = String(domain.hashValue)
            let groupId = "\(parentId):\(domainHash)"
            
            // Recursively group children by Context (Title)
            let children = groupByAppContext(activities: domainActivities, parentId: groupId)
            
            let group = ActivityGroup(
                id: groupId,
                name: domain,
                level: .domain,
                children: children,
                activities: domainActivities,
                bundleId: domainActivities.first?.appBundleId
            )
            groups.append(group)
        }
        
        return groups.isEmpty ? nil : groups.sorted { $0.totalDuration > $1.totalDuration }
    }

    /// Groups activities by context (Title/URL/FilePath)
    /// - Parameter activities: List of activities to group (assumed to be filtered by app)
    /// - Returns: Array of ActivityGroup at .appContext level
    static func groupByAppContext(activities: [Activity], parentId: String) -> [ActivityGroup]? {
        var groups: [ActivityGroup] = []
        var activitiesByContext: [String: [Activity]] = [:]
        
        for activity in activities {
            let context = getContextName(for: activity)
            activitiesByContext[context, default: []].append(activity)
        }
        
        for (context, contextActivities) in activitiesByContext {
            // Use hash of context to ensure unique ID
            let contextHash = String(context.hashValue)
            let groupId = "\(parentId):\(contextHash)"
            
            // Recursively group children by Record (Detail)
            // No need to group further, just map to leaf nodes
            let children = mapToRecordGroups(activities: contextActivities, parentId: groupId)
            
            let group = ActivityGroup(
                id: groupId,
                name: context,
                level: .appContext,
                children: children,
                activities: contextActivities,
                bundleId: contextActivities.first?.appBundleId
            )
            groups.append(group)
        }
        
        return groups.isEmpty ? nil : groups.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    /// Maps activities to individual record groups (Detail level) without re-sorting
    /// - Parameter activities: List of activities
    /// - Returns: Array of ActivityGroup at .detail level
    static func mapToRecordGroups(activities: [Activity], parentId: String) -> [ActivityGroup]? {
        // Ensure strictly sorted by start time descending (newest first)
        // Using stable sort to preserve order of identical times if any
        let sortedActivities = activities.sorted { $0.startTime > $1.startTime }
        
        return sortedActivities.map { activity in
            let startTimeStr = formatTime(activity.startTime)
            let endTimeStr = activity.endTime != nil ? formatTime(activity.endTime!) : "Now"
            let timeRange = "\(startTimeStr) - \(endTimeStr)"
            
            return ActivityGroup(
                id: "\(parentId):\(activity.id.uuidString)",
                name: timeRange,
                level: .detail,
                children: nil, // Leaf node
                activities: [activity],
                bundleId: activity.appBundleId
            )
        }
    }

    // MARK: - Utility Methods
    
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private static func getContextName(for activity: Activity) -> String {
        if let title = activity.appTitle, !title.isEmpty {
            return title
        }
        if let url = activity.webUrl, !url.isEmpty {
            return url
        }
        if let path = activity.filePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        return "Untitled"
    }

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
            "company.thebrowser.Browser",
        ]
        return browsers.contains(bundleId)
    }
}
