import SwiftUI

class AppState: ObservableObject {
    @Published var projects: [Project]
    @Published var isTimerActive: Bool = false

    init() {
        self.projects = [
            Project(id: "workmagic", name: "workmagic", color: .red, sortOrder: 0),
            Project(id: "side_project", name: "side_project", color: .purple, sortOrder: 1),
            Project(id: "project1", name: "Project1", color: .green, sortOrder: 2),
            Project(id: "sub_project", name: "Sub Project", color: .orange, parentID: "workmagic", sortOrder: 0)
        ]
    }
    
    func addProject(_ project: Project) {
        projects.append(project)
    }
    
    func moveProject(from source: IndexSet, to destination: Int, parentID: String?) {
        // Get the projects that are at the same level (e.g., root projects or children of a specific parent)
        var projectsToReorder = self.projects.filter { $0.parentID == parentID }.sorted { $0.sortOrder < $1.sortOrder }
        
        // Perform the move on this subset of projects
        projectsToReorder.move(fromOffsets: source, toOffset: destination)
        
        // Create a dictionary to map project IDs to their new sort order
        let newOrderMap = Dictionary(uniqueKeysWithValues: projectsToReorder.enumerated().map { (index, project) in
            (project.id, index)
        })
        
        // Create a new projects array with updated sort orders
        let updatedProjects = self.projects.map { project -> Project in
            // If this project was part of the reordered list, update its sortOrder
            if let newSortOrder = newOrderMap[project.id] {
                project.sortOrder = newSortOrder
            }
            return project
        }
        
        // Replace the old array with the new one to trigger the @Published property update
        self.projects = updatedProjects
    }

    var projectTree: [Project] {
        // Build the tree structure without modifying @Published properties
        var childrenMap: [String: [Project]] = [:]
        
        // Group projects by their parent
        for project in projects {
            if let parentID = project.parentID {
                if childrenMap[parentID] == nil {
                    childrenMap[parentID] = []
                }
                childrenMap[parentID]!.append(project)
            }
        }
        
        // Sort children for each parent
        for (parentId, children) in childrenMap {
            childrenMap[parentId] = children.sorted(by: { $0.sortOrder < $1.sortOrder })
        }
        
        // Return sorted root projects
        let rootProjects = projects.filter { $0.parentID == nil }.sorted(by: { $0.sortOrder < $1.sortOrder })
        
        // Update children arrays outside of the computed property to avoid warning
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for project in self.projects {
                project.children = childrenMap[project.id] ?? []
            }
        }
        
        return rootProjects
    }
}
