//
//  ActivityManager.swift
//  time-vscode
//
//  Created by Kiro on 8/6/25.
//

import Foundation
import SwiftData
import AppKit
import os.log

@MainActor
class ActivityManager: ObservableObject {
    // MARK: - Singleton
    static let shared = ActivityManager()
    
    // MARK: - Private Properties
    private var currentActivity: Activity?
    private var notificationObservers: [NSObjectProtocol] = []
    private var modelContext: ModelContext?
    
    // Sleep/wake state management
    private var sleepStartTime: Date?
    
    // Error handling and retry configuration
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 0.5
    private var isStorageAvailable = true
    private var pendingActivities: [Activity] = []
    
    // Logging
    private let logger = Logger(subsystem: "com.time-vscode.ActivityManager", category: "ActivityTracking")
    
    // Health monitoring
    private var lastSuccessfulSave: Date?
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 5
    
    // MARK: - Initialization
    private init() {
        // Private initializer for singleton pattern
    }
    
    // MARK: - Public Methods
    
    /// Start tracking app activity with comprehensive initialization
    func startTracking(modelContext: ModelContext) {
        // Store model context for use in notification handlers
        self.modelContext = modelContext
        
        // Remove any existing observers first
        stopTracking(modelContext: modelContext)
        
        // Initialize health monitoring
        isStorageAvailable = true
        consecutiveFailures = 0
        lastSuccessfulSave = Date()
        
        // Perform initial cleanup of incomplete records
        Task {
            await cleanupIncompleteRecords(modelContext: modelContext)
        }
        
        // Register NSWorkspace notification observers
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // App activation observer
        let appActivationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAppActivation(notification)
            }
        }
        notificationObservers.append(appActivationObserver)
        
        // System sleep observer
        let sleepObserver = notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleSystemSleep()
            }
        }
        notificationObservers.append(sleepObserver)
        
        // System wake observer
        let wakeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleSystemWake()
            }
        }
        notificationObservers.append(wakeObserver)
        
        logger.info("Started tracking with \(self.notificationObservers.count) observers")
        logHealthMetrics()
    }
    
    /// Stop tracking app activity
    func stopTracking(modelContext: ModelContext) {
        // Finish current activity if one exists before stopping
        if let current = currentActivity {
            current.endTime = Date()
            current.duration = current.calculatedDuration
            
            // Validate duration is positive
            if current.duration < 0 {
                logger.warning("Negative duration detected during stop, setting to 0")
                current.duration = 0
            }
            
            Task {
                do {
                    try await saveActivity(current, modelContext: modelContext)
                    logger.info("Saved final activity before stopping: \(current.appName)")
                } catch {
                    logger.error("Error saving final activity during stop - \(error.localizedDescription)")
                }
            }
        }
        
        // Remove all notification observers
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
        
        notificationObservers.removeAll()
        
        // Clear all state references
        self.modelContext = nil
        currentActivity = nil
        sleepStartTime = nil
        
        logger.info("Stopped tracking, removed all observers and cleared state")
    }
    
 
    
    /// Track app switch to new application with notification userInfo
    func trackAppSwitch(notification: Notification, modelContext: ModelContext) async {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier != nil else {
            logger.error("Invalid app activation notification")
            return
        }
        
        let appInfo = resolveAppInfo(from: app)
        await trackAppSwitch(appInfo: appInfo, modelContext: modelContext)
    }
    
    /// Track app switch to new application with app information
    private func trackAppSwitch(appInfo: AppInfo, modelContext: ModelContext) async {
        do {
            let now = Date()
            
            // Validate input data
            guard !appInfo.name.isEmpty else {
                logger.error("App name cannot be empty")
                return
            }
            
            // Check if this is the same app as currently active (avoid duplicate tracking)
            if let current = currentActivity,
               current.appBundleId == appInfo.bundleId {
                // TODO: Handle case where app doesn't switch but window title changes
                // Should update current activity's title if it's different from appInfo.title
                // This would be useful for tracking different documents/tabs within the same app
                logger.debug("Ignoring switch to same app: \(appInfo.name)")
                return
            }
            
            // If no current activity exists, create new activity but don't save yet
            if currentActivity == nil {
                let newActivity = Activity(
                    appName: appInfo.name,
                    appBundleId: appInfo.bundleId,
                    appTitle: appInfo.title,
                    duration: 0, // Will be calculated when activity ends
                    startTime: now,
                    endTime: nil, // nil indicates this is the active activity
                    icon: appInfo.icon
                )
                
                // Set as current activity but don't save to database yet
                currentActivity = newActivity
                logger.info("Started tracking new activity - \(appInfo.name) (not saved yet)")
                return
            }
            
            // Finish current activity and save it
            if let current = currentActivity {
                // Validate that current activity has a valid start time
                if current.startTime > now {
                    logger.error("Current activity has invalid start time, fixing")
                    // Fix the invalid start time
                    current.startTime = now.addingTimeInterval(-60) // Set to 1 minute ago as fallback
                }
                
                // Set end time and calculate duration
                current.endTime = now
                current.duration = current.calculatedDuration
                
                // Validate duration is positive
                if current.duration < 0 {
                    logger.warning("Negative duration detected, setting to 0")
                    current.duration = 0
                }
                
                // Save the finished activity using the enhanced saveActivity method
                try await saveActivity(current, modelContext: modelContext)
            }
            
            // Create new activity for the activated app
            let newActivity = Activity(
                appName: appInfo.name,
                appBundleId: appInfo.bundleId,
                appTitle: appInfo.title,
                duration: 0, // Will be calculated when activity ends
                startTime: now,
                endTime: nil, // nil indicates this is the active activity
                icon: appInfo.icon
            )
            
            // Update current activity reference (don't save to database yet)
            currentActivity = newActivity
            
            logger.info("Started new activity - \(appInfo.name) (\(appInfo.bundleId))")
            
        } catch {
            logger.error("Error tracking app switch - \(error.localizedDescription)")
            
            // Attempt recovery by clearing current activity state
            currentActivity = nil
            
            // Log health metrics for debugging
            logHealthMetrics()
        }
    }
    
    // MARK: - SwiftData Persistence Operations
    
    /// Save an activity to the database with comprehensive error handling and retry logic
    func saveActivity(_ activity: Activity, modelContext: ModelContext) async throws {
        // Validate activity data before persistence
        try validateActivity(activity)
        
        // Check if storage is available
        guard isStorageAvailable else {
            logger.warning("Storage unavailable, adding activity to pending queue: \(activity.appName)")
            pendingActivities.append(activity)
            throw ActivityManagerError.storageUnavailable
        }
        
        // Attempt to save with retry logic
        var lastError: Error?
        
        for attempt in 1...maxRetryAttempts {
            do {
                // Ensure only one active activity exists before saving
                if activity.endTime == nil {
                    try ensureOnlyOneActiveActivity(excluding: activity, modelContext: modelContext)
                }
                
                // Insert activity into context
                modelContext.insert(activity)
                
                // Save to database
                try modelContext.save()
                
                // Success - reset failure counters and update health metrics
                consecutiveFailures = 0
                lastSuccessfulSave = Date()
                
                logger.info("Successfully saved activity - \(activity.appName) (\(activity.duration, privacy: .public)s) on attempt \(attempt)")
                
                // Process any pending activities if storage is now working
                if !pendingActivities.isEmpty {
                    Task {
                        await processPendingActivities(modelContext: modelContext)
                    }
                }
                
                return
                
            } catch {
                lastError = error
                consecutiveFailures += 1
                
                logger.error("Save attempt \(attempt) failed for activity \(activity.appName): \(error.localizedDescription)")
                
                // Check if this is a transient error that should be retried
                if shouldRetry(error: error) && attempt < maxRetryAttempts {
                    // Wait before retrying with exponential backoff
                    let delay = retryDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Non-retryable error or max attempts reached
                    break
                }
            }
        }
        
        // All retry attempts failed
        handleSaveFailure(activity: activity, error: lastError!)
        throw ActivityManagerError.saveFailed(lastError!)
    }
    
    /// Save multiple activities in a batch operation with comprehensive error handling
    func batchSaveActivities(_ activities: [Activity], modelContext: ModelContext) async throws {
        guard !activities.isEmpty else {
            logger.info("No activities to save in batch")
            return
        }
        
        // Check if storage is available
        guard isStorageAvailable else {
            logger.warning("Storage unavailable, adding \(activities.count) activities to pending queue")
            pendingActivities.append(contentsOf: activities)
            throw ActivityManagerError.storageUnavailable
        }
        
        // Validate all activities before batch operation
        for activity in activities {
            try validateActivity(activity)
        }
        
        // Attempt batch save with retry logic
        var lastError: Error?
        
        for attempt in 1...maxRetryAttempts {
            do {
                // Ensure data integrity for active activities
                let activeActivities = activities.filter { $0.endTime == nil }
                if activeActivities.count > 1 {
                    throw ActivityManagerError.invalidData("Cannot batch save multiple active activities")
                }
                
                // Insert all activities into context
                for activity in activities {
                    modelContext.insert(activity)
                }
                
                // Save all at once for better performance
                try modelContext.save()
                
                // Success - reset failure counters
                consecutiveFailures = 0
                lastSuccessfulSave = Date()
                
                logger.info("Successfully batch saved \(activities.count) activities on attempt \(attempt)")
                return
                
            } catch {
                lastError = error
                consecutiveFailures += 1
                
                logger.error("Batch save attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Check if this is a transient error that should be retried
                if shouldRetry(error: error) && attempt < maxRetryAttempts {
                    // Wait before retrying with exponential backoff
                    let delay = retryDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    break
                }
            }
        }
        
        // All retry attempts failed
        handleBatchSaveFailure(activities: activities, error: lastError!)
        throw ActivityManagerError.batchSaveFailed(lastError!)
    }
    
    /// Get the currently active activity (always returns in-memory state)
    func getCurrentActivity() -> Activity? {
        // Always return the in-memory current activity reference
        // This is dynamic and reflects the real-time state of activity tracking
        return currentActivity
    }
    
    /// Get system health status for monitoring and debugging
    func getHealthStatus() -> HealthStatus {
        return HealthStatus(
            isStorageAvailable: isStorageAvailable,
            consecutiveFailures: consecutiveFailures,
            pendingActivitiesCount: pendingActivities.count,
            lastSuccessfulSave: lastSuccessfulSave,
            currentActivity: currentActivity?.appName,
            isTracking: !notificationObservers.isEmpty,
            sleepStartTime: sleepStartTime
        )
    }
    
    /// Health status structure for monitoring
    struct HealthStatus {
        let isStorageAvailable: Bool
        let consecutiveFailures: Int
        let pendingActivitiesCount: Int
        let lastSuccessfulSave: Date?
        let currentActivity: String?
        let isTracking: Bool
        let sleepStartTime: Date?
        
        var timeSinceLastSuccess: TimeInterval? {
            lastSuccessfulSave?.timeIntervalSinceNow.magnitude
        }
        
        var isHealthy: Bool {
            return isStorageAvailable && consecutiveFailures < 3 && pendingActivitiesCount < 10
        }
    }
    

    

    
    // MARK: - Data Validation
    
    /// Validate activity data before persistence with comprehensive rules
    private func validateActivity(_ activity: Activity) throws {
        // Validate app name is not empty and reasonable length
        let trimmedAppName = activity.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppName.isEmpty else {
            throw ActivityManagerError.invalidData("App name cannot be empty")
        }
        guard trimmedAppName.count <= 255 else {
            throw ActivityManagerError.invalidData("App name too long (max 255 characters)")
        }
        
        // Validate bundle ID is not empty and follows proper format
        let trimmedBundleId = activity.appBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBundleId.isEmpty else {
            throw ActivityManagerError.invalidData("App bundle ID cannot be empty")
        }
        guard trimmedBundleId.count <= 255 else {
            throw ActivityManagerError.invalidData("App bundle ID too long (max 255 characters)")
        }
        
        // Validate app title length if present
        if let appTitle = activity.appTitle {
            guard appTitle.count <= 500 else {
                throw ActivityManagerError.invalidData("App title too long (max 500 characters)")
            }
        }
        
        // Validate start time is reasonable (not too far in the past or future)
        let now = Date()
        let maxPastTime = now.addingTimeInterval(-86400 * 30) // 30 days ago
        let maxFutureTime = now.addingTimeInterval(60) // 1 minute in future (for clock skew)
        
        guard activity.startTime >= maxPastTime else {
            throw ActivityManagerError.invalidData("Start time too far in the past (max 30 days)")
        }
        guard activity.startTime <= maxFutureTime else {
            throw ActivityManagerError.invalidData("Start time cannot be in the future")
        }
        
        // If endTime exists, validate it's after startTime and reasonable
        if let endTime = activity.endTime {
            guard endTime >= activity.startTime else {
                throw ActivityManagerError.invalidData("End time must be after start time")
            }
            
            // Validate end time is not too far in the future
            guard endTime <= maxFutureTime else {
                throw ActivityManagerError.invalidData("End time cannot be in the future")
            }
            
            // Validate duration is reasonable (not longer than 24 hours)
            let calculatedDuration = endTime.timeIntervalSince(activity.startTime)
            guard calculatedDuration <= 86400 else {
                throw ActivityManagerError.invalidData("Activity duration cannot exceed 24 hours")
            }
            
            // Validate duration matches calculated duration with tolerance
            let tolerance: TimeInterval = 2.0 // Allow 2 second tolerance for processing delays
            guard abs(activity.duration - calculatedDuration) <= tolerance else {
                logger.warning("Duration mismatch: stored=\(activity.duration), calculated=\(calculatedDuration)")
                throw ActivityManagerError.invalidData("Duration does not match calculated time difference")
            }
        } else {
            // For active activities, validate they haven't been running too long
            let activeDuration = now.timeIntervalSince(activity.startTime)
            guard activeDuration <= 86400 else {
                throw ActivityManagerError.invalidData("Active activity cannot run longer than 24 hours")
            }
        }
        
        // Validate duration is not negative
        guard activity.duration >= 0 else {
            throw ActivityManagerError.invalidData("Duration cannot be negative")
        }
        
        // Validate icon string is reasonable
        guard activity.icon.count <= 100 else {
            throw ActivityManagerError.invalidData("Icon identifier too long (max 100 characters)")
        }
        
        // For active activities (endTime == nil), ensure only one exists
        if activity.endTime == nil {
            // Check in-memory current activity to ensure only one active activity exists
            if let existing = currentActivity, existing.id != activity.id {
                throw ActivityManagerError.invalidData("Only one active activity can exist at a time")
            }
        }
    }
    
    // MARK: - Error Handling Helpers
    
    /// Determine if an error should be retried
    private func shouldRetry(error: Error) -> Bool {
        // Check for transient errors that are worth retrying
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSCocoaErrorDomain:
                // Core Data/SwiftData transient errors
                switch nsError.code {
                case NSPersistentStoreSaveError,
                     NSManagedObjectContextLockingError,
                     NSPersistentStoreTimeoutError:
                    return true
                default:
                    return false
                }
            case NSSQLiteErrorDomain:
                // SQLite transient errors
                switch nsError.code {
                case 5: // SQLITE_BUSY
                    return true
                case 6: // SQLITE_LOCKED
                    return true
                case 13: // SQLITE_FULL (disk full - might be temporary)
                    return true
                default:
                    return false
                }
            default:
                return false
            }
        }
        
        // Don't retry validation errors
        if error is ActivityManagerError {
            return false
        }
        
        return false
    }
    
    /// Handle save failure with graceful degradation
    private func handleSaveFailure(activity: Activity, error: Error) {
        logger.error("Save failed after all retry attempts for activity \(activity.appName): \(error.localizedDescription)")
        
        // Check if we should mark storage as unavailable
        if consecutiveFailures >= maxConsecutiveFailures {
            isStorageAvailable = false
            logger.critical("Storage marked as unavailable after \(self.consecutiveFailures) consecutive failures")
            
            // Schedule storage availability check
            Task {
                await checkStorageAvailability()
            }
        }
        
        // Add to pending activities for later retry
        pendingActivities.append(activity)
        
        // Log health metrics
        logHealthMetrics()
    }
    
    /// Handle batch save failure with graceful degradation
    private func handleBatchSaveFailure(activities: [Activity], error: Error) {
        logger.error("Batch save failed after all retry attempts for \(activities.count) activities: \(error.localizedDescription)")
        
        // Check if we should mark storage as unavailable
        if consecutiveFailures >= maxConsecutiveFailures {
            isStorageAvailable = false
            logger.critical("Storage marked as unavailable after \(self.consecutiveFailures) consecutive failures")
        }
        
        // Add all activities to pending queue
        pendingActivities.append(contentsOf: activities)
        
        // Log health metrics
        logHealthMetrics()
    }
    
    /// Process pending activities when storage becomes available
    private func processPendingActivities(modelContext: ModelContext) async {
        guard !pendingActivities.isEmpty && isStorageAvailable else { return }
        
        logger.info("Processing \(self.pendingActivities.count) pending activities")
        
        let activitiesToProcess = pendingActivities
        pendingActivities.removeAll()
        
        var successCount = 0
        var failedActivities: [Activity] = []
        
        for activity in activitiesToProcess {
            do {
                try await saveActivityWithoutRetry(activity, modelContext: modelContext)
                successCount += 1
            } catch {
                logger.error("Failed to process pending activity \(activity.appName): \(error.localizedDescription)")
                failedActivities.append(activity)
            }
        }
        
        // Re-add failed activities to pending queue
        pendingActivities.append(contentsOf: failedActivities)
        
        logger.info("Processed \(successCount) pending activities, \(failedActivities.count) failed")
    }
    
    /// Save activity without retry logic (used for pending activity processing)
    private func saveActivityWithoutRetry(_ activity: Activity, modelContext: ModelContext) async throws {
        try validateActivity(activity)
        
        if activity.endTime == nil {
            try ensureOnlyOneActiveActivity(excluding: activity, modelContext: modelContext)
        }
        
        modelContext.insert(activity)
        try modelContext.save()
    }
    
    /// Ensure only one active activity exists in the database
    private func ensureOnlyOneActiveActivity(excluding activity: Activity, modelContext: ModelContext) throws {
        let activityId = activity.id
        let predicate = #Predicate<Activity> { existingActivity in
            existingActivity.endTime == nil && existingActivity.id != activityId
        }
        
        let descriptor = FetchDescriptor<Activity>(predicate: predicate)
        
        do {
            let activeActivities = try modelContext.fetch(descriptor)
            
            if !activeActivities.isEmpty {
                logger.warning("Found \(activeActivities.count) existing active activities, ending them")
                
                let now = Date()
                for activeActivity in activeActivities {
                    activeActivity.endTime = now
                    activeActivity.duration = activeActivity.calculatedDuration
                }
                
                try modelContext.save()
            }
        } catch {
            logger.error("Failed to check for existing active activities: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Check storage availability and attempt to restore service
    private func checkStorageAvailability() async {
        guard !isStorageAvailable else { return }
        
        logger.info("Checking storage availability...")
        
        // Wait before checking to allow transient issues to resolve
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // Try a simple database operation to test availability
        guard let context = modelContext else {
            logger.error("No model context available for storage check")
            return
        }
        
        do {
            // Try to fetch a single activity to test database connectivity
            var descriptor = FetchDescriptor<Activity>()
            descriptor.fetchLimit = 1
            _ = try context.fetch(descriptor)
            
            // If we get here, storage is working again
            isStorageAvailable = true
            consecutiveFailures = 0
            logger.info("Storage availability restored")
            
            // Process any pending activities
            await processPendingActivities(modelContext: context)
            
        } catch {
            logger.error("Storage still unavailable: \(error.localizedDescription)")
            
            // Schedule another check
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await checkStorageAvailability()
            }
        }
    }
    
    /// Log system health metrics
    private func logHealthMetrics() {
        let timeSinceLastSuccess = lastSuccessfulSave?.timeIntervalSinceNow ?? -Double.infinity
        
        logger.info("""
            ActivityManager Health Metrics:
            - Storage Available: \(self.isStorageAvailable)
            - Consecutive Failures: \(self.consecutiveFailures)
            - Pending Activities: \(self.pendingActivities.count)
            - Time Since Last Success: \(abs(timeSinceLastSuccess))s
            - Current Activity: \(self.currentActivity?.appName ?? "None")
            """)
    }
    
    /// Cleanup incomplete records from the database
    func cleanupIncompleteRecords(modelContext: ModelContext) async {
        logger.info("Starting cleanup of incomplete records")
        
        do {
            // Find activities that have been active for more than 24 hours
            let oneDayAgo = Date().addingTimeInterval(-86400)
            let predicate = #Predicate<Activity> { activity in
                activity.endTime == nil && activity.startTime < oneDayAgo
            }
            
            let descriptor = FetchDescriptor<Activity>(predicate: predicate)
            let staleActivities = try modelContext.fetch(descriptor)
            
            if !staleActivities.isEmpty {
                logger.warning("Found \(staleActivities.count) stale active activities, cleaning up")
                
                for activity in staleActivities {
                    // End the activity at a reasonable time (1 hour after start)
                    activity.endTime = activity.startTime.addingTimeInterval(3600)
                    activity.duration = activity.calculatedDuration
                }
                
                try modelContext.save()
                logger.info("Cleaned up \(staleActivities.count) stale activities")
            }
            
            // Find activities with invalid durations and fix them
            let allActivitiesPredicate = #Predicate<Activity> { activity in
                activity.endTime != nil
            }
            let allDescriptor = FetchDescriptor<Activity>(predicate: allActivitiesPredicate)
            let completedActivities = try modelContext.fetch(allDescriptor)
            
            var fixedCount = 0
            for activity in completedActivities {
                if let endTime = activity.endTime {
                    let calculatedDuration = endTime.timeIntervalSince(activity.startTime)
                    let tolerance: TimeInterval = 2.0
                    
                    if abs(activity.duration - calculatedDuration) > tolerance {
                        activity.duration = calculatedDuration
                        fixedCount += 1
                    }
                }
            }
            
            if fixedCount > 0 {
                try modelContext.save()
                logger.info("Fixed duration for \(fixedCount) activities")
            }
            
        } catch {
            logger.error("Failed to cleanup incomplete records: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Types
    
    enum ActivityManagerError: LocalizedError {
        case saveFailed(Error)
        case batchSaveFailed(Error)
        case invalidData(String)
        case noModelContext
        case sleepHandlingFailed(Error)
        case wakeHandlingFailed(Error)
        case storageUnavailable
        case dataIntegrityViolation(String)
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let error):
                return "Failed to save activity: \(error.localizedDescription)"
            case .batchSaveFailed(let error):
                return "Failed to batch save activities: \(error.localizedDescription)"
            case .invalidData(let message):
                return "Invalid activity data: \(message)"
            case .noModelContext:
                return "No model context available for database operations"
            case .sleepHandlingFailed(let error):
                return "Failed to handle system sleep: \(error.localizedDescription)"
            case .wakeHandlingFailed(let error):
                return "Failed to handle system wake: \(error.localizedDescription)"
            case .storageUnavailable:
                return "Storage is currently unavailable, activity queued for later processing"
            case .dataIntegrityViolation(let message):
                return "Data integrity violation: \(message)"
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// App information structure
    private struct AppInfo {
        let name: String
        let bundleId: String
        let title: String?
        let icon: String
    }
    
    /// Resolve all app information from NSRunningApplication
    private func resolveAppInfo(from app: NSRunningApplication) -> AppInfo {
        let bundleId = app.bundleIdentifier ?? "unknown"
        let name = getAppName(bundleId: bundleId, fallbackName: app.localizedName ?? bundleId)
        let title = getWindowTitle(from: app)
        let icon = getAppIcon(bundleId: bundleId)
        
        return AppInfo(name: name, bundleId: bundleId, title: title, icon: icon)
    }
    
    /// Get window title from NSRunningApplication using AXUIElement
    private func getWindowTitle(from app: NSRunningApplication) -> String? {
        // Try to get the window title from the application using AXUIElement
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success, let window = focusedWindow {
            var windowTitle: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &windowTitle)
            
            if titleResult == .success, let title = windowTitle as? String, !title.isEmpty {
                return title
            }
        }
        
        // Fallback: try to get title from bundle info
        if let bundleId = app.bundleIdentifier,
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        }
        
        return nil
    }
    
    /// Get app name from bundle identifier with fallback
    private func getAppName(bundleId: String, fallbackName: String) -> String {
        // Try to get the localized name from the running application
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }),
           let localizedName = app.localizedName, !localizedName.isEmpty {
            return localizedName
        }
        
        // Try to get app name from bundle
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        
        // Try CFBundleName as fallback
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        
        // Extract app name from bundle identifier as last resort
        let components = bundleId.components(separatedBy: ".")
        if let lastComponent = components.last, !lastComponent.isEmpty {
            // Capitalize first letter and return
            return lastComponent.prefix(1).uppercased() + lastComponent.dropFirst()
        }
        
        // Return fallback name if all else fails
        return fallbackName
    }
    

    
    /// Get app icon identifier for the given bundle ID
    private func getAppIcon(bundleId: String) -> String {
        // For now, return a default icon identifier
        // This could be enhanced to extract actual app icons in the future
        return "app.fill"
    }
    
    /// Handle app activation notification
    private func handleAppActivation(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            logger.error("Invalid app activation notification")
            return
        }
        
        let appName = app.localizedName ?? bundleId
        logger.debug("App activated - \(appName) (\(bundleId))")
        
        // Track the app switch with notification information
        guard let context = modelContext else {
            logger.error("No model context available for app switch tracking")
            return
        }
        Task {
            await trackAppSwitch(notification: notification, modelContext: context)
        }
    }
    
    /// Handle system sleep event - stops current tracking and saves pending data
    private func handleSystemSleep() async {
        do {
            logger.info("System going to sleep")
            
            // Record sleep start time for logging
            sleepStartTime = Date()
            
            // Finish current activity if one exists
            if let current = currentActivity {
                let sleepTime = Date()
                current.endTime = sleepTime
                current.duration = current.calculatedDuration
                
                // Validate duration is positive
                if current.duration < 0 {
                    logger.warning("Negative duration detected during sleep, setting to 0")
                    current.duration = 0
                }
                
                // Ensure all pending data is saved before system sleep
                if let context = modelContext {
                    try await saveActivity(current, modelContext: context)
                    
                    // Force save any pending changes to ensure data persistence
                    try context.save()
                    logger.info("Successfully saved activity before sleep: \(current.appName)")
                } else {
                    logger.error("No model context available to save activity before sleep")
                    throw ActivityManagerError.noModelContext
                }
                
                // Clear current activity to prevent stale references
                currentActivity = nil
            }
            
            // Process any remaining pending activities before sleep
            if !pendingActivities.isEmpty && isStorageAvailable {
                logger.info("Processing \(self.pendingActivities.count) pending activities before sleep")
                if let context = modelContext {
                    Task {
                        await processPendingActivities(modelContext: context)
                    }
                }
            }
            
            logger.info("Sleep handling completed - tracking stopped")
            
        } catch {
            logger.error("Error handling system sleep - \(error.localizedDescription)")
            
            // Even if save fails, ensure we're in consistent state
            sleepStartTime = Date()
            currentActivity = nil
            
            // Log health metrics for debugging
            logHealthMetrics()
            
            // Wrap the error for better context
            let sleepError = ActivityManagerError.sleepHandlingFailed(error)
            logger.error("Sleep handling error details - \(sleepError.errorDescription ?? "Unknown error")")
        }
    }
    
    /// Handle system wake event - clears sleep state and prepares for normal tracking
    private func handleSystemWake() {
        logger.info("System woke from sleep")
        
        // Log sleep duration if available
        if let sleepStart = sleepStartTime {
            let sleepDuration = Date().timeIntervalSince(sleepStart)
            logger.info("System was asleep for \(sleepDuration) seconds")
        }
        
        // Clear sleep state
        sleepStartTime = nil
        
        // Check storage availability after wake
        if !isStorageAvailable {
            Task {
                await checkStorageAvailability()
            }
        }
        
        // Process any pending activities if storage is available
        if !pendingActivities.isEmpty && isStorageAvailable {
            logger.info("Processing \(self.pendingActivities.count) pending activities after wake")
            if let context = modelContext {
                Task {
                    await processPendingActivities(modelContext: context)
                }
            }
        }
        
        // TODO: Add user preference/setting to determine whether to continue tracking 
        // the same time-entry that was active before sleep or start fresh.
        // This will be implemented at the time-entry level, not activity level.
        
        // Normal app activation events will handle starting new tracking automatically
        
        logger.info("Wake handling completed - ready for new app activation events")
        logHealthMetrics()
    }
}