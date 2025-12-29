import SwiftUI
import SwiftData

struct TimelineView: View {
    var activities: [Activity]
    var events: [Event]
    
    // Controlled from outside
    @Binding var visibleTimeRange: ClosedRange<Date>
    var totalTimeRange: ClosedRange<Date>
    var selectedTimeRange: ClosedRange<Date>? // Visual highlight for filtered range
    
    // Callback for filtering (Drag Selection)
    var onRangeSelected: ((ClosedRange<Date>) -> Void)?
    
    @AppStorage("timelineMergeStatisticsEnabled") private var mergeEnabled = false
    @AppStorage("timelineMergeIntervalMinutes") private var mergeIntervalMinutes = 30
    
    @State private var renderBlocks: [TimelineRenderBlock] = []
    @State private var eventRenderBlocks: [TimelineRenderBlock] = []
    
    @State private var hoveredBlock: TimelineRenderBlock? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    @State private var selectedEventId: UUID? = nil
    @State private var showEditEventPopover: Bool = false
    
    // Create Event State
    @State private var showCreateEventPopover: Bool = false
    @State private var dragCreateStartTime: Date?
    @State private var dragCreateEndTime: Date?
    @State private var dragCreateLocation: CGPoint = .zero
    
    private let processor = TimelineProcessor()
    
    init(activities: [Activity], events: [Event] = [], visibleTimeRange: Binding<ClosedRange<Date>>, totalTimeRange: ClosedRange<Date>, selectedTimeRange: ClosedRange<Date>? = nil, onRangeSelected: ((ClosedRange<Date>) -> Void)? = nil) {
        self.activities = activities
        self.events = events
        self._visibleTimeRange = visibleTimeRange
        self.totalTimeRange = totalTimeRange
        self.selectedTimeRange = selectedTimeRange
        self.onRangeSelected = onRangeSelected
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            VStack(alignment: .leading, spacing: 0) {
                // Header: Time Axis Labels
                TimeAxisHeader(range: visibleTimeRange, width: width)
                    .frame(height: 24)
                    .background(Material.bar)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(nsColor: .separatorColor)),
                        alignment: .bottom
                    )
                
                ZStack(alignment: .topLeading) {
                    // Background Grid
                    TimeAxisGrid(range: visibleTimeRange, width: width)
                    
                    // Selected Range Highlight
                    if let selected = selectedTimeRange, selected != totalTimeRange {
                        TimelineSelectionLayer(selectedRange: selected, visibleRange: visibleTimeRange, width: width)
                    }
                    
                    VStack(spacing: 0) {
                        // App Activity Track (Top)
                        Canvas { context, size in
                            for block in renderBlocks {
                                // Draw Rounded Rect
                                let path = Path(roundedRect: block.rect, cornerRadius: 4)
                                context.fill(path, with: .color(block.color))
                                
                                // Draw Icon (if space permits)
                                if block.rect.width > 20, let icon = block.icon {
                                    let iconSize: CGFloat = 16
                                    // Center icon in the block
                                    let iconRect = CGRect(
                                        x: block.rect.midX - (iconSize / 2),
                                        y: block.rect.midY - (iconSize / 2),
                                        width: iconSize,
                                        height: iconSize
                                    )
                                    context.draw(Image(nsImage: icon), in: iconRect)
                                }
                            }
                        }
                        .frame(height: 48)
                        
                        Divider()
                        
                        // Event Track (Bottom)
                        Canvas { context, size in
                            for block in eventRenderBlocks {
                                let path = Path(roundedRect: block.rect, cornerRadius: 4)
                                context.fill(path, with: .color(block.color))
                                
                                // Text
                                if block.rect.width > 20 {
                                    let center = CGPoint(x: block.rect.midX, y: block.rect.midY)
                                    let text = Text(block.appName)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    context.draw(text, at: center, anchor: .center)
                                }
                            }
                        }
                        .frame(height: 48)
                    }
                    
                    // Interaction Overlay
                    TimelineInteractionOverlay(
                        visibleTimeRange: $visibleTimeRange,
                        totalTimeRange: totalTimeRange,
                        totalWidth: width,
                        onHover: { point in
                            // Check Activity Track (Top, 0-48)
                            if point.y < 48 {
                                // Hit test on activity blocks
                                if let block = renderBlocks.first(where: { $0.rect.contains(point) }) {
                                    hoveredBlock = block
                                    hoverLocation = point
                                } else {
                                    // If moving within the same track but not on a block, clear
                                    hoveredBlock = nil
                                }
                            }
                            // Check Event Track (Bottom, > 49)
                            else if point.y > 49 {
                                // Convert point to Event Track coordinate space (y - 49)
                                let localY = point.y - 49
                                let localPoint = CGPoint(x: point.x, y: localY)
                                
                                if let block = eventRenderBlocks.first(where: { $0.rect.contains(localPoint) }) {
                                    hoveredBlock = block
                                    hoverLocation = point
                                } else {
                                    hoveredBlock = nil
                                }
                            } else {
                                // Divider or out of bounds
                                hoveredBlock = nil
                            }
                        },
                        onHoverEnd: {
                            hoveredBlock = nil
                        },
                        onClick: { point in
                            // Single click logic (e.g. Selection)
                            // Currently empty to avoid conflict with double click
                        },
                        onDoubleClick: { point in
                            // Event Track is > 49 (48 + 1)
                            if point.y > 49 {
                                let eventY = point.y - 49
                                if let block = eventRenderBlocks.first(where: { $0.rect.contains(CGPoint(x: point.x, y: eventY)) }) {
                                    if let id = block.eventId {
                                        selectedEventId = id
                                        // Calculate center point of the block in global coordinate space
                                        // Block rect is local to the track (y-offset: 49)
                                        let centerX = block.rect.midX
                                        let centerY = block.rect.midY + 49
                                        dragCreateLocation = CGPoint(x: centerX, y: centerY)
                                        
                                        showEditEventPopover = true
                                    }
                                }
                            } else {
                                // Activity Track Double Click -> Reset Zoom
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    visibleTimeRange = totalTimeRange
                                    onRangeSelected?(totalTimeRange)
                                }
                            }
                        },
                        onDragEnd: { x1, x2, y in
                            // Calculate Time Range
                            let duration = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
                            let pxPerSec = width / duration
                            
                            let t1 = visibleTimeRange.lowerBound.addingTimeInterval(Double(x1) / pxPerSec)
                            let t2 = visibleTimeRange.lowerBound.addingTimeInterval(Double(x2) / pxPerSec)
                            
                            let start = min(t1, t2)
                            let end = max(t1, t2)
                            
                            // Check if this is Event Creation (y > 48)
                            if y > 48 {
                                dragCreateStartTime = start
                                dragCreateEndTime = end
                                dragCreateLocation = CGPoint(x: (x1 + x2) / 2, y: y)
                                showCreateEventPopover = true
                            } else {
                                // Drag Select on Activity Track -> Filter Time
                                // Validate duration (min 60s)
                                if end.timeIntervalSince(start) > 60 {
                                    // Update visible range AND trigger filter callback
                                    visibleTimeRange = start...end
                                    onRangeSelected?(start...end)
                                }
                            }
                        }
                    )
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .zIndex(1)
                .overlay(alignment: .topTrailing) {
                    // Reset Zoom Button
                    if !isFullyZoomedOut {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                visibleTimeRange = totalTimeRange
                                onRangeSelected?(totalTimeRange)
                            }
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(6)
                                .background(Material.regular)
                                .clipShape(Circle())
                                .shadow(radius: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .help("Reset Zoom")
                        .transition(.opacity)
                    }
                }
                
                // Navigator (Scrollbar) - Hide when not zoomed
                if !isFullyZoomedOut {
                    Divider()
                    
                    TimeNavigatorView(visibleRange: $visibleTimeRange, totalRange: totalTimeRange)
                        .padding(.vertical, 4)
                        .background(Material.bar)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .shadow(radius: 1, y: 1)
            // Tooltip Overlay
            .overlay(alignment: .topLeading) {
                    if let block = hoveredBlock {
                        TimelineTooltipView(block: block)
                            // Position vertically based on track (Top/Bottom)
                            // Position horizontally centered on the block
                            .position(
                                x: block.rect.midX,
                                y: hoverLocation.y > 48 ? 15 : 85
                            )
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            // Edit Event Overlay
            .overlay(alignment: .topLeading) {
                 if showEditEventPopover, let id = selectedEventId, let event = events.first(where: { $0.id == id }) {
                     Color.clear
                        .frame(width: 1, height: 1)
                        .position(dragCreateLocation) // Use the captured block location
                        .popover(isPresented: $showEditEventPopover) {
                             EditEventView(event: event)
                                 .onDisappear {
                                     // Trigger recalculation after edit
                                     recalculate(width: width)
                                 }
                        }
                 }
            }
            // Create Event Overlay (from Drag)
            .overlay(alignment: .topLeading) {
                if showCreateEventPopover {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .position(dragCreateLocation)
                        .popover(isPresented: $showCreateEventPopover) {
                            StartEventView(initialStartTime: dragCreateStartTime, initialEndTime: dragCreateEndTime)
                                .onDisappear {
                                    // Trigger recalculation after create
                                    recalculate(width: width)
                                }
                        }
                }
            }
            .onChange(of: width) { newWidth in
                recalculate(width: newWidth)
            }
            .onChange(of: activities) { _ in
                recalculate(width: width)
            }
            .onChange(of: events) { _ in
                recalculate(width: width)
            }
            .onChange(of: visibleTimeRange) { _ in
                recalculate(width: width)
            }
            .onChange(of: mergeEnabled) { _ in
                recalculate(width: width)
            }
            .onChange(of: mergeIntervalMinutes) { _ in
                recalculate(width: width)
            }
            .onAppear {
                recalculate(width: width)
            }
        }
        .frame(height: isFullyZoomedOut ? 122 : 138)
    }
    
    private var isFullyZoomedOut: Bool {
        let totalDuration = totalTimeRange.upperBound.timeIntervalSince(totalTimeRange.lowerBound)
        let visibleDuration = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        return visibleDuration >= totalDuration * 0.99
    }
    
    private func recalculate(width: CGFloat) {
        let blocks: [TimelineRenderBlock]
        if mergeEnabled {
            let interval = TimeInterval(mergeIntervalMinutes * 60)
            blocks = processor.processMerged(activities: activities, visibleTimeRange: visibleTimeRange, canvasWidth: width, interval: interval)
        } else {
            blocks = processor.process(activities: activities, visibleTimeRange: visibleTimeRange, canvasWidth: width)
        }
        self.renderBlocks = blocks
        
        let evtBlocks = processor.processEvents(events: events, visibleTimeRange: visibleTimeRange, canvasWidth: width)
        self.eventRenderBlocks = evtBlocks
    }
}

// MARK: - Helper Views

struct TimeAxisHeader: View {
    let range: ClosedRange<Date>
    let width: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let totalSeconds = range.upperBound.timeIntervalSince(range.lowerBound)
            guard totalSeconds > 0 else { return }
            let pxPerSec = width / totalSeconds
            
            // 1. Calculate Strategy
            let strategy = TimeAxisStrategy.calculateInterval(for: range, width: width)
            
            // 2. Generate Ticks
            let ticks = TimeAxisStrategy.generateTicks(range: range, interval: strategy)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = strategy.labelFormat
            
            for date in ticks {
                let x = CGFloat(date.timeIntervalSince(range.lowerBound)) * pxPerSec
                
                // Draw Text
                let textStr = dateFormatter.string(from: date)
                let text = Text(textStr).font(.caption).foregroundColor(.secondary)
                context.draw(text, at: CGPoint(x: x, y: size.height / 2))
            }
        }
    }
}

struct TimeAxisGrid: View {
    let range: ClosedRange<Date>
    let width: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let totalSeconds = range.upperBound.timeIntervalSince(range.lowerBound)
            guard totalSeconds > 0 else { return }
            let pxPerSec = width / totalSeconds
            
            // 1. Calculate Strategy
            let strategy = TimeAxisStrategy.calculateInterval(for: range, width: width)
            
            // 2. Generate Ticks
            let ticks = TimeAxisStrategy.generateTicks(range: range, interval: strategy)
            
            for date in ticks {
                let x = CGFloat(date.timeIntervalSince(range.lowerBound)) * pxPerSec
                
                // Draw Line
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 1)
            }
        }
    }
}

struct TimelineSelectionLayer: View {
    let selectedRange: ClosedRange<Date>
    let visibleRange: ClosedRange<Date>
    let width: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let visibleDuration = visibleRange.upperBound.timeIntervalSince(visibleRange.lowerBound)
            guard visibleDuration > 0 else { return }
            let pxPerSec = width / visibleDuration
            
            let startOffset = selectedRange.lowerBound.timeIntervalSince(visibleRange.lowerBound)
            let endOffset = selectedRange.upperBound.timeIntervalSince(visibleRange.lowerBound)
            
            let x1 = CGFloat(startOffset) * pxPerSec
            let x2 = CGFloat(endOffset) * pxPerSec
            
            // Draw Blue Box
            // Ensure width is at least 1px to be visible
            let rectWidth = max(1, x2 - x1)
            let rect = CGRect(x: x1, y: 0, width: rectWidth, height: size.height)
            
            // Style: Similar to drag selection (blue with alpha)
            context.fill(Path(rect), with: .color(.blue.opacity(0.1)))
            
            // Optional: Add Border
            let borderPath = Path(rect)
            context.stroke(borderPath, with: .color(.blue.opacity(0.3)), lineWidth: 1)
        }
        .allowsHitTesting(false) // Let clicks pass through
    }
}
