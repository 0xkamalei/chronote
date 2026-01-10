import SwiftUI

struct SettingsView: View {
    private enum Tab: Hashable {
        case general
        case tracking
        case rules
    }
    
    @State private var selectedTab: Tab = .general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tab.general)
            
            TrackingSettingsView()
                .tabItem {
                    Label("Tracking", systemImage: "timer")
                }
                .tag(Tab.tracking)
        }
        .padding(20)
        .frame(width: 550, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("timelineMergeStatisticsEnabled") private var mergeEnabled = false
    @AppStorage("timelineMergeIntervalMinutes") private var mergeIntervalMinutes = 30
    
    @State private var launchManager = LaunchAtLoginManager.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        ThemePreviewButton(theme: .light, selectedTheme: $appTheme)
                        ThemePreviewButton(theme: .dark, selectedTheme: $appTheme)
                        ThemePreviewButton(theme: .system, selectedTheme: $appTheme)
                    }
                    .padding(.vertical, 4)
                    
                    Text("Select the color scheme for the application. System follows your macOS settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("Appearance")
            }
            
            Section {
                Toggle(isOn: $mergeEnabled) {
                    VStack(alignment: .leading) {
                        Text("Merge Fragmented Activities")
                        Text("Combine short activities within a time range into a continuous block.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if mergeEnabled {
                    Stepper(value: $mergeIntervalMinutes, in: 10...1440, step: 10) {
                        HStack {
                            Text("Merge Interval")
                            Spacer()
                            Text(formatInterval(mergeIntervalMinutes))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Timeline")
            }
            
            Section {
                Toggle(isOn: Bindable(launchManager).isEnabled) {
                    VStack(alignment: .leading) {
                        Text("Launch at login")
                        Text("Automatically start Time Tracker when you log in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
    
    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = Double(minutes) / 60.0
            return String(format: "%.1f hours", hours)
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Appearance")
                .font(.headline)
            
            HStack(spacing: 20) {
                ThemePreviewButton(theme: .light, selectedTheme: $appTheme)
                ThemePreviewButton(theme: .dark, selectedTheme: $appTheme)
                ThemePreviewButton(theme: .system, selectedTheme: $appTheme)
            }
            
            Text("Select the color scheme for the application. System follows your macOS settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
    }
}

struct ThemePreviewButton: View {
    let theme: AppTheme
    @Binding var selectedTheme: AppTheme
    
    var isSelected: Bool {
        selectedTheme == theme
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                // Content Representation
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Sidebar
                        Rectangle()
                            .fill(sidebarColor)
                            .frame(width: geo.size.width * 0.3)
                        
                        // Main Content
                        VStack(spacing: 4) {
                            // Header
                            Rectangle()
                                .fill(headerColor)
                                .frame(height: 10)
                                .padding(.top, 6)
                                .padding(.horizontal, 6)
                            
                            // Lines
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(contentColor)
                                    .frame(height: 2)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(contentColor)
                                    .frame(height: 2)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(contentColor.opacity(0.6))
                                    .frame(height: 2)
                                    .padding(.trailing, 10)
                            }
                            .padding(.horizontal, 6)
                            
                            Spacer()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Selection Ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .frame(width: 74, height: 54) // Slightly larger than the preview
                }
                
                // System split effect
                if theme == .system {
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geo.size.height))
                            path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            path.closeSubpath()
                        }
                        .fill(Color.black.opacity(0.1)) // Subtle darkening for the "dark" half
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(width: 68, height: 48)
            .onTapGesture {
                selectedTheme = theme
            }
            
            Text(theme.rawValue)
                .font(.subheadline)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
    }
    
    // MARK: - Color Helpers
    
    private var backgroundColor: Color {
        switch theme {
        case .light: return Color(white: 0.95)
        case .dark: return Color(white: 0.25)
        case .system: return Color(white: 0.95)
        }
    }
    
    private var sidebarColor: Color {
        switch theme {
        case .light: return Color(white: 0.9)
        case .dark: return Color(white: 0.2)
        case .system: return Color(white: 0.9)
        }
    }
    
    private var headerColor: Color {
        switch theme {
        case .light: return Color(white: 0.85)
        case .dark: return Color(white: 0.3)
        case .system: return Color(white: 0.85)
        }
    }
    
    private var contentColor: Color {
        switch theme {
        case .light: return Color(white: 0.8)
        case .dark: return Color(white: 0.4)
        case .system: return Color(white: 0.8)
        }
    }
}





struct PlaceholderSettingsView: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("\(title) Settings")
                .font(.title2)
            Text("This feature is coming soon.")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
