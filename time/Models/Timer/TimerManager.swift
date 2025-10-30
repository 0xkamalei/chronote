import Foundation
import SwiftData
import SwiftUI
import UserNotifications
import AppKit
import os

@MainActor
class TimerManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var activeSession: TimerSession?
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var formattedElapsedTime: String = "0:00"
    
    // MARK: - Configuration Properties
    
    @Published var defaultEstimatedDuration: TimeInterval = 2 * 60 * 60 // 2 hours
    @Published var enableNotifications: Bool = true
    @Published var enableSounds: Bool = true
    @Published var autoCreateTimeEntry: Bool = true
    @Published var notificationInterval: TimeInterval = 30 * 60 // 30 minutes
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var modelContext: ModelContext?
    private var notificationManager: NotificationManager?
    private let logger = Logger(subsystem: "com.timetracking.app", category: "TimerManager")
    
    // MARK: - Persistence Keys
    
    private enum UserDefaultsKeys {
        static let activeSessionId = "TimerManager.activeSessionId"
        static let isRunning = "TimerManager.isRunning"
        static let isPaused = "TimerManager.isPaused"
        static let sessionStartTime = "TimerManager.sessionStartTime"
        static let pausedElapsedTime = "TimerManager.pausedElapsedTime"
        static let defaultEstimatedDuration = "TimerManager.defaultEstimatedDuration"
        static let enableNotifications = "TimerManager.enableNotifications"
        static let enableSounds = "TimerManager.enableSounds"
        static let autoCreateTimeEntry = "TimerManager.autoCreateTimeEntry"
        static let notificationInterval = "TimerManager.notificationInterval"
    }
    
    // MARK: - Initialization
    
    init() {
        loadConfiguration()
        setupNotificationObservers()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration Management
    
    /// Sets the model context for data persistence
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        restoreActiveSession()
    }
    
    /// Sets the notification manager for timer notifications
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
    }
    
    /// Loads configuration from UserDefaults
    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        
        defaultEstimatedDuration = defaults.object(forKey: UserDefaultsKeys.defaultEstimatedDuration) as? TimeInterval ?? (2 * 60 * 60)
        enableNotifications = defaults.object(forKey: UserDefaultsKeys.enableNotifications) as? Bool ?? true
        enableSounds = defaults.object(forKey: UserDefaultsKeys.enableSounds) as? Bool ?? true
        autoCreateTimeEntry = defaults.object(forKey: UserDefaultsKeys.autoCreateTimeEntry) as? Bool ?? true
        notificationInterval = defaults.object(forKey: UserDefaultsKeys.notificationInterval) as? TimeInterval ?? (30 * 60)
    }
    
    /// Saves configuration to UserDefaults
    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        
        defaults.set(defaultEstimatedDuration, forKey: UserDefaultsKeys.defaultEstimatedDuration)
        defaults.set(enableNotifications, forKey: UserDefaultsKeys.enableNotifications)
        defaults.set(enableSounds, forKey: UserDefaultsKeys.enableSounds)
        defaults.set(autoCreateTimeEntry, forKey: UserDefaultsKeys.autoCreateTimeEntry)
        defaults.set(notificationInterval, forKey: UserDefaultsKeys.notificationInterval)
    }
    
    // MARK: - Timer Management
    
    /// Starts a new timer session
    func startTimer(project: Project? = nil, title: String? = nil, notes: String? = nil, estimatedDuration: TimeInterval? = nil) throws {
        guard activeSession == nil else {
            throw TimerManagerError.sessionAlreadyActive
        }
        
        guard let modelContext = modelContext else {
            throw TimerManagerError.noModelContext
        }
        
        // Create new timer session
        let session = TimerSession(
            projectId: project?.id,
            title: title,
            notes: notes,
            estimatedDuration: estimatedDuration ?? defaultEstimatedDuration
        )
        
        // Validate session
        if case .failure(let error) = session.validate() {
            throw TimerManagerError.validationFailed(error.localizedDescription)
        }
        
        // Save to database
        modelContext.insert(session)
        
        do {
            try modelContext.save()
        } catch {
            throw TimerManagerError.persistenceFailure(error.localizedDescription)
        }
        
        // Update state
        activeSession = session
        isRunning = true
        isPaused = false
        elapsedTime = 0
        
        // Start timer
        startInternalTimer()
        
        // Save state for crash recovery
        saveTimerState()
        
        // Schedule notifications
        scheduleNotifications()
        
        // Post notification
        NotificationCenter.default.post(
            name: .timerDidStart,
            object: self,
            userInfo: [
                "sessionId": session.id.uuidString,
                "projectId": project?.id as Any,
                "title": title as Any,
                "estimatedDuration": estimatedDuration as Any
            ]
        )
        
        logger.info("Timer started: \(session.id.uuidString)")
    }
    
    /// Stops the active timer session
    func stopTimer(createTimeEntry: Bool? = nil) async throws {
        guard let session = activeSession else {
            throw TimerManagerError.noActiveSession
        }
        
        guard let modelContext = modelContext else {
            throw TimerManagerError.noModelContext
        }
        
        // Stop internal timer
        stopInternalTimer()
        
        // Complete the session
        session.complete()
        
        // Update state
        let completedSession = session
        activeSession = nil
        isRunning = false
        isPaused = false
        elapsedTime = 0
        formattedElapsedTime = "0:00"
        
        // Save to database
        do {
            try modelContext.save()
        } catch {
            throw TimerManagerError.persistenceFailure(error.localizedDescription)
        }
        
        // Clear saved state
        clearTimerState()
        
        // Cancel notifications
        cancelNotifications()
        
        // Create time entry if requested
        let shouldCreateTimeEntry = createTimeEntry ?? autoCreateTimeEntry
        var createdTimeEntry: TimeEntry?
        
        if shouldCreateTimeEntry {
            do {
                // Get project from ProjectManager if needed
                var project: Project?
                if let projectId = completedSession.projectId {
                    project = ProjectManager.shared.getProject(by: projectId)
                }
                
                createdTimeEntry = try await TimeEntryManager.shared.createFromTimer(
                    project: project,
                    startTime: completedSession.startTime,
                    endTime: completedSession.endTime ?? Date(),
                    title: completedSession.title,
                    notes: completedSession.notes
                )
                
                logger.info("Created time entry from timer session: \(createdTimeEntry?.id.uuidString ?? "unknown")")
            } catch {
                logger.error("Failed to create time entry from timer: \(error.localizedDescription)")
            }
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .timerDidStop,
            object: self,
            userInfo: [
                "sessionId": completedSession.id.uuidString,
                "duration": completedSession.actualDuration as Any,
                "timeEntryCreated": shouldCreateTimeEntry,
                "timeEntryId": createdTimeEntry?.id.uuidString as Any
            ]
        )
        
        logger.info("Timer stopped: \(completedSession.id.uuidString), duration: \(completedSession.actualDuration ?? 0)s")
    }
    
    /// Pauses the active timer
    func pauseTimer() throws {
        guard let session = activeSession else {
            throw TimerManagerError.noActiveSession
        }
        
        guard isRunning && !isPaused else {
            throw TimerManagerError.timerNotRunning
        }
        
        // Stop internal timer
        stopInternalTimer()
        
        // Update state
        isPaused = true
        
        // Save state
        saveTimerState()
        
        // Cancel notifications
        cancelNotifications()
        
        // Post notification
        NotificationCenter.default.post(
            name: .timerDidPause,
            object: self,
            userInfo: [
                "sessionId": session.id.uuidString,
                "elapsedTime": elapsedTime
            ]
        )
        
        logger.info("Timer paused: \(session.id.uuidString)")
    }
    
    /// Resumes the paused timer
    func resumeTimer() throws {
        guard let session = activeSession else {
            throw TimerManagerError.noActiveSession
        }
        
        guard isRunning && isPaused else {
            throw TimerManagerError.timerNotPaused
        }
        
        // Update state
        isPaused = false
        
        // Start internal timer
        startInternalTimer()
        
        // Save state
        saveTimerState()
        
        // Schedule notifications
        scheduleNotifications()
        
        // Post notification
        NotificationCenter.default.post(
            name: .timerDidResume,
            object: self,
            userInfo: [
                "sessionId": session.id.uuidString,
                "elapsedTime": elapsedTime
            ]
        )
        
        logger.info("Timer resumed: \(session.id.uuidString)")
    }
    
    // MARK: - Internal Timer Management
    
    /// Starts the internal timer for UI updates
    private func startInternalTimer() {
        stopInternalTimer() // Ensure no duplicate timers
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }
    
    /// Stops the internal timer
    private func stopInternalTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Updates the elapsed time and formatted string
    private func updateElapsedTime() {
        guard let session = activeSession, isRunning && !isPaused else { return }
        
        elapsedTime = session.elapsedTime
        formattedElapsedTime = formatDuration(elapsedTime)
        
        // Check if estimated duration is exceeded
        if let estimatedDuration = session.estimatedDuration,
           elapsedTime >= estimatedDuration,
           enableNotifications {
            // This will be handled by scheduled notifications
        }
    }
    
    // MARK: - Persistence and Recovery
    
    /// Saves timer state for crash recovery
    private func saveTimerState() {
        let defaults = UserDefaults.standard
        
        if let session = activeSession {
            defaults.set(session.id.uuidString, forKey: UserDefaultsKeys.activeSessionId)
            defaults.set(isRunning, forKey: UserDefaultsKeys.isRunning)
            defaults.set(isPaused, forKey: UserDefaultsKeys.isPaused)
            defaults.set(session.startTime, forKey: UserDefaultsKeys.sessionStartTime)
            defaults.set(elapsedTime, forKey: UserDefaultsKeys.pausedElapsedTime)
        } else {
            clearTimerState()
        }
    }
    
    /// Clears saved timer state
    private func clearTimerState() {
        let defaults = UserDefaults.standard
        
        defaults.removeObject(forKey: UserDefaultsKeys.activeSessionId)
        defaults.removeObject(forKey: UserDefaultsKeys.isRunning)
        defaults.removeObject(forKey: UserDefaultsKeys.isPaused)
        defaults.removeObject(forKey: UserDefaultsKeys.sessionStartTime)
        defaults.removeObject(forKey: UserDefaultsKeys.pausedElapsedTime)
    }
    
    /// Restores active session from saved state
    private func restoreActiveSession() {
        guard let modelContext = modelContext else { return }
        
        let defaults = UserDefaults.standard
        
        guard let sessionIdString = defaults.string(forKey: UserDefaultsKeys.activeSessionId),
              let sessionId = UUID(uuidString: sessionIdString) else {
            return
        }
        
        // Find the session in the database
        let descriptor = FetchDescriptor<TimerSession>(
            predicate: #Predicate<TimerSession> { session in
                session.id == sessionId && session.isActive
            }
        )
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            guard let session = sessions.first else {
                clearTimerState()
                return
            }
            
            // Restore state
            activeSession = session
            isRunning = defaults.bool(forKey: UserDefaultsKeys.isRunning)
            isPaused = defaults.bool(forKey: UserDefaultsKeys.isPaused)
            
            if isRunning && !isPaused {
                // Resume timer
                startInternalTimer()
                scheduleNotifications()
            }
            
            logger.info("Restored timer session: \(session.id.uuidString)")
            
        } catch {
            logger.error("Failed to restore timer session: \(error.localizedDescription)")
            clearTimerState()
        }
    }
    
    // MARK: - Notification Management
    
    /// Schedules notifications for the active timer
    private func scheduleNotifications() {
        guard enableNotifications,
              let session = activeSession,
              let estimatedDuration = session.estimatedDuration,
              let notificationManager = notificationManager else {
            return
        }
        
        // Schedule completion notification
        let completionTime = session.startTime.addingTimeInterval(estimatedDuration)
        notificationManager.scheduleTimerCompletionNotification(
            at: completionTime,
            sessionId: session.id.uuidString,
            title: session.title,
            playSound: enableSounds
        )
        
        // Schedule interval notifications if configured
        if notificationInterval > 0 && notificationInterval < estimatedDuration {
            let intervalCount = Int(estimatedDuration / notificationInterval)
            for i in 1...intervalCount {
                let intervalTime = session.startTime.addingTimeInterval(TimeInterval(i) * notificationInterval)
                if intervalTime < completionTime {
                    notificationManager.scheduleTimerIntervalNotification(
                        at: intervalTime,
                        sessionId: session.id.uuidString,
                        interval: i,
                        playSound: false
                    )
                }
            }
        }
    }
    
    /// Cancels all scheduled notifications for the active timer
    private func cancelNotifications() {
        guard let session = activeSession,
              let notificationManager = notificationManager else {
            return
        }
        
        notificationManager.cancelTimerNotifications(sessionId: session.id.uuidString)
    }
    
    // MARK: - Utility Methods
    
    /// Formats a duration in seconds to a human-readable string
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Gets the current timer progress (0.0 to 1.0+)
    func getCurrentProgress() -> Double {
        guard let session = activeSession else { return 0.0 }
        return session.progress
    }
    
    /// Checks if the timer has exceeded its estimated duration
    func hasExceededEstimate() -> Bool {
        guard let session = activeSession else { return false }
        return session.hasExceededEstimate
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidHide),
            name: NSApplication.didHideNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidUnhide),
            name: NSApplication.didUnhideNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillTerminate() {
        saveTimerState()
        saveConfiguration()
    }
    
    @objc private func handleAppDidHide() {
        saveTimerState()
    }
    
    @objc private func handleAppDidUnhide() {
        // Refresh elapsed time in case the app was hidden for a while
        updateElapsedTime()
    }
}

// MARK: - Error Types

enum TimerManagerError: LocalizedError {
    case sessionAlreadyActive
    case noActiveSession
    case noModelContext
    case timerNotRunning
    case timerNotPaused
    case validationFailed(String)
    case persistenceFailure(String)
    case notificationPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "A timer session is already active"
        case .noActiveSession:
            return "No active timer session"
        case .noModelContext:
            return "Model context not available"
        case .timerNotRunning:
            return "Timer is not running"
        case .timerNotPaused:
            return "Timer is not paused"
        case let .validationFailed(message):
            return "Validation failed: \(message)"
        case let .persistenceFailure(message):
            return "Persistence failure: \(message)"
        case .notificationPermissionDenied:
            return "Notification permission denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Stop the current timer before starting a new one."
        case .noActiveSession:
            return "Start a timer session first."
        case .noModelContext:
            return "Ensure the app is properly initialized."
        case .timerNotRunning:
            return "Start the timer first."
        case .timerNotPaused:
            return "Pause the timer first."
        case .validationFailed:
            return "Check the timer session data and try again."
        case .persistenceFailure:
            return "Check storage permissions and try again."
        case .notificationPermissionDenied:
            return "Enable notifications in system settings."
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let timerDidStart = Notification.Name("timerDidStart")
    static let timerDidStop = Notification.Name("timerDidStop")
    static let timerDidPause = Notification.Name("timerDidPause")
    static let timerDidResume = Notification.Name("timerDidResume")
}