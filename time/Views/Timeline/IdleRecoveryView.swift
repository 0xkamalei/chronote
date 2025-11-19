import SwiftData
import SwiftUI

/// Dialog for handling idle time recovery
struct IdleRecoveryView: View {
    let idleStartTime: Date
    let idleDuration: TimeInterval
    let onComplete: (IdleRecoveryAction) -> Void

    @Query private var projects: [Project]
    @State private var selectedProject: Project?
    @State private var activityTitle: String = ""
    @State private var notes: String = ""
    @State private var selectedAction: IdleRecoveryAction = .ignore

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: idleDuration) ?? "\(Int(idleDuration))s"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "zzz")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)

                Text("Idle Time Detected")
                    .font(.headline)

                Text("You were idle for \(formattedDuration)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // Action selection
            VStack(alignment: .leading, spacing: 12) {
                Text("What would you like to do?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                // Ignore option
                Button(action: { selectedAction = .ignore }) {
                    HStack {
                        Image(systemName: selectedAction == .ignore ? "checkmark.circle.fill" : "circle")
                        Text("Ignore this idle time")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(12)
                .background(selectedAction == .ignore ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(6)

                // Mark as break
                Button(action: { selectedAction = .markAsBreak }) {
                    HStack {
                        Image(systemName: selectedAction == .markAsBreak ? "checkmark.circle.fill" : "circle")
                        Text("Mark as break")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(12)
                .background(selectedAction == .markAsBreak ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(6)

                // Custom entry
                Button(action: { selectedAction = .createTimeEntry(activity: "", notes: nil) }) {
                    HStack {
                        Image(systemName: selectedAction.isCreateTimeEntry ? "checkmark.circle.fill" : "circle")
                        Text("Create custom entry")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(12)
                .background(selectedAction.isCreateTimeEntry ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
            .padding()

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onComplete(.ignore)
                }
                .buttonStyle(.bordered)

                Button("Confirm") {
                    onComplete(selectedAction)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 350)
    }
}

// MARK: - Idle Recovery Action Extension

extension IdleRecoveryAction {
    var isCreateTimeEntry: Bool {
        if case .createTimeEntry = self {
            return true
        }
        return false
    }
}

#Preview {
    IdleRecoveryView(
        idleStartTime: Date(),
        idleDuration: 600,
        onComplete: { _ in }
    )
}
