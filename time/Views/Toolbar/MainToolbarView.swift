import AppKit
import SwiftData
import SwiftUI

struct MainToolbarView: ToolbarContent {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @Binding var searchText: String

    init(
        selectedDateRange: Binding<AppDateRange>,
        selectedPreset: Binding<AppDateRangePreset?>,
        searchText: Binding<String>,
        modelContext: ModelContext
    ) {
        _selectedDateRange = selectedDateRange
        _selectedPreset = selectedPreset
        _searchText = searchText
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            DateNavigatorView(selectedDateRange: $selectedDateRange, selectedPreset: $selectedPreset)
        }
    }
}
