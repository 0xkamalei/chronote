import AppKit
import Foundation
import SwiftData
import SwiftUI
import os

@MainActor
class ProjectManager: ObservableObject {
    static let shared = ProjectManager()
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Core CRUD Operations
    
    /// Creates a new project
    func createProject(name: String, color: Color, productivityRating: Double = 0.5, isArchived: Bool = false) async throws -> Project {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidName("Name cannot be empty")
        }
        
        let project = Project(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color,
            sortOrder: 0,
            productivityRating: productivityRating,
            isArchived: isArchived
        )
        
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<Project>()
            let allProjects = try? modelContext.fetch(descriptor)
            project.sortOrder = (allProjects?.count ?? 0)
            
            modelContext.insert(project)
            try modelContext.save()
        }
        
        return project
    }
    
    /// Updates an existing project
    func updateProject(_ project: Project, name: String? = nil, color: Color? = nil, productivityRating: Double? = nil, isArchived: Bool? = nil) async throws {
        if let name = name {
            project.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let color = color {
            project.color = color
        }
        if let productivityRating = productivityRating {
            project.productivityRating = productivityRating
        }
        if let isArchived = isArchived {
            project.isArchived = isArchived
        }
        
        try modelContext?.save()
    }
    
    /// Deletes a project
    func deleteProject(_ project: Project) async throws {
        guard let modelContext = modelContext else { return }
        
        modelContext.delete(project)
        try modelContext.save()
        
        NotificationCenter.default.post(
             name: .projectWasDeleted,
             object: nil,
             userInfo: ["projectId": project.id]
         )
    }
    
    // MARK: - Reordering
    
    func reorderProject(_ project: Project, to newIndex: Int) async throws {
         project.sortOrder = newIndex
         if let context = modelContext {
             try context.save()
         }
    }
    
    func getAllProjects() async throws -> [Project] {
        guard let modelContext = modelContext else { return [] }
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)])
        return try modelContext.fetch(descriptor)
    }
    
    func getProject(by id: String) -> Project? {
        guard let modelContext = modelContext else { return nil }
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    func findProject(by id: String) -> Project? {
        getProject(by: id)
    }
}


extension Notification.Name {
    static let projectWasDeleted = Notification.Name("projectWasDeleted")
}


