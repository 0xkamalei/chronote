import AppKit
import Foundation
import os.log
import SwiftData

/// Enhanced activity tracker that monitors application switches and system events
/// Integrates with existing ActivityManager for data persistence and IdleDetector for idle management
@MainActor
class ActivityTracker: ObservableObject {
    // MARK: - Singleton

    static let shared = ActivityTracker()

    // MARK: - Published Properties

    @Published var isTracking: Bool = false
    @Published var currentApplication: String?
    @Published var isIdlePaused: Bool = false

    // MARK: - Private Properties

    private var notificationObservers: [NSObjectProtocol] = []
    private var activityManager: ActivityManager
    private var metadataCapture: ApplicationMetadataCapture
    private var contextCapturer: ContextCapturer
    private var idleDetector: IdleDetector
    private var modelContext: ModelContext?
    private var notificationManager: NotificationManager?

    private let logger = Logger(subsystem: "com.time-vscode.ActivityTracker", category: "ActivityTracking")

    // Configuration
    private var isTrackingEnabled: Bool = true
    private var minimumActivityDuration: TimeInterval = 1.0 // 1 second minimum
    private var trackWindowTitles: Bool = true
    private var captureBrowserData: Bool = true
    private var respectPrivateBrowsing: Bool = true

    // MARK: - Initialization

    private init() {
        activityManager = ActivityManager.shared
        metadataCapture = ApplicationMetadataCapture.shared
        contextCapturer = ContextCapturer()
        idleDetector = IdleDetector.shared
        setupIdleDetectionIntegration()
        logger.info("ActivityTracker initialized with context capture and idle detection support")
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopTracking()
        }
    }

    // MARK: - Public Methods

    /// Sets the notification manager for tracking status notifications
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
    }

    /// Start tracking app activity with comprehensive initialization
    func startTracking(modelContext: ModelContext) {
        guard !isTracking else {
            logger.warning("ActivityTracker is already tracking")
            return
        }

        guard isTrackingEnabled else {
            logger.info("Activity tracking is disabled")
            notificationManager?.sendTrackingStoppedNotification(reason: "Tracking disabled by user")
            return
        }

        self.modelContext = modelContext

        // Clear any existing observers first
        stopTracking()

        do {
            try setupNotificationObservers()
        } catch {
            logger.error("Failed to setup notification observers: \(error.localizedDescription)")
            notificationManager?.sendTrackingStoppedNotification(reason: "Failed to initialize: \(error.localizedDescription)")
            return  // Just return instead of throwing since the function doesn't throw
        }

        // Start the underlying ActivityManager
        activityManager.startTracking(modelContext: modelContext)

        // Start idle detection
        idleDetector.startMonitoring()

        isTracking = true
        logger.info("ActivityTracker started successfully with \(self.notificationObservers.count) observers and idle detection")
        
        // Send tracking restarted notification if we have a notification manager
        notificationManager?.sendTrackingRestartedNotification()
    }

    /// Stop tracking app activity
    func stopTracking(reason: String = "User stopped tracking") {
        guard isTracking else {
            logger.debug("ActivityTracker is not currently tracking")
            return
        }

        removeNotificationObservers()

        // Stop the underlying ActivityManager
        if let context = modelContext {
            activityManager.stopTracking(modelContext: context)
        }

        // Stop idle detection
        idleDetector.stopMonitoring()

        isTracking = false
        currentApplication = nil
        isIdlePaused = false
        modelContext = nil

        logger.info("ActivityTracker stopped successfully: \(reason)")
        
        // Send tracking stopped notification
        notificationManager?.sendTrackingStoppedNotification(reason: reason)
    }

    /// Get current tracking status and health information
    func getTrackingStatus() -> TrackingStatus {
        let healthStatus = activityManager.getHealthStatus()
        let idleStatus = idleDetector.getIdleStatus()

        return TrackingStatus(
            isTracking: isTracking,
            isTrackingEnabled: isTrackingEnabled,
            observerCount: notificationObservers.count,
            currentApplication: currentApplication,
            activityManagerHealth: healthStatus,
            minimumActivityDuration: minimumActivityDuration,
            trackWindowTitles: trackWindowTitles,
            captureBrowserData: captureBrowserData,
            respectPrivateBrowsing: respectPrivateBrowsing,
            accessibilityEnabled: contextCapturer.isAccessibilityEnabled(),
            isIdlePaused: isIdlePaused,
            idleStatus: idleStatus
        )
    }

    /// Update tracking configuration
    func updateConfiguration(
        isEnabled: Bool? = nil,
        minimumDuration: TimeInterval? = nil,
        trackTitles: Bool? = nil,
        captureBrowser: Bool? = nil,
        respectPrivate: Bool? = nil
    ) {
        var configChanged = false

        if let enabled = isEnabled, enabled != isTrackingEnabled {
            isTrackingEnabled = enabled
            configChanged = true
            logger.info("Tracking enabled changed to: \(enabled)")
        }

        if let duration = minimumDuration, duration != minimumActivityDuration {
            minimumActivityDuration = max(0.1, duration) // Minimum 0.1 seconds
            configChanged = true
            logger.info("Minimum activity duration changed to: \(duration)")
        }

        if let trackTitles = trackTitles, trackTitles != trackWindowTitles {
            trackWindowTitles = trackTitles
            contextCapturer.setCaptureWindowTitles(trackTitles)
            configChanged = true
            logger.info("Track window titles changed to: \(trackTitles)")
        }

        if let captureBrowser = captureBrowser, captureBrowser != captureBrowserData {
            captureBrowserData = captureBrowser
            contextCapturer.setCaptureBrowserData(captureBrowser)
            configChanged = true
            logger.info("Capture browser data changed to: \(captureBrowser)")
        }

        if let respectPrivate = respectPrivate, respectPrivate != respectPrivateBrowsing {
            respectPrivateBrowsing = respectPrivate
            contextCapturer.setRespectPrivateBrowsing(respectPrivate)
            configChanged = true
            logger.info("Respect private browsing changed to: \(respectPrivate)")
        }

        if configChanged {
            // Restart tracking if currently active to apply new configuration
            if isTracking, let context = modelContext {
                logger.info("Restarting tracking to apply configuration changes")
                stopTracking()
                startTracking(modelContext: context)
            }
        }
    }

    // MARK: - Private Methods - Idle Detection Integration
    
    /// Set up integration with idle detection system
    private func setupIdleDetectionIntegration() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIdleStateChangeNotification(_:)),
            name: .idleStateChanged,
            object: nil
        )
        
        logger.debug("Idle detection integration set up")
    }
    
    @objc private func handleIdleStateChangeNotification(_ notification: Notification) {
        Task { @MainActor in
            handleIdleStateChange(notification)
        }
    }
    
    /// Handle idle state changes from IdleDetector
    private func handleIdleStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isIdle = userInfo["isIdle"] as? Bool,
              let idleStartTime = userInfo["idleStartTime"] as? Date
        else {
            logger.error("Invalid idle state change notification")
            return
        }
        
        if isIdle {
            handleIdleDetected(idleStartTime: idleStartTime)
        } else {
            if let idleDuration = userInfo["idleDuration"] as? TimeInterval,
               let returnTime = userInfo["returnTime"] as? Date {
                handleReturnFromIdle(
                    idleStartTime: idleStartTime,
                    idleDuration: idleDuration,
                    returnTime: returnTime
                )
            }
        }
    }
    
    /// Handle when idle state is detected - pause activity tracking
    private func handleIdleDetected(idleStartTime: Date) {
        guard isTracking else { return }
        
        logger.info("Idle detected - pausing activity tracking at \(idleStartTime)")
        isIdlePaused = true
        
        // End the current activity at the idle start time
        if let context = modelContext {
            activityManager.endCurrentActivityAt(time: idleStartTime, modelContext: context)
        }
    }
    
    /// Handle when user returns from idle - resume activity tracking and adjust durations
    private func handleReturnFromIdle(
        idleStartTime: Date,
        idleDuration: TimeInterval,
        returnTime: Date
    ) {
        guard isTracking else { return }
        
        logger.info("Returned from idle - resuming activity tracking after \(idleDuration)s idle")
        isIdlePaused = false
        
        // Mark any activities during idle period with idle markers
        if let context = modelContext {
            markIdleTimeInActivities(
                idleStartTime: idleStartTime,
                idleDuration: idleDuration,
                context: context
            )
        }
        
        // Resume tracking from the return time
        currentApplication = getCurrentActiveApplication()
    }
    
    /// Mark activities that occurred during idle time with idle markers
    private func markIdleTimeInActivities(
        idleStartTime: Date,
        idleDuration: TimeInterval,
        context: ModelContext
    ) {
        let idleEndTime = idleStartTime.addingTimeInterval(idleDuration)
        
        do {
            // Find activities that overlap with the idle period
            // We need to fetch all activities and filter them manually due to SwiftData predicate limitations
            let descriptor = FetchDescriptor<Activity>()
            let allActivities = try context.fetch(descriptor)
            
            let overlappingActivities = allActivities.filter { activity in
                let activityEndTime = activity.endTime ?? Date()
                return activity.startTime < idleEndTime && activityEndTime > idleStartTime
            }
            
            for activity in overlappingActivities {
                let activityEndTime = activity.endTime ?? Date()
                
                // Adjust activity duration to exclude idle time
                if activity.startTime >= idleStartTime && activityEndTime <= idleEndTime {
                    // Activity is entirely within idle period - mark as idle
                    activity.isIdleTime = true
                    logger.debug("Marked activity '\(activity.appName)' as idle time")
                } else if activity.startTime < idleStartTime && activityEndTime > idleEndTime {
                    // Activity spans the entire idle period - split it
                    splitActivityAroundIdlePeriod(
                        activity: activity,
                        idleStartTime: idleStartTime,
                        idleEndTime: idleEndTime,
                        context: context
                    )
                } else if activity.startTime < idleStartTime && activityEndTime > idleStartTime {
                    // Activity started before idle and ended during idle - truncate
                    activity.endTime = idleStartTime
                    logger.debug("Truncated activity '\(activity.appName)' at idle start")
                } else if activity.startTime < idleEndTime && activityEndTime > idleEndTime {
                    // Activity started during idle and ended after - adjust start time
                    activity.startTime = idleEndTime
                    logger.debug("Adjusted activity '\(activity.appName)' start time to idle end")
                }
            }
            
            try context.save()
            logger.info("Processed \(overlappingActivities.count) activities for idle time adjustment")
            
        } catch {
            logger.error("Failed to mark idle time in activities: \(error)")
        }
    }
    
    /// Split an activity that spans an idle period into two activities
    private func splitActivityAroundIdlePeriod(
        activity: Activity,
        idleStartTime: Date,
        idleEndTime: Date,
        context: ModelContext
    ) {
        guard let originalEndTime = activity.endTime else {
            logger.warning("Cannot split activity with no end time")
            return
        }
        
        // Truncate the original activity to end at idle start
        activity.endTime = idleStartTime
        
        // Create a new activity for the time after idle
        let postIdleActivity = Activity(
            id: UUID().uuidString,
            appName: activity.appName,
            bundleID: activity.appBundleId,
            startTime: idleEndTime,
            endTime: originalEndTime,
            windowTitle: activity.windowTitle,
            url: activity.url,
            documentPath: activity.documentPath,
            isIdleTime: false
        )
        
        context.insert(postIdleActivity)
        
        logger.info("Split activity '\(activity.appName)' around idle period")
    }
    
    /// Get the currently active application
    private func getCurrentActiveApplication() -> String? {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            let metadata = metadataCapture.extractApplicationMetadata(from: frontmostApp)
            return metadata.bestDisplayName
        }
        return nil
    }

    // MARK: - Private Methods - Notification Setup

    /// Configure NSWorkspace notification observers with proper error handling
    private func setupNotificationObservers() throws {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        do {
            // Configure didActivateApplicationNotification listener
            let appActivationObserver = notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    do {
                        try await self?.handleAppActivation(notification)
                    } catch {
                        self?.logger.error("Failed to handle app activation: \(error.localizedDescription)")
                        self?.handleTrackingError(error)
                    }
                }
            }
            notificationObservers.append(appActivationObserver)
            logger.debug("Added app activation observer")

            // Configure willSleepNotification listener
            let sleepObserver = notificationCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    do {
                        try await self?.handleSystemSleep(notification)
                    } catch {
                        self?.logger.error("Failed to handle system sleep: \(error.localizedDescription)")
                        self?.handleTrackingError(error)
                    }
                }
            }
            notificationObservers.append(sleepObserver)
            logger.debug("Added system sleep observer")

            // Configure didWakeNotification listener
            let wakeObserver = notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    do {
                        try self?.handleSystemWake(notification)
                    } catch {
                        self?.logger.error("Failed to handle system wake: \(error.localizedDescription)")
                        self?.handleTrackingError(error)
                    }
                }
            }
            notificationObservers.append(wakeObserver)
            logger.debug("Added system wake observer")

            logger.info("Successfully configured \(self.notificationObservers.count) notification observers")
            
        } catch {
            logger.error("Failed to setup notification observers: \(error.localizedDescription)")
            notificationManager?.sendTrackingStoppedNotification(reason: "Failed to setup system observers")
            throw ActivityTrackerError.notificationRegistrationFailed(error)
        }
    }
    
    /// Handle tracking errors and send appropriate notifications
    private func handleTrackingError(_ error: Error) {
        logger.error("Tracking error occurred: \(error.localizedDescription)")
        
        // Check if this is a critical error that should stop tracking
        let isCritical = shouldStopTrackingForError(error)
        
        if isCritical {
            stopTracking(reason: "Critical error: \(error.localizedDescription)")
        } else {
            // Send a warning notification but continue tracking
            notificationManager?.sendTrackingStoppedNotification(reason: "Warning: \(error.localizedDescription)")
        }
    }
    
    /// Determine if an error should cause tracking to stop
    private func shouldStopTrackingForError(_ error: Error) -> Bool {
        // Add logic to determine critical vs non-critical errors
        if error is ActivityTrackerError {
            return true
        }
        
        // Check for specific error types that indicate system-level issues
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            // Core Data or system-level errors are usually critical
            return true
        }
        
        return false
    }

    /// Remove all notification observers with proper cleanup and memory management
    private func removeNotificationObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }

        let removedCount = notificationObservers.count
        notificationObservers.removeAll()

        if removedCount > 0 {
            logger.info("Removed \(removedCount) notification observers")
        }
    }

    // MARK: - Private Methods - Event Handlers

    /// Handle application activation events with context capture
    private func handleAppActivation(_ notification: Notification) async throws {
        guard isTracking, isTrackingEnabled else {
            logger.debug("Ignoring app activation - tracking disabled")
            return
        }

        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier
        else {
            logger.error("Invalid app activation notification - missing application info")
            return
        }

        // Extract comprehensive application metadata
        let metadata = metadataCapture.extractApplicationMetadata(from: app)
        currentApplication = metadata.bestDisplayName

        logger.debug("App activated: \(metadata.bestDisplayName) (\(bundleId))")
        logger.debug("Metadata extracted - Name: \(metadata.appName), Version: \(metadata.version ?? "unknown")")

        // Capture context information
        let contextData = await captureContextData(for: app)

        // Delegate to ActivityManager for actual tracking with context
        guard let context = modelContext else {
            logger.error("No model context available for app activation tracking")
            throw ActivityTrackerError.trackingNotStarted
        }

        await activityManager.trackAppSwitchWithContext(
            notification: notification,
            windowTitle: contextData.windowTitle,
            url: contextData.url,
            documentPath: contextData.documentPath,
            contextData: contextData.additionalData,
            modelContext: context
        )
    }

    /// Handle system sleep events
    private func handleSystemSleep(_: Notification) async throws {
        guard isTracking else {
            logger.debug("Ignoring system sleep - not tracking")
            return
        }

        logger.info("System going to sleep - pausing activity tracking")
        currentApplication = nil

        // The ActivityManager handles the actual sleep logic
        // We just need to update our state
        logger.debug("System sleep event handled")
    }

    /// Handle system wake events
    private func handleSystemWake(_: Notification) throws {
        guard isTracking else {
            logger.debug("Ignoring system wake - not tracking")
            return
        }

        logger.info("System woke from sleep - resuming activity tracking")

        // The ActivityManager handles the actual wake logic
        // We just need to update our state
        logger.debug("System wake event handled")
    }

    // MARK: - Context Capture Methods

    /// Context data structure for captured information
    private struct CapturedContextData {
        let windowTitle: String?
        let url: String?
        let documentPath: String?
        let additionalData: Data?
    }

    /// Capture context information for the given application
    private func captureContextData(for app: NSRunningApplication) async -> CapturedContextData {
        guard trackWindowTitles || captureBrowserData else {
            logger.debug("Context capture disabled, skipping")
            return CapturedContextData(windowTitle: nil, url: nil, documentPath: nil, additionalData: nil)
        }

        // Capture window title if enabled
        var windowTitle: String?
        if trackWindowTitles {
            if let capturedTitle = contextCapturer.captureWindowTitle(for: app) {
                windowTitle = filterSensitiveWindowTitle(capturedTitle)
                if let title = windowTitle {
                    logger.debug("Captured window title: \(title)")
                }
            }
        }

        // Capture browser context if this is a supported browser
        var url: String?
        var additionalData: Data?
        
        if captureBrowserData && contextCapturer.isSupportedBrowser(app) {
            if let browserContext = contextCapturer.captureBrowserContext(for: app) {
                logger.debug("Captured browser context - URL: \(browserContext.url ?? "none"), Private: \(browserContext.isPrivate)")
                
                // Only include data if not in private mode or if we're not respecting private browsing
                if !browserContext.isPrivate || !respectPrivateBrowsing {
                    url = browserContext.url
                    
                    // Store additional browser context data
                    additionalData = try? JSONEncoder().encode(browserContext)
                } else {
                    logger.debug("Skipped browser data due to private browsing mode")
                }
            }
        }

        // TODO: Add document path capture for document-based applications
        let documentPath: String? = nil

        return CapturedContextData(
            windowTitle: windowTitle,
            url: url,
            documentPath: documentPath,
            additionalData: additionalData
        )
    }

    /// Filter sensitive information from window titles
    private func filterSensitiveWindowTitle(_ title: String) -> String? {
        let lowercaseTitle = title.lowercased()
        
        // List of sensitive keywords that should cause filtering
        let sensitiveKeywords = [
            "password", "login", "signin", "auth", "private", "incognito",
            "banking", "payment", "credit", "ssn", "social security"
        ]
        
        // Check if title contains sensitive keywords
        for keyword in sensitiveKeywords {
            if lowercaseTitle.contains(keyword) {
                logger.debug("Filtered sensitive window title containing: \(keyword)")
                return nil // Filter out completely
            }
        }
        
        return title
    }

    /// Check if accessibility permissions are available
    func checkAccessibilityPermissions() -> Bool {
        return contextCapturer.isAccessibilityEnabled()
    }

    /// Request accessibility permissions from the user
    func requestAccessibilityPermissions() -> Bool {
        return contextCapturer.requestAccessibilityPermissions()
    }

    // MARK: - Supporting Types

    /// Comprehensive tracking status information
    struct TrackingStatus {
        let isTracking: Bool
        let isTrackingEnabled: Bool
        let observerCount: Int
        let currentApplication: String?
        let activityManagerHealth: ActivityManager.HealthStatus
        let minimumActivityDuration: TimeInterval
        let trackWindowTitles: Bool
        let captureBrowserData: Bool
        let respectPrivateBrowsing: Bool
        let accessibilityEnabled: Bool
        let isIdlePaused: Bool
        let idleStatus: IdleDetector.IdleStatus

        var isHealthy: Bool {
            return isTracking &&
                isTrackingEnabled &&
                observerCount > 0 &&
                activityManagerHealth.isHealthy &&
                idleStatus.isHealthy
        }

        var statusDescription: String {
            if !isTrackingEnabled {
                return "Tracking disabled"
            } else if !isTracking {
                return "Not tracking"
            } else if isIdlePaused {
                return "Paused (idle)"
            } else if observerCount == 0 {
                return "No observers registered"
            } else if !activityManagerHealth.isHealthy {
                return "ActivityManager unhealthy"
            } else if !idleStatus.isHealthy {
                return "Idle detection unhealthy"
            } else {
                return "Tracking active"
            }
        }

        var contextCaptureStatus: String {
            var status: [String] = []
            
            if trackWindowTitles {
                if accessibilityEnabled {
                    status.append("Window titles: enabled")
                } else {
                    status.append("Window titles: disabled (no accessibility)")
                }
            } else {
                status.append("Window titles: disabled")
            }
            
            if captureBrowserData {
                status.append("Browser data: enabled")
                if respectPrivateBrowsing {
                    status.append("Private browsing: respected")
                } else {
                    status.append("Private browsing: ignored")
                }
            } else {
                status.append("Browser data: disabled")
            }
            
            status.append("Idle detection: \(idleStatus.statusDescription)")
            
            return status.joined(separator: ", ")
        }
    }

    /// Activity tracker specific errors
    enum ActivityTrackerError: LocalizedError {
        case notificationRegistrationFailed(Error)
        case trackingNotStarted
        case configurationError(String)
        case systemPermissionDenied

        var errorDescription: String? {
            switch self {
            case let .notificationRegistrationFailed(error):
                return "Failed to register notification observers: \(error.localizedDescription)"
            case .trackingNotStarted:
                return "Activity tracking has not been started"
            case let .configurationError(message):
                return "Configuration error: \(message)"
            case .systemPermissionDenied:
                return "System permissions required for activity tracking are not granted"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .notificationRegistrationFailed:
                return "Try restarting the application or check system permissions"
            case .trackingNotStarted:
                return "Call startTracking(modelContext:) before using tracking features"
            case .configurationError:
                return "Check the configuration parameters and try again"
            case .systemPermissionDenied:
                return "Grant the required permissions in System Preferences"
            }
        }
    }
}
