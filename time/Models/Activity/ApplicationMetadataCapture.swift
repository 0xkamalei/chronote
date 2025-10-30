import AppKit
import Foundation
import os.log

/// Handles application metadata capture including names, bundle IDs, and icons
/// Provides efficient caching and fallback mechanisms for missing data
@MainActor
class ApplicationMetadataCapture {
    // MARK: - Singleton
    
    static let shared = ApplicationMetadataCapture()
    
    // MARK: - Private Properties
    
    private var metadataCache: [String: ApplicationMetadata] = [:]
    private var iconCache: [String: NSImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.time-vscode.metadata-cache", qos: .utility)
    
    private let logger = Logger(subsystem: "com.time-vscode.ApplicationMetadataCapture", category: "MetadataCapture")
    
    // Cache configuration
    private let maxCacheSize = 500
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    
    // MARK: - Initialization
    
    private init() {
        logger.info("ApplicationMetadataCapture initialized")
        setupCacheCleanupTimer()
    }
    
    // MARK: - Public Methods
    
    /// Extract comprehensive application metadata from NSRunningApplication
    /// - Parameter app: The running application to extract metadata from
    /// - Returns: Complete application metadata with fallbacks applied
    func extractApplicationMetadata(from app: NSRunningApplication) -> ApplicationMetadata {
        let bundleId = app.bundleIdentifier ?? "unknown.app.\(app.processIdentifier)"
        
        // Check cache first
        if let cachedMetadata = getCachedMetadata(for: bundleId) {
            logger.debug("Using cached metadata for: \(bundleId)")
            return cachedMetadata
        }
        
        logger.debug("Extracting metadata for: \(bundleId)")
        
        // Extract all metadata components
        let appName = extractApplicationName(from: app)
        let localizedName = extractLocalizedName(from: app)
        let displayName = extractDisplayName(from: app, bundleId: bundleId)
        let icon = extractApplicationIcon(from: app, bundleId: bundleId)
        let version = extractApplicationVersion(from: app, bundleId: bundleId)
        let path = extractApplicationPath(from: app, bundleId: bundleId)
        
        let metadata = ApplicationMetadata(
            bundleId: bundleId,
            appName: appName,
            localizedName: localizedName,
            displayName: displayName,
            icon: icon,
            version: version,
            path: path,
            processIdentifier: app.processIdentifier,
            lastUpdated: Date()
        )
        
        // Cache the metadata
        cacheMetadata(metadata, for: bundleId)
        
        logger.debug("Extracted metadata for \(appName) (\(bundleId))")
        return metadata
    }
    
    /// Get application icon with caching and fallback mechanisms
    /// - Parameters:
    ///   - bundleId: The bundle identifier of the application
    ///   - fallbackName: Optional fallback name for icon lookup
    /// - Returns: NSImage of the application icon or default icon
    func getApplicationIcon(bundleId: String, fallbackName: String? = nil) -> NSImage {
        // Check icon cache first
        if let cachedIcon = iconCache[bundleId] {
            return cachedIcon
        }
        
        var icon: NSImage?
        
        // Try to get icon from bundle
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL) {
            
            // Try bundle icon file
            if let iconFileName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
                icon = bundle.image(forResource: iconFileName)
            }
            
            // Try bundle icon name
            if icon == nil,
               let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String {
                icon = NSImage(named: iconName)
            }
        }
        
        // Try workspace icon
        if icon == nil {
            if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            }
        }
        
        // Try fallback name
        if icon == nil, let fallbackName = fallbackName {
            icon = NSImage(named: fallbackName)
        }
        
        // Use default application icon as final fallback
        let finalIcon = icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Application") ?? NSImage()
        
        // Cache the icon
        iconCache[bundleId] = finalIcon
        
        // Manage cache size
        if iconCache.count > maxCacheSize {
            cleanupIconCache()
        }
        
        return finalIcon
    }
    
    /// Clear all cached metadata and icons
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.metadataCache.removeAll()
            DispatchQueue.main.async {
                self?.iconCache.removeAll()
                self?.logger.info("Cleared all metadata and icon caches")
            }
        }
    }
    
    /// Get cache statistics for monitoring
    func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            metadataCacheSize: metadataCache.count,
            iconCacheSize: iconCache.count,
            maxCacheSize: maxCacheSize,
            cacheExpirationTime: cacheExpirationTime
        )
    }
    
    // MARK: - Private Methods - Metadata Extraction
    
    /// Extract application name with multiple fallback strategies
    private func extractApplicationName(from app: NSRunningApplication) -> String {
        // Try localized name first
        if let localizedName = app.localizedName, !localizedName.isEmpty {
            return localizedName
        }
        
        // Try bundle display name
        if let bundleId = app.bundleIdentifier,
           let displayName = extractDisplayName(from: app, bundleId: bundleId),
           !displayName.isEmpty {
            return displayName
        }
        
        // Try executable name
        if let executableURL = app.executableURL {
            let executableName = executableURL.lastPathComponent
            if !executableName.isEmpty {
                return executableName
            }
        }
        
        // Final fallback to bundle ID or process ID
        return app.bundleIdentifier ?? "Process \(app.processIdentifier)"
    }
    
    /// Extract localized application name
    private func extractLocalizedName(from app: NSRunningApplication) -> String? {
        return app.localizedName
    }
    
    /// Extract display name from bundle information
    private func extractDisplayName(from app: NSRunningApplication, bundleId: String) -> String? {
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
              let bundle = Bundle(url: bundleURL) else {
            return nil
        }
        
        // Try CFBundleDisplayName first
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        
        // Try CFBundleName
        if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        
        // Try to derive from bundle ID
        let components = bundleId.components(separatedBy: ".")
        if let lastComponent = components.last, !lastComponent.isEmpty {
            return lastComponent.prefix(1).uppercased() + lastComponent.dropFirst()
        }
        
        return nil
    }
    
    /// Extract application version information
    private func extractApplicationVersion(from app: NSRunningApplication, bundleId: String) -> String? {
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
              let bundle = Bundle(url: bundleURL) else {
            return nil
        }
        
        // Try CFBundleShortVersionString first
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return version
        }
        
        // Try CFBundleVersion
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            return version
        }
        
        return nil
    }
    
    /// Extract application path
    private func extractApplicationPath(from app: NSRunningApplication, bundleId: String) -> String? {
        // Try bundle URL first
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return bundleURL.path
        }
        
        // Try executable URL
        if let executableURL = app.executableURL {
            return executableURL.path
        }
        
        return nil
    }
    
    /// Extract application icon with multiple fallback strategies
    private func extractApplicationIcon(from app: NSRunningApplication, bundleId: String) -> NSImage {
        return getApplicationIcon(bundleId: bundleId, fallbackName: app.localizedName)
    }
    
    // MARK: - Private Methods - Caching
    
    /// Get cached metadata if available and not expired
    private func getCachedMetadata(for bundleId: String) -> ApplicationMetadata? {
        guard let metadata = metadataCache[bundleId] else {
            return nil
        }
        
        // Check if cache entry is expired
        let age = Date().timeIntervalSince(metadata.lastUpdated)
        if age > cacheExpirationTime {
            metadataCache.removeValue(forKey: bundleId)
            return nil
        }
        
        return metadata
    }
    
    /// Cache metadata for future use
    private func cacheMetadata(_ metadata: ApplicationMetadata, for bundleId: String) {
        cacheQueue.async { [weak self] in
            self?.metadataCache[bundleId] = metadata
            
            // Manage cache size
            if let self = self, self.metadataCache.count > self.maxCacheSize {
                self.cleanupMetadataCache()
            }
        }
    }
    
    /// Clean up expired metadata cache entries
    private func cleanupMetadataCache() {
        let now = Date()
        let expiredKeys = metadataCache.compactMap { key, metadata in
            now.timeIntervalSince(metadata.lastUpdated) > cacheExpirationTime ? key : nil
        }
        
        for key in expiredKeys {
            metadataCache.removeValue(forKey: key)
        }
        
        // If still too large, remove oldest entries
        if metadataCache.count > maxCacheSize {
            let sortedEntries = metadataCache.sorted { $0.value.lastUpdated < $1.value.lastUpdated }
            let entriesToRemove = sortedEntries.prefix(metadataCache.count - maxCacheSize)
            
            for (key, _) in entriesToRemove {
                metadataCache.removeValue(forKey: key)
            }
        }
        
        logger.debug("Cleaned up metadata cache, now contains \(self.metadataCache.count) entries")
    }
    
    /// Clean up icon cache when it gets too large
    private func cleanupIconCache() {
        // Remove random entries to get back to reasonable size
        let targetSize = maxCacheSize * 3 / 4 // Remove 25% of entries
        let keysToRemove = Array(iconCache.keys.shuffled().prefix(iconCache.count - targetSize))
        
        for key in keysToRemove {
            iconCache.removeValue(forKey: key)
        }
        
        logger.debug("Cleaned up icon cache, now contains \(self.iconCache.count) entries")
    }
    
    /// Setup periodic cache cleanup
    private func setupCacheCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: cacheExpirationTime / 2, repeats: true) { [weak self] _ in
            self?.cacheQueue.async {
                self?.cleanupMetadataCache()
            }
        }
    }
    
    // MARK: - Supporting Types
    
    /// Complete application metadata structure
    struct ApplicationMetadata {
        let bundleId: String
        let appName: String
        let localizedName: String?
        let displayName: String?
        let icon: NSImage
        let version: String?
        let path: String?
        let processIdentifier: pid_t
        let lastUpdated: Date
        
        /// Get the best available name for display
        var bestDisplayName: String {
            return displayName ?? localizedName ?? appName
        }
        
        /// Get a short identifier for the application
        var shortIdentifier: String {
            if let lastComponent = bundleId.components(separatedBy: ".").last {
                return lastComponent
            }
            return bundleId
        }
    }
    
    /// Cache statistics for monitoring
    struct CacheStatistics {
        let metadataCacheSize: Int
        let iconCacheSize: Int
        let maxCacheSize: Int
        let cacheExpirationTime: TimeInterval
        
        var totalCacheSize: Int {
            return metadataCacheSize + iconCacheSize
        }
        
        var cacheUtilization: Double {
            return Double(totalCacheSize) / Double(maxCacheSize * 2) // Both metadata and icon caches
        }
    }
}