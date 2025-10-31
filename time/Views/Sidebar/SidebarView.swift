import SwiftData
import SwiftUI

import os

struct SidebarView: View {
    @State private var isMyProjectsExpanded: Bool = true
    @State private var showingCreateProject = false
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectManager: ProjectManager

    @Query(sort: \Project.sortOrder) private var projects: [Project]

    private var rootProjects: [Project] {
        let roots = projects.filter { $0.parentID == nil }
        return roots.map { root in
            let project = root
            project.children = buildChildren(for: root.id)
            return project
        }
    }

    private func buildChildren(for parentID: String) -> [Project] {
        let children = projects.filter { $0.parentID == parentID }
        return children.map { child in
            let project = child
            project.children = buildChildren(for: child.id)
            return project
        }
    }

    var body: some View {
        List(selection: $appState.selectedSidebar) {
            Section {
                NavigationLink(value: "Activities") {
                    Label("Activities", systemImage: "clock")
                }
                .accessibilityIdentifier("sidebar.activities")
                NavigationLink(value: "Time Entries") {
                    Label("Time Entries", systemImage: "list.bullet.clipboard")
                }
                .accessibilityIdentifier("sidebar.timeEntries")
                NavigationLink(value: "Stats") {
                    Label("Stats", systemImage: "chart.bar")
                }
                .accessibilityIdentifier("sidebar.stats")
                NavigationLink(value: "Reports") {
                    Label("Reports", systemImage: "doc.text")
                }
                .accessibilityIdentifier("sidebar.reports")
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
                    ForEach(rootProjects) { project in
                        ProjectRowView(project: project, level: 0)
                    }
                    .onMove(perform: moveProjects)
                    .deleteDisabled(true)
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
                        .accessibilityHint("Creates a new project at the root level")
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
            EditProjectView(mode: .create(parentID: nil), isPresented: $showingCreateProject)
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
                    if index < rootProjects.count {
                        let project = rootProjects[index]
                        let newIndex = destination > index ? destination - 1 : destination
                        try await projectManager.reorderProject(project, to: newIndex, in: nil)
                    }
                }
            } catch {
                Logger.ui.error("️ Failed to move project: \(error.localizedDescription)")
            }
        }
    }
}
