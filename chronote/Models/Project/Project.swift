import Foundation
import SwiftData
import SwiftUI

@Model
final class Project: Equatable, Codable {
    @Attribute(.unique) var id: String
    var name: String
    var colorData: Data?
    var sortOrder: Int
    var productivityRating: Double = 0.5
    var isArchived: Bool = false
    
 

    var color: Color {
        get {
            guard let colorData = colorData else { return .blue }
            #if canImport(UIKit)
                if let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
                    return Color(uiColor)
                }
            #elseif canImport(AppKit)
                if let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                    return Color(nsColor)
                }
            #endif
            return .blue
        }
        set {
            #if canImport(UIKit)
                colorData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(newValue), requiringSecureCoding: false)
            #elseif canImport(AppKit)
                colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(newValue), requiringSecureCoding: false)
            #endif
        }
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, name, colorData, sortOrder, productivityRating, isArchived
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(colorData, forKey: .colorData)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(productivityRating, forKey: .productivityRating)
        try container.encode(isArchived, forKey: .isArchived)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorData = try container.decodeIfPresent(Data.self, forKey: .colorData)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        productivityRating = try container.decodeIfPresent(Double.self, forKey: .productivityRating) ?? 0.5
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    init(id: String = UUID().uuidString, name: String = "", color: Color = .blue, sortOrder: Int = 0, productivityRating: Double = 0.5, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.color = color
        self.productivityRating = productivityRating
        self.isArchived = isArchived
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}

