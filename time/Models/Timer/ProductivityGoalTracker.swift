import Foundation
import SwiftData
import os

@MainActor
class ProductivityGoalTracker: ObservableObject {
    // MARK: - Published Properties
    
    @Published var dailyGoalHours: Double = 8.0
    @Published var weeklyGoalHours: Double = 40.0
    @Published var dailyProgress: Double = 0.0
    @Published var weeklyProgress: Double = 0.0
    @Published var dailyGoalReached: Bool = false
    @Published var weeklyGoalReached: Bool = false
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var notificationManager: NotificationManager?
    private let logger = Logger(subsystem: "com.timetracking.app", category: "ProductivityGoalTracker")
    
    // Track if we've already sent notifications today/this week to avoid spam
    private var dailyGoalNotificationSent: Bool = false
    private var weeklyGoalNotificationSent: Bool = false
    
    // MARK: - Initialization
    
    init() {
        loadGoals()
        setupDailyReset()
    }
    
    // MARK: - Configuration
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        updateProgress()
    }
    
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
    }
    
    // MARK: - Goal Management
    
    func updateDailyGoal(_ hours: Double) {
        dailyGoalHours = max(0.1, hours)
        saveGoals()
        updateProgress()
        logger.info("Daily goal updated to \(hours) hours")
    }
    
    func updateWeeklyGoal(_ hours: Double) {
        weeklyGoalHours = max(0.1, hours)
        saveGoals()
        updateProgress()
        logger.info("Weekly goal updated to \(hours) hours")
    }
    
    // MARK: - Progress Tracking
    
    func updateProgress() {
        guard let modelContext = modelContext else { return }
        
        Task {
            do {
                // Calculate daily progress
                let dailyHours = try await calculateDailyHours(context: modelContext)
                let weeklyHours = try await calculateWeeklyHours(context: modelContext)
                
                await MainActor.run {
                    self.dailyProgress = dailyHours / self.dailyGoalHours
                    self.weeklyProgress = weeklyHours / self.weeklyGoalHours
                    
                    // Check if goals are reached
                    self.checkDailyGoalReached(dailyHours)
                    self.checkWeeklyGoalReached(weeklyHours)
                }
                
            } catch {
                logger.error("Failed to update progress: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateDailyHours(context: ModelContext) async throws -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Fetch time entries for today
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startTime >= today && entry.startTime < tomorrow
            }
        )
        
        let timeEntries = try context.fetch(descriptor)
        let totalSeconds = timeEntries.reduce(0) { total, entry in
            total + (entry.endTime.timeIntervalSince(entry.startTime))
        }
        
        return totalSeconds / 3600.0 // Convert to hours
    }
    
    private func calculateWeeklyHours(context: ModelContext) async throws -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            throw ProductivityGoalError.dateCalculationFailed
        }
        
        // Fetch time entries for this week
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startTime >= weekInterval.start && entry.startTime < weekInterval.end
            }
        )
        
        let timeEntries = try context.fetch(descriptor)
        let totalSeconds = timeEntries.reduce(0) { total, entry in
            total + (entry.endTime.timeIntervalSince(entry.startTime))
        }
        
        return totalSeconds / 3600.0 // Convert to hours
    }
    
    private func checkDailyGoalReached(_ currentHours: Double) {
        let wasReached = dailyGoalReached
        dailyGoalReached = currentHours >= dailyGoalHours
        
        // Send notification if goal was just reached
        if dailyGoalReached && !wasReached && !dailyGoalNotificationSent {
            notificationManager?.sendDailyGoalReachedNotification(hours: dailyGoalHours)
            dailyGoalNotificationSent = true
            logger.info("Daily goal reached! \(currentHours) / \(self.dailyGoalHours) hours")
        }
    }
    
    private func checkWeeklyGoalReached(_ currentHours: Double) {
        let wasReached = weeklyGoalReached
        weeklyGoalReached = currentHours >= weeklyGoalHours
        
        // Send notification if goal was just reached
        if weeklyGoalReached && !wasReached && !weeklyGoalNotificationSent {
            notificationManager?.sendWeeklyGoalReachedNotification(hours: weeklyGoalHours)
            weeklyGoalNotificationSent = true
            logger.info("Weekly goal reached! \(currentHours) / \(self.weeklyGoalHours) hours")
        }
    }
    
    // MARK: - Inactivity Tracking
    
    private var lastActivityTime: Date = Date()
    private var inactivityTimer: Timer?
    
    func recordActivity() {
        lastActivityTime = Date()
        resetInactivityTimer()
    }
    
    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        
        guard let notificationManager = notificationManager,
              notificationManager.preferences.inactivityRemindersEnabled else {
            return
        }
        
        let thresholdHours = notificationManager.preferences.inactivityThresholdHours
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: thresholdHours * 3600, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleInactivityThresholdReached()
            }
        }
    }
    
    private func handleInactivityThresholdReached() {
        guard let notificationManager = notificationManager else { return }
        
        let inactiveHours = Date().timeIntervalSince(lastActivityTime) / 3600.0
        notificationManager.scheduleInactivityReminder(after: 0) // Send immediately
        
        logger.info("Inactivity threshold reached: \(inactiveHours) hours")
        
        // Schedule next reminder if user doesn't respond
        let snoozeHours = notificationManager.preferences.inactivitySnoozeHours
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: snoozeHours * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleInactivityThresholdReached()
            }
        }
    }
    
    // MARK: - Daily Summary
    
    func scheduleDailySummary() {
        guard let notificationManager = notificationManager,
              let summaryTime = notificationManager.preferences.dailySummaryTime else {
            return
        }
        
        Task {
            do {
                guard let modelContext = modelContext else { return }
                
                let dailyHours = try await calculateDailyHours(context: modelContext)
                let topProjects = try await getTopProjectsForToday(context: modelContext)
                
                // Schedule for today at the specified time
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let summaryComponents = calendar.dateComponents([.hour, .minute], from: summaryTime)
                
                if let scheduledTime = calendar.date(bySettingHour: summaryComponents.hour ?? 18,
                                                   minute: summaryComponents.minute ?? 0,
                                                   second: 0,
                                                   of: today) {
                    
                    await MainActor.run {
                        notificationManager.scheduleDailySummary(
                            totalHours: dailyHours,
                            topProjects: topProjects,
                            at: scheduledTime
                        )
                    }
                }
                
            } catch {
                logger.error("Failed to schedule daily summary: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleWeeklySummary() {
        guard let notificationManager = notificationManager,
              let summaryTime = notificationManager.preferences.weeklySummaryTime else {
            return
        }
        
        Task {
            do {
                guard let modelContext = modelContext else { return }
                
                let weeklyHours = try await calculateWeeklyHours(context: modelContext)
                let topProjects = try await getTopProjectsForWeek(context: modelContext)
                
                // Schedule for the specified day and time
                let calendar = Calendar.current
                let summaryDay = notificationManager.preferences.weeklySummaryDay
                let summaryComponents = calendar.dateComponents([.hour, .minute], from: summaryTime)
                
                // Find next occurrence of the summary day
                var dateComponents = DateComponents()
                dateComponents.weekday = summaryDay
                dateComponents.hour = summaryComponents.hour ?? 19
                dateComponents.minute = summaryComponents.minute ?? 0
                
                if let scheduledTime = calendar.nextDate(after: Date(),
                                                       matching: dateComponents,
                                                       matchingPolicy: .nextTime) {
                    
                    await MainActor.run {
                        notificationManager.scheduleWeeklySummary(
                            totalHours: weeklyHours,
                            topProjects: topProjects,
                            at: scheduledTime
                        )
                    }
                }
                
            } catch {
                logger.error("Failed to schedule weekly summary: \(error.localizedDescription)")
            }
        }
    }
    
    private func getTopProjectsForToday(context: ModelContext) async throws -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startTime >= today && entry.startTime < tomorrow && entry.project != nil
            }
        )
        
        let timeEntries = try context.fetch(descriptor)
        
        // Group by project and calculate total time
        var projectTimes: [String: TimeInterval] = [:]
        for entry in timeEntries {
            guard let projectName = entry.project?.name else { continue }
            let duration = entry.endTime.timeIntervalSince(entry.startTime)
            projectTimes[projectName, default: 0] += duration
        }
        
        // Sort by time and return top 3
        return projectTimes.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    private func getTopProjectsForWeek(context: ModelContext) async throws -> [String] {
        let calendar = Calendar.current
        let now = Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            throw ProductivityGoalError.dateCalculationFailed
        }
        
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startTime >= weekInterval.start && entry.startTime < weekInterval.end && entry.project != nil
            }
        )
        
        let timeEntries = try context.fetch(descriptor)
        
        // Group by project and calculate total time
        var projectTimes: [String: TimeInterval] = [:]
        for entry in timeEntries {
            guard let projectName = entry.project?.name else { continue }
            let duration = entry.endTime.timeIntervalSince(entry.startTime)
            projectTimes[projectName, default: 0] += duration
        }
        
        // Sort by time and return top 3
        return projectTimes.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    // MARK: - Persistence
    
    private func loadGoals() {
        let defaults = UserDefaults.standard
        dailyGoalHours = defaults.object(forKey: "ProductivityGoalTracker.dailyGoalHours") as? Double ?? 8.0
        weeklyGoalHours = defaults.object(forKey: "ProductivityGoalTracker.weeklyGoalHours") as? Double ?? 40.0
    }
    
    private func saveGoals() {
        let defaults = UserDefaults.standard
        defaults.set(dailyGoalHours, forKey: "ProductivityGoalTracker.dailyGoalHours")
        defaults.set(weeklyGoalHours, forKey: "ProductivityGoalTracker.weeklyGoalHours")
    }
    
    // MARK: - Daily Reset
    
    private func setupDailyReset() {
        // Reset notification flags at midnight
        let calendar = Calendar.current
        let now = Date()
        
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            let timeUntilMidnight = tomorrow.timeIntervalSince(now)
            
            Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.resetDailyFlags()
                    self?.setupDailyReset() // Schedule next reset
                }
            }
        }
    }
    
    private func resetDailyFlags() {
        dailyGoalNotificationSent = false
        
        // Reset weekly flag on Sunday (or configured day)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        if weekday == 1 { // Sunday
            weeklyGoalNotificationSent = false
        }
        
        updateProgress()
        scheduleDailySummary()
        
        logger.info("Daily flags reset")
    }
}

// MARK: - Error Types

enum ProductivityGoalError: LocalizedError {
    case dateCalculationFailed
    case noModelContext
    
    var errorDescription: String? {
        switch self {
        case .dateCalculationFailed:
            return "Failed to calculate date intervals"
        case .noModelContext:
            return "Model context not available"
        }
    }
}