import SwiftUI
import SwiftData

struct RuleManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var ruleManager: RuleManager
    @StateObject private var ruleEngine: RuleEngine
    @State private var showingCreateRule = false
    @State private var selectedRule: Rule?
    @State private var showingDeleteAlert = false
    @State private var ruleToDelete: Rule?
    @State private var searchText = ""
    
    init(modelContext: ModelContext) {
        let ruleManager = RuleManager(modelContext: modelContext)
        let ruleEngine = RuleEngine(ruleManager: ruleManager, modelContext: modelContext)
        self._ruleManager = StateObject(wrappedValue: ruleManager)
        self._ruleEngine = StateObject(wrappedValue: ruleEngine)
    }
    
    var filteredRules: [Rule] {
        if searchText.isEmpty {
            return ruleManager.rules
        } else {
            return ruleManager.rules.filter { rule in
                rule.name.localizedCaseInsensitiveContains(searchText) ||
                rule.conditions.contains { condition in
                    condition.displayName.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Rules List
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search rules...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top)
                
                // Rules List
                List(filteredRules, id: \.id, selection: $selectedRule) { rule in
                    RuleRowView(rule: rule, ruleManager: ruleManager)
                        .contextMenu {
                            RuleContextMenu(rule: rule, ruleManager: ruleManager) {
                                ruleToDelete = rule
                                showingDeleteAlert = true
                            }
                        }
                }
                .listStyle(.sidebar)
                
                // Statistics Footer
                RuleStatisticsFooter(ruleManager: ruleManager, ruleEngine: ruleEngine)
            }
            .navigationTitle("Rules")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Rule") {
                        showingCreateRule = true
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Menu("Actions") {
                        Button("Refresh Rules") {
                            ruleManager.loadRules()
                        }
                        
                        Divider()
                        
                        Button("Apply All Rules") {
                            Task {
                                // This would need ProjectManager integration
                                // try await ruleEngine.applyRulesRetroactively(from: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), projectManager: projectManager)
                            }
                        }
                        .disabled(ruleEngine.isProcessing)
                    }
                }
            }
        } detail: {
            // Rule Detail View
            if let selectedRule = selectedRule {
                RuleDetailView(rule: selectedRule, ruleManager: ruleManager, ruleEngine: ruleEngine)
            } else {
                RuleEmptyStateView()
            }
        }
        .sheet(isPresented: $showingCreateRule) {
            CreateRuleView(ruleManager: ruleManager)
        }
        .alert("Delete Rule", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let rule = ruleToDelete {
                    try? ruleManager.deleteRule(rule)
                }
            }
        } message: {
            if let rule = ruleToDelete {
                Text("Are you sure you want to delete the rule '\(rule.name)'? This action cannot be undone.")
            }
        }
        .onAppear {
            ruleManager.loadRules()
        }
    }
}

// MARK: - Rule Row View

struct RuleRowView: View {
    let rule: Rule
    let ruleManager: RuleManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.name)
                        .font(.headline)
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)
                    
                    Spacer()
                    
                    if rule.priority > 0 {
                        Text("Priority: \(rule.priority)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text("\(rule.conditions.count) condition\(rule.conditions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let action = rule.action {
                    Text(action.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if rule.applicationCount > 0 {
                    Text("Applied \(rule.applicationCount) times")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in
                    try? ruleManager.toggleRule(rule)
                }
            ))
            .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Rule Context Menu

struct RuleContextMenu: View {
    let rule: Rule
    let ruleManager: RuleManager
    let onDelete: () -> Void
    
    var body: some View {
        Button("Duplicate") {
            try? ruleManager.duplicateRule(rule)
        }
        
        Button(rule.isEnabled ? "Disable" : "Enable") {
            try? ruleManager.toggleRule(rule)
        }
        
        Divider()
        
        Button("Delete", role: .destructive) {
            onDelete()
        }
    }
}

// MARK: - Statistics Footer

struct RuleStatisticsFooter: View {
    let ruleManager: RuleManager
    let ruleEngine: RuleEngine
    
    var body: some View {
        let stats = ruleEngine.getRuleStatistics()
        
        VStack(spacing: 4) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rules: \(stats.ruleStatistics.totalRules)")
                        .font(.caption2)
                    Text("Enabled: \(stats.ruleStatistics.enabledRules)")
                        .font(.caption2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Applications: \(stats.ruleStatistics.totalApplications)")
                        .font(.caption2)
                    Text("Match Rate: \(String(format: "%.1f", stats.ruleMatchPercentage))%")
                        .font(.caption2)
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Empty State View

struct RuleEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Select a Rule")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Choose a rule from the sidebar to view its details and configuration.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RuleManagementView(modelContext: ModelContext(try! ModelContainer(for: Rule.self)))
}