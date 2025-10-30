import Foundation
import os
import SwiftData
import SwiftUI

@MainActor
class TimeEntryManager: ObservableObject {
    // MARK: - Singleton

    static let shared = TimeEntryManager()

    // MARK: - Published Properties

    @Published private(set) var timeEntries: [TimeEntry] = []
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private Properties

    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.time-vscode.TimeEntryManager", category: "TimeEntryTracking")
    
    // Debouncing for notifications
    private var notificationDebounceTimer: Timer?
    private let notificationDebounceInterval: TimeInterval = 0.3
    private var pendingNotificationUserInfo: [String: Any] = [:]

    // MARK: - Initialization

    private init() {
        timeEntries = []
    }
    
    deinit {
        notificationDebounceTimer?.invalidate()
    }

    /// Sets the SwiftData model context for persistence operations and initializes time entry tracking
    /// - Parameter modelContext: The ModelContext to use for SwiftData operations
    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext

        Task { @MainActor in
            do {
                try await loadTimeEntries()
                logger.info("TimeEntryManager initialized with modelContext")
            } catch {
                logger.error("Failed to load time entries after setting modelContext: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Loading Operations

    /// Loads time entries from persistent storage
    /// - Throws: TimeEntryError if loading fails
    func loadTimeEntries() async throws {
        isLoading = true
        defer { isLoading = false }

        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }

        do {
            let descriptor = FetchDescriptor<TimeEntry>(
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )

            let fetchedTimeEntries = try modelContext.fetch(descriptor)
            timeEntries = fetchedTimeEntries

            logger.info("Loaded \(fetchedTimeEntries.count) time entries from persistence")

        } catch {
            logger.error("Failed to fetch time entries: \(error.localizedDescription)")
            throw TimeEntryError.persistenceFailure("Failed to fetch time entries: \(error.localizedDescription)")
        }
    }

    /// Saves time entries to persistent storage
    /// - Throws: TimeEntryError if saving fails
    func saveTimeEntries() async throws {
        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }

        do {
            try modelContext.save()
            logger.info("Time entries saved successfully")
        } catch {
            logger.error("Failed to save time entries: \(error.localizedDescription)")
            throw TimeEntryError.persistenceFailure("Failed to save time entries: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Management

    /// Notifies observers that time entries have changed with debouncing
    private func notifyTimeEntriesChanged(operation: String = "unknown", timeEntryId: String? = nil) {
        // Always send objectWillChange immediately for reactive UI
        objectWillChange.send()
        
        // Prepare notification user info
        var userInfo: [String: Any] = [
            "timeEntries": timeEntries,
            "timeEntryCount": timeEntries.count,
            "timestamp": Date(),
            "operation": operation
        ]
        
        if let timeEntryId = timeEntryId {
            userInfo["timeEntryId"] = timeEntryId
        }
        
        // Store pending notification info
        pendingNotificationUserInfo = userInfo
        
        // Cancel existing timer and start new one for debouncing
        notificationDebounceTimer?.invalidate()
        notificationDebounceTimer = Timer.scheduledTimer(withTimeInterval: notificationDebounceInterval, repeats: false) { [weak self] _ in
            self?.sendDebouncedNotification()
        }
    }
    
    /// Sends the debounced notification
    private func sendDebouncedNotification() {
        NotificationCenter.default.post(
            name: .timeEntryDidChange,
            object: self,
            userInfo: pendingNotificationUserInfo
        )
        
        logger.info("Debounced time entry change notification sent - \(self.timeEntries.count) entries")
        pendingNotificationUserInfo.removeAll()
    }
    
    /// Sends immediate notification for time entry deletion
    private func notifyTimeEntryDeleted(timeEntryId: String, batchOperation: Bool = false) {
        let userInfo: [String: Any] = [
            "timeEntryId": timeEntryId,
            "timestamp": Date(),
            "batchOperation": batchOperation
        ]
        
        NotificationCenter.default.post(
            name: .timeEntryWasDeleted,
            object: nil,
            userInfo: userInfo
        )
        
        logger.info("Time entry deletion notification sent - ID: \(timeEntryId)")
    }

    /// Forces an immediate UI update
    @MainActor
    func forceUIUpdate() {
        notifyTimeEntriesChanged(operation: "forceUpdate")
    }

    // MARK: - Core CRUD Operations

    /// Creates a new time entry with comprehensive validation
    /// - Parameters:
    ///   - projectId: Optional project ID to associate with the time entry
    ///   - title: The title/description of the time entry
    ///   - notes: Optional notes for the time entry
    ///   - startTime: The start time of the work session
    ///   - endTime: The end time of the work session
    /// - Returns: The created TimeEntry
    /// - Throws: TimeEntryError if validation fails or creation fails
    func createTimeEntry(
        projectId: String? = nil,
        title: String,
        notes: String? = nil,
        startTime: Date,
        endTime: Date
    ) async throws -> TimeEntry {
        // Validate input parameters
        let validationResult = validateTimeEntryInput(
            projectId: projectId,
            title: title,
            notes: notes,
            startTime: startTime,
            endTime: endTime
        )

        switch validationResult {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        // Create the time entry
        let timeEntry = TimeEntry(
            projectId: projectId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: startTime,
            endTime: endTime
        )

        // Insert into SwiftData context
        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }

        modelContext.insert(timeEntry)

        // Save to persistence
        try await saveTimeEntries()

        // Add to local array and sort
        timeEntries.append(timeEntry)
        timeEntries.sort { $0.startTime > $1.startTime }

        // Notify observers
        notifyTimeEntriesChanged(operation: "create", timeEntryId: timeEntry.id.uuidString)

        logger.info("Created time entry: \(title) (\(timeEntry.durationString))")

        return timeEntry
    }

    /// Updates an existing time entry with conflict resolution
    /// - Parameters:
    ///   - timeEntry: The time entry to update
    ///   - projectId: Optional new project ID
    ///   - title: Optional new title
    ///   - notes: Optional new notes
    ///   - startTime: Optional new start time
    ///   - endTime: Optional new end time
    /// - Throws: TimeEntryError if validation fails or update fails
    func updateTimeEntry(
        _ timeEntry: TimeEntry,
        projectId: String? = nil,
        title: String? = nil,
        notes: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) async throws {
        // Check if time entry still exists in our collection
        guard let entryIndex = timeEntries.firstIndex(where: { $0.id == timeEntry.id }) else {
            throw TimeEntryError.validationFailed("Time entry not found")
        }

        let targetEntry = timeEntries[entryIndex]

        // Prepare updated values
        let updatedProjectId = projectId ?? targetEntry.projectId
        let updatedTitle = title ?? targetEntry.title
        let updatedNotes = notes ?? targetEntry.notes
        let updatedStartTime = startTime ?? targetEntry.startTime
        let updatedEndTime = endTime ?? targetEntry.endTime

        // Validate the updated values
        let validationResult = validateTimeEntryInput(
            projectId: updatedProjectId,
            title: updatedTitle,
            notes: updatedNotes,
            startTime: updatedStartTime,
            endTime: updatedEndTime
        )

        switch validationResult {
        case let .failure(error):
            throw error
        case .success:
            break
        }

        // Apply updates
        if let newProjectId = projectId {
            targetEntry.projectId = newProjectId
        }

        if let newTitle = title {
            targetEntry.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let newNotes = notes {
            targetEntry.notes = newNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let newStartTime = startTime {
            targetEntry.startTime = newStartTime
        }

        if let newEndTime = endTime {
            targetEntry.endTime = newEndTime
        }

        // Recalculate duration and update timestamp
        targetEntry.recalculateDuration()
        targetEntry.markAsUpdated()

        // Save to persistence
        try await saveTimeEntries()

        // Re-sort the array if times changed
        if startTime != nil || endTime != nil {
            timeEntries.sort { $0.startTime > $1.startTime }
        }

        // Notify observers
        notifyTimeEntriesChanged(operation: "update", timeEntryId: targetEntry.id.uuidString)

        logger.info("Updated time entry: \(targetEntry.title)")
    }

    /// Deletes a time entry with proper cleanup and notifications
    /// - Parameter timeEntry: The time entry to delete
    /// - Throws: TimeEntryError if deletion fails
    func deleteTimeEntry(_ timeEntry: TimeEntry) async throws {
        // Check if time entry exists in our collection
        guard let entryIndex = timeEntries.firstIndex(where: { $0.id == timeEntry.id }) else {
            throw TimeEntryError.validationFailed("Time entry not found")
        }

        let targetEntry = timeEntries[entryIndex]

        // Remove from SwiftData context
        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }

        modelContext.delete(targetEntry)

        // Save to persistence
        try await saveTimeEntries()

        // Remove from local array
        timeEntries.remove(at: entryIndex)

        // Send deletion notification
        notifyTimeEntryDeleted(timeEntryId: timeEntry.id.uuidString)

        // Notify observers of change
        notifyTimeEntriesChanged(operation: "delete", timeEntryId: timeEntry.id.uuidString)

        logger.info("Deleted time entry: \(targetEntry.title)")
    }

    /// Retrieves time entries with optional filtering
    /// - Parameter project: Optional project to filter by
    /// - Returns: Array of time entries matching the criteria
    func getTimeEntries(for project: Project? = nil) -> [TimeEntry] {
        guard let project = project else {
            return timeEntries
        }

        return timeEntries.filter { $0.projectId == project.id }
    }

    /// Retrieves time entries within a specific date range
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    ///   - project: Optional project to filter by
    /// - Returns: Array of time entries within the date range
    func getTimeEntriesInDateRange(
        from startDate: Date,
        to endDate: Date,
        for project: Project? = nil
    ) -> [TimeEntry] {
        let filteredEntries = timeEntries.filter { entry in
            entry.startTime >= startDate && entry.endTime <= endDate
        }

        if let project = project {
            return filteredEntries.filter { $0.projectId == project.id }
        }

        return filteredEntries
    }

    /// Retrieves time entries for a specific date
    /// - Parameters:
    ///   - date: The date to filter by
    ///   - project: Optional project to filter by
    /// - Returns: Array of time entries for the specified date
    func getTimeEntries(for date: Date, project: Project? = nil) -> [TimeEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        return getTimeEntriesInDateRange(from: startOfDay, to: endOfDay, for: project)
    }

    // MARK: - Integration Methods

    /// Creates a time entry from a timer session
    /// - Parameters:
    ///   - project: Optional project to associate with the time entry
    ///   - startTime: The start time of the timer session
    ///   - endTime: The end time of the timer session
    ///   - title: Optional custom title for the time entry
    ///   - notes: Optional custom notes for the time entry
    /// - Returns: The created TimeEntry
    /// - Throws: TimeEntryError if creation fails
    func createFromTimer(
        project: Project?,
        startTime: Date,
        endTime: Date,
        title: String? = nil,
        notes: String? = nil
    ) async throws -> TimeEntry {
        let entryTitle = title ?? project?.name ?? "Timer Session"
        let entryNotes = notes ?? "Created from timer"

        return try await createTimeEntry(
            projectId: project?.id,
            title: entryTitle,
            notes: entryNotes,
            startTime: startTime,
            endTime: endTime
        )
    }

    /// Reassigns time entries from one project to another
    /// - Parameters:
    ///   - fromProject: The source project
    ///   - toProject: The target project (nil for unassigned)
    /// - Throws: TimeEntryError if reassignment fails
    func reassignTimeEntries(from fromProject: Project, to toProject: Project?) async throws {
        let affectedEntries = timeEntries.filter { $0.projectId == fromProject.id }

        guard !affectedEntries.isEmpty else {
            return
        }

        // Validate target project exists if provided
        if let toProject = toProject {
            guard ProjectManager.shared.getProject(by: toProject.id) != nil else {
                throw TimeEntryError.projectNotFound("Target project not found")
            }
        }

        // Update all affected entries
        for entry in affectedEntries {
            entry.projectId = toProject?.id
            entry.markAsUpdated()
        }

        // Save changes
        try await saveTimeEntries()

        // Notify observers
        notifyTimeEntriesChanged(operation: "reassign")

        let targetName = toProject?.name ?? "Unassigned"
        logger.info("Reassigned \(affectedEntries.count) time entries from '\(fromProject.name)' to '\(targetName)'")
    }

    // MARK: - Validation Methods

    /// Validates time entry input parameters
    /// - Parameters:
    ///   - projectId: Optional project ID
    ///   - title: The title of the time entry
    ///   - notes: Optional notes
    ///   - startTime: The start time
    ///   - endTime: The end time
    /// - Returns: ValidationResult indicating success or failure
    private func validateTimeEntryInput(
        projectId: String?,
        title: String,
        notes: String?,
        startTime: Date,
        endTime: Date
    ) -> TimeEntryValidationResult {
        // Validate project if provided
        if let projectId = projectId, !projectId.isEmpty {
            guard ProjectManager.shared.getProject(by: projectId) != nil else {
                return .failure(.projectNotFound("Project with ID '\(projectId)' not found"))
            }
        }

        // Validate title
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return .failure(.validationFailed("Title cannot be empty"))
        }

        if trimmedTitle.count > 200 {
            return .failure(.validationFailed("Title cannot exceed 200 characters"))
        }

        // Validate notes if provided
        if let notes = notes, notes.count > 1000 {
            return .failure(.validationFailed("Notes cannot exceed 1000 characters"))
        }

        // Validate time range
        if endTime <= startTime {
            return .failure(.validationFailed("End time must be after start time"))
        }

        let duration = endTime.timeIntervalSince(startTime)

        // Minimum duration: 1 minute
        if duration < 60 {
            return .failure(.validationFailed("Duration must be at least 1 minute"))
        }

        // Maximum duration: 24 hours
        if duration > 24 * 60 * 60 {
            return .failure(.validationFailed("Duration cannot exceed 24 hours"))
        }

        // Check if times are in reasonable range
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now

        if startTime < oneYearAgo || startTime > oneYearFromNow {
            return .failure(.validationFailed("Start time is outside reasonable range"))
        }

        if endTime < oneYearAgo || endTime > oneYearFromNow {
            return .failure(.validationFailed("End time is outside reasonable range"))
        }

        return .success
    }

    /// Validates a time entry object
    /// - Parameter timeEntry: The time entry to validate
    /// - Returns: ValidationResult indicating success or failure
    func validateTimeEntry(_ timeEntry: TimeEntry) -> TimeEntryValidationResult {
        return validateTimeEntryInput(
            projectId: timeEntry.projectId,
            title: timeEntry.title,
            notes: timeEntry.notes,
            startTime: timeEntry.startTime,
            endTime: timeEntry.endTime
        )
    }

    // MARK: - Batch Operations

    /// Creates multiple time entries in a single batch operation
    /// - Parameter timeEntryData: Array of tuples containing time entry data
    /// - Returns: Array of created TimeEntry objects
    /// - Throws: TimeEntryError if batch creation fails
    func createTimeEntriesBatch(_ timeEntryData: [(projectId: String?, title: String, notes: String?, startTime: Date, endTime: Date)]) async throws -> [TimeEntry] {
        guard !timeEntryData.isEmpty else {
            return []
        }
        
        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }
        
        var createdEntries: [TimeEntry] = []
        
        // Validate all entries first
        for data in timeEntryData {
            let validationResult = validateTimeEntryInput(
                projectId: data.projectId,
                title: data.title,
                notes: data.notes,
                startTime: data.startTime,
                endTime: data.endTime
            )
            
            if case let .failure(error) = validationResult {
                throw error
            }
        }
        
        // Create all entries
        for data in timeEntryData {
            let timeEntry = TimeEntry(
                projectId: data.projectId,
                title: data.title.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: data.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: data.startTime,
                endTime: data.endTime
            )
            
            modelContext.insert(timeEntry)
            createdEntries.append(timeEntry)
        }
        
        // Single save operation for all entries
        try await saveTimeEntries()
        
        // Add to local array and sort
        timeEntries.append(contentsOf: createdEntries)
        timeEntries.sort { $0.startTime > $1.startTime }
        
        // Notify observers
        notifyTimeEntriesChanged(operation: "batchCreate")
        
        logger.info("Created \(createdEntries.count) time entries in batch operation")
        
        return createdEntries
    }
    
    /// Updates multiple time entries in a single batch operation
    /// - Parameter updates: Array of tuples containing time entry and update data
    /// - Throws: TimeEntryError if batch update fails
    func updateTimeEntriesBatch(_ updates: [(timeEntry: TimeEntry, projectId: String?, title: String?, notes: String?, startTime: Date?, endTime: Date?)]) async throws {
        guard !updates.isEmpty else {
            return
        }
        
        // Validate all updates first
        for update in updates {
            guard timeEntries.contains(where: { $0.id == update.timeEntry.id }) else {
                throw TimeEntryError.validationFailed("Time entry not found: \(update.timeEntry.id)")
            }
            
            let updatedProjectId = update.projectId ?? update.timeEntry.projectId
            let updatedTitle = update.title ?? update.timeEntry.title
            let updatedNotes = update.notes ?? update.timeEntry.notes
            let updatedStartTime = update.startTime ?? update.timeEntry.startTime
            let updatedEndTime = update.endTime ?? update.timeEntry.endTime
            
            let validationResult = validateTimeEntryInput(
                projectId: updatedProjectId,
                title: updatedTitle,
                notes: updatedNotes,
                startTime: updatedStartTime,
                endTime: updatedEndTime
            )
            
            if case let .failure(error) = validationResult {
                throw error
            }
        }
        
        // Apply all updates
        for update in updates {
            if let projectId = update.projectId {
                update.timeEntry.projectId = projectId
            }
            if let title = update.title {
                update.timeEntry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let notes = update.notes {
                update.timeEntry.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let startTime = update.startTime {
                update.timeEntry.startTime = startTime
            }
            if let endTime = update.endTime {
                update.timeEntry.endTime = endTime
            }
            
            update.timeEntry.recalculateDuration()
            update.timeEntry.markAsUpdated()
        }
        
        // Single save operation for all updates
        try await saveTimeEntries()
        
        // Re-sort if any times changed
        let hasTimeChanges = updates.contains { $0.startTime != nil || $0.endTime != nil }
        if hasTimeChanges {
            timeEntries.sort { $0.startTime > $1.startTime }
        }
        
        // Notify observers
        notifyTimeEntriesChanged(operation: "batchUpdate")
        
        logger.info("Updated \(updates.count) time entries in batch operation")
    }
    
    /// Deletes multiple time entries in a single batch operation
    /// - Parameter timeEntries: Array of time entries to delete
    /// - Throws: TimeEntryError if batch deletion fails
    func deleteTimeEntriesBatch(_ timeEntriesToDelete: [TimeEntry]) async throws {
        guard !timeEntriesToDelete.isEmpty else {
            return
        }
        
        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }
        
        var deletedIds: [UUID] = []
        
        // Remove from SwiftData context
        for timeEntry in timeEntriesToDelete {
            if let index = timeEntries.firstIndex(where: { $0.id == timeEntry.id }) {
                let targetEntry = timeEntries[index]
                modelContext.delete(targetEntry)
                deletedIds.append(targetEntry.id)
            }
        }
        
        // Single save operation for all deletions
        try await saveTimeEntries()
        
        // Remove from local array
        timeEntries.removeAll { entry in
            deletedIds.contains(entry.id)
        }
        
        // Send batch deletion notification
        let firstDeletedId = deletedIds.first?.uuidString ?? "batch"
        notifyTimeEntryDeleted(timeEntryId: firstDeletedId, batchOperation: true)
        
        // Notify observers
        notifyTimeEntriesChanged(operation: "batchDelete")
        
        logger.info("Deleted \(deletedIds.count) time entries in batch operation")
    }
    
    // MARK: - Query Optimization and Pagination
    
    /// Loads time entries with pagination support for large datasets
    /// - Parameters:
    ///   - offset: Number of entries to skip
    ///   - limit: Maximum number of entries to return
    ///   - projectId: Optional project ID to filter by
    ///   - startDate: Optional start date filter
    ///   - endDate: Optional end date filter
    /// - Returns: Array of time entries matching the criteria
    /// - Throws: TimeEntryError if loading fails
    func loadTimeEntriesPaginated(
        offset: Int = 0,
        limit: Int = 100,
        projectId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [TimeEntry] {
        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }
        
        var descriptor = FetchDescriptor<TimeEntry>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        // Build predicate for filtering
        var predicates: [Predicate<TimeEntry>] = []
        
        if let projectId = projectId {
            predicates.append(#Predicate<TimeEntry> { entry in
                entry.projectId == projectId
            })
        }
        
        if let startDate = startDate {
            predicates.append(#Predicate<TimeEntry> { entry in
                entry.startTime >= startDate
            })
        }
        
        if let endDate = endDate {
            predicates.append(#Predicate<TimeEntry> { entry in
                entry.endTime <= endDate
            })
        }
        
        if !predicates.isEmpty {
            descriptor.predicate = predicates.reduce(predicates[0]) { result, predicate in
                #Predicate<TimeEntry> { entry in
                    result.evaluate(entry) && predicate.evaluate(entry)
                }
            }
        }
        
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        
        do {
            let paginatedEntries = try modelContext.fetch(descriptor)
            logger.info("Loaded \(paginatedEntries.count) time entries (offset: \(offset), limit: \(limit))")
            return paginatedEntries
        } catch {
            logger.error("Failed to load paginated time entries: \(error.localizedDescription)")
            throw TimeEntryError.persistenceFailure("Failed to load paginated time entries: \(error.localizedDescription)")
        }
    }
    
    /// Gets the total count of time entries matching the given criteria
    /// - Parameters:
    ///   - projectId: Optional project ID to filter by
    ///   - startDate: Optional start date filter
    ///   - endDate: Optional end date filter
    /// - Returns: Total count of matching time entries
    /// - Throws: TimeEntryError if counting fails
    func getTimeEntryCount(
        projectId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> Int {
        guard let modelContext = modelContext else {
            throw TimeEntryError.persistenceFailure("ModelContext not available")
        }
        
        var descriptor = FetchDescriptor<TimeEntry>()
        
        // Build predicate for filtering (same as pagination method)
        var predicates: [Predicate<TimeEntry>] = []
        
        if let projectId = projectId {
            predicates.append(#Predicate<TimeEntry> { entry in
                entry.projectId == projectId
            })
        }
        
        if let startDate = startDate {
            predicates.append(#Predicate<TimeEntry> { entry in
                entry.startTime >= startDate
            })
        }
        
        if let endDate = endDate {
            predicates.append(#Predicate<TimeEntry> { entry in
                entry.endTime <= endDate
            })
        }
        
        if !predicates.isEmpty {
            descriptor.predicate = predicates.reduce(predicates[0]) { result, predicate in
                #Predicate<TimeEntry> { entry in
                    result.evaluate(entry) && predicate.evaluate(entry)
                }
            }
        }
        
        do {
            let entries = try modelContext.fetch(descriptor)
            return entries.count
        } catch {
            logger.error("Failed to count time entries: \(error.localizedDescription)")
            throw TimeEntryError.persistenceFailure("Failed to count time entries: \(error.localizedDescription)")
        }
    }
    
    /// Optimized query for getting time entries grouped by project
    /// - Parameters:
    ///   - startDate: Optional start date filter
    ///   - endDate: Optional end date filter
    /// - Returns: Dictionary mapping project IDs to arrays of time entries
    /// - Throws: TimeEntryError if query fails
    func getTimeEntriesGroupedByProject(
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [String?: [TimeEntry]] {
        let entries = try await loadTimeEntriesPaginated(
            offset: 0,
            limit: Int.max, // Load all for grouping
            startDate: startDate,
            endDate: endDate
        )
        
        let grouped = Dictionary(grouping: entries) { $0.projectId }
        logger.info("Grouped \(entries.count) time entries by project into \(grouped.count) groups")
        
        return grouped
    }
    
    // MARK: - Error Handling and Recovery

    /// Performs retry logic for failed operations
    /// - Parameters:
    ///   - operation: The operation to retry
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - delay: Base delay between retries in seconds (default: 0.5)
    /// - Returns: The result of the operation
    /// - Throws: The last error encountered if all retries fail
    private func performWithRetry<T>(
        operation: () async throws -> T,
        maxAttempts: Int = 3,
        delay: TimeInterval = 0.5
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1 ... maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                logger.warning("Operation failed on attempt \(attempt): \(error.localizedDescription)")

                if attempt < maxAttempts {
                    let retryDelay = delay * pow(2.0, Double(attempt - 1)) // Exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? TimeEntryError.persistenceFailure("Unknown error during retry operation")
    }

    /// Handles data corruption by attempting to repair time entries
    /// - Throws: TimeEntryError if repair fails
    func repairDataIntegrity() async throws {
        logger.info("Starting data integrity repair for time entries")

        var repairedCount = 0

        for timeEntry in timeEntries {
            let wasValid = timeEntry.isValid
            timeEntry.repairDataIntegrity()

            if !wasValid, timeEntry.isValid {
                repairedCount += 1
            }
        }

        if repairedCount > 0 {
            try await saveTimeEntries()
            notifyTimeEntriesChanged(operation: "repair")
            logger.info("Repaired \(repairedCount) time entries")
        } else {
            logger.info("No time entries required repair")
        }
    }

    /// Handles graceful error recovery for persistence failures
    /// - Parameter error: The error that occurred
    /// - Returns: True if recovery was successful, false otherwise
    private func handlePersistenceError(_ error: Error) async -> Bool {
        logger.error("Persistence error occurred: \(error.localizedDescription)")

        // Attempt to reload data from persistence
        do {
            try await loadTimeEntries()
            logger.info("Successfully recovered by reloading time entries")
            return true
        } catch {
            logger.error("Failed to recover by reloading: \(error.localizedDescription)")
        }

        // Attempt data integrity repair
        do {
            try await repairDataIntegrity()
            logger.info("Successfully recovered by repairing data integrity")
            return true
        } catch {
            logger.error("Failed to recover by repairing data: \(error.localizedDescription)")
        }

        return false
    }
    
    // MARK: - Data Conflict Resolution Support
    
    /// Get all time entries from the database for conflict resolution
    func getAllTimeEntries() async -> [TimeEntry] {
        guard let modelContext = modelContext else {
            logger.error("No model context available for getAllTimeEntries")
            return []
        }
        
        do {
            let descriptor = FetchDescriptor<TimeEntry>(
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            let entries = try modelContext.fetch(descriptor)
            logger.info("Retrieved \(entries.count) time entries for conflict resolution")
            return entries
        } catch {
            logger.error("Failed to fetch all time entries: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Update a time entry for conflict resolution
    func updateTimeEntry(_ timeEntry: TimeEntry) async {
        guard let modelContext = modelContext else {
            logger.error("No model context available for updateTimeEntry")
            return
        }
        
        do {
            let validationResult = validateTimeEntry(timeEntry)
            if case .failure(let error) = validationResult {
                logger.error("Time entry validation failed: \(error.localizedDescription)")
                return
            }
            
            timeEntry.markAsUpdated()
            try modelContext.save()
            logger.info("Updated time entry: \(timeEntry.title)")
        } catch {
            logger.error("Failed to update time entry: \(error.localizedDescription)")
        }
    }
    
    /// Delete a time entry for conflict resolution
    func deleteTimeEntryWithoutThrowing(_ timeEntry: TimeEntry) async {
        guard let modelContext = modelContext else {
            logger.error("No model context available for deleteTimeEntry")
            return
        }
        
        do {
            modelContext.delete(timeEntry)
            try modelContext.save()
            
            // Remove from local array if present
            timeEntries.removeAll { $0.id == timeEntry.id }
            
            logger.info("Deleted time entry: \(timeEntry.title)")
        } catch {
            logger.error("Failed to delete time entry: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let timeEntryDidChange = Notification.Name("timeEntryDidChange")
    static let timeEntryWasDeleted = Notification.Name("timeEntryWasDeleted")
}
