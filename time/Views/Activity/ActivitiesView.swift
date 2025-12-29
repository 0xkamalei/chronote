import SwiftData
import SwiftUI

/// Main view displaying activities in a hierarchical, collapsible structure
struct ActivitiesView: View {
    let activities: [Activity]
    let initialGroupingLevel: ActivityGroupLevel
    
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var activityGroups: [ActivityGroup] = []
    @State private var selection: Set<String> = []
    
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
                        RecursiveActivityRow(group: group, selection: $selection)
                    }
                }
                .listStyle(.plain)
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
        .background(Color(nsColor: .windowBackgroundColor))
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
    @Binding var selection: Set<String>
    @State private var isExpanded: Bool = false
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var allProjects: [Project]
    
    var body: some View {
        if let children = group.children, !children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    RecursiveActivityRow(group: child, selection: $selection)
                }
            } label: {
                HierarchicalActivityRow(group: group, isSelected: selection.contains(group.id))
                    .contentShape(Rectangle())
                    .gesture(TapGesture(count: 2).onEnded {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    })
                    .simultaneousGesture(TapGesture().onEnded {
                        selection = [group.id]
                    })
                    .contextMenu {
                        assignMenu
                    }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            HierarchicalActivityRow(group: group, isSelected: selection.contains(group.id))
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    selection = [group.id]
                })
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .contextMenu {
                    assignMenu
                }
        }
    }
    
    private var assignMenu: some View {
        Menu("Assign to Project") {
            Button("Unassigned") {
                assignToProject(nil)
            }
            
            Divider()
            
            ForEach(allProjects) { project in
                Button {
                    assignToProject(project)
                } label: {
                    HStack {
                        Circle()
                            .fill(project.color)
                            .frame(width: 8, height: 8)
                        Text(project.name)
                    }
                }
            }
        }
    }
    
    private func assignToProject(_ project: Project?) {
        // Update all activities in this group
        for activity in group.activities {
            activity.projectId = project?.id
        }
        
        // Save changes
        try? modelContext.save()
    }
}
