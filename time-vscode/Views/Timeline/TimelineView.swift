import AppKit // Added AppKit import to access NSColor
import SwiftUI

struct TimelineView: View {
    @State private var timelineScale: CGFloat = 1.0
    
    // Mock activities data - replace with real data source
    private let activities: [Activity] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return [
            // Test: Exactly at 9:00 AM (should align with 09:00 marker)
            Activity(appName: "Xcode", appBundleId: "com.apple.dt.Xcode", duration: 3600,
                     startTime: today.addingTimeInterval(9 * 3600), // 9:00 AM
                     endTime: today.addingTimeInterval(10 * 3600), // 10:00 AM
                     icon: "hammer"),
            // Test: Exactly at 12:00 PM (should align with 12:00 marker)
            Activity(appName: "Safari", appBundleId: "com.apple.Safari", duration: 1800,
                     startTime: today.addingTimeInterval(12 * 3600), // 12:00 PM
                     endTime: today.addingTimeInterval(12.5 * 3600), // 12:30 PM
                     icon: "safari"),
            // Test: Exactly at 18:00 (should align with 18:00 marker)
            Activity(appName: "Terminal", appBundleId: "com.apple.Terminal", duration: 900,
                     startTime: today.addingTimeInterval(18 * 3600), // 6:00 PM
                     endTime: today.addingTimeInterval(18.25 * 3600), // 6:15 PM
                     icon: "terminal"),
            // Test: Exactly at 0:00 (should align with 00:00 marker)
            Activity(appName: "Notes", appBundleId: "com.apple.Notes", duration: 1800,
                     startTime: today.addingTimeInterval(0 * 3600), // 12:00 AM
                     endTime: today.addingTimeInterval(0.5 * 3600), // 12:30 AM
                     icon: "note.text")
        ]
    }()
    
    private var timelineWidth: CGFloat {
        return 24 * 80 * timelineScale // 24 hours * 80px per hour
    }
    
    private var totalWidth: CGFloat {
        return 140 + timelineWidth
    }
    
    // Helper function to get app-specific colors
    private func colorForApp(_ bundleId: String) -> Color {
        switch bundleId {
        case "com.apple.dt.Xcode":
            return .blue
        case "com.apple.Safari":
            return .orange
        case "com.apple.Terminal":
            return .green
        case "com.apple.Notes":
            return .yellow
        default:
            return .gray
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 12) {
                // Time header
                HStack(alignment: .bottom, spacing: 0) {
                    Text("TIME")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .leading)
                        .padding(.leading, 16)

                    
                    ForEach(Array(0..<24), id: \.self) { hour in
                        let timeString = String(format: "%02d:00", hour)
                        VStack(spacing: 2) {
                            Text(timeString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1, height: 8)
                        }
                        .frame(width: 80 * timelineScale, alignment: .leading)
                    }
                }
                .padding(.bottom, 8)
                .padding(.top, 4)
                
                // Device row
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MACBOOK PRO INTEL i9")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        Text("Device Activity")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, alignment: .leading)
                    .padding(.leading, 16)
                    
                    // Timeline blocks
                    ZStack(alignment: .leading) {
                        // Background timeline
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)]), startPoint: .leading, endPoint: .trailing))
                            .frame(width: timelineWidth, height: 30)
                            .cornerRadius(5)

                        // Activity blocks positioned according to time
                        Group {
                            ForEach(activities, id: \.id) { activity in
                                let startSeconds = activity.startTime.timeIntervalSinceMidnight()
                                let endSeconds = activity.endTime.timeIntervalSinceMidnight()
                                // Convert to hours for direct pixel positioning
                                let startHours = startSeconds / 3600
                                let endHours = endSeconds / 3600
                                // Calculate position and width as fractions of timeline width
                                let start = startHours / 24.0  // 0-1 range based on 24 hours
                                let end = endHours / 24.0
                                let width = end - start
                                let appColor = colorForApp(activity.appBundleId)
        
                                TimeBlock(color: appColor.opacity(0.6), position: start, width: width, iconName: activity.icon)
                            }
                        }
                    }
                }
                
                // Project row
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROJECT")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        Text("Project Timeline")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, alignment: .leading)
                    .padding(.leading, 16)
                    
                    // Project timeline
                    ZStack(alignment: .leading) {
                        // Background timeline
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)]), startPoint: .leading, endPoint: .trailing))
                            .frame(width: timelineWidth, height: 30)
                            .cornerRadius(5)
                        
                        // Project blocks - dynamic in real app
                        Group {
                            TimeBlock(color: .orange.opacity(0.6), position: 0.1, width: 0.3)
                                .overlay(IconOverlay(iconName: "folder", color: .orange), alignment: .leading)
                            TimeBlock(color: .purple.opacity(0.6), position: 0.5, width: 0.2)
                                .overlay(IconOverlay(iconName: "doc", color: .purple), alignment: .leading)
                            // more dynamic blocks here...
                        }
                    }
                }
                
                // Time entries row
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TIME ENTRIES")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        Text("Manual Entries")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, alignment: .leading)
                    .padding(.leading, 16)
                    
                    // Time entries blocks
                    ZStack(alignment: .leading) {
                        // Background timeline
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)]), startPoint: .leading, endPoint: .trailing))
                            .frame(width: timelineWidth, height: 30)
                            .cornerRadius(5)

                        // Entry blocks - dynamic in real app
                        Group {
                            TimeEntryBlock(position: 0.07, width: 0.15)
                                .overlay(IconOverlay(iconName: "timer", color: .blue), alignment: .leading)
                            TimeEntryBlock(position: 0.25, width: 0.1)
                                .overlay(IconOverlay(iconName: "calendar", color: .green), alignment: .leading)
                            // more dynamic blocks here...
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .scrollIndicators(.visible, axes: .horizontal)
        .contentMargins(.horizontal, 0) // 确保内容边距不影响滚动
        .onZoom(scale: $timelineScale)
    }
}

struct TimeBlock: View {
    let color: Color
    let position: Double // 0-1 position on timeline
    let width: Double // 0-1 width on timeline
    let iconName: String? // Optional icon name
    
    init(color: Color, position: Double, width: Double, iconName: String? = nil) {
        self.color = color
        self.position = position
        self.width = width
        self.iconName = iconName
    }
    
    var body: some View {
                        GeometryReader { geo in
                            let blockWidth = width * geo.size.width
                            let blockX = position * geo.size.width
                            let centerX = blockX + blockWidth / 2
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.8), color.opacity(0.4)]), startPoint: .top, endPoint: .bottom))
                                    .frame(width: blockWidth, height: 30)
                                    .position(x: centerX, y: 15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(color.opacity(0.3), lineWidth: 1)
                                            .frame(width: blockWidth, height: 30)
                                            .position(x: centerX, y: 15)
                                    )
                                
                                // App icon in the center
                                if let iconName = iconName {
                                    Image(systemName: iconName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                                .frame(width: 20, height: 20)
                                        )
                                        .position(x: centerX, y: 15)
                                }
                            }
                        }
        .frame(height: 30)
    }
}

struct TimeEntryBlock: View {
    let position: Double // 0-1 position on timeline
    let width: Double // 0-1 width on timeline
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: position * geo.size.width)
                
                Button(action: {}) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)]), startPoint: .top, endPoint: .bottom))
                            .frame(width: width * geo.size.width, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("+")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.gray)
                    }
                }
                .buttonStyle(.plain)
                .onHover { _ in
                    // Add hover effect here if needed
                }
                
                Spacer()
            }
        }
        .frame(height: 30)
    }
}

struct IconOverlay: View {
    let iconName: String
    let color: Color
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 20, height: 20)
            )
            .padding(.leading, 4)
    }
}

// Date extension for timeline calculations
extension Date {
    func timeIntervalSinceMidnight() -> TimeInterval {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: self)
        return timeIntervalSince(midnight)
    }
}

#Preview {
    TimelineView()
}
