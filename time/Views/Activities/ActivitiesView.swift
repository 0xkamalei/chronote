import SwiftUI

struct ActivitiesView: View {
    let activities: [Activity]
    @State private var hierarchyGroups: [ActivityHierarchyGroup] = []
    @State private var totalDuration: TimeInterval = 0

    // Fixed configuration for MVP - Unified mode with project grouping
    private let displayMode = "Unified"
    private let groupByProject = true

    // Data inclusion options (for future implementation)
    @State private var includeTimeEntries = true
    @State private var includeAppUsage = true
    @State private var includeTitles = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with total activity time
            HStack {
                Text("All Activities: \(formattedTotalDuration)")
                    .font(.headline)

                Spacer()

                // Fixed display mode indicator
                Text(displayMode)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Hierarchical activity list
            List {
                if hierarchyGroups.isEmpty {
                    // Empty state
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("No activities found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("0m 0s")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                } else {
                    ForEach(hierarchyGroups) { group in
                        HierarchicalActivityRow(group: group)
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 12))
                    }
                }
            }
            .listStyle(.plain)
        }
        .onAppear {
            buildHierarchy()
        }
        .onChange(of: activities) {
            buildHierarchy()
        }
    }

    // MARK: - Private Methods

    /// Builds the hierarchical structure using ActivityDataProcessor
    private func buildHierarchy() {
        // Use ActivityDataProcessor to create the hierarchy
        hierarchyGroups = ActivityDataProcessor.buildHierarchy(
            activities: activities,
            timeEntries: MockData.timeEntries,
            projects: MockData.projects
        )

        // Calculate total duration across all visible activities
        totalDuration = ActivityDataProcessor.calculateTotalDurationForActivities(activities)
    }

    /// Formats the total duration for display in the header
    private var formattedTotalDuration: String {
        return ActivityDataProcessor.formatDuration(totalDuration)
    }
}

#Preview {
    ActivitiesView(activities: MockData.activities)
}
