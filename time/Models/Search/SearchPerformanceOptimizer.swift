import Foundation
import SwiftData
import os.log

/// Performance optimization utilities for search operations
class SearchPerformanceOptimizer {
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.timetracking.search", category: "Performance")
    private var queryCache: [String: CachedSearchResult] = [:]
    private let maxCacheSize = 50
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    // Performance metrics
    private var searchMetrics: SearchMetrics = SearchMetrics()
    
    // MARK: - Cache Management
    
    /// Cached search result with expiration
    private struct CachedSearchResult {
        let results: SearchResults
        let timestamp: Date
        let queryHash: String
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    
    /// Gets cached search results if available and not expired
    func getCachedResults(for query: String, filters: SearchFilters) -> SearchResults? {
        let cacheKey = generateCacheKey(query: query, filters: filters)
        
        guard let cached = queryCache[cacheKey] else {
            return nil
        }
        
        if cached.isExpired {
            queryCache.removeValue(forKey: cacheKey)
            return nil
        }
        
        logger.debug("Cache hit for query: \(query, privacy: .private)")
        searchMetrics.recordCacheHit()
        
        return cached.results
    }
    
    /// Caches search results
    func cacheResults(_ results: SearchResults, for query: String, filters: SearchFilters) {
        let cacheKey = generateCacheKey(query: query, filters: filters)
        
        // Clean up expired entries if cache is getting full
        if queryCache.count >= maxCacheSize {
            cleanupExpiredCache()
        }
        
        // Remove oldest entries if still at capacity
        if queryCache.count >= maxCacheSize {
            let sortedKeys = queryCache.keys.sorted { key1, key2 in
                let timestamp1 = queryCache[key1]?.timestamp ?? Date.distantPast
                let timestamp2 = queryCache[key2]?.timestamp ?? Date.distantPast
                return timestamp1 < timestamp2
            }
            
            // Remove oldest 25% of entries
            let removeCount = maxCacheSize / 4
            for i in 0..<removeCount {
                queryCache.removeValue(forKey: sortedKeys[i])
            }
        }
        
        queryCache[cacheKey] = CachedSearchResult(
            results: results,
            timestamp: Date(),
            queryHash: cacheKey
        )
        
        logger.debug("Cached results for query: \(query, privacy: .private)")
    }
    
    /// Invalidates cache entries that might be affected by data changes
    func invalidateCache(for changeType: DataChangeType) {
        switch changeType {
        case .activity, .timeEntry, .project:
            // For now, invalidate all cache entries when data changes
            // In the future, we could be more selective
            queryCache.removeAll()
            logger.debug("Cache invalidated due to data change: \(changeType)")
        case .index:
            // Index changes don't require cache invalidation
            break
        }
    }
    
    /// Clears all cached results
    func clearCache() {
        queryCache.removeAll()
        logger.debug("Search cache cleared")
    }
    
    // MARK: - Query Optimization
    
    /// Optimizes a search query for better performance
    func optimizeQuery(_ query: String) -> String {
        var optimized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove redundant whitespace
        optimized = optimized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Convert to lowercase for consistent caching
        optimized = optimized.lowercased()
        
        // Remove very short terms that don't add value
        let terms = optimized.components(separatedBy: .whitespaces)
        let filteredTerms = terms.filter { term in
            // Keep terms that are 2+ characters or are operators
            return term.count >= 2 || term.contains(":") || term.hasPrefix("-") || term.hasPrefix("\"")
        }
        
        return filteredTerms.joined(separator: " ")
    }
    
    /// Determines if a query should use fast path optimization
    func shouldUseFastPath(query: String, filters: SearchFilters) -> Bool {
        // Use fast path for simple queries without complex filters
        let isSimpleQuery = !query.contains(":") && !query.contains("\"") && !query.contains("-")
        let hasMinimalFilters = !filters.hasActiveFilters || 
                               (filters.selectedProjects.count <= 1 && filters.selectedApps.count <= 1)
        
        return isSimpleQuery && hasMinimalFilters
    }
    
    /// Estimates the complexity of a search operation
    func estimateSearchComplexity(query: String, filters: SearchFilters, dataSize: DataSize) -> SearchComplexity {
        var complexity = SearchComplexity.low
        
        // Query complexity
        if query.contains("\"") || query.contains(":") {
            complexity = .medium
        }
        
        if query.components(separatedBy: .whitespaces).count > 5 {
            complexity = .high
        }
        
        // Filter complexity
        if filters.selectedProjects.count > 5 || filters.selectedApps.count > 10 {
            complexity = SearchComplexity(rawValue: max(complexity.rawValue, SearchComplexity.medium.rawValue)) ?? .medium
        }
        
        // Data size impact
        if dataSize.totalItems > 10000 {
            complexity = SearchComplexity(rawValue: min(complexity.rawValue + 1, SearchComplexity.high.rawValue)) ?? .high
        }
        
        return complexity
    }
    
    // MARK: - Performance Monitoring
    
    /// Records search performance metrics
    func recordSearchPerformance(
        query: String,
        resultCount: Int,
        searchTime: TimeInterval,
        cacheHit: Bool
    ) {
        searchMetrics.recordSearch(
            query: query,
            resultCount: resultCount,
            searchTime: searchTime,
            cacheHit: cacheHit
        )
        
        // Log slow searches
        if searchTime > 1.0 {
            logger.warning("Slow search detected: \(searchTime, privacy: .public)s for query: \(query, privacy: .private)")
        }
        
        // Log searches with many results that might need pagination
        if resultCount > 1000 {
            logger.info("Large result set: \(resultCount) results for query: \(query, privacy: .private)")
        }
    }
    
    /// Gets current performance metrics
    func getPerformanceMetrics() -> SearchMetrics {
        return searchMetrics
    }
    
    /// Resets performance metrics
    func resetMetrics() {
        searchMetrics = SearchMetrics()
    }
    
    // MARK: - Memory Management
    
    /// Performs memory cleanup and optimization
    func performMemoryCleanup() {
        cleanupExpiredCache()
        
        // Compact metrics if they're getting too large
        if searchMetrics.totalSearches > 10000 {
            searchMetrics.compact()
        }
        
        logger.debug("Memory cleanup completed")
    }
    
    // MARK: - Private Helper Methods
    
    private func generateCacheKey(query: String, filters: SearchFilters) -> String {
        let queryHash = query.hash
        let filtersHash = filters.hashValue
        return "\(queryHash)_\(filtersHash)"
    }
    
    private func cleanupExpiredCache() {
        let expiredKeys = queryCache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            queryCache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            logger.debug("Cleaned up \(expiredKeys.count) expired cache entries")
        }
    }
}

// MARK: - Supporting Types

enum DataChangeType: CustomStringConvertible {
    case activity
    case timeEntry
    case project
    case index
    
    var description: String {
        switch self {
        case .activity:
            return "activity"
        case .timeEntry:
            return "timeEntry"
        case .project:
            return "project"
        case .index:
            return "index"
        }
    }
}

enum SearchComplexity: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    
    var description: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    var recommendedTimeout: TimeInterval {
        switch self {
        case .low:
            return 1.0
        case .medium:
            return 3.0
        case .high:
            return 10.0
        }
    }
}

struct DataSize {
    let activities: Int
    let timeEntries: Int
    let projects: Int
    
    var totalItems: Int {
        return activities + timeEntries + projects
    }
    
    var complexity: SearchComplexity {
        if totalItems < 1000 {
            return .low
        } else if totalItems < 10000 {
            return .medium
        } else {
            return .high
        }
    }
}

/// Performance metrics for search operations
struct SearchMetrics {
    private(set) var totalSearches: Int = 0
    private(set) var cacheHits: Int = 0
    private(set) var averageSearchTime: TimeInterval = 0
    private(set) var slowSearchCount: Int = 0
    private(set) var searchTimes: [TimeInterval] = []
    private(set) var queryFrequency: [String: Int] = [:]
    
    var cacheHitRate: Double {
        guard totalSearches > 0 else { return 0 }
        return Double(cacheHits) / Double(totalSearches)
    }
    
    var slowSearchRate: Double {
        guard totalSearches > 0 else { return 0 }
        return Double(slowSearchCount) / Double(totalSearches)
    }
    
    var medianSearchTime: TimeInterval {
        guard !searchTimes.isEmpty else { return 0 }
        let sorted = searchTimes.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? 
            (sorted[mid - 1] + sorted[mid]) / 2 : 
            sorted[mid]
    }
    
    mutating func recordSearch(query: String, resultCount: Int, searchTime: TimeInterval, cacheHit: Bool) {
        totalSearches += 1
        
        if cacheHit {
            cacheHits += 1
        }
        
        // Update average search time
        averageSearchTime = (averageSearchTime * Double(totalSearches - 1) + searchTime) / Double(totalSearches)
        
        // Track search times for median calculation
        searchTimes.append(searchTime)
        if searchTimes.count > 1000 {
            searchTimes.removeFirst(searchTimes.count - 1000)
        }
        
        // Count slow searches (>1 second)
        if searchTime > 1.0 {
            slowSearchCount += 1
        }
        
        // Track query frequency
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedQuery.isEmpty {
            queryFrequency[normalizedQuery, default: 0] += 1
        }
    }
    
    mutating func recordCacheHit() {
        // This is called separately from recordSearch for cache-only hits
        cacheHits += 1
    }
    
    mutating func compact() {
        // Keep only the most recent 1000 search times
        if searchTimes.count > 1000 {
            searchTimes = Array(searchTimes.suffix(1000))
        }
        
        // Keep only the top 100 most frequent queries
        if queryFrequency.count > 100 {
            let topQueries = queryFrequency.sorted { $0.value > $1.value }.prefix(100)
            queryFrequency = Dictionary(topQueries.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
        }
    }
    
    var description: String {
        return """
        Search Performance Metrics:
        - Total Searches: \(totalSearches)
        - Cache Hit Rate: \(String(format: "%.1f", cacheHitRate * 100))%
        - Average Search Time: \(String(format: "%.3f", averageSearchTime))s
        - Median Search Time: \(String(format: "%.3f", medianSearchTime))s
        - Slow Search Rate: \(String(format: "%.1f", slowSearchRate * 100))%
        """
    }
}

// MARK: - SearchFilters Hashable Extension

extension SearchFilters: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(startDate)
        hasher.combine(endDate)
        hasher.combine(selectedProjects)
        hasher.combine(selectedApps)
        hasher.combine(minDuration)
        hasher.combine(maxDuration)
        hasher.combine(excludeIdleTime)
        hasher.combine(includeArchived)
    }
}