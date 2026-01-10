import os

extension Logger {
    /// UI-related logs (view changes, user interactions)
    static let ui = Logger(subsystem: "dev.leix.chronote", category: "UI")

    /// Application state management logs
    static let appState = Logger(subsystem: "dev.leix.chronote", category: "AppState")

    /// Project management and operations logs
    static let projectManager = Logger(subsystem: "dev.leix.chronote", category: "ProjectManager")

    /// Activity tracking and monitoring logs
    static let activity = Logger(subsystem: "dev.leix.chronote", category: "Activity")

    /// Database and persistence logs
    static let database = Logger(subsystem: "dev.leix.chronote", category: "Database")

    /// General application logs
    static let general = Logger(subsystem: "dev.leix.chronote", category: "General")
}

/// Privacy levels for logging sensitive information
enum LogPrivacy {
    case `public`
    case `private`
    case sensitive
    case auto
}
