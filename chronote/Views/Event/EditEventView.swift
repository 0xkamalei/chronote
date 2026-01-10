import SwiftUI
import SwiftData

struct EditEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EventManager.self) private var eventManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    
    @Bindable var event: Event
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Event Name", text: $event.name)
                
                Picker("Project", selection: $event.projectId) {
                    Text("None").tag(String?.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(String?.some(project.id))
                    }
                }
                
                DatePicker("Start Time", selection: $event.startTime)
                
                if event.endTime != nil {
                    DatePicker("End Time", selection: Binding(
                        get: { event.endTime ?? Date() },
                        set: { event.endTime = $0 }
                    ), in: event.startTime...)
                } else {
                    Button("Stop Event Now") {
                        eventManager.stopCurrentEvent()
                    }
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Button("Delete Event", role: .destructive) {
                    deleteEvent()
                    dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 300)
    }
    
    private func deleteEvent() {
        if eventManager.currentEvent?.id == event.id {
            eventManager.currentEvent = nil
        }
        modelContext.delete(event)
        try? modelContext.save()
    }
}
