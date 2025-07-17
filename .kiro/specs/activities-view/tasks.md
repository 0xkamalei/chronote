# Implementation Plan - MVP Version

**Important Notes**: 
- If similar components already exist in the codebase, create new components with distinct names rather than modifying existing ones.
- Ensure each task maintains compilation and doesn't break existing functionality - all changes should be additive and non-breaking.

## Phase 1: MVP Core Functionality

- [-] 1. Create basic data models for MVP
  - Create simplified ActivityGroup model for basic grouping
  - Use fixed configuration (no Configuration model needed)
  - _Requirements: 4.1, 5.1_

- [ ] 2. Build test data for hierarchy testing
  - Create comprehensive test data in MockData with projects, time entries, and activities
  - Ensure data covers all 6 hierarchy levels (Project → Subproject → Time Entry → Time Period → App Name → App Title)
  - Include edge cases like unassigned activities and overlapping time periods
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [ ] 3. Implement basic ActivityDataProcessor
  - Create data processor that reads MockData.activities and MockData.timeEntries with fixed settings
  - Implement project assignment logic through time matching (assigned vs unassigned)
  - Add duration calculation and overlap detection to prevent double-counting
  - Output: processed flat data with project assignments and calculated durations
  - _Requirements: 2.1, 5.1, 5.2, 5.3_

- [ ] 4. Implement basic ActivityHierarchyBuilder
  - Create hierarchy builder that takes processed data from ActivityDataProcessor
  - Build 6-level structure (Project → Subproject → Time Entry → Time Period → App Name → App Title)
  - Handle grouping and aggregation for all 6 levels with parent-child relationships
  - Output: ActivityGroup[] tree structure for UI rendering
  - _Requirements: 2.1, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  
- [ ] 5. Create HierarchicalActivityRow component
  - Implement recursive SwiftUI component for rendering individual hierarchy rows
  - Add expansion/collapse functionality and visual hierarchy styling
  - Handle display of aggregated data (duration totals, activity counts)
  - Support all 6 hierarchy levels (Project → Subproject → Time Entry → Time Period → App Name → App Title)
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [ ] 6. Create main ActivitiesView container
  - Implement main SwiftUI view that coordinates with ActivityDataProcessor
  - Add header showing total activity time across all visible activities
  - Integrate HierarchicalActivityRow for displaying the hierarchy
  - Handle fixed project grouping display mode
  - _Requirements: 1.1, 1.6, 2.1, 5.1_

- [ ] 7. Add basic interaction and empty states
  - Implement expand/collapse functionality for project groups
  - Add empty state handling with "0m 0s" display
  - Ensure basic visual styling and consistent interactions
  - _Requirements: 1.5, 4.2, 5.4_

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