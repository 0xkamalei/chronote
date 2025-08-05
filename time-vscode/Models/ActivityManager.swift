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
        // Remove all notification observers
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
        
        notificationObservers.removeAll()
        
        // Clear model context reference
        self.modelContext = nil
        
        print("ActivityManager: Stopped tracking, removed \(notificationObservers.count) observers")
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
                
                // Insert the finished activity into database and save
                modelContext.insert(current)
                try modelContext.save()
                
                print("ActivityManager: Finished and saved activity - \(current.appName) (\(current.duration)s)")
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
    
    /// Get the currently active activity
    func getCurrentActivity() -> Activity? {
        // TODO: Implement current activity retrieval
        return currentActivity
    }
    
    /// Get recent activities with specified limit
    func getRecentActivities(limit: Int) -> [Activity] {
        // TODO: Implement recent activities retrieval
        return []
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
    
    /// Handle system sleep event
    private func handleSystemSleep() {
        do {
            print("ActivityManager: System going to sleep")
            
            // Finish current activity if one exists
            if let current = currentActivity {
                current.endTime = Date()
                current.duration = current.calculatedDuration
                
                // Validate duration is positive
                if current.duration < 0 {
                    print("ActivityManager: Warning - Negative duration detected, setting to 0")
                    current.duration = 0
                }
                
                // Insert and save to database if model context is available
                if let context = modelContext {
                    context.insert(current)
                    try context.save()
                    print("ActivityManager: Saved current activity before sleep - \(current.appName) (\(current.duration)s)")
                }
                
                currentActivity = nil
            }
            
        } catch {
            print("ActivityManager: Error handling system sleep - \(error.localizedDescription)")
        }
    }
    
    /// Handle system wake event
    private func handleSystemWake() {
        print("ActivityManager: System woke from sleep")
        
        // Clear any stale current activity reference
        currentActivity = nil
        
        // Get the currently active application to resume tracking
        if let activeApp = NSWorkspace.shared.frontmostApplication,
           activeApp.bundleIdentifier != nil {
            let appInfo = resolveAppInfo(from: activeApp)
            print("ActivityManager: Resuming tracking for active app - \(appInfo.name)")
            
            // Track the currently active app with detailed information
            guard let context = modelContext else {
                print("ActivityManager: No model context available for wake tracking")
                return
            }
            trackAppSwitch(appInfo: appInfo, modelContext: context)
        }
    }
}