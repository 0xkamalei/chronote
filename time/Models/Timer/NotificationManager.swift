import Foundation
import os
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    private let logger = Logger(subsystem: "com.timetracking.app", category: "NotificationManager")

    // MARK: - Published Properties

    @Published var notificationPermissionGranted = false
    @Published var preferences = NotificationPreferences()

    // MARK: - Notification Categories

    enum NotificationCategory: String, CaseIterable {
        case timerCompletion = "TIMER_COMPLETION"
        case timerInterval = "TIMER_INTERVAL"
        case trackingStatus = "TRACKING_STATUS"
        case productivityGoal = "PRODUCTIVITY_GOAL"
        case inactivityReminder = "INACTIVITY_REMINDER"
        case dailySummary = "DAILY_SUMMARY"
        case weeklySummary = "WEEKLY_SUMMARY"
    }

    // MARK: - Notification Types

    enum NotificationType: CustomStringConvertible {
        case timerCompleted(sessionId: String, title: String?, duration: TimeInterval)
        case timerInterval(sessionId: String, interval: Int)
        case trackingStopped(reason: String)
        case trackingRestarted
        case dailyGoalReached(hours: Double)
        case weeklyGoalReached(hours: Double)
        case inactivityReminder(hours: Double)
        case dailySummary(totalHours: Double, topProjects: [String])
        case weeklySummary(totalHours: Double, topProjects: [String])
        
        var description: String {
            switch self {
            case .timerCompleted:
                return "timerCompleted"
            case .timerInterval:
                return "timerInterval"
            case .trackingStopped:
                return "trackingStopped"
            case .trackingRestarted:
                return "trackingRestarted"
            case .dailyGoalReached:
                return "dailyGoalReached"
            case .weeklyGoalReached:
                return "weeklyGoalReached"
            case .inactivityReminder:
                return "inactivityReminder"
            case .dailySummary:
                return "dailySummary"
            case .weeklySummary:
                return "weeklySummary"
            }
        }
    }

    // MARK: - Initialization

    init() {
        setupNotificationCategories()
        requestNotificationPermission()
        loadPreferences()
    }

    // MARK: - Setup and Configuration

    /// Sets up notification categories and actions
    private func setupNotificationCategories() {
        let timerCompletionCategory = UNNotificationCategory(
            identifier: NotificationCategory.timerCompletion.rawValue,
            actions: [
                UNNotificationAction(identifier: "START_NEW_TIMER", title: "Start New Timer", options: []),
                UNNotificationAction(identifier: "VIEW_TIMELINE", title: "View Timeline", options: [.foreground]),
            ],
            intentIdentifiers: [],
            options: []
        )

        let trackingStatusCategory = UNNotificationCategory(
            identifier: NotificationCategory.trackingStatus.rawValue,
            actions: [
                UNNotificationAction(identifier: "RESTART_TRACKING", title: "Restart Tracking", options: []),
                UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: []),
            ],
            intentIdentifiers: [],
            options: []
        )

        let inactivityReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.inactivityReminder.rawValue,
            actions: [
                UNNotificationAction(identifier: "START_TIMER", title: "Start Timer", options: [.foreground]),
                UNNotificationAction(identifier: "SNOOZE", title: "Remind Later", options: []),
            ],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            timerCompletionCategory,
            trackingStatusCategory,
            inactivityReminderCategory,
        ])
    }

    // MARK: - Permission Management

    /// Requests notification permission from the user
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                if let error = error {
                    self.logger.error("Failed to request notification permission: \(error.localizedDescription)")
                    self.notificationPermissionGranted = false
                } else {
                    self.logger.info("Notification permission granted: \(granted)")
                    self.notificationPermissionGranted = granted
                }
            }
        }
    }

    /// Checks if notification permission is granted
    func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let granted = settings.authorizationStatus == .authorized
        await MainActor.run {
            self.notificationPermissionGranted = granted
        }
        return granted
    }

    /// Requests notification permission if not already granted
    func requestPermissionIfNeeded() async -> Bool {
        let currentStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus

        if currentStatus == .notDetermined {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                await MainActor.run {
                    self.notificationPermissionGranted = granted
                }
                return granted
            } catch {
                logger.error("Failed to request notification permission: \(error.localizedDescription)")
                return false
            }
        }

        return currentStatus == .authorized
    }

    // MARK: - Notification Scheduling

    /// Schedules a notification based on type and preferences
    func scheduleNotification(_ type: NotificationType, at date: Date? = nil) {
        guard notificationPermissionGranted else {
            logger.warning("Cannot schedule notification - permission not granted")
            return
        }

        guard shouldSendNotification(for: type) else {
            logger.debug("Notification blocked by preferences: \(type)")
            return
        }

        let content = createNotificationContent(for: type)
        let identifier = createNotificationIdentifier(for: type)

        let trigger: UNNotificationTrigger?
        if let date = date {
            trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
                repeats: false
            )
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                self.logger.info("Scheduled notification: \(identifier)")
            }
        }
    }

    // MARK: - Timer Notifications

    /// Schedules a timer completion notification
    func scheduleTimerCompletionNotification(at date: Date, sessionId: String, title: String?, playSound _: Bool) {
        let type = NotificationType.timerCompleted(sessionId: sessionId, title: title, duration: 0)
        scheduleNotification(type, at: date)
    }

    /// Schedules a timer interval notification
    func scheduleTimerIntervalNotification(at date: Date, sessionId: String, interval: Int, playSound _: Bool) {
        let type = NotificationType.timerInterval(sessionId: sessionId, interval: interval)
        scheduleNotification(type, at: date)
    }

    // MARK: - Tracking Status Notifications

    /// Sends notification when tracking stops unexpectedly
    func sendTrackingStoppedNotification(reason: String) {
        let type = NotificationType.trackingStopped(reason: reason)
        scheduleNotification(type)
    }

    /// Sends notification when tracking is restarted
    func sendTrackingRestartedNotification() {
        let type = NotificationType.trackingRestarted
        scheduleNotification(type)
    }

    // MARK: - Productivity Goal Notifications

    /// Sends notification when daily goal is reached
    func sendDailyGoalReachedNotification(hours: Double) {
        let type = NotificationType.dailyGoalReached(hours: hours)
        scheduleNotification(type)
    }

    /// Sends notification when weekly goal is reached
    func sendWeeklyGoalReachedNotification(hours: Double) {
        let type = NotificationType.weeklyGoalReached(hours: hours)
        scheduleNotification(type)
    }

    // MARK: - Inactivity Reminders

    /// Schedules an inactivity reminder notification
    func scheduleInactivityReminder(after hours: Double) {
        let type = NotificationType.inactivityReminder(hours: hours)
        let reminderDate = Date().addingTimeInterval(hours * 3600)
        scheduleNotification(type, at: reminderDate)
    }

    /// Cancels pending inactivity reminders
    func cancelInactivityReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToCancel = requests
                .filter { $0.content.categoryIdentifier == NotificationCategory.inactivityReminder.rawValue }
                .map { $0.identifier }

            if !identifiersToCancel.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
                self.logger.info("Cancelled \(identifiersToCancel.count) inactivity reminder notifications")
            }
        }
    }

    // MARK: - Summary Notifications

    /// Schedules daily summary notification
    func scheduleDailySummary(totalHours: Double, topProjects: [String], at date: Date) {
        let type = NotificationType.dailySummary(totalHours: totalHours, topProjects: topProjects)
        scheduleNotification(type, at: date)
    }

    /// Schedules weekly summary notification
    func scheduleWeeklySummary(totalHours: Double, topProjects: [String], at date: Date) {
        let type = NotificationType.weeklySummary(totalHours: totalHours, topProjects: topProjects)
        scheduleNotification(type, at: date)
    }

    /// Cancels all notifications for a specific timer session
    func cancelTimerNotifications(sessionId: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToCancel = requests
                .filter { $0.content.userInfo["sessionId"] as? String == sessionId }
                .map { $0.identifier }

            if !identifiersToCancel.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
                self.logger.info("Cancelled \(identifiersToCancel.count) notifications for session: \(sessionId)")
            }
        }
    }

    /// Cancels all timer notifications
    func cancelAllTimerNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let timerNotificationIds = requests
                .filter { request in
                    request.content.categoryIdentifier == NotificationCategory.timerCompletion.rawValue ||
                        request.content.categoryIdentifier == NotificationCategory.timerInterval.rawValue
                }
                .map { $0.identifier }

            if !timerNotificationIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: timerNotificationIds)
                self.logger.info("Cancelled \(timerNotificationIds.count) timer notifications")
            }
        }
    }

    // MARK: - Notification Content Creation

    private func createNotificationContent(for type: NotificationType) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        switch type {
        case let .timerCompleted(sessionId, title, duration):
            content.title = "Timer Completed"
            content.body = title ?? "Your timer session has finished"
            content.categoryIdentifier = NotificationCategory.timerCompletion.rawValue
            content.userInfo = ["sessionId": sessionId, "type": "completion", "duration": duration]

        case let .timerInterval(sessionId, interval):
            content.title = "Timer Update"
            content.body = "Timer has been running for \(interval * 30) minutes"
            content.categoryIdentifier = NotificationCategory.timerInterval.rawValue
            content.userInfo = ["sessionId": sessionId, "type": "interval", "interval": interval]

        case let .trackingStopped(reason):
            content.title = "Tracking Stopped"
            content.body = "Time tracking has stopped: \(reason)"
            content.categoryIdentifier = NotificationCategory.trackingStatus.rawValue
            content.userInfo = ["type": "tracking_stopped", "reason": reason]

        case .trackingRestarted:
            content.title = "Tracking Restarted"
            content.body = "Time tracking has been automatically restarted"
            content.categoryIdentifier = NotificationCategory.trackingStatus.rawValue
            content.userInfo = ["type": "tracking_restarted"]

        case let .dailyGoalReached(hours):
            content.title = "Daily Goal Reached! 🎉"
            content.body = "Congratulations! You've reached your daily goal of \(String(format: "%.1f", hours)) hours"
            content.categoryIdentifier = NotificationCategory.productivityGoal.rawValue
            content.userInfo = ["type": "daily_goal", "hours": hours]

        case let .weeklyGoalReached(hours):
            content.title = "Weekly Goal Reached! 🎉"
            content.body = "Amazing! You've reached your weekly goal of \(String(format: "%.1f", hours)) hours"
            content.categoryIdentifier = NotificationCategory.productivityGoal.rawValue
            content.userInfo = ["type": "weekly_goal", "hours": hours]

        case let .inactivityReminder(hours):
            content.title = "Time to Track?"
            content.body = "You haven't tracked time for \(String(format: "%.1f", hours)) hours. Ready to start?"
            content.categoryIdentifier = NotificationCategory.inactivityReminder.rawValue
            content.userInfo = ["type": "inactivity_reminder", "hours": hours]

        case let .dailySummary(totalHours, topProjects):
            content.title = "Daily Summary"
            let projectsText = topProjects.isEmpty ? "No projects" : topProjects.prefix(3).joined(separator: ", ")
            content.body = "Today: \(String(format: "%.1f", totalHours))h • Top projects: \(projectsText)"
            content.categoryIdentifier = NotificationCategory.dailySummary.rawValue
            content.userInfo = ["type": "daily_summary", "hours": totalHours, "projects": topProjects]

        case let .weeklySummary(totalHours, topProjects):
            content.title = "Weekly Summary"
            let projectsText = topProjects.isEmpty ? "No projects" : topProjects.prefix(3).joined(separator: ", ")
            content.body = "This week: \(String(format: "%.1f", totalHours))h • Top projects: \(projectsText)"
            content.categoryIdentifier = NotificationCategory.weeklySummary.rawValue
            content.userInfo = ["type": "weekly_summary", "hours": totalHours, "projects": topProjects]
        }

        // Apply sound preferences
        if shouldPlaySound(for: type) {
            content.sound = getNotificationSound(for: type)
        }

        return content
    }

    private func createNotificationIdentifier(for type: NotificationType) -> String {
        switch type {
        case let .timerCompleted(sessionId, _, _):
            return "timer_completion_\(sessionId)"
        case let .timerInterval(sessionId, interval):
            return "timer_interval_\(sessionId)_\(interval)"
        case .trackingStopped:
            return "tracking_stopped_\(Date().timeIntervalSince1970)"
        case .trackingRestarted:
            return "tracking_restarted_\(Date().timeIntervalSince1970)"
        case .dailyGoalReached:
            return "daily_goal_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        case .weeklyGoalReached:
            return "weekly_goal_\(Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start.timeIntervalSince1970 ?? 0)"
        case .inactivityReminder:
            return "inactivity_reminder_\(Date().timeIntervalSince1970)"
        case .dailySummary:
            return "daily_summary_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        case .weeklySummary:
            return "weekly_summary_\(Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start.timeIntervalSince1970 ?? 0)"
        }
    }

    // MARK: - Preference Management

    private func shouldSendNotification(for type: NotificationType) -> Bool {
        // Check quiet hours
        if preferences.respectQuietHours && isInQuietHours() {
            return false
        }

        // Check individual notification type preferences
        switch type {
        case .timerCompleted, .timerInterval:
            return preferences.timerNotificationsEnabled
        case .trackingStopped, .trackingRestarted:
            return preferences.trackingStatusNotificationsEnabled
        case .dailyGoalReached, .weeklyGoalReached:
            return preferences.productivityGoalNotificationsEnabled
        case .inactivityReminder:
            return preferences.inactivityRemindersEnabled
        case .dailySummary, .weeklySummary:
            return preferences.summaryNotificationsEnabled
        }
    }

    private func shouldPlaySound(for type: NotificationType) -> Bool {
        switch type {
        case .timerCompleted, .timerInterval:
            return preferences.timerSoundsEnabled
        case .trackingStopped, .trackingRestarted:
            return preferences.trackingStatusSoundsEnabled
        case .dailyGoalReached, .weeklyGoalReached:
            return preferences.productivityGoalSoundsEnabled
        case .inactivityReminder:
            return preferences.inactivityReminderSoundsEnabled
        case .dailySummary, .weeklySummary:
            return preferences.summarySoundsEnabled
        }
    }

    private func getNotificationSound(for type: NotificationType) -> UNNotificationSound {
        switch type {
        case .timerCompleted, .timerInterval:
            return UNNotificationSound(named: UNNotificationSoundName(preferences.timerSoundName))
        case .trackingStopped, .trackingRestarted:
            return .default
        case .dailyGoalReached, .weeklyGoalReached:
            return UNNotificationSound(named: UNNotificationSoundName("success.aiff"))
        case .inactivityReminder:
            return UNNotificationSound(named: UNNotificationSoundName("gentle.aiff"))
        case .dailySummary, .weeklySummary:
            return .default
        }
    }

    private func isInQuietHours() -> Bool {
        guard let quietStart = preferences.quietHoursStart,
              let quietEnd = preferences.quietHoursEnd
        else {
            return false
        }

        let now = Date()
        let calendar = Calendar.current
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)

        let startComponents = calendar.dateComponents([.hour, .minute], from: quietStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietEnd)

        let currentMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)

        if startMinutes <= endMinutes {
            // Same day quiet hours (e.g., 22:00 to 08:00 next day)
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight quiet hours (e.g., 22:00 to 08:00 next day)
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }

    private func loadPreferences() {
        // Load preferences from UserDefaults or use defaults
        if let data = UserDefaults.standard.data(forKey: "NotificationPreferences"),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        {
            preferences = decoded
        }
    }

    func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "NotificationPreferences")
        }
    }

    // MARK: - Notification History

    func getDeliveredNotifications() async -> [UNNotification] {
        return await UNUserNotificationCenter.current().deliveredNotifications()
    }

    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    // General settings
    var notificationsEnabled = true
    var respectQuietHours = true
    var quietHoursStart: Date?
    var quietHoursEnd: Date?

    // Timer notifications
    var timerNotificationsEnabled = true
    var timerSoundsEnabled = true
    var timerSoundName = "default.aiff"
    var timerIntervalNotificationsEnabled = false
    var timerIntervalMinutes = 30

    // Tracking status notifications
    var trackingStatusNotificationsEnabled = true
    var trackingStatusSoundsEnabled = true

    // Productivity goal notifications
    var productivityGoalNotificationsEnabled = true
    var productivityGoalSoundsEnabled = true
    var dailyGoalHours: Double = 8.0
    var weeklyGoalHours: Double = 40.0

    // Inactivity reminders
    var inactivityRemindersEnabled = true
    var inactivityReminderSoundsEnabled = false
    var inactivityThresholdHours: Double = 2.0
    var inactivitySnoozeHours: Double = 1.0

    // Summary notifications
    var summaryNotificationsEnabled = true
    var summarySoundsEnabled = false
    var dailySummaryTime: Date?
    var weeklySummaryDay = 1 // Sunday = 1
    var weeklySummaryTime: Date?

    init() {
        // Set default quiet hours (22:00 to 08:00)
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.hour = 22
        startComponents.minute = 0
        quietHoursStart = calendar.date(from: startComponents)

        var endComponents = DateComponents()
        endComponents.hour = 8
        endComponents.minute = 0
        quietHoursEnd = calendar.date(from: endComponents)

        // Set default daily summary time (18:00)
        var summaryComponents = DateComponents()
        summaryComponents.hour = 18
        summaryComponents.minute = 0
        dailySummaryTime = calendar.date(from: summaryComponents)

        // Set default weekly summary time (Sunday 19:00)
        var weeklySummaryComponents = DateComponents()
        weeklySummaryComponents.hour = 19
        weeklySummaryComponents.minute = 0
        weeklySummaryTime = calendar.date(from: weeklySummaryComponents)
    }
}
