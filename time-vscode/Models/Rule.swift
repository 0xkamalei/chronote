
import SwiftUI

struct Rule: Identifiable, Hashable {
    let id = UUID()
    var type: RuleType = .titleOrPath
    var condition: RuleCondition = .contains
    var value: String = ""
}

enum RuleType: String, CaseIterable, Identifiable {
    case keywords = "Keywords"
    case titleOrPath = "Title or Path"
    case domain = "Domain (e.g. xyz.com)"
    case fullWebsite = "Full Website URL"
    case filePath = "File Path"
    case title = "Title"
    case path = "Path (File or URL)"
    case applicationName = "Application Name"
    case device = "Device"
    case startTime = "Start Time"
    case dayOfWeek = "Day of Week"
    
    var id: String { self.rawValue }
}

enum RuleCondition: String, CaseIterable, Identifiable {
    case contains = "contains"
    case doesNotContain = "does not contain"
    case `is` = "is"
    case isNot = "is not"
    case startsWith = "starts with"
    case endsWith = "ends with"
    
    var id: String { self.rawValue }
}
