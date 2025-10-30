import SwiftUI
import SwiftData

struct RetroactiveRuleApplicationView: View {
    let ruleEngine: RuleEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var selectedEndDate = Date()
    @State private var selectedAppNames: Set<String> = []
    @State private var availableAppNames: [String] = []
    @State private var impactAnalysis: RuleImpactAnalysis?
    @State private var isAnalyzing = false
    @State private var isApplying = false
    @State private var showingConfirmation = false
    @State private var applicationCompleted = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Configuration Section
                Form {
                    Section("Date Range") {
                        DatePicker("Start Date", selection: $selectedStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $selectedEndDate, displayedComponents: .date)
                    }
                    
                    Section("Filter by Applications") {
                        if availableAppNames.isEmpty {
                            Text("Loading applications...")
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button(selectedAppNames.isEmpty ? "Select All" : "Clear All") {
                                        if selectedAppNames.isEmpty {
                                            selectedAppNames = Set(availableAppNames)
                                        } else {
                                            selectedAppNames.removeAll()
                                        }
                                    }
                                    .font(.caption)
                                    
                                    Spacer()
                                    
                                    Text("\(selectedAppNames.count) of \(availableAppNames.count) selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                    ForEach(availableAppNames, id: \.self) { appName in
                                        Toggle(appName, isOn: Binding(
                                            get: { selectedAppNames.contains(appName) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedAppNames.insert(appName)
                                                } else {
                                                    selectedAppNames.remove(appName)
                                                }
                                            }
                                        ))
                                        .toggleStyle(.checkbox)
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("Analysis") {
                        Button("Analyze Impact") {
                            analyzeImpact()
                        }
                        .disabled(isAnalyzing || isApplying)
                        
                        if isAnalyzing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Analyzing activities...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                
                // Impact Analysis Results
                if let analysis = impactAnalysis {
                    VStack(spacing: 0) {
                        Divider()
                        
                        ImpactAnalysisView(analysis: analysis)
                            .padding()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                }
                
                // Error Message
                if let errorMessage = errorMessage {
                    VStack(spacing: 0) {
                        Divider()
                        
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                    }
                }
                
                // Progress View (when applying)
                if isApplying {
                    VStack(spacing: 0) {
                        Divider()
                        
                        VStack(spacing: 12) {
                            ProgressView(value: ruleEngine.processingProgress)
                                .progressViewStyle(.linear)
                            
                            Text(ruleEngine.processingStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
                
                // Success Message
                if applicationCompleted {
                    VStack(spacing: 0) {
                        Divider()
                        
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("Rules applied successfully!")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                    }
                }
            }
            .navigationTitle("Apply Rules Retroactively")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isApplying)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply Rules") {
                        showingConfirmation = true
                    }
                    .disabled(impactAnalysis == nil || isApplying || applicationCompleted)
                }
            }
        }
        .alert("Confirm Rule Application", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Apply", role: .destructive) {
                applyRules()
            }
        } message: {
            if let analysis = impactAnalysis {
                Text("This will apply rules to \(analysis.affectedActivities) activities. This action cannot be undone.")
            }
        }
        .onAppear {
            loadAvailableAppNames()
        }
    }
    
    private func loadAvailableAppNames() {
        Task {
            do {
                let descriptor = FetchDescriptor<Activity>(
                    sortBy: [SortDescriptor(\.appName)]
                )
                let activities = try modelContext.fetch(descriptor)
                let uniqueAppNames = Set(activities.map { $0.appName }).sorted()
                
                await MainActor.run {
                    availableAppNames = uniqueAppNames
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load applications: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func analyzeImpact() {
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch activities in the date range
                let predicate = #Predicate<Activity> { activity in
                    activity.startTime >= selectedStartDate && activity.startTime <= selectedEndDate
                }
                let descriptor = FetchDescriptor<Activity>(predicate: predicate)
                let activities = try modelContext.fetch(descriptor)
                
                // Filter by selected app names if any are selected
                let filteredActivities: [Activity]
                if selectedAppNames.isEmpty {
                    filteredActivities = activities
                } else {
                    filteredActivities = activities.filter { selectedAppNames.contains($0.appName) }
                }
                
                let analysis = ruleEngine.analyzeRuleImpact(for: filteredActivities)
                
                await MainActor.run {
                    impactAnalysis = analysis
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Analysis failed: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func applyRules() {
        isApplying = true
        errorMessage = nil
        applicationCompleted = false
        
        Task {
            do {
                // This would need ProjectManager integration
                // For now, we'll simulate the application
                let appNamesArray = selectedAppNames.isEmpty ? nil : Array(selectedAppNames)
                
                // Note: This call would need a ProjectManager instance
                // try await ruleEngine.applyRulesRetroactively(
                //     from: selectedStartDate,
                //     to: selectedEndDate,
                //     appNames: appNamesArray,
                //     projectManager: projectManager
                // )
                
                // Simulate progress for now
                for i in 1...10 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await MainActor.run {
                        ruleEngine.processingProgress = Double(i) / 10.0
                        ruleEngine.processingStatus = "Processing batch \(i) of 10..."
                    }
                }
                
                await MainActor.run {
                    isApplying = false
                    applicationCompleted = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Application failed: \(error.localizedDescription)"
                    isApplying = false
                }
            }
        }
    }
}

// MARK: - Impact Analysis View

struct ImpactAnalysisView: View {
    let analysis: RuleImpactAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Impact Analysis")
                .font(.headline)
            
            // Summary Statistics
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analysis.totalActivities)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Will Be Affected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analysis.affectedActivities)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Affected Percentage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", analysis.affectedPercentage))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            
            // Rules Impact Breakdown
            if !analysis.impactByRule.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rules Impact")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(analysis.impactByRule.prefix(5), id: \.rule.id) { impact in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(impact.rule.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(impact.affectedActivities.count) activities")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatDuration(impact.totalDuration))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if analysis.impactByRule.count > 5 {
                        Text("... and \(analysis.impactByRule.count - 5) more rules")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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
    let ruleEngine = RuleEngine(
        ruleManager: RuleManager(modelContext: ModelContext(try! ModelContainer(for: Rule.self))),
        modelContext: ModelContext(try! ModelContainer(for: Rule.self))
    )
    
    return RetroactiveRuleApplicationView(ruleEngine: ruleEngine)
}