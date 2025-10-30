import Foundation
import os.log
import SwiftData
import SwiftUI

@MainActor
class TimelineViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var timelineScale: CGFloat = 1.0
    @Published var timeScale: TimeScale = .hours
    @Published var selectedDateRange: DateInterval
    @Published var activities: [Activity] = []
    @Published var timeEntries: [TimeEntry] = []
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: TimelineError?

    // MARK: - Private Properties

    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.time-vscode.TimelineViewModel", category: "Timeline")
    private var dataCache: [String: Any] = [:]
    private var lastRefreshTime: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init(selectedDate: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        selectedDateRange = DateInterval(start: startOfDay, end: endOfDay)

        logger.info("TimelineViewModel initialized for date: \(selectedDate)")
    }

    // MARK: - Public Methods

    /// Set the model context and trigger initial data load
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        Task {
            await refreshData()
        }
    }

    /// Update the selected date range and refresh data
    func setDateRange(_ range: DateInterval) {
        guard selectedDateRange != range else { return }

        selectedDateRange = range
        clearCache()

        Task {
            await refreshData()
        }

        logger.info("Date range updated: \(range.start) to \(range.end)")
    }

    /// Zoom the timeline by the specified scale factor
    func zoomTimeline(scale: CGFloat) {
        let clampedScale = max(0.1, min(5.0, scale))
        guard timelineScale != clampedScale else { return }

        timelineScale = clampedScale

        // Auto-adjust time scale based on zoom level
        updateTimeScaleForZoom(clampedScale)

        logger.debug("Timeline scale updated to: \(clampedScale)")
    }

    /// Set the time scale (hours, days, weeks)
    func setTimeScale(_ scale: TimeScale) {
        guard timeScale != scale else { return }

        timeScale = scale
        adjustDateRangeForTimeScale()

        Task {
            await refreshData()
        }

        logger.info("Time scale updated to: \(scale.rawValue)")
    }

    private func updateTimeScaleForZoom(_ scale: CGFloat) {
        let newTimeScale: TimeScale

        if scale >= 2.0 {
            newTimeScale = .hours
        } else if scale >= 0.5 {
            newTimeScale = .days
        } else {
            newTimeScale = .weeks
        }

        if newTimeScale != timeScale {
            timeScale = newTimeScale
            adjustDateRangeForTimeScale()
        }
    }

    private func adjustDateRangeForTimeScale() {
        let calendar = Calendar.current
        let currentStart = selectedDateRange.start

        let newRange: DateInterval

        switch timeScale {
        case .hours:
            // Show single day
            let startOfDay = calendar.startOfDay(for: currentStart)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            newRange = DateInterval(start: startOfDay, end: endOfDay)

        case .days:
            // Show week
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: currentStart)?.start ?? currentStart
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? startOfWeek
            newRange = DateInterval(start: startOfWeek, end: endOfWeek)

        case .weeks:
            // Show month
            let startOfMonth = calendar.dateInterval(of: .month, for: currentStart)?.start ?? currentStart
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? startOfMonth
            newRange = DateInterval(start: startOfMonth, end: endOfMonth)
        }

        if newRange != selectedDateRange {
            selectedDateRange = newRange
            clearCache()
        }
    }

    /// Select a specific time range on the timeline
    func selectTimeRange(start: Date, end: Date) {
        let newRange = DateInterval(start: start, end: end)
        setDateRange(newRange)
    }

    /// Create a new time entry at the specified time range
    func createTimeEntryAt(startTime: Date, endTime: Date) -> TimeEntry {
        let timeEntry = TimeEntry(
            title: "New Entry",
            startTime: startTime,
            endTime: endTime
        )

        logger.info("Created new time entry: \(startTime) to \(endTime)")
        return timeEntry
    }

    /// Assign an activity to a project
    func assignActivityToProject(activity: Activity, project: Project) async {
        guard modelContext != nil else {
            logger.error("No model context available for activity assignment")
            return
        }

        // Note: This is a placeholder implementation
        // In a full implementation, we would need to create a relationship
        // between activities and projects, possibly through a separate model

        logger.info("Assigned activity '\(activity.appName)' to project '\(project.name)'")

        // Refresh data to reflect changes
        await refreshData()
    }

    /// Update time entry duration by resizing
    func updateTimeEntryDuration(timeEntry: TimeEntry, newStartTime: Date, newEndTime: Date) async {
        guard let context = modelContext else {
            logger.error("No model context available for time entry update")
            return
        }

        do {
            timeEntry.startTime = newStartTime
            timeEntry.endTime = newEndTime
            timeEntry.duration = newEndTime.timeIntervalSince(newStartTime)
            timeEntry.markAsUpdated()

            try context.save()

            logger.info("Updated time entry duration: \(timeEntry.title)")

            // Refresh data to reflect changes
            await refreshData()

        } catch {
            logger.error("Failed to update time entry duration: \(error)")
            self.error = .assignmentFailed(error)
        }
    }

    /// Create a new time entry and save it
    func saveTimeEntry(_ timeEntry: TimeEntry) async {
        guard let context = modelContext else {
            logger.error("No model context available for time entry save")
            return
        }

        do {
            context.insert(timeEntry)
            try context.save()

            logger.info("Saved new time entry: \(timeEntry.title)")

            // Refresh data to reflect changes
            await refreshData()

        } catch {
            logger.error("Failed to save time entry: \(error)")
            self.error = .assignmentFailed(error)
        }
    }

    /// Delete a time entry
    func deleteTimeEntry(_ timeEntry: TimeEntry) async {
        guard let context = modelContext else {
            logger.error("No model context available for time entry deletion")
            return
        }

        do {
            context.delete(timeEntry)
            try context.save()

            logger.info("Deleted time entry: \(timeEntry.title)")

            // Refresh data to reflect changes
            await refreshData()

        } catch {
            logger.error("Failed to delete time entry: \(error)")
            self.error = .assignmentFailed(error)
        }
    }

    /// Batch assign multiple activities to a project
    func batchAssignActivitiesToProject(activities: [Activity], project: Project) async {
        guard modelContext != nil else {
            logger.error("No model context available for batch assignment")
            return
        }

        // Note: This is a placeholder implementation
        // In a full implementation, we would batch update the relationships

        logger.info("Batch assigned \(activities.count) activities to project '\(project.name)'")

        // Refresh data to reflect changes
        await refreshData()
    }

    /// Refresh all timeline data
    func refreshData() async {
        guard let context = modelContext else {
            logger.error("No model context available for data refresh")
            return
        }

        isLoading = true
        error = nil

        do {
            // Check cache first
            if let cachedData = getCachedData(), !shouldRefreshCache() {
                logger.debug("Using cached timeline data")
                applyCache(cachedData)
                isLoading = false
                return
            }

            // Fetch activities for the selected date range
            let activitiesData = try await fetchActivities(context: context)

            // Fetch time entries for the selected date range
            let timeEntriesData = try await fetchTimeEntries(context: context)

            // Fetch all projects (needed for assignment operations)
            let projectsData = try await fetchProjects(context: context)

            // Update published properties
            activities = activitiesData
            timeEntries = timeEntriesData
            projects = projectsData

            // Cache the data
            cacheData(activities: activitiesData, timeEntries: timeEntriesData, projects: projectsData)

            lastRefreshTime = Date()

            logger.info("Timeline data refreshed: \(activitiesData.count) activities, \(timeEntriesData.count) time entries, \(projectsData.count) projects")

        } catch {
            logger.error("Failed to refresh timeline data: \(error)")
            self.error = .dataLoadFailed(error)
        }

        isLoading = false
    }

    // MARK: - Data Fetching Methods

    private func fetchActivities(context: ModelContext) async throws -> [Activity] {
        let startDate = selectedDateRange.start
        let endDate = selectedDateRange.end

        let predicate = #Predicate<Activity> { activity in
            activity.startTime >= startDate && activity.startTime < endDate
        }

        var descriptor = FetchDescriptor<Activity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Activity.startTime, order: .forward)]
        )

        // Limit to reasonable number for performance
        descriptor.fetchLimit = 1000

        return try context.fetch(descriptor)
    }

    private func fetchTimeEntries(context: ModelContext) async throws -> [TimeEntry] {
        let startDate = selectedDateRange.start
        let endDate = selectedDateRange.end

        let predicate = #Predicate<TimeEntry> { entry in
            entry.startTime >= startDate && entry.startTime < endDate
        }

        var descriptor = FetchDescriptor<TimeEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\TimeEntry.startTime, order: .forward)]
        )

        descriptor.fetchLimit = 500

        return try context.fetch(descriptor)
    }

    private func fetchProjects(context: ModelContext) async throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\Project.sortOrder, order: .forward)]
        )

        return try context.fetch(descriptor)
    }

    // MARK: - Caching Methods

    private func getCachedData() -> TimelineCacheData? {
        let cacheKey = cacheKeyForDateRange(selectedDateRange)
        return dataCache[cacheKey] as? TimelineCacheData
    }

    private func cacheData(activities: [Activity], timeEntries: [TimeEntry], projects: [Project]) {
        let cacheKey = cacheKeyForDateRange(selectedDateRange)
        let cacheData = TimelineCacheData(
            activities: activities,
            timeEntries: timeEntries,
            projects: projects,
            timestamp: Date()
        )
        dataCache[cacheKey] = cacheData
    }

    private func applyCache(_ cacheData: TimelineCacheData) {
        activities = cacheData.activities
        timeEntries = cacheData.timeEntries
        projects = cacheData.projects
    }

    private func shouldRefreshCache() -> Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > cacheTimeout
    }

    private func clearCache() {
        dataCache.removeAll()
        lastRefreshTime = nil
    }

    private func cacheKeyForDateRange(_ range: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: range.start))_\(formatter.string(from: range.end))"
    }

    // MARK: - Utility Methods

    /// Get activities grouped by hour for timeline display
    func getActivitiesByHour() -> [Int: [Activity]] {
        let calendar = Calendar.current
        var groupedActivities: [Int: [Activity]] = [:]

        for activity in activities {
            let hour = calendar.component(.hour, from: activity.startTime)
            if groupedActivities[hour] == nil {
                groupedActivities[hour] = []
            }
            groupedActivities[hour]?.append(activity)
        }

        return groupedActivities
    }

    /// Get time entries grouped by hour for timeline display
    func getTimeEntriesByHour() -> [Int: [TimeEntry]] {
        let calendar = Calendar.current
        var groupedEntries: [Int: [TimeEntry]] = [:]

        for entry in timeEntries {
            let hour = calendar.component(.hour, from: entry.startTime)
            if groupedEntries[hour] == nil {
                groupedEntries[hour] = []
            }
            groupedEntries[hour]?.append(entry)
        }

        return groupedEntries
    }

    /// Calculate timeline width based on scale and time scale
    func getTimelineWidth() -> CGFloat {
        let baseWidth: CGFloat

        switch timeScale {
        case .hours:
            baseWidth = 24 * 80 // 24 hours * 80px per hour
        case .days:
            baseWidth = 7 * 120 // 7 days * 120px per day
        case .weeks:
            baseWidth = 4 * 200 // 4 weeks * 200px per week
        }

        return baseWidth * timelineScale
    }

    /// Get total width including labels
    func getTotalWidth() -> CGFloat {
        return 140 + getTimelineWidth()
    }

    /// Convert time to position on timeline (0-1 range)
    func timeToPosition(_ time: Date) -> Double {
        let timeInterval = time.timeIntervalSince(selectedDateRange.start)
        let totalDuration = selectedDateRange.duration

        return min(max(timeInterval / totalDuration, 0), 1)
    }

    /// Convert duration to width on timeline (0-1 range)
    func durationToWidth(_ duration: TimeInterval) -> Double {
        let totalDuration = selectedDateRange.duration
        return min(duration / totalDuration, 1)
    }
}

// MARK: - Supporting Types

struct TimelineCacheData {
    let activities: [Activity]
    let timeEntries: [TimeEntry]
    let projects: [Project]
    let timestamp: Date
}

enum TimeScale: String, CaseIterable {
    case hours = "Hours"
    case days = "Days"
    case weeks = "Weeks"

    var displayName: String {
        return rawValue
    }
}

enum TimelineError: LocalizedError {
    case dataLoadFailed(Error)
    case assignmentFailed(Error)
    case invalidDateRange
    case cacheError

    var errorDescription: String? {
        switch self {
        case let .dataLoadFailed(error):
            return "Failed to load timeline data: \(error.localizedDescription)"
        case let .assignmentFailed(error):
            return "Failed to assign activity to project: \(error.localizedDescription)"
        case .invalidDateRange:
            return "Invalid date range selected"
        case .cacheError:
            return "Timeline cache error"
        }
    }
}
