# Design Document

## Overview

This design implements an automatic app activity recording and persistence backend module for macOS that continuously monitors application usage and stores data using SwiftData with SQLite backend. The system operates as a background service that captures app switches, calculates usage durations, and handles system events like sleep/wake cycles.

The solution integrates with the existing SwiftUI/SwiftData architecture while providing a robust, performant activity tracking system. The design focuses on creating a clean separation between activity monitoring, data persistence, and the existing UI components.

**Design Decision**: The implementation uses SwiftData as the primary persistence layer with SQLite as the underlying storage engine, leveraging the existing ModelContainer setup in the app. This ensures consistency with the current architecture while providing the performance and reliability needed for continuous background recording.

**Architecture Rationale**: The modular design separates concerns into distinct components: ActivityRecorder for system monitoring, ActivityRecord SwiftData model for persistence, and ActivityManager as the coordination layer. This architecture enables testability, maintainability, and future extensibility while ensuring minimal performance impact on the system.

## Architecture

The implementation follows a simplified architecture with minimal components:

- **ActivityManager**: Core service that handles NSWorkspace notifications, system events, and data persistence
- **ActivityRecord**: SwiftData model for persistent storage of activity data

**Design Decision**: The ActivityManager combines monitoring and persistence responsibilities to minimize complexity. This single-responsibility approach reduces the number of components while maintaining clean separation between system monitoring and data storage.

## Data Models

### Enhanced Activity SwiftData Model

Convert the existing Activity struct to a SwiftData model for persistence:

```swift
@Model
final class Activity {
    var id: UUID
    var appName: String
    var appBundleId: String
    var appTitle: String?
    var duration: TimeInterval
    var startTime: Date
    var endTime: Date?  // Optional for currently active apps (nil = active)
    var icon: String
    
    // Computed properties (preserved from original)
    var durationString: String { ... }
    var minutes: Int { ... }
    var calculatedDuration: TimeInterval { ... }
    var isActive: Bool { return endTime == nil }  // Computed from endTime
}
```

**Key Design Changes**:
- **Convert struct to class**: Required for SwiftData @Model
- **Optional endTime**: Support tracking currently active applications (endTime = nil means active)
- **Computed isActive**: Derived from endTime being nil, no redundant storage
- **Preserve existing API**: Maintain durationString and minutes computed properties
- **Maintain compatibility**: Existing UI code continues to work with minimal changes

**Migration Strategy**: The existing Activity struct becomes a SwiftData model, eliminating the need for a separate ActivityRecord type. This reduces complexity and maintains compatibility with existing UI components.

**Storage Strategy**: Uses SQLite through SwiftData's automatic schema generation, with indexing on frequently queried fields (startTime, appBundleId, isActive) for optimal performance.

## Storage Layer Design

### Database Architecture

**SQLite Configuration**:
```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    groupContainer: .automatic,
    cloudKitDatabase: .none  // Local storage only for privacy
)
```

**Key Storage Decisions**:
- **Local SQLite storage**: Ensures privacy and offline functionality
- **No CloudKit sync**: Activity data remains on device for privacy
- **Automatic schema migration**: SwiftData handles model evolution
- **Write-ahead logging**: SQLite WAL mode for better concurrency

### Data Access Patterns

**Write Operations**:
```swift
// High-frequency writes for activity tracking
func saveActivity(_ activity: Activity, context: ModelContext) {
    context.insert(activity)
    try? context.save()
}

// Batch operations for performance
func batchSaveActivities(_ activities: [Activity], context: ModelContext) {
    activities.forEach { context.insert($0) }
    try? context.save()
}
```

**Read Operations**:
```swift
// Efficient queries with predicates
func getActivitiesForDate(_ date: Date) -> [Activity] {
    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let predicate = #Predicate<Activity> { activity in
        activity.startTime >= startOfDay && activity.startTime < endOfDay
    }
    
    let descriptor = FetchDescriptor<Activity>(predicate: predicate)
    return try? context.fetch(descriptor) ?? []
}
```

### Performance Optimization

**Indexing Strategy**:
- Primary index on `id` (UUID)
- Composite index on `(startTime, appBundleId)` for time-based queries
- Index on `endTime` for finding active activities (WHERE endTime IS NULL)
- Index on `appBundleId` for app-specific queries

**Query Optimization**:
- Use predicates for efficient filtering
- Limit result sets with FetchDescriptor
- Lazy loading for large datasets
- Background context for heavy operations

**Memory Management**:
- Automatic object lifecycle through SwiftData
- Periodic cleanup of old records
- Efficient batch operations
- Connection pooling handled by SwiftData

### Data Integrity and Consistency

**Transaction Management**:
```swift
// Atomic operations for critical updates
func finishCurrentActivity(context: ModelContext) {
    context.transaction {
        if let current = getCurrentActivity() {
            current.endTime = Date()
            current.duration = current.endTime!.timeIntervalSince(current.startTime)
            current.isActive = false
        }
    }
}
```

**Validation Rules**:
- `startTime` must be before `endTime` (when endTime exists)
- `duration` must match calculated time difference
- Only one activity can have `endTime = nil` at a time (only one active activity)
- `appBundleId` cannot be empty

**Error Recovery**:
- Automatic retry for transient database errors
- Graceful handling of disk space issues
- Data validation before persistence
- Corruption detection and recovery

### Storage Lifecycle Management

**Initialization**:
```swift
// Database setup in app launch
func initializeStorage() {
    // Verify database integrity
    // Run any pending migrations
    // Clean up incomplete records
    // Set up performance monitoring
}
```

**Maintenance Operations**:
- Periodic VACUUM operations for space reclamation
- Cleanup of records older than retention period
- Index optimization and statistics updates
- Database health monitoring

**Backup and Recovery**:
- Automatic SQLite backup mechanisms
- Export functionality for data portability
- Import validation and conflict resolution
- Disaster recovery procedures

## Components and Interfaces

### ActivityManager (Unified Component)

Single service that handles both monitoring and persistence:

**Key Responsibilities**:
- Registers NSWorkspace notification observers for app activation/deactivation
- Monitors system sleep/wake notifications
- Captures app switch events with precise timestamps
- Handles database operations directly using SwiftData
- Provides public API for UI integration
- Manages error recovery and data consistency

**Public Interface**:
```swift
@MainActor
class ActivityManager: ObservableObject {
    static let shared = ActivityManager()
    private var currentActivity: Activity?
    private var notificationObservers: [NSObjectProtocol] = []
    
    func startTracking(modelContext: ModelContext)
    func stopTracking(modelContext: ModelContext)
    func trackAppSwitch(newApp: String, modelContext: ModelContext)
    func getCurrentActivity() -> Activity?
    func getRecentActivities(limit: Int) -> [Activity]
    
    // Private methods
    private func handleAppActivation(_ notification: Notification)
    private func handleSystemSleep()
    private func handleSystemWake()
}
```

**Design Decision**: Combining monitoring and persistence in a single component reduces complexity and eliminates unnecessary abstractions. The ActivityManager directly uses SwiftData's ModelContext for database operations, leveraging the framework's built-in performance optimizations.

## Error Handling and Data Integrity

### Robust Error Handling

The system implements comprehensive error handling at multiple levels:

**Database Operation Errors**:
- Automatic retry logic for transient failures
- Graceful degradation when storage is unavailable
- Error logging and recovery mechanisms
- Data validation before persistence

**System Event Handling**:
- Timeout handling for unresponsive applications
- Recovery from notification system failures
- Handling of rapid app switching scenarios
- Protection against duplicate event processing

**Data Consistency Measures**:
- Transaction-based operations for critical updates
- Validation of activity duration calculations
- Automatic correction of incomplete records
- Periodic data integrity checks

### Performance Optimization

**Memory Management**:
- Minimal in-memory state to reduce memory footprint
- Efficient object lifecycle management
- Automatic cleanup of completed activities
- Smart caching for frequently accessed data

**CPU Optimization**:
- Asynchronous processing for non-critical operations
- Efficient notification handling without blocking
- Optimized database queries with proper indexing
- Background processing for data maintenance

**Storage Optimization**:
- Batch operations to minimize disk I/O
- Efficient SQLite configuration through SwiftData
- Automatic database optimization and vacuuming
- Configurable data retention policies

## Integration with Existing System

### SwiftData Integration

The design leverages the existing SwiftData setup in `time_vscodeApp.swift`:

**Schema Extension**:
```swift
let schema = Schema([
    Item.self,
    Activity.self,
])
```

**ModelContainer Configuration**:
- Extends existing container with new models
- Maintains backward compatibility with existing data
- Handles schema migrations automatically
- Preserves existing SQLite storage configuration

### UI Integration Points

The backend provides clean integration points for existing UI components:

**Data Access Patterns**:
- SwiftData @Query integration for reactive UI updates
- Efficient filtering and sorting for activity views
- Real-time updates for currently active applications
- Historical data access with date range filtering

**Existing Component Integration**:
- Direct compatibility with existing Activity-based UI components
- No conversion utilities needed - same data type throughout
- Maintains existing UI patterns and data flow
- Seamless transition from MockData to persistent storage

## System Event Handling

### NSWorkspace Notification Management

**Application Lifecycle Events**:
```swift
// App activation monitoring
NSWorkspace.didActivateApplicationNotification
NSWorkspace.didDeactivateApplicationNotification

// System state monitoring  
NSWorkspace.willSleepNotification
NSWorkspace.didWakeNotification
```

**Event Processing Strategy**:
- Main queue registration for immediate response
- Background queue processing for database operations
- Debouncing for rapid app switching scenarios
- State validation before processing events

### Sleep/Wake Cycle Handling

**Sleep Event Processing**:
1. Immediately stop current activity tracking
2. Calculate and save final duration for active activity
3. Mark session as completed
4. Flush pending database operations
5. Clean up system resources

**Wake Event Processing**:
1. Resume system monitoring
2. Optionally continue tracking previously active app
3. Create new session for resumed activities
4. Validate system state consistency

**Design Decision**: The system does not automatically resume tracking the previously active application after wake events. This prevents artificial activity recording during sleep periods and allows users to naturally resume their workflow.

## Testing Strategy

### Unit Testing

**Core Component Testing**:
- ActivityRecorder event handling logic
- ActivityManager state management
- Data model validation and relationships
- Duration calculation accuracy
- Error handling scenarios

**Mock Integration**:
- NSWorkspace notification simulation
- ModelContext mocking for database operations
- System event simulation for sleep/wake cycles
- Performance testing with large datasets

### Integration Testing

**End-to-End Scenarios**:
- Complete app switch recording workflow
- System sleep/wake cycle handling
- Database persistence and retrieval
- UI integration and data binding
- Error recovery and data consistency

**Performance Testing**:
- Memory usage under continuous monitoring
- CPU impact during normal operation
- Database performance with large datasets
- System responsiveness during heavy activity

## Migration and Deployment

### Data Migration Strategy

**Schema Evolution**:
- SwiftData automatic migration for model changes
- Backward compatibility with existing data
- Validation of migrated data integrity
- Rollback capabilities for failed migrations

**Deployment Considerations**:
- Gradual rollout with feature flags
- Monitoring and alerting for system health
- Performance metrics collection
- User feedback integration for optimization

The design provides a robust, performant foundation for automatic app activity recording while maintaining clean integration with the existing SwiftUI/SwiftData architecture. The modular approach ensures maintainability and extensibility for future enhancements.