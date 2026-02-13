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

struct InsightActivityDTO: Encodable {
    let index: Int
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
    let storedDurationSeconds: Double
    let calculatedDurationSeconds: Double
    let contextLabel: String
}

struct InsightSessionDTO: Encodable {
    let index: Int
    let startTime: String
    let endTime: String
    let durationSeconds: Double
    let dominantAppBundleId: String?
    let dominantAppName: String?
    let contextSwitchCount: Int
    let activityIndices: [Int]
}

struct InsightBehavioralBlockDTO: Encodable {
    let index: Int
    let blockType: String
    let startTime: String
    let endTime: String
    let durationSeconds: Double
    let dominantActivity: String?
    let dominantAppBundleId: String?
    let focusScore: Double
    let contextSwitchCount: Int
    let sessionIndices: [Int]
}

struct InsightTimeStructureDTO: Encodable {
    let totalTrackedSeconds: Double
    let deepDurationSeconds: Double
    let fragmentedDurationSeconds: Double
    let passiveDurationSeconds: Double
    let communicationDurationSeconds: Double
    let idleDurationSeconds: Double
    let deepPercentage: Double
    let fragmentedPercentage: Double
    let passivePercentage: Double
    let communicationPercentage: Double
    let idlePercentage: Double
    let totalTrackedFormatted: String
    let deepDurationFormatted: String
    let fragmentedDurationFormatted: String
    let passiveDurationFormatted: String
    let communicationDurationFormatted: String
    let idleDurationFormatted: String
}

struct InsightNarrativeDTO: Encodable {
    let headline: String
    let subtext: String
    let keyMetrics: [String: String]
}

struct InsightComparisonDTO: Encodable {
    let name: String
    let value: String
    let change: Double
    let isPositive: Bool
    let changeFormatted: String
}

struct InsightActivitiesLayerDTO: Encodable {
    let count: Int
    let totalDurationSeconds: Double
    let items: [InsightActivityDTO]
}

struct InsightSessionsLayerDTO: Encodable {
    let count: Int
    let items: [InsightSessionDTO]
}

struct InsightBehavioralBlocksLayerDTO: Encodable {
    let count: Int
    let items: [InsightBehavioralBlockDTO]
}

struct InsightComparisonLayerDTO: Encodable {
    let count: Int
    let items: [InsightComparisonDTO]
    let formattedByMetric: [String: String]
}

struct TodayInsightComputationDTO: Encodable {
    let analysisVersion: String
    let activities: InsightActivitiesLayerDTO
    let sessions: InsightSessionsLayerDTO
    let behavioralBlocks: InsightBehavioralBlocksLayerDTO
    let timeStructure: InsightTimeStructureDTO
    let insight: InsightNarrativeDTO?
    let comparisonWithYesterday: InsightComparisonLayerDTO
}

struct DailyInsightSummaryResponse: Encodable {
    let date: String
    let windowStart: String
    let windowEnd: String
    let todayInsight: TodayInsightComputationDTO
}

private struct InsightActivityRecord {
    let index: Int
    let appName: String
    let bundleId: String
    let title: String?
    let filePath: String?
    let webURL: String?
    let domain: String?
    let projectId: String?
    let projectName: String?
    let startTime: Date
    let endTime: Date?
    let storedDurationSeconds: Double

    func calculatedDuration(at referenceNow: Date) -> Double {
        if let endTime {
            return max(0, endTime.timeIntervalSince(startTime))
        }
        return max(0, referenceNow.timeIntervalSince(startTime))
    }
}

private struct InsightSessionSnapshot {
    let index: Int
    let startTime: Date
    let endTime: Date
    let dominantAppBundleId: String?
    let dominantAppName: String?
    let contextSwitchCount: Int
    let activityIndices: [Int]

    var duration: Double {
        max(0, endTime.timeIntervalSince(startTime))
    }
}

private enum InsightBlockType: String {
    case deep
    case fragmented
    case passive
    case communication
    case idle
}

private struct InsightBehavioralBlockSnapshot {
    let index: Int
    let startTime: Date
    let endTime: Date
    let blockType: InsightBlockType
    let dominantActivity: String?
    let dominantAppBundleId: String?
    let focusScore: Double
    let contextSwitchCount: Int
    let sessionIndices: [Int]

    var duration: Double {
        max(0, endTime.timeIntervalSince(startTime))
    }
}

private struct InsightTimeStructureSnapshot {
    let deepDuration: Double
    let fragmentedDuration: Double
    let passiveDuration: Double
    let communicationDuration: Double
    let idleDuration: Double

    var totalTracked: Double {
        deepDuration + fragmentedDuration + passiveDuration + communicationDuration + idleDuration
    }

    var deepPercentage: Double {
        percentage(of: deepDuration)
    }

    var fragmentedPercentage: Double {
        percentage(of: fragmentedDuration)
    }

    var passivePercentage: Double {
        percentage(of: passiveDuration)
    }

    var communicationPercentage: Double {
        percentage(of: communicationDuration)
    }

    var idlePercentage: Double {
        percentage(of: idleDuration)
    }

    var totalTrackedFormatted: String {
        ChronoteCLI.formatInsightDuration(totalTracked)
    }

    var deepDurationFormatted: String {
        ChronoteCLI.formatInsightDuration(deepDuration)
    }

    var fragmentedDurationFormatted: String {
        ChronoteCLI.formatInsightDuration(fragmentedDuration)
    }

    var passiveDurationFormatted: String {
        ChronoteCLI.formatInsightDuration(passiveDuration)
    }

    var communicationDurationFormatted: String {
        ChronoteCLI.formatInsightDuration(communicationDuration)
    }

    var idleDurationFormatted: String {
        ChronoteCLI.formatInsightDuration(idleDuration)
    }

    private func percentage(of value: Double) -> Double {
        guard totalTracked > 0 else { return 0 }
        return (value / totalTracked) * 100
    }
}

private struct InsightNarrativeSnapshot {
    let headline: String
    let subtext: String
    let keyMetrics: [String: String]
}

private struct InsightComparisonSnapshot {
    let name: String
    let value: String
    let change: Double
    let isPositive: Bool

    var changeFormatted: String {
        let prefix = change >= 0 ? "+" : ""
        return "\(prefix)\(Int(change))%"
    }
}

private struct InsightBehaviorBlockBuilder {
    let blockType: InsightBlockType
    private(set) var startTime: Date = .distantFuture
    private(set) var endTime: Date = .distantPast
    private(set) var sessionIndices: [Int] = []
    private(set) var contextSwitchCount = 0

    private var focusScoreWeightedSum: Double = 0
    private var totalDuration: Double = 0
    private var appDurationsByName: [String: Double] = [:]
    private var appDurationsByBundle: [String: Double] = [:]
    private var domainDurations: [String: Double] = [:]
    private var contextDurations: [String: Double] = [:]

    init(blockType: InsightBlockType) {
        self.blockType = blockType
    }

    mutating func add(
        session: InsightSessionSnapshot,
        focusScore: Double,
        activities: [InsightActivityRecord],
        referenceNow: Date
    ) {
        startTime = min(startTime, session.startTime)
        endTime = max(endTime, session.endTime)
        sessionIndices.append(session.index)
        contextSwitchCount += session.contextSwitchCount

        let duration = max(0, session.duration)
        totalDuration += duration
        focusScoreWeightedSum += focusScore * duration

        if let name = session.dominantAppName {
            appDurationsByName[name, default: 0] += duration
        }
        if let bundle = session.dominantAppBundleId {
            appDurationsByBundle[bundle, default: 0] += duration
        }

        for activity in activities {
            let activityDuration = max(0, activity.calculatedDuration(at: referenceNow))
            let context = ChronoteCLI.contextLabel(for: activity)
            contextDurations[context, default: 0] += activityDuration

            if let domain = ChronoteCLI.extractDomain(from: activity) {
                domainDurations[domain, default: 0] += activityDuration
            }
        }
    }

    var averageFocusScore: Double {
        guard totalDuration > 0 else { return 0.0 }
        return focusScoreWeightedSum / totalDuration
    }

    var dominantAppBundleId: String? {
        appDurationsByBundle.max(by: { $0.value < $1.value })?.key
    }

    var dominantActivity: String? {
        let topContexts = contextDurations.sorted { $0.value > $1.value }.map(\.key)
        let topDomains = domainDurations.sorted { $0.value > $1.value }.map(\.key)

        if blockType == .passive, let firstDomain = topDomains.first {
            if topDomains.count > 1 {
                return "\(firstDomain) + \(topDomains[1])"
            }
            return firstDomain
        }

        if blockType == .deep, let firstContext = topContexts.first {
            if topContexts.count > 1 {
                return "\(firstContext) + \(topContexts[1])"
            }
            return firstContext
        }

        let sortedApps = appDurationsByName.sorted { $0.value > $1.value }.map(\.key)
        guard let first = sortedApps.first else { return nil }
        guard sortedApps.count > 1 else { return first }

        switch blockType {
        case .fragmented:
            return "Multiple apps"
        case .deep, .passive, .communication:
            return "\(first) + \(sortedApps[1])"
        case .idle:
            return "Idle"
        }
    }
}

struct ChronoteCLI {
    private static let insightAnalysisVersion = "3"

    private static let sessionGapThreshold: TimeInterval = 5 * 60
    private static let maxSessionDuration: TimeInterval = 60 * 60

    private static let deepFocusMinMinutesKey = "deepFocusMinMinutes"
    private static let defaultDeepFocusMinMinutes = 20
    private static let deepWorkMaxSwitches = 3
    private static let fragmentedHighSwitchThreshold = 5
    private static let fragmentedShortDurationThreshold: TimeInterval = 10 * 60
    private static let blockMergeGapThreshold: TimeInterval = 20 * 60

    private static let communicationBundleIds: Set<String> = [
        "com.apple.mail",
        "com.tinyspeck.slackmacgap",
        "com.microsoft.teams",
        "com.apple.iChat",
        "com.microsoft.Outlook",
        "com.readdle.smartemail-Mac",
        "com.postbox-inc.postboxapp",
    ]

    private static let passiveFallbackBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.apple.news",
        "com.reederapp.macOS",
        "com.apple.Preview",
    ]

    private static let passiveDomainKeywords: [String] = [
        "youtube.com", "youtu.be",
        "bilibili.com",
        "x.com", "twitter.com",
        "weibo.com",
        "reddit.com",
        "news.ycombinator.com",
        "medium.com",
        "zhihu.com",
        "instagram.com",
        "facebook.com",
        "tiktok.com",
    ]

    private static let communicationDomainKeywords: [String] = [
        "slack.com",
        "discord.com",
        "teams.microsoft.com",
        "mail.google.com",
        "outlook.office.com",
        "web.whatsapp.com",
        "wechat.com",
    ]

    private static var deepWorkMinDuration: TimeInterval {
        let configuredMinutes = UserDefaults.standard.integer(forKey: deepFocusMinMinutesKey)
        let minutes = configuredMinutes > 0 ? configuredMinutes : defaultDeepFocusMinMinutes
        return TimeInterval(minutes * 60)
    }

    static func main() -> Int32 {
        do {
            let args = try parseArguments(CommandLine.arguments)
            let storePath = args.options["store"] ?? Constants.defaultStorePath
            let pretty = args.flags.contains("pretty")

            if args.command == "mcp-stdio" {
                try runMCPStdio(storePath: storePath)
                return 0
            }

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
            },
            {
              "name": "mcp-stdio",
              "description": "Run MCP server over stdio",
              "options": ["--store <path>"]
            }
          ]
        }
        """
    }

    private static func runMCPStdio(storePath: String) throws {
        while let request = try readMCPMessage() {
            guard let method = request["method"] as? String else { continue }
            let id = request["id"]
            let params = request["params"] as? [String: Any] ?? [:]

            // Notifications do not require a response.
            let shouldReply = id != nil

            switch method {
            case "initialize":
                guard shouldReply else { continue }
                try writeMCPResponse([
                    "jsonrpc": "2.0",
                    "id": id as Any,
                    "result": [
                        "protocolVersion": "2024-11-05",
                        "capabilities": ["tools": [:]],
                        "serverInfo": [
                            "name": "chronote-cli",
                            "version": "0.1.0",
                        ],
                    ],
                ])
            case "ping":
                guard shouldReply else { continue }
                try writeMCPResponse([
                    "jsonrpc": "2.0",
                    "id": id as Any,
                    "result": [:],
                ])
            case "tools/list":
                guard shouldReply else { continue }
                try writeMCPResponse([
                    "jsonrpc": "2.0",
                    "id": id as Any,
                    "result": [
                        "tools": mcpTools(),
                    ],
                ])
            case "tools/call":
                guard shouldReply else { continue }
                do {
                    guard let toolName = params["name"] as? String else {
                        throw CLIError.invalidArguments("Missing tool name")
                    }
                    let toolArgs = params["arguments"] as? [String: Any] ?? [:]
                    let result = try callMCPTool(toolName: toolName, args: toolArgs, storePath: storePath)
                    try writeMCPResponse([
                        "jsonrpc": "2.0",
                        "id": id as Any,
                        "result": result,
                    ])
                } catch {
                    try writeMCPResponse([
                        "jsonrpc": "2.0",
                        "id": id as Any,
                        "error": [
                            "code": -32000,
                            "message": error.localizedDescription,
                        ],
                    ])
                }
            default:
                guard shouldReply else { continue }
                try writeMCPResponse([
                    "jsonrpc": "2.0",
                    "id": id as Any,
                    "error": [
                        "code": -32601,
                        "message": "Method not found: \(method)",
                    ],
                ])
            }
        }
    }

    private static func mcpTools() -> [[String: Any]] {
        [
            [
                "name": "chronote.projects",
                "description": "List projects from Chronote local store",
                "inputSchema": [
                    "type": "object",
                    "properties": [:],
                ],
            ],
            [
                "name": "chronote.activities",
                "description": "List activity records in a time window",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "start": ["type": "string", "description": "ISO-8601 inclusive lower bound"],
                        "end": ["type": "string", "description": "ISO-8601 exclusive upper bound"],
                        "limit": ["type": "integer", "minimum": 1, "maximum": 5000],
                    ],
                ],
            ],
            [
                "name": "chronote.events",
                "description": "List manual event records in a time window",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "start": ["type": "string", "description": "ISO-8601 inclusive lower bound"],
                        "end": ["type": "string", "description": "ISO-8601 exclusive upper bound"],
                        "limit": ["type": "integer", "minimum": 1, "maximum": 5000],
                    ],
                ],
            ],
            [
                "name": "chronote.summary",
                "description": "Get one-day activity summary",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "date": ["type": "string", "description": "YYYY-MM-DD"],
                    ],
                ],
            ],
        ]
    }

    private static func callMCPTool(
        toolName: String,
        args: [String: Any],
        storePath: String
    ) throws -> [String: Any] {
        let db = try SQLiteDatabase(path: storePath)
        defer { db.close() }

        let responseObject: Any
        switch toolName {
        case "chronote.projects":
            responseObject = try toJSONObject(listProjects(db: db))
        case "chronote.activities":
            let response = try listActivities(
                db: db,
                args: makeArgs(command: "activities", from: args)
            )
            responseObject = try toJSONObject(response)
        case "chronote.events":
            let response = try listEvents(
                db: db,
                args: makeArgs(command: "events", from: args)
            )
            responseObject = try toJSONObject(response)
        case "chronote.summary":
            let response = try summary(
                db: db,
                args: makeArgs(command: "summary", from: args)
            )
            responseObject = try toJSONObject(response)
        default:
            throw CLIError.invalidArguments("Unknown tool: \(toolName)")
        }

        let structured = responseObject as? [String: Any] ?? [:]
        let prettyData = try JSONSerialization.data(withJSONObject: structured, options: [.prettyPrinted])
        let text = String(data: prettyData, encoding: .utf8) ?? "{}"

        return [
            "content": [
                [
                    "type": "text",
                    "text": text,
                ],
            ],
            "structuredContent": structured,
            "isError": false,
        ]
    }

    private static func makeArgs(command: String, from dict: [String: Any]) -> Arguments {
        var options: [String: String] = [:]
        if let start = dict["start"] as? String { options["start"] = start }
        if let end = dict["end"] as? String { options["end"] = end }
        if let date = dict["date"] as? String { options["date"] = date }
        if let limit = dict["limit"] as? Int { options["limit"] = "\(limit)" }
        if let limitString = dict["limit"] as? String { options["limit"] = limitString }
        return Arguments(command: command, options: options, flags: [])
    }

    private static func toJSONObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: [])
    }

    private static func readMCPMessage() throws -> [String: Any]? {
        var contentLength: Int?

        while true {
            guard let lineData = try readLineData() else { return nil }
            guard let line = String(data: lineData, encoding: .utf8) else {
                throw CLIError.invalidArguments("Invalid MCP header encoding")
            }

            if line == "\r\n" || line == "\n" {
                break
            }

            if line.lowercased().hasPrefix("content-length:") {
                let value = line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value, let intValue = Int(value) {
                    contentLength = intValue
                }
            }
        }

        guard let length = contentLength, length > 0 else {
            throw CLIError.invalidArguments("Missing Content-Length")
        }

        let body = FileHandle.standardInput.readData(ofLength: length)
        if body.isEmpty { return nil }
        let object = try JSONSerialization.jsonObject(with: body, options: [])
        return object as? [String: Any]
    }

    private static func readLineData() throws -> Data? {
        var buffer = Data()
        while true {
            let byte = FileHandle.standardInput.readData(ofLength: 1)
            if byte.isEmpty {
                return buffer.isEmpty ? nil : buffer
            }
            buffer.append(byte)
            if byte == Data([0x0A]) { // \n
                return buffer
            }
        }
    }

    private static func writeMCPResponse(_ payload: [String: Any]) throws {
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        let header = "Content-Length: \(body.count)\r\n\r\n"
        guard let headerData = header.data(using: .utf8) else {
            throw CLIError.encoding
        }
        FileHandle.standardOutput.write(headerData)
        FileHandle.standardOutput.write(body)
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

    private static func summary(db: SQLiteDatabase, args: Arguments) throws -> DailyInsightSummaryResponse {
        let targetDate = try args.options["date"].map(parseDateOnly) ?? Date()
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: targetDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw CLIError.invalidArguments("Failed to compute day window")
        }

        let now = Date()
        let projects = try projectMap(db: db)
        let activities = try fetchInsightActivities(
            db: db,
            start: dayStart,
            end: dayEnd,
            projects: projects
        )

        let sessions = analyzeInsightSessions(from: activities, referenceNow: now)
        let blocks = analyzeInsightBlocks(
            from: sessions,
            activities: activities,
            referenceNow: now
        )
        let structure = analyzeInsightTimeStructure(from: blocks)

        let narrative: InsightNarrativeSnapshot? = activities.isEmpty
            ? nil
            : generateInsightNarrative(structure: structure, blocks: blocks)

        var comparisonItems: [InsightComparisonSnapshot] = []
        if !activities.isEmpty,
           let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: dayStart) {
            let yesterdayActivities = try fetchInsightActivities(
                db: db,
                start: yesterdayStart,
                end: dayStart,
                projects: projects
            )
            if !yesterdayActivities.isEmpty {
                let yesterdaySessions = analyzeInsightSessions(from: yesterdayActivities, referenceNow: now)
                let yesterdayBlocks = analyzeInsightBlocks(
                    from: yesterdaySessions,
                    activities: yesterdayActivities,
                    referenceNow: now
                )
                let yesterdayStructure = analyzeInsightTimeStructure(from: yesterdayBlocks)
                comparisonItems = compareInsightStructures(today: structure, yesterday: yesterdayStructure)
            }
        }

        let comparisonLayer = InsightComparisonLayerDTO(
            count: comparisonItems.count,
            items: comparisonItems.map {
                InsightComparisonDTO(
                    name: $0.name,
                    value: $0.value,
                    change: $0.change,
                    isPositive: $0.isPositive,
                    changeFormatted: $0.changeFormatted
                )
            },
            formattedByMetric: Dictionary(uniqueKeysWithValues: comparisonItems.map {
                ($0.name, "\($0.value) (\($0.changeFormatted))")
            })
        )

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return DailyInsightSummaryResponse(
            date: dateFormatter.string(from: dayStart),
            windowStart: isoString(dayStart),
            windowEnd: isoString(dayEnd),
            todayInsight: TodayInsightComputationDTO(
                analysisVersion: insightAnalysisVersion,
                activities: InsightActivitiesLayerDTO(
                    count: activities.count,
                    totalDurationSeconds: activities.reduce(0) { $0 + $1.calculatedDuration(at: now) },
                    items: activities.map {
                        InsightActivityDTO(
                            index: $0.index,
                            appName: $0.appName,
                            bundleId: $0.bundleId,
                            title: $0.title,
                            filePath: $0.filePath,
                            webURL: $0.webURL,
                            domain: $0.domain,
                            projectId: $0.projectId,
                            projectName: $0.projectName,
                            startTime: isoString($0.startTime),
                            endTime: $0.endTime.map(isoString),
                            storedDurationSeconds: $0.storedDurationSeconds,
                            calculatedDurationSeconds: $0.calculatedDuration(at: now),
                            contextLabel: contextLabel(for: $0)
                        )
                    }
                ),
                sessions: InsightSessionsLayerDTO(
                    count: sessions.count,
                    items: sessions.map {
                        InsightSessionDTO(
                            index: $0.index,
                            startTime: isoString($0.startTime),
                            endTime: isoString($0.endTime),
                            durationSeconds: $0.duration,
                            dominantAppBundleId: $0.dominantAppBundleId,
                            dominantAppName: $0.dominantAppName,
                            contextSwitchCount: $0.contextSwitchCount,
                            activityIndices: $0.activityIndices
                        )
                    }
                ),
                behavioralBlocks: InsightBehavioralBlocksLayerDTO(
                    count: blocks.count,
                    items: blocks.map {
                        InsightBehavioralBlockDTO(
                            index: $0.index,
                            blockType: $0.blockType.rawValue,
                            startTime: isoString($0.startTime),
                            endTime: isoString($0.endTime),
                            durationSeconds: $0.duration,
                            dominantActivity: $0.dominantActivity,
                            dominantAppBundleId: $0.dominantAppBundleId,
                            focusScore: $0.focusScore,
                            contextSwitchCount: $0.contextSwitchCount,
                            sessionIndices: $0.sessionIndices
                        )
                    }
                ),
                timeStructure: InsightTimeStructureDTO(
                    totalTrackedSeconds: structure.totalTracked,
                    deepDurationSeconds: structure.deepDuration,
                    fragmentedDurationSeconds: structure.fragmentedDuration,
                    passiveDurationSeconds: structure.passiveDuration,
                    communicationDurationSeconds: structure.communicationDuration,
                    idleDurationSeconds: structure.idleDuration,
                    deepPercentage: structure.deepPercentage,
                    fragmentedPercentage: structure.fragmentedPercentage,
                    passivePercentage: structure.passivePercentage,
                    communicationPercentage: structure.communicationPercentage,
                    idlePercentage: structure.idlePercentage,
                    totalTrackedFormatted: structure.totalTrackedFormatted,
                    deepDurationFormatted: structure.deepDurationFormatted,
                    fragmentedDurationFormatted: structure.fragmentedDurationFormatted,
                    passiveDurationFormatted: structure.passiveDurationFormatted,
                    communicationDurationFormatted: structure.communicationDurationFormatted,
                    idleDurationFormatted: structure.idleDurationFormatted
                ),
                insight: narrative.map {
                    InsightNarrativeDTO(
                        headline: $0.headline,
                        subtext: $0.subtext,
                        keyMetrics: $0.keyMetrics
                    )
                },
                comparisonWithYesterday: comparisonLayer
            )
        )
    }

    private static func fetchInsightActivities(
        db: SQLiteDatabase,
        start: Date,
        end: Date,
        projects: [String: String]
    ) throws -> [InsightActivityRecord] {
        let rows = try db.query(
            sql: """
            SELECT ZAPPNAME, ZAPPBUNDLEID, ZAPPTITLE, ZFILEPATH, ZWEBURL, ZDOMAIN, ZPROJECTID, ZSTARTTIME, ZENDTIME, ZDURATION
            FROM ZACTIVITY
            WHERE ZSTARTTIME >= ? AND ZSTARTTIME < ?
            ORDER BY ZSTARTTIME ASC
            """,
            params: [.double(toAppleTimestamp(start)), .double(toAppleTimestamp(end))]
        )

        return rows.enumerated().compactMap { offset, row in
            guard let startTime = fromAppleTimestampDate(row.double("ZSTARTTIME")) else { return nil }
            let projectId = row.string("ZPROJECTID")
            return InsightActivityRecord(
                index: offset,
                appName: row.string("ZAPPNAME") ?? "",
                bundleId: row.string("ZAPPBUNDLEID") ?? "",
                title: row.string("ZAPPTITLE"),
                filePath: row.string("ZFILEPATH"),
                webURL: row.string("ZWEBURL"),
                domain: row.string("ZDOMAIN"),
                projectId: projectId,
                projectName: projectId.flatMap { projects[$0] },
                startTime: startTime,
                endTime: fromAppleTimestampDate(row.double("ZENDTIME")),
                storedDurationSeconds: row.double("ZDURATION") ?? 0
            )
        }
    }

    private static func analyzeInsightSessions(
        from activities: [InsightActivityRecord],
        referenceNow: Date
    ) -> [InsightSessionSnapshot] {
        let sortedActivities = activities.sorted { $0.startTime < $1.startTime }
        guard !sortedActivities.isEmpty else { return [] }

        var sessions: [InsightSessionSnapshot] = []
        var currentActivities: [InsightActivityRecord] = []
        var sessionIndex = 0

        for activity in sortedActivities {
            if currentActivities.isEmpty {
                currentActivities.append(activity)
                continue
            }

            let lastActivity = currentActivities[currentActivities.count - 1]
            let gap = activity.startTime.timeIntervalSince(lastActivity.endTime ?? lastActivity.startTime)
            let currentSessionStart = currentActivities[0].startTime
            let activityEnd = activity.endTime ?? activity.startTime
            let projectedDuration = activityEnd.timeIntervalSince(currentSessionStart)

            if gap <= sessionGapThreshold && projectedDuration <= maxSessionDuration {
                currentActivities.append(activity)
            } else {
                if let session = createInsightSession(
                    from: currentActivities,
                    index: sessionIndex,
                    referenceNow: referenceNow
                ) {
                    sessions.append(session)
                    sessionIndex += 1
                }
                currentActivities = [activity]
            }
        }

        if let session = createInsightSession(
            from: currentActivities,
            index: sessionIndex,
            referenceNow: referenceNow
        ) {
            sessions.append(session)
        }

        return sessions
    }

    private static func createInsightSession(
        from activities: [InsightActivityRecord],
        index: Int,
        referenceNow: Date
    ) -> InsightSessionSnapshot? {
        guard !activities.isEmpty else { return nil }

        let startTime = activities[0].startTime
        let endTime = activities[activities.count - 1].endTime ?? referenceNow

        var bundleDurations: [String: Double] = [:]
        for activity in activities {
            bundleDurations[activity.bundleId, default: 0] += activity.calculatedDuration(at: referenceNow)
        }

        let dominantBundle = bundleDurations.max(by: { $0.value < $1.value })?.key
        let dominantName = activities.first(where: { $0.bundleId == dominantBundle })?.appName

        return InsightSessionSnapshot(
            index: index,
            startTime: startTime,
            endTime: endTime,
            dominantAppBundleId: dominantBundle,
            dominantAppName: dominantName,
            contextSwitchCount: max(0, activities.count - 1),
            activityIndices: activities.map(\.index)
        )
    }

    private static func analyzeInsightBlocks(
        from sessions: [InsightSessionSnapshot],
        activities: [InsightActivityRecord],
        referenceNow: Date
    ) -> [InsightBehavioralBlockSnapshot] {
        guard !sessions.isEmpty else { return [] }
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let activitiesByIndex = Dictionary(uniqueKeysWithValues: activities.map { ($0.index, $0) })
        var builders: [InsightBehaviorBlockBuilder] = []

        for session in sortedSessions {
            let sessionActivities = session.activityIndices.compactMap { activitiesByIndex[$0] }
            let blockType = classifyInsightSession(session, activities: sessionActivities, referenceNow: referenceNow)
            let focusScore = calculateInsightFocusScore(session: session, blockType: blockType)

            if var last = builders.last {
                let gap = session.startTime.timeIntervalSince(last.endTime)
                if last.blockType == blockType && gap <= blockMergeGapThreshold {
                    last.add(
                        session: session,
                        focusScore: focusScore,
                        activities: sessionActivities,
                        referenceNow: referenceNow
                    )
                    builders[builders.count - 1] = last
                    continue
                }
            }

            var builder = InsightBehaviorBlockBuilder(blockType: blockType)
            builder.add(
                session: session,
                focusScore: focusScore,
                activities: sessionActivities,
                referenceNow: referenceNow
            )
            builders.append(builder)
        }

        return builders.enumerated().map { offset, builder in
            InsightBehavioralBlockSnapshot(
                index: offset,
                startTime: builder.startTime,
                endTime: builder.endTime,
                blockType: builder.blockType,
                dominantActivity: builder.dominantActivity,
                dominantAppBundleId: builder.dominantAppBundleId,
                focusScore: builder.averageFocusScore,
                contextSwitchCount: builder.contextSwitchCount,
                sessionIndices: builder.sessionIndices
            )
        }
    }

    private static func classifyInsightSession(
        _ session: InsightSessionSnapshot,
        activities: [InsightActivityRecord],
        referenceNow: Date
    ) -> InsightBlockType {
        let duration = session.duration
        let switches = session.contextSwitchCount

        if duration < 60 && switches == 0 {
            return .idle
        }

        if isCommunicationSession(session, activities: activities, referenceNow: referenceNow) {
            return .communication
        }

        if duration >= deepWorkMinDuration && switches <= deepWorkMaxSwitches {
            return .deep
        }

        if switches >= fragmentedHighSwitchThreshold ||
            (duration < fragmentedShortDurationThreshold && switches > 0) {
            return .fragmented
        }

        if isPassiveSession(session, activities: activities, referenceNow: referenceNow) {
            return .passive
        }

        return .fragmented
    }

    private static func calculateInsightFocusScore(
        session: InsightSessionSnapshot,
        blockType: InsightBlockType
    ) -> Double {
        var score: Double
        switch blockType {
        case .deep:
            score = 0.9
        case .fragmented:
            score = 0.3
        case .passive:
            score = 0.5
        case .communication:
            score = 0.6
        case .idle:
            score = 0.0
        }

        let durationMinutes = session.duration / 60
        if durationMinutes > 45 {
            score = min(1.0, score + 0.1)
        }

        let switchPenalty = Double(session.contextSwitchCount) * 0.02
        return max(0.0, score - switchPenalty)
    }

    private static func isCommunicationSession(
        _ session: InsightSessionSnapshot,
        activities: [InsightActivityRecord],
        referenceNow: Date
    ) -> Bool {
        if let bundleId = session.dominantAppBundleId,
           communicationBundleIds.contains(bundleId) {
            return true
        }

        var domainDuration: Double = 0
        var communicationDuration: Double = 0
        for activity in activities {
            guard let domain = extractDomain(from: activity) else { continue }
            let duration = max(0, activity.calculatedDuration(at: referenceNow))
            domainDuration += duration
            if isCommunicationDomain(domain) {
                communicationDuration += duration
            }
        }

        guard domainDuration > 0 else { return false }
        return communicationDuration / domainDuration >= 0.5
    }

    private static func isPassiveSession(
        _ session: InsightSessionSnapshot,
        activities: [InsightActivityRecord],
        referenceNow: Date
    ) -> Bool {
        var domainDuration: Double = 0
        var passiveDuration: Double = 0
        for activity in activities {
            guard let domain = extractDomain(from: activity) else { continue }
            let duration = max(0, activity.calculatedDuration(at: referenceNow))
            domainDuration += duration
            if isPassiveDomain(domain) {
                passiveDuration += duration
            }
        }

        if domainDuration > 0 {
            return passiveDuration / domainDuration >= 0.5
        }

        if let bundleId = session.dominantAppBundleId {
            return passiveFallbackBundleIds.contains(bundleId)
        }
        return false
    }

    private static func analyzeInsightTimeStructure(
        from blocks: [InsightBehavioralBlockSnapshot]
    ) -> InsightTimeStructureSnapshot {
        var deepDuration: Double = 0
        var fragmentedDuration: Double = 0
        var passiveDuration: Double = 0
        var communicationDuration: Double = 0
        var idleDuration: Double = 0

        for block in blocks {
            switch block.blockType {
            case .deep:
                deepDuration += block.duration
            case .fragmented:
                fragmentedDuration += block.duration
            case .passive:
                passiveDuration += block.duration
            case .communication:
                communicationDuration += block.duration
            case .idle:
                idleDuration += block.duration
            }
        }

        return InsightTimeStructureSnapshot(
            deepDuration: deepDuration,
            fragmentedDuration: fragmentedDuration,
            passiveDuration: passiveDuration,
            communicationDuration: communicationDuration,
            idleDuration: idleDuration
        )
    }

    private static func generateInsightNarrative(
        structure: InsightTimeStructureSnapshot,
        blocks: [InsightBehavioralBlockSnapshot]
    ) -> InsightNarrativeSnapshot {
        let headline = generateInsightHeadline(structure: structure, blocks: blocks)
        let subtext = generateInsightSubtext(structure: structure, blocks: blocks)
        var keyMetrics = extractInsightKeyMetrics(blocks: blocks)
        keyMetrics["analysisVersion"] = insightAnalysisVersion
        return InsightNarrativeSnapshot(headline: headline, subtext: subtext, keyMetrics: keyMetrics)
    }

    private static func generateInsightHeadline(
        structure: InsightTimeStructureSnapshot,
        blocks: [InsightBehavioralBlockSnapshot]
    ) -> String {
        let totalMinutes = Int(structure.totalTracked / 60)
        let deepBlocks = blocks.filter { $0.blockType == .deep }

        if structure.deepPercentage > 40 {
            return "This day was productive with \(deepBlocks.count) deep focus sessions totaling \(structure.deepDurationFormatted)."
        } else if structure.fragmentedPercentage > 50 {
            let deepSessionCount = deepBlocks.count
            if deepSessionCount == 0 {
                return "Your day was highly fragmented with no sustained deep focus periods."
            }
            return "Your day was mostly fragmented. Only \(deepSessionCount) deep focus sessions occurred, totaling \(structure.deepDurationFormatted)."
        } else if structure.communicationPercentage > 30 {
            return "This day was communication-heavy with \(structure.communicationDurationFormatted) in meetings and messages."
        } else if structure.passivePercentage > 40 {
            return "You spent significant time in passive consumption (\(structure.passiveDurationFormatted)) on this day."
        } else {
            return "This day was balanced across different types of work (\(totalMinutes)m total tracked)."
        }
    }

    private static func generateInsightSubtext(
        structure: InsightTimeStructureSnapshot,
        blocks: [InsightBehavioralBlockSnapshot]
    ) -> String {
        let deepBlocks = blocks.filter { $0.blockType == .deep }.sorted { $0.duration > $1.duration }

        if let longestBlock = deepBlocks.first {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let start = formatter.string(from: longestBlock.startTime)
            let end = formatter.string(from: longestBlock.endTime)
            let appName = longestBlock.dominantActivity ?? "an app"
            return "The longest uninterrupted work happened between \(start) and \(end) in \(appName)."
        }

        if blocks.count > 10 {
            return "You switched contexts \(blocks.count) times throughout the day, indicating high fragmentation."
        }

        if structure.totalTracked < 2 * 3600 {
            return "Limited tracking data for this day - consider keeping your tracking running longer."
        }

        return "Your work pattern shows a mix of focused and fragmented periods."
    }

    private static func extractInsightKeyMetrics(
        blocks: [InsightBehavioralBlockSnapshot]
    ) -> [String: String] {
        var metrics: [String: String] = [:]
        let deepBlocks = blocks.filter { $0.blockType == .deep }
        metrics["deepSessionCount"] = "\(deepBlocks.count)"

        if let longestDeep = deepBlocks.max(by: { $0.duration < $1.duration }) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            metrics["longestDeepStart"] = formatter.string(from: longestDeep.startTime)
            metrics["longestDeepDuration"] = formatInsightDuration(longestDeep.duration)
        }

        let totalSwitches = blocks.reduce(0) { $0 + $1.contextSwitchCount }
        metrics["totalContextSwitches"] = "\(totalSwitches)"
        metrics["totalBlocks"] = "\(blocks.count)"

        let avgFocus = blocks.isEmpty ? 0 : blocks.reduce(0.0) { $0 + $1.focusScore } / Double(blocks.count)
        metrics["averageFocusScore"] = String(format: "%.2f", avgFocus)

        return metrics
    }

    private static func compareInsightStructures(
        today: InsightTimeStructureSnapshot,
        yesterday: InsightTimeStructureSnapshot
    ) -> [InsightComparisonSnapshot] {
        [
            InsightComparisonSnapshot(
                name: "Deep Focus",
                value: today.deepDurationFormatted,
                change: calculateInsightPercentageChange(from: yesterday.deepDuration, to: today.deepDuration),
                isPositive: true
            ),
            InsightComparisonSnapshot(
                name: "Fragmented Time",
                value: today.fragmentedDurationFormatted,
                change: calculateInsightPercentageChange(from: yesterday.fragmentedDuration, to: today.fragmentedDuration),
                isPositive: false
            ),
            InsightComparisonSnapshot(
                name: "Passive Time",
                value: today.passiveDurationFormatted,
                change: calculateInsightPercentageChange(from: yesterday.passiveDuration, to: today.passiveDuration),
                isPositive: false
            ),
        ]
    }

    private static func calculateInsightPercentageChange(from old: Double, to new: Double) -> Double {
        guard old > 0 else {
            return new > 0 ? 100 : 0
        }
        return ((new - old) / old) * 100
    }

    fileprivate static func extractDomain(from activity: InsightActivityRecord) -> String? {
        if let domain = activity.domain, !domain.isEmpty {
            return normalizeHost(domain)
        }
        if let urlString = activity.webURL,
           let url = URL(string: urlString),
           let host = url.host {
            return normalizeHost(host)
        }
        return nil
    }

    fileprivate static func contextLabel(for activity: InsightActivityRecord) -> String {
        if let title = activity.title, !title.isEmpty {
            return title
        }
        if let domain = extractDomain(from: activity) {
            return domain
        }
        if let path = activity.filePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        return activity.appName
    }

    private static func isPassiveDomain(_ domain: String) -> Bool {
        matches(domain: domain, keywords: passiveDomainKeywords)
    }

    private static func isCommunicationDomain(_ domain: String) -> Bool {
        matches(domain: domain, keywords: communicationDomainKeywords)
    }

    private static func normalizeHost(_ host: String) -> String {
        let lower = host.lowercased()
        if lower.hasPrefix("www.") {
            return String(lower.dropFirst(4))
        }
        return lower
    }

    private static func matches(domain: String, keywords: [String]) -> Bool {
        let normalized = normalizeHost(domain)
        return keywords.contains { keyword in
            normalized == keyword || normalized.hasSuffix(".\(keyword)")
        }
    }

    private static func fromAppleTimestampDate(_ value: Double?) -> Date? {
        guard let value else { return nil }
        return Date(timeIntervalSince1970: value + Constants.appleReferenceDate)
    }

    static func formatInsightDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
