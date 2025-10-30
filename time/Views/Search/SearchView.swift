import SwiftUI
import SwiftData

/// Main search interface that combines search bar, filters, and results
struct SearchView: View {
    @StateObject private var searchManager: SearchManager
    @State private var isSearchExpanded = false
    @Environment(\.modelContext) private var modelContext
    
    init(modelContext: ModelContext) {
        self._searchManager = StateObject(wrappedValue: SearchManager(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(searchManager: searchManager)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            // Active filters summary
            if searchManager.activeFilters.hasActiveFilters {
                activeFiltersBar
            }
            
            // Search results
            SearchResultsView(searchManager: searchManager)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            searchManager.rebuildSearchIndex()
        }
    }
    
    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Date range filter
                if let startDate = searchManager.activeFilters.startDate,
                   let endDate = searchManager.activeFilters.endDate {
                    filterChip(
                        title: "Date: \(formatDateRange(startDate, endDate))",
                        icon: "calendar"
                    ) {
                        var filters = searchManager.activeFilters
                        filters.startDate = nil
                        filters.endDate = nil
                        searchManager.applyFilters(filters)
                    }
                }
                
                // Project filters
                if !searchManager.activeFilters.selectedProjects.isEmpty {
                    filterChip(
                        title: "Projects: \(searchManager.activeFilters.selectedProjects.count)",
                        icon: "folder"
                    ) {
                        var filters = searchManager.activeFilters
                        filters.selectedProjects.removeAll()
                        searchManager.applyFilters(filters)
                    }
                }
                
                // App filters
                if !searchManager.activeFilters.selectedApps.isEmpty {
                    filterChip(
                        title: "Apps: \(searchManager.activeFilters.selectedApps.count)",
                        icon: "app.badge"
                    ) {
                        var filters = searchManager.activeFilters
                        filters.selectedApps.removeAll()
                        searchManager.applyFilters(filters)
                    }
                }
                
                // Duration filter
                if let minDuration = searchManager.activeFilters.minDuration {
                    let minutes = Int(minDuration / 60)
                    filterChip(
                        title: "Min: \(minutes)m",
                        icon: "clock"
                    ) {
                        var filters = searchManager.activeFilters
                        filters.minDuration = nil
                        searchManager.applyFilters(filters)
                    }
                }
                
                // Idle time filter
                if searchManager.activeFilters.excludeIdleTime {
                    filterChip(
                        title: "No idle time",
                        icon: "moon.zzz"
                    ) {
                        var filters = searchManager.activeFilters
                        filters.excludeIdleTime = false
                        searchManager.applyFilters(filters)
                    }
                }
                
                // Clear all button
                Button("Clear All") {
                    searchManager.clearFilters()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func filterChip(title: String, icon: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            
            Text(title)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .cornerRadius(12)
    }
    
    private func formatDateRange(_ startDate: Date, _ endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return formatter.string(from: startDate)
        } else {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}

/// Compact search bar for toolbar integration
struct CompactSearchBarView: View {
    @ObservedObject var searchManager: SearchManager
    @State private var showingFullSearch = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search...", text: $searchManager.searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    if !searchManager.searchQuery.isEmpty {
                        showingFullSearch = true
                    }
                }
                .onChange(of: searchManager.searchQuery) { _, newValue in
                    if !newValue.isEmpty {
                        searchManager.search()
                    }
                }
            
            if !searchManager.searchQuery.isEmpty {
                Button(action: {
                    searchManager.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            
            if searchManager.activeFilters.hasActiveFilters {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .onTapGesture {
            if !isSearchFocused && (!searchManager.searchQuery.isEmpty || searchManager.activeFilters.hasActiveFilters) {
                showingFullSearch = true
            }
        }
        .sheet(isPresented: $showingFullSearch) {
            NavigationView {
                SearchView(modelContext: searchManager.modelContext)
                    .navigationTitle("Search")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingFullSearch = false
                            }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }
}

/// Search interface for integration into existing views
struct IntegratedSearchView: View {
    @ObservedObject var searchManager: SearchManager
    let onResultSelected: ((any SearchResultItem) -> Void)?
    
    init(searchManager: SearchManager, onResultSelected: ((any SearchResultItem) -> Void)? = nil) {
        self.searchManager = searchManager
        self.onResultSelected = onResultSelected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(searchManager: searchManager)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            if searchManager.searchResults.hasResults || searchManager.isSearching {
                Divider()
                
                SearchResultsView(searchManager: searchManager)
            }
        }
    }
}

// MARK: - Search Result Item Protocol

protocol SearchResultItem: Identifiable {
    var title: String { get }
    var subtitle: String? { get }
    var type: SearchResultType { get }
}

enum SearchResultType {
    case activity
    case timeEntry
    case project
}

// MARK: - Extensions for Search Result Items

extension Activity: SearchResultItem {
    var title: String { appName }
    var subtitle: String? { windowTitle }
    var type: SearchResultType { .activity }
}

extension TimeEntry: SearchResultItem {
    var subtitle: String? { notes }
    var type: SearchResultType { .timeEntry }
}

extension Project: SearchResultItem {
    var title: String { name }
    var subtitle: String? { parentID != nil ? "Subproject" : nil }
    var type: SearchResultType { .project }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(for: Activity.self, TimeEntry.self, Project.self)
    
    return SearchView(modelContext: container.mainContext)
        .frame(width: 800, height: 600)
}