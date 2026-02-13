import SwiftUI

/// Visualizes session segments across a full day timeline (00:00 - 24:00).
struct BehaviorTimelineView: View {
    let date: Date
    let sessions: [Session]
    let blocks: [BehavioralBlock]
    let activities: [Activity]

    private struct HoverInfo {
        let sessionId: UUID
        let blockType: BlockType
        let anchor: CGPoint
    }

    private struct SessionSegment {
        let sessionId: UUID
        let blockType: BlockType
        let rect: CGRect
    }

    @State private var hoverInfo: HoverInfo?

    private let tooltipWidth: CGFloat = 300
    private let tooltipEstimatedHeight: CGFloat = 152

    private let deepColor = Color.blue
    private let fragmentedColor = Color.orange
    private let passiveColor = Color.purple
    private let communicationColor = Color.cyan
    private let idleColor = Color(white: 0.82)

    private var sortedSessions: [Session] {
        sessions.sorted { $0.startTime < $1.startTime }
    }

    private var blockTypeBySessionId: [UUID: BlockType] {
        var map: [UUID: BlockType] = [:]
        for block in blocks {
            for sessionId in block.sessionIds where map[sessionId] == nil {
                map[sessionId] = block.blockType
            }
        }
        return map
    }

    private var activitiesById: [UUID: Activity] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }

    private var dayStart: Date {
        Calendar.current.startOfDay(for: date)
    }

    private var dayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
    }

    private var dayDuration: TimeInterval {
        dayEnd.timeIntervalSince(dayStart)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Behavior Timeline")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }

            VStack(spacing: 10) {
                HStack {
                    Text("00:00")
                    Spacer()
                    Text("06:00")
                    Spacer()
                    Text("12:00")
                    Spacer()
                    Text("18:00")
                    Spacer()
                    Text("24:00")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    let segments = buildSegments(width: geometry.size.width)
                    ZStack(alignment: .topLeading) {
                        Canvas { context, size in
                            let background = Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerRadius: 8)
                            context.fill(background, with: .color(Color(NSColor.controlBackgroundColor)))

                            for segment in segments {
                                let path = Path(roundedRect: segment.rect, cornerRadius: 6)
                                context.fill(path, with: .color(color(for: segment.blockType)))
                            }
                        }
                        .frame(height: 56)

                    }
                    .frame(width: geometry.size.width, height: 56)
                    .contentShape(Rectangle())
                    .onContinuousHover(coordinateSpace: .local) { phase in
                        switch phase {
                        case .active(let location):
                            if let segment = segments.last(where: { $0.rect.contains(location) }) {
                                hoverInfo = HoverInfo(
                                    sessionId: segment.sessionId,
                                    blockType: segment.blockType,
                                    anchor: location
                                )
                            } else {
                                hoverInfo = nil
                            }
                        case .ended:
                            hoverInfo = nil
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        GeometryReader { overlayGeo in
                            if let hoverInfo,
                               let hoveredSession = sortedSessions.first(where: { $0.id == hoverInfo.sessionId }) {
                                let descriptor = sessionDescriptor(for: hoveredSession, blockType: hoverInfo.blockType)
                                SessionTooltipCard(
                                    sessionName: descriptor.name,
                                    session: hoveredSession,
                                    blockType: hoverInfo.blockType,
                                    contentSummary: descriptor.content
                                )
                                .frame(width: tooltipWidth, alignment: .leading)
                                .position(
                                    x: tooltipCenterX(anchorX: hoverInfo.anchor.x, width: overlayGeo.size.width),
                                    y: tooltipCenterY(anchorY: hoverInfo.anchor.y, height: overlayGeo.size.height)
                                )
                                .zIndex(10)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(height: 56)
            }
            .padding(8)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .zIndex(hoverInfo == nil ? 0 : 1000)
    }

    private func color(for blockType: BlockType) -> Color {
        switch blockType {
        case .deep:
            return deepColor
        case .fragmented:
            return fragmentedColor
        case .passive:
            return passiveColor
        case .communication:
            return communicationColor
        case .idle:
            return idleColor
        }
    }

    private func tooltipCenterX(anchorX: CGFloat, width: CGFloat) -> CGFloat {
        let halfWidth = tooltipWidth / 2
        let clamped = min(max(anchorX, halfWidth), max(halfWidth, width - halfWidth))
        return clamped
    }

    private func tooltipCenterY(anchorY: CGFloat, height: CGFloat) -> CGFloat {
        let halfHeight = tooltipEstimatedHeight / 2
        let preferredTop = anchorY - tooltipEstimatedHeight - 10
        if preferredTop >= 0 {
            return preferredTop + halfHeight
        }

        let belowTop = anchorY + 10
        let maxTop = max(0, height - tooltipEstimatedHeight)
        return min(max(belowTop, 0), maxTop) + halfHeight
    }

    private func buildSegments(width: CGFloat) -> [SessionSegment] {
        guard width > 0, dayDuration > 0 else { return [] }

        return sortedSessions.compactMap { session in
            let clampedStart = max(session.startTime, dayStart)
            let clampedEnd = min(session.endTime, dayEnd)
            let segmentDuration = clampedEnd.timeIntervalSince(clampedStart)
            guard segmentDuration > 0 else { return nil }

            let startOffset = clampedStart.timeIntervalSince(dayStart)
            let x = width * (startOffset / dayDuration)
            let segmentWidth = max(3, width * (segmentDuration / dayDuration))
            let blockType = blockTypeBySessionId[session.id] ?? .fragmented

            return SessionSegment(
                sessionId: session.id,
                blockType: blockType,
                rect: CGRect(x: x, y: 6, width: segmentWidth, height: 44)
            )
        }
    }

    private func sessionDescriptor(for session: Session, blockType: BlockType) -> (name: String, content: String) {
        let sessionActivities = session.activityIds.compactMap { activitiesById[$0] }
        guard !sessionActivities.isEmpty else {
            return (name: fallbackSessionName(session: session, blockType: blockType), content: "N/A")
        }

        var contextDurations: [String: TimeInterval] = [:]
        var domainDurations: [String: TimeInterval] = [:]
        for activity in sessionActivities {
            let duration = max(0, activity.calculatedDuration)
            let context = BehaviorClassificationConfig.contextLabel(for: activity)
            contextDurations[context, default: 0] += duration
            if let domain = BehaviorClassificationConfig.extractDomain(from: activity) {
                domainDurations[domain, default: 0] += duration
            }
        }

        let topContexts = contextDurations.sorted { $0.value > $1.value }.map(\.key)
        let topDomains = domainDurations.sorted { $0.value > $1.value }.map(\.key)

        let topContextSummary: String = {
            guard let first = topContexts.first else { return "N/A" }
            return topContexts.count > 1 ? "\(first), \(topContexts[1])" : first
        }()

        let topDomainSummary: String = {
            guard let first = topDomains.first else { return "N/A" }
            return topDomains.count > 1 ? "\(first), \(topDomains[1])" : first
        }()

        switch blockType {
        case .passive:
            let primary = topDomains.first ?? topContexts.first ?? "Unknown content"
            return (name: "Passive: \(primary)", content: topDomainSummary)
        case .deep:
            let primary = topContexts.first ?? session.dominantAppName ?? "Focus Work"
            return (name: "Deep Focus: \(primary)", content: topContextSummary)
        case .communication:
            let primary = topDomains.first ?? topContexts.first ?? session.dominantAppName ?? "Conversation"
            return (name: "Communication: \(primary)", content: topDomainSummary != "N/A" ? topDomainSummary : topContextSummary)
        case .fragmented:
            let primary = topContexts.first ?? session.dominantAppName ?? "Multiple contexts"
            return (name: "Fragmented: \(primary)", content: topContextSummary)
        case .idle:
            return (name: "Idle Break", content: topContextSummary)
        }
    }

    private func fallbackSessionName(session: Session, blockType: BlockType) -> String {
        let app = session.dominantAppName ?? "Unknown App"
        switch blockType {
        case .deep:
            return "Deep Focus: \(app)"
        case .fragmented:
            return "Fragmented: \(app)"
        case .passive:
            return "Passive: \(app)"
        case .communication:
            return "Communication: \(app)"
        case .idle:
            return "Idle Break"
        }
    }
}

private struct SessionTooltipCard: View {
    let sessionName: String
    let session: Session
    let blockType: BlockType
    let contentSummary: String

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: session.startTime)) ～ \(formatter.string(from: session.endTime))"
    }

    private var blockTypeLabel: String {
        String(blockType.rawValue.prefix(1)).uppercased() + blockType.rawValue.dropFirst()
    }

    private var switchingLabel: String {
        let switches = session.contextSwitchCount
        if switches == 0 { return "None" }
        if switches <= 3 { return "Low" }
        if switches <= 8 { return "Medium" }
        return "High"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sessionName)
                .font(.system(size: 12, weight: .semibold))

            Text("App: \(session.dominantAppName ?? "Unknown App")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("Type: \(blockTypeLabel)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Time: \(timeRange)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Duration: \(ActivityDataProcessor.formatDuration(session.duration))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Switching: \(switchingLabel)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Content: \(contentSummary)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.14), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    let now = Date()
    let dayStart = Calendar.current.startOfDay(for: now)

    let previewActivities = [
        Activity(
            appName: "Chrome",
            appBundleId: "com.google.Chrome",
            appTitle: "YouTube - Music",
            webUrl: "https://www.youtube.com/watch?v=1",
            domain: "youtube.com",
            duration: 1800,
            startTime: dayStart.addingTimeInterval(3600),
            endTime: dayStart.addingTimeInterval(5400)
        ),
    ]
    let previewSession = Session(
        startTime: dayStart.addingTimeInterval(3600),
        endTime: dayStart.addingTimeInterval(5400),
        dominantAppBundleId: "com.google.Chrome",
        dominantAppName: "Google Chrome",
        contextSwitchCount: 4,
        activityIds: [previewActivities[0].id]
    )
    let previewBlock = BehavioralBlock(
        startTime: previewSession.startTime,
        endTime: previewSession.endTime,
        blockType: .passive,
        sessionIds: [previewSession.id]
    )

    BehaviorTimelineView(
        date: now,
        sessions: [previewSession],
        blocks: [previewBlock],
        activities: previewActivities
    )
    .padding()
}
