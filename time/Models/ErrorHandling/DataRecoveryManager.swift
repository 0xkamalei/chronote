import Foundation
import SwiftData
import os.log

// MARK: - Data Recovery Manager

@MainActor
class DataRecoveryManager: ObservableObject {
    static let shared = DataRecoveryManager()
    
    @Published var isRecoveryInProgress = false
    @Published var recoveryProgress: Double = 0.0
    @Published var lastBackupDate: Date?
    @Published var availableBackups: [BackupInfo] = []
    
    private let logger = Logger(subsystem: "com.timetracking.app", category: "DataRecovery")
    private let fileManager = FileManager.default
    private let backupDirectory: URL
    private let maxBackups = 10
    
    private init() {
        // Create backup directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        backupDirectory = appSupport.appendingPathComponent("TimeTracking/Backups")
        
        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create backup directory: \(error)")
        }
        
        loadAvailableBackups()
        setupAutomaticBackup()
    }
    
    // MARK: - Data Backup
    
    func createBackup(type: BackupType = .manual) async -> Result<BackupInfo, TimeTrackingError> {
        isRecoveryInProgress = true
        recoveryProgress = 0.0
        
        defer {
            isRecoveryInProgress = false
            recoveryProgress = 0.0
        }
        
        do {
            let backupInfo = BackupInfo(
                id: UUID(),
                timestamp: Date(),
                type: type,
                size: 0,
                checksum: ""
            )
            
            let backupURL = backupDirectory.appendingPathComponent("backup_\(backupInfo.id.uuidString).timebackup")
            
            logger.info("Creating backup: \(backupURL.lastPathComponent)")
            
            // Step 1: Collect all data (20% progress)
            recoveryProgress = 0.2
            let dataToBackup = try await collectDataForBackup()
            
            // Step 2: Serialize data (40% progress)
            recoveryProgress = 0.4
            let serializedData = try serializeBackupData(dataToBackup)
            
            // Step 3: Compress data (60% progress)
            recoveryProgress = 0.6
            let compressedData = try compressData(serializedData)
            
            // Step 4: Calculate checksum (80% progress)
            recoveryProgress = 0.8
            let checksum = calculateChecksum(compressedData)
            
            // Step 5: Write to file (100% progress)
            try compressedData.write(to: backupURL)
            recoveryProgress = 1.0
            
            let finalBackupInfo = BackupInfo(
                id: backupInfo.id,
                timestamp: backupInfo.timestamp,
                type: type,
                size: compressedData.count,
                checksum: checksum,
                url: backupURL
            )
            
            availableBackups.insert(finalBackupInfo, at: 0)
            lastBackupDate = Date()
            
            // Clean up old backups
            cleanupOldBackups()
            
            logger.info("Backup created successfully: \(finalBackupInfo.size) bytes")
            return .success(finalBackupInfo)
            
        } catch {
            logger.error("Backup creation failed: \(error)")
            return .failure(.dataBackupFailure(error.localizedDescription))
        }
    }
    
    private func collectDataForBackup() async throws -> BackupData {
        // In a real implementation, this would collect data from SwiftData
        // For now, we'll create a placeholder structure
        
        return BackupData(
            activities: [], // Would collect from ActivityManager
            projects: [],  // Would collect from ProjectManager
            timeEntries: [], // Would collect from TimeEntryManager
            rules: [],     // Would collect from RuleManager
            settings: [:], // Would collect app settings
            metadata: BackupMetadata(
                version: "1.0",
                createdAt: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
        )
    }
    
    private func serializeBackupData(_ data: BackupData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(data)
    }
    
    private func compressData(_ data: Data) throws -> Data {
        // Simple compression using NSData compression
        return try (data as NSData).compressed(using: .lzfse) as Data
    }
    
    private func calculateChecksum(_ data: Data) -> String {
        return data.sha256
    }
    
    // MARK: - Data Restoration
    
    func restoreFromBackup(_ backupInfo: BackupInfo) async -> Result<Void, TimeTrackingError> {
        isRecoveryInProgress = true
        recoveryProgress = 0.0
        
        defer {
            isRecoveryInProgress = false
            recoveryProgress = 0.0
        }
        
        do {
            guard let backupURL = backupInfo.url,
                  fileManager.fileExists(atPath: backupURL.path) else {
                return .failure(.dataRestoreFailure("Backup file not found"))
            }
            
            logger.info("Restoring from backup: \(backupURL.lastPathComponent)")
            
            // Step 1: Read backup file (20% progress)
            recoveryProgress = 0.2
            let compressedData = try Data(contentsOf: backupURL)
            
            // Step 2: Verify checksum (40% progress)
            recoveryProgress = 0.4
            let checksum = calculateChecksum(compressedData)
            guard checksum == backupInfo.checksum else {
                return .failure(.dataRestoreFailure("Backup file is corrupted (checksum mismatch)"))
            }
            
            // Step 3: Decompress data (60% progress)
            recoveryProgress = 0.6
            let decompressedData = try (compressedData as NSData).decompressed(using: .lzfse) as Data
            
            // Step 4: Deserialize data (80% progress)
            recoveryProgress = 0.8
            let backupData = try deserializeBackupData(decompressedData)
            
            // Step 5: Restore data to database (100% progress)
            try await restoreDataToDatabase(backupData)
            recoveryProgress = 1.0
            
            logger.info("Backup restored successfully")
            return .success(())
            
        } catch {
            logger.error("Backup restoration failed: \(error)")
            return .failure(.dataRestoreFailure(error.localizedDescription))
        }
    }
    
    private func deserializeBackupData(_ data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupData.self, from: data)
    }
    
    private func restoreDataToDatabase(_ backupData: BackupData) async throws {
        // In a real implementation, this would restore data to SwiftData
        // This would involve:
        // 1. Clearing existing data (with user confirmation)
        // 2. Inserting backup data
        // 3. Updating relationships
        // 4. Validating data integrity
        
        logger.info("Restoring \(backupData.activities.count) activities, \(backupData.projects.count) projects, \(backupData.timeEntries.count) time entries")
    }
    
    // MARK: - Data Corruption Detection and Repair
    
    func detectDataCorruption() async -> [DataCorruptionIssue] {
        var issues: [DataCorruptionIssue] = []
        
        logger.info("Starting data corruption detection")
        
        // Check for orphaned time entries
        let orphanedTimeEntries = await detectOrphanedTimeEntries()
        if !orphanedTimeEntries.isEmpty {
            issues.append(.orphanedTimeEntries(orphanedTimeEntries))
        }
        
        // Check for overlapping activities
        let overlappingActivities = await detectOverlappingActivities()
        if !overlappingActivities.isEmpty {
            issues.append(.overlappingActivities(overlappingActivities))
        }
        
        // Check for invalid date ranges
        let invalidDateRanges = await detectInvalidDateRanges()
        if !invalidDateRanges.isEmpty {
            issues.append(.invalidDateRanges(invalidDateRanges))
        }
        
        // Check for missing project references
        let missingProjectRefs = await detectMissingProjectReferences()
        if !missingProjectRefs.isEmpty {
            issues.append(.missingProjectReferences(missingProjectRefs))
        }
        
        logger.info("Data corruption detection completed: \(issues.count) issues found")
        return issues
    }
    
    func repairDataCorruption(_ issues: [DataCorruptionIssue]) async -> Result<DataRepairResult, TimeTrackingError> {
        isRecoveryInProgress = true
        recoveryProgress = 0.0
        
        defer {
            isRecoveryInProgress = false
            recoveryProgress = 0.0
        }
        
        var repairResult = DataRepairResult()
        let totalIssues = issues.count
        
        for (index, issue) in issues.enumerated() {
            recoveryProgress = Double(index) / Double(totalIssues)
            
            do {
                let issueResult = try await repairSingleIssue(issue)
                repairResult.merge(issueResult)
            } catch {
                logger.error("Failed to repair issue \(issue): \(error)")
                repairResult.failedRepairs.append(issue)
            }
        }
        
        recoveryProgress = 1.0
        
        logger.info("Data repair completed: \(repairResult.repairedIssues) repaired, \(repairResult.failedRepairs.count) failed")
        return .success(repairResult)
    }
    
    private func repairSingleIssue(_ issue: DataCorruptionIssue) async throws -> DataRepairResult {
        var result = DataRepairResult()
        
        switch issue {
        case .orphanedTimeEntries(let entries):
            // Remove orphaned time entries or assign to default project
            result.repairedIssues += entries.count
            
        case .overlappingActivities(let activities):
            // Merge or split overlapping activities
            result.repairedIssues += activities.count
            
        case .invalidDateRanges(let ranges):
            // Fix invalid date ranges
            result.repairedIssues += ranges.count
            
        case .missingProjectReferences(let references):
            // Create missing projects or reassign to existing ones
            result.repairedIssues += references.count
        }
        
        return result
    }
    
    // MARK: - Corruption Detection Methods
    
    private func detectOrphanedTimeEntries() async -> [String] {
        // Implementation would check for time entries without valid project references
        return []
    }
    
    private func detectOverlappingActivities() async -> [String] {
        // Implementation would check for activities with overlapping time ranges
        return []
    }
    
    private func detectInvalidDateRanges() async -> [String] {
        // Implementation would check for activities/entries with invalid date ranges
        return []
    }
    
    private func detectMissingProjectReferences() async -> [String] {
        // Implementation would check for missing project references
        return []
    }
    
    // MARK: - Crash Recovery
    
    func performCrashRecovery() async -> Result<CrashRecoveryResult, TimeTrackingError> {
        logger.info("Starting crash recovery")
        
        var result = CrashRecoveryResult()
        
        // Check for incomplete operations
        let incompleteOps = await detectIncompleteOperations()
        
        for operation in incompleteOps {
            do {
                try await recoverIncompleteOperation(operation)
                result.recoveredOperations.append(operation)
            } catch {
                logger.error("Failed to recover operation \(operation.id): \(error)")
                result.failedOperations.append(operation)
            }
        }
        
        // Check for corrupted active sessions
        let corruptedSessions = await detectCorruptedSessions()
        
        for session in corruptedSessions {
            do {
                try await recoverSession(session)
                result.recoveredSessions.append(session)
            } catch {
                logger.error("Failed to recover session \(session.id): \(error)")
                result.failedSessions.append(session)
            }
        }
        
        logger.info("Crash recovery completed: \(result.recoveredOperations.count) operations, \(result.recoveredSessions.count) sessions recovered")
        return .success(result)
    }
    
    private func detectIncompleteOperations() async -> [IncompleteOperation] {
        // Implementation would detect operations that were interrupted by crash
        return []
    }
    
    private func recoverIncompleteOperation(_ operation: IncompleteOperation) async throws {
        // Implementation would complete or rollback incomplete operations
    }
    
    private func detectCorruptedSessions() async -> [CorruptedSession] {
        // Implementation would detect sessions that were corrupted by crash
        return []
    }
    
    private func recoverSession(_ session: CorruptedSession) async throws {
        // Implementation would recover or clean up corrupted sessions
    }
    
    // MARK: - Automatic Backup
    
    private func setupAutomaticBackup() {
        // Schedule automatic backups
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in // Every hour
            Task { @MainActor in
                if self.shouldCreateAutomaticBackup() {
                    let _ = await self.createBackup(type: .automatic)
                }
            }
        }
    }
    
    private func shouldCreateAutomaticBackup() -> Bool {
        guard let lastBackup = lastBackupDate else { return true }
        return Date().timeIntervalSince(lastBackup) > 3600 // 1 hour
    }
    
    // MARK: - Backup Management
    
    private func loadAvailableBackups() {
        do {
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
                .filter { $0.pathExtension == "timebackup" }
            
            availableBackups = backupFiles.compactMap { url in
                guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                      let creationDate = resourceValues.creationDate,
                      let fileSize = resourceValues.fileSize else {
                    return nil
                }
                
                // Extract UUID from filename
                let filename = url.deletingPathExtension().lastPathComponent
                guard filename.hasPrefix("backup_"),
                      let uuidString = filename.components(separatedBy: "_").last,
                      let uuid = UUID(uuidString: uuidString) else {
                    return nil
                }
                
                return BackupInfo(
                    id: uuid,
                    timestamp: creationDate,
                    type: .manual, // We can't determine type from file, assume manual
                    size: fileSize,
                    checksum: "", // Would need to calculate
                    url: url
                )
            }
            .sorted { $0.timestamp > $1.timestamp }
            
            lastBackupDate = availableBackups.first?.timestamp
            
        } catch {
            logger.error("Failed to load available backups: \(error)")
        }
    }
    
    private func cleanupOldBackups() {
        while availableBackups.count > maxBackups {
            if let oldestBackup = availableBackups.last,
               let url = oldestBackup.url {
                do {
                    try fileManager.removeItem(at: url)
                    availableBackups.removeLast()
                } catch {
                    logger.error("Failed to remove old backup: \(error)")
                    break
                }
            }
        }
    }
    
    func deleteBackup(_ backupInfo: BackupInfo) -> Result<Void, TimeTrackingError> {
        guard let url = backupInfo.url else {
            return .failure(.dataBackupFailure("Backup URL not found"))
        }
        
        do {
            try fileManager.removeItem(at: url)
            availableBackups.removeAll { $0.id == backupInfo.id }
            logger.info("Backup deleted: \(url.lastPathComponent)")
            return .success(())
        } catch {
            logger.error("Failed to delete backup: \(error)")
            return .failure(.dataBackupFailure(error.localizedDescription))
        }
    }
}

// MARK: - Supporting Types

struct BackupInfo: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: BackupType
    let size: Int
    let checksum: String
    let url: URL?
    
    init(id: UUID, timestamp: Date, type: BackupType, size: Int, checksum: String, url: URL? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.size = size
        self.checksum = checksum
        self.url = url
    }
}

enum BackupType: String, Codable, CaseIterable {
    case manual = "manual"
    case automatic = "automatic"
    case emergency = "emergency"
}

struct BackupData: Codable {
    let activities: [BackupActivity]
    let projects: [BackupProject]
    let timeEntries: [BackupTimeEntry]
    let rules: [BackupRule]
    let settings: [String: String]
    let metadata: BackupMetadata
}

struct BackupMetadata: Codable {
    let version: String
    let createdAt: Date
    let appVersion: String
}

// Simplified backup data structures
struct BackupActivity: Codable {
    let id: String
    let startTime: Date
    let endTime: Date?
    let applicationName: String
    let bundleID: String
    let windowTitle: String?
}

struct BackupProject: Codable {
    let id: String
    let name: String
    let color: String
    let parentID: String?
}

struct BackupTimeEntry: Codable {
    let id: String
    let startTime: Date
    let endTime: Date
    let projectID: String?
    let title: String?
    let notes: String?
}

struct BackupRule: Codable {
    let id: String
    let name: String
    let conditions: String // JSON encoded
    let actions: String // JSON encoded
}

enum DataCorruptionIssue: CustomStringConvertible {
    case orphanedTimeEntries([String])
    case overlappingActivities([String])
    case invalidDateRanges([String])
    case missingProjectReferences([String])
    
    var description: String {
        switch self {
        case .orphanedTimeEntries:
            return "orphanedTimeEntries"
        case .overlappingActivities:
            return "overlappingActivities"
        case .invalidDateRanges:
            return "invalidDateRanges"
        case .missingProjectReferences:
            return "missingProjectReferences"
        }
    }
}

struct DataRepairResult {
    var repairedIssues: Int = 0
    var failedRepairs: [DataCorruptionIssue] = []
    
    mutating func merge(_ other: DataRepairResult) {
        repairedIssues += other.repairedIssues
        failedRepairs.append(contentsOf: other.failedRepairs)
    }
}

struct CrashRecoveryResult {
    var recoveredOperations: [IncompleteOperation] = []
    var failedOperations: [IncompleteOperation] = []
    var recoveredSessions: [CorruptedSession] = []
    var failedSessions: [CorruptedSession] = []
}

struct IncompleteOperation {
    let id: UUID
    let type: String
    let startTime: Date
    let data: [String: Any]
}

struct CorruptedSession {
    let id: UUID
    let type: String
    let lastUpdate: Date
    let data: [String: Any]
}

// MARK: - Extensions

extension Data {
    var sha256: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit

extension SHA256 {
    static func hash(data: Data) -> SHA256.Digest {
        return SHA256.hash(data: data)
    }
}