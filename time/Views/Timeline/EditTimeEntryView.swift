import os
import SwiftUI
import SwiftData

struct EditTimeEntryView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var timeEntryManager = TimeEntryManager.shared
    @Binding var isPresented: Bool

    let timeEntry: TimeEntry

    @Query(sort: \Project.sortOrder) private var allProjects: [Project]

    init(isPresented: Binding<Bool>, timeEntry: TimeEntry) {
        _isPresented = isPresented
        self.timeEntry = timeEntry
    }

    @State private var selectedProject: Project?
    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startTime: Date = .init()
    @State private var endTime: Date = .init()
    @State private var duration: TimeInterval = 0

    // Error handling and validation
    @State private var errorMessage: String?
    @State private var isUpdating: Bool = false
    @State private var validationErrors: [String] = []

    private let logger = Logger(subsystem: "com.time-vscode.EditTimeEntryView", category: "UI")

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Time Entry")
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
                        .onChange(of: selectedProject) { _, _ in
                            validateInput()
                        }

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
                        }
                    }
                }

                HStack {
                    Text("Title:").frame(width: 120, alignment: .leading)
                    TextField("Enter a descriptive title...", text: $title)
                        .onChange(of: title) { _, _ in
                            validateInput()
                        }
                }

                HStack(alignment: .top) {
                    Text("Notes:").frame(width: 120, alignment: .leading)
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                        .onChange(of: notes) { _, _ in
                            validateInput()
                        }
                }

                HStack {
                    Text("Start Time:").frame(width: 120, alignment: .leading)
                    DatePicker("", selection: $startTime)
                        .labelsHidden()
                        .onChange(of: startTime) { _, _ in
                            updateDurationFromTimes()
                            validateInput()
                        }
                    Button("-15m") {
                        startTime = startTime.addingTimeInterval(-15 * 60)
                    }
                    Button("+15m") {
                        startTime = startTime.addingTimeInterval(15 * 60)
                    }
                    Button("prev") {
                        // Set to end of previous time entry
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

                // Show original values for reference
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original Values:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Created: \(formatDate(timeEntry.createdAt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        if timeEntry.updatedAt != timeEntry.createdAt {
                            Text("Updated: \(formatDate(timeEntry.updatedAt))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Reset") {
                    resetToOriginalValues()
                }
                .disabled(isUpdating)

                Button("Update Time Entry") {
                    updateTimeEntry()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isUpdating || !isValidInput() || !hasChanges())
            }
        }
        .padding()
        .frame(minWidth: 500, idealWidth: 550)
        .onAppear {
            populateFormWithTimeEntry()
            validateInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryDidChange)) { notification in
            logger.debug("EditTimeEntryView received time entry change notification")

            // Check if the time entry being edited was modified externally
            if let userInfo = notification.userInfo,
               let modifiedTimeEntryId = userInfo["timeEntryId"] as? String,
               modifiedTimeEntryId == timeEntry.id.uuidString,
               let operation = userInfo["operation"] as? String,
               operation != "update"
            { // Avoid reacting to our own updates
                logger.info("Time entry being edited was modified externally, refreshing form")
                populateFormWithTimeEntry()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeEntryWasDeleted)) { notification in
            logger.debug("EditTimeEntryView received time entry deletion notification")

            // Check if the time entry being edited was deleted
            if let userInfo = notification.userInfo,
               let deletedTimeEntryId = userInfo["timeEntryId"] as? String,
               deletedTimeEntryId == timeEntry.id.uuidString
            {
                logger.warning("Time entry being edited was deleted, closing form")
                isPresented = false
            }
        }
    }

    // MARK: - Helper Methods

    private func populateFormWithTimeEntry() {
        // Set form fields from the time entry
        title = timeEntry.title
        notes = timeEntry.notes ?? ""
        startTime = timeEntry.startTime
        endTime = timeEntry.endTime
        duration = timeEntry.calculatedDuration

        // Find and set the selected project
        if let projectId = timeEntry.projectId {
            selectedProject = projectManager.getProject(by: projectId)
        } else {
            selectedProject = nil
        }
    }

    private func resetToOriginalValues() {
        populateFormWithTimeEntry()
        validateInput()
        errorMessage = nil
    }

    private func hasChanges() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalNotes = timeEntry.notes ?? ""

        return trimmedTitle != timeEntry.title ||
            trimmedNotes != originalNotes ||
            startTime != timeEntry.startTime ||
            endTime != timeEntry.endTime ||
            selectedProject?.id != timeEntry.projectId
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

        // Validate project exists if selected
        if let selectedProject = selectedProject {
            if projectManager.getProject(by: selectedProject.id) == nil {
                validationErrors.append("Selected project no longer exists")
            }
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func getPreviousEndTime() -> Date {
        // Get the most recent time entry's end time (excluding current one), or start of day if none
        let recentEntries = timeEntryManager.timeEntries.filter { $0.id != timeEntry.id }.prefix(5)
        if let lastEntry = recentEntries.first {
            return lastEntry.endTime
        }

        // Default to start of current day
        return Calendar.current.startOfDay(for: Date())
    }

    private func updateTimeEntry() {
        guard isValidInput(), hasChanges() else {
            errorMessage = "No changes to save or validation errors present"
            return
        }

        isUpdating = true
        errorMessage = nil

        Task {
            do {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalNotes = trimmedNotes.isEmpty ? nil : trimmedNotes

                try await timeEntryManager.updateTimeEntry(
                    timeEntry,
                    projectId: selectedProject?.id,
                    title: trimmedTitle,
                    notes: finalNotes,
                    startTime: startTime,
                    endTime: endTime
                )

                await MainActor.run {
                    logger.info("Successfully updated time entry: \(trimmedTitle)")
                    isPresented = false
                }

            } catch {
                await MainActor.run {
                    isUpdating = false
                    if let timeEntryError = error as? TimeEntryError {
                        errorMessage = timeEntryError.localizedDescription
                    } else {
                        errorMessage = "Failed to update time entry: \(error.localizedDescription)"
                    }
                    logger.error("Failed to update time entry: \(error)")
                }
            }
        }
    }
}

#Preview {
    // Create a sample time entry for preview
    let sampleTimeEntry = TimeEntry(
        projectId: nil,
        title: "Sample Task",
        notes: "Some notes about the task",
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date()
    )

    EditTimeEntryView(isPresented: .constant(true), timeEntry: sampleTimeEntry)
        .environment(AppState())
        .environmentObject(ProjectManager.shared)
}
