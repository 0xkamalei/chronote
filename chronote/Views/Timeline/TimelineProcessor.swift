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
        eventBlockHeight: CGFloat = 24
    ) async -> TimelineProcessingResult {
        let now = Date()
        let activitySnapshots = activities.map { TimelineActivitySnapshot(from: $0, fallbackEndTime: now) }
        let eventSnapshots = events.map { TimelineEventSnapshot(from: $0, fallbackEndTime: now) }
        let minDrawWidth = MIN_DRAW_WIDTH_PX
        let trackHeight = TRACK_HEIGHT

        let computed = await Task.detached(priority: .userInitiated) {
            let activityBlocks = Self.computeSessionBlocks(
                activitySnapshots: activitySnapshots,
                visibleTimeRange: visibleTimeRange,
                canvasWidth: canvasWidth,
                minDrawWidth: minDrawWidth
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
            minDrawWidth: MIN_DRAW_WIDTH_PX
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
                    
                    let color = self.color(for: appName)
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
        
        let color = color(for: pending.appName)
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
            color: color(for: computed.appName),
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
            color: color(for: computed.appName),
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
        minDrawWidth: CGFloat
    ) -> [ComputedActivityBlock] {
        guard !activitySnapshots.isEmpty, canvasWidth > 0 else { return [] }

        let totalSeconds = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        guard totalSeconds > 0 else { return [] }

        let pixelsPerSecond = canvasWidth / CGFloat(totalSeconds)
        let rangeStart = visibleTimeRange.lowerBound
        let aggregator = TimelineSessionAggregator()
        let sessions = aggregator.aggregateSessions(from: activitySnapshots, visibleTimeRange: visibleTimeRange)

        return sessions.compactMap { session in
            if session.endTime <= visibleTimeRange.lowerBound || session.startTime >= visibleTimeRange.upperBound {
                return nil
            }

            let clippedStart = max(session.startTime, visibleTimeRange.lowerBound)
            let clippedEnd = min(session.endTime, visibleTimeRange.upperBound)
            let startX = CGFloat(clippedStart.timeIntervalSince(rangeStart)) * pixelsPerSecond
            let endX = CGFloat(clippedEnd.timeIntervalSince(rangeStart)) * pixelsPerSecond
            let width = endX - startX
            guard width > 0.5 else { return nil }

            return ComputedActivityBlock(
                startX: startX,
                width: max(width, minDrawWidth),
                appBundleId: session.primaryAppBundleId,
                appName: session.primaryAppName,
                underlyingActivityIds: session.underlyingActivityIds,
                totalDuration: session.duration,
                startTime: session.startTime,
                endTime: session.endTime
            )
        }
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
    
    private func color(for string: String) -> Color {
        // Generate a consistent color using a stable hash
        let hash = stableHash(string)
        // Hue: 0-1
        let hue = Double(hash % 100) / 100.0
        // Saturation: 0.6 - 0.9 (Vibrant)
        let saturation = 0.6 + (Double((hash / 100) % 4) / 10.0)
        // Brightness: 0.8 - 1.0
        let brightness = 0.8 + (Double((hash / 400) % 3) / 10.0)
        
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    private func stableHash(_ string: String) -> Int {
        var hash = 5381
        for char in string.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(char.value)
        }
        return abs(hash)
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
