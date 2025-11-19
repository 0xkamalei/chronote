import Foundation
import SwiftData
import SwiftUI

@Model
final class Project: Equatable, Codable {
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

    // MARK: - Codable Implementation

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

    init(id: String = UUID().uuidString, name: String = "", color: Color = .blue, parentID: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.color = color
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Tree Traversal Helpers

    /// Checks if this project is an ancestor of the given project
    func isAncestorOf(_ project: Project) -> Bool {
        return Project.isAncestor(self, of: project)
    }

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

    /// Adds a child project
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

    /// Validates if this project can be a parent of another project
    func validateAsParentOf(_ project: Project) -> ValidationResult {
        // Check if moving would create a circular reference
        if isDescendantOf(project) {
            return .failure(.circularReference)
        }
        return .success
    }

    /// Get all descendant projects
    var descendants: [Project] {
        var result: [Project] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: child.descendants)
        }
        return result
    }

    /// Get the depth of this project in the hierarchy
    var depth: Int {
        // This is computed based on parentID relationship
        // In a real implementation, you'd query the data
        // For MVP, return a simple value
        return 0
    }

    /// Check if this project can accept children (e.g., hierarchy depth limit)
    var canAcceptChildren: Bool {
        // For MVP, always allow (simplified)
        return true
    }

    // MARK: - Private Helper Methods

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
}
