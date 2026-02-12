import Foundation
import SwiftData
import os

/// Central coordinator for all analysis operations
/// Orchestrates the flow from activities → sessions → blocks → structure → insight
@MainActor
final class AnalysisManager: ObservableObject {
    private let logger = Logger(subsystem: "dev.leix.chronote", category: "AnalysisManager")
    
    static let shared = AnalysisManager()
    
    // Analyzers
    private let sessionAnalyzer = SessionAnalyzer.shared
    private let behavioralAnalyzer = BehavioralAnalyzer.shared
    private let structureAnalyzer = TimeStructureAnalyzer.shared
    private let insightGenerator = InsightGenerator.shared
    
    // Cache
    @Published private(set) var cachedInsight: DailyInsight?
    @Published private(set) var isAnalyzing = false
    
    private init() {}
    
    /// Performs complete analysis for a given date
    /// This is the main entry point for analysis
    func analyzeDay(_ date: Date, modelContext: ModelContext) async throws -> DailyInsight {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        logger.info("Starting analysis for date: \(date)")
        
        // Step 1: Fetch activities for the date
        let activities = try fetchActivities(for: date, modelContext: modelContext)
        guard !activities.isEmpty else {
            logger.warning("No activities found for \(date)")
            throw AnalysisError.noActivities
        }
        
        // Step 2: Clear existing analysis for this date (reanalysis)
        try clearAnalysis(for: date, modelContext: modelContext)
        
        // Step 3: Create sessions from activities
        let sessions = try sessionAnalyzer.analyzeSessions(from: activities, modelContext: modelContext)
        try modelContext.save()
        logger.info("Created \(sessions.count) sessions")
        
        // Step 4: Create behavioral blocks from sessions
        let blocks = try behavioralAnalyzer.analyzeBlocks(from: sessions, modelContext: modelContext)
        try modelContext.save()
        logger.info("Created \(blocks.count) behavioral blocks")
        
        // Step 5: Create time structure from blocks
        let structure = try structureAnalyzer.analyzeTimeStructure(from: blocks, for: date, modelContext: modelContext)
        try modelContext.save()
        logger.info("Created time structure")
        
        // Step 6: Generate insight
        let insight = try insightGenerator.generateInsight(from: structure, blocks: blocks, for: date, modelContext: modelContext)
        try modelContext.save()
        
        // Step 7: Add comparison with yesterday if available
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date),
           let yesterdayStructure = try structureAnalyzer.getTimeStructure(for: yesterday, modelContext: modelContext) {
            let comparisons = structureAnalyzer.compareStructures(structure, yesterdayStructure)
            insightGenerator.addComparisonMetrics(to: insight, comparisons: comparisons)
            try modelContext.save()
        }
        
        cachedInsight = insight
        logger.info("Analysis complete for \(date)")
        
        return insight
    }
    
    /// Fetches or generates insight for a date
    /// Returns cached insight if available, otherwise performs analysis
    func getOrCreateInsight(for date: Date, modelContext: ModelContext) async throws -> DailyInsight {
        // Check if insight already exists
        if let existing = try insightGenerator.getInsight(for: date, modelContext: modelContext) {
            logger.debug("Using existing insight for \(date)")
            cachedInsight = existing
            return existing
        }
        
        // Generate new insight
        return try await analyzeDay(date, modelContext: modelContext)
    }
    
    /// Gets time structure for a date
    func getTimeStructure(for date: Date, modelContext: ModelContext) throws -> TimeStructure? {
        return try structureAnalyzer.getTimeStructure(for: date, modelContext: modelContext)
    }
    
    /// Gets behavioral blocks for a date
    func getBehavioralBlocks(for date: Date, modelContext: ModelContext) throws -> [BehavioralBlock] {
        return try behavioralAnalyzer.getBlocks(for: date, modelContext: modelContext)
    }
    
    /// Gets sessions for a date
    func getSessions(for date: Date, modelContext: ModelContext) throws -> [Session] {
        return try sessionAnalyzer.getSessions(for: date, modelContext: modelContext)
    }
    
    /// Fetches activities for a given date
    private func fetchActivities(for date: Date, modelContext: ModelContext) throws -> [Activity] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<Activity> { activity in
            activity.startTime >= startOfDay && activity.startTime < endOfDay
        }
        
        let descriptor = FetchDescriptor<Activity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Clears all analysis data for a date (for reanalysis)
    private func clearAnalysis(for date: Date, modelContext: ModelContext) throws {
        try sessionAnalyzer.clearSessions(for: date, modelContext: modelContext)
        try behavioralAnalyzer.clearBlocks(for: date, modelContext: modelContext)
        try structureAnalyzer.clearTimeStructure(for: date, modelContext: modelContext)
        
        // Clear insight
        if let insight = try insightGenerator.getInsight(for: date, modelContext: modelContext) {
            modelContext.delete(insight)
        }
        
        try modelContext.save()
        logger.info("Cleared existing analysis for \(date)")
    }
    
    /// Forces reanalysis for a date
    func reanalyzeDay(_ date: Date, modelContext: ModelContext) async throws -> DailyInsight {
        try clearAnalysis(for: date, modelContext: modelContext)
        return try await analyzeDay(date, modelContext: modelContext)
    }
}

/// Analysis errors
enum AnalysisError: Error, LocalizedError {
    case noActivities
    case noSessions
    case analysisInProgress
    
    var errorDescription: String? {
        switch self {
        case .noActivities:
            return "No activities found for the selected date"
        case .noSessions:
            return "Could not create sessions from activities"
        case .analysisInProgress:
            return "Analysis is already in progress"
        }
    }
}
