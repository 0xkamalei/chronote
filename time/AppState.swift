import SwiftData
import SwiftUI
import os

@MainActor
class AppState: ObservableObject {
    // Core managers
    @Published var timerManager: TimerManager = .init()

    @Published var selectedProject: Project?
    @Published var selectedSidebar: String? = "All Activities"

    // Time entry selection
    @Published var selectedTimeEntry: TimeEntry?
    @Published var timeEntryFilterProject: Project?
    @Published var timeEntryFilterDateRange: DateInterval?

    init() {
        selectedSidebar = "All Activities"
        selectedProject = nil
        setupNotificationObservers()
    }

    /// Sets the model context for managers that need it
    func setModelContext(_ context: ModelContext) {
        timerManager.setModelContext(context)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Sets up notification observers for project change events
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProjectDeleted(_:)),
            name: .projectWasDeleted,
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
    }

    /// 选择项目
    func selectProject(_ project: Project) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedSidebar = nil
            selectedProject = project
        }

        // Notify through NotificationCenter
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

        NotificationCenter.default.post(
            name: .projectSelectionChanged,
            object: nil,
            userInfo: [:]
        )
    }

    /// 检查是否选择了特定的特殊项目
    func isSpecialItemSelected(_ item: String) -> Bool {
        return selectedSidebar == item && selectedProject == nil
    }

    /// 检查是否选择了特定的项目
    func isProjectSelected(_ project: Project) -> Bool {
        return selectedProject?.id == project.id && selectedSidebar == nil
    }

    // MARK: - Timer Management

    func startTimer(project: Project? = nil, title: String? = nil, notes: String? = nil) {
        do {
            let targetProject = project ?? selectedProject
            try timerManager.startTimer(
                project: targetProject,
                title: title,
                notes: notes,
                estimatedDuration: timerManager.defaultEstimatedDuration
            )
        } catch {
            Logger.appState.error("Failed to start timer: \(error.localizedDescription)")
        }
    }

    func stopTimer() async {
        do {
            try await timerManager.stopTimer()
        } catch {
            Logger.appState.error("Failed to stop timer: \(error.localizedDescription)")
        }
    }

    var isTimerActive: Bool {
        return timerManager.isRunning
    }

    // MARK: - Time Entry Selection Management

    func selectTimeEntry(_ timeEntry: TimeEntry) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedTimeEntry = timeEntry
        }
    }

    func clearTimeEntrySelection() {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedTimeEntry = nil
        }
    }

    func isTimeEntrySelected(_ timeEntry: TimeEntry) -> Bool {
        return selectedTimeEntry?.id == timeEntry.id
    }

    // MARK: - Notification Handlers

    @objc private func handleProjectDeleted(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedProjectId = userInfo["projectId"] as? String,
           selectedProject?.id == deletedProjectId
        {
            clearSelection()
        }
    }

    @objc private func handleTimeEntryDeleted(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedTimeEntryId = userInfo["timeEntryId"] as? String,
           let selectedId = selectedTimeEntry?.id.uuidString,
           deletedTimeEntryId == selectedId
        {
            clearTimeEntrySelection()
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let projectSelectionChanged = Notification.Name("projectSelectionChanged")
    static let projectDidChange = Notification.Name("projectDidChange")
    static let projectWasDeleted = Notification.Name("projectWasDeleted")
    static let timeEntrySelectionChanged = Notification.Name("timeEntrySelectionChanged")
    static let timeEntryWasDeleted = Notification.Name("timeEntryWasDeleted")
}
