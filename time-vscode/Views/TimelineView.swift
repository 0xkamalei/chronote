import AppKit // Added AppKit import to access NSColor
import SwiftUI

struct TimelineView: View {
    @State private var timelineScale: CGFloat = 1.0
    
    // Mock activities data - replace with real data source
    private let activities: [Activity] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return [
            Activity(appName: "Xcode", appBundleId: "com.apple.dt.Xcode", duration: 3600, 
                    startTime: today.addingTimeInterval(9 * 3600), // 9:00 AM
                    endTime: today.addingTimeInterval(10 * 3600), // 10:00 AM
                    icon: "hammer"),
            Activity(appName: "Safari", appBundleId: "com.apple.Safari", duration: 1800, 
                    startTime: today.addingTimeInterval(10 * 3600), // 10:00 AM
                    endTime: today.addingTimeInterval(10.5 * 3600), // 10:30 AM
                    icon: "safari"),
            Activity(appName: "Terminal", appBundleId: "com.apple.Terminal", duration: 900, 
                    startTime: today.addingTimeInterval(11 * 3600), // 11:00 AM
                    endTime: today.addingTimeInterval(11.25 * 3600), // 11:15 AM
                    icon: "terminal"),
            Activity(appName: "Notes", appBundleId: "com.apple.Notes", duration: 1800, 
                    startTime: today.addingTimeInterval(14 * 3600), // 2:00 PM
                    endTime: today.addingTimeInterval(14.5 * 3600), // 2:30 PM
                    icon: "note.text")
        ]
    }()
    
    private var timelineWidth: CGFloat {
        return 1920 * timelineScale
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
                    
                    ForEach(["00:00", "01:00", "02:00", "03:00", "04:00", "05:00", "06:00", "07:00", "08:00", "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00", "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"], id: \.self) { time in
                        VStack(spacing: 2) {
                            Text(time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1, height: 8)
                        }
                        .frame(width: 80 * timelineScale)
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
        let start = activity.startTime.timeIntervalSinceMidnight() / 86400
        let end = activity.endTime.timeIntervalSinceMidnight() / 86400
        let width = end - start
        let appColor = colorForApp(activity.appBundleId)
        
        TimeBlock(color: appColor.opacity(0.6), position: start, width: width)
            .overlay(IconOverlay(iconName: activity.icon, color: appColor), alignment: .leading)
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
    
    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.8), color.opacity(0.4)]), startPoint: .top, endPoint: .bottom))
                .frame(width: width * geo.size.width, height: 30)
                .position(x: position * geo.size.width + (width * geo.size.width / 2), y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                        .frame(width: width * geo.size.width, height: 30)
                        .position(x: position * geo.size.width + (width * geo.size.width / 2), y: 15)
                )
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
                .onHover { hovering in
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
        return self.timeIntervalSince(midnight)
    }
}

#Preview {
    TimelineView()
}
