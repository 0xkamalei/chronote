import AppKit
import SwiftData
import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @StateObject private var selectionManager = TimelineSelectionManager()
    @Environment(\.modelContext) private var modelContext

    private var timelineWidth: CGFloat {
        return viewModel.getTimelineWidth()
    }

    private var totalWidth: CGFloat {
        return viewModel.getTotalWidth()
    }

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

    private func colorForProject(_ project: Project?) -> Color {
        return project?.color ?? .gray
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 12) {
                // Time header row
                timeHeaderRow

                // Device activity row
                deviceActivityRow

                // Project row
                projectRow

                // Time entries row
                timeEntriesRow
            }
            .padding(.bottom)
        }
        .scrollIndicators(.visible, axes: .horizontal)
        .contentMargins(.horizontal, 0)
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading timeline...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .alert("Timeline Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Unknown error")
        }
    }

    // MARK: - Timeline Rows

    private var timeHeaderRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TIME")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text(viewModel.timeScale.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 140, alignment: .leading)
            .padding(.leading, 16)

            timeScaleHeaders
        }
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var timeScaleHeaders: some View {
        switch viewModel.timeScale {
        case .hours:
            ForEach(0..<24, id: \.self) { (hour: Int) in
                let timeString = String(format: "%02d:00", hour)
                VStack(spacing: 2) {
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 8)
                }
                .frame(width: 80 * viewModel.timelineScale, alignment: .leading)
            }

        case .days:
            ForEach(0..<7, id: \.self) { (day: Int) in
                let date = Calendar.current.date(byAdding: .day, value: day, to: viewModel.selectedDateRange.start) ?? viewModel.selectedDateRange.start

                VStack(spacing: 2) {
                    Text(date, format: .dateTime.weekday(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 8)
                }
                .frame(width: 120 * viewModel.timelineScale, alignment: .leading)
            }

        case .weeks:
            ForEach(0..<4, id: \.self) { (week: Int) in
                let date = Calendar.current.date(byAdding: .weekOfYear, value: week, to: viewModel.selectedDateRange.start) ?? viewModel.selectedDateRange.start

                VStack(spacing: 2) {
                    Text("Week \(week + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 8)
                }
                .frame(width: 200 * viewModel.timelineScale, alignment: .leading)
            }
        }
    }

    private var deviceActivityRow: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DEVICE ACTIVITY")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("App Usage")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 140, alignment: .leading)
            .padding(.leading, 16)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)]), startPoint: .leading, endPoint: .trailing))
                    .frame(width: timelineWidth, height: 30)
                    .cornerRadius(5)

                ForEach(viewModel.activities, id: \.id) { activity in
                    let position = viewModel.timeToPosition(activity.startTime)
                    let width = viewModel.durationToWidth(activity.calculatedDuration)
                    let appColor = colorForApp(activity.appBundleId)

                    Rectangle()
                        .fill(appColor.opacity(0.6))
                        .frame(width: width * timelineWidth, height: 25)
                        .offset(x: position * timelineWidth)
                        .cornerRadius(3)
                }
            }
        }
    }

    private var projectRow: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROJECTS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("Project Timeline")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 140, alignment: .leading)
            .padding(.leading, 16)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)]), startPoint: .leading, endPoint: .trailing))
                    .frame(width: timelineWidth, height: 30)
                    .cornerRadius(5)

                // Placeholder project blocks
                ForEach(Array(viewModel.projects.prefix(3).enumerated()), id: \.element.id) { index, project in
                    let position = Double(index) * 0.25 + 0.1
                    let width = 0.15

                    Rectangle()
                        .fill(project.color.opacity(0.6))
                        .frame(width: width * timelineWidth, height: 25)
                        .offset(x: position * timelineWidth)
                        .cornerRadius(3)
                }
            }
        }
    }

    private var timeEntriesRow: some View {
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

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)]), startPoint: .leading, endPoint: .trailing))
                    .frame(width: timelineWidth, height: 30)
                    .cornerRadius(5)

                ForEach(viewModel.timeEntries, id: \.id) { entry in
                    let position = viewModel.timeToPosition(entry.startTime)
                    let width = viewModel.durationToWidth(entry.calculatedDuration)
                    let projectColor = viewModel.projects.first { $0.id == entry.projectId }?.color ?? .blue

                    Rectangle()
                        .fill(projectColor.opacity(0.8))
                        .frame(width: width * timelineWidth, height: 25)
                        .offset(x: position * timelineWidth)
                        .cornerRadius(3)
                }
            }
        }
    }
}

// MARK: - Selection Manager

@MainActor
class TimelineSelectionManager: ObservableObject {
    @Published var selectedActivities: Set<UUID> = []
    @Published var selectedTimeEntries: Set<UUID> = []
    @Published var isSelectionMode = false

    func toggleActivitySelection(_ activity: Activity) {
        if selectedActivities.contains(activity.id) {
            selectedActivities.remove(activity.id)
        } else {
            selectedActivities.insert(activity.id)
        }

        isSelectionMode = !selectedActivities.isEmpty || !selectedTimeEntries.isEmpty
    }

    func toggleTimeEntrySelection(_ timeEntry: TimeEntry) {
        if selectedTimeEntries.contains(timeEntry.id) {
            selectedTimeEntries.remove(timeEntry.id)
        } else {
            selectedTimeEntries.insert(timeEntry.id)
        }

        isSelectionMode = !selectedActivities.isEmpty || !selectedTimeEntries.isEmpty
    }

    func clearSelection() {
        selectedActivities.removeAll()
        selectedTimeEntries.removeAll()
        isSelectionMode = false
    }

    func selectAll(activities: [Activity], timeEntries: [TimeEntry]) {
        selectedActivities = Set(activities.map { $0.id })
        selectedTimeEntries = Set(timeEntries.map { $0.id })
        isSelectionMode = true
    }
}

#Preview {
    TimelineView()
}
