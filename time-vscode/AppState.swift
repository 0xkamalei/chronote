import SwiftUI

class AppState: ObservableObject {
    @Published var projects: [Project]
    @Published var isTimerActive: Bool = false
    
    // 全局管理选择状态
    @Published var selectedProject: Project?
    @Published var selectedSidebar: String? = "All Activities"

    init() {
        self.projects = MockData.projects
        
        // 初始化时设置默认选择
        self.selectedSidebar = "All Activities"
        self.selectedProject = nil
        
        // 初始化时构建项目树
        updateProjectTree()
    }
    
    // MARK: - Selection Management
    
    /// 选择特殊项目（All Activities, Unassigned, My Projects）
    func selectSpecialItem(_ item: String) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedProject = nil
            selectedSidebar = item
        }
        
        // Console logging for debugging
        print("🔍 Selected special item: \(item)")
        
        switch item {
        case "All Activities":
            print("📊 Filtering: Show all activities (no project filter)")
        case "Unassigned":
            print("❓ Filtering: Show only unassigned activities")
        case "My Projects":
            print("📁 Filtering: Show all activities assigned to projects")
        default:
            break
        }
    }
    
    /// 选择项目
    func selectProject(_ project: Project) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedSidebar = nil
            selectedProject = project
        }
        
        // Console logging for debugging
        print("🎯 Selected project: \(project.name)")
        print("📂 Project ID: \(project.id)")
        if let parentID = project.parentID {
            print("🔗 Parent ID: \(parentID)")
        }
        print("🎨 Project color: \(project.color)")
        print("📊 Filtering: Show activities for project '\(project.name)'")
    }
    
    /// 清除所有选择
    func clearSelection() {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedProject = nil
            selectedSidebar = nil
        }
    }
    
    /// 检查是否选择了特定的特殊项目
    func isSpecialItemSelected(_ item: String) -> Bool {
        return selectedSidebar == item && selectedProject == nil
    }
    
    /// 检查是否选择了特定的项目
    func isProjectSelected(_ project: Project) -> Bool {
        return selectedProject?.id == project.id && selectedSidebar == nil
    }
    
    // MARK: - Project Management
    
    func addProject(_ project: Project) {
        projects.append(project)
        updateProjectTree()
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
        updateProjectTree()
    }
    
    /// 安全地更新项目树结构
    private func updateProjectTree() {
        // 构建子项目映射
        var childrenMap: [String: [Project]] = [:]
        
        // 按父项目分组
        for project in projects {
            if let parentID = project.parentID {
                if childrenMap[parentID] == nil {
                    childrenMap[parentID] = []
                }
                childrenMap[parentID]!.append(project)
            }
        }
        
        // 对每个父项目的子项目进行排序
        for (parentId, children) in childrenMap {
            childrenMap[parentId] = children.sorted(by: { $0.sortOrder < $1.sortOrder })
        }
        
        // 更新每个项目的子项目数组
        for project in projects {
            project.children = childrenMap[project.id] ?? []
        }
    }

    var projectTree: [Project] {
        // 只返回根项目，子项目已经在 updateProjectTree 中设置
        return projects.filter { $0.parentID == nil }.sorted(by: { $0.sortOrder < $1.sortOrder })
    }
}
