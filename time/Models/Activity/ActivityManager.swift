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

    private let logger = Logger(subsystem: "com.time-vscode.ActivityManager", category: "ActivityTracking")

    // MARK: - Initialization

    private init() {}

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

        logger.info("Started tracking app activities")
    }

    /// Stop tracking app activity
    func stopTracking(modelContext: ModelContext) {
        if let current = self.currentActivity {
            current.endTime = Date()
            current.duration = current.calculatedDuration

            if current.duration > 0 {
                do {
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

    /// Track an app switch
    func trackAppSwitch(newApp: String, modelContext: ModelContext) {
        self.modelContext = modelContext

        // Save the previous activity
        if let current = self.currentActivity {
            current.endTime = Date()
            current.duration = current.calculatedDuration

            if current.duration > 0 {
                do {
                    try modelContext.save()
                    logger.info("Saved activity for: \(current.appName)")
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
        }

        let now = Date()
        let newActivity = Activity(
            appName: appName,
            appBundleId: newApp,
            duration: 0,
            startTime: now,
            endTime: nil
        )

        self.currentActivity = newActivity
        logger.info("Started tracking: \(appName)")
    }

    // MARK: - Private Methods

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }

        if let modelContext = modelContext {
            trackAppSwitch(newApp: bundleId, modelContext: modelContext)
        }
    }

    private func handleSystemSleep() async {
        if let modelContext = modelContext {
            stopTracking(modelContext: modelContext)
        }
    }
}

// MARK: - Public Helper Methods

extension ActivityManager {
    /// Set notification manager (for integration with AppState)
    func setNotificationManager(_ manager: NotificationManager) {
        // No-op for MVP version
    }

    /// Get the current activity being tracked
    func getCurrentActivity() -> Activity? {
        return currentActivity
    }
}
