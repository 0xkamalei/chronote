import SwiftUI
import SwiftData

/// Main search bar component with live search and suggestions
struct SearchBarView: View {
    @ObservedObject var searchManager: SearchManager
    @State private var showingSuggestions = false
    @State private var showingFilters = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                // Search text field
                TextField("Search activities, time entries, and projects...", text: $searchManager.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        searchManager.searchImmediate()
                        hideKeyboard()
                    }
                    .onChange(of: searchManager.searchQuery) { _, newValue in
                        searchManager.search()
                        showingSuggestions = !newValue.isEmpty && isSearchFocused
                    }
                
                // Clear button
                if !searchManager.searchQuery.isEmpty {
                    Button(action: {
                        searchManager.clearSearch()
                        showingSuggestions = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                
                // Filter button
                Button(action: {
                    showingFilters.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                        
                        if searchManager.activeFilters.hasActiveFilters {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(searchManager.activeFilters.hasActiveFilters ? .blue : .secondary)
                .popover(isPresented: $showingFilters) {
                    SearchFiltersView(searchManager: searchManager)
                        .frame(width: 350, height: 400)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSearchFocused ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            
            // Search suggestions dropdown
            if showingSuggestions && isSearchFocused {
                SearchSuggestionsView(searchManager: searchManager) { suggestion in
                    searchManager.searchQuery = suggestion.text
                    searchManager.searchImmediate()
                    showingSuggestions = false
                    hideKeyboard()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(.top, 4)
            }
        }
        .onTapGesture {
            if !isSearchFocused {
                isSearchFocused = true
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            if !focused {
                showingSuggestions = false
            } else if !searchManager.searchQuery.isEmpty {
                showingSuggestions = true
            }
        }
    }
    
    private func hideKeyboard() {
        isSearchFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}

/// Search suggestions dropdown
struct SearchSuggestionsView: View {
    @ObservedObject var searchManager: SearchManager
    let onSuggestionSelected: (SearchSuggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let suggestions = searchManager.getSearchSuggestions()
            
            if !suggestions.isEmpty {
                ForEach(suggestions) { suggestion in
                    Button(action: {
                        onSuggestionSelected(suggestion)
                    }) {
                        HStack {
                            Image(systemName: suggestion.icon)
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                                .frame(width: 16)
                            
                            Text(suggestion.displayText)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(suggestion.type.displayName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                    .onHover { hovering in
                        // Add hover effect if needed
                    }
                    
                    if suggestion.id != suggestions.last?.id {
                        Divider()
                    }
                }
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    Text("No suggestions")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// MARK: - Extensions

extension SearchSuggestion.SuggestionType {
    var displayName: String {
        switch self {
        case .history:
            return "Recent"
        case .appName:
            return "App"
        case .project:
            return "Project"
        case .windowTitle:
            return "Window"
        case .url:
            return "URL"
        case .tag:
            return "Tag"
        }
    }
}

// MARK: - Preview

#Preview {
    @StateObject var searchManager = SearchManager(modelContext: ModelContext(try! ModelContainer(for: Activity.self, TimeEntry.self, Project.self)))
    
    VStack {
        SearchBarView(searchManager: searchManager)
            .padding()
        
        Spacer()
    }
    .frame(width: 400, height: 200)
}