# Requirements Document

## Introduction

This feature implements a comprehensive ActivitiesView component that displays user activities with advanced grouping, filtering, and hierarchical display capabilities. The view supports multiple display modes including unified view, category grouping, and chronological sorting, with configurable options for data inclusion and grouping strategies.

## Requirements

### Requirement 1

**User Story:** As a user, I want to view my activities in different display modes, so that I can organize and analyze my time usage according to different perspectives.

#### Acceptance Criteria

1. WHEN the user selects "Unified" mode THEN the system SHALL display all activities in a single integrated view
2. WHEN the user selects "By Category" mode THEN the system SHALL group activities by application category or type
3. WHEN the user selects "Chronological" mode THEN the system SHALL display activities ordered by time sequence
4. WHEN the user switches between modes THEN the system SHALL immediately update the display without losing current state
5. WHEN any mode is active THEN the system SHALL maintain consistent visual styling and interaction patterns
6. IF implementing the initial version THEN the system SHALL support only 'Unified' mode with fixed configuration

### Requirement 2

**User Story:** As a user, I want to configure how my activities are grouped, so that I can customize the view to match my workflow and analysis needs.

#### Acceptance Criteria

1. WHEN "Group by project" is enabled THEN the system SHALL organize activities under their assigned projects
2. WHEN "Group by device" is enabled THEN the system SHALL organize activities by the device they originated from
3. WHEN "Group websites independently of their browser" is enabled THEN the system SHALL separate website activities from browser applications
4. WHEN "Group websites by path before title" is enabled THEN the system SHALL organize websites by URL path structure
5. WHEN "Group file paths independently of their app" is enabled THEN the system SHALL separate file activities from their parent applications
6. WHEN "Group file paths by all parent directories" is selected THEN the system SHALL create hierarchical grouping based on directory structure
7. Currently we only need to implement 'Group by project'

### Requirement 3

**User Story:** As a user, I want to control what types of data are included in the activities view, so that I can focus on the information most relevant to my needs.

#### Acceptance Criteria

1. WHEN "Include time entries" is enabled THEN the system SHALL display manual time entries alongside automatic activity tracking
2. WHEN "Include app usage date ranges" is enabled THEN the system SHALL show application usage periods and durations
3. WHEN "Create entries for titles in addition to paths" is enabled THEN the system SHALL generate separate entries for document titles and file paths
4. WHEN any inclusion option is toggled THEN the system SHALL immediately update the activity list and recalculate totals
5. WHEN multiple inclusion options are active THEN the system SHALL merge and deduplicate related entries appropriately

### Requirement 4

**User Story:** As a user, I want to see hierarchical activity organization with expandable groups following a specific hierarchy, so that I can drill down from projects to detailed time entries.

#### Acceptance Criteria

1. WHEN activities are grouped THEN the system SHALL display them in a n-level hierarchy: Project → Subproject → Time Entry → Time Period → App Name → App Title -> n level(directory/domain)→ Time Detail List
2. WHEN a project group is expanded THEN the system SHALL show all subprojects under that project
3. WHEN a subproject is expanded THEN the system SHALL show all time entries associated with that subproject
4. WHEN a time entry is expanded THEN the system SHALL show time periods for that entry
5. WHEN a time period is expanded THEN the system SHALL show all app names active during that period
6. WHEN an app name is expanded THEN the system SHALL show all app titles (documents/websites) for that application
7. WHEN an app title is expanded THEN the system SHALL show the detailed time list with individual time segments
8. WHEN activities have the same app title THEN the system SHALL group their time details together under a single app title entry

### Requirement 5

**User Story:** As a user, I want to see accurate time calculations and activity counts, so that I can understand my actual time usage patterns.

#### Acceptance Criteria

1. WHEN the view loads THEN the system SHALL display the total time across all visible activities in the header
2. WHEN activities are filtered or grouped THEN the system SHALL recalculate and display accurate subtotals for each group
3. WHEN time entries contain app usage data THEN the system SHALL handle duration calculations to properly attribute app activities to their respective time entries
4. WHEN no activities match the current filters THEN the system SHALL display "0m 0s" and an appropriate empty state message