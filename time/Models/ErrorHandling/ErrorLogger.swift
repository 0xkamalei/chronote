import Foundation
import os.log

// MARK: - Error Logger

@MainActor
class ErrorLogger: ObservableObject {
    static let shared = ErrorLogger()
    
    private let logger = Logger(subsystem: "com.timetracking.app", category: "ErrorLogger")
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let maxLogFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles: Int = 5
    
    @Published var recentErrors: [ErrorLogEntry] = []
    @Published var errorCounts: [ErrorCategory: Int] = [:]
    
    private init() {
        // Create logs directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("TimeTracking/Logs")
        
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create log directory: \(error)")
        }
        
        // Initialize error counts
        for category in ErrorCategory.allCases {
            errorCounts[category] = 0
        }
        
        // Load recent errors from disk
        loadRecentErrors()
        
        // Set up crash detection
        setupCrashDetection()
    }
    
    // MARK: - Error Logging
    
    func logError(
        _ error: TimeTrackingError,
        context: ErrorContext,
        userAction: String? = nil,
        additionalInfo: [String: Any] = [:]
    ) {
        let entry = ErrorLogEntry(
            error: error,
            context: context,
            userAction: userAction,
            additionalInfo: additionalInfo
        )
        
        // Add to recent errors
        recentErrors.insert(entry, at: 0)
        
        // Keep only last 100 errors in memory
        if recentErrors.count > 100 {
            recentErrors.removeLast()
        }
        
        // Update error counts
        errorCounts[error.category, default: 0] += 1
        
        // Log to system logger
        logToSystem(entry)
        
        // Write to file
        writeToLogFile(entry)
        
        // Handle critical errors
        if error.severity == .critical {
            handleCriticalError(entry)
        }
    }
    
    func logException(
        _ exception: NSException,
        context: ErrorContext? = nil
    ) {
        let error = TimeTrackingError.systemResourceExhausted
        let enhancedContext = ErrorContext(
            userAction: context?.userAction,
            systemState: context?.systemState ?? [:],
            stackTrace: exception.callStackSymbols.joined(separator: "\n"),
            additionalInfo: [
                "exception_name": exception.name.rawValue,
                "exception_reason": exception.reason ?? "Unknown"
            ]
        )
        
        logError(error, context: enhancedContext)
    }
    
    func logCrash(crashInfo: [String: Any]) {
        let error = TimeTrackingError.systemResourceExhausted
        let context = ErrorContext(
            userAction: "Application crashed",
            systemState: crashInfo,
            stackTrace: crashInfo["stackTrace"] as? String,
            additionalInfo: crashInfo
        )
        
        logError(error, context: context)
    }
    
    private func logToSystem(_ entry: ErrorLogEntry) {
        let message = """
        Error: \(entry.error.localizedDescription)
        Category: \(entry.error.category.rawValue)
        Severity: \(entry.error.severity.rawValue)
        User Action: \(entry.userAction ?? "None")
        Timestamp: \(entry.timestamp)
        """
        
        logger.log(level: entry.error.severity.logLevel, "\(message)")
    }
    
    private func writeToLogFile(_ entry: ErrorLogEntry) {
        let logFileName = "errors_\(DateFormatter.logFileFormatter.string(from: Date())).log"
        let logFileURL = logDirectory.appendingPathComponent(logFileName)
        
        let logLine = formatLogEntry(entry)
        
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logLine.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
            
            // Rotate logs if necessary
            rotateLogsIfNeeded()
            
        } catch {
            logger.error("Failed to write to log file: \(error.localizedDescription)")
        }
    }
    
    private func formatLogEntry(_ entry: ErrorLogEntry) -> String {
        let formatter = DateFormatter.iso8601Formatter
        
        var logLine = """
        [\(formatter.string(from: entry.timestamp))] [\(entry.error.severity.rawValue.uppercased())] [\(entry.error.category.rawValue)]
        Error: \(entry.error.localizedDescription)
        """
        
        if let userAction = entry.userAction {
            logLine += "\nUser Action: \(userAction)"
        }
        
        if let stackTrace = entry.context.stackTrace {
            logLine += "\nStack Trace:\n\(stackTrace)"
        }
        
        if !entry.additionalInfo.isEmpty {
            logLine += "\nAdditional Info: \(entry.additionalInfo)"
        }
        
        logLine += "\n" + String(repeating: "-", count: 80) + "\n"
        
        return logLine
    }
    
    private func rotateLogsIfNeeded() {
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }
            
            // Remove excess log files
            if logFiles.count > maxLogFiles {
                for fileURL in logFiles.dropFirst(maxLogFiles) {
                    try fileManager.removeItem(at: fileURL)
                }
            }
            
            // Check file sizes and rotate if needed
            for fileURL in logFiles {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize, fileSize > maxLogFileSize {
                    // Archive the large file
                    let archiveName = fileURL.lastPathComponent.replacingOccurrences(of: ".log", with: "_archived.log")
                    let archiveURL = logDirectory.appendingPathComponent(archiveName)
                    try fileManager.moveItem(at: fileURL, to: archiveURL)
                }
            }
            
        } catch {
            logger.error("Failed to rotate logs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Crash Detection
    
    private func setupCrashDetection() {
        // Set up exception handler
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                ErrorLogger.shared.logException(exception)
            }
        }
        
        // Set up signal handler for crashes
        signal(SIGABRT) { signal in
            Task { @MainActor in
                ErrorLogger.shared.logCrash(crashInfo: [
                    "signal": signal,
                    "type": "SIGABRT",
                    "timestamp": Date()
                ])
            }
        }
        
        signal(SIGILL) { signal in
            Task { @MainActor in
                ErrorLogger.shared.logCrash(crashInfo: [
                    "signal": signal,
                    "type": "SIGILL",
                    "timestamp": Date()
                ])
            }
        }
        
        signal(SIGSEGV) { signal in
            Task { @MainActor in
                ErrorLogger.shared.logCrash(crashInfo: [
                    "signal": signal,
                    "type": "SIGSEGV",
                    "timestamp": Date()
                ])
            }
        }
    }
    
    private func handleCriticalError(_ entry: ErrorLogEntry) {
        // For critical errors, we might want to:
        // 1. Create an immediate backup
        // 2. Send crash report (if user opted in)
        // 3. Show user notification
        // 4. Attempt automatic recovery
        
        logger.fault("Critical error detected: \(entry.error.localizedDescription)")
        
        // Trigger emergency backup
        Task {
            await createEmergencyBackup()
        }
    }
    
    private func createEmergencyBackup() async {
        // Implementation would depend on backup system
        logger.info("Creating emergency backup due to critical error")
    }
    
    // MARK: - Error Retrieval and Analysis
    
    func getErrors(
        category: ErrorCategory? = nil,
        severity: ErrorSeverity? = nil,
        since: Date? = nil,
        limit: Int = 100
    ) -> [ErrorLogEntry] {
        var filtered = recentErrors
        
        if let category = category {
            filtered = filtered.filter { $0.error.category == category }
        }
        
        if let severity = severity {
            filtered = filtered.filter { $0.error.severity == severity }
        }
        
        if let since = since {
            filtered = filtered.filter { $0.timestamp >= since }
        }
        
        return Array(filtered.prefix(limit))
    }
    
    func getErrorStatistics(for period: StatisticsPeriod = .lastWeek) -> ErrorStatistics {
        let cutoffDate = period.cutoffDate
        let relevantErrors = recentErrors.filter { $0.timestamp >= cutoffDate }
        
        var categoryCounts: [ErrorCategory: Int] = [:]
        var severityCounts: [ErrorSeverity: Int] = [:]
        
        for error in relevantErrors {
            categoryCounts[error.error.category, default: 0] += 1
            severityCounts[error.error.severity, default: 0] += 1
        }
        
        return ErrorStatistics(
            totalErrors: relevantErrors.count,
            categoryCounts: categoryCounts,
            severityCounts: severityCounts,
            period: period,
            mostCommonError: findMostCommonError(in: relevantErrors),
            errorRate: calculateErrorRate(errors: relevantErrors, period: period)
        )
    }
    
    private func findMostCommonError(in errors: [ErrorLogEntry]) -> TimeTrackingError? {
        let errorCounts = Dictionary(grouping: errors) { $0.error }
            .mapValues { $0.count }
        
        return errorCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func calculateErrorRate(errors: [ErrorLogEntry], period: StatisticsPeriod) -> Double {
        let timeInterval = Date().timeIntervalSince(period.cutoffDate)
        let hoursInPeriod = timeInterval / 3600
        return hoursInPeriod > 0 ? Double(errors.count) / hoursInPeriod : 0
    }
    
    private func loadRecentErrors() {
        // Load recent errors from the most recent log file
        // This is a simplified implementation
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }
            
            // For now, just initialize empty - in a full implementation,
            // we would parse the log files to reconstruct recent errors
            
        } catch {
            logger.error("Failed to load recent errors: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Log Export
    
    func exportLogs() -> URL? {
        do {
            let exportURL = logDirectory.appendingPathComponent("exported_logs_\(Date().timeIntervalSince1970).zip")
            // Implementation would create a zip file of all logs
            // For now, return the log directory
            return logDirectory
        } catch {
            logger.error("Failed to export logs: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Supporting Types

struct ErrorLogEntry: Identifiable {
    let id = UUID()
    let error: TimeTrackingError
    let context: ErrorContext
    let userAction: String?
    let additionalInfo: [String: Any]
    let timestamp: Date
    
    init(error: TimeTrackingError, 
         context: ErrorContext, 
         userAction: String? = nil, 
         additionalInfo: [String: Any] = [:]) {
        self.error = error
        self.context = context
        self.userAction = userAction
        self.additionalInfo = additionalInfo
        self.timestamp = Date()
    }
}

struct ErrorStatistics {
    let totalErrors: Int
    let categoryCounts: [ErrorCategory: Int]
    let severityCounts: [ErrorSeverity: Int]
    let period: StatisticsPeriod
    let mostCommonError: TimeTrackingError?
    let errorRate: Double // Errors per hour
}

enum StatisticsPeriod {
    case lastHour
    case lastDay
    case lastWeek
    case lastMonth
    
    var cutoffDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .lastHour:
            return calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        case .lastDay:
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .lastWeek:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let logFileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}