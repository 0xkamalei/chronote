import SwiftUI
import SwiftData

struct TimelineView: View {
    var activities: [Activity]
    
    // Controlled from outside
    @Binding var visibleTimeRange: ClosedRange<Date>
    var totalTimeRange: ClosedRange<Date>
    
    @State private var renderBlocks: [TimelineRenderBlock] = []
    @State private var hoveredBlock: TimelineRenderBlock? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    private let processor = TimelineProcessor()
    
    init(activities: [Activity], visibleTimeRange: Binding<ClosedRange<Date>>, totalTimeRange: ClosedRange<Date>) {
        self.activities = activities
        self._visibleTimeRange = visibleTimeRange
        self.totalTimeRange = totalTimeRange
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
                    
                    // App Activity Track
                    // We wrap Canvas in a view to handle drawing
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
                    .frame(height: 48) // Increased Track height
                    
                    // Interaction Overlay
                    TimelineInteractionOverlay(
                        visibleTimeRange: $visibleTimeRange,
                        totalTimeRange: totalTimeRange,
                        totalWidth: width,
                        onHover: { x in
                            // Find block at x
                            // Since blocks are sorted by X (mostly), we can binary search or just linear scan for MVP
                            // The processor output is sorted by Time -> X.
                            // However, we need to handle potential overlaps or simple hit test.
                            // Blocks have `rect`. We just check if x is within rect.minX...rect.maxX
                            
                            // Note: onHover provides x relative to view.
                            // Blocks are rendered relative to 0...width.
                            
                            // Optimization: Binary Search
                            // For now, firstMatch is fine.
                            if let block = renderBlocks.first(where: { $0.rect.contains(CGPoint(x: x, y: 20)) }) {
                                hoveredBlock = block
                                hoverLocation = CGPoint(x: x, y: 0) // Y will be adjusted by Popover
                            } else {
                                hoveredBlock = nil
                            }
                        },
                        onHoverEnd: {
                            hoveredBlock = nil
                        }
                    )
                    
                    // Tooltip Popover (Moved to overlay to avoid clipping if possible, but ZStack clips by default in some contexts. 
                    // To truly avoid clipping, we should use .overlay on the top-level container or use a GeometryReader at root.
                    // However, shifting Y position down and clamping X is easier for now.)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .zIndex(1) // Ensure track is above navigator
                
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
            // Tooltip Overlay at the top level of the component to reduce clipping risk
            .overlay(alignment: .topLeading) {
                    if let block = hoveredBlock {
                        TimelineTooltipView(block: block)
                            // Smart Positioning
                            .offset(
                                x: min(max(0, hoverLocation.x - 100), width - 200), // Clamp X
                                y: 60 // Show BELOW the track to avoid top clipping
                            )
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            .onChange(of: width) { newWidth in
                recalculate(width: newWidth)
            }
            .onChange(of: activities) { _ in
                recalculate(width: width)
            }
            .onChange(of: visibleTimeRange) { _ in
                recalculate(width: width)
            }
            .onAppear {
                recalculate(width: width)
            }
        }
        .frame(height: isFullyZoomedOut ? 74 : 90) // Adjust height based on scrollbar visibility
    }
    
    private var isFullyZoomedOut: Bool {
        let totalDuration = totalTimeRange.upperBound.timeIntervalSince(totalTimeRange.lowerBound)
        let visibleDuration = visibleTimeRange.upperBound.timeIntervalSince(visibleTimeRange.lowerBound)
        // Allow small floating point error (e.g. 99% zoomed out is effectively full)
        return visibleDuration >= totalDuration * 0.99
    }
    
    private func recalculate(width: CGFloat) {
        let blocks = processor.process(activities: activities, visibleTimeRange: visibleTimeRange, canvasWidth: width)
        self.renderBlocks = blocks
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
