
import AppKit
import os
import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var activityQueryManager = ActivityQueryManager.shared
    @StateObject private var activityManager = ActivityManager.shared
    @StateObject private var timeEntryManager = TimeEntryManager.shared
    @StateObject private var notificationManager = NotificationManager()

    @State private var searchText: String = ""
    @State private var isDatePickerExpanded: Bool = false
    @State private var selectedDateRange = AppDateRange(startDate: Date(), endDate: Date())
    @State private var selectedPreset: AppDateRangePreset?

    @State private var isAddingProject: Bool = false
    @State private var isStartingTimer: Bool = false
    @State private var isAddingTimeEntry: Bool = false

    private var detailView: some View {
        Group {
            if appState.selectedSidebar == "Time Entries" {
                TimeEntryListView()
            } else {
                VStack(spacing: 0) {
                    currentActivityStatusBar
                    filterStatusIndicator
                    TimelineView()
                    Divider()
                    ActivitiesView(activities: activityQueryManager.activities)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $isAddingProject) {
            EditProjectView(
                mode: .create(parentID: nil),
                isPresented: $isAddingProject
            )
        }
        .sheet(isPresented: $isAddingTimeEntry) {
            NewTimeEntryView(isPresented: $isAddingTimeEntry)
        }
    }

    @ViewBuilder
    private var currentActivityStatusBar: some View {
        if let currentActivity = activityManager.getCurrentActivity() {
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)

                Text("Currently tracking: \(currentActivity.appName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Duration: \(currentActivity.durationString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))

            Divider()
        }
    }

    @ViewBuilder
    private var filterStatusIndicator: some View {
        let filterDescription = activityQueryManager.getCurrentFilterDescription()
        if !filterDescription.isEmpty && filterDescription != "All Activities" {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.blue)
                    .font(.caption)

                Text("Filters: \(filterDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(activityQueryManager.activities.count) of \(activityQueryManager.totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))

            Divider()
        }
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: .constant(.all),
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
        .environmentObject(projectManager)
        .onAppear {
            // Initialize managers with modelContext
            projectManager.setModelContext(modelContext)
            activityQueryManager.setModelContext(modelContext)
            timeEntryManager.setModelContext(modelContext)
            appState.timerManager.setModelContext(modelContext)
            appState.timerManager.setNotificationManager(notificationManager)
            appState.idleRecoveryManager.setModelContext(modelContext)
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
        .sheet(isPresented: $appState.idleRecoveryManager.isShowingRecoveryDialog) {
            if let recovery = appState.idleRecoveryManager.pendingIdleRecovery {
                IdleRecoveryView(
                    idleStartTime: recovery.idleStartTime,
                    idleDuration: recovery.idleDuration,
                    onComplete: { action in
                        appState.idleRecoveryManager.processIdleRecoveryAction(action)
                    }
                )
                .interactiveDismissDisabled(true)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
