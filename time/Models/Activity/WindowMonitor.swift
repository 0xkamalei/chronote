import AppKit
import ApplicationServices
import Foundation
import os.log

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
    
    private let logger = Logger(subsystem: "com.time-vscode.WindowMonitor", category: "WindowMonitor")
    
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
        
        // 3. Get URL (Browser specific)
        var webUrl: String?
        
        if let app = NSRunningApplication(processIdentifier: processIdentifier),
           let bundleId = app.bundleIdentifier {
            
            // Only attempt for known browsers to avoid overhead
            if isBrowser(bundleId) {
                webUrl = getBrowserUrl(for: bundleId)
            }
        }
        
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
    
    // MARK: - Private Helper Methods
    
    private func isBrowser(_ bundleId: String) -> Bool {
        let browsers = [
            "company.thebrowser.Browser", // Arc
            "com.google.Chrome",
            "com.apple.Safari",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "org.mozilla.firefox" // Firefox (requires specific handling, but listed for completeness)
        ]
        return browsers.contains(bundleId)
    }
    
    private func getBrowserUrl(for bundleId: String) -> String? {
        var source: String?
        
        switch bundleId {
        case "company.thebrowser.Browser":
            // Arc specific: try window 1 which often maps better than front window in some contexts
            source = """
            tell application id "\(bundleId)"
                get URL of active tab of window 1
            end tell
            """
        case "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser":
            // Chromium based
            // Note: Arc uses "Arc" as application name in AppleScript usually, but let's try generic approach or name based.
            // "tell application id \"...\"" is safer.
            source = """
            tell application id "\(bundleId)"
                get URL of active tab of front window
            end tell
            """
        case "com.apple.Safari":
            source = """
            tell application id "\(bundleId)"
                get URL of front document
            end tell
            """
        default:
            return nil
        }
        
        guard let scriptSource = source else { return nil }
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let result = script.executeAndReturnError(&error)
            if let error = error {
                if let code = error[NSAppleScript.errorNumber] as? Int, code == -1743 {
                     logger.error("Permission denied: Please allow this app to control browsers in System Settings > Privacy & Security > Automation")
                } else {
                     logger.error("AppleScript error for \(bundleId): \(error)")
                }
                return nil
            }
            return result.stringValue
        }
        
        return nil
    }
}

