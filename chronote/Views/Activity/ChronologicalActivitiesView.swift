import SwiftData
import SwiftUI

/// Chronological view displaying activities in a flat, time-ordered list
struct ChronologicalActivitiesView: View {
    let activities: [Activity]
    
    @State private var sortedActivities: [Activity] = []
    @State private var selection: Set<UUID> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activities.isEmpty {
                emptyState
            } else {
                // Chronological list
                List(selection: $selection) {
                    ForEach(sortedActivities, id: \.id) { activity in
                        ChronologicalActivityRow(activity: activity, isSelected: selection.contains(activity.id))
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            updateSortedActivities()
        }
        .onChange(of: activities) {
            updateSortedActivities()
        }
    }
    
    // MARK: - Views
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No activities recorded")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Activities will appear here in chronological order")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Methods
    
    private func updateSortedActivities() {
        // Sort activities by start time in descending order (newest first)
        sortedActivities = activities.sorted { $0.startTime > $1.startTime }
    }
}

/// Individual row for chronological activity display
struct ChronologicalActivityRow: View {
    let activity: Activity
    let isSelected: Bool
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Duration column (like "2m")
            Text(formatShortDuration())
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 30, alignment: .leading)
            
            // Date and time range in single line
            Text(formatDateTimeRange())
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)
            
            // App info with icon and name
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    AppIconView(bundleId: activity.appBundleId, size: 16)
                    
                    Text(activity.appName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    if let projectId = activity.projectId {
                        Text(projectId)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .padding(.horizontal, 4)
                            .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(activity.appBundleId)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.8))
                    .lineLimit(1)
                
                if let title = activity.appTitle {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
                
                if let url = activity.webUrl {
                    Text(url)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white : .blue)
                        .lineLimit(1)
                }
                
                if let path = activity.filePath {
                    Text(path)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                if let domain = activity.domain {
                    Text("Domain: \(domain)")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
                
                if let icon = activity.icon {
                     Text("Icon: \(icon)")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Additional details or status
            if activity.isActive {
                Text("Active")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatDateTimeRange() -> String {
        let startStr = dateTimeFormatter.string(from: activity.startTime)
        
        if let endTime = activity.endTime {
            let endStr = timeFormatter.string(from: endTime)
            return "\(startStr)-\(endStr)"
        } else {
            return "\(startStr)-now"
        }
    }
    
    private func formatShortDuration() -> String {
        let duration = activity.calculatedDuration
        
        if duration < 60 {
            return "\(Int(duration))s"
        }
        
        let totalMinutes = Int(duration / 60)
        
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h\(minutes)m"
        }
    }
    
    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.5)
    }
}

#Preview {
        let mockActivities = [
            Activity(
                appName: "Finder",
                appBundleId: "com.apple.finder",
                appTitle: "7% Code, 6% LDX",
                duration: 3600,
                startTime: Date().addingTimeInterval(-7200),
                endTime: Date().addingTimeInterval(-3600)
            ),
            Activity(
                appName: "LDX",
                appBundleId: "com.ldx.app",
                duration: 1800,
                startTime: Date().addingTimeInterval(-3600),
                endTime: Date().addingTimeInterval(-1800)
            ),
            Activity(
                appName: "Code",
                appBundleId: "com.microsoft.vscode",
                duration: 900,
                startTime: Date().addingTimeInterval(-1800),
                endTime: Date().addingTimeInterval(-900)
            )
        ]
        
        ChronologicalActivitiesView(activities: mockActivities)
            .frame(width: 800, height: 600)
    }

    #Preview("Row") {
        let activity = Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            duration: 1800,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800)
        )
        
        VStack {
            ChronologicalActivityRow(activity: activity, isSelected: false)
            ChronologicalActivityRow(activity: activity, isSelected: true)
        }
        .padding()
        .frame(width: 500)
    }