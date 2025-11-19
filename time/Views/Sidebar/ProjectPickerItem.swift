import SwiftUI

struct ProjectPickerItem: View {
    let project: Project
    let level: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            projectRow

            ForEach(project.children.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { child in
                ProjectPickerItem(project: child, level: level + 1)
            }
        }
    }

    // MARK: - Private Views

    private var projectRow: some View {
        HStack(spacing: dynamicSpacing) {
            hierarchyIndentation

            hierarchyIndicator

            colorIndicator

            projectName

            Spacer(minLength: 8)

            statusIndicators
        }
        .font(.system(size: dynamicFontSize, weight: .regular, design: .default))
        .padding(.vertical, dynamicVerticalPadding)
        .tag(project as Project?)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) {}
    }

    private var hierarchyIndentation: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< level, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: dynamicIndentationWidth, height: 1)
                    .accessibilityHidden(true)
            }
        }
    }

    private var hierarchyIndicator: some View {
        Group {
            if level > 0 {
                Image(systemName: hierarchySymbol)
                    .font(.system(size: dynamicIconSize, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: dynamicIconFrameSize, height: dynamicIconFrameSize)
                    .accessibilityHidden(true) // Included in main accessibility label
            }
        }
    }

    private var hierarchySymbol: String {
        switch level {
        case 1:
            return "L.square"
        case 2:
            return "l.square"
        case 3:
            return "minus"
        default:
            return "circle.fill"
        }
    }

    private var colorIndicator: some View {
        Circle()
            .fill(project.color)
            .frame(width: dynamicColorIndicatorSize, height: dynamicColorIndicatorSize)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
            )
            .accessibilityHidden(true) // Color information included in accessibility label
    }

    private var projectName: some View {
        Text(project.name)
            .foregroundColor(.primary)
            .lineLimit(dynamicLineLimit)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .accessibilityHidden(true) // Included in main accessibility label
    }

    private var statusIndicators: some View {
        HStack(spacing: 2) {
            if !project.children.isEmpty {
                Image(systemName: "folder.fill")
                    .font(.system(size: dynamicStatusIconSize))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true) // Included in accessibility value
            }

            if level > 2 {
                Text("\(level)")
                    .font(.system(size: dynamicDepthIndicatorSize, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                    )
                    .accessibilityHidden(true) // Included in accessibility value
            }
        }
    }

    // MARK: - Dynamic Type Support

    private var dynamicFontSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 11
        case .medium:
            return 13
        case .large:
            return 15
        case .xLarge:
            return 17
        case .xxLarge:
            return 19
        case .xxxLarge:
            return 21
        case .accessibility1:
            return 23
        case .accessibility2:
            return 26
        case .accessibility3:
            return 30
        case .accessibility4:
            return 34
        case .accessibility5:
            return 38
        @unknown default:
            return 13
        }
    }

    private var dynamicSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 6 : 4
    }

    private var dynamicVerticalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 4 : 2
    }

    private var dynamicIndentationWidth: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:
            return 16
        case .large, .xLarge:
            return 18
        case .xxLarge, .xxxLarge:
            return 20
        default:
            return 24
        }
    }

    private var dynamicIconSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 8
        case .medium:
            return 10
        case .large:
            return 11
        case .xLarge:
            return 12
        default:
            return 14
        }
    }

    private var dynamicIconFrameSize: CGFloat {
        dynamicIconSize + 2
    }

    private var dynamicColorIndicatorSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 6
        case .medium:
            return 8
        case .large:
            return 9
        case .xLarge:
            return 10
        default:
            return 12
        }
    }

    private var dynamicStatusIconSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 7
        case .medium:
            return 9
        case .large:
            return 10
        default:
            return 11
        }
    }

    private var dynamicDepthIndicatorSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 6
        case .medium:
            return 8
        case .large:
            return 9
        default:
            return 10
        }
    }

    private var dynamicLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    // MARK: - Accessibility Support

    private var accessibilityLabel: String {
        var label = project.name

        if level > 0 {
            let levelDescription = level == 1 ? "sub-project" : "level \(level) project"
            label = "\(label), \(levelDescription)"
        }

        return label
    }

    private var accessibilityHint: String {
        if level == 0 {
            return "Top-level project. Double-tap to select."
        } else {
            return "Nested project at level \(level). Double-tap to select."
        }
    }

    private var accessibilityValue: String {
        var values: [String] = []

        let colorName = colorAccessibilityName(for: project.color)
        values.append("Color: \(colorName)")

        if !project.children.isEmpty {
            let childCount = project.children.count
            let childText = childCount == 1 ? "1 sub-project" : "\(childCount) sub-projects"
            values.append("Contains \(childText)")
        }

        if level > 0 {
            values.append("Nested under parent project")
        }

        return values.joined(separator: ", ")
    }

    private func colorAccessibilityName(for color: Color) -> String {
        let colorComponents = color.cgColor?.components ?? [0, 0, 0, 1]

        guard colorComponents.count >= 3 else { return "Unknown" }

        let red = colorComponents[0]
        let green = colorComponents[1]
        let blue = colorComponents[2]

        if red > 0.8 && green < 0.3 && blue < 0.3 {
            return "Red"
        } else if red < 0.3 && green > 0.8 && blue < 0.3 {
            return "Green"
        } else if red < 0.3 && green < 0.3 && blue > 0.8 {
            return "Blue"
        } else if red > 0.8 && green > 0.8 && blue < 0.3 {
            return "Yellow"
        } else if red > 0.8 && green < 0.3 && blue > 0.8 {
            return "Purple"
        } else if red < 0.3 && green > 0.8 && blue > 0.8 {
            return "Cyan"
        } else if red > 0.8 && green > 0.5 && blue < 0.3 {
            return "Orange"
        } else if red > 0.7 && green > 0.7 && blue > 0.7 {
            return "Light Gray"
        } else if red < 0.3 && green < 0.3 && blue < 0.3 {
            return "Dark Gray"
        } else {
            return "Custom Color"
        }
    }
}
