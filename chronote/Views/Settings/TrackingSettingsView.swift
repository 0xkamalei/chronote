import AppKit
import SwiftUI

struct TrackingSettingsView: View {
    @State private var isAccessibilityEnabled: Bool = false
    @State private var automationRequestHint: String?
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
                browserAutomationCard
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

    private var browserAutomationCard: some View {
        SettingCard(title: "Browser Automation Permission", systemImage: "safari") {
            Text("Chronote needs Automation permission to read browser tab URLs (Chrome/Safari/Edge/Brave/Arc).")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: requestBrowserAutomationAndOpenSettings) {
                    Label("Request Permission & Open Automation Settings", systemImage: "link.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Text("Keep the target browser running, then click the button. macOS grants permission per browser app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let hint = automationRequestHint {
                    Text(hint)
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

    private func requestBrowserAutomationAndOpenSettings() {
        WindowMonitor.shared.requestBrowserAutomationPermissions()
        automationRequestHint = "If no prompt appears, remove existing denied entries for Chronote under Automation and retry."
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    TrackingSettingsView()
}
