
import os
import SwiftData
import SwiftUI

@main
struct time_vscodeApp: App {
    private static let logger = Logger(subsystem: "com.time.vscode", category: "App")

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Activity.self,
            Project.self,
            TimeEntry.self,
            Rule.self,
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
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .environment(appState)
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
    }
}
