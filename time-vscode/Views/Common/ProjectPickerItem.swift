import SwiftUI

// Helper view for displaying projects in tree structure
struct ProjectPickerItem: View {
    let project: Project
    let level: Int
    
    var body: some View {
        Group {
            // Current project with indentation - separate colored dot and default text
            Text("\(String(repeating: "  ", count: level))") +
            Text("● ").foregroundColor(project.color) +
            Text(project.name).foregroundColor(.primary)
        }
        .font(.system(size: 13))
        .tag(project as Project?)
        
        // Recursively display child projects
        ForEach(project.children.sorted(by: { $0.name < $1.name }), id: \.id) { child in
            ProjectPickerItem(project: child, level: level + 1)
        }
    }
}
