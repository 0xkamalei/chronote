import SwiftUI
import SwiftData
import os

/// Main view for displaying daily insights and analysis
struct InsightView: View {
    let date: Date
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analysisManager = AnalysisManager.shared
    
    @State private var insight: DailyInsight?
    @State private var timeStructure: TimeStructure?
    @State private var behavioralBlocks: [BehavioralBlock] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let logger = Logger(subsystem: "dev.leix.chronote", category: "InsightView")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Analyzing your day...")
                        .padding()
                } else if let error = errorMessage {
                    errorView(error)
                } else if let insight = insight {
                    // Content
                    NarrativeHeaderView(
                        headline: insight.headline,
                        subtext: insight.subtext
                    )
                    
                    if let structure = timeStructure {
                        TimeStructureView(structure: structure)
                    }
                    
                    if !behavioralBlocks.isEmpty {
                        BehavioralBlocksListView(blocks: behavioralBlocks)
                    }
                    
                    if !insight.comparisonMetrics.isEmpty {
                        DailyComparisonView(comparisonData: parseComparisons(insight.comparisonMetrics))
                    }
                } else {
                    emptyStateView
                }
            }
            .padding([.horizontal, .top], 32)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadInsight()
        }
        .onChange(of: date) { _, _ in
            Task {
                await loadInsight()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Data Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking your activities to see insights here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Analysis Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadInsight()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
    
    private func loadInsight() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Try to get or create insight
            let loadedInsight = try await analysisManager.getOrCreateInsight(for: date, modelContext: modelContext)
            
            // Load related data
            let loadedStructure = try analysisManager.getTimeStructure(for: date, modelContext: modelContext)
            let loadedBlocks = try analysisManager.getBehavioralBlocks(for: date, modelContext: modelContext)
            
            await MainActor.run {
                insight = loadedInsight
                timeStructure = loadedStructure
                behavioralBlocks = loadedBlocks
                isLoading = false
            }
            
            logger.info("Loaded insight for \(date)")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            logger.error("Failed to load insight: \(error.localizedDescription)")
        }
    }
    
    // Parse comparison metrics from dictionary
    private func parseComparisons(_ dict: [String: String]) -> [ComparisonMetric] {
        var comparisons: [ComparisonMetric] = []
        
        // Expected format: "value (±percentage%)"
        for (name, valueString) in dict {
            // Simple parsing - extract value and change
            let components = valueString.components(separatedBy: " (")
            guard components.count == 2 else { continue }
            
            let value = components[0]
            let changeString = components[1].replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "%", with: "")
            
            if let change = Double(changeString) {
                let isPositive = !["Fragmented Time", "Passive Time"].contains(name)
                comparisons.append(ComparisonMetric(
                    name: name,
                    value: value,
                    change: change,
                    isPositive: isPositive
                ))
            }
        }
        
        return comparisons
    }
}

#Preview {
    InsightView(date: Date())
        .modelContainer(for: [Activity.self, Session.self, BehavioralBlock.self, TimeStructure.self, DailyInsight.self])
}
