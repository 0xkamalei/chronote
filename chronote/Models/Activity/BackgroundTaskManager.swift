import AppKit
import Foundation
import os.log

@MainActor
class BackgroundTaskManager: ObservableObject {
    // MARK: - Singleton

    static let shared = BackgroundTaskManager()

    // MARK: - Private Properties

    private var backgroundTimer: Timer?
    private var isRunning = false
    private let logger = Logger(subsystem: "com.time-vscode.BackgroundTaskManager", category: "BackgroundTracking")
    private let checkInterval: TimeInterval = 5.0 // Check every 5 seconds

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start the background tracking task
    func startBackgroundTracking() {
        guard !isRunning else { return }

        isRunning = true
        logger.info("Starting background activity tracking")

        // Set up a timer that periodically checks if the frontmost app has changed
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndTrackAppActivity()
            }
        }
    }

    /// Stop the background tracking task
    func stopBackgroundTracking() {
        guard isRunning else { return }

        backgroundTimer?.invalidate()
        backgroundTimer = nil
        isRunning = false
        logger.info("Stopped background activity tracking")
    }

    // MARK: - Private Methods

    /// Periodically check the frontmost app and update tracking
    private func checkAndTrackAppActivity() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier else { return }

        // Notify ActivityManager to potentially update tracking
        // This ensures we continue tracking even when the app is in background
        NotificationCenter.default.post(
            name: NSNotification.Name("BackgroundAppCheckNotification"),
            object: nil,
            userInfo: [
                "bundleId": bundleId,
                "processIdentifier": app.processIdentifier
            ]
        )
    }
}
