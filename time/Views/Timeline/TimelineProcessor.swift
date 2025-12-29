import Foundation
import SwiftUI
import AppKit

class TimelineProcessor {
    // Cache for app icons to avoid repeated lookups
    private var iconCache: [String: NSImage] = [:]
    
    // Constants for Level of Detail (LOD)
    private let MERGE_THRESHOLD_PX: CGFloat = 1.0
    private let MIN_DRAW_WIDTH_PX: CGFloat = 1.0 // Draw at least 1px line
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
    
    /// Converts raw activities into renderable blocks
    /// - Parameters:
    ///   - activities: List of raw activities
    ///   - visibleTimeRange: The time range currently visible on screen (or total range)
    ///   - canvasWidth: The width of the canvas in pixels
    /// - Returns: A list of `TimelineRenderBlock` ready for drawing
    func process(activities: [Activity], visibleTimeRange: ClosedRange<Date>, canvasWidth: CGFloat) -> [TimelineRenderBlock] {
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
            let activityEnd = activity.endTime ?? Date()
            
            // Skip activities strictly outside range? 
            // We keep them if they overlap. 
            // Simple check: End < RangeStart OR Start > RangeEnd
            if activityEnd < visibleTimeRange.lowerBound || activity.startTime > visibleTimeRange.upperBound {
                continue
            }
            
            let actStartX = getX(activity.startTime)
            let actEndX = getX(activityEnd)
            // Ensure width is non-negative
            let actWidth = max(0, actEndX - actStartX)
            
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
    
    private func createBlock(from pending: PendingBlock) -> TimelineRenderBlock? {
        let rawWidth = pending.endX - pending.startX
        
        // Culling: If the block is microscopically small, ignore it?
        // Let's say < 0.5px is noise.
        if rawWidth < 0.5 { return nil }
        
        // Visual Clamp: Ensure it is at least visible (e.g. 1px or 2px)
        // This makes sure short activities like "Cmd+Tab check" are seen as a thin line.
        let visualWidth = max(rawWidth, MIN_DRAW_WIDTH_PX)
        
        // Layout within the track
        let blockHeight = TRACK_HEIGHT - (BLOCK_PADDING * 2)
        let rect = CGRect(
            x: pending.startX,
            y: BLOCK_PADDING,
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
    
    // MARK: - Helpers
    
    private func color(for string: String) -> Color {
        // Generate a consistent color from string hash
        // Use a simple algorithm to spread colors
        let hash = abs(string.hashValue)
        // Hue: 0-1
        let hue = Double(hash % 100) / 100.0
        // Saturation: 0.6 - 0.9 (Vibrant)
        let saturation = 0.6 + (Double((hash / 100) % 4) / 10.0)
        // Brightness: 0.8 - 1.0
        let brightness = 0.8 + (Double((hash / 400) % 3) / 10.0)
        
        return Color(hue: hue, saturation: saturation, brightness: brightness)
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
