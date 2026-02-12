import Foundation
import SwiftData

/// Daily aggregation of time by behavioral structure
/// Provides the "structure view" of how a day was spent
@Model
final class TimeStructure {
    var id: UUID
    var date: Date
    
    // Duration in seconds for each block type
    var deepDuration: TimeInterval
    var fragmentedDuration: TimeInterval
    var passiveDuration: TimeInterval
    var communicationDuration: TimeInterval
    var idleDuration: TimeInterval
    
    // Store block IDs
    var blockIds: [UUID]
    
    // Computed properties
    var totalTracked: TimeInterval {
        deepDuration + fragmentedDuration + passiveDuration + communicationDuration + idleDuration
    }
    
    var deepPercentage: Double {
        guard totalTracked > 0 else { return 0 }
        return (deepDuration / totalTracked) * 100
    }
    
    var fragmentedPercentage: Double {
        guard totalTracked > 0 else { return 0 }
        return (fragmentedDuration / totalTracked) * 100
    }
    
    var passivePercentage: Double {
        guard totalTracked > 0 else { return 0 }
        return (passiveDuration / totalTracked) * 100
    }
    
    var communicationPercentage: Double {
        guard totalTracked > 0 else { return 0 }
        return (communicationDuration / totalTracked) * 100
    }
    
    var idlePercentage: Double {
        guard totalTracked > 0 else { return 0 }
        return (idleDuration / totalTracked) * 100
    }
    
    // Formatted durations
    var totalTrackedFormatted: String {
        formatDuration(totalTracked)
    }
    
    var deepDurationFormatted: String {
        formatDuration(deepDuration)
    }
    
    var fragmentedDurationFormatted: String {
        formatDuration(fragmentedDuration)
    }
    
    var passiveDurationFormatted: String {
        formatDuration(passiveDuration)
    }
    
    var communicationDurationFormatted: String {
        formatDuration(communicationDuration)
    }
    
    var idleDurationFormatted: String {
        formatDuration(idleDuration)
    }
    
    init(
        id: UUID = UUID(),
        date: Date,
        deepDuration: TimeInterval = 0,
        fragmentedDuration: TimeInterval = 0,
        passiveDuration: TimeInterval = 0,
        communicationDuration: TimeInterval = 0,
        idleDuration: TimeInterval = 0,
        blockIds: [UUID] = []
    ) {
        self.id = id
        self.date = date
        self.deepDuration = deepDuration
        self.fragmentedDuration = fragmentedDuration
        self.passiveDuration = passiveDuration
        self.communicationDuration = communicationDuration
        self.idleDuration = idleDuration
        self.blockIds = blockIds
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
