import Foundation
import Testing
@testable import time

struct ActivityDataProcessorTests {
    // Helper to build an activity quickly
    private func makeActivity(start: Date, end: Date, appName: String = "App", bundleId: String = "com.example.App", title: String? = nil) -> Activity {
        Activity(appName: appName,
                 appBundleId: bundleId,
                 appTitle: title,
                 duration: end.timeIntervalSince(start),
                 startTime: start,
                 endTime: end,
                 icon: "")
    }

    @Test("matches single activity to single overlapping time entry, prefers max overlap")
    func matchSingleActivityToSingleTimeEntry() throws {
        let base = Date()
        let activity = makeActivity(start: base.addingTimeInterval(60), end: base.addingTimeInterval(60 * 10))

        let entry = TimeEntry(projectId: "p1",
                              title: "Work",
                              startTime: base,
                              endTime: base.addingTimeInterval(60 * 30))

        let matches = ActivityDataProcessor.matchActivitiesToTimeEntries([activity], [entry])
        #expect(matches.count == 1)
        let activityMatches = matches[activity.id]
        #expect(activityMatches != nil)
        #expect(activityMatches!.count == 1)
        // Full activity duration should overlap here
        let expected = activity.endTime!.timeIntervalSince(activity.startTime)
        #expect(abs(activityMatches!.first!.overlapDuration - expected) < 0.001)
        #expect(activityMatches!.first!.timeEntry.id == entry.id)
    }

    @Test("multiple entries: ensure best match sorted first by overlap duration")
    func bestMatchOrdering() throws {
        let base = Date()
        let activity = makeActivity(start: base.addingTimeInterval(300), // 5m
                                    end: base.addingTimeInterval(900)) // 15m

        // Overlap windows: entry1 overlaps 10m, entry2 overlaps 5m
        let entry1 = TimeEntry(projectId: "p1", title: "Deep Work",
                               startTime: base.addingTimeInterval(240), // 4m
                               endTime: base.addingTimeInterval(1200)) // 20m
        let entry2 = TimeEntry(projectId: "p1", title: "Shallow Work",
                               startTime: base.addingTimeInterval(0),
                               endTime: base.addingTimeInterval(600)) // first 10m

        let matches = ActivityDataProcessor.matchActivitiesToTimeEntries([activity], [entry1, entry2])
        let activityMatches = matches[activity.id]
        #expect(activityMatches != nil)
        #expect(activityMatches!.count == 2)
        // entry1 should have larger overlap and appear first
        #expect(activityMatches!.first!.timeEntry.id == entry1.id)
        #expect(activityMatches!.first!.overlapDuration > activityMatches!.last!.overlapDuration)
    }

    @Test("no overlap should yield empty matches for that activity")
    func noOverlap() throws {
        let base = Date()
        let activity = makeActivity(start: base.addingTimeInterval(0), end: base.addingTimeInterval(60))
        let entry = TimeEntry(projectId: "p1", title: "Later",
                              startTime: base.addingTimeInterval(120),
                              endTime: base.addingTimeInterval(180))

        let matches = ActivityDataProcessor.matchActivitiesToTimeEntries([activity], [entry])
        #expect(matches[activity.id] == nil)
        #expect(matches.isEmpty)
    }

    @Test("ongoing activity (nil endTime) should be ignored")
    func ongoingActivityIgnored() throws {
        let base = Date()
        let ongoing = Activity(appName: "App", appBundleId: "com.example.App", appTitle: nil, duration: 0, startTime: base, endTime: nil, icon: "")
        let entry = TimeEntry(projectId: "p1", title: "Now",
                              startTime: base.addingTimeInterval(-300),
                              endTime: base.addingTimeInterval(300))

        let matches = ActivityDataProcessor.matchActivitiesToTimeEntries([ongoing], [entry])
        #expect(matches.isEmpty)
    }

    @Test("edge-touching intervals (end == start) count as no overlap")
    func edgeTouchingNoOverlap() throws {
        let base = Date()
        let activity = makeActivity(start: base, end: base.addingTimeInterval(60))
        // entry starts exactly when activity ends
        let entry = TimeEntry(projectId: "p1", title: "After",
                              startTime: base.addingTimeInterval(60),
                              endTime: base.addingTimeInterval(120))

        let matches = ActivityDataProcessor.matchActivitiesToTimeEntries([activity], [entry])
        #expect(matches.isEmpty)
    }
}
