import SwiftUI
import SwiftData

struct StartEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EventManager.self) private var eventManager
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    
    @State private var name: String = ""
    @State private var selectedProjectId: String? = nil
    @State var startTime: Date = Date()
    @State var hasEndTime: Bool = false
    @State var endTime: Date = Date().addingTimeInterval(3600)
    
    init(initialStartTime: Date? = nil, initialEndTime: Date? = nil) {
        if let start = initialStartTime {
            _startTime = State(initialValue: start)
        }
        if let end = initialEndTime {
            _endTime = State(initialValue: end)
            _hasEndTime = State(initialValue: true)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Event Name", text: $name)
                
                Picker("Project", selection: $selectedProjectId) {
                    Text("None").tag(String?.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(String?.some(project.id))
                    }
                }
                
                DatePicker("Start Time", selection: $startTime)
                
                Toggle("Set End Time", isOn: $hasEndTime)
                
                if hasEndTime {
                    DatePicker("End Time", selection: $endTime, in: startTime...)
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Button(hasEndTime ? "Save Event" : "Start Event") {
                    if hasEndTime {
                         let event = Event(name: name, startTime: startTime, endTime: endTime, projectId: selectedProjectId)
                         eventManager.insertEvent(event)
                    } else {
                        eventManager.startEvent(name: name, startTime: startTime, projectId: selectedProjectId)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.defaultAction)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 300)
    }
}
