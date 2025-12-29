import SwiftUI
import AppKit

/// Helper to get app icon from bundle ID
struct AppIconView: View {
    let bundleId: String?
    let size: CGFloat
    
    var body: some View {
        if let bundleId = bundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app")
                .font(.system(size: size * 0.7))
                .frame(width: size, height: size)
                .foregroundColor(.secondary)
        }
    }
}

/// A simple row that displays app activity without collapsible hierarchy
struct HierarchicalActivityRow: View {
    let group: ActivityGroup

    var body: some View {
        HStack(spacing: 8) {
            // Duration on the left
            Text(group.durationString)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Chevron indicator (non-interactive, just visual)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
            
            // App icon
            if group.level == .appName {
                AppIconView(bundleId: group.bundleId, size: 18)
            } else {
                Image(systemName: group.levelIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 18)
            }
            
            // App name
            Text(group.name)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack {
        HierarchicalActivityRow(
            group: ActivityGroup(
                name: "Safari",
                level: .appName,
                children: [],
                activities: [],
                bundleId: "com.apple.Safari"
            )
        )
    }
    .padding()
}
