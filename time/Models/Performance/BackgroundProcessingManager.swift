import Foundation
import os
import SwiftUI

/// Manages background processing and threading for performance optimization
@MainActor
class BackgroundProcessingManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = BackgroundProcessingManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var processingMetrics: ProcessingMetrics = ProcessingMetrics()
    @Published private(set) var activeOperations: [BackgroundOperation] = []
    @Published private(set) var isProcessingHeavyOperations: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.time.vscode", category: "BackgroundProcessing")
    
    // Queue management
    private let backgroundQueue = DispatchQueue(label: "com.time.vscode.background", qos: .utility, attributes: .concurrent)
    private let heavyOperationQueue = DispatchQueue(label: "com.time.vscode.heavy", qos: .background, attributes: .concurrent)
    private let dataProcessingQueue = DispatchQueue(label: "com.time.vscode.dataProcessing", qos: .userInitiated, attributes: .concurrent)
    
    // Operation tracking
    private var operationCounter: Int = 0
    private let operationCounterLock = NSLock()
    
    // Throttling and rate limiting
    private var operationThrottler: OperationThrottler = OperationThrottler()
    private var rateLimiter: RateLimiter = RateLimiter()
    
    // Performance monitoring
    private var performanceTracker: BackgroundPerformanceTracker = BackgroundPerformanceTracker()
    
    // MARK: - Initialization
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - Background Operation Execution
    
    /// Executes a lightweight background operation
    func executeBackgroundOperation<T>(
        _ operation: @escaping () throws -> T,
        priority: TaskPriority = .medium,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let operationId = generateOperationId()
        let backgroundOp = BackgroundOperation(
            id: operationId,
            type: .background,
            priority: priority,
            startTime: Date()
        )
        
        await addActiveOperation(backgroundOp)
        
        defer {
            Task { @MainActor in
                await self.removeActiveOperation(operationId)
            }
        }
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await withCheckedThrowingContinuation { continuation in
                    self.backgroundQueue.async {
                        do {
                            let result = try operation()
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
            
            // Add timeout task if specified
            if let timeout = timeout {
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw BackgroundProcessingError.timeout
                }
            }
            
            // Return the first completed task (either operation or timeout)
            guard let result = try await group.next() else {
                throw BackgroundProcessingError.operationFailed
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Executes a heavy computational operation
    func executeHeavyOperation<T>(
        _ operation: @escaping () throws -> T,
        priority: TaskPriority = .low,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws -> T {
        // Check if we should throttle heavy operations
        guard await operationThrottler.shouldAllowOperation(.heavy) else {
            throw BackgroundProcessingError.throttled
        }
        
        let operationId = generateOperationId()
        let heavyOp = BackgroundOperation(
            id: operationId,
            type: .heavy,
            priority: priority,
            startTime: Date()
        )
        
        await addActiveOperation(heavyOp)
        isProcessingHeavyOperations = true
        
        defer {
            Task { @MainActor in
                await self.removeActiveOperation(operationId)
                self.updateHeavyOperationStatus()
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            heavyOperationQueue.async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Executes data processing operations with memory optimization
    func executeDataProcessing<Input, Output>(
        input: [Input],
        chunkSize: Int = 1000,
        processor: @escaping ([Input]) throws -> [Output],
        progressCallback: ((Double) -> Void)? = nil
    ) async throws -> [Output] {
        let operationId = generateOperationId()
        let dataOp = BackgroundOperation(
            id: operationId,
            type: .dataProcessing,
            priority: .medium,
            startTime: Date()
        )
        
        await addActiveOperation(dataOp)
        
        defer {
            Task { @MainActor in
                await self.removeActiveOperation(operationId)
            }
        }
        
        var results: [Output] = []
        results.reserveCapacity(input.count)
        
        let chunks = input.chunked(into: chunkSize)
        let totalChunks = chunks.count
        
        for (index, chunk) in chunks.enumerated() {
            // Process chunk in background
            let chunkResults = try await withCheckedThrowingContinuation { continuation in
                dataProcessingQueue.async {
                    do {
                        let result = try processor(chunk)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            results.append(contentsOf: chunkResults)
            
            // Update progress
            let progress = Double(index + 1) / Double(totalChunks)
            progressCallback?(progress)
            
            // Allow other operations to run between chunks
            if index % 5 == 0 {
                await Task.yield()
            }
        }
        
        return results
    }
    
    /// Executes batch operations with automatic batching and throttling
    func executeBatchOperations<T>(
        operations: [() throws -> T],
        batchSize: Int = 10,
        delayBetweenBatches: TimeInterval = 0.1
    ) async throws -> [T] {
        let operationId = generateOperationId()
        let batchOp = BackgroundOperation(
            id: operationId,
            type: .batch,
            priority: .medium,
            startTime: Date()
        )
        
        await addActiveOperation(batchOp)
        
        defer {
            Task { @MainActor in
                await self.removeActiveOperation(operationId)
            }
        }
        
        var results: [T] = []
        results.reserveCapacity(operations.count)
        
        let batches = operations.chunked(into: batchSize)
        
        for batch in batches {
            // Execute batch in parallel
            let batchResults = try await withThrowingTaskGroup(of: T.self) { group in
                for operation in batch {
                    group.addTask {
                        return try await self.executeBackgroundOperation(operation)
                    }
                }
                
                var batchResults: [T] = []
                for try await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
            
            results.append(contentsOf: batchResults)
            
            // Delay between batches to prevent overwhelming the system
            if delayBetweenBatches > 0 {
                try await Task.sleep(nanoseconds: UInt64(delayBetweenBatches * 1_000_000_000))
            }
        }
        
        return results
    }
    
    // MARK: - Concurrent Operations
    
    /// Executes multiple operations concurrently with automatic load balancing
    func executeConcurrentOperations<T>(
        operations: [() async throws -> T],
        maxConcurrency: Int? = nil
    ) async throws -> [T] {
        let effectiveMaxConcurrency = maxConcurrency ?? min(operations.count, ProcessInfo.processInfo.activeProcessorCount)
        
        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var results: [T?] = Array(repeating: nil, count: operations.count)
            var currentIndex = 0
            
            // Start initial batch of operations
            for _ in 0..<min(effectiveMaxConcurrency, operations.count) {
                let index = currentIndex
                currentIndex += 1
                
                group.addTask {
                    let result = try await operations[index]()
                    return (index, result)
                }
            }
            
            // Process results and start new operations
            while let (index, result) = try await group.next() {
                results[index] = result
                
                // Start next operation if available
                if currentIndex < operations.count {
                    let nextIndex = currentIndex
                    currentIndex += 1
                    
                    group.addTask {
                        let result = try await operations[nextIndex]()
                        return (nextIndex, result)
                    }
                }
            }
            
            return results.compactMap { $0 }
        }
    }
    
    // MARK: - Memory-Efficient Processing
    
    /// Creates a memory-efficient processing pipeline
    func createProcessingPipeline<Input, Output>(
        chunkSize: Int = 1000,
        maxMemoryUsage: Int = 50 * 1024 * 1024, // 50MB
        processor: @escaping ([Input]) async throws -> [Output]
    ) -> ([Input]) async throws -> [Output] {
        return { inputs in
            var results: [Output] = []
            let chunks = inputs.chunked(into: chunkSize)
            
            for chunk in chunks {
                // Check memory usage before processing
                let currentMemory = await MemoryManager.shared.getMemoryPerformanceMetrics().currentMemoryUsage
                
                if currentMemory > maxMemoryUsage {
                    // Wait for memory to be freed
                    await MemoryManager.shared.clearAllCaches()
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                
                let chunkResults = try await processor(chunk)
                results.append(contentsOf: chunkResults)
                
                // Allow garbage collection between chunks
                await Task.yield()
            }
            
            return results
        }
    }
    
    // MARK: - Operation Management
    
    private func addActiveOperation(_ operation: BackgroundOperation) async {
        activeOperations.append(operation)
        processingMetrics.totalOperations += 1
        
        // Update metrics
        updateProcessingMetrics()
    }
    
    private func removeActiveOperation(_ operationId: String) async {
        if let index = activeOperations.firstIndex(where: { $0.id == operationId }) {
            let operation = activeOperations.remove(at: index)
            
            // Update completion metrics
            let duration = Date().timeIntervalSince(operation.startTime)
            processingMetrics.totalProcessingTime += duration
            processingMetrics.averageOperationDuration = processingMetrics.totalProcessingTime / Double(processingMetrics.totalOperations)
            
            if duration > processingMetrics.longestOperationDuration {
                processingMetrics.longestOperationDuration = duration
            }
        }
        
        updateProcessingMetrics()
    }
    
    private func updateHeavyOperationStatus() {
        isProcessingHeavyOperations = activeOperations.contains { $0.type == .heavy }
    }
    
    private func updateProcessingMetrics() {
        processingMetrics.activeOperationCount = activeOperations.count
        processingMetrics.heavyOperationCount = activeOperations.filter { $0.type == .heavy }.count
        processingMetrics.lastUpdateTime = Date()
    }
    
    private func generateOperationId() -> String {
        operationCounterLock.lock()
        defer { operationCounterLock.unlock() }
        
        operationCounter += 1
        return "op_\(operationCounter)_\(Date().timeIntervalSince1970)"
    }
    
    // MARK: - Performance Monitoring
    
    private func setupPerformanceMonitoring() {
        // Monitor queue performance
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performanceTracker.updateMetrics()
            }
        }
    }
    
    /// Gets current processing performance metrics
    func getProcessingMetrics() -> ProcessingMetrics {
        return processingMetrics
    }
    
    /// Gets queue performance statistics
    func getQueueStatistics() -> QueueStatistics {
        return QueueStatistics(
            backgroundQueueLoad: performanceTracker.getQueueLoad(.background),
            heavyQueueLoad: performanceTracker.getQueueLoad(.heavy),
            dataProcessingQueueLoad: performanceTracker.getQueueLoad(.dataProcessing),
            averageWaitTime: performanceTracker.averageWaitTime,
            throughput: performanceTracker.throughput
        )
    }
    
    // MARK: - Throttling and Rate Limiting
    
    /// Configures operation throttling
    func configureThrottling(maxConcurrentOperations: Int, maxHeavyOperations: Int) {
        operationThrottler.configure(
            maxConcurrentOperations: maxConcurrentOperations,
            maxHeavyOperations: maxHeavyOperations
        )
    }
    
    /// Configures rate limiting
    func configureRateLimit(operationsPerSecond: Double) {
        rateLimiter.configure(operationsPerSecond: operationsPerSecond)
    }
    
    // MARK: - Cleanup and Shutdown
    
    /// Cancels all active operations
    func cancelAllOperations() async {
        logger.warning("Cancelling all active operations")
        
        let operationIds = activeOperations.map { $0.id }
        
        for operationId in operationIds {
            await removeActiveOperation(operationId)
        }
        
        activeOperations.removeAll()
        isProcessingHeavyOperations = false
        
        logger.info("All operations cancelled")
    }
    
    /// Waits for all active operations to complete
    func waitForCompletion(timeout: TimeInterval = 30.0) async throws {
        let startTime = Date()
        
        while !activeOperations.isEmpty {
            if Date().timeIntervalSince(startTime) > timeout {
                throw BackgroundProcessingError.timeout
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}

// MARK: - Supporting Types

struct ProcessingMetrics {
    var totalOperations: Int = 0
    var activeOperationCount: Int = 0
    var heavyOperationCount: Int = 0
    var totalProcessingTime: TimeInterval = 0
    var averageOperationDuration: TimeInterval = 0
    var longestOperationDuration: TimeInterval = 0
    var lastUpdateTime: Date = Date()
}

struct QueueStatistics {
    let backgroundQueueLoad: Double
    let heavyQueueLoad: Double
    let dataProcessingQueueLoad: Double
    let averageWaitTime: TimeInterval
    let throughput: Double
}

struct BackgroundOperation: Identifiable {
    let id: String
    let type: OperationType
    let priority: TaskPriority
    let startTime: Date
    var progress: Double = 0.0
    
    var duration: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
}

enum OperationType {
    case background
    case heavy
    case dataProcessing
    case batch
}

enum BackgroundProcessingError: LocalizedError {
    case timeout
    case throttled
    case operationFailed
    case memoryPressure
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out"
        case .throttled:
            return "Operation was throttled due to system load"
        case .operationFailed:
            return "Background operation failed"
        case .memoryPressure:
            return "Operation cancelled due to memory pressure"
        }
    }
}

// MARK: - Throttling and Rate Limiting

class OperationThrottler {
    private var maxConcurrentOperations: Int = 10
    private var maxHeavyOperations: Int = 2
    private var currentOperations: Int = 0
    private var currentHeavyOperations: Int = 0
    private let lock = NSLock()
    
    func configure(maxConcurrentOperations: Int, maxHeavyOperations: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        self.maxConcurrentOperations = maxConcurrentOperations
        self.maxHeavyOperations = maxHeavyOperations
    }
    
    func shouldAllowOperation(_ type: OperationType) async -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        switch type {
        case .heavy:
            return currentHeavyOperations < maxHeavyOperations && currentOperations < maxConcurrentOperations
        default:
            return currentOperations < maxConcurrentOperations
        }
    }
    
    func operationStarted(_ type: OperationType) {
        lock.lock()
        defer { lock.unlock() }
        
        currentOperations += 1
        if type == .heavy {
            currentHeavyOperations += 1
        }
    }
    
    func operationCompleted(_ type: OperationType) {
        lock.lock()
        defer { lock.unlock() }
        
        currentOperations = max(0, currentOperations - 1)
        if type == .heavy {
            currentHeavyOperations = max(0, currentHeavyOperations - 1)
        }
    }
}

class RateLimiter {
    private var operationsPerSecond: Double = 10.0
    private var lastOperationTime: Date = Date()
    private let lock = NSLock()
    
    func configure(operationsPerSecond: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        self.operationsPerSecond = operationsPerSecond
    }
    
    func shouldAllowOperation() async -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let timeSinceLastOperation = now.timeIntervalSince(lastOperationTime)
        let minimumInterval = 1.0 / operationsPerSecond
        
        if timeSinceLastOperation >= minimumInterval {
            lastOperationTime = now
            return true
        }
        
        return false
    }
}

// MARK: - Performance Tracking

class BackgroundPerformanceTracker {
    private var queueLoads: [OperationType: Double] = [:]
    private var operationHistory: [Date] = []
    private let historyLimit = 1000
    
    var averageWaitTime: TimeInterval = 0
    var throughput: Double = 0
    
    func updateMetrics() {
        // Update throughput based on recent operations
        let now = Date()
        let recentOperations = operationHistory.filter { now.timeIntervalSince($0) < 60 } // Last minute
        throughput = Double(recentOperations.count) / 60.0
        
        // Clean up old history
        operationHistory = operationHistory.filter { now.timeIntervalSince($0) < 300 } // Keep 5 minutes
    }
    
    func recordOperation() {
        operationHistory.append(Date())
        
        if operationHistory.count > historyLimit {
            operationHistory = Array(operationHistory.suffix(historyLimit / 2))
        }
    }
    
    func getQueueLoad(_ type: OperationType) -> Double {
        return queueLoads[type] ?? 0.0
    }
    
    func setQueueLoad(_ type: OperationType, load: Double) {
        queueLoads[type] = load
    }
}

