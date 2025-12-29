import SwiftUI
import AppKit

struct TimelineInteractionOverlay: NSViewRepresentable {
    @Binding var visibleTimeRange: ClosedRange<Date>
    var totalTimeRange: ClosedRange<Date>
    var totalWidth: CGFloat
    
    // Hit-Testing Callback
    var onHover: ((CGPoint) -> Void)?
    var onHoverEnd: (() -> Void)?
    var onClick: ((CGPoint) -> Void)?
    var onDoubleClick: ((CGPoint) -> Void)?
    
    // Drag Selection Callback (start, end, y)
    var onDragEnd: ((CGFloat, CGFloat, CGFloat) -> Void)?
    
    func makeNSView(context: Context) -> NSView {
        let view = InteractionView()
        view.onScroll = { event in
            context.coordinator.handleScroll(event)
        }
        view.onMagnify = { event in
            context.coordinator.handleMagnify(event)
        }
        
        // Pass Zoom-to-Range event back to Coordinator
        view.onZoomToRange = { x1, x2, y in
            context.coordinator.handleZoomOrDrag(x1: x1, x2: x2, y: y)
        }
        
        // Pass Hover event
        view.onHover = { point in
            onHover?(point)
        }
        view.onHoverEnd = {
            onHoverEnd?()
        }
        
        view.onClick = { point in
            onClick?(point)
        }
        
        view.onDoubleClick = { point in
            onDoubleClick?(point)
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
        
        func handleZoomOrDrag(x1: CGFloat, x2: CGFloat, y: CGFloat) {
            // Always pass drag event up to parent
            // Parent will decide whether to:
            // 1. Create Event (if y > 48)
            // 2. Zoom & Filter (if y <= 48)
            parent.onDragEnd?(x1, x2, y)
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
        var onClick: ((CGPoint) -> Void)?
        var onDoubleClick: ((CGPoint) -> Void)?
        
        // Drag Selection UI
        private var dragStartPoint: CGPoint?
        private var selectionLayer: CALayer?
        
        override var acceptsFirstResponder: Bool { true }
        override var isFlipped: Bool { true }
        
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
            if event.clickCount == 2 {
                let point = convert(event.locationInWindow, from: nil)
                onDoubleClick?(point)
                return
            }
            handleDragStart(event: event)
        }
        
        override func rightMouseDown(with event: NSEvent) {
            handleDragStart(event: event)
        }
        
        override func mouseDragged(with event: NSEvent) {
            handleDragUpdate(event: event)
        }
        
        override func rightMouseDragged(with event: NSEvent) {
            handleDragUpdate(event: event)
        }
        
        override func mouseUp(with event: NSEvent) {
            handleDragEnd(event: event)
        }
        
        override func rightMouseUp(with event: NSEvent) {
            handleDragEnd(event: event)
        }
        
        // MARK: - Unified Drag Handling
        
        private func handleDragStart(event: NSEvent) {
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
        
        private func handleDragUpdate(event: NSEvent) {
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
        
        private func handleDragEnd(event: NSEvent) {
            guard let start = dragStartPoint else { return }
            let end = convert(event.locationInWindow, from: nil)
            
            selectionLayer?.isHidden = true
            dragStartPoint = nil
            
            let distance = abs(end.x - start.x)
            if distance > 10 {
                let x1 = min(start.x, end.x)
                let x2 = max(start.x, end.x)
                
                // Check if Right Click (Right Mouse Up or Ctrl+Left Click)
                let isRightClick = event.type == .rightMouseUp || (event.modifierFlags.contains(.control) && event.type == .leftMouseUp)
                
                // If Right Click -> Force Y > 49 to trigger Event Creation
                // If Left Click -> Force Y = 0 to trigger only Zoom/Filter
                let effectiveY = isRightClick ? 50.0 : 0.0
                
                onZoomToRange?(x1, x2, effectiveY)
            } else {
                onClick?(end)
            }
        }
        
        // We need a way to communicate "Zoom to X1...X2" back to SwiftUI.
        var onZoomToRange: ((CGFloat, CGFloat, CGFloat) -> Void)?
    }
}
