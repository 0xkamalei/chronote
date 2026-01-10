import Foundation
import SwiftUI
import AppKit

/// A purely visual representation of a block on the timeline.
/// This struct is optimized for high-performance rendering in a Canvas.
struct TimelineRenderBlock: Identifiable {
    let id: UUID = UUID()
    
    /// The geometric frame in the canvas coordinate system
    let rect: CGRect
    
    /// The color to fill the block
    let color: Color
    
    /// The app bundle ID (used for deduplication or specific logic)
    let appBundleId: String
    
    /// The app name for display
    let appName: String
    
    /// The app icon, resolved during processing (optional)
    let icon: NSImage?
    
    /// The original activity IDs that were merged into this block
    /// Used for hit-testing and showing details on hover
    let underlyingActivityIds: [UUID]
    
    /// Total duration of activities in this block (pre-calculated)
    let totalDuration: TimeInterval
    
    /// Time range for display
    let startTime: Date
    let endTime: Date
    
    /// Optional Event ID for manual events
    var eventId: UUID? = nil
}
