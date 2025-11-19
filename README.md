# TimeVibe

一个原生 macOS 时间跟踪应用，使用 SwiftUI 和 SwiftData 构建。类似 Timing.app，自动追踪应用使用情况，管理分层项目，并提供专注工作会话的计时器功能。

## ✨ 主要功能

- **自动活动追踪** - 自动记录应用使用时间和切换事件
- **分层项目管理** - 支持项目和子项目的层级结构
- **时间条目管理** - 手动添加或通过计时器生成时间条目
- **交互式时间线** - 可视化展示应用使用、项目状态和时间分配
- **规则引擎** - 基于规则自动分配活动到项目
- **统计报告** - 详细的时间统计和生产力分析

## 🚀 快速开始

### 环境要求

- macOS 15.0+
- Xcode 26+
- Swift 6+

### 构建和运行

```bash
# 在 Xcode 中打开项目
open time.xcodeproj

# 或使用命令行构建
xcodebuild -project time.xcodeproj -scheme time -configuration Debug build
```
 
 

## 🏗️ 核心架构

### 数据模型

- **Project** - 分层项目结构，支持颜色编码
- **Activity** - 应用使用追踪记录
- **TimeEntry** - 工作时间段，关联到项目,同时也能关联到Activity

 

## 🔧 开发

### 代码风格

- 使用 SwiftUI 和 SwiftData 最佳实践
- 遵循 Swift API 设计指南
- 所有视图支持 `#Preview` 预览
- 使用 swiftformat 格式化代码
 
 

 
