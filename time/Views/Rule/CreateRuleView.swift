import SwiftUI
import SwiftData

struct CreateRuleView: View {
    let ruleManager: RuleManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var ruleName = ""
    @State private var conditions: [RuleCondition] = []
    @State private var selectedAction: RuleAction?
    @State private var priority = 0
    @State private var showingAddCondition = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Details") {
                    TextField("Rule Name", text: $ruleName)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("Priority")
                        Spacer()
                        Stepper("\(priority)", value: $priority, in: 0...100)
                    }
                }
                
                Section("Conditions") {
                    if conditions.isEmpty {
                        Text("No conditions added")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(conditions.enumerated()), id: \.offset) { index, condition in
                            HStack {
                                if index > 0 {
                                    Text("AND")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(condition.displayName)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                Button("Remove") {
                                    conditions.remove(at: index)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button("Add Condition") {
                        showingAddCondition = true
                    }
                }
                
                Section("Action") {
                    if let action = selectedAction {
                        HStack {
                            Text(action.displayName)
                            Spacer()
                            Button("Change") {
                                // Show action picker
                            }
                        }
                    } else {
                        Button("Select Action") {
                            // Show action picker
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createRule()
                    }
                    .disabled(!canCreateRule)
                }
            }
        }
        .sheet(isPresented: $showingAddCondition) {
            AddConditionView { condition in
                conditions.append(condition)
            }
        }
    }
    
    private var canCreateRule: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !conditions.isEmpty &&
        selectedAction != nil
    }
    
    private func createRule() {
        guard let action = selectedAction else { return }
        
        do {
            try ruleManager.createRule(
                name: ruleName.trimmingCharacters(in: .whitespacesAndNewlines),
                conditions: conditions,
                action: action,
                priority: priority
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Edit Rule View

struct EditRuleView: View {
    let rule: Rule
    let ruleManager: RuleManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var ruleName: String
    @State private var conditions: [RuleCondition]
    @State private var selectedAction: RuleAction?
    @State private var priority: Int
    @State private var isEnabled: Bool
    @State private var showingAddCondition = false
    @State private var errorMessage: String?
    
    init(rule: Rule, ruleManager: RuleManager) {
        self.rule = rule
        self.ruleManager = ruleManager
        self._ruleName = State(initialValue: rule.name)
        self._conditions = State(initialValue: rule.conditions)
        self._selectedAction = State(initialValue: rule.action)
        self._priority = State(initialValue: rule.priority)
        self._isEnabled = State(initialValue: rule.isEnabled)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Details") {
                    TextField("Rule Name", text: $ruleName)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("Priority")
                        Spacer()
                        Stepper("\(priority)", value: $priority, in: 0...100)
                    }
                    
                    Toggle("Enabled", isOn: $isEnabled)
                }
                
                Section("Conditions") {
                    if conditions.isEmpty {
                        Text("No conditions added")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(conditions.enumerated()), id: \.offset) { index, condition in
                            HStack {
                                if index > 0 {
                                    Text("AND")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(condition.displayName)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                Button("Remove") {
                                    conditions.remove(at: index)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button("Add Condition") {
                        showingAddCondition = true
                    }
                }
                
                Section("Action") {
                    if let action = selectedAction {
                        HStack {
                            Text(action.displayName)
                            Spacer()
                            Button("Change") {
                                // Show action picker
                            }
                        }
                    } else {
                        Button("Select Action") {
                            // Show action picker
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(!canSaveRule)
                }
            }
        }
        .sheet(isPresented: $showingAddCondition) {
            AddConditionView { condition in
                conditions.append(condition)
            }
        }
    }
    
    private var canSaveRule: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !conditions.isEmpty &&
        selectedAction != nil
    }
    
    private func saveRule() {
        guard let action = selectedAction else { return }
        
        do {
            try ruleManager.updateRule(
                rule,
                name: ruleName.trimmingCharacters(in: .whitespacesAndNewlines),
                conditions: conditions,
                action: action,
                priority: priority,
                isEnabled: isEnabled
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Add Condition View

struct AddConditionView: View {
    let onConditionAdded: (RuleCondition) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedConditionType = ConditionType.appName
    @State private var stringValue = ""
    @State private var matchType = RuleCondition.MatchType.contains
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var selectedDays: Set<Int> = []
    @State private var comparisonType = RuleCondition.ComparisonType.greaterThan
    @State private var durationMinutes = 5
    
    enum ConditionType: String, CaseIterable {
        case appName = "App Name"
        case windowTitle = "Window Title"
        case url = "URL"
        case documentPath = "Document Path"
        case timeRange = "Time Range"
        case dayOfWeek = "Day of Week"
        case duration = "Duration"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Condition Type") {
                    Picker("Type", selection: $selectedConditionType) {
                        ForEach(ConditionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Configuration") {
                    switch selectedConditionType {
                    case .appName, .windowTitle, .url, .documentPath:
                        TextField("Value", text: $stringValue)
                            .textFieldStyle(.roundedBorder)
                        
                        Picker("Match Type", selection: $matchType) {
                            ForEach(RuleCondition.MatchType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        
                    case .timeRange:
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        
                    case .dayOfWeek:
                        VStack(alignment: .leading) {
                            Text("Select Days")
                                .font(.headline)
                            
                            ForEach(1...7, id: \.self) { day in
                                Toggle(dayName(for: day), isOn: Binding(
                                    get: { selectedDays.contains(day) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedDays.insert(day)
                                        } else {
                                            selectedDays.remove(day)
                                        }
                                    }
                                ))
                            }
                        }
                        
                    case .duration:
                        Picker("Comparison", selection: $comparisonType) {
                            ForEach(RuleCondition.ComparisonType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            Text("Duration")
                            Spacer()
                            Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 1...1440)
                        }
                    }
                }
            }
            .navigationTitle("Add Condition")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCondition()
                    }
                    .disabled(!canAddCondition)
                }
            }
        }
    }
    
    private var canAddCondition: Bool {
        switch selectedConditionType {
        case .appName, .windowTitle, .url, .documentPath:
            return !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .timeRange:
            return startTime != endTime
        case .dayOfWeek:
            return !selectedDays.isEmpty
        case .duration:
            return durationMinutes > 0
        }
    }
    
    private func addCondition() {
        let condition: RuleCondition
        
        switch selectedConditionType {
        case .appName:
            condition = .appName(stringValue, matchType)
        case .windowTitle:
            condition = .windowTitle(stringValue, matchType)
        case .url:
            condition = .url(stringValue, matchType)
        case .documentPath:
            condition = .documentPath(stringValue, matchType)
        case .timeRange:
            condition = .timeRange(start: startTime, end: endTime)
        case .dayOfWeek:
            condition = .dayOfWeek(Array(selectedDays))
        case .duration:
            condition = .duration(comparison: comparisonType, minutes: durationMinutes)
        }
        
        onConditionAdded(condition)
        dismiss()
    }
    
    private func dayName(for day: Int) -> String {
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard day >= 1 && day <= 7 else { return "Invalid" }
        return dayNames[day - 1]
    }
}

#Preview {
    CreateRuleView(ruleManager: RuleManager(modelContext: ModelContext(try! ModelContainer(for: Rule.self))))
}