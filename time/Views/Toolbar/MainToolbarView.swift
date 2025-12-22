import AppKit
import SwiftData
import SwiftUI

struct MainToolbarView: ToolbarContent {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Binding var isAddingProject: Bool
    @Binding var isStartingTimer: Bool
    @Binding var isAddingTimeEntry: Bool
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @Binding var searchText: String

    init(
        isAddingProject: Binding<Bool>,
        isStartingTimer: Binding<Bool>,
        isAddingTimeEntry: Binding<Bool>,
        selectedDateRange: Binding<AppDateRange>,
        selectedPreset: Binding<AppDateRangePreset?>,
        searchText: Binding<String>,
        modelContext: ModelContext
    ) {
        _isAddingProject = isAddingProject
        _isStartingTimer = isStartingTimer
        _isAddingTimeEntry = isAddingTimeEntry
        _selectedDateRange = selectedDateRange
        _selectedPreset = selectedPreset
        _searchText = searchText
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: {
                isAddingProject = true
            }) {
                HStack {
                    Image(systemName: "plus.rectangle")
                    Text("New Project")
                }
            }
            .accessibilityIdentifier("toolbar.newProjectButton")
        }

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

        ToolbarItem(placement: .navigation) {
            HStack {
                Button(action: {
                    if appState.isTimerActive {
                        Task {
                            await appState.stopTimer()
                        }
                    } else {
                        isStartingTimer.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: appState.isTimerActive ? "stop.circle" : "play.circle")
                        Text(appState.isTimerActive ? "Stop Timer" : "Start Timer")
                    }
                }
                .accessibilityIdentifier("toolbar.timerButton")
                .popover(isPresented: $isStartingTimer) {
                    StartTimerView(isPresented: $isStartingTimer)
                }

                // Show timer display when active
                if appState.isTimerActive {
                    Divider()
                        .frame(height: 20)

                    TimerDisplayView()
                }
            }
        }

        ToolbarItem(placement: .principal) {
            DateNavigatorView(selectedDateRange: $selectedDateRange, selectedPreset: $selectedPreset)
        }
    }
}
