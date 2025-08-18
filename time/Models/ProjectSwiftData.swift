import SwiftUI
import SwiftData
import Foundation

@Model
final class ProjectSwiftData {
    @Attribute(.unique) var id: String
    var name: String
    var parentID: String?
    var sortOrder: Int
    var isExpanded: Bool
    
    init(id: String = UUID().uuidString, name: String = "", parentID: String? = nil, sortOrder: Int = 0, isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.isExpanded = isExpanded
    }
}