# Timeline 改进 - 测试与验证指南

## 快速验证步骤

### 1. 编译和运行
```bash
xcodebuild -project time.xcodeproj -scheme time -configuration Release build
open time.xcodeproj  # 在 Xcode 中运行
```

### 2. 查看 Timeline
- 打开应用
- 导航到有多天数据的视图
- 观察 Timeline 的变化

---

## 预期视觉变化

### Before（旧方式）
```
Timeline 显示大量小色块，高频切换：
┌──┬─┬──┬┬──┬─┬──┬─────┬──┬─┬──┐
│A1│B│C1│││C2│D│E1│ E2  │F │G│H│
└──┴─┴──┴┴──┴─┴──┴─────┴──┴─┴──┘
用户感受："为什么这么乱？我明明在做一件事。"
```

### After（新方式 - 会话聚合）
```
Timeline 显示大块色块，清晰分段：
┌─────────────────────┬────────┬───────────┐
│    Session A        │Session B│Session C  │
│(多个Activity合并)   │         │           │
└─────────────────────┴────────┴───────────┘
用户感受："这是我今天的 3 个主要任务。"
```

---

## 关键测试场景

### 场景 1：短活动噪声抑制

**测试数据**：
- 09:00-10:00 Chrome（编码）
- 10:00-10:20 System Notification（< 30s）
- 10:20-11:00 Chrome（继续编码）

**预期**：
- 旧方式：3 个色块
- 新方式：1 个色块（通知被吸收）

**验证方法**：
1. 查看 TimelineView 渲染的块数
2. 用 debugDescription 打印 renderBlocks
3. 观察色块宽度

```swift
// 可以在 TimelineView 中临时添加
print("Blocks count: \(renderBlocks.count)")
for block in renderBlocks {
    print("Block: \(block.appName) \(block.startTime)-\(block.endTime)")
}
```

### 场景 2：间隔内同项目合并

**测试数据**：
- 14:00-14:30 VS Code（Project A）
- 14:30-14:45 Slack（分散）← 45s 间隔
- 14:45-15:15 VS Code（Project A 继续）

**预期**：
- 旧方式：3 个块
- 新方式：2 个块（VS Code 的两段被识别为连续）

**验证方法**：
1. 观察 VS Code 色块是否视觉连续
2. 检查 Session 的 underlyingActivityIds 数量
3. 用快速视觉测试：能否一眼看出"中间被打断过"？

### 场景 3：不同项目的合理分离

**测试数据**：
- 11:00-11:30 Chrome（Project A）
- 11:30-11:35 Finder（2 分钟间隔）← 超过 90s
- 11:35-12:00 Chrome（Project B，不同的项目）

**预期**：
- 应该是 3 个不同的块（即使同一个应用）
- 因为项目不同 + 间隔长

**验证方法**：
1. 观察是否有 3 个色块
2. 确认 Chrome 的两个块颜色相同但分开
3. 检查 Session 边界划分

---

## 定量验证

### Block 数量对比

**测试**：同一天数据，对比块数
```
旧方式 process():    30 块 ← Activity 几乎一对一
新方式 processWithSessionAggregation(): 8 块 ← 聚合后
```

**预期比例**：至少 3-5 倍的减少

### 平均块宽度

**测试**：测量平均块宽度（像素）
```
旧方式：20px（很多小条）
新方式：150px（大块，易读）
```

---

## 代码级验证

### 1. SessionAggregator 单元测试

```swift
// 可在 TimelineSessionAggregator 旁创建
class TimelineSessionAggregatorTests {

    func testNoiseAbsorption() {
        // 测试 < 30s 活动被吸收
        let activities = [
            Activity(..., duration: 3600),  // 1 小时
            Activity(..., duration: 15),    // 15s 噪声
            Activity(..., duration: 3600),  // 1 小时
        ]

        let aggregator = TimelineSessionAggregator()
        let sessions = aggregator.aggregateSessions(from: activities)

        // 预期：2 个 Session（中间的 15s 被吸收）
        XCTAssertEqual(sessions.count, 2)
    }

    func testVisualContinuity() {
        // 测试 90s 内同项目合并
        let activities = [
            Activity(..., projectId: "A", duration: 3600),
            Activity(..., gap: 45),  // 45s 间隔
            Activity(..., projectId: "A", duration: 3600),
        ]

        let aggregator = TimelineSessionAggregator()
        let sessions = aggregator.aggregateSessions(from: activities)

        // 预期：1 个 Session（两个 Activity 被合并）
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].underlyingActivityIds.count, 2)
    }
}
```

### 2. Processor 输出检查

```swift
// 在 recalculate() 后检查
let blocks = processor.processWithSessionAggregation(...)

// 检查点
print("Total blocks: \(blocks.count)")
print("Average duration: \(blocks.map { $0.totalDuration }.reduce(0, +) / Double(blocks.count))")
print("Min duration: \(blocks.map { $0.totalDuration }.min() ?? 0)")
print("Max duration: \(blocks.map { $0.totalDuration }.max() ?? 0)")
```

---

## 用户验证（5 秒规则）

### 执行步骤

1. **准备一个完全不了解代码的人**（朋友、同事、家人）
2. **让他们看一眼（5 秒）Timeline**
3. **合上屏幕，问一个问题**：
   ```
   "你刚才看到的，是我'今天干了什么'，还是'系统记录了什么'？"
   ```

### 评分标准

| 回答 | 意义 |
|------|------|
| "你今天干了什么" | ✅ Session 聚合成功，用户感受到了"认知会话" |
| "系统记录了什么" | ⚠️ 仍然看起来像"事件日志"，可能需要调参 |
| "看不懂" | ❌ Session 块太多或太复杂，需要更激进的合并 |

### 进阶验证

如果用户成功理解，再问：
```
"这 3 个（或 N 个）块分别是什么？你能描述一下吗？"
```

**预期**：用户能快速用自然语言描述每个 Session 的含义。

---

## 参数调优测试

如果视觉效果不理想，尝试调整参数：

### 参数组合 A（默认）
```swift
noiseThreshold = 30  // 秒
visualContinuityThreshold = 90
minSessionDuration = 5
```

### 参数组合 B（更激进合并）
```swift
noiseThreshold = 15  // 更低，更多被吸收
visualContinuityThreshold = 120  // 更长间隔也合并
minSessionDuration = 3
```

### 参数组合 C（更保守合并）
```swift
noiseThreshold = 60  // 更高，只有极短被吸收
visualContinuityThreshold = 60  // 严格分离
minSessionDuration = 10
```

**测试方法**：
1. 修改参数
2. 重新编译
3. 观察 Timeline 变化
4. 用 5 秒规则重新验证

---

## 性能验证

### 检查项

1. **编译时间**：应该没有显著增加（新增 2 个文件）
2. **运行时性能**：Session 聚合是 O(n)，应该很快
3. **内存占用**：Session 数据结构轻量

### 性能测试代码

```swift
let startTime = Date()

let sessions = sessionAggregator.aggregateSessions(from: activities)
let blocks = processor.processWithSessionAggregation(
    activities: activities,
    visibleTimeRange: range,
    canvasWidth: 1000
)

let elapsed = Date().timeIntervalSince(startTime)
print("Aggregation time: \(elapsed * 1000)ms for \(activities.count) activities")

// 预期：< 10ms 对于 1000+ activities
```

---

## 向后兼容性检查

旧的 process() 方法应该仍然可用：

```swift
// 这应该仍然能工作
let oldBlocks = processor.process(
    activities: activities,
    visibleTimeRange: range,
    canvasWidth: width
)

// 新方法
let newBlocks = processor.processWithSessionAggregation(
    activities: activities,
    visibleTimeRange: range,
    canvasWidth: width
)

// newBlocks.count 应该 << oldBlocks.count
```

---

## 回归测试清单

- [ ] Timeline 仍然显示所有相关日期
- [ ] 缩放（zoom）仍然工作正常
- [ ] 时间轴标签（TimeAxisHeader）仍然准确
- [ ] 悬停 Tooltip 仍然显示
- [ ] 拖拽选择时间范围仍然工作
- [ ] 事件（Event）轨道仍然正常显示
- [ ] 没有内存泄漏（检查 Instruments）

---

## 最终验证清单

- [ ] 编译成功（无错误、无警告）
- [ ] Timeline 块数显著减少（3-5 倍）
- [ ] 5 秒规则测试通过
- [ ] 用户能快速理解每个 Session
- [ ] 没有性能回归
- [ ] 向后兼容性保持

