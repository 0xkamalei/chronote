import Foundation

// MARK: - Project Management Types

/// Errors that can occur during project operations
enum ProjectError: LocalizedError, Equatable {
    case invalidName(String)
    case hasActiveTimer
    case hasTimeEntries(count: Int)
    case persistenceFailure(String)
    case projectNotFound(String)
    case duplicateName(String)
    case operationCancelled
    case invalidOperation(String)

    var errorDescription: String? {
        switch self {
        case let .invalidName(reason):
            return "Invalid project name: \(reason)"
        case .hasActiveTimer:
            return "Cannot delete project with active timer"
        case let .hasTimeEntries(count):
            return "Project has \(count) time \(count == 1 ? "entry" : "entries")"
        case let .persistenceFailure(details):
            return "Failed to save changes: \(details)"
        case let .projectNotFound(id):
            return "Project not found: \(id)"
        case let .duplicateName(name):
            return "A project with the name '\(name)' already exists"
        case .operationCancelled:
            return "Operation was cancelled"
        case let .invalidOperation(reason):
            return "Invalid operation: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidName:
            return "Please enter a valid project name with at least one non-whitespace character."
        case .hasActiveTimer:
            return "Stop the active timer before deleting this project."
        case .hasTimeEntries:
            return "Choose how to handle the time entries: reassign them to another project or delete them."
        case .persistenceFailure:
            return "Check your disk space and file permissions, then try again."
        case .projectNotFound:
            return "The project may have been deleted. Refresh the project list."
        case .duplicateName:
            return "Choose a different name."
        case .operationCancelled:
            return nil
        case .invalidOperation:
            return "The operation cannot be completed in the current state."
        }
    }

    var failureReason: String? {
        switch self {
        case let .invalidName(reason):
            return reason
        case .hasActiveTimer:
            return "An active timer is running for this project"
        case let .hasTimeEntries(count):
            return "\(count) time \(count == 1 ? "entry is" : "entries are") associated with this project"
        case let .persistenceFailure(details):
            return details
        case let .projectNotFound(id):
            return "Project ID \(id) not found in the database"
        case let .duplicateName(name):
            return "Project name '\(name)' conflicts with an existing project"
        case .operationCancelled:
            return "User cancelled the operation"
        case let .invalidOperation(reason):
            return reason
        }
    }

    // MARK: - Equatable Conformance

    static func == (lhs: ProjectError, rhs: ProjectError) -> Bool {
        switch (lhs, rhs) {
        case let (.invalidName(l), .invalidName(r)):
            return l == r
        case (.hasActiveTimer, .hasActiveTimer):
            return true
        case let (.hasTimeEntries(l), .hasTimeEntries(r)):
            return l == r
        case let (.persistenceFailure(l), .persistenceFailure(r)):
            return l == r
        case let (.projectNotFound(l), .projectNotFound(r)):
            return l == r
        case let (.duplicateName(l), .duplicateName(r)):
            return l == r
        case (.operationCancelled, .operationCancelled):
            return true
        case let (.invalidOperation(l), .invalidOperation(r)):
            return l == r
        default:
            return false
        }
    }
}
