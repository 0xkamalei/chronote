# project spec

copy to CLAUDE.md/GEMINI.md/copilot-instructions.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native macOS time tracking application built with SwiftUI and SwiftData. like timing app. The app tracks application usage, manages hierarchical projects, and provides timer functionality for focused work sessions.

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project time-vscode.xcodeproj -scheme time-vscode -configuration Debug build

# Build for release
xcodebuild -project time-vscode.xcodeproj -scheme time-vscode -configuration Release build

# Open in Xcode
open time-vscode.xcodeproj
```

### Common Development Tasks
- Use Xcode's built-in simulator to test the app
- The app targets macOS with minimum deployment target defined in project settings
- SwiftUI previews are available for most views using `#Preview`

## Architecture

### Code style

- 使用最新版本swiftUI，swiftData的最佳实践

### Features

- project
  - project支持hierarchy，可以给project添加sub project
  - 在创建project，“new time entiry","start timer"时都可以快捷添加subproject
  - 在左侧sibebar展示project tree，并且可以通过拖动project改变project的显示顺序
  - 通过点击选中左侧project，就把当前project作为"All Activity"的查询筛选条件
  - project.title 是project下具体的一个事情；比如project是开发timing.app；project.title是编写PRD
  - "Unassigned" 这个代表 activity 没有通过time-entry被分配到project；可以选中Unassigned只筛选Unassigned的activity
  - "All Activities" 代表不通过project筛选；选中后在明细就要显示“Unassigned"在最上面
  - “My Projects" 等同于查询所有分配到projects的activity
  - 选中project 如果没有对应的activity，显示“No time traced"
  - 在sidebar 的 project 后尾要显示 这个project 对应的activity的时间总和 UI 见 @ui/siderbar-project.png.                                    
- Activity
  - activity 打开程序后自动记录，待实现中
  - activity 根据 application 切换事件 自动记录上一个app占用的时间
  - activity的展示结果，可以按照多种条件筛选，时间范围，project，
  - activity的明细展示，分为两列，一列是汇总，一列是分组展示；默认是groupby project,project.title,activity.title,
  - activity的展示逻辑是多层的折叠列表，project -> subproject 如果有的话 -> title(timeEntry中填写的) 对于unassigned的没有title -> 时间段 -> app 图表和名称 -> app.title 相同title的activities会聚合再一起-> Activities app使用明细开始时间~结束时间;具体可以查看UI @ui/main-layout.png
- timepicker
  - 通过timepicker 组件可以快速选择时间范围，只支持日期选择
  - 在使用快捷选择时间时，两个对应的日期选择也会实施计算变化，并且即时的被用来筛选数据
  - 具体UI @ui/timepicker.png
- time entry
  - 时间分配功能，将activity分配到对应的project or subproject
  - time line 功能
    - 此功能是app的核心，用来展示overview的app使用情况，project情况，以及project.title情况
    - 可以用来展示project，activity，同时也用来快速滑动选中时间范围，还可以用于快速添加time entry,具体UI @ui/timeline.png
    - time line 部分可以通过按住 cmd+鼠标滚轮 放大缩小
    - time line 一共分为三行；
    - timeline 第一行是当前设备activity，显示为应用图标，如果缩放的话显示为那段时间用时最多的app图标；鼠标悬浮在图标显示详细信息
    - timeline 第二行是project的色块
    - timeline 第三行是time entry,如果没有assign显示快捷按钮，点击pop up "New time entry",start-time end-time会自动添入
- background 后台
  - 通过 `didActivateApplicationNotification` 获取app激活通知
  - 激活后调用 `ActivityManager.trackAppSwitch` 代码示例：
    ```
    NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
        print("Event didActivateApplicationNotification")
        // 在这里执行你的回调操作
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            //print("当前激活的应用: \(app.localizedName ?? "未知")")
            print(app.bundleIdentifier ?? "-")
            Task {
                @MainActor in
                ActivityManager.shared.trackAppSwitch(newApp:  app.bundleIdentifier ?? "-", modelContext: modelContext)
            }
        }
    }

     NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
        print("Event willSleepNotification")
        Task {
            @MainActor in
            ActivityManager.shared.stopTrack(modelContext: modelContext)
        }
    }
    ```
  - 
### APP tracing 的实现逻辑

监听 `didActivateApplicationNotification` ，`willSleepNotification` 事件，通过ActivityManager维护一个状态，如果切换了app，就保存上一个app的activity。
如果 系统 sleep了就直接保存现在的app状态。

要能获取到app的icon用于回显的时候使用。

### activity 统计逻辑
根据每个 activity 的结束时间减去开始时间计算duration，合并duration就是使用时间。可以根据分组分别统计每个分组的时间。比如如果按照project分组，就可以按照duration计算每个project的总时间。

### State Management
- **AppState**: Central `ObservableObject` managing global application state
  - Project hierarchy with parent/child relationships
  - Timer state and active tracking
  - Project reordering through index-based system
- Projects are managed in-memory with plans for SwiftData integration

### Data Models
- **Project**: Hierarchical project structure with color coding, custom encoding/decoding for Color persistence
- **Activity**: Represents app usage tracking with duration and system icons and app id
- **TimeEntry** 对应一个project下的工作周期，由用户通过按钮开始记录和结束记录；也可根据配置由系统待机时停止记录

### View Architecture
- **NavigationSplitView**: Main layout with sidebar and detail views
- **SidebarView**: Project navigation with expandable/collapsible sections
- **Modular Views**: Separate views for editing projects, time entries, and timer controls
- **Sheet Presentations**: Modal dialogs for adding projects and time entries



### Key Files
- `AppState.swift`: Central state management and project hierarchy logic
- `Models/Project.swift`: Project model with color encoding and hierarchy support
- `Views/SidebarView.swift`: Project navigation and selection
- `ContentView.swift`: Main application layout and sheet coordination

## Development Notes

### Project Management
- use git commit save all changes before update files
- Mock data currently used for development and testing

### State Flow
- AppState serves as single source of truth for project data
- Published properties automatically update SwiftUI views
- Timer state managed centrally for consistency across views
- Sheet presentation state managed in ContentView for modal coordination

### UI Patterns
- Color-coded projects for visual organization
- Disclosure groups for expandable project hierarchies
- NavigationLink and selection binding for sidebar navigation