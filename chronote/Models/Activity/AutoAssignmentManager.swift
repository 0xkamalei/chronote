import Foundation
import SwiftData
import os.log

/// Manages automatic project assignment rules with caching
@MainActor
final class AutoAssignmentManager {
    static let shared = AutoAssignmentManager()
    
    private let logger = Logger(subsystem: "com.time-vscode.AutoAssignmentManager", category: "Rules")
    
    // Cache: Ordered list of projects for evaluation priority
    private var cachedProjects: [Project] = []
    // Cache: Map of project ID to its rules
    private var cachedRules: [String: [AutoAssignRule]] = [:]
    
    private init() {}
    
    /// Reloads all rules from the database into memory
    func reloadRules(modelContext: ModelContext) {
        do {
            // Fetch all projects sorted by sort order
            let projectDescriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)])
            cachedProjects = try modelContext.fetch(projectDescriptor)
            
            // Fetch all rules
            let ruleDescriptor = FetchDescriptor<AutoAssignRule>()
            let allRules = try modelContext.fetch(ruleDescriptor)
            
            // Group rules by projectId
            cachedRules = Dictionary(grouping: allRules, by: { $0.projectId })
            
            logger.info("Reloaded auto-assignment rules. Projects: \(self.cachedProjects.count), Rules: \(allRules.count)")
        } catch {
            logger.error("Failed to reload rules: \(error.localizedDescription)")
            cachedProjects = []
            cachedRules = [:]
        }
    }
    
    /// Evaluates an activity against cached rules and returns a matching project ID
    func evaluate(activity: Activity) -> String? {
        // Evaluate against projects in order
        for project in cachedProjects {
            if let rules = cachedRules[project.id] {
                for rule in rules {
                    if matches(rule: rule, activity: activity) {
                        logger.debug("Activity '\(activity.appName)' matched project '\(project.name)' via rule '\(rule.value)'")
                        return project.id
                    }
                }
            }
        }
        return nil
    }
    
    private func matches(rule: AutoAssignRule, activity: Activity) -> Bool {
        switch rule.ruleType {
        case .appBundleId:
            return activity.appBundleId == rule.value
            
        case .titleKeyword:
            guard let title = activity.appTitle else { return false }
            return title.localizedCaseInsensitiveContains(rule.value)
        }
    }
}
