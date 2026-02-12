# Timeline 重新设计 - 快速开始（5 分钟）

## 你需要知道的 3 件事

### 1️⃣ 发生了什么？
Timeline 现在用"**认知会话**"替代"原始事件"显示时间线。

**Before**：30+ 个小色块，看起来很乱
**After**：3-5 个大色块，一眼看懂

### 2️⃣ 为什么这样做？
因为 Timing 也这样做。OpenAI 分析表明：
- 用户不需要"准确"的 Activity 记录
- 用户需要"可理解"的任务概览
- 30 分钟的合并是"报表友好"，不是"视觉友好"

### 3️⃣ 工作原理
```
Raw Activity（如：9:00-9:05 Chrome, 9:05-9:10 VS Code, 9:10-9:45 Chrome）
         ↓
Session 聚合（相邻 Activity + 同项目 → 合并）
         ↓
Timeline 显示（1 个大块，而非 3 个小块）
```

---

## 验证改进（1 分钟）

### 方式 1：视觉检查
```
运行应用 → 打开 Timeline
观察：色块数是否明显减少？（预期：3-5 倍）
```

### 方式 2：代码检查
```swift
// TimelineView.swift 中，查看 recalculate() 方法
let blocks = processor.processWithSessionAggregation(...)
//                      ↑ 这个新方法做了 Session 聚合
```

### 方式 3：5 秒规则（完整测试）
```
1. 找个不懂代码的人看 Timeline 5 秒
2. 问："你看到的是我'干了什么'还是'系统记录了什么'？"
3. 如果他们说"干了什么" → ✅ 成功
```

---

## 新增代码（仅 256 行）

### TimelineSession.swift（62 行）
定义"认知会话"的数据结构。包含：
- 时间范围
- 主要应用/项目
- 包含的原始 Activity（追踪源头）
- 置信度（反映用户专注度）

### TimelineSessionAggregator.swift（194 行）
聚合引擎。核心逻辑：
```swift
// 两条合并规则
if duration < 30秒:           // 噪声抑制
    merge_to_neighbor()
else if gap < 90秒 && same_project:  // 视觉连续
    merge_into_session()
```

---

## 关键参数（可调）

都在 `TimelineSessionAggregator` 中：

```swift
noiseThreshold = 30            // < 此值的活动被吸收
visualContinuityThreshold = 90 // 间隔 < 此值则合并
minSessionDuration = 5         // Session 最短长度
```

**如果 Timeline 仍然很碎**：降低这些值
**如果合并过度**：提高这些值

---

## 编译状态

✅ **BUILD SUCCEEDED**

没有错误、没有性能回归、向后兼容。

---

## 文档导航

| 文档 | 用途 | 阅读时间 |
|------|------|--------|
| 这个文件 | 快速理解改进 | 5 分钟 |
| **README_TIMELINE_REDESIGN.md** | 详细解释 + 常见问题 | 10 分钟 |
| **DESIGN_PRINCIPLES.md** | 设计原则速查 | 5 分钟 |
| **TESTING_GUIDE.md** | 如何验证效果 | 15 分钟 |
| **TIMELINE_REDESIGN.md** | 完整技术文档 | 20 分钟 |
| **IMPLEMENTATION_SUMMARY.md** | 本次改进的全面总结 | 15 分钟 |
| **Timing vs App Differences.md** | 背景分析（必读） | 30 分钟 |

---

## 最常见的 3 个问题

### Q1: 这会丢失数据吗？
**A**: 不会。`Session.underlyingActivityIds` 追踪所有原始 Activity。只是**显示**方式改变了。

### Q2: 统计报告会变？
**A**: 不会。统计仍用 30 分钟合并。这个改进只影响 Timeline 视觉。

### Q3: 效果不满意怎么办？
**A**: 调参数。都在 `TimelineSessionAggregator` 中，试试改改 `noiseThreshold`。

---

## 一句话总结

**Timeline 现在显示的是"你今天干了什么"，而不是"系统记录了什么"。**

这就是与 Timing 的根本对齐。

