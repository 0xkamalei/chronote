
import SwiftUI
import SwiftData
import os

// MARK: - App Delegate for Lifecycle Management
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.time.vscode", category: "AppDelegate")
    var modelContainer: ModelContainer?
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application will terminate - stopping activity tracking")
        
        if let modelContainer = modelContainer {
            let context = modelContainer.mainContext
            
            let semaphore = DispatchSemaphore(value: 0)
            
            Task { @MainActor in
                ActivityManager.shared.stopTracking(modelContext: context)
                logger.info("Activity tracking stopped during app termination")
                semaphore.signal()
            }
            
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
        let schema = Schema([
            Item.self,
            Activity.self,
            Project.self,
            TimeEntry.self,
            TimerSession.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none // Keep data local for privacy
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            let context = container.mainContext
            
            SchemaMigration.performMigrationIfNeeded(modelContext: context)
            
            Task {
                do {
                    try await DatabaseConfiguration.optimizeDatabase(modelContext: context)
                } catch {
                    logger.error("Failed to optimize database: \(error)")
                }
            }
            
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
                    appDelegate.modelContainer = sharedModelContainer
                    setupAppState()
                    startActivityTracking()
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit time-vscode") {
                    stopActivityTrackingAndQuit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
    
    // MARK: - App Setup
    
    /// Set up AppState with model context and notification integration
    private func setupAppState() {
        Task { @MainActor in
            let context = sharedModelContainer.mainContext
            appState.setModelContext(context)
            Self.logger.info("AppState configured with model context and notifications")
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
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            NSApplication.shared.terminate(nil)
        }
    }
}
