import SwiftUI

struct SidebarView: View {
    @Binding var selectedSidebar: String?
    @Binding var selectedProject: Project?
    @State private var isMyProjectsExpanded: Bool = true
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(selection: $selectedSidebar) {
            Section {
                NavigationLink(value: "Activities") {
                    Label("Activities", systemImage: "clock")
                }
                NavigationLink(value: "Stats") {
                    Label("Stats", systemImage: "chart.bar")
                }
                NavigationLink(value: "Reports") {
                    Label("Reports", systemImage: "doc.text")
                }
            }
            
            Section(header: Text("Projects")) {
                HStack {
                    Label("All Activities", systemImage: "tray.full")
                    Spacer()
                    Text("37m")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .tag("All Activities")
                
                HStack {
                    Label("Unassigned", systemImage: "questionmark.circle")
                    Spacer()
                    Text("37m")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .tag("Unassigned")
                
                // My Projects as a folding item
                DisclosureGroup(isExpanded: $isMyProjectsExpanded) {
                    ForEach(appState.projectTree) { project in
                        ProjectRowView(project: project, selectedProject: $selectedProject)
                    }
                    .onMove(perform: moveProjects)
                    .deleteDisabled(true)
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("My Projects")
                        Spacer()
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Time Tracker")
    }
    
    private func moveProjects(from source: IndexSet, to destination: Int) {
        appState.moveProject(from: source, to: destination, parentID: nil)
    }
}
