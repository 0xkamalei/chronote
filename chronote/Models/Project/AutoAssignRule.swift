import Foundation
import SwiftData

enum AutoAssignRuleType: String, Codable, CaseIterable {
    case appBundleId
    case titleKeyword
    
    var displayName: String {
        switch self {
        case .appBundleId: return "App"
        case .titleKeyword: return "Title Keyword"
        }
    }
}

@Model
final class AutoAssignRule: Identifiable, Codable {
    var id: String
    var projectId: String
    var ruleTypeRaw: String
    var value: String
    
    var ruleType: AutoAssignRuleType {
        get { AutoAssignRuleType(rawValue: ruleTypeRaw) ?? .appBundleId }
        set { ruleTypeRaw = newValue.rawValue }
    }
    
    init(id: String = UUID().uuidString, projectId: String = "", ruleType: AutoAssignRuleType, value: String) {
        self.id = id
        self.projectId = projectId
        self.ruleTypeRaw = ruleType.rawValue
        self.value = value
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, projectId, ruleTypeRaw, value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(ruleTypeRaw, forKey: .ruleTypeRaw)
        try container.encode(value, forKey: .value)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        projectId = try container.decode(String.self, forKey: .projectId)
        ruleTypeRaw = try container.decode(String.self, forKey: .ruleTypeRaw)
        value = try container.decode(String.self, forKey: .value)
    }
}
