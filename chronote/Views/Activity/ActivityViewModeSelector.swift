import SwiftUI

/// Component for selecting activity view mode (Unified, Chronological)
struct ActivityViewModeSelector: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 0) {
            // Unified button
            Button(action: {
                appState.activityViewMode = .unified
            }) {
                Text("Unified")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(ViewModeButtonStyle(isSelected: appState.activityViewMode == .unified))
            
            // Chronological button
            Button(action: {
                appState.activityViewMode = .chronological
            }) {
                Text("Chronological")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(ViewModeButtonStyle(isSelected: appState.activityViewMode == .chronological))
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Custom button style for view mode selector
struct ViewModeButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        Color.blue
                    } else if configuration.isPressed {
                        Color.secondary.opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ActivityViewModeSelector()
        .environment(AppState())
        .padding()
}