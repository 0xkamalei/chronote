import SwiftUI

struct TrackingSettingsView: View {
    @State private var isAccessibilityEnabled: Bool = false
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @AppStorage("stopEventOnIdle") private var stopEventOnIdle: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Toggle("Stop current event when computer is idle", isOn: $stopEventOnIdle)
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                
            VStack(spacing: 12) {
                Text("In order to track the paths of most documents, you need to allow Time to use the Accessibility system. Simply tick the corresponding checkbox in the Security preferences.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if isAccessibilityEnabled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility is enabled")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 12) {
                        Button(action: requestPermissionAndOpenSettings) {
                            HStack {
                                Image(systemName: "lock.fill")
                                Text("Request Permission & Open Settings")
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Text("If you don't see the app in the list, click the '+' button in System Settings and add the app manually.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            
            Spacer()
        }
        .onAppear(perform: checkPermissions)
        .onReceive(timer) { _ in
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        isAccessibilityEnabled = WindowMonitor.shared.checkAccessibilityPermissions()
    }
    
    private func requestPermissionAndOpenSettings() {
        // Trigger the system prompt
        _ = WindowMonitor.shared.checkAccessibilityPermissions()
        
        // Open the settings page
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    TrackingSettingsView()
}
