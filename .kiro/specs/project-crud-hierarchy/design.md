# Design Document

## Overview

This design implements a comprehensive project management system with full CRUD operations and drag-and-drop hierarchy management for the time tracking application. The solution extends the existing Project model and AppState architecture while introducing new service layers for data persistence, enhanced UI components for project management, and sophisticated drag-and-drop functionality.

The design follows SwiftUI best practices with ObservableObject patterns, maintains separation of concerns through dedicated service layers, and provides a seamless user experience with real-time updates and visual feedback.

## Architecture

### Core Components

1. **ProjectManager**: A comprehensive service class that handles all project CRUD operations, hierarchy management, and persistence
2. **Enhanced Project Model**: Extended with additional properties and methods for drag-and-drop support
3. **Enhanced EditProjectView**: Existing modal enhanced for both create and edit modes
4. **Enhanced ProjectRowView**: Existing project row enhanced with drag-and-drop capabilities and context menus
5. **Enhanced SidebarView**: Updated to include "Create Project" button and integrate with ProjectManager
6. **ProjectDragDropHandler**: Specialized component for handling complex drag-and-drop logic
7. **ProjectRightClickMenu**: Reusable right-click menu component for project operations

### Data Flow

```
User Action → View Component → ProjectManager → AppState → UI Update
```

## Components and Interfaces

### ProjectManager Service

Following Apple's latest SwiftUI and Swift best practices:

```swift
@MainActor
class ProjectManager: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var isLoading: Bool = false
    
    // CRUD Operations with async/await
    func createProject(name: String, color: Color, parentID: String?) async throws -> Project
    func updateProject(_ project: Project, name: String?, color: Color?, parentID: String?) async throws
    func deleteProject(_ project: Project, deleteChildren: Bool) async throws
    func getProject(by id: String) -> Project?
    
    // Hierarchy Operations
    func moveProject(_ project: Project, to newParent: Project?, at index: Int) async throws
    func validateHierarchyMove(_ project: Project, to newParent: Project?) -> ValidationResult
    func buildProjectTree(from projects: [Project]) -> [Project]
    func updateSortOrders(for projects: [Project], in parent: String?)
    
    // Modern Drag and Drop Support (iOS 16+/macOS 13+)
    func handleDrop(_ projects: [Project], on target: Project?, at location: CGPoint) -> Bool
    func canAcceptDrop(_ projects: [Project], on target: Project?) -> Bool
    func reorderProject(_ project: Project, to index: Int, in parentID: String?) -> Bool
    func moveProject(_ project: Project, toParent: Project?) -> Bool
    
    // Delete Operations with Complex Logic
    func canDeleteProject(_ project: Project) -> (canDelete: Bool, reason: String?)
    func deleteProject(_ project: Project, strategy: DeletionStrategy) async throws
    func handleActiveTimerForProject(_ project: Project) async throws
    func reassignTimeEntries(from project: Project, to targetProject: Project?) async throws
    
    // Persistence with modern Swift Concurrency
    func saveProjects() async throws
    func loadProjects() async throws
    func autoSave() // Background saving
    
    // Validation with Result type
    func validateProject(name: String, parentID: String?) -> ValidationResult
    func validateHierarchyMove(_ project: Project, to newParent: Project?) -> ValidationResult
}

enum DeletionStrategy {
    case deleteChildren
    case moveChildrenToParent
    case moveChildrenToRoot
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

enum ValidationResult {
    case success
    case failure(ProjectError)
}
```

### Enhanced Project Model

Following modern SwiftUI patterns and Apple's best practices:

```swift
class Project: ObservableObject, Identifiable, Hashable, Transferable {
    // Existing properties...
    @Published var isExpanded: Bool = true
    
    // Transferable conformance for modern drag and drop
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .project)
    }
    
    // Computed properties for hierarchy
    var depth: Int { /* calculated based on parent chain */ }
    var descendants: [Project] { /* all child projects recursively */ }
    
    // Validation methods
    func canBeParentOf(_ project: Project) -> Bool
    func validateAsParentOf(_ project: Project) -> ValidationResult
}

// Custom UTType for project drag and drop
extension UTType {
    static let project = UTType(exportedAs: "com.yourapp.project")
}
```

### Enhanced EditProjectView

Following Apple's latest SwiftUI patterns and design guidelines:

```swift
struct EditProjectView: View {
    enum Mode {
        case create(parentID: String?)
        case edit(Project)
    }
    
    let mode: Mode
    @Binding var isPresented: Bool
    @EnvironmentObject private var projectManager: ProjectManager
    
    // Modern SwiftUI state management
    @State private var formData = ProjectFormData()
    @State private var validationErrors: [ValidationError] = []
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Modern form sections with proper styling
                ProjectBasicInfoSection(formData: $formData)
                ProjectHierarchySection(formData: $formData)
                ProjectAdvancedSection(formData: $formData)
                
                if case .edit(let project) = mode {
                    ProjectDangerZoneSection(project: project)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncButton("Save") {
                        await saveProject()
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
        }
    }
}
```

### Enhanced ProjectRowView

The existing ProjectRowView will be enhanced following Apple's latest SwiftUI best practices:

```swift
struct ProjectRowView: View {
    @ObservedObject var project: Project
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectManager: ProjectManager
    
    var body: some View {
        // Use modern SwiftUI drag and drop APIs
        projectLabel
            .draggable(project) {
                // Drag preview
                ProjectDragPreview(project: project)
            }
            .dropDestination(for: Project.self) { projects, location in
                // Handle drop using modern dropDestination API
                projectManager.handleDrop(projects, on: project, at: location)
            }
            .contextMenu {
                // Modern right-click menu with SF Symbols
                ProjectRightClickMenu(project: project)
            }
    }
}
```

### Enhanced SidebarView

The existing SidebarView will be enhanced with:

```swift
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showingCreateProject = false
    
    var body: some View {
        List {
            // Existing sections...
            
            Section(header: projectSectionHeader) {
                // Existing special items...
                
                // Enhanced My Projects section with create button
                DisclosureGroup(isExpanded: $isMyProjectsExpanded) {
                    ForEach(projectManager.projectTree) { project in
                        ProjectRowView(project: project)
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("My Projects")
                        Spacer()
                        Button(action: { showingCreateProject = true }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            EditProjectView(mode: .create(parentID: nil), isPresented: $showingCreateProject)
        }
    }
}
```

### ProjectRightClickMenu

```swift
struct ProjectRightClickMenu: View {
    let project: Project
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showingEditProject = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCreateChild = false
    
    var body: some View {
        Group {
            Button("Edit Project", systemImage: "pencil") {
                showingEditProject = true
            }
            
            Button("Add Child Project", systemImage: "plus") {
                showingCreateChild = true
            }
            
            Divider()
            
            Button("Delete Project", systemImage: "trash", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(mode: .edit(project), isPresented: $showingEditProject)
        }
        .sheet(isPresented: $showingCreateChild) {
            EditProjectView(mode: .create(parentID: project.id), isPresented: $showingCreateChild)
        }
        .confirmationDialog("Delete Project", isPresented: $showingDeleteConfirmation) {
            ProjectDeleteConfirmationDialog(project: project)
        }
    }
}
```

### ProjectDragDropHandler

```swift
struct ProjectDragDropHandler {
    let projectManager: ProjectManager
    
    // Handle different drop scenarios
    func handleDrop(_ projects: [Project], on target: Project?, at location: CGPoint, in bounds: CGRect) -> Bool {
        guard let draggedProject = projects.first else { return false }
        
        let dropPosition = getDropPosition(for: location, in: bounds)
        
        switch dropPosition {
        case .inside(let targetProject):
            return projectManager.moveProject(draggedProject, toParent: targetProject)
        case .between(let index, let parentID):
            return projectManager.reorderProject(draggedProject, to: index, in: parentID)
        case .invalid:
            return false
        }
    }
    
    private func getDropPosition(for location: CGPoint, in bounds: CGRect) -> DropPosition {
        // Complex logic to determine if dropping inside, above, or below
    }
}

enum DropPosition {
    case inside(Project)
    case between(index: Int, parentID: String?)
    case invalid
}
```

### Enhanced ProjectPickerItem

The existing ProjectPickerItem will be enhanced with:
- Modern SwiftUI layout using Grid or LazyVStack
- SF Symbols for better visual hierarchy
- Improved accessibility with proper labels and hints
- Support for Dynamic Type

## Data Models

### Project Model Extensions

```swift
extension Project {
    // Drag and Drop Properties
    var isDraggable: Bool { return true }
    var canAcceptChildren: Bool { return true }
    
    // Hierarchy Helpers
    func isAncestorOf(_ project: Project) -> Bool
    func getPath() -> String
    func getSiblings() -> [Project]
    
    // Validation
    func validateName(_ name: String) -> ValidationResult
    func validateParent(_ parent: Project?) -> ValidationResult
}
```

### New Data Structures

```swift
enum DropPosition {
    case above
    case below
    case inside
}

struct ProjectDragData {
    let project: Project
    let sourceIndex: Int
    let sourceParentID: String?
}

enum ValidationResult {
    case valid
    case invalid(String)
}

struct ProjectFormData {
    var name: String = ""
    var color: Color = .blue
    var parentID: String?
    var notes: String = ""
    var isArchived: Bool = false
}
```

## Error Handling

### Validation Errors

1. **Name Validation**: Empty names, duplicate names within the same parent
2. **Hierarchy Validation**: Circular references, maximum depth limits
3. **Deletion Validation**: Projects with active timers, projects with time entries

### Error Recovery

```swift
enum ProjectError: LocalizedError {
    case invalidName(String)
    case circularReference
    case deleteActiveProject
    case persistenceFailure(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidName(let reason):
            return "Invalid project name: \(reason)"
        case .circularReference:
            return "Cannot move project: would create circular reference"
        case .deleteActiveProject:
            return "Cannot delete project with active timer"
        case .persistenceFailure(let error):
            return "Failed to save changes: \(error.localizedDescription)"
        }
    }
}
```

### Error Handling Strategy

1. **Validation**: Prevent invalid operations before they occur
2. **User Feedback**: Clear error messages with actionable guidance
3. **Graceful Degradation**: Maintain app stability when operations fail
4. **Recovery Options**: Provide undo functionality where appropriate

## Testing Strategy

### Unit Tests

1. **ProjectManager Tests**
   - CRUD operation validation
   - Hierarchy manipulation correctness
   - Error handling scenarios

2. **ProjectManager Hierarchy Tests**
   - Tree building algorithms
   - Circular reference detection
   - Sort order management

3. **Project Model Tests**
   - Validation logic
   - Hierarchy relationship methods
   - Drag-and-drop data structures

### Integration Tests

1. **View Integration Tests**
   - Form submission workflows
   - Drag-and-drop interactions
   - Real-time UI updates

2. **Data Persistence Tests**
   - Save/load operations
   - Data integrity after operations
   - Migration scenarios

### UI Tests

1. **User Workflow Tests**
   - Complete CRUD workflows
   - Drag-and-drop scenarios
   - Error handling user experience

2. **Accessibility Tests**
   - VoiceOver support for drag-and-drop
   - Keyboard navigation
   - Screen reader compatibility

## Implementation Approach

### Phase 1: Core Infrastructure
- Implement comprehensive ProjectManager service
- Extend Project model with new properties
- Add hierarchy management and validation logic

### Phase 2: CRUD Operations
- Implement ProjectFormView
- Add create/edit/delete functionality
- Integrate with existing AppState
- Add persistence layer

### Phase 3: Drag and Drop
- Implement DraggableProjectRowView
- Add drag gesture handling
- Create drop target detection
- Implement visual feedback

### Phase 4: Integration and Polish
- Update existing views to use new components
- Add error handling and validation
- Implement undo functionality
- Performance optimization

## Integration Strategy

### AppState Integration

```swift
// Enhanced AppState to work with ProjectManager
class AppState: ObservableObject {
    @Published var projectManager = ProjectManager()
    
    // Updated methods to use ProjectManager
    func selectProject(_ project: Project) {
        // Ensure project still exists after potential deletions
        guard projectManager.getProject(by: project.id) != nil else {
            clearSelection()
            return
        }
        // Existing selection logic...
    }
    
    // Handle project deletions gracefully
    func handleProjectDeletion(_ projectID: String) {
        if selectedProject?.id == projectID {
            clearSelection()
        }
    }
}
```

### View Integration Points

1. **SidebarView**: Add create button, integrate ProjectManager
2. **ProjectRowView**: Add context menu, drag-and-drop support
3. **EditProjectView**: Support both create and edit modes
4. **ProjectPickerItem**: Update to use ProjectManager data
5. **Timeline/Activity Views**: Handle project changes gracefully

### Real-time Updates

```swift
// Ensure all views update when projects change
extension ProjectManager {
    func notifyProjectChanged(_ project: Project) {
        // Trigger UI updates across all views
        objectWillChange.send()
        
        // Notify AppState of changes
        NotificationCenter.default.post(
            name: .projectDidChange,
            object: project
        )
    }
}
```

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading**: Load project hierarchies on demand
2. **Efficient Updates**: Use targeted ObservableObject updates
3. **Drag Performance**: Optimize drag gesture handling for smooth interactions
4. **Memory Management**: Proper cleanup of drag state and temporary objects
5. **Background Persistence**: Auto-save changes without blocking UI

### Scalability

1. **Large Hierarchies**: Efficient tree traversal algorithms with maximum depth limits
2. **Batch Operations**: Support for bulk project operations
3. **Search and Filter**: Fast project lookup capabilities with indexing
4. **Persistence**: Efficient data storage using Core Data or similar
5. **Undo/Redo**: Command pattern for complex operations