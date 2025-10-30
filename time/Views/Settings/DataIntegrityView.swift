import SwiftUI

struct DataIntegrityView: View {
    @StateObject private var conflictResolver = DataConflictResolver(
        activityManager: ActivityManager.shared,
        timeEntryManager: TimeEntryManager.shared
    )
    
    @State private var validationResult: DataValidationResult?
    @State private var isScanning = false
    @State private var showingConflictDetails = false
    @State private var selectedConflict: DataConflict?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            
            if isScanning {
                scanningSection
            } else {
                actionButtonsSection
                
                if let result = validationResult {
                    validationResultSection(result)
                }
                
                if !conflictResolver.detectedConflicts.isEmpty {
                    conflictsSection
                }
                
                if !conflictResolver.resolutionResults.isEmpty {
                    resolutionHistorySection
                }
            }
        }
        .padding()
        .navigationTitle("Data Integrity")
        .sheet(isPresented: $showingConflictDetails) {
            if let conflict = selectedConflict {
                ConflictDetailView(
                    conflict: conflict,
                    resolver: conflictResolver
                )
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Integrity Management")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Scan for and resolve conflicts in your time tracking data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var scanningSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Scanning for data conflicts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button("Scan for Conflicts") {
                scanForConflicts()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Validate Data") {
                validateData()
            }
            .buttonStyle(.bordered)
            
            Button("Repair Data") {
                repairData()
            }
            .buttonStyle(.bordered)
            
            if !conflictResolver.detectedConflicts.isEmpty {
                Button("Auto-Resolve") {
                    autoResolveConflicts()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }
    
    private func validationResultSection(_ result: DataValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.isValid ? .green : .orange)
                
                Text("Validation Result")
                    .font(.headline)
                
                Spacer()
                
                Text(result.validatedAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if result.isValid {
                Text("✅ No data integrity issues found")
                    .foregroundColor(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Found \(result.conflicts.count) conflicts")
                        .foregroundColor(.orange)
                    
                    if !result.warnings.isEmpty {
                        Text("ℹ️ \(result.warnings.count) warnings")
                            .foregroundColor(.blue)
                    }
                    
                    if result.repairedItems > 0 {
                        Text("🔧 Repaired \(result.repairedItems) items")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Conflicts")
                .font(.headline)
            
            ForEach(conflictResolver.detectedConflicts, id: \.id) { conflict in
                ConflictRowView(conflict: conflict) {
                    selectedConflict = conflict
                    showingConflictDetails = true
                }
            }
        }
    }
    
    private var resolutionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Resolution History")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear History") {
                    conflictResolver.clearResolutionHistory()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            ForEach(conflictResolver.resolutionResults, id: \.conflictId) { result in
                ResolutionResultRowView(result: result)
            }
        }
    }
    
    // MARK: - Actions
    
    private func scanForConflicts() {
        isScanning = true
        Task {
            await conflictResolver.scanForConflicts()
            await MainActor.run {
                isScanning = false
            }
        }
    }
    
    private func validateData() {
        isScanning = true
        Task {
            let result = await conflictResolver.validateDataIntegrity()
            await MainActor.run {
                validationResult = result
                isScanning = false
            }
        }
    }
    
    private func repairData() {
        isScanning = true
        Task {
            let result = await conflictResolver.repairDataIntegrity()
            await MainActor.run {
                validationResult = result
                isScanning = false
            }
        }
    }
    
    private func autoResolveConflicts() {
        isScanning = true
        Task {
            await conflictResolver.resolveConflictsAutomatically()
            await MainActor.run {
                isScanning = false
            }
        }
    }
}

struct ConflictRowView: View {
    let conflict: DataConflict
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        severityIcon
                        Text(conflictTypeDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(conflict.items.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if conflict.overlapDuration > 0 {
                        Text("Overlap: \(ActivityDataProcessor.formatDuration(conflict.overlapDuration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Suggested: \(resolutionDescription)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var severityIcon: some View {
        Image(systemName: severityIconName)
            .foregroundColor(severityColor)
    }
    
    private var severityIconName: String {
        switch conflict.severity {
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.octagon.fill"
        }
    }
    
    private var severityColor: Color {
        switch conflict.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    private var resolutionDescription: String {
        switch conflict.suggestedResolution {
        case .mergeItems: return "Merge Items"
        case .keepFirst: return "Keep First"
        case .keepLast: return "Keep Last"
        case .keepLongest: return "Keep Longest"
        case .splitOverlap: return "Split Overlap"
        case .deleteInvalid: return "Delete Invalid"
        case .manualReview: return "Manual Review"
        }
    }
    
    private var conflictTypeDescription: String {
        switch conflict.type {
        case .overlappingTimeEntries:
            return "Overlapping Time Entries"
        case .overlappingActivities:
            return "Overlapping Activities"
        case .activityTimeEntryMismatch:
            return "Activity-Time Entry Mismatch"
        case .duplicateEntries:
            return "Duplicate Entries"
        case .invalidDuration:
            return "Invalid Duration"
        case .futureTimestamp:
            return "Future Timestamp"
        }
    }
}

struct ResolutionResultRowView: View {
    let result: ConflictResolutionResult
    
    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(resolutionDescription)
                    .font(.subheadline)
                
                if !result.success, let error = result.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Text(result.resolvedAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if result.success {
                VStack(alignment: .trailing, spacing: 2) {
                    if !result.modifiedItems.isEmpty {
                        Text("\(result.modifiedItems.count) modified")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if !result.deletedItems.isEmpty {
                        Text("\(result.deletedItems.count) deleted")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var resolutionDescription: String {
        switch result.resolution {
        case .mergeItems: return "Merged Items"
        case .keepFirst: return "Kept First Item"
        case .keepLast: return "Kept Last Item"
        case .keepLongest: return "Kept Longest Item"
        case .splitOverlap: return "Split Overlap"
        case .deleteInvalid: return "Deleted Invalid Items"
        case .manualReview: return "Manual Review Required"
        }
    }
}

struct ConflictDetailView: View {
    let conflict: DataConflict
    let resolver: DataConflictResolver
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedResolution: ConflictResolution
    @State private var isResolving = false
    
    init(conflict: DataConflict, resolver: DataConflictResolver) {
        self.conflict = conflict
        self.resolver = resolver
        self._selectedResolution = State(initialValue: conflict.suggestedResolution)
    }
    
    // MARK: - Computed Properties
    
    private var conflictTypeDescription: String {
        switch conflict.type {
        case .overlappingTimeEntries:
            return "Overlapping Time Entries"
        case .overlappingActivities:
            return "Overlapping Activities"
        case .activityTimeEntryMismatch:
            return "Activity-Time Entry Mismatch"
        case .duplicateEntries:
            return "Duplicate Entries"
        case .invalidDuration:
            return "Invalid Duration"
        case .futureTimestamp:
            return "Future Timestamp"
        }
    }
    
    private var severityDescription: String {
        switch conflict.severity {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    private var availableResolutions: [ConflictResolution] {
        switch conflict.type {
        case .overlappingTimeEntries, .overlappingActivities:
            return [.mergeItems, .keepFirst, .keepLast, .keepLongest, .manualReview]
        case .duplicateEntries:
            return [.keepFirst, .keepLast, .keepLongest, .manualReview]
        case .invalidDuration, .futureTimestamp:
            return [.deleteInvalid, .manualReview]
        case .activityTimeEntryMismatch:
            return [.manualReview]
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                conflictInfoSection
                itemsSection
                resolutionSection
                
                Spacer()
                
                actionButtonsSection
            }
            .padding()
            .navigationTitle("Conflict Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    

    
    private var conflictInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Conflict Information")
                    .font(.headline)
            }
            
            Text("Type: \(self.conflictTypeDescription)")
            Text("Severity: \(self.severityDescription)")
            
            if self.conflict.overlapDuration > 0 {
                Text("Overlap Duration: \(ActivityDataProcessor.formatDuration(self.conflict.overlapDuration))")
            }
            
            Text("Detected: \(self.conflict.detectedAt, style: .relative) ago")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Affected Items")
                .font(.headline)
            
            ForEach(Array(self.conflict.items.enumerated()), id: \.offset) { index, item in
                ConflictItemRowView(item: item, index: index + 1)
            }
        }
    }
    
    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resolution Strategy")
                .font(.headline)
            
            Picker("Resolution", selection: self.$selectedResolution) {
                ForEach(self.availableResolutions, id: \.self) { resolution in
                    Text(self.resolutionName(resolution))
                        .tag(resolution)
                }
            }
            .pickerStyle(.menu)
            
            Text(self.resolutionDescription(self.selectedResolution))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionButtonsSection: some View {
        HStack {
            Button("Cancel") {
                self.dismiss()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(self.isResolving ? "Resolving..." : "Apply Resolution") {
                self.applyResolution()
            }
            .buttonStyle(.borderedProminent)
            .disabled(self.isResolving)
        }
    }
    
    private func resolutionName(_ resolution: ConflictResolution) -> String {
        switch resolution {
        case .mergeItems: return "Merge Items"
        case .keepFirst: return "Keep First"
        case .keepLast: return "Keep Last"
        case .keepLongest: return "Keep Longest"
        case .splitOverlap: return "Split Overlap"
        case .deleteInvalid: return "Delete Invalid"
        case .manualReview: return "Manual Review"
        }
    }
    
    private func resolutionDescription(_ resolution: ConflictResolution) -> String {
        switch resolution {
        case .mergeItems: return "Combine overlapping items into a single item"
        case .keepFirst: return "Keep the earliest item and remove others"
        case .keepLast: return "Keep the latest item and remove others"
        case .keepLongest: return "Keep the item with the longest duration"
        case .splitOverlap: return "Split overlapping portions (requires manual review)"
        case .deleteInvalid: return "Remove items with invalid data"
        case .manualReview: return "Mark for manual review and resolution"
        }
    }
    
    private func applyResolution() {
        self.isResolving = true
        Task {
            await self.resolver.resolveConflict(self.conflict, resolution: self.selectedResolution)
            await MainActor.run {
                self.isResolving = false
                self.dismiss()
            }
        }
    }
}

struct ConflictItemRowView: View {
    let item: ConflictItem
    let index: Int
    
    var body: some View {
        HStack {
            Text("\(index).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: itemIcon)
                        .foregroundColor(itemColor)
                    
                    Text(itemTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(ActivityDataProcessor.formatDuration(item.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(item.startTime, style: .time) - \(item.endTime, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(6)
    }
    
    private var itemIcon: String {
        switch item {
        case .activity: return "app.fill"
        case .timeEntry: return "clock.fill"
        }
    }
    
    private var itemColor: Color {
        switch item {
        case .activity: return .blue
        case .timeEntry: return .green
        }
    }
    
    private var itemTitle: String {
        switch item {
        case .activity(let activity):
            return activity.bestDisplayTitle
        case .timeEntry(let timeEntry):
            return timeEntry.title
        }
    }
}

#Preview {
    DataIntegrityView()
}