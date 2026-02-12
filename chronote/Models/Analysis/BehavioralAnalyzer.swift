import Foundation
import SwiftData
import os

/// Analyzes sessions and classifies them into behavioral blocks
/// Determines the type of behavior (deep, fragmented, passive, etc.)
@MainActor
final class BehavioralAnalyzer {
    private let logger = Logger(subsystem: "dev.leix.chronote", category: "BehavioralAnalyzer")
    
    // Classification thresholds
    private let deepWorkMinDuration: TimeInterval = 30 * 60 // 30 minutes
    private let deepWorkMaxSwitches = 3
    private let fragmentedHighSwitchThreshold = 5
    private let fragmentedShortDurationThreshold: TimeInterval = 10 * 60 // 10 minutes
    
    // App categorization patterns
    private let communicationApps = [
        "com.apple.mail",
        "com.tinyspeck.slackmacgap", // Slack
        "com.microsoft.teams",
        "com.apple.iChat", // Messages
        "com.microsoft.Outlook",
        "com.readdle.smartemail-Mac", // Spark
        "com.postbox-inc.postboxapp"
    ]
    
    private let passiveApps = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.apple.news",
        "com.reederapp.macOS", // Reeder
        "net.shinyfrog.bear", // Bear (reading mode)
        "com.apple.Preview"
    ]
    
    static let shared = BehavioralAnalyzer()
    
    private init() {}
    
    /// Analyzes sessions and creates behavioral blocks
    func analyzeBlocks(from sessions: [Session], modelContext: ModelContext) throws -> [BehavioralBlock] {
        guard !sessions.isEmpty else {
            logger.debug("No sessions to analyze for behavioral blocks")
            return []
        }
        
        var blocks: [BehavioralBlock] = []
        
        for session in sessions {
            let blockType = classifySession(session)
            let focusScore = calculateFocusScore(session, blockType: blockType)
            
            let block = BehavioralBlock(
                startTime: session.startTime,
                endTime: session.endTime,
                blockType: blockType,
                dominantActivity: session.dominantAppName,
                dominantAppBundleId: session.dominantAppBundleId,
                focusScore: focusScore,
                contextSwitchCount: session.contextSwitchCount,
                sessionIds: [session.id]
            )
            
            modelContext.insert(block)
            blocks.append(block)
        }
        
        logger.info("Created \(blocks.count) behavioral blocks from \(sessions.count) sessions")
        return blocks
    }
    
    /// Classifies a session into a block type
    private func classifySession(_ session: Session) -> BlockType {
        let duration = session.duration
        let switches = session.contextSwitchCount
        
        // Check for idle first (very short duration with no switches)
        if duration < 60 && switches == 0 {
            return .idle
        }
        
        // Check for communication apps
        if let bundleId = session.dominantAppBundleId,
           communicationApps.contains(bundleId) {
            return .communication
        }
        
        // Check for deep work: long duration + low switches
        if duration >= deepWorkMinDuration && switches <= deepWorkMaxSwitches {
            return .deep
        }
        
        // Check for fragmented work: high switches OR short bursts
        if switches >= fragmentedHighSwitchThreshold ||
           (duration < fragmentedShortDurationThreshold && switches > 0) {
            return .fragmented
        }
        
        // Check for passive consumption (browsers, readers)
        if let bundleId = session.dominantAppBundleId,
           passiveApps.contains(bundleId) {
            return .passive
        }
        
        // Default: moderate work is considered fragmented
        return .fragmented
    }
    
    /// Calculates a focus score for a session (0-1)
    private func calculateFocusScore(_ session: Session, blockType: BlockType) -> Double {
        // Base score by block type
        var score: Double
        switch blockType {
        case .deep:
            score = 0.9
        case .fragmented:
            score = 0.3
        case .passive:
            score = 0.5
        case .communication:
            score = 0.6
        case .idle:
            score = 0.0
        }
        
        // Adjust by duration (longer sessions get slightly higher scores)
        let durationMinutes = session.duration / 60
        if durationMinutes > 45 {
            score = min(1.0, score + 0.1)
        }
        
        // Adjust by context switches (more switches reduce score)
        let switchPenalty = Double(session.contextSwitchCount) * 0.02
        score = max(0.0, score - switchPenalty)
        
        return score
    }
    
    /// Retrieves behavioral blocks for a specific date
    func getBlocks(for date: Date, modelContext: ModelContext) throws -> [BehavioralBlock] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<BehavioralBlock> { block in
            block.startTime >= startOfDay && block.startTime < endOfDay
        }
        
        let descriptor = FetchDescriptor<BehavioralBlock>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Clears all behavioral blocks for a date
    func clearBlocks(for date: Date, modelContext: ModelContext) throws {
        let blocks = try getBlocks(for: date, modelContext: modelContext)
        for block in blocks {
            modelContext.delete(block)
        }
        logger.info("Cleared \(blocks.count) behavioral blocks for date: \(date)")
    }
}
