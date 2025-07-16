
import SwiftUI
import AppKit

struct ZoomModifier: ViewModifier {
    @Binding var scale: CGFloat
    @State private var initialScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .background(ZoomableView(scale: $scale))
    }
}

private struct ZoomableView: NSViewRepresentable {
    @Binding var scale: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        let recognizer = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnification))
        view.addGestureRecognizer(recognizer)
        
        context.coordinator.view = view
        
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: ZoomableView
        var view: NSView? {
            didSet {
                // Add a scroll wheel event monitor
                NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    self?.handleScroll(event: event) ?? event
                }
            }
        }

        init(_ parent: ZoomableView) {
            self.parent = parent
        }

        @objc func handleMagnification(recognizer: NSMagnificationGestureRecognizer) {
            // Handle standard pinch-to-zoom gestures
            let newScale = max(0.5, min(3.0, recognizer.magnification + parent.scale))
            parent.scale = newScale
        }
        
        func handleScroll(event: NSEvent) -> NSEvent? {
            guard let view = self.view, let _ = view.window, view.isMouseInView else { return event }
            
            // Check if the command key is pressed
            if event.modifierFlags.contains(.command) {
                let deltaY = event.scrollingDeltaY
                let zoomFactor = deltaY * 0.02 // Adjust sensitivity
                
                // Update the scale, clamping between min and max values
                let newScale = max(0.5, min(5.0, parent.scale - zoomFactor))
                parent.scale = newScale
                
                // Return nil to consume the event and prevent scrolling
                return nil
            }
            
            // Return the event to allow normal scrolling
            return event
        }
    }
}

extension View {
    func onZoom(scale: Binding<CGFloat>) -> some View {
        self.modifier(ZoomModifier(scale: scale))
    }
}

// Helper to check if the mouse is inside the view's bounds
extension NSView {
    var isMouseInView: Bool {
        guard let window = self.window else { return false }
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let locationInView = self.convert(mouseLocation, from: nil)
        return self.bounds.contains(locationInView)
    }
}
