import Foundation
import SwiftData
import os

/// Schema migration utility for handling data model evolution
class SchemaMigration {
    private static let logger = Logger(subsystem: "com.time.vscode", category: "SchemaMigration")
    private static let currentSchemaVersion = "1.1.0"
    private static let schemaVersionKey = "SchemaVersion"
    
    /// Performs migration from MockData to SwiftData models if needed
    static func performMigrationIfNeeded(modelContext: ModelContext) {
        let currentVersion = getCurrentSchemaVersion()
        logger.info("Current schema version: \(currentVersion ?? "none")")
        
        if shouldPerformMigration(currentVersion: currentVersion) {
            logger.info("Starting schema migration...")
            do {
                try migrateFromMockData(modelContext: modelContext)
                setSchemaVersion(currentSchemaVersion)
                logger.info("Schema migration completed successfully")
            } catch {
                logger.error("Schema migration failed: \(error.localizedDescription)")
                handleMigrationFailure(error: error)
            }
        } else {
            logger.info("No migration needed")
        }
        
        validateDataIntegrity(modelContext: modelContext)
    }
    
    /// Checks if migration is needed based on current version
    private static func shouldPerformMigration(currentVersion: String?) -> Bool {
        guard let currentVersion = currentVersion else {
            return hasExistingData()
        }
        
        return currentVersion != currentSchemaVersion
    }
    
    /// Checks if there's existing data that might need migration
    private static func hasExistingData() -> Bool {
        return false // For now, assume fresh installs don't need migration
    }
    
    /// Migrates data from MockData structure to SwiftData models
    private static func migrateFromMockData(modelContext: ModelContext) throws {
        logger.info("Migrating MockData to SwiftData models...")
        
        let existingActivities = try fetchExistingActivities(modelContext: modelContext)
        if !existingActivities.isEmpty {
            logger.info("Activities already exist, checking for context data migration")
            try migrateActivityContextData(activities: existingActivities, modelContext: modelContext)
            return
        }
        
        var migratedCount = 0
        for mockActivity in MockData.activities {
            let activity = Activity(
                appName: mockActivity.appName,
                appBundleId: mockActivity.appBundleId,
                appTitle: mockActivity.appTitle,
                duration: mockActivity.duration,
                startTime: mockActivity.startTime,
                endTime: mockActivity.endTime,
                icon: mockActivity.icon,
                windowTitle: nil, // New context fields start as nil
                url: nil,
                documentPath: nil,
                contextData: nil
            )
            
            modelContext.insert(activity)
            migratedCount += 1
        }
        
        try modelContext.save()
        logger.info("Successfully migrated \(migratedCount) activities from MockData")
    }
    
    /// Migrates existing activities to include new context data fields
    private static func migrateActivityContextData(activities: [Activity], modelContext: ModelContext) throws {
        logger.info("Migrating existing activities to include context data fields...")
        
        var migratedCount = 0
        for activity in activities {
            // Check if activity already has the new fields (they would be nil if not migrated)
            // Since SwiftData handles schema evolution automatically, we just need to validate
            do {
                try activity.validateContextData()
                migratedCount += 1
            } catch {
                logger.warning("Activity \(activity.id) failed context data validation: \(error.localizedDescription)")
                // Reset invalid context data to nil
                activity.windowTitle = nil
                activity.url = nil
                activity.documentPath = nil
                activity.contextData = nil
                migratedCount += 1
            }
        }
        
        if migratedCount > 0 {
            try modelContext.save()
            logger.info("Successfully migrated context data for \(migratedCount) activities")
        }
    }
    
    /// Fetches existing activities to check for duplicates
    private static func fetchExistingActivities(modelContext: ModelContext) throws -> [Activity] {
        let descriptor = FetchDescriptor<Activity>()
        return try modelContext.fetch(descriptor)
    }
    
    /// Validates data integrity after migration or startup
    private static func validateDataIntegrity(modelContext: ModelContext) {
        logger.info("Validating data integrity...")
        
        do {
            var validationErrors: [String] = []
            
            // Validate Activities
            let activities = try fetchExistingActivities(modelContext: modelContext)
            
            let activeActivities = activities.filter { $0.endTime == nil }
            if activeActivities.count > 1 {
                validationErrors.append("Multiple active activities found: \(activeActivities.count)")
                fixMultipleActiveActivities(activities: activeActivities, modelContext: modelContext)
            }
            
            for activity in activities {
                if let endTime = activity.endTime, endTime < activity.startTime {
                    validationErrors.append("Invalid time range for activity \(activity.id): endTime before startTime")
                }
                
                if activity.appBundleId.isEmpty {
                    validationErrors.append("Empty bundle ID for activity \(activity.id)")
                }
            }
            
            // Validate TimeEntries
            let timeEntries = try fetchExistingTimeEntries(modelContext: modelContext)
            var repairedEntries = 0
            
            for timeEntry in timeEntries {
                if !timeEntry.isValid {
                    let validationResult = timeEntry.validateTimeEntry()
                    if case .failure(let error) = validationResult {
                        validationErrors.append("Invalid time entry \(timeEntry.id): \(error.localizedDescription)")
                    }
                    
                    // Attempt to repair the time entry
                    timeEntry.repairDataIntegrity()
                    repairedEntries += 1
                }
                
                // Check for orphaned time entries (invalid project references)
                if let projectId = timeEntry.projectId {
                    let projectExists = try checkProjectExists(projectId: projectId, modelContext: modelContext)
                    if !projectExists {
                        validationErrors.append("Orphaned time entry \(timeEntry.id): references non-existent project \(projectId)")
                    }
                }
            }
            
            // Validate TimerSessions
            let timerSessions = try fetchExistingTimerSessions(modelContext: modelContext)
            
            let activeSessions = timerSessions.filter { $0.isActive }
            if activeSessions.count > 1 {
                validationErrors.append("Multiple active timer sessions found: \(activeSessions.count)")
                fixMultipleActiveTimerSessions(sessions: activeSessions, modelContext: modelContext)
            }
            
            for session in timerSessions {
                if case .failure(let error) = session.validate() {
                    validationErrors.append("Invalid timer session \(session.id): \(error.localizedDescription)")
                }
            }
            
            if repairedEntries > 0 {
                try modelContext.save()
                logger.info("Repaired \(repairedEntries) time entries with data integrity issues")
            }
            
            if validationErrors.isEmpty {
                logger.info("Data integrity validation passed")
            } else {
                logger.warning("Data integrity issues found: \(validationErrors.joined(separator: ", "))")
            }
            
        } catch {
            logger.error("Data integrity validation failed: \(error.localizedDescription)")
        }
    }
    
    /// Fetches existing time entries to check for validation issues
    private static func fetchExistingTimeEntries(modelContext: ModelContext) throws -> [TimeEntry] {
        let descriptor = FetchDescriptor<TimeEntry>()
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches existing timer sessions to check for validation issues
    private static func fetchExistingTimerSessions(modelContext: ModelContext) throws -> [TimerSession] {
        let descriptor = FetchDescriptor<TimerSession>()
        return try modelContext.fetch(descriptor)
    }
    
    /// Checks if a project exists by ID
    private static func checkProjectExists(projectId: String, modelContext: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { project in
                project.id == projectId
            }
        )
        descriptor.fetchLimit = 1
        let projects = try modelContext.fetch(descriptor)
        return !projects.isEmpty
    }
    
    /// Fixes multiple active activities by setting endTime for all but the most recent
    private static func fixMultipleActiveActivities(activities: [Activity], modelContext: ModelContext) {
        let sortedActivities = activities.sorted { $0.startTime > $1.startTime }
        
        for (index, activity) in sortedActivities.enumerated() {
            if index > 0 { // Skip the first (most recent) activity
                activity.endTime = Date()
                activity.duration = activity.calculatedDuration
            }
        }
        
        do {
            try modelContext.save()
            logger.info("Fixed multiple active activities")
        } catch {
            logger.error("Failed to fix multiple active activities: \(error.localizedDescription)")
        }
    }
    
    /// Fixes multiple active timer sessions by completing all but the most recent
    private static func fixMultipleActiveTimerSessions(sessions: [TimerSession], modelContext: ModelContext) {
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
        
        for (index, session) in sortedSessions.enumerated() {
            if index > 0 { // Skip the first (most recent) session
                session.interrupt()
            }
        }
        
        do {
            try modelContext.save()
            logger.info("Fixed multiple active timer sessions")
        } catch {
            logger.error("Failed to fix multiple active timer sessions: \(error.localizedDescription)")
        }
    }
    
    /// Handles migration failure with fallback mechanisms
    private static func handleMigrationFailure(error: Error) {
        logger.error("Migration failed, implementing fallback strategy")
        
        
        UserDefaults.standard.set("failed", forKey: "MigrationStatus")
        UserDefaults.standard.set(error.localizedDescription, forKey: "MigrationError")
        
        logger.info("Continuing with empty database after migration failure")
    }
    
    /// Gets the current schema version from UserDefaults
    private static func getCurrentSchemaVersion() -> String? {
        return UserDefaults.standard.string(forKey: schemaVersionKey)
    }
    
    /// Sets the schema version in UserDefaults
    private static func setSchemaVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: schemaVersionKey)
        logger.info("Schema version set to: \(version)")
    }
    
    /// Clears migration status for testing purposes
    static func clearMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: schemaVersionKey)
        UserDefaults.standard.removeObject(forKey: "MigrationStatus")
        UserDefaults.standard.removeObject(forKey: "MigrationError")
    }
}
