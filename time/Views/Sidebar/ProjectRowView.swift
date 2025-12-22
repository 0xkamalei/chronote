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
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var dragStartTime: Date?

    @State private var isDropTarget = false
    @State private var dropPosition: DropPosition = .invalid
    @State private var showDropIndicator = false
    @State private var dropFeedbackDebouncer: Timer?

    @State private var cachedRowHeight: CGFloat = 28

    @State private var showingEditProject = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectLabel
        }
    }

    private var projectLabelContent: some View {
        HStack(spacing: 8) {
            colorIndicator
            projectNameText
            Spacer()
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

    private var projectLabel: some View {
        projectLabelContent
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(projectBackground)
            .modifier(DragModifier(isDragging: isDragging, dragOffset: dragOffset))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.selectProject(project)
                }
            }
            .contextMenu {
                Button("Edit Project", systemImage: "pencil") {
                    showingEditProject = true
                }

                Divider()

                Button("Delete Project", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
            .sheet(isPresented: $showingEditProject) {
                EditProjectView(
                    mode: .edit(project),
                    isPresented: $showingEditProject
                )
            }
            .confirmationDialog(
                "Delete Project",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteProject()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete '\(project.name)'? This action cannot be undone.")
            }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .local)
                    .onChanged(handleDragChanged)
                    .onEnded(handleDragEnded)
            )
            .overlay(alignment: .top) {
                dropIndicatorTop
            }
            .overlay(alignment: .bottom) {
                dropIndicatorBottom
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
            newPosition = .below
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

        if appState.isProjectSelected(project) {
            label += ", currently selected"
        }

        return label
    }

    /// Accessibility hint providing usage guidance
    private var accessibilityHint: String {
        var hints: [String] = []

        hints.append("Double tap to select")
        hints.append("Long press for more options")
        hints.append("Drag to reorder")

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

    private func deleteProject() {
        Task {
            do {
                // Clear selection if deleting selected project
                if appState.selectedProject?.id == project.id {
                    await MainActor.run { appState.clearSelection() }
                }
                try await projectManager.deleteProject(project)
            } catch {
                Logger.ui.error("Failed to delete project: \(error)")
            }
        }
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
// MARK: - Drop Position Enum

enum DropPosition: String {
    case above
    case below
    case inside
    case invalid
}
