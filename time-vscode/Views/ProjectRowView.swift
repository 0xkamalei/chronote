import SwiftUI

struct ProjectRowView: View {
    @ObservedObject var project: Project
    @EnvironmentObject private var appState: AppState

    init(project: Project) {
        self.project = project
    }

    var body: some View {
        if !project.children.isEmpty {
            DisclosureGroup(
                content: {
                    ForEach(project.children) { child in
                        ProjectRowView(project: child)
                    }
                    .onMove { source, destination in
                        moveChildProjects(from: source, to: destination)
                    }
                },
                label: { projectLabel }
            )
        } else {
            projectLabel
        }
    }

    private var projectLabel: some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundColor(project.color)
                .font(.system(size: 12))
            Text(project.name)
            Spacer()
        }
        .contentShape(Rectangle())
        .background(appState.isProjectSelected(project) ? Color.accentColor.opacity(0.2) : Color.clear)
        .onTapGesture {
            appState.selectProject(project)
        }
    }
    
    private func moveChildProjects(from source: IndexSet, to destination: Int) {
        appState.moveProject(from: source, to: destination, parentID: project.id)
    }
}
