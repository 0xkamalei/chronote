# Requirements Document

## Introduction

This feature implements the ActivitiesView component to use MockData instead of hardcoded activities data. The view will display activities with proper grouping, sorting, and hierarchical display logic as specified in the project documentation. The implementation will support multi-level collapsible lists showing project -> subproject -> title -> time period -> app details.

## Requirements

### Requirement 1

**User Story:** As a user, I want to see my activities loaded from MockData, so that the ActivitiesView displays real data instead of placeholder content.

#### Acceptance Criteria

1. WHEN the ActivitiesView loads THEN the system SHALL display activities using data from MockData.activities
2. WHEN MockData contains activities THEN the system SHALL show the correct total duration in the header
3. WHEN activities are displayed THEN the system SHALL show app names, icons, and duration for each activity
4. WHEN no activities exist in MockData THEN the system SHALL display an appropriate empty state

### Requirement 2

**User Story:** As a user, I want to sort my activities by different criteria, so that I can view my time data organized in the most useful way for my needs.

#### Acceptance Criteria

1. WHEN the sort mode is set to "Unfiled" THEN the system SHALL group activities by project and include both time entries and app usage data ranges following the fixed configuration layout as shown in the reference image
2. WHEN the sort mode is set to "By Category" THEN the system SHALL group activities by application type or category
3. WHEN the sort mode is set to "Chronological" THEN the system SHALL display activities ordered by time sequence
4. WHEN the user changes sort mode THEN the system SHALL immediately update the activity display to reflect the new sorting
5. WHEN implementing the MVP THEN the system SHALL use fixed selection logic for the Unfiled group display

### Requirement 3

**User Story:** As a user, I want to see browser activities with expandable website lists, so that I can view detailed browsing history in a hierarchical format.

#### Acceptance Criteria

1. WHEN an activity is from a browser application THEN the system SHALL display it as an expandable group
2. WHEN a browser group is expanded THEN the system SHALL show individual websites visited
3. WHEN a browser group is collapsed THEN the system SHALL show only the browser name and total duration
4. WHEN website entries are displayed THEN the system SHALL show website URLs and individual durations
5. WHEN the user clicks on a browser group THEN the system SHALL toggle the expanded/collapsed state

### Requirement 4

**User Story:** As a user, I want to see unassigned activities clearly marked, so that I can identify time that hasn't been allocated to projects.

#### Acceptance Criteria

1. WHEN activities are not assigned to projects THEN the system SHALL display an "(Unassigned)" section
2. WHEN the unassigned section is shown THEN the system SHALL display the total unassigned time
3. WHEN unassigned activities exist THEN the system SHALL use a neutral icon to indicate unassigned status
4. WHEN no unassigned activities exist THEN the system SHALL not display the unassigned section