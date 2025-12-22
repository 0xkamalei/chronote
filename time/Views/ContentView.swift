
import AppKit
import os
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var activityQueryManager = ActivityQueryManager.shared
    @StateObject private var activityManager = ActivityManager.shared
    @StateObject private var timeEntryManager = TimeEntryManager.shared
    @StateObject private var notificationManager = NotificationManager()

    @State private var searchText: String = ""
    @State private var isDatePickerExpanded: Bool = false
    @State private var selectedDateRange = AppDateRangePreset.today.dateRange
    @State private var selectedPreset: AppDateRangePreset? = .today

    @State private var isAddingTimeEntry: Bool = false

    private var activitiesView: some View {
        ActivityViewContainer(activities: activityQueryManager.activities)
    }

    private var detailView: some View {
        activitiesView
            .frame(minWidth: 600, minHeight: 400)
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: Bindable(appState).columnVisibility,
            sidebar: {
                SidebarView()
                    .accessibilityIdentifier("view.sidebar")
            },
            detail: {
                detailView
                    .accessibilityIdentifier("view.detail")
            }
        )
        .navigationSplitViewStyle(.balanced)
        .environmentObject(projectManager)
        .environmentObject(activityQueryManager)
        .environmentObject(activityManager)
        .environmentObject(timeEntryManager)
        .toolbar {
            MainToolbarView(
                isAddingTimeEntry: $isAddingTimeEntry,
                selectedDateRange: $selectedDateRange,
                selectedPreset: $selectedPreset,
                searchText: $searchText,
                modelContext: modelContext
            )
        }
        .onAppear {
            // Initialize managers with modelContext
            projectManager.setModelContext(modelContext)
            activityQueryManager.setModelContext(modelContext)
            
            // Sync initial date range
            let start = min(selectedDateRange.startDate, selectedDateRange.endDate)
            let end = max(selectedDateRange.startDate, selectedDateRange.endDate)
            let initialInterval = DateInterval(start: start, end: end)
            activityQueryManager.setDateRange(initialInterval)
            
            // Sync initial sidebar filter
            activityQueryManager.setSidebarFilter(appState.selectedSidebar)
            
            timeEntryManager.setModelContext(modelContext)
            activityManager.startTracking(modelContext: modelContext)
            
            // Initialize AutoClassificationService
            AutoClassificationService.shared.loadRules(modelContext: modelContext)
            
            // Allow TimeEntryManager to access ActivityManager if needed, or vice versa
            // For now, they are independent singletons initialized with context
            
            if !WindowMonitor.shared.checkAccessibilityPermissions() {
                Logger.ui.warning("Accessibility permissions missing. Window titles will not be tracked.")
            }
        }
        .onChange(of: appState.selectedProject) { _, newProject in
            activityQueryManager.setProjectFilter(newProject)
            Logger.ui.info("Project selection changed to: \(newProject?.name ?? "None", privacy: .public)")
        }
        .onChange(of: appState.selectedSidebar) { _, newSidebar in
            activityQueryManager.setSidebarFilter(newSidebar)
            Logger.ui.info("Sidebar selection changed to: \(newSidebar ?? "None", privacy: .public)")
        }
        .onChange(of: selectedDateRange) { _, newDateRange in
            // Ensure start date is before or equal to end date to avoid DateInterval crash
            let start = min(newDateRange.startDate, newDateRange.endDate)
            let end = max(newDateRange.startDate, newDateRange.endDate)
            let dateInterval = DateInterval(start: start, end: end)
            activityQueryManager.setDateRange(dateInterval)
            Logger.ui.debug("Date range changed: \(start, privacy: .public) - \(end, privacy: .public)")
        }
        .onChange(of: searchText) { _, newSearchText in
            activityQueryManager.setSearchText(newSearchText)
            Logger.ui.debug("Search text changed: \(newSearchText, privacy: .private)")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
