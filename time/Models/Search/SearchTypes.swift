import Foundation
import SwiftUI

// MARK: - Search Results

/// Container for search results with ranking information
struct SearchResults {
    var activities: [RankedActivity] = []
    var timeEntries: [RankedTimeEntry] = []
    var projects: [RankedProject] = []
    var totalCount: Int = 0
    
    var isEmpty: Bool {
        return totalCount == 0
    }
    
    var hasResults: Bool {
        return !isEmpty
    }
}

/// Activity with relevance score for search results
struct RankedActivity {
    let activity: Activity
    let relevanceScore: Double
    
    /// Highlighted text for search result display
    var highlightedAppName: AttributedString {
        return AttributedString(activity.appName) // TODO: Add highlighting
    }
    
    var highlightedWindowTitle: AttributedString? {
        guard let windowTitle = activity.windowTitle else { return nil }
        return AttributedString(windowTitle) // TODO: Add highlighting
    }
}

/// Time entry with relevance score for search results
struct RankedTimeEntry {
    let timeEntry: TimeEntry
    let relevanceScore: Double
    
    /// Highlighted text for search result display
    var highlightedTitle: AttributedString {
        return AttributedString(timeEntry.title) // TODO: Add highlighting
    }
    
    var highlightedNotes: AttributedString? {
        guard let notes = timeEntry.notes else { return nil }
        return AttributedString(notes) // TODO: Add highlighting
    }
}

/// Project with relevance score for search results
struct RankedProject {
    let project: Project
    let relevanceScore: Double
    
    /// Highlighted text for search result display
    var highlightedName: AttributedString {
        return AttributedString(project.name) // TODO: Add highlighting
    }
}

// MARK: - Search Filters

/// Container for all search filter options
struct SearchFilters: Codable, Equatable {
    var startDate: Date?
    var endDate: Date?
    var selectedProjects: Set<String> = []
    var selectedApps: Set<String> = []
    var minDuration: TimeInterval?
    var maxDuration: TimeInterval?
    var excludeIdleTime: Bool = false
    var includeArchived: Bool = false
    
    /// Check if any filters are currently active
    var hasActiveFilters: Bool {
        return startDate != nil ||
               endDate != nil ||
               !selectedProjects.isEmpty ||
               !selectedApps.isEmpty ||
               minDuration != nil ||
               maxDuration != nil ||
               excludeIdleTime ||
               includeArchived
    }
    
    /// Get a summary description of active filters
    var filterSummary: String {
        var components: [String] = []
        
        if let startDate = startDate, let endDate = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            components.append("Date: \(formatter.string(from: startDate)) - \(formatter.string(from: endDate))")
        }
        
        if !selectedProjects.isEmpty {
            components.append("Projects: \(selectedProjects.count)")
        }
        
        if !selectedApps.isEmpty {
            components.append("Apps: \(selectedApps.count)")
        }
        
        if let minDuration = minDuration {
            let minutes = Int(minDuration / 60)
            components.append("Min duration: \(minutes)m")
        }
        
        if excludeIdleTime {
            components.append("Exclude idle")
        }
        
        return components.joined(separator: ", ")
    }
    
    /// Reset all filters to default values
    mutating func reset() {
        startDate = nil
        endDate = nil
        selectedProjects.removeAll()
        selectedApps.removeAll()
        minDuration = nil
        maxDuration = nil
        excludeIdleTime = false
        includeArchived = false
    }
}

// MARK: - Search Suggestions

/// Search suggestion with type information
struct SearchSuggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    
    enum SuggestionType {
        case history
        case appName
        case project
        case windowTitle
        case url
        case tag
    }
    
    var icon: String {
        switch type {
        case .history:
            return "clock.arrow.circlepath"
        case .appName:
            return "app.badge"
        case .project:
            return "folder"
        case .windowTitle:
            return "doc.text"
        case .url:
            return "globe"
        case .tag:
            return "tag"
        }
    }
    
    var displayText: String {
        return text
    }
}

// MARK: - Saved Searches

/// Saved search configuration
struct SavedSearch: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var query: String
    var filters: SearchFilters
    let createdAt: Date
    var lastUsedAt: Date?
    
    init(id: UUID = UUID(), name: String, query: String, filters: SearchFilters, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.query = query
        self.filters = filters
        self.createdAt = createdAt
    }
    
    /// Update the last used timestamp
    mutating func markAsUsed() {
        lastUsedAt = Date()
    }
    
    /// Get a description of the saved search
    var description: String {
        var components: [String] = []
        
        if !query.isEmpty {
            components.append("Query: \"\(query)\"")
        }
        
        if filters.hasActiveFilters {
            components.append(filters.filterSummary)
        }
        
        return components.joined(separator: " | ")
    }
}

// MARK: - Search Query Parsing

/// Parsed search query with structured components
struct ParsedQuery {
    var textTerms: [String] = []
    var appFilters: [String] = []
    var projectFilters: [String] = []
    var dateFilters: [DateFilter] = []
    var durationFilters: [DurationFilter] = []
    var excludeTerms: [String] = []
    
    struct DateFilter {
        let type: DateFilterType
        let date: Date
        
        enum DateFilterType {
            case after
            case before
            case on
        }
    }
    
    struct DurationFilter {
        let type: DurationFilterType
        let duration: TimeInterval
        
        enum DurationFilterType {
            case greaterThan
            case lessThan
            case equalTo
        }
    }
    
    /// Check if the parsed query has any meaningful content
    var isEmpty: Bool {
        return textTerms.isEmpty &&
               appFilters.isEmpty &&
               projectFilters.isEmpty &&
               dateFilters.isEmpty &&
               durationFilters.isEmpty &&
               excludeTerms.isEmpty
    }
}

/// Result of query validation
enum QueryValidationResult {
    case valid
    case invalid(String)
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Search Statistics

/// Statistics about search performance and usage
struct SearchStatistics {
    var totalSearches: Int = 0
    var averageSearchTime: TimeInterval = 0
    var mostSearchedTerms: [String: Int] = [:]
    var searchResultCounts: [Int] = []
    
    /// Add a search to statistics
    mutating func recordSearch(query: String, resultCount: Int, searchTime: TimeInterval) {
        totalSearches += 1
        
        // Update average search time
        averageSearchTime = (averageSearchTime * Double(totalSearches - 1) + searchTime) / Double(totalSearches)
        
        // Track search terms
        let terms = query.lowercased().components(separatedBy: .whitespaces)
        for term in terms where !term.isEmpty {
            mostSearchedTerms[term, default: 0] += 1
        }
        
        // Track result counts
        searchResultCounts.append(resultCount)
        
        // Keep only last 1000 searches for performance
        if searchResultCounts.count > 1000 {
            searchResultCounts.removeFirst(searchResultCounts.count - 1000)
        }
    }
    
    /// Get the most frequently searched terms
    var topSearchTerms: [(String, Int)] {
        return mostSearchedTerms.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }
    
    /// Get average number of results per search
    var averageResultCount: Double {
        guard !searchResultCounts.isEmpty else { return 0 }
        return Double(searchResultCounts.reduce(0, +)) / Double(searchResultCounts.count)
    }
}

// MARK: - Search Context

/// Context information for search operations
struct SearchContext {
    let currentDate: Date
    let timeZone: TimeZone
    let locale: Locale
    
    init(currentDate: Date = Date(), timeZone: TimeZone = .current, locale: Locale = .current) {
        self.currentDate = currentDate
        self.timeZone = timeZone
        self.locale = locale
    }
}

// MARK: - Search Error Types

/// Errors that can occur during search operations
enum SearchError: LocalizedError {
    case invalidQuery(String)
    case databaseError(Error)
    case indexingError(String)
    case timeoutError
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery(let message):
            return "Invalid search query: \(message)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .indexingError(let message):
            return "Search indexing error: \(message)"
        case .timeoutError:
            return "Search operation timed out"
        case .insufficientPermissions:
            return "Insufficient permissions to perform search"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidQuery:
            return "Please check your search syntax and try again."
        case .databaseError:
            return "Please try again. If the problem persists, restart the application."
        case .indexingError:
            return "The search index may need to be rebuilt."
        case .timeoutError:
            return "Try a more specific search query to reduce the number of results."
        case .insufficientPermissions:
            return "Please check your application permissions."
        }
    }
}