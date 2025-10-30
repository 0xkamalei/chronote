
import AppKit
import Foundation
import os.log
import SwiftData

@MainActor
class ActivityManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ActivityManager()

    // MARK: - Private Properties

    private var currentActivity: Activity?
    private var notificationObservers: [NSObjectProtocol] = []
    private var modelContext: ModelContext?

    private var sleepStartTime: Date?

    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 0.5
    private var isStorageAvailable = true
    private var pendingActivities: [Activity] = []

    private let logger = Logger(subsystem: "com.time-vscode.ActivityManager", category: "ActivityTracking")

    private var lastSuccessfulSave: Date?
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 5

    // MARK: - Initialization

    private init() {
    }

    // MARK: - Public Methods

    /// Start tracking app activity with comprehensive initialization
    func startTracking(modelContext: ModelContext) {
        stopTracking(modelContext: modelContext)

        self.modelContext = modelContext

        isStorageAvailable = true
        consecutiveFailures = 0
        lastSuccessfulSave = Date()

        Task {
            await cleanupIncompleteRecords(modelContext: modelContext)
        }

        let notificationCenter = NSWorkspace.shared.notificationCenter

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

        let sleepObserver = notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSystemSleep()
            }
        }
        notificationObservers.append(sleepObserver)

        let wakeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
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
        if let current = currentActivity {
            current.endTime = Date()
            current.duration = current.calculatedDuration

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

        let notificationCenter = NSWorkspace.shared.notificationCenter

        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }

        notificationObservers.removeAll()

        self.modelContext = nil
        currentActivity = nil
        sleepStartTime = nil

        logger.info("Stopped tracking, removed all observers and cleared state")
    }

    /// Track app switch to new application with notification userInfo
    func trackAppSwitch(notification: Notification, modelContext: ModelContext) async {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier != nil
        else {
            logger.error("Invalid app activation notification")
            return
        }

        let appInfo = resolveAppInfo(from: app)
        await trackAppSwitch(appInfo: appInfo, modelContext: modelContext)
    }

    /// Track app switch with additional context data
    func trackAppSwitchWithContext(
        notification: Notification,
        windowTitle: String? = nil,
        url: String? = nil,
        documentPath: String? = nil,
        contextData: Data? = nil,
        modelContext: ModelContext
    ) async {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier != nil
        else {
            logger.error("Invalid app activation notification")
            return
        }

        let appInfo = resolveAppInfo(from: app)
        await trackAppSwitchWithContext(
            appInfo: appInfo,
            windowTitle: windowTitle,
            url: url,
            documentPath: documentPath,
            contextData: contextData,
            modelContext: modelContext
        )
    }

    /// Track app switch to new application with app information
    private func trackAppSwitch(appInfo: AppInfo, modelContext: ModelContext) async {
        await trackAppSwitchWithContext(
            appInfo: appInfo,
            windowTitle: nil,
            url: nil,
            documentPath: nil,
            contextData: nil,
            modelContext: modelContext
        )
    }

    /// Track app switch with context data
    private func trackAppSwitchWithContext(
        appInfo: AppInfo,
        windowTitle: String? = nil,
        url: String? = nil,
        documentPath: String? = nil,
        contextData: Data? = nil,
        modelContext: ModelContext
    ) async {
        do {
            let now = Date()

            guard !appInfo.name.isEmpty else {
                logger.error("App name cannot be empty")
                return
            }

            if let current = currentActivity,
               current.appBundleId == appInfo.bundleId
            {
                logger.debug("Ignoring switch to same app: \(appInfo.name)")
                return
            }

            if currentActivity == nil {
                let newActivity = Activity(
                    appName: appInfo.name,
                    appBundleId: appInfo.bundleId,
                    appTitle: appInfo.title,
                    duration: 0, // Will be calculated when activity ends
                    startTime: now,
                    endTime: nil, // nil indicates this is the active activity
                    icon: appInfo.icon,
                    windowTitle: windowTitle,
                    url: url,
                    documentPath: documentPath,
                    contextData: contextData
                )

                currentActivity = newActivity
                logger.info("Started tracking new activity - \(appInfo.name) (not saved yet)")
                return
            }

            if let current = currentActivity {
                if current.startTime > now {
                    logger.error("Current activity has invalid start time, fixing")
                    current.startTime = now.addingTimeInterval(-60) // Set to 1 minute ago as fallback
                }

                current.endTime = now
                current.duration = current.calculatedDuration

                if current.duration < 0 {
                    logger.warning("Negative duration detected, setting to 0")
                    current.duration = 0
                }

                try await saveActivity(current, modelContext: modelContext)
            }

            let newActivity = Activity(
                appName: appInfo.name,
                appBundleId: appInfo.bundleId,
                appTitle: appInfo.title,
                duration: 0, // Will be calculated when activity ends
                startTime: now,
                endTime: nil, // nil indicates this is the active activity
                icon: appInfo.icon,
                windowTitle: windowTitle,
                url: url,
                documentPath: documentPath,
                contextData: contextData
            )

            currentActivity = newActivity

            logger.info("Started new activity - \(appInfo.name) (\(appInfo.bundleId))")

        } catch {
            logger.error("Error tracking app switch - \(error.localizedDescription)")

            currentActivity = nil

            logHealthMetrics()
        }
    }

    // MARK: - SwiftData Persistence Operations

    /// Save an activity to the database with comprehensive error handling and retry logic
    func saveActivity(_ activity: Activity, modelContext: ModelContext) async throws {
        try validateActivity(activity)

        guard isStorageAvailable else {
            logger.warning("Storage unavailable, adding activity to pending queue: \(activity.appName)")
            pendingActivities.append(activity)
            throw ActivityManagerError.storageUnavailable
        }

        var lastError: Error?

        for attempt in 1 ... maxRetryAttempts {
            do {
                if activity.endTime == nil {
                    try ensureOnlyOneActiveActivity(excluding: activity, modelContext: modelContext)
                }

                modelContext.insert(activity)

                try modelContext.save()

                consecutiveFailures = 0
                lastSuccessfulSave = Date()

                logger.info("Successfully saved activity - \(activity.appName) (\(activity.duration, privacy: .public)s) on attempt \(attempt)")

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

                if shouldRetry(error: error), attempt < maxRetryAttempts {
                    let delay = retryDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    break
                }
            }
        }

        handleSaveFailure(activity: activity, error: lastError!)
        throw ActivityManagerError.saveFailed(lastError!)
    }

    /// Save multiple activities in a batch operation with comprehensive error handling
    func batchSaveActivities(_ activities: [Activity], modelContext: ModelContext) async throws {
        guard !activities.isEmpty else {
            logger.info("No activities to save in batch")
            return
        }

        guard isStorageAvailable else {
            logger.warning("Storage unavailable, adding \(activities.count) activities to pending queue")
            pendingActivities.append(contentsOf: activities)
            throw ActivityManagerError.storageUnavailable
        }

        for activity in activities {
            try validateActivity(activity)
        }

        var lastError: Error?

        for attempt in 1 ... maxRetryAttempts {
            do {
                let activeActivities = activities.filter { $0.endTime == nil }
                if activeActivities.count > 1 {
                    throw ActivityManagerError.invalidData("Cannot batch save multiple active activities")
                }

                for activity in activities {
                    modelContext.insert(activity)
                }

                try modelContext.save()

                consecutiveFailures = 0
                lastSuccessfulSave = Date()

                logger.info("Successfully batch saved \(activities.count) activities on attempt \(attempt)")
                return

            } catch {
                lastError = error
                consecutiveFailures += 1

                logger.error("Batch save attempt \(attempt) failed: \(error.localizedDescription)")

                if shouldRetry(error: error), attempt < maxRetryAttempts {
                    let delay = retryDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    break
                }
            }
        }

        handleBatchSaveFailure(activities: activities, error: lastError!)
        throw ActivityManagerError.batchSaveFailed(lastError!)
    }

    /// Get the currently active activity (always returns in-memory state)
    func getCurrentActivity() -> Activity? {
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
        // Validate new context data fields first
        try activity.validateContextData()
        let trimmedAppName = activity.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppName.isEmpty else {
            throw ActivityManagerError.invalidData("App name cannot be empty")
        }
        guard trimmedAppName.count <= 255 else {
            throw ActivityManagerError.invalidData("App name too long (max 255 characters)")
        }

        let trimmedBundleId = activity.appBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBundleId.isEmpty else {
            throw ActivityManagerError.invalidData("App bundle ID cannot be empty")
        }
        guard trimmedBundleId.count <= 255 else {
            throw ActivityManagerError.invalidData("App bundle ID too long (max 255 characters)")
        }

        if let appTitle = activity.appTitle {
            guard appTitle.count <= 500 else {
                throw ActivityManagerError.invalidData("App title too long (max 500 characters)")
            }
        }

        let now = Date()
        let maxPastTime = now.addingTimeInterval(-86400 * 30) // 30 days ago
        let maxFutureTime = now.addingTimeInterval(60) // 1 minute in future (for clock skew)

        guard activity.startTime >= maxPastTime else {
            throw ActivityManagerError.invalidData("Start time too far in the past (max 30 days)")
        }
        guard activity.startTime <= maxFutureTime else {
            throw ActivityManagerError.invalidData("Start time cannot be in the future")
        }

        if let endTime = activity.endTime {
            guard endTime >= activity.startTime else {
                throw ActivityManagerError.invalidData("End time must be after start time")
            }

            guard endTime <= maxFutureTime else {
                throw ActivityManagerError.invalidData("End time cannot be in the future")
            }

            let calculatedDuration = endTime.timeIntervalSince(activity.startTime)
            guard calculatedDuration <= 86400 else {
                throw ActivityManagerError.invalidData("Activity duration cannot exceed 24 hours")
            }

            let tolerance: TimeInterval = 2.0 // Allow 2 second tolerance for processing delays
            guard abs(activity.duration - calculatedDuration) <= tolerance else {
                logger.warning("Duration mismatch: stored=\(activity.duration), calculated=\(calculatedDuration)")
                throw ActivityManagerError.invalidData("Duration does not match calculated time difference")
            }
        } else {
            let activeDuration = now.timeIntervalSince(activity.startTime)
            guard activeDuration <= 86400 else {
                throw ActivityManagerError.invalidData("Active activity cannot run longer than 24 hours")
            }
        }

        guard activity.duration >= 0 else {
            throw ActivityManagerError.invalidData("Duration cannot be negative")
        }

        guard activity.icon.count <= 100 else {
            throw ActivityManagerError.invalidData("Icon identifier too long (max 100 characters)")
        }

        if activity.endTime == nil {
            if let existing = currentActivity, existing.id != activity.id {
                throw ActivityManagerError.invalidData("Only one active activity can exist at a time")
            }
        }
    }

    // MARK: - Error Handling Helpers

    /// Determine if an error should be retried
    private func shouldRetry(error: Error) -> Bool {
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSCocoaErrorDomain:
                switch nsError.code {
                case NSPersistentStoreSaveError,
                     NSManagedObjectContextLockingError,
                     NSPersistentStoreTimeoutError:
                    return true
                default:
                    return false
                }
            case NSSQLiteErrorDomain:
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

        if error is ActivityManagerError {
            return false
        }

        return false
    }

    /// Handle save failure with graceful degradation
    private func handleSaveFailure(activity: Activity, error: Error) {
        logger.error("Save failed after all retry attempts for activity \(activity.appName): \(error.localizedDescription)")

        if consecutiveFailures >= maxConsecutiveFailures {
            isStorageAvailable = false
            logger.critical("Storage marked as unavailable after \(self.consecutiveFailures) consecutive failures")

            Task {
                await checkStorageAvailability()
            }
        }

        pendingActivities.append(activity)

        logHealthMetrics()
    }

    /// Handle batch save failure with graceful degradation
    private func handleBatchSaveFailure(activities: [Activity], error: Error) {
        logger.error("Batch save failed after all retry attempts for \(activities.count) activities: \(error.localizedDescription)")

        if consecutiveFailures >= maxConsecutiveFailures {
            isStorageAvailable = false
            logger.critical("Storage marked as unavailable after \(self.consecutiveFailures) consecutive failures")
        }

        pendingActivities.append(contentsOf: activities)

        logHealthMetrics()
    }

    /// Process pending activities when storage becomes available
    private func processPendingActivities(modelContext: ModelContext) async {
        guard !pendingActivities.isEmpty, isStorageAvailable else { return }

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

        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

        guard let context = modelContext else {
            logger.error("No model context available for storage check")
            return
        }

        do {
            var descriptor = FetchDescriptor<Activity>()
            descriptor.fetchLimit = 1
            _ = try context.fetch(descriptor)

            isStorageAvailable = true
            consecutiveFailures = 0
            logger.info("Storage availability restored")

            await processPendingActivities(modelContext: context)

        } catch {
            logger.error("Storage still unavailable: \(error.localizedDescription)")

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
            let oneDayAgo = Date().addingTimeInterval(-86400)
            let predicate = #Predicate<Activity> { activity in
                activity.endTime == nil && activity.startTime < oneDayAgo
            }

            let descriptor = FetchDescriptor<Activity>(predicate: predicate)
            let staleActivities = try modelContext.fetch(descriptor)

            if !staleActivities.isEmpty {
                logger.warning("Found \(staleActivities.count) stale active activities, cleaning up")

                for activity in staleActivities {
                    activity.endTime = activity.startTime.addingTimeInterval(3600)
                    activity.duration = activity.calculatedDuration
                }

                try modelContext.save()
                logger.info("Cleaned up \(staleActivities.count) stale activities")
            }

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
            case let .saveFailed(error):
                return "Failed to save activity: \(error.localizedDescription)"
            case let .batchSaveFailed(error):
                return "Failed to batch save activities: \(error.localizedDescription)"
            case let .invalidData(message):
                return "Invalid activity data: \(message)"
            case .noModelContext:
                return "No model context available for database operations"
            case let .sleepHandlingFailed(error):
                return "Failed to handle system sleep: \(error.localizedDescription)"
            case let .wakeHandlingFailed(error):
                return "Failed to handle system wake: \(error.localizedDescription)"
            case .storageUnavailable:
                return "Storage is currently unavailable, activity queued for later processing"
            case let .dataIntegrityViolation(message):
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

        if let bundleId = app.bundleIdentifier,
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        {
            return displayName
        }

        return nil
    }

    /// Get app name from bundle identifier with fallback
    private func getAppName(bundleId: String, fallbackName: String) -> String {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }),
           let localizedName = app.localizedName, !localizedName.isEmpty
        {
            return localizedName
        }

        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty
        {
            return displayName
        }

        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty
        {
            return bundleName
        }

        let components = bundleId.components(separatedBy: ".")
        if let lastComponent = components.last, !lastComponent.isEmpty {
            return lastComponent.prefix(1).uppercased() + lastComponent.dropFirst()
        }

        return fallbackName
    }

    /// Get app icon identifier for the given bundle ID
    private func getAppIcon(bundleId _: String) -> String {
        return "app.fill"
    }

    /// Handle app activation notification
    private func handleAppActivation(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier
        else {
            logger.error("Invalid app activation notification")
            return
        }

        let appName = app.localizedName ?? bundleId
        logger.debug("App activated - \(appName) (\(bundleId))")

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

            sleepStartTime = Date()

            if let current = currentActivity {
                let sleepTime = Date()
                current.endTime = sleepTime
                current.duration = current.calculatedDuration

                if current.duration < 0 {
                    logger.warning("Negative duration detected during sleep, setting to 0")
                    current.duration = 0
                }

                if let context = modelContext {
                    try await saveActivity(current, modelContext: context)

                    try context.save()
                    logger.info("Successfully saved activity before sleep: \(current.appName)")
                } else {
                    logger.error("No model context available to save activity before sleep")
                    throw ActivityManagerError.noModelContext
                }

                currentActivity = nil
            }

            if !pendingActivities.isEmpty, isStorageAvailable {
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

            sleepStartTime = Date()
            currentActivity = nil

            logHealthMetrics()

            let sleepError = ActivityManagerError.sleepHandlingFailed(error)
            logger.error("Sleep handling error details - \(sleepError.errorDescription ?? "Unknown error")")
        }
    }

    /// Handle system wake event - clears sleep state and prepares for normal tracking
    private func handleSystemWake() {
        logger.info("System woke from sleep")

        if let sleepStart = sleepStartTime {
            let sleepDuration = Date().timeIntervalSince(sleepStart)
            logger.info("System was asleep for \(sleepDuration) seconds")
        }

        sleepStartTime = nil

        if !isStorageAvailable {
            Task {
                await checkStorageAvailability()
            }
        }

        if !pendingActivities.isEmpty, isStorageAvailable {
            logger.info("Processing \(self.pendingActivities.count) pending activities after wake")
            if let context = modelContext {
                Task {
                    await processPendingActivities(modelContext: context)
                }
            }
        }



        logger.info("Wake handling completed - ready for new app activation events")
        logHealthMetrics()
    }
    
    /// End the current activity at a specific time (used for idle detection)
    func endCurrentActivityAt(time: Date, modelContext: ModelContext) {
        guard let current = currentActivity else {
            logger.debug("No current activity to end at specified time")
            return
        }
        
        logger.info("Ending current activity '\(current.appName)' at \(time)")
        
        current.endTime = time
        current.duration = current.calculatedDuration
        
        if current.duration < 0 {
            logger.warning("Negative duration detected when ending activity at specific time, setting to 0")
            current.duration = 0
        }
        
        Task {
            do {
                try await saveActivity(current, modelContext: modelContext)
                logger.info("Successfully saved activity ended at specific time: \(current.appName)")
            } catch {
                logger.error("Error saving activity ended at specific time: \(error)")
            }
        }
        
        currentActivity = nil
    }
    
    // MARK: - Data Conflict Resolution Support
    
    /// Get all activities from the database for conflict resolution
    func getAllActivities() async -> [Activity] {
        guard let modelContext = modelContext else {
            logger.error("No model context available for getAllActivities")
            return []
        }
        
        do {
            let descriptor = FetchDescriptor<Activity>(
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            let activities = try modelContext.fetch(descriptor)
            logger.info("Retrieved \(activities.count) activities for conflict resolution")
            return activities
        } catch {
            logger.error("Failed to fetch all activities: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Update an activity for conflict resolution
    func updateActivity(_ activity: Activity) async {
        guard let modelContext = modelContext else {
            logger.error("No model context available for updateActivity")
            return
        }
        
        do {
            try validateActivity(activity)
            try modelContext.save()
            logger.info("Updated activity: \(activity.appName)")
        } catch {
            logger.error("Failed to update activity: \(error.localizedDescription)")
        }
    }
    
    /// Delete an activity for conflict resolution
    func deleteActivity(_ activity: Activity) async {
        guard let modelContext = modelContext else {
            logger.error("No model context available for deleteActivity")
            return
        }
        
        do {
            modelContext.delete(activity)
            try modelContext.save()
            logger.info("Deleted activity: \(activity.appName)")
        } catch {
            logger.error("Failed to delete activity: \(error.localizedDescription)")
        }
    }
}
