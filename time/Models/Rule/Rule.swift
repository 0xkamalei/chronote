import Foundation
import SwiftData
import SwiftUI

@Model
final class Rule {
    @Attribute(.unique) var id: UUID
    var name: String
    var conditionsData: Data // JSON encoded conditions
    var actionData: Data // JSON encoded action
    var priority: Int
    var isEnabled: Bool = true
    var createdAt: Date
    var lastAppliedAt: Date?
    var applicationCount: Int = 0

    // Transient properties for working with conditions and actions
    @Transient var conditions: [RuleCondition] = []
    @Transient var action: RuleAction?

    init(name: String, conditions: [RuleCondition], action: RuleAction, priority: Int = 0) {
        id = UUID()
        self.name = name
        self.priority = priority
        createdAt = Date()

        // Encode conditions and action to Data
        do {
            let encoder = JSONEncoder()
            conditionsData = try encoder.encode(conditions)
            actionData = try encoder.encode(action)

            // Set transient properties
            self.conditions = conditions
            self.action = action
        } catch {
            // Fallback to empty data if encoding fails
            conditionsData = Data()
            actionData = Data()
            self.conditions = []
            self.action = nil
        }
    }

    /// Load conditions and action from stored data
    func loadFromData() {
        do {
            let decoder = JSONDecoder()
            conditions = try decoder.decode([RuleCondition].self, from: conditionsData)
            action = try decoder.decode(RuleAction.self, from: actionData)
        } catch {
            // Fallback to empty if decoding fails
            conditions = []
            action = nil
        }
    }

    /// Save conditions and action to data
    func saveToData() throws {
        let encoder = JSONEncoder()
        conditionsData = try encoder.encode(conditions)
        if let action = action {
            actionData = try encoder.encode(action)
        }
    }

    /// Update the rule with new conditions and action
    func update(name: String? = nil, conditions: [RuleCondition]? = nil, action: RuleAction? = nil, priority: Int? = nil, isEnabled: Bool? = nil) throws {
        if let name = name {
            self.name = name
        }
        if let conditions = conditions {
            self.conditions = conditions
        }
        if let action = action {
            self.action = action
        }
        if let priority = priority {
            self.priority = priority
        }
        if let isEnabled = isEnabled {
            self.isEnabled = isEnabled
        }

        try saveToData()
    }

    /// Record that this rule was applied
    func recordApplication() {
        lastAppliedAt = Date()
        applicationCount += 1
    }

    /// Validate the rule configuration
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw RuleValidationError.emptyName
        }

        if conditions.isEmpty {
            throw RuleValidationError.noConditions
        }

        if action == nil {
            throw RuleValidationError.noAction
        }

        // Validate each condition
        for condition in conditions {
            try condition.validate()
        }

        // Validate action
        try action?.validate()
    }
}

// MARK: - Rule Conditions

enum RuleCondition: Codable, Equatable {
    case appName(String, MatchType)
    case windowTitle(String, MatchType)
    case url(String, MatchType)
    case documentPath(String, MatchType)
    case timeRange(start: Date, end: Date)
    case dayOfWeek([Int]) // 1-7, Sunday = 1
    case duration(comparison: ComparisonType, minutes: Int)

    enum MatchType: String, Codable, CaseIterable {
        case contains
        case doesNotContain = "does not contain"
        case equals
        case notEquals = "not equals"
        case startsWith = "starts with"
        case endsWith = "ends with"
        case regex = "matches regex"

        var displayName: String {
            return rawValue
        }
    }

    enum ComparisonType: String, Codable, CaseIterable {
        case greaterThan = "greater than"
        case lessThan = "less than"
        case equalTo = "equal to"

        var displayName: String {
            return rawValue
        }
    }

    /// Get the display name for this condition
    var displayName: String {
        switch self {
        case let .appName(value, matchType):
            return "App name \(matchType.displayName) '\(value)'"
        case let .windowTitle(value, matchType):
            return "Window title \(matchType.displayName) '\(value)'"
        case let .url(value, matchType):
            return "URL \(matchType.displayName) '\(value)'"
        case let .documentPath(value, matchType):
            return "Document path \(matchType.displayName) '\(value)'"
        case let .timeRange(start, end):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Time between \(formatter.string(from: start)) and \(formatter.string(from: end))"
        case let .dayOfWeek(days):
            let dayNames = days.map { dayName(for: $0) }.joined(separator: ", ")
            return "Day of week: \(dayNames)"
        case let .duration(comparison, minutes):
            return "Duration \(comparison.displayName) \(minutes) minutes"
        }
    }

    /// Validate the condition
    func validate() throws {
        switch self {
        case let .appName(value, _), let .windowTitle(value, _), let .url(value, _), let .documentPath(value, _):
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw RuleValidationError.emptyConditionValue
            }
        case let .timeRange(start, end):
            if start >= end {
                throw RuleValidationError.invalidTimeRange
            }
        case let .dayOfWeek(days):
            if days.isEmpty || days.contains(where: { $0 < 1 || $0 > 7 }) {
                throw RuleValidationError.invalidDayOfWeek
            }
        case let .duration(_, minutes):
            if minutes <= 0 {
                throw RuleValidationError.invalidDuration
            }
        }
    }

    private func dayName(for day: Int) -> String {
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard day >= 1 && day <= 7 else { return "Invalid" }
        return dayNames[day - 1]
    }
}

// MARK: - Rule Actions

enum RuleAction: Codable, Equatable {
    case assignToProject(String) // Project ID
    case setProductivityScore(Double)
    case addTags([String])
    case ignore // Don't track this activity

    /// Get the display name for this action
    var displayName: String {
        switch self {
        case let .assignToProject(projectId):
            return "Assign to project (ID: \(projectId))"
        case let .setProductivityScore(score):
            return "Set productivity score to \(score)"
        case let .addTags(tags):
            return "Add tags: \(tags.joined(separator: ", "))"
        case .ignore:
            return "Ignore activity"
        }
    }

    /// Validate the action
    func validate() throws {
        switch self {
        case let .assignToProject(projectId):
            if projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw RuleValidationError.emptyProjectId
            }
        case let .setProductivityScore(score):
            if score < 0 || score > 10 {
                throw RuleValidationError.invalidProductivityScore
            }
        case let .addTags(tags):
            if tags.isEmpty || tags.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                throw RuleValidationError.emptyTags
            }
        case .ignore:
            break // Always valid
        }
    }
}

// MARK: - Validation Errors

enum RuleValidationError: LocalizedError {
    case emptyName
    case noConditions
    case noAction
    case emptyConditionValue
    case invalidTimeRange
    case invalidDayOfWeek
    case invalidDuration
    case emptyProjectId
    case invalidProductivityScore
    case emptyTags

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Rule name cannot be empty"
        case .noConditions:
            return "Rule must have at least one condition"
        case .noAction:
            return "Rule must have an action"
        case .emptyConditionValue:
            return "Condition value cannot be empty"
        case .invalidTimeRange:
            return "Start time must be before end time"
        case .invalidDayOfWeek:
            return "Invalid day of week (must be 1-7)"
        case .invalidDuration:
            return "Duration must be greater than 0"
        case .emptyProjectId:
            return "Project ID cannot be empty"
        case .invalidProductivityScore:
            return "Productivity score must be between 0 and 10"
        case .emptyTags:
            return "Tags cannot be empty"
        }
    }
}
