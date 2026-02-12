import Foundation
import SwiftData
import os

/// Aggregates behavioral blocks into daily time structure
/// Provides the high-level view of how time was distributed
@MainActor
final class TimeStructureAnalyzer {
    private let logger = Logger(subsystem: "dev.leix.chronote", category: "TimeStructureAnalyzer")
    
    static let shared = TimeStructureAnalyzer()
    
    private init() {}
    
    /// Analyzes behavioral blocks and creates time structure for a day
    func analyzeTimeStructure(from blocks: [BehavioralBlock], for date: Date, modelContext: ModelContext) throws -> TimeStructure {
        var deepDuration: TimeInterval = 0
        var fragmentedDuration: TimeInterval = 0
        var passiveDuration: TimeInterval = 0
        var communicationDuration: TimeInterval = 0
        var idleDuration: TimeInterval = 0
        
        // Aggregate durations by block type
        for block in blocks {
            switch block.blockType {
            case .deep:
                deepDuration += block.duration
            case .fragmented:
                fragmentedDuration += block.duration
            case .passive:
                passiveDuration += block.duration
            case .communication:
                communicationDuration += block.duration
            case .idle:
                idleDuration += block.duration
            }
        }
        
        // Normalize date to start of day
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        let structure = TimeStructure(
            date: normalizedDate,
            deepDuration: deepDuration,
            fragmentedDuration: fragmentedDuration,
            passiveDuration: passiveDuration,
            communicationDuration: communicationDuration,
            idleDuration: idleDuration,
            blockIds: blocks.map { $0.id }
        )
        
        modelContext.insert(structure)
        
        logger.info("""
            Created time structure for \(normalizedDate): 
            Deep: \(deepDuration/60)m, 
            Fragmented: \(fragmentedDuration/60)m, 
            Passive: \(passiveDuration/60)m, 
            Communication: \(communicationDuration/60)m, 
            Idle: \(idleDuration/60)m
            """)
        
        return structure
    }
    
    /// Retrieves time structure for a specific date
    func getTimeStructure(for date: Date, modelContext: ModelContext) throws -> TimeStructure? {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        let predicate = #Predicate<TimeStructure> { structure in
            structure.date == normalizedDate
        }
        
        let descriptor = FetchDescriptor<TimeStructure>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)
        
        return results.first
    }
    
    /// Compares two time structures and generates comparison metrics
    func compareStructures(_ today: TimeStructure, _ yesterday: TimeStructure) -> [ComparisonMetric] {
        var comparisons: [ComparisonMetric] = []
        
        // Deep work comparison
        let deepChange = calculatePercentageChange(
            from: yesterday.deepDuration,
            to: today.deepDuration
        )
        comparisons.append(ComparisonMetric(
            name: "Deep Focus",
            value: today.deepDurationFormatted,
            change: deepChange,
            isPositive: true // More deep work is good
        ))
        
        // Fragmented work comparison
        let fragmentedChange = calculatePercentageChange(
            from: yesterday.fragmentedDuration,
            to: today.fragmentedDuration
        )
        comparisons.append(ComparisonMetric(
            name: "Fragmented Time",
            value: today.fragmentedDurationFormatted,
            change: fragmentedChange,
            isPositive: false // Less fragmentation is good
        ))
        
        // Context switches (if we had that data at structure level)
        // For now, use passive time as third metric
        let passiveChange = calculatePercentageChange(
            from: yesterday.passiveDuration,
            to: today.passiveDuration
        )
        comparisons.append(ComparisonMetric(
            name: "Passive Time",
            value: today.passiveDurationFormatted,
            change: passiveChange,
            isPositive: false // Less passive is generally better
        ))
        
        return comparisons
    }
    
    /// Calculates percentage change between two values
    private func calculatePercentageChange(from old: TimeInterval, to new: TimeInterval) -> Double {
        guard old > 0 else {
            return new > 0 ? 100 : 0
        }
        return ((new - old) / old) * 100
    }
    
    /// Clears time structure for a date
    func clearTimeStructure(for date: Date, modelContext: ModelContext) throws {
        if let structure = try getTimeStructure(for: date, modelContext: modelContext) {
            modelContext.delete(structure)
            logger.info("Cleared time structure for date: \(date)")
        }
    }
}
