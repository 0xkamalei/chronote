import SwiftUI
import AppKit

struct TimelineInteractionOverlay: NSViewRepresentable {
    @Binding var visibleTimeRange: ClosedRange<Date>
    var totalTimeRange: ClosedRange<Date>
    var totalWidth: CGFloat
    
    // Hit-Testing Callback
    var onHover: ((CGFloat) -> Void)?
    var onHoverEnd: (() -> Void)?
    
    func makeNSView(context: Context) -> NSView {
        let view = InteractionView()
        view.onScroll = { event in
            context.coordinator.handleScroll(event)
        }
        view.onMagnify = { event in
            context.coordinator.handleMagnify(event)
        }
        
        // Pass Zoom-to-Range event back to Coordinator
        view.onZoomToRange = { x1, x2 in
            context.coordinator.handleZoomToRange(x1: x1, x2: x2)
        }
        
        // Pass Hover event
        view.onHover = { point in
            onHover?(point.x)
        }
        view.onHoverEnd = {
            onHoverEnd?()
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: TimelineInteractionOverlay
        
        // Drag Selection State
        var dragStartPoint: CGPoint?
        var dragSelectionLayer: CALayer?
        
        init(_ parent: TimelineInteractionOverlay) {
            self.parent = parent
        }
        
        // MARK: - Gestures
        
        func handleZoomToRange(x1: CGFloat, x2: CGFloat) {
            let currentRange = parent.visibleTimeRange
            let duration = currentRange.upperBound.timeIntervalSince(currentRange.lowerBound)
            
            guard parent.totalWidth > 0 else { return }
            let pixelsPerSecond = parent.totalWidth / duration
            
            // Map X coordinates to Time
            // X=0 is currentRange.lowerBound
            let t1 = currentRange.lowerBound.addingTimeInterval(Double(x1) / pixelsPerSecond)
            let t2 = currentRange.lowerBound.addingTimeInterval(Double(x2) / pixelsPerSecond)
            
            // Validate and Update
            // Ensure min duration
            if t2.timeIntervalSince(t1) > 60 {
                 DispatchQueue.main.async {
                     self.parent.visibleTimeRange = t1...t2
                 }
            }
        }
        
        func handleScroll(_ event: NSEvent) {
            let isCommandPressed = event.modifierFlags.contains(.command)
            
            if isCommandPressed {
                let delta = event.deltaY
                if delta == 0 { return }
                let zoomFactor = 1.0 - (delta * 0.05)
                applyZoom(factor: zoomFactor)
            } else {
                let deltaX = event.deltaX
                if deltaX == 0 { return }
                applyPan(deltaX: deltaX)
            }
        }
        
        func handleMagnify(_ event: NSEvent) {
            let zoomFactor = 1.0 - event.magnification
            applyZoom(factor: zoomFactor)
        }
        
        // MARK: - Logic
        
        private func applyZoom(factor: CGFloat) {
            let currentRange = parent.visibleTimeRange
            let totalRange = parent.totalTimeRange
            let duration = currentRange.upperBound.timeIntervalSince(currentRange.lowerBound)
            let totalDuration = totalRange.upperBound.timeIntervalSince(totalRange.lowerBound)
            
            // Calculate new duration
            var newDuration = duration * factor
            
            // Constrain: Min 1 minute, Max totalDuration
            newDuration = max(60, min(newDuration, totalDuration))
            
            // Zoom from center
            let center = currentRange.lowerBound.addingTimeInterval(duration / 2)
            var newStart = center.addingTimeInterval(-newDuration / 2)
            var newEnd = center.addingTimeInterval(newDuration / 2)
            
            // Clamp to bounds (Shift if needed)
            if newStart < totalRange.lowerBound {
                newStart = totalRange.lowerBound
                newEnd = newStart.addingTimeInterval(newDuration)
            } else if newEnd > totalRange.upperBound {
                newEnd = totalRange.upperBound
                newStart = newEnd.addingTimeInterval(-newDuration)
            }
            
            DispatchQueue.main.async {
                self.parent.visibleTimeRange = newStart...newEnd
            }
        }
        
        private func applyPan(deltaX: CGFloat) {
            let currentRange = parent.visibleTimeRange
            let totalRange = parent.totalTimeRange
            let duration = currentRange.upperBound.timeIntervalSince(currentRange.lowerBound)
            
            guard parent.totalWidth > 0 else { return }
            let pixelsPerSecond = parent.totalWidth / duration
            
            let secondsShift = Double(deltaX) / pixelsPerSecond
            
            var newStart = currentRange.lowerBound.addingTimeInterval(-secondsShift)
            var newEnd = currentRange.upperBound.addingTimeInterval(-secondsShift)
            
            // Clamp
            if newStart < totalRange.lowerBound {
                newStart = totalRange.lowerBound
                newEnd = newStart.addingTimeInterval(duration)
            } else if newEnd > totalRange.upperBound {
                newEnd = totalRange.upperBound
                newStart = newEnd.addingTimeInterval(-duration)
            }
            
            DispatchQueue.main.async {
                self.parent.visibleTimeRange = newStart...newEnd
            }
        }
    }
    
    class InteractionView: NSView {
        var onScroll: ((NSEvent) -> Void)?
        var onMagnify: ((NSEvent) -> Void)?
        
        // Hover
        var onHover: ((CGPoint) -> Void)?
        var onHoverEnd: (() -> Void)?
        
        // Drag Selection UI
        private var dragStartPoint: CGPoint?
        private var selectionLayer: CALayer?
        
        override var acceptsFirstResponder: Bool { true }
        
        // Enable Mouse Tracking
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach { removeTrackingArea($0) }
            
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
            let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(trackingArea)
        }
        
        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onHover?(point)
        }
        
        override func mouseExited(with event: NSEvent) {
            onHoverEnd?()
        }
        
        override func scrollWheel(with event: NSEvent) {
            onScroll?(event)
        }
        
        override func magnify(with event: NSEvent) {
            onMagnify?(event)
        }
        
        override func mouseDown(with event: NSEvent) {
            dragStartPoint = convert(event.locationInWindow, from: nil)
            
            // Init selection layer
            if selectionLayer == nil {
                let layer = CALayer()
                layer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
                layer.borderColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
                layer.borderWidth = 1
                self.layer?.addSublayer(layer)
                self.selectionLayer = layer
            }
            selectionLayer?.frame = .zero
            selectionLayer?.isHidden = false
        }
        
        override func mouseDragged(with event: NSEvent) {
            guard let start = dragStartPoint else { return }
            let current = convert(event.locationInWindow, from: nil)
            
            let rect = CGRect(x: min(start.x, current.x),
                              y: 0, // Full height
                              width: abs(current.x - start.x),
                              height: bounds.height)
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            selectionLayer?.frame = rect
            CATransaction.commit()
        }
        
        override func mouseUp(with event: NSEvent) {
            guard let start = dragStartPoint else { return }
            let end = convert(event.locationInWindow, from: nil)
            
            selectionLayer?.isHidden = true
            dragStartPoint = nil
            
            let distance = abs(end.x - start.x)
            if distance > 10 {
                let x1 = min(start.x, end.x)
                let x2 = max(start.x, end.x)
                onZoomToRange?(x1, x2)
            }
        }
        
        // We need a way to communicate "Zoom to X1...X2" back to SwiftUI.
        var onZoomToRange: ((CGFloat, CGFloat) -> Void)?
    }
}
