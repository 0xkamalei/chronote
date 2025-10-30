import Foundation
import SwiftUI
import os.log

// MARK: - Graceful Degradation Manager

@MainActor
class GracefulDegradationManager: ObservableObject {
    static let shared = GracefulDegradationManager()
    
    @Published var currentMode: OperationMode = .normal
    @Published var activeFeatures: Set<AppFeature> = Set(AppFeature.allCases)
    @Published var systemHealth: SystemHealth = SystemHealth()
    @Published var degradationHistory: [DegradationEvent] = []
    
    private let logger = Logger(subsystem: "com.timetracking.app", category: "GracefulDegradation")
    private let healthMonitor = SystemHealthMonitor()
    private var monitoringTimer: Timer?
    
    private init() {
        startHealthMonitoring()
        setupDegradationRules()
    }
    
    // MARK: - Operation Mode Management
    
    func switchToMode(_ mode: OperationMode, reason: String) {
        let previousMode = currentMode
        currentMode = mode
        
        logger.info("Switching from \(previousMode.rawValue) to \(mode.rawValue): \(reason)")
        
        // Update active features based on mode
        updateActiveFeatures(for: mode)
        
        // Record degradation event
        let event = DegradationEvent(
            timestamp: Date(),
            fromMode: previousMode,
            toMode: mode,
            reason: reason,
            triggeredBy: .automatic
        )
        degradationHistory.insert(event, at: 0)
        
        // Keep only last 100 events
        if degradationHistory.count > 100 {
            degradationHistory.removeLast()
        }
        
        // Notify components of mode change
        NotificationCenter.default.post(
            name: .operationModeChanged,
            object: self,
            userInfo: ["mode": mode, "reason": reason]
        )
    }
    
    private func updateActiveFeatures(for mode: OperationMode) {
        switch mode {
        case .normal:
            activeFeatures = Set(AppFeature.allCases)
            
        case .reducedFunctionality:
            activeFeatures = [
                .basicTimeTracking,
                .manualTimeEntries,
                .projectManagement,
                .basicReporting
            ]
            
        case .minimalMode:
            activeFeatures = [
                .basicTimeTracking,
                .manualTimeEntries
            ]
            
        case .offlineMode:
            activeFeatures = [
                .basicTimeTracking,
                .manualTimeEntries,
                .projectManagement,
                .offlineStorage
            ]
            
        case .emergencyMode:
            activeFeatures = [
                .basicTimeTracking,
                .emergencyBackup
            ]
        }
        
        logger.info("Active features updated: \(self.activeFeatures.count) features enabled")
    }
    
    // MARK: - Feature Availability
    
    func isFeatureAvailable(_ feature: AppFeature) -> Bool {
        return activeFeatures.contains(feature)
    }
    
    func requireFeature(_ feature: AppFeature) throws {
        guard isFeatureAvailable(feature) else {
            throw TimeTrackingError.systemAPIUnavailable("Feature \(feature.rawValue) is not available in \(currentMode.rawValue) mode")
        }
    }
    
    func withFeature<T>(_ feature: AppFeature, fallback: T, operation: () throws -> T) -> T {
        guard isFeatureAvailable(feature) else {
            logger.info("Feature \(feature.rawValue) not available, using fallback")
            return fallback
        }
        
        do {
            return try operation()
        } catch {
            logger.error("Feature \(feature.rawValue) operation failed: \(error)")
            return fallback
        }
    }
    
    func withFeatureAsync<T>(_ feature: AppFeature, fallback: T, operation: () async throws -> T) async -> T {
        guard isFeatureAvailable(feature) else {
            logger.info("Feature \(feature.rawValue) not available, using fallback")
            return fallback
        }
        
        do {
            return try await operation()
        } catch {
            logger.error("Feature \(feature.rawValue) operation failed: \(error)")
            return fallback
        }
    }
    
    // MARK: - System Health Monitoring
    
    private func startHealthMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                await self.updateSystemHealth()
                self.evaluateDegradationNeeds()
            }
        }
    }
    
    private func updateSystemHealth() async {
        systemHealth = await healthMonitor.getCurrentHealth()
        
        // Log health status periodically
        if systemHealth.overallScore < 0.7 {
            logger.warning("System health degraded: \(self.systemHealth.overallScore)")
        }
    }
    
    private func evaluateDegradationNeeds() {
        let newMode = determineOptimalMode(for: systemHealth)
        
        if newMode != currentMode {
            let reason = generateDegradationReason(for: systemHealth)
            switchToMode(newMode, reason: reason)
        }
    }
    
    private func determineOptimalMode(for health: SystemHealth) -> OperationMode {
        // Critical system issues - emergency mode
        if health.memoryPressure > 0.9 || health.cpuUsage > 0.95 {
            return .emergencyMode
        }
        
        // Severe resource constraints - minimal mode
        if health.memoryPressure > 0.8 || health.cpuUsage > 0.85 || health.diskSpace < 0.1 {
            return .minimalMode
        }
        
        // Moderate issues - reduced functionality
        if health.memoryPressure > 0.7 || health.cpuUsage > 0.75 || health.diskSpace < 0.2 {
            return .reducedFunctionality
        }
        
        // Network issues - offline mode
        if !health.networkAvailable && currentMode != .offlineMode {
            return .offlineMode
        }
        
        // Good health - normal mode
        if health.overallScore > 0.8 {
            return .normal
        }
        
        return currentMode // No change needed
    }
    
    private func generateDegradationReason(for health: SystemHealth) -> String {
        var reasons: [String] = []
        
        if health.memoryPressure > 0.8 {
            reasons.append("High memory pressure (\(Int(health.memoryPressure * 100))%)")
        }
        
        if health.cpuUsage > 0.8 {
            reasons.append("High CPU usage (\(Int(health.cpuUsage * 100))%)")
        }
        
        if health.diskSpace < 0.2 {
            reasons.append("Low disk space (\(Int(health.diskSpace * 100))%)")
        }
        
        if !health.networkAvailable {
            reasons.append("Network unavailable")
        }
        
        if health.databasePerformance < 0.5 {
            reasons.append("Poor database performance")
        }
        
        return reasons.isEmpty ? "System optimization" : reasons.joined(separator: ", ")
    }
    
    // MARK: - Fallback Implementations
    
    func getActivityTrackingFallback() -> ActivityTrackingFallback {
        switch currentMode {
        case .normal:
            return .fullTracking
        case .reducedFunctionality:
            return .reducedFrequency
        case .minimalMode, .emergencyMode:
            return .manualOnly
        case .offlineMode:
            return .localOnly
        }
    }
    
    func getSearchFallback() -> SearchFallback {
        switch currentMode {
        case .normal:
            return .fullSearch
        case .reducedFunctionality:
            return .basicSearch
        case .minimalMode, .emergencyMode, .offlineMode:
            return .noSearch
        }
    }
    
    func getReportingFallback() -> ReportingFallback {
        switch currentMode {
        case .normal:
            return .fullReporting
        case .reducedFunctionality:
            return .basicReporting
        case .minimalMode, .emergencyMode, .offlineMode:
            return .noReporting
        }
    }
    
    func getRuleEngineFallback() -> RuleEngineFallback {
        switch currentMode {
        case .normal:
            return .fullRuleEngine
        case .reducedFunctionality:
            return .simpleRules
        case .minimalMode, .emergencyMode, .offlineMode:
            return .noRules
        }
    }
    
    // MARK: - Progressive Enhancement
    
    func enableProgressiveFeature(_ feature: AppFeature) -> Bool {
        guard !activeFeatures.contains(feature) else {
            return true // Already enabled
        }
        
        // Check if system can handle the additional feature
        if canEnableFeature(feature) {
            activeFeatures.insert(feature)
            logger.info("Progressive enhancement: enabled \(feature.rawValue)")
            return true
        } else {
            logger.warning("Cannot enable \(feature.rawValue) due to system constraints")
            return false
        }
    }
    
    func disableNonEssentialFeature(_ feature: AppFeature) {
        guard !feature.isEssential else {
            logger.warning("Cannot disable essential feature: \(feature.rawValue)")
            return
        }
        
        activeFeatures.remove(feature)
        logger.info("Disabled non-essential feature: \(feature.rawValue)")
    }
    
    private func canEnableFeature(_ feature: AppFeature) -> Bool {
        let requiredResources = feature.resourceRequirements
        
        return systemHealth.memoryPressure < (1.0 - requiredResources.memory) &&
               systemHealth.cpuUsage < (1.0 - requiredResources.cpu) &&
               systemHealth.diskSpace > requiredResources.disk
    }
    
    // MARK: - Offline Capability
    
    func enableOfflineMode() {
        switchToMode(.offlineMode, reason: "User requested offline mode")
        
        // Initialize offline storage
        OfflineStorageManager.shared.initialize()
        
        // Queue pending operations
        OfflineOperationQueue.shared.startQueueing()
    }
    
    func disableOfflineMode() {
        guard currentMode == .offlineMode else { return }
        
        // Sync offline data when network becomes available
        if systemHealth.networkAvailable {
            Task {
                await OfflineStorageManager.shared.syncPendingData()
                switchToMode(.normal, reason: "Network restored, offline sync completed")
            }
        }
    }
    
    // MARK: - Degradation Rules Setup
    
    private func setupDegradationRules() {
        // Set up automatic degradation rules based on system conditions
        
        // Memory pressure rule
        NotificationCenter.default.addObserver(
            forName: .memoryPressureWarning,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if self.currentMode == .normal {
                    self.switchToMode(.reducedFunctionality, reason: "Memory pressure warning")
                }
            }
        }
        
        // Network connectivity rule
        NotificationCenter.default.addObserver(
            forName: .networkConnectivityChanged,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                if let isConnected = notification.userInfo?["connected"] as? Bool {
                    if !isConnected && self.currentMode != .offlineMode {
                        self.enableOfflineMode()
                    } else if isConnected && self.currentMode == .offlineMode {
                        self.disableOfflineMode()
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Mode Control
    
    func forceMode(_ mode: OperationMode, reason: String = "User requested") {
        let event = DegradationEvent(
            timestamp: Date(),
            fromMode: currentMode,
            toMode: mode,
            reason: reason,
            triggeredBy: .manual
        )
        degradationHistory.insert(event, at: 0)
        
        switchToMode(mode, reason: reason)
    }
    
    func resetToOptimalMode() {
        let optimalMode = determineOptimalMode(for: systemHealth)
        switchToMode(optimalMode, reason: "Reset to optimal mode")
    }
    
    // MARK: - Degradation Statistics
    
    func getDegradationStatistics() -> DegradationStatistics {
        let totalEvents = degradationHistory.count
        let automaticEvents = degradationHistory.filter { $0.triggeredBy == .automatic }.count
        let manualEvents = totalEvents - automaticEvents
        
        let modeDistribution = Dictionary(grouping: degradationHistory) { $0.toMode }
            .mapValues { $0.count }
        
        let averageTimeInMode = calculateAverageTimeInMode()
        
        return DegradationStatistics(
            totalDegradationEvents: totalEvents,
            automaticDegradations: automaticEvents,
            manualDegradations: manualEvents,
            currentMode: currentMode,
            modeDistribution: modeDistribution,
            averageTimeInMode: averageTimeInMode,
            systemHealthScore: systemHealth.overallScore
        )
    }
    
    private func calculateAverageTimeInMode() -> [OperationMode: TimeInterval] {
        var modeTimeMap: [OperationMode: TimeInterval] = [:]
        
        for i in 0..<(degradationHistory.count - 1) {
            let event = degradationHistory[i]
            let nextEvent = degradationHistory[i + 1]
            let timeInMode = event.timestamp.timeIntervalSince(nextEvent.timestamp)
            
            modeTimeMap[event.toMode, default: 0] += timeInMode
        }
        
        // Add current mode time
        if let lastEvent = degradationHistory.first {
            let currentModeTime = Date().timeIntervalSince(lastEvent.timestamp)
            modeTimeMap[currentMode, default: 0] += currentModeTime
        }
        
        return modeTimeMap
    }
}

// MARK: - Supporting Types

enum OperationMode: String, CaseIterable {
    case normal = "normal"
    case reducedFunctionality = "reduced"
    case minimalMode = "minimal"
    case offlineMode = "offline"
    case emergencyMode = "emergency"
    
    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .reducedFunctionality:
            return "Reduced Functionality"
        case .minimalMode:
            return "Minimal Mode"
        case .offlineMode:
            return "Offline Mode"
        case .emergencyMode:
            return "Emergency Mode"
        }
    }
    
    var description: String {
        switch self {
        case .normal:
            return "All features available"
        case .reducedFunctionality:
            return "Some advanced features disabled to improve performance"
        case .minimalMode:
            return "Only essential features available"
        case .offlineMode:
            return "Working offline with local data only"
        case .emergencyMode:
            return "Critical system issues detected, minimal functionality only"
        }
    }
}

enum AppFeature: String, CaseIterable {
    case basicTimeTracking = "basic_time_tracking"
    case automaticActivityTracking = "automatic_activity_tracking"
    case manualTimeEntries = "manual_time_entries"
    case projectManagement = "project_management"
    case ruleEngine = "rule_engine"
    case advancedSearch = "advanced_search"
    case basicSearch = "basic_search"
    case fullReporting = "full_reporting"
    case basicReporting = "basic_reporting"
    case dataExport = "data_export"
    case notifications = "notifications"
    case backgroundProcessing = "background_processing"
    case contextCapture = "context_capture"
    case idleDetection = "idle_detection"
    case performanceMonitoring = "performance_monitoring"
    case offlineStorage = "offline_storage"
    case emergencyBackup = "emergency_backup"
    
    var isEssential: Bool {
        switch self {
        case .basicTimeTracking, .manualTimeEntries:
            return true
        default:
            return false
        }
    }
    
    var resourceRequirements: ResourceRequirements {
        switch self {
        case .basicTimeTracking, .manualTimeEntries:
            return ResourceRequirements(memory: 0.1, cpu: 0.05, disk: 0.01)
        case .automaticActivityTracking:
            return ResourceRequirements(memory: 0.2, cpu: 0.15, disk: 0.05)
        case .ruleEngine:
            return ResourceRequirements(memory: 0.15, cpu: 0.1, disk: 0.02)
        case .advancedSearch:
            return ResourceRequirements(memory: 0.25, cpu: 0.2, disk: 0.1)
        case .fullReporting:
            return ResourceRequirements(memory: 0.3, cpu: 0.25, disk: 0.05)
        default:
            return ResourceRequirements(memory: 0.1, cpu: 0.05, disk: 0.01)
        }
    }
}

struct ResourceRequirements {
    let memory: Double // Percentage of available memory
    let cpu: Double    // Percentage of CPU capacity
    let disk: Double   // Percentage of available disk space
}

struct SystemHealth {
    var memoryPressure: Double = 0.0
    var cpuUsage: Double = 0.0
    var diskSpace: Double = 1.0
    var networkAvailable: Bool = true
    var databasePerformance: Double = 1.0
    var overallScore: Double = 1.0
    
    init() {
        updateOverallScore()
    }
    
    mutating func updateOverallScore() {
        let memoryScore = 1.0 - memoryPressure
        let cpuScore = 1.0 - cpuUsage
        let diskScore = diskSpace
        let networkScore = networkAvailable ? 1.0 : 0.5
        let dbScore = databasePerformance
        
        overallScore = (memoryScore + cpuScore + diskScore + networkScore + dbScore) / 5.0
    }
}

struct DegradationEvent {
    let timestamp: Date
    let fromMode: OperationMode
    let toMode: OperationMode
    let reason: String
    let triggeredBy: DegradationTrigger
}

enum DegradationTrigger {
    case automatic
    case manual
}

struct DegradationStatistics {
    let totalDegradationEvents: Int
    let automaticDegradations: Int
    let manualDegradations: Int
    let currentMode: OperationMode
    let modeDistribution: [OperationMode: Int]
    let averageTimeInMode: [OperationMode: TimeInterval]
    let systemHealthScore: Double
}

// MARK: - Fallback Types

enum ActivityTrackingFallback {
    case fullTracking
    case reducedFrequency
    case manualOnly
    case localOnly
}

enum SearchFallback {
    case fullSearch
    case basicSearch
    case noSearch
}

enum ReportingFallback {
    case fullReporting
    case basicReporting
    case noReporting
}

enum RuleEngineFallback {
    case fullRuleEngine
    case simpleRules
    case noRules
}

// MARK: - System Health Monitor

class SystemHealthMonitor {
    func getCurrentHealth() async -> SystemHealth {
        var health = SystemHealth()
        
        // Get memory pressure
        health.memoryPressure = await getMemoryPressure()
        
        // Get CPU usage
        health.cpuUsage = await getCPUUsage()
        
        // Get disk space
        health.diskSpace = await getDiskSpace()
        
        // Check network availability
        health.networkAvailable = await checkNetworkAvailability()
        
        // Check database performance
        health.databasePerformance = await checkDatabasePerformance()
        
        health.updateOverallScore()
        
        return health
    }
    
    private func getMemoryPressure() async -> Double {
        // Implementation would check actual memory pressure
        // For now, return a simulated value
        return 0.3
    }
    
    private func getCPUUsage() async -> Double {
        // Implementation would check actual CPU usage
        return 0.2
    }
    
    private func getDiskSpace() async -> Double {
        // Implementation would check actual disk space
        return 0.8
    }
    
    private func checkNetworkAvailability() async -> Bool {
        // Implementation would check actual network connectivity
        return true
    }
    
    private func checkDatabasePerformance() async -> Double {
        // Implementation would measure database query performance
        return 0.9
    }
}

// MARK: - Offline Support Classes

class OfflineStorageManager {
    static let shared = OfflineStorageManager()
    
    private init() {}
    
    func initialize() {
        // Initialize offline storage
    }
    
    func syncPendingData() async {
        // Sync offline data when network becomes available
    }
}

class OfflineOperationQueue {
    static let shared = OfflineOperationQueue()
    
    private init() {}
    
    func startQueueing() {
        // Start queueing operations for offline mode
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let operationModeChanged = Notification.Name("operationModeChanged")
    static let memoryPressureWarning = Notification.Name("memoryPressureWarning")
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}