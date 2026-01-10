# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chronoteis a free, open-source macOS time tracking application built as an alternative to Timing App. It automatically tracks app usage, categorizes activities into projects, and provides visual analytics - all while keeping data stored locally.


I'm currently in the MVP (Minimum Viable Product) stage, ignore the tedious testing and documentation and focus on the implementation of the core logic.

Don't use Chinese characters in the code.


## Build and Development Commands

### Building the Project
```bash
# Build using Xcode command line
xcodebuild -project time.xcodeproj -scheme time -configuration Release build

# Build and create a distributable DMG package
./package.sh
```

### Running the App
Open `time.xcodeproj` in Xcode and run the scheme `time` (Cmd+R). The app requires macOS 14+ and Accessibility permissions to function properly.

### Project Structure Location
The Xcode project file is located at `time.xcodeproj/project.pbxproj`.

## Architecture

### Data Models (SwiftData)

The app uses SwiftData for persistence with four main models:

1. **Activity** (`time/Models/Activity/Activity.swift`) - Records of app usage with context
   - Tracks: app name/bundle ID, window title, file path, web URL, domain
   - Links to projects via `projectId` (auto-assigned by rules)
   - Core fields: `startTime`, `endTime`, `duration`

2. **Project** (`time/Models/Project/Project.swift`) - User-defined categorization
   - Contains: name, color, sortOrder, productivityRating, isArchived
   - Color stored as serialized `Data` (NSColor/UIColor)

3. **AutoAssignRule** (`time/Models/Project/AutoAssignRule.swift`) - Automatic project assignment
   - Rule types: `appBundleId` or `titleKeyword`
   - Evaluated by `AutoAssignmentManager` when activities are created

4. **Event** (`time/Models/Event/Event.swift`) - Manual time tracking entries
   - User-started timed events with optional project association
   - Distinct from automatic Activity tracking

### Core Managers

All managers are `@MainActor` singletons accessed via `.shared`:

- **ActivityManager** (`time/Models/Activity/ActivityManager.swift`)
  - Singleton responsible for automatic app activity tracking
  - Observes NSWorkspace notifications for app switches, sleep, idle states
  - Delegates to `ContextMonitor` for window title/URL tracking
  - Delegates to `IdleMonitor` for detecting user inactivity
  - Calls `AutoAssignmentManager` to auto-assign projects to new activities
  - Key methods: `startTracking(modelContext:)`, `stopTracking(modelContext:)`, `trackAppSwitch(...)`

- **ProjectManager** (`time/Models/Project/ProjectManager.swift`)
  - CRUD operations for projects
  - Posts `.projectWasDeleted` notification on deletion

- **EventManager** (`time/Models/Event/EventManager.swift`)
  - Manages manual time tracking events
  - Tracks single `currentEvent` (ongoing event with nil endTime)
  - Can auto-stop events on user idle if configured

- **ActivityQueryManager** (`time/Models/Activity/ActivityQueryManager.swift`)
  - Centralized filtering/querying of activities
  - Applies filters: date range, project, sidebar selection, search text
  - Used by ContentView to populate activity lists

### Monitoring System

- **WindowMonitor** (`time/Models/Activity/WindowMonitor.swift`)
  - Uses macOS Accessibility APIs to read window titles and browser URLs
  - Returns `ActivityContext` (title, filePath, webUrl)

- **ContextMonitor** (`time/Models/Activity/ContextMonitor.swift`)
  - Polls a specific PID for context changes (e.g., tab switches in browser)
  - Debounces changes with 5-second delay
  - Notifies `ActivityManager` via `ContextMonitorDelegate`

- **IdleMonitor** (`time/Models/Activity/IdleMonitor.swift`)
  - Detects user inactivity using `CGEventSource.secondsSinceLastEventType`
  - Posts `.userDidBecomeIdle` and `.userDidBecomeActive` notifications

### View Architecture

- **ContentView** (`time/Views/ContentView.swift`) - Main application view
  - NavigationSplitView with sidebar and detail columns
  - Manages date range selection, timeline zoom, and activity filtering
  - Integrates ActivityQueryManager for filtered results
  - Contains TimelineView (140pt height) above activity list
  - Uses debouncing for timeline viewport changes (200ms delay)

- **Views Organization:**
  - `time/Views/Activity/` - Activity list and related components
  - `time/Views/Event/` - Manual event tracking UI
  - `time/Views/Timeline/` - Timeline visualization with zoom/pan
  - `time/Views/Sidebar/` - Project list and navigation
  - `time/Views/Settings/` - App preferences
  - `time/Views/MenuBar/` - Menu bar extra views
  - `time/Views/Toolbar/` - Main toolbar with date picker

### State Management

- **AppState** (`time/AppState.swift`) - `@Observable` global state
  - Navigation state: `selectedProject`, `selectedSidebar`, `columnVisibility`
  - Activity view mode: `.unified` or `.chronological`
  - Timer state for manual event tracking

- **App Entry** (`time/App.swift`) - `@main` struct
  - Creates SwiftData `ModelContainer` with custom store location
  - Handles migration errors by deleting corrupt stores
  - Schema: `[Activity.self, Project.self, AutoAssignRule.self, Event.self]`
  - Store location: `~/Library/Application Support/time-trace.store`
  - Provides AppState and EventManager as environment objects

### Permissions

The app requires **Accessibility Permission** to read window titles and URLs. Check status with:
```swift
WindowMonitor.shared.checkAccessibilityPermissions()
```

## Important Implementation Notes

1. **ActivityManager Lifecycle:**
   - Call `startTracking(modelContext:)` on app launch
   - ActivityManager saves activities to SwiftData when:
     - User switches apps
     - User becomes idle
     - App goes to sleep
     - Tracking is stopped
   - Activities with duration > 0 are saved; shorter durations are filtered out

2. **Context Tracking:**
   - ContextMonitor uses 5-second debounce to avoid creating too many activity records
   - When context changes (e.g., browser tab switch), ActivityManager saves current activity and creates a new one with the same appBundleId but new context

3. **Auto-Assignment:**
   - `AutoAssignmentManager.shared.reloadRules(modelContext:)` must be called before evaluation
   - Rules are evaluated when new activities are created in `trackAppSwitch`

4. **Data Store Migration:**
   - App.swift handles migration failures by detecting error code 134110
   - Deletes `.store`, `.store-wal`, `.store-shm` files and recreates container

5. **Logging:**
   - Uses `os.Logger` throughout the codebase
   - Logger subsystem: `com.time.vscode` or `com.time-vscode` (inconsistent naming)
   - Import: `import os` or `import os.log`

6. **Timeline Integration:**
   - Timeline uses separate `visibleTimeRange` (for zoom) vs `selectedTimeRange` (for filtering)
   - Debounced viewport updates prevent UI lag during zoom/pan
   - Events and activities are both displayed on the timeline

## Key Patterns

- All managers use `@MainActor` to ensure thread-safety
- SwiftData operations use `modelContext.insert()` followed by `try modelContext.save()`
- Project colors stored as serialized NSColor/UIColor Data (cross-platform compatibility)
- Navigation state coordinated through AppState with separate project/sidebar selection
