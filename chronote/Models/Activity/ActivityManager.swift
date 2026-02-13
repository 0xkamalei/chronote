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
    private(set) var modelContext: ModelContext?  // Made accessible for checking initialization

    private let ignoredBundleIds: Set<String> = [
        "com.apple.loginwindow",
        // Universal Control / continuity control surfaces should not be tracked as work activity.
        "com.apple.universalcontrol",
        "com.apple.UniversalControl",
        "com.apple.universalcontrold"
    ]

    private let contextMonitor = ContextMonitor()

    private let logger = Logger(subsystem: "com.time-vscode.ActivityManager", category: "ActivityTracking")

    // MARK: - Initialization

    private init() {
        contextMonitor.delegate = self
    }

    // MARK: - Public Methods

    /// Start tracking app activity
    func startTracking(modelContext: ModelContext) {
        stopTracking(modelContext: modelContext)

        self.modelContext = modelContext

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
                await self?.handleSystemWake()
            }
        }
        notificationObservers.append(wakeObserver)

        // Idle Observers
        let idleObserver = notificationCenter.addObserver(
            forName: .userDidBecomeIdle,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleUserIdle(notification)
            }
        }
        notificationObservers.append(idleObserver)

        let activeObserver = notificationCenter.addObserver(
            forName: .userDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleUserActive(notification)
            }
        }
        notificationObservers.append(activeObserver)

        // Background app check observer
        let backgroundCheckObserver = notificationCenter.addObserver(
            forName: NSNotification.Name("BackgroundAppCheckNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleBackgroundAppCheck(notification)
            }
        }
        notificationObservers.append(backgroundCheckObserver)

        IdleMonitor.shared.startMonitoring()
        BackgroundTaskManager.shared.startBackgroundTracking()

        logger.info("Started tracking app activities")

        // Initial track of current app
        if let app = NSWorkspace.shared.frontmostApplication,
           let bundleId = app.bundleIdentifier {
            let context = WindowMonitor.shared.getContext(for: app.processIdentifier)
            // Initialize AutoAssignmentManager rules
            Task { @MainActor in
                AutoAssignmentManager.shared.reloadRules(modelContext: modelContext)
                trackAppSwitch(newApp: bundleId, context: context, modelContext: modelContext)
            }
        }
    }
    
    /// Stop tracking app activity
    func stopTracking(modelContext: ModelContext, endTime: Date = Date()) {
        IdleMonitor.shared.stopMonitoring()
        contextMonitor.stopMonitoring()
        BackgroundTaskManager.shared.stopBackgroundTracking()

        if let current = self.currentActivity {
            current.endTime = endTime
            current.duration = current.calculatedDuration

            if current.duration > 0 {
                do {
                    // Insert into context before saving (if not already managed)
                    if current.modelContext == nil {
                        modelContext.insert(current)
                    }
                    try modelContext.save()
                    logger.info("Saved current activity: \(current.appName)")
                } catch {
                    logger.error("Failed to save activity: \(error.localizedDescription)")
                }
            }

            self.currentActivity = nil
        }

        for observer in notificationObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        notificationObservers.removeAll()
        logger.info("Stopped tracking")
    }

    /// Track an app switch (or context switch)
    func trackAppSwitch(newApp: String, context: ActivityContext, startTime: Date = Date(), modelContext: ModelContext) {
        self.modelContext = modelContext

        // Save the previous activity
        if let current = self.currentActivity {
            current.endTime = startTime
            current.duration = current.calculatedDuration

            // Filter out short activities (noise) if this is a context switch within same app?
            // For now, we save everything as per requirement "duration > 0".
            // The 5s debounce in ContextMonitor handles the noise filtering.
            
            if current.duration > 0 {
                do {
                    // Insert into context before saving (if not already managed)
                    if current.modelContext == nil {
                        modelContext.insert(current)
                    }
                    try modelContext.save()
                    logger.info("Saved activity for: \(current.appName) | Title: \(current.appTitle ?? "nil") | URL: \(current.webUrl ?? "nil") | Duration: \(String(format: "%.1f", current.duration))s")
                } catch {
                    logger.error("Failed to save activity: \(error.localizedDescription)")
                }
            }
        }

        // Check if the new app is ignored
        if ignoredBundleIds.contains(newApp) {
            logger.info("Ignored app switch to: \(newApp)")
            self.currentActivity = nil
            contextMonitor.stopMonitoring()
            return
        }

        // Create a new activity for the new app
        var appName = newApp
        // Try to get the localized app name
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == newApp }) {
            appName = app.localizedName ?? newApp
            
            // Start monitoring the new PID
            contextMonitor.startMonitoring(pid: app.processIdentifier, initialContext: context)
        }

        let newActivity = Activity(
            appName: appName,
            appBundleId: newApp,
            appTitle: context.title,
            filePath: context.filePath,
            webUrl: context.webUrl,
            domain: extractDomain(from: context.webUrl),
            duration: 0,
            startTime: startTime,
            endTime: nil
        )

        // Priority 1: If there is a running manual event with a project, force-assign this activity to that project.
        if let runningEventProjectId = runningEventProjectId(modelContext: modelContext) {
            newActivity.projectId = runningEventProjectId
            logger.debug("Assigned activity '\(appName)' to running event project \(runningEventProjectId)")
        }
        // Priority 2: Fallback to rule-based auto assignment.
        else if let projectId = AutoAssignmentManager.shared.evaluate(activity: newActivity) {
            newActivity.projectId = projectId
            logger.debug("Auto-assigned activity '\(appName)' to project \(projectId)")
        }

        self.currentActivity = newActivity
        if let title = context.title {
            logger.info("Started tracking: \(appName) - \(title)")
        } else {
            logger.info("Started tracking: \(appName)")
        }
    }

    // MARK: - Private Methods

    private func extractDomain(from urlString: String?) -> String? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        return url.host
    }

    /// Returns the projectId of the currently running event (endTime == nil), if any.
    private func runningEventProjectId(modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor).first?.projectId
        } catch {
            logger.error("Failed to fetch running event for activity assignment: \(error.localizedDescription)")
            return nil
        }
    }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }

        let context = WindowMonitor.shared.getContext(for: app.processIdentifier)

        if let modelContext = modelContext {
            trackAppSwitch(newApp: bundleId, context: context, modelContext: modelContext)
        }
    }

    private func handleSystemSleep() async {
        logger.info("System going to sleep, saving current activity")

        // Save current activity but keep observers alive
        if let modelContext = modelContext, let current = self.currentActivity {
            current.endTime = Date()
            current.duration = current.calculatedDuration

            if current.duration > 0 {
                do {
                    if current.modelContext == nil {
                        modelContext.insert(current)
                    }
                    try modelContext.save()
                    logger.info("Saved activity before sleep: \(current.appName)")
                } catch {
                    logger.error("Failed to save activity before sleep: \(error.localizedDescription)")
                }
            }
            self.currentActivity = nil
        }

        // Stop context monitoring and background tasks temporarily
        contextMonitor.stopMonitoring()
        BackgroundTaskManager.shared.stopBackgroundTracking()
    }

    private func handleSystemWake() async {
        logger.info("System woke up, resuming tracking")

        // Add a small delay to ensure system is fully ready after wake
        // NSWorkspace.frontmostApplication may not be available immediately after wake
        try? await Task.sleep(for: .milliseconds(500))

        // Resume tracking with current frontmost app
        if let app = NSWorkspace.shared.frontmostApplication,
           let bundleId = app.bundleIdentifier,
           let modelContext = modelContext {

            let context = WindowMonitor.shared.getContext(for: app.processIdentifier)
            trackAppSwitch(newApp: bundleId, context: context, modelContext: modelContext)
            logger.info("Resumed tracking after wake: \(app.localizedName ?? bundleId)")
        } else {
            logger.warning("Could not resume tracking after wake: no frontmost app or modelContext")
        }

        // Restart background tasks
        BackgroundTaskManager.shared.startBackgroundTracking()
    }

    private func handleUserIdle(_ notification: Notification) {
        guard let idleStartTime = notification.userInfo?["idleStartTime"] as? Date else { return }
        logger.info("Handling user idle (start: \(idleStartTime))")
        
        if let modelContext = modelContext {
            // Stop tracking, setting end time to when idle started
            // But don't remove observers, just stop current activity
            if let current = self.currentActivity {
                current.endTime = idleStartTime
                current.duration = current.calculatedDuration
                
                if current.duration > 0 {
                    do {
                        // Insert into context before saving (if not already managed)
                        if current.modelContext == nil {
                            modelContext.insert(current)
                        }
                        try modelContext.save()
                        logger.info("Saved activity before idle: \(current.appName)")
                    } catch {
                        logger.error("Failed to save activity: \(error)")
                    }
                }
                self.currentActivity = nil
            }
            // Note: We don't stop ContextMonitor here explicitly, but since currentActivity is nil,
            // we effectively stop recording.
            // Ideally we should pause ContextMonitor or ignore its callbacks when idle.
        }
    }

    private func handleUserActive(_ notification: Notification) {
        logger.info("Handling user active")

        // Resume tracking frontmost app
        if let app = NSWorkspace.shared.frontmostApplication,
           let bundleId = app.bundleIdentifier,
           let modelContext = modelContext {

            let context = WindowMonitor.shared.getContext(for: app.processIdentifier)
            trackAppSwitch(newApp: bundleId, context: context, modelContext: modelContext)
        }
    }

    private func handleBackgroundAppCheck(_ notification: Notification) {
        guard let bundleId = notification.userInfo?["bundleId"] as? String,
              let processId = notification.userInfo?["processIdentifier"] as? Int32,
              let modelContext = modelContext else { return }

        // Check if the frontmost app has changed
        if let currentActivity = self.currentActivity, currentActivity.appBundleId == bundleId {
            // App hasn't changed, but we still check for context changes (e.g., browser tabs)
            return
        }

        // App has changed, track the new app
        let context = WindowMonitor.shared.getContext(for: processId)
        trackAppSwitch(newApp: bundleId, context: context, modelContext: modelContext)
    }
}

// MARK: - ContextMonitorDelegate
extension ActivityManager: ContextMonitorDelegate {
    nonisolated func didDetectContextChange(context: ActivityContext, startTime: Date) {
        Task { @MainActor in
            guard let modelContext = self.modelContext,
                  let current = self.currentActivity else { return }
            
            // Reuse trackAppSwitch with retroactive time
            self.trackAppSwitch(
                newApp: current.appBundleId,
                context: context,
                startTime: startTime,
                modelContext: modelContext
            )
        }
    }
}

// MARK: - Public Helper Methods

extension ActivityManager {
    /// Get the current activity being tracked
    func getCurrentActivity() -> Activity? {
        return currentActivity
    }
}
