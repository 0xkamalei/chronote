import Foundation
import SwiftData
import SwiftUI

@MainActor
class BatchRuleOperations: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var operationHistory: [RuleOperation] = []
    
    private let modelContext: ModelContext
    private let ruleEngine: RuleEngine
    
    init(modelContext: ModelContext, ruleEngine: RuleEngine) {
        self.modelContext = modelContext
        self.ruleEngine = ruleEngine
    }
    
    // MARK: - Batch Operations
    
    /// Apply rules to a batch of activities with detailed tracking
    func applyRulesToBatch(
        activities: [Activity],
        projectManager: ProjectManager,
        createUndoPoint: Bool = true
    ) async throws {
        isProcessing = true
        progress = 0.0
        statusMessage = "Preparing batch operation..."
        
        defer {
            isProcessing = false
            progress = 0.0
            statusMessage = ""
        }
        
        var undoData: [ActivityUndoData] = []
        var appliedRules: [UUID: Int] = [:] // Rule ID to application count
        
        if createUndoPoint {
            // Create undo data for all activities
            undoData = activities.map { activity in
                ActivityUndoData(
                    activityId: activity.id,
                    originalContextData: activity.contextData
                )
            }
        }
        
        let totalActivities = activities.count
        var processedCount = 0
        
        for activity in activities {
            do {
                if let matchingRule = ruleEngine.evaluateRules(for: activity) {
                    try await applyRuleToActivity(matchingRule, activity: activity, projectManager: projectManager)
                    
                    // Track rule applications
                    appliedRules[matchingRule.id, default: 0] += 1
                }
                
                processedCount += 1
                progress = Double(processedCount) / Double(totalActivities)
                statusMessage = "Processed \(processedCount) of \(totalActivities) activities"
                
                // Yield control periodically
                if processedCount % 10 == 0 {
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
            } catch {
                throw BatchOperationError.activityProcessingFailed(activity.id, error)
            }
        }
        
        // Record the operation for undo
        if createUndoPoint {
            let operation = RuleOperation(
                type: .batchApplication,
                timestamp: Date(),
                affectedActivities: undoData,
                appliedRules: appliedRules,
                description: "Applied rules to \(totalActivities) activities"
            )
            operationHistory.append(operation)
            
            // Keep only the last 10 operations
            if operationHistory.count > 10 {
                operationHistory.removeFirst(operationHistory.count - 10)
            }
        }
        
        statusMessage = "Completed processing \(totalActivities) activities"
    }
    
    /// Apply a specific rule retroactively with undo support
    func applyRuleRetroactively(
        rule: Rule,
        from startDate: Date,
        to endDate: Date? = nil,
        appNames: [String]? = nil,
        projectManager: ProjectManager
    ) async throws {
        isProcessing = true
        progress = 0.0
        statusMessage = "Loading activities..."
        
        defer {
            isProcessing = false
            progress = 0.0
            statusMessage = ""
        }
        
        // Fetch activities matching criteria
        let activities = try fetchActivities(
            from: startDate,
            to: endDate,
            appNames: appNames
        )
        
        statusMessage = "Found \(activities.count) activities to process"
        
        // Filter activities that would match this rule
        let matchingActivities = activities.filter { activity in
            ruleEngine.evaluateRules(for: activity)?.id == rule.id
        }
        
        statusMessage = "Applying rule to \(matchingActivities.count) matching activities"
        
        // Apply the rule to matching activities
        try await applyRulesToBatch(
            activities: matchingActivities,
            projectManager: projectManager,
            createUndoPoint: true
        )
    }
    
    // MARK: - Undo Operations
    
    /// Undo the last batch operation
    func undoLastOperation() throws {
        guard let lastOperation = operationHistory.last else {
            throw BatchOperationError.noOperationToUndo
        }
        
        try undoOperation(lastOperation)
        operationHistory.removeLast()
    }
    
    /// Undo a specific operation
    func undoOperation(_ operation: RuleOperation) throws {
        for undoData in operation.affectedActivities {
            // Find the activity using the UUID value directly
            let activityId = undoData.activityId
            let predicate = #Predicate<Activity> { activity in
                activity.id == activityId
            }
            let descriptor = FetchDescriptor<Activity>(predicate: predicate)

            guard let activity = try modelContext.fetch(descriptor).first else {
                continue // Activity might have been deleted
            }

            // Restore original context data
            activity.contextData = undoData.originalContextData
        }

        try modelContext.save()
    }
    
    /// Clear all operation history
    func clearOperationHistory() {
        operationHistory.removeAll()
    }
    
    // MARK: - Progress Tracking and Reporting
    
    /// Get detailed progress information
    func getProgressInfo() -> BatchProgressInfo {
        return BatchProgressInfo(
            isProcessing: isProcessing,
            progress: progress,
            statusMessage: statusMessage,
            canUndo: !operationHistory.isEmpty
        )
    }
    
    /// Generate a report of the last operation
    func generateOperationReport(_ operation: RuleOperation) -> OperationReport {
        let affectedCount = operation.affectedActivities.count
        let rulesApplied = operation.appliedRules.values.reduce(0, +)

        let topRules = operation.appliedRules
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }

        return OperationReport(
            operation: operation,
            affectedActivitiesCount: affectedCount,
            totalRuleApplications: rulesApplied,
            topRules: Array(topRules)
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchActivities(
        from startDate: Date,
        to endDate: Date? = nil,
        appNames: [String]? = nil
    ) throws -> [Activity] {
        // Build the predicate based on which parameters are provided
        let predicate: Predicate<Activity>

        if let endDate = endDate, let appNames = appNames, !appNames.isEmpty {
            // All parameters provided
            predicate = #Predicate<Activity> { activity in
                activity.startTime >= startDate &&
                activity.startTime <= endDate &&
                appNames.contains(activity.appName)
            }
        } else if let endDate = endDate {
            // Only endDate provided
            predicate = #Predicate<Activity> { activity in
                activity.startTime >= startDate && activity.startTime <= endDate
            }
        } else if let appNames = appNames, !appNames.isEmpty {
            // Only appNames provided
            predicate = #Predicate<Activity> { activity in
                activity.startTime >= startDate && appNames.contains(activity.appName)
            }
        } else {
            // Only startDate provided
            predicate = #Predicate<Activity> { activity in
                activity.startTime >= startDate
            }
        }

        let descriptor = FetchDescriptor<Activity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        return try modelContext.fetch(descriptor)
    }
    
    private func applyRuleToActivity(
        _ rule: Rule,
        activity: Activity,
        projectManager: ProjectManager
    ) async throws {
        guard let action = rule.action else {
            throw BatchOperationError.ruleHasNoAction(rule.id)
        }
        
        switch action {
        case .assignToProject(let projectId):
            // This would need integration with ActivityManager
            // For now, store in context data
            var contextDict: [String: Any] = [:]
            if let existingData = activity.contextData {
                contextDict = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            }
            contextDict["assignedProjectId"] = projectId
            contextDict["assignedByRule"] = rule.id.uuidString
            activity.contextData = try JSONSerialization.data(withJSONObject: contextDict)
            
        case .setProductivityScore(let score):
            var contextDict: [String: Any] = [:]
            if let existingData = activity.contextData {
                contextDict = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            }
            contextDict["productivityScore"] = score
            contextDict["assignedByRule"] = rule.id.uuidString
            activity.contextData = try JSONSerialization.data(withJSONObject: contextDict)
            
        case .addTags(let tags):
            var contextDict: [String: Any] = [:]
            if let existingData = activity.contextData {
                contextDict = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            }
            var existingTags = contextDict["tags"] as? [String] ?? []
            existingTags.append(contentsOf: tags)
            contextDict["tags"] = Array(Set(existingTags))
            contextDict["assignedByRule"] = rule.id.uuidString
            activity.contextData = try JSONSerialization.data(withJSONObject: contextDict)
            
        case .ignore:
            var contextDict: [String: Any] = [:]
            if let existingData = activity.contextData {
                contextDict = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            }
            contextDict["ignored"] = true
            contextDict["assignedByRule"] = rule.id.uuidString
            activity.contextData = try JSONSerialization.data(withJSONObject: contextDict)
        }
        
        // Record that the rule was applied
        rule.recordApplication()
    }
}

// MARK: - Supporting Types

struct ActivityUndoData {
    let activityId: UUID
    let originalContextData: Data?
}

struct RuleOperation {
    let id = UUID()
    let type: OperationType
    let timestamp: Date
    let affectedActivities: [ActivityUndoData]
    let appliedRules: [UUID: Int] // Rule ID to application count
    let description: String
    
    enum OperationType {
        case batchApplication
        case retroactiveApplication
        case singleRuleApplication
    }
}

struct BatchProgressInfo {
    let isProcessing: Bool
    let progress: Double
    let statusMessage: String
    let canUndo: Bool
}

struct OperationReport {
    let operation: RuleOperation
    let affectedActivitiesCount: Int
    let totalRuleApplications: Int
    let topRules: [(UUID, Int)]

    var summary: String {
        return "\(operation.description) - \(affectedActivitiesCount) activities affected, \(totalRuleApplications) rule applications"
    }
}

enum BatchOperationError: LocalizedError {
    case noOperationToUndo
    case activityProcessingFailed(UUID, Error)
    case ruleHasNoAction(UUID)
    case invalidDateRange
    
    var errorDescription: String? {
        switch self {
        case .noOperationToUndo:
            return "No operation available to undo"
        case .activityProcessingFailed(let activityId, let error):
            return "Failed to process activity \(activityId): \(error.localizedDescription)"
        case .ruleHasNoAction(let ruleId):
            return "Rule \(ruleId) has no action defined"
        case .invalidDateRange:
            return "Invalid date range specified"
        }
    }
}