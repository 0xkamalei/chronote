# Implementation Plan

- [x] 1. Enhance Project Model with basic hierarchy support
  - Implement computed properties for hierarchy depth and descendants
  - Add validation methods for parent-child relationships
  - Create helper methods for tree traversal and manipulation
  - Add proper Hashable and Identifiable conformance
  - _Requirements: 1.6, 2.5, 4.4_

- [ ] 2. Create comprehensive ProjectManager service
  - [x] 2.1 Implement core CRUD operations with async/await
    - Write createProject method with validation and unique ID generation
    - Implement updateProject method with hierarchy validation
    - Create deleteProject method with complex deletion strategies
    - Add getProject lookup method with error handling
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 3.1_

  - [x] 2.2 Implement hierarchy management operations
    - Write buildProjectTree method for tree structure creation
    - Create moveProject method for parent changes
    - Implement reorderProject method for sort order updates
    - Add validateHierarchyMove method for circular reference prevention
    - _Requirements: 2.3, 2.6, 4.1, 4.5, 5.3, 5.4_

  - [x] 2.3 Add project reordering support methods
    - Implement manual project reordering within same parent
    - Create sort order management for project siblings
    - Add validation for reorder operations
    - Write helper methods for sort order updates
    - _Requirements: 5.4, 5.5_

  - [x] 2.4 Implement deletion logic with time entry handling
    - Create canDeleteProject method checking for active timers and time entries
    - Implement handleActiveTimerForProject method to stop active timers
    - Write reassignTimeEntries method for time entry migration
    - Add deletion confirmation dialog data preparation
    - _Requirements: 3.2, 3.3, 3.4, 3.5_

  - [x] 2.5 Add persistence and auto-save functionality
    - Implement saveProjects method with error handling
    - Create loadProjects method with data validation
    - Add autoSave background functionality
    - Write data migration logic for existing projects
    - _Requirements: 6.6_

- [ ] 3. Enhance EditProjectView for both create and edit modes
  - [ ] 3.1 Implement mode-based form initialization
    - Add Mode enum with create and edit cases
    - Create form data initialization logic for both modes
    - Implement proper navigation title based on mode
    - Add form validation state management
    - _Requirements: 1.1, 2.1_

  - [ ] 3.2 Add comprehensive form validation
    - Implement real-time name validation with error display
    - Create parent selection validation preventing circular references
    - Add color picker with accessibility support
    - Write form submission validation logic
    - _Requirements: 1.2, 1.5, 2.2, 2.5_

  - [ ] 3.3 Implement delete functionality in edit mode
    - Add ProjectDangerZoneSection for delete operations
    - Create ProjectDeleteConfirmationDialog component
    - Implement deletion strategy selection (children handling)
    - Add time entry reassignment options
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ] 3.4 Add async form submission with loading states
    - Implement AsyncButton for save operations
    - Add loading indicators during form submission
    - Create error handling with user-friendly messages
    - Write success feedback and form dismissal logic
    - _Requirements: 1.3, 2.4, 6.2_

- [ ] 4. Enhance ProjectRowView with basic functionality
  - [ ] 4.1 Integrate ProjectRightClickMenu
    - Add contextMenu modifier with ProjectRightClickMenu
    - Implement edit, create child, and delete actions
    - Create proper sheet presentation for edit/create forms
    - Add confirmation dialogs for destructive actions
    - _Requirements: 2.1, 3.1_

  - [ ] 4.2 Enhance visual hierarchy display
    - Improve expand/collapse indicators with SF Symbols
    - Add proper indentation for hierarchy levels
    - Implement color indicators and project status display
    - Create smooth animations for expand/collapse operations
    - _Requirements: 4.2, 4.3, 4.4, 4.6_

- [ ] 5. Enhance SidebarView with project management integration
  - [ ] 5.1 Add "Create Project" button to My Projects section
    - Modify My Projects header to include plus button
    - Implement sheet presentation for create project form
    - Add proper button styling and accessibility labels
    - Create visual feedback for button interactions
    - _Requirements: 1.1_

  - [ ] 5.2 Integrate ProjectManager with existing project display
    - Replace direct projects array access with ProjectManager
    - Update project tree building to use ProjectManager methods
    - Implement real-time updates when projects change
    - Add error handling for project loading failures
    - _Requirements: 4.1, 6.1, 6.2_

  - [ ] 5.3 Update project selection handling
    - Modify selectProject method to validate project existence
    - Add graceful handling of deleted project selections
    - Implement selection persistence across project operations
    - Create selection update notifications for other views
    - _Requirements: 6.4, 6.5_

- [ ] 6. Enhance ProjectPickerItem with modern SwiftUI patterns
  - [ ] 6.1 Improve visual hierarchy representation
    - Replace text-based indentation with proper SwiftUI layout
    - Add SF Symbols for better visual hierarchy indicators
    - Implement proper color coding and status indicators
    - Create accessibility improvements with proper labels
    - _Requirements: 4.4_

  - [ ] 6.2 Add Dynamic Type and accessibility support
    - Implement proper font scaling for Dynamic Type
    - Add VoiceOver support with descriptive labels
    - Create keyboard navigation support
    - Write accessibility hints for hierarchy relationships
    - _Requirements: 4.4_

- [ ] 7. Integrate ProjectManager with AppState
  - [ ] 7.1 Update AppState to use ProjectManager
    - Replace direct project management with ProjectManager delegation
    - Modify selection methods to validate project existence
    - Add project change notification handling
    - Create graceful degradation for project operation failures
    - _Requirements: 6.1, 6.4, 6.5_

  - [ ] 7.2 Implement real-time UI updates
    - Add NotificationCenter integration for project changes
    - Create automatic UI refresh when projects are modified
    - Implement efficient update propagation to all views
    - Add debouncing for rapid project changes
    - _Requirements: 6.2, 6.3_

- [ ] 8. Add comprehensive error handling and validation
  - [ ] 8.1 Create ProjectError enum with localized descriptions
    - Define all possible project operation errors
    - Add localized error messages for user display
    - Create error recovery suggestions
    - Implement error logging for debugging
    - _Requirements: 1.5, 2.5, 3.4, 5.6_

  - [ ] 8.2 Implement validation throughout the system
    - Add input validation for all project operations
    - Create hierarchy validation preventing circular references
    - Implement business rule validation (max depth, naming, etc.)
    - Write comprehensive validation tests
    - _Requirements: 1.2, 2.2, 2.5, 5.6_

- [ ] 9. Add persistence and data integrity
  - [ ] 9.1 Implement robust data persistence
    - Create save/load operations with error handling
    - Add data validation during load operations
    - Implement backup and recovery mechanisms
    - Write data migration logic for schema changes
    - _Requirements: 6.6_

  - [ ] 9.2 Add auto-save and background persistence
    - Implement automatic saving after project operations
    - Create background save operations without UI blocking
    - Add conflict resolution for concurrent modifications
    - Write persistence performance optimization
    - _Requirements: 6.6_

- [ ] 10. Create comprehensive test suite
  - [ ] 10.1 Write unit tests for ProjectManager
    - Test all CRUD operations with various scenarios
    - Create hierarchy manipulation test cases
    - Add validation logic testing
    - Write error handling test coverage
    - _Requirements: All requirements validation_

  - [ ] 10.2 Add integration tests for UI components
    - Test drag-and-drop functionality end-to-end
    - Create form submission and validation tests
    - Add real-time update testing
    - Write accessibility testing for all components
    - _Requirements: All requirements validation_

- [ ] 11. Implement drag-and-drop functionality
  - [ ] 11.1 Add Transferable support to Project Model
    - Add Transferable conformance for drag-and-drop functionality
    - Create custom UTType for project drag-and-drop operations
    - Implement proper data encoding/decoding for transfers
    - Add drag preview customization
    - _Requirements: 5.1_

  - [ ] 11.2 Enhance ProjectRowView with drag functionality
    - Add draggable modifier with Project transferable
    - Create ProjectDragPreview component for drag visual
    - Implement drag state management and visual feedback
    - Add accessibility support for drag operations
    - _Requirements: 5.1, 5.7_

  - [ ] 11.3 Add drop destination handling to ProjectRowView
    - Implement dropDestination modifier for receiving drops
    - Create drop position detection (inside, above, below)
    - Add drop target highlighting with visual feedback
    - Write drop validation and execution logic
    - _Requirements: 5.2, 5.3, 5.4, 5.6_

  - [ ] 11.4 Create ProjectDragDropHandler for complex drag logic
    - Write getDropPosition method for precise drop location detection
    - Create visual feedback for different drop zones
    - Add boundary detection for valid drop areas
    - Implement drop position preview indicators
    - _Requirements: 5.2, 5.3, 5.4_

  - [ ] 11.5 Add drag-and-drop support methods to ProjectManager
    - Implement handleDrop method for modern SwiftUI drag-and-drop
    - Create canAcceptDrop validation method
    - Add drag validation and execution with error handling
    - Write drag operation logging and undo functionality
    - _Requirements: 5.1, 5.2, 5.6, 5.7_

- [ ] 12. Performance optimization and polish
  - [ ] 12.1 Optimize drag-and-drop performance
    - Implement efficient drag gesture handling
    - Add smooth animations for drag operations
    - Create optimized tree traversal algorithms
    - Write memory management for drag state
    - _Requirements: 5.1, 5.7_

  - [ ] 12.2 Add final polish and user experience improvements
    - Implement smooth animations for all project operations
    - Add haptic feedback for drag-and-drop operations
    - Create loading states for async operations
    - Write comprehensive accessibility testing and improvements
    - _Requirements: All requirements enhancement_