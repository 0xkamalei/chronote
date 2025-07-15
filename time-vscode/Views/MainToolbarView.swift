
import SwiftUI

struct MainToolbarView: ToolbarContent {
    @EnvironmentObject private var appState: AppState
    @Binding var isAddingProject: Bool
    @Binding var isStartingTimer: Bool
    @Binding var isAddingTimeEntry: Bool
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @Binding var searchText: String

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
        }
        
        ToolbarItem(placement: .navigation) {
            Button(action: {
                isAddingTimeEntry = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("New Time Entry")
                }
            }
        }
        
        ToolbarItem(placement: .navigation) {
            Button(action: {
                if appState.isTimerActive {
                    appState.isTimerActive = false
                } else {
                    isStartingTimer.toggle()
                }
            }) {
                HStack {
                    Image(systemName: appState.isTimerActive ? "stop.circle" : "play.circle")
                    Text(appState.isTimerActive ? "Stop Timer" : "Start Timer")
                }
            }
            .popover(isPresented: $isStartingTimer) {
                StartTimerView(isPresented: $isStartingTimer)
            }
        }
        
        ToolbarItem(placement: .principal) {
            DateNavigatorView(selectedDateRange: $selectedDateRange, selectedPreset: $selectedPreset)
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: {}) {
                HStack {
                    Image(systemName: "desktopcomputer")
                    Text("Devices")
                }
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: {}) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filters")
                }
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 140)
            }
            .padding(5)
            .cornerRadius(8)
        }
    }
}
