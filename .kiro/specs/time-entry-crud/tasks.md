# Implementation Plan

- [x] 1. Create TimeEntry SwiftData model and core data structures

  - Convert existing TimeEntry struct to SwiftData @Model class with proper attributes and relationships
  - Add validation methods and computed properties for duration calculations
  - Implement proper initialization and data integrity constraints
  - _Requirements: 1.6, 1.7, 6.1, 6.2_

- [x] 2. Implement TimeEntryManager business logic layer

  - [x] 2.1 Create TimeEntryManager singleton class with ObservableObject conformance

    - Set up singleton pattern following ProjectManager architecture
    - Add @Published properties for reactive UI updates
    - Implement ModelContext integration and initialization
    - _Requirements: 1.1, 2.1, 6.1_

  - [x] 2.2 Implement core CRUD operations

    - Write createTimeEntry method with comprehensive validation
    - Implement updateTimeEntry with conflict resolution
    - Add deleteTimeEntry with proper cleanup and notifications
    - Create getTimeEntries query methods with filtering support
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 3.1, 3.2, 4.1, 4.2_

  - [x] 2.3 Add validation and error handling systems

    - Implement comprehensive validation methods for time entries
    - Create TimeEntryError enum with localized error messages
    - Add retry logic and graceful error recovery mechanisms
    - _Requirements: 1.8, 3.7, 4.6, 6.4_

  - [ ]\* 2.4 Write unit tests for TimeEntryManager
    - Create comprehensive test suite for CRUD operations
    - Test validation logic and error handling scenarios
    - Verify integration with SwiftData persistence layer
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 6.4_

- [x] 3. Enhance existing UI components for time entry creation

  - [x] 3.1 Update NewTimeEntryView with actual save functionality

    - Integrate TimeEntryManager for saving time entries
    - Add proper validation and error display
    - Implement duration calculation and time picker enhancements
    - _Requirements: 1.1, 1.2, 1.5, 1.6, 1.7, 1.8_

  - [x] 3.2 Create EditTimeEntryView for updating existing entries

    - Build edit form similar to NewTimeEntryView structure
    - Pre-populate form fields with existing TimeEntry data
    - Implement update operations through TimeEntryManager
    - Add project reassignment and validation
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ]\* 3.3 Write UI tests for time entry forms
    - Test form validation and user interaction flows
    - Verify proper error handling and user feedback
    - Test project selection and time picker functionality
    - _Requirements: 1.8, 3.7_

- [x] 4. Create time entry list and management views

  - [x] 4.1 Build TimeEntryListView for displaying time entries

    - Create list view with chronological sorting
    - Implement filtering by project and date range
    - Add edit and delete actions for each entry
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 4.2 Add time entry management to main navigation
    - Integrate TimeEntryListView into existing app navigation
    - Update ContentView to include time entry management
    - Add toolbar buttons for creating new time entries
    - _Requirements: 2.1, 5.1, 5.2, 5.3, 5.4_

- [x] 5. Implement project integration and relationship management

  - [x] 5.1 Add project deletion handling for time entries

    - Implement reassignment logic when projects are deleted
    - Update ProjectManager to handle time entry dependencies
    - Add confirmation dialogs for project deletion with time entries
    - _Requirements: 5.2, 5.3, 4.1, 4.2, 4.3, 4.4_

  - [x] 5.2 Create timer integration for automatic time entry creation
    - Modify ActivityManager to create time entries when timers stop
    - Add configuration options for automatic time entry creation
    - Implement proper project association from active timer state
    - _Requirements: 5.5, 5.6_

- [x] 6. Add database optimizations and performance enhancements

  - [x] 6.1 Update DatabaseConfiguration for TimeEntry indexing

    - Add database indexes for TimeEntry queries (projectId, startTime, date ranges)
    - Implement performance optimization for time entry operations
    - Add database maintenance routines for time entry cleanup
    - _Requirements: 6.2, 6.3, 6.6_

  - [x] 6.2 Implement batch operations and query optimization
    - Add batch save/update operations for multiple time entries
    - Optimize query performance for large datasets
    - Implement pagination for time entry lists
    - _Requirements: 6.6, 2.6, 2.7_

- [x] 7. Integrate time entries with activity grouping system

  - [x] 7.1 Update ActivityHierarchyGroup to include time entries

    - Modify existing activity grouping logic to incorporate time entries
    - Ensure time entries appear in activity views when "Include time entries" is enabled
    - Update ProjectTimeEntryGroup to handle time entry relationships
    - _Requirements: 5.1, 5.4, 5.6_

  - [x] 7.2 Update ActivitiesView to display time entries
    - Modify existing ActivitiesView to show time entries alongside activities
    - Implement proper grouping and sorting with time entries included
    - Add visual distinction between automatic activities and manual time entries
    - _Requirements: 5.1, 5.4, 5.6_

- [x] 8. Add notification system and reactive updates

  - [x] 8.1 Implement NotificationCenter integration

    - Add time entry change notifications following existing patterns
    - Update AppState to handle time entry selection and filtering
    - Ensure UI components react to time entry changes
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 4.4_

  - [x] 8.2 Add real-time UI updates and state management
    - Implement @Published property updates for reactive UI
    - Add debounced updates to prevent excessive notifications
    - Ensure consistent state across all time entry views
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
