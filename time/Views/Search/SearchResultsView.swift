import SwiftUI
import SwiftData

/// Displays search results with categorized sections
struct SearchResultsView: View {
    @ObservedObject var searchManager: SearchManager
    @State private var selectedTab: ResultTab = .all
    
    enum ResultTab: String, CaseIterable {
        case all = "All"
        case activities = "Activities"
        case timeEntries = "Time Entries"
        case projects = "Projects"
        
        var icon: String {
            switch self {
            case .all:
                return "list.bullet"
            case .activities:
                return "app.badge"
            case .timeEntries:
                return "clock"
            case .projects:
                return "folder"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search status and results count
            searchStatusHeader
            
            // Tab selector
            if searchManager.searchResults.hasResults {
                tabSelector
                
                Divider()
            }
            
            // Results content
            if searchManager.isSearching {
                searchingView
            } else if searchManager.searchResults.isEmpty {
                emptyResultsView
            } else {
                resultsContent
            }
        }
    }
    
    // MARK: - Search Status Header
    
    private var searchStatusHeader: some View {
        HStack {
            if searchManager.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 16, height: 16)
                
                Text("Searching...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if searchManager.searchResults.hasResults {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                
                Text("\(searchManager.searchResults.totalCount) results")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if !searchManager.searchQuery.isEmpty || searchManager.activeFilters.hasActiveFilters {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                
                Text("No results found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Active filters indicator
            if searchManager.activeFilters.hasActiveFilters {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))
                    
                    Text("Filtered")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ResultTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 13))
                        
                        // Count badge
                        if let count = getTabCount(tab), count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(selectedTab == tab ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.accentColor : Color.clear)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Results Content
    
    private var resultsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .all:
                    allResultsView
                case .activities:
                    activitiesResultsView
                case .timeEntries:
                    timeEntriesResultsView
                case .projects:
                    projectsResultsView
                }
            }
        }
    }
    
    private var allResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Activities section
            if !searchManager.searchResults.activities.isEmpty {
                resultSection(title: "Activities", count: searchManager.searchResults.activities.count) {
                    ForEach(Array(searchManager.searchResults.activities.prefix(5).enumerated()), id: \.element.activity.id) { index, rankedActivity in
                        ActivityResultRow(rankedActivity: rankedActivity)
                        
                        if index < min(4, searchManager.searchResults.activities.count - 1) {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                    
                    if searchManager.searchResults.activities.count > 5 {
                        Button("Show all \(searchManager.searchResults.activities.count) activities") {
                            selectedTab = .activities
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .padding(.leading, 40)
                        .padding(.top, 8)
                    }
                }
            }
            
            // Time Entries section
            if !searchManager.searchResults.timeEntries.isEmpty {
                resultSection(title: "Time Entries", count: searchManager.searchResults.timeEntries.count) {
                    ForEach(Array(searchManager.searchResults.timeEntries.prefix(5).enumerated()), id: \.element.timeEntry.id) { index, rankedEntry in
                        TimeEntryResultRow(rankedTimeEntry: rankedEntry)
                        
                        if index < min(4, searchManager.searchResults.timeEntries.count - 1) {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                    
                    if searchManager.searchResults.timeEntries.count > 5 {
                        Button("Show all \(searchManager.searchResults.timeEntries.count) time entries") {
                            selectedTab = .timeEntries
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .padding(.leading, 40)
                        .padding(.top, 8)
                    }
                }
            }
            
            // Projects section
            if !searchManager.searchResults.projects.isEmpty {
                resultSection(title: "Projects", count: searchManager.searchResults.projects.count) {
                    ForEach(Array(searchManager.searchResults.projects.prefix(5).enumerated()), id: \.element.project.id) { index, rankedProject in
                        ProjectResultRow(rankedProject: rankedProject)
                        
                        if index < min(4, searchManager.searchResults.projects.count - 1) {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                    
                    if searchManager.searchResults.projects.count > 5 {
                        Button("Show all \(searchManager.searchResults.projects.count) projects") {
                            selectedTab = .projects
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .padding(.leading, 40)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(16)
    }
    
    private var activitiesResultsView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(searchManager.searchResults.activities.enumerated()), id: \.element.activity.id) { index, rankedActivity in
                ActivityResultRow(rankedActivity: rankedActivity)
                
                if index < searchManager.searchResults.activities.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .padding(16)
    }
    
    private var timeEntriesResultsView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(searchManager.searchResults.timeEntries.enumerated()), id: \.element.timeEntry.id) { index, rankedEntry in
                TimeEntryResultRow(rankedTimeEntry: rankedEntry)
                
                if index < searchManager.searchResults.timeEntries.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .padding(16)
    }
    
    private var projectsResultsView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(searchManager.searchResults.projects.enumerated()), id: \.element.project.id) { index, rankedProject in
                ProjectResultRow(rankedProject: rankedProject)
                
                if index < searchManager.searchResults.projects.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - Empty and Loading States
    
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Please wait while we search through your data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            if searchManager.searchQuery.isEmpty && !searchManager.activeFilters.hasActiveFilters {
                Text("Start typing to search")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Search through your activities, time entries, and projects")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No results found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("• Different keywords")
                    Text("• Removing some filters")
                    Text("• Checking your spelling")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Helper Methods
    
    private func resultSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            content()
        }
    }
    
    private func getTabCount(_ tab: ResultTab) -> Int? {
        switch tab {
        case .all:
            return searchManager.searchResults.totalCount
        case .activities:
            return searchManager.searchResults.activities.count
        case .timeEntries:
            return searchManager.searchResults.timeEntries.count
        case .projects:
            return searchManager.searchResults.projects.count
        }
    }
}

// MARK: - Result Row Components

struct ActivityResultRow: View {
    let rankedActivity: RankedActivity
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // App icon placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(rankedActivity.activity.appName.prefix(1)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rankedActivity.activity.appName)
                    .font(.system(size: 14, weight: .medium))
                
                if let windowTitle = rankedActivity.activity.windowTitle {
                    Text(windowTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(rankedActivity.activity.startTime, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(rankedActivity.activity.durationString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Relevance score (for debugging)
            #if DEBUG
            Text(String(format: "%.1f", rankedActivity.relevanceScore))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            #endif
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct TimeEntryResultRow: View {
    let rankedTimeEntry: RankedTimeEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time entry icon
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.green.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rankedTimeEntry.timeEntry.title)
                    .font(.system(size: 14, weight: .medium))
                
                if let notes = rankedTimeEntry.timeEntry.notes {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(rankedTimeEntry.timeEntry.startTime, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(rankedTimeEntry.timeEntry.durationString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Relevance score (for debugging)
            #if DEBUG
            Text(String(format: "%.1f", rankedTimeEntry.relevanceScore))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            #endif
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct ProjectResultRow: View {
    let rankedProject: RankedProject
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Project color indicator
            Circle()
                .fill(rankedProject.project.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(rankedProject.project.name)
                    .font(.system(size: 14, weight: .medium))
                
                if let parentID = rankedProject.project.parentID {
                    Text("Subproject")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Relevance score (for debugging)
            #if DEBUG
            Text(String(format: "%.1f", rankedProject.relevanceScore))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            #endif
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    @StateObject var searchManager = SearchManager(modelContext: ModelContext(try! ModelContainer(for: Activity.self, TimeEntry.self, Project.self)))
    
    SearchResultsView(searchManager: searchManager)
        .frame(width: 600, height: 400)
}