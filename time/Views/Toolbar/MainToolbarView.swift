
import SwiftUI
import SwiftData
import AppKit

struct MainToolbarView: ToolbarContent {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Binding var isAddingProject: Bool
    @Binding var isStartingTimer: Bool
    @Binding var isAddingTimeEntry: Bool
    @Binding var selectedDateRange: AppDateRange
    @Binding var selectedPreset: AppDateRangePreset?
    @Binding var searchText: String
    
    @StateObject private var searchManager: SearchManager
    
    init(
        isAddingProject: Binding<Bool>,
        isStartingTimer: Binding<Bool>,
        isAddingTimeEntry: Binding<Bool>,
        selectedDateRange: Binding<AppDateRange>,
        selectedPreset: Binding<AppDateRangePreset?>,
        searchText: Binding<String>,
        modelContext: ModelContext
    ) {
        self._isAddingProject = isAddingProject
        self._isStartingTimer = isStartingTimer
        self._isAddingTimeEntry = isAddingTimeEntry
        self._selectedDateRange = selectedDateRange
        self._selectedPreset = selectedPreset
        self._searchText = searchText
        self._searchManager = StateObject(wrappedValue: SearchManager(modelContext: modelContext))
    }

    private func openSettingsWindow() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        settingsWindow.title = "Settings"
        settingsWindow.contentView = NSHostingView(rootView: 
            SettingsView()
                .environmentObject(appState)
        )
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
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
            CompactSearchBarView(searchManager: searchManager)
                .frame(width: 180)
                .accessibilityIdentifier("toolbar.searchField")
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                openSettingsWindow()
            }) {
                Image(systemName: "gear")
            }
            .help("Settings")
            .accessibilityIdentifier("toolbar.settingsButton")
        }
    }
}
