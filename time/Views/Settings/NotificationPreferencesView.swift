import SwiftUI

struct NotificationPreferencesView: View {
    @ObservedObject var notificationManager: NotificationManager
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Form {
            // General Settings Section
            Section("General") {
                Toggle("Enable Notifications", isOn: $notificationManager.preferences.notificationsEnabled)
                    .onChange(of: notificationManager.preferences.notificationsEnabled) { _, newValue in
                        if newValue && !notificationManager.notificationPermissionGranted {
                            Task {
                                let granted = await notificationManager.requestPermissionIfNeeded()
                                if !granted {
                                    showingPermissionAlert = true
                                    notificationManager.preferences.notificationsEnabled = false
                                }
                            }
                        }
                        notificationManager.savePreferences()
                    }
                
                if notificationManager.preferences.notificationsEnabled {
                    Toggle("Respect Quiet Hours", isOn: $notificationManager.preferences.respectQuietHours)
                        .onChange(of: notificationManager.preferences.respectQuietHours) { _, _ in
                            notificationManager.savePreferences()
                        }
                    
                    if notificationManager.preferences.respectQuietHours {
                        QuietHoursSection(notificationManager: notificationManager)
                    }
                }
            }
            
            if notificationManager.preferences.notificationsEnabled {
                // Timer Notifications Section
                TimerNotificationsSection(notificationManager: notificationManager)
                
                // Tracking Status Section
                TrackingStatusSection(notificationManager: notificationManager)
                
                // Productivity Goals Section
                ProductivityGoalsSection(notificationManager: notificationManager)
                
                // Inactivity Reminders Section
                InactivityRemindersSection(notificationManager: notificationManager)
                
                // Summary Notifications Section
                SummaryNotificationsSection(notificationManager: notificationManager)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notification Preferences")
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open System Preferences") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications for this app in System Preferences to receive alerts.")
        }
    }
}

// MARK: - Quiet Hours Section

struct QuietHoursSection: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quiet Hours Start:")
                Spacer()
                DatePicker("", selection: Binding(
                    get: { notificationManager.preferences.quietHoursStart ?? Date() },
                    set: { 
                        notificationManager.preferences.quietHoursStart = $0
                        notificationManager.savePreferences()
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            }
            
            HStack {
                Text("Quiet Hours End:")
                Spacer()
                DatePicker("", selection: Binding(
                    get: { notificationManager.preferences.quietHoursEnd ?? Date() },
                    set: { 
                        notificationManager.preferences.quietHoursEnd = $0
                        notificationManager.savePreferences()
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            }
        }
        .padding(.leading, 20)
    }
}

// MARK: - Timer Notifications Section

struct TimerNotificationsSection: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        Section("Timer Notifications") {
            Toggle("Timer Completion Alerts", isOn: $notificationManager.preferences.timerNotificationsEnabled)
                .onChange(of: notificationManager.preferences.timerNotificationsEnabled) { _, _ in
                    notificationManager.savePreferences()
                }
            
            if notificationManager.preferences.timerNotificationsEnabled {
                Toggle("Play Sounds", isOn: $notificationManager.preferences.timerSoundsEnabled)
                    .onChange(of: notificationManager.preferences.timerSoundsEnabled) { _, _ in
                        notificationManager.savePreferences()
                    }
                
                HStack {
                    Text("Sound:")
                    Spacer()
                    Picker("Timer Sound", selection: $notificationManager.preferences.timerSoundName) {
                        Text("Default").tag("default.aiff")
                        Text("Bell").tag("bell.aiff")
                        Text("Chime").tag("chime.aiff")
                        Text("Ding").tag("ding.aiff")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: notificationManager.preferences.timerSoundName) { _, _ in
                        notificationManager.savePreferences()
                    }
                }
                
                Toggle("Interval Notifications", isOn: $notificationManager.preferences.timerIntervalNotificationsEnabled)
                    .onChange(of: notificationManager.preferences.timerIntervalNotificationsEnabled) { _, _ in
                        notificationManager.savePreferences()
                    }
                
                if notificationManager.preferences.timerIntervalNotificationsEnabled {
                    HStack {
                        Text("Interval:")
                        Spacer()
                        Picker("Interval", selection: $notificationManager.preferences.timerIntervalMinutes) {
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("45 minutes").tag(45)
                            Text("60 minutes").tag(60)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: notificationManager.preferences.timerIntervalMinutes) { _, _ in
                            notificationManager.savePreferences()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tracking Status Section

struct TrackingStatusSection: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        Section("Tracking Status") {
            Toggle("Tracking Status Alerts", isOn: $notificationManager.preferences.trackingStatusNotificationsEnabled)
                .onChange(of: notificationManager.preferences.trackingStatusNotificationsEnabled) { _, _ in
                    notificationManager.savePreferences()
                }
            
            if notificationManager.preferences.trackingStatusNotificationsEnabled {
                Toggle("Play Sounds", isOn: $notificationManager.preferences.trackingStatusSoundsEnabled)
                    .onChange(of: notificationManager.preferences.trackingStatusSoundsEnabled) { _, _ in
                        notificationManager.savePreferences()
                    }
            }
        }
    }
}

// MARK: - Productivity Goals Section

struct ProductivityGoalsSection: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        Section("Productivity Goals") {
            Toggle("Goal Achievement Notifications", isOn: $notificationManager.preferences.productivityGoalNotificationsEnabled)
                .onChange(of: notificationManager.preferences.productivityGoalNotificationsEnabled) { _, _ in
                    notificationManager.savePreferences()
                }
            
            if notificationManager.preferences.productivityGoalNotificationsEnabled {
                Toggle("Play Sounds", isOn: $notificationManager.preferences.productivityGoalSoundsEnabled)
                    .onChange(of: notificationManager.preferences.productivityGoalSoundsEnabled) { _, _ in
                        notificationManager.savePreferences()
                    }
                
                HStack {
                    Text("Daily Goal:")
                    Spacer()
                    TextField("Hours", value: $notificationManager.preferences.dailyGoalHours, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: notificationManager.preferences.dailyGoalHours) { _, _ in
                            notificationManager.savePreferences()
                        }
                    Text("hours")
                }
                
                HStack {
                    Text("Weekly Goal:")
                    Spacer()
                    TextField("Hours", value: $notificationManager.preferences.weeklyGoalHours, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: notificationManager.preferences.weeklyGoalHours) { _, _ in
                            notificationManager.savePreferences()
                        }
                    Text("hours")
                }
            }
        }
    }
}

// MARK: - Inactivity Reminders Section

struct InactivityRemindersSection: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        Section("Inactivity Reminders") {
            Toggle("Inactivity Reminders", isOn: $notificationManager.preferences.inactivityRemindersEnabled)
                .onChange(of: notificationManager.preferences.inactivityRemindersEnabled) { _, _ in
                    notificationManager.savePreferences()
                }
            
            if notificationManager.preferences.inactivityRemindersEnabled {
                Toggle("Play Sounds", isOn: $notificationManager.preferences.inactivityReminderSoundsEnabled)
                    .onChange(of: notificationManager.preferences.inactivityReminderSoundsEnabled) { _, _ in
                        notificationManager.savePreferences()
                    }
                
                HStack {
                    Text("Remind after:")
                    Spacer()
                    TextField("Hours", value: $notificationManager.preferences.inactivityThresholdHours, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: notificationManager.preferences.inactivityThresholdHours) { _, _ in
                            notificationManager.savePreferences()
                        }
                    Text("hours")
                }
                
                HStack {
                    Text("Snooze for:")
                    Spacer()
                    TextField("Hours", value: $notificationManager.preferences.inactivitySnoozeHours, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: notificationManager.preferences.inactivitySnoozeHours) { _, _ in
                            notificationManager.savePreferences()
                        }
                    Text("hours")
                }
            }
        }
    }
}

// MARK: - Summary Notifications Section

struct SummaryNotificationsSection: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        Section("Summary Notifications") {
            Toggle("Daily & Weekly Summaries", isOn: $notificationManager.preferences.summaryNotificationsEnabled)
                .onChange(of: notificationManager.preferences.summaryNotificationsEnabled) { _, _ in
                    notificationManager.savePreferences()
                }
            
            if notificationManager.preferences.summaryNotificationsEnabled {
                Toggle("Play Sounds", isOn: $notificationManager.preferences.summarySoundsEnabled)
                    .onChange(of: notificationManager.preferences.summarySoundsEnabled) { _, _ in
                        notificationManager.savePreferences()
                    }
                
                HStack {
                    Text("Daily Summary Time:")
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: { notificationManager.preferences.dailySummaryTime ?? Date() },
                        set: { 
                            notificationManager.preferences.dailySummaryTime = $0
                            notificationManager.savePreferences()
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
                
                HStack {
                    Text("Weekly Summary Day:")
                    Spacer()
                    Picker("Day", selection: $notificationManager.preferences.weeklySummaryDay) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Tuesday").tag(3)
                        Text("Wednesday").tag(4)
                        Text("Thursday").tag(5)
                        Text("Friday").tag(6)
                        Text("Saturday").tag(7)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: notificationManager.preferences.weeklySummaryDay) { _, _ in
                        notificationManager.savePreferences()
                    }
                }
                
                HStack {
                    Text("Weekly Summary Time:")
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: { notificationManager.preferences.weeklySummaryTime ?? Date() },
                        set: { 
                            notificationManager.preferences.weeklySummaryTime = $0
                            notificationManager.savePreferences()
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        NotificationPreferencesView(notificationManager: NotificationManager())
    }
    .frame(width: 600, height: 800)
}