import SwiftUI

struct SidebarView: View {
    @State private var isMyProjectsExpanded: Bool = true
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(selection: $appState.selectedSidebar) {
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
                // All Activities
                HStack {
                    Label("All Activities", systemImage: "tray.full")
                    Spacer()
                    Text("37m")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
                .background(appState.isSpecialItemSelected("All Activities") ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture {
                    appState.selectSpecialItem("All Activities")
                }
                
                // Unassigned
                HStack {
                    Label("Unassigned", systemImage: "questionmark.circle")
                    Spacer()
                    Text("37m")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
                .background(appState.isSpecialItemSelected("Unassigned") ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture {
                    appState.selectSpecialItem("Unassigned")
                }
                
                // My Projects as a folding item
                DisclosureGroup(isExpanded: $isMyProjectsExpanded) {
                    ForEach(appState.projectTree) { project in
                        ProjectRowView(project: project)
                    }
                    .onMove(perform: moveProjects)
                    .deleteDisabled(true)
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("My Projects")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .background(appState.isSpecialItemSelected("My Projects") ? Color.accentColor.opacity(0.2) : Color.clear)
                    .onTapGesture {
                        appState.selectSpecialItem("My Projects")
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
