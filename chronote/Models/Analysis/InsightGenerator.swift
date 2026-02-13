import Foundation
import SwiftData
import os

/// Generates natural language insights from time structure
/// Creates the narrative explanation for the day
@MainActor
final class InsightGenerator {
    private let logger = Logger(subsystem: "dev.leix.chronote", category: "InsightGenerator")
    
    static let shared = InsightGenerator()
    
    private init() {}
    
    /// Generates a daily insight from time structure and behavioral blocks
    func generateInsight(
        from structure: TimeStructure,
        blocks: [BehavioralBlock],
        for date: Date,
        modelContext: ModelContext
    ) throws -> DailyInsight {
        // Generate headline
        let headline = generateHeadline(structure: structure, blocks: blocks)
        
        // Generate subtext
        let subtext = generateSubtext(structure: structure, blocks: blocks)
        
        // Extract key metrics
        var keyMetrics = extractKeyMetrics(blocks: blocks)
        keyMetrics["analysisVersion"] = AnalysisManager.analysisVersion()
        
        let insight = DailyInsight(
            date: date,
            headline: headline,
            subtext: subtext,
            timeStructureId: structure.id,
            keyMetrics: keyMetrics,
            generatedAt: Date()
        )
        
        modelContext.insert(insight)
        logger.info("Generated insight for \(date): \(headline)")
        
        return insight
    }
    
    /// Generates the headline based on dominant time structure
    private func generateHeadline(structure: TimeStructure, blocks: [BehavioralBlock]) -> String {
        let totalMinutes = Int(structure.totalTracked / 60)
        let deepBlocks = blocks.filter { $0.blockType == .deep }
        let fragmentedBlocks = blocks.filter { $0.blockType == .fragmented }
        
        // Determine dominant pattern
        if structure.deepPercentage > 40 {
            return "This day was productive with \(deepBlocks.count) deep focus sessions totaling \(structure.deepDurationFormatted)."
        } else if structure.fragmentedPercentage > 50 {
            let deepSessionCount = deepBlocks.count
            if deepSessionCount == 0 {
                return "Your day was highly fragmented with no sustained deep focus periods."
            } else {
                return "Your day was mostly fragmented. Only \(deepSessionCount) deep focus sessions occurred, totaling \(structure.deepDurationFormatted)."
            }
        } else if structure.communicationPercentage > 30 {
            return "This day was communication-heavy with \(structure.communicationDurationFormatted) in meetings and messages."
        } else if structure.passivePercentage > 40 {
            return "You spent significant time in passive consumption (\(structure.passiveDurationFormatted)) on this day."
        } else {
            // Balanced day
            return "This day was balanced across different types of work (\(totalMinutes)m total tracked)."
        }
    }
    
    /// Generates supporting subtext with specific details
    private func generateSubtext(structure: TimeStructure, blocks: [BehavioralBlock]) -> String {
        let deepBlocks = blocks.filter { $0.blockType == .deep }.sorted { $0.duration > $1.duration }
        
        if let longestBlock = deepBlocks.first {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let startTime = formatter.string(from: longestBlock.startTime)
            let endTime = formatter.string(from: longestBlock.endTime)
            let appName = longestBlock.dominantActivity ?? "an app"
            
            return "The longest uninterrupted work happened between \(startTime) and \(endTime) in \(appName)."
        } else if blocks.count > 10 {
            return "You switched contexts \(blocks.count) times throughout the day, indicating high fragmentation."
        } else if structure.totalTracked < 2 * 3600 { // Less than 2 hours
            return "Limited tracking data for this day - consider keeping your tracking running longer."
        } else {
            return "Your work pattern shows a mix of focused and fragmented periods."
        }
    }
    
    /// Extracts key metrics for detailed view
    private func extractKeyMetrics(blocks: [BehavioralBlock]) -> [String: String] {
        var metrics: [String: String] = [:]
        
        let deepBlocks = blocks.filter { $0.blockType == .deep }
        metrics["deepSessionCount"] = "\(deepBlocks.count)"
        
        if let longestDeep = deepBlocks.max(by: { $0.duration < $1.duration }) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            metrics["longestDeepStart"] = formatter.string(from: longestDeep.startTime)
            metrics["longestDeepDuration"] = longestDeep.durationFormatted
        }
        
        let totalSwitches = blocks.reduce(0) { $0 + $1.contextSwitchCount }
        metrics["totalContextSwitches"] = "\(totalSwitches)"
        
        metrics["totalBlocks"] = "\(blocks.count)"
        
        // Average focus score
        let avgFocus = blocks.isEmpty ? 0 : blocks.reduce(0.0) { $0 + $1.focusScore } / Double(blocks.count)
        metrics["averageFocusScore"] = String(format: "%.2f", avgFocus)
        
        return metrics
    }
    
    /// Retrieves insight for a specific date
    func getInsight(for date: Date, modelContext: ModelContext) throws -> DailyInsight? {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        let predicate = #Predicate<DailyInsight> { insight in
            insight.date == normalizedDate
        }
        
        let descriptor = FetchDescriptor<DailyInsight>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)
        
        return results.first
    }
    
    /// Adds comparison metrics to an existing insight
    func addComparisonMetrics(
        to insight: DailyInsight,
        comparisons: [ComparisonMetric]
    ) {
        var comparisonDict: [String: String] = [:]
        
        for comparison in comparisons {
            comparisonDict[comparison.name] = """
            \(comparison.value) (\(comparison.changeFormatted))
            """
        }
        
        insight.comparisonMetrics = comparisonDict
    }
}
