import SwiftData
import SwiftUI

/// Main view displaying activities in a hierarchical, collapsible structure
struct ActivitiesView: View {
    let activities: [Activity]
    let initialGroupingLevel: ActivityGroupLevel
    
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var activityGroups: [ActivityGroup] = []
    
    init(activities: [Activity], initialGroupingLevel: ActivityGroupLevel = .project) {
        self.activities = activities
        self.initialGroupingLevel = initialGroupingLevel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activities.isEmpty {
                emptyState
            } else {
                // Hierarchical list
                List {
                    ForEach(activityGroups) { group in
                        RecursiveActivityRow(group: group)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear {
            updateGroups()
        }
        .onChange(of: activities) {
            updateGroups()
        }
        // Also update when project list changes (e.g. renaming)
        .onChange(of: projects) {
            updateGroups()
        }
        // Update when grouping level changes (e.g. switching between "Unassigned" and "All Activities")
        .onChange(of: initialGroupingLevel) {
            updateGroups()
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

    private func updateGroups() {
        Task {
            let grouped: [ActivityGroup]
            if initialGroupingLevel == .project {
                grouped = ActivityDataProcessor.groupByProject(activities: activities, projects: projects)
            } else {
                // When starting at app level (e.g. inside a project view), group directly by app
                grouped = ActivityDataProcessor.groupByApp(activities: activities, parentId: "root") ?? []
            }
            
            await MainActor.run {
                self.activityGroups = grouped
            }
        }
    }
}

#Preview {
    ActivitiesView(activities: [])
        .modelContainer(for: [Activity.self, Project.self], inMemory: true)
}

struct RecursiveActivityRow: View {
    let group: ActivityGroup
    @State private var isExpanded: Bool = false
    
    var body: some View {
        if let children = group.children, !children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    RecursiveActivityRow(group: child)
                }
            } label: {
                HierarchicalActivityRow(group: group)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            HierarchicalActivityRow(group: group)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }
}
