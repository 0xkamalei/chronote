import AppKit
import Foundation
import os.log

/// Idle detection system that monitors user activity and manages idle states
/// Integrates with ActivityTracker to pause tracking during idle periods
@MainActor
class IdleDetector: ObservableObject {
    // MARK: - Singleton

    static let shared = IdleDetector()

    // MARK: - Published Properties

    @Published var isIdle: Bool = false
    @Published var idleStartTime: Date?
    @Published var lastActivityTime: Date = .init()
    @Published var isMonitoring: Bool = false

    // MARK: - Private Properties

    private var eventTap: CFMachPort?
    private var idleTimer: Timer?
    private var runLoopSource: CFRunLoopSource?

    private let logger = Logger(subsystem: "com.time-vscode.IdleDetector", category: "IdleDetection")

    // Configuration
    private var idleThreshold: TimeInterval = 300 // 5 minutes default
    private var isIdleDetectionEnabled: Bool = true
    private var checkInterval: TimeInterval = 30 // Check every 30 seconds

    // MARK: - Initialization

    private init() {
        logger.info("IdleDetector initialized with \(self.idleThreshold)s threshold")
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopMonitoring()
        }
    }

    // MARK: - Public Methods

    /// Start monitoring system events for idle detection
    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("IdleDetector is already monitoring")
            return
        }

        guard isIdleDetectionEnabled else {
            logger.info("Idle detection is disabled")
            return
        }

        // Request accessibility permissions if needed
        guard checkAccessibilityPermissions() else {
            logger.error("Accessibility permissions required for idle detection")
            return
        }

        setupEventTap()
        setupIdleTimer()

        isMonitoring = true
        lastActivityTime = Date()

        logger.info("IdleDetector started monitoring with \(self.idleThreshold)s threshold")
    }

    /// Stop monitoring system events
    func stopMonitoring() {
        guard isMonitoring else {
            logger.debug("IdleDetector is not currently monitoring")
            return
        }

        cleanupEventTap()
        cleanupIdleTimer()

        isMonitoring = false
        isIdle = false
        idleStartTime = nil

        logger.info("IdleDetector stopped monitoring")
    }

    /// Reset the idle timer (called when user activity is detected)
    func resetIdleTimer() {
        lastActivityTime = Date()

        if isIdle {
            logger.info("User returned from idle state")
            handleReturnFromIdle()
        }
    }

    /// Get current idle detection status
    func getIdleStatus() -> IdleStatus {
        let currentIdleDuration = isIdle ? Date().timeIntervalSince(idleStartTime ?? Date()) : 0
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)

        return IdleStatus(
            isMonitoring: isMonitoring,
            isIdle: isIdle,
            isEnabled: isIdleDetectionEnabled,
            idleThreshold: idleThreshold,
            currentIdleDuration: currentIdleDuration,
            timeSinceLastActivity: timeSinceLastActivity,
            idleStartTime: idleStartTime,
            lastActivityTime: lastActivityTime,
            hasAccessibilityPermissions: checkAccessibilityPermissions()
        )
    }

    /// Update idle detection configuration
    func updateConfiguration(
        isEnabled: Bool? = nil,
        threshold: TimeInterval? = nil,
        checkInterval: TimeInterval? = nil
    ) {
        var configChanged = false

        if let enabled = isEnabled, enabled != isIdleDetectionEnabled {
            isIdleDetectionEnabled = enabled
            configChanged = true
            logger.info("Idle detection enabled changed to: \(enabled)")
        }

        if let threshold = threshold, threshold != idleThreshold {
            idleThreshold = max(60, threshold) // Minimum 1 minute
            configChanged = true
            logger.info("Idle threshold changed to: \(threshold)s")
        }

        if let interval = checkInterval, interval != self.checkInterval {
            self.checkInterval = max(10, interval) // Minimum 10 seconds
            configChanged = true
            logger.info("Check interval changed to: \(interval)s")
        }

        if configChanged, isMonitoring {
            logger.info("Restarting idle detection to apply configuration changes")
            stopMonitoring()
            startMonitoring()
        }
    }

    // MARK: - Private Methods - Event Tap Setup

    /// Set up CGEventTap for monitoring mouse and keyboard events
    private func setupEventTap() {
        // Define the events we want to monitor
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        // Create the event tap
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                // Get the IdleDetector instance
                let detector = Unmanaged<IdleDetector>.fromOpaque(refcon!).takeUnretainedValue()

                // Reset idle timer on any user activity
                Task { @MainActor in
                    detector.resetIdleTimer()
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            logger.error("Failed to create event tap for idle detection")
            return
        }

        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            logger.error("Failed to create run loop source for event tap")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        logger.debug("Event tap configured successfully")
    }

    /// Clean up event tap resources
    private func cleanupEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        logger.debug("Event tap cleaned up")
    }

    // MARK: - Private Methods - Idle Timer

    /// Set up timer for periodic idle checking
    private func setupIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForIdleState()
            }
        }

        logger.debug("Idle timer configured with \(self.checkInterval)s interval")
    }

    /// Clean up idle timer
    private func cleanupIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
        logger.debug("Idle timer cleaned up")
    }

    /// Check if the system should be considered idle
    private func checkForIdleState() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)

        if !isIdle, timeSinceLastActivity >= idleThreshold {
            logger.info("Idle state detected after \(timeSinceLastActivity)s of inactivity")
            handleIdleDetected()
        }
    }

    /// Handle when idle state is detected
    private func handleIdleDetected() {
        isIdle = true
        idleStartTime = Date().addingTimeInterval(-idleThreshold) // Backdate to when idle actually started

        // Notify ActivityTracker to pause tracking
        NotificationCenter.default.post(
            name: .idleStateChanged,
            object: self,
            userInfo: [
                "isIdle": true,
                "idleStartTime": idleStartTime!,
                "idleDuration": idleThreshold,
            ]
        )

        logger.info("Idle state activated, notifications sent")
    }

    /// Handle when user returns from idle state
    private func handleReturnFromIdle() {
        guard let idleStart = idleStartTime else {
            logger.warning("Return from idle called but no idle start time recorded")
            return
        }

        let idleDuration = Date().timeIntervalSince(idleStart)

        isIdle = false
        let previousIdleStartTime = idleStartTime
        idleStartTime = nil

        // Notify ActivityTracker to resume tracking
        NotificationCenter.default.post(
            name: .idleStateChanged,
            object: self,
            userInfo: [
                "isIdle": false,
                "idleStartTime": previousIdleStartTime!,
                "idleDuration": idleDuration,
                "returnTime": Date(),
            ]
        )

        logger.info("Returned from idle state after \(idleDuration)s")
    }

    // MARK: - Private Methods - Permissions

    /// Check if accessibility permissions are granted
    private func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Request accessibility permissions from the user
    func requestAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Supporting Types

    /// Comprehensive idle detection status information
    struct IdleStatus {
        let isMonitoring: Bool
        let isIdle: Bool
        let isEnabled: Bool
        let idleThreshold: TimeInterval
        let currentIdleDuration: TimeInterval
        let timeSinceLastActivity: TimeInterval
        let idleStartTime: Date?
        let lastActivityTime: Date
        let hasAccessibilityPermissions: Bool

        var isHealthy: Bool {
            return isEnabled && hasAccessibilityPermissions && (isMonitoring || !isEnabled)
        }

        var statusDescription: String {
            if !isEnabled {
                return "Idle detection disabled"
            } else if !hasAccessibilityPermissions {
                return "Missing accessibility permissions"
            } else if !isMonitoring {
                return "Not monitoring"
            } else if isIdle {
                return "Currently idle (\(Int(currentIdleDuration))s)"
            } else {
                return "Active (\(Int(timeSinceLastActivity))s since last activity)"
            }
        }
    }

    /// Idle detection specific errors
    enum IdleDetectionError: LocalizedError {
        case accessibilityPermissionDenied
        case eventTapCreationFailed
        case configurationError(String)
        case systemResourceUnavailable

        var errorDescription: String? {
            switch self {
            case .accessibilityPermissionDenied:
                return "Accessibility permissions are required for idle detection"
            case .eventTapCreationFailed:
                return "Failed to create system event tap for idle detection"
            case let .configurationError(message):
                return "Idle detection configuration error: \(message)"
            case .systemResourceUnavailable:
                return "System resources required for idle detection are not available"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .accessibilityPermissionDenied:
                return "Grant accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility"
            case .eventTapCreationFailed:
                return "Try restarting the application or check system permissions"
            case .configurationError:
                return "Check the idle detection configuration and try again"
            case .systemResourceUnavailable:
                return "Close other applications that might be using system resources and try again"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let idleStateChanged = Notification.Name("IdleStateChanged")
}
