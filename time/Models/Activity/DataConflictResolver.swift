import Foundation
import SwiftData

/// Manager class for handling data conflicts and integrity issues
@MainActor
class DataConflictResolver: ObservableObject {
    @Published var detectedConflicts: [DataConflict] = []
    @Published var resolutionResults: [ConflictResolutionResult] = []
    @Published var isResolving = false
    
    private let activityManager: ActivityManager
    private let timeEntryManager: TimeEntryManager
    
    init(activityManager: ActivityManager, timeEntryManager: TimeEntryManager) {
        self.activityManager = activityManager
        self.timeEntryManager = timeEntryManager
    }
    
    // MARK: - Public Interface
    
    /// Scans for conflicts in current data
    func scanForConflicts() async {
        isResolving = true
        defer { isResolving = false }
        
        let activities = await activityManager.getAllActivities()
        let timeEntries = await timeEntryManager.getAllTimeEntries()
        
        detectedConflicts = ActivityDataProcessor.detectConflicts(
            activities: activities,
            timeEntries: timeEntries
        )
    }
    
    /// Validates data integrity
    func validateDataIntegrity() async -> DataValidationResult {
        let activities = await activityManager.getAllActivities()
        let timeEntries = await timeEntryManager.getAllTimeEntries()
        
        return ActivityDataProcessor.validateDataIntegrity(
            activities: activities,
            timeEntries: timeEntries
        )
    }
    
    /// Automatically resolves conflicts where possible
    func resolveConflictsAutomatically() async -> [ConflictResolutionResult] {
        isResolving = true
        defer { isResolving = false }
        
        var activities = await activityManager.getAllActivities()
        var timeEntries = await timeEntryManager.getAllTimeEntries()
        
        let results = ActivityDataProcessor.resolveConflictsAutomatically(
            conflicts: detectedConflicts,
            activities: &activities,
            timeEntries: &timeEntries
        )
        
        // Apply changes to the database
        await applyResolutionChanges(results: results, activities: activities, timeEntries: timeEntries)
        
        resolutionResults = results
        return results
    }
    
    /// Repairs data integrity issues
    func repairDataIntegrity() async -> DataValidationResult {
        isResolving = true
        defer { isResolving = false }
        
        var activities = await activityManager.getAllActivities()
        var timeEntries = await timeEntryManager.getAllTimeEntries()
        
        let result = ActivityDataProcessor.repairDataIntegrity(
            activities: &activities,
            timeEntries: &timeEntries
        )
        
        // Apply repairs to the database
        await applyDataRepairs(activities: activities, timeEntries: timeEntries)
        
        return result
    }
    
    /// Resolves a specific conflict manually
    func resolveConflict(_ conflict: DataConflict, resolution: ConflictResolution) async -> ConflictResolutionResult {
        isResolving = true
        defer { isResolving = false }
        
        var activities = await activityManager.getAllActivities()
        var timeEntries = await timeEntryManager.getAllTimeEntries()
        
        let modifiedConflict = DataConflict(
            type: conflict.type,
            items: conflict.items,
            overlapDuration: conflict.overlapDuration
        )
        
        // Override the suggested resolution
        let result = resolveConflictWithStrategy(
            modifiedConflict,
            resolution: resolution,
            activities: &activities,
            timeEntries: &timeEntries
        )
        
        // Apply changes to the database
        await applyResolutionChanges(results: [result], activities: activities, timeEntries: timeEntries)
        
        // Remove resolved conflict from detected conflicts
        detectedConflicts.removeAll { $0.id == conflict.id }
        resolutionResults.append(result)
        
        return result
    }
    
    /// Clears resolution history
    func clearResolutionHistory() {
        resolutionResults.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func resolveConflictWithStrategy(
        _ conflict: DataConflict,
        resolution: ConflictResolution,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        switch resolution {
        case .mergeItems:
            return mergeConflictItems(conflict, activities: &activities, timeEntries: &timeEntries)
        case .keepFirst:
            return keepFirstItem(conflict, activities: &activities, timeEntries: &timeEntries)
        case .keepLast:
            return keepLastItem(conflict, activities: &activities, timeEntries: &timeEntries)
        case .keepLongest:
            return keepLongestItem(conflict, activities: &activities, timeEntries: &timeEntries)
        case .splitOverlap:
            return splitOverlappingItems(conflict, activities: &activities, timeEntries: &timeEntries)
        case .deleteInvalid:
            return deleteInvalidItems(conflict, activities: &activities, timeEntries: &timeEntries)
        case .manualReview:
            return ConflictResolutionResult(
                conflictId: conflict.id,
                resolution: .manualReview,
                success: false,
                error: ConflictResolutionError.requiresManualReview
            )
        }
    }
    
    private func applyResolutionChanges(
        results: [ConflictResolutionResult],
        activities: [Activity],
        timeEntries: [TimeEntry]
    ) async {
        // Update activities
        for activity in activities {
            await activityManager.updateActivity(activity)
        }
        
        // Update time entries
        for timeEntry in timeEntries {
            await timeEntryManager.updateTimeEntry(timeEntry)
        }
        
        // Delete items that were marked for deletion
        for result in results where result.success {
            for deletedItem in result.deletedItems {
                switch deletedItem {
                case .activity(let activity):
                    await activityManager.deleteActivity(activity)
                case .timeEntry(let timeEntry):
                    await timeEntryManager.deleteTimeEntryWithoutThrowing(timeEntry)
                }
            }
        }
    }
    
    private func applyDataRepairs(activities: [Activity], timeEntries: [TimeEntry]) async {
        // Update repaired activities
        for activity in activities {
            await activityManager.updateActivity(activity)
        }
        
        // Update repaired time entries
        for timeEntry in timeEntries {
            await timeEntryManager.updateTimeEntry(timeEntry)
        }
    }
    
    // MARK: - Conflict Resolution Strategies
    
    private func mergeConflictItems(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        guard conflict.items.count == 2 else {
            return ConflictResolutionResult(
                conflictId: conflict.id,
                resolution: .mergeItems,
                success: false,
                error: ConflictResolutionError.cannotMergeMultipleItems
            )
        }
        
        let item1 = conflict.items[0]
        let item2 = conflict.items[1]
        
        // Merge time entries
        if case .timeEntry(let entry1) = item1, case .timeEntry(let entry2) = item2 {
            return mergeTimeEntries(entry1, entry2, timeEntries: &timeEntries, conflictId: conflict.id)
        }
        
        // Merge activities
        if case .activity(let activity1) = item1, case .activity(let activity2) = item2 {
            return mergeActivities(activity1, activity2, activities: &activities, conflictId: conflict.id)
        }
        
        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .mergeItems,
            success: false,
            error: ConflictResolutionError.unsupportedMergeOperation
        )
    }
    
    private func mergeTimeEntries(
        _ entry1: TimeEntry,
        _ entry2: TimeEntry,
        timeEntries: inout [TimeEntry],
        conflictId: UUID
    ) -> ConflictResolutionResult {
        let mergedStartTime = min(entry1.startTime, entry2.startTime)
        let mergedEndTime = max(entry1.endTime, entry2.endTime)
        let mergedTitle = "\(entry1.title) + \(entry2.title)"
        let mergedNotes = [entry1.notes, entry2.notes].compactMap { $0 }.joined(separator: "; ")
        
        let mergedEntry = TimeEntry(
            projectId: entry1.projectId ?? entry2.projectId,
            title: mergedTitle,
            notes: mergedNotes.isEmpty ? nil : mergedNotes,
            startTime: mergedStartTime,
            endTime: mergedEndTime
        )
        
        // Remove original entries and add merged one
        timeEntries.removeAll { $0.id == entry1.id || $0.id == entry2.id }
        timeEntries.append(mergedEntry)
        
        return ConflictResolutionResult(
            conflictId: conflictId,
            resolution: .mergeItems,
            success: true,
            modifiedItems: [.timeEntry(mergedEntry)],
            deletedItems: [.timeEntry(entry1), .timeEntry(entry2)]
        )
    }
    
    private func mergeActivities(
        _ activity1: Activity,
        _ activity2: Activity,
        activities: inout [Activity],
        conflictId: UUID
    ) -> ConflictResolutionResult {
        let mergedStartTime = min(activity1.startTime, activity2.startTime)
        let mergedEndTime = max(activity1.endTime ?? Date(), activity2.endTime ?? Date())
        let mergedDuration = mergedEndTime.timeIntervalSince(mergedStartTime)
        
        // Use the activity with more context information
        let primaryActivity = activity1.windowTitle != nil ? activity1 : activity2
        
        let mergedActivity = Activity(
            appName: primaryActivity.appName,
            appBundleId: primaryActivity.appBundleId,
            appTitle: primaryActivity.appTitle,
            duration: mergedDuration,
            startTime: mergedStartTime,
            endTime: mergedEndTime,
            icon: primaryActivity.icon,
            windowTitle: primaryActivity.windowTitle ?? (activity1.windowTitle ?? activity2.windowTitle),
            url: primaryActivity.url ?? (activity1.url ?? activity2.url),
            documentPath: primaryActivity.documentPath ?? (activity1.documentPath ?? activity2.documentPath),
            isIdleTime: activity1.isIdleTime || activity2.isIdleTime
        )
        
        // Remove original activities and add merged one
        activities.removeAll { $0.id == activity1.id || $0.id == activity2.id }
        activities.append(mergedActivity)
        
        return ConflictResolutionResult(
            conflictId: conflictId,
            resolution: .mergeItems,
            success: true,
            modifiedItems: [.activity(mergedActivity)],
            deletedItems: [.activity(activity1), .activity(activity2)]
        )
    }
    
    private func keepFirstItem(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        let sortedItems = conflict.items.sorted { $0.startTime < $1.startTime }
        let itemToKeep = sortedItems.first!
        let itemsToDelete = Array(sortedItems.dropFirst())
        
        removeItems(itemsToDelete, from: &activities, and: &timeEntries)
        
        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .keepFirst,
            success: true,
            modifiedItems: [itemToKeep],
            deletedItems: itemsToDelete
        )
    }
    
    private func keepLastItem(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        let sortedItems = conflict.items.sorted { $0.startTime < $1.startTime }
        let itemToKeep = sortedItems.last!
        let itemsToDelete = Array(sortedItems.dropLast())
        
        removeItems(itemsToDelete, from: &activities, and: &timeEntries)
        
        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .keepLast,
            success: true,
            modifiedItems: [itemToKeep],
            deletedItems: itemsToDelete
        )
    }
    
    private func keepLongestItem(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        let sortedItems = conflict.items.sorted { $0.duration > $1.duration }
        let itemToKeep = sortedItems.first!
        let itemsToDelete = Array(sortedItems.dropFirst())
        
        removeItems(itemsToDelete, from: &activities, and: &timeEntries)
        
        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .keepLongest,
            success: true,
            modifiedItems: [itemToKeep],
            deletedItems: itemsToDelete
        )
    }
    
    private func splitOverlappingItems(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        // Advanced splitting logic would go here
        // For now, return as requiring manual review
        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .splitOverlap,
            success: false,
            error: ConflictResolutionError.requiresManualReview
        )
    }
    
    private func deleteInvalidItems(
        _ conflict: DataConflict,
        activities: inout [Activity],
        timeEntries: inout [TimeEntry]
    ) -> ConflictResolutionResult {
        var deletedItems: [ConflictItem] = []
        let now = Date()
        let futureThreshold = now.addingTimeInterval(3600) // 1 hour in future
        
        for item in conflict.items {
            var shouldDelete = false
            
            switch item {
            case .activity(let activity):
                if activity.duration <= 0 || activity.startTime > futureThreshold {
                    shouldDelete = true
                }
            case .timeEntry(let timeEntry):
                if timeEntry.duration <= 0 || !timeEntry.isValid || timeEntry.startTime > futureThreshold {
                    shouldDelete = true
                }
            }
            
            if shouldDelete {
                removeItems([item], from: &activities, and: &timeEntries)
                deletedItems.append(item)
            }
        }
        
        return ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: .deleteInvalid,
            success: true,
            deletedItems: deletedItems
        )
    }
    
    private func removeItems(
        _ items: [ConflictItem],
        from activities: inout [Activity],
        and timeEntries: inout [TimeEntry]
    ) {
        for item in items {
            switch item {
            case .activity(let activity):
                activities.removeAll { $0.id == activity.id }
            case .timeEntry(let timeEntry):
                timeEntries.removeAll { $0.id == timeEntry.id }
            }
        }
    }
}

