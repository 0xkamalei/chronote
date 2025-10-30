import SwiftUI
import SwiftData

/// Comprehensive search filters panel
struct SearchFiltersView: View {
    @ObservedObject var searchManager: SearchManager
    @State private var tempFilters: SearchFilters
    @State private var availableApps: [String] = []
    @State private var availableProjects: [Project] = []
    
    init(searchManager: SearchManager) {
        self.searchManager = searchManager
        self._tempFilters = State(initialValue: searchManager.activeFilters)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Search Filters")
                    .font(.headline)
                
                Spacer()
                
                Button("Reset") {
                    tempFilters.reset()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date Range Filter
                    dateRangeSection
                    
                    Divider()
                    
                    // Project Filter
                    projectFilterSection
                    
                    Divider()
                    
                    // Application Filter
                    applicationFilterSection
                    
                    Divider()
                    
                    // Duration Filter
                    durationFilterSection
                    
                    Divider()
                    
                    // Additional Options
                    additionalOptionsSection
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            // Action Buttons
            HStack {
                Button("Cancel") {
                    tempFilters = searchManager.activeFilters
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Apply Filters") {
                    searchManager.applyFilters(tempFilters)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!tempFilters.hasActiveFilters && !searchManager.activeFilters.hasActiveFilters)
            }
        }
        .padding()
        .onAppear {
            loadAvailableData()
        }
    }
    
    // MARK: - Date Range Section
    
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: Binding(
                        get: { tempFilters.startDate ?? Date() },
                        set: { tempFilters.startDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .disabled(tempFilters.startDate == nil)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: Binding(
                        get: { tempFilters.endDate ?? Date() },
                        set: { tempFilters.endDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .disabled(tempFilters.endDate == nil)
                }
            }
            
            HStack {
                Toggle("Enable date filter", isOn: Binding(
                    get: { tempFilters.startDate != nil || tempFilters.endDate != nil },
                    set: { enabled in
                        if enabled {
                            if tempFilters.startDate == nil {
                                tempFilters.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                            }
                            if tempFilters.endDate == nil {
                                tempFilters.endDate = Date()
                            }
                        } else {
                            tempFilters.startDate = nil
                            tempFilters.endDate = nil
                        }
                    }
                ))
                .toggleStyle(.checkbox)
                
                Spacer()
            }
            
            // Quick date range buttons
            HStack {
                quickDateButton("Today", days: 0)
                quickDateButton("Week", days: 7)
                quickDateButton("Month", days: 30)
                quickDateButton("3 Months", days: 90)
            }
        }
    }
    
    private func quickDateButton(_ title: String, days: Int) -> some View {
        Button(title) {
            let endDate = Date()
            let startDate = days == 0 ? 
                Calendar.current.startOfDay(for: endDate) :
                Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
            
            tempFilters.startDate = startDate
            tempFilters.endDate = endDate
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }
    
    // MARK: - Project Filter Section
    
    private var projectFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projects")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !tempFilters.selectedProjects.isEmpty {
                    Text("\(tempFilters.selectedProjects.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if availableProjects.isEmpty {
                Text("No projects available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(availableProjects, id: \.id) { project in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { tempFilters.selectedProjects.contains(project.id) },
                                set: { selected in
                                    if selected {
                                        tempFilters.selectedProjects.insert(project.id)
                                    } else {
                                        tempFilters.selectedProjects.remove(project.id)
                                    }
                                }
                            )) {
                                HStack {
                                    Circle()
                                        .fill(project.color)
                                        .frame(width: 12, height: 12)
                                    
                                    Text(project.name)
                                        .font(.system(size: 13))
                                }
                            }
                            .toggleStyle(.checkbox)
                            
                            Spacer()
                        }
                    }
                }
                .frame(maxHeight: 120)
                
                HStack {
                    Button("Select All") {
                        tempFilters.selectedProjects = Set(availableProjects.map { $0.id })
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    Button("Clear All") {
                        tempFilters.selectedProjects.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Application Filter Section
    
    private var applicationFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Applications")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !tempFilters.selectedApps.isEmpty {
                    Text("\(tempFilters.selectedApps.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if availableApps.isEmpty {
                Text("No applications available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(availableApps, id: \.self) { app in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { tempFilters.selectedApps.contains(app) },
                                set: { selected in
                                    if selected {
                                        tempFilters.selectedApps.insert(app)
                                    } else {
                                        tempFilters.selectedApps.remove(app)
                                    }
                                }
                            )) {
                                Text(app)
                                    .font(.system(size: 13))
                            }
                            .toggleStyle(.checkbox)
                            
                            Spacer()
                        }
                    }
                }
                .frame(maxHeight: 120)
                
                HStack {
                    Button("Select All") {
                        tempFilters.selectedApps = Set(availableApps)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    Button("Clear All") {
                        tempFilters.selectedApps.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Duration Filter Section
    
    private var durationFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Minimum (minutes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0", value: Binding(
                        get: { 
                            if let duration = tempFilters.minDuration {
                                return Int(duration / 60)
                            }
                            return 0
                        },
                        set: { minutes in
                            tempFilters.minDuration = minutes > 0 ? TimeInterval(minutes * 60) : nil
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maximum (minutes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("∞", value: Binding(
                        get: { 
                            if let duration = tempFilters.maxDuration {
                                return Int(duration / 60)
                            }
                            return 0
                        },
                        set: { minutes in
                            tempFilters.maxDuration = minutes > 0 ? TimeInterval(minutes * 60) : nil
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                
                Spacer()
            }
            
            // Quick duration buttons
            HStack {
                quickDurationButton("1m+", minutes: 1)
                quickDurationButton("5m+", minutes: 5)
                quickDurationButton("15m+", minutes: 15)
                quickDurationButton("1h+", minutes: 60)
            }
        }
    }
    
    private func quickDurationButton(_ title: String, minutes: Int) -> some View {
        Button(title) {
            tempFilters.minDuration = TimeInterval(minutes * 60)
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(4)
    }
    
    // MARK: - Additional Options Section
    
    private var additionalOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Exclude idle time", isOn: $tempFilters.excludeIdleTime)
                    .toggleStyle(.checkbox)
                
                Toggle("Include archived items", isOn: $tempFilters.includeArchived)
                    .toggleStyle(.checkbox)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAvailableData() {
        // This would typically load from the search manager or data source
        // For now, we'll use placeholder data
        availableApps = ["Xcode", "Safari", "Mail", "Finder", "Terminal"]
        availableProjects = [] // Would be loaded from ProjectManager
    }
}

// MARK: - Preview

#Preview {
    @StateObject var searchManager = SearchManager(modelContext: ModelContext(try! ModelContainer(for: Activity.self, TimeEntry.self, Project.self)))
    
    SearchFiltersView(searchManager: searchManager)
        .frame(width: 350, height: 400)
}