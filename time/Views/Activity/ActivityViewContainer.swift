import SwiftUI

/// Container view that includes the view mode selector and the corresponding activity view
struct ActivityViewContainer: View {
    let activities: [Activity]
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with view mode selector
            headerView
            
            Divider()
            
            // Activity content based on selected mode
            activityContentView
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("All Activities: \(formatTotalDuration())")
                    .font(.headline)
                
                Text("\(activities.count) activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // View mode selector
            ActivityViewModeSelector()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    @ViewBuilder
    private var activityContentView: some View {
        switch appState.activityViewMode {
        case .unified:
            // Use hierarchical view as "Unified" mode
            ActivitiesView(activities: activities, initialGroupingLevel: currentGroupingLevel)
        case .chronological:
            ChronologicalActivitiesView(activities: activities)
        }
    }
    
    private var currentGroupingLevel: ActivityGroupLevel {
        if appState.selectedProject != nil || appState.selectedSidebar == "Unassigned" {
            return .appName
        } else {
            return .project
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTotalDuration() -> String {
        let totalDuration = activities.reduce(0) { $0 + $1.calculatedDuration }
        return ActivityDataProcessor.formatDuration(totalDuration)
    }
}

#Preview {
    let mockActivities = [
        Activity(
            appName: "Safari",
            appBundleId: "com.apple.Safari",
            duration: 3600,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date()
        ),
        Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            duration: 1800,
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date()
        )
    ]
    
    ActivityViewContainer(activities: mockActivities)
        .environment(AppState())
        .frame(width: 800, height: 600)
}
