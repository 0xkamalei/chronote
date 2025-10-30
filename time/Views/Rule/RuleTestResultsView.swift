import SwiftUI

struct RuleTestResultsView: View {
    let testResults: RuleTestResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Test Results")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Rule: \(testResults.rule.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Statistics Cards
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Matches",
                            value: "\(testResults.matchingActivities.count)",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Match Rate",
                            value: "\(String(format: "%.1f", testResults.matchPercentage))%",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Total Time",
                            value: formatDuration(testResults.totalDuration),
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Avg Duration",
                            value: formatDuration(testResults.averageDuration),
                            color: .purple
                        )
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Matching Activities List
                if testResults.matchingActivities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Matching Activities")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("This rule didn't match any activities in the test period.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(testResults.matchingActivities, id: \.id) { activity in
                        ActivityRowView(activity: activity)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Test Results")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Activity Row View

struct ActivityRowView: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon Placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(activity.appName.prefix(1)))
                        .font(.caption)
                        .fontWeight(.medium)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.appName)
                    .font(.headline)
                    .lineLimit(1)
                
                if let windowTitle = activity.windowTitle, !windowTitle.isEmpty {
                    Text(windowTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if let url = activity.url, !url.isEmpty {
                    Text(url)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(activity.startTime, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDuration(activity.calculatedDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 1 {
            return "<1m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

#Preview {
    let sampleRule = Rule(
        name: "Development Work",
        conditions: [.appName("Xcode", .contains)],
        action: .assignToProject("dev-project")
    )
    
    let sampleActivities = [
        Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            duration: 3600,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            icon: "",
            windowTitle: "MyProject - ContentView.swift"
        ),
        Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            duration: 1800,
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date(),
            icon: "",
            windowTitle: "MyProject - Models.swift"
        )
    ]
    
    let testResults = RuleTestResult(
        rule: sampleRule,
        matchingActivities: sampleActivities,
        totalDuration: 5400,
        matchPercentage: 85.0
    )
    
    return RuleTestResultsView(testResults: testResults)
}