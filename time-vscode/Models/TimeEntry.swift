import SwiftUI
import Foundation

struct TimeEntry: Identifiable, Codable {
    let id: String
    let projectId: String?
    let title: String
    let notes: String?
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    
    init(id: String = UUID().uuidString, projectId: String? = nil, title: String, notes: String? = nil, startTime: Date, endTime: Date) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.notes = notes
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
    }
}