import Foundation
import SwiftUI
import AppKit

struct TimelineEventSnapshot: Sendable {
    let id: UUID
    let name: String
    let startTime: Date
    let endTime: Date
    let projectId: String?

    init(from event: Event, fallbackEndTime: Date) {
        let resolvedEndTime = max(event.endTime ?? fallbackEndTime, event.startTime)
        self.id = event.id
        self.name = event.name
        self.startTime = event.startTime
        self.endTime = resolvedEndTime
        self.projectId = event.projectId
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct TimelineProcessingResult {
    let activityBlocks: [TimelineRenderBlock]
    let eventBlocks: [TimelineRenderBlock]
}

/// TimelineProcessor converts activities into renderable timeline blocks.
///
/// NEW STRATEGY (based on OpenAI analysis):
/// 1. First aggregate activities into cognitive sessions (via TimelineSessionAggregator)
/// 2. Then render sessions (not individual activities) as visual blocks
/// 3. This separates "statistical merge" (30min) from "visual merge" (30s-90s)
@MainActor
class TimelineProcessor {
    // Cache for app icons to avoid repeated lookups
    private var iconCache: [String: NSImage] = [:]
    private var iconDominantColorCache: [String: NSColor] = [:]
    private var blockColorCache: [String: Color] = [:]

    // Constants for Level of Detail (LOD)
    private let MERGE_THRESHOLD_PX: CGFloat = 1.0
    private let MIN_DRAW_WIDTH_PX: CGFloat = 2.0 // Draw at least 2px line
    private let TRACK_HEIGHT: CGFloat = 40.0
    private let BLOCK_PADDING: CGFloat = 4.0

    // Accumulator for merging
    private struct PendingBlock {
        var startX: CGFloat
        var endX: CGFloat
        var appBundleId: String
        var appName: String
        var activityIds: [UUID]
        var startTime: Date
        var endTime: Date
    }

    private struct ComputedActivityBlock: Sendable {
        var startX: CGFloat
        var width: CGFloat
        var appBundleId: String
        var appName: String
        var underlyingActivityIds: [UUID]
        var totalDuration: TimeInterval
        var startTime: Date
        var endTime: Date
    }

    private struct SessionAppSegment: Sendable {
        var appBundleId: String
        var appName: String
        var startTime: Date
        var endTime: Date
        var underlyingActivityIds: [UUID]
    }

    private struct ComputedEventBlock: Sendable {
        var startX: CGFloat
        var width: CGFloat
        var appName: String
        var totalDuration: TimeInterval
        var startTime: Date
        var endTime: Date
        var eventId: UUID
        var projectId: String?
    }

    private struct DetachedComputationResult: Sendable {
        let activityBlocks: [ComputedActivityBlock]
        let eventBlocks: [ComputedEventBlock]
    }

    func processAsync(
        activities: [ActivitySnapshot],
        events: [Event],
        visibleTimeRange: ClosedRange<Date>,
        canvasWidth: CGFloat,
        eventBlockHeight: CGFloat = 24,
        mergeEnabled: Bool = true
    ) async -> TimelineProcessingResult {
        let now = Date()
        let activitySnapshots = activities.map { TimelineActivitySnapshot(from: $0, fallbackEndTime: now) }
        let eventSnapshots = events.map { TimelineEventSnapshot(from: $0, fallbackEndTime: now) }
        let minDrawWidth = MIN_DRAW_WIDTH_PX
        let trackHeight = TRACK_HEIGHT
        let effectiveMergeInterval = Self.adaptiveMergeInterval(
            visibleTimeRange: visibleTimeRange,
            canvasWidth: canvasWidth
        )

        let computed = await Task.detached(priority: .userInitiated) {
            let activityBlocks = Self.computeSessionBlocks(
                activitySnapshots: activitySnapshots,
                visibleTimeRange: visibleTimeRange,
                canvasWidth: canvasWidth,
                minDrawWidth: minDrawWidth,
                mergeEnabled: mergeEnabled,
                mergeInterval: effectiveMergeInterval
            )
            let eventBlocks = Self.computeEventBlocks(
                eventSnapshots: eventSnapshots,
                visibleTimeRange: visibleTimeRange,
                canvasWidth: canvasWidth,
                minDrawWidth: minDrawWidth
            )
            return DetachedComputationResult(activityBlocks: activityBlocks, eventBlocks: eventBlocks)
        }.value

        let hydratedActivityBlocks = computed.activityBlocks.map {
            makeActivityRenderBlock(from: $0, trackHeight: trackHeight)
        }
        let hydratedEventBlocks = computed.eventBlocks.map {
            makeEventRenderBlock(from: $0, blockHeight: eventBlockHeight)
        }

        return TimelineProcessingResult(
            activityBlocks: hydratedActivityBlocks,
            eventBlocks: hydratedEventBlocks
        )
    }
    
    /// NEW: Converts raw activities into cognitive sessions, then renders as blocks.
    /// This is the recommended approach that matches Timing's visual style.
    ///
    /// - Parameters:
    ///   - activities: List of raw activities
    ///   - visibleTimeRange: The time range currently visible on screen
    ///   - canvasWidth: The width of the canvas in pixels
    /// - Returns: A list of `TimelineRenderBlock` ready for drawing
    func processWithSessionAggregation(activities: [ActivitySnapshot], visibleTimeRange: ClosedRange<Date>, canvasWidth: CGFloat) -> [TimelineRenderBlock] {
        let snapshots = activities.map { TimelineActivitySnapshot(from: $0, fallbackEndTime: Date()) }
        let computedBlocks = Self.computeSessionBlocks(
            activitySnapshots: snapshots,
            visibleTimeRange: visibleTimeRange,
            canvasWidth: canvasWidth,
            minDrawWidth: MIN_DRAW_WIDTH_PX,
            mergeEnabled: true,
            mergeInterval: Self.adaptiveMergeInterval(
                visibleTimeRange: visibleTimeRange,
                canvasWidth: canvasWidth
            )
        )
        return computedBlocks.map { makeActivityRenderBlock(from: $0, trackHeight: TRACK_HEIGHT) }
    }

    /// DEPRECATED: Old approach - converts raw activities into renderable blocks
    /// Kept for backward compatibility. Use processWithSessionAggregation() instead.
    /// - Parameters:
    ///   - activities: List of raw activities
    ///   - visibleTimeRange: The time range currently visible on screen (or total range)
    ///   - canvasWidth: The width of the canvas in pixels
    /// - Returns: A list of `TimelineRenderBlock` ready for drawing
    func process(activities: [ActivitySnapshot], visibleTimeRange: ClosedRange<Date>, canvasWidth: CGFloat) -> [TimelineRenderBlock] {
        guard !activities.isEmpty, canvasWidth > 0 else { return [] }
        
        let totalSeconds = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        guard totalSeconds > 0 else { return [] }
        
        let pixelsPerSecond = canvasWidth / CGFloat(totalSeconds)
        let startTime = visibleTimeRange.lowerBound
        
        // 1. Sort activities by start time
        let sortedActivities = activities.sorted { $0.startTime < $1.startTime }
        
        var renderBlocks: [TimelineRenderBlock] = []
        
        // Helper to get X position relative to the start of the visible range
        func getX(_ date: Date) -> CGFloat {
            return CGFloat(date.timeIntervalSince(startTime)) * pixelsPerSecond
        }
        
        var pending: PendingBlock?
        
        for activity in sortedActivities {
            let activityEnd = activity.endTime ?? activity.capturedAt
            
            // Skip activities strictly outside range? 
            // We keep them if they overlap. 
            // Simple check: End < RangeStart OR Start > RangeEnd
            if activityEnd < visibleTimeRange.lowerBound || activity.startTime > visibleTimeRange.upperBound {
                continue
            }
            
            let actStartX = getX(activity.startTime)
            let actEndX = getX(activityEnd)
            
            let actBundleId = activity.appBundleId
            let actName = activity.appName
            let actId = activity.id
            
            if var current = pending {
                let gap = actStartX - current.endX
                
                // Merge Condition: Same App AND Gap is small
                if actBundleId == current.appBundleId && gap <= MERGE_THRESHOLD_PX {
                    // Merge: Extend current block
                    current.endX = max(current.endX, actEndX)
                    current.endTime = max(current.endTime, activityEnd)
                    current.activityIds.append(actId)
                    pending = current // Update pending struct
                } else {
                    // Finalize current
                    if let finalized = createBlock(from: current) {
                        renderBlocks.append(finalized)
                    }
                    // Start new
                    pending = PendingBlock(
                        startX: actStartX,
                        endX: actEndX,
                        appBundleId: actBundleId,
                        appName: actName,
                        activityIds: [actId],
                        startTime: activity.startTime,
                        endTime: activityEnd
                    )
                }
            } else {
                // Start first block
                pending = PendingBlock(
                    startX: actStartX,
                    endX: actEndX,
                    appBundleId: actBundleId,
                    appName: actName,
                    activityIds: [actId],
                    startTime: activity.startTime,
                    endTime: activityEnd
                )
            }
        }
        
        // Finalize last block
        if let current = pending, let finalized = createBlock(from: current) {
            renderBlocks.append(finalized)
        }
        
        return renderBlocks
    }
    
    /// Converts raw activities into aggregated blocks based on time intervals
    func processMerged(activities: [ActivitySnapshot], visibleTimeRange: ClosedRange<Date>, canvasWidth: CGFloat, interval: TimeInterval) -> [TimelineRenderBlock] {
        guard !activities.isEmpty, canvasWidth > 0, interval > 0 else { return [] }
        
        let totalSeconds = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        guard totalSeconds > 0 else { return [] }
        
        let pixelsPerSecond = canvasWidth / CGFloat(totalSeconds)
        let visibleStart = visibleTimeRange.lowerBound
        
        func getX(_ date: Date) -> CGFloat {
            return CGFloat(date.timeIntervalSince(visibleStart)) * pixelsPerSecond
        }
        
        // 1. Align start time to interval
        let startInterval = floor(visibleStart.timeIntervalSince1970 / interval) * interval
        let endInterval = ceil(visibleTimeRange.upperBound.timeIntervalSince1970 / interval) * interval
        
        var renderBlocks: [TimelineRenderBlock] = []
        
        // 2. Iterate buckets
        var currentBucketStart = startInterval
        while currentBucketStart < endInterval {
            let bucketStart = Date(timeIntervalSince1970: currentBucketStart)
            let bucketEnd = Date(timeIntervalSince1970: currentBucketStart + interval)
            
            // 3. Find overlapping activities and sum durations
            var appDurations: [String: TimeInterval] = [:]
            var appNames: [String: String] = [:]
            var appActivityIds: [String: [UUID]] = [:]
            
            for activity in activities {
                let actEnd = activity.endTime ?? activity.capturedAt
                if actEnd <= bucketStart || activity.startTime >= bucketEnd {
                    continue
                }
                
                let overlapStart = max(activity.startTime, bucketStart)
                let overlapEnd = min(actEnd, bucketEnd)
                let duration = overlapEnd.timeIntervalSince(overlapStart)
                
                if duration > 0 {
                    let bundleId = activity.appBundleId
                    appDurations[bundleId, default: 0] += duration
                    appNames[bundleId] = activity.appName // Keep last name
                    appActivityIds[bundleId, default: []].append(activity.id)
                }
            }
            
            // 4. Sort apps by duration
            let sortedApps = appDurations.keys.sorted {
                appDurations[$0]! > appDurations[$1]!
            }
            
            // 5. Create Blocks
            // We stack them starting from bucketStart
            var currentBlockStartTime = bucketStart
            
            for bundleId in sortedApps {
                let duration = appDurations[bundleId]!
                let appName = appNames[bundleId] ?? ""
                let ids = appActivityIds[bundleId] ?? []
                
                let blockEndTime = currentBlockStartTime.addingTimeInterval(duration)
                
                let startX = getX(currentBlockStartTime)
                let endX = getX(blockEndTime)
                let width = max(0, endX - startX)
                
                // Only draw if visible (width > 0.5)
                if width >= 0.5 {
                    // Rect
                    let rect = CGRect(
                        x: startX,
                        y: 0,
                        width: width,
                        height: TRACK_HEIGHT + 8
                    )
                    
                    let color = self.color(for: appName, bundleId: bundleId)
                    let icon = self.icon(for: bundleId)
                    
                    renderBlocks.append(TimelineRenderBlock(
                        rect: rect,
                        color: color,
                        appBundleId: bundleId,
                        appName: appName,
                        icon: icon,
                        underlyingActivityIds: ids,
                        totalDuration: duration,
                        startTime: currentBlockStartTime, // Visual start
                        endTime: blockEndTime // Visual end
                    ))
                }
                
                currentBlockStartTime = blockEndTime
            }
            
            currentBucketStart += interval
        }
        
        return renderBlocks
    }
    
    func processEvents(events: [Event], visibleTimeRange: ClosedRange<Date>, canvasWidth: CGFloat, blockHeight: CGFloat = 24) -> [TimelineRenderBlock] {
        let snapshots = events.map { TimelineEventSnapshot(from: $0, fallbackEndTime: Date()) }
        let computedBlocks = Self.computeEventBlocks(
            eventSnapshots: snapshots,
            visibleTimeRange: visibleTimeRange,
            canvasWidth: canvasWidth,
            minDrawWidth: MIN_DRAW_WIDTH_PX
        )
        return computedBlocks.map { makeEventRenderBlock(from: $0, blockHeight: blockHeight) }
    }
    
    private func createBlock(from pending: PendingBlock) -> TimelineRenderBlock? {
        let rawWidth = pending.endX - pending.startX
        
        // Culling: If the block is microscopically small, ignore it?
        // Let's say < 0.5px is noise.
        if rawWidth < 0.5 { return nil }
        
        // Visual Clamp: Ensure it is at least visible (e.g. 1px or 2px)
        // This makes sure short activities like "Cmd+Tab check" are seen as a thin line.
        let visualWidth = max(rawWidth, MIN_DRAW_WIDTH_PX)
        
        // Layout within the track
        // Full height for activities
        let blockHeight = TRACK_HEIGHT + 8 // 48
        let rect = CGRect(
            x: pending.startX,
            y: 0,
            width: visualWidth,
            height: blockHeight
        )
        
        let color = color(for: pending.appName, bundleId: pending.appBundleId)
        let icon = icon(for: pending.appBundleId)
        
        // Calculate total duration roughly (end - start)
        // For accurate duration of *active* time, we would need to sum up underlying activities.
        // But since we merged gaps < 1px, the visual block duration is continuous.
        let totalDuration = pending.endTime.timeIntervalSince(pending.startTime)
        
        return TimelineRenderBlock(
            rect: rect,
            color: color,
            appBundleId: pending.appBundleId,
            appName: pending.appName,
            icon: icon,
            underlyingActivityIds: pending.activityIds,
            totalDuration: totalDuration,
            startTime: pending.startTime,
            endTime: pending.endTime
        )
    }

    private func makeActivityRenderBlock(from computed: ComputedActivityBlock, trackHeight: CGFloat) -> TimelineRenderBlock {
        let rect = CGRect(
            x: computed.startX,
            y: 0,
            width: computed.width,
            height: trackHeight + 8
        )

        return TimelineRenderBlock(
            rect: rect,
            color: color(for: computed.appName, bundleId: computed.appBundleId),
            appBundleId: computed.appBundleId,
            appName: computed.appName,
            icon: icon(for: computed.appBundleId),
            underlyingActivityIds: computed.underlyingActivityIds,
            totalDuration: computed.totalDuration,
            startTime: computed.startTime,
            endTime: computed.endTime
        )
    }

    private func makeEventRenderBlock(from computed: ComputedEventBlock, blockHeight: CGFloat) -> TimelineRenderBlock {
        let rect = CGRect(
            x: computed.startX,
            y: 0,
            width: computed.width,
            height: blockHeight
        )

        return TimelineRenderBlock(
            rect: rect,
            color: color(for: computed.appName, bundleId: nil),
            appBundleId: "ManualEvent",
            appName: computed.appName,
            icon: nil,
            underlyingActivityIds: [],
            totalDuration: computed.totalDuration,
            startTime: computed.startTime,
            endTime: computed.endTime,
            eventId: computed.eventId,
            projectId: computed.projectId
        )
    }

    nonisolated private static func computeSessionBlocks(
        activitySnapshots: [TimelineActivitySnapshot],
        visibleTimeRange: ClosedRange<Date>,
        canvasWidth: CGFloat,
        minDrawWidth: CGFloat,
        mergeEnabled: Bool,
        mergeInterval: TimeInterval
    ) -> [ComputedActivityBlock] {
        guard !activitySnapshots.isEmpty, canvasWidth > 0 else { return [] }

        let totalSeconds = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        guard totalSeconds > 0 else { return [] }

        let pixelsPerSecond = canvasWidth / CGFloat(totalSeconds)
        let rangeStart = visibleTimeRange.lowerBound
        let aggregator = TimelineSessionAggregator()
        let baseSessions = aggregator.aggregateSessions(from: activitySnapshots, visibleTimeRange: visibleTimeRange)
        let sessions: [TimelineSession]
        if mergeEnabled {
            sessions = mergeSessions(baseSessions, maxGap: mergeInterval)
        } else {
            sessions = baseSessions
        }

        var blocks: [ComputedActivityBlock] = []
        blocks.reserveCapacity(sessions.count * 2)

        for session in sessions {
            let segments = splitIntoAppSegments(
                session,
                secondsPerPixel: Double(totalSeconds) / Double(canvasWidth)
            )
            for segment in segments {
                if segment.endTime <= visibleTimeRange.lowerBound || segment.startTime >= visibleTimeRange.upperBound {
                    continue
                }

                let clippedStart = max(segment.startTime, visibleTimeRange.lowerBound)
                let clippedEnd = min(segment.endTime, visibleTimeRange.upperBound)
                let startX = CGFloat(clippedStart.timeIntervalSince(rangeStart)) * pixelsPerSecond
                let endX = CGFloat(clippedEnd.timeIntervalSince(rangeStart)) * pixelsPerSecond
                let width = endX - startX
                guard width > 0.5 else { continue }

                blocks.append(ComputedActivityBlock(
                    startX: startX,
                    width: max(width, minDrawWidth),
                    appBundleId: segment.appBundleId,
                    appName: segment.appName,
                    underlyingActivityIds: segment.underlyingActivityIds,
                    totalDuration: clippedEnd.timeIntervalSince(clippedStart),
                    startTime: clippedStart,
                    endTime: clippedEnd
                ))
            }
        }

        return blocks
    }

    nonisolated private static func adaptiveMergeInterval(
        visibleTimeRange: ClosedRange<Date>,
        canvasWidth: CGFloat
    ) -> TimeInterval {
        let visibleDuration = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        guard visibleDuration > 0, canvasWidth > 0 else { return 60 }

        // Keep short visual gaps connected at current zoom, while avoiding over-merge.
        let secondsPerPixel = visibleDuration / Double(canvasWidth)
        let targetGapPixels = 12.0
        let adaptiveGap = secondsPerPixel * targetGapPixels

        let minGap: TimeInterval = 45
        let maxGap: TimeInterval = 20 * 60
        return min(max(adaptiveGap, minGap), maxGap)
    }

    nonisolated private static func splitIntoAppSegments(
        _ session: TimelineSession,
        secondsPerPixel: TimeInterval
    ) -> [SessionAppSegment] {
        let sameAppGapTolerance: TimeInterval = 2
        let sortedActivities = session.activities
            .filter { !$0.isNoise && $0.endTime > $0.startTime }
            .sorted { lhs, rhs in
                if lhs.startTime == rhs.startTime {
                    return lhs.endTime < rhs.endTime
                }
                return lhs.startTime < rhs.startTime
            }

        guard !sortedActivities.isEmpty else {
            return [SessionAppSegment(
                appBundleId: session.primaryAppBundleId,
                appName: session.primaryAppName,
                startTime: session.startTime,
                endTime: session.endTime,
                underlyingActivityIds: session.underlyingActivityIds
            )]
        }

        var segments: [SessionAppSegment] = []
        segments.reserveCapacity(sortedActivities.count)

        for activity in sortedActivities {
            if var last = segments.last,
               last.appBundleId == activity.appBundleId,
               activity.startTime.timeIntervalSince(last.endTime) <= sameAppGapTolerance {
                last.endTime = max(last.endTime, activity.endTime)
                last.underlyingActivityIds.append(activity.activityId)
                segments[segments.count - 1] = last
            } else {
                segments.append(SessionAppSegment(
                    appBundleId: activity.appBundleId,
                    appName: activity.appName,
                    startTime: activity.startTime,
                    endTime: activity.endTime,
                    underlyingActivityIds: [activity.activityId]
                ))
            }
        }

        let simplified = simplifySegments(segments, secondsPerPixel: secondsPerPixel)
        return coalesceSameAppSegments(simplified, gapTolerance: sameAppGapTolerance)
    }

    nonisolated private static func simplifySegments(
        _ segments: [SessionAppSegment],
        secondsPerPixel: TimeInterval
    ) -> [SessionAppSegment] {
        guard segments.count > 1 else { return segments }

        let interruptionThreshold = min(max(secondsPerPixel * 5, 18), 180)
        let minorSegmentThreshold = min(max(secondsPerPixel * 9, 45), 8 * 60)
        let bridgeGapTolerance = min(max(secondsPerPixel * 2, 2), 75)

        var simplified = segments

        // Step 1: bridge short interruptions when both sides are the same app.
        var index = 0
        while index + 2 < simplified.count {
            let previous = simplified[index]
            let middle = simplified[index + 1]
            let next = simplified[index + 2]
            let middleDuration = middle.endTime.timeIntervalSince(middle.startTime)
            let gapToMiddle = middle.startTime.timeIntervalSince(previous.endTime)
            let gapToNext = next.startTime.timeIntervalSince(middle.endTime)

            if previous.appBundleId == next.appBundleId,
               middleDuration <= interruptionThreshold,
               gapToMiddle <= bridgeGapTolerance,
               gapToNext <= bridgeGapTolerance {
                var merged = previous
                merged.endTime = max(next.endTime, middle.endTime)
                merged.underlyingActivityIds.append(contentsOf: middle.underlyingActivityIds)
                merged.underlyingActivityIds.append(contentsOf: next.underlyingActivityIds)
                simplified[index] = merged
                simplified.remove(at: index + 2)
                simplified.remove(at: index + 1)
                if index > 0 {
                    index -= 1
                }
                continue
            }

            index += 1
        }

        // Step 2: absorb very short fragments into neighboring dominant segments.
        var fragmentIndex = 0
        while fragmentIndex < simplified.count {
            let segment = simplified[fragmentIndex]
            let duration = segment.endTime.timeIntervalSince(segment.startTime)

            guard duration <= minorSegmentThreshold, simplified.count > 1 else {
                fragmentIndex += 1
                continue
            }

            let leftIndex = fragmentIndex > 0 ? fragmentIndex - 1 : nil
            let rightIndex = fragmentIndex + 1 < simplified.count ? fragmentIndex + 1 : nil

            if let leftIndex, let rightIndex,
               simplified[leftIndex].appBundleId == simplified[rightIndex].appBundleId {
                var merged = simplified[leftIndex]
                let right = simplified[rightIndex]
                merged.endTime = max(right.endTime, segment.endTime)
                merged.underlyingActivityIds.append(contentsOf: segment.underlyingActivityIds)
                merged.underlyingActivityIds.append(contentsOf: right.underlyingActivityIds)
                simplified[leftIndex] = merged
                simplified.remove(at: rightIndex)
                simplified.remove(at: fragmentIndex)
                fragmentIndex = max(0, leftIndex - 1)
                continue
            }

            var targetIndex: Int?
            if let leftIndex, let rightIndex {
                let leftDuration = simplified[leftIndex].endTime.timeIntervalSince(simplified[leftIndex].startTime)
                let rightDuration = simplified[rightIndex].endTime.timeIntervalSince(simplified[rightIndex].startTime)
                targetIndex = leftDuration >= rightDuration ? leftIndex : rightIndex
            } else if let leftIndex {
                targetIndex = leftIndex
            } else if let rightIndex {
                targetIndex = rightIndex
            }

            guard let targetIndex else {
                fragmentIndex += 1
                continue
            }

            if targetIndex < fragmentIndex {
                var target = simplified[targetIndex]
                target.endTime = max(target.endTime, segment.endTime)
                target.underlyingActivityIds.append(contentsOf: segment.underlyingActivityIds)
                simplified[targetIndex] = target
                simplified.remove(at: fragmentIndex)
                fragmentIndex = max(0, targetIndex - 1)
            } else {
                var target = simplified[targetIndex]
                target.startTime = min(target.startTime, segment.startTime)
                target.underlyingActivityIds.insert(contentsOf: segment.underlyingActivityIds, at: 0)
                simplified[targetIndex] = target
                simplified.remove(at: fragmentIndex)
                fragmentIndex = max(0, fragmentIndex - 1)
            }
        }

        return simplified
    }

    nonisolated private static func coalesceSameAppSegments(
        _ segments: [SessionAppSegment],
        gapTolerance: TimeInterval
    ) -> [SessionAppSegment] {
        guard !segments.isEmpty else { return [] }

        var merged: [SessionAppSegment] = [segments[0]]
        for segment in segments.dropFirst() {
            let gap = segment.startTime.timeIntervalSince(merged[merged.count - 1].endTime)
            if gap <= gapTolerance, merged[merged.count - 1].appBundleId == segment.appBundleId {
                var last = merged[merged.count - 1]
                last.endTime = max(last.endTime, segment.endTime)
                last.underlyingActivityIds.append(contentsOf: segment.underlyingActivityIds)
                merged[merged.count - 1] = last
            } else {
                merged.append(segment)
            }
        }
        return merged
    }

    nonisolated private static func mergeSessions(_ sessions: [TimelineSession], maxGap: TimeInterval) -> [TimelineSession] {
        guard sessions.count > 1, maxGap > 0 else { return sessions }

        var merged: [TimelineSession] = []
        var current = sessions[0]

        for next in sessions.dropFirst() {
            let gap = next.startTime.timeIntervalSince(current.endTime)
            if gap <= maxGap {
                current.startTime = min(current.startTime, next.startTime)
                current.endTime = max(current.endTime, next.endTime)
                current.underlyingActivityIds.append(contentsOf: next.underlyingActivityIds)
                current.activities.append(contentsOf: next.activities)
                current.activities.sort { $0.startTime < $1.startTime }
                current.containsNoise = current.containsNoise || next.containsNoise
                current.confidence = min(current.confidence, next.confidence)
                if current.primaryProjectId == nil {
                    current.primaryProjectId = next.primaryProjectId
                }
            } else {
                merged.append(current)
                current = next
            }
        }

        merged.append(current)
        return merged
    }

    nonisolated private static func computeEventBlocks(
        eventSnapshots: [TimelineEventSnapshot],
        visibleTimeRange: ClosedRange<Date>,
        canvasWidth: CGFloat,
        minDrawWidth: CGFloat
    ) -> [ComputedEventBlock] {
        guard !eventSnapshots.isEmpty, canvasWidth > 0 else { return [] }

        let totalSeconds = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        guard totalSeconds > 0 else { return [] }

        let pixelsPerSecond = canvasWidth / CGFloat(totalSeconds)
        let rangeStart = visibleTimeRange.lowerBound

        return eventSnapshots.compactMap { event in
            if event.endTime <= visibleTimeRange.lowerBound || event.startTime >= visibleTimeRange.upperBound {
                return nil
            }

            let clippedStart = max(event.startTime, visibleTimeRange.lowerBound)
            let clippedEnd = min(event.endTime, visibleTimeRange.upperBound)
            let startX = CGFloat(clippedStart.timeIntervalSince(rangeStart)) * pixelsPerSecond
            let endX = CGFloat(clippedEnd.timeIntervalSince(rangeStart)) * pixelsPerSecond
            let width = endX - startX
            guard width > 0 else { return nil }

            return ComputedEventBlock(
                startX: startX,
                width: max(width, minDrawWidth),
                appName: event.name,
                totalDuration: event.duration,
                startTime: event.startTime,
                endTime: event.endTime,
                eventId: event.id,
                projectId: event.projectId
            )
        }
    }
    
    // MARK: - Helpers
    
    private func color(for string: String, bundleId: String?) -> Color {
        let cacheKey = "\(bundleId ?? "event")::\(string)"
        if let cached = blockColorCache[cacheKey] {
            return cached
        }

        let hash = stableHash(cacheKey)
        let resolved: Color

        if let bundleId,
           !bundleId.isEmpty,
           let iconDominant = dominantColor(forBundleId: bundleId) {
            resolved = Color(nsColor: normalizeBlockColor(base: iconDominant, hash: hash))
        } else {
            resolved = Color(nsColor: fallbackThemeColor(hash: hash))
        }

        blockColorCache[cacheKey] = resolved
        return resolved
    }

    private func dominantColor(forBundleId bundleId: String) -> NSColor? {
        if let cached = iconDominantColorCache[bundleId] {
            return cached
        }

        guard let icon = icon(for: bundleId),
              let extracted = extractDominantColor(from: icon)?.usingColorSpace(.deviceRGB) else {
            return nil
        }

        iconDominantColorCache[bundleId] = extracted
        return extracted
    }

    private func extractDominantColor(from image: NSImage) -> NSColor? {
        let sampleSize = CGSize(width: 32, height: 32)
        let drawRect = CGRect(origin: .zero, size: sampleSize)

        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
              let context = CGContext(
                data: nil,
                width: Int(sampleSize.width),
                height: Int(sampleSize.height),
                bitsPerComponent: 8,
                bytesPerRow: Int(sampleSize.width) * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let data = context.data else {
            return nil
        }

        context.interpolationQuality = .medium
        context.clear(drawRect)
        context.draw(cgImage, in: drawRect)

        let pixelCount = Int(sampleSize.width * sampleSize.height)
        let bytes = data.bindMemory(to: UInt8.self, capacity: pixelCount * 4)

        let hueBins = 24
        let satBins = 4
        let bucketCount = hueBins * satBins
        var scores = Array(repeating: CGFloat.zero, count: bucketCount)
        var redTotals = Array(repeating: CGFloat.zero, count: bucketCount)
        var greenTotals = Array(repeating: CGFloat.zero, count: bucketCount)
        var blueTotals = Array(repeating: CGFloat.zero, count: bucketCount)

        var fallbackWeight: CGFloat = 0
        var fallbackR: CGFloat = 0
        var fallbackG: CGFloat = 0
        var fallbackB: CGFloat = 0

        for index in 0..<pixelCount {
            let offset = index * 4
            let r = CGFloat(bytes[offset]) / 255
            let g = CGFloat(bytes[offset + 1]) / 255
            let b = CGFloat(bytes[offset + 2]) / 255
            let a = CGFloat(bytes[offset + 3]) / 255

            guard a > 0.18 else { continue }

            let rgbColor = NSColor(deviceRed: r, green: g, blue: b, alpha: a)
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            let fallbackPixelWeight = a * max(0.25, brightness)
            fallbackWeight += fallbackPixelWeight
            fallbackR += r * fallbackPixelWeight
            fallbackG += g * fallbackPixelWeight
            fallbackB += b * fallbackPixelWeight

            guard brightness > 0.12 else { continue }
            guard !(saturation < 0.10 && (brightness < 0.25 || brightness > 0.95)) else { continue }

            let hueIndex = min(hueBins - 1, Int(hue * CGFloat(hueBins)))
            let satIndex = min(satBins - 1, Int(saturation * CGFloat(satBins)))
            let bucket = hueIndex * satBins + satIndex

            let chromaWeight = a * (0.30 + saturation * 0.70) * (brightness > 0.94 ? 0.7 : 1.0)
            scores[bucket] += chromaWeight
            redTotals[bucket] += r * chromaWeight
            greenTotals[bucket] += g * chromaWeight
            blueTotals[bucket] += b * chromaWeight
        }

        if let bestBucket = scores.indices.max(by: { scores[$0] < scores[$1] }),
           scores[bestBucket] > 0.001 {
            let weight = scores[bestBucket]
            return NSColor(
                deviceRed: redTotals[bestBucket] / weight,
                green: greenTotals[bestBucket] / weight,
                blue: blueTotals[bestBucket] / weight,
                alpha: 1
            )
        }

        guard fallbackWeight > 0.001 else { return nil }
        return NSColor(
            deviceRed: fallbackR / fallbackWeight,
            green: fallbackG / fallbackWeight,
            blue: fallbackB / fallbackWeight,
            alpha: 1
        )
    }

    private func normalizeBlockColor(base: NSColor, hash: Int) -> NSColor {
        let seed = themeColorSeed()
        let rgbBase = base.usingColorSpace(.deviceRGB) ?? base

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgbBase.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Use stepped hue buckets so apps with similarly blue icons still separate clearly.
        let hueShift = hueSpreadOffset(hash: hash)
        let tunedHue = wrappedHue(hue + hueShift)
        let tunedSaturation = clamped(
            max(0.52, saturation * 1.28),
            min: seed.isDark ? 0.56 : 0.50,
            max: seed.isDark ? 0.96 : 0.90
        )
        let tunedBrightness = clamped(
            brightness + (seed.isDark ? 0.08 : 0.04),
            min: seed.isDark ? 0.66 : 0.56,
            max: seed.isDark ? 0.96 : 0.88
        )

        let vivid = NSColor(calibratedHue: tunedHue, saturation: tunedSaturation, brightness: tunedBrightness, alpha: 1)
        let contrastAdjusted = ensureContrast(vivid, against: seed.background, isDark: seed.isDark)
        let blendAmount: CGFloat = seed.isDark ? 0.02 : 0.06
        let themed = contrastAdjusted.blended(withFraction: blendAmount, of: seed.background) ?? contrastAdjusted
        let alphaOut: CGFloat = seed.isDark ? 0.76 : 0.70

        return themed.withAlphaComponent(alphaOut)
    }

    private func fallbackThemeColor(hash: Int) -> NSColor {
        let seed = themeColorSeed()
        let hueShift = hueSpreadOffset(hash: hash) * 1.05
        let saturationShift = (CGFloat((hash / 1_000) % 1_000) / 1_000.0 - 0.5) * 0.20
        let brightnessShift = (CGFloat((hash / 1_000_000) % 1_000) / 1_000.0 - 0.5) * 0.12

        let hue = wrappedHue(seed.hue + hueShift)
        let saturation = clamped(seed.saturation + saturationShift, min: 0.50, max: 0.82)
        let brightness = clamped(
            seed.brightness + brightnessShift,
            min: seed.isDark ? 0.64 : 0.54,
            max: seed.isDark ? 0.88 : 0.78
        )

        let base = NSColor(calibratedHue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        let contrastAdjusted = ensureContrast(base, against: seed.background, isDark: seed.isDark)
        let blendAmount: CGFloat = seed.isDark ? 0.04 : 0.10
        let themed = contrastAdjusted.blended(withFraction: blendAmount, of: seed.background) ?? contrastAdjusted
        let alpha: CGFloat = seed.isDark ? 0.74 : 0.68

        return themed.withAlphaComponent(alpha)
    }
    
    private func stableHash(_ string: String) -> Int {
        var hash = 5381
        for char in string.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(char.value)
        }
        return abs(hash)
    }

    private struct ThemeColorSeed {
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
        let background: NSColor
        let isDark: Bool
    }

    private func themeColorSeed() -> ThemeColorSeed {
        let background = NSColor.controlBackgroundColor.usingColorSpace(.deviceRGB) ?? NSColor.windowBackgroundColor
        let accent = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? NSColor.systemBlue

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        accent.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let isDark = perceivedLuminance(of: background) < 0.50
        let baseSaturation = clamped(max(0.30, saturation * 0.66), min: 0.38, max: 0.62)
        let baseBrightness: CGFloat = isDark ? 0.70 : 0.58

        return ThemeColorSeed(
            hue: hue,
            saturation: baseSaturation,
            brightness: baseBrightness,
            background: background,
            isDark: isDark
        )
    }

    private func perceivedLuminance(of color: NSColor) -> CGFloat {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }

    private func clamped(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        Swift.max(lowerBound, Swift.min(value, upperBound))
    }

    private func wrappedHue(_ value: CGFloat) -> CGFloat {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
    }

    private func hueSpreadOffset(hash: Int) -> CGFloat {
        let steps: [CGFloat] = [-0.26, -0.18, -0.12, -0.06, 0, 0.06, 0.12, 0.18, 0.26]
        let step = steps[hash % steps.count]
        let jitter = (CGFloat((hash / 97) % 100) / 100.0 - 0.5) * 0.03
        return step + jitter
    }

    private func ensureContrast(_ color: NSColor, against background: NSColor, isDark: Bool) -> NSColor {
        let bgLuminance = perceivedLuminance(of: background)
        let colorLuminance = perceivedLuminance(of: color)
        guard abs(colorLuminance - bgLuminance) < 0.26 else { return color }

        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let adjustedBrightness: CGFloat
        if isDark {
            adjustedBrightness = clamped(brightness + 0.18, min: 0.64, max: 0.96)
        } else {
            adjustedBrightness = clamped(brightness - 0.18, min: 0.30, max: 0.70)
        }

        return NSColor(calibratedHue: hue, saturation: saturation, brightness: adjustedBrightness, alpha: alpha)
    }
    
    private func icon(for bundleId: String) -> NSImage? {
        if let cached = iconCache[bundleId] {
            return cached
        }
        
        // Try to find the app
        if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let image = NSWorkspace.shared.icon(forFile: path.path)
            iconCache[bundleId] = image
            return image
        }
        
        // Fallback: Check if we can get icon by bundle ID directly (sometimes works better)
        // But NSWorkspace.icon(forFile:) is standard. 
        
        return nil
    }
}
