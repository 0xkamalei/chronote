import os
import SwiftData
import SwiftUI

// App state only store gblobal UI state
class AppState: ObservableObject {
    @Published var selectedProject: Project?
    @Published var selectedSidebar: String? = "All Activities"
    @Published var isTimerStarting: Bool = false

    init() {
        selectedSidebar = "All Activities"
        selectedProject = nil
    }
}
