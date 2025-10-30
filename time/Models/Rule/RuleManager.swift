import Foundation
import SwiftData
import SwiftUI

@MainActor
class RuleManager: ObservableObject {
    @Published var rules: [Rule] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRules()
    }
    
    // MARK: - Rule CRUD Operations
    
    /// Load all rules from the database
    func loadRules() {
        isLoading = true
        error = nil
        
        do {
            let descriptor = FetchDescriptor<Rule>(
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt)]
            )
            rules = try modelContext.fetch(descriptor)
            
            // Load transient data for each rule
            for rule in rules {
                rule.loadFromData()
            }
        } catch {
            self.error = error
            rules = []
        }
        
        isLoading = false
    }
    
    /// Create a new rule
    func createRule(name: String, conditions: [RuleCondition], action: RuleAction, priority: Int = 0) throws {
        let rule = Rule(name: name, conditions: conditions, action: action, priority: priority)
        
        // Validate the rule before saving
        try rule.validate()
        
        modelContext.insert(rule)
        try modelContext.save()
        
        rules.append(rule)
        sortRules()
    }
    
    /// Update an existing rule
    func updateRule(_ rule: Rule, name: String? = nil, conditions: [RuleCondition]? = nil, action: RuleAction? = nil, priority: Int? = nil, isEnabled: Bool? = nil) throws {
        try rule.update(name: name, conditions: conditions, action: action, priority: priority, isEnabled: isEnabled)
        try rule.validate()
        try modelContext.save()
        
        sortRules()
    }
    
    /// Delete a rule
    func deleteRule(_ rule: Rule) throws {
        modelContext.delete(rule)
        try modelContext.save()
        
        rules.removeAll { $0.id == rule.id }
    }
    
    /// Toggle rule enabled state
    func toggleRule(_ rule: Rule) throws {
        try updateRule(rule, isEnabled: !rule.isEnabled)
    }
    
    /// Duplicate a rule
    func duplicateRule(_ rule: Rule) throws {
        let newName = "Copy of \(rule.name)"
        try createRule(name: newName, conditions: rule.conditions, action: rule.action!, priority: rule.priority)
    }
    
    // MARK: - Rule Evaluation
    
    /// Evaluate all rules against an activity and return the best matching rule
    func evaluateRules(for activity: Activity) -> Rule? {
        let enabledRules = rules.filter { $0.isEnabled }
        var matchingRules: [(rule: Rule, specificity: Int)] = []
        
        for rule in enabledRules {
            if let specificity = evaluateRule(rule, against: activity) {
                matchingRules.append((rule: rule, specificity: specificity))
            }
        }
        
        // Sort by priority (higher first), then by specificity (higher first)
        matchingRules.sort { first, second in
            if first.rule.priority != second.rule.priority {
                return first.rule.priority > second.rule.priority
            }
            return first.specificity > second.specificity
        }
        
        return matchingRules.first?.rule
    }
    
    /// Evaluate a single rule against an activity
    /// Returns specificity score if rule matches, nil if it doesn't match
    func evaluateRule(_ rule: Rule, against activity: Activity) -> Int? {
        var specificity = 0
        
        // All conditions must match for the rule to apply
        for condition in rule.conditions {
            if let conditionSpecificity = evaluateCondition(condition, against: activity) {
                specificity += conditionSpecificity
            } else {
                return nil // Condition doesn't match, rule doesn't apply
            }
        }
        
        return specificity
    }
    
    /// Evaluate a single condition against an activity
    /// Returns specificity score if condition matches, nil if it doesn't match
    private func evaluateCondition(_ condition: RuleCondition, against activity: Activity) -> Int? {
        switch condition {
        case .appName(let pattern, let matchType):
            return evaluateStringMatch(activity.appName, pattern: pattern, matchType: matchType, baseSpecificity: 10)
            
        case .windowTitle(let pattern, let matchType):
            guard let windowTitle = activity.windowTitle else { return nil }
            return evaluateStringMatch(windowTitle, pattern: pattern, matchType: matchType, baseSpecificity: 20)
            
        case .url(let pattern, let matchType):
            guard let url = activity.url else { return nil }
            return evaluateStringMatch(url, pattern: pattern, matchType: matchType, baseSpecificity: 15)
            
        case .documentPath(let pattern, let matchType):
            guard let documentPath = activity.documentPath else { return nil }
            return evaluateStringMatch(documentPath, pattern: pattern, matchType: matchType, baseSpecificity: 15)
            
        case .timeRange(let start, let end):
            return RuleEvaluator.timeInRange(activity.startTime, start: start, end: end) ? 5 : nil
            
        case .dayOfWeek(let days):
            return RuleEvaluator.dateMatchesDaysOfWeek(activity.startTime, days: days) ? 5 : nil
            
        case .duration(let comparison, let minutes):
            return RuleEvaluator.durationMatches(activity.calculatedDuration, comparison: comparison, targetMinutes: minutes) ? 10 : nil
        }
    }
    
    /// Evaluate string matching with different match types using advanced algorithms
    private func evaluateStringMatch(_ text: String, pattern: String, matchType: RuleCondition.MatchType, baseSpecificity: Int) -> Int? {
        let lowercaseText = text.lowercased()
        let lowercasePattern = pattern.lowercased()
        
        switch matchType {
        case .contains:
            return lowercaseText.contains(lowercasePattern) ? baseSpecificity : nil
        case .doesNotContain:
            return !lowercaseText.contains(lowercasePattern) ? baseSpecificity : nil
        case .equals:
            return lowercaseText == lowercasePattern ? baseSpecificity + 10 : nil
        case .notEquals:
            return lowercaseText != lowercasePattern ? baseSpecificity : nil
        case .startsWith:
            return lowercaseText.hasPrefix(lowercasePattern) ? baseSpecificity + 5 : nil
        case .endsWith:
            return lowercaseText.hasSuffix(lowercasePattern) ? baseSpecificity + 5 : nil
        case .regex:
            return RuleEvaluator.regexMatch(text, pattern: pattern) ? baseSpecificity + 15 : nil
        }
    }
    
    // MARK: - Rule Application
    
    /// Apply a rule's action to an activity
    func applyRule(_ rule: Rule, to activity: Activity, projectManager: ProjectManager) throws {
        guard let action = rule.action else {
            throw RuleApplicationError.noAction
        }
        
        switch action {
        case .assignToProject(let _):
            // Note: This would need integration with ActivityManager to actually assign the project
            // For now, we just record that the rule was applied
            rule.recordApplication()
            
        case .setProductivityScore(let score):
            // This would need to be implemented in the Activity model
            // For now, we could store it in contextData
            var contextDict: [String: Any] = [:]
            if let existingData = activity.contextData {
                contextDict = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            }
            contextDict["productivityScore"] = score
            activity.contextData = try JSONSerialization.data(withJSONObject: contextDict)
            rule.recordApplication()
            
        case .addTags(let tags):
            // Similar to productivity score, store in contextData
            var contextDict: [String: Any] = [:]
            if let existingData = activity.contextData {
                contextDict = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            }
            var existingTags = contextDict["tags"] as? [String] ?? []
            existingTags.append(contentsOf: tags)
            contextDict["tags"] = Array(Set(existingTags)) // Remove duplicates
            activity.contextData = try JSONSerialization.data(withJSONObject: contextDict)
            rule.recordApplication()
            
        case .ignore:
            // Mark activity as ignored
            var contextDict: [String: Any] = [:]
            if let existingData = activity.contextData {
                contextDict = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            }
            contextDict["ignored"] = true
            activity.contextData = try JSONSerialization.data(withJSONObject: contextDict)
            rule.recordApplication()
        }
        
        try modelContext.save()
    }
    
    /// Apply rules to a batch of activities
    func applyRulesToActivities(_ activities: [Activity], projectManager: ProjectManager, progressCallback: ((Int, Int) -> Void)? = nil) throws {
        for (index, activity) in activities.enumerated() {
            if let matchingRule = evaluateRules(for: activity) {
                try applyRule(matchingRule, to: activity, projectManager: projectManager)
            }
            progressCallback?(index + 1, activities.count)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Sort rules by priority and creation date
    private func sortRules() {
        rules.sort { first, second in
            if first.priority != second.priority {
                return first.priority > second.priority
            }
            return first.createdAt < second.createdAt
        }
    }
    
    /// Get rules that would match a given activity (for testing/preview)
    func getMatchingRules(for activity: Activity) -> [Rule] {
        return rules.filter { rule in
            rule.isEnabled && evaluateRule(rule, against: activity) != nil
        }
    }
    
    /// Get statistics about rule usage
    func getRuleStatistics() -> RuleStatistics {
        let totalRules = rules.count
        let enabledRules = rules.filter { $0.isEnabled }.count
        let totalApplications = rules.reduce(0) { $0 + $1.applicationCount }
        let mostUsedRule = rules.max { $0.applicationCount < $1.applicationCount }
        
        return RuleStatistics(
            totalRules: totalRules,
            enabledRules: enabledRules,
            totalApplications: totalApplications,
            mostUsedRule: mostUsedRule
        )
    }
}

// MARK: - Supporting Types

struct RuleStatistics {
    let totalRules: Int
    let enabledRules: Int
    let totalApplications: Int
    let mostUsedRule: Rule?
}

enum RuleApplicationError: LocalizedError {
    case noAction
    case projectNotFound
    case invalidAction
    
    var errorDescription: String? {
        switch self {
        case .noAction:
            return "Rule has no action defined"
        case .projectNotFound:
            return "Target project not found"
        case .invalidAction:
            return "Invalid rule action"
        }
    }
}