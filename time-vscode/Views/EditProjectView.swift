import SwiftUI

struct EditProjectView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    @State private var projectName: String = "Project"
    @State private var includeActivities: Bool = false
    @State private var notes: String = ""
    @State private var parent: Project? = nil
    @State private var color: Color = .blue
    @State private var rating: Double = 0.5
    @State private var archived: Bool = false
    @State private var rules: [Rule] = [Rule()]
    @State private var ruleGroupCondition: RuleGroupCondition = .all
    @State private var isRuleEditorExpanded: Bool = true

    enum RuleGroupCondition: String, CaseIterable, Identifiable {
        case all = "All"
        case any = "Any"
        
        var id: String { self.rawValue }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Project")
                .font(.title)
            
            Text("Projects let you organize your time by what you worked on.")
                .foregroundColor(.secondary)

            Form {
                TextField("Name:", text: $projectName)
                Picker("Parent:", selection: $parent) {
                    Text("None").tag(nil as Project?)
                    ForEach(appState.projectTree, id: \.id) { project in
                        ProjectPickerItem(project: project, level: 0)
                    }
                }
                Toggle(isOn: $includeActivities) {
                    Text("Include any activities with \"\(projectName)\" in their title or path")
                }
                
                TextField("Notes:", text: $notes, axis: .vertical)
                    .lineLimit(3...)

                ColorPicker("Color:", selection: $color)
                
                HStack {
                    Text("Rating:")
                    Slider(value: $rating, in: 0...1)
                    Text(rating > 0.5 ? "PRODUCTIVE" : "UNPRODUCTIVE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle(isOn: $archived) {
                    Text("Archived")
                }
                Text("If selected, this project and all of its children will be hidden in various parts of the app and their rules will be ignored.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            DisclosureGroup("Rule Editor (advanced)", isExpanded: $isRuleEditorExpanded) {
                VStack {
                    HStack {
                        Picker("Condition", selection: $ruleGroupCondition) {
                            ForEach(RuleGroupCondition.allCases) { condition in
                                Text(condition.rawValue).tag(condition)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("of the following are true")
                        Spacer()
                        Button(action: addRule) {
                            Image(systemName: "plus")
                        }
                    }
                    
                    ForEach($rules) { $rule in
                        HStack {
                            Picker("Type", selection: $rule.type) {
                                ForEach(RuleType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .frame(minWidth: 150)
                            
                            Picker("Condition", selection: $rule.condition) {
                                ForEach(RuleCondition.allCases) { condition in
                                    Text(condition.rawValue).tag(condition)
                                }
                            }
                            .frame(minWidth: 120)
                            
                            TextField("Value", text: $rule.value)
                            
                            Button(action: { removeRule(rule) }) {
                                Image(systemName: "minus")
                            }
                        }
                    }
                }
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Spacer()
                Button("Save Project") {
                    // TODO: Add save logic
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 500, idealWidth: 600)
    }
    
    private func addRule() {
        rules.append(Rule())
    }
    
    private func removeRule(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
    }
}

#Preview {
    EditProjectView(isPresented: .constant(true))
        .environmentObject(AppState())
}
