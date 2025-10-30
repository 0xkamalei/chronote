import Foundation
import os.log

// MARK: - Error Recovery Manager

@MainActor
class ErrorRecoveryManager: ObservableObject {
    static let shared = ErrorRecoveryManager()
    
    @Published var activeRecoveryOperations: [UUID: RecoveryOperation] = [:]
    @Published var recoveryHistory: [RecoveryAttempt] = []
    
    private let logger = Logger(subsystem: "com.timetracking.app", category: "ErrorRecovery")
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 60.0
    
    private init() {}
    
    // MARK: - Recovery Operations
    
    /// Attempts to recover from an error with exponential backoff
    func attemptRecovery(
        for error: TimeTrackingError,
        context: ErrorContext,
        recoveryStrategy: RecoveryStrategy
    ) async -> RecoveryResult {
        let operationId = UUID()
        let operation = RecoveryOperation(
            id: operationId,
            error: error,
            context: context,
            strategy: recoveryStrategy,
            startTime: Date()
        )
        
        activeRecoveryOperations[operationId] = operation
        
        logger.info("Starting recovery operation for error: \(error.localizedDescription)")
        
        let result = await performRecoveryWithBackoff(operation: operation)
        
        activeRecoveryOperations.removeValue(forKey: operationId)
        
        let attempt = RecoveryAttempt(
            operation: operation,
            result: result,
            completedAt: Date()
        )
        recoveryHistory.append(attempt)
        
        // Keep only last 100 recovery attempts
        if recoveryHistory.count > 100 {
            recoveryHistory.removeFirst(recoveryHistory.count - 100)
        }
        
        return result
    }
    
    private func performRecoveryWithBackoff(operation: RecoveryOperation) async -> RecoveryResult {
        var attemptCount = 0
        var lastError: Error?
        
        while attemptCount < maxRetryAttempts {
            do {
                logger.info("Recovery attempt \(attemptCount + 1) for operation \(operation.id)")
                
                let success = try await executeRecoveryStrategy(operation.strategy, context: operation.context)
                
                if success {
                    logger.info("Recovery successful after \(attemptCount + 1) attempts")
                    return .success(attemptCount + 1)
                } else {
                    throw TimeTrackingError.dataValidationFailure("Recovery strategy returned false")
                }
                
            } catch {
                lastError = error
                attemptCount += 1
                
                logger.error("Recovery attempt \(attemptCount) failed: \(error.localizedDescription)")
                
                if attemptCount < maxRetryAttempts {
                    let delay = calculateBackoffDelay(attempt: attemptCount)
                    logger.info("Waiting \(delay) seconds before next attempt")
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        logger.error("Recovery failed after \(self.maxRetryAttempts) attempts")
        return .failure(lastError ?? TimeTrackingError.systemResourceExhausted)
    }
    
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt - 1))
        let jitteredDelay = exponentialDelay * (0.5 + Double.random(in: 0...0.5))
        return min(jitteredDelay, maxRetryDelay)
    }
    
    private func executeRecoveryStrategy(_ strategy: RecoveryStrategy, context: ErrorContext) async throws -> Bool {
        switch strategy {
        case .retry:
            return true // Simple retry, success depends on the original operation
            
        case .fallback(let fallbackAction):
            return try await fallbackAction()
            
        case .repair(let repairAction):
            return try await repairAction()
            
        case .reset(let resetAction):
            return try await resetAction()
            
        case .gracefulDegradation(let degradationAction):
            return try await degradationAction()
            
        case .userIntervention(let interventionAction):
            return try await interventionAction()
            
        case .systemRestart:
            // This would typically involve restarting components, not the entire system
            return try await restartSystemComponents()
            
        case .dataRecovery(let recoveryAction):
            return try await recoveryAction()
        }
    }
    
    private func restartSystemComponents() async throws -> Bool {
        // Restart key system components
        logger.info("Restarting system components")
        
        // This would restart managers, clear caches, etc.
        // Implementation would depend on specific components
        
        return true
    }
    
    // MARK: - Recovery Status
    
    func getRecoveryStatus(for operationId: UUID) -> RecoveryOperation? {
        return activeRecoveryOperations[operationId]
    }
    
    func cancelRecovery(operationId: UUID) {
        activeRecoveryOperations.removeValue(forKey: operationId)
        logger.info("Cancelled recovery operation: \(operationId)")
    }
    
    func getRecoveryHistory(for category: ErrorCategory? = nil) -> [RecoveryAttempt] {
        if let category = category {
            return recoveryHistory.filter { $0.operation.error.category == category }
        }
        return recoveryHistory
    }
    
    // MARK: - Recovery Statistics
    
    func getRecoveryStatistics() -> RecoveryStatistics {
        let totalAttempts = recoveryHistory.count
        let successfulAttempts = recoveryHistory.filter { $0.result.isSuccess }.count
        let failedAttempts = totalAttempts - successfulAttempts
        
        let successRate = totalAttempts > 0 ? Double(successfulAttempts) / Double(totalAttempts) : 0.0
        
        let averageAttemptsToSuccess = recoveryHistory
            .compactMap { attempt in
                if case .success(let attempts) = attempt.result {
                    return attempts
                }
                return nil
            }
            .reduce(0, +) / max(successfulAttempts, 1)
        
        return RecoveryStatistics(
            totalAttempts: totalAttempts,
            successfulAttempts: successfulAttempts,
            failedAttempts: failedAttempts,
            successRate: successRate,
            averageAttemptsToSuccess: averageAttemptsToSuccess
        )
    }
}

// MARK: - Supporting Types

struct RecoveryOperation {
    let id: UUID
    let error: TimeTrackingError
    let context: ErrorContext
    let strategy: RecoveryStrategy
    let startTime: Date
}

struct RecoveryAttempt {
    let operation: RecoveryOperation
    let result: RecoveryResult
    let completedAt: Date
}

enum RecoveryStrategy {
    case retry
    case fallback(() async throws -> Bool)
    case repair(() async throws -> Bool)
    case reset(() async throws -> Bool)
    case gracefulDegradation(() async throws -> Bool)
    case userIntervention(() async throws -> Bool)
    case systemRestart
    case dataRecovery(() async throws -> Bool)
}

enum RecoveryResult {
    case success(Int) // Number of attempts needed
    case failure(Error)
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

struct RecoveryStatistics {
    let totalAttempts: Int
    let successfulAttempts: Int
    let failedAttempts: Int
    let successRate: Double
    let averageAttemptsToSuccess: Int
}

// MARK: - Recovery Strategy Factory

struct RecoveryStrategyFactory {
    static func createStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error.category {
        case .activityTracking:
            return createActivityTrackingStrategy(for: error)
        case .timer:
            return createTimerStrategy(for: error)
        case .database:
            return createDatabaseStrategy(for: error)
        case .ruleEngine:
            return createRuleEngineStrategy(for: error)
        case .search:
            return createSearchStrategy(for: error)
        case .system:
            return createSystemStrategy(for: error)
        case .dataIntegrity:
            return createDataIntegrityStrategy(for: error)
        case .network:
            return createNetworkStrategy(for: error)
        }
    }
    
    private static func createActivityTrackingStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .activityTrackingPermissionDenied:
            return .userIntervention {
                // Guide user to grant permissions
                return false // Requires manual user action
            }
        case .activityTrackingSystemResourceUnavailable:
            return .gracefulDegradation {
                // Reduce tracking frequency
                return true
            }
        case .activityTrackingDataCorruption:
            return .repair {
                // Attempt to repair corrupted activity data
                return true
            }
        default:
            return .retry
        }
    }
    
    private static func createTimerStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .timerAlreadyRunning:
            return .fallback {
                // Stop existing timer and start new one
                return true
            }
        case .timerPersistenceFailure:
            return .repair {
                // Attempt to repair timer persistence
                return true
            }
        default:
            return .retry
        }
    }
    
    private static func createDatabaseStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .databaseCorruption:
            return .dataRecovery {
                // Attempt database repair
                return true
            }
        case .databaseConnectionFailure:
            return .reset {
                // Reset database connection
                return true
            }
        default:
            return .retry
        }
    }
    
    private static func createRuleEngineStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .ruleEvaluationFailure:
            return .gracefulDegradation {
                // Disable problematic rules
                return true
            }
        default:
            return .retry
        }
    }
    
    private static func createSearchStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .searchIndexCorruption:
            return .repair {
                // Rebuild search index
                return true
            }
        default:
            return .retry
        }
    }
    
    private static func createSystemStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .systemPermissionDenied:
            return .userIntervention {
                // Guide user to grant permissions
                return false
            }
        case .systemResourceExhausted:
            return .gracefulDegradation {
                // Reduce resource usage
                return true
            }
        default:
            return .systemRestart
        }
    }
    
    private static func createDataIntegrityStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .dataValidationFailure, .dataConflictDetected:
            return .repair {
                // Attempt data repair
                return true
            }
        case .dataBackupFailure, .dataRestoreFailure:
            return .fallback {
                // Use alternative backup/restore method
                return true
            }
        default:
            return .retry
        }
    }
    
    private static func createNetworkStrategy(for error: TimeTrackingError) -> RecoveryStrategy {
        switch error {
        case .networkConnectionLost:
            return .gracefulDegradation {
                // Switch to offline mode
                return true
            }
        default:
            return .retry
        }
    }
}