import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
class AppState {
    var columnVisibility: NavigationSplitViewVisibility = .all
    var selectedProject: Project?
    var selectedSidebar: String? = "All Activities"
    var isTimerStarting: Bool = false
    var selectedTimeEntryId: UUID?

    // Timer Logic
    var isTimerActive: Bool = false
    var timerStartTime: Date?
    var defaultEstimatedDuration: TimeInterval = 7200
    var enableSounds: Bool = true
    
    // Timer Metadata
    private var timerProject: Project?
    private var timerTitle: String?
    private var timerNotes: String?

    init() {
        // Properties initialized with default values
    }

    func clearSelection() {
        selectedProject = nil
    }

    func selectProject(_ project: Project?) {
        selectedProject = project
        selectedSidebar = nil // Clear sidebar selection when project is selected
    }

    func isProjectSelected(_ project: Project) -> Bool {
        return selectedProject?.id == project.id
    }
    
    func validateCurrentSelection() {
        if selectedProject != nil {
            selectedSidebar = nil
        }
    }
    
    func selectSpecialItem(_ item: String) {
        selectedSidebar = item
        selectedProject = nil
    }
    
    func isSpecialItemSelected(_ item: String) -> Bool {
        return selectedSidebar == item && selectedProject == nil
    }

    // MARK: - Time Entry Selection

    func selectTimeEntry(_ timeEntry: TimeEntry?) {
        selectedTimeEntryId = timeEntry?.id
    }

    func isTimeEntrySelected(_ timeEntry: TimeEntry) -> Bool {
        return selectedTimeEntryId == timeEntry.id
    }
    
    func clearTimeEntrySelection() {
        selectedTimeEntryId = nil
    }

    // MARK: - Timer Logic

    @MainActor
    func startTimer(project: Project? = nil, title: String? = nil, notes: String? = nil) {
        isTimerActive = true
        timerStartTime = Date()
        self.timerProject = project
        self.timerTitle = title
        self.timerNotes = notes
        isTimerStarting = false 
    }
    
    @MainActor
    func stopTimer() async {
        guard let startTime = timerStartTime else {
            isTimerActive = false
            return
        }
        
        let endTime = Date()
        isTimerActive = false
        timerStartTime = nil
        
        do {
            _ = try await TimeEntryManager.shared.createFromTimer(
                project: timerProject ?? selectedProject,
                startTime: startTime,
                endTime: endTime,
                title: timerTitle,
                notes: timerNotes
            )
        } catch {
             print("Failed to stop timer and create entry: \(error)")
        }
        
        // Reset metadata
        timerProject = nil
        timerTitle = nil
        timerNotes = nil
    }
}
