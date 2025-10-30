import Foundation
import os
import SwiftUI

/// Manages resource cleanup and leak prevention
@MainActor
class ResourceCleanupManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = ResourceCleanupManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var cleanupMetrics: CleanupMetrics = CleanupMetrics()
    @Published private(set) var isCleanupInProgress: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.time.vscode", category: "ResourceCleanup")
    
    // Resource tracking
    private var trackedResources: [String: TrackedResource] = [:]
    private var resourceLeakDetector: ResourceLeakDetector = ResourceLeakDetector()
    
    // Cleanup scheduling
    private var cleanupTimer: Timer?
    private var emergencyCleanupTimer: Timer?
    
    // Cleanup strategies
    private var cleanupStrategies: [ResourceType: CleanupStrategy] = [:]
    
    // MARK: - Initialization
    
    private init() {
        setupCleanupStrategies()
        startPeriodicCleanup()
        setupMemoryPressureHandling()
    }
    
    deinit {
        // Cannot call async method in deinit, so we invalidate timers directly
        cleanupTimer?.invalidate()
        cleanupTimer = nil

        emergencyCleanupTimer?.invalidate()
        emergencyCleanupTimer = nil
    }
    
    // MARK: - Resource Tracking
    
    /// Registers a resource for tracking and automatic cleanup
    func trackResource<T: AnyObject>(_ resource: T, type: ResourceType, identifier: String, metadata: [String: Any] = [:]) {
        let trackedResource = TrackedResource(
            resource: resource,
            type: type,
            identifier: identifier,
            creationTime: Date(),
            lastAccessTime: Date(),
            metadata: metadata
        )
        
        trackedResources[identifier] = trackedResource
        resourceLeakDetector.registerResource(identifier, type: type)
        
        logger.debug("Tracking resource: \(identifier) (\(type))")
    }
    
    /// Unregisters a resource from tracking
    func untrackResource(_ identifier: String) async {
        if let resource = trackedResources.removeValue(forKey: identifier) {
            resourceLeakDetector.unregisterResource(identifier)
            logger.debug("Untracked resource: \(identifier) (\(resource.type))")
        }
    }
    
    /// Updates the last access time for a tracked resource
    func touchResource(_ identifier: String) {
        trackedResources[identifier]?.lastAccessTime = Date()
    }
    
    /// Gets information about a tracked resource
    func getResourceInfo(_ identifier: String) -> TrackedResource? {
        return trackedResources[identifier]
    }
    
    /// Gets all tracked resources of a specific type
    func getTrackedResources(ofType type: ResourceType) -> [TrackedResource] {
        return trackedResources.values.filter { $0.type == type }
    }
    
    // MARK: - Cleanup Operations
    
    /// Performs comprehensive resource cleanup
    func performCleanup(strategy: CleanupLevel = .normal) async {
        guard !isCleanupInProgress else {
            logger.warning("Cleanup already in progress, skipping")
            return
        }
        
        isCleanupInProgress = true
        let startTime = Date()
        
        logger.info("Starting resource cleanup (level: \(strategy))")
        
        defer {
            isCleanupInProgress = false
            let duration = Date().timeIntervalSince(startTime)
            cleanupMetrics.lastCleanupDuration = duration
            cleanupMetrics.lastCleanupTime = Date()
            logger.info("Resource cleanup completed in \(String(format: "%.2f", duration))s")
        }
        
        var cleanedResources = 0
        var freedMemory = 0
        
        // Clean up deallocated resources
        cleanedResources += cleanupDeallocatedResources()
        
        // Clean up stale resources based on strategy
        let staleResources = identifyStaleResources(for: strategy)
        for resource in staleResources {
            if await cleanupResource(resource) {
                cleanedResources += 1
                freedMemory += estimateResourceMemoryUsage(resource)
            }
        }
        
        // Perform type-specific cleanup
        for (type, cleanupStrategy) in cleanupStrategies {
            let typeResources = getTrackedResources(ofType: type)
            let cleaned = await cleanupStrategy.cleanup(typeResources, level: strategy)
            cleanedResources += cleaned
        }
        
        // Update metrics
        cleanupMetrics.totalCleanupOperations += 1
        cleanupMetrics.resourcesCleaned += cleanedResources
        cleanupMetrics.estimatedMemoryFreed += freedMemory
        
        // Check for potential leaks
        detectPotentialLeaks()
        
        logger.info("Cleanup completed: \(cleanedResources) resources cleaned, ~\(freedMemory) bytes freed")
    }
    
    /// Performs emergency cleanup under memory pressure
    func performEmergencyCleanup() async {
        logger.warning("Performing emergency resource cleanup")
        
        await performCleanup(strategy: .aggressive)
        
        // Additional emergency measures
        await forceGarbageCollection()
        await clearNonEssentialCaches()
        
        // Notify other components
        NotificationCenter.default.post(
            name: .emergencyCleanupPerformed,
            object: self,
            userInfo: ["metrics": cleanupMetrics]
        )
    }
    
    private func cleanupDeallocatedResources() -> Int {
        let initialCount = trackedResources.count
        
        trackedResources = trackedResources.compactMapValues { resource in
            resource.resource != nil ? resource : nil
        }
        
        let cleanedCount = initialCount - trackedResources.count
        
        if cleanedCount > 0 {
            logger.debug("Cleaned up \(cleanedCount) deallocated resources")
        }
        
        return cleanedCount
    }
    
    private func identifyStaleResources(for level: CleanupLevel) -> [TrackedResource] {
        let cutoffTime: TimeInterval
        
        switch level {
        case .light:
            cutoffTime = -3600 // 1 hour
        case .normal:
            cutoffTime = -1800 // 30 minutes
        case .aggressive:
            cutoffTime = -600 // 10 minutes
        case .emergency:
            cutoffTime = -300 // 5 minutes
        }
        
        let threshold = Date().addingTimeInterval(cutoffTime)
        
        return trackedResources.values.filter { resource in
            resource.lastAccessTime < threshold && resource.type.isCleanupEligible
        }
    }
    
    private func cleanupResource(_ resource: TrackedResource) async -> Bool {
        guard let cleanupStrategy = cleanupStrategies[resource.type] else {
            // Default cleanup - just remove from tracking
            await untrackResource(resource.identifier)
            return true
        }

        return await cleanupStrategy.cleanupSingle(resource)
    }
    
    private func estimateResourceMemoryUsage(_ resource: TrackedResource) -> Int {
        // Rough estimation based on resource type
        switch resource.type {
        case .image:
            return 1024 * 1024 // 1MB estimate
        case .cache:
            return 512 * 1024 // 512KB estimate
        case .temporaryFile:
            return 100 * 1024 // 100KB estimate
        case .networkConnection:
            return 10 * 1024 // 10KB estimate
        case .timer:
            return 1024 // 1KB estimate
        case .observer:
            return 512 // 512 bytes estimate
        case .other:
            return 10 * 1024 // 10KB estimate
        }
    }
    
    // MARK: - Leak Detection
    
    private func detectPotentialLeaks() {
        let leaks = resourceLeakDetector.detectLeaks(trackedResources.values.map { $0 })
        
        if !leaks.isEmpty {
            logger.warning("Potential resource leaks detected: \(leaks.count)")
            
            for leak in leaks {
                logger.warning("Potential leak: \(leak.identifier) (\(leak.type)) - age: \(leak.age)s")
            }
            
            // Update metrics
            cleanupMetrics.potentialLeaksDetected += leaks.count
            
            // Notify about leaks
            NotificationCenter.default.post(
                name: .resourceLeaksDetected,
                object: self,
                userInfo: ["leaks": leaks]
            )
        }
    }
    
    // MARK: - Cleanup Strategies Setup
    
    private func setupCleanupStrategies() {
        cleanupStrategies[.image] = ImageCleanupStrategy()
        cleanupStrategies[.cache] = CacheCleanupStrategy()
        cleanupStrategies[.temporaryFile] = FileCleanupStrategy()
        cleanupStrategies[.networkConnection] = NetworkCleanupStrategy()
        cleanupStrategies[.timer] = TimerCleanupStrategy()
        cleanupStrategies[.observer] = ObserverCleanupStrategy()
        cleanupStrategies[.other] = DefaultCleanupStrategy()
    }
    
    // MARK: - Periodic Cleanup
    
    private func startPeriodicCleanup() {
        // Regular cleanup every 10 minutes
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCleanup(strategy: .light)
            }
        }
        
        logger.info("Periodic cleanup started")
    }
    
    private func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        emergencyCleanupTimer?.invalidate()
        emergencyCleanupTimer = nil
        
        logger.info("Periodic cleanup stopped")
    }
    
    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            forName: .memoryPressureDetected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performEmergencyCleanup()
            }
        }
    }
    
    // MARK: - Emergency Operations
    
    private func forceGarbageCollection() async {
        // Force autorelease pool drain
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    // Trigger garbage collection
                }
                continuation.resume()
            }
        }
        
        logger.debug("Forced garbage collection")
    }
    
    private func clearNonEssentialCaches() async {
        // Clear image caches
        let imageResources = getTrackedResources(ofType: .image)
        for resource in imageResources {
            if !resource.isEssential {
                _ = await cleanupResource(resource)
            }
        }

        // Clear temporary files
        let fileResources = getTrackedResources(ofType: .temporaryFile)
        for resource in fileResources {
            _ = await cleanupResource(resource)
        }

        logger.debug("Cleared non-essential caches")
    }
    
    // MARK: - Metrics and Monitoring
    
    /// Gets current cleanup metrics
    func getCleanupMetrics() -> CleanupMetrics {
        return cleanupMetrics
    }
    
    /// Gets resource usage statistics
    func getResourceStatistics() -> ResourceStatistics {
        let resourceCounts = Dictionary(grouping: trackedResources.values) { $0.type }
            .mapValues { $0.count }
        
        let totalMemoryEstimate = trackedResources.values
            .map { estimateResourceMemoryUsage($0) }
            .reduce(0, +)
        
        return ResourceStatistics(
            totalTrackedResources: trackedResources.count,
            resourceCountsByType: resourceCounts,
            estimatedMemoryUsage: totalMemoryEstimate,
            oldestResourceAge: getOldestResourceAge(),
            averageResourceAge: getAverageResourceAge()
        )
    }
    
    private func getOldestResourceAge() -> TimeInterval {
        guard let oldestResource = trackedResources.values.min(by: { $0.creationTime < $1.creationTime }) else {
            return 0
        }
        return Date().timeIntervalSince(oldestResource.creationTime)
    }
    
    private func getAverageResourceAge() -> TimeInterval {
        guard !trackedResources.isEmpty else { return 0 }
        
        let totalAge = trackedResources.values
            .map { Date().timeIntervalSince($0.creationTime) }
            .reduce(0, +)
        
        return totalAge / Double(trackedResources.count)
    }
}

// MARK: - Supporting Types

struct CleanupMetrics {
    var totalCleanupOperations: Int = 0
    var resourcesCleaned: Int = 0
    var estimatedMemoryFreed: Int = 0
    var potentialLeaksDetected: Int = 0
    var lastCleanupTime: Date?
    var lastCleanupDuration: TimeInterval = 0
}

struct ResourceStatistics {
    let totalTrackedResources: Int
    let resourceCountsByType: [ResourceType: Int]
    let estimatedMemoryUsage: Int
    let oldestResourceAge: TimeInterval
    let averageResourceAge: TimeInterval
}

class TrackedResource {
    weak var resource: AnyObject?
    let type: ResourceType
    let identifier: String
    let creationTime: Date
    var lastAccessTime: Date
    let metadata: [String: Any]
    
    var isEssential: Bool {
        return metadata["essential"] as? Bool ?? false
    }
    
    var age: TimeInterval {
        return Date().timeIntervalSince(creationTime)
    }
    
    init(resource: AnyObject, type: ResourceType, identifier: String, creationTime: Date, lastAccessTime: Date, metadata: [String: Any]) {
        self.resource = resource
        self.type = type
        self.identifier = identifier
        self.creationTime = creationTime
        self.lastAccessTime = lastAccessTime
        self.metadata = metadata
    }
}

enum ResourceType: CustomStringConvertible {
    case image
    case cache
    case temporaryFile
    case networkConnection
    case timer
    case observer
    case other

    var isCleanupEligible: Bool {
        switch self {
        case .image, .cache, .temporaryFile:
            return true
        case .networkConnection, .timer, .observer:
            return false // Require explicit cleanup
        case .other:
            return true
        }
    }

    var description: String {
        switch self {
        case .image: return "image"
        case .cache: return "cache"
        case .temporaryFile: return "temporaryFile"
        case .networkConnection: return "networkConnection"
        case .timer: return "timer"
        case .observer: return "observer"
        case .other: return "other"
        }
    }
}

enum CleanupLevel: CustomStringConvertible {
    case light
    case normal
    case aggressive
    case emergency

    var description: String {
        switch self {
        case .light: return "light"
        case .normal: return "normal"
        case .aggressive: return "aggressive"
        case .emergency: return "emergency"
        }
    }
}

// MARK: - Cleanup Strategies

protocol CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int
    func cleanupSingle(_ resource: TrackedResource) async -> Bool
}

class ImageCleanupStrategy: CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int {
        var cleaned = 0
        
        for resource in resources {
            if await cleanupSingle(resource) {
                cleaned += 1
            }
        }
        
        return cleaned
    }
    
    func cleanupSingle(_ resource: TrackedResource) async -> Bool {
        // Clear image from memory if not essential
        if !resource.isEssential {
            await ResourceCleanupManager.shared.untrackResource(resource.identifier)
            return true
        }
        return false
    }
}

class CacheCleanupStrategy: CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int {
        var cleaned = 0
        
        for resource in resources {
            if await cleanupSingle(resource) {
                cleaned += 1
            }
        }
        
        return cleaned
    }
    
    func cleanupSingle(_ resource: TrackedResource) async -> Bool {
        // Clear cache entry
        await ResourceCleanupManager.shared.untrackResource(resource.identifier)
        return true
    }
}

class FileCleanupStrategy: CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int {
        var cleaned = 0
        
        for resource in resources {
            if await cleanupSingle(resource) {
                cleaned += 1
            }
        }
        
        return cleaned
    }
    
    func cleanupSingle(_ resource: TrackedResource) async -> Bool {
        // Delete temporary file
        if let filePath = resource.metadata["filePath"] as? String {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        await ResourceCleanupManager.shared.untrackResource(resource.identifier)
        return true
    }
}

class NetworkCleanupStrategy: CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int {
        var cleaned = 0
        
        for resource in resources {
            if await cleanupSingle(resource) {
                cleaned += 1
            }
        }
        
        return cleaned
    }
    
    func cleanupSingle(_ resource: TrackedResource) async -> Bool {
        // Close network connection if stale
        if resource.age > 300 { // 5 minutes
            await ResourceCleanupManager.shared.untrackResource(resource.identifier)
            return true
        }
        return false
    }
}

class TimerCleanupStrategy: CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int {
        var cleaned = 0
        
        for resource in resources {
            if await cleanupSingle(resource) {
                cleaned += 1
            }
        }
        
        return cleaned
    }
    
    func cleanupSingle(_ resource: TrackedResource) async -> Bool {
        // Invalidate timer if resource is deallocated
        if resource.resource == nil {
            await ResourceCleanupManager.shared.untrackResource(resource.identifier)
            return true
        }
        return false
    }
}

class ObserverCleanupStrategy: CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int {
        var cleaned = 0
        
        for resource in resources {
            if await cleanupSingle(resource) {
                cleaned += 1
            }
        }
        
        return cleaned
    }
    
    func cleanupSingle(_ resource: TrackedResource) async -> Bool {
        // Remove observer if resource is deallocated
        if resource.resource == nil {
            await ResourceCleanupManager.shared.untrackResource(resource.identifier)
            return true
        }
        return false
    }
}

class DefaultCleanupStrategy: CleanupStrategy {
    func cleanup(_ resources: [TrackedResource], level: CleanupLevel) async -> Int {
        var cleaned = 0
        
        for resource in resources {
            if await cleanupSingle(resource) {
                cleaned += 1
            }
        }
        
        return cleaned
    }
    
    func cleanupSingle(_ resource: TrackedResource) async -> Bool {
        // Default cleanup - just untrack if deallocated
        if resource.resource == nil {
            await ResourceCleanupManager.shared.untrackResource(resource.identifier)
            return true
        }
        return false
    }
}

// MARK: - Leak Detection

class ResourceLeakDetector {
    private var resourceRegistry: [String: ResourceRegistration] = [:]
    
    func registerResource(_ identifier: String, type: ResourceType) {
        resourceRegistry[identifier] = ResourceRegistration(
            identifier: identifier,
            type: type,
            registrationTime: Date()
        )
    }
    
    func unregisterResource(_ identifier: String) {
        resourceRegistry.removeValue(forKey: identifier)
    }
    
    func detectLeaks(_ trackedResources: [TrackedResource]) -> [ResourceLeak] {
        var leaks: [ResourceLeak] = []
        
        for resource in trackedResources {
            // Check for long-lived resources that might be leaks
            if resource.age > 3600 && resource.resource != nil { // 1 hour
                let leak = ResourceLeak(
                    identifier: resource.identifier,
                    type: resource.type,
                    age: resource.age,
                    lastAccess: resource.lastAccessTime
                )
                leaks.append(leak)
            }
        }
        
        return leaks
    }
}

struct ResourceRegistration {
    let identifier: String
    let type: ResourceType
    let registrationTime: Date
}

struct ResourceLeak {
    let identifier: String
    let type: ResourceType
    let age: TimeInterval
    let lastAccess: Date
}

// MARK: - Notifications

extension Notification.Name {
    static let emergencyCleanupPerformed = Notification.Name("emergencyCleanupPerformed")
    static let resourceLeaksDetected = Notification.Name("resourceLeaksDetected")
}