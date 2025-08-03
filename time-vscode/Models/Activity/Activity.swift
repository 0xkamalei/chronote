import SwiftUI
import Foundation

struct Activity: Identifiable, Equatable {
    let id = UUID()
    let appName: String
    let appBundleId: String
    let appTitle: String?
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let icon: String
    
    static func == (lhs: Activity, rhs: Activity) -> Bool {
        return lhs.id == rhs.id
    }
    
    var durationString: String {
        let minutes = Int(duration / 60)
        if minutes < 1 {
            return "<1m"
        }
        return "\(minutes)m"
    }
    
    var minutes: Int {
        return Int(duration / 60)
    }
    
    init(appName: String, appBundleId: String, appTitle: String? = nil, duration: TimeInterval, startTime: Date, endTime: Date, icon: String) {
        self.appName = appName
        self.appBundleId = appBundleId
        self.appTitle = appTitle
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.icon = icon
    }
}