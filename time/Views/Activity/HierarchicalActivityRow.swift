import SwiftUI

/// A row that displays a single level in the activity hierarchy with collapsible children
struct HierarchicalActivityRow: View {
    let group: ActivityHierarchyGroup

    @AppStorage("expandedHierarchyGroups") private var expandedGroupsData: String = ""
    @State private var isExpanded: Bool = false

    private var expandedGroupIds: Set<String> {
        Set(expandedGroupsData.split(separator: ",").map(String.init))
    }

    init(group: ActivityHierarchyGroup) {
        self.group = group
        let groupKey = "\(group.level)_\(group.name)"
        let isExpanded = UserDefaults.standard.string(forKey: "expandedHierarchyGroups")
            .map { $0.split(separator: ",").map(String.init).contains(groupKey) } ?? false
        _isExpanded = State(initialValue: isExpanded)
    }

    private var groupKey: String {
        return "\(group.level)_\(group.name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                // Expand/Collapse button
                if !group.children.isEmpty || !group.activities.isEmpty {
                    Button(action: toggleExpanded) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 16)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                        .frame(width: 16)
                        .foregroundColor(.secondary)
                        .opacity(0)
                }

                // Icon and name
                HStack(spacing: 8) {
                    Image(systemName: group.levelIcon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                        .frame(width: 18)

                    Text(group.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()
                }

                // Duration and activity count
                VStack(alignment: .trailing, spacing: 2) {
                    Text(group.durationString)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !group.activities.isEmpty {
                        Text("\(group.activities.count) items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(rowBackground)
            .contentShape(Rectangle())

            // Children rows
            if isExpanded && !group.children.isEmpty {
                Divider()
                    .padding(.leading, 44)

                ForEach(group.children, id: \.id) { child in
                    HierarchicalActivityRow(group: child)
                }
            }

            // Activity details (leaf level)
            if isExpanded && !group.activities.isEmpty {
                Divider()
                    .padding(.leading, 44)

                ForEach(group.activities, id: \.id) { activity in
                    ActivityDetailRow(activity: activity)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }

        // Save state to @AppStorage
        var expandedIds = expandedGroupIds
        if isExpanded {
            expandedIds.insert(groupKey)
        } else {
            expandedIds.remove(groupKey)
        }
        expandedGroupsData = expandedIds.joined(separator: ",")
    }

    private var iconColor: Color {
        switch group.level {
        case .project:
            return .blue
        case .subproject:
            return .cyan
        case .timeEntry:
            return .green
        case .timePeriod:
            return .orange
        case .appName:
            return .purple
        case .appTitle:
            return .gray
        }
    }

    private var rowBackground: Color {
        switch group.level {
        case .project:
            return isExpanded ? Color.blue.opacity(0.08) : .clear
        case .subproject:
            return isExpanded ? Color.cyan.opacity(0.05) : .clear
        case .timeEntry:
            return isExpanded ? Color.green.opacity(0.05) : .clear
        case .timePeriod:
            return isExpanded ? Color.orange.opacity(0.05) : .clear
        case .appName:
            return isExpanded ? Color.purple.opacity(0.05) : .clear
        case .appTitle:
            return Color.gray.opacity(0.02)
        }
    }
}

/// Row showing individual activity details
struct ActivityDetailRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            // Empty space for alignment
            Image(systemName: "minus")
                .font(.system(size: 12))
                .frame(width: 16)
                .opacity(0)

            // Activity details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(activity.appName)
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text(formatTimeRange())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(formatDuration(activity.calculatedDuration))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Helper Methods

    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let startStr = formatter.string(from: activity.startTime)
        let endStr = activity.endTime.map { formatter.string(from: $0) } ?? "now"

        return "\(startStr) - \(endStr)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    let mockActivity = Activity(
        appName: "Safari",
        appBundleId: "com.apple.Safari",
        duration: 3600,
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date()
    )

    VStack {
        HierarchicalActivityRow(
            group: ActivityHierarchyGroup(
                name: "My Project",
                level: .project,
                children: [],
                activities: [mockActivity]
            )
        )
    }
    .padding()
}
