import SwiftData
import SwiftUI

import os

struct SidebarView: View {
    @State private var isMyProjectsExpanded: Bool = true
    @State private var showingCreateProject = false
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var activityQueryManager: ActivityQueryManager

    @Query(sort: \Project.sortOrder) private var projects: [Project]
    
    // Unified selection enum
    enum SidebarSelection: Hashable {
        case allActivities
        case unassigned
        case myProjects // Parent category, though usually not selectable in the same way, but needed for consistency
        case project(Project)
    }
    
    private var selection: Binding<SidebarSelection?> {
        Binding {
            if let project = appState.selectedProject {
                return .project(project)
            } else if let sidebar = appState.selectedSidebar {
                switch sidebar {
                case "All Activities": return .allActivities
                case "Unassigned": return .unassigned
                case "My Projects": return .myProjects
                default: return nil
                }
            }
            return nil
        } set: { newValue in
            switch newValue {
            case .allActivities:
                appState.selectSpecialItem("All Activities")
            case .unassigned:
                appState.selectSpecialItem("Unassigned")
            case .myProjects:
                appState.selectSpecialItem("My Projects")
            case .project(let project):
                appState.selectProject(project)
            case nil:
                // Handle deselection if needed, though sidebar usually enforces one selection
                break
            }
        }
    }
    
    var body: some View {
        List(selection: selection) {
            Section {
                NavigationLink(value: SidebarSelection.allActivities) {
                    Label("All Activities", systemImage: "tray.full")
                        .padding(.vertical, 2)
                }
                .accessibilityIdentifier("sidebar.allActivities")

                NavigationLink(value: SidebarSelection.unassigned) {
                    Label("Unassigned", systemImage: "questionmark.circle")
                        .padding(.vertical, 2)
                }
                .accessibilityIdentifier("sidebar.unassigned")
            } header: {
                Text("Activities")
            }

            Section(header: Text("Projects")) {
                DisclosureGroup(isExpanded: $isMyProjectsExpanded) {
                    ForEach(projects) { project in
                        NavigationLink(value: SidebarSelection.project(project)) {
                            ProjectRowView(project: project)
                        }
                        .accessibilityIdentifier("sidebar.project.\(project.id)")
                    }
                    .onMove(perform: moveProjects)
                } label: {
                    Label("My Projects", systemImage: "folder")
                        .padding(.vertical, 2)
                }
                .accessibilityIdentifier("sidebar.myProjectsDisclosure")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Time Tracker")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingCreateProject = true
                }) {
                    Label("New Project", systemImage: "plus.rectangle.on.folder")
                }
                .accessibilityIdentifier("sidebar.newProjectButton")
                .help("Create a new project")
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            EditProjectView(mode: .create, isPresented: $showingCreateProject)
        }
        .onAppear {
            appState.validateCurrentSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectDidChange)) { notification in
            if let changedProject = notification.object as? Project {
                Logger.ui.info("Project changed: \(changedProject.name)")
            }
            appState.validateCurrentSelection()
        }
    }

    private func moveProjects(from source: IndexSet, to destination: Int) {
        Task {
            do {
                for index in source {
                    if index < projects.count {
                        let project = projects[index]
                        let newIndex = destination > index ? destination - 1 : destination
                        try await projectManager.reorderProject(project, to: newIndex)
                    }
                }
            } catch {
                Logger.ui.error("️ Failed to move project: \(error.localizedDescription)")
            }
        }
    }
}


extension Notification.Name {
    static let projectDidChange = Notification.Name("projectDidChange")
}
