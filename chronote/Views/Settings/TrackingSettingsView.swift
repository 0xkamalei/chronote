import AppKit
import SwiftUI

struct TrackingSettingsView: View {
    @State private var isAccessibilityEnabled: Bool = false
    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    @AppStorage("stopEventOnIdle") private var stopEventOnIdle: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tracking")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 4)

                trackingBehaviorCard
                accessibilityCard
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: checkPermissions)
        .onReceive(timer) { _ in
            checkPermissions()
        }
    }

    private var trackingBehaviorCard: some View {
        SettingCard(title: "Event Behavior", systemImage: "hourglass.tophalf.filled") {
            Toggle(isOn: $stopEventOnIdle) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stop current event when computer is idle")
                    Text("When the system detects idle time, the running event will end at the idle start timestamp.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var accessibilityCard: some View {
        SettingCard(title: "Accessibility Permission", systemImage: "lock.shield") {
            Text("Chronote needs Accessibility permission to read active app and window context more accurately.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(isAccessibilityEnabled ? .green : .orange)
                    .frame(width: 10, height: 10)
                Text(isAccessibilityEnabled ? "Permission granted" : "Permission required")
                    .font(.subheadline.weight(.semibold))
            }

            if isAccessibilityEnabled {
                Text("You are all set. Tracking can capture richer context.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: requestPermissionAndOpenSettings) {
                        Label("Request Permission & Open Settings", systemImage: "gear")
                    }
                    .buttonStyle(.borderedProminent)

                    Text("If Chronote does not appear in the list, click '+' in System Settings and add this app manually.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func checkPermissions() {
        isAccessibilityEnabled = WindowMonitor.shared.checkAccessibilityPermissions()
    }

    private func requestPermissionAndOpenSettings() {
        _ = WindowMonitor.shared.requestAccessibilityPermissions()
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    TrackingSettingsView()
}
