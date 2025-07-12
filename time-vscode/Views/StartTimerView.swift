import SwiftUI

struct StartTimerView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    
    @State private var selectedProject: Project? // Assuming Project model exists
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var startTime: Date = Date()
    @State private var estimatedDuration: String = "2 Hours"
    @State private var playSound: Bool = true
    @State private var isAddingSubproject = false
    @State private var newSubprojectName = ""
    
    
    
 
    let durationOptions = ["30 Minutes", "1 Hour", "2 Hours", "4 Hours"]

    

    var body: some View {
        VStack(spacing: 16) {
            Text("What are you going to do?")
                .font(.title2)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Project:").frame(width: 120, alignment: .leading)
                    VStack(alignment: .leading) {
                        Picker("", selection: $selectedProject) {
                            ForEach(appState.projectTree) { project in
                                ProjectPickerItem(project: project, level: 0)
                            }
                        }
                        .labelsHidden()

                        if isAddingSubproject {
                            TextField("New Subproject Name", text: $newSubprojectName, onCommit: {
                                if !newSubprojectName.isEmpty, let parent = selectedProject {
                                    let newProject = Project(id: "", name: newSubprojectName, color: .gray, parentID: parent.id)
                                    appState.addProject(newProject)
                                    selectedProject = newProject
                                    newSubprojectName = "" // Clear for next entry
                                }
                            })
                        } else {
                            Button("New Subproject...") {
                                isAddingSubproject = true
                            }
                        }
                    }
                }

                HStack {
                    Text("Title:").frame(width: 120, alignment: .leading)
                    TextField("", text: $title)
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
                }
                
                HStack {
                    Text("Estimated Duration:").frame(width: 120, alignment: .leading)
                    Picker("", selection: $estimatedDuration) {
                        ForEach(durationOptions, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .labelsHidden()
                }
                
                Text("We'll send a notification once this has elapsed, to help you remember stopping the timer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 128)
                
                Toggle("Play a sound when notifying", isOn: $playSound)
                    .padding(.leading, 128)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Start Tracking") {
                    appState.isTimerActive = true
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 450, idealWidth: 500)
    }
}

#Preview {
    StartTimerView(isPresented: .constant(true))
        .environmentObject(AppState())
}
