import SwiftUI

import os

struct EditProjectView: View {
    // MARK: - Mode Definition

    enum Mode {
        case create(parentID: String?)
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

        var parentID: String? {
            switch self {
            case let .create(parentID):
                return parentID
            case let .edit(project):
                return project.parentID
            }
        }
    }

    // MARK: - Form Data Structure

    struct ProjectFormData {
        var name: String = ""
        var color: Color = .blue
        var parentID: String? = nil
        var includeActivities: Bool = false
        var notes: String = ""
        var rating: Double = 0.5
        var archived: Bool = false
        var rules: [ProjectRule] = []
        var ruleGroupCondition: RuleGroupCondition = .all

        var nameError: String? = nil
        var parentError: String? = nil
        var hasErrors: Bool {
            return nameError != nil || parentError != nil
        }
    }

    enum RuleGroupCondition: String, CaseIterable, Identifiable {
        case all = "All"
        case any = "Any"

        var id: String { rawValue }
    }

    enum DeletionStrategy: String, CaseIterable, Identifiable {
        case deleteChildren = "Delete all child projects"
        case moveChildrenToParent = "Move children to parent level"
        case moveChildrenToRoot = "Move children to root level"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .deleteChildren:
                return "All child projects will be permanently deleted"
            case .moveChildrenToParent:
                return "Child projects will be moved to the parent level"
            case .moveChildrenToRoot:
                return "Child projects will be moved to the root level"
            }
        }
    }

    // MARK: - Properties

    let mode: Mode
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var formData = ProjectFormData()
    @State private var isRuleEditorExpanded: Bool = true

    @State private var showingDeleteConfirmation = false
    @State private var deletionStrategy: DeletionStrategy = .moveChildrenToParent
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
        NavigationStack {
            VStack(spacing: 16) {
                Text(navigationTitle)
                    .font(.title)

                Text("Projects let you organize your time by what you worked on.")
                    .foregroundColor(.secondary)

                Form {
                    Section("Basic Information") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Project Name", text: $formData.name, prompt: Text("Enter project name"))
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    validateName()
                                }
                                .onChange(of: formData.name) { _, newValue in
                                    if formData.nameError != nil {
                                        formData.nameError = nil
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if formData.name == newValue {
                                            validateName()
                                        }
                                    }
                                }
                                .accessibilityLabel("Project Name")
                                .accessibilityHint("Enter a unique name for this project")
                                .accessibilityIdentifier("projectForm.nameField")

                            if let nameError = formData.nameError {
                                Label(nameError, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .accessibilityLabel("Name validation error: \(nameError)")
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Picker("Parent Project", selection: $formData.parentID) {
                                Text("None (Root Level)").tag(nil as String?)
                                ForEach(availableParentProjects, id: \.id) { project in
                                    ProjectPickerItem(project: project, level: 0)
                                        .tag(project.id as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: formData.parentID) { _, _ in
                                validateParent()
                            }
                            .accessibilityLabel("Parent Project")
                            .accessibilityHint("Choose a parent project or leave as root level")

                            if let parentError = formData.parentError {
                                Label(parentError, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .accessibilityLabel("Parent validation error: \(parentError)")
                            }
                        }

                        ColorPicker("Project Color", selection: $formData.color, supportsOpacity: false)
                            .accessibilityLabel("Project Color")
                            .accessibilityHint("Choose a color to identify this project")
                    }

                    Section("Advanced Settings") {
                        Toggle(isOn: $formData.includeActivities) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-include Activities")
                                Text("Include activities with \"\(formData.name.isEmpty ? "project name" : formData.name)\" in their title or path")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityLabel("Auto-include Activities")
                        .accessibilityHint("Automatically include activities that match the project name")

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.headline)
                            TextField("Additional notes about this project", text: $formData.notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3 ... 6)
                                .accessibilityLabel("Project Notes")
                                .accessibilityHint("Optional notes about this project")
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Productivity Rating:")
                                    .font(.headline)
                                Spacer()
                                Text(formData.rating > 0.5 ? "PRODUCTIVE" : "UNPRODUCTIVE")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(formData.rating > 0.5 ? .green : .orange)
                            }

                            Slider(value: $formData.rating, in: 0 ... 1) {
                                Text("Productivity Rating")
                            } minimumValueLabel: {
                                Text("Low")
                                    .font(.caption)
                            } maximumValueLabel: {
                                Text("High")
                                    .font(.caption)
                            }
                            .accessibilityLabel("Productivity Rating")
                            .accessibilityValue("\(Int(formData.rating * 100))% productive")
                            .accessibilityHint("Rate how productive this project is")
                        }

                        Toggle(isOn: $formData.archived) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Archive Project")
                                Text("Archived projects are hidden from most views and their rules are ignored")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityLabel("Archive Project")
                        .accessibilityHint("Hide this project from most views")
                    }

                    if case let .edit(project) = mode {
                        ProjectDangerZoneSection(project: project, onDelete: {
                            showingDeleteConfirmation = true
                        })
                        .disabled(isSubmitting || isDeleting)
                    }
                }

                DisclosureGroup("Rule Editor (advanced)", isExpanded: $isRuleEditorExpanded) {
                    VStack {
                        HStack {
                            Picker("Condition", selection: $formData.ruleGroupCondition) {
                                ForEach(RuleGroupCondition.allCases) { condition in
                                    Text(condition.rawValue).tag(condition)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("of the following are true")
                            Spacer()
                            Button(action: addRule) {
                                Image(systemName: "plus")
                            }
                        }

                        ForEach($formData.rules) { $rule in
                            HStack {
                                Picker("Type", selection: $rule.type) {
                                    ForEach(ProjectRuleType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .frame(minWidth: 150)

                                Picker("Condition", selection: $rule.condition) {
                                    ForEach(ProjectRuleCondition.allCases) { condition in
                                        Text(condition.rawValue).tag(condition)
                                    }
                                }
                                .frame(minWidth: 120)

                                TextField("Value", text: $rule.value)

                                Button(action: { removeRule(rule) }) {
                                    Image(systemName: "minus")
                                }
                            }
                        }
                    }
                }

                if let submitError = submitError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .scaleEffect(1.2)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: submitError)
                        Text(submitError)
                            .foregroundColor(.red)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .offset(x: errorShakeOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                            errorShakeOffset = 5
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            errorShakeOffset = 0
                        }

                        #if canImport(UIKit)
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.error)
                        #endif
                    }
                }

                if showingSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .scaleEffect(successPulseScale)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: successPulseScale)
                        Text(mode.isEditing ? "Project updated successfully" : "Project created successfully")
                            .foregroundColor(.green)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)) {
                            successPulseScale = 1.2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            successPulseScale = 1.0
                        }

                        #if canImport(UIKit)
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                        #endif
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isSubmitting || isDeleting)

                    Spacer()

                    AsyncButton(
                        title: mode.isEditing ? "Save Changes" : "Create Project",
                        isLoading: isSubmitting,
                        action: {
                            await saveProjectAsync()
                        }
                    )
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                    .accessibilityIdentifier("projectForm.submitButton")
                }
            }
            .padding()
            .frame(minWidth: 500, idealWidth: 600)
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
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))

                            Text(isSubmitting ? "Saving project..." : "Deleting project...")
                                .font(.headline)
                                .foregroundColor(.primary)

                            if operationProgress > 0 {
                                ProgressView(value: operationProgress, total: 1.0)
                                    .frame(width: 200)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .shadow(radius: 20)
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity
                    ))
                }
            }
            .onAppear {
                initializeFormData()

                formScale = 0.9
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    formScale = 1.0
                }
            }
            .confirmationDialog("Delete Project", isPresented: $showingDeleteConfirmation) {
                if case let .edit(project) = mode {
                    ProjectDeleteConfirmationDialog(
                        project: project,
                        deletionStrategy: $deletionStrategy,
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
    }

    // MARK: - Computed Properties for Form Logic

    /// Available parent projects (excludes the project being edited and its descendants)
    private var availableParentProjects: [Project] {
        switch mode {
        case .create:
            return projectManager.buildProjectTree()
        case let .edit(project):
            let excludedIds = Set([project.id] + project.descendants.map { $0.id })
            return projectManager.projects.filter { !excludedIds.contains($0.id) }
        }
    }

    /// Available projects for time entry reassignment (excludes the project being deleted and its descendants)
    private var availableProjectsForReassignment: [Project] {
        switch mode {
        case .create:
            return []
        case let .edit(project):
            let excludedIds = Set([project.id] + project.descendants.map { $0.id })
            return projectManager.projects.filter { !excludedIds.contains($0.id) }
        }
    }

    // MARK: - Form Initialization

    /// Initializes form data based on the mode (create vs edit)
    private func initializeFormData() {
        switch mode {
        case let .create(parentID):
            formData = ProjectFormData()
            formData.parentID = parentID
            formData.name = ""
            formData.color = .blue

        case let .edit(project):
            formData.name = project.name
            formData.color = project.color
            formData.parentID = project.parentID
            formData.includeActivities = false
            formData.notes = ""
            formData.rating = 0.5
            formData.archived = false
            formData.rules = [ProjectRule()]
            formData.ruleGroupCondition = .all
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

        let existingProjects = projectManager.projects.filter { project in
            project.parentID == formData.parentID &&
                project.name.lowercased() == trimmedName.lowercased()
        }

        let filteredProjects: [Project]
        if case let .edit(currentProject) = mode {
            filteredProjects = existingProjects.filter { $0.id != currentProject.id }
        } else {
            filteredProjects = existingProjects
        }

        if !filteredProjects.isEmpty {
            formData.nameError = "A project with this name already exists at this level"
            return
        }

        formData.nameError = nil
    }

    /// Validates the parent selection with circular reference prevention
    private func validateParent() {
        guard let parentID = formData.parentID else {
            formData.parentError = nil
            return
        }

        guard let parent = projectManager.projects.first(where: { $0.id == parentID }) else {
            formData.parentError = "Selected parent project not found"
            return
        }

        if case let .edit(project) = mode {
            if parent.id == project.id {
                formData.parentError = "A project cannot be its own parent"
                return
            }

            if project.isAncestorOf(parent) {
                formData.parentError = "Cannot create circular reference - selected parent is a child of this project"
                return
            }

            if parent.depth >= 4 {
                formData.parentError = "Project hierarchy would be too deep (maximum 5 levels)"
                return
            }

            let validationResult = parent.validateAsParentOf(project)
            switch validationResult {
            case let .failure(error):
                formData.parentError = error.localizedDescription
                return
            case .success:
                break
            }
        } else {
            if parent.depth >= 4 {
                formData.parentError = "Selected parent is too deep in hierarchy (maximum 5 levels)"
                return
            }
        }

        formData.parentError = nil
    }

    /// Validates the entire form before submission
    private func validateForm() -> Bool {
        validateName()
        validateParent()

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

    /// Creates a new project asynchronously
    private func createNewProjectAsync() async throws {
        let trimmedName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let existingProjects = projectManager.projects.filter { project in
            project.parentID == formData.parentID &&
                project.name.lowercased() == trimmedName.lowercased()
        }

        if !existingProjects.isEmpty {
            throw ProjectCreationError.duplicateName
        }

        let newProject = Project(
            name: trimmedName,
            color: formData.color,
            parentID: formData.parentID,
            sortOrder: calculateNextSortOrder()
        )

        _ = try await projectManager.createProject(name: newProject.name, color: newProject.color, parentID: newProject.parentID)
    }

    /// Updates an existing project asynchronously
    private func updateExistingProjectAsync(_ project: Project) async throws {
        let trimmedName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let existingProjects = projectManager.projects.filter { existingProject in
            existingProject.parentID == formData.parentID &&
                existingProject.name.lowercased() == trimmedName.lowercased() &&
                existingProject.id != project.id
        }

        if !existingProjects.isEmpty {
            throw ProjectCreationError.duplicateName
        }

        await MainActor.run {
            project.name = trimmedName
            project.color = formData.color

            if project.parentID != formData.parentID {
                if let oldParentID = project.parentID,
                   let oldParent = projectManager.projects.first(where: { $0.id == oldParentID })
                {
                    oldParent.removeChild(project)
                }

                project.parentID = formData.parentID

                if let newParentID = formData.parentID,
                   let newParent = projectManager.projects.first(where: { $0.id == newParentID })
                {
                    newParent.addChild(project)
                }

                project.sortOrder = calculateNextSortOrder()
            }

            appState.objectWillChange.send()
        }
    }

    /// Calculates the next sort order for the current parent
    private func calculateNextSortOrder() -> Int {
        let siblings = projectManager.projects.filter { $0.parentID == formData.parentID }
        return siblings.map { $0.sortOrder }.max() ?? 0 + 1
    }

    // MARK: - Delete Functionality

    /// Deletes the project with the selected strategy
    private func deleteProject() {
        guard case let .edit(project) = mode else { return }

        Task {
            await deleteProjectAsync(project)
        }
    }

    /// Deletes the project asynchronously with error handling
    private func deleteProjectAsync(_ project: Project) async {
        isDeleting = true
        submitError = nil

        defer {
            isDeleting = false
        }

        do {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            let children = await MainActor.run { project.children }

            switch deletionStrategy {
            case .deleteChildren:
                for child in children {
                    // Clear selection if deleting selected project
                    if appState.selectedProject?.id == child.id {
                        await MainActor.run { appState.clearSelection() }
                    }
                    try await projectManager.deleteProject(child)
                }

            case .moveChildrenToParent:
                await MainActor.run {
                    for child in children {
                        child.parentID = project.parentID
                        child.sortOrder = calculateNextSortOrderForParent(project.parentID)
                    }
                }

            case .moveChildrenToRoot:
                await MainActor.run {
                    for child in children {
                        child.parentID = nil
                        child.sortOrder = calculateNextSortOrderForParent(nil)
                    }
                }
            }

            if let targetProject = timeEntryReassignmentTarget {
                Logger.ui.debug("Would reassign time entries from \(project.name) to \(targetProject.name)")
            }

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

    /// Calculates the next sort order for a specific parent
    private func calculateNextSortOrderForParent(_ parentID: String?) -> Int {
        let siblings = projectManager.projects.filter { $0.parentID == parentID }
        return siblings.map { $0.sortOrder }.max() ?? 0 + 1
    }

    // MARK: - Rule Management

    private func addRule() {
        formData.rules.append(ProjectRule())
    }

    private func removeRule(_ rule: ProjectRule) {
        formData.rules.removeAll { $0.id == rule.id }
    }
}

// MARK: - Rule Types

enum ProjectRuleType: String, CaseIterable, Identifiable {
    case application = "Application"
    case windowTitle = "Window Title"
    case url = "URL"
    case path = "Path"

    var id: String { rawValue }
}

enum ProjectRuleCondition: String, CaseIterable, Identifiable {
    case contains = "Contains"
    case equals = "Equals"
    case startsWith = "Starts With"
    case endsWith = "Ends With"
    case matches = "Matches"

    var id: String { rawValue }
}

struct ProjectRule: Identifiable {
    let id = UUID()
    var type: ProjectRuleType = .application
    var condition: ProjectRuleCondition = .contains
    var value: String = ""
}

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
    @Binding var deletionStrategy: EditProjectView.DeletionStrategy
    @Binding var timeEntryReassignmentTarget: Project?
    let availableProjects: [Project]
    let onConfirm: () -> Void

    var body: some View {
        Group {
            if !project.children.isEmpty {
                Text("This project has \(project.children.count) child project(s). What should happen to them?")

                ForEach(EditProjectView.DeletionStrategy.allCases) { strategy in
                    Button(strategy.rawValue) {
                        deletionStrategy = strategy
                        onConfirm()
                    }
                }
            } else {
                Button("Delete", role: .destructive) {
                    onConfirm()
                }
            }

            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Error Types

enum ProjectCreationError: LocalizedError {
    case duplicateName
    case invalidParent
    case networkError

    var errorDescription: String? {
        switch self {
        case .duplicateName:
            return "A project with this name already exists at this level"
        case .invalidParent:
            return "The selected parent project is invalid"
        case .networkError:
            return "Network error occurred while saving"
        }
    }
}

// MARK: - AsyncButton Component

struct AsyncButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void

    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle())
                }
                Text(title)
            }
        }
        .disabled(isLoading)
    }
}

#Preview("Create Mode") {
    EditProjectView(mode: .create(parentID: nil), isPresented: .constant(true))
        .environmentObject(AppState())
}

#Preview("Edit Mode") {
    let sampleProject = Project(name: "Sample Project", color: .blue)
    return EditProjectView(mode: .edit(sampleProject), isPresented: .constant(true))
        .environmentObject(AppState())
}
