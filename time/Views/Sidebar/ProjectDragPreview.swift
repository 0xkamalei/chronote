import SwiftUI

/// A performance-optimized visual component that provides a custom drag preview for Project drag operations
struct ProjectDragPreview: View {
    let project: Project
    let isDragging: Bool

    private let shadowRadius: CGFloat
    private let shadowOffset: CGSize
    private let strokeOpacity: Double
    private let strokeWidth: CGFloat

    init(project: Project, isDragging: Bool = false) {
        self.project = project
        self.isDragging = isDragging

        shadowRadius = isDragging ? 8 : 4
        shadowOffset = CGSize(width: 0, height: isDragging ? 4 : 2)
        strokeOpacity = isDragging ? 0.6 : 0.3
        strokeWidth = isDragging ? 2 : 1
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(project.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                )
                .drawingGroup() // Optimize rendering for better performance

            Text(project.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(
                    color: .black.opacity(isDragging ? 0.2 : 0.1),
                    radius: shadowRadius,
                    x: shadowOffset.width,
                    y: shadowOffset.height
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(project.color.opacity(strokeOpacity), lineWidth: strokeWidth)
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .drawingGroup() // Optimize entire view for better drag performance
    }
}

#Preview {
    VStack(spacing: 16) {
        ProjectDragPreview(project: Project(name: "Root Project", color: .blue))
        ProjectDragPreview(project: Project(name: "Other Project", color: .green))
        ProjectDragPreview(project: Project(name: "Another Project", color: .orange))
    }
    .padding()
}
