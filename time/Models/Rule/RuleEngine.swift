import Foundation
import SwiftData
import SwiftUI

@MainActor
class RuleEngine: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingStatus: String = ""
    @Published var lastError: Error?
    
    private let ruleManager: RuleManager
    private let modelContext: ModelContext
    
    init(ruleManager: RuleManager, modelContext: ModelContext) {
        self.ruleManager = ruleManager
        self.modelContext = modelContext
    }
    
    // MARK: - Rule Evaluation
    
    /// Evaluate rules for a single activity and return the best matching rule
    func evaluateRules(for activity: Activity) -> Rule? {
        return ruleManager.evaluateRules(for: activity)
    }
    
    /// Evaluate rules for multiple activities and return a dictionary of activity ID to matching rule
    func evaluateRules(for activities: [Activity]) -> [UUID: Rule] {
        var results: [UUID: Rule] = [:]
        
        for activity in activities {
            if let matchingRule = evaluateRules(for: activity) {
                results[activity.id] = matchingRule
            }
        }
        
        return results
    }
    
    /// Get all rules that would match an activity (for preview/testing)
    func getMatchingRules(for activity: Activity) -> [Rule] {
        return ruleManager.getMatchingRules(for: activity)
    }
    
    // MARK: - Rule Application
    
    /// Apply the best matching rule to an activity
    func applyRulesToActivity(_ activity: Activity, projectManager: ProjectManager) throws {
        guard let matchingRule = evaluateRules(for: activity) else {
            return // No matching rule
        }
        
        try ruleManager.applyRule(matchingRule, to: activity, projectManager: projectManager)
    }
    
    /// Apply rules to multiple activities with progress tracking
    func applyRulesToActivities(_ activities: [Activity], projectManager: ProjectManager) async throws {
        isProcessing = true
        processingProgress = 0.0
        processingStatus = "Applying rules to activities..."
        lastError = nil
        
        defer {
            isProcessing = false
            processingProgress = 0.0
            processingStatus = ""
        }
        
        let totalActivities = activities.count
        var processedCount = 0
        
        for activity in activities {
            do {
                try applyRulesToActivity(activity, projectManager: projectManager)
                processedCount += 1
                
                // Update progress
                await MainActor.run {
                    processingProgress = Double(processedCount) / Double(totalActivities)
                    processingStatus = "Processed \(processedCount) of \(totalActivities) activities"
                }
                
                // Yield control periodically to keep UI responsive
                if processedCount % 10 == 0 {
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
            } catch {
                lastError = error
                throw error
            }
        }
    }
    
    // MARK: - Retroactive Rule Application
    
    /// Apply rules retroactively to all activities from a specific date
    func applyRulesRetroactively(from date: Date, projectManager: ProjectManager) async throws {
        isProcessing = true
        processingProgress = 0.0
        processingStatus = "Loading activities..."
        lastError = nil
        
        defer {
            isProcessing = false
            processingProgress = 0.0
            processingStatus = ""
        }
        
        do {
            // Fetch activities from the specified date
            let predicate = #Predicate<Activity> { activity in
                activity.startTime >= date
            }
            let descriptor = FetchDescriptor<Activity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.startTime)]
            )
            
            let activities = try modelContext.fetch(descriptor)
            
            await MainActor.run {
                processingStatus = "Found \(activities.count) activities to process"
            }
            
            // Apply rules to the activities
            try await applyRulesToActivities(activities, projectManager: projectManager)
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Apply rules retroactively to activities matching specific criteria
    func applyRulesRetroactively(
        from startDate: Date,
        to endDate: Date? = nil,
        appNames: [String]? = nil,
        projectManager: ProjectManager
    ) async throws {
        isProcessing = true
        processingProgress = 0.0
        processingStatus = "Loading activities with criteria..."
        lastError = nil
        
        defer {
            isProcessing = false
            processingProgress = 0.0
            processingStatus = ""
        }
        
        do {
            // Build predicate based on criteria
            let predicate = #Predicate<Activity> { activity in
                (activity.startTime >= startDate && 
                 (endDate == nil || activity.startTime <= endDate!)) &&
                (appNames == nil || appNames!.isEmpty || appNames!.contains(activity.appName))
            }
            
            let descriptor = FetchDescriptor<Activity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.startTime)]
            )
            
            let activities = try modelContext.fetch(descriptor)
            
            await MainActor.run {
                processingStatus = "Found \(activities.count) activities matching criteria"
            }
            
            // Apply rules to the filtered activities
            try await applyRulesToActivities(activities, projectManager: projectManager)
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    // MARK: - Rule Impact Analysis
    
    /// Analyze the potential impact of applying rules to activities
    func analyzeRuleImpact(for activities: [Activity]) -> RuleImpactAnalysis {
        var impactByRule: [UUID: RuleImpact] = [:]
        var totalAffectedActivities = 0
        var unaffectedActivities = 0
        
        for activity in activities {
            if let matchingRule = evaluateRules(for: activity) {
                totalAffectedActivities += 1
                
                if impactByRule[matchingRule.id] == nil {
                    impactByRule[matchingRule.id] = RuleImpact(
                        rule: matchingRule,
                        affectedActivities: [],
                        totalDuration: 0
                    )
                }
                
                impactByRule[matchingRule.id]?.affectedActivities.append(activity)
                impactByRule[matchingRule.id]?.totalDuration += activity.calculatedDuration
            } else {
                unaffectedActivities += 1
            }
        }
        
        return RuleImpactAnalysis(
            totalActivities: activities.count,
            affectedActivities: totalAffectedActivities,
            unaffectedActivities: unaffectedActivities,
            impactByRule: Array(impactByRule.values)
        )
    }
    
    /// Analyze the impact of applying rules retroactively from a date
    func analyzeRetroactiveImpact(from date: Date) throws -> RuleImpactAnalysis {
        let predicate = #Predicate<Activity> { activity in
            activity.startTime >= date
        }
        let descriptor = FetchDescriptor<Activity>(predicate: predicate)
        let activities = try modelContext.fetch(descriptor)
        
        return analyzeRuleImpact(for: activities)
    }
    
    // MARK: - Rule Testing and Preview
    
    /// Test a rule against sample activities without applying it
    func testRule(_ rule: Rule, against activities: [Activity]) -> RuleTestResult {
        var matchingActivities: [Activity] = []
        var totalDuration: TimeInterval = 0
        
        for activity in activities {
            if ruleManager.evaluateRule(rule, against: activity) != nil {
                matchingActivities.append(activity)
                totalDuration += activity.calculatedDuration
            }
        }
        
        return RuleTestResult(
            rule: rule,
            matchingActivities: matchingActivities,
            totalDuration: totalDuration,
            matchPercentage: Double(matchingActivities.count) / Double(activities.count) * 100
        )
    }
    
    /// Preview what would happen if a rule were applied to recent activities
    func previewRuleApplication(_ rule: Rule, daysBack: Int = 7) throws -> RuleTestResult {
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let predicate = #Predicate<Activity> { activity in
            activity.startTime >= startDate
        }
        let descriptor = FetchDescriptor<Activity>(predicate: predicate)
        let activities = try modelContext.fetch(descriptor)
        
        return testRule(rule, against: activities)
    }
    
    // MARK: - Statistics and Reporting
    
    /// Get comprehensive statistics about rule usage and effectiveness
    func getRuleStatistics() -> RuleEngineStatistics {
        let ruleStats = ruleManager.getRuleStatistics()
        
        // Get additional statistics from the database
        do {
            let allActivitiesDescriptor = FetchDescriptor<Activity>()
            let allActivities = try modelContext.fetch(allActivitiesDescriptor)
            
            let rulesEvaluated = evaluateRules(for: allActivities)
            let activitiesWithRules = rulesEvaluated.count
            let activitiesWithoutRules = allActivities.count - activitiesWithRules
            
            return RuleEngineStatistics(
                ruleStatistics: ruleStats,
                totalActivities: allActivities.count,
                activitiesWithMatchingRules: activitiesWithRules,
                activitiesWithoutMatchingRules: activitiesWithoutRules,
                ruleMatchPercentage: Double(activitiesWithRules) / Double(allActivities.count) * 100
            )
        } catch {
            return RuleEngineStatistics(
                ruleStatistics: ruleStats,
                totalActivities: 0,
                activitiesWithMatchingRules: 0,
                activitiesWithoutMatchingRules: 0,
                ruleMatchPercentage: 0
            )
        }
    }
}

// MARK: - Supporting Types

struct RuleImpactAnalysis {
    let totalActivities: Int
    let affectedActivities: Int
    let unaffectedActivities: Int
    let impactByRule: [RuleImpact]
    
    var affectedPercentage: Double {
        guard totalActivities > 0 else { return 0 }
        return Double(affectedActivities) / Double(totalActivities) * 100
    }
}

struct RuleImpact {
    let rule: Rule
    var affectedActivities: [Activity]
    var totalDuration: TimeInterval
    
    var averageDuration: TimeInterval {
        guard !affectedActivities.isEmpty else { return 0 }
        return totalDuration / Double(affectedActivities.count)
    }
}

struct RuleTestResult {
    let rule: Rule
    let matchingActivities: [Activity]
    let totalDuration: TimeInterval
    let matchPercentage: Double
    
    var averageDuration: TimeInterval {
        guard !matchingActivities.isEmpty else { return 0 }
        return totalDuration / Double(matchingActivities.count)
    }
}

struct RuleEngineStatistics {
    let ruleStatistics: RuleStatistics
    let totalActivities: Int
    let activitiesWithMatchingRules: Int
    let activitiesWithoutMatchingRules: Int
    let ruleMatchPercentage: Double
}