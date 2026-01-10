import Foundation
import Observation
import SwiftData
import SwiftUI

enum ActivityViewMode {
    case unified
    case chronological
}

@Observable
class AppState {
    var columnVisibility: NavigationSplitViewVisibility = .all
    var selectedProject: Project?
    var selectedSidebar: String? = "All Activities"
    var isTimerStarting: Bool = false

    // Timer Logic
    var isTimerActive: Bool = false
    var timerStartTime: Date?
    var defaultEstimatedDuration: TimeInterval = 7200
    var enableSounds: Bool = true
    
    // Timer Metadata
    private var timerProject: Project?
    private var timerTitle: String?
    private var timerNotes: String?
    
    // Activity View Mode
    var activityViewMode: ActivityViewMode = .unified

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



}
