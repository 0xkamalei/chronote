import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(EventManager.self) private var eventManager
    @State private var newEventName: String = ""
    @State private var recentNames: [String] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area
            VStack(alignment: .leading, spacing: 16) {
                if let currentEvent = eventManager.currentEvent {
                    runningEventView(currentEvent)
                } else {
                    startEventView()
                }
            }
            .padding(16)
            
            Divider()
            
            // Footer
            HStack {
                Button {
                    openApp()
                } label: {
                    Label("Open Time Trace", systemImage: "macwindow")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                Spacer()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit")
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 320)
        .onAppear {
            recentNames = eventManager.getRecentEventNames()
        }
        .onChange(of: eventManager.currentEvent) { _, _ in
            recentNames = eventManager.getRecentEventNames()
        }
    }
    
    private func runningEventView(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse, options: .repeating)
                        Text("Running")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(event.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }
                
                Spacer()
                
                EventDurationView(startTime: event.startTime)
                    .font(.monospacedDigit(.body)())
                    .foregroundStyle(.secondary)
            }
            
            Button(role: .destructive) {
                eventManager.stopCurrentEvent()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Event")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
    }
    
    private func startEventView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ready to Track")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    TextField("What are you working on?", text: $newEventName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .onSubmit {
                            startEvent()
                        }
                    
                    Button {
                        startEvent()
                    } label: {
                        Image(systemName: "play.fill")
                            .frame(width: 16, height: 16)
                            .padding(8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newEventName.isEmpty)
                }
            }
            
            if !recentNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 4) {
                        ForEach(recentNames, id: \.self) { name in
                            Button {
                                eventManager.startEvent(name: name)
                            } label: {
                                HStack {
                                    Text(name)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "play.circle")
                                        .foregroundStyle(.secondary.opacity(0.5))
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovered in
                                if isHovered {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                }
            }
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

struct EventDurationView: View {
    let startTime: Date
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(durationString)
            .onReceive(timer) { input in now = input }
            .onAppear { now = Date() }
    }
    
    var durationString: String {
        let interval = now.timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
