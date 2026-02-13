import SwiftUI

struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case tracking = "Tracking"

        var id: String { rawValue }
    }

    @State private var selectedTab: Tab? = .general

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: tab))
                                .frame(width: 16)
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? .white : .primary)
                        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .frame(minWidth: 150, idealWidth: 180, maxWidth: 200)

            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .tracking:
                    TrackingSettingsView()
                case nil:
                    ContentUnavailableView("Select a setting", systemImage: "gearshape.2")
                }
            }
            .frame(minWidth: 600)
        }
        .frame(width: 860, height: 560)
    }

    private func icon(for tab: Tab) -> String {
        switch tab {
        case .general:
            return "gearshape"
        case .tracking:
            return "timer"
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("timelineMergeStatisticsEnabled") private var mergeEnabled = true
    @AppStorage("timelineMergeIntervalMinutes") private var mergeIntervalMinutes = 30

    @State private var launchManager = LaunchAtLoginManager.shared
    @State private var cliStatus: CLIInstallStatus = .unknown
    @State private var cliMessage: String?
    @State private var checkingCLI = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("General")
                    .font(.system(size: 30, weight: .bold))
                    .padding(.top, 4)

                SettingCard(title: "Timeline", systemImage: "timeline.selection") {
                    Toggle(isOn: $mergeEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Merge Fragmented Activities")
                            Text("Combine short activities within a time range into a continuous block.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if mergeEnabled {
                        Divider()
                        Stepper(value: $mergeIntervalMinutes, in: 10...1440, step: 10) {
                            HStack {
                                Text("Merge Interval")
                                Spacer()
                                Text(formatInterval(mergeIntervalMinutes))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                SettingCard(title: "Startup", systemImage: "power.circle") {
                    Toggle(isOn: Bindable(launchManager).isEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch at login")
                            Text("Automatically start Chronote when you log in.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SettingCard(title: "chronote-cli", systemImage: "terminal") {
                    HStack(alignment: .top, spacing: 12) {
                        statusDot
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cliStatus.title)
                                .font(.subheadline.weight(.semibold))
                            Text(cliStatus.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    if let cliMessage {
                        Text(cliMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    HStack(spacing: 10) {
                        if cliStatus == .notInstalled {
                            Button("Install") {
                                installCLI()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(checkingCLI || CLIPathInstaller.embeddedCLIURL() == nil)
                        }

                        Button {
                            checkCLIStatus()
                        } label: {
                            HStack(spacing: 6) {
                                if checkingCLI {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Check Availability")
                            }
                        }
                        .disabled(checkingCLI)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            launchManager.refreshStatus()
            checkCLIStatus()
        }
    }

    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = Double(minutes) / 60.0
            return String(format: "%.1f hours", hours)
        }
    }

    private func checkCLIStatus() {
        checkingCLI = true
        cliMessage = nil
        defer { checkingCLI = false }

        if let resolvedPath = CLIPathInstaller.resolvedCLIPath() {
            cliStatus = .installed
            cliMessage = "Found at: \(resolvedPath)"
        } else {
            cliStatus = .notInstalled
            cliMessage = "chronote-cli is not detected in this app environment."
        }
    }

    private func installCLI() {
        do {
            try CLIPathInstaller.installSymlinkToPath()
            cliMessage = "Installed successfully."
            checkCLIStatus()
        } catch {
            cliMessage = error.localizedDescription
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(cliStatus.color)
            .frame(width: 10, height: 10)
            .padding(.top, 5)
    }
}

struct SettingCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
        )
    }
}

private enum CLIInstallStatus {
    case unknown
    case installed
    case notInstalled

    var title: String {
        switch self {
        case .unknown:
            return "Not Checked"
        case .installed:
            return "Installed"
        case .notInstalled:
            return "Not Installed"
        }
    }

    var description: String {
        switch self {
        case .unknown:
            return "Click check to verify whether chronote-cli is available."
        case .installed:
            return "chronote-cli is available."
        case .notInstalled:
            return "chronote-cli is not available."
        }
    }

    var color: Color {
        switch self {
        case .unknown:
            return .secondary
        case .installed:
            return .green
        case .notInstalled:
            return .orange
        }
    }
}

#Preview {
    SettingsView()
}
