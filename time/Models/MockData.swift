import Foundation
import SwiftUI

enum MockData {
    static let activities = [
        Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            appTitle: "time-vscode.xcodeproj - ActivitiesView.swift",
            duration: 85 * 60,
            startTime: Date().addingTimeInterval(-14400),
            endTime: Date().addingTimeInterval(-9300),
            icon: "hammer",
            windowTitle: "time-vscode.xcodeproj - ActivitiesView.swift",
            documentPath: "/Users/developer/Projects/time-vscode/Views/Activities/ActivitiesView.swift"
        ),
        Activity(
            appName: "Xcode",
            appBundleId: "com.apple.dt.Xcode",
            appTitle: "time-vscode.xcodeproj - MockData.swift",
            duration: 42 * 60,
            startTime: Date().addingTimeInterval(-9000),
            endTime: Date().addingTimeInterval(-6480),
            icon: "hammer",
            windowTitle: "time-vscode.xcodeproj - MockData.swift",
            documentPath: "/Users/developer/Projects/time-vscode/Models/MockData.swift"
        ),
        Activity(
            appName: "Visual Studio Code",
            appBundleId: "com.microsoft.VSCode",
            appTitle: "~/Projects/time-vscode/Models/ActivityHierarchyGroup.swift",
            duration: 67 * 60,
            startTime: Date().addingTimeInterval(-13800),
            endTime: Date().addingTimeInterval(-9780),
            icon: "chevron.left.forwardslash.chevron.right",
            windowTitle: "ActivityHierarchyGroup.swift - time-vscode - Visual Studio Code",
            documentPath: "/Users/developer/Projects/time-vscode/Models/ActivityHierarchyGroup.swift"
        ),
        Activity(
            appName: "Visual Studio Code",
            appBundleId: "com.microsoft.VSCode",
            appTitle: "~/Projects/time-vscode/Views/Activities/ActivitiesView.swift",
            duration: 38 * 60,
            startTime: Date().addingTimeInterval(-8400),
            endTime: Date().addingTimeInterval(-6120),
            icon: "chevron.left.forwardslash.chevron.right",
            windowTitle: "ActivitiesView.swift - time-vscode - Visual Studio Code",
            documentPath: "/Users/developer/Projects/time-vscode/Views/Activities/ActivitiesView.swift"
        ),
        Activity(
            appName: "Visual Studio Code",
            appBundleId: "com.microsoft.VSCode",
            appTitle: "README.md",
            duration: 15 * 60,
            startTime: Date().addingTimeInterval(-5400),
            endTime: Date().addingTimeInterval(-4500),
            icon: "chevron.left.forwardslash.chevron.right",
            windowTitle: "README.md - time-vscode - Visual Studio Code",
            documentPath: "/Users/developer/Projects/time-vscode/README.md"
        ),

        Activity(
            appName: "Google Chrome",
            appBundleId: "com.google.Chrome",
            appTitle: "developer.apple.com/documentation/swiftui/hierarchical-views",
            duration: 52 * 60,
            startTime: Date().addingTimeInterval(-12600),
            endTime: Date().addingTimeInterval(-9480),
            icon: "globe",
            windowTitle: "Hierarchical Views | Apple Developer Documentation",
            url: "https://developer.apple.com/documentation/swiftui/hierarchical-views"
        ),
        Activity(
            appName: "Google Chrome",
            appBundleId: "com.google.Chrome",
            appTitle: "stackoverflow.com - SwiftUI List hierarchy implementation",
            duration: 28 * 60,
            startTime: Date().addingTimeInterval(-8100),
            endTime: Date().addingTimeInterval(-6420),
            icon: "globe",
            windowTitle: "SwiftUI List hierarchy implementation - Stack Overflow",
            url: "https://stackoverflow.com/questions/swiftui-list-hierarchy"
        ),
        Activity(
            appName: "Safari",
            appBundleId: "com.apple.Safari",
            appTitle: "github.com/user/time-vscode - Pull Request #42",
            duration: 35 * 60,
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-5100),
            icon: "safari",
            windowTitle: "Add hierarchical activity view by user · Pull Request #42",
            url: "https://github.com/user/time-vscode/pull/42"
        ),
        Activity(
            appName: "Microsoft Edge",
            appBundleId: "com.microsoft.edgemac",
            appTitle: "figma.com/design/activities-hierarchy-mockup",
            duration: 44 * 60,
            startTime: Date().addingTimeInterval(-10800),
            endTime: Date().addingTimeInterval(-8160),
            icon: "safari",
            windowTitle: "Activities Hierarchy Mockup - Figma",
            url: "https://figma.com/design/activities-hierarchy-mockup"
        ),

        Activity(
            appName: "Slack",
            appBundleId: "com.tinyspeck.slackmacgap",
            appTitle: "#development - Time tracking app discussion",
            duration: 18 * 60,
            startTime: Date().addingTimeInterval(-6300),
            endTime: Date().addingTimeInterval(-5220),
            icon: "number"
        ),
        Activity(
            appName: "Discord",
            appBundleId: "com.hnc.Discord",
            appTitle: "SwiftUI Developers - #general",
            duration: 22 * 60,
            startTime: Date().addingTimeInterval(-5700),
            endTime: Date().addingTimeInterval(-4380),
            icon: "bubble.left.and.bubble.right"
        ),
        Activity(
            appName: "Microsoft Teams",
            appBundleId: "com.microsoft.teams2",
            appTitle: "Project Standup Meeting",
            duration: 30 * 60,
            startTime: Date().addingTimeInterval(-10800),
            endTime: Date().addingTimeInterval(-9000),
            icon: "video"
        ),
        Activity(
            appName: "Telegram",
            appBundleId: "ru.keepcoder.Telegram",
            appTitle: "iOS Development Group",
            duration: 12 * 60,
            startTime: Date().addingTimeInterval(-4200),
            endTime: Date().addingTimeInterval(-3480),
            icon: "paperplane"
        ),

        Activity(
            appName: "Figma",
            appBundleId: "com.figma.Desktop",
            appTitle: "Time Tracker - Activities View Redesign",
            duration: 73 * 60,
            startTime: Date().addingTimeInterval(-11400),
            endTime: Date().addingTimeInterval(-7020),
            icon: "paintbrush"
        ),
        Activity(
            appName: "Sketch",
            appBundleId: "com.bohemiancoding.sketch3",
            appTitle: "Hierarchy Icons Design",
            duration: 26 * 60,
            startTime: Date().addingTimeInterval(-6600),
            endTime: Date().addingTimeInterval(-5040),
            icon: "pencil.and.outline"
        ),
        Activity(
            appName: "Notion",
            appBundleId: "notion.id",
            appTitle: "Activities View - Technical Specification",
            duration: 41 * 60,
            startTime: Date().addingTimeInterval(-9600),
            endTime: Date().addingTimeInterval(-7140),
            icon: "doc.text"
        ),

        Activity(
            appName: "iOS Simulator",
            appBundleId: "com.apple.iphonesimulator",
            appTitle: "iPhone 15 Pro - time-vscode",
            duration: 33 * 60,
            startTime: Date().addingTimeInterval(-4800),
            endTime: Date().addingTimeInterval(-2820),
            icon: "iphone"
        ),
        Activity(
            appName: "Instruments",
            appBundleId: "com.apple.dt.instruments",
            appTitle: "Time Profiler - time-vscode",
            duration: 19 * 60,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-2460),
            icon: "chart.line.uptrend.xyaxis"
        ),

        Activity(
            appName: "Terminal",
            appBundleId: "com.apple.Terminal",
            appTitle: "~/Projects/time-vscode - git operations",
            duration: 14 * 60,
            startTime: Date().addingTimeInterval(-3000),
            endTime: Date().addingTimeInterval(-2160),
            icon: "terminal"
        ),
        Activity(
            appName: "Finder",
            appBundleId: "com.apple.finder",
            appTitle: "~/Projects/time-vscode/Models",
            duration: 8 * 60,
            startTime: Date().addingTimeInterval(-2400),
            endTime: Date().addingTimeInterval(-1920),
            icon: "folder"
        ),
        Activity(
            appName: "Git Streaks",
            appBundleId: "com.gitstreaks.macos",
            appTitle: "time-vscode repository",
            duration: 5 * 60,
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date().addingTimeInterval(-1500),
            icon: "arrow.triangle.branch"
        ),

        Activity(
            appName: "Spotlight",
            appBundleId: "com.apple.Spotlight",
            duration: 45,
            startTime: Date().addingTimeInterval(-900),
            endTime: Date().addingTimeInterval(-855),
            icon: "magnifyingglass"
        ),
        Activity(
            appName: "System Preferences",
            appBundleId: "com.apple.systempreferences",
            appTitle: "Displays",
            duration: 2 * 60,
            startTime: Date().addingTimeInterval(-1200),
            endTime: Date().addingTimeInterval(-1080),
            icon: "gearshape"
        ),

        Activity(
            appName: "Calculator",
            appBundleId: "com.apple.calculator",
            duration: 3 * 60,
            startTime: Date().addingTimeInterval(-1500),
            endTime: Date().addingTimeInterval(-1320),
            icon: "plus.forwardslash.minus"
        ),
        Activity(
            appName: "Music",
            appBundleId: "com.apple.Music",
            duration: 120 * 60, // Background activity
            startTime: Date().addingTimeInterval(-14400),
            endTime: Date().addingTimeInterval(-7200),
            icon: "music.note"
        ),

        Activity(
            appName: "time-vscode",
            appBundleId: "com.time.vscode",
            appTitle: "Activities View Testing",
            duration: 25 * 60,
            startTime: Date().addingTimeInterval(-1500),
            endTime: Date().addingTimeInterval(0),
            icon: "clock"
        ),
    ]

    static let projects = [
        Project(id: "workmagic", name: "WorkMagic", color: .red, sortOrder: 0),
        Project(id: "side_project", name: "Side Projects", color: .purple, sortOrder: 1),
        Project(id: "client_work", name: "Client Work", color: .blue, sortOrder: 2),
        Project(id: "learning", name: "Learning & Research", color: .green, sortOrder: 3),
        Project(id: "personal", name: "Personal", color: .orange, sortOrder: 4),

        Project(id: "time_tracker", name: "Time Tracker App", color: .red, parentID: "workmagic", sortOrder: 0),
        Project(id: "activities_view", name: "Activities View", color: .pink, parentID: "time_tracker", sortOrder: 0),
        Project(id: "timeline_view", name: "Timeline View", color: .red, parentID: "time_tracker", sortOrder: 1),
        Project(id: "project_management", name: "Project Management", color: .red, parentID: "workmagic", sortOrder: 1),

        Project(id: "ios_experiments", name: "iOS Experiments", color: .purple, parentID: "side_project", sortOrder: 0),
        Project(id: "swiftui_components", name: "SwiftUI Components", color: .indigo, parentID: "ios_experiments", sortOrder: 0),
        Project(id: "web_portfolio", name: "Web Portfolio", color: .purple, parentID: "side_project", sortOrder: 1),

        Project(id: "client_a", name: "Client A - Mobile App", color: .blue, parentID: "client_work", sortOrder: 0),
        Project(id: "client_b", name: "Client B - Dashboard", color: .cyan, parentID: "client_work", sortOrder: 1),
        Project(id: "maintenance", name: "Maintenance Tasks", color: .blue, parentID: "client_work", sortOrder: 2),

        Project(id: "swiftui_learning", name: "SwiftUI Advanced", color: .green, parentID: "learning", sortOrder: 0),
        Project(id: "architecture_patterns", name: "Architecture Patterns", color: .mint, parentID: "learning", sortOrder: 1),
        Project(id: "performance_optimization", name: "Performance Optimization", color: .green, parentID: "learning", sortOrder: 2),

        Project(id: "health_fitness", name: "Health & Fitness", color: .orange, parentID: "personal", sortOrder: 0),
        Project(id: "home_automation", name: "Home Automation", color: .yellow, parentID: "personal", sortOrder: 1),
    ]

    static let timeEntries = [
        TimeEntry(
            projectId: "activities_view",
            title: "Implement hierarchical activity grouping",
            notes: "Working on the core logic for grouping activities by project, time period, and app",
            startTime: Date().addingTimeInterval(-14400),
            endTime: Date().addingTimeInterval(-12600)
        ),
        TimeEntry(
            projectId: "activities_view",
            title: "Design activity list UI components",
            notes: "Creating reusable SwiftUI components for the activity hierarchy display",
            startTime: Date().addingTimeInterval(-12600),
            endTime: Date().addingTimeInterval(-10800)
        ),
        TimeEntry(
            projectId: "activities_view",
            title: "Implement expand/collapse functionality",
            notes: "Adding interactive expand/collapse for hierarchy levels",
            startTime: Date().addingTimeInterval(-10800),
            endTime: Date().addingTimeInterval(-9000)
        ),
        TimeEntry(
            projectId: "activities_view",
            title: "Create comprehensive mock data",
            notes: "Building test data that covers all hierarchy scenarios and edge cases",
            startTime: Date().addingTimeInterval(-9000),
            endTime: Date().addingTimeInterval(-7200)
        ),
        TimeEntry(
            projectId: "activities_view",
            title: "Testing and debugging",
            notes: "Testing hierarchy display with various data scenarios",
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-5400)
        ),

        TimeEntry(
            projectId: "timeline_view",
            title: "Timeline visualization research",
            notes: "Researching best practices for timeline UI in time tracking apps",
            startTime: Date().addingTimeInterval(-5400),
            endTime: Date().addingTimeInterval(-4500)
        ),
        TimeEntry(
            projectId: "timeline_view",
            title: "Timeline component implementation",
            notes: "Building the core timeline visualization component",
            startTime: Date().addingTimeInterval(-4500),
            endTime: Date().addingTimeInterval(-3600)
        ),

        TimeEntry(
            projectId: "swiftui_learning",
            title: "Advanced List and OutlineGroup study",
            notes: "Learning about hierarchical data display in SwiftUI",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-2700)
        ),
        TimeEntry(
            projectId: "swiftui_learning",
            title: "State management patterns",
            notes: "Studying ObservableObject and StateObject patterns for complex UIs",
            startTime: Date().addingTimeInterval(-2700),
            endTime: Date().addingTimeInterval(-1800)
        ),

        TimeEntry(
            projectId: "client_a",
            title: "Mobile app bug fixes",
            notes: "Fixing critical issues in the iOS app",
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date().addingTimeInterval(-1200)
        ),
        TimeEntry(
            projectId: "client_b",
            title: "Dashboard performance optimization",
            notes: "Optimizing data loading and rendering performance",
            startTime: Date().addingTimeInterval(-1200),
            endTime: Date().addingTimeInterval(-600)
        ),

        TimeEntry(
            title: "General research and exploration",
            notes: "Exploring new iOS development techniques and tools",
            startTime: Date().addingTimeInterval(-600),
            endTime: Date().addingTimeInterval(-300)
        ),
        TimeEntry(
            title: "Code review and documentation",
            notes: "Reviewing code and updating project documentation",
            startTime: Date().addingTimeInterval(-300),
            endTime: Date().addingTimeInterval(0)
        ),

        TimeEntry(
            projectId: "swiftui_components",
            title: "Reusable component library",
            notes: "Building a library of reusable SwiftUI components",
            startTime: Date().addingTimeInterval(-8400),
            endTime: Date().addingTimeInterval(-7800)
        ),
        TimeEntry(
            projectId: "performance_optimization",
            title: "Memory usage analysis",
            notes: "Analyzing and optimizing memory usage in SwiftUI apps",
            startTime: Date().addingTimeInterval(-4800),
            endTime: Date().addingTimeInterval(-4200)
        ),

        TimeEntry(
            projectId: "maintenance",
            title: "Quick bug fix",
            notes: "Fixed a minor UI issue",
            startTime: Date().addingTimeInterval(-2400),
            endTime: Date().addingTimeInterval(-2280)
        ),

        TimeEntry(
            projectId: "health_fitness",
            title: "Fitness app planning",
            notes: "Planning features for a personal fitness tracking app",
            startTime: Date().addingTimeInterval(-3000),
            endTime: Date().addingTimeInterval(-2400)
        ),
        TimeEntry(
            projectId: "home_automation",
            title: "Smart home integration research",
            notes: "Researching HomeKit integration possibilities",
            startTime: Date().addingTimeInterval(-1500),
            endTime: Date().addingTimeInterval(-900)
        ),
    ]
}
