import SwiftUI

/// SwiftUI component for recursive rendering of hierarchical activity rows
/// Supports all 6 hierarchy levels with expansion/collapse functionality
struct HierarchicalActivityRow: View {
    let group: ActivityGroup
    @State private var isExpanded: Bool = false
    
    // Visual styling constants for different hierarchy levels
    private var indentationLevel: CGFloat {
        switch group.level {
        case .project: return 0
        case .subproject: return 20
        case .timeEntry: return 40
        case .timePeriod: return 60
        case .appName: return 80
        case .appTitle: return 100
        }
    }
    
    private var iconName: String {
        switch group.level {
        case .project: return "folder"
        case .subproject: return "folder.badge.plus"
        case .timeEntry: return "clock"
        case .timePeriod: return "calendar"
        case .appName: return "app"
        case .appTitle: return "doc.text"
        }
    }
    
    private var fontSize: Font {
        switch group.level {
        case .project: return .headline
        case .subproject: return .subheadline
        case .timeEntry: return .body
        case .timePeriod: return .body
        case .appName: return .callout
        case .appTitle: return .caption
        }
    }
    
    private var textColor: Color {
        switch group.level {
        case .project: return .primary
        case .subproject: return .primary
        case .timeEntry: return .secondary
        case .timePeriod: return .secondary
        case .appName: return .secondary
        case .appTitle: return Color.secondary.opacity(0.7)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row content
            HStack {
                // Indentation spacing
                Spacer()
                    .frame(width: indentationLevel)
                
                // Expansion indicator (only show if has children)
                if group.hasChildren {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer()
                        .frame(width: 12)
                }
                
                // Level-appropriate icon
                Image(systemName: iconName)
                    .font(.system(size: iconSize))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                // Group name
                Text(group.name)
                    .font(fontSize)
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                Spacer()
                
                // Aggregated data display
                HStack(spacing: 8) {
                    // Item count (only show if > 1 or has children)
                    if group.itemCount > 1 || group.hasChildren {
                        Text("\(group.itemCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    // Duration display
                    Text(group.durationString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, rowVerticalPadding)
            .contentShape(Rectangle()) // Make entire row tappable
            .onTapGesture {
                if group.hasChildren {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Expanded children (recursive rendering)
            if isExpanded && group.hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    // Render child groups recursively
                    ForEach(group.children) { childGroup in
                        HierarchicalActivityRow(group: childGroup)
                    }
                    
                    // Render individual activities at the leaf level
                    ForEach(group.activities) { activity in
                        ActivityLeafRow(activity: activity, indentationLevel: indentationLevel + 20)
                    }
                }
            }
        }
    }
    
    // Helper computed properties for styling
    private var iconSize: CGFloat {
        switch group.level {
        case .project: return 16
        case .subproject: return 14
        case .timeEntry: return 12
        case .timePeriod: return 12
        case .appName: return 11
        case .appTitle: return 10
        }
    }
    
    private var iconColor: Color {
        switch group.level {
        case .project: return .blue
        case .subproject: return .green
        case .timeEntry: return .orange
        case .timePeriod: return .purple
        case .appName: return .red
        case .appTitle: return .gray
        }
    }
    
    private var rowVerticalPadding: CGFloat {
        switch group.level {
        case .project: return 8
        case .subproject: return 6
        case .timeEntry: return 4
        case .timePeriod: return 4
        case .appName: return 3
        case .appTitle: return 2
        }
    }
}

/// Leaf row component for individual activities
struct ActivityLeafRow: View {
    let activity: Activity
    let indentationLevel: CGFloat
    
    var body: some View {
        HStack {
            // Indentation spacing
            Spacer()
                .frame(width: indentationLevel)
            
            // No expansion indicator for leaf nodes
            Spacer()
                .frame(width: 12)
            
            // Activity icon
            Image(systemName: activity.icon)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .frame(width: 20)
            
            // Activity title or app name
            Text(activity.appTitle ?? activity.appName)
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.7))
                .lineLimit(1)
            
            Spacer()
            
            // Activity duration
            Text(activity.durationString)
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.7))
                .monospacedDigit()
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    // Create sample data for preview
    let sampleActivity = Activity(
        appName: "Safari",
        appBundleId: "com.apple.Safari",
        appTitle: "GitHub - Example Repository",
        duration: 300, // 5 minutes
        startTime: Date(),
        endTime: Date().addingTimeInterval(300),
        icon: "safari"
    )
    
    let sampleGroup = ActivityGroup(
        name: "Development Project",
        level: .project,
        children: [
            ActivityGroup(
                name: "Web Development",
                level: .subproject,
                children: [
                    ActivityGroup(
                        name: "Morning Session",
                        level: .timeEntry,
                        children: [
                            ActivityGroup(
                                name: "9:00 AM - 10:00 AM",
                                level: .timePeriod,
                                children: [
                                    ActivityGroup(
                                        name: "Safari",
                                        level: .appName,
                                        children: [
                                            ActivityGroup(
                                                name: "github.com",
                                                level: .appTitle,
                                                activities: [sampleActivity]
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ]
            )
        ]
    )
    
    return List {
        HierarchicalActivityRow(group: sampleGroup)
    }
    .listStyle(.plain)
}