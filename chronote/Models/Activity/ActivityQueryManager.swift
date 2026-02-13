import Foundation
import os.log
import SwiftData
import SwiftUI

@MainActor
class ActivityQueryManager: ObservableObject {
    static let shared = ActivityQueryManager()

    @Published var activities: [ActivitySnapshot] = []
    @Published var isLoading = false
    @Published var totalCount = 0

    private var modelContainer: ModelContainer?
    private let logger = Logger(subsystem: "com.time-vscode.ActivityQueryManager", category: "QueryManagement")

    private var currentDateRange: DateInterval?
    private var currentSearchText = ""
    private var currentProjectId: String?
    private var currentProjectName: String?
    private var currentSidebarFilter: String?

    private var refreshTask: Task<Void, Never>?
    private var latestRefreshRequestID: UInt64 = 0

    private let searchDebounceNanoseconds: UInt64 = 250_000_000

    private init() {
        logger.info("ActivityQueryManager initialized")
    }

    deinit {
        refreshTask?.cancel()
    }

    func setModelContext(_ context: ModelContext) {
        modelContainer = context.container
        scheduleRefresh()
    }

    func setDateRange(_ range: DateInterval?) {
        if let currentRange = currentDateRange, let newRange = range {
            if currentRange.start == newRange.start && currentRange.end == newRange.end {
                return
            }
        } else if currentDateRange == nil && range == nil {
            return
        }

        currentDateRange = range
        scheduleRefresh()
    }

    func setSearchText(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentSearchText != trimmedText else { return }
        currentSearchText = trimmedText
        scheduleRefresh(debounceNanoseconds: searchDebounceNanoseconds)
    }

    func setProjectFilter(_ project: Project?) {
        let projectId = project?.id
        guard currentProjectId != projectId else { return }
        currentProjectId = projectId
        currentProjectName = project?.name
        currentSidebarFilter = nil
        scheduleRefresh()
    }

    func setSidebarFilter(_ filter: String?) {
        guard currentSidebarFilter != filter else { return }
        currentSidebarFilter = filter
        currentProjectId = nil
        currentProjectName = nil
        scheduleRefresh()
    }

    func refreshActivities() async {
        let requestID = nextRequestID()
        refreshTask?.cancel()
        await performRefresh(filters: makeFilters(), requestID: requestID)
    }

    func assignProject(
        activityIDs: [UUID],
        to project: Project?,
        using context: ModelContext
    ) throws {
        guard !activityIDs.isEmpty else { return }

        let targetProjectId = project?.id
        let targetIds = Set(activityIDs)
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate<Activity> { activity in
                targetIds.contains(activity.id)
            }
        )

        let matchedActivities = try context.fetch(descriptor)
        for activity in matchedActivities {
            activity.projectId = targetProjectId
        }
        try context.save()

        scheduleRefresh()
    }

    func getCurrentFilterDescription() -> String {
        var components: [String] = []

        if let dateRange = currentDateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            components.append("Date: \(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))")
        }

        if !currentSearchText.isEmpty {
            components.append("Search: \"\(currentSearchText)\"")
        }

        if let projectName = currentProjectName {
            components.append("Project: \(projectName)")
        }

        if let sidebar = currentSidebarFilter {
            components.append("Filter: \(sidebar)")
        }

        return components.isEmpty ? "All Activities" : components.joined(separator: ", ")
    }

    private func scheduleRefresh(debounceNanoseconds: UInt64 = 0) {
        guard modelContainer != nil else { return }

        let requestID = nextRequestID()
        let filters = makeFilters()
        refreshTask?.cancel()

        refreshTask = Task { [weak self] in
            guard let self else { return }
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await self.performRefresh(filters: filters, requestID: requestID)
        }
    }

    private func nextRequestID() -> UInt64 {
        latestRefreshRequestID &+= 1
        return latestRefreshRequestID
    }

    private func makeFilters() -> QueryFilters {
        QueryFilters(
            dateRange: currentDateRange,
            searchText: currentSearchText,
            projectId: currentProjectId,
            sidebarFilter: currentSidebarFilter
        )
    }

    private func performRefresh(filters: QueryFilters, requestID: UInt64) async {
        guard let modelContainer else {
            logger.error("ModelContainer not set")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshots = try await Task.detached(priority: .userInitiated) {
                try Self.fetchSnapshots(container: modelContainer, filters: filters)
            }.value

            guard !Task.isCancelled else { return }
            guard requestID == latestRefreshRequestID else { return }

            activities = snapshots
            totalCount = snapshots.count
            logger.info("Refreshed activities: \(snapshots.count) loaded")
        } catch {
            guard requestID == latestRefreshRequestID else { return }
            logger.error("Failed to refresh activities: \(error.localizedDescription)")
            activities = []
            totalCount = 0
        }
    }

    nonisolated private static func fetchSnapshots(
        container: ModelContainer,
        filters: QueryFilters
    ) throws -> [ActivitySnapshot] {
        let context = ModelContext(container)
        let descriptor = buildFetchDescriptor(filters: filters)
        let fetchedActivities = try context.fetch(descriptor)
        let capturedAt = Date()
        let snapshots = fetchedActivities.map { ActivitySnapshot(from: $0, capturedAt: capturedAt) }
        return applyInMemorySearch(snapshots, searchText: filters.searchText)
    }

    nonisolated private static func applyInMemorySearch(
        _ activities: [ActivitySnapshot],
        searchText: String
    ) -> [ActivitySnapshot] {
        guard !searchText.isEmpty else { return activities }
        return activities.filter { $0.appName.localizedStandardContains(searchText) }
    }

    nonisolated private static func buildFetchDescriptor(filters: QueryFilters) -> FetchDescriptor<Activity> {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\Activity.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = adaptiveFetchLimit(for: filters.dateRange)

        if let range = filters.dateRange {
            let start = range.start
            let end = range.end

            if let projectId = filters.projectId {
                descriptor.predicate = #Predicate<Activity> { activity in
                    if let aid = activity.projectId {
                        return activity.startTime >= start && activity.startTime < end && aid == projectId
                    } else {
                        return false
                    }
                }
            } else if filters.sidebarFilter == "Unassigned" {
                descriptor.predicate = #Predicate<Activity> { activity in
                    activity.startTime >= start && activity.startTime < end && activity.projectId == nil
                }
            } else if filters.sidebarFilter == "My Projects" {
                descriptor.predicate = #Predicate<Activity> { activity in
                    activity.startTime >= start && activity.startTime < end && activity.projectId != nil
                }
            } else {
                descriptor.predicate = #Predicate<Activity> { activity in
                    activity.startTime >= start && activity.startTime < end
                }
            }
        } else if let projectId = filters.projectId {
            descriptor.predicate = #Predicate<Activity> { activity in
                if let aid = activity.projectId {
                    return aid == projectId
                } else {
                    return false
                }
            }
        }

        return descriptor
    }

    nonisolated private static func adaptiveFetchLimit(for dateRange: DateInterval?) -> Int? {
        guard let dateRange else { return 50_000 }
        let dayCount = max(1, Int(dateRange.duration / 86_400))

        if dayCount <= 2 {
            return nil
        }
        if dayCount <= 7 {
            return 30_000
        }
        if dayCount <= 31 {
            return 50_000
        }
        return 80_000
    }
}

private struct QueryFilters: Sendable {
    let dateRange: DateInterval?
    let searchText: String
    let projectId: String?
    let sidebarFilter: String?
}
