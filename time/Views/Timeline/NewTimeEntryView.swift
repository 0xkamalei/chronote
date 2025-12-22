import os
import SwiftUI
import SwiftData

struct NewTimeEntryView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var timeEntryManager = TimeEntryManager.shared
    @Binding var isPresented: Bool

    @Query(sort: \Project.sortOrder) private var allProjects: [Project]

    @State private var selectedProject: Project?
    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startTime: Date = .init()
    @State private var endTime: Date = Date().addingTimeInterval(3600) // Default 1 hour
    @State private var duration: TimeInterval = 3600 // Default 1 hour

    // Error handling and validation
    @State private var errorMessage: String?
    @State private var isCreating: Bool = false
    @State private var validationErrors: [String] = []

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    private let logger = Logger(subsystem: "com.time-vscode.NewTimeEntryView", category: "UI")

    var body: some View {
        VStack(spacing: 16) {
// ... (previous content)
            Text("New Time Entry")
                .font(.title2)

            // Error display
            if let errorMessage = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Validation errors
            if !validationErrors.isEmpty {

                  VStack(alignment: .leading, spacing: 4) {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Project:").frame(width: 120, alignment: .leading)
                    VStack(alignment: .leading) {
                        Picker("", selection: $selectedProject) {
                            Text("(No Project)").tag(nil as Project?)

                            ForEach(allProjects, id: \.id) { project in
                                ProjectPickerItem(project: project)
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("newEntry.projectPicker")

                        if isAddingProject {
                            TextField("New Project Name", text: $newProjectName)
                                .onSubmit {
                                    if !newProjectName.isEmpty {
                                        Task {
                                            do {
                                                let newProject = try await projectManager.createProject(name: newProjectName, color: .gray)
                                                await MainActor.run {
                                                    selectedProject = newProject
                                                    newProjectName = ""
                                                    isAddingProject = false
                                                }
                                            } catch {
                                                await MainActor.run {
                                                    errorMessage = "Failed to create project: \(error.localizedDescription)"
                                                }
                                                logger.error("Failed to create project: \(error)")
                                            }
                                        }
                                    }
                                }
                        } else {
                            Button("New Project...") {
                                isAddingProject = true
                            }
                            .accessibilityIdentifier("newEntry.newProjectButton")
                        }
                    }
                }

                HStack {
                    Text("Title:").frame(width: 120, alignment: .leading)
                    TextField("Enter a descriptive title...", text: $title)
                        .onChange(of: title) { _, _ in
                            validateInput()
                        }
                        .accessibilityIdentifier("newEntry.titleField")
                }

                HStack(alignment: .top) {
                    Text("Notes:").frame(width: 120, alignment: .leading)
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                        .onChange(of: notes) { _, _ in
                            validateInput()
                        }
                        .accessibilityIdentifier("newEntry.notesField")
                }

                HStack {
                    Text("Start Time:").frame(width: 120, alignment: .leading)
                    DatePicker("", selection: $startTime)
                        .labelsHidden()
                        .onChange(of: startTime) { _, _ in
                            updateDurationFromTimes()
                            validateInput()
                        }
                        .accessibilityIdentifier("newEntry.startTimePicker")
                    Button("-15m") {
                        startTime = startTime.addingTimeInterval(-15 * 60)
                    }
                    Button("+15m") {
                        startTime = startTime.addingTimeInterval(15 * 60)
                    }
                    Button("prev") {
                        // Set to end of last time entry or beginning of day
                        startTime = getPreviousEndTime()
                    }
                }

                HStack {
                    Text("End Time:").frame(width: 120, alignment: .leading)
                    DatePicker("", selection: $endTime)
                        .labelsHidden()
                        .onChange(of: endTime) { _, _ in
                            updateDurationFromTimes()
                            validateInput()
                        }
                        .accessibilityIdentifier("newEntry.endTimePicker")
                    Button("-15m") {
                        endTime = endTime.addingTimeInterval(-15 * 60)
                    }
                    Button("+15m") {
                        endTime = endTime.addingTimeInterval(15 * 60)
                    }
                    Button("now") {
                        endTime = Date()
                    }
                }

                HStack {
                    Text("Duration:").frame(width: 120, alignment: .leading)
                    Text(formatDuration(duration))
                        .foregroundColor(duration < 60 ? .red : .primary)
                    Stepper("", value: $duration, in: 60 ... 86400, step: 60)
                        .labelsHidden()
                        .onChange(of: duration) { _, _ in
                            updateEndTimeFromDuration()
                            validateInput()
                        }
                }
            }

            HStack {
                Button("Discard") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("newEntry.discardButton")

                Spacer()

                Button("Add Time Entry") {
                    createTimeEntry()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isCreating || !isValidInput())
                .accessibilityIdentifier("newEntry.submitButton")
            }
        }
        .padding()
        .frame(minWidth: 500, idealWidth: 550)
        .onAppear {
            initializeDefaults()
            validateInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryDidChange)) { _ in
            logger.debug("NewTimeEntryView received time entry change notification")
            // The form doesn't need to react to external changes, but we could add logic here if needed
        }
    }

    // MARK: - Helper Methods

    private func initializeDefaults() {
        // Set default times if not already set
        if startTime == endTime {
            let now = Date()
            startTime = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now.addingTimeInterval(-3600)
            endTime = now
            updateDurationFromTimes()
        }

        // Set default project if one is selected in app state
        if selectedProject == nil {
            selectedProject = appState.selectedProject
        }
    }

    private func validateInput() {
        validationErrors.removeAll()
        errorMessage = nil

        // Validate title
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            validationErrors.append("Title is required")
        } else if trimmedTitle.count > 200 {
            validationErrors.append("Title cannot exceed 200 characters")
        }

        // Validate notes
        if notes.count > 1000 {
            validationErrors.append("Notes cannot exceed 1000 characters")
        }

        // Validate time range
        if endTime <= startTime {
            validationErrors.append("End time must be after start time")
        } else {
            let calculatedDuration = endTime.timeIntervalSince(startTime)

            if calculatedDuration < 60 {
                validationErrors.append("Duration must be at least 1 minute")
            } else if calculatedDuration > 24 * 60 * 60 {
                validationErrors.append("Duration cannot exceed 24 hours")
            }
        }

        // Validate time bounds
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now

        if startTime < oneYearAgo || startTime > oneYearFromNow {
            validationErrors.append("Start time is outside reasonable range")
        }

        if endTime < oneYearAgo || endTime > oneYearFromNow {
            validationErrors.append("End time is outside reasonable range")
        }
    }

    private func isValidInput() -> Bool {
        return validationErrors.isEmpty && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateDurationFromTimes() {
        duration = max(0, endTime.timeIntervalSince(startTime))
    }

    private func updateEndTimeFromDuration() {
        endTime = startTime.addingTimeInterval(duration)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)

        if totalMinutes < 1 {
            return "<1m"
        } else if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }

    private func getPreviousEndTime() -> Date {
        // Get the most recent time entry's end time, or start of day if none
        let recentEntries = timeEntryManager.timeEntries.prefix(5)
        if let lastEntry = recentEntries.first {
            return lastEntry.endTime
        }

        // Default to start of current day
        return Calendar.current.startOfDay(for: Date())
    }

    private func createTimeEntry() {
        guard isValidInput() else {
            errorMessage = "Please fix the validation errors before saving"
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalNotes = trimmedNotes.isEmpty ? nil : trimmedNotes

                let timeEntry = try await timeEntryManager.createTimeEntry(
                    projectId: selectedProject?.id,
                    title: trimmedTitle,
                    notes: finalNotes,
                    startTime: startTime,
                    endTime: endTime
                )

                await MainActor.run {
                    logger.info("Successfully created time entry: \(timeEntry.title)")
                    isPresented = false
                }

            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create time entry: \(error.localizedDescription)"
                    logger.error("Failed to create time entry: \(error)")
                }
            }
        }
    }
}

extension DateComponentsFormatter {
    static let shortTime: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

#Preview {
    NewTimeEntryView(isPresented: .constant(true))
        .environment(AppState())
}
