import SwiftUI

/// Preferences view for configuring idle detection behavior
struct IdlePreferencesView: View {
    // MARK: - Properties
    
    @ObservedObject private var idleDetector = IdleDetector.shared
    
    @State private var isIdleDetectionEnabled: Bool = true
    @State private var idleThreshold: Double = 300 // 5 minutes in seconds
    @State private var checkInterval: Double = 30 // 30 seconds
    @State private var showAccessibilityAlert = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            
            Divider()
            
            enabledToggleSection
            
            if isIdleDetectionEnabled {
                thresholdSection
                intervalSection
                permissionsSection
            }
            
            Divider()
            
            statusSection
            
            Spacer()
        }
        .padding(20)
        .frame(width: 480, height: dynamicHeight)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.questionmark")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Idle Detection Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text("Configure how the app detects and handles idle time")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var enabledToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable idle detection", isOn: $isIdleDetectionEnabled)
                .font(.headline)
                .onChange(of: isIdleDetectionEnabled) { _, newValue in
                    updateIdleDetectionEnabled(newValue)
                }
            
            if !isIdleDetectionEnabled {
                Text("When disabled, all time will be tracked continuously without idle detection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }
    
    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Idle Threshold")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Consider idle after:")
                    Spacer()
                    Text(formattedThreshold)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $idleThreshold, in: 60...1800, step: 60) // 1 minute to 30 minutes
                    .onChange(of: idleThreshold) { _, newValue in
                        updateIdleThreshold(newValue)
                    }
                
                HStack {
                    Text("1 min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("30 min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Time without mouse or keyboard activity before considering the user idle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check Interval")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Check for idle every:")
                    Spacer()
                    Text(formattedInterval)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $checkInterval, in: 10...120, step: 10) // 10 seconds to 2 minutes
                    .onChange(of: checkInterval) { _, newValue in
                        updateCheckInterval(newValue)
                    }
                
                HStack {
                    Text("10 sec")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("2 min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("How often to check if the idle threshold has been reached")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility Access")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Required to monitor mouse and keyboard activity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if idleDetector.getIdleStatus().hasAccessibilityPermissions {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Granted")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                } else {
                    Button("Grant Access") {
                        requestAccessibilityPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)
            
            let status = idleDetector.getIdleStatus()
            
            VStack(alignment: .leading, spacing: 8) {
                statusRow(
                    title: "Detection Status",
                    value: status.statusDescription,
                    isHealthy: status.isHealthy
                )
                
                if status.isMonitoring {
                    statusRow(
                        title: "Time Since Last Activity",
                        value: formattedDuration(status.timeSinceLastActivity),
                        isHealthy: true
                    )
                    
                    if status.isIdle {
                        statusRow(
                            title: "Current Idle Duration",
                            value: formattedDuration(status.currentIdleDuration),
                            isHealthy: false
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var dynamicHeight: CGFloat {
        var height: CGFloat = 200 // Base height
        
        if isIdleDetectionEnabled {
            height += 300 // Add space for all settings
        }
        
        return height
    }
    
    private var formattedThreshold: String {
        let minutes = Int(idleThreshold / 60)
        if minutes == 1 {
            return "1 minute"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    private var formattedInterval: String {
        let seconds = Int(checkInterval)
        if seconds < 60 {
            return "\(seconds) seconds"
        } else {
            let minutes = seconds / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func statusRow(title: String, value: String, isHealthy: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack {
                if !isHealthy {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(isHealthy ? .secondary : .orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func loadCurrentSettings() {
        let status = idleDetector.getIdleStatus()
        isIdleDetectionEnabled = status.isEnabled
        idleThreshold = status.idleThreshold
        // checkInterval would need to be exposed from IdleDetector if we want to load it
    }
    
    private func updateIdleDetectionEnabled(_ enabled: Bool) {
        idleDetector.updateConfiguration(isEnabled: enabled)
    }
    
    private func updateIdleThreshold(_ threshold: Double) {
        idleDetector.updateConfiguration(threshold: threshold)
    }
    
    private func updateCheckInterval(_ interval: Double) {
        idleDetector.updateConfiguration(checkInterval: interval)
    }
    
    private func requestAccessibilityPermissions() {
        let granted = idleDetector.requestAccessibilityPermissions()
        if !granted {
            showAccessibilityAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    IdlePreferencesView()
}