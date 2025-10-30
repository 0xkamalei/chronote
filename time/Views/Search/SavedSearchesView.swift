import SwiftUI
import SwiftData

/// View for managing saved searches
struct SavedSearchesView: View {
    @ObservedObject var searchManager: SearchManager
    @State private var showingSaveDialog = false
    @State private var newSearchName = ""
    @State private var selectedSearch: SavedSearch?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Saved Searches")
                    .font(.headline)
                
                Spacer()
                
                Button("Save Current") {
                    showingSaveDialog = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchManager.searchQuery.isEmpty && !searchManager.activeFilters.hasActiveFilters)
            }
            
            // Saved searches list
            if searchManager.savedSearches.isEmpty {
                emptyStateView
            } else {
                savedSearchesList
            }
        }
        .padding()
        .sheet(isPresented: $showingSaveDialog) {
            saveSearchDialog
        }
        .alert("Delete Saved Search", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let search = selectedSearch {
                    searchManager.deleteSavedSearch(search)
                    selectedSearch = nil
                }
            }
        } message: {
            if let search = selectedSearch {
                Text("Are you sure you want to delete '\(search.name)'? This action cannot be undone.")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Saved Searches")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Save your frequently used searches for quick access")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private var savedSearchesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(searchManager.savedSearches) { savedSearch in
                    SavedSearchRow(
                        savedSearch: savedSearch,
                        onLoad: {
                            searchManager.loadSavedSearch(savedSearch)
                        },
                        onDelete: {
                            selectedSearch = savedSearch
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
        }
    }
    
    private var saveSearchDialog: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Save Search")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Search Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter a name for this search", text: $newSearchName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Preview of what will be saved
            VStack(alignment: .leading, spacing: 8) {
                Text("This search will include:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    if !searchManager.searchQuery.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Query: \"\(searchManager.searchQuery)\"")
                                .font(.caption)
                        }
                    }
                    
                    if searchManager.activeFilters.hasActiveFilters {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Filters: \(searchManager.activeFilters.filterSummary)")
                                .font(.caption)
                        }
                    }
                }
                .padding(.leading, 16)
            }
            
            HStack {
                Button("Cancel") {
                    showingSaveDialog = false
                    newSearchName = ""
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Save") {
                    searchManager.saveCurrentSearch(name: newSearchName)
                    showingSaveDialog = false
                    newSearchName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newSearchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

/// Individual saved search row
struct SavedSearchRow: View {
    let savedSearch: SavedSearch
    let onLoad: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(savedSearch.name)
                    .font(.system(size: 14, weight: .medium))
                
                Text(savedSearch.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("Created: \(savedSearch.createdAt, style: .date)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let lastUsed = savedSearch.lastUsedAt {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("Last used: \(lastUsed, style: .relative)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 8) {
                    Button("Load") {
                        onLoad()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .background(isHovering ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onLoad()
        }
    }
}

/// Search history view
struct SearchHistoryView: View {
    @ObservedObject var searchManager: SearchManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search History")
                    .font(.headline)
                
                Spacer()
                
                if !searchManager.searchHistory.isEmpty {
                    Button("Clear History") {
                        searchManager.clearHistory()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
            
            if searchManager.searchHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Search History")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Your recent searches will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(searchManager.searchHistory.enumerated()), id: \.element) { index, query in
                            SearchHistoryRow(
                                query: query,
                                isRecent: index < 3,
                                onSelect: {
                                    searchManager.searchQuery = query
                                    searchManager.searchImmediate()
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
}

/// Individual search history row
struct SearchHistoryRow: View {
    let query: String
    let isRecent: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(isRecent ? .blue : .secondary)
                .font(.system(size: 12))
            
            Text(query)
                .font(.system(size: 13))
                .foregroundColor(isHovering ? .primary : .secondary)
            
            Spacer()
            
            if isRecent {
                Text("Recent")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

/// Advanced search options view
struct AdvancedSearchOptionsView: View {
    @ObservedObject var searchManager: SearchManager
    @State private var showingQueryHelp = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Advanced Search")
                    .font(.headline)
                
                Spacer()
                
                Button("Query Help") {
                    showingQueryHelp = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Search Operators")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    operatorExample("app:Xcode", "Search in specific app")
                    operatorExample("project:\"My Project\"", "Search in specific project")
                    operatorExample("after:2024-01-01", "Search after date")
                    operatorExample("duration:>30m", "Search by duration")
                    operatorExample("-idle", "Exclude idle time")
                    operatorExample("\"exact phrase\"", "Search exact phrase")
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Searches")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    quickSearchButton("Today's activities", "after:today")
                    quickSearchButton("Long sessions", "duration:>1h")
                    quickSearchButton("Development work", "app:Xcode OR app:\"Visual Studio Code\"")
                    quickSearchButton("This week", "after:thisweek")
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingQueryHelp) {
            SearchQueryHelpView()
        }
    }
    
    private func operatorExample(_ query: String, _ description: String) -> some View {
        HStack {
            Text(query)
                .font(.system(size: 12).monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private func quickSearchButton(_ title: String, _ query: String) -> some View {
        Button(title) {
            searchManager.searchQuery = query
            searchManager.searchImmediate()
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .cornerRadius(6)
    }
}

/// Search query help view
struct SearchQueryHelpView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection("Basic Search", [
                        ("Simple text", "Search for any text in activities, time entries, or projects"),
                        ("\"Exact phrase\"", "Search for an exact phrase using quotes"),
                        ("-exclude", "Exclude terms by prefixing with minus sign")
                    ])
                    
                    helpSection("Filter Operators", [
                        ("app:name", "Filter by application name"),
                        ("project:name", "Filter by project name"),
                        ("after:date", "Show items after specific date"),
                        ("before:date", "Show items before specific date"),
                        ("on:date", "Show items on specific date"),
                        ("duration:time", "Filter by duration (e.g., >30m, <2h)")
                    ])
                    
                    helpSection("Date Formats", [
                        ("2024-01-01", "Specific date (YYYY-MM-DD)"),
                        ("today", "Today's date"),
                        ("yesterday", "Yesterday's date"),
                        ("thisweek", "Start of current week"),
                        ("lastweek", "Start of last week"),
                        ("3d", "3 days ago"),
                        ("1w", "1 week ago")
                    ])
                    
                    helpSection("Duration Formats", [
                        ("30m", "30 minutes"),
                        ("1h", "1 hour"),
                        ("1h30m", "1 hour 30 minutes"),
                        (">30m", "More than 30 minutes"),
                        ("<2h", "Less than 2 hours")
                    ])
                    
                    helpSection("Examples", [
                        ("app:Xcode after:today", "Xcode usage today"),
                        ("project:\"My Project\" duration:>1h", "Long sessions in My Project"),
                        ("\"bug fix\" -test", "Bug fix work excluding tests"),
                        ("after:lastweek before:today", "Last week's activities")
                    ])
                }
                .padding()
            }
            .navigationTitle("Search Query Help")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func helpSection(_ title: String, _ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack(alignment: .top) {
                        Text(item.0)
                            .font(.system(size: 12).monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                            .frame(minWidth: 120, alignment: .leading)
                        
                        Text(item.1)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(for: Activity.self, TimeEntry.self, Project.self)
    let searchManager = SearchManager(modelContext: container.mainContext)
    
    TabView {
        SavedSearchesView(searchManager: searchManager)
            .tabItem {
                Label("Saved", systemImage: "bookmark")
            }
        
        SearchHistoryView(searchManager: searchManager)
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        
        AdvancedSearchOptionsView(searchManager: searchManager)
            .tabItem {
                Label("Advanced", systemImage: "gearshape")
            }
    }
    .frame(width: 500, height: 400)
}