import AppKit
import ApplicationServices
import Foundation

/// Captures context information from applications, including window titles and browser-specific data
@MainActor
class ContextCapturer {
    // MARK: - Browser Context Data Model

    struct BrowserContext: Codable {
        let url: String?
        let title: String?
        let domain: String?
        let isPrivate: Bool
        let tabCount: Int?

        init(url: String? = nil, title: String? = nil, domain: String? = nil, isPrivate: Bool = false, tabCount: Int? = nil) {
            self.url = url
            self.title = title
            self.domain = domain
            self.isPrivate = isPrivate
            self.tabCount = tabCount
        }
    }

    // MARK: - Browser Bundle IDs

    private enum BrowserBundleID {
        static let safari = "com.apple.Safari"
        static let chrome = "com.google.Chrome"
        static let firefox = "org.mozilla.firefox"
        static let edge = "com.microsoft.edgemac"
        static let brave = "com.brave.Browser"
        static let opera = "com.operasoftware.Opera"
    }

    // MARK: - Privacy Settings

    private var captureWindowTitles: Bool = true
    private var captureBrowserData: Bool = true
    private var respectPrivateBrowsing: Bool = true
    private var sensitiveDataFilters: [String] = [
        "password", "login", "signin", "auth", "private", "incognito",
        "banking", "payment", "credit", "ssn", "social security",
    ]

    // MARK: - Public Interface

    /// Capture window title for the given application
    func captureWindowTitle(for app: NSRunningApplication) -> String? {
        guard captureWindowTitles else { return nil }

        // Get the frontmost window title using Accessibility API
        guard let windowTitle = getAccessibilityWindowTitle(for: app) else {
            return nil
        }

        // Apply privacy filtering
        return filterSensitiveData(windowTitle)
    }

    /// Capture browser-specific context for supported browsers
    func captureBrowserContext(for app: NSRunningApplication) -> BrowserContext? {
        guard captureBrowserData,
              let bundleId = app.bundleIdentifier
        else {
            return nil
        }

        switch bundleId {
        case BrowserBundleID.safari:
            return captureSafariContext(app: app)
        case BrowserBundleID.chrome:
            return captureChromeContext(app: app)
        case BrowserBundleID.firefox:
            return captureFirefoxContext(app: app)
        case BrowserBundleID.edge:
            return captureEdgeContext(app: app)
        case BrowserBundleID.brave:
            return captureBraveContext(app: app)
        case BrowserBundleID.opera:
            return captureOperaContext(app: app)
        default:
            return nil
        }
    }

    /// Check if accessibility permissions are granted
    func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request accessibility permissions
    func requestAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Configuration

    func setCaptureWindowTitles(_ enabled: Bool) {
        captureWindowTitles = enabled
    }

    func setCaptureBrowserData(_ enabled: Bool) {
        captureBrowserData = enabled
    }

    func setRespectPrivateBrowsing(_ enabled: Bool) {
        respectPrivateBrowsing = enabled
    }

    func addSensitiveDataFilter(_ filter: String) {
        sensitiveDataFilters.append(filter.lowercased())
    }

    // MARK: - Private Implementation

    private func getAccessibilityWindowTitle(for app: NSRunningApplication) -> String? {
        guard isAccessibilityEnabled() else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get the frontmost window
        var frontmostWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &frontmostWindow)

        guard result == .success,
              let window = frontmostWindow
        else {
            return nil
        }

        // Get the window title
        var windowTitle: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &windowTitle)

        guard titleResult == .success,
              let title = windowTitle as? String
        else {
            return nil
        }

        return title
    }

    // MARK: - Safari Context Capture

    private func captureSafariContext(app _: NSRunningApplication) -> BrowserContext? {
        // Safari uses AppleScript for URL extraction
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                set currentTab to current tab of front window
                set tabURL to URL of currentTab
                set tabTitle to name of currentTab
                set isPrivate to (private browsing of front window)
                set tabCount to count of tabs of front window
                return tabURL & "|" & tabTitle & "|" & (isPrivate as string) & "|" & (tabCount as string)
            end if
        end tell
        """

        guard let result = executeAppleScript(script) else {
            return nil
        }

        let components = result.components(separatedBy: "|")
        guard components.count >= 4 else {
            return nil
        }

        let url = components[0].isEmpty ? nil : components[0]
        let title = components[1].isEmpty ? nil : components[1]
        let isPrivate = components[2] == "true"
        let tabCount = Int(components[3])

        // Respect private browsing
        if respectPrivateBrowsing, isPrivate {
            return BrowserContext(isPrivate: true, tabCount: tabCount)
        }

        let domain = url.flatMap { URL(string: $0)?.host }
        let filteredURL = url.flatMap { filterSensitiveData($0) }
        let filteredTitle = title.flatMap { filterSensitiveData($0) }

        return BrowserContext(
            url: filteredURL,
            title: filteredTitle,
            domain: domain,
            isPrivate: isPrivate,
            tabCount: tabCount
        )
    }

    // MARK: - Chrome Context Capture

    private func captureChromeContext(app _: NSRunningApplication) -> BrowserContext? {
        let script = """
        tell application "Google Chrome"
            if (count of windows) > 0 then
                set currentTab to active tab of front window
                set tabURL to URL of currentTab
                set tabTitle to title of currentTab
                set isIncognito to (mode of front window is "incognito")
                set tabCount to count of tabs of front window
                return tabURL & "|" & tabTitle & "|" & (isIncognito as string) & "|" & (tabCount as string)
            end if
        end tell
        """

        guard let result = executeAppleScript(script) else {
            return nil
        }

        let components = result.components(separatedBy: "|")
        guard components.count >= 4 else {
            return nil
        }

        let url = components[0].isEmpty ? nil : components[0]
        let title = components[1].isEmpty ? nil : components[1]
        let isPrivate = components[2] == "true"
        let tabCount = Int(components[3])

        // Respect incognito mode
        if respectPrivateBrowsing, isPrivate {
            return BrowserContext(isPrivate: true, tabCount: tabCount)
        }

        let domain = url.flatMap { URL(string: $0)?.host }
        let filteredURL = url.flatMap { filterSensitiveData($0) }
        let filteredTitle = title.flatMap { filterSensitiveData($0) }

        return BrowserContext(
            url: filteredURL,
            title: filteredTitle,
            domain: domain,
            isPrivate: isPrivate,
            tabCount: tabCount
        )
    }

    // MARK: - Firefox Context Capture

    private func captureFirefoxContext(app: NSRunningApplication) -> BrowserContext? {
        // Firefox doesn't have reliable AppleScript support
        // Fall back to window title parsing
        guard let windowTitle = getAccessibilityWindowTitle(for: app) else {
            return nil
        }

        // Firefox window titles typically follow: "Page Title - Mozilla Firefox"
        let isPrivate = windowTitle.contains("Private Browsing")

        if respectPrivateBrowsing, isPrivate {
            return BrowserContext(isPrivate: true)
        }

        // Extract title by removing " - Mozilla Firefox" suffix
        let title = windowTitle.replacingOccurrences(of: " - Mozilla Firefox", with: "")
            .replacingOccurrences(of: " (Private Browsing)", with: "")

        let filteredTitle = filterSensitiveData(title)

        return BrowserContext(
            title: (filteredTitle?.isEmpty == false) ? filteredTitle : nil,
            isPrivate: isPrivate
        )
    }

    // MARK: - Edge Context Capture

    private func captureEdgeContext(app: NSRunningApplication) -> BrowserContext? {
        // Edge has limited AppleScript support, use window title parsing
        guard let windowTitle = getAccessibilityWindowTitle(for: app) else {
            return nil
        }

        let isPrivate = windowTitle.contains("InPrivate")

        if respectPrivateBrowsing, isPrivate {
            return BrowserContext(isPrivate: true)
        }

        // Extract title by removing " - Microsoft Edge" suffix
        let title = windowTitle.replacingOccurrences(of: " - Microsoft Edge", with: "")
            .replacingOccurrences(of: " (InPrivate)", with: "")

        let filteredTitle = filterSensitiveData(title)

        return BrowserContext(
            title: (filteredTitle?.isEmpty == false) ? filteredTitle : nil,
            isPrivate: isPrivate
        )
    }

    // MARK: - Brave Context Capture

    private func captureBraveContext(app: NSRunningApplication) -> BrowserContext? {
        // Brave uses similar AppleScript to Chrome
        let script = """
        tell application "Brave Browser"
            if (count of windows) > 0 then
                set currentTab to active tab of front window
                set tabURL to URL of currentTab
                set tabTitle to title of currentTab
                set isPrivate to (mode of front window is "incognito")
                set tabCount to count of tabs of front window
                return tabURL & "|" & tabTitle & "|" & (isPrivate as string) & "|" & (tabCount as string)
            end if
        end tell
        """

        guard let result = executeAppleScript(script) else {
            // Fall back to window title parsing
            return captureBraveFromWindowTitle(app: app)
        }

        let components = result.components(separatedBy: "|")
        guard components.count >= 4 else {
            return nil
        }

        let url = components[0].isEmpty ? nil : components[0]
        let title = components[1].isEmpty ? nil : components[1]
        let isPrivate = components[2] == "true"
        let tabCount = Int(components[3])

        if respectPrivateBrowsing, isPrivate {
            return BrowserContext(isPrivate: true, tabCount: tabCount)
        }

        let domain = url.flatMap { URL(string: $0)?.host }
        let filteredURL = url.flatMap { filterSensitiveData($0) }
        let filteredTitle = title.flatMap { filterSensitiveData($0) }

        return BrowserContext(
            url: filteredURL,
            title: filteredTitle,
            domain: domain,
            isPrivate: isPrivate,
            tabCount: tabCount
        )
    }

    private func captureBraveFromWindowTitle(app: NSRunningApplication) -> BrowserContext? {
        guard let windowTitle = getAccessibilityWindowTitle(for: app) else {
            return nil
        }

        let isPrivate = windowTitle.contains("Private")

        if respectPrivateBrowsing, isPrivate {
            return BrowserContext(isPrivate: true)
        }

        let title = windowTitle.replacingOccurrences(of: " - Brave", with: "")
            .replacingOccurrences(of: " (Private)", with: "")

        let filteredTitle = filterSensitiveData(title)

        return BrowserContext(
            title: (filteredTitle?.isEmpty == false) ? filteredTitle : nil,
            isPrivate: isPrivate
        )
    }

    // MARK: - Opera Context Capture

    private func captureOperaContext(app: NSRunningApplication) -> BrowserContext? {
        // Opera has limited AppleScript support, use window title parsing
        guard let windowTitle = getAccessibilityWindowTitle(for: app) else {
            return nil
        }

        let isPrivate = windowTitle.contains("Private")

        if respectPrivateBrowsing, isPrivate {
            return BrowserContext(isPrivate: true)
        }

        let title = windowTitle.replacingOccurrences(of: " - Opera", with: "")
            .replacingOccurrences(of: " (Private)", with: "")

        let filteredTitle = filterSensitiveData(title)

        return BrowserContext(
            title: (filteredTitle?.isEmpty == false) ? filteredTitle : nil,
            isPrivate: isPrivate
        )
    }

    // MARK: - Utility Methods

    private func executeAppleScript(_ script: String) -> String? {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?

        guard let result = appleScript?.executeAndReturnError(&error),
              error == nil
        else {
            return nil
        }

        return result.stringValue
    }

    private func filterSensitiveData(_ text: String) -> String? {
        let lowercaseText = text.lowercased()

        // Check if text contains sensitive keywords
        for filter in sensitiveDataFilters {
            if lowercaseText.contains(filter) {
                return nil // Filter out sensitive data
            }
        }

        // Additional URL-specific filtering
        if text.hasPrefix("http") {
            // Filter out URLs with sensitive paths
            let sensitiveURLPatterns = [
                "/login", "/signin", "/auth", "/password", "/payment",
                "/checkout", "/billing", "/account", "/profile",
            ]

            for pattern in sensitiveURLPatterns {
                if lowercaseText.contains(pattern) {
                    // Return domain only for sensitive URLs
                    if let url = URL(string: text) {
                        return url.host
                    }
                    return nil
                }
            }
        }

        return text
    }
}

// MARK: - Browser Detection Extension

extension ContextCapturer {
    /// Check if the given application is a supported browser
    func isSupportedBrowser(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else {
            return false
        }

        return [
            BrowserBundleID.safari,
            BrowserBundleID.chrome,
            BrowserBundleID.firefox,
            BrowserBundleID.edge,
            BrowserBundleID.brave,
            BrowserBundleID.opera,
        ].contains(bundleId)
    }

    /// Get browser name from bundle ID
    func getBrowserName(from bundleId: String) -> String? {
        switch bundleId {
        case BrowserBundleID.safari:
            return "Safari"
        case BrowserBundleID.chrome:
            return "Chrome"
        case BrowserBundleID.firefox:
            return "Firefox"
        case BrowserBundleID.edge:
            return "Edge"
        case BrowserBundleID.brave:
            return "Brave"
        case BrowserBundleID.opera:
            return "Opera"
        default:
            return nil
        }
    }
}
