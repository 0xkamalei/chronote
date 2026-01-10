
import os
import SwiftData
import SwiftUI

@main
struct timApp: App {
    private static let logger = Logger(subsystem: "com.time.vscode", category: "App")

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Activity.self,
            Project.self,
            AutoAssignRule.self,
            Event.self,
        ])
        
        // Define a custom store URL
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        let storeURL = appSupportDir.appendingPathComponent("time-trace.store")

        let modelConfiguration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            logger.error("Could not create ModelContainer: \(error.localizedDescription)")
            
            // Attempt to recover by deleting the store if migration fails
            // Check for specific migration errors or general failure
            let nsError = error as NSError
            
            // Function to recursively check for migration error
            func isMigrationError(_ error: NSError) -> Bool {
                if error.domain == NSCocoaErrorDomain && error.code == 134110 {
                    return true
                }
                if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    return isMigrationError(underlying)
                }
                return false
            }
            
            // Code 134110 is persistent store migration error (NSValidationMissingMandatoryPropertyError)
            if isMigrationError(nsError) {
                logger.warning("Migration failed. Attempting to delete existing store and recreate.")
                
                let walURL = storeURL.deletingPathExtension().appendingPathExtension("store-wal")
                let shmURL = storeURL.deletingPathExtension().appendingPathExtension("store-shm")
                
                do {
                    try FileManager.default.removeItem(at: storeURL)
                    try? FileManager.default.removeItem(at: walURL)
                    try? FileManager.default.removeItem(at: shmURL)
                    logger.info("Deleted old store files at \(storeURL.path).")
                    
                    // Retry creating the container
                    let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                    logger.info("Successfully recreated ModelContainer after reset.")
                    return container
                } catch {
                    logger.critical("Failed to delete store or recreate container: \(error.localizedDescription)")
                    fatalError("Could not create ModelContainer: \(error.localizedDescription)")
                }
            }
            
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()

    @State private var appState = AppState()
    @State private var eventManager = EventManager()
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .environment(appState)
                .environment(eventManager)
                .preferredColorScheme(appTheme.colorScheme)
                .onAppear {
                    eventManager.setModelContext(sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit time-vscode") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
        
        MenuBarExtra {
            MenuBarView()
                .environment(eventManager)
                .modelContainer(sharedModelContainer)
        } label: {
            if let event = eventManager.currentEvent {
                MenuBarLabelView(event: event)
            } else {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
