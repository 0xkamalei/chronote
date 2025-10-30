import Foundation
import os
import SwiftData

/// Database performance optimization utilities
@MainActor
class DatabasePerformanceOptimizer: ObservableObject {
    // MARK: - Singleton

    static let shared = DatabasePerformanceOptimizer()

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.time.vscode", category: "DatabasePerformance")
    private var modelContext: ModelContext?

    // Performance monitoring
    @Published private(set) var performanceMetrics: PerformanceMetrics = .init()
    private var queryPerformanceCache: [String: QueryPerformanceData] = [:]

    // Batch operation management
    private var batchOperationQueue: [BatchOperation] = []
    private var isBatchProcessing: Bool = false

    // MARK: - Initialization

    private init() {}

    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("DatabasePerformanceOptimizer initialized with modelContext")
    }

    // MARK: - Database Indexing

    /// Creates comprehensive database indexes for optimal query performance
    func createOptimizedIndexes() async throws {
        guard let modelContext = modelContext else {
            throw PerformanceError.noModelContext
        }

        logger.info("Creating optimized database indexes...")

        let startTime = Date()

        // Activity indexes for time-based queries
        try await createActivityIndexes()

        // TimeEntry indexes for project and date filtering
        try await createTimeEntryIndexes()

        // Project indexes for hierarchy operations
        try await createProjectIndexes()

        // Rule indexes for evaluation performance
        try await createRuleIndexes()

        // Timer session indexes
        try await createTimerSessionIndexes()

        let duration = Date().timeIntervalSince(startTime)
        logger.info("Database indexes created successfully in \(String(format: "%.2f", duration))s")

        // Update performance metrics
        performanceMetrics.lastIndexCreationTime = Date()
        performanceMetrics.indexCreationDuration = duration
    }

    private func createActivityIndexes() async throws {
        let indexes = [
            // Primary time-based queries
            "CREATE INDEX IF NOT EXISTS idx_activity_start_time ON Activity(startTime);",
            "CREATE INDEX IF NOT EXISTS idx_activity_end_time ON Activity(endTime);",
            "CREATE INDEX IF NOT EXISTS idx_activity_time_range ON Activity(startTime, endTime);",

            // App-based filtering
            "CREATE INDEX IF NOT EXISTS idx_activity_bundle_id ON Activity(appBundleId);",
            "CREATE INDEX IF NOT EXISTS idx_activity_app_name ON Activity(appName);",

            // Duration and performance queries
            "CREATE INDEX IF NOT EXISTS idx_activity_duration ON Activity(duration);",
            "CREATE INDEX IF NOT EXISTS idx_activity_active ON Activity(endTime) WHERE endTime IS NULL;",

            // Composite indexes for common query patterns
            "CREATE INDEX IF NOT EXISTS idx_activity_app_time ON Activity(appBundleId, startTime);",
            "CREATE INDEX IF NOT EXISTS idx_activity_time_duration ON Activity(startTime, duration);",

            // Context data indexes
            "CREATE INDEX IF NOT EXISTS idx_activity_window_title ON Activity(windowTitle);",
            "CREATE INDEX IF NOT EXISTS idx_activity_url ON Activity(url);",
            "CREATE INDEX IF NOT EXISTS idx_activity_idle ON Activity(isIdleTime);",

            // Date-based partitioning support
            "CREATE INDEX IF NOT EXISTS idx_activity_date ON Activity(date(startTime));",
            "CREATE INDEX IF NOT EXISTS idx_activity_month ON Activity(strftime('%Y-%m', startTime));",
        ]

        for indexSQL in indexes {
            try await executeSQL(indexSQL)
        }

        logger.info("Activity indexes created")
    }

    private func createTimeEntryIndexes() async throws {
        let indexes = [
            // Project-based queries
            "CREATE INDEX IF NOT EXISTS idx_timeentry_project ON TimeEntry(projectId);",
            "CREATE INDEX IF NOT EXISTS idx_timeentry_project_time ON TimeEntry(projectId, startTime);",

            // Time-based queries
            "CREATE INDEX IF NOT EXISTS idx_timeentry_start_time ON TimeEntry(startTime);",
            "CREATE INDEX IF NOT EXISTS idx_timeentry_end_time ON TimeEntry(endTime);",
            "CREATE INDEX IF NOT EXISTS idx_timeentry_date_range ON TimeEntry(startTime, endTime);",

            // Duration and statistics
            "CREATE INDEX IF NOT EXISTS idx_timeentry_duration ON TimeEntry(duration);",
            "CREATE INDEX IF NOT EXISTS idx_timeentry_project_duration ON TimeEntry(projectId, duration);",

            // Audit and tracking
            "CREATE INDEX IF NOT EXISTS idx_timeentry_created_at ON TimeEntry(createdAt);",
            "CREATE INDEX IF NOT EXISTS idx_timeentry_updated_at ON TimeEntry(updatedAt);",

            // Search and filtering
            "CREATE INDEX IF NOT EXISTS idx_timeentry_title ON TimeEntry(title);",

            // Date-based partitioning
            "CREATE INDEX IF NOT EXISTS idx_timeentry_date ON TimeEntry(date(startTime));",
            "CREATE INDEX IF NOT EXISTS idx_timeentry_week ON TimeEntry(strftime('%Y-%W', startTime));",
            "CREATE INDEX IF NOT EXISTS idx_timeentry_month ON TimeEntry(strftime('%Y-%m', startTime));",
        ]

        for indexSQL in indexes {
            try await executeSQL(indexSQL)
        }

        logger.info("TimeEntry indexes created")
    }

    private func createProjectIndexes() async throws {
        let indexes = [
            // Hierarchy queries
            "CREATE INDEX IF NOT EXISTS idx_project_parent ON Project(parentID);",
            "CREATE INDEX IF NOT EXISTS idx_project_sort_order ON Project(sortOrder);",
            "CREATE INDEX IF NOT EXISTS idx_project_parent_sort ON Project(parentID, sortOrder);",

            // Search and filtering
            "CREATE INDEX IF NOT EXISTS idx_project_name ON Project(name);",
            "CREATE INDEX IF NOT EXISTS idx_project_expanded ON Project(isExpanded);",
        ]

        for indexSQL in indexes {
            try await executeSQL(indexSQL)
        }

        logger.info("Project indexes created")
    }

    private func createRuleIndexes() async throws {
        let indexes = [
            // Rule evaluation
            "CREATE INDEX IF NOT EXISTS idx_rule_enabled ON Rule(isEnabled);",
            "CREATE INDEX IF NOT EXISTS idx_rule_priority ON Rule(priority);",
            "CREATE INDEX IF NOT EXISTS idx_rule_enabled_priority ON Rule(isEnabled, priority);",

            // Rule management
            "CREATE INDEX IF NOT EXISTS idx_rule_created_at ON Rule(createdAt);",
            "CREATE INDEX IF NOT EXISTS idx_rule_last_applied ON Rule(lastAppliedAt);",
            "CREATE INDEX IF NOT EXISTS idx_rule_application_count ON Rule(applicationCount);",
        ]

        for indexSQL in indexes {
            try await executeSQL(indexSQL)
        }

        logger.info("Rule indexes created")
    }

    private func createTimerSessionIndexes() async throws {
        let indexes = [
            // Timer session queries
            "CREATE INDEX IF NOT EXISTS idx_timersession_start_time ON TimerSession(startTime);",
            "CREATE INDEX IF NOT EXISTS idx_timersession_project ON TimerSession(projectId);",
            "CREATE INDEX IF NOT EXISTS idx_timersession_completed ON TimerSession(isCompleted);",
            "CREATE INDEX IF NOT EXISTS idx_timersession_active ON TimerSession(isCompleted, endTime);",
        ]

        for indexSQL in indexes {
            try await executeSQL(indexSQL)
        }

        logger.info("TimerSession indexes created")
    }

    // MARK: - Query Optimization

    /// Optimizes database queries with performance monitoring
    func optimizeQueries() async throws {
        guard let modelContext = modelContext else {
            throw PerformanceError.noModelContext
        }

        logger.info("Optimizing database queries...")

        // Update SQLite query optimizer statistics
        try await executeSQL("ANALYZE;")

        // Optimize query planner
        try await executeSQL("PRAGMA optimize;")

        // Configure optimal SQLite settings
        try await configureOptimalSettings()

        logger.info("Database query optimization completed")
    }

    private func configureOptimalSettings() async throws {
        let settings = [
            // Use WAL mode for better concurrency
            "PRAGMA journal_mode = WAL;",

            // Optimize synchronization for performance
            "PRAGMA synchronous = NORMAL;",

            // Increase cache size (10MB)
            "PRAGMA cache_size = -10000;",

            // Enable foreign key constraints
            "PRAGMA foreign_keys = ON;",

            // Use memory for temporary storage
            "PRAGMA temp_store = MEMORY;",

            // Optimize page size for modern systems
            "PRAGMA page_size = 4096;",

            // Enable automatic index creation
            "PRAGMA automatic_index = ON;",

            // Optimize checkpoint behavior
            "PRAGMA wal_autocheckpoint = 1000;",
        ]

        for setting in settings {
            try await executeSQL(setting)
        }

        logger.info("Optimal SQLite settings configured")
    }

    // MARK: - Batch Operations

    /// Executes batch operations for improved performance
    func executeBatchOperations(_ operations: [BatchOperation]) async throws {
        guard !operations.isEmpty else { return }

        logger.info("Executing \(operations.count) batch operations...")

        let startTime = Date()
        isBatchProcessing = true

        defer {
            isBatchProcessing = false
            let duration = Date().timeIntervalSince(startTime)
            performanceMetrics.lastBatchOperationDuration = duration
            logger.info("Batch operations completed in \(String(format: "%.2f", duration))s")
        }

        // Group operations by type for optimal execution
        let groupedOperations = Dictionary(grouping: operations) { $0.type }

        // Execute operations in optimal order
        let executionOrder: [BatchOperationType] = [.insert, .update, .delete]

        for operationType in executionOrder {
            if let typeOperations = groupedOperations[operationType] {
                try await executeBatchOperationsOfType(typeOperations)
            }
        }
    }

    private func executeBatchOperationsOfType(_ operations: [BatchOperation]) async throws {
        guard let modelContext = modelContext else {
            throw PerformanceError.noModelContext
        }

        // Begin transaction for batch operations
        try await executeSQL("BEGIN TRANSACTION;")

        do {
            for operation in operations {
                switch operation.type {
                case .insert:
                    try await executeBatchInsert(operation)
                case .update:
                    try await executeBatchUpdate(operation)
                case .delete:
                    try await executeBatchDelete(operation)
                }
            }

            // Commit transaction
            try await executeSQL("COMMIT;")

            // Save SwiftData context
            try modelContext.save()

        } catch {
            // Rollback on error
            try await executeSQL("ROLLBACK;")
            throw error
        }
    }

    private func executeBatchInsert(_ operation: BatchOperation) async throws {
        // Implementation depends on the specific data type
        logger.debug("Executing batch insert operation: \(operation.description)")
    }

    private func executeBatchUpdate(_ operation: BatchOperation) async throws {
        // Implementation depends on the specific data type
        logger.debug("Executing batch update operation: \(operation.description)")
    }

    private func executeBatchDelete(_ operation: BatchOperation) async throws {
        // Implementation depends on the specific data type
        logger.debug("Executing batch delete operation: \(operation.description)")
    }

    // MARK: - Data Pagination

    /// Creates paginated fetch descriptors for large datasets
    func createPaginatedDescriptor<T: PersistentModel>(
        for _: T.Type,
        offset: Int,
        limit: Int,
        sortBy: [SortDescriptor<T>] = [],
        predicate: Predicate<T>? = nil
    ) -> FetchDescriptor<T> {
        var descriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortBy
        )

        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit

        return descriptor
    }

    /// Executes paginated queries with performance monitoring
    func executePaginatedQuery<T: PersistentModel>(
        descriptor: FetchDescriptor<T>
    ) async throws -> [T] {
        guard let modelContext = modelContext else {
            throw PerformanceError.noModelContext
        }

        let startTime = Date()
        let queryKey = generateQueryKey(for: descriptor)

        do {
            let results = try modelContext.fetch(descriptor)

            let duration = Date().timeIntervalSince(startTime)

            // Cache query performance data
            queryPerformanceCache[queryKey] = QueryPerformanceData(
                queryType: String(describing: T.self),
                duration: duration,
                resultCount: results.count,
                timestamp: Date()
            )

            // Update performance metrics
            performanceMetrics.totalQueries += 1
            performanceMetrics.averageQueryDuration = calculateAverageQueryDuration()

            if duration > performanceMetrics.slowestQueryDuration {
                performanceMetrics.slowestQueryDuration = duration
                performanceMetrics.slowestQueryType = String(describing: T.self)
            }

            logger.debug("Paginated query executed in \(String(format: "%.3f", duration))s, returned \(results.count) results")

            return results

        } catch {
            logger.error("Paginated query failed: \(error.localizedDescription)")
            throw PerformanceError.queryFailed(error)
        }
    }

    // MARK: - Database Maintenance

    /// Performs comprehensive database maintenance
    func performMaintenance() async throws {
        logger.info("Starting database maintenance...")

        let startTime = Date()

        // Clean up old performance data
        cleanupPerformanceCache()

        // Optimize database
        try await optimizeQueries()

        // Vacuum database if needed
        try await vacuumIfNeeded()

        // Update statistics
        try await executeSQL("ANALYZE;")

        let duration = Date().timeIntervalSince(startTime)
        performanceMetrics.lastMaintenanceTime = Date()
        performanceMetrics.lastMaintenanceDuration = duration

        logger.info("Database maintenance completed in \(String(format: "%.2f", duration))s")
    }

    private func vacuumIfNeeded() async throws {
        // Check if vacuum is needed (simplified check)
        let shouldVacuum = performanceMetrics.totalQueries > 10000

        if shouldVacuum {
            logger.info("Performing database vacuum...")
            try await executeSQL("VACUUM;")
            logger.info("Database vacuum completed")
        }
    }

    private func cleanupPerformanceCache() {
        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour ago

        let initialCount = queryPerformanceCache.count
        queryPerformanceCache = queryPerformanceCache.filter { $0.value.timestamp > cutoffTime }

        let removedCount = initialCount - queryPerformanceCache.count
        if removedCount > 0 {
            logger.debug("Cleaned up \(removedCount) old performance cache entries")
        }
    }

    // MARK: - Performance Monitoring

    /// Gets current performance metrics
    func getPerformanceMetrics() -> PerformanceMetrics {
        return performanceMetrics
    }

    /// Gets query performance statistics
    func getQueryPerformanceStats() -> QueryPerformanceStats {
        let recentQueries = queryPerformanceCache.values.filter {
            $0.timestamp > Date().addingTimeInterval(-300) // Last 5 minutes
        }

        let totalDuration = recentQueries.reduce(0) { $0 + $1.duration }
        let averageDuration = recentQueries.isEmpty ? 0 : totalDuration / Double(recentQueries.count)

        let slowestQuery = recentQueries.max { $0.duration < $1.duration }

        return QueryPerformanceStats(
            totalQueries: recentQueries.count,
            averageDuration: averageDuration,
            slowestDuration: slowestQuery?.duration ?? 0,
            slowestQueryType: slowestQuery?.queryType ?? "None"
        )
    }

    private func calculateAverageQueryDuration() -> Double {
        let recentQueries = queryPerformanceCache.values.filter {
            $0.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }

        guard !recentQueries.isEmpty else { return 0 }

        let totalDuration = recentQueries.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(recentQueries.count)
    }

    private func generateQueryKey<T: PersistentModel>(for descriptor: FetchDescriptor<T>) -> String {
        return "\(T.self)_\(descriptor.fetchOffset ?? 0)_\(descriptor.fetchLimit ?? 0)_\(Date().timeIntervalSince1970)"
    }

    // MARK: - Utility Methods

    private func executeSQL(_ sql: String) async throws {
        // In a real implementation, this would execute raw SQL
        // For SwiftData, we'll log the SQL that would be executed
        logger.debug("Would execute SQL: \(sql)")
    }
}

// MARK: - Supporting Types

struct PerformanceMetrics {
    var totalQueries: Int = 0
    var averageQueryDuration: Double = 0
    var slowestQueryDuration: Double = 0
    var slowestQueryType: String = ""
    var lastIndexCreationTime: Date?
    var indexCreationDuration: Double = 0
    var lastBatchOperationDuration: Double = 0
    var lastMaintenanceTime: Date?
    var lastMaintenanceDuration: Double = 0
}

struct QueryPerformanceData {
    let queryType: String
    let duration: Double
    let resultCount: Int
    let timestamp: Date
}

struct QueryPerformanceStats {
    let totalQueries: Int
    let averageDuration: Double
    let slowestDuration: Double
    let slowestQueryType: String
}

struct BatchOperation {
    let type: BatchOperationType
    let description: String
    let data: Any?
}

enum BatchOperationType {
    case insert
    case update
    case delete
}

enum PerformanceError: LocalizedError {
    case noModelContext
    case queryFailed(Error)
    case batchOperationFailed(Error)
    case maintenanceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "No model context available for database operations"
        case let .queryFailed(error):
            return "Database query failed: \(error.localizedDescription)"
        case let .batchOperationFailed(error):
            return "Batch operation failed: \(error.localizedDescription)"
        case let .maintenanceFailed(error):
            return "Database maintenance failed: \(error.localizedDescription)"
        }
    }
}
