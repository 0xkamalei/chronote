# Time Tracking App - Remaining Features Design

## Overview

This design document outlines the technical implementation approach for completing the time tracking application's core functionality. The design focuses on building robust, performant, and user-friendly features while maintaining the existing SwiftUI/SwiftData architecture.

## Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer (SwiftUI)                       │
├─────────────────────────────────────────────────────────────────┤
│  TimelineView  │  SidebarView  │  TimerView  │  ActivitiesView  │
├─────────────────────────────────────────────────────────────────┤
│                    State Management Layer                       │
├─────────────────────────────────────────────────────────────────┤
│     AppState     │  TimerManager  │  ActivityQueryManager       │
├─────────────────────────────────────────────────────────────────┤
│                    Business Logic Layer                         │
├─────────────────────────────────────────────────────────────────┤
│ ActivityTracker │ RuleEngine │ IdleDetector │ ContextCapturer   │
├─────────────────────────────────────────────────────────────────┤
│                    Data Access Layer                            │
├─────────────────────────────────────────────────────────────────┤
│  ActivityManager │ ProjectManager │ TimeEntryManager │ RuleManager│
├─────────────────────────────────────────────────────────────────┤
│                    Persistence Layer                            │
├─────────────────────────────────────────────────────────────────┤
│                        SwiftData                                │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Activity Tracking System

#### ActivityTracker Class
```swift
@MainActor
class ActivityTracker: ObservableObject {
    // Core tracking functionality
    func startTracking()
    func stopTracking()
    func handleAppSwitch(_ notification: Notification)
    func handleSystemSleep()
    func handleSystemWake()
    
    // Configuration
    var isTrackingEnabled: Bool
    var minimumActivityDuration: TimeInterval
    var trackWindowTitles: Bool
}
```

#### Implementation Details
- **NSWorkspace Integration**: Monitor `didActivateApplicationNotification` and `willSleepNotification`
- **Accessibility API**: Use `AXUIElementCopyAttributeValue` for window title capture
- **Background Processing**: Implement efficient background queue for data processing
- **Error Handling**: Robust retry mechanisms with exponential backoff

### 2. Real-time Timer System

#### TimerManager Class
```swift
@MainActor
class TimerManager: ObservableObject {
    @Published var activeTimer: TimerSession?
    @Published var isRunning: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    
    func startTimer(project: Project?, title: String?, notes: String?)
    func stopTimer() -> TimeEntry?
    func pauseTimer()
    func resumeTimer()
    func getFormattedElapsedTime() -> String
}

struct TimerSession {
    let id: UUID
    let startTime: Date
    var project: Project?
    var title: String?
    var notes: String?
    var estimatedDuration: TimeInterval?
}
```

#### Implementation Details
- **Timer Implementation**: Use `Timer.scheduledTimer` with 1-second intervals for UI updates
- **Background Persistence**: Save timer state to UserDefaults for crash recovery
- **Notification Integration**: Schedule local notifications for timer completion
- **Status Bar Integration**: Show timer in menu bar with live updates

### 3. Interactive Timeline Component

#### TimelineViewModel Class
```swift
@MainActor
class TimelineViewModel: ObservableObject {
    @Published var timelineScale: CGFloat = 1.0
    @Published var selectedDateRange: DateInterval
    @Published var activities: [Activity] = []
    @Published var timeEntries: [TimeEntry] = []
    @Published var projects: [Project] = []
    
    func zoomTimeline(scale: CGFloat)
    func selectTimeRange(start: Date, end: Date)
    func createTimeEntryAt(startTime: Date, endTime: Date)
    func assignActivityToProject(activity: Activity, project: Project)
}
```

#### Timeline Rendering Strategy
- **Three-Row Layout**: Device activities, projects, time entries
- **Scalable Blocks**: Width proportional to duration, minimum 2px width
- **Hover Interactions**: Show detailed tooltips with activity information
- **Drag & Drop**: Support dragging activities to projects
- **Zoom Functionality**: Cmd+scroll wheel for timeline scaling

### 4. Idle Detection System

#### IdleDetector Class
```swift
class IdleDetector {
    private var idleTimer: Timer?
    private var lastActivityTime: Date = Date()
    private let idleThreshold: TimeInterval = 300 // 5 minutes
    
    func startMonitoring()
    func stopMonitoring()
    func resetIdleTimer()
    func handleIdleDetected()
    func handleReturnFromIdle()
}
```

#### Implementation Details
- **System Event Monitoring**: Use `CGEventTap` to monitor mouse/keyboard activity
- **Idle Threshold**: Configurable idle time (default 5 minutes)
- **Recovery Dialog**: Present options for handling idle time
- **Activity Adjustment**: Retroactively adjust activity durations

### 5. Context Capture System

#### ContextCapturer Class
```swift
class ContextCapturer {
    func captureWindowTitle(for app: NSRunningApplication) -> String?
    func captureBrowserContext(for app: NSRunningApplication) -> BrowserContext?
    func requestAccessibilityPermissions() -> Bool
    func isAccessibilityEnabled() -> Bool
}

struct BrowserContext {
    let url: String?
    let title: String?
    let domain: String?
}
```

#### Implementation Details
- **Accessibility API**: Use AXUIElement for window title capture
- **Browser Integration**: Special handling for Safari, Chrome, Firefox
- **Privacy Controls**: Respect user privacy settings and incognito mode
- **Permission Management**: Guide users through accessibility permission setup

### 6. Rule Engine System

#### RuleEngine Class
```swift
@MainActor
class RuleEngine: ObservableObject {
    @Published var rules: [Rule] = []
    
    func evaluateRules(for activity: Activity) -> Project?
    func createRule(conditions: [RuleCondition], action: RuleAction)
    func updateRule(_ rule: Rule)
    func deleteRule(_ rule: Rule)
    func applyRulesRetroactively(from date: Date)
}

struct Rule {
    let id: UUID
    let name: String
    let conditions: [RuleCondition]
    let action: RuleAction
    let priority: Int
    let isEnabled: Bool
}

enum RuleCondition {
    case appName(String, MatchType)
    case windowTitle(String, MatchType)
    case timeRange(start: Date, end: Date)
    case dayOfWeek([Int])
}

enum RuleAction {
    case assignToProject(Project)
    case setProductivityScore(Double)
    case addTags([String])
}
```

## Data Models

### Enhanced Activity Model
```swift
@Model
final class Activity {
    // Existing properties...
    var windowTitle: String?
    var url: String? // For browser activities
    var documentPath: String? // For document-based apps
    var isIdleTime: Bool = false
    var contextData: Data? // JSON for additional context
    var assignedByRule: String? // Rule ID that assigned this activity
}
```

### Timer Session Model
```swift
@Model
final class TimerSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var projectId: String?
    var title: String?
    var notes: String?
    var estimatedDuration: TimeInterval?
    var actualDuration: TimeInterval?
    var isCompleted: Bool = false
    var wasInterrupted: Bool = false
}
```

### Rule Model
```swift
@Model
final class Rule {
    @Attribute(.unique) var id: UUID
    var name: String
    var conditionsData: Data // JSON encoded conditions
    var actionData: Data // JSON encoded action
    var priority: Int
    var isEnabled: Bool = true
    var createdAt: Date
    var lastAppliedAt: Date?
    var applicationCount: Int = 0
}
```

## Error Handling

### Error Types
```swift
enum ActivityTrackingError: LocalizedError {
    case permissionDenied
    case systemResourceUnavailable
    case dataCorruption
    case networkUnavailable
    case storageQuotaExceeded
    
    var errorDescription: String? { /* Implementation */ }
    var recoverySuggestion: String? { /* Implementation */ }
}
```

### Error Recovery Strategy
1. **Graceful Degradation**: Continue basic functionality when advanced features fail
2. **Automatic Retry**: Exponential backoff for transient failures
3. **User Notification**: Clear error messages with actionable solutions
4. **Data Recovery**: Automatic repair of corrupted data where possible
5. **Fallback Modes**: Alternative tracking methods when primary systems fail

## Testing Strategy

### Unit Testing
- **ActivityTracker**: Mock NSWorkspace notifications and verify activity creation
- **TimerManager**: Test timer state transitions and persistence
- **RuleEngine**: Verify rule evaluation logic with various conditions
- **IdleDetector**: Mock system events and test idle detection accuracy

### Integration Testing
- **End-to-End Tracking**: Simulate full activity tracking workflow
- **Data Persistence**: Verify SwiftData integration and data integrity
- **UI Interactions**: Test timeline interactions and project assignments
- **Performance Testing**: Measure resource usage under various loads

### Performance Benchmarks
- **Memory Usage**: < 50MB during normal operation
- **CPU Usage**: < 1% average, < 5% during intensive operations
- **Database Operations**: < 100ms for typical queries
- **UI Responsiveness**: < 16ms frame time for smooth 60fps

## Security and Privacy

### Privacy Controls
- **Accessibility Permissions**: Clear explanation and optional features
- **Data Encryption**: Encrypt sensitive data like window titles
- **Local Storage**: All data stored locally by default
- **Incognito Detection**: Respect private browsing modes
- **User Consent**: Explicit opt-in for advanced tracking features

### Security Measures
- **Input Validation**: Sanitize all captured data
- **SQL Injection Prevention**: Use SwiftData's built-in protections
- **Memory Safety**: Proper cleanup of observers and timers
- **Sandboxing**: Respect macOS app sandbox requirements

## Performance Optimization

### Memory Management
- **Weak References**: Prevent retain cycles in observers
- **Data Pagination**: Load activities in chunks for large datasets
- **Cache Management**: LRU cache for frequently accessed data
- **Background Processing**: Move heavy operations off main thread

### Database Optimization
- **Indexing Strategy**: Index frequently queried fields (startTime, projectId)
- **Batch Operations**: Group database writes for efficiency
- **Query Optimization**: Use predicates to minimize data transfer
- **Archival System**: Move old data to separate storage

## Deployment and Rollout

### Feature Flags
```swift
struct FeatureFlags {
    static let advancedActivityTracking = true
    static let ruleEngine = false // Gradual rollout
    static let browserIntegration = true
    static let idleDetection = true
}
```

### Migration Strategy
1. **Database Migration**: Seamless upgrade of existing data
2. **Settings Migration**: Preserve user preferences
3. **Backward Compatibility**: Support for older data formats
4. **Rollback Plan**: Ability to revert to previous version if needed

### Monitoring and Analytics
- **Crash Reporting**: Automatic crash detection and reporting
- **Performance Metrics**: Track resource usage and performance
- **Feature Usage**: Monitor adoption of new features
- **Error Tracking**: Centralized error logging and analysis