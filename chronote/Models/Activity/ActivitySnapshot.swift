import Foundation

struct ActivitySnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let appName: String
    let appBundleId: String
    let appTitle: String?
    let filePath: String?
    let webUrl: String?
    let domain: String?
    let icon: String?
    let projectId: String?
    let startTime: Date
    let endTime: Date?
    let capturedAt: Date

    init(
        id: UUID,
        appName: String,
        appBundleId: String,
        appTitle: String?,
        filePath: String?,
        webUrl: String?,
        domain: String?,
        icon: String?,
        projectId: String?,
        startTime: Date,
        endTime: Date?,
        capturedAt: Date
    ) {
        self.id = id
        self.appName = appName
        self.appBundleId = appBundleId
        self.appTitle = appTitle
        self.filePath = filePath
        self.webUrl = webUrl
        self.domain = domain
        self.icon = icon
        self.projectId = projectId
        self.startTime = startTime
        self.endTime = endTime
        self.capturedAt = capturedAt
    }

    init(from activity: Activity, capturedAt: Date) {
        self.init(
            id: activity.id,
            appName: activity.appName,
            appBundleId: activity.appBundleId,
            appTitle: activity.appTitle,
            filePath: activity.filePath,
            webUrl: activity.webUrl,
            domain: activity.domain,
            icon: activity.icon,
            projectId: activity.projectId,
            startTime: activity.startTime,
            endTime: activity.endTime,
            capturedAt: capturedAt
        )
    }

    var resolvedEndTime: Date {
        max(endTime ?? capturedAt, startTime)
    }

    var calculatedDuration: TimeInterval {
        resolvedEndTime.timeIntervalSince(startTime)
    }

    var isActive: Bool {
        endTime == nil
    }
}
