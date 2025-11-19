
import os
import SwiftData
import SwiftUI

@main
struct time_vscodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private static let logger = Logger(subsystem: "com.time.vscode", category: "App")

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
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
            return container
        } catch {
            logger.error("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .environmentObject(appState)
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
    }
}
