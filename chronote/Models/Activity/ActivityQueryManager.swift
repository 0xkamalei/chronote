
import Foundation
import os.log
import SwiftData
import SwiftUI

@MainActor
class ActivityQueryManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ActivityQueryManager()

    // MARK: - Published Properties

    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var totalCount = 0

    // MARK: - Private Properties

    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.time-vscode.ActivityQueryManager", category: "QueryManagement")

    private var currentDateRange: DateInterval?
    private var currentSearchText: String = ""
    private var currentProjectFilter: Project?
    private var currentSidebarFilter: String?

    // MARK: - Initialization

    private init() {
        logger.info("ActivityQueryManager initialized")
    }

    // MARK: - Public Methods

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        Task {
            await refreshActivities()
        }
    }

    func setDateRange(_ range: DateInterval?) {
        // Log the incoming range for debugging
        if let range = range {
            logger.info("setDateRange called with: \(range.start) - \(range.end)")
        } else {
            logger.info("setDateRange called with: nil")
        }
        
        // Check if range actually changed
        if let currentRange = currentDateRange, let newRange = range {
            if currentRange.start == newRange.start && currentRange.end == newRange.end {
                logger.info("Date range unchanged, skipping refresh")
                return
            }
        } else if currentDateRange == nil && range == nil {
            logger.info("Both ranges are nil, skipping refresh")
            return
        }
        
        currentDateRange = range
        Task {
            await refreshActivities()
        }
    }

    func setSearchText(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentSearchText != trimmedText else { return }
        currentSearchText = trimmedText
        Task {
            await refreshActivities()
        }
    }

    func setProjectFilter(_ project: Project?) {
        guard currentProjectFilter?.id != project?.id else { return }
        currentProjectFilter = project
        currentSidebarFilter = nil // 清除侧边栏筛选
        Task {
            await refreshActivities()
        }
    }

    func setSidebarFilter(_ filter: String?) {
        guard currentSidebarFilter != filter else { return }
        currentSidebarFilter = filter
        currentProjectFilter = nil // 清除项目筛选
        Task {
            await refreshActivities()
        }
    }

    func refreshActivities() async {
        guard let context = modelContext else {
            logger.error("ModelContext not set")
            return
        }

        isLoading = true
        
        // Debug: Log current filter state with timezone info
        if let range = currentDateRange {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            logger.info("Current date range: \(formatter.string(from: range.start)) - \(formatter.string(from: range.end))")
            logger.info("Current timezone: \(TimeZone.current.identifier)")
        } else {
            logger.info("Current date range: nil")
        }

        do {
            // Fetch all activities first, then filter in memory
            // This avoids potential issues with SwiftData #Predicate and Date comparisons
            var allDescriptor = FetchDescriptor<Activity>(
                sortBy: [SortDescriptor(\Activity.startTime, order: .reverse)]
            )
            allDescriptor.fetchLimit = 5000 // Reasonable limit
            
            let allActivities = try context.fetch(allDescriptor)
            logger.info("Total activities fetched: \(allActivities.count)")
            
            // Apply date range filter in memory
            var fetchedActivities = allActivities
            if let range = currentDateRange {
                fetchedActivities = allActivities.filter { activity in
                    activity.startTime >= range.start && activity.startTime < range.end
                }
                logger.info("After date filter: \(fetchedActivities.count) activities")
                
                // Debug: if no results, show sample data
                if fetchedActivities.isEmpty && !allActivities.isEmpty {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    logger.warning("No activities in date range. Sample activities:")
                    for activity in allActivities.prefix(5) {
                        logger.info("  - \(activity.appName): \(formatter.string(from: activity.startTime))")
                    }
                }
            }

            // Apply other filters in memory
            let filteredActivities = applyInMemoryFilters(fetchedActivities)

            self.totalCount = filteredActivities.count
            activities = Array(filteredActivities.prefix(1000)) // Limit to 1000 for display

            logger.info("Refreshed activities: \(self.activities.count) loaded, total: \(self.totalCount)")

        } catch {
            logger.error("Failed to refresh activities: \(error.localizedDescription)")
            activities = []
            self.totalCount = 0
        }

        isLoading = false
    }

    private func applyInMemoryFilters(_ activities: [Activity]) -> [Activity] {
        var filtered = activities

        if !currentSearchText.isEmpty {
            filtered = filtered.filter { activity in
                activity.appName.localizedStandardContains(currentSearchText)
            }
        }

        if let project = currentProjectFilter {
            filtered = filtered.filter { $0.projectId == project.id }
            logger.info("Project filter applied in memory: \(project.name)")
        }

        if let sidebarFilter = currentSidebarFilter {
            switch sidebarFilter {
            case "All Activities":
                break
            case "Unassigned":
                filtered = filtered.filter { $0.projectId == nil }
                logger.info("Unassigned filter applied in memory")
            case "My Projects":
                filtered = filtered.filter { $0.projectId != nil }
                logger.info("My Projects filter applied in memory")
            default:
                break
            }
        }

        return filtered
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

        if let project = currentProjectFilter {
            components.append("Project: \(project.name)")
        }

        if let sidebar = currentSidebarFilter {
            components.append("Filter: \(sidebar)")
        }

        return components.isEmpty ? "All Activities" : components.joined(separator: ", ")
    }

    // MARK: - Private Methods

    private func buildFetchDescriptor() -> FetchDescriptor<Activity> {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\Activity.startTime, order: .reverse)]
        )

        let range = currentDateRange
        let project = currentProjectFilter
        let sidebar = currentSidebarFilter
        let searchText = currentSearchText

        if let range = range {
            let start = range.start
            let end = range.end
            
            // Log the actual values being used in predicate
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            logger.info("Building predicate with start: \(formatter.string(from: start)), end: \(formatter.string(from: end))")

            if let project = project {
                let pid = project.id
                descriptor.predicate = #Predicate<Activity> { activity in
                    if let aid = activity.projectId {
                        return activity.startTime >= start && activity.startTime < end && aid == pid
                    } else {
                        return false
                    }
                }
            } else if sidebar == "Unassigned" {
                descriptor.predicate = #Predicate<Activity> { activity in
                    activity.startTime >= start && activity.startTime < end && activity.projectId == nil
                }
            } else if sidebar == "My Projects" {
                descriptor.predicate = #Predicate<Activity> { activity in
                    activity.startTime >= start && activity.startTime < end && activity.projectId != nil
                }
            } else {
                descriptor.predicate = #Predicate<Activity> { activity in
                    activity.startTime >= start && activity.startTime < end
                }
            }
        } else if let project = project {
            let pid = project.id
            descriptor.predicate = #Predicate<Activity> { activity in
                if let aid = activity.projectId {
                    return aid == pid
                } else {
                    return false
                }
            }
        } else if !searchText.isEmpty {
            descriptor.predicate = #Predicate<Activity> { activity in
                activity.appName.localizedStandardContains(searchText)
            }
        }

        descriptor.fetchLimit = 1000 // 最多加载1000条记录

        return descriptor
    }

    private func buildCountDescriptor() -> FetchDescriptor<Activity> {
        var descriptor = buildFetchDescriptor()
        descriptor.fetchLimit = nil  
        return descriptor
    }
}

// MARK: - Supporting Types

struct FilterState {
    let dateRange: DateInterval?
    let searchText: String
    let projectFilter: Project?
    let sidebarFilter: String?

    var hasActiveFilters: Bool {
        return dateRange != nil ||
            !searchText.isEmpty ||
            projectFilter != nil ||
            (sidebarFilter != nil && sidebarFilter != "All Activities")
    }
}
