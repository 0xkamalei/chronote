# Timeline 重新设计（基于 OpenAI 分析）

## 核心变化：从"数据可视化"到"感知可视化"

### 问题诊断

原始实现：
```
原始 Activity 记录
→ 按时间顺序
→ 一条记录 = 一段色块
→ 如实画出来
```

这导致：
- 高频切换 → 碎片化
- App 切换/窗口抖动 → 视觉噪声
- 用户困惑："我明明在做一件事，为什么像在随机游走？"

### 新方案：认知会话聚合（Cognitive Session Aggregation）

```
Raw Activities
→ Noise Suppression (< 30s → merge)
→ Session Inference (gap < 90s, same project → merge)
→ Visual Layout
```

这样的流程产生：
- 视觉连续性：用户感受到"专注做一件事"
- 噪声抑制：OS 行为（通知、快速切换）被降权
- 可解释性：用户一眼看懂这一天做了什么

## 关键参数

| 参数 | 含义 | 阈值 |
|------|------|------|
| noiseThreshold | 活动时长 < 此值 = 噪声 | **30 秒** |
| visualContinuityThreshold | 两个活动间隔 < 此值 + 同项目 = 合并 | **90 秒** |
| minSessionDuration | Session 最短时长 | **5 秒** |

### 与统计合并的区别

| 维度 | 统计合并（旧） | 认知合并（新） |
|------|----------------|-----------------|
| 目的 | 生成报告统计 | 改善视觉感受 |
| 阈值 | 30 分钟 | 30 秒 - 2 分钟 |
| 参与者 | Stats/Reports | Timeline 渲染 |
| 是否用户可见 | 不直接可见 | **立即可见** |

**关键洞察**：30 分钟是"报表友好"的阈值，不是"视觉友好"的阈值。

## 实现细节

### 1. TimelineSession（新数据模型）

```swift
struct TimelineSession {
    let id: UUID
    var startTime: Date
    var endTime: Date

    // 主要项目/应用
    var primaryProjectId: UUID?
    var primaryAppBundleId: String
    var primaryAppName: String

    // 用户专注度（0-1）
    var confidence: Double = 1.0

    // 底层所有 Activity
    var underlyingActivityIds: [UUID]

    // 明细活动（用于下钻）
    var activities: [TimelineSessionActivity] = []

    // 是否包含被抑制的噪声
    var containsNoise: Bool = false
}
```

### 2. TimelineSessionAggregator（聚合引擎）

```swift
class TimelineSessionAggregator {
    /// 将 Activity 聚合为认知 Session
    func aggregateSessions(from activities: [Activity]) -> [TimelineSession]
}
```

合并规则：
1. **噪声吞噬**：活动 < 30s，合并到相邻 Activity
2. **时间连续性**：同项目 + 间隔 < 90s → 合并
3. **语义连续性**：同应用 + 间隔 < 90s → 合并

### 3. TimelineProcessor（重构）

新增方法：
```swift
func processWithSessionAggregation(
    activities: [Activity],
    visibleTimeRange: ClosedRange<Date>,
    canvasWidth: CGFloat
) -> [TimelineRenderBlock]
```

渲染流程：
1. 调用 SessionAggregator 将 Activity → Session
2. 遍历 Session（而非 Activity）生成渲染块
3. 结果是"连续、清晰"而非"碎片化"

## 使用方式

### 原有代码

```swift
// 旧方式（已弃用）
if mergeEnabled {
    let interval = TimeInterval(mergeIntervalMinutes * 60)
    blocks = processor.processMerged(activities: activities, ...)
} else {
    blocks = processor.process(activities: activities, ...)
}
```

### 新方式

```swift
// 新方式（推荐）
let blocks = processor.processWithSessionAggregation(
    activities: activities,
    visibleTimeRange: visibleTimeRange,
    canvasWidth: width
)
```

TimelineView 已自动更新，使用新方式。

## 验证方法

### 5 秒规则（从 OpenAI 分析）

1. 找一个**完全不了解实现的人**
2. 打开 app，显示 timeline **5 秒**
3. 合上屏幕，问：
   > **"你刚才看到的，是我今天'干了什么'，还是'系统记录了什么'？"**

**预期**：用户应该说"干了什么"，而非"系统记录"。

### 对比验证

同一天数据，对比：
- **Activity timeline**（旧）：很多小色块，看起来乱
- **Session timeline**（新）：几个大色块，一目了然

差别应该是"立刻明显"的。

## 可调参数（如果需要进一步调优）

在 TimelineSessionAggregator 中：

```swift
private let noiseThreshold: TimeInterval = 30      // 试试 15-60s
private let visualContinuityThreshold: TimeInterval = 90  // 试试 60-120s
private let minSessionDuration: TimeInterval = 5    // 试试 3-10s
```

根据实际用户反馈调整。

## 下一步（可选）

1. **二层可视化**：Session 作为主视图，点击展开显示底层 Activities
2. **Confidence 编码**：用色饱度/明度反映用户专注度
3. **Noise 可视化**：可选显示被抑制的噪声（灰色小条）
4. **时间戳标签**：Session 块上显示起止时间

## 关键引用

参考文档：`Timing vs App Differences.md` - OpenAI 对两者差异的深入分析
