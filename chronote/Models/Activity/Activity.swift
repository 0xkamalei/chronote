import Foundation
import SwiftData
import SwiftUI

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var appName: String
    var appBundleId: String
    var appTitle: String? // Window title
    var filePath: String? // Full file path (for editors/Finder)
    var webUrl: String?   // Full URL (for browsers)
    var domain: String?   // Domain extracted from URL
    var icon: String? // Icon reference
    var projectId: String? // Linked Project ID (Auto-assigned)
    var duration: TimeInterval
    var startTime: Date
    var endTime: Date? // Optional for ongoing activities

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
            return Date().timeIntervalSince(startTime)
        }
    }

    var isActive: Bool {
        return endTime == nil
    }

    // MARK: - Initialization

    init(appName: String, appBundleId: String, appTitle: String? = nil, filePath: String? = nil, webUrl: String? = nil, domain: String? = nil, duration: TimeInterval, startTime: Date, endTime: Date? = nil, icon: String? = nil) {
        id = UUID()
        self.appName = appName
        self.appBundleId = appBundleId
        self.appTitle = appTitle
        self.filePath = filePath
        self.webUrl = webUrl
        self.domain = domain
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.icon = icon
    }

    // Convenience initializer
    convenience init(id: String, appName: String, bundleID: String, startTime: Date, endTime: Date) {
        let duration = endTime.timeIntervalSince(startTime)
        self.init(
            appName: appName,
            appBundleId: bundleID,
            duration: duration,
            startTime: startTime,
            endTime: endTime
        )
        self.id = UUID(uuidString: id) ?? UUID()
    }
}

