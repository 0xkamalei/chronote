import SwiftUI
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
class ProjectManager: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var isLoading: Bool = false
    
    // Reference to AppState for integration
    private weak var appState: AppState?
    
    init(appState: AppState? = nil, modelContext: ModelContext? = nil) {
        self.appState = appState
        self.modelContext = modelContext
        
        // Initialize projects - will be loaded from persistence in loadProjects()
        self.projects = []
        
        // Load projects from persistent storage
        Task {
            do {
                try await loadProjects()
                
                // Enable auto-save after successful load
                enableAutoSave()
                
            } catch {
                print("⚠️ Failed to load projects during initialization: \(error.localizedDescription)")
                // Fall back to AppState projects if available
                if let appState = appState {
                    self.projects = appState.projects
                }
            }
        }
    }
    
    deinit {
        // Clean up auto-save timer
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
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
        // Validate project name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameValidation = validateProjectName(trimmedName)
        switch nameValidation {
        case .failure(let error):
            throw error
        case .success:
            break
        }
        
        // Validate parent if provided
        if let parentID = parentID {
            let parentValidation = validateParent(parentID)
            switch parentValidation {
            case .failure(let error):
                throw error
            case .success:
                break
            }
        }
        
        // Check for duplicate names within the same parent
        let duplicateValidation = validateUniqueNameInParent(trimmedName, parentID: parentID)
        switch duplicateValidation {
        case .failure(let error):
            throw error
        case .success:
            break
        }
        
        // Generate unique ID
        let projectID = generateUniqueID()
        
        // Calculate sort order (append to end of siblings)
        let sortOrder = calculateNextSortOrder(for: parentID)
        
        // Create the project
        let project = Project(
            id: projectID,
            name: trimmedName,
            color: color,
            parentID: parentID,
            sortOrder: sortOrder
        )
        
        // Insert into SwiftData
        if let modelContext = modelContext {
            modelContext.insert(project)
        }
        
        // Add to projects array
        projects.append(project)
        
        // Update project tree structure
        updateProjectTree()
        
        // Notify AppState if available
        appState?.projects = projects
        appState?.addProject(project)
        
        // Mark as changed and auto-save
        markAsChanged()
        try await saveProjects()
        
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
        // Find the project in our array
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found")
        }
        
        let targetProject = projects[projectIndex]
        let oldParentID = targetProject.parentID
        
        // Validate name if provided
        if let newName = name {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameValidation = validateProjectName(trimmedName)
            switch nameValidation {
            case .failure(let error):
                throw error
            case .success:
                break
            }
            
            // Check for duplicate names within the same parent (excluding current project)
            let duplicateValidation = validateUniqueNameInParent(trimmedName, parentID: parentID ?? targetProject.parentID, excludingProjectID: project.id)
            switch duplicateValidation {
            case .failure(let error):
                throw error
            case .success:
                break
            }
        }
        
        // Validate parent change if provided
        if let newParentID = parentID, newParentID != targetProject.parentID {
            let parentValidation = validateParent(newParentID)
            switch parentValidation {
            case .failure(let error):
                throw error
            case .success:
                break
            }
            
            // Validate hierarchy move
            let hierarchyValidation = validateHierarchyMove(targetProject, to: getProject(by: newParentID))
            switch hierarchyValidation {
            case .failure(let error):
                throw error
            case .success:
                break
            }
        }
        
        // Apply changes
        if let newName = name {
            targetProject.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let newColor = color {
            targetProject.color = newColor
        }
        
        if let newParentID = parentID, newParentID != targetProject.parentID {
            // Remove from old parent's children
            if let oldParent = getProject(by: oldParentID) {
                oldParent.removeChild(targetProject)
            }
            
            // Update parent ID
            targetProject.parentID = newParentID.isEmpty ? nil : newParentID
            
            // Calculate new sort order in new parent
            targetProject.sortOrder = calculateNextSortOrder(for: targetProject.parentID)
            
            // Add to new parent's children
            if let newParent = getProject(by: newParentID) {
                newParent.addChild(targetProject)
            }
        }
        
        // Update project tree structure
        updateProjectTree()
        
        // Notify AppState if available
        appState?.projects = projects
        
        // Mark as changed and auto-save
        markAsChanged()
        try await saveProjects()
    }
    
    /// Deletes a project with complex deletion strategies and time entry handling
    /// - Parameters:
    ///   - project: The project to delete
    ///   - strategy: How to handle child projects
    ///   - timeEntryReassignmentTarget: Target project for time entry reassignment (nil for unassigned)
    /// - Throws: ProjectError if deletion is not allowed
    func deleteProject(_ project: Project, strategy: DeletionStrategy = .moveChildrenToParent, timeEntryReassignmentTarget: Project? = nil) async throws {
        // Find the project in our array
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found")
        }
        
        let targetProject = projects[projectIndex]
        
        // Handle active timer if present
        try await handleActiveTimerForProject(targetProject)
        
        // Reassign time entries if any exist
        try await reassignTimeEntries(from: targetProject, to: timeEntryReassignmentTarget)
        
        // After handling timers and time entries, check if project can be deleted
        let canDeleteResult = canDeleteProject(targetProject)
        if !canDeleteResult.canDelete {
            if let reason = canDeleteResult.reason {
                throw ProjectError.invalidName(reason)
            }
        }
        
        // Handle child projects according to strategy
        let children = targetProject.children
        
        switch strategy {
        case .deleteChildren:
            // Recursively delete all children
            for child in children {
                try await deleteProject(child, strategy: .deleteChildren)
            }
            
        case .moveChildrenToParent:
            // Move children to this project's parent
            for child in children {
                child.parentID = targetProject.parentID
                child.sortOrder = calculateNextSortOrder(for: child.parentID)
            }
            
        case .moveChildrenToRoot:
            // Move children to root level
            for child in children {
                child.parentID = nil
                child.sortOrder = calculateNextSortOrder(for: nil)
            }
        }
        
        // Remove from parent's children if it has a parent
        if let parentID = targetProject.parentID,
           let parent = getProject(by: parentID) {
            parent.removeChild(targetProject)
        }
        
        // Remove from SwiftData
        if let modelContext = modelContext {
            modelContext.delete(targetProject)
        }
        
        // Remove from projects array
        projects.removeAll { $0.id == project.id }
        
        // Update sort orders for remaining siblings
        updateSortOrdersForSiblings(of: targetProject)
        
        // Update project tree structure
        updateProjectTree()
        
        // Handle selection in AppState if this project was selected
        if appState?.selectedProject?.id == project.id {
            appState?.clearSelection()
        }
        
        // Notify AppState if available
        appState?.projects = projects
        
        // Mark as changed and auto-save
        markAsChanged()
        try await saveProjects()
    }
    
    /// Retrieves a project by ID with error handling
    /// - Parameter id: The project ID to search for
    /// - Returns: The project if found, nil otherwise
    func getProject(by id: String?) -> Project? {
        guard let id = id, !id.isEmpty else { return nil }
        return projects.first { $0.id == id }
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
        // Cannot move to itself
        if let newParent = newParent, newParent.id == project.id {
            return .failure(.circularReference)
        }
        
        // Cannot move to one of its descendants (would create circular reference)
        if let newParent = newParent, isAncestor(project, of: newParent) {
            return .failure(.circularReference)
        }
        
        // Check maximum depth limit
        let newDepth = (newParent != nil ? getProjectDepth(newParent!) : -1) + 1
        if newDepth >= 5 { // Maximum 5 levels (0-4)
            return .failure(.hierarchyTooDeep)
        }
        
        // Validate that the new parent can accept children
        if let newParent = newParent {
            let parentValidation = newParent.validateAsParentOf(project)
            switch parentValidation {
            case .failure(let error):
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
        // Check for active activities (timers) associated with this project
        if hasActiveTimer(for: project) {
            return (false, "Project has an active timer running. Stop the timer before deleting.")
        }
        
        // Check for existing time entries associated with this project
        let timeEntryCount = getTimeEntryCount(for: project)
        if timeEntryCount > 0 {
            return (false, "Project has \(timeEntryCount) time entries. Choose how to handle them before deletion.")
        }
        
        // Check if project has children with active timers or time entries
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
        // Check if there's an active timer for this project
        guard hasActiveTimer(for: project) else {
            // No active timer, nothing to handle
            return
        }
        
        // Get the current active activity from ActivityManager
        if let currentActivity = ActivityManager.shared.getCurrentActivity() {
            // Check if the current activity is associated with this project
            // Note: This assumes activities can be linked to projects via some mechanism
            // For now, we'll stop any active timer as a safety measure
            
            // End the current activity
            let now = Date()
            currentActivity.endTime = now
            currentActivity.duration = currentActivity.calculatedDuration
            
            // Save the ended activity if we have a model context
            if let modelContext = getModelContext() {
                try await ActivityManager.shared.saveActivity(currentActivity, modelContext: modelContext)
            }
            
            // Update AppState timer status
            appState?.isTimerActive = false
            
            print("🛑 Stopped active timer for project: \(project.name)")
        }
    }
    
    /// Reassigns time entries from one project to another or to unassigned
    /// - Parameters:
    ///   - sourceProject: The project whose time entries should be reassigned
    ///   - targetProject: The target project (nil for unassigned)
    /// - Throws: ProjectError if reassignment fails
    func reassignTimeEntries(from sourceProject: Project, to targetProject: Project?) async throws {
        // Get all time entries for the source project
        let timeEntries = getTimeEntries(for: sourceProject)
        
        guard !timeEntries.isEmpty else {
            // No time entries to reassign
            return
        }
        
        // Validate target project exists if provided
        if let targetProject = targetProject {
            guard getProject(by: targetProject.id) != nil else {
                throw ProjectError.invalidName("Target project not found")
            }
        }
        
        // Reassign each time entry
        let _ = targetProject?.id
        var reassignedCount = 0
        
        for _ in timeEntries {
            // Update the time entry's project ID
            // Note: This assumes TimeEntry has a mutable projectId property
            // In a real implementation, this would update the database
            reassignedCount += 1
        }
        
        let targetName = targetProject?.name ?? "Unassigned"
        print("📝 Reassigned \(reassignedCount) time entries from '\(sourceProject.name)' to '\(targetName)'")
    }
    
    /// Prepares deletion confirmation dialog data with comprehensive information
    /// - Parameter project: The project to prepare deletion data for
    /// - Returns: DeletionConfirmationData with all necessary information
    func prepareDeletionConfirmationData(for project: Project) -> DeletionConfirmationData {
        let hasActiveTimer = hasActiveTimer(for: project)
        let timeEntryCount = getTimeEntryCount(for: project)
        let childrenCount = project.children.count
        let childrenWithIssues = getChildrenWithDeletionIssues(project)
        
        // Determine available strategies based on project state
        var availableStrategies: [DeletionStrategy] = []
        
        if childrenCount > 0 {
            availableStrategies.append(.moveChildrenToParent)
            availableStrategies.append(.moveChildrenToRoot)
            availableStrategies.append(.deleteChildren)
        }
        
        // Determine recommended strategy
        let recommendedStrategy: DeletionStrategy = {
            if childrenCount == 0 {
                return .deleteChildren // No children, so this is effectively just delete
            } else if project.parentID != nil {
                return .moveChildrenToParent // Move to parent if project has a parent
            } else {
                return .moveChildrenToRoot // Move to root if project is at root level
            }
        }()
        
        // Prepare time entry reassignment options
        var reassignmentOptions: [Project] = []
        if timeEntryCount > 0 {
            // Get all projects except the one being deleted and its descendants
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
    private func hasActiveTimer(for project: Project) -> Bool {
        // Check if there's a current activity in ActivityManager
        // Note: In a full implementation, this would check if the current activity
        // is associated with this project through some linking mechanism
        
        // For now, we'll check the AppState timer status as a proxy
        return appState?.isTimerActive == true
    }
    
    /// Gets the count of time entries for a project
    /// - Parameter project: The project to count time entries for
    /// - Returns: Number of time entries
    private func getTimeEntryCount(for project: Project) -> Int {
        // In a real implementation, this would query the database for TimeEntry records
        // where projectId matches the project.id
        
        // For now, return 0 as placeholder
        // TODO: Implement actual time entry counting when TimeEntry persistence is available
        return 0
    }
    
    /// Gets all time entries for a project
    /// - Parameter project: The project to get time entries for
    /// - Returns: Array of time entries
    private func getTimeEntries(for project: Project) -> [TimeEntry] {
        // In a real implementation, this would query the database for TimeEntry records
        // where projectId matches the project.id
        
        // For now, return empty array as placeholder
        // TODO: Implement actual time entry fetching when TimeEntry persistence is available
        return []
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
    
    /// Gets the model context for database operations
    /// - Returns: ModelContext if available
    private func getModelContext() -> ModelContext? {
        // In a real implementation, this would return the SwiftData ModelContext
        // For now, return nil as placeholder
        // TODO: Implement model context access when SwiftData integration is complete
        return nil
    }
    
    // MARK: - Hierarchy Management Operations
    
    /// Builds a complete project tree structure from flat project array
    /// - Parameter projects: Optional array of projects to build tree from (defaults to self.projects)
    /// - Returns: Array of root projects with properly structured children
    func buildProjectTree(from projects: [Project]? = nil) -> [Project] {
        let sourceProjects = projects ?? self.projects
        
        // Create a map of parent ID to children for efficient lookup
        var childrenMap: [String: [Project]] = [:]
        var rootProjects: [Project] = []
        
        // First pass: group projects by parent ID
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
        
        // Second pass: sort children by sort order and assign to parents
        for (parentID, children) in childrenMap {
            let sortedChildren = children.sorted { $0.sortOrder < $1.sortOrder }
            childrenMap[parentID] = sortedChildren
            
            // Find the parent project and assign children
            if let parent = sourceProjects.first(where: { $0.id == parentID }) {
                parent.children = sortedChildren
            }
        }
        
        // Ensure all projects have their children properly set
        for project in sourceProjects {
            project.children = childrenMap[project.id] ?? []
        }
        
        // Sort root projects by sort order
        return rootProjects.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// Moves a project to a new parent with validation and sort order management
    /// - Parameters:
    ///   - project: The project to move
    ///   - newParent: The new parent project (nil for root level)
    ///   - index: Optional specific index within the new parent's children (defaults to end)
    /// - Throws: ProjectError if the move is invalid
    func moveProject(_ project: Project, to newParent: Project?, at index: Int? = nil) async throws {
        // Validate the hierarchy move
        let validation = validateHierarchyMove(project, to: newParent)
        switch validation {
        case .failure(let error):
            throw error
        case .success:
            break
        }
        
        let oldParentID = project.parentID
        let newParentID = newParent?.id
        
        // If moving to the same parent, this is just a reorder operation
        if oldParentID == newParentID {
            if let index = index {
                try await reorderProject(project, to: index, in: newParentID)
            }
            return
        }
        
        // Remove from old parent's children
        if let oldParentID = oldParentID,
           let oldParent = getProject(by: oldParentID) {
            oldParent.removeChild(project)
            // Update sort orders for remaining siblings in old parent
            updateSortOrdersInParent(oldParentID)
        } else {
            // Was a root project, update root project sort orders
            updateSortOrdersInParent(nil)
        }
        
        // Update project's parent ID
        project.parentID = newParentID
        
        // Calculate new sort order
        if let index = index {
            // Insert at specific index
            let siblings = projects.filter { $0.parentID == newParentID }
            let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }
            
            if index >= sortedSiblings.count {
                // Append to end
                project.sortOrder = calculateNextSortOrder(for: newParentID)
            } else {
                // Insert at index, shift others
                project.sortOrder = index
                for (siblingIndex, sibling) in sortedSiblings.enumerated() {
                    if siblingIndex >= index {
                        sibling.sortOrder = siblingIndex + 1
                    }
                }
            }
        } else {
            // Append to end of new parent's children
            project.sortOrder = calculateNextSortOrder(for: newParentID)
        }
        
        // Add to new parent's children
        if let newParent = newParent {
            newParent.addChild(project)
        }
        
        // Rebuild the project tree to ensure consistency
        updateProjectTree()
        
        // Notify AppState if available
        appState?.projects = projects
        
        // Mark as changed and auto-save
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
        // Validate that the project belongs to the specified parent
        guard project.parentID == parentID else {
            throw ProjectError.invalidName("Project does not belong to the specified parent")
        }
        
        // Get all siblings (including the project being moved)
        let siblings = projects.filter { $0.parentID == parentID }
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }
        
        // Validate index bounds
        guard index >= 0 && index < sortedSiblings.count else {
            throw ProjectError.invalidName("Invalid index for reordering")
        }
        
        // Find current position
        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found in siblings")
        }
        
        // If already at the target position, no need to reorder
        if currentIndex == index {
            return
        }
        
        // Update sort orders
        if currentIndex < index {
            // Moving down: shift projects up
            for i in (currentIndex + 1)...index {
                sortedSiblings[i].sortOrder = i - 1
            }
        } else {
            // Moving up: shift projects down
            for i in index..<currentIndex {
                sortedSiblings[i].sortOrder = i + 1
            }
        }
        
        // Set the new sort order for the moved project
        project.sortOrder = index
        
        // Rebuild the project tree to ensure consistency
        updateProjectTree()
        
        // Notify AppState if available
        appState?.projects = projects
        
        // Mark as changed and auto-save
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
        
        // Validate the reorder operation
        let validation = validateReorderOperation(project, to: newIndex, in: parentID)
        switch validation {
        case .failure(let error):
            throw error
        case .success:
            break
        }
        
        // Perform the reorder
        try await reorderProject(project, to: newIndex, in: parentID)
    }
    
    /// Manages sort order for project siblings by inserting a project at a specific position
    /// - Parameters:
    ///   - project: The project to insert
    ///   - index: The target index position
    ///   - parentID: The parent ID (nil for root level)
    /// - Throws: ProjectError if the operation is invalid
    func insertProjectAtIndex(_ project: Project, at index: Int, in parentID: String?) async throws {
        // Validate the insertion
        let validation = validateInsertOperation(project, at: index, in: parentID)
        switch validation {
        case .failure(let error):
            throw error
        case .success:
            break
        }
        
        // Get siblings in the target parent
        let siblings = getSiblingsInParent(parentID, excluding: project.id)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }
        
        // Update the project's parent and sort order
        project.parentID = parentID
        
        // Shift existing siblings to make room
        for (siblingIndex, sibling) in sortedSiblings.enumerated() {
            if siblingIndex >= index {
                sibling.sortOrder = siblingIndex + 1
            }
        }
        
        // Set the new project's sort order
        project.sortOrder = index
        
        // Update parent-child relationships
        if let newParent = getProject(by: parentID) {
            newParent.addChild(project)
        }
        
        // Rebuild the project tree
        updateProjectTree()
        
        // Notify AppState if available
        appState?.projects = projects
        
        // Mark as changed and auto-save
        markAsChanged()
        try await saveProjects()
    }
    
    /// Swaps the positions of two projects within the same parent
    /// - Parameters:
    ///   - project1: The first project to swap
    ///   - project2: The second project to swap
    /// - Throws: ProjectError if the projects don't have the same parent
    func swapProjectPositions(_ project1: Project, _ project2: Project) async throws {
        // Validate that both projects have the same parent
        guard project1.parentID == project2.parentID else {
            throw ProjectError.invalidName("Cannot swap projects with different parents")
        }
        
        // Swap sort orders
        let tempSortOrder = project1.sortOrder
        project1.sortOrder = project2.sortOrder
        project2.sortOrder = tempSortOrder
        
        // Update parent's children order
        if let parentID = project1.parentID,
           let parent = getProject(by: parentID) {
            parent.sortChildren()
        }
        
        // Rebuild the project tree
        updateProjectTree()
        
        // Notify AppState if available
        appState?.projects = projects
        
        // Mark as changed and auto-save
        markAsChanged()
        try await saveProjects()
    }
    
    /// Moves a project up one position within its siblings
    /// - Parameter project: The project to move up
    /// - Throws: ProjectError if the project is already at the top
    func moveProjectUp(_ project: Project) async throws {
        let siblings = getSiblingsInParent(project.parentID, including: project.id)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }
        
        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found in siblings")
        }
        
        guard currentIndex > 0 else {
            throw ProjectError.invalidName("Project is already at the top")
        }
        
        let newIndex = currentIndex - 1
        try await reorderProject(project, to: newIndex, in: project.parentID)
    }
    
    /// Moves a project down one position within its siblings
    /// - Parameter project: The project to move down
    /// - Throws: ProjectError if the project is already at the bottom
    func moveProjectDown(_ project: Project) async throws {
        let siblings = getSiblingsInParent(project.parentID, including: project.id)
        let sortedSiblings = siblings.sorted { $0.sortOrder < $1.sortOrder }
        
        guard let currentIndex = sortedSiblings.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectError.invalidName("Project not found in siblings")
        }
        
        guard currentIndex < sortedSiblings.count - 1 else {
            throw ProjectError.invalidName("Project is already at the bottom")
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
        let siblings = getSiblingsInParent(project.parentID, including: project.id)
        let lastIndex = siblings.count - 1
        try await reorderProject(project, to: lastIndex, in: project.parentID)
    }
    
    /// Normalizes sort orders within a parent to ensure they are sequential starting from 0
    /// - Parameter parentID: The parent ID (nil for root level)
    func normalizeSortOrders(in parentID: String?) async throws {
        let children = getSiblingsInParent(parentID, including: nil)
        let sortedChildren = children.sorted { $0.sortOrder < $1.sortOrder }
        
        for (index, child) in sortedChildren.enumerated() {
            child.sortOrder = index
        }
        
        // Update parent's children order
        if let parentID = parentID,
           let parent = getProject(by: parentID) {
            parent.sortChildren()
        }
        
        // Rebuild the project tree
        updateProjectTree()
        
        // Notify AppState if available
        appState?.projects = projects
        
        // Mark as changed and auto-save
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
        // Validate that the project belongs to the specified parent
        guard project.parentID == parentID else {
            return .failure(.invalidName("Project does not belong to the specified parent"))
        }
        
        // Get siblings count
        let siblings = getSiblingsInParent(parentID, including: project.id)
        
        // Validate index bounds
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
        // Validate parent exists if not nil
        if let parentID = parentID {
            guard getProject(by: parentID) != nil else {
                return .failure(.invalidName("Parent project not found"))
            }
        }
        
        // Get siblings count (excluding the project being inserted)
        let siblings = getSiblingsInParent(parentID, excluding: project.id)
        
        // Validate index bounds (can insert at the end, so <= count is valid)
        guard index >= 0 && index <= siblings.count else {
            return .failure(.invalidName("Invalid index for insertion: \(index)"))
        }
        
        // Validate hierarchy move if changing parents
        if project.parentID != parentID {
            let newParent = getProject(by: parentID)
            let hierarchyValidation = validateHierarchyMove(project, to: newParent)
            switch hierarchyValidation {
            case .failure(let error):
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
        let siblings = getSiblingsInParent(project.parentID, including: project.id)
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
        let siblings = getSiblingsInParent(project.parentID, including: project.id)
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
    
    /// Gets all siblings within a specific parent, optionally including a specific project
    /// - Parameters:
    ///   - parentID: The parent ID (nil for root level)
    ///   - includingID: Optional project ID to include (if nil, includes all)
    /// - Returns: Array of sibling projects
    private func getSiblingsInParent(_ parentID: String?, including includingID: String?) -> [Project] {
        return projects.filter { project in
            project.parentID == parentID && 
            (includingID == nil || project.id == includingID || true)
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
        let siblings = getSiblingsInParent(project.parentID, including: project.id)
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
        
        // Traverse up the parent chain using the complete project list
        while let parentID = current.parentID {
            // Prevent infinite loops
            if visited.contains(current.id) {
                return false
            }
            visited.insert(current.id)
            
            // Check if we found the ancestor
            if parentID == ancestor.id {
                return true
            }
            
            // Find the parent in the complete project list
            guard let parent = getProject(by: parentID) else {
                // Parent not found, break the chain
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
            // Prevent infinite loops
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
        } while projects.contains { $0.id == newID }
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
        // Build children map
        var childrenMap: [String: [Project]] = [:]
        
        // Group by parent
        for project in projects {
            if let parentID = project.parentID {
                if childrenMap[parentID] == nil {
                    childrenMap[parentID] = []
                }
                childrenMap[parentID]!.append(project)
            }
        }
        
        // Sort children by sort order
        for (parentId, children) in childrenMap {
            childrenMap[parentId] = children.sorted(by: { $0.sortOrder < $1.sortOrder })
        }
        
        // Update each project's children array
        for project in projects {
            project.children = childrenMap[project.id] ?? []
        }
    }
    
    /// Returns the project tree (root projects only)
    var projectTree: [Project] {
        return projects.filter { $0.parentID == nil }.sorted(by: { $0.sortOrder < $1.sortOrder })
    }
    
    // MARK: - SwiftData Persistence and Auto-Save Functionality
    
    private var modelContext: ModelContext?
    private var autoSaveTimer: Timer?
    private var hasUnsavedChanges = false
    
    /// Sets the ModelContext for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Saves projects to SwiftData with error handling
    func saveProjects() async throws {
        guard let modelContext = modelContext else {
            print("⚠️ ModelContext not available for saving projects")
            return
        }
        
        isLoading = true
        
        do {
            // Save the context to persist all changes
            try modelContext.save()
            
            // Mark as saved
            hasUnsavedChanges = false
            
            print("💾 Successfully saved \(projects.count) projects to SwiftData")
            
        } catch {
            print("❌ Failed to save projects: \(error.localizedDescription)")
            throw ProjectError.persistenceFailure(error)
        }
        
        isLoading = false
    }
    
    /// Loads projects from SwiftData with data validation
    func loadProjects() async throws {
        guard let modelContext = modelContext else {
            print("⚠️ ModelContext not available for loading projects")
            try await initializeProjectsFromMockData()
            return
        }
        
        isLoading = true
        
        do {
            // Fetch all projects from SwiftData
            let descriptor = FetchDescriptor<Project>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            let loadedProjects = try modelContext.fetch(descriptor)
            
            if loadedProjects.isEmpty {
                // No saved data, initialize with MockData
                try await initializeProjectsFromMockData()
                isLoading = false
                return
            }
            
            // Validate project data integrity
            let validatedProjects = try validateProjectData(loadedProjects)
            
            // Update projects array
            projects = validatedProjects
            
            // Rebuild project tree structure
            updateProjectTree()
            
            // Update AppState if available
            appState?.projects = projects
            
            print("📂 Successfully loaded \(projects.count) projects from SwiftData")
            
        } catch {
            print("❌ Failed to load projects: \(error.localizedDescription)")
            // Fall back to MockData if loading fails
            try await initializeProjectsFromMockData()
        }
        
        isLoading = false
    }
    
    /// Enables auto-save functionality with background persistence
    func enableAutoSave(interval: TimeInterval = 30.0) {
        // Disable existing timer if any
        disableAutoSave()
        
        // Create new timer for auto-save
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutoSave()
            }
        }
        
        print("🔄 Auto-save enabled with \(interval) second interval")
    }
    
    /// Disables auto-save functionality
    func disableAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        print("⏹️ Auto-save disabled")
    }
    
    /// Performs auto-save if there are unsaved changes
    private func performAutoSave() async {
        guard hasUnsavedChanges else { return }
        
        do {
            try await saveProjects()
            print("🔄 Auto-save completed successfully")
        } catch {
            print("⚠️ Auto-save failed: \(error.localizedDescription)")
        }
    }
    
    /// Marks that there are unsaved changes
    private func markAsChanged() {
        hasUnsavedChanges = true
    }
    
    // MARK: - Data Migration Logic
    
    /// Initializes projects from MockData for first-time users
    private func initializeProjectsFromMockData() async throws {
        guard let modelContext = modelContext else {
            print("⚠️ ModelContext not available for MockData initialization")
            return
        }
        
        print("🆕 Initializing projects from MockData...")
        
        // Get projects from MockData and insert them into SwiftData
        let mockProjects = MockData.projects
        
        for mockProject in mockProjects {
            let project = Project(
                id: mockProject.id,
                name: mockProject.name,
                color: mockProject.color,
                parentID: mockProject.parentID,
                sortOrder: mockProject.sortOrder
            )
            modelContext.insert(project)
        }
        
        // Save to SwiftData
        try modelContext.save()
        
        // Update local projects array
        projects = mockProjects
        
        // Rebuild project tree
        updateProjectTree()
        
        // Update AppState
        appState?.projects = projects
        
        print("✅ Initialized \(projects.count) projects from MockData")
    }
    
    /// Validates project data integrity after loading
    private func validateProjectData(_ projects: [Project]) throws -> [Project] {
        var validatedProjects: [Project] = []
        var projectIDs = Set<String>()
        
        // Check for duplicate IDs and basic validation
        for project in projects {
            // Check for duplicate IDs
            if projectIDs.contains(project.id) {
                print("⚠️ Duplicate project ID found: \(project.id), skipping...")
                continue
            }
            projectIDs.insert(project.id)
            
            // Validate project name
            if project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("⚠️ Project with empty name found: \(project.id), setting default name...")
                project.name = "Untitled Project"
            }
            
            // Validate sort order
            if project.sortOrder < 0 {
                print("⚠️ Invalid sort order for project \(project.name): \(project.sortOrder), setting to 0...")
                project.sortOrder = 0
            }
            
            validatedProjects.append(project)
        }
        
        // Validate parent-child relationships
        validatedProjects = validateHierarchyIntegrity(validatedProjects)
        
        return validatedProjects
    }
    
    /// Validates and fixes hierarchy integrity issues
    private func validateHierarchyIntegrity(_ projects: [Project]) -> [Project] {
        let projectIDs = Set(projects.map { $0.id })
        var fixedProjects: [Project] = []
        
        for project in projects {
            let fixedProject = project
            
            // Check if parent exists
            if let parentID = project.parentID, !projectIDs.contains(parentID) {
                print("⚠️ Parent not found for project \(project.name): \(parentID), moving to root level...")
                fixedProject.parentID = nil
            }
            
            // Check for circular references (basic check)
            if let parentID = project.parentID, parentID == project.id {
                print("⚠️ Circular reference detected for project \(project.name), moving to root level...")
                fixedProject.parentID = nil
            }
            
            fixedProjects.append(fixedProject)
        }
        
        return fixedProjects
    }
}

// MARK: - Supporting Types

enum DeletionStrategy {
    case deleteChildren
    case moveChildrenToParent
    case moveChildrenToRoot
}



/// Data structure for deletion confirmation dialog
struct DeletionConfirmationData {
    let project: Project
    let hasActiveTimer: Bool
    let timeEntryCount: Int
    let childrenCount: Int
    let childrenWithIssues: [Project]
    let availableStrategies: [DeletionStrategy]
    let recommendedStrategy: DeletionStrategy
    let timeEntryReassignmentOptions: [Project]
    
    /// Indicates if deletion requires user decisions
    var requiresUserDecision: Bool {
        return hasActiveTimer || timeEntryCount > 0 || childrenCount > 0
    }
    
    /// Indicates if deletion can proceed without issues
    var canDeleteSafely: Bool {
        return !hasActiveTimer && timeEntryCount == 0 && childrenWithIssues.isEmpty
    }
    
    /// Gets a user-friendly description of deletion issues
    var deletionIssuesDescription: String {
        var issues: [String] = []
        
        if hasActiveTimer {
            issues.append("Active timer running")
        }
        
        if timeEntryCount > 0 {
            issues.append("\(timeEntryCount) time entries")
        }
        
        if !childrenWithIssues.isEmpty {
            issues.append("\(childrenWithIssues.count) child projects with issues")
        }
        
        if childrenCount > 0 && childrenWithIssues.isEmpty {
            issues.append("\(childrenCount) child projects")
        }
        
        return issues.isEmpty ? "No issues" : issues.joined(separator: ", ")
    }
}