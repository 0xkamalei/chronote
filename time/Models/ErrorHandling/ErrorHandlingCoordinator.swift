import Foundation
import SwiftUI
import os.log

// MARK: - Error Handling Coordinator

@MainActor
class ErrorHandlingCoordinator: ObservableObject {
    static let shared = ErrorHandlingCoordinator()
    
    // Component references
    private let logger = ErrorLogger.shared
    private let presenter = ErrorPresenter.shared
    private let recoveryManager = ErrorRecoveryManager.shared
    private let dataRecovery = DataRecoveryManager.shared
    private let integrityChecker = DataIntegrityChecker.shared
    private let degradationManager = GracefulDegradationManager.shared
    
    @Published var isInitialized = false
    @Published var systemStatus: SystemStatus = .initializing
    @Published var criticalErrorsCount: Int = 0
    @Published var lastHealthCheck: Date?
    
    private let systemLogger = Logger(subsystem: "com.timetracking.app", category: "ErrorHandlingCoordinator")
    
    private init() {
        setupErrorHandling()
    }
    
    // MARK: - Initialization
    
    func initialize() async {
        systemLogger.info("Initializing error handling system")
        systemStatus = .initializing
        
        do {
            // Perform startup health checks
            await performStartupHealthCheck()
            
            // Initialize monitoring
            setupErrorHandling()
            
            // Setup crash recovery
            await performCrashRecovery()
            
            // Initialize graceful degradation
            await initializeGracefulDegradation()
            
            systemStatus = .healthy
            isInitialized = true
            
            systemLogger.info("Error handling system initialized successfully")
            
        } catch {
            systemLogger.error("Failed to initialize error handling system: \(error)")
            systemStatus = .degraded
            
            // Even if initialization fails, mark as initialized to allow basic functionality
            isInitialized = true
            
            // Present initialization error to user
            await handleError(
                TimeTrackingError.systemConfigurationInvalid,
                context: ErrorContext(
                    userAction: "System initialization",
                    additionalInfo: ["initialization_error": error.localizedDescription]
                )
            )
        }
    }
    
    private func setupErrorHandling() {
        // Set up global error handlers
        setupUncaughtExceptionHandler()
        setupSignalHandlers()
        setupNotificationObservers()
    }
    
    private func setupUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                await ErrorHandlingCoordinator.shared.handleException(exception)
            }
        }
    }
    
    private func setupSignalHandlers() {
        // Handle various crash signals
        let signals = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS]
        
        for signal in signals {
            Darwin.signal(signal) { signalNumber in
                Task { @MainActor in
                    await ErrorHandlingCoordinator.shared.handleSignal(signalNumber)
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Observe system notifications
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await self.handleMemoryWarning()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .operationModeChanged,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                await self.handleOperationModeChange(notification)
            }
        }
    }
    
    // MARK: - Error Handling Entry Points
    
    func handleError(
        _ error: TimeTrackingError,
        context: ErrorContext,
        presentationStyle: ErrorPresentationStyle = .automatic,
        attemptRecovery: Bool = true
    ) async {
        systemLogger.info("Handling error: \(error.localizedDescription)")
        
        // Update critical error count
        if error.severity == .critical {
            criticalErrorsCount += 1
        }
        
        // Log the error
        logger.logError(error, context: context)
        
        // Check if we need to degrade system functionality
        await evaluateSystemDegradation(for: error)
        
        // Attempt automatic recovery if enabled
        if attemptRecovery && shouldAttemptRecovery(for: error) {
            let recoveryResult = await attemptAutomaticRecovery(error: error, context: context)
            
            if recoveryResult.isSuccess {
                systemLogger.info("Automatic recovery successful for error: \(error)")
                return // Don't present error if recovery was successful
            }
        }
        
        // Present error to user
        presenter.presentError(error, context: context, presentationStyle: presentationStyle)
        
        // Update system status
        updateSystemStatus(for: error)
    }
    
    func handleException(_ exception: NSException) async {
        systemLogger.fault("Uncaught exception: \(exception.name.rawValue)")
        
        let error = TimeTrackingError.systemResourceExhausted
        let context = ErrorContext(
            userAction: "System exception occurred",
            systemState: ["exception_name": exception.name.rawValue],
            stackTrace: exception.callStackSymbols.joined(separator: "\n"),
            additionalInfo: [
                "reason": exception.reason ?? "Unknown",
                "user_info": exception.userInfo ?? [:]
            ]
        )
        
        // Log exception
        logger.logException(exception, context: context)
        
        // Force emergency mode
        degradationManager.forceMode(.emergencyMode, reason: "Uncaught exception: \(exception.name.rawValue)")
        
        // Create emergency backup
        let _ = await dataRecovery.createBackup(type: .emergency)
        
        // Present critical error
        await handleError(error, context: context, presentationStyle: .alert, attemptRecovery: false)
    }
    
    func handleSignal(_ signal: Int32) async {
        systemLogger.fault("Signal received: \(signal)")
        
        let signalName = getSignalName(signal)
        let error = TimeTrackingError.systemResourceExhausted
        let context = ErrorContext(
            userAction: "System signal received",
            additionalInfo: [
                "signal": signal,
                "signal_name": signalName,
                "timestamp": Date()
            ]
        )
        
        // Log crash
        logger.logCrash(crashInfo: [
            "signal": signal,
            "signal_name": signalName,
            "timestamp": Date()
        ])
        
        // Force emergency mode
        degradationManager.forceMode(.emergencyMode, reason: "System signal: \(signalName)")
        
        // Create emergency backup
        let _ = await dataRecovery.createBackup(type: .emergency)
    }
    
    private func getSignalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        default: return "UNKNOWN(\(signal))"
        }
    }
    
    // MARK: - System Health and Recovery
    
    private func performStartupHealthCheck() async {
        systemLogger.info("Performing startup health check")
        
        // Check data integrity
        let integrityResult = await integrityChecker.performQuickIntegrityCheck()
        
        if !integrityResult.issues.isEmpty {
            systemLogger.warning("Data integrity issues found: \(integrityResult.issues.count)")
            
            // Attempt auto-fix for critical issues
            let criticalIssues = integrityResult.issues.filter { $0.severity == .critical }
            if !criticalIssues.isEmpty {
                let _ = await integrityChecker.autoFixIssues(criticalIssues)
            }
        }
        
        // Check for crash recovery needs
        let crashRecoveryResult = await dataRecovery.performCrashRecovery()
        
        if case .success(let result) = crashRecoveryResult {
            if !result.recoveredOperations.isEmpty || !result.recoveredSessions.isEmpty {
                systemLogger.info("Crash recovery completed: \(result.recoveredOperations.count) operations, \(result.recoveredSessions.count) sessions")
            }
        }
        
        lastHealthCheck = Date()
    }
    
    private func performCrashRecovery() async {
        // Check if app crashed previously
        let didCrashPreviously = UserDefaults.standard.bool(forKey: "app_crashed_previously")
        
        if didCrashPreviously {
            systemLogger.info("Previous crash detected, performing recovery")
            
            let recoveryResult = await dataRecovery.performCrashRecovery()
            
            switch recoveryResult {
            case .success(let result):
                systemLogger.info("Crash recovery successful")
                
                // Show recovery notification to user
                presenter.presentError(
                    TimeTrackingError.dataValidationFailure("Previous session recovered"),
                    context: ErrorContext(
                        userAction: "App startup after crash",
                        additionalInfo: [
                            "recovered_operations": result.recoveredOperations.count,
                            "recovered_sessions": result.recoveredSessions.count
                        ]
                    ),
                    presentationStyle: .banner
                )
                
            case .failure(let error):
                systemLogger.error("Crash recovery failed: \(error)")
                await handleError(error, context: ErrorContext(userAction: "Crash recovery"))
            }
            
            // Clear crash flag
            UserDefaults.standard.set(false, forKey: "app_crashed_previously")
        }
        
        // Set crash flag for next startup
        UserDefaults.standard.set(true, forKey: "app_crashed_previously")
    }
    
    private func initializeGracefulDegradation() async {
        // Initialize graceful degradation system
        // This will start monitoring system health and adjust operation mode as needed
        systemLogger.info("Initializing graceful degradation system")
    }
    
    // MARK: - Recovery Logic
    
    private func shouldAttemptRecovery(for error: TimeTrackingError) -> Bool {
        switch error {
        case .activityTrackingPermissionDenied, .systemPermissionDenied:
            return false // Requires manual user action
        case .timerAlreadyRunning:
            return true // Can be automatically resolved
        case .databaseCorruption, .dataValidationFailure:
            return true // Can attempt automatic repair
        default:
            return error.severity != .critical // Don't auto-recover from critical errors
        }
    }
    
    private func attemptAutomaticRecovery(error: TimeTrackingError, context: ErrorContext) async -> RecoveryResult {
        let strategy = RecoveryStrategyFactory.createStrategy(for: error)
        return await recoveryManager.attemptRecovery(for: error, context: context, recoveryStrategy: strategy)
    }
    
    // MARK: - System Degradation
    
    private func evaluateSystemDegradation(for error: TimeTrackingError) async {
        // Determine if error should trigger system degradation
        let shouldDegrade = shouldTriggerDegradation(for: error)
        
        if shouldDegrade {
            let newMode = determineDegradationMode(for: error)
            degradationManager.switchToMode(newMode, reason: "Error: \(error.localizedDescription)")
        }
    }
    
    private func shouldTriggerDegradation(for error: TimeTrackingError) -> Bool {
        switch error.severity {
        case .critical:
            return true
        case .high:
            // Trigger degradation if we've had multiple high-severity errors recently
            let recentHighSeverityErrors = logger.getErrors(severity: .high, since: Date().addingTimeInterval(-300)) // Last 5 minutes
            return recentHighSeverityErrors.count >= 3
        default:
            return false
        }
    }
    
    private func determineDegradationMode(for error: TimeTrackingError) -> OperationMode {
        switch error.category {
        case .database:
            return .emergencyMode
        case .system:
            return .minimalMode
        case .activityTracking, .timer:
            return .reducedFunctionality
        default:
            return .reducedFunctionality
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleMemoryWarning() async {
        systemLogger.warning("Memory warning received")
        
        let error = TimeTrackingError.systemResourceExhausted
        let context = ErrorContext(
            userAction: "System memory warning",
            systemState: ["memory_pressure": "high"]
        )
        
        await handleError(error, context: context, presentationStyle: .banner)
    }
    
    private func handleOperationModeChange(_ notification: Notification) async {
        guard let mode = notification.userInfo?["mode"] as? OperationMode,
              let reason = notification.userInfo?["reason"] as? String else {
            return
        }
        
        systemLogger.info("Operation mode changed to \(mode.rawValue): \(reason)")
        
        // Update system status based on new mode
        systemStatus = mode == .normal ? .healthy : .degraded
        
        // Notify user of significant mode changes
        if mode == .emergencyMode || mode == .minimalMode {
            presenter.presentError(
                TimeTrackingError.systemResourceExhausted,
                context: ErrorContext(
                    userAction: "System mode change",
                    additionalInfo: ["new_mode": mode.rawValue, "reason": reason]
                ),
                presentationStyle: .banner
            )
        }
    }
    
    // MARK: - System Status Management
    
    private func updateSystemStatus(for error: TimeTrackingError) {
        switch error.severity {
        case .critical:
            systemStatus = .critical
        case .high:
            if systemStatus == .healthy {
                systemStatus = .degraded
            }
        default:
            break // Don't change status for low/medium severity errors
        }
    }
    
    // MARK: - Health Monitoring
    
    func performPeriodicHealthCheck() async {
        systemLogger.info("Performing periodic health check")
        
        // Check data integrity
        let integrityResult = await integrityChecker.performQuickIntegrityCheck()
        
        // Check system health
        let systemHealth = degradationManager.systemHealth
        
        // Update last health check time
        lastHealthCheck = Date()
        
        // Log health status
        systemLogger.info("Health check completed - Integrity issues: \(integrityResult.issues.count), System health: \(systemHealth.overallScore)")
        
        // Auto-fix minor issues
        let minorIssues = integrityResult.issues.filter { $0.severity == .low && $0.canAutoFix }
        if !minorIssues.isEmpty {
            let _ = await integrityChecker.autoFixIssues(minorIssues)
        }
    }
    
    // MARK: - Statistics and Reporting
    
    func getErrorHandlingStatistics() -> ErrorHandlingStatistics {
        let errorStats = logger.getErrorStatistics()
        let recoveryStats = recoveryManager.getRecoveryStatistics()
        let degradationStats = degradationManager.getDegradationStatistics()
        
        return ErrorHandlingStatistics(
            totalErrors: errorStats.totalErrors,
            criticalErrors: criticalErrorsCount,
            errorsByCategory: errorStats.categoryCounts,
            recoverySuccessRate: recoveryStats.successRate,
            currentOperationMode: degradationStats.currentMode,
            systemHealthScore: degradationStats.systemHealthScore,
            lastHealthCheck: lastHealthCheck
        )
    }
    
    // MARK: - Manual Controls
    
    func resetErrorHandlingSystem() async {
        systemLogger.info("Resetting error handling system")
        
        // Reset counters
        criticalErrorsCount = 0
        
        // Clear error history
        presenter.clearErrorHistory()
        
        // Reset to optimal operation mode
        degradationManager.resetToOptimalMode()
        
        // Perform fresh health check
        await performStartupHealthCheck()
        
        systemStatus = .healthy
    }
    
    func exportErrorLogs() -> URL? {
        return logger.exportLogs()
    }
}

// MARK: - Supporting Types

enum SystemStatus {
    case initializing
    case healthy
    case degraded
    case critical
    
    var displayName: String {
        switch self {
        case .initializing:
            return "Initializing"
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .critical:
            return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .initializing:
            return .blue
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .critical:
            return .red
        }
    }
}

struct ErrorHandlingStatistics {
    let totalErrors: Int
    let criticalErrors: Int
    let errorsByCategory: [ErrorCategory: Int]
    let recoverySuccessRate: Double
    let currentOperationMode: OperationMode
    let systemHealthScore: Double
    let lastHealthCheck: Date?
}

// MARK: - SwiftUI Integration

struct ErrorHandlingStatusView: View {
    @ObservedObject var coordinator = ErrorHandlingCoordinator.shared
    
    var body: some View {
        HStack {
            Circle()
                .fill(coordinator.systemStatus.color)
                .frame(width: 8, height: 8)
            
            Text(coordinator.systemStatus.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if coordinator.criticalErrorsCount > 0 {
                Text("(\(coordinator.criticalErrorsCount) critical)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

extension View {
    func withErrorHandling() -> some View {
        self
            .errorHandling() // From ErrorPresenter
            .onAppear {
                Task {
                    if !ErrorHandlingCoordinator.shared.isInitialized {
                        await ErrorHandlingCoordinator.shared.initialize()
                    }
                }
            }
    }
}