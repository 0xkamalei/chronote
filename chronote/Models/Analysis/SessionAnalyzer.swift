import Foundation
import SwiftData
import os

// Import Activity model - adjust path if needed
// Note: Activity model should be accessible via import

/// Analyzes activities and groups them into sessions
/// A session is a continuous period of work without significant interruptions
@MainActor
final class SessionAnalyzer {
    private let logger = Logger(subsystem: "dev.leix.chronote", category: "SessionAnalyzer")
    
    // Configuration
    private let sessionGapThreshold: TimeInterval = 5 * 60 // 5 minutes
    /// Keep session granularity useful for timeline visualization.
    private let maxSessionDuration: TimeInterval = 60 * 60 // 60 minutes
    
    static let shared = SessionAnalyzer()
    
    private init() {}
    
    /// Analyzes activities for a given date and creates sessions
    /// - Parameters:
    ///   - activities: Array of activities to analyze
    ///   - modelContext: SwiftData model context for persistence
    /// - Returns: Array of created sessions
    func analyzeSessions(from activities: [Activity], modelContext: ModelContext) throws -> [Session] {
        // Sort activities by start time
        let sortedActivities = activities.sorted { $0.startTime < $1.startTime }
        
        guard !sortedActivities.isEmpty else {
            logger.debug("No activities to analyze for sessions")
            return []
        }
        
        var sessions: [Session] = []
        var currentSessionActivities: [Activity] = []
        
        for activity in sortedActivities {
            if currentSessionActivities.isEmpty {
                // Start new session
                currentSessionActivities.append(activity)
            } else {
                // Check if this activity belongs to current session
                let lastActivity = currentSessionActivities.last!
                let gap = activity.startTime.timeIntervalSince(lastActivity.endTime ?? lastActivity.startTime)
                let currentSessionStart = currentSessionActivities.first!.startTime
                let activityEnd = activity.endTime ?? activity.startTime
                let projectedSessionDuration = activityEnd.timeIntervalSince(currentSessionStart)
                
                if gap <= sessionGapThreshold && projectedSessionDuration <= maxSessionDuration {
                    // Continue current session
                    currentSessionActivities.append(activity)
                } else {
                    // End current session and start new one
                    if let session = createSession(from: currentSessionActivities, modelContext: modelContext) {
                        sessions.append(session)
                    }
                    currentSessionActivities = [activity]
                }
            }
        }
        
        // Don't forget the last session
        if !currentSessionActivities.isEmpty {
            if let session = createSession(from: currentSessionActivities, modelContext: modelContext) {
                sessions.append(session)
            }
        }
        
        logger.info("Created \(sessions.count) sessions from \(activities.count) activities")
        return sessions
    }
    
    /// Creates a session from a group of activities
    private func createSession(from activities: [Activity], modelContext: ModelContext) -> Session? {
        guard !activities.isEmpty else { return nil }
        
        let startTime = activities.first!.startTime
        let endTime = activities.last!.endTime ?? Date()
        
        // Find dominant app (most time spent)
        var appDurations: [String: TimeInterval] = [:]
        for activity in activities {
            let duration = activity.calculatedDuration
            appDurations[activity.appBundleId, default: 0] += duration
        }
        
        let dominantApp = appDurations.max(by: { $0.value < $1.value })
        let contextSwitchCount = max(0, activities.count - 1) // Switches = transitions between activities
        
        let session = Session(
            startTime: startTime,
            endTime: endTime,
            dominantAppBundleId: dominantApp?.key,
            dominantAppName: activities.first(where: { $0.appBundleId == dominantApp?.key })?.appName,
            contextSwitchCount: contextSwitchCount,
            activityIds: activities.map { $0.id }
        )
        
        modelContext.insert(session)
        return session
    }
    
    /// Retrieves sessions for a specific date
    func getSessions(for date: Date, modelContext: ModelContext) throws -> [Session] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<Session> { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }
        
        let descriptor = FetchDescriptor<Session>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Clears all sessions for a date (useful for reanalysis)
    func clearSessions(for date: Date, modelContext: ModelContext) throws {
        let sessions = try getSessions(for: date, modelContext: modelContext)
        for session in sessions {
            modelContext.delete(session)
        }
        logger.info("Cleared \(sessions.count) sessions for date: \(date)")
    }
}
