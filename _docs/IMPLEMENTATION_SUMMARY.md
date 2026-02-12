# Timeline 重新设计 - 实施总结

## 完成状态 ✅

基于 `Timing vs App Differences.md` 中 OpenAI 的深度分析，已成功重新设计 Timeline 的核心实现逻辑。

### 核心改变：从"直观映射原始数据"到"感知友好的认知会话"

---

## 关键文件变更

### 新增文件

#### 1. `TimelineSession.swift`
**用途**：定义认知会话的数据模型
```swift
struct TimelineSession {
    let id: UUID
    var startTime: Date
    var endTime: Date

    var primaryProjectId: String?
    var primaryAppBundleId: String
    var primaryAppName: String

    var confidence: Double = 1.0
    var underlyingActivityIds: [UUID]
    var activities: [TimelineSessionActivity] = []
    var containsNoise: Bool = false
}
```

**关键概念**：
- Session ≠ Activity：一个 Session 可能包含多个 Activity
- confidence：反映用户是否真的专注在这项任务上
- containsNoise：标记是否包含被抑制的噪声

#### 2. `TimelineSessionAggregator.swift`
**用途**：将原始 Activity 聚合为 Session（这是核心逻辑）

**聚合规则**（基于人类感知）：
```swift
// 噪声抑制：< 30 秒 → 合并
noiseThreshold: TimeInterval = 30

// 视觉连续性：同项目 + 间隔 < 90 秒 → 合并
visualContinuityThreshold: TimeInterval = 90

// 最小 Session 时长（避免 2 秒的"Session"）
minSessionDuration: TimeInterval = 5
```

**工作流程**：
1. 遍历已排序的 Activity
2. 对于每个 Activity，判断是否为"噪声"（< 30s）
3. 噪声活动被吸收到相邻 Session
4. 非噪声活动如果与当前 Session 间隔短（< 90s）且同项目/同应用，则合并
5. 否则开启新 Session

### 修改的文件

#### 1. `TimelineProcessor.swift`
**关键变化**：
- 新增 `processWithSessionAggregation()` 方法（推荐）
- 保留原有 `process()` 和 `processMerged()` 方法（兼容）
- 新方法流程：Activity → Session → RenderBlock

```swift
func processWithSessionAggregation(
    activities: [Activity],
    visibleTimeRange: ClosedRange<Date>,
    canvasWidth: CGFloat
) -> [TimelineRenderBlock] {
    // 1. 聚合 Activity → Session
    let sessions = sessionAggregator.aggregateSessions(from: activities)

    // 2. 渲染 Session（而非 Activity）
    // 结果：更少、更大的色块，看起来更连续
}
```

#### 2. `TimelineView.swift`
**关键变化**：
- 移除了过时的 `mergeEnabled` 和 `mergeIntervalMinutes` 存储
- `recalculate()` 方法现在直接使用 `processWithSessionAggregation()`
- 移除了统计合并的 UI 控制（不再需要）

```swift
private func recalculate(width: CGFloat) {
    // 直接使用新的会话聚合方法
    let blocks = processor.processWithSessionAggregation(
        activities: activities,
        visibleTimeRange: visibleTimeRange,
        canvasWidth: width
    )
    self.renderBlocks = blocks
}
```

---

## 视觉效果对比

### 原始方式（旧）
```
┌─┬─────┬──┬───┬──┬─┬──────┬────┬──┐
│A│ B B │C │D D│E │F│  G   │ H  │I │  ← 碎片化，很乱
└─┴─────┴──┴───┴──┴─┴──────┴────┴──┘
```

**问题**：
- 每个小色块都是一个 Activity
- 用户看到"系统记录了什么"，而不是"我在做什么"
- 视觉噪声：OS 行为（通知、切歌）被可视化

### 新方式（认知会话）
```
┌─────────────────────┬─────┬──────────┐
│      Session 1      │ Ses2│ Session3 │  ← 清晰，一目了然
│ (含A+B+part of C)   │     │          │
└─────────────────────┴─────┴──────────┘
```

**改进**：
- 相同项目/应用的 Activity 被合并
- < 30s 的活动被吸收（不单独显示）
- 用户一眼看到：今天的几个主要任务

---

## 参数对标

| 维度 | 旧方法（统计） | 新方法（感知） | 区别 |
|------|---|---|---|
| **目的** | 生成报告 | 改善视觉 | 不同用途 |
| **阈值** | 30 分钟 | 30 秒～90 秒 | 10 倍差异 |
| **参与者** | Stats/Reports | Timeline | 不相交 |
| **是否可见** | 用户看不到 | 立即可见 | 用户直接感受 |
| **启发** | 统计学 | 认知科学 | 根本不同 |

**关键洞察**：
- 30 分钟是"报表友好"的，不是"视觉友好"的
- 人类感知连续工作的窗口是 **30s～2 分钟**
- Timing 针对后者优化，而非前者

---

## 验证方法（5 秒规则）

从 OpenAI 分析推荐：

1. **找一个完全不懂代码的人**
2. **打开 Timeline，显示 5 秒，关闭**
3. **问**：
   > "你刚才看到的，是我'今天干了什么'，还是'系统记录了什么'？"

**预期**：用户说"干了什么"，而非"系统记录"。

**验证流程**：
```
Activity Timeline（旧）→ 用户困惑："这是啥？"
        ↓
Session Timeline（新）→ 用户明白："这是 3 个主要任务"
```

---

## 代码质量

✅ **编译状态**：SUCCESS（无错误）
✅ **类型安全**：所有类型检查通过
✅ **向后兼容**：旧方法保留，不强制迁移
✅ **架构清晰**：关注分离（聚合 ≠ 渲染）

---

## 下一步优化方向（可选）

### 1. 二层可视化
- Session 作为主块显示
- 点击展开显示底层 Activities

### 2. Confidence 编码
- 用色饱度/明度反映用户专注度
- 低 confidence Session 用灰色显示

### 3. 噪声可视化
- 可选显示被抑制的噪声
- 灰色小条 + tooltip：被吸收的活动

### 4. 时间戳标签
- Session 块上显示起止时间
- 悬停显示细节

### 5. 调参工具
- 通过设置调整 `noiseThreshold` 和 `visualContinuityThreshold`
- 用户可根据习惯微调

---

## 参数调优（如需要）

所有感知阈值在 `TimelineSessionAggregator` 中：

```swift
// 噪声阈值（试试 15～60s）
private let noiseThreshold: TimeInterval = 30

// 视觉连续性（试试 60～120s）
private let visualContinuityThreshold: TimeInterval = 90

// 最小 Session（试试 3～10s）
private let minSessionDuration: TimeInterval = 5
```

根据用户反馈调整。

---

## 关键引用

📄 **参考文档**：`Timing vs App Differences.md`

**核心论点摘录**：
> "Timing 并不是'画得更准'，而是'画得更有产品设计意识'。
> 它在 _数据语义重构、视觉编码、时间压缩、噪声抑制_ 四个层面都做了二次加工。"

> "30 分钟是'报表友好'的阈值，不是'视觉友好'的阈值。"

> "Timing 的竞争力不在'记录时间'，而在'替用户解释时间'。"

---

## 总结

这次重新设计的关键是**思维转变**：

- ❌ 不再问："Activity 是否准确被记录了？"
- ✅ 改为问："用户一眼能看懂这一天吗？"

Timeline 现在渲染的不是"系统事件日志"，而是"用户的认知会话"——这是与 Timing 视觉风格的根本对齐。

