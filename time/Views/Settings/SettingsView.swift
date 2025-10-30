import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .notifications
    
    enum SettingsTab: String, CaseIterable {
        case notifications = "Notifications"
        case productivity = "Productivity"
        case tracking = "Tracking"
        case general = "General"
        
        var icon: String {
            switch self {
            case .notifications:
                return "bell"
            case .productivity:
                return "chart.bar"
            case .tracking:
                return "clock"
            case .general:
                return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Settings")
            .frame(minWidth: 200)
        } detail: {
            // Detail View
            Group {
                switch selectedTab {
                case .notifications:
                    NotificationSettingsDetailView()
                case .productivity:
                    ProductivitySettingsDetailView()
                case .tracking:
                    TrackingSettingsDetailView()
                case .general:
                    GeneralSettingsDetailView()
                }
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Notification Settings Detail

struct NotificationSettingsDetailView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSubTab: NotificationSubTab = .preferences
    
    enum NotificationSubTab: String, CaseIterable {
        case preferences = "Preferences"
        case history = "History"
        
        var icon: String {
            switch self {
            case .preferences:
                return "slider.horizontal.3"
            case .history:
                return "clock.arrow.circlepath"
            }
        }
    }
    
    var body: some View {
        VStack {
            // Sub-navigation
            Picker("Notification Section", selection: $selectedSubTab) {
                ForEach(NotificationSubTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            switch selectedSubTab {
            case .preferences:
                NotificationPreferencesView(notificationManager: appState.notificationManager)
            case .history:
                NotificationHistoryView(notificationManager: appState.notificationManager)
            }
        }
        .navigationTitle("Notification Settings")
    }
}

// MARK: - Productivity Settings Detail

struct ProductivitySettingsDetailView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Daily Goals") {
                HStack {
                    Text("Daily Goal:")
                    Spacer()
                    TextField("Hours", value: $appState.productivityGoalTracker.dailyGoalHours, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("hours")
                }
                
                HStack {
                    Text("Current Progress:")
                    Spacer()
                    ProgressView(value: appState.productivityGoalTracker.dailyProgress)
                        .frame(width: 200)
                    Text("\(Int(appState.productivityGoalTracker.dailyProgress * 100))%")
                        .frame(width: 40, alignment: .trailing)
                }
                
                if appState.productivityGoalTracker.dailyGoalReached {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Daily goal reached!")
                            .foregroundColor(.green)
                    }
                }
            }
            
            Section("Weekly Goals") {
                HStack {
                    Text("Weekly Goal:")
                    Spacer()
                    TextField("Hours", value: $appState.productivityGoalTracker.weeklyGoalHours, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("hours")
                }
                
                HStack {
                    Text("Current Progress:")
                    Spacer()
                    ProgressView(value: appState.productivityGoalTracker.weeklyProgress)
                        .frame(width: 200)
                    Text("\(Int(appState.productivityGoalTracker.weeklyProgress * 100))%")
                        .frame(width: 40, alignment: .trailing)
                }
                
                if appState.productivityGoalTracker.weeklyGoalReached {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Weekly goal reached!")
                            .foregroundColor(.green)
                    }
                }
            }
            
            Section("Actions") {
                Button("Update Progress Now") {
                    appState.productivityGoalTracker.updateProgress()
                }
                
                Button("Schedule Daily Summary") {
                    appState.productivityGoalTracker.scheduleDailySummary()
                }
                
                Button("Schedule Weekly Summary") {
                    appState.productivityGoalTracker.scheduleWeeklySummary()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Productivity Settings")
    }
}

// MARK: - Tracking Settings Detail

struct TrackingSettingsDetailView: View {
    @EnvironmentObject var appState: AppState
    @State private var trackingStatus = ActivityTracker.shared.getTrackingStatus()
    
    var body: some View {
        Form {
            Section("Tracking Status") {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(trackingStatus.statusDescription)
                        .foregroundColor(trackingStatus.isHealthy ? .green : .red)
                }
                
                HStack {
                    Text("Current App:")
                    Spacer()
                    Text(trackingStatus.currentApplication ?? "None")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Observers:")
                    Spacer()
                    Text("\(trackingStatus.observerCount)")
                }
                
                HStack {
                    Text("Idle Status:")
                    Spacer()
                    Text(trackingStatus.isIdlePaused ? "Paused" : "Active")
                        .foregroundColor(trackingStatus.isIdlePaused ? .orange : .green)
                }
            }
            
            Section("Configuration") {
                Toggle("Enable Tracking", isOn: .constant(trackingStatus.isTrackingEnabled))
                    .disabled(true) // Read-only for now
                
                Toggle("Track Window Titles", isOn: .constant(trackingStatus.trackWindowTitles))
                    .disabled(true) // Read-only for now
                
                Toggle("Capture Browser Data", isOn: .constant(trackingStatus.captureBrowserData))
                    .disabled(true) // Read-only for now
                
                HStack {
                    Text("Minimum Duration:")
                    Spacer()
                    Text("\(trackingStatus.minimumActivityDuration, specifier: "%.1f")s")
                }
            }
            
            Section("Context Capture") {
                Text(trackingStatus.contextCaptureStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Actions") {
                Button("Refresh Status") {
                    trackingStatus = ActivityTracker.shared.getTrackingStatus()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Tracking Settings")
        .onAppear {
            trackingStatus = ActivityTracker.shared.getTrackingStatus()
        }
    }
}

// MARK: - General Settings Detail

struct GeneralSettingsDetailView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Timer Settings") {
                HStack {
                    Text("Default Duration:")
                    Spacer()
                    TextField("Minutes", value: Binding(
                        get: { appState.timerManager.defaultEstimatedDuration / 60 },
                        set: { appState.timerManager.defaultEstimatedDuration = $0 * 60 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    Text("minutes")
                }
                
                Toggle("Enable Notifications", isOn: $appState.timerManager.enableNotifications)
                Toggle("Enable Sounds", isOn: $appState.timerManager.enableSounds)
                Toggle("Auto-create Time Entries", isOn: $appState.timerManager.autoCreateTimeEntry)
            }
            
            Section("Time Entry Settings") {
                Toggle("Automatic Time Entry Creation", isOn: $appState.automaticTimeEntryCreation)
            }
            
            Section("Application") {
                HStack {
                    Text("Version:")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build:")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General Settings")
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppState())
}