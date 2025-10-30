import Foundation
import os
import SwiftUI

/// Comprehensive performance monitoring and metrics collection
@MainActor
class PerformanceMonitor: ObservableObject {
    // MARK: - Singleton
    
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    
    @Published private(set) var systemMetrics: SystemMetrics = SystemMetrics()
    @Published private(set) var applicationMetrics: ApplicationMetrics = ApplicationMetrics()
    @Published private(set) var performanceAlerts: [PerformanceAlert] = []
    @Published private(set) var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.time.vscode", category: "PerformanceMonitor")
    
    // Monitoring timers
    private var systemMonitorTimer: Timer?
    private var applicationMonitorTimer: Timer?
    private var alertCleanupTimer: Timer?
    
    // Performance tracking
    private var operationMetrics: [String: OperationMetrics] = [:]
    private var performanceHistory: [PerformanceSnapshot] = []
    private let maxHistorySize = 1000
    
    // Thresholds for performance alerts
    private let cpuThreshold: Double = 80.0 // 80%
    private let memoryThreshold: Double = 85.0 // 85%
    private let responseTimeThreshold: Double = 1.0 // 1 second
    private let errorRateThreshold: Double = 5.0 // 5%
    
    // Resource monitoring
    private var resourceUsageHistory: [ResourceUsageSnapshot] = []
    private let maxResourceHistorySize = 500
    
    // MARK: - Initialization
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    deinit {
        // We can't call async methods from deinit, so we'll just invalidate our monitoring timers
        systemMonitorTimer?.invalidate()
        applicationMonitorTimer?.invalidate()
        alertCleanupTimer?.invalidate()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start system monitoring (every 30 seconds)
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemMetrics()
            }
        }
        
        // Start application monitoring (every 10 seconds)
        applicationMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateApplicationMetrics()
            }
        }
        
        // Start alert cleanup (every 5 minutes)
        alertCleanupTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupOldAlerts()
            }
        }
        
        logger.info("Performance monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
        
        applicationMonitorTimer?.invalidate()
        applicationMonitorTimer = nil
        
        alertCleanupTimer?.invalidate()
        alertCleanupTimer = nil
        
        logger.info("Performance monitoring stopped")
    }
    
    private func setupPerformanceMonitoring() {
        // Start monitoring automatically
        startMonitoring()
        
        // Listen for memory pressure notifications
        NotificationCenter.default.addObserver(
            forName: .memoryPressureDetected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMemoryPressureAlert(notification)
        }
    }
    
    // MARK: - System Metrics Collection
    
    private func updateSystemMetrics() {
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()
        let diskUsage = getCurrentDiskUsage()
        
        systemMetrics = SystemMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            timestamp: Date()
        )
        
        // Check for performance alerts
        checkSystemPerformanceAlerts(cpuUsage: cpuUsage, memoryUsage: memoryUsage)
        
        // Record resource usage history
        recordResourceUsage(cpuUsage: cpuUsage, memoryUsage: memoryUsage)
        
        logger.debug("System metrics updated - CPU: \(String(format: "%.1f", cpuUsage))%, Memory: \(String(format: "%.1f", memoryUsage))%")
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            // This is a simplified CPU usage calculation
            // In a real implementation, you'd need to track CPU time over intervals
            return Double.random(in: 0...100) // Placeholder
        }
        
        return 0.0
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let usedMemory = UInt64(info.resident_size)
            return (Double(usedMemory) / Double(totalMemory)) * 100.0
        }
        
        return 0.0
    }
    
    private func getCurrentDiskUsage() -> Double {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            
            if let totalCapacity = values.volumeTotalCapacity,
               let availableCapacity = values.volumeAvailableCapacity {
                let usedCapacity = totalCapacity - availableCapacity
                return (Double(usedCapacity) / Double(totalCapacity)) * 100.0
            }
        } catch {
            logger.error("Failed to get disk usage: \(error.localizedDescription)")
        }
        
        return 0.0
    }
    
    // MARK: - Application Metrics Collection
    
    private func updateApplicationMetrics() {
        let responseTime = calculateAverageResponseTime()
        let errorRate = calculateErrorRate()
        let throughput = calculateThroughput()
        let activeOperations = operationMetrics.values.filter { !$0.isCompleted }.count
        
        applicationMetrics = ApplicationMetrics(
            averageResponseTime: responseTime,
            errorRate: errorRate,
            throughput: throughput,
            activeOperations: activeOperations,
            totalOperations: operationMetrics.count,
            timestamp: Date()
        )
        
        // Check for application performance alerts
        checkApplicationPerformanceAlerts(responseTime: responseTime, errorRate: errorRate)
        
        // Record performance snapshot
        recordPerformanceSnapshot()
        
        logger.debug("Application metrics updated - Response: \(String(format: "%.3f", responseTime))s, Error Rate: \(String(format: "%.1f", errorRate))%")
    }
    
    private func calculateAverageResponseTime() -> Double {
        let recentOperations = operationMetrics.values.filter {
            $0.endTime?.timeIntervalSinceNow ?? 0 > -300 // Last 5 minutes
        }
        
        guard !recentOperations.isEmpty else { return 0.0 }
        
        let totalDuration = recentOperations.compactMap { $0.duration }.reduce(0, +)
        return totalDuration / Double(recentOperations.count)
    }
    
    private func calculateErrorRate() -> Double {
        let recentOperations = operationMetrics.values.filter {
            $0.endTime?.timeIntervalSinceNow ?? 0 > -300 // Last 5 minutes
        }
        
        guard !recentOperations.isEmpty else { return 0.0 }
        
        let errorCount = recentOperations.filter { $0.hasError }.count
        return (Double(errorCount) / Double(recentOperations.count)) * 100.0
    }
    
    private func calculateThroughput() -> Double {
        let recentOperations = operationMetrics.values.filter {
            $0.endTime?.timeIntervalSinceNow ?? 0 > -60 // Last minute
        }
        
        return Double(recentOperations.count) / 60.0 // Operations per second
    }
    
    // MARK: - Operation Tracking
    
    /// Starts tracking a performance operation
    func startOperation(_ operationName: String, category: OperationCategory = .general) -> String {
        let operationId = UUID().uuidString
        
        let metrics = OperationMetrics(
            id: operationId,
            name: operationName,
            category: category,
            startTime: Date(),
            endTime: nil,
            duration: 0,
            hasError: false,
            errorMessage: nil,
            metadata: [:]
        )
        
        operationMetrics[operationId] = metrics
        
        logger.debug("Started operation: \(operationName) (\(operationId))")
        
        return operationId
    }
    
    /// Ends tracking a performance operation
    func endOperation(_ operationId: String, success: Bool = true, errorMessage: String? = nil, metadata: [String: Any] = [:]) {
        guard var metrics = operationMetrics[operationId] else {
            logger.warning("Attempted to end unknown operation: \(operationId)")
            return
        }
        
        let endTime = Date()
        metrics.endTime = endTime
        metrics.duration = endTime.timeIntervalSince(metrics.startTime)
        metrics.hasError = !success
        metrics.errorMessage = errorMessage
        metrics.metadata = metadata
        
        operationMetrics[operationId] = metrics
        
        // Log performance if operation took too long
        if metrics.duration > responseTimeThreshold {
            logger.warning("Slow operation detected: \(metrics.name) took \(String(format: "%.3f", metrics.duration))s")
            
            addPerformanceAlert(
                type: .slowOperation,
                message: "Operation '\(metrics.name)' took \(String(format: "%.3f", metrics.duration))s",
                severity: .warning,
                metadata: ["operationId": operationId, "duration": metrics.duration]
            )
        }
        
        logger.debug("Ended operation: \(metrics.name) (\(operationId)) - Duration: \(String(format: "%.3f", metrics.duration))s")
    }
    
    /// Tracks a simple operation with automatic timing
    func trackOperation<T>(_ operationName: String, category: OperationCategory = .general, operation: () throws -> T) rethrows -> T {
        let operationId = startOperation(operationName, category: category)
        
        do {
            let result = try operation()
            endOperation(operationId, success: true)
            return result
        } catch {
            endOperation(operationId, success: false, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    /// Tracks an async operation with automatic timing
    func trackAsyncOperation<T>(_ operationName: String, category: OperationCategory = .general, operation: () async throws -> T) async rethrows -> T {
        let operationId = startOperation(operationName, category: category)
        
        do {
            let result = try await operation()
            endOperation(operationId, success: true)
            return result
        } catch {
            endOperation(operationId, success: false, errorMessage: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Performance Alerts
    
    private func checkSystemPerformanceAlerts(cpuUsage: Double, memoryUsage: Double) {
        // CPU usage alert
        if cpuUsage > cpuThreshold {
            addPerformanceAlert(
                type: .highCPUUsage,
                message: "High CPU usage detected: \(String(format: "%.1f", cpuUsage))%",
                severity: cpuUsage > 95 ? .critical : .warning,
                metadata: ["cpuUsage": cpuUsage]
            )
        }
        
        // Memory usage alert
        if memoryUsage > memoryThreshold {
            addPerformanceAlert(
                type: .highMemoryUsage,
                message: "High memory usage detected: \(String(format: "%.1f", memoryUsage))%",
                severity: memoryUsage > 95 ? .critical : .warning,
                metadata: ["memoryUsage": memoryUsage]
            )
        }
    }
    
    private func checkApplicationPerformanceAlerts(responseTime: Double, errorRate: Double) {
        // Response time alert
        if responseTime > responseTimeThreshold {
            addPerformanceAlert(
                type: .slowResponseTime,
                message: "Slow response time detected: \(String(format: "%.3f", responseTime))s",
                severity: responseTime > 5.0 ? .critical : .warning,
                metadata: ["responseTime": responseTime]
            )
        }
        
        // Error rate alert
        if errorRate > errorRateThreshold {
            addPerformanceAlert(
                type: .highErrorRate,
                message: "High error rate detected: \(String(format: "%.1f", errorRate))%",
                severity: errorRate > 20.0 ? .critical : .warning,
                metadata: ["errorRate": errorRate]
            )
        }
    }
    
    private func addPerformanceAlert(type: PerformanceAlertType, message: String, severity: AlertSeverity, metadata: [String: Any] = [:]) {
        // Check if we already have a recent alert of this type
        let recentAlert = performanceAlerts.first {
            $0.type == type && $0.timestamp.timeIntervalSinceNow > -60 // Within last minute
        }
        
        guard recentAlert == nil else { return } // Don't spam alerts
        
        let alert = PerformanceAlert(
            id: UUID(),
            type: type,
            message: message,
            severity: severity,
            timestamp: Date(),
            metadata: metadata
        )
        
        performanceAlerts.append(alert)
        
        // Keep only recent alerts
        if performanceAlerts.count > 100 {
            performanceAlerts = Array(performanceAlerts.suffix(50))
        }
        
        logger.info("Performance alert: \(message)")
        
        // Post notification for external handling
        NotificationCenter.default.post(
            name: .performanceAlertGenerated,
            object: self,
            userInfo: ["alert": alert]
        )
    }
    
    private func handleMemoryPressureAlert(_ notification: Notification) {
        addPerformanceAlert(
            type: .memoryPressure,
            message: "System memory pressure detected",
            severity: .critical,
            metadata: notification.userInfo as? [String: Any] ?? [:]
        )
    }
    
    private func cleanupOldAlerts() {
        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let initialCount = performanceAlerts.count
        
        performanceAlerts = performanceAlerts.filter { $0.timestamp > cutoffTime }
        
        let removedCount = initialCount - performanceAlerts.count
        if removedCount > 0 {
            logger.debug("Cleaned up \(removedCount) old performance alerts")
        }
    }
    
    // MARK: - Performance History
    
    private func recordPerformanceSnapshot() {
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            systemMetrics: systemMetrics,
            applicationMetrics: applicationMetrics,
            activeOperations: operationMetrics.values.filter { !$0.isCompleted }.count
        )
        
        performanceHistory.append(snapshot)
        
        // Keep history size manageable
        if performanceHistory.count > maxHistorySize {
            performanceHistory = Array(performanceHistory.suffix(maxHistorySize / 2))
        }
    }
    
    private func recordResourceUsage(cpuUsage: Double, memoryUsage: Double) {
        let snapshot = ResourceUsageSnapshot(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage
        )
        
        resourceUsageHistory.append(snapshot)
        
        // Keep history size manageable
        if resourceUsageHistory.count > maxResourceHistorySize {
            resourceUsageHistory = Array(resourceUsageHistory.suffix(maxResourceHistorySize / 2))
        }
    }
    
    // MARK: - Performance Analysis
    
    /// Gets performance statistics for a specific time period
    func getPerformanceStatistics(for timeInterval: TimeInterval) -> PerformanceStatistics {
        let cutoffTime = Date().addingTimeInterval(-timeInterval)
        
        let recentSnapshots = performanceHistory.filter { $0.timestamp > cutoffTime }
        let recentOperations = operationMetrics.values.filter {
            ($0.endTime ?? Date()).timeIntervalSince(cutoffTime) > 0
        }
        
        let avgCPU = recentSnapshots.isEmpty ? 0 : recentSnapshots.map { $0.systemMetrics.cpuUsage }.reduce(0, +) / Double(recentSnapshots.count)
        let avgMemory = recentSnapshots.isEmpty ? 0 : recentSnapshots.map { $0.systemMetrics.memoryUsage }.reduce(0, +) / Double(recentSnapshots.count)
        let avgResponseTime = recentOperations.isEmpty ? 0 : recentOperations.map { $0.duration }.reduce(0, +) / Double(recentOperations.count)
        
        let errorCount = recentOperations.filter { $0.hasError }.count
        let errorRate = recentOperations.isEmpty ? 0 : (Double(errorCount) / Double(recentOperations.count)) * 100
        
        return PerformanceStatistics(
            timeInterval: timeInterval,
            averageCPUUsage: avgCPU,
            averageMemoryUsage: avgMemory,
            averageResponseTime: avgResponseTime,
            errorRate: errorRate,
            totalOperations: recentOperations.count,
            alertCount: performanceAlerts.filter { $0.timestamp > cutoffTime }.count
        )
    }
    
    /// Gets current performance summary
    func getCurrentPerformanceSummary() -> PerformanceSummary {
        let stats5min = getPerformanceStatistics(for: 300) // 5 minutes
        let stats1hour = getPerformanceStatistics(for: 3600) // 1 hour
        
        return PerformanceSummary(
            currentSystemMetrics: systemMetrics,
            currentApplicationMetrics: applicationMetrics,
            recentStatistics: stats5min,
            hourlyStatistics: stats1hour,
            activeAlerts: performanceAlerts.filter { $0.timestamp.timeIntervalSinceNow > -300 }, // Last 5 minutes
            performanceScore: calculatePerformanceScore()
        )
    }
    
    private func calculatePerformanceScore() -> Double {
        // Calculate a performance score from 0-100 based on various metrics
        var score = 100.0
        
        // CPU usage penalty
        if systemMetrics.cpuUsage > 50 {
            score -= (systemMetrics.cpuUsage - 50) * 0.5
        }
        
        // Memory usage penalty
        if systemMetrics.memoryUsage > 60 {
            score -= (systemMetrics.memoryUsage - 60) * 0.8
        }
        
        // Response time penalty
        if applicationMetrics.averageResponseTime > 0.5 {
            score -= (applicationMetrics.averageResponseTime - 0.5) * 20
        }
        
        // Error rate penalty
        score -= applicationMetrics.errorRate * 2
        
        // Recent alerts penalty
        let recentAlerts = performanceAlerts.filter { $0.timestamp.timeIntervalSinceNow > -300 }
        score -= Double(recentAlerts.count) * 5
        
        return max(0, min(100, score))
    }
}

// MARK: - Supporting Types

struct SystemMetrics {
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let timestamp: Date
    
    init(cpuUsage: Double = 0, memoryUsage: Double = 0, diskUsage: Double = 0, timestamp: Date = Date()) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskUsage = diskUsage
        self.timestamp = timestamp
    }
}

struct ApplicationMetrics {
    let averageResponseTime: Double
    let errorRate: Double
    let throughput: Double
    let activeOperations: Int
    let totalOperations: Int
    let timestamp: Date
    
    init(averageResponseTime: Double = 0, errorRate: Double = 0, throughput: Double = 0, activeOperations: Int = 0, totalOperations: Int = 0, timestamp: Date = Date()) {
        self.averageResponseTime = averageResponseTime
        self.errorRate = errorRate
        self.throughput = throughput
        self.activeOperations = activeOperations
        self.totalOperations = totalOperations
        self.timestamp = timestamp
    }
}

struct OperationMetrics {
    let id: String
    let name: String
    let category: OperationCategory
    let startTime: Date
    var endTime: Date?
    var duration: Double
    var hasError: Bool
    var errorMessage: String?
    var metadata: [String: Any]
    
    var isCompleted: Bool {
        return endTime != nil
    }
}

enum OperationCategory {
    case database
    case network
    case fileSystem
    case computation
    case ui
    case general
}

struct PerformanceAlert: Identifiable {
    let id: UUID
    let type: PerformanceAlertType
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    let metadata: [String: Any]
}

enum PerformanceAlertType {
    case highCPUUsage
    case highMemoryUsage
    case slowResponseTime
    case highErrorRate
    case slowOperation
    case memoryPressure
}

enum AlertSeverity {
    case info
    case warning
    case critical
}

struct PerformanceSnapshot {
    let timestamp: Date
    let systemMetrics: SystemMetrics
    let applicationMetrics: ApplicationMetrics
    let activeOperations: Int
}

struct ResourceUsageSnapshot {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
}

struct PerformanceStatistics {
    let timeInterval: TimeInterval
    let averageCPUUsage: Double
    let averageMemoryUsage: Double
    let averageResponseTime: Double
    let errorRate: Double
    let totalOperations: Int
    let alertCount: Int
}

struct PerformanceSummary {
    let currentSystemMetrics: SystemMetrics
    let currentApplicationMetrics: ApplicationMetrics
    let recentStatistics: PerformanceStatistics
    let hourlyStatistics: PerformanceStatistics
    let activeAlerts: [PerformanceAlert]
    let performanceScore: Double
}

// MARK: - Notifications

extension Notification.Name {
    static let performanceAlertGenerated = Notification.Name("performanceAlertGenerated")
}