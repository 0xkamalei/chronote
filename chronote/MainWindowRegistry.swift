import AppKit
import SwiftUI

@MainActor
enum MainWindowRegistry {
    private static weak var mainWindow: NSWindow?
    private static let windowIdentifier = NSUserInterfaceItemIdentifier("chronote.mainWindow")

    static func bind(_ window: NSWindow?) {
        guard let window else { return }
        mainWindow = window
        if window.identifier != windowIdentifier {
            window.identifier = windowIdentifier
        }
    }

    static func presentMainWindow() {
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        if let fallback = NSApp.windows.first(where: { $0.identifier == windowIdentifier }) {
            bind(fallback)
            fallback.makeKeyAndOrderFront(nil)
        }
    }
}

struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in
            MainWindowRegistry.bind(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            MainWindowRegistry.bind(nsView?.window)
        }
    }
}
