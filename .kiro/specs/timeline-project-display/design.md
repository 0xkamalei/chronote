# Design Document

## Overview

This design implements dynamic project and time entry visualization in the TimelineView by replacing static placeholder blocks with data-driven components that use MockData. The solution maintains the existing timeline structure while adding proper data binding and positioning calculations.

## Architecture

The implementation follows the existing TimelineView architecture with these key components:

- **TimelineView**: Main container that orchestrates the timeline display
- **ProjectTimelineRow**: New component for displaying project blocks
- **TimeEntryTimelineRow**: New component for displaying time entry blocks  
- **TimelineBlock**: Enhanced existing component for rendering individual blocks
- **MockData**: Existing data source providing projects and time entries

## Components and Interfaces

### TimelineView Enhancements

The main TimelineView will be updated to:
- Import MockData for projects and time entries
- Replace static project and time entry rows with dynamic data-driven rows
- Maintain existing timeline scale and positioning logic

### ProjectTimelineRow Component

New component that:
- Takes an array of Project objects and associated time ranges
- Calculates project block positions based on work sessions
- Renders project blocks with appropriate colors and labels
- Handles project hierarchy (parent/child relationships)

### TimeEntryTimelineRow Component  

New component that:
- Takes an array of TimeEntry objects
- Positions blocks based on startTime and endTime
- Colors blocks based on associated project or uses default color
- Displays entry titles and duration information

### Enhanced TimelineBlock Component

The existing TimelineBlock will be enhanced to:
- Accept additional metadata (title, project info)
- Support different visual styles for projects vs time entries
- Handle hover states and interaction feedback
- Display appropriate icons and labels

## Data Models

### Project Timeline Data

Projects need to be converted to timeline blocks by:
- Calculating time ranges from associated time entries
- Grouping consecutive work sessions on the same project
- Determining block positions and widths based on time ranges

### Time Entry Timeline Data

Time entries map directly to timeline blocks:
- startTime determines horizontal position
- duration (endTime - startTime) determines block width
- projectId links to project for color and metadata

## Error Handling

- Handle missing or invalid time data gracefully
- Provide fallback colors for projects without color assignments
- Handle edge cases like zero-duration entries or invalid time ranges
- Ensure timeline remains functional with empty or partial data

## Testing Strategy

### Unit Tests
- Test time position calculations for various time ranges
- Test block width calculations for different durations
- Test project color assignment and fallback logic
- Test time entry to timeline block conversion

### Integration Tests
- Test complete timeline rendering with mock data
- Test timeline scaling with dynamic blocks
- Test interaction between project and time entry rows
- Test timeline scrolling and zoom functionality

### Visual Tests
- Verify block positioning accuracy against time markers
- Verify color consistency between projects and time entries
- Verify proper block sizing at different zoom levels
- Verify timeline layout with various data combinations