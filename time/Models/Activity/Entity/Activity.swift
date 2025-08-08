import SwiftUI
import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var appName: String
    var appBundleId: String
    var appTitle: String?
    var duration: TimeInterval
    var startTime: Date
    var endTime: Date? // Optional for ongoing activities (nil = active)
    var icon: String
    
    var durationString: String {
        let minutes = Int(calculatedDuration / 60)
        if minutes < 1 {
            return "<1m"
        }
        return "\(minutes)m"
    }
    
    var minutes: Int {
        return Int(calculatedDuration / 60)
    }
    
    var calculatedDuration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            // For ongoing activities, calculate duration from start to now
            return Date().timeIntervalSince(startTime)
        }
    }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    init(appName: String, appBundleId: String, appTitle: String? = nil, duration: TimeInterval, startTime: Date, endTime: Date? = nil, icon: String) {
        self.id = UUID()
        self.appName = appName
        self.appBundleId = appBundleId
        self.appTitle = appTitle
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.icon = icon
    }
}