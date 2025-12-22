import SwiftUI
import SwiftData

import os
#if canImport(AppKit)
import AppKit
#endif

struct EditProjectView: View {
    // MARK: - Mode Definition

    enum Mode {
        case create
        case edit(Project)

        var isEditing: Bool {
            switch self {
            case .edit:
                return true
            case .create:
                return false
            }
        }

        var project: Project? {
            switch self {
            case let .edit(project):
                return project
            case .create:
                return nil
            }
        }
    }

    // MARK: - Form Data Structure

    struct ProjectFormData {
        var name: String = ""
        var color: Color = .blue
        var productivityRating: Double = 0.5
        var archived: Bool = false

        var nameError: String? = nil
        var hasErrors: Bool {
            return nameError != nil
        }
    }


    // MARK: - Properties

    let mode: Mode
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager

    @Query(sort: \Project.sortOrder) private var allProjects: [Project]

    init(mode: Mode, isPresented: Binding<Bool>) {
        self.mode = mode
        _isPresented = isPresented
    }

    @State private var formData = ProjectFormData()

    @State private var showingDeleteConfirmation = false
    @State private var timeEntryReassignmentTarget: Project? = nil

    @State private var isSubmitting = false
    @State private var isDeleting = false
    @State private var submitError: String? = nil
    @State private var showingSuccessMessage = false
    @State private var operationProgress: Double = 0.0
    @State private var showingLoadingOverlay = false

    @State private var formScale: CGFloat = 1.0
    @State private var errorShakeOffset: CGFloat = 0
    @State private var successPulseScale: CGFloat = 1.0

    // MARK: - Computed Properties

    private var navigationTitle: String {
        switch mode {
        case .create:
            return "Create Project"
        case .edit:
            return "Edit Project"
        }
    }

    private var isFormValid: Bool {
        return !formData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !formData.hasErrors && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Text(navigationTitle)
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("Projects let you organize your time by what you worked on.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Form Content
                    VStack(alignment: .leading, spacing: 20) {
                        // Basic Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Basic Information")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                                GridRow {
                                    Text("Project Name")
                                        .gridColumnAlignment(.trailing)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        TextField("Enter project name", text: $formData.name)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: .infinity)
                                        
                                        if let nameError = formData.nameError {
                                            Text(nameError)
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                
                                GridRow {
                                    Text("Project Color")
                                        .gridColumnAlignment(.trailing)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        ColorPicker("", selection: $formData.color)
                                            .labelsHidden()
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)

                        // Productivity Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Advanced Settings")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Productivity Rating")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formData.productivityRating > 0.5 ? "PRODUCTIVE" : "UNPRODUCTIVE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(formData.productivityRating > 0.5 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                        .foregroundColor(formData.productivityRating > 0.5 ? .green : .orange)
                                        .cornerRadius(4)
                                }
                                
                                Slider(value: $formData.productivityRating, in: 0...1) {
                                    Text("Productivity Rating")
                                } minimumValueLabel: {
                                    Text("Low").font(.caption2).foregroundColor(.secondary)
                                } maximumValueLabel: {
                                    Text("High").font(.caption2).foregroundColor(.secondary)
                                }
                                .accentColor(formData.productivityRating > 0.5 ? .green : .orange)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                Toggle(isOn: $formData.archived) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Archive Project")
                                            .font(.body)
                                        Text("Archived projects are hidden from most views")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }

                    if case let .edit(project) = mode {
                        ProjectDangerZoneSection(project: project, onDelete: {
                            showingDeleteConfirmation = true
                        })
                        .disabled(isSubmitting || isDeleting)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
            }

            // Messages & Footer
            VStack(spacing: 12) {
                if let submitError = submitError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(submitError)
                            .foregroundColor(.red)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .offset(x: errorShakeOffset)
                }

                if showingSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(mode.isEditing ? "Project updated successfully" : "Project created successfully")
                            .foregroundColor(.green)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSubmitting || isDeleting)

                    Spacer()

                    Button(action: {
                        Task { await saveProjectAsync() }
                    }) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 10)
                        } else {
                            Text(mode.isEditing ? "Save Changes" : "Create Project")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(minWidth: 550, maxWidth: 650, minHeight: 500, maxHeight: 800)
        .navigationTitle(navigationTitle)
        .scaleEffect(formScale)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: formScale)
        .overlay {
            if showingLoadingOverlay {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(isSubmitting ? "Saving project..." : "Deleting project...")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if operationProgress > 0 {
                            ProgressView(value: operationProgress, total: 1.0)
                                .frame(width: 200)
                        }
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
                }
            }
        }
        .onAppear {
            initializeFormData()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                formScale = 1.0
            }
        }
        .confirmationDialog("Delete Project", isPresented: $showingDeleteConfirmation) {
            if case let .edit(project) = mode {
                ProjectDeleteConfirmationDialog(
                    project: project,
                    timeEntryReassignmentTarget: $timeEntryReassignmentTarget,
                    availableProjects: availableProjectsForReassignment,
                    onConfirm: {
                        deleteProject()
                    }
                )
            }
        } message: {
            if case let .edit(project) = mode {
                Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - Computed Properties for Form Logic

    /// Available projects for time entry reassignment (excludes the project being deleted)
    private var availableProjectsForReassignment: [Project] {
        switch mode {
        case .create:
            return []
        case let .edit(project):
            return allProjects.filter { $0.id != project.id }
        }
    }

    // MARK: - Form Initialization

    /// Initializes form data based on the mode (create vs edit)
    private func initializeFormData() {
        switch mode {
        case .create:
            formData = ProjectFormData()
            formData.name = ""
            formData.color = .blue

        case let .edit(project):
            formData.name = project.name
            formData.color = project.color
            formData.productivityRating = project.productivityRating
            formData.archived = project.isArchived
        }
    }

    // MARK: - Validation Methods

    /// Validates the project name with comprehensive checks
    private func validateName() {
        let trimmedName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            formData.nameError = "Project name is required"
            return
        }

        if trimmedName.count < 2 {
            formData.nameError = "Project name must be at least 2 characters"
            return
        }

        if trimmedName.count > 100 {
            formData.nameError = "Project name cannot exceed 100 characters"
            return
        }

        let invalidCharacters = CharacterSet(charactersIn: "<>:\"/\\|?*")
        if trimmedName.rangeOfCharacter(from: invalidCharacters) != nil {
            formData.nameError = "Project name contains invalid characters"
            return
        }

        let reservedNames = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
        if reservedNames.contains(trimmedName.uppercased()) {
            formData.nameError = "This name is reserved and cannot be used"
            return
        }

        let existingProjects = allProjects.filter { project in
                project.name.lowercased() == trimmedName.lowercased()
        }

        let filteredProjects: [Project]
        if case let .edit(currentProject) = mode {
            filteredProjects = existingProjects.filter { $0.id != currentProject.id }
        } else {
            filteredProjects = existingProjects
        }

        if !filteredProjects.isEmpty {
            formData.nameError = "A project with this name already exists"
            return
        }

        formData.nameError = nil
    }

    /// Validates the entire form before submission
    private func validateForm() -> Bool {
        validateName()
        return !formData.hasErrors
    }

    // MARK: - Form Actions

    /// Saves the project asynchronously with enhanced UX and error handling
    private func saveProjectAsync() async {
        submitError = nil
        showingSuccessMessage = false
        isSubmitting = true
        operationProgress = 0.0

        withAnimation(.easeInOut(duration: 0.3)) {
            showingLoadingOverlay = true
        }

        defer {
            isSubmitting = false
            withAnimation(.easeInOut(duration: 0.3)) {
                showingLoadingOverlay = false
            }
        }

        do {
            operationProgress = 0.1
            guard validateForm() else {
                return
            }

            operationProgress = 0.3

            #if canImport(UIKit)
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            #endif

            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            operationProgress = 0.5

            switch mode {
            case .create:
                try await createNewProjectAsync()
            case let .edit(project):
                try await updateExistingProjectAsync(project)
            }

            operationProgress = 0.9
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            operationProgress = 1.0

            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showingSuccessMessage = true
            }

            #if canImport(UIKit)
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            #endif

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    formScale = 0.9
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isPresented = false
                }
            }

        } catch {
            submitError = error.localizedDescription
            operationProgress = 0.0

            #if canImport(UIKit)
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            #endif
        }
    }

    private func createNewProjectAsync() async throws {
        let trimmedName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await projectManager.createProject(
            name: trimmedName,
            color: formData.color,
            productivityRating: formData.productivityRating,
            isArchived: formData.archived
        )
    }

    /// Updates an existing project asynchronously
    private func updateExistingProjectAsync(_ project: Project) async throws {
        let trimmedName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let existingProjects = allProjects.filter { existingProject in
                existingProject.name.lowercased() == trimmedName.lowercased() &&
                existingProject.id != project.id
        }

        if !existingProjects.isEmpty {
            throw ProjectCreationError.duplicateName
        }

        try await projectManager.updateProject(
            project,
            name: trimmedName,
            color: formData.color,
            productivityRating: formData.productivityRating,
            isArchived: formData.archived
        )
    }

    /// Calculates the next sort order
    private func calculateNextSortOrder() -> Int {
        return (allProjects.map { $0.sortOrder }.max() ?? 0) + 1
    }

    // MARK: - Delete Functionality

    /// Deletes the project
    private func deleteProject() {
        guard case let .edit(project) = mode else { return }
        
        Task {
            await deleteProjectAsync(project)
        }
    }

    /// Deletes the project asynchronously
    private func deleteProjectAsync(_ project: Project) async {
        isDeleting = true
        submitError = nil

        defer {
            isDeleting = false
        }

        do {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            // Clear selection if deleting selected project
            if appState.selectedProject?.id == project.id {
                await MainActor.run { appState.clearSelection() }
            }

            try await projectManager.deleteProject(project)

            await MainActor.run {
                isPresented = false
            }

        } catch {
            await MainActor.run {
                submitError = "Failed to delete project: \(error.localizedDescription)"
            }
        }
    }


}

// MARK: - Rule Types and Components



// MARK: - Supporting Components

/// Danger zone section for project deletion
struct ProjectDangerZoneSection: View {
    let project: Project
    let onDelete: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Danger Zone")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                Text("Once you delete a project, there is no going back. Please be certain.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete Project")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isEnabled ? Color.red : Color.gray)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete Project")
                .accessibilityHint("Permanently delete this project")
            }
            .padding(.vertical, 8)
        } header: {
            EmptyView()
        }
    }
}

/// Confirmation dialog for project deletion
struct ProjectDeleteConfirmationDialog: View {
    let project: Project
    @Binding var timeEntryReassignmentTarget: Project?
    let availableProjects: [Project]
    let onConfirm: () -> Void

    var body: some View {
        Group {
            Button("Delete", role: .destructive) {
                onConfirm()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Error Types

enum ProjectCreationError: LocalizedError {
    case duplicateName
    case networkError

    var errorDescription: String? {
        switch self {
        case .duplicateName:
            return "A project with this name already exists"
        case .networkError:
            return "Network error occurred while saving"
        }
    }
}


#Preview("Create Mode") {
    EditProjectView(mode: .create, isPresented: .constant(true))
        .environment(AppState())
}

#Preview("Edit Mode") {
    let sampleProject = Project(name: "Sample Project", color: .blue)
    return EditProjectView(mode: .edit(sampleProject), isPresented: .constant(true))
        .environment(AppState())
}
