import SwiftUI

class Project: ObservableObject, Identifiable, Hashable {
    let id: String
    @Published var name: String
    @Published var color: Color
    @Published var children: [Project] = []
    @Published var parentID: String?
    @Published var sortOrder: Int
    @Published var isExpanded: Bool = true

    init(id: String, name: String, color: Color, parentID: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.color = color
        self.parentID = parentID
        self.sortOrder = sortOrder
    }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Computed Properties for Hierarchy
    
    /// Calculates the depth of this project in the hierarchy
    var depth: Int {
        guard let parentID = parentID else { return 0 }
        return getDepth(from: parentID, visited: Set<String>())
    }
    
    /// Returns all descendant projects recursively
    var descendants: [Project] {
        var result: [Project] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: child.descendants)
        }
        return result
    }
    
    /// Returns all sibling projects (projects with the same parent)
    var siblings: [Project] {
        // This will be populated by the ProjectManager when building the tree
        return []
    }
    
    /// Returns the path from root to this project as a string
    var hierarchyPath: String {
        guard let parentID = parentID else { return name }
        return getHierarchyPath(visited: Set<String>())
    }
    
    // MARK: - Validation Methods
    
    /// Validates if this project can be a parent of the given project
    func canBeParentOf(_ project: Project) -> Bool {
        // Cannot be parent of itself
        if self.id == project.id {
            return false
        }
        
        // Cannot be parent if it would create a circular reference
        if project.isAncestorOf(self) {
            return false
        }
        
        // Check maximum depth limit (5 levels)
        if self.depth >= 4 { // 0-based, so 4 means 5 levels
            return false
        }
        
        return true
    }
    
    /// Validates the parent-child relationship
    func validateAsParentOf(_ project: Project) -> ValidationResult {
        if !canBeParentOf(project) {
            if self.id == project.id {
                return .failure(.circularReference)
            }
            if project.isAncestorOf(self) {
                return .failure(.circularReference)
            }
            if self.depth >= 4 {
                return .failure(.hierarchyTooDeep)
            }
        }
        return .success
    }
    
    /// Validates the project name
    func validateName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .failure(.invalidName("Name cannot be empty"))
        }
        
        if trimmedName.count > 100 {
            return .failure(.invalidName("Name cannot exceed 100 characters"))
        }
        
        return .success
    }
    
    // MARK: - Tree Traversal and Manipulation Helpers
    
    /// Checks if this project is an ancestor of the given project
    func isAncestorOf(_ project: Project) -> Bool {
        return project.hasAncestor(withID: self.id)
    }
    
    /// Checks if this project is a descendant of the given project
    func isDescendantOf(_ project: Project) -> Bool {
        return hasAncestor(withID: project.id)
    }
    
    /// Finds a child project by ID
    func findChild(withID id: String) -> Project? {
        for child in children {
            if child.id == id {
                return child
            }
            if let found = child.findChild(withID: id) {
                return found
            }
        }
        return nil
    }
    
    /// Adds a child project maintaining sort order
    func addChild(_ project: Project) {
        project.parentID = self.id
        children.append(project)
        sortChildren()
    }
    
    /// Removes a child project
    func removeChild(_ project: Project) {
        children.removeAll { $0.id == project.id }
        project.parentID = nil
    }
    
    /// Sorts children by their sortOrder property
    func sortChildren() {
        children.sort { $0.sortOrder < $1.sortOrder }
    }
    
    /// Updates sort orders for all children
    func updateChildrenSortOrder() {
        for (index, child) in children.enumerated() {
            child.sortOrder = index
        }
    }
    
    /// Gets all projects at the same hierarchy level
    func getSiblingsFromTree(_ allProjects: [Project]) -> [Project] {
        return allProjects.filter { $0.parentID == self.parentID && $0.id != self.id }
    }
    
    // MARK: - Private Helper Methods
    
    private func getDepth(from parentID: String, visited: Set<String>) -> Int {
        // Prevent infinite loops in case of circular references
        if visited.contains(parentID) {
            return 0
        }
        
        var newVisited = visited
        newVisited.insert(parentID)
        
        // This would need to be implemented with access to all projects
        // For now, we'll return a basic calculation
        // The ProjectManager will provide the full implementation
        return 1
    }
    
    private func hasAncestor(withID ancestorID: String, visited: Set<String> = Set()) -> Bool {
        guard let parentID = parentID else { return false }
        
        // Prevent infinite loops
        if visited.contains(self.id) {
            return false
        }
        
        if parentID == ancestorID {
            return true
        }
        
        var newVisited = visited
        newVisited.insert(self.id)
        
        // This would need access to all projects to traverse up the tree
        // The ProjectManager will provide the full implementation
        return false
    }
    
    private func getHierarchyPath(visited: Set<String> = Set()) -> String {
        guard let parentID = parentID else { return name }
        
        // Prevent infinite loops
        if visited.contains(self.id) {
            return name
        }
        
        // This would need access to all projects to build the full path
        // The ProjectManager will provide the full implementation
        return name
    }
}

// MARK: - Supporting Types

enum ValidationResult {
    case success
    case failure(ProjectError)
}

enum ProjectError: LocalizedError {
    case invalidName(String)
    case circularReference
    case hasActiveTimer
    case hasTimeEntries(count: Int)
    case persistenceFailure(Error)
    case hierarchyTooDeep
    
    var errorDescription: String? {
        switch self {
        case .invalidName(let reason):
            return "Invalid project name: \(reason)"
        case .circularReference:
            return "Cannot move project: would create circular reference"
        case .hasActiveTimer:
            return "Cannot delete project with active timer. Stop the timer first."
        case .hasTimeEntries(let count):
            return "Project has \(count) time entries. Choose how to handle them."
        case .persistenceFailure(let error):
            return "Failed to save changes: \(error.localizedDescription)"
        case .hierarchyTooDeep:
            return "Project hierarchy is too deep (maximum 5 levels)"
        }
    }
}