# Design Document

## Overview

This design implements the ActivitiesView component to use MockData instead of hardcoded activities. The solution maintains the existing UI structure while adding proper data binding, sorting logic, and hierarchical grouping capabilities. The implementation will support browser activity expansion, unassigned activity tracking, and multiple sort modes as specified in the project requirements.

## Architecture

The implementation follows the existing SwiftUI architecture with these key components:

- **ActivitiesView**: Main container that displays activities with sorting and grouping
- **ActivityDataProcessor**: New utility class for processing and grouping activities
- **BrowserActivityGroup**: Component for handling expandable browser activities
- **ActivityRow**: Enhanced component for displaying individual activities
- **MockData**: Existing data source providing activities

## Components and Interfaces

### ActivitiesView Enhancements

The main ActivitiesView will be updated to:
- Remove hardcoded activities and use MockData.activities
- Calculate total duration dynamically from actual activity data
- Implement proper sorting logic for all three sort modes
- Handle empty states when no activities are available
- Manage expanded/collapsed state for browser groups

### ActivityDataProcessor

New utility class that:
- Processes raw activities from MockData
- Implements sorting logic for Unfiled, Category, and Chronological modes
- Groups activities by project for Unfiled mode, including both time entries and app usage data ranges
- Groups browser activities and identifies websites
- Calculates total durations for groups and overall activities
- Handles unassigned activity identification
- Implements fixed configuration logic for MVP phase

### BrowserActivityGroup Component

New component that:
- Displays browser applications as expandable groups
- Shows individual websites when expanded
- Maintains expansion state using @State
- Displays total browser duration and individual website durations
- Uses proper indentation for hierarchical display

### Enhanced ActivityRow Component

Enhanced component that:
- Displays individual non-browser activities
- Shows app icon, name, and duration
- Handles different activity types consistently
- Supports proper styling and spacing

## Data Models

### Activity Processing

Activities will be processed to:
- Calculate total duration across all activities
- Group browser activities by app name
- Extract website information from appTitle for browsers
- Sort activities according to selected mode
- Identify unassigned activities (those without project association)

### Browser Activity Grouping

Browser activities will be grouped by:
- Identifying browser apps (Chrome, Safari, Edge, etc.)
- Aggregating total time per browser
- Extracting individual websites from appTitle
- Creating hierarchical structure for display

### Sort Mode Implementation

Three sort modes will be implemented:

- **Unfiled**: Group activities by project, including both time entries and app usage data ranges. Uses fixed configuration layout as shown in reference image for MVP phase
- **By Category**: Group activities by application type/category
- **Chronological**: Display activities ordered by time sequence without grouping

## Error Handling

- Handle empty MockData.activities gracefully
- Provide appropriate empty state messages
- Handle missing appTitle for browser activities
- Ensure duration calculations don't fail with invalid data
- Handle expansion state persistence across view updates

