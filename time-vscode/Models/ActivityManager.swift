//
//  ActivityManager.swift
//  time-vscode
//
//  Created by Kiro on 8/6/25.
//

import Foundation
import SwiftData
import AppKit

@MainActor
class ActivityManager: ObservableObject {
    // MARK: - Singleton
    static let shared = ActivityManager()
    
    // MARK: - Private Properties
    private var currentActivity: Activity?
    private var notificationObservers: [NSObjectProtocol] = []
    private var modelContext: ModelContext?
    
    // Sleep/wake state management
    private var sleepStartTime: Date?
    
    // MARK: - Initialization
    private init() {
        // Private initializer for singleton pattern
    }
    
    // MARK: - Public Methods
    
    /// Start tracking app activity
    func startTracking(modelContext: ModelContext) {
        // Store model context for use in notification handlers
        self.modelContext = modelContext
        
        // Remove any existing observers first
        stopTracking(modelContext: modelContext)
        
        // Register NSWorkspace notification observers
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // App activation observer
        let appActivationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAppActivation(notification)
            }
        }
        notificationObservers.append(appActivationObserver)
        
        // System sleep observer
        let sleepObserver = notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleSystemSleep()
            }
        }
        notificationObservers.append(sleepObserver)
        
        // System wake observer
        let wakeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleSystemWake()
            }
        }
        notificationObservers.append(wakeObserver)
        
        print("ActivityManager: Started tracking with \(notificationObservers.count) observers")
    }
    
    /// Stop tracking app activity
    func stopTracking(modelContext: ModelContext) {
        // Finish current activity if one exists before stopping
        if let current = currentActivity {
            do {
                current.endTime = Date()
                current.duration = current.calculatedDuration
                
                // Validate duration is positive
                if current.duration < 0 {
                    print("ActivityManager: Warning - Negative duration detected during stop, setting to 0")
                    current.duration = 0
                }
                
                try saveActivity(current, modelContext: modelContext)
                print("ActivityManager: Saved final activity before stopping: \(current.appName)")
            } catch {
                print("ActivityManager: Error saving final activity during stop - \(error.localizedDescription)")
            }
        }
        
        // Remove all notification observers
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
        
        notificationObservers.removeAll()
        
        // Clear all state references
        self.modelContext = nil
        currentActivity = nil
        sleepStartTime = nil
        
        print("ActivityManager: Stopped tracking, removed all observers and cleared state")
    }
    
 
    
    /// Track app switch to new application with notification userInfo
    func trackAppSwitch(notification: Notification, modelContext: ModelContext) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier != nil else {
            print("ActivityManager: Invalid app activation notification")
            return
        }
        
        let appInfo = resolveAppInfo(from: app)
        trackAppSwitch(appInfo: appInfo, modelContext: modelContext)
    }
    
    /// Track app switch to new application with app information
    private func trackAppSwitch(appInfo: AppInfo, modelContext: ModelContext) {
        do {
            let now = Date()
            
            // Validate input data
            guard !appInfo.name.isEmpty else {
                print("ActivityManager: Error - App name cannot be empty")
                return
            }
            
            // Check if this is the same app as currently active (avoid duplicate tracking)
            if let current = currentActivity,
               current.appBundleId == appInfo.bundleId {
                // TODO: Handle case where app doesn't switch but window title changes
                // Should update current activity's title if it's different from appInfo.title
                // This would be useful for tracking different documents/tabs within the same app
                print("ActivityManager: Ignoring switch to same app: \(appInfo.name)")
                return
            }
            
            // If no current activity exists, create new activity but don't save yet
            if currentActivity == nil {
                let newActivity = Activity(
                    appName: appInfo.name,
                    appBundleId: appInfo.bundleId,
                    appTitle: appInfo.title,
                    duration: 0, // Will be calculated when activity ends
                    startTime: now,
                    endTime: nil, // nil indicates this is the active activity
                    icon: appInfo.icon
                )
                
                // Set as current activity but don't save to database yet
                currentActivity = newActivity
                print("ActivityManager: Started tracking new activity - \(appInfo.name) (not saved yet)")
                return
            }
            
            // Finish current activity and save it
            if let current = currentActivity {
                // Validate that current activity has a valid start time
                if current.startTime > now {
                    print("ActivityManager: Error - Current activity has invalid start time")
                    // Fix the invalid start time
                    current.startTime = now.addingTimeInterval(-60) // Set to 1 minute ago as fallback
                }
                
                // Set end time and calculate duration
                current.endTime = now
                current.duration = current.calculatedDuration
                
                // Validate duration is positive
                if current.duration < 0 {
                    print("ActivityManager: Warning - Negative duration detected, setting to 0")
                    current.duration = 0
                }
                
                // Save the finished activity using the new saveActivity method
                try saveActivity(current, modelContext: modelContext)
            }
            
            // Create new activity for the activated app
            let newActivity = Activity(
                appName: appInfo.name,
                appBundleId: appInfo.bundleId,
                appTitle: appInfo.title,
                duration: 0, // Will be calculated when activity ends
                startTime: now,
                endTime: nil, // nil indicates this is the active activity
                icon: appInfo.icon
            )
            
            // Update current activity reference (don't save to database yet)
            currentActivity = newActivity
            
            print("ActivityManager: Started new activity - \(appInfo.name) (\(appInfo.bundleId))")
            
        } catch {
            print("ActivityManager: Error tracking app switch - \(error.localizedDescription)")
            
            // Attempt recovery by clearing current activity state
            currentActivity = nil
        }
    }
    
    // MARK: - SwiftData Persistence Operations
    
    /// Save an activity to the database with proper error handling
    func saveActivity(_ activity: Activity, modelContext: ModelContext) throws {
        // Validate activity data before persistence
        try validateActivity(activity)
        
        do {
            // Insert activity into context
            modelContext.insert(activity)
            
            // Save to database
            try modelContext.save()
            
            print("ActivityManager: Successfully saved activity - \(activity.appName) (\(activity.duration)s)")
            
        } catch {
            print("ActivityManager: Error saving activity - \(error.localizedDescription)")
            throw ActivityManagerError.saveFailed(error)
        }
    }
    
    /// Save multiple activities in a batch operation for performance optimization
    func batchSaveActivities(_ activities: [Activity], modelContext: ModelContext) throws {
        guard !activities.isEmpty else {
            print("ActivityManager: No activities to save in batch")
            return
        }
        
        do {
            // Validate all activities before batch operation
            for activity in activities {
                try validateActivity(activity)
            }
            
            // Insert all activities into context
            for activity in activities {
                modelContext.insert(activity)
            }
            
            // Save all at once for better performance
            try modelContext.save()
            
            print("ActivityManager: Successfully batch saved \(activities.count) activities")
            
        } catch {
            print("ActivityManager: Error in batch save operation - \(error.localizedDescription)")
            throw ActivityManagerError.batchSaveFailed(error)
        }
    }
    
    /// Get the currently active activity (always returns in-memory state)
    func getCurrentActivity() -> Activity? {
        // Always return the in-memory current activity reference
        // This is dynamic and reflects the real-time state of activity tracking
        return currentActivity
    }
    

    

    
    // MARK: - Data Validation
    
    /// Validate activity data before persistence
    private func validateActivity(_ activity: Activity) throws {
        // Validate app name is not empty
        guard !activity.appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ActivityManagerError.invalidData("App name cannot be empty")
        }
        
        // Validate bundle ID is not empty
        guard !activity.appBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ActivityManagerError.invalidData("App bundle ID cannot be empty")
        }
        
        // Validate start time is not in the future
        let now = Date()
        guard activity.startTime <= now else {
            throw ActivityManagerError.invalidData("Start time cannot be in the future")
        }
        
        // If endTime exists, validate it's after startTime
        if let endTime = activity.endTime {
            guard endTime >= activity.startTime else {
                throw ActivityManagerError.invalidData("End time must be after start time")
            }
            
            // Validate duration matches calculated duration
            let calculatedDuration = endTime.timeIntervalSince(activity.startTime)
            let tolerance: TimeInterval = 1.0 // Allow 1 second tolerance
            
            guard abs(activity.duration - calculatedDuration) <= tolerance else {
                throw ActivityManagerError.invalidData("Duration does not match calculated time difference")
            }
        }
        
        // Validate duration is not negative
        guard activity.duration >= 0 else {
            throw ActivityManagerError.invalidData("Duration cannot be negative")
        }
        
        // For active activities (endTime == nil), ensure only one exists
        if activity.endTime == nil {
            // Check in-memory current activity to ensure only one active activity exists
            if let existing = currentActivity, existing.id != activity.id {
                throw ActivityManagerError.invalidData("Only one active activity can exist at a time")
            }
        }
    }
    
    // MARK: - Error Types
    
    enum ActivityManagerError: LocalizedError {
        case saveFailed(Error)
        case batchSaveFailed(Error)
        case invalidData(String)
        case noModelContext
        case sleepHandlingFailed(Error)
        case wakeHandlingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let error):
                return "Failed to save activity: \(error.localizedDescription)"
            case .batchSaveFailed(let error):
                return "Failed to batch save activities: \(error.localizedDescription)"
            case .invalidData(let message):
                return "Invalid activity data: \(message)"
            case .noModelContext:
                return "No model context available for database operations"
            case .sleepHandlingFailed(let error):
                return "Failed to handle system sleep: \(error.localizedDescription)"
            case .wakeHandlingFailed(let error):
                return "Failed to handle system wake: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// App information structure
    private struct AppInfo {
        let name: String
        let bundleId: String
        let title: String?
        let icon: String
    }
    
    /// Resolve all app information from NSRunningApplication
    private func resolveAppInfo(from app: NSRunningApplication) -> AppInfo {
        let bundleId = app.bundleIdentifier ?? "unknown"
        let name = getAppName(bundleId: bundleId, fallbackName: app.localizedName ?? bundleId)
        let title = getWindowTitle(from: app)
        let icon = getAppIcon(bundleId: bundleId)
        
        return AppInfo(name: name, bundleId: bundleId, title: title, icon: icon)
    }
    
    /// Get window title from NSRunningApplication using AXUIElement
    private func getWindowTitle(from app: NSRunningApplication) -> String? {
        // Try to get the window title from the application using AXUIElement
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success, let window = focusedWindow {
            var windowTitle: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &windowTitle)
            
            if titleResult == .success, let title = windowTitle as? String, !title.isEmpty {
                return title
            }
        }
        
        // Fallback: try to get title from bundle info
        if let bundleId = app.bundleIdentifier,
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        }
        
        return nil
    }
    
    /// Get app name from bundle identifier with fallback
    private func getAppName(bundleId: String, fallbackName: String) -> String {
        // Try to get the localized name from the running application
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }),
           let localizedName = app.localizedName, !localizedName.isEmpty {
            return localizedName
        }
        
        // Try to get app name from bundle
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        
        // Try CFBundleName as fallback
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: bundleURL),
           let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        
        // Extract app name from bundle identifier as last resort
        let components = bundleId.components(separatedBy: ".")
        if let lastComponent = components.last, !lastComponent.isEmpty {
            // Capitalize first letter and return
            return lastComponent.prefix(1).uppercased() + lastComponent.dropFirst()
        }
        
        // Return fallback name if all else fails
        return fallbackName
    }
    

    
    /// Get app icon identifier for the given bundle ID
    private func getAppIcon(bundleId: String) -> String {
        // For now, return a default icon identifier
        // This could be enhanced to extract actual app icons in the future
        return "app.fill"
    }
    
    /// Handle app activation notification
    private func handleAppActivation(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            print("ActivityManager: Invalid app activation notification")
            return
        }
        
        let appName = app.localizedName ?? bundleId
        print("ActivityManager: App activated - \(appName) (\(bundleId))")
        
        // Track the app switch with notification information
        guard let context = modelContext else {
            print("ActivityManager: No model context available for app switch tracking")
            return
        }
        trackAppSwitch(notification: notification, modelContext: context)
    }
    
    /// Handle system sleep event - stops current tracking and saves pending data
    private func handleSystemSleep() {
        do {
            print("ActivityManager: System going to sleep")
            
            // Record sleep start time for logging
            sleepStartTime = Date()
            
            // Finish current activity if one exists
            if let current = currentActivity {
                let sleepTime = Date()
                current.endTime = sleepTime
                current.duration = current.calculatedDuration
                
                // Validate duration is positive
                if current.duration < 0 {
                    print("ActivityManager: Warning - Negative duration detected during sleep, setting to 0")
                    current.duration = 0
                }
                
                // Ensure all pending data is saved before system sleep
                if let context = modelContext {
                    try saveActivity(current, modelContext: context)
                    
                    // Force save any pending changes to ensure data persistence
                    try context.save()
                    print("ActivityManager: Successfully saved activity before sleep: \(current.appName)")
                } else {
                    print("ActivityManager: Warning - No model context available to save activity before sleep")
                }
                
                // Clear current activity to prevent stale references
                currentActivity = nil
            }
            
            print("ActivityManager: Sleep handling completed - tracking stopped")
            
        } catch {
            print("ActivityManager: Error handling system sleep - \(error.localizedDescription)")
            
            // Even if save fails, ensure we're in consistent state
            sleepStartTime = Date()
            currentActivity = nil
            
            // Log the specific error for debugging
            if let activityError = error as? ActivityManagerError {
                print("ActivityManager: Sleep handling error details - \(activityError.errorDescription ?? "Unknown error")")
            }
        }
    }
    
    /// Handle system wake event - clears sleep state and prepares for normal tracking
    private func handleSystemWake() {
        print("ActivityManager: System woke from sleep")
        
        
        // TODO: Add user preference/setting to determine whether to continue tracking 
        // the same time-entry that was active before sleep or start fresh.
        // This will be implemented at the time-entry level, not activity level.
        
        // Normal app activation events will handle starting new tracking automatically
        
        print("ActivityManager: Wake handling completed - ready for new app activation events")
    }
}