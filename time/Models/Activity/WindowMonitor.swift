import AppKit
import ApplicationServices
import Foundation

struct ActivityContext: Equatable {
    let title: String?
    let filePath: String?
    let webUrl: String?
    
    var isEmpty: Bool {
        return title == nil && filePath == nil && webUrl == nil
    }
}

class WindowMonitor {
    static let shared = WindowMonitor()
    
    private init() {}
    
    /// Retrieves the full context (title, path, url) of the focused window
    func getContext(for processIdentifier: pid_t) -> ActivityContext {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard result == .success, let window = focusedWindow else {
            return ActivityContext(title: nil, filePath: nil, webUrl: nil)
        }
        
        let axWindow = window as! AXUIElement
        
        // 1. Get Title
        var title: AnyObject?
        var titleString: String?
        if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &title) == .success {
            titleString = title as? String
            if titleString?.isEmpty == true { titleString = nil }
        }
        
        // 2. Get Document (File Path)
        var document: AnyObject?
        var filePath: String?
        if AXUIElementCopyAttributeValue(axWindow, kAXDocumentAttribute as CFString, &document) == .success,
           let urlString = document as? String,
           let url = URL(string: urlString) {
            filePath = url.path
        }
        
        // 3. Get URL (Browser specific - simplified for now)
        // This is complex via AX. For now, we will leave it as nil or implement a basic check later.
        // Implementing full browser URL fetching via AX requires traversing the UI tree which is expensive for polling.
        // We can add specific browser handlers later.
        let webUrl: String? = nil 
        
        return ActivityContext(title: titleString, filePath: filePath, webUrl: webUrl)
    }
    
    /// Retrieves the title of the focused window for a given process ID
    /// - Parameter processIdentifier: The PID of the application
    /// - Returns: The window title if available, nil otherwise
    func getActiveWindowTitle(for processIdentifier: pid_t) -> String? {
        return getContext(for: processIdentifier).title
    }
    
    /// Checks if the application has accessibility permissions
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

