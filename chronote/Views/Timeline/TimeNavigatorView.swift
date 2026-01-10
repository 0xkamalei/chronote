import SwiftUI

struct TimeNavigatorView: View {
    @Binding var visibleRange: ClosedRange<Date>
    let totalRange: ClosedRange<Date>
    
    @State private var dragStartRange: ClosedRange<Date>? = nil
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // Guard against zero duration
            let totalDuration = max(1, totalRange.upperBound.timeIntervalSince(totalRange.lowerBound))
            let visibleDuration = visibleRange.upperBound.timeIntervalSince(visibleRange.lowerBound)
            
            let startOffset = visibleRange.lowerBound.timeIntervalSince(totalRange.lowerBound)
            
            // Calculate thumb position and width
            // Ensure thumb doesn't disappear if zoomed in extremely
            let thumbWidth = max(24, width * CGFloat(visibleDuration / totalDuration))
            
            // Clamp X to bounds
            let ratio = max(0, min(1, startOffset / totalDuration))
            let thumbX = width * CGFloat(ratio)
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 6)
                
                // Thumb
                Capsule()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: thumbWidth, height: 6)
                    .offset(x: thumbX)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartRange == nil {
                                    dragStartRange = visibleRange
                                }
                                
                                guard let startRange = dragStartRange else { return }
                                
                                let pxPerSecond = width / CGFloat(totalDuration)
                                let secondsShift = Double(value.translation.width) / Double(pxPerSecond)
                                
                                let duration = startRange.upperBound.timeIntervalSince(startRange.lowerBound)
                                
                                var newStart = startRange.lowerBound.addingTimeInterval(secondsShift)
                                var newEnd = startRange.upperBound.addingTimeInterval(secondsShift)
                                
                                // Clamp to total bounds
                                if newStart < totalRange.lowerBound {
                                    newStart = totalRange.lowerBound
                                    newEnd = newStart.addingTimeInterval(duration)
                                } else if newEnd > totalRange.upperBound {
                                    newEnd = totalRange.upperBound
                                    newStart = newEnd.addingTimeInterval(-duration)
                                }
                                
                                visibleRange = newStart...newEnd
                            }
                            .onEnded { _ in
                                dragStartRange = nil
                            }
                    )
            }
            .padding(.horizontal, 1) // Avoid edge clipping
        }
        .frame(height: 12)
    }
}
