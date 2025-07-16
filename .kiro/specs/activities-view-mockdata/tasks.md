# Implementation Plan

- [ ] 1. Create ActivityDataProcessor utility class
  - Implement ActivityDataProcessor class with methods for processing and grouping activities
  - Add browser detection logic to identify browser applications (Chrome, Safari, Edge, etc.)
  - Create duration calculation functions for activity groups and totals
  - Implement fixed configuration logic for MVP phase Unfiled mode
  - _Requirements: 1.1, 1.2, 2.1_

- [ ] 2. Implement sort mode logic
  - Add sorting functions for Unfiled mode (group by project, include time entries and app usage data ranges)
  - Implement Category mode sorting (group activities by application type/category)
  - Create Chronological mode sorting (display activities ordered by time sequence)
  - Implement activity filtering logic for unassigned activities
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 3. Update ActivitiesView to use MockData
  - Replace hardcoded activities with MockData.activities
  - Integrate ActivityDataProcessor for data processing
  - Update total duration calculation to use real data from processed activities
  - Remove hardcoded duration display and calculate dynamically from MockData
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 4. Implement dynamic browser activity grouping
  - Replace hardcoded Chrome browser logic with dynamic browser detection
  - Use ActivityDataProcessor to group all browser activities by application
  - Implement website extraction from appTitle for browser activities
  - Add expansion/collapse state management for all browser groups
  - Create hierarchical display with proper indentation for websites
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 5. Connect sort mode functionality to UI
  - Connect sort mode picker to ActivityDataProcessor sorting logic
  - Implement real-time activity display updates when sort mode changes
  - Handle project grouping display for Unfiled mode with fixed configuration
  - Handle category grouping display for "By Category" mode
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 6. Implement unassigned activities section
  - Use ActivityDataProcessor to identify activities without project association
  - Calculate and display total unassigned time from processed data
  - Display unassigned activities count and duration in UI
  - Handle empty unassigned state appropriately
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 7. Add empty state handling
  - Implement empty state display when MockData.activities is empty
  - Add appropriate messaging for empty activity lists
  - Handle edge cases with zero-duration activities gracefully
  - Ensure proper error handling for missing or invalid activity data
  - _Requirements: 1.4_

- [ ] 8. Finalize visual consistency and integration
  - Ensure consistent styling across all activity types and groups
  - Verify proper hierarchical indentation for browser website displays
  - Apply consistent duration formatting throughout the view
  - Validate complete integration of MockData with all sort modes and grouping
  - _Requirements: 1.3, 3.4, 4.2_