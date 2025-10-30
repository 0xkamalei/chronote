# Design Document

## Overview

This design implements a comprehensive TimeEntry CRUD system that integrates seamlessly with the existing SwiftData-based architecture. The system follows the established patterns used by ProjectManager and ActivityManager, providing a TimeEntryManager for business logic, a SwiftData @Model for persistence, and reactive UI integration through ObservableObject and NotificationCenter patterns.

The design ensures data integrity, performance optimization, and seamless integration with existing project management and activity tracking features while maintaining the application's architectural consistency.

## Architecture

### Core Components

```
TimeEntry System Architecture:

┌─────────────────────────────────────────────────────────────────┐
│                           UI Layer                              │
├─────────────────────────────────────────────────────────────────┤
│ NewTimeEntryView │ EditTimeEntryView │ TimeEntryListView        │
│ (Enhanced)       │ (New)             │ (New)                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Business Logic Layer                       │
├─────────────────────────────────────────────────────────────────┤
│                    TimeEntryManager                             │
│  • CRUD Operations    • Validation      • Project Integration   │
│  • Timer Integration  • Notifications   • Data Consistency     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Data Persistence Layer                     │
├─────────────────────────────────────────────────────────────────┤
│                    TimeEntry @Model                             │
│  • SwiftData Entity   • Relationships   • Computed Properties  │
│  • Validation Rules   • Indexing        • Migration Support    │
└─────────────────────────────────────────────────────────────────┘
```

### Integration Points

- **ProjectManager**: TimeEntry creation/editing uses existing project selection
- **ActivityManager**: Timer stop events create TimeEntry records
- **AppState**: Global state management for UI updates and selection
- **SwiftData**: Unified persistence layer with existing models

## Components and Interfaces

### 1. TimeEntry SwiftData Model

```swift
@Model
final class TimeEntry {
    @Attribute(.unique) var id: UUID
    var projectId: String?
    var title: String
    var notes: String?
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var createdAt: Date
    var updatedAt: Date
    
    // Computed properties
    var calculatedDuration: TimeInterval { ... }
    var durationString: String { ... }
    var isValid: Bool { ... }
    
    // Relationships (computed at runtime)
    var project: Project? { ... }
    
    init(projectId: String?, title: String, notes: String?, startTime: Date, endTime: Date)
}
```

**Key Design Decisions:**
- Uses UUID for unique identification (consistent with Activity model)
- Stores projectId as String? for optional project association
- Includes both stored duration and computed duration for validation
- Tracks creation/modification timestamps for audit trail
- Project relationship computed at runtime to avoid SwiftData complexity

### 2. TimeEntryManager Business Logic

```swift
@MainActor
class TimeEntryManager: ObservableObject {
    // Singleton pattern (consistent with ProjectManager/ActivityManager)
    static let shared = TimeEntryManager()
    
    // Published properties for reactive UI
    @Published private(set) var timeEntries: [TimeEntry] = []
    @Published private(set) var isLoading: Bool = false
    
    // Core CRUD operations
    func createTimeEntry(...) async throws -> TimeEntry
    func updateTimeEntry(...) async throws
    func deleteTimeEntry(...) async throws
    func getTimeEntries(for project: Project?) -> [TimeEntry]
    
    // Integration methods
    func createFromTimer(project: Project?, startTime: Date, endTime: Date) async throws -> TimeEntry
    func reassignTimeEntries(from: Project, to: Project?) async throws
    
    // Validation and utilities
    func validateTimeEntry(...) -> ValidationResult
    func getTimeEntriesInDateRange(...) -> [TimeEntry]
}
```

**Key Design Decisions:**
- Follows singleton pattern established by other managers
- Uses @MainActor for thread safety (consistent with existing managers)
- Provides both direct CRUD and integration-specific methods
- Implements comprehensive validation following ProjectManager patterns
- Supports batch operations for performance

### 3. Enhanced UI Components

#### NewTimeEntryView (Enhanced)
- Maintains existing UI structure and project selection
- Adds actual save functionality through TimeEntryManager
- Implements proper validation and error handling
- Integrates with existing ProjectManager for project selection

#### EditTimeEntryView (New)
- Similar structure to NewTimeEntryView but for editing
- Pre-populates form with existing TimeEntry data
- Handles update operations and validation
- Supports project reassignment

#### TimeEntryListView (New)
- Displays time entries in chronological order
- Supports filtering by project and date range
- Provides edit/delete actions for each entry
- Integrates with existing activity grouping system

## Data Models

### TimeEntry Entity Schema

```sql
-- SwiftData will generate similar SQLite schema
CREATE TABLE TimeEntry (
    id TEXT PRIMARY KEY,
    projectId TEXT NULL,
    title TEXT NOT NULL,
    notes TEXT NULL,
    startTime REAL NOT NULL,
    endTime REAL NOT NULL,
    duration REAL NOT NULL,
    createdAt REAL NOT NULL,
    updatedAt REAL NOT NULL
);

-- Indexes for performance (handled by DatabaseConfiguration)
CREATE INDEX idx_timeentry_project ON TimeEntry(projectId);
CREATE INDEX idx_timeentry_start_time ON TimeEntry(startTime);
CREATE INDEX idx_timeentry_date_range ON TimeEntry(startTime, endTime);
```

### Relationships and Constraints

- **Project Association**: Optional foreign key to Project.id
- **Time Validation**: endTime must be after startTime
- **Duration Consistency**: stored duration must match calculated duration
- **Title Requirement**: title cannot be empty
- **Time Boundaries**: reasonable limits on duration and time ranges

### Data Integrity Rules

1. **Temporal Consistency**: endTime >= startTime
2. **Duration Accuracy**: duration = endTime - startTime (within tolerance)
3. **Project Validity**: projectId must reference existing project or be null
4. **Title Validation**: non-empty, reasonable length limits
5. **Time Bounds**: start/end times within reasonable past/future limits

## Error Handling

### Error Types

```swift
enum TimeEntryError: LocalizedError {
    case invalidTimeRange(String)
    case invalidDuration(String)
    case projectNotFound(String)
    case titleRequired
    case persistenceFailure(String)
    case validationFailed(String)
    
    var errorDescription: String? { ... }
}
```

### Error Handling Strategy

- **Validation Errors**: Immediate user feedback with specific messages
- **Persistence Errors**: Retry logic with exponential backoff
- **Project Relationship Errors**: Graceful handling of deleted projects
- **Concurrent Modification**: Optimistic locking with conflict resolution
- **Data Corruption**: Automatic repair and logging

### Recovery Mechanisms

1. **Auto-save**: Periodic saving of draft entries
2. **Conflict Resolution**: Last-write-wins with user notification
3. **Data Repair**: Automatic fixing of duration inconsistencies
4. **Orphan Handling**: Reassignment of entries from deleted projects

## Testing Strategy

### Unit Testing Focus Areas

1. **TimeEntryManager CRUD Operations**
   - Create, read, update, delete functionality
   - Validation logic and error handling
   - Project integration and relationship management

2. **TimeEntry Model Validation**
   - Data integrity constraints
   - Computed property accuracy
   - Edge cases and boundary conditions

3. **Integration Testing**
   - ProjectManager integration
   - ActivityManager timer integration
   - SwiftData persistence operations

### Test Data Strategy

- **Mock TimeEntries**: Comprehensive test data covering edge cases
- **Project Integration**: Tests with various project hierarchies
- **Time Scenarios**: Different time ranges, durations, and edge cases
- **Error Conditions**: Invalid data, missing projects, concurrent access

### Performance Testing

- **Large Dataset**: Performance with thousands of time entries
- **Query Optimization**: Efficient filtering and sorting operations
- **Memory Usage**: Proper cleanup and memory management
- **Concurrent Operations**: Thread safety and data consistency

## Integration Patterns

### ProjectManager Integration

```swift
// TimeEntryManager uses ProjectManager for validation
func validateProject(_ projectId: String?) -> ValidationResult {
    guard let projectId = projectId else { return .success }
    guard ProjectManager.shared.getProject(by: projectId) != nil else {
        return .failure(.projectNotFound("Project not found"))
    }
    return .success
}

// Handle project deletion
func handleProjectDeletion(_ projectId: String, reassignTo: String?) async throws {
    let affectedEntries = timeEntries.filter { $0.projectId == projectId }
    for entry in affectedEntries {
        entry.projectId = reassignTo
        entry.updatedAt = Date()
    }
    try await saveChanges()
}
```

### ActivityManager Integration

```swift
// Create TimeEntry when timer stops
extension ActivityManager {
    func stopTimer(createTimeEntry: Bool = true) async throws {
        guard let currentActivity = getCurrentActivity() else { return }
        
        // Stop the activity
        currentActivity.endTime = Date()
        try await saveActivity(currentActivity, modelContext: modelContext)
        
        // Create time entry if requested
        if createTimeEntry {
            let timeEntry = try await TimeEntryManager.shared.createFromTimer(
                project: AppState.shared.selectedProject,
                startTime: currentActivity.startTime,
                endTime: currentActivity.endTime!
            )
        }
    }
}
```

### Notification Integration

```swift
// TimeEntryManager sends notifications for UI updates
extension Notification.Name {
    static let timeEntryDidChange = Notification.Name("timeEntryDidChange")
    static let timeEntryWasDeleted = Notification.Name("timeEntryWasDeleted")
}

// UI components listen for updates
NotificationCenter.default.addObserver(
    forName: .timeEntryDidChange,
    object: nil,
    queue: .main
) { _ in
    // Refresh time entry displays
}
```

## Performance Optimizations

### Database Optimizations

1. **Indexing Strategy**: Indexes on projectId, startTime, and date ranges
2. **Query Optimization**: Efficient filtering and pagination
3. **Batch Operations**: Bulk insert/update for multiple entries
4. **Connection Pooling**: Reuse of SwiftData ModelContext

### Memory Management

1. **Lazy Loading**: Load time entries on demand
2. **Pagination**: Limit query results for large datasets
3. **Cache Management**: Intelligent caching with invalidation
4. **Weak References**: Prevent retain cycles in relationships

### UI Performance

1. **Reactive Updates**: Efficient UI updates through @Published properties
2. **Debounced Operations**: Prevent excessive API calls during editing
3. **Background Processing**: Heavy operations on background queues
4. **Optimistic UI**: Immediate UI updates with rollback on failure

## Migration and Versioning

### Schema Evolution

```swift
// Future schema changes handled through SwiftData migrations
enum TimeEntrySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    @Model
    final class TimeEntry {
        // New fields added in v2
        var tags: [String] = []
        var billableRate: Double?
        // ... existing fields
    }
}
```

### Data Migration Strategy

1. **Backward Compatibility**: Maintain compatibility with existing data
2. **Incremental Migration**: Step-by-step schema evolution
3. **Data Validation**: Verify data integrity after migration
4. **Rollback Support**: Ability to revert problematic migrations

This design provides a robust, scalable, and maintainable TimeEntry system that integrates seamlessly with the existing application architecture while following established patterns and best practices.