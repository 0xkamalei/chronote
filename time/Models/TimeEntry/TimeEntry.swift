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

    var calculatedDuration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

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

    var minutes: Int {
        return Int(calculatedDuration / 60)
    }

    var hours: Double {
        return calculatedDuration / 3600
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

    // Convenience initializer
    convenience init(id: String, startTime: Date, endTime: Date, projectID: String?, title: String, notes: String?) {
        self.init(
            projectId: projectID,
            title: title,
            notes: notes,
            startTime: startTime,
            endTime: endTime
        )
        self.id = UUID(uuidString: id) ?? UUID()
    }

    // MARK: - Helper Methods

    func recalculateDuration() {
        duration = calculatedDuration
    }

    var isValid: Bool {
        return !title.trimmingCharacters(in: .whitespaces).isEmpty
            && startTime < endTime
    }

    func repairDataIntegrity() {
        if startTime > endTime {
            swap(&startTime, &endTime)
        }
        recalculateDuration()
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

    /// Updates the updatedAt timestamp
    func markAsUpdated() {
        updatedAt = Date()
    }
}
