import SwiftUI

struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case tracking = "Tracking"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .tracking: return "timer"
            }
        }
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 180)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Detail
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .tracking:
                    TrackingSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 860, height: 560)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("timelineMergeStatisticsEnabled") private var mergeEnabled = true
    @AppStorage("deepFocusMinMinutes") private var deepFocusMinMinutes: Int = 20

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
                            Text("Automatically connect short gaps based on current timeline zoom.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SettingCard(title: "Insights", systemImage: "brain.head.profile") {
                    DurationSettingRow(
                        title: "Deep Focus Minimum Duration",
                        detail1: "Sessions at or above this duration (with low switches) are classified as Deep Focus.",
                        detail2: "Changes apply to newly generated day insights.",
                        value: $deepFocusMinMinutes,
                        range: 5...120,
                        unitText: "min"
                    )
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
                            .disabled(checkingCLI)
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

    private func checkCLIStatus() {
        checkingCLI = true
        cliMessage = nil

        Task {
            let resolvedPath = CLIPathInstaller.resolvedCLIPath()

            await MainActor.run {
                if let resolvedPath {
                    cliStatus = .installed
                    cliMessage = "Found at: \(resolvedPath)"
                } else {
                    cliStatus = .notInstalled
                    cliMessage = "chronote-cli is not detected in this app environment."
                }
                checkingCLI = false
            }
        }
    }

    private func installCLI() {
        guard let command = CLIPathInstaller.manualInstallCommandForEmbeddedCLI() else {
            cliMessage = "Embedded CLI not found in app bundle."
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Install chronote-cli"
        alert.informativeText = "Please run this command in Terminal:\n\n\(command)"
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(cliStatus.color)
            .frame(width: 10, height: 10)
            .padding(.top, 5)
    }
}


private struct DurationSettingRow: View {
    let title: String
    let detail1: String
    let detail2: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unitText: String
    @State private var draftValue: String = ""
    @FocusState private var isEditingValue: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail2)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                TextField("min", text: $draftValue)
                    .frame(width: 72)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .textFieldStyle(.roundedBorder)
                    .focused($isEditingValue)
                    .onSubmit {
                        commitDraft()
                    }
                    .onChange(of: isEditingValue) { _, focused in
                        if !focused {
                            commitDraft()
                        }
                    }
                Text(unitText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            syncDraftFromValue()
        }
        .onChange(of: value) { _, _ in
            if !isEditingValue {
                syncDraftFromValue()
            }
        }
    }

    private func syncDraftFromValue() {
        draftValue = "\(value)"
    }

    private func commitDraft() {
        let trimmed = draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            syncDraftFromValue()
            return
        }

        guard let parsed = Int(trimmed) else {
            syncDraftFromValue()
            return
        }

        value = max(range.lowerBound, min(parsed, range.upperBound))
        syncDraftFromValue()
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
