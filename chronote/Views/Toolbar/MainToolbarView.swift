import AppKit
import SwiftData
import SwiftUI

struct MainToolbarView: ToolbarContent {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

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
        ToolbarItem(placement: .navigation) {
            EventControlView()
        }

        ToolbarItem(placement: .principal) {
            DateNavigatorView(selectedDateRange: $selectedDateRange, selectedPreset: $selectedPreset)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                appTheme = appTheme.next
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: appTheme.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Appearance")
        }
    }
}

struct EventControlView: View {
    @Environment(EventManager.self) private var eventManager
    @State private var showStartEventPopover: Bool = false
    
    var body: some View {
        HStack {
            if let currentEvent = eventManager.currentEvent {
                Button {
                    eventManager.stopCurrentEvent()
                } label: {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                        Text("Stop \(currentEvent.name)")
                        TimerView(startTime: currentEvent.startTime)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            } else {
                Button {
                    showStartEventPopover = true
                } label: {
                    HStack {
                        Image(systemName: "play.circle")
                        Text("Start Event")
                    }
                }
                .popover(isPresented: $showStartEventPopover) {
                    StartEventView()
                }
            }
        }
    }
}

struct TimerView: View {
    let startTime: Date
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(durationString)
            .monospacedDigit()
            .onReceive(timer) { input in
                now = input
            }
            .onAppear {
                now = Date()
            }
    }
    
    var durationString: String {
        let interval = now.timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
