import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(EventManager.self) private var eventManager
    @State private var newEventName: String = ""
    @State private var recentNames: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let currentEvent = eventManager.currentEvent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Running Event")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentEvent.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Button(role: .destructive) {
                    eventManager.stopCurrentEvent()
                } label: {
                    Text("Stop Event")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start New Event")
                        .font(.headline)
                    
                    HStack {
                        TextField("Event Name", text: $newEventName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                startEvent()
                            }
                        
                        Button {
                            startEvent()
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newEventName.isEmpty)
                    }
                }
                
                if !recentNames.isEmpty {
                    Divider()
                    Text("Recent Events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recentNames, id: \.self) { name in
                            Button {
                                eventManager.startEvent(name: name)
                            } label: {
                                HStack {
                                    Text(name)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Open Time Trace") {
                    openApp()
                }
                .buttonStyle(.link)
                .font(.caption)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            recentNames = eventManager.getRecentEventNames()
        }
        .onChange(of: eventManager.currentEvent) { _, _ in
            recentNames = eventManager.getRecentEventNames()
        }
    }
    
    private func startEvent() {
        guard !newEventName.isEmpty else { return }
        eventManager.startEvent(name: newEventName)
        newEventName = ""
    }
    
    private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct MenuBarLabelView: View {
    let event: Event
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Image(systemName: "record.circle.fill")
            Text("\(event.name): \(durationString)")
        }
        .onReceive(timer) { input in now = input }
        .onAppear { now = Date() }
    }
    
    var durationString: String {
        let interval = now.timeIntervalSince(event.startTime)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
