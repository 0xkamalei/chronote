import Charts
import SwiftUI

/// Performance monitoring dashboard view
struct PerformanceDashboardView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var memoryManager = MemoryManager.shared
    @StateObject private var databaseOptimizer = DatabasePerformanceOptimizer.shared

    @State private var selectedTimeRange: TimeRange = .last5Minutes
    @State private var showingAlerts = false
    @State private var isPerformingMaintenance = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Performance Score Card
                    performanceScoreCard

                    // System Metrics
                    systemMetricsSection

                    // Application Metrics
                    applicationMetricsSection

                    // Memory Management
                    memoryManagementSection

                    // Database Performance
                    databasePerformanceSection

                    // Performance Alerts
                    performanceAlertsSection

                    // Performance History Charts
                    performanceChartsSection

                    // Maintenance Actions
                    maintenanceActionsSection
                }
                .padding()
            }
            .navigationTitle("Performance Dashboard")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Alerts") {
                        showingAlerts = true
                    }
                    .badge(performanceMonitor.performanceAlerts.count)

                    Menu("Time Range") {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button(range.displayName) {
                                selectedTimeRange = range
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAlerts) {
                PerformanceAlertsView(alerts: performanceMonitor.performanceAlerts)
            }
        }
    }

    // MARK: - Performance Score Card

    private var performanceScoreCard: some View {
        let summary = performanceMonitor.getCurrentPerformanceSummary()

        return VStack(spacing: 12) {
            HStack {
                Text("Performance Score")
                    .font(.headline)
                Spacer()
                Text("\(Int(summary.performanceScore))")
                    .font(.largeTitle.bold())
                    .foregroundColor(scoreColor(summary.performanceScore))
            }

            ProgressView(value: summary.performanceScore, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: scoreColor(summary.performanceScore)))

            HStack {
                performanceIndicator("CPU", value: summary.currentSystemMetrics.cpuUsage, unit: "%", threshold: 80)
                Spacer()
                performanceIndicator("Memory", value: summary.currentSystemMetrics.memoryUsage, unit: "%", threshold: 85)
                Spacer()
                performanceIndicator("Response", value: summary.currentApplicationMetrics.averageResponseTime * 1000, unit: "ms", threshold: 1000)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func performanceIndicator(_ title: String, value: Double, unit: String, threshold: Double) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(value > threshold ? .red : .primary)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80 ... 100:
            return .green
        case 60 ..< 80:
            return .orange
        default:
            return .red
        }
    }

    // MARK: - System Metrics Section

    private var systemMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Metrics")
                .font(.headline)

            HStack(spacing: 20) {
                metricCard("CPU Usage", value: performanceMonitor.systemMetrics.cpuUsage, unit: "%", color: .blue)
                metricCard("Memory Usage", value: performanceMonitor.systemMetrics.memoryUsage, unit: "%", color: .orange)
                metricCard("Disk Usage", value: performanceMonitor.systemMetrics.diskUsage, unit: "%", color: .purple)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Application Metrics Section

    private var applicationMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application Metrics")
                .font(.headline)

            HStack(spacing: 20) {
                metricCard("Response Time", value: performanceMonitor.applicationMetrics.averageResponseTime * 1000, unit: "ms", color: .green)
                metricCard("Error Rate", value: performanceMonitor.applicationMetrics.errorRate, unit: "%", color: .red)
                metricCard("Throughput", value: performanceMonitor.applicationMetrics.throughput, unit: "ops/s", color: .cyan)
            }

            HStack(spacing: 20) {
                Text("Active Operations: \(performanceMonitor.applicationMetrics.activeOperations)")
                    .font(.caption)
                Spacer()
                Text("Total Operations: \(performanceMonitor.applicationMetrics.totalOperations)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Memory Management Section

    private var memoryManagementSection: some View {
        let memoryMetrics = memoryManager.getMemoryPerformanceMetrics()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memory Management")
                    .font(.headline)

                Spacer()

                if memoryManager.isMemoryPressureHigh {
                    Label("High Pressure", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Used Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(memoryMetrics.currentMemoryUsage), countStyle: .memory))
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Cache Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(memoryMetrics.cacheSize), countStyle: .memory))
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Efficiency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", memoryMetrics.memoryEfficiency * 100))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(memoryMetrics.memoryEfficiency > 0.7 ? .green : .orange)
                }
            }

            HStack {
                Button("Clear Caches") {
                    memoryManager.clearAllCaches()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Cache Entries: \(memoryMetrics.cacheEntryCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Database Performance Section

    private var databasePerformanceSection: some View {
        let dbMetrics = databaseOptimizer.getPerformanceMetrics()
        let queryStats = databaseOptimizer.getQueryPerformanceStats()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Database Performance")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Avg Query Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.3f", queryStats.averageDuration))s")
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Total Queries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(queryStats.totalQueries)")
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Slowest Query")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.3f", queryStats.slowestDuration))s")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(queryStats.slowestDuration > 1.0 ? .red : .primary)
                }
            }

            if let lastMaintenance = dbMetrics.lastMaintenanceTime {
                HStack {
                    Text("Last Maintenance:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lastMaintenance, style: .relative)
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Performance Alerts Section

    private var performanceAlertsSection: some View {
        let recentAlerts = performanceMonitor.performanceAlerts.prefix(3)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Alerts")
                    .font(.headline)

                Spacer()

                if !performanceMonitor.performanceAlerts.isEmpty {
                    Button("View All") {
                        showingAlerts = true
                    }
                    .font(.caption)
                }
            }

            if recentAlerts.isEmpty {
                Text("No recent performance alerts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(recentAlerts), id: \.id) { alert in
                    alertRow(alert)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func alertRow(_ alert: PerformanceAlert) -> some View {
        HStack {
            Image(systemName: alertIcon(alert.severity))
                .foregroundColor(alertColor(alert.severity))

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.caption)
                    .lineLimit(2)

                Text(alert.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func alertIcon(_ severity: AlertSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }

    private func alertColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    // MARK: - Performance Charts Section

    private var performanceChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(.headline)

            // This would contain actual charts in a real implementation
            Text("Performance charts would be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Maintenance Actions Section

    private var maintenanceActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Maintenance Actions")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Optimize Database") {
                    Task {
                        isPerformingMaintenance = true
                        try? await databaseOptimizer.performMaintenance()
                        isPerformingMaintenance = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isPerformingMaintenance)

                Button("Clear Memory Caches") {
                    memoryManager.clearAllCaches()
                }
                .buttonStyle(.bordered)

                Button("Force Cleanup") {
                    // Trigger emergency cleanup
                    NotificationCenter.default.post(name: .emergencyMemoryCleanup, object: nil)
                }
                .buttonStyle(.bordered)
            }

            if isPerformingMaintenance {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Performing maintenance...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Helper Views

    private func metricCard(_ title: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Performance Alerts View

struct PerformanceAlertsView: View {
    let alerts: [PerformanceAlert]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(alerts, id: \.id) { alert in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: alertIcon(alert.severity))
                            .foregroundColor(alertColor(alert.severity))

                        Text(alertTypeDisplayName(alert.type))
                            .font(.headline)

                        Spacer()

                        Text(alert.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(alert.message)
                        .font(.body)

                    Text(alert.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Performance Alerts")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func alertIcon(_ severity: AlertSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }

    private func alertColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    private func alertTypeDisplayName(_ type: PerformanceAlertType) -> String {
        switch type {
        case .highCPUUsage:
            return "High CPU Usage"
        case .highMemoryUsage:
            return "High Memory Usage"
        case .slowResponseTime:
            return "Slow Response Time"
        case .highErrorRate:
            return "High Error Rate"
        case .slowOperation:
            return "Slow Operation"
        case .memoryPressure:
            return "Memory Pressure"
        }
    }
}

// MARK: - Supporting Types

enum TimeRange: CaseIterable {
    case last5Minutes
    case last30Minutes
    case last1Hour
    case last6Hours
    case last24Hours

    var displayName: String {
        switch self {
        case .last5Minutes:
            return "Last 5 Minutes"
        case .last30Minutes:
            return "Last 30 Minutes"
        case .last1Hour:
            return "Last Hour"
        case .last6Hours:
            return "Last 6 Hours"
        case .last24Hours:
            return "Last 24 Hours"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .last5Minutes:
            return 300
        case .last30Minutes:
            return 1800
        case .last1Hour:
            return 3600
        case .last6Hours:
            return 21600
        case .last24Hours:
            return 86400
        }
    }
}

#Preview {
    PerformanceDashboardView()
}
