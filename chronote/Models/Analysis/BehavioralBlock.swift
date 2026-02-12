import Foundation
import SwiftData

/// Types of behavioral patterns identified in time tracking
enum BlockType: String, Codable {
    case deep          // Long duration, low context switches - focused work
    case fragmented    // High frequency switches - interrupted work
    case passive       // Browsing/reading - information consumption
    case communication // Email, Slack, Messages - collaboration
    case idle          // No activity or system idle
}

/// Represents a higher-level semantic unit of behavior
/// Groups sessions into meaningful behavioral patterns
@Model
final class BehavioralBlock {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var blockType: BlockType
    var dominantActivity: String?
    var dominantAppBundleId: String?
    var focusScore: Double // 0-1, measures quality of focus
    var contextSwitchCount: Int
    
    // Store session IDs
    var sessionIds: [UUID]
    
    // Computed property for duration
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    // Human-readable duration
    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Time range formatted
    var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        blockType: BlockType,
        dominantActivity: String? = nil,
        dominantAppBundleId: String? = nil,
        focusScore: Double = 0.5,
        contextSwitchCount: Int = 0,
        sessionIds: [UUID] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.blockType = blockType
        self.dominantActivity = dominantActivity
        self.dominantAppBundleId = dominantAppBundleId
        self.focusScore = focusScore
        self.contextSwitchCount = contextSwitchCount
        self.sessionIds = sessionIds
    }
}
