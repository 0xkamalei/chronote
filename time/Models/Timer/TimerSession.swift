import Foundation
import SwiftData
import SwiftUI

@Model
final class TimerSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var projectId: String?
    var title: String?
    var notes: String?
    var estimatedDuration: TimeInterval?
    var actualDuration: TimeInterval?
    var isCompleted: Bool = false
    var wasInterrupted: Bool = false
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    /// Current elapsed time for active sessions
    var elapsedTime: TimeInterval {
        let endTime = self.endTime ?? Date()
        return endTime.timeIntervalSince(startTime)
    }

    /// Whether this session is currently active
    var isActive: Bool {
        return endTime == nil && !isCompleted
    }

    /// Formatted elapsed time string
    var formattedElapsedTime: String {
        return formatDuration(elapsedTime)
    }

    /// Formatted estimated duration string
    var formattedEstimatedDuration: String? {
        guard let estimatedDuration = estimatedDuration else { return nil }
        return formatDuration(estimatedDuration)
    }

    /// Progress towards estimated duration (0.0 to 1.0+)
    var progress: Double {
        guard let estimatedDuration = estimatedDuration, estimatedDuration > 0 else { return 0.0 }
        return elapsedTime / estimatedDuration
    }

    /// Whether the session has exceeded its estimated duration
    var hasExceededEstimate: Bool {
        guard let estimatedDuration = estimatedDuration else { return false }
        return elapsedTime > estimatedDuration
    }

    // MARK: - Initialization

    init(projectId: String? = nil, title: String? = nil, notes: String? = nil, estimatedDuration: TimeInterval? = nil) {
        id = UUID()
        startTime = Date()
        endTime = nil
        self.projectId = projectId
        self.title = title
        self.notes = notes
        self.estimatedDuration = estimatedDuration
        actualDuration = nil
        isCompleted = false
        wasInterrupted = false
        createdAt = Date()
        updatedAt = Date()
    }

    // MARK: - Session Management

    /// Completes the timer session
    func complete() {
        guard isActive else { return }

        endTime = Date()
        actualDuration = elapsedTime
        isCompleted = true
        updatedAt = Date()
    }

    /// Marks the session as interrupted
    func interrupt() {
        guard isActive else { return }

        endTime = Date()
        actualDuration = elapsedTime
        wasInterrupted = true
        isCompleted = true
        updatedAt = Date()
    }

    /// Updates session metadata
    func updateMetadata(title: String? = nil, notes: String? = nil, projectId: String? = nil, estimatedDuration: TimeInterval? = nil) {
        if let title = title {
            self.title = title
        }
        if let notes = notes {
            self.notes = notes
        }
        if let projectId = projectId {
            self.projectId = projectId
        }
        if let estimatedDuration = estimatedDuration {
            self.estimatedDuration = estimatedDuration
        }
        updatedAt = Date()
    }

    // MARK: - Validation

    /// Validates the timer session data
    func validate() -> TimerSessionValidationResult {
        // Validate start time
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let oneHourFromNow = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now

        if startTime < oneYearAgo || startTime > oneHourFromNow {
            return .failure(.invalidStartTime("Start time is outside reasonable range"))
        }

        // Validate end time if present
        if let endTime = endTime {
            if endTime <= startTime {
                return .failure(.invalidEndTime("End time must be after start time"))
            }

            if endTime > oneHourFromNow {
                return .failure(.invalidEndTime("End time cannot be in the future"))
            }
        }

        // Validate estimated duration if present
        if let estimatedDuration = estimatedDuration {
            if estimatedDuration <= 0 {
                return .failure(.invalidEstimatedDuration("Estimated duration must be positive"))
            }

            if estimatedDuration > 24 * 60 * 60 { // 24 hours
                return .failure(.invalidEstimatedDuration("Estimated duration cannot exceed 24 hours"))
            }
        }

        // Validate title length if present
        if let title = title, title.count > 200 {
            return .failure(.invalidTitle("Title cannot exceed 200 characters"))
        }

        // Validate notes length if present
        if let notes = notes, notes.count > 1000 {
            return .failure(.invalidNotes("Notes cannot exceed 1000 characters"))
        }

        return .success
    }

    // MARK: - Utility Methods

    /// Formats a duration in seconds to a human-readable string
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Creates a TimeEntry from this completed session
    func createTimeEntry() -> TimeEntry? {
        guard isCompleted, let endTime = endTime else { return nil }

        let timeEntry = TimeEntry(
            projectId: projectId,
            title: title ?? "Timer Session",
            notes: notes,
            startTime: startTime,
            endTime: endTime
        )

        return timeEntry
    }
}

// MARK: - Validation Types

enum TimerSessionValidationResult {
    case success
    case failure(TimerSessionError)
}

enum TimerSessionError: LocalizedError {
    case invalidStartTime(String)
    case invalidEndTime(String)
    case invalidEstimatedDuration(String)
    case invalidTitle(String)
    case invalidNotes(String)
    case sessionAlreadyCompleted
    case sessionNotActive

    var errorDescription: String? {
        switch self {
        case let .invalidStartTime(message):
            return "Invalid start time: \(message)"
        case let .invalidEndTime(message):
            return "Invalid end time: \(message)"
        case let .invalidEstimatedDuration(message):
            return "Invalid estimated duration: \(message)"
        case let .invalidTitle(message):
            return "Invalid title: \(message)"
        case let .invalidNotes(message):
            return "Invalid notes: \(message)"
        case .sessionAlreadyCompleted:
            return "Timer session is already completed"
        case .sessionNotActive:
            return "Timer session is not active"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidStartTime:
            return "Ensure the start time is within a reasonable range."
        case .invalidEndTime:
            return "Ensure the end time is after the start time and not in the future."
        case .invalidEstimatedDuration:
            return "Set an estimated duration between 1 minute and 24 hours."
        case .invalidTitle:
            return "Keep the title under 200 characters."
        case .invalidNotes:
            return "Keep the notes under 1000 characters."
        case .sessionAlreadyCompleted:
            return "Create a new timer session instead."
        case .sessionNotActive:
            return "Start a new timer session first."
        }
    }
}
