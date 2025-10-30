import Foundation
import os
import SwiftData

/// Automated performance testing and benchmarking
@MainActor
class PerformanceTestRunner: ObservableObject {
    // MARK: - Singleton
    
    static let shared = PerformanceTestRunner()
    
    // MARK: - Published Properties
    
    @Published private(set) var testResults: [PerformanceTestResult] = []
    @Published private(set) var isRunningTests: Bool = false
    @Published private(set) var currentTest: String?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.time.vscode", category: "PerformanceTest")
    private var modelContext: ModelContext?
    
    // Test configurations
    private let testConfigurations: [PerformanceTestConfiguration] = [
        PerformanceTestConfiguration(
            name: "Database Query Performance",
            category: .database,
            iterations: 100,
            warmupIterations: 10,
            timeout: 30.0
        ),
        PerformanceTestConfiguration(
            name: "Memory Usage Under Load",
            category: .memory,
            iterations: 50,
            warmupIterations: 5,
            timeout: 60.0
        ),
        PerformanceTestConfiguration(
            name: "UI Responsiveness",
            category: .ui,
            iterations: 200,
            warmupIterations: 20,
            timeout: 15.0
        ),
        PerformanceTestConfiguration(
            name: "Background Processing",
            category: .processing,
            iterations: 75,
            warmupIterations: 10,
            timeout: 45.0
        ),
        PerformanceTestConfiguration(
            name: "Data Processing Pipeline",
            category: .dataProcessing,
            iterations: 30,
            warmupIterations: 5,
            timeout: 120.0
        )
    ]
    
    // MARK: - Initialization
    
    private init() {}
    
    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Test Execution
    
    /// Runs all performance tests
    func runAllTests() async {
        guard !isRunningTests else {
            logger.warning("Performance tests already running")
            return
        }
        
        isRunningTests = true
        testResults.removeAll()
        
        logger.info("Starting comprehensive performance test suite")
        
        defer {
            isRunningTests = false
            currentTest = nil
        }
        
        for configuration in testConfigurations {
            currentTest = configuration.name
            
            do {
                let result = try await runPerformanceTest(configuration)
                testResults.append(result)
                
                logger.info("Completed test: \(configuration.name) - Score: \(String(format: "%.2f", result.performanceScore))")
                
                // Brief pause between tests
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
            } catch {
                logger.error("Test failed: \(configuration.name) - \(error.localizedDescription)")
                
                let failedResult = PerformanceTestResult(
                    testName: configuration.name,
                    category: configuration.category,
                    executionTime: Date(),
                    duration: 0,
                    iterations: 0,
                    averageResponseTime: 0,
                    minResponseTime: 0,
                    maxResponseTime: 0,
                    throughput: 0,
                    memoryUsage: 0,
                    cpuUsage: 0,
                    performanceScore: 0,
                    passed: false,
                    errorMessage: error.localizedDescription
                )
                
                testResults.append(failedResult)
            }
        }
        
        // Generate summary report
        generateTestReport()
        
        logger.info("Performance test suite completed")
    }
    
    /// Runs a specific performance test
    func runPerformanceTest(_ configuration: PerformanceTestConfiguration) async throws -> PerformanceTestResult {
        logger.info("Running performance test: \(configuration.name)")
        
        let startTime = Date()
        var responseTimes: [TimeInterval] = []
        var memoryUsages: [UInt64] = []
        var cpuUsages: [Double] = []
        
        // Warmup iterations
        for _ in 0..<configuration.warmupIterations {
            _ = try await executeTestIteration(configuration)
        }
        
        // Actual test iterations
        for iteration in 0..<configuration.iterations {
            let iterationStart = Date()
            
            // Execute test based on category
            try await executeTestIteration(configuration)
            
            let iterationTime = Date().timeIntervalSince(iterationStart)
            responseTimes.append(iterationTime)
            
            // Collect system metrics
            let memoryMetrics = MemoryManager.shared.getMemoryPerformanceMetrics()
            memoryUsages.append(memoryMetrics.currentMemoryUsage)
            
            let systemMetrics = PerformanceMonitor.shared.systemMetrics
            cpuUsages.append(systemMetrics.cpuUsage)
            
            // Check timeout
            if Date().timeIntervalSince(startTime) > configuration.timeout {
                throw PerformanceTestError.timeout
            }
            
            // Progress logging
            if iteration % 10 == 0 {
                logger.debug("Test progress: \(iteration)/\(configuration.iterations)")
            }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        
        // Calculate statistics
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let minResponseTime = responseTimes.min() ?? 0
        let maxResponseTime = responseTimes.max() ?? 0
        let throughput = Double(configuration.iterations) / totalDuration
        
        let avgMemoryUsage = memoryUsages.reduce(0, +) / UInt64(memoryUsages.count)
        let avgCpuUsage = cpuUsages.reduce(0, +) / Double(cpuUsages.count)
        
        // Calculate performance score
        let performanceScore = calculatePerformanceScore(
            configuration: configuration,
            avgResponseTime: avgResponseTime,
            throughput: throughput,
            memoryUsage: avgMemoryUsage,
            cpuUsage: avgCpuUsage
        )
        
        let result = PerformanceTestResult(
            testName: configuration.name,
            category: configuration.category,
            executionTime: startTime,
            duration: totalDuration,
            iterations: configuration.iterations,
            averageResponseTime: avgResponseTime,
            minResponseTime: minResponseTime,
            maxResponseTime: maxResponseTime,
            throughput: throughput,
            memoryUsage: avgMemoryUsage,
            cpuUsage: avgCpuUsage,
            performanceScore: performanceScore,
            passed: performanceScore >= 70.0, // 70% threshold
            errorMessage: nil
        )
        
        return result
    }
    
    // MARK: - Test Implementations
    
    private func executeTestIteration(_ configuration: PerformanceTestConfiguration) async throws {
        switch configuration.category {
        case .database:
            try await executeDatabaseTest()
        case .memory:
            try await executeMemoryTest()
        case .ui:
            try await executeUITest()
        case .processing:
            try await executeProcessingTest()
        case .dataProcessing:
            try await executeDataProcessingTest()
        }
    }
    
    private func executeDatabaseTest() async throws {
        guard let modelContext = modelContext else {
            throw PerformanceTestError.noModelContext
        }
        
        // Test various database operations
        let operations = [
            { try await self.testActivityQuery(modelContext) },
            { try await self.testProjectQuery(modelContext) },
            { try await self.testTimeEntryQuery(modelContext) },
            { try await self.testComplexQuery(modelContext) }
        ]
        
        let randomOperation = operations.randomElement()!
        try await randomOperation()
    }
    
    private func testActivityQuery(_ modelContext: ModelContext) async throws {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        
        _ = try modelContext.fetch(descriptor)
    }
    
    private func testProjectQuery(_ modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        _ = try modelContext.fetch(descriptor)
    }
    
    private func testTimeEntryQuery(_ modelContext: ModelContext) async throws {
        let twentyFourHoursAgo = Date().addingTimeInterval(-86400)
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startTime > twentyFourHoursAgo // Last 24 hours
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        _ = try modelContext.fetch(descriptor)
    }
    
    private func testComplexQuery(_ modelContext: ModelContext) async throws {
        // Complex query with joins and filtering
        let yesterday = Date().addingTimeInterval(-86400)
        
        let activityDescriptor = FetchDescriptor<Activity>(
            predicate: #Predicate<Activity> { activity in
                activity.startTime > yesterday && activity.duration > 60
            }
        )
        
        let activities = try modelContext.fetch(activityDescriptor)
        
        // Process results to simulate real usage
        let totalDuration = activities.reduce(0) { $0 + $1.duration }
        _ = totalDuration
    }
    
    private func executeMemoryTest() async throws {
        // Test memory allocation and deallocation patterns
        let memoryManager = MemoryManager.shared
        
        // Allocate test data
        var testData: [Data] = []
        
        for i in 0..<100 {
            let data = Data(count: 1024 * 10) // 10KB each
            testData.append(data)
            
            // Register with memory manager
            memoryManager.registerCache(data, forKey: "test_\(i)", estimatedSize: data.count)
        }
        
        // Access some data randomly
        for _ in 0..<20 {
            let randomIndex = Int.random(in: 0..<testData.count)
            _ = memoryManager.getCachedData(forKey: "test_\(randomIndex)", as: Data.self)
        }
        
        // Clean up
        for i in 0..<100 {
            memoryManager.removeCacheEntry(forKey: "test_\(i)")
        }
    }
    
    private func executeUITest() async throws {
        // Simulate UI operations
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Simulate UI work
                let startTime = Date()
                
                // Simulate layout calculations
                for _ in 0..<1000 {
                    _ = CGRect(x: 0, y: 0, width: 100, height: 100)
                }
                
                // Simulate view updates
                let duration = Date().timeIntervalSince(startTime)
                _ = duration
                
                continuation.resume()
            }
        }
    }
    
    private func executeProcessingTest() async throws {
        let backgroundManager = BackgroundProcessingManager.shared
        
        // Test background processing
        let result = try await backgroundManager.executeBackgroundOperation {
            // Simulate computational work
            var sum = 0
            for i in 0..<10000 {
                sum += i * i
            }
            return sum
        }
        
        _ = result
    }
    
    private func executeDataProcessingTest() async throws {
        let backgroundManager = BackgroundProcessingManager.shared
        
        // Generate test data
        let testData = Array(0..<1000)
        
        // Process data in chunks
        let results = try await backgroundManager.executeDataProcessing(
            input: testData,
            chunkSize: 100,
            processor: { chunk in
                return chunk.map { $0 * 2 }
            }
        )
        
        _ = results
    }
    
    // MARK: - Performance Scoring
    
    private func calculatePerformanceScore(
        configuration: PerformanceTestConfiguration,
        avgResponseTime: TimeInterval,
        throughput: Double,
        memoryUsage: UInt64,
        cpuUsage: Double
    ) -> Double {
        var score = 100.0
        
        // Response time scoring (lower is better)
        let responseTimeThreshold: TimeInterval
        switch configuration.category {
        case .database:
            responseTimeThreshold = 0.01 // 10ms
        case .memory:
            responseTimeThreshold = 0.001 // 1ms
        case .ui:
            responseTimeThreshold = 0.016 // 16ms (60fps)
        case .processing:
            responseTimeThreshold = 0.1 // 100ms
        case .dataProcessing:
            responseTimeThreshold = 0.05 // 50ms
        }
        
        if avgResponseTime > responseTimeThreshold {
            let penalty = (avgResponseTime - responseTimeThreshold) / responseTimeThreshold * 30
            score -= min(penalty, 30)
        }
        
        // Throughput scoring (higher is better)
        let throughputThreshold: Double
        switch configuration.category {
        case .database:
            throughputThreshold = 100 // ops/sec
        case .memory:
            throughputThreshold = 1000 // ops/sec
        case .ui:
            throughputThreshold = 60 // fps
        case .processing:
            throughputThreshold = 10 // ops/sec
        case .dataProcessing:
            throughputThreshold = 20 // ops/sec
        }
        
        if throughput < throughputThreshold {
            let penalty = (throughputThreshold - throughput) / throughputThreshold * 25
            score -= min(penalty, 25)
        }
        
        // Memory usage scoring (lower is better)
        let memoryThreshold: UInt64 = 100 * 1024 * 1024 // 100MB
        if memoryUsage > memoryThreshold {
            let penalty = Double(memoryUsage - memoryThreshold) / Double(memoryThreshold) * 20
            score -= min(penalty, 20)
        }
        
        // CPU usage scoring (lower is better)
        if cpuUsage > 50 {
            let penalty = (cpuUsage - 50) / 50 * 25
            score -= min(penalty, 25)
        }
        
        return max(0, min(100, score))
    }
    
    // MARK: - Reporting
    
    private func generateTestReport() {
        let passedTests = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        let overallScore = testResults.map { $0.performanceScore }.reduce(0, +) / Double(totalTests)
        
        logger.info("""
        Performance Test Report:
        - Tests Passed: \(passedTests)/\(totalTests)
        - Overall Score: \(String(format: "%.2f", overallScore))%
        - Average Response Time: \(String(format: "%.3f", self.getAverageResponseTime()))s
        - Average Throughput: \(String(format: "%.2f", self.getAverageThroughput())) ops/sec
        """)
        
        // Log individual test results
        for result in testResults {
            let status = result.passed ? "PASS" : "FAIL"
            logger.info("[\(status)] \(result.testName): \(String(format: "%.2f", result.performanceScore))%")
        }
    }
    
    private func getAverageResponseTime() -> TimeInterval {
        guard !testResults.isEmpty else { return 0 }
        return testResults.map { $0.averageResponseTime }.reduce(0, +) / Double(testResults.count)
    }
    
    private func getAverageThroughput() -> Double {
        guard !testResults.isEmpty else { return 0 }
        return testResults.map { $0.throughput }.reduce(0, +) / Double(testResults.count)
    }
    
    // MARK: - Benchmark Comparison
    
    /// Compares current results with baseline benchmarks
    func compareWithBaseline() -> PerformanceComparison? {
        guard !testResults.isEmpty else { return nil }
        
        // Load baseline results (in a real implementation, these would be stored)
        let baselineResults = getBaselineResults()
        
        var comparisons: [TestComparison] = []
        
        for result in testResults {
            if let baseline = baselineResults.first(where: { $0.testName == result.testName }) {
                let responseTimeChange = ((result.averageResponseTime - baseline.averageResponseTime) / baseline.averageResponseTime) * 100
                let throughputChange = ((result.throughput - baseline.throughput) / baseline.throughput) * 100
                let scoreChange = result.performanceScore - baseline.performanceScore
                
                let comparison = TestComparison(
                    testName: result.testName,
                    responseTimeChange: responseTimeChange,
                    throughputChange: throughputChange,
                    scoreChange: scoreChange,
                    isRegression: scoreChange < -5.0 // 5% threshold
                )
                
                comparisons.append(comparison)
            }
        }
        
        let overallScoreChange = testResults.map { $0.performanceScore }.reduce(0, +) / Double(testResults.count) -
                                baselineResults.map { $0.performanceScore }.reduce(0, +) / Double(baselineResults.count)
        
        return PerformanceComparison(
            testComparisons: comparisons,
            overallScoreChange: overallScoreChange,
            hasRegressions: comparisons.contains { $0.isRegression }
        )
    }
    
    private func getBaselineResults() -> [PerformanceTestResult] {
        // In a real implementation, these would be loaded from storage
        // For now, return mock baseline data
        return testConfigurations.map { config in
            PerformanceTestResult(
                testName: config.name,
                category: config.category,
                executionTime: Date().addingTimeInterval(-86400), // Yesterday
                duration: 10.0,
                iterations: config.iterations,
                averageResponseTime: 0.01,
                minResponseTime: 0.005,
                maxResponseTime: 0.02,
                throughput: 100.0,
                memoryUsage: 50 * 1024 * 1024, // 50MB
                cpuUsage: 25.0,
                performanceScore: 85.0,
                passed: true,
                errorMessage: nil
            )
        }
    }
}

// MARK: - Supporting Types

struct PerformanceTestConfiguration {
    let name: String
    let category: TestCategory
    let iterations: Int
    let warmupIterations: Int
    let timeout: TimeInterval
}

struct PerformanceTestResult: Identifiable {
    let id = UUID()
    let testName: String
    let category: TestCategory
    let executionTime: Date
    let duration: TimeInterval
    let iterations: Int
    let averageResponseTime: TimeInterval
    let minResponseTime: TimeInterval
    let maxResponseTime: TimeInterval
    let throughput: Double
    let memoryUsage: UInt64
    let cpuUsage: Double
    let performanceScore: Double
    let passed: Bool
    let errorMessage: String?
}

struct PerformanceComparison {
    let testComparisons: [TestComparison]
    let overallScoreChange: Double
    let hasRegressions: Bool
}

struct TestComparison {
    let testName: String
    let responseTimeChange: Double // Percentage change
    let throughputChange: Double // Percentage change
    let scoreChange: Double // Absolute change
    let isRegression: Bool
}

enum TestCategory {
    case database
    case memory
    case ui
    case processing
    case dataProcessing
}

enum PerformanceTestError: LocalizedError {
    case timeout
    case noModelContext
    case testFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Performance test timed out"
        case .noModelContext:
            return "No model context available for database tests"
        case .testFailed(let message):
            return "Test failed: \(message)"
        }
    }
}