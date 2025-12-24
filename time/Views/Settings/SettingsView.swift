import SwiftUI

struct SettingsView: View {
    private enum Tab: Hashable {
        case general
        case tracking
        case rules
        case appearance
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
            
            PlaceholderSettingsView(title: "Rules", icon: "list.bullet.rectangle")
                .tabItem {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.rules)
            
            PlaceholderSettingsView(title: "Appearance", icon: "paintbrush")
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(Tab.appearance)
        }
        .padding(20)
        .frame(width: 550, height: 400)
    }
}

struct GeneralSettingsView: View {
    @State private var launchManager = LaunchAtLoginManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section {
                    Toggle("Launch at login", isOn: Bindable(launchManager).isEnabled)
                } header: {
                    Text("Application")
                }
            }
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
