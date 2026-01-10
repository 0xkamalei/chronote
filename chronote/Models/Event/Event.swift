import Foundation
import SwiftData

@Model
final class Event {
    @Attribute(.unique) var id: UUID
    var name: String
    var startTime: Date
    var endTime: Date?
    var projectId: String?
    
    init(name: String, startTime: Date = Date(), endTime: Date? = nil, projectId: String? = nil) {
        self.id = UUID()
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.projectId = projectId
    }
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}
