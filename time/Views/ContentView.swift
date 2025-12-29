
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
    @StateObject private var notificationManager = NotificationManager()

    @State private var searchText: String = ""
    @State private var isDatePickerExpanded: Bool = false
    @State private var selectedDateRange = AppDateRangePreset.today.dateRange
    @State private var selectedPreset: AppDateRangePreset? = .today
    
    // Timeline viewport state (defaults to selectedDateRange, but can be zoomed)
    @State private var timelineVisibleRange: ClosedRange<Date> = Date()...Date()

    // Debounced Viewport State
    @State private var debouncedVisibleRange: ClosedRange<Date> = Date()...Date()
    
    // Filtered activities based on debounced viewport
    private var viewportActivities: [Activity] {
        let start = debouncedVisibleRange.lowerBound
        let end = debouncedVisibleRange.upperBound
        return activityQueryManager.activities.filter { activity in
            // Keep activity if it overlaps with visible range
            // Overlap logic: (ActStart < ViewEnd) AND (ActEnd > ViewStart)
            let actEnd = activity.endTime ?? Date()
            return activity.startTime < end && actEnd > start
        }
    }

    private var activitiesView: some View {
        ActivityViewContainer(activities: viewportActivities)
    }

    private var detailView: some View {
        VStack(spacing: 0) {
            // Timeline Visualization
            if !activityQueryManager.activities.isEmpty {
                let start = min(selectedDateRange.startDate, selectedDateRange.endDate)
                let end = max(selectedDateRange.startDate, selectedDateRange.endDate)
                
                TimelineView(
                    activities: activityQueryManager.activities,
                    visibleTimeRange: $timelineVisibleRange,
                    totalTimeRange: start...end
                )
                .frame(height: 100) // Adjusted container height
                .padding(8) // Outer padding
                .zIndex(1) // Ensure Tooltip floats above the list below
                
                Divider()
            }
            
            activitiesView
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @State private var timelineDebounceTask: Task<Void, Never>?
    
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
        .toolbar {
            MainToolbarView(
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
            timelineVisibleRange = start...end
            debouncedVisibleRange = start...end
            
            // Sync initial sidebar filter
            activityQueryManager.setSidebarFilter(appState.selectedSidebar)
            
            activityManager.startTracking(modelContext: modelContext)
            
            // TODO: Initialize AutoClassificationService when Rules are back
            // AutoClassificationService.shared.loadRules(modelContext: modelContext)
            
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
            // Reset timeline zoom when global range changes
            timelineVisibleRange = start...end
            debouncedVisibleRange = start...end
            Logger.ui.debug("Date range changed: \(start, privacy: .public) - \(end, privacy: .public)")
        }
        .onChange(of: timelineVisibleRange) { _, newRange in
            // Debounce update to activities list to avoid lag
            timelineDebounceTask?.cancel()
            timelineDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                if !Task.isCancelled {
                    await MainActor.run {
                        self.debouncedVisibleRange = newRange
                    }
                }
            }
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
