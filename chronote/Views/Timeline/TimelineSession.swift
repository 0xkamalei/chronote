import Foundation

/// TimelineSession represents a "cognitive session" - how the user perceives their time spent,
/// not just raw activity data.
///
/// Based on OpenAI's analysis: "Timing doesn't visualize activities, it visualizes cognitive sessions"
/// This model bridges the gap between raw Activity records and user perception.
struct TimelineSession {
    let id: UUID
    var startTime: Date
    var endTime: Date

    /// Primary project or app for this session
    /// Note: projectId is stored as String in Activity model
    var primaryProjectId: String?
    var primaryAppBundleId: String
    var primaryAppName: String

    /// Confidence in the primary app (0-1). Lower = less certain user was truly focused.
    var confidence: Double = 1.0

    /// All underlying activities that contributed to this session
    var underlyingActivityIds: [UUID]

    /// Child activities with their time slices (for drill-down if needed)
    var activities: [TimelineSessionActivity] = []

    /// Whether this session contains noise that was suppressed
    /// (e.g., system notifications, quick app switches)
    var containsNoise: Bool = false

    /// Metrics
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var activityCount: Int {
        underlyingActivityIds.count
    }
}

/// Individual activity within a session (for drill-down details)
struct TimelineSessionActivity {
    let activityId: UUID
    let appBundleId: String
    let appName: String
    let startTime: Date
    let endTime: Date
    let isNoise: Bool
}

/// Aggregated metrics for a session (used for statistics)
extension TimelineSession {
    var appDistribution: [String: TimeInterval] {
        var distribution: [String: TimeInterval] = [:]
        for activity in activities {
            let duration = activity.endTime.timeIntervalSince(activity.startTime)
            distribution[activity.appBundleId, default: 0] += duration
        }
        return distribution
    }
}
