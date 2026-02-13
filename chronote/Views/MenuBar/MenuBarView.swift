import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(EventManager.self) private var eventManager
    @State private var newEventName: String = ""
    @State private var recentNames: [String] = []
    @AppStorage("showInDock") private var showInDock: Bool = true
    private let menuWidth: CGFloat = 344
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                if let currentEvent = eventManager.currentEvent {
                    runningEventView(currentEvent)
                } else {
                    startEventView()
                }
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .underPageBackgroundColor).opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            Divider()
            
            footerView
        }
        .frame(width: menuWidth)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            recentNames = eventManager.getRecentEventNames()
            AppVisibilityController.apply(showInDock: showInDock)
        }
        .onChange(of: eventManager.currentEvent) { _, _ in
            recentNames = eventManager.getRecentEventNames()
        }
    }

    private var footerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                openApp()
            } label: {
                Label("Open Main Window", systemImage: "macwindow")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "dock.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Show in Dock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Toggle("", isOn: $showInDock)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: showInDock) { _, newValue in
                            AppVisibilityController.apply(showInDock: newValue)
                        }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .quaternarySystemFill))
                )

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 84)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func runningEventView(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label("Tracking", systemImage: "record.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.red.opacity(0.12))
                    )

                Spacer()

                EventDurationView(startTime: event.startTime)
                    .font(.monospacedDigit(.callout)())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
            }

            Text(event.name)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

            Button(role: .destructive) {
                eventManager.stopCurrentEvent()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Event")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.regular)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }
    
    private func startEventView() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to Track")
                        .font(.title3.weight(.bold))
                    Text("Start a session in one click.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(.blue.opacity(0.14))
                    )
            }

            HStack(spacing: 8) {
                TextField("What are you working on?", text: $newEventName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    )
                    .onSubmit {
                        startEvent()
                    }

                Button {
                    startEvent()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.85), .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(newEventName.isEmpty)
                .opacity(newEventName.isEmpty ? 0.5 : 1)
            }
            
            if !recentNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(recentNames.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(nsColor: .quaternarySystemFill))
                            )
                    }

                    VStack(spacing: 6) {
                        ForEach(Array(recentNames.prefix(5)), id: \.self) { name in
                            Button {
                                eventManager.startEvent(name: name)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(name)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Text("Start")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 9)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
                                )
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
                .padding(.top, 2)
            }
        }
    }

    private func startEvent() {
        guard !newEventName.isEmpty else { return }
        eventManager.startEvent(name: newEventName)
        newEventName = ""
    }
    
    private func openApp() {
        openWindow(id: "main")
        DispatchQueue.main.async {
            MainWindowRegistry.presentMainWindow()
            AppVisibilityController.activateApp()
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
