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
        
        IdleMonitor.shared.startMonitoring()

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

        // Auto assign project
        if let projectId = AutoAssignmentManager.shared.evaluate(activity: newActivity) {
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

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }

        let context = WindowMonitor.shared.getContext(for: app.processIdentifier)

        if let modelContext = modelContext {
            trackAppSwitch(newApp: bundleId, context: context, modelContext: modelContext)
        }
    }

    private func handleSystemSleep() async {
        if let modelContext = modelContext {
            stopTracking(modelContext: modelContext)
        }
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
