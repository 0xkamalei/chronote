import SwiftData
import SwiftUI

import os

@MainActor
class AppState: ObservableObject {
    // Timer management - now using TimerManager
    @Published var timerManager: TimerManager = TimerManager()
    @Published var automaticTimeEntryCreation: Bool = true

    // Notification and productivity tracking
    @Published var notificationManager: NotificationManager = NotificationManager()
    @Published var productivityGoalTracker: ProductivityGoalTracker = ProductivityGoalTracker()

    // Idle detection and recovery management
    @Published var idleRecoveryManager: IdleRecoveryManager = IdleRecoveryManager.shared
    
    // Performance monitoring and optimization
    @Published var performanceMonitor: PerformanceMonitor = PerformanceMonitor.shared
    @Published var memoryManager: MemoryManager = MemoryManager.shared
    @Published var databaseOptimizer: DatabasePerformanceOptimizer = DatabasePerformanceOptimizer.shared

    @Published var selectedProject: Project?
    @Published var selectedSidebar: String? = "All Activities"

    // Time entry selection and filtering
    @Published var selectedTimeEntry: TimeEntry?
    @Published var timeEntryFilterProject: Project?
    @Published var timeEntryFilterDateRange: DateInterval?

    init() {
        selectedSidebar = "All Activities"
        selectedProject = nil

        setupNotificationObservers()
        setupNotificationIntegration()
    }
    
    /// Sets up integration between notification manager and other components
    private func setupNotificationIntegration() {
        // Connect TimerManager with NotificationManager
        timerManager.setNotificationManager(notificationManager)
        
        // Connect ProductivityGoalTracker with NotificationManager
        productivityGoalTracker.setNotificationManager(notificationManager)
        
        // Connect ActivityTracker with NotificationManager (if available)
        ActivityTracker.shared.setNotificationManager(notificationManager)
    }
    
    /// Sets the model context for all managers that need it
    func setModelContext(_ context: ModelContext) {
        timerManager.setModelContext(context)
        productivityGoalTracker.setModelContext(context)
        
        // Initialize performance monitoring components
        databaseOptimizer.setModelContext(context)
        
        // Optimize database on startup
        Task {
            do {
                try await DatabaseConfiguration.optimizeDatabase(modelContext: context)
                Logger.appState.info("Database optimization completed during startup")
            } catch {
                Logger.appState.error("Database optimization failed during startup: \(error.localizedDescription)")
            }
        }
        
        // Schedule recurring summaries
        productivityGoalTracker.scheduleDailySummary()
        productivityGoalTracker.scheduleWeeklySummary()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Sets up notification observers for project change events
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProjectChange(_:)),
            name: .projectDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProjectDeleted(_:)),
            name: .projectWasDeleted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimerStopRequest(_:)),
            name: .timerShouldStop,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimeEntryChange(_:)),
            name: .timeEntryDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimeEntryDeleted(_:)),
            name: .timeEntryWasDeleted,
            object: nil
        )
    }

    // MARK: - Selection Management

    /// 选择特殊项目（All Activities, Unassigned, My Projects）
    func selectSpecialItem(_ item: String) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedProject = nil
            selectedSidebar = item
        }

        Logger.appState.info("Selected special item: \(item, privacy: .public)")

        switch item {
        case "All Activities":
            Logger.appState.info("Filtering mode: Show all activities")
        case "Unassigned":
            Logger.appState.info("Filtering mode: Show unassigned activities")
        case "My Projects":
            Logger.appState.info("Filtering mode: Show project activities")
        default:
            break
        }
    }

    /// 选择项目
    func selectProject(_ project: Project) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedSidebar = nil
            selectedProject = project
        }

        Logger.appState.info("Selected project: \(project.name, privacy: .public)")
        Logger.appState.debug("Project ID: \(project.id, privacy: .public)")
        if let parentID = project.parentID {
            Logger.appState.debug("Parent project ID: \(parentID, privacy: .public)")
        }
        Logger.appState.debug("Project color: \(String(describing: project.color), privacy: .public)")
        Logger.appState.info("Applying project filter: \(project.name, privacy: .public)")

        // Notify through NotificationCenter instead of direct manager dependency
        NotificationCenter.default.post(
            name: .projectSelectionChanged,
            object: nil,
            userInfo: ["project": project]
        )
    }

    /// 清除所有选择
    func clearSelection() {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedProject = nil
            selectedSidebar = nil
        }

        // Notify through NotificationCenter
        NotificationCenter.default.post(
            name: .projectSelectionChanged,
            object: nil,
            userInfo: [:]
        )
    }

    /// Handles graceful selection when a project is deleted
    private func handleDeletedProjectSelection() {
        Logger.appState.notice("Handling deleted project selection, reverting to All Activities")
        selectSpecialItem("All Activities")
    }

    /// Validates current selection and handles deleted projects
    /// Should be called when receiving project deletion notifications
    func validateCurrentSelection() {
        // This will be handled by notification observers
    }

    // MARK: - Timer Management (Delegated to TimerManager)

    /// Starts a timer with the specified parameters
    /// - Parameters:
    ///   - project: Optional project to associate with the timer
    ///   - title: Optional title for the timer session
    ///   - notes: Optional notes for the timer session
    ///   - createTimeEntry: Whether to create a time entry when the timer stops (defaults to global setting)
    func startTimer(project: Project? = nil, title: String? = nil, notes: String? = nil, createTimeEntry: Bool? = nil) {
        do {
            let targetProject = project ?? selectedProject
            let shouldCreateTimeEntry = createTimeEntry ?? automaticTimeEntryCreation
            
            // Update TimerManager's auto-create setting
            timerManager.autoCreateTimeEntry = shouldCreateTimeEntry
            
            try timerManager.startTimer(
                project: targetProject,
                title: title,
                notes: notes,
                estimatedDuration: timerManager.defaultEstimatedDuration
            )
            
            // Record activity for productivity tracking
            productivityGoalTracker.recordActivity()
            
            Logger.appState.info("Timer started for project: \(targetProject?.name ?? "None")")
        } catch {
            Logger.appState.error("Failed to start timer: \(error.localizedDescription)")
        }
    }

    /// Stops the active timer and optionally creates a time entry
    /// - Parameter createTimeEntry: Whether to create a time entry (overrides the default setting)
    func stopTimer(createTimeEntry: Bool? = nil) async {
        do {
            try await timerManager.stopTimer(createTimeEntry: createTimeEntry)
            
            // Update productivity progress after stopping timer
            productivityGoalTracker.updateProgress()
            
            Logger.appState.info("Timer stopped successfully")
        } catch {
            Logger.appState.error("Failed to stop timer: \(error.localizedDescription)")
        }
    }

    /// Gets the current timer duration
    /// - Returns: The duration since timer start, or 0 if no timer is active
    func getCurrentTimerDuration() -> TimeInterval {
        return timerManager.elapsedTime
    }

    /// Checks if the timer is active for a specific project
    /// - Parameter project: The project to check
    /// - Returns: True if the timer is active for the specified project
    func isTimerActive(for project: Project) -> Bool {
        guard let activeSession = timerManager.activeSession else { return false }
        return activeSession.projectId == project.id
    }
    
    /// Convenience property to check if any timer is active
    var isTimerActive: Bool {
        return timerManager.isRunning
    }

    /// 检查是否选择了特定的特殊项目
    func isSpecialItemSelected(_ item: String) -> Bool {
        return selectedSidebar == item && selectedProject == nil
    }

    /// 检查是否选择了特定的项目
    func isProjectSelected(_ project: Project) -> Bool {
        return selectedProject?.id == project.id && selectedSidebar == nil
    }

    // MARK: - Time Entry Selection Management

    /// Selects a time entry for detailed view or editing
    /// - Parameter timeEntry: The time entry to select
    func selectTimeEntry(_ timeEntry: TimeEntry) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedTimeEntry = timeEntry
        }

        Logger.appState.info("Selected time entry: \(timeEntry.title)")

        NotificationCenter.default.post(
            name: .timeEntrySelectionChanged,
            object: nil,
            userInfo: ["timeEntry": timeEntry]
        )
    }

    /// Clears the selected time entry
    func clearTimeEntrySelection() {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedTimeEntry = nil
        }

        NotificationCenter.default.post(
            name: .timeEntrySelectionChanged,
            object: nil,
            userInfo: [:]
        )
    }

    /// Sets the time entry filter project
    /// - Parameter project: The project to filter by, or nil for all projects
    func setTimeEntryFilterProject(_ project: Project?) {
        timeEntryFilterProject = project

        Logger.appState.info("Time entry filter project set to: \(project?.name ?? "All Projects")")

        NotificationCenter.default.post(
            name: .timeEntryFilterChanged,
            object: nil,
            userInfo: ["filterProject": project as Any]
        )
    }

    /// Sets the time entry filter date range
    /// - Parameter dateRange: The date range to filter by
    func setTimeEntryFilterDateRange(_ dateRange: DateInterval?) {
        timeEntryFilterDateRange = dateRange

        Logger.appState.info("Time entry filter date range set")

        NotificationCenter.default.post(
            name: .timeEntryFilterChanged,
            object: nil,
            userInfo: ["filterDateRange": dateRange as Any]
        )
    }

    /// Checks if a specific time entry is selected
    /// - Parameter timeEntry: The time entry to check
    /// - Returns: True if the time entry is selected
    func isTimeEntrySelected(_ timeEntry: TimeEntry) -> Bool {
        return selectedTimeEntry?.id == timeEntry.id
    }

    // MARK: - Notification Handlers

    /// Handles project change notifications from ProjectManager
    /// - Parameter notification: The notification containing project change information
    @objc private func handleProjectChange(_ notification: Notification) {
        validateCurrentSelection()

        if let userInfo = notification.userInfo,
           let projectCount = userInfo["projectCount"] as? Int,
           let timestamp = userInfo["timestamp"] as? Date
        {
            Logger.appState.debug("AppState received project change notification: \(projectCount) projects at \(timestamp, privacy: .public)")
        }
    }

    /// Handles project deletion notifications from ProjectManager
    /// - Parameter notification: The notification containing deleted project information
    @objc private func handleProjectDeleted(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedProjectId = userInfo["projectId"] as? String,
           selectedProject?.id == deletedProjectId
        {
            Logger.appState.notice("Selected project was deleted, clearing selection")
            clearSelection()
        }
    }

    /// Handles timer stop requests from other components
    /// - Parameter notification: The notification containing timer stop request information
    @objc private func handleTimerStopRequest(_ notification: Notification) {
        guard timerManager.isRunning else {
            return
        }

        if let userInfo = notification.userInfo {
            let createTimeEntry = userInfo["createTimeEntry"] as? Bool ?? false
            let reason = userInfo["reason"] as? String ?? "external_request"

            Logger.appState.info("Received timer stop request: \(reason)")

            Task {
                await stopTimer(createTimeEntry: createTimeEntry)
            }
        }
    }

    /// Handles time entry change notifications from TimeEntryManager
    /// - Parameter notification: The notification containing time entry change information
    @objc private func handleTimeEntryChange(_ notification: Notification) {
        Logger.appState.debug("AppState received time entry change notification")

        if let userInfo = notification.userInfo {
            if let operation = userInfo["operation"] as? String {
                Logger.appState.debug("Time entry operation: \(operation)")
            }

            if let timeEntryId = userInfo["timeEntryId"] as? String,
               let selectedId = selectedTimeEntry?.id.uuidString,
               timeEntryId == selectedId
            {
                // The selected time entry was modified, we might need to refresh it
                Logger.appState.debug("Selected time entry was modified")
            }
        }

        // Trigger UI updates by updating a published property
        objectWillChange.send()
    }

    /// Handles time entry deletion notifications from TimeEntryManager
    /// - Parameter notification: The notification containing deleted time entry information
    @objc private func handleTimeEntryDeleted(_ notification: Notification) {
        Logger.appState.debug("AppState received time entry deletion notification")

        if let userInfo = notification.userInfo,
           let deletedTimeEntryId = userInfo["timeEntryId"] as? String,
           let selectedId = selectedTimeEntry?.id.uuidString,
           deletedTimeEntryId == selectedId
        {
            Logger.appState.notice("Selected time entry was deleted, clearing selection")
            clearTimeEntrySelection()
        }

        // Trigger UI updates
        objectWillChange.send()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let projectSelectionChanged = Notification.Name("projectSelectionChanged")
    static let projectDidChange = Notification.Name("projectDidChange")
    static let projectOperationFailed = Notification.Name("projectOperationFailed")
    static let projectWasDeleted = Notification.Name("projectWasDeleted")
    static let timerShouldStop = Notification.Name("timerShouldStop")
    static let timeEntrySelectionChanged = Notification.Name("timeEntrySelectionChanged")
    static let timeEntryFilterChanged = Notification.Name("timeEntryFilterChanged")
}
