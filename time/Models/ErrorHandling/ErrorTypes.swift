import Foundation
import os.log

// MARK: - Core Error Types

/// Comprehensive error types for the time tracking application
enum TimeTrackingError: LocalizedError, Equatable, Hashable {
    // Activity Tracking Errors
    case activityTrackingPermissionDenied
    case activityTrackingSystemResourceUnavailable
    case activityTrackingDataCorruption(String)
    case activityTrackingNetworkUnavailable
    case activityTrackingStorageQuotaExceeded

    // Timer Errors
    case timerAlreadyRunning
    case timerNotFound
    case timerPersistenceFailure(String)
    case timerNotificationFailure

    // Database Errors
    case databaseConnectionFailure
    case databaseCorruption(String)
    case databaseMigrationFailure(String)
    case databaseQueryTimeout
    case databaseStorageFull

    // Rule Engine Errors
    case ruleEvaluationFailure(String)
    case ruleConditionInvalid(String)
    case ruleActionFailure(String)

    // Search Errors
    case searchIndexCorruption
    case searchQueryInvalid(String)
    case searchPerformanceThresholdExceeded

    // System Errors
    case systemPermissionDenied(String)
    case systemResourceExhausted
    case systemAPIUnavailable(String)
    case systemConfigurationInvalid

    // Data Integrity Errors
    case dataValidationFailure(String)
    case dataConflictDetected(String)
    case dataBackupFailure(String)
    case dataRestoreFailure(String)

    // Network/Sync Errors (for future use)
    case networkConnectionLost
    case syncConflictDetected
    case syncAuthenticationFailure

    var errorDescription: String? {
        switch self {
        // Activity Tracking
        case .activityTrackingPermissionDenied:
            return "Permission denied for activity tracking. Please grant accessibility permissions in System Preferences."
        case .activityTrackingSystemResourceUnavailable:
            return "System resources unavailable for activity tracking."
        case let .activityTrackingDataCorruption(details):
            return "Activity data corruption detected: \(details)"
        case .activityTrackingNetworkUnavailable:
            return "Network unavailable for activity sync."
        case .activityTrackingStorageQuotaExceeded:
            return "Storage quota exceeded for activity data."
        // Timer
        case .timerAlreadyRunning:
            return "A timer is already running. Stop the current timer before starting a new one."
        case .timerNotFound:
            return "Timer not found or has been deleted."
        case let .timerPersistenceFailure(details):
            return "Failed to save timer data: \(details)"
        case .timerNotificationFailure:
            return "Failed to schedule timer notification."
        // Database
        case .databaseConnectionFailure:
            return "Failed to connect to the database."
        case let .databaseCorruption(details):
            return "Database corruption detected: \(details)"
        case let .databaseMigrationFailure(details):
            return "Database migration failed: \(details)"
        case .databaseQueryTimeout:
            return "Database query timed out."
        case .databaseStorageFull:
            return "Database storage is full."
        // Rule Engine
        case let .ruleEvaluationFailure(details):
            return "Rule evaluation failed: \(details)"
        case let .ruleConditionInvalid(details):
            return "Invalid rule condition: \(details)"
        case let .ruleActionFailure(details):
            return "Rule action failed: \(details)"
        // Search
        case .searchIndexCorruption:
            return "Search index is corrupted and needs to be rebuilt."
        case let .searchQueryInvalid(details):
            return "Invalid search query: \(details)"
        case .searchPerformanceThresholdExceeded:
            return "Search operation exceeded performance threshold."
        // System
        case let .systemPermissionDenied(permission):
            return "System permission denied: \(permission)"
        case .systemResourceExhausted:
            return "System resources exhausted."
        case let .systemAPIUnavailable(api):
            return "System API unavailable: \(api)"
        case .systemConfigurationInvalid:
            return "Invalid system configuration."
        // Data Integrity
        case let .dataValidationFailure(details):
            return "Data validation failed: \(details)"
        case let .dataConflictDetected(details):
            return "Data conflict detected: \(details)"
        case let .dataBackupFailure(details):
            return "Data backup failed: \(details)"
        case let .dataRestoreFailure(details):
            return "Data restore failed: \(details)"
        // Network/Sync
        case .networkConnectionLost:
            return "Network connection lost."
        case .syncConflictDetected:
            return "Sync conflict detected."
        case .syncAuthenticationFailure:
            return "Sync authentication failed."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        // Activity Tracking
        case .activityTrackingPermissionDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Accessibility and enable access for this app."
        case .activityTrackingSystemResourceUnavailable:
            return "Close other applications to free up system resources, then restart activity tracking."
        case .activityTrackingDataCorruption:
            return "The app will attempt to repair the data automatically. If this fails, you may need to reset activity data."
        case .activityTrackingNetworkUnavailable:
            return "Check your internet connection and try again."
        case .activityTrackingStorageQuotaExceeded:
            return "Free up disk space or archive old activity data."
        // Timer
        case .timerAlreadyRunning:
            return "Stop the current timer from the status bar or main window before starting a new one."
        case .timerNotFound:
            return "Refresh the timer list or restart the application."
        case .timerPersistenceFailure:
            return "Check available disk space and restart the application."
        case .timerNotificationFailure:
            return "Check notification permissions in System Preferences."
        // Database
        case .databaseConnectionFailure:
            return "Restart the application. If the problem persists, check disk permissions."
        case .databaseCorruption:
            return "The app will attempt automatic repair. If this fails, restore from backup."
        case .databaseMigrationFailure:
            return "Restart the application. If migration continues to fail, contact support."
        case .databaseQueryTimeout:
            return "The operation is taking longer than expected. Try again or restart the app."
        case .databaseStorageFull:
            return "Free up disk space or archive old data."
        // Rule Engine
        case .ruleEvaluationFailure:
            return "Check rule conditions and try again. Disable problematic rules if needed."
        case .ruleConditionInvalid:
            return "Edit the rule to fix invalid conditions."
        case .ruleActionFailure:
            return "Check that the target project exists and try again."
        // Search
        case .searchIndexCorruption:
            return "The search index will be rebuilt automatically. This may take a few minutes."
        case .searchQueryInvalid:
            return "Check your search syntax and try again."
        case .searchPerformanceThresholdExceeded:
            return "Try a more specific search query or filter the results."
        // System
        case .systemPermissionDenied:
            return "Grant the required permission in System Preferences and restart the app."
        case .systemResourceExhausted:
            return "Close other applications and restart this app."
        case .systemAPIUnavailable:
            return "Update macOS to the latest version or restart your computer."
        case .systemConfigurationInvalid:
            return "Reset app preferences or reinstall the application."
        // Data Integrity
        case .dataValidationFailure:
            return "The app will attempt to fix invalid data automatically."
        case .dataConflictDetected:
            return "Choose which version of the data to keep or merge the changes."
        case .dataBackupFailure:
            return "Check available disk space and backup permissions."
        case .dataRestoreFailure:
            return "Verify the backup file is valid and try again."
        // Network/Sync
        case .networkConnectionLost:
            return "Check your internet connection and try again."
        case .syncConflictDetected:
            return "Resolve conflicts manually or choose automatic resolution."
        case .syncAuthenticationFailure:
            return "Re-authenticate your sync account."
        }
    }

    /// Error severity level for prioritizing handling and logging
    var severity: ErrorSeverity {
        switch self {
        case .activityTrackingPermissionDenied, .systemPermissionDenied:
            return .high
        case .databaseCorruption, .dataValidationFailure, .dataConflictDetected:
            return .critical
        case .timerAlreadyRunning, .searchQueryInvalid:
            return .low
        case .databaseConnectionFailure, .systemResourceExhausted:
            return .high
        default:
            return .medium
        }
    }

    /// Category for error grouping and handling
    var category: ErrorCategory {
        switch self {
        case .activityTrackingPermissionDenied, .activityTrackingSystemResourceUnavailable,
             .activityTrackingDataCorruption, .activityTrackingNetworkUnavailable,
             .activityTrackingStorageQuotaExceeded:
            return .activityTracking
        case .timerAlreadyRunning, .timerNotFound, .timerPersistenceFailure, .timerNotificationFailure:
            return .timer
        case .databaseConnectionFailure, .databaseCorruption, .databaseMigrationFailure,
             .databaseQueryTimeout, .databaseStorageFull:
            return .database
        case .ruleEvaluationFailure, .ruleConditionInvalid, .ruleActionFailure:
            return .ruleEngine
        case .searchIndexCorruption, .searchQueryInvalid, .searchPerformanceThresholdExceeded:
            return .search
        case .systemPermissionDenied, .systemResourceExhausted, .systemAPIUnavailable, .systemConfigurationInvalid:
            return .system
        case .dataValidationFailure, .dataConflictDetected, .dataBackupFailure, .dataRestoreFailure:
            return .dataIntegrity
        case .networkConnectionLost, .syncConflictDetected, .syncAuthenticationFailure:
            return .network
        }
    }
}

// MARK: - Supporting Types

enum ErrorSeverity: String, CaseIterable {
    case low
    case medium
    case high
    case critical

    var logLevel: OSLogType {
        switch self {
        case .low:
            return .info
        case .medium:
            return .default
        case .high:
            return .error
        case .critical:
            return .fault
        }
    }
}

enum ErrorCategory: String, CaseIterable {
    case activityTracking = "activity_tracking"
    case timer
    case database
    case ruleEngine = "rule_engine"
    case search
    case system
    case dataIntegrity = "data_integrity"
    case network
}

// MARK: - Error Context

struct ErrorContext {
    let timestamp: Date
    let userAction: String?
    let systemState: [String: Any]
    let stackTrace: String?
    let additionalInfo: [String: Any]

    init(userAction: String? = nil,
         systemState: [String: Any] = [:],
         stackTrace: String? = nil,
         additionalInfo: [String: Any] = [:])
    {
        timestamp = Date()
        self.userAction = userAction
        self.systemState = systemState
        self.stackTrace = stackTrace
        self.additionalInfo = additionalInfo
    }
}
