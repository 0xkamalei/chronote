import SwiftUI
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Model
final class Project {
    @Attribute(.unique) var id: String
    var name: String
    var colorData: Data?
    var parentID: String?
    var sortOrder: Int
    var isExpanded: Bool = true
    
    // Computed property for SwiftUI Color
    var color: Color {
        get {
            guard let colorData = colorData else { return .blue }
            #if canImport(UIKit)
            if let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
                return Color(uiColor)
            }
            #elseif canImport(AppKit)
            if let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                return Color(nsColor)
            }
            #endif
            return .blue
        }
        set {
            #if canImport(UIKit)
            colorData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(newValue), requiringSecureCoding: false)
            #elseif canImport(AppKit)
            colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(newValue), requiringSecureCoding: false)
            #endif
        }
    }
    
    // Transient property for children (computed from all projects)
    @Transient var children: [Project] = []

    init(id: String = UUID().uuidString, name: String = "", color: Color = .blue, parentID: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.color = color // This will set colorData through the setter
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
    /// This method works by checking if the target project has this project as an ancestor
    func isAncestorOf(_ project: Project) -> Bool {
        return Project.isAncestor(self, of: project)
    }
    
    /// Static method to check if one project is an ancestor of another
    /// - Parameters:
    ///   - ancestor: The potential ancestor project
    ///   - descendant: The potential descendant project
    /// - Returns: True if ancestor is an ancestor of descendant
    static func isAncestor(_ ancestor: Project, of descendant: Project) -> Bool {
        var current = descendant
        var visited = Set<String>()
        
        // Traverse up the parent chain
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
            
            // Find the parent in the current project's context
            // This is a simplified check - in practice, ProjectManager would provide the full tree
            if let parent = current.children.first(where: { $0.id == parentID }) {
                current = parent
            } else {
                // Cannot find parent, break the chain
                break
            }
        }
        
        return false
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
    
    // MARK: - Reordering Support Methods
    
    /// Checks if this project can be reordered within its current parent
    var canBeReordered: Bool {
        // Projects can always be reordered unless they are the only child
        return true
    }
    
    /// Gets the current position within siblings (0-based index)
    func getCurrentPosition(in allProjects: [Project]) -> Int? {
        let siblings = getSiblingsFromTree(allProjects)
        let allSiblingsIncludingSelf = siblings + [self]
        let sortedSiblings = allSiblingsIncludingSelf.sorted { $0.sortOrder < $1.sortOrder }
        
        return sortedSiblings.firstIndex(where: { $0.id == self.id })
    }
    
    /// Checks if this project can move up in the sort order
    func canMoveUp(in allProjects: [Project]) -> Bool {
        guard let position = getCurrentPosition(in: allProjects) else { return false }
        return position > 0
    }
    
    /// Checks if this project can move down in the sort order
    func canMoveDown(in allProjects: [Project]) -> Bool {
        let siblings = getSiblingsFromTree(allProjects)
        guard let position = getCurrentPosition(in: allProjects) else { return false }
        return position < siblings.count // siblings.count because we're not including self in siblings
    }
    
    /// Validates if this project can be inserted at a specific position within a parent
    /// - Parameters:
    ///   - index: The target index position
    ///   - parentID: The target parent ID
    ///   - allProjects: All projects for validation
    /// - Returns: ValidationResult indicating success or failure
    func validateInsertionAt(index: Int, in parentID: String?, allProjects: [Project]) -> ValidationResult {
        // Check if moving to a different parent would create circular reference
        if let targetParentID = parentID, targetParentID != self.parentID {
            if let targetParent = allProjects.first(where: { $0.id == targetParentID }) {
                if !targetParent.canBeParentOf(self) {
                    return .failure(.circularReference)
                }
            }
        }
        
        // Get siblings in target parent
        let targetSiblings = allProjects.filter { 
            $0.parentID == parentID && $0.id != self.id 
        }
        
        // Validate index bounds
        if index < 0 || index > targetSiblings.count {
            return .failure(.invalidName("Invalid insertion index"))
        }
        
        return .success
    }
    
    // MARK: - Private Helper Methods
    
    private func getDepth(from parentID: String, visited: Set<String>) -> Int {
        // Prevent infinite loops in case of circular references
        if visited.contains(parentID) {
            return 0
        }
        
        var newVisited = visited
        newVisited.insert(parentID)
        
        // For now, return a basic calculation
        // This will be enhanced when we have access to ProjectManager
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
        
        // Check parent's ancestors recursively through the parent object
        // This requires the parent to be properly linked in the tree structure
        for child in children {
            if child.hasAncestor(withID: ancestorID, visited: newVisited) {
                return true
            }
        }
        
        return false
    }
    
    private func getHierarchyPath(visited: Set<String> = Set()) -> String {
        guard let parentID = parentID else { return name }
        
        // Prevent infinite loops
        if visited.contains(self.id) {
            return name
        }
        
        // For now, return just the name
        // This will be enhanced when we have proper parent references
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

    /// Updates this project's sort order and maintains sibling order consistency
    /// - Parameters:
    ///   - newSortOrder: The new sort order value
    ///   - allProjects: All projects for sibling management
    func updateSortOrder(to newSortOrder: Int, in allProjects: [Project]) {
        let oldSortOrder = self.sortOrder
        self.sortOrder = newSortOrder
        
        // Update siblings' sort orders if necessary
        let siblings = getSiblingsFromTree(allProjects)
        
        if newSortOrder > oldSortOrder {
            // Moving down: shift siblings up
            for sibling in siblings {
                if sibling.sortOrder > oldSortOrder && sibling.sortOrder <= newSortOrder {
                    sibling.sortOrder -= 1
                }
            }
        } else if newSortOrder < oldSortOrder {
            // Moving up: shift siblings down
            for sibling in siblings {
                if sibling.sortOrder >= newSortOrder && sibling.sortOrder < oldSortOrder {
                    sibling.sortOrder += 1
                }
            }
        }
    }
    
    /// Checks if this project can be moved to a specific parent
    /// - Parameters:
    ///   - targetParentID: The target parent ID
    ///   - allProjects: All projects for validation
    /// - Returns: True if the move is valid
    func canMoveTo(parentID targetParentID: String?, in allProjects: [Project]) -> Bool {
        // Can always move to root level
        if targetParentID == nil {
            return true
        }
        
        // Find target parent
        guard let targetParent = allProjects.first(where: { $0.id == targetParentID }) else {
            return false
        }
        
        // Check if target parent can accept this project
        return targetParent.canBeParentOf(self)
    }
    
    /// Gets the maximum sort order among siblings
    /// - Parameter allProjects: All projects for sibling lookup
    /// - Returns: The maximum sort order, or -1 if no siblings
    func getMaxSortOrderAmongSiblings(in allProjects: [Project]) -> Int {
        let siblings = getSiblingsFromTree(allProjects)
        let allSiblingsIncludingSelf = siblings + [self]
        return allSiblingsIncludingSelf.map { $0.sortOrder }.max() ?? -1
    }
    
    /// Gets the minimum sort order among siblings
    /// - Parameter allProjects: All projects for sibling lookup
    /// - Returns: The minimum sort order, or 0 if no siblings
    func getMinSortOrderAmongSiblings(in allProjects: [Project]) -> Int {
        let siblings = getSiblingsFromTree(allProjects)
        let allSiblingsIncludingSelf = siblings + [self]
        return allSiblingsIncludingSelf.map { $0.sortOrder }.min() ?? 0
    }
}