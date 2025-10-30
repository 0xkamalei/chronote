# Implementation Plan - Remaining Features

## Phase 1: Core Activity Tracking Infrastructure

- [x] 1. Implement Enhanced Activity Tracking System

  - Create ActivityTracker class with NSWorkspace integration
  - Implement proper app switch detection and handling
  - Add system sleep/wake event handling
  - Integrate with existing ActivityManager for data persistence
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 1.1 Set up NSWorkspace notification observers

  - Configure didActivateApplicationNotification listener
  - Configure willSleepNotification and didWakeNotification listeners
  - Implement proper observer cleanup and memory management
  - Add error handling for notification registration failures
  - _Requirements: 1.1, 1.4, 1.5_

- [x] 1.2 Implement application metadata capture

  - Extract application name, bundle ID, and localized name
  - Implement application icon retrieval and caching
  - Add fallback mechanisms for missing application data
  - Create efficient app metadata caching system
  - _Requirements: 1.3_

- [x] 1.3 Enhance Activity model with context data

  - Add windowTitle, url, documentPath fields to Activity model
  - Implement SwiftData migration for new fields
  - Add validation for new context data fields
  - Update existing Activity creation code to handle new fields
  - _Requirements: 1.3, 5.2, 5.3_

- [ ]\* 1.4 Write comprehensive activity tracking tests
  - Create unit tests for ActivityTracker class
  - Mock NSWorkspace notifications for testing
  - Test activity creation and persistence workflows
  - Add performance tests for tracking overhead
  - _Requirements: 1.1, 1.2, 1.3_

## Phase 2: Real-time Timer System

- [x] 2. Implement Timer Management System

  - Create TimerManager class with real-time updates
  - Implement timer persistence for crash recovery
  - Add timer state management and UI integration
  - Connect timer completion to TimeEntry creation
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 2.1 Create TimerManager and TimerSession models

  - Implement TimerManager as ObservableObject with published properties
  - Create TimerSession SwiftData model for persistence
  - Add timer state validation and error handling
  - Implement timer configuration and settings management
  - _Requirements: 2.1, 2.4_

- [x] 2.2 Implement real-time timer functionality

  - Create Timer instance with 1-second update intervals
  - Implement elapsed time calculation and formatting
  - Add timer pause/resume functionality
  - Create background timer persistence using UserDefaults
  - _Requirements: 2.1, 2.2, 2.4_

- [x] 2.3 Integrate timer with UI components

  - Update AppState to use TimerManager instead of basic boolean
  - Modify StartTimerView to work with new timer system
  - Add real-time timer display in status bar and main UI
  - Implement timer controls (start, stop, pause, resume)
  - _Requirements: 2.1, 2.2_

- [x] 2.4 Implement timer notifications and completion

  - Add local notification scheduling for timer completion
  - Create notification handling for timer alerts
  - Implement automatic TimeEntry creation on timer stop
  - Add timer completion sound and visual feedback
  - _Requirements: 2.3, 2.5, 12.1_

- [ ]\* 2.5 Create timer system tests
  - Write unit tests for TimerManager functionality
  - Test timer persistence and recovery scenarios
  - Create integration tests for timer-to-TimeEntry workflow
  - Add performance tests for timer accuracy and resource usage
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

## Phase 3: Context Capture and Window Title Integration

- [x] 3. Implement Context Capture System

  - Create ContextCapturer class for window title extraction
  - Implement Accessibility API integration
  - Add browser-specific context capture
  - Integrate context capture with activity tracking
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 3.1 Implement Accessibility API integration

  - Create ContextCapturer class with AXUIElement methods
  - Implement window title capture using kAXTitleAttribute
  - Add accessibility permission checking and request flow
  - Create fallback behavior when accessibility is disabled
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 3.2 Add browser-specific context capture

  - Implement Safari URL and title extraction
  - Add Chrome and Firefox context capture support
  - Create browser context data model and storage
  - Add privacy controls for browser data capture
  - _Requirements: 5.4, 5.5_

- [x] 3.3 Integrate context capture with activity tracking

  - Modify ActivityTracker to use ContextCapturer
  - Update activity creation to include window titles and URLs
  - Add context data validation and sanitization
  - Implement privacy filtering for sensitive information
  - _Requirements: 5.1, 5.2, 5.5_

- [ ]\* 3.4 Create context capture tests
  - Write unit tests for ContextCapturer methods
  - Mock Accessibility API responses for testing
  - Test browser context extraction with sample data
  - Add privacy and security tests for data sanitization
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

## Phase 4: Idle Detection System

- [x] 4. Implement Idle Detection and Management

  - Create IdleDetector class with system event monitoring
  - Implement idle time threshold configuration
  - Add idle recovery dialog and user interaction
  - Integrate idle detection with activity tracking
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 4.1 Create IdleDetector with system event monitoring

  - Implement CGEventTap for mouse and keyboard monitoring
  - Add idle timer with configurable threshold (default 5 minutes)
  - Create idle state management and tracking
  - Implement proper cleanup and resource management
  - _Requirements: 4.1, 4.3_

- [x] 4.2 Implement idle recovery user interface

  - Create idle recovery dialog with activity options
  - Add "What were you doing?" prompt with common activities
  - Implement idle time handling options (ignore, assign to project, etc.)
  - Create user preferences for idle detection behavior
  - _Requirements: 4.2, 4.4_

- [x] 4.3 Integrate idle detection with activity tracking

  - Modify ActivityTracker to pause during idle periods
  - Implement activity duration adjustment for idle time
  - Add idle time markers in activity records
  - Create idle time reporting and statistics
  - _Requirements: 4.1, 4.3, 4.4_

- [ ]\* 4.4 Create idle detection tests
  - Write unit tests for IdleDetector functionality
  - Mock system events for idle detection testing
  - Test idle recovery dialog and user interactions
  - Add integration tests for idle time handling in activities
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

## Phase 5: Interactive Timeline Implementation

- [x] 5. Implement Interactive Timeline Visualization

  - Replace mock data in TimelineView with real data binding
  - Implement three-row timeline layout with proper scaling
  - Add timeline interaction features (hover, click, drag)
  - Create timeline zoom and navigation controls
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 5.1 Create TimelineViewModel for data management

  - Implement TimelineViewModel as ObservableObject
  - Add real-time data binding to activities, projects, and time entries
  - Create timeline data filtering and date range management
  - Implement efficient data loading and caching for timeline
  - _Requirements: 3.1, 3.2_

- [x] 5.2 Implement three-row timeline layout

  - Create device activity row with app icons and duration blocks
  - Implement project row with color-coded project blocks
  - Add time entry row with manual entry blocks and add buttons
  - Ensure proper alignment and scaling across all rows
  - _Requirements: 3.1, 3.2_

- [x] 5.3 Add timeline interaction and hover effects

  - Implement hover tooltips with detailed activity information
  - Add click handlers for timeline block selection
  - Create context menus for timeline elements
  - Implement keyboard navigation for timeline
  - _Requirements: 3.3, 10.2_

- [x] 5.4 Implement timeline zoom and scaling

  - Add zoom controls with Cmd+scroll wheel support
  - Implement dynamic time scale adjustment (hours, days, weeks)
  - Create smooth zoom animations and transitions
  - Add zoom level indicators and reset functionality
  - _Requirements: 3.4_

- [x] 5.5 Create timeline editing capabilities

  - Implement drag-and-drop from timeline to project sidebar
  - Add timeline block resizing for duration editing
  - Create new time entry creation from empty timeline areas
  - Implement batch selection and operations for timeline items
  - _Requirements: 3.5, 10.1, 10.3, 10.4, 10.5_

- [ ]\* 5.6 Create timeline component tests
  - Write unit tests for TimelineViewModel data management
  - Test timeline rendering with various data scenarios
  - Create interaction tests for hover, click, and drag operations
  - Add performance tests for timeline rendering with large datasets
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

## Phase 6: Rule Engine Implementation

- [x] 6. Implement Automatic Rule Engine System

  - Create RuleEngine class for automatic project assignment
  - Implement rule creation and management UI
  - Add rule evaluation and application logic
  - Create retroactive rule application functionality
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 6.1 Create Rule data model and storage

  - Implement Rule SwiftData model with conditions and actions
  - Create RuleCondition and RuleAction enums with associated values
  - Add rule serialization and deserialization logic
  - Implement rule validation and error handling
  - _Requirements: 6.1, 6.3_

- [x] 6.2 Implement RuleEngine evaluation logic

  - Create rule matching algorithm with priority handling
  - Implement condition evaluation for app names, window titles, time patterns
  - Add rule conflict resolution and most-specific-rule selection
  - Create rule application tracking and statistics
  - _Requirements: 6.2, 6.3_

- [x] 6.3 Create rule management user interface

  - Design and implement rule creation dialog
  - Add rule editing and deletion functionality
  - Create rule list view with enable/disable toggles
  - Implement rule testing and preview functionality
  - _Requirements: 6.1, 6.4_

- [x] 6.4 Implement retroactive rule application

  - Create batch rule application for existing activities
  - Add progress tracking for large-scale rule application
  - Implement rule application confirmation and undo functionality
  - Create rule impact analysis and reporting
  - _Requirements: 6.4_

- [ ]\* 6.5 Create rule engine tests
  - Write unit tests for rule evaluation logic
  - Test rule condition matching with various scenarios
  - Create integration tests for rule application workflow
  - Add performance tests for rule evaluation with large datasets
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

## Phase 7: Search and Filtering System

- [x] 7. Implement Advanced Search and Filtering

  - Create SearchManager for activity and time entry search
  - Implement real-time filtering for timeline and activity views
  - Add saved search and filter combinations
  - Create advanced search with multiple criteria
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 7.1 Create SearchManager and search infrastructure

  - Implement SearchManager class with full-text search capabilities
  - Add search indexing for activities, time entries, and projects
  - Create search query parsing and validation
  - Implement search result ranking and relevance scoring
  - _Requirements: 11.1, 11.3_

- [x] 7.2 Implement real-time filtering UI

  - Add search bar to main interface with live results
  - Create filter panels for date ranges, projects, and applications
  - Implement filter combination and boolean logic
  - Add filter state persistence and restoration
  - _Requirements: 11.2, 11.4_

- [x] 7.3 Create advanced search features

  - Implement search suggestions and autocomplete
  - Add search history and recent searches
  - Create search result highlighting and context
  - Implement search performance optimization and caching
  - _Requirements: 11.1, 11.3, 11.5_

- [ ]\* 7.4 Create search system tests
  - Write unit tests for search query parsing and execution
  - Test search performance with large datasets
  - Create integration tests for search UI and filtering
  - Add search accuracy and relevance tests
  - _Requirements: 11.1, 11.2, 11.3, 11.4_

## Phase 8: Notification and Alert System

- [x] 8. Implement Notification and Alert System

  - Create NotificationManager for system notifications
  - Implement timer completion and tracking alerts
  - Add productivity goal notifications
  - Create notification preferences and customization
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [x] 8.1 Create NotificationManager infrastructure

  - Implement NotificationManager with UNUserNotificationCenter
  - Add notification permission request and handling
  - Create notification templates and customization
  - Implement notification scheduling and delivery
  - _Requirements: 12.1, 12.2, 12.5_

- [x] 8.2 Implement timer and tracking notifications

  - Add timer completion notifications with custom sounds
  - Create tracking status alerts for system issues
  - Implement daily/weekly productivity summary notifications
  - Add gentle reminder notifications for inactive periods
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [x] 8.3 Create notification preferences UI

  - Design notification settings panel with granular controls
  - Add notification scheduling and quiet hours
  - Implement notification sound and style customization
  - Create notification history and management
  - _Requirements: 12.5_

- [ ]\* 8.4 Create notification system tests
  - Write unit tests for notification scheduling and delivery
  - Test notification permission handling and fallbacks
  - Create integration tests for notification UI and preferences
  - Add notification timing and accuracy tests
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

## Phase 9: Data Processing and Statistics

- [ ] 9. Implement Advanced Data Processing

  - Enhance ActivityDataProcessor with statistical analysis
  - Implement productivity scoring and insights
  - Add data aggregation and reporting features
  - Create data export and backup functionality
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 9.1 Enhance ActivityDataProcessor with statistics

  - Add statistical analysis methods for time usage patterns
  - Implement productivity scoring algorithms
  - Create trend analysis and pattern recognition
  - Add data aggregation by various time periods and categories
  - _Requirements: 7.1, 7.2, 7.3_

- [x] 9.2 Implement data conflict resolution

  - Create algorithms for handling overlapping time entries
  - Add data validation and integrity checking
  - Implement automatic conflict resolution with user override
  - Create data repair and cleanup utilities
  - _Requirements: 7.2, 9.2_

- [ ] 9.3 Create reporting and export features

  - Implement data export in multiple formats (CSV, JSON, PDF)
  - Add customizable report generation
  - Create data backup and restore functionality
  - Implement data archival for performance optimization
  - _Requirements: 7.4, 7.5_

- [ ]\* 9.4 Create data processing tests
  - Write unit tests for statistical analysis algorithms
  - Test data conflict resolution and repair functionality
  - Create performance tests for large dataset processing
  - Add data integrity and validation tests
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

## Phase 10: Performance Optimization and Polish

- [x] 10. Implement Performance Optimizations

  - Optimize database queries and indexing
  - Implement efficient memory management
  - Add background processing and threading
  - Create performance monitoring and metrics
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 10.1 Optimize database performance

  - Add database indexes for frequently queried fields
  - Implement query optimization and batch operations
  - Create data pagination for large datasets
  - Add database maintenance and cleanup routines
  - _Requirements: 8.1, 8.2_

- [x] 10.2 Implement memory and resource management

  - Add memory usage monitoring and optimization
  - Implement efficient caching strategies
  - Create background processing for heavy operations
  - Add resource cleanup and leak prevention
  - _Requirements: 8.2, 8.3, 8.4_

- [x] 10.3 Create performance monitoring

  - Implement performance metrics collection
  - Add resource usage tracking and alerts
  - Create performance dashboard for debugging
  - Implement automated performance testing
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ]\* 10.4 Create comprehensive performance tests
  - Write performance benchmarks for all major components
  - Test memory usage under various load conditions
  - Create stress tests for concurrent operations
  - Add performance regression testing
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

## Phase 11: Error Handling and Data Integrity

- [x] 11. Implement Robust Error Handling

  - Create comprehensive error handling system
  - Implement data recovery and repair mechanisms
  - Add graceful degradation for system failures
  - Create error reporting and logging system
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 11.1 Create error handling infrastructure

  - Implement comprehensive error types and handling
  - Add error recovery strategies with exponential backoff
  - Create user-friendly error messages and recovery suggestions
  - Implement error logging and crash reporting
  - _Requirements: 9.1, 9.2, 9.3_

- [x] 11.2 Implement data recovery mechanisms

  - Create automatic data repair for corruption
  - Add crash recovery for incomplete operations
  - Implement data backup and restore functionality
  - Create data validation and integrity checking
  - _Requirements: 9.2, 9.3, 9.4_

- [x] 11.3 Add graceful degradation features

  - Implement fallback modes for system failures
  - Create reduced functionality modes for resource constraints
  - Add offline capability and sync when available
  - Implement progressive enhancement for optional features
  - _Requirements: 9.1, 9.5_

- [ ]\* 11.4 Create error handling tests
  - Write unit tests for error scenarios and recovery
  - Test data corruption detection and repair
  - Create integration tests for system failure scenarios
  - Add stress tests for error handling under load
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_
