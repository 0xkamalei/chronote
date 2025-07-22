# Implementation Plan - MVP Version

**Important Notes**: 
- If similar components already exist in the codebase, create new components with distinct names rather than modifying existing ones.
- Ensure each task maintains compilation and doesn't break existing functionality - all changes should be additive and non-breaking.

## Phase 1: MVP Core Functionality

- [x] 1. Create basic data models for MVP
  - Create simplified ActivityGroup model for basic grouping
  - Use fixed configuration (no Configuration model needed)
  - _Design: 2.2_
  - _Requirements: Requirement 4.1, Requirement 5.1_

- [x] 2. Enhance MockData with comprehensive test data for hierarchy testing
  - Expand MockData.activities to include more diverse app types and titles covering all hierarchy levels
  - Add time entries that overlap with activity time ranges for project assignment testing
  - Include activities with nested app titles (websites with domains/paths, files with directory structures)
  - Add edge cases like unassigned activities, overlapping time periods, and activities without titles
  - Ensure data covers all 6 hierarchy levels (Project → Subproject → Time Entry → Time Period → App Name → App Title)
  - _Design: 2.1, 2.4_
  - _Requirements: Requirement 4.1, Requirement 4.2, Requirement 4.3, Requirement 4.4, Requirement 4.5, Requirement 4.6_

- [x] 3. Implement project assignment logic in ActivityDataProcessor
  - Extend existing ActivityDataProcessor to implement project assignment through time matching
  - Add method to match activities to time entries based on temporal overlap
  - Implement logic to assign activities to projects based on their associated time entries
  - Add duration calculation and overlap detection to prevent double-counting
  - Create method to separate assigned vs unassigned activities
  - _Design: 4.2, 2.1_
  - _Requirements: Requirement 2.1, Requirement 5.1, Requirement 5.2, Requirement 5.3_

- [x] 4. Create ActivityHierarchyBuilder class
  - Create new ActivityHierarchyBuilder class that takes processed data from ActivityDataProcessor
  - Implement buildHierarchy method that creates 6-level structure (Project → Subproject → Time Entry → Time Period → App Name → App Title)
  - Handle grouping and aggregation for all 6 levels with proper parent-child relationships
  - Implement time period segmentation logic for breaking activities into meaningful time segments
  - Add logic for grouping activities with the same app title under single entries
  - Output: ActivityGroup[] tree structure ready for UI rendering
  - _Design: 4.3, 2.4_
  - _Requirements: Requirement 2.1, Requirement 4.1, Requirement 4.2, Requirement 4.3, Requirement 4.4, Requirement 4.5, Requirement 4.6, Requirement 4.8_
  
- [x] 5. Create HierarchicalActivityRow SwiftUI component
  - Create new HierarchicalActivityRow SwiftUI view for recursive rendering of hierarchy rows
  - Implement expansion/collapse functionality with @State management for expanded groups
  - Add visual hierarchy styling with appropriate indentation and icons for each level
  - Handle display of aggregated data (duration totals, activity counts) for each row
  - Support rendering of all 6 hierarchy levels with level-appropriate styling
  - Add tap gesture handling for expand/collapse interactions
  - _Design: 4.4, 3_
  - _Requirements: Requirement 4.1, Requirement 4.2, Requirement 4.3, Requirement 4.4, Requirement 4.5, Requirement 4.6_

- [ ] 6. Refactor ActivitiesView to use hierarchical components
  - Replace current ActivitiesView implementation with new hierarchical approach
  - Integrate ActivityDataProcessor and ActivityHierarchyBuilder for data processing
  - Add header showing total activity time across all visible activities (replace hardcoded "24m 56s")
  - Replace current activity list with HierarchicalActivityRow components
  - Remove hardcoded browser-specific logic and use generic hierarchy rendering
  - Implement fixed project grouping display mode as specified in requirements
  - _Design: 4.1, 5.1_
  - _Requirements: Requirement 1.1, Requirement 1.6, Requirement 2.1, Requirement 5.1_

- [ ] 7. Add comprehensive interaction and empty states
  - Implement proper expand/collapse functionality for all hierarchy levels
  - Add empty state handling with "0m 0s" display when no activities match filters
  - Ensure consistent visual styling across all hierarchy levels and interaction states
  - Add loading states and error handling for data processing
  - Implement proper state management for expanded groups across view updates
  - _Design: 6.1, 6.3, 4.1_
  - _Requirements: Requirement 1.5, Requirement 4.2, Requirement 5.4_

## Phase 2: Enhanced Features (Future)

- [ ] 8. Extend to n-level domain/directory hierarchy
  - Add n-level nested structure for websites (Domain → Path segments → Final URL/Title)
  - Add n-level nested structure for files (Directory hierarchy → Subdirectories → Final file/document)
  - Create HierarchicalActivityRow for recursive rendering of variable depth
  - _Requirements: 4.7, 4.8_

- [ ] 9. Add data inclusion controls
  - Implement three inclusion toggles (time entries, app usage, titles)
  - Add immediate display updates when toggles change
  - Implement proper data merging and deduplication
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 10. Add advanced features and optimization
  - Implement performance optimization for large datasets
  - Add robust error handling and edge cases
  - Enhance visual styling and user experience
  - _Requirements: 5.3, 5.4_