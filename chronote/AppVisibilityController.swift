import AppKit

@MainActor
enum AppVisibilityController {
    static func apply(showInDock: Bool) {
        let targetPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != targetPolicy else { return }
        NSApp.setActivationPolicy(targetPolicy)
    }

    static func activateApp() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }
}
