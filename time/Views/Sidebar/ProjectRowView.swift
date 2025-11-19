import os
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct ProjectRowView: View {
    var project: Project
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectManager: ProjectManager

    private let level: Int

    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var dragStartTime: Date?

    @State private var isDropTarget = false
    @State private var dropPosition: DropPosition = .invalid
    @State private var showDropIndicator = false
    @State private var dropFeedbackDebouncer: Timer?

    @State private var cachedRowHeight: CGFloat = 28
    @State private var cachedIndentationWidth: CGFloat = 0

    init(project: Project, level: Int = 0) {
        self.project = project
        self.level = level
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectLabel

            if !project.children.isEmpty && project.isExpanded {
                ForEach(project.children) { child in
                    ProjectRowView(project: child, level: level + 1)
                }
                .onMove { source, destination in
                    moveChildProjects(from: source, to: destination)
                }
            }
        }
    }

    private var projectLabelContent: some View {
        HStack(spacing: 8) {
            indentationView
            expandCollapseIndicator
            colorIndicator
            projectNameText
            Spacer()
            statusIndicators
        }
    }

    private var indentationView: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< level, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 16)
            }
        }
    }

    private var colorIndicator: some View {
        Circle()
            .fill(project.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
            )
    }

    private var projectNameText: some View {
        Text(project.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var statusIndicators: some View {
        HStack(spacing: 4) {
            if !project.children.isEmpty {
                Text("\(project.children.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    )
            }
        }
    }

    private var projectLabel: some View {
        projectLabelContent
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(projectBackground)
            .modifier(DragModifier(isDragging: isDragging, dragOffset: dragOffset))
            .modifier(ProjectLabelInteractionModifier(
                project: project,
                appState: appState,
                accessibilityLabel: accessibilityLabel,
                accessibilityHint: accessibilityHint,
                accessibilityValue: accessibilityValue,
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded
            ))
            // Note: Drag and drop simplified for MVP - requires Transferable protocol
            // .dropDestination(for: Project.self) { droppedProjects, location in
            //     handleProjectDrop(droppedProjects: droppedProjects, at: location)
            // } isTargeted: { isTargeted in
            //     handleDropTargetChange(isTargeted)
            // }
            .overlay(alignment: .top) {
                dropIndicatorTop
            }
            .overlay(alignment: .bottom) {
                dropIndicatorBottom
            }
            .overlay {
                dropIndicatorInside
            }
    }

    private var dropIndicatorTop: some View {
        Group {
            if showDropIndicator && dropPosition == .above {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .opacity(0.8)
            }
        }
    }

    private var dropIndicatorBottom: some View {
        Group {
            if showDropIndicator && dropPosition == .below {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .opacity(0.8)
            }
        }
    }

    private var dropIndicatorInside: some View {
        Group {
            if showDropIndicator && dropPosition == .inside {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .opacity(0.6)
            }
        }
    }

    @ViewBuilder
    private var expandCollapseIndicator: some View {
        if !project.children.isEmpty {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    project.isExpanded.toggle()
                }
            }) {
                Image(systemName: project.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(project.isExpanded ? 0 : -90))
                    .animation(.easeInOut(duration: 0.2), value: project.isExpanded)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 12, height: 12)
        }
    }

    private var backgroundColorForProject: Color {
        if appState.isProjectSelected(project) {
            return Color.accentColor.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var projectBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(backgroundColorForProject)
    }

    private func moveChildProjects(from source: IndexSet, to destination: Int) {
        let projectsToReorder = projectManager.projects.filter { $0.parentID == project.id }.sorted { $0.sortOrder < $1.sortOrder }

        guard let sourceIndex = source.first,
              sourceIndex < projectsToReorder.count
        else {
            Logger.ui.warning("Invalid source index for project reorder operation")
            return
        }

        let projectToMove = projectsToReorder[sourceIndex]

        Task {
            do {
                try await projectManager.reorderProject(projectToMove, to: destination, in: project.id)
            } catch {
                Logger.ui.error("Failed to reorder project: \(error.localizedDescription)")
            }
        }
    }

    private func handleProjectDrop(droppedProjects: [Project], at location: CGPoint) -> Bool {
        guard let droppedProject = droppedProjects.first else { return false }

        if !validateDrop(droppedProject: droppedProject) {
            return false
        }

        let detectedPosition = getDropPosition(for: location)

        switch detectedPosition {
        case .above:
            return handleDropAbove(droppedProject: droppedProject)
        case .below:
            return handleDropBelow(droppedProject: droppedProject)
        case .inside:
            return handleDropInside(droppedProject: droppedProject)
        case .invalid:
            return false
        }
    }

    private func validateDrop(droppedProject: Project) -> Bool {
        if droppedProject.id == project.id {
            return false
        }

        if isProjectAncestor(droppedProject, of: project) {
            return false
        }

        return true
    }

    private func handleDropAbove(droppedProject: Project) -> Bool {
        let targetParentID = project.parentID
        let targetSortOrder = project.sortOrder

        Task {
            do {
                guard let project = projectManager.getProject(by: droppedProject.id) else {
                    Logger.ui.error("Project not found: \(droppedProject.id)")
                    return
                }

                let newParent = targetParentID != nil ? projectManager.getProject(by: targetParentID!) : nil

                try await projectManager.moveProject(project, to: newParent)
                try await projectManager.reorderProject(project, to: targetSortOrder, in: targetParentID)

                Logger.ui.info("Successfully moved project '\(project.name)' to position \(targetSortOrder)")
            } catch {
                Logger.ui.error("Failed to move project to position: \(error.localizedDescription)")
            }
        }
        return true
    }

    private func handleDropBelow(droppedProject: Project) -> Bool {
        let targetParentID = project.parentID
        let targetSortOrder = project.sortOrder + 1

        Task {
            do {
                guard let project = projectManager.getProject(by: droppedProject.id) else {
                    Logger.ui.error("Project not found: \(droppedProject.id)")
                    return
                }

                let newParent = targetParentID != nil ? projectManager.getProject(by: targetParentID!) : nil

                try await projectManager.moveProject(project, to: newParent)
                try await projectManager.reorderProject(project, to: targetSortOrder, in: targetParentID)

                Logger.ui.info("Successfully moved project '\(project.name)' to position \(targetSortOrder)")
            } catch {
                Logger.ui.error("Failed to move project to position: \(error.localizedDescription)")
            }
        }
        return true
    }

    private func handleDropInside(droppedProject: Project) -> Bool {
        Task {
            do {
                guard let project = projectManager.getProject(by: droppedProject.id) else {
                    Logger.ui.error("Project not found: \(droppedProject.id)")
                    return
                }

                let newParent = projectManager.getProject(by: self.project.id)
                try await projectManager.moveProject(project, to: newParent)

                Logger.ui.info("Successfully moved project '\(project.name)' to new parent")
            } catch {
                Logger.ui.error("Failed to move project: \(error.localizedDescription)")
            }
        }
        return true
    }

    private func isProjectAncestor(_ potentialAncestor: Project, of project: Project) -> Bool {
        var current = project
        while let parentID = current.parentID {
            if parentID == potentialAncestor.id {
                return true
            }
            if let parent = projectManager.findProject(by: parentID) {
                current = parent
            } else {
                break
            }
        }
        return false
    }

    // MARK: - Performance Optimized Drag Handling

    /// Handles drag gesture changes with performance optimization
    private func handleDragChanged(_ value: DragGesture.Value) {
        let dragThreshold: CGFloat = 3.0
        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))

        if dragDistance > dragThreshold, !isDragging {
            isDragging = true
            dragStartTime = Date()

            #if canImport(UIKit)
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            #endif
        }

        if isDragging {
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                dragOffset = CGSize(
                    width: value.translation.width * 0.3, // Reduce movement for better control
                    height: value.translation.height * 0.3
                )
            }
        }
    }

    /// Handles drag gesture end with cleanup
    private func handleDragEnded(_: DragGesture.Value) {
        guard isDragging else { return }

        let dragDuration = dragStartTime.map { Date().timeIntervalSince($0) } ?? 0

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isDragging = false
            dragOffset = .zero
        }

        dragStartTime = nil

        #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        #endif

        Logger.ui.info("Drag completed in \(dragDuration, format: .fixed(precision: 2))s")
    }

    /// Handles drop target changes with debouncing for performance
    private func handleDropTargetChange(_ isTargeted: Bool) {
        dropFeedbackDebouncer?.invalidate()

        dropFeedbackDebouncer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.isDropTarget = isTargeted
                    self.showDropIndicator = isTargeted

                    if !isTargeted {
                        self.dropPosition = .invalid
                    }
                }
            }
        }
    }

    /// Optimized drop position calculation with caching
    private func getDropPosition(for location: CGPoint) -> DropPosition {
        let rowHeight = cachedRowHeight
        let topThreshold: CGFloat = rowHeight * 0.25
        let bottomThreshold: CGFloat = rowHeight * 0.75

        let newPosition: DropPosition

        if location.y < topThreshold {
            newPosition = .above
        } else if location.y > bottomThreshold {
            newPosition = .below
        } else {
            newPosition = project.canAcceptChildren ? .inside : .below
        }

        if newPosition != dropPosition {
            withAnimation(.easeInOut(duration: 0.1)) {
                dropPosition = newPosition
            }
        }

        return newPosition
    }

    // MARK: - Accessibility Support

    /// Comprehensive accessibility label for the project row
    private var accessibilityLabel: String {
        var label = "Project: \(project.name)"

        if level > 0 {
            label += ", level \(level + 1)"
        }

        if !project.children.isEmpty {
            label += ", \(project.children.count) child project\(project.children.count == 1 ? "" : "s")"
            label += project.isExpanded ? ", expanded" : ", collapsed"
        }

        if appState.isProjectSelected(project) {
            label += ", currently selected"
        }

        return label
    }

    /// Accessibility hint providing usage guidance
    private var accessibilityHint: String {
        var hints: [String] = []

        hints.append("Double tap to select")

        if !project.children.isEmpty {
            hints.append("Swipe up or down to expand or collapse")
        }

        hints.append("Long press for more options")
        hints.append("Drag to reorder or move to different parent")

        return hints.joined(separator: ". ")
    }

    /// Accessibility value providing current state information
    private var accessibilityValue: String {
        var values: [String] = []

        if appState.isProjectSelected(project) {
            values.append("Selected")
        }

        if isDragging {
            values.append("Being dragged")
        }

        if isDropTarget {
            values.append("Drop target")
        }

        return values.isEmpty ? "" : values.joined(separator: ", ")
    }
}

// MARK: - Drag Modifier

struct DragModifier: ViewModifier {
    let isDragging: Bool
    let dragOffset: CGSize

    func body(content: Content) -> some View {
        content
            .offset(dragOffset)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .opacity(isDragging ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: isDragging)
            .animation(.easeInOut(duration: 0.15), value: dragOffset)
    }
}

// MARK: - Project Label Interaction Modifier

struct ProjectLabelInteractionModifier: ViewModifier {
    let project: Project
    let appState: AppState
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityValue: String
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    func body(content: Content) -> some View {
        content
            // .draggable(project) {
            //     ProjectDragPreview(project: project, isDragging: true)
            // }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.selectProject(project)
                }
            }
            .contextMenu {
                ProjectRightClickMenu(project: project)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(appState.isProjectSelected(project) ? [.isSelected] : [])
            .accessibilityAction(.default) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.selectProject(project)
                }
            }
            .accessibilityAction(.showMenu) {}
    }
}
