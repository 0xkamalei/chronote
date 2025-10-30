import SwiftUI

/// Performance settings and configuration view
struct PerformanceSettingsView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var memoryManager = MemoryManager.shared
    @StateObject private var databaseOptimizer = DatabasePerformanceOptimizer.shared
    @StateObject private var backgroundProcessor = BackgroundProcessingManager.shared
    @StateObject private var resourceCleanup = ResourceCleanupManager.shared
    @StateObject private var testRunner = PerformanceTestRunner.shared
    
    @State private var isRunningTests = false
    @State private var showingTestResults = false
    @State private var selectedTab: SettingsTab = .monitoring
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedTab {
                        case .monitoring:
                            monitoringSettings
                        case .memory:
                            memorySettings
                        case .database:
                            databaseSettings
                        case .processing:
                            processingSettings
                        case .testing:
                            testingSettings
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Performance Settings")
            .sheet(isPresented: $showingTestResults) {
                PerformanceTestResultsView(results: testRunner.testResults)
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 16))
                        Text(tab.title)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Monitoring Settings
    
    private var monitoringSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Monitoring")
                .font(.title2.bold())
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monitoring Configuration")
                        .font(.headline)
                    
                    Toggle("Enable Performance Monitoring", isOn: .constant(performanceMonitor.isMonitoring))
                        .disabled(true) // Always enabled for now
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert Thresholds")
                            .font(.subheadline.bold())
                        
                        HStack {
                            Text("CPU Usage Alert:")
                            Spacer()
                            Text("80%")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Memory Usage Alert:")
                            Spacer()
                            Text("85%")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Response Time Alert:")
                            Spacer()
                            Text("1.0s")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Status")
                        .font(.headline)
                    
                    let summary = performanceMonitor.getCurrentPerformanceSummary()
                    
                    HStack {
                        Text("Performance Score:")
                        Spacer()
                        Text("\(Int(summary.performanceScore))%")
                            .foregroundColor(scoreColor(summary.performanceScore))
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Active Alerts:")
                        Spacer()
                        Text("\(summary.activeAlerts.count)")
                            .foregroundColor(summary.activeAlerts.isEmpty ? .green : .red)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Monitoring Since:")
                        Spacer()
                        Text("App Launch")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Settings
    
    private var memorySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Management")
                .font(.title2.bold())
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cache Configuration")
                        .font(.headline)
                    
                    let memoryMetrics = memoryManager.getMemoryPerformanceMetrics()
                    
                    HStack {
                        Text("Current Cache Size:")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(memoryMetrics.cacheSize), countStyle: .memory))
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Cache Entries:")
                        Spacer()
                        Text("\(memoryMetrics.cacheEntryCount)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Memory Efficiency:")
                        Spacer()
                        Text("\(String(format: "%.1f", memoryMetrics.memoryEfficiency * 100))%")
                            .foregroundColor(memoryMetrics.memoryEfficiency > 0.7 ? .green : .orange)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("Clear All Caches") {
                            memoryManager.clearAllCaches()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        if memoryManager.isMemoryPressureHigh {
                            Label("High Pressure", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resource Cleanup")
                        .font(.headline)
                    
                    let cleanupMetrics = resourceCleanup.getCleanupMetrics()
                    let resourceStats = resourceCleanup.getResourceStatistics()
                    
                    HStack {
                        Text("Tracked Resources:")
                        Spacer()
                        Text("\(resourceStats.totalTrackedResources)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Resources Cleaned:")
                        Spacer()
                        Text("\(cleanupMetrics.resourcesCleaned)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    if let lastCleanup = cleanupMetrics.lastCleanupTime {
                        HStack {
                            Text("Last Cleanup:")
                            Spacer()
                            Text(lastCleanup, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Button("Force Cleanup") {
                        Task {
                            await resourceCleanup.performCleanup(strategy: .normal)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(resourceCleanup.isCleanupInProgress)
                }
            }
        }
    }
    
    // MARK: - Database Settings
    
    private var databaseSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Database Performance")
                .font(.title2.bold())
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Query Performance")
                        .font(.headline)
                    
                    let dbMetrics = databaseOptimizer.getPerformanceMetrics()
                    let queryStats = databaseOptimizer.getQueryPerformanceStats()
                    
                    HStack {
                        Text("Total Queries:")
                        Spacer()
                        Text("\(queryStats.totalQueries)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Average Query Time:")
                        Spacer()
                        Text("\(String(format: "%.3f", queryStats.averageDuration))s")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Slowest Query:")
                        Spacer()
                        Text("\(String(format: "%.3f", queryStats.slowestDuration))s")
                            .foregroundColor(queryStats.slowestDuration > 1.0 ? .red : .primary)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    if !queryStats.slowestQueryType.isEmpty {
                        HStack {
                            Text("Slowest Type:")
                            Spacer()
                            Text(queryStats.slowestQueryType)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Database Maintenance")
                        .font(.headline)
                    
                    if let lastMaintenance = dbMetrics.lastMaintenanceTime {
                        HStack {
                            Text("Last Maintenance:")
                            Spacer()
                            Text(lastMaintenance, style: .relative)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Maintenance Duration:")
                            Spacer()
                            Text("\(String(format: "%.2f", dbMetrics.lastMaintenanceDuration))s")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    if let lastIndexCreation = dbMetrics.lastIndexCreationTime {
                        HStack {
                            Text("Indexes Created:")
                            Spacer()
                            Text(lastIndexCreation, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Button("Run Maintenance") {
                        Task {
                            try? await databaseOptimizer.performMaintenance()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Processing Settings
    
    private var processingSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Background Processing")
                .font(.title2.bold())
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Processing Status")
                        .font(.headline)
                    
                    let processingMetrics = backgroundProcessor.getProcessingMetrics()
                    
                    HStack {
                        Text("Active Operations:")
                        Spacer()
                        Text("\(processingMetrics.activeOperationCount)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Heavy Operations:")
                        Spacer()
                        Text("\(processingMetrics.heavyOperationCount)")
                            .foregroundColor(processingMetrics.heavyOperationCount > 0 ? .orange : .primary)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Total Operations:")
                        Spacer()
                        Text("\(processingMetrics.totalOperations)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Average Duration:")
                        Spacer()
                        Text("\(String(format: "%.3f", processingMetrics.averageOperationDuration))s")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    if backgroundProcessor.isProcessingHeavyOperations {
                        HStack {
                            Label("Heavy Processing Active", systemImage: "cpu.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Queue Configuration")
                        .font(.headline)
                    
                    let queueStats = backgroundProcessor.getQueueStatistics()
                    
                    HStack {
                        Text("Background Queue Load:")
                        Spacer()
                        Text("\(String(format: "%.1f", queueStats.backgroundQueueLoad * 100))%")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Heavy Queue Load:")
                        Spacer()
                        Text("\(String(format: "%.1f", queueStats.heavyQueueLoad * 100))%")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Throughput:")
                        Spacer()
                        Text("\(String(format: "%.2f", queueStats.throughput)) ops/s")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Divider()
                    
                    Button("Cancel All Operations") {
                        Task {
                            await backgroundProcessor.cancelAllOperations()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(processingMetrics.activeOperationCount == 0)
                }
            }
        }
    }
    
    // MARK: - Testing Settings
    
    private var testingSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Testing")
                .font(.title2.bold())
            
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Automated Testing")
                        .font(.headline)
                    
                    if testRunner.isRunningTests {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Running Tests...")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            if let currentTest = testRunner.currentTest {
                                Text("Current: \(currentTest)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Run comprehensive performance tests to benchmark your system.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Run All Tests") {
                                    Task {
                                        await testRunner.runAllTests()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                if !testRunner.testResults.isEmpty {
                                    Button("View Results") {
                                        showingTestResults = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            
            if !testRunner.testResults.isEmpty {
                settingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Latest Test Results")
                            .font(.headline)
                        
                        let passedTests = testRunner.testResults.filter { $0.passed }.count
                        let totalTests = testRunner.testResults.count
                        let overallScore = testRunner.testResults.map { $0.performanceScore }.reduce(0, +) / Double(totalTests)
                        
                        HStack {
                            Text("Tests Passed:")
                            Spacer()
                            Text("\(passedTests)/\(totalTests)")
                                .foregroundColor(passedTests == totalTests ? .green : .orange)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Overall Score:")
                            Spacer()
                            Text("\(String(format: "%.1f", overallScore))%")
                                .foregroundColor(scoreColor(overallScore))
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        // Show recent test results
                        ForEach(testRunner.testResults.prefix(3), id: \.id) { result in
                            HStack {
                                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.passed ? .green : .red)
                                
                                Text(result.testName)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text("\(String(format: "%.1f", result.performanceScore))%")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if testRunner.testResults.count > 3 {
                            Button("View All Results") {
                                showingTestResults = true
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Performance Test Results View

struct PerformanceTestResultsView: View {
    let results: [PerformanceTestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(results, id: \.id) { result in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.passed ? .green : .red)
                        
                        Text(result.testName)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", result.performanceScore))%")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(scoreColor(result.performanceScore))
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Response Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.3f", result.averageResponseTime))s")
                                .font(.caption.monospaced())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Throughput")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.2f", result.throughput)) ops/s")
                                .font(.caption.monospaced())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Memory")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(result.memoryUsage), countStyle: .memory))
                                .font(.caption.monospaced())
                        }
                    }
                    
                    if let errorMessage = result.errorMessage {
                        Text("Error: \(errorMessage)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Supporting Types

enum SettingsTab: CaseIterable {
    case monitoring
    case memory
    case database
    case processing
    case testing
    
    var title: String {
        switch self {
        case .monitoring:
            return "Monitoring"
        case .memory:
            return "Memory"
        case .database:
            return "Database"
        case .processing:
            return "Processing"
        case .testing:
            return "Testing"
        }
    }
    
    var iconName: String {
        switch self {
        case .monitoring:
            return "chart.line.uptrend.xyaxis"
        case .memory:
            return "memorychip"
        case .database:
            return "cylinder"
        case .processing:
            return "cpu"
        case .testing:
            return "testtube.2"
        }
    }
}

#Preview {
    PerformanceSettingsView()
}