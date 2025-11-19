import SwiftData
import SwiftUI

/// Main view displaying activities in a hierarchical, collapsible structure
struct ActivitiesView: View {
    let activities: [Activity]

    @Query private var timeEntries: [TimeEntry]
    @Query private var projects: [Project]

    @State private var hierarchyGroups: [ActivityHierarchyGroup] = []
    @State private var totalDuration: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activities.isEmpty {
                emptyState
            } else {
                // Header with total duration
                headerView

                // Hierarchical list
                List {
                    ForEach(hierarchyGroups, id: \.id) { group in
                        HierarchicalActivityRow(group: group)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            buildHierarchy()
        }
        .onChange(of: activities) {
            buildHierarchy()
        }
        .onChange(of: timeEntries) {
            buildHierarchy()
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No activities recorded")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Activities will appear here as you switch between apps")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activities")
                    .font(.headline)

                Text("Total: \(ActivityDataProcessor.formatDuration(totalDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(activities.count) activities")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(timeEntries.count) entries")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }/

    // MARK: - Methods

    private func buildHierarchy() {
        hierarchyGroups = ActivityDataProcessor.buildHierarchy(
            activities: activities,
            timeEntries: timeEntries,
            projects: projects
        )

        totalDuration = ActivityDataProcessor.calculateTotalDuration(for: activities)
    }
}

#Preview {
    ActivitiesView(activities: [])
        .modelContainer(for: Activity.self, inMemory: true)
}
