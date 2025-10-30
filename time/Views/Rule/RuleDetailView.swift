import SwiftUI
import SwiftData

struct RuleDetailView: View {
    let rule: Rule
    let ruleManager: RuleManager
    let ruleEngine: RuleEngine
    
    @State private var showingEditSheet = false
    @State private var showingTestResults = false
    @State private var testResults: RuleTestResult?
    @State private var isTestingRule = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                RuleHeaderView(rule: rule, ruleManager: ruleManager)
                
                // Conditions Section
                RuleConditionsSection(rule: rule)
                
                // Action Section
                RuleActionSection(rule: rule)
                
                // Statistics Section
                RuleStatisticsSection(rule: rule)
                
                // Test Section
                RuleTestSection(
                    rule: rule,
                    ruleEngine: ruleEngine,
                    isTestingRule: $isTestingRule,
                    testResults: $testResults,
                    showingTestResults: $showingTestResults
                )
            }
            .padding()
        }
        .navigationTitle(rule.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRuleView(rule: rule, ruleManager: ruleManager)
        }
        .sheet(isPresented: $showingTestResults) {
            if let testResults = testResults {
                RuleTestResultsView(testResults: testResults)
            }
        }
    }
}

// MARK: - Rule Header

struct RuleHeaderView: View {
    let rule: Rule
    let ruleManager: RuleManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Created \(rule.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Toggle("Enabled", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { _ in
                            try? ruleManager.toggleRule(rule)
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    if rule.priority > 0 {
                        HStack {
                            Text("Priority:")
                                .font(.caption)
                            Text("\(rule.priority)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            if let lastApplied = rule.lastAppliedAt {
                Text("Last applied: \(lastApplied, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Conditions Section

struct RuleConditionsSection: View {
    let rule: Rule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conditions")
                .font(.headline)
            
            if rule.conditions.isEmpty {
                Text("No conditions defined")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(rule.conditions.enumerated()), id: \.offset) { index, condition in
                        HStack {
                            if index > 0 {
                                Text("AND")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Text(condition.displayName)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Action Section

struct RuleActionSection: View {
    let rule: Rule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action")
                .font(.headline)
            
            if let action = rule.action {
                HStack {
                    Text(action.displayName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    
                    Spacer()
                }
            } else {
                Text("No action defined")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Statistics Section

struct RuleStatisticsSection: View {
    let rule: Rule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Applications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(rule.applicationCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(rule.priority)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Test Section

struct RuleTestSection: View {
    let rule: Rule
    let ruleEngine: RuleEngine
    @Binding var isTestingRule: Bool
    @Binding var testResults: RuleTestResult?
    @Binding var showingTestResults: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Rule")
                .font(.headline)
            
            Text("Test this rule against recent activities to see how it would perform.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Test Against Last 7 Days") {
                    testRule(daysBack: 7)
                }
                .disabled(isTestingRule)
                
                Button("Test Against Last 30 Days") {
                    testRule(daysBack: 30)
                }
                .disabled(isTestingRule)
                
                Spacer()
                
                if isTestingRule {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let results = testResults {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Text("Last Test Results:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("View Details") {
                            showingTestResults = true
                        }
                        .font(.caption)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Matches")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(results.matchingActivities.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text("Match Rate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", results.matchPercentage))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Total Time")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDuration(results.totalDuration))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func testRule(daysBack: Int) {
        isTestingRule = true
        
        Task {
            do {
                let results = try ruleEngine.previewRuleApplication(rule, daysBack: daysBack)
                await MainActor.run {
                    testResults = results
                    isTestingRule = false
                }
            } catch {
                await MainActor.run {
                    isTestingRule = false
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    let rule = Rule(
        name: "Sample Rule",
        conditions: [
            .appName("Xcode", .contains),
            .timeRange(start: Date(), end: Date())
        ],
        action: .assignToProject("project-id")
    )
    
    return RuleDetailView(
        rule: rule,
        ruleManager: RuleManager(modelContext: ModelContext(try! ModelContainer(for: Rule.self))),
        ruleEngine: RuleEngine(
            ruleManager: RuleManager(modelContext: ModelContext(try! ModelContainer(for: Rule.self))),
            modelContext: ModelContext(try! ModelContainer(for: Rule.self))
        )
    )
}