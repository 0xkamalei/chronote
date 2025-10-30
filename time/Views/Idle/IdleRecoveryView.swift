import SwiftUI
import SwiftData

/// Dialog for handling idle time recovery when user returns from idle state
struct IdleRecoveryView: View {
    // MARK: - Properties
    
    let idleStartTime: Date
    let idleDuration: TimeInterval
    let onComplete: (IdleRecoveryAction) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    
    @State private var selectedAction: IdleRecoveryAction = .ignore
    @State private var selectedProject: Project?
    @State private var customActivity: String = ""
    @State private var notes: String = ""
    @State private var showingProjectPicker = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            Divider()
            
            actionSelectionSection
            
            if selectedAction == .assignToProject {
                projectSelectionSection
            }
            
            if selectedAction == .createTimeEntry {
                timeEntryDetailsSection
            }
            
            Divider()
            
            buttonSection
        }
        .padding(24)
        .frame(width: 480, height: dynamicHeight)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("What were you doing?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You were away for \(formattedIdleDuration)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("From \(formattedTimeRange)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How would you like to handle this time?")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                actionOption(
                    action: .ignore,
                    title: "Ignore this time",
                    description: "Don't track this idle period",
                    icon: "xmark.circle"
                )
                
                actionOption(
                    action: .assignToProject,
                    title: "Assign to a project",
                    description: "Create a time entry for a specific project",
                    icon: "folder"
                )
                
                actionOption(
                    action: .createTimeEntry,
                    title: "Create custom time entry",
                    description: "Add a manual time entry with custom details",
                    icon: "plus.circle"
                )
                
                actionOption(
                    action: .markAsBreak,
                    title: "Mark as break time",
                    description: "Record this as a break or personal time",
                    icon: "cup.and.saucer"
                )
            }
        }
    }
    
    private var projectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Project")
                .font(.headline)
            
            Button(action: { showingProjectPicker = true }) {
                HStack {
                    if let project = selectedProject {
                        Circle()
                            .fill(project.color)
                            .frame(width: 12, height: 12)
                        Text(project.name)
                    } else {
                        Text("Choose a project...")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showingProjectPicker) {
                ProjectPickerPopover(
                    projects: projects,
                    selectedProject: $selectedProject,
                    onDismiss: { showingProjectPicker = false }
                )
            }
            
            TextField("Activity description (optional)", text: $customActivity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var timeEntryDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Entry Details")
                .font(.headline)
            
            TextField("What were you working on?", text: $customActivity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                onComplete(.ignore)
            }
            .keyboardShortcut(.escape)
            
            Spacer()
            
            Button("Apply") {
                handleApplyAction()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .disabled(!isActionValid)
        }
    }
    
    // MARK: - Helper Methods
    
    private func actionOption(
        action: IdleRecoveryAction,
        title: String,
        description: String,
        icon: String
    ) -> some View {
        Button(action: { selectedAction = action }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(selectedAction == action ? .accentColor : .secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedAction == action {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedAction == action ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedAction == action ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formattedIdleDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: idleDuration) ?? "\(Int(idleDuration / 60)) min"
    }
    
    private var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let endTime = idleStartTime.addingTimeInterval(idleDuration)
        return "\(formatter.string(from: idleStartTime)) - \(formatter.string(from: endTime))"
    }
    
    private var dynamicHeight: CGFloat {
        var height: CGFloat = 280 // Base height
        
        if selectedAction == .assignToProject {
            height += 100
        } else if selectedAction == .createTimeEntry {
            height += 120
        }
        
        return height
    }
    
    private var isActionValid: Bool {
        switch selectedAction {
        case .ignore, .markAsBreak:
            return true
        case .assignToProject:
            return selectedProject != nil
        case .createTimeEntry:
            return !customActivity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func handleApplyAction() {
        var finalAction = selectedAction
        
        // Populate action with additional data
        switch selectedAction {
        case .assignToProject:
            if let project = selectedProject {
                finalAction = .assignToProject(
                    project: project,
                    activity: customActivity.isEmpty ? nil : customActivity
                )
            }
        case .createTimeEntry:
            finalAction = .createTimeEntry(
                activity: customActivity,
                notes: notes.isEmpty ? nil : notes
            )
        default:
            break
        }
        
        onComplete(finalAction)
    }
}

// MARK: - Project Picker Popover

private struct ProjectPickerPopover: View {
    let projects: [Project]
    @Binding var selectedProject: Project?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select Project")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(hierarchicalProjects, id: \.id) { project in
                        ProjectPickerRow(
                            project: project,
                            isSelected: selectedProject?.id == project.id,
                            onSelect: {
                                selectedProject = project
                                onDismiss()
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var hierarchicalProjects: [Project] {
        // Create a simple flat list for now - could be enhanced with hierarchy later
        return projects.sorted { $0.name < $1.name }
    }
}

private struct ProjectPickerRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(project.color)
                    .frame(width: 12, height: 12)
                
                Text(project.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Idle Recovery Action

enum IdleRecoveryAction: Equatable, CustomStringConvertible {
    case ignore
    case assignToProject(project: Project? = nil, activity: String? = nil)
    case createTimeEntry(activity: String, notes: String? = nil)
    case markAsBreak
    
    static func == (lhs: IdleRecoveryAction, rhs: IdleRecoveryAction) -> Bool {
        switch (lhs, rhs) {
        case (.ignore, .ignore), (.markAsBreak, .markAsBreak):
            return true
        case let (.assignToProject(p1, a1), .assignToProject(p2, a2)):
            return p1?.id == p2?.id && a1 == a2
        case let (.createTimeEntry(a1, n1), .createTimeEntry(a2, n2)):
            return a1 == a2 && n1 == n2
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .ignore:
            return "ignore"
        case .assignToProject:
            return "assignToProject"
        case .createTimeEntry:
            return "createTimeEntry"
        case .markAsBreak:
            return "markAsBreak"
        }
    }
}

// MARK: - Preview

#Preview {
    IdleRecoveryView(
        idleStartTime: Date().addingTimeInterval(-900), // 15 minutes ago
        idleDuration: 900, // 15 minutes
        onComplete: { action in
            print("Selected action: \(action)")
        }
    )
    .modelContainer(for: Project.self, inMemory: true)
}