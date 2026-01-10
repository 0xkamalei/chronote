import os
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct ProjectRowView: View {
    var project: Project
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var showingEditProject = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(project.color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            Text(project.name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit Project", systemImage: "pencil") {
                showingEditProject = true
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

    private func deleteProject() {
        Task {
            do {
                // Clear selection if deleting selected project
                if appState.selectedProject?.id == project.id {
                    await MainActor.run { appState.clearSelection() }
                }
                try await projectManager.deleteProject(project)
            } catch {
                Logger.ui.error("Failed to delete project: \(error)")
            }
        }
    }
}
