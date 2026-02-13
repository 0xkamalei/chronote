import Foundation
import SQLite3

struct Constants {
    static let defaultStorePath = NSHomeDirectory() + "/Library/Application Support/time-trace.store"
    static let appleReferenceDate: TimeInterval = 978_307_200 // 2001-01-01 00:00:00 UTC
}

enum CLIError: LocalizedError {
    case invalidArguments(String)
    case database(String)
    case encoding

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        case .database(let message):
            return message
        case .encoding:
            return "Failed to encode JSON output"
        }
    }
}

struct Arguments {
    let command: String
    let options: [String: String]
    let flags: Set<String>
}

struct ProjectDTO: Encodable {
    let id: String
    let name: String
    let isArchived: Bool
    let sortOrder: Int
    let productivityRating: Double
}

struct ProjectsResponse: Encodable {
    let count: Int
    let projects: [ProjectDTO]
}

struct ActivityDTO: Encodable {
    let appName: String
    let bundleId: String
    let title: String?
    let filePath: String?
    let webURL: String?
    let domain: String?
    let projectId: String?
    let projectName: String?
    let startTime: String
    let endTime: String?
    let durationSeconds: Double
}

struct ActivitiesResponse: Encodable {
    let count: Int
    let start: String?
    let end: String?
    let activities: [ActivityDTO]
}

struct EventDTO: Encodable {
    let name: String
    let projectId: String?
    let projectName: String?
    let startTime: String
    let endTime: String?
    let durationSeconds: Double?
}

struct EventsResponse: Encodable {
    let count: Int
    let start: String?
    let end: String?
    let events: [EventDTO]
}

struct AppSummaryDTO: Encodable {
    let appName: String
    let count: Int
    let durationSeconds: Double
}

struct ProjectSummaryDTO: Encodable {
    let projectId: String?
    let projectName: String?
    let count: Int
    let durationSeconds: Double
}

struct DailySummaryResponse: Encodable {
    let date: String
    let windowStart: String
    let windowEnd: String
    let activityCount: Int
    let totalDurationSeconds: Double
    let topApps: [AppSummaryDTO]
    let projects: [ProjectSummaryDTO]
}

struct ChronoteCLI {
    static func main() -> Int32 {
        do {
            let args = try parseArguments(CommandLine.arguments)
            let storePath = args.options["store"] ?? Constants.defaultStorePath
            let pretty = args.flags.contains("pretty")
            let db = try SQLiteDatabase(path: storePath)
            defer { db.close() }

            let output: String
            switch args.command {
            case "help":
                output = helpText()
            case "projects":
                output = try encodeJSON(try listProjects(db: db), pretty: pretty)
            case "activities":
                output = try encodeJSON(try listActivities(db: db, args: args), pretty: pretty)
            case "events":
                output = try encodeJSON(try listEvents(db: db, args: args), pretty: pretty)
            case "summary":
                output = try encodeJSON(try summary(db: db, args: args), pretty: pretty)
            default:
                throw CLIError.invalidArguments("Unknown command: \(args.command)")
            }

            FileHandle.standardOutput.write(Data(output.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
            return 0
        } catch {
            let message = error.localizedDescription.replacingOccurrences(of: "\"", with: "\\\"")
            let payload = "{\"error\":\"\(message)\"}\n"
            FileHandle.standardError.write(Data(payload.utf8))
            return 1
        }
    }

    private static func parseArguments(_ argv: [String]) throws -> Arguments {
        let tokens = Array(argv.dropFirst())
        guard let command = tokens.first else {
            return Arguments(command: "help", options: [:], flags: [])
        }

        var options: [String: String] = [:]
        var flags = Set<String>()
        var index = 1
        while index < tokens.count {
            let token = tokens[index]
            guard token.hasPrefix("--") else {
                index += 1
                continue
            }

            let key = String(token.dropFirst(2))
            if index + 1 < tokens.count, !tokens[index + 1].hasPrefix("--") {
                options[key] = tokens[index + 1]
                index += 2
            } else {
                flags.insert(key)
                index += 1
            }
        }

        return Arguments(command: command, options: options, flags: flags)
    }

    private static func encodeJSON<T: Encodable>(_ value: T, pretty: Bool) throws -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIError.encoding
        }
        return text
    }

    private static func helpText() -> String {
        """
        {
          "usage": "chronote-cli <command> [options]",
          "commands": [
            {
              "name": "help",
              "description": "Show command help"
            },
            {
              "name": "projects",
              "description": "List projects",
              "options": ["--store <path>", "--pretty"]
            },
            {
              "name": "activities",
              "description": "List activity records",
              "options": ["--start <ISO8601>", "--end <ISO8601>", "--limit <1..5000>", "--store <path>", "--pretty"]
            },
            {
              "name": "events",
              "description": "List manual event records",
              "options": ["--start <ISO8601>", "--end <ISO8601>", "--limit <1..5000>", "--store <path>", "--pretty"]
            },
            {
              "name": "summary",
              "description": "Get one-day activity summary",
              "options": ["--date <YYYY-MM-DD>", "--store <path>", "--pretty"]
            }
          ]
        }
        """
    }

    private static func parseISODateTime(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: value) {
            return parsed
        }
        let fallback = ISO8601DateFormatter()
        if let parsed = fallback.date(from: value) {
            return parsed
        }
        throw CLIError.invalidArguments("Invalid datetime: \(value)")
    }

    private static func parseDateOnly(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsed = formatter.date(from: value) {
            return parsed
        }
        throw CLIError.invalidArguments("Invalid date: \(value). Expected YYYY-MM-DD")
    }

    private static func toAppleTimestamp(_ date: Date) -> Double {
        date.timeIntervalSince1970 - Constants.appleReferenceDate
    }

    private static func fromAppleTimestamp(_ value: Double?) -> String? {
        guard let value else { return nil }
        let date = Date(timeIntervalSince1970: value + Constants.appleReferenceDate)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func projectMap(db: SQLiteDatabase) throws -> [String: String] {
        let rows = try db.query(
            sql: "SELECT ZID, ZNAME FROM ZPROJECT"
        )
        var map: [String: String] = [:]
        for row in rows {
            guard let id = row.string("ZID"), let name = row.string("ZNAME") else { continue }
            map[id] = name
        }
        return map
    }

    private static func listProjects(db: SQLiteDatabase) throws -> ProjectsResponse {
        let rows = try db.query(
            sql: """
            SELECT ZID, ZNAME, ZISARCHIVED, ZSORTORDER, ZPRODUCTIVITYRATING
            FROM ZPROJECT
            ORDER BY ZSORTORDER ASC, ZNAME ASC
            """
        )
        let projects = rows.compactMap { row -> ProjectDTO? in
            guard let id = row.string("ZID"), let name = row.string("ZNAME") else { return nil }
            return ProjectDTO(
                id: id,
                name: name,
                isArchived: (row.int("ZISARCHIVED") ?? 0) != 0,
                sortOrder: row.int("ZSORTORDER") ?? 0,
                productivityRating: row.double("ZPRODUCTIVITYRATING") ?? 0
            )
        }
        return ProjectsResponse(count: projects.count, projects: projects)
    }

    private static func listActivities(db: SQLiteDatabase, args: Arguments) throws -> ActivitiesResponse {
        let limit = max(1, min(Int(args.options["limit"] ?? "200") ?? 200, 5000))
        let startDate = try args.options["start"].map(parseISODateTime)
        let endDate = try args.options["end"].map(parseISODateTime)

        var sql = """
        SELECT ZAPPNAME, ZAPPBUNDLEID, ZAPPTITLE, ZFILEPATH, ZWEBURL, ZDOMAIN, ZPROJECTID, ZSTARTTIME, ZENDTIME, ZDURATION
        FROM ZACTIVITY
        """
        var params: [SQLiteValue] = []
        var clauses: [String] = []
        if let startDate {
            clauses.append("ZSTARTTIME >= ?")
            params.append(.double(toAppleTimestamp(startDate)))
        }
        if let endDate {
            clauses.append("ZSTARTTIME < ?")
            params.append(.double(toAppleTimestamp(endDate)))
        }
        if !clauses.isEmpty {
            sql += " WHERE " + clauses.joined(separator: " AND ")
        }
        sql += " ORDER BY ZSTARTTIME DESC LIMIT ?"
        params.append(.int(limit))

        let rows = try db.query(sql: sql, params: params)
        let projects = try projectMap(db: db)

        let activities = rows.map { row in
            ActivityDTO(
                appName: row.string("ZAPPNAME") ?? "",
                bundleId: row.string("ZAPPBUNDLEID") ?? "",
                title: row.string("ZAPPTITLE"),
                filePath: row.string("ZFILEPATH"),
                webURL: row.string("ZWEBURL"),
                domain: row.string("ZDOMAIN"),
                projectId: row.string("ZPROJECTID"),
                projectName: row.string("ZPROJECTID").flatMap { projects[$0] },
                startTime: fromAppleTimestamp(row.double("ZSTARTTIME")) ?? "",
                endTime: fromAppleTimestamp(row.double("ZENDTIME")),
                durationSeconds: row.double("ZDURATION") ?? 0
            )
        }

        return ActivitiesResponse(
            count: activities.count,
            start: startDate.map(isoString),
            end: endDate.map(isoString),
            activities: activities
        )
    }

    private static func listEvents(db: SQLiteDatabase, args: Arguments) throws -> EventsResponse {
        let limit = max(1, min(Int(args.options["limit"] ?? "200") ?? 200, 5000))
        let startDate = try args.options["start"].map(parseISODateTime)
        let endDate = try args.options["end"].map(parseISODateTime)

        var sql = "SELECT ZNAME, ZPROJECTID, ZSTARTTIME, ZENDTIME FROM ZEVENT"
        var params: [SQLiteValue] = []
        var clauses: [String] = []
        if let startDate {
            clauses.append("ZSTARTTIME >= ?")
            params.append(.double(toAppleTimestamp(startDate)))
        }
        if let endDate {
            clauses.append("ZSTARTTIME < ?")
            params.append(.double(toAppleTimestamp(endDate)))
        }
        if !clauses.isEmpty {
            sql += " WHERE " + clauses.joined(separator: " AND ")
        }
        sql += " ORDER BY ZSTARTTIME DESC LIMIT ?"
        params.append(.int(limit))

        let rows = try db.query(sql: sql, params: params)
        let projects = try projectMap(db: db)

        let events = rows.map { row in
            let start = row.double("ZSTARTTIME")
            let end = row.double("ZENDTIME")
            let duration = (start != nil && end != nil) ? (end! - start!) : nil
            return EventDTO(
                name: row.string("ZNAME") ?? "",
                projectId: row.string("ZPROJECTID"),
                projectName: row.string("ZPROJECTID").flatMap { projects[$0] },
                startTime: fromAppleTimestamp(start) ?? "",
                endTime: fromAppleTimestamp(end),
                durationSeconds: duration
            )
        }

        return EventsResponse(
            count: events.count,
            start: startDate.map(isoString),
            end: endDate.map(isoString),
            events: events
        )
    }

    private static func summary(db: SQLiteDatabase, args: Arguments) throws -> DailySummaryResponse {
        let targetDate: Date
        if let dateArg = args.options["date"] {
            targetDate = try parseDateOnly(dateArg)
        } else {
            targetDate = Date()
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: targetDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw CLIError.invalidArguments("Failed to compute day window")
        }

        let startTs = toAppleTimestamp(dayStart)
        let endTs = toAppleTimestamp(dayEnd)
        let projects = try projectMap(db: db)

        let totalRows = try db.query(
            sql: """
            SELECT COUNT(*) AS C, COALESCE(SUM(ZDURATION), 0) AS S
            FROM ZACTIVITY
            WHERE ZSTARTTIME >= ? AND ZSTARTTIME < ?
            """,
            params: [.double(startTs), .double(endTs)]
        )
        let totalRow = totalRows.first
        let count = totalRow?.int("C") ?? 0
        let duration = totalRow?.double("S") ?? 0

        let appRows = try db.query(
            sql: """
            SELECT ZAPPNAME AS APP, COUNT(*) AS C, COALESCE(SUM(ZDURATION), 0) AS S
            FROM ZACTIVITY
            WHERE ZSTARTTIME >= ? AND ZSTARTTIME < ?
            GROUP BY ZAPPNAME
            ORDER BY S DESC
            LIMIT 20
            """,
            params: [.double(startTs), .double(endTs)]
        )
        let topApps = appRows.map { row in
            AppSummaryDTO(
                appName: row.string("APP") ?? "",
                count: row.int("C") ?? 0,
                durationSeconds: row.double("S") ?? 0
            )
        }

        let projectRows = try db.query(
            sql: """
            SELECT ZPROJECTID AS PID, COUNT(*) AS C, COALESCE(SUM(ZDURATION), 0) AS S
            FROM ZACTIVITY
            WHERE ZSTARTTIME >= ? AND ZSTARTTIME < ?
            GROUP BY ZPROJECTID
            ORDER BY S DESC
            """,
            params: [.double(startTs), .double(endTs)]
        )

        let projectStats = projectRows.map { row in
            let pid = row.string("PID")
            return ProjectSummaryDTO(
                projectId: pid,
                projectName: pid.flatMap { projects[$0] } ?? (pid == nil ? "Unassigned" : nil),
                count: row.int("C") ?? 0,
                durationSeconds: row.double("S") ?? 0
            )
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return DailySummaryResponse(
            date: dateFormatter.string(from: dayStart),
            windowStart: isoString(dayStart),
            windowEnd: isoString(dayEnd),
            activityCount: count,
            totalDurationSeconds: duration,
            topApps: topApps,
            projects: projectStats
        )
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

enum SQLiteValue {
    case int(Int)
    case double(Double)
    case text(String)
}

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_close(handle)
            throw CLIError.database("Failed to open sqlite db: \(message)")
        }
    }

    deinit {
        close()
    }

    func close() {
        if handle != nil {
            sqlite3_close(handle)
            handle = nil
        }
    }

    func query(sql: String, params: [SQLiteValue] = []) throws -> [SQLiteRow] {
        guard let handle else {
            throw CLIError.database("Database is closed")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CLIError.database(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in params.enumerated() {
            let i = Int32(index + 1)
            switch value {
            case .int(let v):
                sqlite3_bind_int64(statement, i, sqlite3_int64(v))
            case .double(let v):
                sqlite3_bind_double(statement, i, v)
            case .text(let v):
                let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(statement, i, v, -1, sqliteTransient)
            }
        }

        var rows: [SQLiteRow] = []
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_ROW {
                rows.append(SQLiteRow(statement: statement))
            } else if rc == SQLITE_DONE {
                break
            } else {
                throw CLIError.database(String(cString: sqlite3_errmsg(handle)))
            }
        }
        return rows
    }
}

struct SQLiteRow {
    private let columns: [String: Any?]

    init(statement: OpaquePointer?) {
        let count = sqlite3_column_count(statement)
        var dict: [String: Any?] = [:]
        for i in 0..<count {
            guard let cName = sqlite3_column_name(statement, i) else { continue }
            let name = String(cString: cName)
            let type = sqlite3_column_type(statement, i)
            switch type {
            case SQLITE_INTEGER:
                dict[name] = Int(sqlite3_column_int64(statement, i))
            case SQLITE_FLOAT:
                dict[name] = Double(sqlite3_column_double(statement, i))
            case SQLITE_TEXT:
                if let cText = sqlite3_column_text(statement, i) {
                    dict[name] = String(cString: cText)
                } else {
                    dict[name] = nil
                }
            case SQLITE_NULL:
                dict[name] = nil
            default:
                dict[name] = nil
            }
        }
        columns = dict
    }

    func string(_ key: String) -> String? { columns[key] as? String }
    func int(_ key: String) -> Int? { columns[key] as? Int }
    func double(_ key: String) -> Double? {
        if let value = columns[key] as? Double { return value }
        if let value = columns[key] as? Int { return Double(value) }
        return nil
    }
}

exit(ChronoteCLI.main())
