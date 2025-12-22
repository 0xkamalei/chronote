import SwiftData
import SwiftUI

import os

struct SidebarView: View {
    @State private var isMyProjectsExpanded: Bool = true
    @State private var showingCreateProject = false
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager

    @Query(sort: \Project.sortOrder) private var projects: [Project]

    var body: some View {
        @Bindable var bindableAppState = appState
        
        List(selection: $bindableAppState.selectedSidebar) {
            Section {
                NavigationLink(value: "Activities") {
                    Label("Activities", systemImage: "clock")
                }
                .accessibilityIdentifier("sidebar.activities")
            }

            Section(header: Text("Projects")) {
                HStack {
                    Label("All Activities", systemImage: "tray.full")
                    Spacer()
                    Text("37m")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
                .background(appState.isSpecialItemSelected("All Activities") ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture {
                    appState.selectSpecialItem("All Activities")
                }
                .accessibilityIdentifier("sidebar.allActivities")

                HStack {
                    Label("Unassigned", systemImage: "questionmark.circle")
                    Spacer()
                    Text("37m")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
                .background(appState.isSpecialItemSelected("Unassigned") ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture {
                    appState.selectSpecialItem("Unassigned")
                }
                .accessibilityIdentifier("sidebar.unassigned")

                DisclosureGroup(isExpanded: $isMyProjectsExpanded) {
                    ForEach(projects) { project in
                        ProjectRowView(project: project)
                    }
                    .onMove(perform: moveProjects)
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("My Projects")
                        Spacer()
                        Button(action: {
                            showingCreateProject = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create New Project")
                        .accessibilityHint("Creates a new project")
                        .help("Create New Project")
                        .accessibilityIdentifier("sidebar.createProjectButton")
                    }
                    .contentShape(Rectangle())
                    .background(appState.isSpecialItemSelected("My Projects") ? Color.accentColor.opacity(0.2) : Color.clear)
                    .onTapGesture {
                        appState.selectSpecialItem("My Projects")
                    }
                    .accessibilityIdentifier("sidebar.myProjects")
                }
                .accessibilityIdentifier("sidebar.myProjectsDisclosure")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Time Tracker")
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
