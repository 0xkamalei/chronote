import SwiftUI

import os

struct ProjectRightClickMenu: View {
    let project: Project
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showingEditProject = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCreateChild = false
    @State private var deletionStrategy: DeletionStrategy = .moveChildrenToParent
    @State private var timeEntryReassignmentTarget: Project? = nil

    var body: some View {
        Group {
            Button("Edit Project", systemImage: "pencil") {
                showingEditProject = true
            }

            Button("Add Child Project", systemImage: "plus") {
                showingCreateChild = true
            }

            Divider()

            Button("Delete Project", systemImage: "trash", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(
                mode: .edit(project),
                isPresented: $showingEditProject
            )
        }
        .sheet(isPresented: $showingCreateChild) {
            EditProjectView(
                mode: .create(parentID: project.id),
                isPresented: $showingCreateChild
            )
        }
        .confirmationDialog(
            "Delete Project",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(project.name)'? This action cannot be undone.")
        }
    }

    /// Available projects for time entry reassignment (excludes the project being deleted)
    private var availableProjectsForReassignment: [Project] {
        return projectManager.projects.filter { $0.id != project.id }
    }

    private func deleteProject() {
        Task {
            do {
                // Clear selection if deleting selected project
                if appState.selectedProject?.id == project.id {
                    await MainActor.run { appState.clearSelection() }
                }
                try await projectManager.deleteProject(project, strategy: deletionStrategy)
            } catch {
                Logger.ui.error("Failed to delete project: \(error)")
            }
        }
    }
}
