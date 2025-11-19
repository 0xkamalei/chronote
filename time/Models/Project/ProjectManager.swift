import AppKit
import Foundation
import SwiftData
import SwiftUI

import os

// MARK: - Supporting Types

/// Enum for drag and drop position
enum DropPosition {
    case above
    case below
    case inside
    case invalid
}

/// Data structure for deletion confirmation dialogs
struct DeletionConfirmationData {
    let project: Project
    let hasActiveTimer: Bool
    let timeEntryCount: Int
    let childrenCount: Int
    let childrenWithIssues: [Project]
    let availableStrategies: [DeletionStrategy]
    let recommendedStrategy: DeletionStrategy
    let timeEntryReassignmentOptions: [Project]
}

@MainActor
class ProjectManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ProjectManager()

    // MARK: - Published Properties

    @Published private(set) var projects: [Project] = []
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private Properties

    private var modelContext: ModelContext?

    // MARK: - Initialization

    private init() {
        projects = []
    }

    /// Sets the SwiftData model context for persistence operations and initializes project tracking
    /// - Parameter modelContext: The ModelContext to use for SwiftData operations
    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext

        Task { @MainActor in
            do {
                try await loadProjects()
                enableAutoSave()
                Logger.projectManager.info("ProjectManager initialized with modelContext")
            } catch {
                Logger.projectManager.error("️ Failed to load projects after setting modelContext: \(error.localizedDescription)")
            }
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil

        debounceTimer?.invalidate()
        debounceTimer = nil

        cacheInvalidationTimer?.invalidate()
        cacheInvalidationTimer = nil

        treeTraversalCache.removeAll()
        projectLookupCache.removeAll()

        Logger.projectManager.debug("ProjectManager deallocated and cleaned up")
    }

    // MARK: - Persistence and Loading

    /// Loads projects from persistent storage
    /// - Throws: ProjectError if loading fails completely
    func loadProjects() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await loadProjectsFromPersistence()
        } catch {
            Logger.projectManager.error("️ Failed to load projects from persistence: \(error.localizedDescription)")

            Logger.projectManager.debug("Initializing with empty projects array")
            projects = []
        }

        updateProjectTree()

        Logger.projectManager.info("Loaded \(self.projects.count) projects")
    }

    /// Loads projects from persistent storage (SwiftData, Core Data, etc.)
    /// - Throws: ProjectError if persistence loading fails
    private func loadProjectsFromPersistence() async throws {
        guard let modelContext = modelContext else {
            throw ProjectError.persistenceFailure("ModelContext not available")
        }

        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)])

        do {
            let fetchedProjects = try modelContext.fetch(descriptor)

            if fetchedProjects.isEmpty {
                throw ProjectError.persistenceFailure("No persisted projects found")
            }

            projects = fetchedProjects
            Logger.projectManager.info("Loaded \(fetchedProjects.count) projects from persistence")

        } catch {
            throw ProjectError.persistenceFailure("Failed to fetch projects: \(error.localizedDescription)")
        }
    }

    /// Saves projects to persistent storage
    /// - Throws: ProjectError if saving fails
    func saveProjects() async throws {
        do {
            try await saveProjectsToPersistence()
            Logger.projectManager.info("Projects saved successfully")
        } catch {
            Logger.projectManager.error("️ Failed to save projects: \(error.localizedDescription)")
            throw ProjectError.persistenceFailure(error.localizedDescription)
        }
    }

    /// Saves projects to persistent storage (SwiftData, Core Data, etc.)
    /// - Throws: Error if persistence saving fails
    private func saveProjectsToPersistence() async throws {
        guard let modelContext = modelContext else {
            throw ProjectError.persistenceFailure("ModelContext not available")
        }

        do {
            try modelContext.save()
            Logger.projectManager.info("Projects saved to persistence")
        } catch {
            throw ProjectError.persistenceFailure("Failed to save projects: \(error.localizedDescription)")
        }
    }

    // MARK: - Auto-Save Management

    private var autoSaveTimer: Timer?
    private var hasUnsavedChanges: Bool = false

    /// Enables automatic saving of project changes
    func enableAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.autoSaveIfNeeded()
            }
        }
        Logger.projectManager.debug("Auto-save enabled")
    }

    /// Marks the project data as having unsaved changes
    func markAsChanged() {
        hasUnsavedChanges = true
    }

    /// Performs auto-save if there are unsaved changes
    private func autoSaveIfNeeded() async {
        guard hasUnsavedChanges else { return }

        do {
            try await saveProjects()
            hasUnsavedChanges = false
        } catch {
            Logger.projectManager.error("️ Auto-save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Real-time UI Updates and Notifications

    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.1

    // MARK: - Performance Optimization and Memory Management

    /// Cache for expensive tree traversal operations
    private var treeTraversalCache: [String: [Project]] = [:]
    private var cacheInvalidationTimer: Timer?

    /// Optimized project lookup cache for O(1) access
    private var projectLookupCache: [String: Project] = [:]
    private var cacheNeedsUpdate: Bool = true

    /// Notifies observers that projects have changed with debouncing and cache invalidation
    private func notifyProjectsChanged() {
        invalidateCaches()

        debounceTimer?.invalidate()

        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sendProjectChangeNotifications()
            }
        }
    }

    /// Invalidates performance caches when data changes
    private func invalidateCaches() {
        treeTraversalCache.removeAll()
        cacheNeedsUpdate = true

        rebuildProjectLookupCache()

        if cacheInvalidationTimer == nil {
            setupPeriodicCacheCleanup()
        }
    }

    /// Sets up periodic cache cleanup to prevent memory bloat
    private func setupPeriodicCacheCleanup() {
        cacheInvalidationTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCacheCleanup()
            }
        }
    }

    /// Performs cache cleanup and memory optimization
    private func performCacheCleanup() {
        if !treeTraversalCache.isEmpty {
            treeTraversalCache.removeAll()
            Logger.projectManager.debug("Cleared tree traversal cache")
        }

        if cacheNeedsUpdate {
            rebuildProjectLookupCache()
        }
    }

    /// Rebuilds the project lookup cache for O(1) access
    private func rebuildProjectLookupCache() {
        projectLookupCache.removeAll(keepingCapacity: true)

        for project in projects {
            projectLookupCache[project.id] = project
        }

        cacheNeedsUpdate = false
        Logger.projectManager.debug("Rebuilt project lookup cache with \(self.projectLookupCache.count) entries")
    }

    /// Sends the actual project change notifications
    @MainActor
    private func sendProjectChangeNotifications() {
        objectWillChange.send()

        NotificationCenter.default.post(
            name: .projectDidChange,
            object: self,
            userInfo: [
                "projects": projects,
                "projectCount": projects.count,
                "timestamp": Date(),
            ]
        )

        Logger.projectManager.info("Project change notification sent - \(self.projects.count) projects")
    }

    /// Notifies observers of a specific project selection change
    func notifyProjectSelectionChanged(_ project: Project?) {
        NotificationCenter.default.post(
            name: .projectSelectionChanged,
            object: project,
            userInfo: [
                "selectedProject": project as Any,
                "timestamp": Date(),
            ]
        )
    }

    /// Forces an immediate UI update without debouncing
    @MainActor
    func forceUIUpdate() {
        debounceTimer?.invalidate()
        sendProjectChangeNotifications()
    }

    // MARK: - Core CRUD Operations

    /// Creates a new project with validation and unique ID generation
    /// - Parameters:
    ///   - name: The project name
    ///   - color: The project color
    ///   - parentID: Optional parent project ID
    /// - Returns: The created project
    /// - Throws: ProjectError if validation fails
    func createProject(name: String, color: Color, parentID: String? = nil) async throws -> Project {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameValidation = validateProjectName(trimmedName)
        switch nameValidation {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        if let parentID = parentID {
            let parentValidation = validateParent(parentID)
            switch parentValidation {
            case let .failure(error):
                throw error
            case .success:
                break
            }
        }

        let duplicateValidation = validateUniqueNameInParent(trimmedName, parentID: parentID)
        switch duplicateValidation {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        let projectID = generateUniqueID()

        let sortOrder = calculateNextSortOrder(for: parentID)

        let project = Project(
            id: projectID,
            name: trimmedName,
            color: color,
            parentID: parentID,
            sortOrder: sortOrder
        )

        if let modelContext = modelContext {
            modelContext.insert(project)
        }

        projects.append(project)

        updateProjectTree()

        notifyProjectsChanged()

        markAsChanged()

        return project
    }

    /// Updates an existing project with validation
    /// - Parameters:
    ///   - project: The project to update
    ///   - name: Optional new name
    ///   - color: Optional new color
    ///   - parentID: Optional new parent ID
    /// - Throws: ProjectError if validation fails
    func updateProject(_ project: Project, name: String? = nil, color: Color? = nil, parentID: String? = nil) async throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found")
        }

        let targetProject = projects[projectIndex]
        let oldParentID = targetProject.parentID

        if let newName = name {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameValidation = validateProjectName(trimmedName)
            switch nameValidation {
            case let .failure(error):
                throw error
            case .success:
                break
            }

            let duplicateValidation = validateUniqueNameInParent(trimmedName, parentID: parentID ?? targetProject.parentID, excludingProjectID: project.id)
            switch duplicateValidation {
            case let .failure(error):
                throw error
            case .success:
                break
            }
        }

        if let newParentID = parentID, newParentID != targetProject.parentID {
            let parentValidation = validateParent(newParentID)
            switch parentValidation {
            case let .failure(error):
                throw error
            case .success:
                break
            }

            let hierarchyValidation = validateHierarchyMove(targetProject, to: getProject(by: newParentID))
            switch hierarchyValidation {
            case let .failure(error):
                throw error
            case .success:
                break
            }
        }

        if let newName = name {
            targetProject.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let newColor = color {
            targetProject.color = newColor
        }

        if let newParentID = parentID, newParentID != targetProject.parentID {
            if let oldParent = getProject(by: oldParentID) {
                oldParent.removeChild(targetProject)
            }

            targetProject.parentID = newParentID.isEmpty ? nil : newParentID

            targetProject.sortOrder = calculateNextSortOrder(for: targetProject.parentID)

            if let newParent = getProject(by: newParentID) {
                newParent.addChild(targetProject)
            }
        }

        updateProjectTree()

        notifyProjectsChanged()

        markAsChanged()
    }

    /// Deletes a project with complex deletion strategies and time entry handling
    /// - Parameters:
    ///   - project: The project to delete
    ///   - strategy: How to handle child projects
    ///   - timeEntryReassignmentTarget: Target project for time entry reassignment (nil for unassigned)
    /// - Throws: ProjectError if deletion is not allowed
    func deleteProject(_ project: Project, strategy: DeletionStrategy = .moveChildrenToParent, timeEntryReassignmentTarget: Project? = nil) async throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found")
        }

        let targetProject = projects[projectIndex]

        try await handleActiveTimerForProject(targetProject)

        try await reassignTimeEntries(from: targetProject, to: timeEntryReassignmentTarget)

        let canDeleteResult = canDeleteProject(targetProject)
        if !canDeleteResult.canDelete {
            if let reason = canDeleteResult.reason {
                throw ProjectError.invalidName(reason)
            }
        }

        let children = targetProject.children

        switch strategy {
        case .deleteChildren:
            for child in children {
                try await deleteProject(child, strategy: .deleteChildren)
            }

        case .moveChildrenToParent:
            for child in children {
                child.parentID = targetProject.parentID
                child.sortOrder = calculateNextSortOrder(for: child.parentID)
            }

        case .moveChildrenToRoot:
            for child in children {
                child.parentID = nil
                child.sortOrder = calculateNextSortOrder(for: nil)
            }
        }

        if let parentID = targetProject.parentID,
           let parent = getProject(by: parentID)
        {
            parent.removeChild(targetProject)
        }

        if let modelContext = modelContext {
            modelContext.delete(targetProject)
        }

        projects.removeAll { $0.id == project.id }

        updateSortOrdersForSiblings(of: targetProject)

        updateProjectTree()

        NotificationCenter.default.post(
            name: .projectWasDeleted,
            object: nil,
            userInfo: ["projectId": project.id]
        )

        notifyProjectsChanged()

        markAsChanged()
        try await saveProjects() // Force immediate save for deletions
    }

    /// Retrieves a project by ID with optimized O(1) lookup
    /// - Parameter id: The project ID to search for
    /// - Returns: The project if found, nil otherwise
    func getProject(by id: String?) -> Project? {
        guard let id = id, !id.isEmpty else { return nil }

        if cacheNeedsUpdate {
            rebuildProjectLookupCache()
        }

        if let cachedProject = projectLookupCache[id] {
            return cachedProject
        }

        let project = projects.first { $0.id == id }

        if let project = project {
            projectLookupCache[id] = project
        }

        return project
    }

    /// Alias for getProject(by:) for backward compatibility
    /// - Parameter id: The project ID to search for
    /// - Returns: The project if found, nil otherwise
    func findProject(by id: String?) -> Project? {
        return getProject(by: id)
    }

    // MARK: - Validation Methods

    /// Validates a project name
    private func validateProjectName(_ name: String) -> ValidationResult {
        if name.isEmpty {
            return .failure(.invalidName("Name cannot be empty"))
        }

        if name.count > 100 {
            return .failure(.invalidName("Name cannot exceed 100 characters"))
        }

        return .success
    }

    /// Validates a parent project ID
    private func validateParent(_ parentID: String) -> ValidationResult {
        if parentID.isEmpty {
            return .success // Empty parent ID means root level
        }

        guard getProject(by: parentID) != nil else {
            return .failure(.invalidName("Parent project not found"))
        }

        return .success
    }

    /// Validates unique name within parent
    private func validateUniqueNameInParent(_ name: String, parentID: String?, excludingProjectID: String? = nil) -> ValidationResult {
        let siblings = projects.filter { project in
            project.parentID == parentID &&
                project.id != excludingProjectID &&
                project.name.lowercased() == name.lowercased()
        }

        if !siblings.isEmpty {
            return .failure(.invalidName("A project with this name already exists in the same location"))
        }

        return .success
    }

    /// Enhanced validation for hierarchy moves with comprehensive checks
    /// - Parameters:
    ///   - project: The project to move
    ///   - newParent: The potential new parent
    /// - Returns: ValidationResult indicating success or specific failure reason
    func validateHierarchyMove(_ project: Project, to newParent: Project?) -> ValidationResult {
        if let newParent = newParent, newParent.id == project.id {
            return .failure(.circularReference)
        }

        if let newParent = newParent, isAncestor(project, of: newParent) {
            return .failure(.circularReference)
        }

        let newDepth = (newParent != nil ? getProjectDepth(newParent!) : -1) + 1
        if newDepth >= 5 { // Maximum 5 levels (0-4)
            return .failure(.hierarchyTooDeep)
        }

        if let newParent = newParent {
            let parentValidation = newParent.validateAsParentOf(project)
            switch parentValidation {
            case let .failure(error):
                return .failure(error)
            case .success:
                break
            }
        }

        return .success
    }

    // MARK: - Deletion Logic with Time Entry Handling

    /// Checks if a project can be deleted by examining active timers and time entries
    /// - Parameter project: The project to check for deletion eligibility
    /// - Returns: Tuple indicating if deletion is allowed and reason if not
    func canDeleteProject(_ project: Project) -> (canDelete: Bool, reason: String?) {
        if hasActiveTimer(for: project) {
            return (false, "Project has an active timer running. Stop the timer before deleting.")
        }

        let timeEntryCount = getTimeEntryCount(for: project)
        if timeEntryCount > 0 {
            return (false, "Project has \(timeEntryCount) time entries. Choose how to handle them before deletion.")
        }

        let childrenWithIssues = getChildrenWithDeletionIssues(project)
        if !childrenWithIssues.isEmpty {
            let childNames = childrenWithIssues.map { $0.name }.joined(separator: ", ")
            return (false, "Child projects (\(childNames)) have active timers or time entries. Handle them first.")
        }

        return (true, nil)
    }

    /// Handles active timer for a project by stopping it
    /// - Parameter project: The project whose active timer should be stopped
    /// - Throws: ProjectError if timer cannot be stopped
    func handleActiveTimerForProject(_ project: Project) async throws {
        guard hasActiveTimer(for: project) else {
            return
        }

        // Send notification to stop timer - AppState will handle this
        NotificationCenter.default.post(
            name: .timerShouldStop,
            object: nil,
            userInfo: [
                "projectId": project.id,
                "reason": "projectDeletion",
                "createTimeEntry": false,
            ]
        )

        Logger.projectManager.info("Requested timer stop for project: \(project.name)")
    }

    /// Reassigns time entries from one project to another or to unassigned
    /// - Parameters:
    ///   - sourceProject: The project whose time entries should be reassigned
    ///   - targetProject: The target project (nil for unassigned)
    /// - Throws: ProjectError if reassignment fails
    func reassignTimeEntries(from sourceProject: Project, to targetProject: Project?) async throws {
        let timeEntries = getTimeEntries(for: sourceProject)

        guard !timeEntries.isEmpty else {
            return
        }

        if let targetProject = targetProject {
            guard getProject(by: targetProject.id) != nil else {
                throw ProjectError.invalidName("Target project not found")
            }
        }

        // Use TimeEntryManager to handle the reassignment
        try await TimeEntryManager.shared.reassignTimeEntries(from: sourceProject, to: targetProject)

        let targetName = targetProject?.name ?? "Unassigned"
        Logger.projectManager.info("Reassigned \(timeEntries.count) time entries from '\(sourceProject.name)' to '\(targetName)'")
    }

    /// Prepares deletion confirmation dialog data with comprehensive information
    /// - Parameter project: The project to prepare deletion data for
    /// - Returns: DeletionConfirmationData with all necessary information
    func prepareDeletionConfirmationData(for project: Project) -> DeletionConfirmationData {
        let hasActiveTimer = hasActiveTimer(for: project)
        let timeEntryCount = getTimeEntryCount(for: project)
        let childrenCount = project.children.count
        let childrenWithIssues = getChildrenWithDeletionIssues(project)

        var availableStrategies: [DeletionStrategy] = []

        if childrenCount > 0 {
            availableStrategies.append(.moveChildrenToParent)
            availableStrategies.append(.moveChildrenToRoot)
            availableStrategies.append(.deleteChildren)
        }

        let recommendedStrategy: DeletionStrategy = {
            if childrenCount == 0 {
                return .deleteChildren // No children, so this is effectively just delete
            } else if project.parentID != nil {
                return .moveChildrenToParent // Move to parent if project has a parent
            } else {
                return .moveChildrenToRoot // Move to root if project is at root level
            }
        }()

        var reassignmentOptions: [Project] = []
        if timeEntryCount > 0 {
            let descendants = getAllDescendants(of: project)
            let excludedIds = Set([project.id] + descendants.map { $0.id })

            reassignmentOptions = projects.filter { !excludedIds.contains($0.id) }
        }

        return DeletionConfirmationData(
            project: project,
            hasActiveTimer: hasActiveTimer,
            timeEntryCount: timeEntryCount,
            childrenCount: childrenCount,
            childrenWithIssues: childrenWithIssues,
            availableStrategies: availableStrategies,
            recommendedStrategy: recommendedStrategy,
            timeEntryReassignmentOptions: reassignmentOptions
        )
    }

    // MARK: - Private Helper Methods for Deletion Logic

    /// Checks if a project has an active timer
    /// - Parameter project: The project to check
    /// - Returns: True if project has an active timer
    private func hasActiveTimer(for _: Project) -> Bool {
        // Check if there's an active activity (timer) for this project
        if ActivityManager.shared.getCurrentActivity() != nil {
            // For now, we'll return false since we don't have direct access to AppState
            // In a full implementation, we'd track project association with activities
            // or use a notification-based approach
            return false
        }
        return false
    }

    /// Gets the count of time entries for a project
    /// - Parameter project: The project to count time entries for
    /// - Returns: Number of time entries
    private func getTimeEntryCount(for project: Project) -> Int {
        return TimeEntryManager.shared.getTimeEntries(for: project).count
    }

    /// Gets all time entries for a project
    /// - Parameter project: The project to get time entries for
    /// - Returns: Array of time entries
    private func getTimeEntries(for project: Project) -> [TimeEntry] {
        return TimeEntryManager.shared.getTimeEntries(for: project)
    }

    /// Gets children projects that have deletion issues (active timers or time entries)
    /// - Parameter project: The parent project to check children for
    /// - Returns: Array of children with issues
    private func getChildrenWithDeletionIssues(_ project: Project) -> [Project] {
        var childrenWithIssues: [Project] = []

        for child in project.children {
            let childCanDelete = canDeleteProject(child)
            if !childCanDelete.canDelete {
                childrenWithIssues.append(child)
            }
        }

        return childrenWithIssues
    }

    /// Gets all descendants of a project recursively
    /// - Parameter project: The project to get descendants for
    /// - Returns: Array of all descendant projects
    private func getAllDescendants(of project: Project) -> [Project] {
        var descendants: [Project] = []

        for child in project.children {
            descendants.append(child)
            descendants.append(contentsOf: getAllDescendants(of: child))
        }

        return descendants
    }

    // MARK: - Hierarchy Management Operations

    /// Builds a complete project tree structure from flat project array
    /// - Parameter projects: Optional array of projects to build tree from (defaults to self.projects)
    /// - Returns: Array of root projects with properly structured children
    func buildProjectTree(from projects: [Project]? = nil) -> [Project] {
        let sourceProjects = projects ?? self.projects

        var childrenMap: [String: [Project]] = [:]
        var rootProjects: [Project] = []

        for project in sourceProjects {
            if let parentID = project.parentID {
                if childrenMap[parentID] == nil {
                    childrenMap[parentID] = []
                }
                childrenMap[parentID]!.append(project)
            } else {
                rootProjects.append(project)
            }
        }

        for (parentID, children) in childrenMap {
            let sortedChildren = children.sorted { $0.sortOrder < $1.sortOrder }
            childrenMap[parentID] = sortedChildren

            if let parent = sourceProjects.first(where: { $0.id == parentID }) {
                parent.children = sortedChildren
            }
        }

        for project in sourceProjects {
            project.children = childrenMap[project.id] ?? []
        }

        return rootProjects.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Moves a project to a new parent with validation and sort order management
    /// - Parameters:
    ///   - project: The project to move
    ///   - newParent: The new parent project (nil for root level)
    ///   - index: Optional specific index within the new parent's children (defaults to end)
    /// - Throws: ProjectError if the move is invalid
    func moveProject(_ project: Project, to newParent: Project?, at index: Int? = nil) async throws {
        let validation = validateHierarchyMove(project, to: newParent)
        switch validation {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        let oldParentID = project.parentID
        let newParentID = newParent?.id

        if oldParentID == newParentID {
            if let index = index {
                try await reorderProject(project, to: index, in: newParentID)
            }
            return
        }

        if let oldParentID = oldParentID,
           let oldParent = getProject(by: oldParentID)
        {
            oldParent.removeChild(project)
            updateSortOrdersInParent(oldParentID)
        } else {
            updateSortOrdersInParent(nil)
        }

        project.parentID = newParentID

        if let index = index {
            let siblings = projects.filter { $0.parentID == newParentID }
            let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

            if index >= sortedSiblings.count {
                project.sortOrder = calculateNextSortOrder(for: newParentID)
            } else {
                project.sortOrder = index
                for (siblingIndex, sibling) in sortedSiblings.enumerated() {
                    if siblingIndex >= index {
                        sibling.sortOrder = siblingIndex + 1
                    }
                }
            }
        } else {
            project.sortOrder = calculateNextSortOrder(for: newParentID)
        }

        if let newParent = newParent {
            newParent.addChild(project)
        }

        updateProjectTree()

        notifyProjectsChanged()

        markAsChanged()
        try await saveProjects()
    }

    /// Reorders a project within its current parent's children
    /// - Parameters:
    ///   - project: The project to reorder
    ///   - index: The new index position
    ///   - parentID: The parent ID (nil for root level)
    /// - Throws: ProjectError if the reorder is invalid
    func reorderProject(_ project: Project, to index: Int, in parentID: String?) async throws {
        guard project.parentID == parentID else {
            throw ProjectError.invalidName("Project does not belong to the specified parent")
        }

        let siblings = projects.filter { $0.parentID == parentID }
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

        guard index >= 0, index < sortedSiblings.count else {
            throw ProjectError.invalidName("Invalid index for reordering")
        }

        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found in siblings")
        }

        if currentIndex == index {
            return
        }

        if currentIndex < index {
            for i in (currentIndex + 1) ... index {
                sortedSiblings[i].sortOrder = i - 1
            }
        } else {
            for i in index ..< currentIndex {
                sortedSiblings[i].sortOrder = i + 1
            }
        }

        project.sortOrder = index

        updateProjectTree()

        notifyProjectsChanged()

        markAsChanged()
        try await saveProjects()
    }

    /// Updates sort orders for all projects within a specific parent
    /// - Parameter parentID: The parent ID (nil for root level projects)
    func updateSortOrders(for projects: [Project], in parentID: String?) {
        let targetProjects = projects.filter { $0.parentID == parentID }
        let sortedProjects = targetProjects.sorted { $0.sortOrder < $1.sortOrder }

        for (index, project) in sortedProjects.enumerated() {
            project.sortOrder = index
        }
    }

    // MARK: - Project Reordering Support Methods

    /// Manually reorders a project within its current parent's children
    /// - Parameters:
    ///   - project: The project to reorder
    ///   - newIndex: The new index position within siblings
    /// - Throws: ProjectError if the reorder operation is invalid
    func reorderProjectManually(_ project: Project, to newIndex: Int) async throws {
        let parentID = project.parentID

        let validation = validateReorderOperation(project, to: newIndex, in: parentID)
        switch validation {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        try await reorderProject(project, to: newIndex, in: parentID)
    }

    /// Manages sort order for project siblings by inserting a project at a specific position
    /// - Parameters:
    ///   - project: The project to insert
    ///   - index: The target index position
    ///   - parentID: The parent ID (nil for root level)
    /// - Throws: ProjectError if the operation is invalid
    func insertProjectAtIndex(_ project: Project, at index: Int, in parentID: String?) async throws {
        let validation = validateInsertOperation(project, at: index, in: parentID)
        switch validation {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        let siblings = getSiblingsInParent(parentID, excluding: project.id)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

        project.parentID = parentID

        for (siblingIndex, sibling) in sortedSiblings.enumerated() {
            if siblingIndex >= index {
                sibling.sortOrder = siblingIndex + 1
            }
        }

        project.sortOrder = index

        if let newParent = getProject(by: parentID) {
            newParent.addChild(project)
        }

        updateProjectTree()

        markAsChanged()
        try await saveProjects()
    }

    /// Swaps the positions of two projects within the same parent
    /// - Parameters:
    ///   - project1: The first project to swap
    ///   - project2: The second project to swap
    /// - Throws: ProjectError if the projects don't have the same parent
    func swapProjectPositions(_ project1: Project, _ project2: Project) async throws {
        guard project1.parentID == project2.parentID else {
            throw ProjectError.invalidName("Cannot swap projects with different parents")
        }

        let tempSortOrder = project1.sortOrder
        project1.sortOrder = project2.sortOrder
        project2.sortOrder = tempSortOrder

        if let parentID = project1.parentID,
           let parent = getProject(by: parentID)
        {
            parent.sortChildren()
        }

        updateProjectTree()

        markAsChanged()
        try await saveProjects()
    }

    /// Moves a project up one position within its siblings
    /// - Parameter project: The project to move up
    /// - Throws: ProjectError if the project is already at the top
    func moveProjectUp(_ project: Project) async throws {
        let siblings = getSiblingsInParent(project.parentID)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidOperation("Project not found in siblings")
        }

        guard currentIndex > 0 else {
            throw ProjectError.invalidOperation("Project is already at the top")
        }

        let newIndex = currentIndex - 1
        try await reorderProject(project, to: newIndex, in: project.parentID)
    }

    /// Moves a project down one position within its siblings
    /// - Parameter project: The project to move down
    /// - Throws: ProjectError if the project is already at the bottom
    func moveProjectDown(_ project: Project) async throws {
        let siblings = getSiblingsInParent(project.parentID)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidOperation("Project not found in siblings")
        }

        guard currentIndex < sortedSiblings.count - 1 else {
            throw ProjectError.invalidOperation("Project is already at the bottom")
        }

        let newIndex = currentIndex + 1
        try await reorderProject(project, to: newIndex, in: project.parentID)
    }

    /// Moves a project to the top of its siblings
    /// - Parameter project: The project to move to top
    /// - Throws: ProjectError if the operation fails
    func moveProjectToTop(_ project: Project) async throws {
        try await reorderProject(project, to: 0, in: project.parentID)
    }

    /// Moves a project to the bottom of its siblings
    /// - Parameter project: The project to move to bottom
    /// - Throws: ProjectError if the operation fails
    func moveProjectToBottom(_ project: Project) async throws {
        let siblings = getSiblingsInParent(project.parentID)
        let lastIndex = siblings.count - 1
        try await reorderProject(project, to: lastIndex, in: project.parentID)
    }

    /// Normalizes sort orders within a parent to ensure they are sequential starting from 0
    /// - Parameter parentID: The parent ID (nil for root level)
    func normalizeSortOrders(in parentID: String?) async throws {
        let children = getSiblingsInParent(parentID)
        let sortedChildren = children.sorted { $0.sortOrder < $1.sortOrder }

        for (index, child) in sortedChildren.enumerated() {
            child.sortOrder = index
        }

        if let parentID = parentID,
           let parent = getProject(by: parentID)
        {
            parent.sortChildren()
        }

        updateProjectTree()

        markAsChanged()
        try await saveProjects()
    }

    // MARK: - Reorder Validation Methods

    /// Validates a reorder operation within the same parent
    /// - Parameters:
    ///   - project: The project to reorder
    ///   - newIndex: The target index
    ///   - parentID: The parent ID
    /// - Returns: ValidationResult indicating success or failure
    func validateReorderOperation(_ project: Project, to newIndex: Int, in parentID: String?) -> ValidationResult {
        guard project.parentID == parentID else {
            return .failure(.invalidName("Project does not belong to the specified parent"))
        }

        let siblings = getSiblingsInParent(parentID)

        guard newIndex >= 0 && newIndex < siblings.count else {
            return .failure(.invalidName("Invalid index for reordering: \(newIndex)"))
        }

        return .success
    }

    /// Validates an insert operation at a specific index
    /// - Parameters:
    ///   - project: The project to insert
    ///   - index: The target index
    ///   - parentID: The parent ID
    /// - Returns: ValidationResult indicating success or failure
    func validateInsertOperation(_ project: Project, at index: Int, in parentID: String?) -> ValidationResult {
        if let parentID = parentID {
            guard getProject(by: parentID) != nil else {
                return .failure(.invalidName("Parent project not found"))
            }
        }

        let siblings = getSiblingsInParent(parentID, excluding: project.id)

        guard index >= 0 && index <= siblings.count else {
            return .failure(.invalidName("Invalid index for insertion: \(index)"))
        }

        if project.parentID != parentID {
            let newParent = getProject(by: parentID)
            let hierarchyValidation = validateHierarchyMove(project, to: newParent)
            switch hierarchyValidation {
            case let .failure(error):
                return .failure(error)
            case .success:
                break
            }
        }

        return .success
    }

    /// Checks if a project can be moved up in the sort order
    /// - Parameter project: The project to check
    /// - Returns: True if the project can be moved up
    func canMoveProjectUp(_ project: Project) -> Bool {
        let siblings = getSiblingsInParent(project.parentID)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            return false
        }

        return currentIndex > 0
    }

    /// Checks if a project can be moved down in the sort order
    /// - Parameter project: The project to check
    /// - Returns: True if the project can be moved down
    func canMoveProjectDown(_ project: Project) -> Bool {
        let siblings = getSiblingsInParent(project.parentID)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            return false
        }

        return currentIndex < sortedSiblings.count - 1
    }

    // MARK: - Sort Order Helper Methods

    /// Gets all siblings within a specific parent
    /// - Parameters:
    ///   - parentID: The parent ID (nil for root level)
    ///   - excludingID: Optional project ID to exclude from results
    /// - Returns: Array of sibling projects
    private func getSiblingsInParent(_ parentID: String?, excluding excludingID: String? = nil) -> [Project] {
        return projects.filter { project in
            project.parentID == parentID &&
                (excludingID == nil || project.id != excludingID)
        }
    }

    /// Finds the next available sort order in a parent
    /// - Parameter parentID: The parent ID (nil for root level)
    /// - Returns: The next available sort order
    func getNextSortOrder(in parentID: String?) -> Int {
        let siblings = getSiblingsInParent(parentID)
        let maxSortOrder = siblings.map { $0.sortOrder }.max() ?? -1
        return maxSortOrder + 1
    }

    /// Compacts sort orders to remove gaps
    /// - Parameter parentID: The parent ID (nil for root level)
    func compactSortOrders(in parentID: String?) async throws {
        try await normalizeSortOrders(in: parentID)
    }

    /// Gets the current position of a project within its siblings
    /// - Parameter project: The project to get position for
    /// - Returns: The zero-based index position, or nil if not found
    func getProjectPosition(_ project: Project) -> Int? {
        let siblings = getSiblingsInParent(project.parentID)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }

        return sortedSiblings.firstIndex(where: { $0.id == project.id })
    }

    /// Updates sort orders after a batch operation
    /// - Parameter parentID: The parent ID to update (nil for root level)
    func updateSortOrdersAfterBatchOperation(in parentID: String?) async throws {
        try await normalizeSortOrders(in: parentID)
    }

    // MARK: - Helper Methods

    /// Updates sort orders for all children within a specific parent
    /// - Parameter parentID: The parent ID (nil for root level)
    private func updateSortOrdersInParent(_ parentID: String?) {
        let children = projects.filter { $0.parentID == parentID }
        let sortedChildren = children.sorted { $0.sortOrder < $1.sortOrder }

        for (index, child) in sortedChildren.enumerated() {
            child.sortOrder = index
        }
    }

    /// Checks if one project is an ancestor of another using the complete project tree
    /// - Parameters:
    ///   - ancestor: The potential ancestor project
    ///   - descendant: The potential descendant project
    /// - Returns: True if ancestor is an ancestor of descendant
    func isAncestor(_ ancestor: Project, of descendant: Project) -> Bool {
        var current = descendant
        var visited = Set<String>()

        while let parentID = current.parentID {
            if visited.contains(current.id) {
                return false
            }
            visited.insert(current.id)

            if parentID == ancestor.id {
                return true
            }

            guard let parent = getProject(by: parentID) else {
                break
            }

            current = parent
        }

        return false
    }

    /// Gets the depth of a project in the hierarchy
    /// - Parameter project: The project to calculate depth for
    /// - Returns: The depth (0 for root projects)
    func getProjectDepth(_ project: Project) -> Int {
        var depth = 0
        var current = project
        var visited = Set<String>()

        while let parentID = current.parentID {
            if visited.contains(current.id) {
                break
            }
            visited.insert(current.id)

            guard let parent = getProject(by: parentID) else {
                break
            }

            depth += 1
            current = parent
        }

        return depth
    }

    /// Generates a unique ID for a new project
    private func generateUniqueID() -> String {
        var newID: String
        repeat {
            newID = UUID().uuidString
        } while projects.contains {
            $0.id == newID
        }
        return newID
    }

    /// Calculates the next sort order for a given parent
    private func calculateNextSortOrder(for parentID: String?) -> Int {
        let siblings = projects.filter { $0.parentID == parentID }
        return siblings.map { $0.sortOrder }.max() ?? 0 + 1
    }

    /// Updates sort orders for siblings after a deletion
    private func updateSortOrdersForSiblings(of deletedProject: Project) {
        let siblings = projects.filter {
            $0.parentID == deletedProject.parentID &&
                $0.sortOrder > deletedProject.sortOrder
        }

        for sibling in siblings {
            sibling.sortOrder -= 1
        }
    }

    /// Updates the project tree structure
    private func updateProjectTree() {
        var childrenMap: [String: [Project]] = [:]

        for project in projects {
            if let parentID = project.parentID {
                if childrenMap[parentID] == nil {
                    childrenMap[parentID] = []
                }
                childrenMap[parentID]!.append(project)
            }
        }

        for (parentId, children) in childrenMap {
            childrenMap[parentId] = children.sorted(by: { $0.sortOrder < $1.sortOrder })
        }

        for project in projects {
            project.children = childrenMap[project.id] ?? []
        }
    }

    /// Returns the project tree (root projects only)
    var projectTree: [Project] {
        return projects.filter { $0.parentID == nil }.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    // MARK: - Drag and Drop Support Methods

    /// Handles modern SwiftUI drag-and-drop operations with comprehensive validation
    /// - Parameters:
    ///   - draggedProject: The project being dragged
    ///   - targetProject: The project being dropped onto
    ///   - position: The drop position (above, below, inside)
    /// - Returns: True if drop was successful, false otherwise
    func handleDrop(draggedProject: Project, targetProject: Project, position: DropPosition) async -> Bool {
        do {
            // Simple validation: don't allow circular references
            if draggedProject.id == targetProject.id || targetProject.isDescendantOf(draggedProject) {
                Logger.projectManager.error("Invalid drop: would create circular reference")
                return false
            }

            switch position {
            case .above:
                try await handleDropAbove(draggedProject: draggedProject, targetProject: targetProject)
            case .below:
                try await handleDropBelow(draggedProject: draggedProject, targetProject: targetProject)
            case .inside:
                try await handleDropInside(draggedProject: draggedProject, targetProject: targetProject)
            case .invalid:
                return false
            }

            logDragOperation(draggedProject: draggedProject, targetProject: targetProject, position: position)

            return true

        } catch {
            Logger.projectManager.error("️ Drop operation failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Validates if a drop operation can be accepted
    /// - Parameters:
    ///   - draggedProject: The project being dragged
    ///   - targetProject: The project being dropped onto
    ///   - position: The intended drop position
    /// - Returns: True if drop can be accepted
    func canAcceptDrop(draggedProject: Project, targetProject: Project, position: DropPosition) -> Bool {
        // Simple validation: don't allow circular references
        return draggedProject.id != targetProject.id && !targetProject.isDescendantOf(draggedProject)
    }

    /// Handles dropping a project above another project (same parent, lower sort order)
    /// - Parameters:
    ///   - draggedProject: The project being dragged
    ///   - targetProject: The project being dropped above
    private func handleDropAbove(draggedProject: Project, targetProject: Project) async throws {
        let newParentID = targetProject.parentID
        let newSortOrder = targetProject.sortOrder

        try await moveProjectToPosition(draggedProject, parentID: newParentID, sortOrder: newSortOrder)

        try await updateSortOrdersAfterInsertion(in: newParentID, insertedAt: newSortOrder, excludingProject: draggedProject)
    }

    /// Handles dropping a project below another project (same parent, higher sort order)
    /// - Parameters:
    ///   - draggedProject: The project being dragged
    ///   - targetProject: The project being dropped below
    private func handleDropBelow(draggedProject: Project, targetProject: Project) async throws {
        let newParentID = targetProject.parentID
        let newSortOrder = targetProject.sortOrder + 1

        try await moveProjectToPosition(draggedProject, parentID: newParentID, sortOrder: newSortOrder)

        try await updateSortOrdersAfterInsertion(in: newParentID, insertedAt: newSortOrder, excludingProject: draggedProject)
    }

    /// Handles dropping a project inside another project (making it a child)
    /// - Parameters:
    ///   - draggedProject: The project being dragged
    ///   - targetProject: The project becoming the new parent
    private func handleDropInside(draggedProject: Project, targetProject: Project) async throws {
        let newParentID = targetProject.id
        let newSortOrder = calculateNextSortOrder(for: newParentID)

        try await moveProjectToPosition(draggedProject, parentID: newParentID, sortOrder: newSortOrder)
    }

    /// Moves a project to a specific position with comprehensive validation and error handling
    /// - Parameters:
    ///   - project: The project to move
    ///   - parentID: The new parent ID (nil for root level)
    ///   - sortOrder: The new sort order
    private func moveProjectToPosition(_ project: Project, parentID: String?, sortOrder: Int) async throws {
        let oldParentID = project.parentID
        let oldSortOrder = project.sortOrder

        let newParent = parentID != nil ? getProject(by: parentID!) : nil
        let hierarchyValidation = validateHierarchyMove(project, to: newParent)

        switch hierarchyValidation {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        if let oldParent = getProject(by: oldParentID) {
            oldParent.removeChild(project)
        }

        project.parentID = parentID
        project.sortOrder = sortOrder

        if let newParent = getProject(by: parentID) {
            newParent.addChild(project)
        }

        try await updateSortOrdersAfterRemoval(in: oldParentID, removedFrom: oldSortOrder)

        updateProjectTree()

        notifyProjectsChanged()

        markAsChanged()

        Logger.projectManager.info("Moved project '\(project.name)' from parent '\(oldParentID ?? "root")' to '\(parentID ?? "root")' at position \(sortOrder)")
    }

    /// Updates sort orders after a project is inserted at a specific position
    /// - Parameters:
    ///   - parentID: The parent ID where insertion occurred
    ///   - insertedAt: The sort order where insertion occurred
    ///   - excludingProject: The project that was inserted (to exclude from updates)
    private func updateSortOrdersAfterInsertion(in parentID: String?, insertedAt: Int, excludingProject: Project) async throws {
        let siblings = projects.filter {
            $0.parentID == parentID && $0.id != excludingProject.id
        }

        for sibling in siblings {
            if sibling.sortOrder >= insertedAt {
                sibling.sortOrder += 1
            }
        }

        markAsChanged()
    }

    /// Updates sort orders after a project is removed from a specific position
    /// - Parameters:
    ///   - parentID: The parent ID where removal occurred
    ///   - removedFrom: The sort order where removal occurred
    private func updateSortOrdersAfterRemoval(in parentID: String?, removedFrom: Int) async throws {
        let siblings = projects.filter {
            $0.parentID == parentID
        }

        for sibling in siblings {
            if sibling.sortOrder > removedFrom {
                sibling.sortOrder -= 1
            }
        }

        markAsChanged()
    }

    /// Logs drag-and-drop operations for debugging and undo functionality
    /// - Parameters:
    ///   - draggedProject: The project that was dragged
    ///   - targetProject: The project that was the drop target
    ///   - position: The drop position that was used
    private func logDragOperation(draggedProject: Project, targetProject: Project, position: DropPosition) {
        let positionDescription: String
        switch position {
        case .above:
            positionDescription = "above"
        case .below:
            positionDescription = "below"
        case .inside:
            positionDescription = "inside"
        case .invalid:
            positionDescription = "invalid"
        }

        Logger.projectManager.info("Drag operation completed: '\(draggedProject.name)' dropped \(positionDescription) '\(targetProject.name)'")
    }

    /// Creates an undo operation for drag-and-drop actions
    /// - Parameters:
    ///   - project: The project that was moved
    ///   - originalParentID: The original parent ID
    ///   - originalSortOrder: The original sort order
    /// - Returns: A closure that can undo the operation
    func createUndoOperation(for project: Project, originalParentID: String?, originalSortOrder: Int) -> () async throws -> Void {
        return { [weak self] in
            guard let self = self else { return }
            try await self.moveProjectToPosition(project, parentID: originalParentID, sortOrder: originalSortOrder)
            Logger.projectManager.info("↩️ Undid drag operation for project: \(project.name)")
        }
    }

    /// Validates drag operations with enhanced error reporting
    /// - Parameters:
    ///   - draggedProject: The project being dragged
    ///   - targetProject: The target project
    ///   - position: The intended drop position
    /// - Returns: Detailed validation result with specific error information
    func validateDragWithDetails(draggedProject: Project, targetProject: Project, position: DropPosition) -> (isValid: Bool, errorMessage: String?) {
        // Simple validation: don't allow circular references
        if draggedProject.id == targetProject.id {
            return (false, "Cannot drop a project onto itself")
        }
        if targetProject.isDescendantOf(draggedProject) {
            return (false, "Cannot create circular reference")
        }
        return (true, nil)
    }

    /// Handles batch drag operations efficiently
    /// - Parameter operations: Array of drag operations to perform
    func performBatchDragOperations(_ operations: [(Project, Project, DropPosition)]) async -> [Bool] {
        var results: [Bool] = []

        for (draggedProject, targetProject, position) in operations {
            let result = await handleDrop(draggedProject: draggedProject, targetProject: targetProject, position: position)
            results.append(result)
        }

        forceUIUpdate()

        return results
    }
}
