import SwiftUI
import SwiftData

import os

struct StartTimerView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var projectManager: ProjectManager
    @Binding var isPresented: Bool

    @Query(sort: \Project.sortOrder) private var allProjects: [Project]

    @State private var selectedProject: Project? // Assuming Project model exists
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startTime: Date = .init()
    @State private var estimatedDuration: String = "2 Hours"
    @State private var playSound: Bool = true
    @State private var isAddingProject = false
    @State private var newProjectName = ""



    let durationOptions = ["30 Minutes", "1 Hour", "2 Hours", "4 Hours"]

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("What are you going to do?")
                .font(.title2)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Project:").frame(width: 120, alignment: .leading)
                    VStack(alignment: .leading) {
                        Picker("", selection: $selectedProject) {
                            ForEach(allProjects) { project in
                                ProjectPickerItem(project: project)
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("startTimer.projectPicker")

                        if isAddingProject {
                            TextField("New Project Name", text: $newProjectName)
                                .accessibilityIdentifier("startTimer.newProjectField")
                                .onSubmit {
                                    if !newProjectName.isEmpty {
                                        Task {
                                            do {
                                                let newProject = try await projectManager.createProject(name: newProjectName, color: .gray)
                                                await MainActor.run {
                                                    selectedProject = newProject
                                                    newProjectName = ""
                                                }
                                            } catch {
                                                Logger.ui.error("Failed to create project: \(error)")
                                            }
                                        }
                                    }
                                }
                        } else {
                            Button("New Project...") {
                                isAddingProject = true
                            }
                            .accessibilityIdentifier("startTimer.newProjectButton")
                        }
                    }
                }

                HStack {
                    Text("Title:").frame(width: 120, alignment: .leading)
                    TextField("", text: $title)
                        .accessibilityIdentifier("startTimer.titleField")
                }

                HStack(alignment: .top) {
                    Text("Notes:").frame(width: 120, alignment: .leading)
                    TextField("", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                        .accessibilityIdentifier("startTimer.notesField")
                }

                HStack {
                    Text("Start Time:").frame(width: 120, alignment: .leading)
                    DatePicker("", selection: $startTime)
                        .labelsHidden()
                        .accessibilityIdentifier("startTimer.startTimePicker")
                }

                HStack {
                    Text("Estimated Duration:").frame(width: 120, alignment: .leading)
                    Picker("", selection: $estimatedDuration) {
                        ForEach(durationOptions, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("startTimer.durationPicker")
                }

                Text("We'll send a notification once this has elapsed, to help you remember stopping the timer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 128)

                Toggle("Play a sound when notifying", isOn: $playSound)
                    .padding(.leading, 128)
                    .accessibilityIdentifier("startTimer.playSoundToggle")
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("startTimer.cancelButton")

                Spacer()

                Button("Start Tracking") {
                    // Parse estimated duration
                    let parsedEstimatedDuration: TimeInterval = {
                        switch estimatedDuration {
                        case "30 Minutes":
                            return 30 * 60
                        case "1 Hour":
                            return 60 * 60
                        case "2 Hours":
                            return 2 * 60 * 60
                        case "4 Hours":
                            return 4 * 60 * 60
                        default:
                            return 2 * 60 * 60 // Default to 2 hours
                        }
                    }()

                    // Update AppState's estimated duration
                    appState.defaultEstimatedDuration = parsedEstimatedDuration
                    appState.enableSounds = playSound

                    appState.startTimer(
                        project: selectedProject,
                        title: title.isEmpty ? nil : title,
                        notes: notes.isEmpty ? nil : notes
                    )
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("startTimer.startButton")
            }
        }
        .padding()
        .frame(minWidth: 450, idealWidth: 500)
    }
}

#Preview {
    StartTimerView(isPresented: .constant(true))
        .environment(AppState())
}
