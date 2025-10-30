import SwiftUI

/// SwiftUI component for recursive rendering of hierarchical activity rows
/// Supports all 6 hierarchy levels with expansion/collapse functionality
struct HierarchicalActivityRow: View {
    let group: ActivityHierarchyGroup
    @State private var isExpanded: Bool = false
    
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
        case .timeEntry: 
            if group.hasOnlyTimeEntries {
                return "clock.fill"
            } else if group.hasMixedContent {
                return "clock.badge.checkmark"
            } else {
                return "clock"
            }
        case .timePeriod: return "calendar"
        case .appName: 
            if group.name == "Manual Time Entries" {
                return "pencil.circle"
            } else {
                return "app"
            }
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
            HStack {
                Spacer()
                    .frame(width: indentationLevel)
                
                if group.hasChildren {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer()
                        .frame(width: 12)
                }
                
                Image(systemName: iconName)
                    .font(.system(size: iconSize))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                Text(group.name)
                    .font(fontSize)
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if group.itemCount > 1 || group.hasChildren {
                        Text("\(group.itemCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
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
            
            if isExpanded && group.hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.children) { childGroup in
                        HierarchicalActivityRow(group: childGroup)
                    }
                    
                    ForEach(group.activities) { activity in
                        ActivityLeafRow(activity: activity, indentationLevel: indentationLevel + 20)
                    }
                    
                    ForEach(group.timeEntries) { timeEntry in
                        TimeEntryLeafRow(timeEntry: timeEntry, indentationLevel: indentationLevel + 20)
                    }
                }
            }
        }
    }
    
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
        case .timeEntry: 
            if group.hasOnlyTimeEntries {
                return .orange
            } else if group.hasMixedContent {
                return .yellow
            } else {
                return .orange
            }
        case .timePeriod: return .purple
        case .appName: 
            if group.name == "Manual Time Entries" {
                return .orange
            } else {
                return .red
            }
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
            Spacer()
                .frame(width: indentationLevel)
            
            Spacer()
                .frame(width: 12)
            
            Image(systemName: activity.icon)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .frame(width: 20)
            
            Text(activity.appTitle ?? activity.appName)
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.7))
                .lineLimit(1)
            
            Spacer()
            
            Text(activity.durationString)
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.7))
                .monospacedDigit()
        }
        .padding(.vertical, 1)
    }
}

/// Leaf row component for individual time entries
struct TimeEntryLeafRow: View {
    let timeEntry: TimeEntry
    let indentationLevel: CGFloat
    
    var body: some View {
        HStack {
            Spacer()
                .frame(width: indentationLevel)
            
            Spacer()
                .frame(width: 12)
            
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(timeEntry.title)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let notes = timeEntry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(Color.secondary.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 1) {
                Text(timeEntry.durationString)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .monospacedDigit()
                
                Text("Manual")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.6))
                    .italic()
            }
        }
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(4)
    }
}

#Preview {
    let sampleActivity = Activity(
        appName: "Safari",
        appBundleId: "com.apple.Safari",
        appTitle: "GitHub - Example Repository",
        duration: 300, // 5 minutes
        startTime: Date(),
        endTime: Date().addingTimeInterval(300),
        icon: "safari"
    )
    
    let sampleTimeEntry = TimeEntry(
        projectId: "project1",
        title: "Code Review Session",
        notes: "Reviewing pull requests",
        startTime: Date(),
        endTime: Date().addingTimeInterval(1800) // 30 minutes
    )
    
    let sampleGroup = ActivityHierarchyGroup(
        name: "Development Project",
        level: .project,
        children: [
            ActivityHierarchyGroup(
                name: "Web Development",
                level: .subproject,
                children: [
                    ActivityHierarchyGroup(
                        name: "Morning Session",
                        level: .timeEntry,
                        children: [
                            ActivityHierarchyGroup(
                                name: "9:00 AM - 10:00 AM",
                                level: .timePeriod,
                                children: [
                                    ActivityHierarchyGroup(
                                        name: "Safari",
                                        level: .appName,
                                        children: [
                                            ActivityHierarchyGroup(
                                                name: "github.com",
                                                level: .appTitle,
                                                activities: [sampleActivity]
                                            )
                                        ]
                                    ),
                                    ActivityHierarchyGroup(
                                        name: "Manual Time Entries",
                                        level: .appName,
                                        children: [
                                            ActivityHierarchyGroup(
                                                name: "Code Review Session",
                                                level: .appTitle,
                                                timeEntries: [sampleTimeEntry]
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
