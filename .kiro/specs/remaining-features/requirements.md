# Time Tracking App - Remaining Features Requirements

## Introduction

This specification covers the remaining core features needed to complete the time tracking application. The app currently has a solid foundation with project management, basic UI components, and data models, but lacks the essential automatic activity tracking, real-time timeline visualization, and timer functionality that make it a complete time tracking solution.

## Glossary

- **Activity**: Automatically recorded app usage events with start/end times and application metadata
- **Timer**: Manual time tracking session that can be started/stopped by the user
- **Timeline**: Visual representation showing activities, projects, and time entries across time
- **Rule Engine**: System for automatically assigning activities to projects based on user-defined rules
- **Activity Tracker**: Background service that monitors application switches and system events
- **Time Entry**: Manual time allocation record that can be created from timers or assigned to activities
- **Idle Detection**: System to detect when user is not actively using the computer
- **Window Title Capture**: Feature to capture the title of the active window for context

## Requirements

### Requirement 1: Automatic Activity Tracking

**User Story:** As a user, I want the app to automatically track which applications I use and for how long, so that I can see my actual time usage without manual input.

#### Acceptance Criteria

1. WHEN the app is running, THE Activity_Tracker SHALL monitor application activation events through NSWorkspace notifications
2. WHEN an application switch occurs, THE Activity_Tracker SHALL save the previous application's usage duration to the database
3. WHEN capturing application data, THE Activity_Tracker SHALL record application name, bundle ID, window title, start time, and end time
4. WHEN the system goes to sleep, THE Activity_Tracker SHALL properly end the current activity and save it
5. WHEN the system wakes up, THE Activity_Tracker SHALL be ready to track new application switches

### Requirement 2: Real-time Timer Functionality

**User Story:** As a user, I want to start and stop manual timers for focused work sessions, so that I can track specific tasks with precision.

#### Acceptance Criteria

1. WHEN I start a timer, THE Timer_System SHALL begin counting elapsed time and update the UI in real-time
2. WHEN a timer is active, THE Timer_System SHALL display the current duration in the status bar and main interface
3. WHEN I stop a timer, THE Timer_System SHALL create a time entry with the recorded duration
4. WHEN the app is quit with an active timer, THE Timer_System SHALL save the timer state and restore it on next launch
5. WHEN a timer reaches an estimated duration, THE Timer_System SHALL send a notification to the user

### Requirement 3: Interactive Timeline Visualization

**User Story:** As a user, I want to see a visual timeline of my activities, projects, and time entries, so that I can understand my time allocation patterns.

#### Acceptance Criteria

1. WHEN viewing the timeline, THE Timeline_Component SHALL display three rows: device activities, projects, and time entries
2. WHEN activities are displayed, THE Timeline_Component SHALL show app icons and scale block widths based on duration
3. WHEN I hover over timeline elements, THE Timeline_Component SHALL show detailed information in tooltips
4. WHEN I zoom the timeline, THE Timeline_Component SHALL adjust the time scale while maintaining proportional block sizes
5. WHEN I click on empty timeline areas, THE Timeline_Component SHALL offer to create new time entries with pre-filled times

### Requirement 4: Idle Time Detection

**User Story:** As a user, I want the app to detect when I'm not actively using my computer, so that idle time is not incorrectly attributed to applications.

#### Acceptance Criteria

1. WHEN the system is idle for more than 5 minutes, THE Idle_Detector SHALL pause activity tracking
2. WHEN the user returns from idle, THE Idle_Detector SHALL prompt to record what was done during the idle period
3. WHEN idle time is detected, THE Idle_Detector SHALL not count it toward the last active application's duration
4. WHEN resuming from idle, THE Idle_Detector SHALL start fresh activity tracking
5. WHERE idle detection is disabled, THE Idle_Detector SHALL continue normal activity tracking

### Requirement 5: Window Title and Context Capture

**User Story:** As a user, I want the app to capture window titles and document names, so that I can see specifically what I was working on within each application.

#### Acceptance Criteria

1. WHEN an application is activated, THE Context_Capturer SHALL attempt to get the active window title using Accessibility APIs
2. WHEN window title is available, THE Context_Capturer SHALL store it with the activity record
3. WHEN accessibility permissions are not granted, THE Context_Capturer SHALL gracefully fall back to application name only
4. WHEN capturing browser titles, THE Context_Capturer SHALL record the page title or URL when possible
5. WHERE privacy mode is enabled, THE Context_Capturer SHALL not record window titles

### Requirement 6: Rule Engine for Automatic Project Assignment

**User Story:** As a user, I want to create rules that automatically assign activities to projects, so that I don't have to manually categorize every activity.

#### Acceptance Criteria

1. WHEN I create a rule, THE Rule_Engine SHALL allow me to specify conditions based on app name, window title, or time patterns
2. WHEN new activities are recorded, THE Rule_Engine SHALL evaluate all rules and assign matching activities to projects
3. WHEN multiple rules match an activity, THE Rule_Engine SHALL apply the most specific rule based on priority
4. WHEN I modify a rule, THE Rule_Engine SHALL offer to retroactively apply it to existing activities
5. WHERE no rules match an activity, THE Rule_Engine SHALL leave it unassigned for manual categorization

### Requirement 7: Activity Data Processing and Statistics

**User Story:** As a user, I want to see aggregated statistics and insights about my time usage, so that I can identify productivity patterns and areas for improvement.

#### Acceptance Criteria

1. WHEN viewing activity summaries, THE Data_Processor SHALL group activities by project, application, and time period
2. WHEN calculating durations, THE Data_Processor SHALL handle overlapping time entries and resolve conflicts
3. WHEN displaying statistics, THE Data_Processor SHALL show total time, average session length, and productivity scores
4. WHEN filtering activities, THE Data_Processor SHALL support date ranges, projects, and application filters
5. WHERE activities span multiple days, THE Data_Processor SHALL correctly split them at midnight boundaries

### Requirement 8: Background Service Management

**User Story:** As a user, I want the app to run efficiently in the background without impacting system performance, so that tracking is seamless and unobtrusive.

#### Acceptance Criteria

1. WHEN the app starts, THE Background_Service SHALL initialize activity tracking with minimal system impact
2. WHEN running in background, THE Background_Service SHALL use less than 1% CPU and 50MB RAM under normal conditions
3. WHEN system resources are low, THE Background_Service SHALL reduce tracking frequency to preserve performance
4. WHEN the app is hidden, THE Background_Service SHALL continue tracking but minimize UI updates
5. WHERE tracking fails, THE Background_Service SHALL retry with exponential backoff and log errors appropriately

### Requirement 9: Data Integrity and Error Recovery

**User Story:** As a user, I want my time tracking data to be reliable and recoverable, so that I don't lose important time records due to system issues.

#### Acceptance Criteria

1. WHEN database operations fail, THE Data_Manager SHALL retry with exponential backoff up to 3 attempts
2. WHEN data corruption is detected, THE Data_Manager SHALL attempt automatic repair and notify the user
3. WHEN the app crashes during tracking, THE Data_Manager SHALL recover incomplete activities on next launch
4. WHEN storage is full, THE Data_Manager SHALL archive old data and continue tracking new activities
5. WHERE data conflicts occur, THE Data_Manager SHALL present resolution options to the user

### Requirement 10: Timeline Interaction and Editing

**User Story:** As a user, I want to interact with the timeline to edit time entries and assign activities to projects, so that I can correct and organize my time data.

#### Acceptance Criteria

1. WHEN I drag activities from the timeline, THE Timeline_Editor SHALL allow dropping them onto projects in the sidebar
2. WHEN I double-click timeline blocks, THE Timeline_Editor SHALL open edit dialogs for time entries or activities
3. WHEN I select multiple timeline items, THE Timeline_Editor SHALL support batch operations like project assignment
4. WHEN I resize timeline blocks, THE Timeline_Editor SHALL update the corresponding time entry durations
5. WHERE timeline edits conflict with existing data, THE Timeline_Editor SHALL show warnings and require confirmation

### Requirement 11: Search and Filtering System

**User Story:** As a user, I want to search and filter my activities and time entries, so that I can quickly find specific work sessions or analyze particular time periods.

#### Acceptance Criteria

1. WHEN I enter search terms, THE Search_System SHALL find matching activities by app name, window title, or project
2. WHEN I apply filters, THE Search_System SHALL update the timeline and activity list in real-time
3. WHEN searching across large datasets, THE Search_System SHALL return results within 500ms
4. WHEN I save filter combinations, THE Search_System SHALL allow me to quickly reapply them
5. WHERE search results are empty, THE Search_System SHALL suggest alternative search terms or filters

### Requirement 12: Notification and Alert System

**User Story:** As a user, I want to receive notifications about timer completion and tracking status, so that I stay informed about my time tracking without constantly checking the app.

#### Acceptance Criteria

1. WHEN a timer reaches its estimated duration, THE Notification_System SHALL send a system notification
2. WHEN tracking stops unexpectedly, THE Notification_System SHALL alert me and offer to restart tracking
3. WHEN daily time goals are reached, THE Notification_System SHALL send congratulatory notifications
4. WHEN I haven't tracked time for extended periods, THE Notification_System SHALL send gentle reminders
5. WHERE notifications are disabled, THE Notification_System SHALL respect system preferences and user settings