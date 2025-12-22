import AppKit
import SwiftData
import SwiftUI

struct MainToolbarView: ToolbarContent {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Binding var isAddingTimeEntry: Bool
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @Binding var searchText: String

    init(
        isAddingTimeEntry: Binding<Bool>,
        selectedDateRange: Binding<AppDateRange>,
        selectedPreset: Binding<AppDateRangePreset?>,
        searchText: Binding<String>,
        modelContext: ModelContext
    ) {
        _isAddingTimeEntry = isAddingTimeEntry
        _selectedDateRange = selectedDateRange
        _selectedPreset = selectedPreset
        _searchText = searchText
    }

    var body: some ToolbarContent {

        if appState.selectedSidebar == "Time Entries" {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    isAddingTimeEntry = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("New Time Entry")
                    }
                }
                .accessibilityIdentifier("toolbar.newTimeEntryButton")
            }
        }



        ToolbarItem(placement: .principal) {
            DateNavigatorView(selectedDateRange: $selectedDateRange, selectedPreset: $selectedPreset)
        }
    }
}
