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
        var rules: [AutoAssignRule] = []

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
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Project.sortOrder) private var allProjects: [Project]

    init(mode: Mode, isPresented: Binding<Bool>) {
        self.mode = mode
        _isPresented = isPresented
    }

    @State private var formData = ProjectFormData()

    @State private var showingDeleteConfirmation = false
    @State private var showingAddRuleSheet = false
    
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
            Form {
                Section {
                    TextField("Project Name", text: $formData.name)
                        .textFieldStyle(.roundedBorder)
                    
                    if let nameError = formData.nameError {
                        Text(nameError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    ColorPicker("Project Color", selection: $formData.color)
                } header: {
                    Text("Basic Information")
                }
                
                Section {
                    if formData.rules.isEmpty {
                        Text("No rules defined")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(formData.rules) { rule in
                            HStack {
                                if rule.ruleType == .appBundleId {
                                    AppIconView(bundleId: rule.value, size: 20)
                                } else {
                                    Image(systemName: "text.magnifyingglass")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20, height: 20)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(rule.ruleType.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(rule.value)
                                        .font(.body)
                                        .foregroundStyle(.secondary) // Make text color subtle as requested
                                }
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    if let index = formData.rules.firstIndex(where: { $0.id == rule.id }) {
                                        formData.rules.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button {
                        showingAddRuleSheet = true
                    } label: {
                        Label("Add Rule", systemImage: "plus")
                    }
                } header: {
                    Text("Auto Assignment Rules")
                } footer: {
                    Text("Activities matching these rules will be automatically assigned to this project.")
                }
                
                if case .edit = mode {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Project", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Danger Zone")
                    } footer: {
                        Text("Once you delete a project, there is no going back.")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Footer
            VStack(spacing: 16) {
                if let submitError = submitError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(submitError)
                            .foregroundColor(.red)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .offset(x: errorShakeOffset)
                }
                
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button(mode.isEditing ? "Save Changes" : "Create Project") {
                        Task { await saveProjectAsync() }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
            }
            .padding()
            .background(.bar)
        }
        .frame(width: 500, height: 600)
        .navigationTitle(navigationTitle)
        .overlay {
            if showingLoadingOverlay {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                }
            }
        }
        .onAppear {
            initializeFormData()
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddAutoAssignRuleView { newRule in
                formData.rules.append(newRule)
                showingAddRuleSheet = false
            }
        }
        .confirmationDialog("Delete Project", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if case let .edit(project) = mode {
                Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - Computed Properties for Form Logic

    // MARK: - Form Initialization

    /// Initializes form data based on the mode (create vs edit)
    private func initializeFormData() {
        switch mode {
        case .create:
            formData = ProjectFormData()
            formData.name = ""
            formData.color = .blue
            formData.rules = []

        case let .edit(project):
            formData.name = project.name
            formData.color = project.color
            formData.productivityRating = project.productivityRating
            formData.archived = project.isArchived
            
            // Fetch rules manually
            let projectId = project.id
            let descriptor = FetchDescriptor<AutoAssignRule>(predicate: #Predicate { $0.projectId == projectId })
            if let rules = try? modelContext.fetch(descriptor) {
                // Create copies
                formData.rules = rules.map { 
                    AutoAssignRule(projectId: projectId, ruleType: $0.ruleType, value: $0.value) 
                }
            } else {
                formData.rules = []
            }
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
        let project = try await projectManager.createProject(
            name: trimmedName,
            color: formData.color,
            productivityRating: formData.productivityRating,
            isArchived: formData.archived
        )
        
        // Add rules
        if !formData.rules.isEmpty {
            await MainActor.run {
                for rule in formData.rules {
                    rule.projectId = project.id // Set the project ID
                    modelContext.insert(rule)
                }
                try? modelContext.save()
                AutoAssignmentManager.shared.reloadRules(modelContext: modelContext)
            }
        }
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
        
        // Update rules
        await MainActor.run {
            let projectId = project.id
            
            // Remove old rules
            let descriptor = FetchDescriptor<AutoAssignRule>(predicate: #Predicate { $0.projectId == projectId })
            if let existingRules = try? modelContext.fetch(descriptor) {
                for rule in existingRules {
                    modelContext.delete(rule)
                }
            }
            
            // Insert new rules
            for rule in formData.rules {
                rule.projectId = projectId
                modelContext.insert(rule)
            }
            
            try? modelContext.save()
            AutoAssignmentManager.shared.reloadRules(modelContext: modelContext)
        }
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
            
            // Delete associated rules manually (since cascade is gone)
            await MainActor.run {
                let projectId = project.id
                let descriptor = FetchDescriptor<AutoAssignRule>(predicate: #Predicate { $0.projectId == projectId })
                if let rules = try? modelContext.fetch(descriptor) {
                    for rule in rules {
                        modelContext.delete(rule)
                    }
                }
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

// AddAutoAssignRuleView has been moved to its own file: AddAutoAssignRuleView.swift


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
