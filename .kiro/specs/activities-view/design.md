# Design Document

## Overview

This design implements a comprehensive ActivitiesView component that displays user activities with advanced grouping, filtering, and hierarchical display capabilities. The implementation focuses on a Unified display mode with project-based grouping, supporting a structured hierarchical display (Project → Subproject → Time Entry → Time Period → App Name → App Title → n-level directory/domain → Time Detail List) for detailed activity drill-down.

The solution integrates both automatic activity tracking and manual time entries with accurate time calculations, expandable group navigation, and real-time updates when inclusion settings change. The design addresses all requirements for display modes, grouping configurations, data inclusion options, hierarchical organization, and time calculations while maintaining consistent visual styling and interaction patterns.

**Design Decision**: The implementation uses a fixed configuration approach (Unified mode with project grouping) to establish robust core functionality and data processing patterns. This ensures thorough validation of the hierarchical display logic and time calculation accuracy before introducing dynamic configuration complexity for "By Category" and "Chronological" modes. This phased approach aligns with Requirement 1.6 which specifies that the initial version should support only 'Unified' mode with fixed configuration.

**Architecture Rationale**: The modular design with separate data processing, hierarchy building, and UI components enables clean separation of concerns, testability, and future extensibility for additional display modes (By Category, Chronological) and grouping options. This architecture supports the requirement for immediate display updates (Requirement 3.4) and maintains consistent visual styling across all interaction patterns (Requirement 1.5). The design specifically focuses on project-based grouping as specified in Requirement 2.1 and 2.7, while maintaining the architectural foundation for future grouping options including device-based grouping (Requirement 2.2), website grouping (Requirements 2.3, 2.4), and file path grouping (Requirements 2.5, 2.6).

**State Management Strategy**: The design employs a reactive architecture where configuration changes trigger immediate data reprocessing and UI updates. This ensures that when users toggle inclusion options (Requirements 3.1, 3.2, 3.3), the display updates instantly without user intervention (Requirement 3.4), and all time calculations are recalculated accurately across the hierarchy (Requirement 5.2).

## Data Models

### Enhanced Activity Model

Extended activity representation that includes:
- Original Activity properties (appName, duration, etc.)
- Computed project assignment based on time matching with time entries
- Computed time entry associations derived from temporal overlap analysis
- Time period segmentation data
- Grouping metadata and relationships

**Design Decision**: Project assignments and time entry associations are computed at runtime by matching Activity timestamps with TimeEntry time ranges, rather than being stored as direct properties. This ensures data consistency and allows for flexible time-based grouping logic.

### ActivityGroup Model

Hierarchical grouping structure that represents computed aggregations from original activities. This model is necessary because:

**Purpose**: The ActivityGroup is a computed data structure that aggregates and organizes raw Activity data into the required hierarchy (Project → Subproject → Time Entry → Time Period → App Name → App Title → n-level directory/domain → Time Detail List). It's not stored data, but rather a processed representation that enables efficient rendering and interaction.

**Contents**:
- Group identifier and display name (e.g., "Project A", "Safari", "github.com")
- Total duration and item count (aggregated from child activities)
- Child groups and leaf activities (the hierarchical structure)
- Metadata for sorting and filtering

**Why it's needed**:
- Raw Activity objects are flat and don't contain grouping relationships
- The UI requires nested, expandable groups with aggregated totals
- Different grouping modes (project, device, website) require different organizational structures
- Enables efficient rendering of large activity datasets through hierarchical organization

**Design Decision**: UI state such as expansion state and user preferences are managed separately in the view layer to maintain clean separation between data models and presentation logic.

### Configuration Model

Settings model that manages activity display and grouping preferences:

**Display Mode Settings**:
- Current display mode (Unified, By Category, Chronological) - initially fixed to Unified
- Mode-specific preferences and state

**Grouping Configuration**:
- Group by project (enabled/disabled)
- Group by device (enabled/disabled) 
- Group websites independently of their browser (enabled/disabled)
- Group websites by path before title (enabled/disabled)
- Group file paths independently of their app (enabled/disabled)
- Group file paths by all parent directories (enabled/disabled)

**Data Inclusion Settings**:
- Include time entries (boolean toggle)
- Include app usage date ranges (boolean toggle)
- Create entries for titles in addition to paths (boolean toggle)

**UI State Management**:
- Expanded group states (Set<String> of expanded group identifiers)
- User preferences and defaults
- Configuration validation rules

**Design Decision**: The Configuration model separates persistent settings (grouping and inclusion options) from transient UI state (expansion states) to enable proper state management and user preference persistence.

### Time Calculation and Aggregation Model

The system implements sophisticated time calculation logic as part of the data processing layer:

**Duration Calculation**:
- Displays total time across all visible activities in the header (Requirement 5.1)
- Recalculates and displays accurate subtotals for each group when activities are filtered or grouped (Requirement 5.2)
- Handles duration calculations to properly attribute app activities to their respective time entries (Requirement 5.3)
- Shows "0m 0s" when no activities match current filters (Requirement 5.4)
- Prevents double-counting of concurrent activities
- Aggregates durations at each hierarchy level

**Time Period Segmentation**:
- Breaks activities into meaningful time segments
- Groups related activities within time periods
- Handles activities spanning multiple periods
- Maintains temporal accuracy in calculations

## Architecture

The implementation follows a modular SwiftUI architecture with clear separation of concerns:

- **ActivitiesView**: Main container with fixed Unified mode and project-based grouping
- **ActivityDataProcessor**: Core data processing engine handling project grouping, filtering, and hierarchy construction
- **ActivityHierarchyBuilder**: Specialized component for building the 6-level hierarchy structure
- **HierarchicalActivityRow**: Recursive component for rendering nested activity structures
- **ActivityGroupHeader**: Component for displaying group summaries and expansion controls

**Design Decision**: The initial implementation uses a fixed configuration (Unified mode with project grouping) to establish the core functionality before adding configuration flexibility. This approach allows for thorough testing of the hierarchical display and data processing logic without the complexity of dynamic configuration management.

## Components and Interfaces

### ActivitiesView (Main Container)

The main view component that:
- Displays activities in fixed Unified mode with project-based grouping (Requirements 1.1, 1.6, 2.1, 2.7)
- Shows total activity time across all visible activities in the header (Requirement 5.1)
- Manages three data inclusion options: "Include time entries", "Include app usage date ranges", and "Create entries for titles in addition to paths" (Requirements 3.1, 3.2, 3.3)
- Immediately updates display and recalculates totals when inclusion options are toggled (Requirement 3.4)
- Handles empty states with "0m 0s" display and appropriate empty state messages (Requirement 5.4)
- Maintains consistent visual styling and interaction patterns across all states (Requirement 1.5)
- Coordinates with ActivityDataProcessor for data processing and merging

### ActivityDataProcessor

Core data processing engine that:
- Merges activities from MockData.activities and MockData.timeEntries (Requirements 3.1, 3.5)
- Applies filtering based on inclusion settings (time entries, app usage, titles) (Requirements 3.1, 3.2, 3.3)
- Implements grouping logic for project-based organization (Requirement 2.1)
- Handles duration calculations and overlap detection to prevent double-counting (Requirement 5.3)
- Provides data transformation for the unified display mode (Requirement 1.1)
- Manages data caching and performance optimization
- Ensures immediate updates when inclusion options are toggled (Requirement 3.4)
- Implements proper merging and deduplication of related entries when multiple inclusion options are active (Requirement 3.5)

### ActivityHierarchyBuilder

Specialized data processing utility class responsible for transforming flat activity data into the required 6+ level hierarchical structure. This utility takes raw activities and time entries and organizes them into a tree structure that matches the display requirements:

**Primary Function**: Converts flat data arrays into nested hierarchy for display

**Hierarchy Construction Process**:
- **Level 1 - Project**: Groups activities by assigned project (including unassigned activities in a separate group)
- **Level 2 - Subproject**: Organizes subprojects under their parent projects when applicable
- **Level 3 - Time Entry**: Associates manual time entries with their respective projects/subprojects
- **Level 4 - Time Period**: Breaks down time entries into discrete time segments (e.g., morning, afternoon periods)
- **Level 5 - App Name**: Groups application activities that occurred during each time period
- **Level 6+ - Variable App Title Hierarchy**: Creates n-level nested structure based on content type:
  - For websites: Domain → Path segments → Final URL/Title
  - For files: Directory hierarchy → Subdirectories → Final file/document
  - For applications: Window/document hierarchy as applicable
- **Final Level - Time Detail List**: Contains the actual time detail segments for each specific item

**Context-Aware App Title Grouping**:
- For browser applications: Groups by website domain first, then by URL path structure
- For file-based applications: Groups by directory path hierarchy
- For other applications: Groups by document/window titles
- Activities with the same app title are grouped together under a single app title entry (Requirement 4.8)

**Key Responsibilities**:
- Processes MockData.activities and MockData.timeEntries into hierarchical structure
- Handles parent-child relationships between hierarchy levels
- Manages grouping logic for activities with the same app title (Requirement 4.8)
- Maintains data integrity during hierarchy construction
- Optimizes structure for efficient rendering by HierarchicalActivityRow component



### HierarchicalActivityRow

SwiftUI view component that recursively renders individual rows in the activity hierarchy tree:
- **Displays any hierarchy level**: Can render projects, subprojects, time entries, time periods, app names, or nested app titles
- **Manages expansion state**: Handles expand/collapse functionality for groups that have children
- **Applies visual hierarchy**: Shows appropriate indentation, icons, and styling based on the hierarchy level
- **Shows aggregated data**: Displays duration totals, activity counts, and relevant metadata for each row
- **Handles user interactions**: Responds to tap gestures for expansion/collapse and selection
- **Recursive rendering**: Calls itself to render child rows when a group is expanded, creating the nested tree structure

## Display Mode and Grouping Implementation

### Unified Mode with Project-Based Grouping

The initial implementation combines display mode and grouping logic in a unified approach:

**Display Characteristics**:
- Displays all activities in a single integrated view
- Combines time entries and app usage data
- Shows complete 6-level hierarchy when applicable
- Maintains consistent sorting within groups

**Project-Based Grouping Logic**:
- Creates project nodes from MockData.projects
- Assigns activities based on time-based project associations
- Handles unassigned activities in separate section
- Maintains project hierarchy (parent/child relationships)

**Design Decision**: The initial implementation focuses solely on Unified mode with project-based grouping to establish core functionality. By Category and Chronological modes, along with additional grouping options (device-based, website, file path), will be added in future iterations once the foundational hierarchy and data processing logic is proven stable.

### Future Grouping Options (Architecture Foundation)

The design maintains architectural support for future grouping implementations:

**Device-Based Grouping**: Will identify device sources from activity metadata and create device-level grouping nodes while maintaining other hierarchy levels within device groups.

**Website and File Path Grouping**: Will provide advanced options to separate websites from browser applications, group websites by URL path structure, handle file paths independently from applications, and create directory-based hierarchies for file activities.



## Error Handling and Edge Cases

### Data Validation

Robust error handling for:
- Missing or invalid activity data
- Inconsistent time entries and durations
- Malformed project relationships
- Configuration conflicts and invalid states

### Performance Optimization

Efficient processing through:
- **ActivityGroup Caching**: Computed ActivityGroup structures are cached and only recalculated when underlying data or inclusion settings change, preventing unnecessary recomputation on UI updates
- **Incremental Hierarchy Updates**: When inclusion options are toggled, only affected portions of the hierarchy are recalculated rather than rebuilding the entire structure
- **Lazy Expansion**: Child groups are only computed when their parent groups are expanded, reducing initial load time
- **Memoized Aggregations**: Duration totals and counts are memoized at each hierarchy level to avoid repeated calculations during rendering
- **Data Change Detection**: Smart diffing algorithms detect actual data changes vs. UI state changes to minimize unnecessary processing
- **Memory Management**: Large activity datasets use pagination and memory-efficient data structures to prevent performance degradation

### Empty States

Appropriate handling of:
- No activities in selected time period
- Empty project assignments
- Missing app titles or metadata
- Filtered results with no matches