import Foundation
import SwiftData
import os

/// Analyzes sessions and classifies them into behavioral blocks
/// Determines the type of behavior (deep, fragmented, passive, etc.)
@MainActor
final class BehavioralAnalyzer {
    private let logger = Logger(subsystem: "dev.leix.chronote", category: "BehavioralAnalyzer")

    // Classification thresholds
    private static let deepFocusMinMinutesKey = "deepFocusMinMinutes"
    private static let defaultDeepFocusMinMinutes = 20
    private let deepWorkMaxSwitches = 3
    private let fragmentedHighSwitchThreshold = 5
    private let fragmentedShortDurationThreshold: TimeInterval = 10 * 60 // 10 minutes
    /// Behavioral blocks are semantic chunks and can absorb nearby same-type sessions.
    private let blockMergeGapThreshold: TimeInterval = 20 * 60 // 20 minutes

    static let shared = BehavioralAnalyzer()

    private init() {}

    private var deepWorkMinDuration: TimeInterval {
        let configuredMinutes = UserDefaults.standard.integer(forKey: Self.deepFocusMinMinutesKey)
        let minutes = configuredMinutes > 0 ? configuredMinutes : Self.defaultDeepFocusMinMinutes
        return TimeInterval(minutes * 60)
    }

    /// Analyzes sessions and creates behavioral blocks
    func analyzeBlocks(from sessions: [Session], modelContext: ModelContext) throws -> [BehavioralBlock] {
        guard !sessions.isEmpty else {
            logger.debug("No sessions to analyze for behavioral blocks")
            return []
        }

        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let activitiesById = try buildActivityIndex(for: sortedSessions, modelContext: modelContext)
        var builders: [BehaviorBlockBuilder] = []

        for session in sortedSessions {
            let sessionActivities = session.activityIds.compactMap { activitiesById[$0] }
            let blockType = classifySession(session, activities: sessionActivities)
            let focusScore = calculateFocusScore(session, blockType: blockType)

            if var last = builders.last {
                let gap = session.startTime.timeIntervalSince(last.endTime)
                if last.blockType == blockType && gap <= blockMergeGapThreshold {
                    last.add(session, focusScore: focusScore, activities: sessionActivities)
                    builders[builders.count - 1] = last
                    continue
                }
            }

            var builder = BehaviorBlockBuilder(blockType: blockType)
            builder.add(session, focusScore: focusScore, activities: sessionActivities)
            builders.append(builder)
        }

        let blocks: [BehavioralBlock] = builders.map { builder in
            let block = BehavioralBlock(
                startTime: builder.startTime,
                endTime: builder.endTime,
                blockType: builder.blockType,
                dominantActivity: builder.dominantActivity,
                dominantAppBundleId: builder.dominantAppBundleId,
                focusScore: builder.averageFocusScore,
                contextSwitchCount: builder.contextSwitchCount,
                sessionIds: builder.sessionIds
            )
            modelContext.insert(block)
            return block
        }

        logger.info("Created \(blocks.count) behavioral blocks from \(sessions.count) sessions (merged)")
        return blocks
    }

    /// Classifies a session into a block type
    private func classifySession(_ session: Session, activities: [Activity]) -> BlockType {
        let duration = session.duration
        let switches = session.contextSwitchCount

        // Check for idle first (very short duration with no switches)
        if duration < 60 && switches == 0 {
            return .idle
        }

        // Communication by app or URL/domain context.
        if isCommunicationSession(session, activities: activities) {
            return .communication
        }

        // Check for deep work: long duration + low switches
        if duration >= deepWorkMinDuration && switches <= deepWorkMaxSwitches {
            return .deep
        }

        // Check for fragmented work: high switches OR short bursts
        if switches >= fragmentedHighSwitchThreshold ||
            (duration < fragmentedShortDurationThreshold && switches > 0) {
            return .fragmented
        }

        // Passive should be inferred primarily from URL/domain context.
        if isPassiveSession(session, activities: activities) {
            return .passive
        }

        // Default: moderate work is considered fragmented
        return .fragmented
    }

    /// Calculates a focus score for a session (0-1)
    private func calculateFocusScore(_ session: Session, blockType: BlockType) -> Double {
        // Base score by block type
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

        // Adjust by duration (longer sessions get slightly higher scores)
        let durationMinutes = session.duration / 60
        if durationMinutes > 45 {
            score = min(1.0, score + 0.1)
        }

        // Adjust by context switches (more switches reduce score)
        let switchPenalty = Double(session.contextSwitchCount) * 0.02
        score = max(0.0, score - switchPenalty)

        return score
    }

    private func buildActivityIndex(for sessions: [Session], modelContext: ModelContext) throws -> [UUID: Activity] {
        guard let first = sessions.first else { return [:] }
        let dayStart = Calendar.current.startOfDay(for: first.startTime)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

        let predicate = #Predicate<Activity> { activity in
            activity.startTime >= dayStart && activity.startTime < dayEnd
        }
        let descriptor = FetchDescriptor<Activity>(predicate: predicate)
        let activities = try modelContext.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }

    private func isCommunicationSession(_ session: Session, activities: [Activity]) -> Bool {
        if let bundleId = session.dominantAppBundleId,
           BehaviorClassificationConfig.communicationBundleIds.contains(bundleId) {
            return true
        }

        var domainDuration: TimeInterval = 0
        var communicationDuration: TimeInterval = 0
        for activity in activities {
            guard let domain = BehaviorClassificationConfig.extractDomain(from: activity) else { continue }
            let duration = max(0, activity.calculatedDuration)
            domainDuration += duration
            if BehaviorClassificationConfig.isCommunicationDomain(domain) {
                communicationDuration += duration
            }
        }

        guard domainDuration > 0 else { return false }
        return communicationDuration / domainDuration >= 0.5
    }

    private func isPassiveSession(_ session: Session, activities: [Activity]) -> Bool {
        var domainDuration: TimeInterval = 0
        var passiveDuration: TimeInterval = 0
        for activity in activities {
            guard let domain = BehaviorClassificationConfig.extractDomain(from: activity) else { continue }
            let duration = max(0, activity.calculatedDuration)
            domainDuration += duration
            if BehaviorClassificationConfig.isPassiveDomain(domain) {
                passiveDuration += duration
            }
        }

        if domainDuration > 0 {
            return passiveDuration / domainDuration >= 0.5
        }

        // Fallback when there is no web context.
        if let bundleId = session.dominantAppBundleId {
            return BehaviorClassificationConfig.passiveFallbackBundleIds.contains(bundleId)
        }
        return false
    }

    /// Retrieves behavioral blocks for a specific date
    func getBlocks(for date: Date, modelContext: ModelContext) throws -> [BehavioralBlock] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<BehavioralBlock> { block in
            block.startTime >= startOfDay && block.startTime < endOfDay
        }

        let descriptor = FetchDescriptor<BehavioralBlock>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Clears all behavioral blocks for a date
    func clearBlocks(for date: Date, modelContext: ModelContext) throws {
        let blocks = try getBlocks(for: date, modelContext: modelContext)
        for block in blocks {
            modelContext.delete(block)
        }
        logger.info("Cleared \(blocks.count) behavioral blocks for date: \(date)")
    }
}

private struct BehaviorBlockBuilder {
    let blockType: BlockType
    private(set) var startTime: Date = .distantFuture
    private(set) var endTime: Date = .distantPast
    private(set) var sessionIds: [UUID] = []
    private(set) var contextSwitchCount = 0

    private var focusScoreWeightedSum: Double = 0
    private var totalDuration: TimeInterval = 0
    private var appDurationsByName: [String: TimeInterval] = [:]
    private var appDurationsByBundle: [String: TimeInterval] = [:]
    private var domainDurations: [String: TimeInterval] = [:]
    private var contextDurations: [String: TimeInterval] = [:]

    init(blockType: BlockType) {
        self.blockType = blockType
    }

    mutating func add(_ session: Session, focusScore: Double, activities: [Activity]) {
        startTime = min(startTime, session.startTime)
        endTime = max(endTime, session.endTime)
        sessionIds.append(session.id)
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
            let activityDuration = max(0, activity.calculatedDuration)
            let context = BehaviorClassificationConfig.contextLabel(for: activity)
            contextDurations[context, default: 0] += activityDuration

            if let domain = BehaviorClassificationConfig.extractDomain(from: activity) {
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
