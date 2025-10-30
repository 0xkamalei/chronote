import SwiftUI
import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var appName: String
    var appBundleId: String
    var appTitle: String?
    var duration: TimeInterval
    var startTime: Date
    var endTime: Date? // Optional for ongoing activities (nil = active)
    var icon: String
    
    // Enhanced context data fields
    var windowTitle: String? = nil
    var url: String? = nil // For browser activities
    var documentPath: String? = nil // For document-based apps
    var contextData: Data? = nil // JSON for additional context
    var isIdleTime: Bool = false // Marks activities that occurred during idle periods
    
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
    
    // MARK: - Context Data Helpers
    
    /// Get the best available title for display (window title, app title, or app name)
    var bestDisplayTitle: String {
        if let windowTitle = windowTitle, !windowTitle.isEmpty {
            return windowTitle
        }
        if let appTitle = appTitle, !appTitle.isEmpty {
            return appTitle
        }
        return appName
    }
    
    /// Check if this activity has browser context (URL)
    var isBrowserActivity: Bool {
        return url != nil && !url!.isEmpty
    }
    
    /// Check if this activity has document context
    var isDocumentActivity: Bool {
        return documentPath != nil && !documentPath!.isEmpty
    }
    
    /// Get domain from URL if available
    var urlDomain: String? {
        guard let urlString = url, let url = URL(string: urlString) else {
            return nil
        }
        return url.host
    }
    
    /// Get filename from document path if available
    var documentFilename: String? {
        guard let path = documentPath else {
            return nil
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    /// Validate context data fields
    func validateContextData() throws {
        // Validate window title length
        if let windowTitle = windowTitle, windowTitle.count > 500 {
            throw ActivityValidationError.windowTitleTooLong
        }
        
        // Validate URL format
        if let urlString = url, !urlString.isEmpty {
            guard URL(string: urlString) != nil else {
                throw ActivityValidationError.invalidURL
            }
            guard urlString.count <= 2000 else {
                throw ActivityValidationError.urlTooLong
            }
        }
        
        // Validate document path
        if let path = documentPath, !path.isEmpty {
            guard path.count <= 1000 else {
                throw ActivityValidationError.documentPathTooLong
            }
        }
        
        // Validate context data size
        if let data = contextData {
            guard data.count <= 10000 else { // 10KB limit
                throw ActivityValidationError.contextDataTooLarge
            }
        }
    }
    
    /// Set context data from a dictionary
    func setContextData<T: Codable>(_ data: T) throws {
        let encoder = JSONEncoder()
        self.contextData = try encoder.encode(data)
    }
    
    /// Get context data as a specific type
    func getContextData<T: Codable>(as type: T.Type) throws -> T? {
        guard let data = contextData else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    // MARK: - Initialization
    
    init(appName: String, appBundleId: String, appTitle: String? = nil, duration: TimeInterval, startTime: Date, endTime: Date? = nil, icon: String, windowTitle: String? = nil, url: String? = nil, documentPath: String? = nil, contextData: Data? = nil, isIdleTime: Bool = false) {
        self.id = UUID()
        self.appName = appName
        self.appBundleId = appBundleId
        self.appTitle = appTitle
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.icon = icon
        self.windowTitle = windowTitle
        self.url = url
        self.documentPath = documentPath
        self.contextData = contextData
        self.isIdleTime = isIdleTime
    }
    
    // Convenience initializer for creating activities with ID and bundle ID
    convenience init(id: String, appName: String, bundleID: String, startTime: Date, endTime: Date, windowTitle: String? = nil, url: String? = nil, documentPath: String? = nil, isIdleTime: Bool = false) {
        let duration = endTime.timeIntervalSince(startTime)
        self.init(
            appName: appName,
            appBundleId: bundleID,
            duration: duration,
            startTime: startTime,
            endTime: endTime,
            icon: "", // Default empty icon
            windowTitle: windowTitle,
            url: url,
            documentPath: documentPath,
            isIdleTime: isIdleTime
        )
        // Override the UUID with the provided string ID
        self.id = UUID(uuidString: id) ?? UUID()
    }
}

// MARK: - Validation Errors

enum ActivityValidationError: LocalizedError {
    case windowTitleTooLong
    case invalidURL
    case urlTooLong
    case documentPathTooLong
    case contextDataTooLarge
    
    var errorDescription: String? {
        switch self {
        case .windowTitleTooLong:
            return "Window title exceeds maximum length of 500 characters"
        case .invalidURL:
            return "Invalid URL format"
        case .urlTooLong:
            return "URL exceeds maximum length of 2000 characters"
        case .documentPathTooLong:
            return "Document path exceeds maximum length of 1000 characters"
        case .contextDataTooLarge:
            return "Context data exceeds maximum size of 10KB"
        }
    }
}
