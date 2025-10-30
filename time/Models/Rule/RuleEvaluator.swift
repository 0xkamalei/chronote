import Foundation
import SwiftData

/// Advanced rule evaluation utilities and algorithms
class RuleEvaluator {
    
    // MARK: - Advanced Matching Algorithms
    
    /// Fuzzy string matching with similarity scoring
    static func fuzzyMatch(_ text: String, pattern: String, threshold: Double = 0.8) -> Bool {
        let similarity = calculateSimilarity(text.lowercased(), pattern.lowercased())
        return similarity >= threshold
    }
    
    /// Calculate string similarity using Levenshtein distance
    static func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let len1 = str1.count
        let len2 = str2.count
        
        if len1 == 0 { return len2 == 0 ? 1.0 : 0.0 }
        if len2 == 0 { return 0.0 }
        
        let maxLen = max(len1, len2)
        let distance = levenshteinDistance(str1, str2)
        
        return 1.0 - (Double(distance) / Double(maxLen))
    }
    
    /// Calculate Levenshtein distance between two strings
    private static func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let arr1 = Array(str1)
        let arr2 = Array(str2)
        let len1 = arr1.count
        let len2 = arr2.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 {
            matrix[i][0] = i
        }
        
        for j in 0...len2 {
            matrix[0][j] = j
        }
        
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = arr1[i-1] == arr2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[len1][len2]
    }
    
    // MARK: - Pattern Matching
    
    /// Advanced regex matching with error handling and caching
    static func regexMatch(_ text: String, pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> Bool {
        do {
            let regex = try getCachedRegex(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    /// Get regex groups from a match
    static func regexGroups(_ text: String, pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> [String] {
        do {
            let regex = try getCachedRegex(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: text.utf16.count)
            
            guard let match = regex.firstMatch(in: text, options: [], range: range) else {
                return []
            }
            
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                let groupRange = match.range(at: i)
                if groupRange.location != NSNotFound,
                   let range = Range(groupRange, in: text) {
                    groups.append(String(text[range]))
                }
            }
            return groups
        } catch {
            return []
        }
    }
    
    // MARK: - Time-based Matching
    
    /// Check if a time falls within a time range, handling day boundaries
    static func timeInRange(_ time: Date, start: Date, end: Date, allowCrossMidnight: Bool = true) -> Bool {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        
        let timeMinutes = (timeComponents.hour ?? 0) * 60 + (timeComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        if startMinutes <= endMinutes {
            // Normal range (e.g., 9:00 AM to 5:00 PM)
            return timeMinutes >= startMinutes && timeMinutes <= endMinutes
        } else if allowCrossMidnight {
            // Range crosses midnight (e.g., 10:00 PM to 6:00 AM)
            return timeMinutes >= startMinutes || timeMinutes <= endMinutes
        } else {
            return false
        }
    }
    
    /// Check if a date falls on specific days of the week
    static func dateMatchesDaysOfWeek(_ date: Date, days: [Int]) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return days.contains(weekday)
    }
    
    /// Check if an activity duration matches a condition
    static func durationMatches(_ duration: TimeInterval, comparison: RuleCondition.ComparisonType, targetMinutes: Int) -> Bool {
        let durationMinutes = Int(duration / 60)
        
        switch comparison {
        case .greaterThan:
            return durationMinutes > targetMinutes
        case .lessThan:
            return durationMinutes < targetMinutes
        case .equalTo:
            return durationMinutes == targetMinutes
        }
    }
    
    // MARK: - Context-aware Matching
    
    /// Extract domain from URL with validation
    static func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") else {
            return nil
        }
        return url.host?.lowercased()
    }
    
    /// Extract filename from document path
    static func extractFilename(from path: String) -> String {
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    /// Extract file extension from document path
    static func extractFileExtension(from path: String) -> String {
        return URL(fileURLWithPath: path).pathExtension.lowercased()
    }
    
    /// Check if an app is a browser
    static func isBrowserApp(_ bundleId: String) -> Bool {
        let browserBundleIds = [
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.operasoftware.Opera",
            "com.brave.Browser",
            "org.webkit.nightly.WebKit"
        ]
        return browserBundleIds.contains(bundleId)
    }
    
    /// Check if an app is a code editor
    static func isCodeEditor(_ bundleId: String) -> Bool {
        let codeEditorBundleIds = [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.jetbrains.intellij",
            "com.sublimetext.4",
            "com.github.atom",
            "com.vim.MacVim",
            "com.coteditor.CotEditor"
        ]
        return codeEditorBundleIds.contains(bundleId)
    }
    
    // MARK: - Rule Conflict Resolution
    
    /// Resolve conflicts between multiple matching rules
    static func resolveRuleConflicts(_ matchingRules: [(rule: Rule, specificity: Int)]) -> Rule? {
        guard !matchingRules.isEmpty else { return nil }
        
        // Sort by priority (higher first), then by specificity (higher first), then by creation date (newer first)
        let sortedRules = matchingRules.sorted { first, second in
            if first.rule.priority != second.rule.priority {
                return first.rule.priority > second.rule.priority
            }
            if first.specificity != second.specificity {
                return first.specificity > second.specificity
            }
            return first.rule.createdAt > second.rule.createdAt
        }
        
        return sortedRules.first?.rule
    }
    
    /// Calculate rule specificity based on condition types
    static func calculateRuleSpecificity(_ rule: Rule) -> Int {
        var specificity = 0
        
        for condition in rule.conditions {
            switch condition {
            case .appName(_, let matchType):
                specificity += matchType == .equals ? 20 : 10
            case .windowTitle(_, let matchType):
                specificity += matchType == .equals ? 30 : 20
            case .url(_, let matchType):
                specificity += matchType == .equals ? 25 : 15
            case .documentPath(_, let matchType):
                specificity += matchType == .equals ? 25 : 15
            case .timeRange:
                specificity += 5
            case .dayOfWeek:
                specificity += 5
            case .duration:
                specificity += 10
            }
        }
        
        return specificity
    }
    
    // MARK: - Performance Optimization
    
    /// Cache for compiled regular expressions
    private static var regexCache: [String: NSRegularExpression] = [:]
    private static let regexCacheQueue = DispatchQueue(label: "rule.regex.cache", attributes: .concurrent)
    
    /// Get cached regex or create and cache new one
    private static func getCachedRegex(pattern: String, options: NSRegularExpression.Options) throws -> NSRegularExpression {
        let cacheKey = "\(pattern)_\(options.rawValue)"
        
        return try regexCacheQueue.sync {
            if let cachedRegex = regexCache[cacheKey] {
                return cachedRegex
            }
            
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            regexCache[cacheKey] = regex
            return regex
        }
    }
    
    /// Clear regex cache to free memory
    static func clearRegexCache() {
        regexCacheQueue.async(flags: .barrier) {
            regexCache.removeAll()
        }
    }
    
    // MARK: - Rule Validation Helpers
    
    /// Validate that a rule's conditions are logically consistent
    static func validateRuleLogic(_ rule: Rule) -> [String] {
        var warnings: [String] = []
        
        // Check for contradictory conditions
        let appNameConditions = rule.conditions.compactMap { condition -> (String, RuleCondition.MatchType)? in
            if case .appName(let value, let matchType) = condition {
                return (value, matchType)
            }
            return nil
        }
        
        if appNameConditions.count > 1 {
            let hasEquals = appNameConditions.contains { $0.1 == .equals }
            let hasNotEquals = appNameConditions.contains { $0.1 == .notEquals }
            
            if hasEquals && hasNotEquals {
                warnings.append("Rule has contradictory app name conditions (equals and not equals)")
            }
        }
        
        // Check for overly broad conditions
        let containsConditions = rule.conditions.filter { condition in
            switch condition {
            case .appName(let value, .contains), .windowTitle(let value, .contains), .url(let value, .contains):
                return value.count < 3
            default:
                return false
            }
        }
        
        if !containsConditions.isEmpty {
            warnings.append("Rule has very short 'contains' conditions that may match too broadly")
        }
        
        return warnings
    }
}

// MARK: - Rule Performance Metrics

struct RulePerformanceMetrics {
    let evaluationTime: TimeInterval
    let matchCount: Int
    let totalActivities: Int
    let averageSpecificity: Double
    
    var matchPercentage: Double {
        guard totalActivities > 0 else { return 0 }
        return Double(matchCount) / Double(totalActivities) * 100
    }
    
    var evaluationsPerSecond: Double {
        guard evaluationTime > 0 else { return 0 }
        return Double(totalActivities) / evaluationTime
    }
}