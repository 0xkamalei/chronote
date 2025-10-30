import AppKit // Added AppKit import to access NSColor
import SwiftUI
import SwiftData

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
        .timelineScrollZoom { zoomFactor in
            viewModel.zoomTimeline(scale: viewModel.timelineScale * zoomFactor)
        }
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
        .focusable()
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                TimeScaleControls(
                    currentTimeScale: viewModel.timeScale,
                    onTimeScaleChange: { scale in
                        viewModel.setTimeScale(scale)
                    }
                )
                
                TimelineZoomControls(
                    currentScale: viewModel.timelineScale,
                    onZoomIn: {
                        viewModel.zoomTimeline(scale: viewModel.timelineScale * 1.2)
                    },
                    onZoomOut: {
                        viewModel.zoomTimeline(scale: viewModel.timelineScale / 1.2)
                    },
                    onResetZoom: {
                        viewModel.zoomTimeline(scale: 1.0)
                    }
                )
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            TimelineSelectionToolbar(
                selectionManager: selectionManager,
                onAssignToProject: {
                    // TODO: Implement batch project assignment
                },
                onDelete: {
                    handleDeleteSelected()
                },
                onClearSelection: {
                    selectionManager.clearSelection()
                }
            )
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Interaction Handlers
    
    private func handleActivityTap(_ activity: Activity) {
        if selectionManager.isSelectionMode {
            selectionManager.toggleActivitySelection(activity)
        } else {
            // TODO: Implement activity editing
            print("Activity tapped: \(activity.appName)")
        }
    }
    
    private func handleActivityContextMenu(_ activity: Activity) {
        // TODO: Implement activity context menu actions
        print("Activity context menu: \(activity.appName)")
    }
    
    private func handleActivityDragStart(_ activity: Activity) {
        print("Activity drag started: \(activity.appName)")
    }
    
    private func handleTimeEntryTap(_ entry: TimeEntry) {
        if selectionManager.isSelectionMode {
            selectionManager.toggleTimeEntrySelection(entry)
        } else {
            // TODO: Implement time entry editing
            print("Time entry tapped: \(entry.title)")
        }
    }
    
    private func handleTimeEntryContextMenu(_ entry: TimeEntry) {
        // TODO: Implement time entry context menu actions
        print("Time entry context menu: \(entry.title)")
    }
    
    private func handleTimeEntryResize(_ entry: TimeEntry, startTime: Date, endTime: Date) {
        Task {
            await viewModel.updateTimeEntryDuration(timeEntry: entry, newStartTime: startTime, newEndTime: endTime)
        }
    }
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow:
            // Navigate to previous day
            let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDateRange.start) ?? viewModel.selectedDateRange.start
            viewModel.setDateRange(DateInterval(start: Calendar.current.startOfDay(for: previousDay), duration: 24 * 60 * 60))
            return .handled
            
        case .rightArrow:
            // Navigate to next day
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDateRange.start) ?? viewModel.selectedDateRange.start
            viewModel.setDateRange(DateInterval(start: Calendar.current.startOfDay(for: nextDay), duration: 24 * 60 * 60))
            return .handled
            
        case "=" where keyPress.modifiers.contains(.command):
            // Zoom in (Cmd + =)
            viewModel.zoomTimeline(scale: viewModel.timelineScale * 1.2)
            return .handled

        case "-" where keyPress.modifiers.contains(.command):
            // Zoom out (Cmd + -)
            viewModel.zoomTimeline(scale: viewModel.timelineScale / 1.2)
            return .handled

        case "0" where keyPress.modifiers.contains(.command):
            // Reset zoom (Cmd + 0)
            viewModel.zoomTimeline(scale: 1.0)
            return .handled
            
        case .space:
            // Refresh data
            Task {
                await viewModel.refreshData()
            }
            return .handled
            
        case .escape:
            // Clear selection
            selectionManager.clearSelection()
            return .handled
            
        case "a" where keyPress.modifiers.contains(.command):
            // Select all (Cmd + A)
            selectionManager.selectAll(activities: viewModel.activities, timeEntries: viewModel.timeEntries)
            return .handled
            
        case .delete, .deleteForward:
            // Delete selected items
            handleDeleteSelected()
            return .handled
            
        default:
            return .ignored
        }
    }
    
    private func handleDeleteSelected() {
        Task {
            // Delete selected time entries
            for entryId in selectionManager.selectedTimeEntries {
                if let entry = viewModel.timeEntries.first(where: { $0.id == entryId }) {
                    await viewModel.deleteTimeEntry(entry)
                }
            }
            
            // Clear selection after deletion
            selectionManager.clearSelection()
        }
    }
}

// MARK: - Time Scale Controls Component

struct TimeScaleControls: View {
    let currentTimeScale: TimeScale
    let onTimeScaleChange: (TimeScale) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimeScale.allCases, id: \.self) { scale in
                Button(scale.displayName) {
                    onTimeScaleChange(scale)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(currentTimeScale == scale ? Color.accentColor : Color.clear)
                )
                .foregroundStyle(currentTimeScale == scale ? .white : .primary)
                .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(radius: 2)
        )
        .opacity(isHovered ? 1.0 : 0.7)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Zoom Controls Component

struct TimelineZoomControls: View {
    let currentScale: CGFloat
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onResetZoom: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Zoom level indicator
            Text("\(Int(currentScale * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40)
            
            // Zoom out button
            Button(action: onZoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .disabled(currentScale <= 0.1)
            
            // Reset zoom button
            Button(action: onResetZoom) {
                Image(systemName: "1.magnifyingglass")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            // Zoom in button
            Button(action: onZoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .disabled(currentScale >= 5.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(radius: 2)
        )
        .opacity(isHovered ? 1.0 : 0.7)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Scroll Wheel Zoom Support

struct TimelineScrollZoomModifier: ViewModifier {
    let onZoom: (CGFloat) -> Void

    func body(content: Content) -> some View {
        // onScrollWheel is not available in macOS 14.4
        // TODO: Implement zoom support using an alternative method
        content
    }
}

extension View {
    func timelineScrollZoom(onZoom: @escaping (CGFloat) -> Void) -> some View {
        self.modifier(TimelineScrollZoomModifier(onZoom: onZoom))
    }
}

// MARK: - Drag and Drop Components

struct ActivityDragPreview: View {
    let activity: Activity?
    
    var body: some View {
        if let activity = activity {
            HStack(spacing: 8) {
                Image(systemName: activity.icon.isEmpty ? "app.fill" : activity.icon)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.appName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(activity.durationString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.regularMaterial)
                    .shadow(radius: 4)
            )
        } else {
            EmptyView()
        }
    }
}

// MARK: - Selection and Batch Operations

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

// MARK: - Selection Toolbar

struct TimelineSelectionToolbar: View {
    let selectionManager: TimelineSelectionManager
    let onAssignToProject: () -> Void
    let onDelete: () -> Void
    let onClearSelection: () -> Void
    
    var body: some View {
        if selectionManager.isSelectionMode {
            HStack(spacing: 12) {
                Text("\(selectionManager.selectedActivities.count + selectionManager.selectedTimeEntries.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Assign to Project") {
                    onAssignToProject()
                }
                .buttonStyle(.bordered)
                
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.bordered)
                
                Button("Clear Selection") {
                    onClearSelection()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
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
                .frame(width: 80 * viewModel.timelineScale, alignment: .leading)
            }
            
        case .days:
            ForEach(Array(0..<7), id: \.self) { day in
                let date = Calendar.current.date(byAdding: .day, value: day, to: viewModel.selectedDateRange.start) ?? viewModel.selectedDateRange.start
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E d"
                
                VStack(spacing: 2) {
                    Text(dayFormatter.string(from: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 8)
                }
                .frame(width: 120 * viewModel.timelineScale, alignment: .leading)
            }
            
        case .weeks:
            ForEach(Array(0..<4), id: \.self) { week in
                let date = Calendar.current.date(byAdding: .weekOfYear, value: week, to: viewModel.selectedDateRange.start) ?? viewModel.selectedDateRange.start
                let weekFormatter = DateFormatter()
                weekFormatter.dateFormat = "MMM d"
                
                VStack(spacing: 2) {
                    Text("Week \(week + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(weekFormatter.string(from: date))
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
    
                    TimeBlock(
                        color: appColor.opacity(selectionManager.selectedActivities.contains(activity.id) ? 0.8 : 0.6), 
                        position: position, 
                        width: width, 
                        iconName: activity.icon.isEmpty ? "app.fill" : activity.icon,
                        activity: activity,
                        onTap: { activity in
                            handleActivityTap(activity)
                        },
                        onContextMenu: { activity in
                            handleActivityContextMenu(activity)
                        },
                        onDragStart: { activity in
                            handleActivityDragStart(activity)
                        }
                    )
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
                
                // Project blocks would be rendered here based on activity-project assignments
                // This is a placeholder implementation since we don't have project assignments yet
                ForEach(Array(viewModel.projects.prefix(3).enumerated()), id: \.element.id) { index, project in
                    let position = Double(index) * 0.25 + 0.1
                    let width = 0.15
                    
                    TimeBlock(
                        color: project.color.opacity(0.6),
                        position: position,
                        width: width,
                        iconName: "folder"
                    )
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
                    
                    TimeEntryBlock(
                        position: position,
                        width: width,
                        color: selectionManager.selectedTimeEntries.contains(entry.id) ? projectColor : projectColor.opacity(0.8),
                        title: entry.title,
                        timeEntry: entry,
                        onTap: { entry in
                            handleTimeEntryTap(entry)
                        },
                        onContextMenu: { entry in
                            handleTimeEntryContextMenu(entry)
                        },
                        onResize: { entry, startTime, endTime in
                            handleTimeEntryResize(entry, startTime: startTime, endTime: endTime)
                        }
                    )
                }
                
                // Add button for creating new time entries
                TimeEntryAddButton(
                    timelineWidth: timelineWidth,
                    onAddEntry: { startTime, endTime in
                        let _ = viewModel.createTimeEntryAt(startTime: startTime, endTime: endTime)
                    }
                )
            }
        }
    }
struct TimeBlock: View {
    let color: Color
    let position: Double // 0-1 position on timeline
    let width: Double // 0-1 width on timeline
    let iconName: String? // Optional icon name
    let activity: Activity?
    let onTap: ((Activity) -> Void)?
    let onContextMenu: ((Activity) -> Void)?
    let onDragStart: ((Activity) -> Void)?
    
    @State private var isHovered = false
    @State private var showTooltip = false
    @State private var isDragging = false
    
    init(color: Color, position: Double, width: Double, iconName: String? = nil, activity: Activity? = nil, onTap: ((Activity) -> Void)? = nil, onContextMenu: ((Activity) -> Void)? = nil, onDragStart: ((Activity) -> Void)? = nil) {
        self.color = color
        self.position = position
        self.width = width
        self.iconName = iconName
        self.activity = activity
        self.onTap = onTap
        self.onContextMenu = onContextMenu
        self.onDragStart = onDragStart
    }
    
    var body: some View {
        GeometryReader { geo in
            let blockWidth = width * geo.size.width
            let blockX = position * geo.size.width
            let centerX = blockX + blockWidth / 2
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(isHovered ? 0.9 : 0.8), 
                            color.opacity(isHovered ? 0.5 : 0.4)
                        ]), 
                        startPoint: .top, 
                        endPoint: .bottom
                    ))
                    .frame(width: blockWidth, height: 30)
                    .position(x: centerX, y: 15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(color.opacity(isHovered ? 0.6 : 0.3), lineWidth: isHovered ? 2 : 1)
                            .frame(width: blockWidth, height: 30)
                            .position(x: centerX, y: 15)
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .opacity(isDragging ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
                
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
            .onHover { hovering in
                isHovered = hovering
                showTooltip = hovering
            }
            .onTapGesture {
                if let activity = activity, let onTap = onTap {
                    onTap(activity)
                }
            }
            .contextMenu {
                if let activity = activity {
                    TimeBlockContextMenu(activity: activity, onContextAction: onContextMenu)
                }
            }
            .draggable(activity ?? Activity(appName: "", appBundleId: "", duration: 0, startTime: Date(), icon: "")) {
                ActivityDragPreview(activity: activity)
            }
            .onDrag {
                isDragging = true
                if let activity = activity {
                    onDragStart?(activity)
                }
                return NSItemProvider(object: activity?.id.uuidString as NSString? ?? "" as NSString)
            }
            .overlay(alignment: .top) {
                if showTooltip, let activity = activity {
                    TimeBlockTooltip(activity: activity)
                        .offset(y: -40)
                        .zIndex(1000)
                }
            }
        }
        .frame(height: 30)
    }
}

struct TimeEntryBlock: View {
    let position: Double // 0-1 position on timeline
    let width: Double // 0-1 width on timeline
    let color: Color
    let title: String
    let timeEntry: TimeEntry?
    let onTap: ((TimeEntry) -> Void)?
    let onContextMenu: ((TimeEntry) -> Void)?
    let onResize: ((TimeEntry, Date, Date) -> Void)?
    
    @State private var isHovered = false
    @State private var showTooltip = false
    @State private var isResizing = false
    @State private var resizeStartX: CGFloat = 0
    @State private var resizeEndX: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let blockWidth = width * geo.size.width
            let blockX = position * geo.size.width
            let centerX = blockX + blockWidth / 2
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(isHovered ? 0.9 : 0.8), 
                            color.opacity(isHovered ? 0.5 : 0.4)
                        ]), 
                        startPoint: .top, 
                        endPoint: .bottom
                    ))
                    .frame(width: blockWidth, height: 30)
                    .position(x: centerX, y: 15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(color.opacity(isHovered ? 0.6 : 0.3), lineWidth: isHovered ? 2 : 1)
                            .frame(width: blockWidth, height: 30)
                            .position(x: centerX, y: 15)
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                
                if blockWidth > 40 { // Only show text if block is wide enough
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .position(x: centerX, y: 15)
                }
                
                // Resize handles
                if isHovered && blockWidth > 20 {
                    // Left resize handle
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 4, height: 30)
                        .position(x: blockX + 2, y: 15)
                        .cursor(.resizeLeftRight)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isResizing = true
                                    resizeStartX = value.location.x
                                }
                                .onEnded { value in
                                    handleLeftResize(value, geo: geo)
                                    isResizing = false
                                }
                        )
                    
                    // Right resize handle
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 4, height: 30)
                        .position(x: blockX + blockWidth - 2, y: 15)
                        .cursor(.resizeLeftRight)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isResizing = true
                                    resizeEndX = value.location.x
                                }
                                .onEnded { value in
                                    handleRightResize(value, geo: geo)
                                    isResizing = false
                                }
                        )
                }
            }
            .onHover { hovering in
                isHovered = hovering
                showTooltip = hovering
            }
            .onTapGesture {
                if let timeEntry = timeEntry, let onTap = onTap {
                    onTap(timeEntry)
                }
            }
            .contextMenu {
                if let timeEntry = timeEntry {
                    TimeEntryContextMenu(timeEntry: timeEntry, onContextAction: onContextMenu)
                }
            }
            .overlay(alignment: .top) {
                if showTooltip, let timeEntry = timeEntry {
                    TimeEntryTooltip(timeEntry: timeEntry)
                        .offset(y: -40)
                        .zIndex(1000)
                }
            }
        }
        .frame(height: 30)
    }
    
    private func handleLeftResize(_ value: DragGesture.Value, geo: GeometryProxy) {
        guard let timeEntry = timeEntry, let onResize = onResize else { return }
        
        let totalWidth = geo.size.width
        let newPosition = max(0, min(1, value.location.x / totalWidth))
        
        // Calculate new start time based on position
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: timeEntry.startTime)
        let dayDuration = 24 * 60 * 60.0
        let newStartTime = startOfDay.addingTimeInterval(newPosition * dayDuration)
        
        // Ensure minimum duration of 1 minute
        let minEndTime = newStartTime.addingTimeInterval(60)
        let endTime = max(minEndTime, timeEntry.endTime)
        
        onResize(timeEntry, newStartTime, endTime)
    }
    
    private func handleRightResize(_ value: DragGesture.Value, geo: GeometryProxy) {
        guard let timeEntry = timeEntry, let onResize = onResize else { return }
        
        let totalWidth = geo.size.width
        let currentEndPosition = (position + width)
        let dragDelta = value.translation.x / totalWidth
        let newEndPosition = max(position + 0.01, min(1, currentEndPosition + dragDelta)) // Minimum 1% width
        
        // Calculate new end time based on position
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: timeEntry.startTime)
        let dayDuration = 24 * 60 * 60.0
        let newEndTime = startOfDay.addingTimeInterval(newEndPosition * dayDuration)
        
        // Ensure minimum duration of 1 minute
        let minEndTime = timeEntry.startTime.addingTimeInterval(60)
        let endTime = max(minEndTime, newEndTime)
        
        onResize(timeEntry, timeEntry.startTime, endTime)
    }
}

struct TimeEntryTooltip: View {
    let timeEntry: TimeEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeEntry.title)
                .font(.caption)
                .fontWeight(.medium)
            
            if let notes = timeEntry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(formatTime(timeEntry.startTime))
                Text("–")
                Text(formatTime(timeEntry.endTime))
                Spacer()
                Text(timeEntry.durationString)
                    .fontWeight(.medium)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            
            if let projectId = timeEntry.projectId {
                HStack {
                    Image(systemName: "folder")
                        .font(.caption2)
                    Text("Project: \(projectId)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.regularMaterial)
                .shadow(radius: 4)
        )
        .frame(maxWidth: 200)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TimeEntryContextMenu: View {
    let timeEntry: TimeEntry
    let onContextAction: ((TimeEntry) -> Void)?
    
    var body: some View {
        Group {
            Button("Edit Time Entry") {
                onContextAction?(timeEntry)
            }
            
            Button("Assign to Project") {
                // TODO: Implement project assignment
            }
            
            Divider()
            
            Button("Duplicate Entry") {
                // TODO: Implement duplication
            }
            
            Button("Copy Details") {
                copyTimeEntryDetails()
            }
            
            Divider()
            
            Button("Delete Entry", role: .destructive) {
                // TODO: Implement delete functionality
            }
        }
    }
    
    private func copyTimeEntryDetails() {
        let details = """
        Title: \(timeEntry.title)
        Duration: \(timeEntry.durationString)
        Time: \(formatTime(timeEntry.startTime)) - \(formatTime(timeEntry.endTime))
        \(timeEntry.notes ?? "")
        """
        
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(details, forType: .string)
        #endif
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TimeEntryAddButton: View {
    let timelineWidth: CGFloat
    let onAddEntry: (Date, Date) -> Void
    
    var body: some View {
        GeometryReader { geo in
            // Add buttons at regular intervals for creating new entries
            ForEach(Array(stride(from: 0, to: 24, by: 2)), id: \.self) { hour in
                let position = Double(hour) / 24.0
                let buttonX = position * geo.size.width
                
                Button(action: {
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let startTime = today.addingTimeInterval(Double(hour) * 3600)
                    let endTime = startTime.addingTimeInterval(3600) // 1 hour duration
                    onAddEntry(startTime, endTime)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .position(x: buttonX, y: 15)
                .opacity(0.6)
                .onHover { isHovered in
                    // Could add hover effects here
                }
            }
        }
        .frame(height: 30)
    }
}

// MARK: - Tooltip and Context Menu Components

struct TimeBlockTooltip: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: activity.icon.isEmpty ? "app.fill" : activity.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(activity.appName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let windowTitle = activity.windowTitle, !windowTitle.isEmpty {
                Text(windowTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(formatTime(activity.startTime))
                Text("–")
                Text(formatTime(activity.endTime ?? Date()))
                Spacer()
                Text(activity.durationString)
                    .fontWeight(.medium)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            
            if let url = activity.url, !url.isEmpty {
                Text(url)
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.regularMaterial)
                .shadow(radius: 4)
        )
        .frame(maxWidth: 200)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TimeBlockContextMenu: View {
    let activity: Activity
    let onContextAction: ((Activity) -> Void)?
    
    var body: some View {
        Group {
            Button("Assign to Project") {
                onContextAction?(activity)
            }
            
            Button("Edit Activity") {
                // TODO: Implement edit functionality
            }
            
            Divider()
            
            Button("Copy Details") {
                copyActivityDetails()
            }
            
            if activity.isBrowserActivity {
                Button("Open URL") {
                    openURL()
                }
            }
            
            if activity.isDocumentActivity {
                Button("Show in Finder") {
                    showInFinder()
                }
            }
            
            Divider()
            
            Button("Delete Activity", role: .destructive) {
                // TODO: Implement delete functionality
            }
        }
    }
    
    private func copyActivityDetails() {
        let details = """
        App: \(activity.appName)
        Duration: \(activity.durationString)
        Time: \(formatTime(activity.startTime)) - \(formatTime(activity.endTime ?? Date()))
        \(activity.windowTitle ?? "")
        \(activity.url ?? "")
        """
        
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(details, forType: .string)
        #endif
    }
    
    private func openURL() {
        guard let urlString = activity.url, let url = URL(string: urlString) else { return }
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    private func showInFinder() {
        guard let path = activity.documentPath, let url = URL(string: path) else { return }
        #if canImport(AppKit)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        #endif
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
