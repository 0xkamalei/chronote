import Foundation
import SwiftData
import SwiftUI

@Model
final class TimeEntry {
    @Attribute(.unique) var id: UUID
    var projectId: String?
    var title: String
    var notes: String?
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    /// Calculates duration from start and end times for validation
    var calculatedDuration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    /// Returns a formatted duration string (e.g., "2h 30m", "45m", "<1m")
    var durationString: String {
        let totalMinutes = Int(calculatedDuration / 60)

        if totalMinutes < 1 {
            return "<1m"
        } else if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }

    /// Returns duration in minutes for calculations
    var minutes: Int {
        return Int(calculatedDuration / 60)
    }

    /// Returns duration in hours for calculations
    var hours: Double {
        return calculatedDuration / 3600
    }

    /// Validates if the time entry has valid data
    var isValid: Bool {
        if case .success = validateTimeEntry() {
            return true
        }
        return false
    }

    /// Returns the project associated with this time entry (computed at runtime)
    var project: Project? {
        guard projectId != nil else { return nil }
        // This will be resolved through ProjectManager when needed
        return nil
    }

    // MARK: - Initialization

    init(projectId: String? = nil, title: String, notes: String? = nil, startTime: Date, endTime: Date) {
        id = UUID()
        self.projectId = projectId
        self.title = title
        self.notes = notes
        self.startTime = startTime
        self.endTime = endTime
        duration = endTime.timeIntervalSince(startTime)
        createdAt = Date()
        updatedAt = Date()
    }
    
    // Convenience initializer with string ID and isManual flag
    convenience init(id: String, startTime: Date, endTime: Date, projectID: String?, title: String, notes: String?, isManual: Bool) {
        self.init(
            projectId: projectID,
            title: title,
            notes: notes,
            startTime: startTime,
            endTime: endTime
        )
        // Override the UUID with the provided string ID
        self.id = UUID(uuidString: id) ?? UUID()
        // Note: isManual flag could be added as a property if needed in the future
    }

    // MARK: - Validation Methods

    /// Validates the entire time entry
    func validateTimeEntry() -> TimeEntryValidationResult {
        // Validate title
        if let titleValidation = validateTitle(title), case .failure = titleValidation {
            return titleValidation
        }

        // Validate time range
        if let timeValidation = validateTimeRange(startTime: startTime, endTime: endTime), case .failure = timeValidation {
            return timeValidation
        }

        // Validate duration consistency
        if let durationValidation = validateDurationConsistency(), case .failure = durationValidation {
            return durationValidation
        }

        return .success
    }

    /// Validates the title field
    func validateTitle(_ title: String) -> TimeEntryValidationResult? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            return .failure(.invalidTimeEntry("Title cannot be empty"))
        }

        if trimmedTitle.count > 200 {
            return .failure(.invalidTimeEntry("Title cannot exceed 200 characters"))
        }

        return .success
    }

    /// Validates the time range
    func validateTimeRange(startTime: Date, endTime: Date) -> TimeEntryValidationResult? {
        if endTime <= startTime {
            return .failure(.invalidTimeEntry("End time must be after start time"))
        }

        let duration = endTime.timeIntervalSince(startTime)

        // Minimum duration: 1 minute
        if duration < 60 {
            return .failure(.invalidTimeEntry("Duration must be at least 1 minute"))
        }

        // Maximum duration: 24 hours
        if duration > 24 * 60 * 60 {
            return .failure(.invalidTimeEntry("Duration cannot exceed 24 hours"))
        }

        // Check if times are in reasonable range (not too far in future/past)
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now

        if startTime < oneYearAgo || startTime > oneYearFromNow {
            return .failure(.invalidTimeEntry("Start time is outside reasonable range"))
        }

        if endTime < oneYearAgo || endTime > oneYearFromNow {
            return .failure(.invalidTimeEntry("End time is outside reasonable range"))
        }

        return .success
    }

    /// Validates that stored duration matches calculated duration
    func validateDurationConsistency() -> TimeEntryValidationResult? {
        let calculatedDur = calculatedDuration
        let tolerance: TimeInterval = 1.0 // 1 second tolerance

        if abs(duration - calculatedDur) > tolerance {
            return .failure(.invalidTimeEntry("Stored duration does not match calculated duration"))
        }

        return .success
    }

    /// Validates notes field
    func validateNotes(_ notes: String?) -> TimeEntryValidationResult? {
        guard let notes = notes else { return .success }

        if notes.count > 1000 {
            return .failure(.invalidTimeEntry("Notes cannot exceed 1000 characters"))
        }

        return .success
    }

    // MARK: - Data Integrity Methods

    /// Updates the stored duration to match calculated duration
    func recalculateDuration() {
        let oldDuration = duration
        duration = calculatedDuration

        if abs(oldDuration - duration) > 1.0 {
            updatedAt = Date()
        }
    }

    /// Updates the updatedAt timestamp
    func markAsUpdated() {
        updatedAt = Date()
    }

    /// Repairs any data integrity issues
    func repairDataIntegrity() {
        // Fix duration if inconsistent
        recalculateDuration()

        // Trim whitespace from title
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure title is not empty
        if title.isEmpty {
            title = "Untitled Entry"
        }

        // Trim notes if present
        if let notes = notes {
            self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if self.notes?.isEmpty == true {
                self.notes = nil
            }
        }

        markAsUpdated()
    }

    // MARK: - Utility Methods

    /// Returns a copy of this time entry with updated times
    func withUpdatedTimes(startTime: Date, endTime: Date) -> TimeEntry {
        let updated = TimeEntry(
            projectId: projectId,
            title: title,
            notes: notes,
            startTime: startTime,
            endTime: endTime
        )
        updated.createdAt = createdAt
        return updated
    }

    /// Returns a copy of this time entry with updated project
    func withUpdatedProject(_ projectId: String?) -> TimeEntry {
        let updated = TimeEntry(
            projectId: projectId,
            title: title,
            notes: notes,
            startTime: startTime,
            endTime: endTime
        )
        updated.createdAt = createdAt
        return updated
    }

    /// Checks if this time entry overlaps with another time entry
    func overlaps(with other: TimeEntry) -> Bool {
        return startTime < other.endTime && endTime > other.startTime
    }

    /// Returns the overlap duration with another time entry
    func overlapDuration(with other: TimeEntry) -> TimeInterval {
        guard overlaps(with: other) else { return 0 }

        let overlapStart = max(startTime, other.startTime)
        let overlapEnd = min(endTime, other.endTime)

        return overlapEnd.timeIntervalSince(overlapStart)
    }
}

// MARK: - TimeEntryValidationResult and Error Types

enum TimeEntryValidationResult {
    case success
    case failure(TimeEntryError)
}

enum TimeEntryError: LocalizedError {
    case invalidTimeRange(String)
    case invalidDuration(String)
    case projectNotFound(String)
    case titleRequired
    case persistenceFailure(String)
    case validationFailed(String)
    case invalidTimeEntry(String) // Keep for backward compatibility

    var errorDescription: String? {
        switch self {
        case let .invalidTimeRange(message):
            return "Invalid time range: \(message)"
        case let .invalidDuration(message):
            return "Invalid duration: \(message)"
        case let .projectNotFound(message):
            return "Project not found: \(message)"
        case .titleRequired:
            return "Title is required"
        case let .persistenceFailure(message):
            return "Persistence failure: \(message)"
        case let .validationFailed(message):
            return "Validation failed: \(message)"
        case let .invalidTimeEntry(message):
            return "Invalid time entry: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidTimeRange:
            return "Ensure the end time is after the start time and both are within reasonable bounds."
        case .invalidDuration:
            return "Check that the duration is between 1 minute and 24 hours."
        case .projectNotFound:
            return "Select a valid project or leave unassigned."
        case .titleRequired:
            return "Enter a descriptive title for the time entry."
        case .persistenceFailure:
            return "Check your storage permissions and try again."
        case .validationFailed:
            return "Review the input data and correct any errors."
        case .invalidTimeEntry:
            return "Review all time entry fields and correct any errors."
        }
    }
}
