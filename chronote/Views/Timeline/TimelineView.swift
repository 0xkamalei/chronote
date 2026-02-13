import SwiftUI
import SwiftData

struct TimelineView: View {
    var activities: [Activity]
    var events: [Event]
    @Query(sort: \Project.name) private var projects: [Project]
    
    // Controlled from outside
    @Binding var visibleTimeRange: ClosedRange<Date>
    var totalTimeRange: ClosedRange<Date>
    var selectedTimeRange: ClosedRange<Date>? // Visual highlight for filtered range
    
    // Callback for filtering (Drag Selection)
    var onRangeSelected: ((ClosedRange<Date>) -> Void)?
    
    @State private var renderBlocks: [TimelineRenderBlock] = []
    @State private var eventRenderBlocks: [TimelineRenderBlock] = []
    
    @State private var hoveredBlock: TimelineRenderBlock? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var hoveredActivity: Activity? = nil  // 悬浮时间戳对应的具体 Activity
    
    @State private var selectedEventId: UUID? = nil
    @State private var showEditEventPopover: Bool = false
    
    // Create Event State
    @State private var showCreateEventPopover: Bool = false
    @State private var dragCreateStartTime: Date?
    @State private var dragCreateEndTime: Date?
    @State private var dragCreateLocation: CGPoint = .zero
    @State private var eventProjectColors: [UUID: Color] = [:]
    @State private var recalcTask: Task<Void, Never>? = nil
    
    private let processor = TimelineProcessor()
    private let activityTrackHeight: CGFloat = 48
    private let eventTrackHeight: CGFloat = 24
    private let projectLineHeight: CGFloat = 4
    private let trackDividerHeight: CGFloat = 1
    
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
            let eventTrackTop = activityTrackHeight + trackDividerHeight
            let projectLineTop = eventTrackTop + eventTrackHeight
            let eventSectionBottom = projectLineTop + projectLineHeight
            
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
                        .frame(height: activityTrackHeight)
                        
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
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(.white)
                                    context.draw(text, at: center, anchor: .center)
                                }
                            }
                        }
                        .frame(height: eventTrackHeight)

                        Canvas { context, size in
                            for block in eventRenderBlocks {
                                let projectColor = projectColor(for: block) ?? block.color.opacity(0.25)
                                let lineRect = CGRect(
                                    x: block.rect.minX,
                                    y: 0,
                                    width: block.rect.width,
                                    height: size.height
                                )
                                let linePath = Path(roundedRect: lineRect, cornerRadius: 2)
                                context.fill(linePath, with: .color(projectColor))
                            }
                        }
                        .frame(height: projectLineHeight)
                    }
                    
                    // Interaction Overlay
                    TimelineInteractionOverlay(
                        visibleTimeRange: $visibleTimeRange,
                        totalTimeRange: totalTimeRange,
                        totalWidth: width,
                        onHover: { point in
                            // Check Activity Track (Top, 0-48)
                            if point.y < activityTrackHeight {
                                // Hit test on activity blocks
                                if let block = renderBlocks.first(where: { $0.rect.contains(point) }) {
                                    hoveredBlock = block
                                    hoverLocation = point

                                    // 根据鼠标位置计算时间戳
                                    let hoveredTimestamp = calculateTimestampFromPoint(point.x, width: width)

                                    // 查找该时间戳对应的 Activity
                                    hoveredActivity = activities.first { activity in
                                        activity.startTime <= hoveredTimestamp &&
                                        hoveredTimestamp <= (activity.endTime ?? Date())
                                    }
                                } else {
                                    hoveredBlock = nil
                                    hoveredActivity = nil
                                }
                            }
                            // Check Event Track (Bottom)
                            else if point.y >= eventTrackTop && point.y < eventSectionBottom {
                                // Convert point to Event Track coordinate space
                                let localY = point.y - eventTrackTop
                                let localPoint = CGPoint(x: point.x, y: localY)

                                if let block = eventRenderBlocks.first(where: { $0.rect.contains(localPoint) }) {
                                    hoveredBlock = block
                                    hoverLocation = point
                                    hoveredActivity = nil  // 事件轨道没有底层 Activity
                                } else {
                                    hoveredBlock = nil
                                    hoveredActivity = nil
                                }
                            } else {
                                // Divider or out of bounds
                                hoveredBlock = nil
                                hoveredActivity = nil
                            }
                        },
                        onHoverEnd: {
                            hoveredBlock = nil
                            hoveredActivity = nil
                        },
                        onClick: { point in
                            // Single click logic (e.g. Selection)
                            // Currently empty to avoid conflict with double click
                        },
                        onDoubleClick: { point in
                            if point.y >= eventTrackTop && point.y < eventSectionBottom {
                                let eventY = point.y - eventTrackTop
                                if let block = eventRenderBlocks.first(where: { $0.rect.contains(CGPoint(x: point.x, y: eventY)) }) {
                                    if let id = block.eventId {
                                        selectedEventId = id
                                        // Calculate center point of the block in global coordinate space
                                        // Block rect is local to the event track
                                        let centerX = block.rect.midX
                                        let centerY = block.rect.midY + eventTrackTop
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
                            
                            // Check if this is Event Creation (event section)
                            if y >= eventTrackTop {
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
                    if let activity = hoveredActivity {
                        TimelineTooltipView(activity: activity)
                            // Position vertically based on track (Top/Bottom)
                            // Position horizontally centered on the hover location
                                .position(
                                    x: hoverLocation.x,
                                    y: hoverLocation.y >= eventTrackTop ? 15 : 85
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
                                    scheduleRecalculate(width: width, debounceNanoseconds: 0)
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
                                    scheduleRecalculate(width: width, debounceNanoseconds: 0)
                                }
                        }
                }
            }
            .onChange(of: width) { _, newWidth in
                scheduleRecalculate(width: newWidth)
            }
            .onChange(of: activities) { _, _ in
                scheduleRecalculate(width: width)
            }
            .onChange(of: events) { _, _ in
                scheduleRecalculate(width: width)
            }
            .onChange(of: projects) { _, _ in
                scheduleRecalculate(width: width)
            }
            .onChange(of: visibleTimeRange) { _, _ in
                scheduleRecalculate(width: width)
            }
            .onAppear {
                // 初次出现时，自动检测活跃时间范围
                let smartRange = TimelineSmartRangeDetector.detectActiveTimeRange(from: activities)
                if smartRange != visibleTimeRange {
                    visibleTimeRange = smartRange
                }
                scheduleRecalculate(width: width, debounceNanoseconds: 0)
            }
            .onDisappear {
                recalcTask?.cancel()
            }
        }
        .frame(height: isFullyZoomedOut ? 102 : 118)
    }
    
    private var isFullyZoomedOut: Bool {
        let totalDuration = totalTimeRange.upperBound.timeIntervalSince(totalTimeRange.lowerBound)
        let visibleDuration = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        return visibleDuration >= totalDuration * 0.99
    }
    
    private func scheduleRecalculate(width: CGFloat, debounceNanoseconds: UInt64 = 16_000_000) {
        recalcTask?.cancel()
        recalcTask = Task { @MainActor in
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }

            let result = await processor.processAsync(
                activities: activities,
                events: events,
                visibleTimeRange: visibleTimeRange,
                canvasWidth: width,
                eventBlockHeight: eventTrackHeight
            )
            guard !Task.isCancelled else { return }

            renderBlocks = result.activityBlocks
            eventRenderBlocks = result.eventBlocks
            eventProjectColors = buildEventProjectColorMap()
        }
    }

    private func buildEventProjectColorMap() -> [UUID: Color] {
        let projectColors = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.color) })
        var map: [UUID: Color] = [:]
        for event in events {
            guard let projectId = event.projectId, let color = projectColors[projectId] else { continue }
            map[event.id] = color
        }
        return map
    }

    private func projectColor(for block: TimelineRenderBlock) -> Color? {
        guard let eventId = block.eventId else { return nil }
        return eventProjectColors[eventId]
    }

    /// 根据鼠标 X 位置计算对应的时间戳
    /// - Parameters:
    ///   - x: 鼠标的 X 坐标（像素）
    ///   - width: Timeline 的总宽度（像素）
    /// - Returns: 对应的时间戳
    private func calculateTimestampFromPoint(_ x: CGFloat, width: CGFloat) -> Date {
        let visibleDuration = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        let pixelsPerSecond = width / visibleDuration
        let secondsFromStart = Double(x) / pixelsPerSecond
        return visibleTimeRange.lowerBound.addingTimeInterval(secondsFromStart)
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
