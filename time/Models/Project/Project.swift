import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - Custom UTType for Project Drag and Drop

extension UTType {
    // Use importedAs to avoid needing to declare in Info.plist
    static let project = UTType(importedAs: "com.timetracking.project")
}

// MARK: - Drag and Drop Data Structures

/// Data structure for project drag operations
struct ProjectDragData: Codable, Transferable {
    let projectID: String
    let projectName: String
    let sourceParentID: String?
    let sourceSortOrder: Int
    let hierarchyDepth: Int

    init(projectID: String, projectName: String, sourceParentID: String?, sourceSortOrder: Int, hierarchyDepth: Int) {
        self.projectID = projectID
        self.projectName = projectName
        self.sourceParentID = sourceParentID
        self.sourceSortOrder = sourceSortOrder
        self.hierarchyDepth = hierarchyDepth
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: ProjectDragData.self, contentType: .projectDragData)
    }
}

// MARK: - Additional UTTypes for Drag Data

extension UTType {
    // Use importedAs to avoid needing to declare in Info.plist
    static let projectDragData = UTType(importedAs: "com.timetracking.project.dragdata")
}

/// Enumeration for different drop positions
enum DropPosition {
    case above
    case below
    case inside
    case invalid
}

@Model
final class Project: Equatable, Transferable, Codable {
    @Attribute(.unique) var id: String
    var name: String
    var colorData: Data?
    var parentID: String?
    var sortOrder: Int
    var isExpanded: Bool = true

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

    @Transient var children: [Project] = []

    // MARK: - Transferable Conformance for Drag and Drop

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: Project.self, contentType: .project)
        ProxyRepresentation(exporting: \.dragTransferData)
    }

    // MARK: - Codable Implementation for Drag and Drop

    enum CodingKeys: String, CodingKey {
        case id, name, colorData, parentID, sortOrder, isExpanded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(colorData, forKey: .colorData)
        try container.encodeIfPresent(parentID, forKey: .parentID)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(isExpanded, forKey: .isExpanded)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorData = try container.decodeIfPresent(Data.self, forKey: .colorData)
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        children = []
    }

    // MARK: - Drag and Drop Properties

    /// Indicates if this project can be dragged
    var isDraggable: Bool {
        return true
    }

    /// Indicates if this project can accept child projects
    var canAcceptChildren: Bool {
        return depth < 4 // Maximum 5 levels (0-4)
    }

    /// Creates a drag preview representation of the project
    var dragPreviewText: String {
        return name
    }

    /// Returns the project's visual representation for drag operations
    var dragDisplayName: String {
        let depthIndicator = String(repeating: "  ", count: depth)
        return "\(depthIndicator)\(name)"
    }

    /// Returns drag data for transfer operations
    var dragTransferData: ProjectDragData {
        return ProjectDragData(
            projectID: id,
            projectName: name,
            sourceParentID: parentID,
            sourceSortOrder: sortOrder,
            hierarchyDepth: depth
        )
    }

    /// Validates if this project can be dropped on another project
    func canBeDroppedOn(_ target: Project) -> Bool {
        if target.id == id {
            return false
        }

        if target.isDescendantOf(self) {
            return false
        }

        return target.canAcceptChildren
    }

    /// Validates if this project can be dropped at a specific position
    func canBeDroppedAt(index: Int, in parentID: String?, allProjects: [Project]) -> Bool {
        return validateInsertionAt(index: index, in: parentID, allProjects: allProjects) == .success
    }

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
        return []
    }

    /// Returns the path from root to this project as a string
    var hierarchyPath: String {
        guard parentID != nil else { return name }
        return getHierarchyPath(visited: Set<String>())
    }

    // MARK: - Validation Methods

    /// Validates if this project can be a parent of the given project
    func canBeParentOf(_ project: Project) -> Bool {
        if id == project.id {
            return false
        }

        if project.isAncestorOf(self) {
            return false
        }

        if depth >= 4 { // 0-based, so 4 means 5 levels
            return false
        }

        return true
    }

    /// Validates the parent-child relationship
    func validateAsParentOf(_ project: Project) -> ValidationResult {
        if !canBeParentOf(project) {
            if id == project.id {
                return .failure(.circularReference)
            }
            if project.isAncestorOf(self) {
                return .failure(.circularReference)
            }
            if depth >= 4 {
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

        while let parentID = current.parentID {
            if visited.contains(current.id) {
                return false
            }
            visited.insert(current.id)

            if parentID == ancestor.id {
                return true
            }

            if let parent = current.children.first(where: { $0.id == parentID }) {
                current = parent
            } else {
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
        project.parentID = id
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
        if let targetParentID = parentID, targetParentID != self.parentID {
            if let targetParent = allProjects.first(where: { $0.id == targetParentID }) {
                if !targetParent.canBeParentOf(self) {
                    return .failure(.circularReference)
                }
            }
        }

        let targetSiblings = allProjects.filter {
            $0.parentID == parentID && $0.id != self.id
        }

        if index < 0 || index > targetSiblings.count {
            return .failure(.invalidName("Invalid insertion index"))
        }

        return .success
    }

    // MARK: - Private Helper Methods

    private func getDepth(from parentID: String, visited: Set<String>) -> Int {
        if visited.contains(parentID) {
            return 0
        }

        var newVisited = visited
        newVisited.insert(parentID)

        return 1
    }

    private func hasAncestor(withID ancestorID: String, visited: Set<String> = Set()) -> Bool {
        guard let parentID = parentID else { return false }

        if visited.contains(id) {
            return false
        }

        if parentID == ancestorID {
            return true
        }

        var newVisited = visited
        newVisited.insert(id)

        for child in children {
            if child.hasAncestor(withID: ancestorID, visited: newVisited) {
                return true
            }
        }

        return false
    }

    private func getHierarchyPath(visited: Set<String> = Set()) -> String {
        guard parentID != nil else { return name }

        if visited.contains(id) {
            return name
        }

        return name
    }
}
