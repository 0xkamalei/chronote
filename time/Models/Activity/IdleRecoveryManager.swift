import SwiftUI
import SwiftData
import os.log

/// Manager for handling idle recovery dialogs and processing user responses
@MainActor
class IdleRecoveryManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = IdleRecoveryManager()
    
    // MARK: - Published Properties
    
    @Published var isShowingRecoveryDialog = false
    @Published var pendingIdleRecovery: PendingIdleRecovery?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.time-vscode.IdleRecoveryManager", category: "IdleRecovery")
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
        logger.info("IdleRecoveryManager initialized")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Set the model context for database operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        logger.debug("Model context set for idle recovery operations")
    }
    
    /// Handle idle state change notifications from IdleDetector
    func handleIdleStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isIdle = userInfo["isIdle"] as? Bool,
              let idleStartTime = userInfo["idleStartTime"] as? Date
        else {
            logger.error("Invalid idle state change notification")
            return
        }
        
        if !isIdle {
            // User returned from idle - show recovery dialog
            if let idleDuration = userInfo["idleDuration"] as? TimeInterval {
                showIdleRecoveryDialog(
                    idleStartTime: idleStartTime,
                    idleDuration: idleDuration
                )
            }
        } else {
            // User went idle - just log it
            logger.info("User went idle at \(idleStartTime)")
        }
    }
    
    /// Show the idle recovery dialog
    func showIdleRecoveryDialog(idleStartTime: Date, idleDuration: TimeInterval) {
        // Only show dialog for significant idle periods (more than 2 minutes)
        guard idleDuration >= 120 else {
            logger.debug("Skipping recovery dialog for short idle period: \(idleDuration)s")
            return
        }
        
        logger.info("Showing idle recovery dialog for \(idleDuration)s idle period")
        
        pendingIdleRecovery = PendingIdleRecovery(
            idleStartTime: idleStartTime,
            idleDuration: idleDuration
        )
        
        isShowingRecoveryDialog = true
    }
    
    /// Process the user's idle recovery action
    func processIdleRecoveryAction(_ action: IdleRecoveryAction) {
        guard let recovery = pendingIdleRecovery,
              let context = modelContext else {
            logger.error("Cannot process idle recovery - missing context or recovery data")
            return
        }
        
        logger.info("Processing idle recovery action: \(action)")
        
        Task {
            do {
                try await processAction(action, for: recovery, context: context)
                
                // Clear the pending recovery and hide dialog
                await MainActor.run {
                    pendingIdleRecovery = nil
                    isShowingRecoveryDialog = false
                }
                
                logger.info("Idle recovery action processed successfully")
                
            } catch {
                logger.error("Failed to process idle recovery action: \(error)")
                
                // Show error to user but still clear the dialog
                await MainActor.run {
                    pendingIdleRecovery = nil
                    isShowingRecoveryDialog = false
                }
            }
        }
    }
    
    /// Dismiss the idle recovery dialog without taking action
    func dismissIdleRecoveryDialog() {
        logger.info("Idle recovery dialog dismissed by user")
        pendingIdleRecovery = nil
        isShowingRecoveryDialog = false
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIdleStateChangeNotification(_:)),
            name: .idleStateChanged,
            object: nil
        )
        
        logger.debug("Notification observers set up")
    }
    
    @objc private func handleIdleStateChangeNotification(_ notification: Notification) {
        Task { @MainActor in
            handleIdleStateChange(notification)
        }
    }
    
    private func processAction(
        _ action: IdleRecoveryAction,
        for recovery: PendingIdleRecovery,
        context: ModelContext
    ) async throws {
        
        switch action {
        case .ignore:
            logger.info("Ignoring idle time - no action taken")
            
        case .assignToProject(let project, let activity):
            try await createTimeEntryForProject(
                project: project,
                activity: activity,
                recovery: recovery,
                context: context
            )
            
        case .createTimeEntry(let activity, let notes):
            try await createCustomTimeEntry(
                activity: activity,
                notes: notes,
                recovery: recovery,
                context: context
            )
            
        case .markAsBreak:
            try await createBreakTimeEntry(
                recovery: recovery,
                context: context
            )
        }
    }
    
    private func createTimeEntryForProject(
        project: Project?,
        activity: String?,
        recovery: PendingIdleRecovery,
        context: ModelContext
    ) async throws {
        
        guard let project = project else {
            throw IdleRecoveryError.missingProject
        }
        
        let timeEntry = TimeEntry(
            id: UUID().uuidString,
            startTime: recovery.idleStartTime,
            endTime: recovery.idleStartTime.addingTimeInterval(recovery.idleDuration),
            projectID: project.id,
            title: activity ?? "Idle time recovery",
            notes: "Recovered from idle time",
            isManual: true
        )
        
        context.insert(timeEntry)
        try context.save()
        
        logger.info("Created time entry for project '\(project.name)' with duration \(recovery.idleDuration)s")
    }
    
    private func createCustomTimeEntry(
        activity: String,
        notes: String?,
        recovery: PendingIdleRecovery,
        context: ModelContext
    ) async throws {
        
        let timeEntry = TimeEntry(
            id: UUID().uuidString,
            startTime: recovery.idleStartTime,
            endTime: recovery.idleStartTime.addingTimeInterval(recovery.idleDuration),
            projectID: nil,
            title: activity,
            notes: notes ?? "Recovered from idle time",
            isManual: true
        )
        
        context.insert(timeEntry)
        try context.save()
        
        logger.info("Created custom time entry '\(activity)' with duration \(recovery.idleDuration)s")
    }
    
    private func createBreakTimeEntry(
        recovery: PendingIdleRecovery,
        context: ModelContext
    ) async throws {
        
        let timeEntry = TimeEntry(
            id: UUID().uuidString,
            startTime: recovery.idleStartTime,
            endTime: recovery.idleStartTime.addingTimeInterval(recovery.idleDuration),
            projectID: nil,
            title: "Break",
            notes: "Break time recovered from idle period",
            isManual: true
        )
        
        context.insert(timeEntry)
        try context.save()
        
        logger.info("Created break time entry with duration \(recovery.idleDuration)s")
    }
    
    // MARK: - Supporting Types
    
    struct PendingIdleRecovery {
        let idleStartTime: Date
        let idleDuration: TimeInterval
        let detectedAt: Date = Date()
        
        var endTime: Date {
            return idleStartTime.addingTimeInterval(idleDuration)
        }
        
        var formattedDuration: String {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            return formatter.string(from: idleDuration) ?? "\(Int(idleDuration / 60)) min"
        }
        
        var formattedTimeRange: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: idleStartTime)) - \(formatter.string(from: endTime))"
        }
    }
    
    enum IdleRecoveryError: LocalizedError {
        case missingProject
        case missingActivity
        case databaseError(Error)
        case invalidTimeRange
        
        var errorDescription: String? {
            switch self {
            case .missingProject:
                return "No project selected for time entry"
            case .missingActivity:
                return "Activity description is required"
            case .databaseError(let error):
                return "Database error: \(error.localizedDescription)"
            case .invalidTimeRange:
                return "Invalid time range for idle recovery"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .missingProject:
                return "Please select a project for the time entry"
            case .missingActivity:
                return "Please provide an activity description"
            case .databaseError:
                return "Try again or restart the application"
            case .invalidTimeRange:
                return "Check the idle time range and try again"
            }
        }
    }
}