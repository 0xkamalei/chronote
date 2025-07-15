# GitHub Copilot Instructions

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

### Code style

- Use best practices with the latest versions of SwiftUI and SwiftData

### Features

- project
  - Project supports hierarchy, allowing you to add sub projects to a project
  - When creating projects, "new time entry", or "start timer", you can quickly add subprojects
  - Display project tree in the left sidebar, and you can change the display order of projects by dragging
  - By clicking to select a project in the left sidebar, the current project becomes the filter condition for "All Activity" queries
  - project.title is a specific task under a project; for example, if the project is developing timing.app, project.title would be writing PRD
  - "Unassigned" represents activities that have not been assigned to a project through time-entry; you can select Unassigned to filter only Unassigned activities
  - "All Activities" represents no filtering by project; when selected, "Unassigned" should be displayed at the top of the details
  - "My Projects" is equivalent to querying all activities assigned to projects
  - When a project is selected but has no corresponding activities, display "No time traced"
  - At the end of each project in the sidebar, display the total time sum of activities corresponding to this project. See UI @ui/siderbar-project.    

                          
- Activity
  - Activity is automatically recorded after opening the program, currently under implementation
  - Activity automatically records the time occupied by the previous app based on application switching events
  - Activity display results can be filtered by various conditions: time range, project
  - Activity detail display is divided into two columns: one for summary, one for grouped display; default is group by project, project.title, activity.title
  - Activity display logic is a multi-level collapsible list: project -> subproject (if any) -> title (filled in timeEntry, no title for unassigned) -> time period -> app icon and name -> app.title (activities with the same title are aggregated together) -> Activities app usage details start time ~ end time; see UI @ui/main-layout.png for details


- timepicker
  - The timepicker component allows quick selection of time ranges, supporting only date selection
  - When using quick time selection, the two corresponding date selectors will calculate and change in real-time, and are used immediately to filter data
  - See UI @ui/timepicker.png for details


- time entry
  - Time allocation function to assign activities to corresponding projects or subprojects
  - Timeline functionality
    - This is the core feature of the app, used to display overview of app usage, project status, and project.title status
    - Can be used to display projects and activities, also for quickly sliding to select time ranges, and for quickly adding time entries. See UI @ui/timeline.png for details
    - The timeline section can be zoomed in/out by holding cmd+mouse wheel
    - Timeline consists of three rows:
    - Timeline first row shows current device activity, displayed as app icons; when zoomed, shows the app icon that was used most during that time period; mouse hover on icon shows detailed information
    - Timeline second row shows project color blocks
    - Timeline third row shows time entries; if not assigned, displays shortcut button, clicking pops up "New time entry" with start-time and end-time automatically filled in

- background
  - Get app activation notifications through `didActivateApplicationNotification`
  - After activation, call `ActivityManager.trackAppSwitch` code example:
    ```
    NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
        print("Event didActivateApplicationNotification")
        // Execute your callback operations here
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            //print("Currently activated app: \(app.localizedName ?? "Unknown")")
            print(app.bundleIdentifier ?? "-")
            Task {
                @MainActor in
                ActivityManager.shared.trackAppSwitch(newApp:  app.bundleIdentifier ?? "-", modelContext: modelContext)
            }
        }
    }

     NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
        print("Event willSleepNotification")
        Task {
            @MainActor in
            ActivityManager.shared.stopTrack(modelContext: modelContext)
        }
    }
    ```
  - 
### APP Tracing Implementation Logic

Listen to `didActivateApplicationNotification` and `willSleepNotification` events, maintain a state through ActivityManager. If the app is switched, save the previous app's activity.
If the system goes to sleep, directly save the current app state.

Must be able to get the app's icon for use during display.

### Activity Statistics Logic
Calculate duration based on each activity's end time minus start time, merge durations to get usage time. Can calculate time for each group separately based on grouping. For example, if grouped by project, you can calculate the total time for each project based on duration.

### State Management
- **AppState**: Central `ObservableObject` managing global application state
  - Project hierarchy with parent/child relationships
  - Timer state and active tracking
  - Project reordering through index-based system
- Projects are managed in-memory with plans for SwiftData integration

### Data Models
- **Project**: Hierarchical project structure with color coding, custom encoding/decoding for Color persistence
- **Activity**: Represents app usage tracking with duration and system icons and app id
- **TimeEntry** Corresponds to a work period under a project, started and ended by user through buttons; can also be stopped automatically by the system during standby based on configuration

### View Architecture
- **NavigationSplitView**: Main layout with sidebar and detail views
- **SidebarView**: Project navigation with expandable/collapsible sections
- **Modular Views**: Separate views for editing projects, time entries, and timer controls
- **Sheet Presentations**: Modal dialogs for adding projects and time entries



### Key Files
- `AppState.swift`: Central state management and project hierarchy logic
- `Models/Project.swift`: Project model with color encoding and hierarchy support
- `Views/SidebarView.swift`: Project navigation and selection
- `ContentView.swift`: Main application layout and sheet coordination

## Development Notes

### Project Management
- use git commit save all changes before update files
- Mock data currently used for development and testing

### State Flow
- AppState serves as single source of truth for project data
- Published properties automatically update SwiftUI views
- Timer state managed centrally for consistency across views
- Sheet presentation state managed in ContentView for modal coordination

### UI Patterns
- Color-coded projects for visual organization
- Disclosure groups for expandable project hierarchies
- NavigationLink and selection binding for sidebar navigation
