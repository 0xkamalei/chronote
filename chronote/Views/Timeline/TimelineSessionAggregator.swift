import Foundation

/// TimelineSessionAggregator implements the "cognitive session" aggregation logic.
///
/// Key principles from OpenAI's analysis:
/// 1. Noise suppression: Activities < 30s are merged into neighbors
/// 2. Visual continuity: Activities with gaps < 90s are merged if same project
/// 3. Session inference: Merge short interruptions to maintain focus perception
/// 4. Project-based grouping: Same project = same session whenever possible
///
/// This is DIFFERENT from the statistical 30-minute merge - this is for visual perception.
class TimelineSessionAggregator {
    // MARK: - Configuration (Visual/Cognitive Thresholds)

    /// Activities shorter than this are considered "noise" and absorbed into neighbors
    /// (vs statistical 30 minutes, this is about perception)
    private let noiseThreshold: TimeInterval = 30 // 30 seconds

    /// Gap between activities of same project to trigger merge
    /// Matches user's perception of "continuous focus on same task"
    private let visualContinuityThreshold: TimeInterval = 90 // 90 seconds

    /// Minimum session duration to be worth displaying as a distinct session
    /// (avoid 2-second "session" artifacts)
    private let minSessionDuration: TimeInterval = 5 // 5 seconds

    // MARK: - Aggregation API

    /// Aggregate activities into cognitive sessions
    /// - Parameters:
    ///   - activities: Raw activities to aggregate
    ///   - includeNoise: Whether to track noise in returned sessions
    /// - Returns: Array of TimelineSession ordered by startTime
    func aggregateSessions(from activities: [Activity], includeNoise: Bool = true) -> [TimelineSession] {
        guard !activities.isEmpty else { return [] }

        let sortedActivities = activities.sorted { $0.startTime < $1.startTime }

        var sessions: [TimelineSession] = []
        var currentSession: TimelineSessionBuilder?

        for activity in sortedActivities {
            let activityEnd = activity.endTime ?? Date()
            let activityDuration = activityEnd.timeIntervalSince(activity.startTime)
            let isNoise = activityDuration < noiseThreshold
            
            if var builder = currentSession {
                let gap = activity.startTime.timeIntervalSince(builder.endTime)
                let shortGap = gap <= visualContinuityThreshold
                
                var shouldMerge = false
                
                if isNoise {
                    // Only merge noise if it's close enough to the previous session
                    if shortGap {
                        shouldMerge = true
                    }
                } else {
                    // Standard merge logic for non-noise activities
                    // Note: projectId is stored as String in Activity
                    let sameProject = (activity.projectId != nil && activity.projectId == builder.primaryProjectId)
                    let sameApp = activity.appBundleId == builder.primaryAppBundleId
                    
                    // Merge if: short gap AND (same project OR same app)
                    if shortGap && (sameProject || sameApp) {
                        shouldMerge = true
                    }
                }
                
                if shouldMerge {
                    builder.addActivity(activity, isNoise: isNoise)
                    currentSession = builder
                } else {
                    // Close previous session
                    if let session = builder.build(minDuration: minSessionDuration) {
                        sessions.append(session)
                    }
                    // Start new session
                    currentSession = TimelineSessionBuilder(from: activity, isNoise: isNoise)
                }
            } else {
                // Start first session
                currentSession = TimelineSessionBuilder(from: activity, isNoise: isNoise)
            }
        }

        // Finalize last session
        if let builder = currentSession, let session = builder.build(minDuration: minSessionDuration) {
            sessions.append(session)
        }

        return sessions
    }

    // MARK: - Helper: Session Builder

    private class TimelineSessionBuilder {
        var id = UUID()
        var startTime: Date
        var endTime: Date
        var primaryAppBundleId: String
        var primaryAppName: String
        var primaryProjectId: String?  // Note: projectId is String in Activity
        var activityIds: [UUID] = []
        var sessionActivities: [TimelineSessionActivity] = []
        var containsNoise = false
        var lastActivityWasNoise = false

        init(from activity: Activity, isNoise: Bool) {
            self.startTime = activity.startTime
            self.endTime = activity.endTime ?? Date()
            self.primaryAppBundleId = activity.appBundleId
            self.primaryAppName = activity.appName
            self.primaryProjectId = activity.projectId
            self.lastActivityWasNoise = isNoise
            self.containsNoise = isNoise

            addActivity(activity, isNoise: isNoise)
        }

        func addActivity(_ activity: Activity, isNoise: Bool) {
            let actEnd = activity.endTime ?? Date()

            activityIds.append(activity.id)
            sessionActivities.append(TimelineSessionActivity(
                activityId: activity.id,
                appBundleId: activity.appBundleId,
                appName: activity.appName,
                startTime: activity.startTime,
                endTime: actEnd,
                isNoise: isNoise
            ))

            // Extend session bounds
            if activity.startTime < startTime {
                startTime = activity.startTime
            }
            if actEnd > endTime {
                endTime = actEnd
            }

            // Update confidence (lower if contains noise or app switches)
            if isNoise {
                containsNoise = true
            }

            lastActivityWasNoise = isNoise
        }

        func build(minDuration: TimeInterval) -> TimelineSession? {
            let duration = endTime.timeIntervalSince(startTime)
            guard duration >= minDuration else { return nil }

            return TimelineSession(
                id: id,
                startTime: startTime,
                endTime: endTime,
                primaryProjectId: primaryProjectId,
                primaryAppBundleId: primaryAppBundleId,
                primaryAppName: primaryAppName,
                confidence: calculateConfidence(),
                underlyingActivityIds: activityIds,
                activities: sessionActivities,
                containsNoise: containsNoise
            )
        }

        private func calculateConfidence() -> Double {
            // Confidence is lower if:
            // 1. Session contains noise
            // 2. Multiple apps are represented
            // 3. Many short interruptions
            var confidence = 1.0

            if containsNoise {
                confidence *= 0.85
            }

            let uniqueApps = Set(sessionActivities.map { $0.appBundleId }).count
            if uniqueApps > 1 {
                let appDiversityPenalty = Double(uniqueApps - 1) * 0.1
                confidence *= max(0.6, 1.0 - appDiversityPenalty)
            }

            return confidence
        }
    }
}
