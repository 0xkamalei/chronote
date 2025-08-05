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
    
    /// Track app switch to new application
    func trackAppSwitch(newApp: String, modelContext: ModelContext) {
        // TODO: Implement app switch tracking logic
        // This method will be implemented in task 5
        print("ActivityManager: App switch to \(newApp) - tracking logic not yet implemented")
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
        
        // Track the app switch (will be implemented in future task)
        guard let context = modelContext else {
            print("ActivityManager: No model context available for app switch tracking")
            return
        }
        trackAppSwitch(newApp: appName, modelContext: context)
    }
    
    /// Handle system sleep event
    private func handleSystemSleep() {
        do {
            print("ActivityManager: System going to sleep")
            
            // Finish current activity if one exists
            if let current = currentActivity {
                current.endTime = Date()
                current.duration = current.endTime!.timeIntervalSince(current.startTime)
                
                // Save to database if model context is available
                if let context = modelContext {
                    try context.save()
                    print("ActivityManager: Saved current activity before sleep")
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
           let bundleId = activeApp.bundleIdentifier {
            let appName = activeApp.localizedName ?? bundleId
            print("ActivityManager: Resuming tracking for active app - \(appName)")
            
            // Track the currently active app (will be implemented in future task)
            guard let context = modelContext else {
                print("ActivityManager: No model context available for wake tracking")
                return
            }
            trackAppSwitch(newApp: appName, modelContext: context)
        }
    }
}