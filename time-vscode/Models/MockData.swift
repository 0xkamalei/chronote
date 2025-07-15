import Foundation
import SwiftUI

struct MockData {
    static let activities = [
        Activity(
            appName: "Google Chrome",
            appBundleId: "com.google.Chrome",
            appTitle: "developer.apple.com",
            duration: 48 * 60,
            startTime: Date().addingTimeInterval(-3000),
            endTime: Date().addingTimeInterval(-120),
            icon: "globe"
        ),
        Activity(
            appName: "Microsoft Edge",
            appBundleId: "com.microsoft.edgemac",
            appTitle: "GitHub",
            duration: 18 * 60,
            startTime: Date().addingTimeInterval(-2000),
            endTime: Date().addingTimeInterval(-920),
            icon: "safari"
        ),
        Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            appTitle: "time-vscode.xcodeproj",
            duration: 17 * 60,
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date().addingTimeInterval(-780),
            icon: "hammer"
        ),
        Activity(
            appName: "Code",
            appBundleId: "com.microsoft.VSCode",
            appTitle: "ActivitiesView.swift",
            duration: 13 * 60,
            startTime: Date().addingTimeInterval(-1500),
            endTime: Date().addingTimeInterval(-720),
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        Activity(
            appName: "Folo",
            appBundleId: "com.folo.app",
            duration: 10 * 60,
            startTime: Date().addingTimeInterval(-1200),
            endTime: Date().addingTimeInterval(-600),
            icon: "f.cursive"
        ),
        Activity(
            appName: "WeChat",
            appBundleId: "com.tencent.xinWeChat",
            duration: 10 * 60,
            startTime: Date().addingTimeInterval(-1000),
            endTime: Date().addingTimeInterval(-400),
            icon: "message"
        ),
        Activity(
            appName: "Universal Control",
            appBundleId: "com.apple.UniversalControl",
            duration: 9 * 60,
            startTime: Date().addingTimeInterval(-900),
            endTime: Date().addingTimeInterval(-360),
            icon: "arrow.left.and.right"
        ),
        Activity(
            appName: "Telegram",
            appBundleId: "ru.keepcoder.Telegram",
            duration: 8 * 60,
            startTime: Date().addingTimeInterval(-800),
            endTime: Date().addingTimeInterval(-320),
            icon: "paperplane"
        ),
        Activity(
            appName: "Discord",
            appBundleId: "com.hnc.Discord",
            appTitle: "General",
            duration: 7 * 60,
            startTime: Date().addingTimeInterval(-700),
            endTime: Date().addingTimeInterval(-280),
            icon: "bubble.left.and.bubble.right"
        ),
        Activity(
            appName: "Slack",
            appBundleId: "com.tinyspeck.slackmacgap",
            duration: 4 * 60,
            startTime: Date().addingTimeInterval(-400),
            endTime: Date().addingTimeInterval(-160),
            icon: "number"
        ),
        Activity(
            appName: "Claude",
            appBundleId: "com.anthropic.claude",
            duration: 4 * 60,
            startTime: Date().addingTimeInterval(-300),
            endTime: Date().addingTimeInterval(-60),
            icon: "brain"
        ),
        Activity(
            appName: "Timing",
            appBundleId: "info.danieldrescher.timing",
            duration: 3 * 60,
            startTime: Date().addingTimeInterval(-200),
            endTime: Date().addingTimeInterval(-20),
            icon: "clock"
        ),
        Activity(
            appName: "Alex",
            appBundleId: "com.alex.app",
            duration: 3 * 60,
            startTime: Date().addingTimeInterval(-180),
            endTime: Date().addingTimeInterval(-0),
            icon: "person"
        ),
        Activity(
            appName: "Finder",
            appBundleId: "com.apple.finder",
            duration: 3 * 60,
            startTime: Date().addingTimeInterval(-160),
            endTime: Date().addingTimeInterval(-80),
            icon: "folder"
        ),
        Activity(
            appName: "Doubao",
            appBundleId: "com.doubao.app",
            duration: 1 * 60,
            startTime: Date().addingTimeInterval(-120),
            endTime: Date().addingTimeInterval(-60),
            icon: "d.circle"
        ),
        Activity(
            appName: "Calendar",
            appBundleId: "com.apple.iCal",
            duration: 1 * 60,
            startTime: Date().addingTimeInterval(-100),
            endTime: Date().addingTimeInterval(-40),
            icon: "calendar"
        ),
        Activity(
            appName: "GitHub Copilot for Xcode Extension",
            appBundleId: "com.github.copilot.xcode",
            duration: 1 * 60,
            startTime: Date().addingTimeInterval(-80),
            endTime: Date().addingTimeInterval(-20),
            icon: "brain.head.profile"
        ),
        Activity(
            appName: "time-vscode",
            appBundleId: "com.time.vscode",
            duration: 30,
            startTime: Date().addingTimeInterval(-60),
            endTime: Date().addingTimeInterval(-30),
            icon: "clock"
        ),
        Activity(
            appName: "App Store",
            appBundleId: "com.apple.AppStore",
            duration: 45,
            startTime: Date().addingTimeInterval(-45),
            endTime: Date().addingTimeInterval(-0),
            icon: "app.badge"
        ),
        Activity(
            appName: "Snipaste",
            appBundleId: "com.snipaste.snipaste",
            duration: 20,
            startTime: Date().addingTimeInterval(-20),
            endTime: Date().addingTimeInterval(-0),
            icon: "scissors"
        )
    ]
    
    static let projects = [
        Project(id: "workmagic", name: "workmagic", color: .red, sortOrder: 0),
        Project(id: "side_project", name: "side_project", color: .purple, sortOrder: 1),
        Project(id: "project1", name: "Project1", color: .green, sortOrder: 2),
        Project(id: "sub_project", name: "Sub Project", color: .orange, parentID: "workmagic", sortOrder: 0)
    ]
    
    static let timeEntries = [
        TimeEntry(
            projectId: "workmagic",
            title: "Code Review",
            notes: "Reviewing SwiftUI implementation",
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-5400)
        ),
        TimeEntry(
            projectId: "side_project",
            title: "UI Design",
            notes: "Working on timeline component",
            startTime: Date().addingTimeInterval(-5400),
            endTime: Date().addingTimeInterval(-3600)
        ),
        TimeEntry(
            projectId: "project1",
            title: "Bug Fixes",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-1800)
        ),
        TimeEntry(
            title: "Research",
            notes: "Learning SwiftData integration",
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date().addingTimeInterval(-900)
        )
    ]
}
