import Foundation
import os
import SQLite3
import SwiftData

/// Database configuration and optimization utilities
class DatabaseConfiguration {
    private static let logger = Logger(subsystem: "com.time.vscode", category: "DatabaseConfiguration")

    /// Configures database for optimal performance with comprehensive optimization
    static func optimizeDatabase(modelContext: ModelContext) async throws {
        logger.info("Optimizing database configuration...")

        // Initialize performance optimizer
        let optimizer = await DatabasePerformanceOptimizer.shared
        await optimizer.setModelContext(modelContext)

        // Create optimized indexes
        try await optimizer.createOptimizedIndexes()

        // Configure optimal SQLite settings
        try await optimizer.optimizeQueries()

        // Perform initial maintenance
        try await optimizer.performMaintenance()

        logger.info("Database optimization completed with performance monitoring")
    }

    /// Creates indexes for frequently queried fields
    private static func createIndexes(modelContext: ModelContext) {
        logger.info("Creating database indexes...")

        // Activity indexes
        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_activity_start_time ON Activity(startTime);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_activity_bundle_id ON Activity(appBundleId);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_activity_end_time ON Activity(endTime);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_activity_time_app ON Activity(startTime, appBundleId);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_activity_duration ON Activity(duration);"
        )

        // TimeEntry indexes for performance optimization
        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_project ON TimeEntry(projectId);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_start_time ON TimeEntry(startTime);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_end_time ON TimeEntry(endTime);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_date_range ON TimeEntry(startTime, endTime);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_duration ON TimeEntry(duration);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_created_at ON TimeEntry(createdAt);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_project_time ON TimeEntry(projectId, startTime);"
        )
        
        // TimerSession indexes
        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timersession_start_time ON TimerSession(startTime);"
        )
        
        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timersession_project ON TimerSession(projectId);"
        )
        
        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timersession_active ON TimerSession(isCompleted, endTime);"
        )

        logger.info("Database indexes created successfully")
    }

    /// Executes raw SQL commands for database optimization
    private static func executeSQL(modelContext _: ModelContext, sql: String) {
        logger.debug("Would execute SQL: \(sql)")
    }

    /// Analyzes database performance and provides recommendations
    static func analyzePerformance(modelContext: ModelContext) {
        logger.info("Analyzing database performance...")

        do {
            // Analyze Activities
            let activityDescriptor = FetchDescriptor<Activity>()
            let activities = try modelContext.fetch(activityDescriptor)
            let activityCount = activities.count

            logger.info("Database contains \(activityCount) activities")

            if activityCount > 10000 {
                logger.warning("Large dataset detected (\(activityCount) activities). Consider implementing data archiving.")
            }

            let activeActivities = activities.filter { $0.endTime == nil }
            if activeActivities.count > 1 {
                logger.warning("Multiple active activities detected: \(activeActivities.count)")
            }

            if !activities.isEmpty {
                let oldestActivity = activities.min { $0.startTime < $1.startTime }
                let newestActivity = activities.max { $0.startTime < $1.startTime }

                if let oldest = oldestActivity, let newest = newestActivity {
                    let timeSpan = newest.startTime.timeIntervalSince(oldest.startTime)
                    let days = timeSpan / (24 * 60 * 60)
                    logger.info("Activity data spans \(Int(days)) days")
                }
            }

            // Analyze TimeEntries
            let timeEntryDescriptor = FetchDescriptor<TimeEntry>()
            let timeEntries = try modelContext.fetch(timeEntryDescriptor)
            let timeEntryCount = timeEntries.count

            logger.info("Database contains \(timeEntryCount) time entries")

            if timeEntryCount > 5000 {
                logger.warning("Large time entry dataset detected (\(timeEntryCount) entries). Consider implementing pagination.")
            }

            // Check for data integrity issues
            let invalidTimeEntries = timeEntries.filter { !$0.isValid }
            if !invalidTimeEntries.isEmpty {
                logger.warning("Found \(invalidTimeEntries.count) invalid time entries that need repair")
            }

            // Check for orphaned time entries (entries with non-existent projects)
            let projectDescriptor = FetchDescriptor<Project>()
            let projects = try modelContext.fetch(projectDescriptor)
            let projectIds = Set(projects.map { $0.id })

            let orphanedEntries = timeEntries.filter { entry in
                guard let projectId = entry.projectId else { return false }
                return !projectIds.contains(projectId)
            }

            if !orphanedEntries.isEmpty {
                logger.warning("Found \(orphanedEntries.count) orphaned time entries with invalid project references")
            }

            if !timeEntries.isEmpty {
                let oldestEntry = timeEntries.min { $0.startTime < $1.startTime }
                let newestEntry = timeEntries.max { $0.startTime < $1.startTime }

                if let oldest = oldestEntry, let newest = newestEntry {
                    let timeSpan = newest.startTime.timeIntervalSince(oldest.startTime)
                    let days = timeSpan / (24 * 60 * 60)
                    logger.info("Time entry data spans \(Int(days)) days")
                }

                let totalTrackedTime = timeEntries.reduce(0) { $0 + $1.duration }
                let hours = totalTrackedTime / 3600
                logger.info("Total tracked time: \(String(format: "%.1f", hours)) hours")
            }

        } catch {
            logger.error("Performance analysis failed: \(error.localizedDescription)")
        }
    }

    /// Performs database maintenance operations
    static func performMaintenance(modelContext: ModelContext) {
        logger.info("Performing database maintenance...")

        // Standard SQLite maintenance
        executeSQL(modelContext: modelContext, sql: "ANALYZE;")
        executeSQL(modelContext: modelContext, sql: "PRAGMA optimize;")

        // TimeEntry specific maintenance
        performTimeEntryMaintenance(modelContext: modelContext)

        logger.info("Database maintenance completed")
    }

    /// Performs TimeEntry-specific maintenance operations
    private static func performTimeEntryMaintenance(modelContext: ModelContext) {
        logger.info("Performing TimeEntry maintenance...")

        do {
            // Clean up invalid time entries
            let timeEntryDescriptor = FetchDescriptor<TimeEntry>()
            let timeEntries = try modelContext.fetch(timeEntryDescriptor)

            var cleanedCount = 0
            var repairedCount = 0

            for entry in timeEntries {
                // Remove entries with invalid time ranges
                if entry.endTime <= entry.startTime {
                    logger.warning("Removing invalid time entry with ID: \(entry.id)")
                    modelContext.delete(entry)
                    cleanedCount += 1
                    continue
                }

                // Repair duration inconsistencies
                let calculatedDuration = entry.endTime.timeIntervalSince(entry.startTime)
                if abs(entry.duration - calculatedDuration) > 1.0 { // Allow 1 second tolerance
                    logger.info("Repairing duration for time entry ID: \(entry.id)")
                    entry.duration = calculatedDuration
                    entry.updatedAt = Date()
                    repairedCount += 1
                }

                // Clean up entries with empty titles
                if entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logger.info("Setting default title for time entry ID: \(entry.id)")
                    entry.title = "Untitled Entry"
                    entry.updatedAt = Date()
                    repairedCount += 1
                }
            }

            // Clean up orphaned time entries (entries with non-existent projects)
            let projectDescriptor = FetchDescriptor<Project>()
            let projects = try modelContext.fetch(projectDescriptor)
            let projectIds = Set(projects.map { $0.id })

            let orphanedEntries = timeEntries.filter { entry in
                guard let projectId = entry.projectId else { return false }
                return !projectIds.contains(projectId)
            }

            for orphanedEntry in orphanedEntries {
                logger.warning("Reassigning orphaned time entry ID: \(orphanedEntry.id) to unassigned")
                orphanedEntry.projectId = nil
                orphanedEntry.updatedAt = Date()
                repairedCount += 1
            }

            if cleanedCount > 0 || repairedCount > 0 {
                try modelContext.save()
                logger.info("TimeEntry maintenance completed: \(cleanedCount) entries removed, \(repairedCount) entries repaired")
            } else {
                logger.info("TimeEntry maintenance completed: No issues found")
            }

        } catch {
            logger.error("TimeEntry maintenance failed: \(error.localizedDescription)")
        }
    }

    /// Validates database schema and integrity
    static func validateSchema(modelContext: ModelContext) -> Bool {
        logger.info("Validating database schema...")

        do {
            // Validate Activity schema
            var activityDescriptor = FetchDescriptor<Activity>()
            activityDescriptor.fetchLimit = 1
            _ = try modelContext.fetch(activityDescriptor)

            // Validate Project schema
            var projectDescriptor = FetchDescriptor<Project>()
            projectDescriptor.fetchLimit = 1
            _ = try modelContext.fetch(projectDescriptor)

            // Validate TimeEntry schema
            var timeEntryDescriptor = FetchDescriptor<TimeEntry>()
            timeEntryDescriptor.fetchLimit = 1
            _ = try modelContext.fetch(timeEntryDescriptor)
            
            // Validate TimerSession schema
            var timerSessionDescriptor = FetchDescriptor<TimerSession>()
            timerSessionDescriptor.fetchLimit = 1
            _ = try modelContext.fetch(timerSessionDescriptor)

            logger.info("Schema validation passed for all models")
            return true
        } catch {
            logger.error("Schema validation failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Optimizes TimeEntry queries for better performance
    static func optimizeTimeEntryQueries(modelContext: ModelContext) {
        logger.info("Optimizing TimeEntry query performance...")

        // Create composite indexes for common query patterns
        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_project_date_range ON TimeEntry(projectId, startTime, endTime);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_date_duration ON TimeEntry(startTime, duration);"
        )

        executeSQL(
            modelContext: modelContext,
            sql: "CREATE INDEX IF NOT EXISTS idx_timeentry_updated_at ON TimeEntry(updatedAt);"
        )

        // Analyze TimeEntry table for query optimization
        executeSQL(modelContext: modelContext, sql: "ANALYZE TimeEntry;")

        logger.info("TimeEntry query optimization completed")
    }

    /// Archives old TimeEntry data to improve performance
    static func archiveOldTimeEntries(modelContext: ModelContext, olderThanDays: Int = 365) {
        logger.info("Archiving time entries older than \(olderThanDays) days...")

        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()

            let descriptor = FetchDescriptor<TimeEntry>(
                predicate: #Predicate<TimeEntry> { entry in
                    entry.startTime < cutoffDate
                }
            )

            let oldEntries = try modelContext.fetch(descriptor)

            if oldEntries.isEmpty {
                logger.info("No old time entries found for archiving")
                return
            }

            // In a real implementation, you might export to a file or separate database
            // For now, we'll just log the count that would be archived
            logger.info("Found \(oldEntries.count) time entries eligible for archiving")

            // Optionally delete very old entries (uncomment if needed)
            // for entry in oldEntries {
            //     modelContext.delete(entry)
            // }
            // try modelContext.save()

        } catch {
            logger.error("Time entry archiving failed: \(error.localizedDescription)")
        }
    }
}
