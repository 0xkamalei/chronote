import SwiftUI

class Project: ObservableObject, Identifiable, Hashable {
    let id: String
    @Published var name: String
    @Published var color: Color
    @Published var children: [Project] = []
    @Published var parentID: String?
    @Published var sortOrder: Int

    init(id: String, name: String, color: Color, parentID: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.color = color
        self.parentID = parentID
        self.sortOrder = sortOrder
    }
    
    // Implementing Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}
