import Foundation

/// Specialized data processing utility class responsible for transforming flat activity data 
/// into the required 6+ level hierarchical structure for display
class ActivityHierarchyBuilder {
    
    // MARK: - Public Interface
    
    /// Builds the complete hierarchy from processed activity data
    /// - Parameters:
    ///   - activities: Array of activities to organize
    ///   - timeEntries: Array of time entries for project associations
    ///   - projects: Array of available projects
    /// - Returns: Array of ActivityGroup representing the root level of the hierarchy
    static func buildHierarchy(
        activities: [Activity],
        timeEntries: [TimeEntry],
        projects: [Project]
    ) -> [ActivityGroup] {
        
        // Step 1: Create project associations using existing logic
        let projectGroups = ActivityDataProcessor.createProjectActivityGroups(
            activities, 
            timeEntries: timeEntries, 
            projects: projects
        )
        
        // Step 2: Build hierarchy for each project group
        var hierarchyGroups: [ActivityGroup] = []
        
        for projectGroup in projectGroups {
            let projectHierarchy = buildProjectHierarchy(projectGroup: projectGroup, projects: projects)
            hierarchyGroups.append(projectHierarchy)
        }
        
        return hierarchyGroups
    }
    
    // MARK: - Private Hierarchy Building Methods
    
    /// Builds the hierarchy for a single project group
    private static func buildProjectHierarchy(
        projectGroup: ProjectActivityGroup,
        projects: [Project]
    ) -> ActivityGroup {
        
        // Level 1: Project
        let projectName = projectGroup.displayName
        let projectActivities = projectGroup.activities
        
        // Find subprojects if this is a parent project
        let subprojects = findSubprojects(for: projectGroup.project, in: projects)
        var children: [ActivityGroup] = []
        
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
        
        return ActivityGroup(
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
    ) -> [ActivityGroup] {
        
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
        
        let subprojectGroup = ActivityGroup(
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
    ) -> [ActivityGroup] {
        
        if let timeEntry = timeEntry {
            // Level 3: Time Entry
            let timePeriodHierarchy = buildTimePeriodHierarchy(activities: activities)
            
            let timeEntryGroup = ActivityGroup(
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
    private static func buildTimePeriodHierarchy(activities: [Activity]) -> [ActivityGroup] {
        
        // Level 4: Time Period - Segment activities into meaningful time periods
        let timePeriods = segmentActivitiesIntoTimePeriods(activities)
        var timePeriodGroups: [ActivityGroup] = []
        
        for (periodName, periodActivities) in timePeriods {
            let appNameHierarchy = buildAppNameHierarchy(activities: periodActivities)
            
            let timePeriodGroup = ActivityGroup(
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
    private static func buildAppNameHierarchy(activities: [Activity]) -> [ActivityGroup] {
        
        // Level 5: App Name - Group by application
        let activitiesByApp = Dictionary(grouping: activities) { $0.appName }
        var appNameGroups: [ActivityGroup] = []
        
        for (appName, appActivities) in activitiesByApp {
            let appTitleHierarchy = buildAppTitleHierarchy(activities: appActivities)
            
            let appNameGroup = ActivityGroup(
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
    private static func buildAppTitleHierarchy(activities: [Activity]) -> [ActivityGroup] {
        
        // Level 6: App Title - Group activities with the same app title under single entries
        let activitiesByTitle = groupActivitiesByAppTitle(activities)
        var appTitleGroups: [ActivityGroup] = []
        
        for (titleKey, titleActivities) in activitiesByTitle {
            let appTitleGroup = ActivityGroup(
                name: titleKey,
                level: .appTitle,
                children: [],
                activities: titleActivities
            )
            
            appTitleGroups.append(appTitleGroup)
        }
        
        return appTitleGroups.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    // MARK: - Helper Methods
    
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
        case 0..<6:
            return "Late Night (12AM-6AM)"
        case 6..<9:
            return "Early Morning (6AM-9AM)"
        case 9..<12:
            return "Morning (9AM-12PM)"
        case 12..<14:
            return "Lunch Time (12PM-2PM)"
        case 14..<17:
            return "Afternoon (2PM-5PM)"
        case 17..<20:
            return "Evening (5PM-8PM)"
        case 20..<24:
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
}