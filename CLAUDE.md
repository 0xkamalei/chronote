# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native macOS time tracking application built with SwiftUI and SwiftData. like timing app. The app tracks application usage, manages hierarchical projects, and provides timer functionality for focused work sessions.

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project time-vscode.xcodeproj -scheme time-vscode -configuration Debug build

# Build for release
xcodebuild -project time-vscode.xcodeproj -scheme time-vscode -configuration Release build

# Open in Xcode
open time-vscode.xcodeproj
```

### Common Development Tasks
- Use Xcode's built-in simulator to test the app
- The app targets macOS with minimum deployment target defined in project settings
- SwiftUI previews are available for most views using `#Preview`

## Architecture

### State Management
- **AppState**: Central `ObservableObject` managing global application state
  - Project hierarchy with parent/child relationships
  - Timer state and active tracking
  - Project reordering through index-based system
- **SwiftData**: Used for persistence with `Item` model (currently minimal)
- Projects are managed in-memory with plans for SwiftData integration

### Data Models
- **Project**: Hierarchical project structure with color coding, custom encoding/decoding for Color persistence
- **Activity**: Represents app usage tracking with duration and system icons

### View Architecture
- **NavigationSplitView**: Main layout with sidebar and detail views
- **SidebarView**: Project navigation with expandable/collapsible sections
- **Modular Views**: Separate views for editing projects, time entries, and timer controls
- **Sheet Presentations**: Modal dialogs for adding projects and time entries

### Project Hierarchy System
Projects use an index-based ordering system where:
- Higher index values appear higher in the list
- Parent/child relationships through `parentID` references
- `AppState.projectTree` computes the hierarchical structure
- Drag-and-drop reordering updates indices to maintain order

### Key Files
- `AppState.swift`: Central state management and project hierarchy logic
- `Models/Project.swift`: Project model with color encoding and hierarchy support
- `Views/SidebarView.swift`: Project navigation and selection
- `ContentView.swift`: Main application layout and sheet coordination

## Development Notes

### Project Management
- Projects support unlimited nesting through parent/child relationships
- Mock data currently used for development and testing

### State Flow
- AppState serves as single source of truth for project data
- Published properties automatically update SwiftUI views
- Timer state managed centrally for consistency across views
- Sheet presentation state managed in ContentView for modal coordination

### UI Patterns
- Uses SF Symbols for consistent iconography
- Color-coded projects for visual organization
- Disclosure groups for expandable project hierarchies
- NavigationLink and selection binding for sidebar navigation