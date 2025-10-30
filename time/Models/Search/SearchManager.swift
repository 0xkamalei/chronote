import Foundation
import os.log
import SwiftData
import SwiftUI

/// Manager class for handling search and filtering operations across activities, time entries, and projects
@MainActor
class SearchManager: ObservableObject {
    // MARK: - Published Properties

    @Published var searchQuery: String = ""
    @Published var isSearching: Bool = false
    @Published var searchResults: SearchResults = .init()
    @Published var activeFilters: SearchFilters = .init()
    @Published var searchHistory: [String] = []
    @Published var savedSearches: [SavedSearch] = []

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.timetracking.search", category: "SearchManager")
    private var searchTask: Task<Void, Never>?
    private let searchIndex = SearchIndex()
    private let performanceOptimizer = SearchPerformanceOptimizer()
    private let debounceDelay: TimeInterval = 0.3

    // MARK: - Dependencies

    let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSearchHistory()
        loadSavedSearches()
        buildSearchIndex()
    }

    // MARK: - Public Search Methods

    /// Performs a search with the current query and filters
    func search() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }

        // Cancel any existing search task
        searchTask?.cancel()

        // Start new search task with debouncing
        searchTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await performSearch()
        }
    }

    /// Performs immediate search without debouncing
    func searchImmediate() {
        searchTask?.cancel()

        Task {
            await performSearch()
        }
    }

    /// Clears search results and query
    func clearSearch() {
        searchQuery = ""
        clearResults()
        searchTask?.cancel()
    }

    /// Applies filters and refreshes results
    func applyFilters(_ filters: SearchFilters) {
        activeFilters = filters
        if !searchQuery.isEmpty || filters.hasActiveFilters {
            searchImmediate()
        } else {
            clearResults()
        }
    }

    /// Clears all active filters
    func clearFilters() {
        activeFilters = SearchFilters()
        if !searchQuery.isEmpty {
            searchImmediate()
        } else {
            clearResults()
        }
    }

    // MARK: - Search History Management

    /// Adds a search query to history
    func addToHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        // Remove if already exists
        searchHistory.removeAll { $0 == trimmedQuery }

        // Add to beginning
        searchHistory.insert(trimmedQuery, at: 0)

        // Limit to 20 items
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }

        saveSearchHistory()
    }

    /// Clears search history
    func clearHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }

    // MARK: - Saved Searches Management

    /// Saves the current search query and filters
    func saveCurrentSearch(name: String) {
        let savedSearch = SavedSearch(
            id: UUID(),
            name: name,
            query: searchQuery,
            filters: activeFilters,
            createdAt: Date()
        )

        savedSearches.append(savedSearch)
        saveSavedSearches()
    }

    /// Loads a saved search
    func loadSavedSearch(_ savedSearch: SavedSearch) {
        searchQuery = savedSearch.query
        activeFilters = savedSearch.filters
        searchImmediate()
    }

    /// Deletes a saved search
    func deleteSavedSearch(_ savedSearch: SavedSearch) {
        savedSearches.removeAll { $0.id == savedSearch.id }
        saveSavedSearches()
    }

    // MARK: - Search Suggestions

    /// Gets search suggestions based on current query
    func getSearchSuggestions() -> [SearchSuggestion] {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var suggestions: [SearchSuggestion] = []

        // Add history suggestions
        let historySuggestions = searchHistory
            .filter { $0.lowercased().contains(query) }
            .prefix(5)
            .map { SearchSuggestion(text: $0, type: .history) }
        suggestions.append(contentsOf: historySuggestions)

        // Add app name suggestions
        let appSuggestions = searchIndex.getAppNameSuggestions(for: query)
            .prefix(3)
            .map { SearchSuggestion(text: $0, type: .appName) }
        suggestions.append(contentsOf: appSuggestions)

        // Add project suggestions
        let projectSuggestions = searchIndex.getProjectSuggestions(for: query)
            .prefix(3)
            .map { SearchSuggestion(text: $0, type: .project) }
        suggestions.append(contentsOf: projectSuggestions)

        return Array(suggestions.prefix(10))
    }

    // MARK: - Private Search Implementation

    private func performSearch() async {
        isSearching = true

        do {
            let results = try await executeSearch()

            await MainActor.run {
                self.searchResults = results
                self.isSearching = false

                // Add to history if it's a meaningful search
                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    addToHistory(searchQuery)
                }
            }

        } catch {
            logger.error("Search failed: \(error.localizedDescription)")

            await MainActor.run {
                self.searchResults = SearchResults()
                self.isSearching = false
            }
        }
    }

    private func executeSearch() async throws -> SearchResults {
        let startTime = Date()
        let optimizedQuery = performanceOptimizer.optimizeQuery(searchQuery)

        // Check cache first
        if let cachedResults = performanceOptimizer.getCachedResults(for: optimizedQuery, filters: activeFilters) {
            performanceOptimizer.recordSearchPerformance(
                query: optimizedQuery,
                resultCount: cachedResults.totalCount,
                searchTime: Date().timeIntervalSince(startTime),
                cacheHit: true
            )
            return cachedResults
        }

        // Determine search strategy based on complexity
        let dataSize = await getDataSize()
        let complexity = performanceOptimizer.estimateSearchComplexity(
            query: optimizedQuery,
            filters: activeFilters,
            dataSize: dataSize
        )

        let results: SearchResults

        if performanceOptimizer.shouldUseFastPath(query: optimizedQuery, filters: activeFilters) {
            results = try await executeFastSearch(query: optimizedQuery)
        } else {
            results = try await executeFullSearch(query: optimizedQuery)
        }

        let searchTime = Date().timeIntervalSince(startTime)

        // Cache results for future use
        performanceOptimizer.cacheResults(results, for: optimizedQuery, filters: activeFilters)

        // Record performance metrics
        performanceOptimizer.recordSearchPerformance(
            query: optimizedQuery,
            resultCount: results.totalCount,
            searchTime: searchTime,
            cacheHit: false
        )

        return results
    }

    private func executeFastSearch(query: String) async throws -> SearchResults {
        // Simplified search for better performance
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Use index-based search for better performance
        let activityIds = searchIndex.searchActivityIds(query: query)
        let timeEntryIds = searchIndex.searchTimeEntryIds(query: query)
        let projectIds = searchIndex.searchProjectIds(query: query)

        // Fetch only the matching items
        let activities = try await fetchActivitiesByIds(Array(activityIds))
        let timeEntries = try await fetchTimeEntriesByIds(Array(timeEntryIds))
        let projects = try await fetchProjectsByIds(Array(projectIds))

        // Apply filters
        let filteredActivities = applyFiltersToActivities(activities)
        let filteredTimeEntries = applyFiltersToTimeEntries(timeEntries)
        let filteredProjects = applyFiltersToProjects(projects)

        // Rank and sort results
        let rankedActivities = rankActivities(filteredActivities, query: query)
        let rankedTimeEntries = rankTimeEntries(filteredTimeEntries, query: query)
        let rankedProjects = rankProjects(filteredProjects, query: query)

        return SearchResults(
            activities: rankedActivities,
            timeEntries: rankedTimeEntries,
            projects: rankedProjects,
            totalCount: rankedActivities.count + rankedTimeEntries.count + rankedProjects.count
        )
    }

    private func executeFullSearch(query: String) async throws -> SearchResults {
        // Full predicate-based search for complex queries
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Build search predicates
        let activityPredicate = buildActivityPredicate(query: query)
        let timeEntryPredicate = buildTimeEntryPredicate(query: query)
        let projectPredicate = buildProjectPredicate(query: query)

        // Execute searches
        let activities = try await searchActivities(predicate: activityPredicate)
        let timeEntries = try await searchTimeEntries(predicate: timeEntryPredicate)
        let projects = try await searchProjects(predicate: projectPredicate)

        // Rank and sort results
        let rankedActivities = rankActivities(activities, query: query)
        let rankedTimeEntries = rankTimeEntries(timeEntries, query: query)
        let rankedProjects = rankProjects(projects, query: query)

        return SearchResults(
            activities: rankedActivities,
            timeEntries: rankedTimeEntries,
            projects: rankedProjects,
            totalCount: rankedActivities.count + rankedTimeEntries.count + rankedProjects.count
        )
    }

    // MARK: - Predicate Building

    private func buildActivityPredicate(query: String) -> Predicate<Activity> {
        var predicates: [Predicate<Activity>] = []

        // Text search predicate
        if !query.isEmpty {
            let textPredicate = #Predicate<Activity> { activity in
                activity.appName.localizedStandardContains(query) ||
                    (activity.windowTitle?.localizedStandardContains(query) ?? false) ||
                    (activity.url?.localizedStandardContains(query) ?? false) ||
                    (activity.documentPath?.localizedStandardContains(query) ?? false)
            }
            predicates.append(textPredicate)
        }

        // Date range filter
        if let startDate = activeFilters.startDate, let endDate = activeFilters.endDate {
            let datePredicate = #Predicate<Activity> { activity in
                activity.startTime >= startDate && activity.startTime <= endDate
            }
            predicates.append(datePredicate)
        }

        // App filter
        if !activeFilters.selectedApps.isEmpty {
            let appPredicate = #Predicate<Activity> { activity in
                activeFilters.selectedApps.contains(activity.appName)
            }
            predicates.append(appPredicate)
        }

        // Duration filter
        if let minDuration = activeFilters.minDuration {
            let durationPredicate = #Predicate<Activity> { activity in
                activity.calculatedDuration >= minDuration
            }
            predicates.append(durationPredicate)
        }

        // Exclude idle time if specified
        if activeFilters.excludeIdleTime {
            let idlePredicate = #Predicate<Activity> { activity in
                !activity.isIdleTime
            }
            predicates.append(idlePredicate)
        }

        // Combine all predicates with AND
        return predicates.reduce(#Predicate<Activity> { _ in true }) { result, predicate in
            #Predicate<Activity> { activity in
                result.evaluate(activity) && predicate.evaluate(activity)
            }
        }
    }

    private func buildTimeEntryPredicate(query: String) -> Predicate<TimeEntry> {
        var predicates: [Predicate<TimeEntry>] = []

        // Text search predicate
        if !query.isEmpty {
            let textPredicate = #Predicate<TimeEntry> { entry in
                entry.title.localizedStandardContains(query) ||
                    (entry.notes?.localizedStandardContains(query) ?? false)
            }
            predicates.append(textPredicate)
        }

        // Date range filter
        if let startDate = activeFilters.startDate, let endDate = activeFilters.endDate {
            let datePredicate = #Predicate<TimeEntry> { entry in
                entry.startTime >= startDate && entry.startTime <= endDate
            }
            predicates.append(datePredicate)
        }

        // Project filter
        if !activeFilters.selectedProjects.isEmpty {
            let projectPredicate = #Predicate<TimeEntry> { entry in
                if let projectId = entry.projectId {
                    return activeFilters.selectedProjects.contains(projectId)
                }
                return false
            }
            predicates.append(projectPredicate)
        }

        // Duration filter
        if let minDuration = activeFilters.minDuration {
            let durationPredicate = #Predicate<TimeEntry> { entry in
                entry.calculatedDuration >= minDuration
            }
            predicates.append(durationPredicate)
        }

        // Combine all predicates with AND
        return predicates.reduce(#Predicate<TimeEntry> { _ in true }) { result, predicate in
            #Predicate<TimeEntry> { entry in
                result.evaluate(entry) && predicate.evaluate(entry)
            }
        }
    }

    private func buildProjectPredicate(query: String) -> Predicate<Project> {
        var predicates: [Predicate<Project>] = []

        // Text search predicate
        if !query.isEmpty {
            let textPredicate = #Predicate<Project> { project in
                project.name.localizedStandardContains(query)
            }
            predicates.append(textPredicate)
        }

        // Selected projects filter
        if !activeFilters.selectedProjects.isEmpty {
            let projectPredicate = #Predicate<Project> { project in
                activeFilters.selectedProjects.contains(project.id)
            }
            predicates.append(projectPredicate)
        }

        // Combine all predicates with AND
        return predicates.reduce(#Predicate<Project> { _ in true }) { result, predicate in
            #Predicate<Project> { project in
                result.evaluate(project) && predicate.evaluate(project)
            }
        }
    }

    // MARK: - Database Queries

    private func searchActivities(predicate: Predicate<Activity>) async throws -> [Activity] {
        let descriptor = FetchDescriptor<Activity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    private func searchTimeEntries(predicate: Predicate<TimeEntry>) async throws -> [TimeEntry] {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    private func searchProjects(predicate: Predicate<Project>) async throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )

        return try modelContext.fetch(descriptor)
    }

    // MARK: - Result Ranking

    private func rankActivities(_ activities: [Activity], query: String) -> [RankedActivity] {
        return activities.map { activity in
            let score = calculateActivityRelevanceScore(activity, query: query)
            return RankedActivity(activity: activity, relevanceScore: score)
        }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func rankTimeEntries(_ timeEntries: [TimeEntry], query: String) -> [RankedTimeEntry] {
        return timeEntries.map { entry in
            let score = calculateTimeEntryRelevanceScore(entry, query: query)
            return RankedTimeEntry(timeEntry: entry, relevanceScore: score)
        }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func rankProjects(_ projects: [Project], query: String) -> [RankedProject] {
        return projects.map { project in
            let score = calculateProjectRelevanceScore(project, query: query)
            return RankedProject(project: project, relevanceScore: score)
        }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    // MARK: - Relevance Scoring

    private func calculateActivityRelevanceScore(_ activity: Activity, query: String) -> Double {
        let lowercaseQuery = query.lowercased()
        var score: Double = 0

        // App name match (highest priority)
        if activity.appName.lowercased().contains(lowercaseQuery) {
            score += activity.appName.lowercased() == lowercaseQuery ? 100 : 50
        }

        // Window title match
        if let windowTitle = activity.windowTitle, windowTitle.lowercased().contains(lowercaseQuery) {
            score += windowTitle.lowercased() == lowercaseQuery ? 80 : 30
        }

        // URL match
        if let url = activity.url, url.lowercased().contains(lowercaseQuery) {
            score += 20
        }

        // Document path match
        if let documentPath = activity.documentPath, documentPath.lowercased().contains(lowercaseQuery) {
            score += 25
        }

        // Recency bonus (more recent activities get higher scores)
        let daysSinceActivity = Date().timeIntervalSince(activity.startTime) / (24 * 60 * 60)
        let recencyBonus = max(0, 10 - daysSinceActivity)
        score += recencyBonus

        // Duration bonus (longer activities get slight bonus)
        let durationBonus = min(5, activity.calculatedDuration / (60 * 60)) // Max 5 points for 1+ hour activities
        score += durationBonus

        return score
    }

    private func calculateTimeEntryRelevanceScore(_ timeEntry: TimeEntry, query: String) -> Double {
        let lowercaseQuery = query.lowercased()
        var score: Double = 0

        // Title match (highest priority)
        if timeEntry.title.lowercased().contains(lowercaseQuery) {
            score += timeEntry.title.lowercased() == lowercaseQuery ? 100 : 60
        }

        // Notes match
        if let notes = timeEntry.notes, notes.lowercased().contains(lowercaseQuery) {
            score += 30
        }

        // Recency bonus
        let daysSinceEntry = Date().timeIntervalSince(timeEntry.startTime) / (24 * 60 * 60)
        let recencyBonus = max(0, 10 - daysSinceEntry)
        score += recencyBonus

        // Duration bonus
        let durationBonus = min(5, timeEntry.calculatedDuration / (60 * 60))
        score += durationBonus

        return score
    }

    private func calculateProjectRelevanceScore(_ project: Project, query: String) -> Double {
        let lowercaseQuery = query.lowercased()
        var score: Double = 0

        // Name match
        if project.name.lowercased().contains(lowercaseQuery) {
            score += project.name.lowercased() == lowercaseQuery ? 100 : 70
        }

        // Hierarchy bonus (root projects get slight bonus)
        if project.parentID == nil {
            score += 5
        }

        return score
    }

    // MARK: - Search Index Management

    private func buildSearchIndex() {
        Task {
            do {
                let activities = try modelContext.fetch(FetchDescriptor<Activity>())
                let timeEntries = try modelContext.fetch(FetchDescriptor<TimeEntry>())
                let projects = try modelContext.fetch(FetchDescriptor<Project>())

                await MainActor.run {
                    searchIndex.buildIndex(activities: activities, timeEntries: timeEntries, projects: projects)
                }
            } catch {
                logger.error("Failed to build search index: \(error.localizedDescription)")
            }
        }
    }

    /// Rebuilds the search index with current data
    func rebuildSearchIndex() {
        buildSearchIndex()
        performanceOptimizer.invalidateCache(for: .index)
    }

    /// Gets performance metrics for the search system
    func getPerformanceMetrics() -> SearchMetrics {
        return performanceOptimizer.getPerformanceMetrics()
    }

    /// Performs memory cleanup and optimization
    func performMemoryCleanup() {
        performanceOptimizer.performMemoryCleanup()
    }

    // MARK: - Utility Methods

    private func clearResults() {
        searchResults = SearchResults()
        isSearching = false
    }

    // MARK: - Persistence

    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "SearchHistory"),
           let history = try? JSONDecoder().decode([String].self, from: data)
        {
            searchHistory = history
        }
    }

    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "SearchHistory")
        }
    }

    private func loadSavedSearches() {
        if let data = UserDefaults.standard.data(forKey: "SavedSearches"),
           let searches = try? JSONDecoder().decode([SavedSearch].self, from: data)
        {
            savedSearches = searches
        }
    }

    private func saveSavedSearches() {
        if let data = try? JSONEncoder().encode(savedSearches) {
            UserDefaults.standard.set(data, forKey: "SavedSearches")
        }
    }

    // MARK: - Helper Methods for Optimized Search

    private func getDataSize() async -> DataSize {
        do {
            let activityCount = try modelContext.fetchCount(FetchDescriptor<Activity>())
            let timeEntryCount = try modelContext.fetchCount(FetchDescriptor<TimeEntry>())
            let projectCount = try modelContext.fetchCount(FetchDescriptor<Project>())

            return DataSize(
                activities: activityCount,
                timeEntries: timeEntryCount,
                projects: projectCount
            )
        } catch {
            logger.error("Failed to get data size: \(error.localizedDescription)")
            return DataSize(activities: 0, timeEntries: 0, projects: 0)
        }
    }

    private func fetchActivitiesByIds(_ ids: [String]) async throws -> [Activity] {
        guard !ids.isEmpty else { return [] }

        let uuids = ids.compactMap { UUID(uuidString: $0) }
        let predicate = #Predicate<Activity> { activity in
            uuids.contains(activity.id)
        }

        let descriptor = FetchDescriptor<Activity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    private func fetchTimeEntriesByIds(_ ids: [String]) async throws -> [TimeEntry] {
        guard !ids.isEmpty else { return [] }

        let uuids = ids.compactMap { UUID(uuidString: $0) }
        let predicate = #Predicate<TimeEntry> { entry in
            uuids.contains(entry.id)
        }

        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    private func fetchProjectsByIds(_ ids: [String]) async throws -> [Project] {
        guard !ids.isEmpty else { return [] }

        let predicate = #Predicate<Project> { project in
            ids.contains(project.id)
        }

        let descriptor = FetchDescriptor<Project>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )

        return try modelContext.fetch(descriptor)
    }

    private func applyFiltersToActivities(_ activities: [Activity]) -> [Activity] {
        return activities.filter { activity in
            // Date range filter
            if let startDate = activeFilters.startDate, activity.startTime < startDate {
                return false
            }
            if let endDate = activeFilters.endDate, activity.startTime > endDate {
                return false
            }

            // App filter
            if !activeFilters.selectedApps.isEmpty, !activeFilters.selectedApps.contains(activity.appName) {
                return false
            }

            // Duration filter
            if let minDuration = activeFilters.minDuration, activity.calculatedDuration < minDuration {
                return false
            }
            if let maxDuration = activeFilters.maxDuration, activity.calculatedDuration > maxDuration {
                return false
            }

            // Idle time filter
            if activeFilters.excludeIdleTime, activity.isIdleTime {
                return false
            }

            return true
        }
    }

    private func applyFiltersToTimeEntries(_ timeEntries: [TimeEntry]) -> [TimeEntry] {
        return timeEntries.filter { entry in
            // Date range filter
            if let startDate = activeFilters.startDate, entry.startTime < startDate {
                return false
            }
            if let endDate = activeFilters.endDate, entry.startTime > endDate {
                return false
            }

            // Project filter
            if !activeFilters.selectedProjects.isEmpty {
                if let projectId = entry.projectId {
                    if !activeFilters.selectedProjects.contains(projectId) {
                        return false
                    }
                } else {
                    return false
                }
            }

            // Duration filter
            if let minDuration = activeFilters.minDuration, entry.calculatedDuration < minDuration {
                return false
            }
            if let maxDuration = activeFilters.maxDuration, entry.calculatedDuration > maxDuration {
                return false
            }

            return true
        }
    }

    private func applyFiltersToProjects(_ projects: [Project]) -> [Project] {
        return projects.filter { project in
            // Selected projects filter
            if !activeFilters.selectedProjects.isEmpty, !activeFilters.selectedProjects.contains(project.id) {
                return false
            }

            return true
        }
    }
}

// MARK: - Search Query Parsing Extension

extension SearchManager {
    /// Parses advanced search queries with operators
    func parseAdvancedQuery(_ query: String) -> ParsedQuery {
        let parser = SearchQueryParser()
        return parser.parse(query)
    }

    /// Validates search query syntax
    func validateQuery(_ query: String) -> QueryValidationResult {
        let parser = SearchQueryParser()
        return parser.validate(query)
    }
}
