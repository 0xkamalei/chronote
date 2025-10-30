import os
import SwiftUI

struct TimeEntryListView: View {
    @StateObject private var timeEntryManager = TimeEntryManager.shared
    @StateObject private var projectManager = ProjectManager.shared
    @EnvironmentObject private var appState: AppState

    @State private var selectedProject: Project?
    @State private var selectedDateRange = DateInterval(start: Calendar.current.startOfDay(for: Date()), end: Date())
    @State private var searchText = ""
    @State private var showingEditTimeEntry = false
    @State private var editingTimeEntry: TimeEntry?
    @State private var showingDeleteConfirmation = false
    @State private var deletingTimeEntry: TimeEntry?
    @State private var showingNewTimeEntry = false

    // Pagination state
    @State private var paginatedEntries: [TimeEntry] = []
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    @State private var hasMoreEntries = true
    @State private var totalEntryCount = 0
    @State private var usePagination = false

    private let pageSize = 50
    private let paginationThreshold = 200 // Use pagination when more than 200 entries

    private let logger = Logger(subsystem: "com.time-vscode.TimeEntryListView", category: "UI")

    // MARK: - Computed Properties

    private var filteredTimeEntries: [TimeEntry] {
        if usePagination {
            return paginatedEntries
        }

        var entries = timeEntryManager.timeEntries

        // Filter by project if selected
        if let selectedProject = selectedProject {
            entries = entries.filter { $0.projectId == selectedProject.id }
        }

        // Filter by date range
        entries = entries.filter { entry in
            entry.startTime >= selectedDateRange.start && entry.endTime <= selectedDateRange.end
        }

        // Filter by search text
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.title.localizedCaseInsensitiveContains(searchText) ||
                    entry.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                    getProjectName(for: entry.projectId).localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries.sorted { $0.startTime > $1.startTime }
    }

    private var totalDuration: TimeInterval {
        filteredTimeEntries.reduce(0) { $0 + $1.calculatedDuration }
    }

    private var formattedTotalDuration: String {
        let totalMinutes = Int(totalDuration / 60)

        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }

    private var displayedEntryCount: String {
        if usePagination {
            return "\(paginatedEntries.count) of \(totalEntryCount)"
        } else {
            return "\(filteredTimeEntries.count)"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerView
            filtersView

            if timeEntryManager.isLoading {
                loadingView
            } else if filteredTimeEntries.isEmpty {
                emptyStateView
            } else {
                timeEntryList
            }
        }
        .navigationTitle("Time Entries")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Entry") {
                    showingNewTimeEntry = true
                }
                .accessibilityIdentifier("timeEntries.newEntryButton")
            }
        }
        .sheet(isPresented: $showingNewTimeEntry) {
            NewTimeEntryView(isPresented: $showingNewTimeEntry)
        }
        .sheet(isPresented: $showingEditTimeEntry) {
            if let editingTimeEntry = editingTimeEntry {
                EditTimeEntryView(
                    isPresented: $showingEditTimeEntry,
                    timeEntry: editingTimeEntry
                )
            }
        }
        .alert("Delete Time Entry", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                deletingTimeEntry = nil
            }
            Button("Delete", role: .destructive) {
                if let timeEntry = deletingTimeEntry {
                    deleteTimeEntry(timeEntry)
                }
            }
        } message: {
            if let timeEntry = deletingTimeEntry {
                Text("Are you sure you want to delete \"\(timeEntry.title)\"? This action cannot be undone.")
            }
        }
        .onAppear {
            setupInitialDateRange()
            checkIfPaginationNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryDidChange)) { _ in
            logger.debug("TimeEntryListView received time entry change notification")

            // Refresh the list when time entries change
            if usePagination {
                Task {
                    await refreshPaginatedEntries()
                }
            }

            // Check if pagination threshold changed
            checkIfPaginationNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryWasDeleted)) { _ in
            logger.debug("TimeEntryListView received time entry deletion notification")

            // Refresh the list when time entries are deleted
            if usePagination {
                Task {
                    await refreshPaginatedEntries()
                }
            }

            // Check if pagination threshold changed
            checkIfPaginationNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryFilterChanged)) { notification in
            logger.debug("TimeEntryListView received filter change notification")

            // Update local filters based on AppState
            if let userInfo = notification.userInfo {
                if let filterProject = userInfo["filterProject"] as? Project {
                    selectedProject = filterProject
                } else if userInfo["filterProject"] != nil {
                    selectedProject = nil
                }

                if let filterDateRange = userInfo["filterDateRange"] as? DateInterval {
                    selectedDateRange = filterDateRange
                }
            }
        }
        .onChange(of: selectedProject) { _ in
            resetPagination()
        }
        .onChange(of: selectedDateRange) { _ in
            resetPagination()
        }
        .onChange(of: searchText) { _ in
            resetPagination()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Entries")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("timeEntries.header.title")

                HStack {
                    Text("\(displayedEntryCount) entries • \(formattedTotalDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("timeEntries.header.countAndDuration")

                    if usePagination && isLoadingMore {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Filters View

    private var filtersView: some View {
        VStack(spacing: 8) {
            HStack {
                // Project filter
                Menu {
                    Button("All Projects") {
                        selectedProject = nil
                    }

                    Divider()

                    ForEach(projectManager.projects.sorted { $0.name < $1.name }) { project in
                        Button(project.name) {
                            selectedProject = project
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(selectedProject?.name ?? "All Projects")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timeEntries.filter.projectMenu")

                Spacer()

                // Date range picker
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { selectedDateRange.start },
                        set: { newStart in
                            selectedDateRange = DateInterval(start: newStart, end: selectedDateRange.end)
                        }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .accessibilityIdentifier("timeEntries.filter.startDate")

                Text("to")
                    .foregroundColor(.secondary)

                DatePicker(
                    "End Date",
                    selection: Binding(
                        get: { selectedDateRange.end },
                        set: { newEnd in
                            selectedDateRange = DateInterval(start: selectedDateRange.start, end: newEnd)
                        }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .accessibilityIdentifier("timeEntries.filter.endDate")
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search time entries...", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("timeEntries.filter.searchField")

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .accessibilityIdentifier("timeEntries.filter.clearButton")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("timeEntries.filter.searchContainer")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .accessibilityIdentifier("timeEntries.filters")
    }

    // MARK: - Time Entry List

    private var timeEntryList: some View {
        List {
            ForEach(filteredTimeEntries) { timeEntry in
                TimeEntryRowView(
                    timeEntry: timeEntry,
                    projectName: getProjectName(for: timeEntry.projectId),
                    projectColor: getProjectColor(for: timeEntry.projectId),
                    onEdit: {
                        editingTimeEntry = timeEntry
                        showingEditTimeEntry = true
                    },
                    onDelete: {
                        deletingTimeEntry = timeEntry
                        showingDeleteConfirmation = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .accessibilityIdentifier("timeEntries.row.\(timeEntry.id)")
                .onAppear {
                    // Load more entries when approaching the end of the list
                    if usePagination && timeEntry == filteredTimeEntries.last {
                        loadMoreEntriesIfNeeded()
                    }
                }
            }

            // Load more button for pagination
            if usePagination && hasMoreEntries && !isLoadingMore {
                Button("Load More Entries") {
                    loadMoreEntries()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.blue)
            }

            if usePagination && isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView("Loading more entries...")
                        .padding()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("timeEntries.list")
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading time entries...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Time Entries Found")
                    .font(.headline)

                Text("Create your first time entry to start tracking your work.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Create Time Entry") {
                showingNewTimeEntry = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Methods

    private func getProjectName(for projectId: String?) -> String {
        guard let projectId = projectId,
              let project = projectManager.getProject(by: projectId)
        else {
            return "Unassigned"
        }
        return project.name
    }

    private func getProjectColor(for projectId: String?) -> Color {
        guard let projectId = projectId,
              let project = projectManager.getProject(by: projectId)
        else {
            return .gray
        }
        return project.color
    }

    private func setupInitialDateRange() {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        selectedDateRange = DateInterval(start: startOfWeek, end: today)
    }

    private func deleteTimeEntry(_ timeEntry: TimeEntry) {
        Task {
            do {
                try await timeEntryManager.deleteTimeEntry(timeEntry)
                logger.info("Successfully deleted time entry: \(timeEntry.title)")

                // Refresh pagination if needed
                if usePagination {
                    await refreshPaginatedEntries()
                }
            } catch {
                logger.error("Failed to delete time entry: \(error.localizedDescription)")
                // TODO: Show error alert to user
            }
        }
        deletingTimeEntry = nil
    }

    // MARK: - Pagination Methods

    private func checkIfPaginationNeeded() {
        Task {
            do {
                let count = try await timeEntryManager.getTimeEntryCount(
                    projectId: selectedProject?.id,
                    startDate: selectedDateRange.start,
                    endDate: selectedDateRange.end
                )

                await MainActor.run {
                    totalEntryCount = count
                    usePagination = count > paginationThreshold

                    if usePagination {
                        loadInitialPaginatedEntries()
                    }
                }
            } catch {
                logger.error("Failed to check entry count: \(error.localizedDescription)")
            }
        }
    }

    private func loadInitialPaginatedEntries() {
        Task {
            do {
                let entries = try await timeEntryManager.loadTimeEntriesPaginated(
                    offset: 0,
                    limit: pageSize,
                    projectId: selectedProject?.id,
                    startDate: selectedDateRange.start,
                    endDate: selectedDateRange.end
                )

                await MainActor.run {
                    paginatedEntries = entries
                    currentPage = 0
                    hasMoreEntries = entries.count == pageSize
                }
            } catch {
                logger.error("Failed to load initial paginated entries: \(error.localizedDescription)")
            }
        }
    }

    private func loadMoreEntries() {
        guard !isLoadingMore, hasMoreEntries else { return }

        isLoadingMore = true

        Task {
            do {
                let nextPage = currentPage + 1
                let entries = try await timeEntryManager.loadTimeEntriesPaginated(
                    offset: nextPage * pageSize,
                    limit: pageSize,
                    projectId: selectedProject?.id,
                    startDate: selectedDateRange.start,
                    endDate: selectedDateRange.end
                )

                await MainActor.run {
                    paginatedEntries.append(contentsOf: entries)
                    currentPage = nextPage
                    hasMoreEntries = entries.count == pageSize
                    isLoadingMore = false
                }
            } catch {
                logger.error("Failed to load more entries: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingMore = false
                }
            }
        }
    }

    private func loadMoreEntriesIfNeeded() {
        // Auto-load more entries when user scrolls near the end
        let remainingEntries = paginatedEntries.count - (currentPage + 1) * pageSize
        if remainingEntries < 10, hasMoreEntries, !isLoadingMore {
            loadMoreEntries()
        }
    }

    private func resetPagination() {
        currentPage = 0
        paginatedEntries = []
        hasMoreEntries = true
        isLoadingMore = false

        if usePagination {
            checkIfPaginationNeeded()
        }
    }

    private func refreshPaginatedEntries() async {
        do {
            let entries = try await timeEntryManager.loadTimeEntriesPaginated(
                offset: 0,
                limit: (currentPage + 1) * pageSize,
                projectId: selectedProject?.id,
                startDate: selectedDateRange.start,
                endDate: selectedDateRange.end
            )

            await MainActor.run {
                paginatedEntries = entries
                hasMoreEntries = entries.count == (currentPage + 1) * pageSize
            }
        } catch {
            logger.error("Failed to refresh paginated entries: \(error.localizedDescription)")
        }
    }
}

// MARK: - Time Entry Row View

struct TimeEntryRowView: View {
    let timeEntry: TimeEntry
    let projectName: String
    let projectColor: Color
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var appState: AppState

    private var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timeEntry.startTime)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timeEntry.startTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Project indicator
                Circle()
                    .fill(projectColor)
                    .frame(width: 8, height: 8)

                Text(projectName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeEntry.title)
                        .font(.headline)
                        .lineLimit(2)

                    if let notes = timeEntry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(formattedStartTime) • \(timeEntry.durationString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Edit time entry")
                    .accessibilityIdentifier("timeEntries.row.editButton.\(timeEntry.id)")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete time entry")
                    .accessibilityIdentifier("timeEntries.row.deleteButton.\(timeEntry.id)")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            appState.isTimeEntrySelected(timeEntry) ?
                Color.accentColor.opacity(0.1) : Color.clear
        )
        .onTapGesture {
            if appState.isTimeEntrySelected(timeEntry) {
                appState.clearTimeEntrySelection()
            } else {
                appState.selectTimeEntry(timeEntry)
            }
        }
        .accessibilityIdentifier("timeEntries.row.container.\(timeEntry.id)")
    }
}

#Preview {
    TimeEntryListView()
        .environmentObject(AppState())
}
