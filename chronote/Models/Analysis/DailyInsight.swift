import Foundation
import SwiftData

/// Represents a narrative explanation for a day's time structure
/// Contains the high-level insights and explanations
@Model
final class DailyInsight {
    var id: UUID
    var date: Date
    var headline: String
    var subtext: String
    
    // Reference to time structure
    var timeStructureId: UUID?
    
    // Key metrics stored as JSON-like dictionary
    // Examples: "deepSessions": 2, "longestDeepStart": "10:30 AM"
    var keyMetrics: [String: String]
    
    // Comparison with previous day
    var comparisonMetrics: [String: String]
    
    // Timestamp when this insight was generated
    var generatedAt: Date
    
    init(
        id: UUID = UUID(),
        date: Date,
        headline: String = "",
        subtext: String = "",
        timeStructureId: UUID? = nil,
        keyMetrics: [String: String] = [:],
        comparisonMetrics: [String: String] = [:],
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.headline = headline
        self.subtext = subtext
        self.timeStructureId = timeStructureId
        self.keyMetrics = keyMetrics
        self.comparisonMetrics = comparisonMetrics
        self.generatedAt = generatedAt
    }
}

/// Comparison data structure (not persisted, computed on-demand)
struct ComparisonMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let change: Double // Percentage change, positive or negative
    let isPositive: Bool // Whether positive change is good
    
    var changeFormatted: String {
        let prefix = change >= 0 ? "+" : ""
        return "\(prefix)\(Int(change))%"
    }
    
    var changeIcon: String {
        if abs(change) < 1 {
            return "minus"
        }
        return change > 0 ? "arrow.up" : "arrow.down"
    }
}
