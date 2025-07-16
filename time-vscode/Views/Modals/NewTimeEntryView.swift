import SwiftUI

struct NewTimeEntryView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    @State private var selectedProject: Project? // Assuming Project model exists
    @State private var isAddingSubproject = false
    @State private var newSubprojectName = ""
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var duration: TimeInterval = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("New Time Entry")
                .font(.title2)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Project:").frame(width: 120, alignment: .leading)
                    VStack(alignment: .leading) {
                        Picker("", selection: $selectedProject) {
                            // No Project option
                            Text("(No Project)").tag(nil as Project?)
                            
                            // Tree structure projects
                            ForEach(appState.projectTree, id: \.id) { project in
                                ProjectPickerItem(project: project, level: 0)
                            }
                        }
                        .labelsHidden()

                        if isAddingSubproject {
                            TextField("New Subproject Name", text: $newSubprojectName)
                                .onSubmit {
                                    if !newSubprojectName.isEmpty, let parent = selectedProject {
                                        let newProject = Project(id: UUID().uuidString, name: newSubprojectName, color: .gray, parentID: parent.id)
                                        appState.addProject(newProject)
                                        selectedProject = newProject
                                        newSubprojectName = ""
                                    }
                                }
                        } else {
                            Button("New Subproject...") {
                                isAddingSubproject = true
                            }
                        }
                    }
                }

                HStack {
                    Text("Title:").frame(width: 120, alignment: .leading)
                    TextField("Try typing a project name here to quickly select it...", text: $title)
                }

                HStack(alignment: .top) {
                    Text("Notes:").frame(width: 120, alignment: .leading)
                    TextField("", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }

                HStack {
                    Text("Start Time:").frame(width: 120, alignment: .leading)
                    DatePicker("", selection: $startTime)
                        .labelsHidden()
                    Button("-15m") {}
                    Button("+15m") {}
                    Button("prev") {}
                }

                HStack {
                    Text("End Time:").frame(width: 120, alignment: .leading)
                    DatePicker("", selection: $endTime)
                        .labelsHidden()
                    Button("-15m") {}
                    Button("+15m") {}
                    Button("now") {}
                }

                HStack {
                    Text("Duration:").frame(width: 120, alignment: .leading)
                    Text(DateComponentsFormatter.shortTime.string(from: duration) ?? "00:00")
                    Stepper("", value: $duration, in: 0...Double.infinity, step: 60)
                        .labelsHidden()
                }
            }

            HStack {
                Button("Discard") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Time Entry") {
                    // TODO: Add time entry logic
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 500, idealWidth: 550)
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
        .environmentObject(AppState())
}
