//
//  time_vscodeApp.swift
//  time-vscode
//
//  Created by seven on 2025/7/1.
//

import SwiftUI
import SwiftData
import OSLog

// MARK: - App Delegate for Lifecycle Management
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.time.vscode", category: "AppDelegate")
    var modelContainer: ModelContainer?
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application will terminate - stopping activity tracking")
        
        // Stop activity tracking synchronously to ensure cleanup completes
        if let modelContainer = modelContainer {
            let context = modelContainer.mainContext
            
            // Run synchronously to ensure completion before termination
            let semaphore = DispatchSemaphore(value: 0)
            
            Task { @MainActor in
                ActivityManager.shared.stopTracking(modelContext: context)
                logger.info("Activity tracking stopped during app termination")
                semaphore.signal()
            }
            
            // Wait for cleanup to complete (with timeout)
            _ = semaphore.wait(timeout: .now() + 2.0)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
    }
}

@main
struct time_vscodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private static let logger = Logger(subsystem: "com.time.vscode", category: "App")
    
    var sharedModelContainer: ModelContainer = {
        // Define schema with all models
        let schema = Schema([
            Item.self,
            Activity.self,
        ])
        
        // Configure ModelConfiguration for optimal SQLite performance
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none // Keep data local for privacy
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Get main context for initialization
            let context = container.mainContext
            
            // Perform migration if needed
            SchemaMigration.performMigrationIfNeeded(modelContext: context)
            
            // Optimize database configuration
            DatabaseConfiguration.optimizeDatabase(modelContext: context)
            
            // Validate schema integrity
            if !DatabaseConfiguration.validateSchema(modelContext: context) {
                logger.error("Schema validation failed during initialization")
            }
            
            logger.info("ModelContainer initialized successfully")
            return container
        } catch {
            logger.error("Could not create ModelContainer: \(error.localizedDescription)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Set model container reference in app delegate for lifecycle management
                    appDelegate.modelContainer = sharedModelContainer
                    startActivityTracking()
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // Add app termination handling
            CommandGroup(replacing: .appTermination) {
                Button("Quit time-vscode") {
                    stopActivityTrackingAndQuit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
    
    // MARK: - Activity Tracking Integration
    
    /// Start activity tracking when the app launches
    private func startActivityTracking() {
        Task { @MainActor in
            let context = sharedModelContainer.mainContext
            ActivityManager.shared.startTracking(modelContext: context)
            Self.logger.info("Activity tracking started automatically on app launch")
        }
    }
    
    /// Stop activity tracking and quit the app
    private func stopActivityTrackingAndQuit() {
        Task { @MainActor in
            let context = sharedModelContainer.mainContext
            ActivityManager.shared.stopTracking(modelContext: context)
            Self.logger.info("Activity tracking stopped before app termination")
            
            // Give a moment for cleanup to complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Quit the app
            NSApplication.shared.terminate(nil)
        }
    }
}
