import Foundation
import os
import SwiftUI

/// Memory and resource management utilities
@MainActor
class MemoryManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = MemoryManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var memoryMetrics: MemoryMetrics = MemoryMetrics()
    @Published private(set) var isMemoryPressureHigh: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.time.vscode", category: "MemoryManager")
    
    // Cache management
    private var cacheRegistry: [String: CacheEntry] = [:]
    private var maxCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private var currentCacheSize: Int = 0
    
    // Memory monitoring
    private var memoryMonitorTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // Background processing
    private let backgroundQueue = DispatchQueue(label: "com.time.vscode.background", qos: .utility)
    private let heavyOperationQueue = DispatchQueue(label: "com.time.vscode.heavy", qos: .background)
    
    // Resource cleanup
    private var cleanupTimer: Timer?
    private var resourceRegistry: [String: WeakResourceReference] = [:]
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryMonitoring()
        setupPeriodicCleanup()
    }
    
    deinit {
        // We can't call async methods from deinit, so we'll just cancel our timers
        memoryMonitorTimer?.invalidate()
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Memory Monitoring
    
    private func setupMemoryMonitoring() {
        // Start periodic memory monitoring
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryMetrics()
            }
        }
        
        // Setup memory pressure monitoring
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
        
        memoryPressureSource?.resume()
        
        logger.info("Memory monitoring started")
    }
    
    private func stopMemoryMonitoring() {
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        
        logger.info("Memory monitoring stopped")
    }
    
    private func updateMemoryMetrics() {
        let metrics = getCurrentMemoryUsage()
        memoryMetrics = metrics
        
        // Check if memory usage is concerning
        let memoryPressure = metrics.usedMemory > (UInt64(Double(metrics.totalMemory) * 0.8)) // 80% threshold
        
        if memoryPressure != isMemoryPressureHigh {
            isMemoryPressureHigh = memoryPressure
            
            if memoryPressure {
                logger.warning("High memory pressure detected: \(metrics.usedMemory / 1024 / 1024)MB used")
                performEmergencyCleanup()
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> MemoryMetrics {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let usedMemory: UInt64
        let totalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
        
        if result == KERN_SUCCESS {
            usedMemory = UInt64(info.resident_size)
        } else {
            usedMemory = 0
            logger.error("Failed to get memory usage information")
        }
        
        return MemoryMetrics(
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            cacheSize: UInt64(currentCacheSize),
            timestamp: Date()
        )
    }
    
    private func handleMemoryPressure() {
        logger.warning("System memory pressure detected, performing cleanup...")
        
        isMemoryPressureHigh = true
        performEmergencyCleanup()
        
        // Notify other components about memory pressure
        NotificationCenter.default.post(
            name: .memoryPressureDetected,
            object: self,
            userInfo: ["metrics": memoryMetrics]
        )
    }
    
    // MARK: - Cache Management
    
    /// Registers a cache entry for management
    func registerCache<T>(_ data: T, forKey key: String, estimatedSize: Int) {
        let entry = CacheEntry(
            data: data,
            size: estimatedSize,
            accessTime: Date(),
            hitCount: 0
        )
        
        // Remove old entry if exists
        if let oldEntry = cacheRegistry[key] {
            currentCacheSize -= oldEntry.size
        }
        
        cacheRegistry[key] = entry
        currentCacheSize += estimatedSize
        
        // Check if we need to evict entries
        if currentCacheSize > maxCacheSize {
            evictLeastRecentlyUsedEntries()
        }
        
        logger.debug("Registered cache entry: \(key) (\(estimatedSize) bytes)")
    }
    
    /// Retrieves data from cache
    func getCachedData<T>(forKey key: String, as type: T.Type) -> T? {
        guard let entry = cacheRegistry[key] else {
            return nil
        }
        
        // Update access statistics
        entry.accessTime = Date()
        entry.hitCount += 1
        
        return entry.data as? T
    }
    
    /// Removes specific cache entry
    func removeCacheEntry(forKey key: String) {
        if let entry = cacheRegistry.removeValue(forKey: key) {
            currentCacheSize -= entry.size
            logger.debug("Removed cache entry: \(key)")
        }
    }
    
    /// Clears all cache entries
    func clearAllCaches() {
        let entryCount = cacheRegistry.count
        let totalSize = currentCacheSize
        
        cacheRegistry.removeAll()
        currentCacheSize = 0
        
        logger.info("Cleared all cache entries: \(entryCount) entries, \(totalSize) bytes")
    }
    
    private func evictLeastRecentlyUsedEntries() {
        let targetSize = maxCacheSize * 3 / 4 // Reduce to 75% of max
        
        // Sort by access time (oldest first)
        let sortedEntries = cacheRegistry.sorted { $0.value.accessTime < $1.value.accessTime }
        
        var evictedCount = 0
        var evictedSize = 0
        
        for (key, entry) in sortedEntries {
            if currentCacheSize <= targetSize {
                break
            }
            
            cacheRegistry.removeValue(forKey: key)
            currentCacheSize -= entry.size
            evictedCount += 1
            evictedSize += entry.size
        }
        
        if evictedCount > 0 {
            logger.info("Evicted \(evictedCount) cache entries (\(evictedSize) bytes) due to memory pressure")
        }
    }
    
    // MARK: - Background Processing
    
    /// Executes heavy operations in background queue
    func executeHeavyOperation<T>(_ operation: @escaping () throws -> T) async throws -> T {
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
    
    /// Executes background operations with lower priority
    func executeBackgroundOperation<T>(_ operation: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundQueue.async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Batches multiple operations for efficient execution
    func executeBatchedOperations<T>(_ operations: [() throws -> T]) async throws -> [T] {
        return try await executeHeavyOperation {
            var results: [T] = []
            results.reserveCapacity(operations.count)
            
            for operation in operations {
                let result = try operation()
                results.append(result)
            }
            
            return results
        }
    }
    
    // MARK: - Resource Management
    
    /// Registers a resource for automatic cleanup
    func registerResource<T: AnyObject>(_ resource: T, withKey key: String) {
        resourceRegistry[key] = WeakResourceReference(resource: resource)
        logger.debug("Registered resource: \(key)")
    }
    
    /// Unregisters a resource
    func unregisterResource(withKey key: String) {
        resourceRegistry.removeValue(forKey: key)
        logger.debug("Unregistered resource: \(key)")
    }
    
    /// Gets registered resource
    func getResource<T: AnyObject>(withKey key: String, as type: T.Type) -> T? {
        return resourceRegistry[key]?.resource as? T
    }
    
    private func setupPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicCleanup()
            }
        }
        
        logger.info("Periodic cleanup started")
    }
    
    private func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        logger.info("Periodic cleanup stopped")
    }
    
    private func performPeriodicCleanup() {
        logger.debug("Performing periodic cleanup...")
        
        // Clean up deallocated resources
        let initialResourceCount = resourceRegistry.count
        resourceRegistry = resourceRegistry.compactMapValues { reference in
            reference.resource != nil ? reference : nil
        }
        
        let cleanedResources = initialResourceCount - resourceRegistry.count
        if cleanedResources > 0 {
            logger.debug("Cleaned up \(cleanedResources) deallocated resources")
        }
        
        // Clean up old cache entries if memory pressure is moderate
        if currentCacheSize > maxCacheSize / 2 {
            cleanupOldCacheEntries()
        }
        
        // Update memory metrics
        updateMemoryMetrics()
    }
    
    private func performEmergencyCleanup() {
        logger.warning("Performing emergency memory cleanup...")
        
        // Clear non-essential caches
        let nonEssentialKeys = cacheRegistry.keys.filter { key in
            !key.hasPrefix("essential_") // Keep essential caches
        }
        
        var freedMemory = 0
        for key in nonEssentialKeys {
            if let entry = cacheRegistry.removeValue(forKey: key) {
                currentCacheSize -= entry.size
                freedMemory += entry.size
            }
        }
        
        // Force garbage collection
        autoreleasepool {
            // Trigger autorelease pool drain
        }
        
        logger.warning("Emergency cleanup freed \(freedMemory) bytes")
        
        // Notify components to reduce memory usage
        NotificationCenter.default.post(
            name: .emergencyMemoryCleanup,
            object: self,
            userInfo: ["freedMemory": freedMemory]
        )
    }
    
    private func cleanupOldCacheEntries() {
        let cutoffTime = Date().addingTimeInterval(-1800) // 30 minutes ago
        
        let oldEntries = cacheRegistry.filter { $0.value.accessTime < cutoffTime }
        
        var cleanedSize = 0
        for (key, entry) in oldEntries {
            cacheRegistry.removeValue(forKey: key)
            currentCacheSize -= entry.size
            cleanedSize += entry.size
        }
        
        if cleanedSize > 0 {
            logger.debug("Cleaned up old cache entries: \(cleanedSize) bytes")
        }
    }
    
    // MARK: - Memory Optimization Utilities
    
    /// Optimizes memory usage for large datasets
    func optimizeForLargeDataset() {
        logger.info("Optimizing memory for large dataset...")
        
        // Reduce cache size temporarily
        let originalMaxSize = maxCacheSize
        maxCacheSize = maxCacheSize / 2
        
        // Clear non-essential caches
        evictLeastRecentlyUsedEntries()
        
        // Schedule restoration of cache size
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            self?.maxCacheSize = originalMaxSize
            self?.logger.info("Cache size restored after large dataset operation")
        }
    }
    
    /// Creates memory-efficient data processing pipeline
    func createMemoryEfficientPipeline<Input, Output>(
        chunkSize: Int = 1000,
        processor: @escaping ([Input]) throws -> [Output]
    ) -> ([Input]) async throws -> [Output] {
        return { inputs in
            var results: [Output] = []
            results.reserveCapacity(inputs.count)
            
            // Process in chunks to avoid memory spikes
            for chunk in inputs.chunked(into: chunkSize) {
                let chunkResults = try await self.executeBackgroundOperation {
                    try processor(chunk)
                }
                results.append(contentsOf: chunkResults)
                
                // Allow memory cleanup between chunks
                if results.count % (chunkSize * 5) == 0 {
                    await Task.yield()
                }
            }
            
            return results
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// Gets current memory performance metrics
    func getMemoryPerformanceMetrics() -> MemoryPerformanceMetrics {
        return MemoryPerformanceMetrics(
            currentMemoryUsage: memoryMetrics.usedMemory,
            totalMemory: memoryMetrics.totalMemory,
            cacheSize: UInt64(currentCacheSize),
            cacheEntryCount: cacheRegistry.count,
            resourceCount: resourceRegistry.count,
            isMemoryPressureHigh: isMemoryPressureHigh,
            memoryEfficiency: calculateMemoryEfficiency()
        )
    }
    
    private func calculateMemoryEfficiency() -> Double {
        guard memoryMetrics.totalMemory > 0 else { return 0 }
        
        let usageRatio = Double(memoryMetrics.usedMemory) / Double(memoryMetrics.totalMemory)
        
        // Efficiency is inverse of usage ratio, with optimal range around 0.3-0.7
        if usageRatio < 0.3 {
            return 1.0 - (0.3 - usageRatio) // Penalty for underutilization
        } else if usageRatio > 0.7 {
            return 1.0 - (usageRatio - 0.7) * 2 // Higher penalty for overutilization
        } else {
            return 1.0 // Optimal range
        }
    }
}

// MARK: - Supporting Types

struct MemoryMetrics {
    let usedMemory: UInt64
    let totalMemory: UInt64
    let cacheSize: UInt64
    let timestamp: Date
    
    init(usedMemory: UInt64 = 0, totalMemory: UInt64 = 0, cacheSize: UInt64 = 0, timestamp: Date = Date()) {
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
        self.cacheSize = cacheSize
        self.timestamp = timestamp
    }
}

struct MemoryPerformanceMetrics {
    let currentMemoryUsage: UInt64
    let totalMemory: UInt64
    let cacheSize: UInt64
    let cacheEntryCount: Int
    let resourceCount: Int
    let isMemoryPressureHigh: Bool
    let memoryEfficiency: Double
}

class CacheEntry {
    let data: Any
    let size: Int
    var accessTime: Date
    var hitCount: Int
    
    init(data: Any, size: Int, accessTime: Date, hitCount: Int = 0) {
        self.data = data
        self.size = size
        self.accessTime = accessTime
        self.hitCount = hitCount
    }
}

class WeakResourceReference {
    weak var resource: AnyObject?
    
    init(resource: AnyObject) {
        self.resource = resource
    }
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryPressureDetected = Notification.Name("memoryPressureDetected")
    static let emergencyMemoryCleanup = Notification.Name("emergencyMemoryCleanup")
}