import os

extension Logger {
    /// UI-related logs (view changes, user interactions)
    static let ui = Logger(subsystem: "com.time.vscode", category: "UI")

    /// Application state management logs
    static let appState = Logger(subsystem: "com.time.vscode", category: "AppState")

    /// Project management and operations logs
    static let projectManager = Logger(subsystem: "com.time.vscode", category: "ProjectManager")

    /// Activity tracking and monitoring logs
    static let activity = Logger(subsystem: "com.time.vscode", category: "Activity")

    /// Database and persistence logs
    static let database = Logger(subsystem: "com.time.vscode", category: "Database")

    /// General application logs
    static let general = Logger(subsystem: "com.time.vscode", category: "General")
}

/// Privacy levels for logging sensitive information
enum LogPrivacy {
    case `public`
    case `private`
    case sensitive
    case auto
}
