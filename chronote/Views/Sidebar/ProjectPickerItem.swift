import SwiftUI

struct ProjectPickerItem: View {
    let project: Project

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        projectRow
    }

    private var projectRow: some View {
        HStack(spacing: dynamicSpacing) {
            colorIndicator
            projectName
            Spacer(minLength: 8)
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

    private var colorIndicator: some View {
        Circle()
            .fill(project.color)
            .frame(width: dynamicColorIndicatorSize, height: dynamicColorIndicatorSize)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }

    private var projectName: some View {
        Text(project.name)
            .foregroundColor(.primary)
            .lineLimit(dynamicLineLimit)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .accessibilityHidden(true)
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

    private var dynamicLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    // MARK: - Accessibility Support

    private var accessibilityLabel: String {
        return project.name
    }

    private var accessibilityHint: String {
        return "Double-tap to select."
    }

    private var accessibilityValue: String {
        var values: [String] = []

        let colorName = colorAccessibilityName(for: project.color)
        values.append("Color: \(colorName)")

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

