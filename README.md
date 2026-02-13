# TimeTrace - 免费开源的 Mac 时间追踪工具

[English](#english) | [中文](#中文)

---

## 中文

### 🎯 解决什么问题？

作为自由职业者、远程工作者或需要精确计费的专业人士，你是否遇到过这些问题：

- **不知道时间都去哪了** - 一天结束后回顾，发现大量时间被无意识消耗
- **手动记录时间太麻烦** - 频繁切换应用记录时间打断工作心流
- **项目计费不准确** - 无法精确统计在每个客户项目上花费的时间
- **Timing App 订阅太贵** - 每年 $96+ 的订阅费用让人望而却步

### ✨ TimeTrace 是什么？

TimeTrace 是一款**完全免费、开源**的 macOS 时间追踪应用，作为 [Timing App](https://timingapp.com/) 的替代方案。它能够：

- 🔄 **自动追踪** - 后台静默记录每个应用的使用时间，无需手动操作
- 🏷️ **智能分类** - 根据窗口标题自动将活动归类到不同项目
- 📊 **可视化统计** - 清晰展示时间分布，了解工作效率
- 🔒 **隐私优先** - 所有数据本地存储，不上传云端
- 💰 **完全免费** - 无订阅、无内购、无广告

### 🛠️ 技术栈

- **SwiftUI** - 现代化原生 macOS 界面
- **SwiftData** - Apple 最新数据持久化框架
- **macOS 14+** - 支持最新系统特性

### 📦 安装

```bash
# 克隆仓库
git clone https://github.com/your-username/mac-time-trace.git

# 使用 Xcode 打开项目
open time.xcodeproj
```

### 🔐 权限说明

TimeTrace 需要以下系统权限才能正常工作：

- **辅助功能权限** - 用于读取窗口标题以实现智能分类

### 🤖 Agent CLI（独立可执行文件）

长期产品化方案使用独立 CLI 可执行文件 `chronote-cli`（不耦合 GUI 生命周期）。
打包后，CLI 会内置在：

```bash
chronote.app/Contents/Resources/chronote-cli
```

首次启动时 App 会提示是否将它安装到 `/usr/local/bin/chronote-cli`（类似 VS Code 的 PATH 提示）。

开发阶段可先构建：

```bash
./scripts/build-chronote-cli.sh
```

产物在：

```bash
build/cli-dist/chronote-cli
```

```bash
# 帮助
./build/cli-dist/chronote-cli help

# 当日汇总
./build/cli-dist/chronote-cli summary --date 2026-02-13 --pretty

# 活动明细
./build/cli-dist/chronote-cli activities --start 2026-02-13T00:00:00+08:00 --end 2026-02-14T00:00:00+08:00 --limit 300 --pretty

# 项目列表
./build/cli-dist/chronote-cli projects --pretty

# 手动 Event 列表
./build/cli-dist/chronote-cli events --limit 200 --pretty

# MCP stdio server
./build/cli-dist/chronote-cli mcp-stdio
```

MCP 客户端配置示例（本地路径按你的机器调整）：

```json
{
  "mcpServers": {
    "chronote": {
      "command": "/absolute/path/to/chronote-cli",
      "args": ["mcp-stdio"]
    }
  }
}
```

### 📄 许可证

MIT License - 自由使用、修改和分发

---

## English

### 🎯 What Problem Does It Solve?

As a freelancer, remote worker, or professional who needs accurate billing, have you faced these challenges:

- **Lost track of time** - End of day review reveals hours unconsciously wasted
- **Manual time tracking is tedious** - Constantly switching apps to log time breaks your flow
- **Inaccurate project billing** - Can't precisely track time spent on each client project
- **Timing App subscription is expensive** - $96+/year subscription cost is prohibitive

### ✨ What is TimeTrace?

TimeTrace is a **completely free, open-source** macOS time tracking application, serving as an alternative to [Timing App](https://timingapp.com/). It offers:

- 🔄 **Automatic Tracking** - Silently records app usage in the background, no manual input needed
- 🏷️ **Smart Classification** - Automatically categorizes activities into projects based on window titles
- 📊 **Visual Analytics** - Clear visualization of time distribution to understand productivity
- 🔒 **Privacy First** - All data stored locally, never uploaded to cloud
- 💰 **Completely Free** - No subscription, no in-app purchases, no ads

### 🛠️ Tech Stack

- **SwiftUI** - Modern native macOS interface
- **SwiftData** - Apple's latest data persistence framework
- **macOS 14+** - Supports latest system features

### 📦 Installation

```bash
# Clone the repository
git clone https://github.com/your-username/mac-time-trace.git

# Open project with Xcode
open time.xcodeproj
```

### 🔐 Permissions

TimeTrace requires the following system permissions to function properly:

- **Accessibility Permission** - Required to read window titles for smart classification

### 🤖 Agent CLI (Standalone Executable)

For long-term productization, use the standalone `chronote-cli` binary.
In packaged builds, it is embedded at:

```bash
chronote.app/Contents/Resources/chronote-cli
```

On first launch, the app prompts to install it into `/usr/local/bin/chronote-cli` (similar to VS Code PATH setup).

During development, build with:

```bash
./scripts/build-chronote-cli.sh
```

Output:

```bash
build/cli-dist/chronote-cli
```

```bash
# Help
./build/cli-dist/chronote-cli help

# Daily summary
./build/cli-dist/chronote-cli summary --date 2026-02-13 --pretty

# Activity records
./build/cli-dist/chronote-cli activities --start 2026-02-13T00:00:00+08:00 --end 2026-02-14T00:00:00+08:00 --limit 300 --pretty

# Projects
./build/cli-dist/chronote-cli projects --pretty

# Manual events
./build/cli-dist/chronote-cli events --limit 200 --pretty

# MCP stdio server
./build/cli-dist/chronote-cli mcp-stdio
```

MCP client config example (adjust local path):

```json
{
  "mcpServers": {
    "chronote": {
      "command": "/absolute/path/to/chronote-cli",
      "args": ["mcp-stdio"]
    }
  }
}
```

### 📄 License

MIT License - Free to use, modify, and distribute

---

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## ⭐ Star History

If this project helps you, please consider giving it a star!

---

**Keywords**: time tracking, productivity, macOS app, timing app alternative, free time tracker, automatic time tracking, freelancer tools, project time management, SwiftUI, open source
