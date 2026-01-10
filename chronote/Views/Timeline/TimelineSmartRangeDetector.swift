import Foundation

/// TimelineSmartRangeDetector 自动检测工作时间范围
/// 分析 Activity 数据，找到用户实际活跃的时间段，而不是显示整个 0-24 小时
class TimelineSmartRangeDetector {

    /// 检测活跃时间范围
    /// - Parameters:
    ///   - activities: 原始 Activity 数据
    ///   - buffer: 在检测到的范围前后添加的缓冲时间（秒），默认 10 分钟
    /// - Returns: 推荐的可见时间范围；如果无活动则返回整天范围
    static func detectActiveTimeRange(
        from activities: [Activity],
        buffer: TimeInterval = 10 * 60  // 默认 10 分钟缓冲
    ) -> ClosedRange<Date> {
        guard !activities.isEmpty else {
            // 如果没有活动，返回当天范围
            return Self.getTodayRange()
        }

        // 找最早的开始时间和最晚的结束时间
        var earliestStart: Date?
        var latestEnd: Date?

        for activity in activities {
            if earliestStart == nil || activity.startTime < earliestStart! {
                earliestStart = activity.startTime
            }

            let actEnd = activity.endTime ?? Date()
            if latestEnd == nil || actEnd > latestEnd! {
                latestEnd = actEnd
            }
        }

        guard let start = earliestStart, let end = latestEnd else {
            return Self.getTodayRange()
        }

        // 添加缓冲时间
        let bufferedStart = start.addingTimeInterval(-buffer)
        let bufferedEnd = end.addingTimeInterval(buffer)

        // 确保范围在今天内
        let todayStart = Calendar.current.startOfDay(for: start)
        let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? bufferedEnd

        let finalStart = max(bufferedStart, todayStart)
        let finalEnd = min(bufferedEnd, tomorrowStart)

        return finalStart ... finalEnd
    }

    /// 检测是否有"间隙"（无活动的时间段）
    /// 如果有较长的间隙，可能表示用户有多个工作时段
    /// - Parameters:
    ///   - activities: 原始 Activity 数据
    ///   - gapThreshold: 认为是"间隙"的最小时间长度（秒），默认 1 小时
    /// - Returns: 间隙列表，每个元素是 (gap_start, gap_end, gap_duration)
    static func detectGaps(
        from activities: [Activity],
        gapThreshold: TimeInterval = 3600  // 1 小时
    ) -> [(start: Date, end: Date, duration: TimeInterval)] {
        guard activities.count > 1 else { return [] }

        let sorted = activities.sorted { $0.startTime < $1.startTime }
        var gaps: [(start: Date, end: Date, duration: TimeInterval)] = []

        for i in 0 ..< sorted.count - 1 {
            let currentEnd = sorted[i].endTime ?? Date()
            let nextStart = sorted[i + 1].startTime

            let gapDuration = nextStart.timeIntervalSince(currentEnd)

            if gapDuration >= gapThreshold {
                gaps.append((start: currentEnd, end: nextStart, duration: gapDuration))
            }
        }

        return gaps
    }

    /// 获取当天的时间范围
    /// - Returns: 从今天 00:00 到 23:59:59
    private static func getTodayRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        return today ... tomorrow
    }

    /// 获取最活跃的时间段（最多 Activity 的时间段）
    /// - Parameters:
    ///   - activities: 原始 Activity 数据
    ///   - bucketSize: 时间桶大小（秒），默认 1 小时
    /// - Returns: 最活跃时间段的起始日期
    static func getMostActiveTimeBucket(
        from activities: [Activity],
        bucketSize: TimeInterval = 3600  // 1 小时
    ) -> Date? {
        guard !activities.isEmpty else { return nil }

        let calendar = Calendar.current
        var buckets: [Date: Int] = [:]

        for activity in activities {
            let dayStart = calendar.startOfDay(for: activity.startTime)
            let secondsSinceStart = activity.startTime.timeIntervalSince(dayStart)
            let bucketIndex = Int(secondsSinceStart / bucketSize)
            let bucketStart = dayStart.addingTimeInterval(Double(bucketIndex) * bucketSize)

            buckets[bucketStart, default: 0] += 1
        }

        return buckets.max(by: { $0.value < $1.value })?.key
    }
}
