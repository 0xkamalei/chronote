import Foundation
import SwiftData

/// Represents a continuous work session without major interruptions
/// A session groups activities that occur close together in time
@Model
final class Session {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var dominantAppBundleId: String?
    var dominantAppName: String?
    var contextSwitchCount: Int
    
    // Computed property for duration
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    // Store activity IDs instead of direct relationship to avoid complexity
    var activityIds: [UUID]
    
    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        dominantAppBundleId: String? = nil,
        dominantAppName: String? = nil,
        contextSwitchCount: Int = 0,
        activityIds: [UUID] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.dominantAppBundleId = dominantAppBundleId
        self.dominantAppName = dominantAppName
        self.contextSwitchCount = contextSwitchCount
        self.activityIds = activityIds
    }
}
