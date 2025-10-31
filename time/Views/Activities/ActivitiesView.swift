import SwiftData
import SwiftUI

struct ActivitiesView: View {
    let activities: [Activity]
    @State private var hierarchyGroups: [ActivityHierarchyGroup] = []
    @State private var totalDuration: TimeInterval = 0

    private let displayMode = "Unified"
    private let groupByProject = true

    @State private var includeTimeEntries = true
    @State private var includeAppUsage = true
    @State private var includeTitles = true

    @ObservedObject private var timeEntryManager = TimeEntryManager.shared
    @ObservedObject private var projectManager = ProjectManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("All Activities: \(formattedTotalDuration)")
                    .font(.headline)
                    .accessibilityIdentifier("activities.header.total")

                Spacer()

                // Toggle controls
                HStack(spacing: 12) {
                    Toggle("Time Entries", isOn: $includeTimeEntries)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .accessibilityIdentifier("activities.toggle.timeEntries")

                    Toggle("App Usage", isOn: $includeAppUsage)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .accessibilityIdentifier("activities.toggle.appUsage")
                }

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

            List {
                if hierarchyGroups.isEmpty {
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
                    .accessibilityIdentifier("activities.emptyState")
                } else {
                    ForEach(hierarchyGroups) { group in
                        HierarchicalActivityRow(group: group)
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 12))
                            .accessibilityIdentifier("activities.row.\(group.id)")
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("activities.list")
        }
        .onAppear {
            buildHierarchy()
        }
        .onChange(of: activities) {
            buildHierarchy()
        }
        .onChange(of: includeTimeEntries) {
            buildHierarchy()
        }
        .onChange(of: includeAppUsage) {
            buildHierarchy()
        }
        .onChange(of: timeEntryManager.timeEntries) {
            buildHierarchy()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryDidChange)) { _ in
            // Rebuild hierarchy when time entries change
            buildHierarchy()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryWasDeleted)) { _ in
            // Rebuild hierarchy when time entries are deleted
            buildHierarchy()
        }
    }

    // MARK: - Private Methods

    /// Builds the hierarchical structure using ActivityDataProcessor
    private func buildHierarchy() {
        let filteredActivities = includeAppUsage ? activities : []
        let timeEntries = includeTimeEntries ? timeEntryManager.timeEntries : []

        hierarchyGroups = ActivityDataProcessor.buildHierarchy(
            activities: filteredActivities,
            timeEntries: timeEntries,
            projects: projectManager.projects,
            includeTimeEntries: includeTimeEntries
        )

        // Calculate total duration including time entries if enabled
        let activitiesDuration = ActivityDataProcessor.calculateTotalDurationForActivities(filteredActivities)
        let timeEntriesDuration = timeEntries.reduce(0) { $0 + $1.duration }
        totalDuration = activitiesDuration + timeEntriesDuration
    }

    /// Formats the total duration for display in the header
    private var formattedTotalDuration: String {
        return ActivityDataProcessor.formatDuration(totalDuration)
    }
}

#Preview {
    let sampleActivities = [
        Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            appTitle: "TimeVibe Project",
            duration: 3600,
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-3600),
            icon: "hammer"
        ),
        Activity(
            appName: "Safari",
            appBundleId: "com.apple.Safari",
            appTitle: "SwiftData Documentation",
            duration: 1800,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-1800),
            icon: "safari"
        )
    ]

    ActivitiesView(activities: sampleActivities)
}
