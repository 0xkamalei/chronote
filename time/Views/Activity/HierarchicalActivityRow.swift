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
    
    // Default width, but could be made adjustable via binding in parent if needed
    @State private var durationWidth: CGFloat = 60

    var body: some View {
        HStack(spacing: 8) {
            // Duration on the left with fixed but wider width
            Text(group.durationString)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: durationWidth, alignment: .trailing)
                .lineLimit(1)
            
            // App icon
            if group.level == .appName {
                AppIconView(bundleId: group.bundleId, size: 18)
            } else if group.level == .detail {
                // No icon for detail level, just alignment padding or maybe a small dot?
                // Or maybe use the clock icon defined in levelIcon
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 18)
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
