//
//  ActivityQuery.swift
//  time-vscode
//
//  Created by Kiro on 8/6/25.
//

import Foundation
import SwiftData

/// Handles all database query operations for Activity entities
@MainActor
class ActivityQuery {
    
    // MARK: - Query Methods
    
    /// Get recent activities with specified limit
    static func getRecentActivities(limit: Int = 50, modelContext: ModelContext) -> [Activity] {
        do {
            var descriptor = FetchDescriptor<Activity>(
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            let activities = try modelContext.fetch(descriptor)
            return activities
            
        } catch {
            print("ActivityQuery: Error fetching recent activities - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get activities for a specific date range
    static func getActivitiesForDateRange(startDate: Date, endDate: Date, limit: Int? = nil, modelContext: ModelContext) -> [Activity] {
        do {
            // Create predicate for date range filtering
            let predicate = #Predicate<Activity> { activity in
                activity.startTime >= startDate && activity.startTime <= endDate
            }
            
            var descriptor = FetchDescriptor<Activity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            let activities = try modelContext.fetch(descriptor)
            return activities
            
        } catch {
            print("ActivityQuery: Error fetching activities for date range - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get activities for a specific date (day)
    static func getActivitiesForDate(_ date: Date, modelContext: ModelContext) -> [Activity] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return getActivitiesForDateRange(startDate: startOfDay, endDate: endOfDay, modelContext: modelContext)
    }
    
    /// Get activities for a specific app bundle ID
    static func getActivitiesForApp(bundleId: String, limit: Int? = nil, modelContext: ModelContext) -> [Activity] {
        do {
            let predicate = #Predicate<Activity> { activity in
                activity.appBundleId == bundleId
            }
            
            var descriptor = FetchDescriptor<Activity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            let activities = try modelContext.fetch(descriptor)
            return activities
            
        } catch {
            print("ActivityQuery: Error fetching activities for app - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get activities for a specific week
    static func getActivitiesForWeek(containing date: Date, modelContext: ModelContext) -> [Activity] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            print("ActivityQuery: Error calculating week interval")
            return []
        }
        
        return getActivitiesForDateRange(
            startDate: weekInterval.start,
            endDate: weekInterval.end,
            modelContext: modelContext
        )
    }
    
    /// Get activities for a specific month
    static func getActivitiesForMonth(containing date: Date, modelContext: ModelContext) -> [Activity] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            print("ActivityQuery: Error calculating month interval")
            return []
        }
        
        return getActivitiesForDateRange(
            startDate: monthInterval.start,
            endDate: monthInterval.end,
            modelContext: modelContext
        )
    }
    
    /// Get total time spent on a specific app within date range
    static func getTotalTimeForApp(bundleId: String, startDate: Date, endDate: Date, modelContext: ModelContext) -> TimeInterval {
        let activities = getActivitiesForApp(bundleId: bundleId, modelContext: modelContext)
        
        let filteredActivities = activities.filter { activity in
            activity.startTime >= startDate && activity.startTime <= endDate
        }
        
        return filteredActivities.reduce(0) { total, activity in
            total + activity.duration
        }
    }
    
    /// Get app usage statistics for a date range
    static func getAppUsageStats(startDate: Date, endDate: Date, modelContext: ModelContext) -> [AppUsageStat] {
        let activities = getActivitiesForDateRange(startDate: startDate, endDate: endDate, modelContext: modelContext)
        
        // Group activities by app bundle ID
        let groupedActivities = Dictionary(grouping: activities) { $0.appBundleId }
        
        // Calculate statistics for each app
        let stats = groupedActivities.map { (bundleId, activities) in
            let totalDuration = activities.reduce(0) { $0 + $1.duration }
            let sessionCount = activities.count
            let averageDuration = sessionCount > 0 ? totalDuration / Double(sessionCount) : 0
            let appName = activities.first?.appName ?? bundleId
            
            return AppUsageStat(
                appName: appName,
                bundleId: bundleId,
                totalDuration: totalDuration,
                sessionCount: sessionCount,
                averageDuration: averageDuration
            )
        }
        
        // Sort by total duration (descending)
        return stats.sorted { $0.totalDuration > $1.totalDuration }
    }
    
    /// Find activities with duration longer than specified threshold
    static func getLongActivities(minimumDuration: TimeInterval, modelContext: ModelContext) -> [Activity] {
        do {
            let predicate = #Predicate<Activity> { activity in
                activity.duration >= minimumDuration
            }
            
            let descriptor = FetchDescriptor<Activity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.duration, order: .reverse)]
            )
            
            let activities = try modelContext.fetch(descriptor)
            return activities
            
        } catch {
            print("ActivityQuery: Error fetching long activities - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Find activities with duration shorter than specified threshold
    static func getShortActivities(maximumDuration: TimeInterval, modelContext: ModelContext) -> [Activity] {
        do {
            let predicate = #Predicate<Activity> { activity in
                activity.duration <= maximumDuration && activity.duration > 0
            }
            
            let descriptor = FetchDescriptor<Activity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.duration, order: .forward)]
            )
            
            let activities = try modelContext.fetch(descriptor)
            return activities
            
        } catch {
            print("ActivityQuery: Error fetching short activities - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get activities count for a specific date range
    static func getActivitiesCount(startDate: Date, endDate: Date, modelContext: ModelContext) -> Int {
        do {
            let predicate = #Predicate<Activity> { activity in
                activity.startTime >= startDate && activity.startTime <= endDate
            }
            
            let descriptor = FetchDescriptor<Activity>(predicate: predicate)
            let activities = try modelContext.fetch(descriptor)
            return activities.count
            
        } catch {
            print("ActivityQuery: Error counting activities - \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Delete old activities beyond retention period for performance
    static func cleanupOldActivities(olderThan date: Date, modelContext: ModelContext) throws {
        do {
            let predicate = #Predicate<Activity> { activity in
                activity.startTime < date
            }
            
            let descriptor = FetchDescriptor<Activity>(predicate: predicate)
            let oldActivities = try modelContext.fetch(descriptor)
            
            for activity in oldActivities {
                modelContext.delete(activity)
            }
            
            try modelContext.save()
            
            print("ActivityQuery: Cleaned up \(oldActivities.count) old activities")
            
        } catch {
            print("ActivityQuery: Error cleaning up old activities - \(error.localizedDescription)")
            throw ActivityQueryError.cleanupFailed(error)
        }
    }
}

// MARK: - Supporting Types

/// App usage statistics structure
struct AppUsageStat {
    let appName: String
    let bundleId: String
    let totalDuration: TimeInterval
    let sessionCount: Int
    let averageDuration: TimeInterval
    
    var totalDurationString: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var averageDurationString: String {
        let minutes = Int(averageDuration / 60)
        if minutes < 1 {
            return "<1m"
        }
        return "\(minutes)m"
    }
}

/// Error types for ActivityQuery operations
enum ActivityQueryError: LocalizedError {
    case cleanupFailed(Error)
    case queryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .cleanupFailed(let error):
            return "Failed to cleanup old activities: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "Failed to execute query: \(error.localizedDescription)"
        }
    }
}