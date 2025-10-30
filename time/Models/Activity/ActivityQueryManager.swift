
import Foundation
import os.log
import SwiftData
import SwiftUI

/// 管理Activity查询的类，根据筛选条件动态查询数据
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

    /// 设置ModelContext
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        Task {
            await refreshActivities()
        }
    }

    /// 设置日期范围筛选
    func setDateRange(_ range: DateInterval?) {
        guard currentDateRange != range else { return }
        currentDateRange = range
        Task {
            await refreshActivities()
        }
    }

    /// 设置搜索文本筛选
    func setSearchText(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentSearchText != trimmedText else { return }
        currentSearchText = trimmedText
        Task {
            await refreshActivities()
        }
    }

    /// 设置项目筛选
    func setProjectFilter(_ project: Project?) {
        guard currentProjectFilter?.id != project?.id else { return }
        currentProjectFilter = project
        currentSidebarFilter = nil // 清除侧边栏筛选
        Task {
            await refreshActivities()
        }
    }

    /// 设置侧边栏筛选
    func setSidebarFilter(_ filter: String?) {
        guard currentSidebarFilter != filter else { return }
        currentSidebarFilter = filter
        currentProjectFilter = nil // 清除项目筛选
        Task {
            await refreshActivities()
        }
    }

    /// 刷新活动数据
    func refreshActivities() async {
        guard let context = modelContext else {
            logger.error("ModelContext not set")
            return
        }

        isLoading = true

        do {
            let descriptor = buildFetchDescriptor()
            let fetchedActivities = try context.fetch(descriptor)

            let filteredActivities = applyInMemoryFilters(fetchedActivities)

            let countDescriptor = buildCountDescriptor()
            totalCount = try context.fetchCount(countDescriptor)

            activities = filteredActivities

            logger.info("Refreshed activities: \(filteredActivities.count) loaded, \(self.totalCount) total matching filters")

        } catch {
            logger.error("Failed to refresh activities: \(error.localizedDescription)")
            activities = []
            totalCount = 0
        }

        isLoading = false
    }

    /// 在内存中应用额外的筛选条件
    private func applyInMemoryFilters(_ activities: [Activity]) -> [Activity] {
        var filtered = activities

        if !currentSearchText.isEmpty, currentDateRange == nil {
        } else if !currentSearchText.isEmpty {
            filtered = filtered.filter { activity in
                activity.appName.localizedStandardContains(currentSearchText) ||
                    (activity.appTitle?.localizedStandardContains(currentSearchText) ?? false)
            }
        }

        if let project = currentProjectFilter {
            logger.info("Project filter applied in memory: \(project.name) (placeholder logic)")
        }

        if let sidebarFilter = currentSidebarFilter {
            switch sidebarFilter {
            case "All Activities":
                break
            case "Unassigned":
                logger.info("Unassigned filter applied in memory (placeholder logic)")
            case "My Projects":
                logger.info("My Projects filter applied in memory (placeholder logic)")
            default:
                break
            }
        }

        return filtered
    }

    /// 获取当前筛选条件的描述
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

    /// 构建查询描述符
    private func buildFetchDescriptor() -> FetchDescriptor<Activity> {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\Activity.startTime, order: .reverse)]
        )

        if let dateRange = currentDateRange {
            let datePredicate = #Predicate<Activity> { activity in
                activity.startTime >= dateRange.start && activity.startTime <= dateRange.end
            }
            descriptor.predicate = datePredicate
        }

        else if !currentSearchText.isEmpty {
            let searchText = currentSearchText // 避免闭包中的self引用
            let searchPredicate = #Predicate<Activity> { activity in
                activity.appName.localizedStandardContains(searchText) ||
                    (activity.appTitle?.localizedStandardContains(searchText) ?? false)
            }
            descriptor.predicate = searchPredicate
        }

        descriptor.fetchLimit = 1000 // 最多加载1000条记录

        return descriptor
    }

    /// 构建计数描述符
    private func buildCountDescriptor() -> FetchDescriptor<Activity> {
        var descriptor = buildFetchDescriptor()
        descriptor.fetchLimit = nil // 移除限制以获取准确计数
        return descriptor
    }
}

// MARK: - Supporting Types

/// 筛选条件状态
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
