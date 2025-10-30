import Foundation
import os.log

/// Search index for fast text-based searching across activities, time entries, and projects
class SearchIndex {
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.timetracking.search", category: "SearchIndex")
    
    // Inverted indexes for fast text search
    private var appNameIndex: [String: Set<String>] = [:]
    private var windowTitleIndex: [String: Set<String>] = [:]
    private var urlIndex: [String: Set<String>] = [:]
    private var documentPathIndex: [String: Set<String>] = [:]
    private var timeEntryTitleIndex: [String: Set<String>] = [:]
    private var timeEntryNotesIndex: [String: Set<String>] = [:]
    private var projectNameIndex: [String: Set<String>] = [:]
    
    // Metadata for suggestions and autocomplete
    private var allAppNames: Set<String> = []
    private var allProjectNames: Set<String> = []
    private var allWindowTitles: Set<String> = []
    private var commonTerms: [String: Int] = [:]
    
    // Index statistics
    private var indexedActivitiesCount: Int = 0
    private var indexedTimeEntriesCount: Int = 0
    private var indexedProjectsCount: Int = 0
    private var lastIndexUpdate: Date = Date()
    
    // MARK: - Public Methods
    
    /// Builds the complete search index from provided data
    func buildIndex(activities: [Activity], timeEntries: [TimeEntry], projects: [Project]) {
        logger.info("Building search index with \(activities.count) activities, \(timeEntries.count) time entries, \(projects.count) projects")
        
        let startTime = Date()
        
        // Clear existing indexes
        clearIndexes()
        
        // Index activities
        for activity in activities {
            indexActivity(activity)
        }
        
        // Index time entries
        for timeEntry in timeEntries {
            indexTimeEntry(timeEntry)
        }
        
        // Index projects
        for project in projects {
            indexProject(project)
        }
        
        // Update statistics
        indexedActivitiesCount = activities.count
        indexedTimeEntriesCount = timeEntries.count
        indexedProjectsCount = projects.count
        lastIndexUpdate = Date()
        
        let indexTime = Date().timeIntervalSince(startTime)
        logger.info("Search index built in \(String(format: "%.3f", indexTime))s")
    }
    
    /// Adds a single activity to the index
    func addActivity(_ activity: Activity) {
        indexActivity(activity)
        indexedActivitiesCount += 1
    }
    
    /// Adds a single time entry to the index
    func addTimeEntry(_ timeEntry: TimeEntry) {
        indexTimeEntry(timeEntry)
        indexedTimeEntriesCount += 1
    }
    
    /// Adds a single project to the index
    func addProject(_ project: Project) {
        indexProject(project)
        indexedProjectsCount += 1
    }
    
    /// Removes an activity from the index
    func removeActivity(_ activityId: String) {
        removeFromIndexes(id: activityId)
        indexedActivitiesCount = max(0, indexedActivitiesCount - 1)
    }
    
    /// Removes a time entry from the index
    func removeTimeEntry(_ timeEntryId: String) {
        removeFromIndexes(id: timeEntryId)
        indexedTimeEntriesCount = max(0, indexedTimeEntriesCount - 1)
    }
    
    /// Removes a project from the index
    func removeProject(_ projectId: String) {
        removeFromIndexes(id: projectId)
        indexedProjectsCount = max(0, indexedProjectsCount - 1)
    }
    
    /// Gets app name suggestions for autocomplete
    func getAppNameSuggestions(for query: String) -> [String] {
        let lowercaseQuery = query.lowercased()
        return allAppNames
            .filter { $0.lowercased().contains(lowercaseQuery) }
            .sorted()
    }
    
    /// Gets project name suggestions for autocomplete
    func getProjectSuggestions(for query: String) -> [String] {
        let lowercaseQuery = query.lowercased()
        return allProjectNames
            .filter { $0.lowercased().contains(lowercaseQuery) }
            .sorted()
    }
    
    /// Gets window title suggestions for autocomplete
    func getWindowTitleSuggestions(for query: String) -> [String] {
        let lowercaseQuery = query.lowercased()
        return allWindowTitles
            .filter { $0.lowercased().contains(lowercaseQuery) }
            .sorted()
            .prefix(10)
            .map { String($0) }
    }
    
    /// Gets common search terms for suggestions
    func getCommonTerms(limit: Int = 20) -> [String] {
        return commonTerms
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    /// Searches for activity IDs matching the query
    func searchActivityIds(query: String) -> Set<String> {
        let terms = tokenize(query)
        guard !terms.isEmpty else { return Set() }
        
        var results: Set<String>?
        
        for term in terms {
            let termResults = searchInIndex(term: term, indexes: [
                appNameIndex,
                windowTitleIndex,
                urlIndex,
                documentPathIndex
            ])
            
            if let existingResults = results {
                results = existingResults.intersection(termResults)
            } else {
                results = termResults
            }
        }
        
        return results ?? Set()
    }
    
    /// Searches for time entry IDs matching the query
    func searchTimeEntryIds(query: String) -> Set<String> {
        let terms = tokenize(query)
        guard !terms.isEmpty else { return Set() }
        
        var results: Set<String>?
        
        for term in terms {
            let termResults = searchInIndex(term: term, indexes: [
                timeEntryTitleIndex,
                timeEntryNotesIndex
            ])
            
            if let existingResults = results {
                results = existingResults.intersection(termResults)
            } else {
                results = termResults
            }
        }
        
        return results ?? Set()
    }
    
    /// Searches for project IDs matching the query
    func searchProjectIds(query: String) -> Set<String> {
        let terms = tokenize(query)
        guard !terms.isEmpty else { return Set() }
        
        var results: Set<String>?
        
        for term in terms {
            let termResults = searchInIndex(term: term, indexes: [projectNameIndex])
            
            if let existingResults = results {
                results = existingResults.intersection(termResults)
            } else {
                results = termResults
            }
        }
        
        return results ?? Set()
    }
    
    /// Gets index statistics
    func getStatistics() -> IndexStatistics {
        return IndexStatistics(
            activitiesCount: indexedActivitiesCount,
            timeEntriesCount: indexedTimeEntriesCount,
            projectsCount: indexedProjectsCount,
            totalTerms: commonTerms.count,
            lastUpdate: lastIndexUpdate
        )
    }
    
    // MARK: - Private Indexing Methods
    
    private func indexActivity(_ activity: Activity) {
        let activityId = activity.id.uuidString
        
        // Index app name
        indexText(activity.appName, for: activityId, in: &appNameIndex)
        allAppNames.insert(activity.appName)
        
        // Index window title
        if let windowTitle = activity.windowTitle, !windowTitle.isEmpty {
            indexText(windowTitle, for: activityId, in: &windowTitleIndex)
            allWindowTitles.insert(windowTitle)
        }
        
        // Index URL
        if let url = activity.url, !url.isEmpty {
            indexText(url, for: activityId, in: &urlIndex)
        }
        
        // Index document path
        if let documentPath = activity.documentPath, !documentPath.isEmpty {
            indexText(documentPath, for: activityId, in: &documentPathIndex)
        }
    }
    
    private func indexTimeEntry(_ timeEntry: TimeEntry) {
        let timeEntryId = timeEntry.id.uuidString
        
        // Index title
        indexText(timeEntry.title, for: timeEntryId, in: &timeEntryTitleIndex)
        
        // Index notes
        if let notes = timeEntry.notes, !notes.isEmpty {
            indexText(notes, for: timeEntryId, in: &timeEntryNotesIndex)
        }
    }
    
    private func indexProject(_ project: Project) {
        let projectId = project.id
        
        // Index project name
        indexText(project.name, for: projectId, in: &projectNameIndex)
        allProjectNames.insert(project.name)
    }
    
    private func indexText(_ text: String, for id: String, in index: inout [String: Set<String>]) {
        let terms = tokenize(text)
        
        for term in terms {
            index[term, default: Set()].insert(id)
            
            // Track common terms for suggestions
            commonTerms[term, default: 0] += 1
        }
    }
    
    private func tokenize(_ text: String) -> [String] {
        let lowercaseText = text.lowercased()
        
        // Split on whitespace and punctuation, but preserve some special characters
        let components = lowercaseText.components(separatedBy: .whitespacesAndNewlines)
        
        var terms: [String] = []
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip very short terms and common stop words
            if trimmed.count >= 2 && !isStopWord(trimmed) {
                terms.append(trimmed)
                
                // Also add prefixes for partial matching
                if trimmed.count > 3 {
                    for i in 3...min(trimmed.count, 8) {
                        let prefix = String(trimmed.prefix(i))
                        terms.append(prefix)
                    }
                }
            }
        }
        
        return terms
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords: Set<String> = [
            "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
            "from", "up", "about", "into", "through", "during", "before", "after", "above",
            "below", "between", "among", "under", "over", "is", "are", "was", "were", "be",
            "been", "being", "have", "has", "had", "do", "does", "did", "will", "would",
            "could", "should", "may", "might", "must", "can", "this", "that", "these",
            "those", "a", "an", "as", "if", "each", "how", "which", "who", "when", "where",
            "why", "what"
        ]
        
        return stopWords.contains(word)
    }
    
    private func searchInIndex(term: String, indexes: [[String: Set<String>]]) -> Set<String> {
        var results: Set<String> = Set()
        
        for index in indexes {
            // Exact match
            if let exactResults = index[term] {
                results.formUnion(exactResults)
            }
            
            // Prefix matching for partial terms
            for (indexTerm, ids) in index {
                if indexTerm.hasPrefix(term) || indexTerm.contains(term) {
                    results.formUnion(ids)
                }
            }
        }
        
        return results
    }
    
    private func removeFromIndexes(id: String) {
        removeFromIndex(id: id, index: &appNameIndex)
        removeFromIndex(id: id, index: &windowTitleIndex)
        removeFromIndex(id: id, index: &urlIndex)
        removeFromIndex(id: id, index: &documentPathIndex)
        removeFromIndex(id: id, index: &timeEntryTitleIndex)
        removeFromIndex(id: id, index: &timeEntryNotesIndex)
        removeFromIndex(id: id, index: &projectNameIndex)
    }
    
    private func removeFromIndex(id: String, index: inout [String: Set<String>]) {
        for (term, var ids) in index {
            if ids.contains(id) {
                ids.remove(id)
                if ids.isEmpty {
                    index.removeValue(forKey: term)
                } else {
                    index[term] = ids
                }
            }
        }
    }
    
    private func clearIndexes() {
        appNameIndex.removeAll()
        windowTitleIndex.removeAll()
        urlIndex.removeAll()
        documentPathIndex.removeAll()
        timeEntryTitleIndex.removeAll()
        timeEntryNotesIndex.removeAll()
        projectNameIndex.removeAll()
        
        allAppNames.removeAll()
        allProjectNames.removeAll()
        allWindowTitles.removeAll()
        commonTerms.removeAll()
        
        indexedActivitiesCount = 0
        indexedTimeEntriesCount = 0
        indexedProjectsCount = 0
    }
}

// MARK: - Index Statistics

/// Statistics about the search index
struct IndexStatistics {
    let activitiesCount: Int
    let timeEntriesCount: Int
    let projectsCount: Int
    let totalTerms: Int
    let lastUpdate: Date
    
    var totalItems: Int {
        return activitiesCount + timeEntriesCount + projectsCount
    }
    
    var description: String {
        return """
        Search Index Statistics:
        - Activities: \(activitiesCount)
        - Time Entries: \(timeEntriesCount)
        - Projects: \(projectsCount)
        - Total Terms: \(totalTerms)
        - Last Update: \(lastUpdate)
        """
    }
}