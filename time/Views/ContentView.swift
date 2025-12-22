
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

    @State private var isAddingProject: Bool = false
    @State private var isStartingTimer: Bool = false
    @State private var isAddingTimeEntry: Bool = false

    private var detailView: some View {
        Group {
            if appState.selectedSidebar == "Time Entries" {
                TimeEntryListView()
            } else {
                VStack(spacing: 0) {
                    TimelineView()
                    Divider()
                    ActivitiesView(activities: activityQueryManager.activities)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $isAddingProject) {
            EditProjectView(
                mode: .create,
                isPresented: $isAddingProject
            )
        }
        .sheet(isPresented: $isAddingTimeEntry) {
            NewTimeEntryView(isPresented: $isAddingTimeEntry)
        }
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
                isAddingProject: $isAddingProject,
                isStartingTimer: $isStartingTimer,
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
            let initialInterval = DateInterval(start: selectedDateRange.startDate, end: selectedDateRange.endDate)
            activityQueryManager.setDateRange(initialInterval)
            
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
            let dateInterval = DateInterval(start: newDateRange.startDate, end: newDateRange.endDate)
            activityQueryManager.setDateRange(dateInterval)
            Logger.ui.debug("Date range changed: \(newDateRange.startDate, privacy: .public) - \(newDateRange.endDate, privacy: .public)")
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
