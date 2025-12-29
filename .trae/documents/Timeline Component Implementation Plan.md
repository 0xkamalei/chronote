# Timeline Component Implementation Plan (Comprehensive)

## 1. Core Logic: TimelineProcessor & Algorithm

### Coordinate System & Mapping
- **Input**: `visibleTimeRange` (Start/End Date), `canvasWidth` (CGFloat).
- **Scale Factor**: `pixelsPerSecond = canvasWidth / totalSeconds`.
- **Mapping Function**:
  ```swift
  func xPosition(for date: Date) -> CGFloat {
      let timeOffset = date.timeIntervalSince(visibleTimeRange.start)
      return timeOffset * pixelsPerSecond
  }
  ```

### Level of Detail (LOD) & Coalescing Algorithm
**Constants**:
- `MERGE_THRESHOLD_PX`: **1.0 pt**. (Gaps smaller than this are visually closed).
- `MIN_DRAW_WIDTH_PX`: **2.0 pt**. (Minimum width to render a block).

**The Loop**:
1.  **Sort**: Ensure `activities` are sorted by `startTime` ascending.
2.  **Iterate**: Walk through the sorted list, maintaining a `pendingBlock`.
3.  **Merge Check**:
    For each `nextActivity`:
    - Calculate pixel gap: `gap = nextActivity.startX - pendingBlock.endX`.
    - **IF** `gap <= MERGE_THRESHOLD_PX` **AND** `nextActivity.appId == pendingBlock.appId`:
      - **MERGE**: Extend `pendingBlock.endTime` to `nextActivity.endTime`. Add `nextActivity` to `pendingBlock.underlyingActivities`.
    - **ELSE**:
      - **FINALIZE** `pendingBlock`: If `width < MIN_DRAW_WIDTH_PX`, clamp to 1px (ensure visibility). Append to `outputList`.
      - **START NEW** block with `nextActivity`.

---

## 2. Implementation Steps (Phase 1)

### Step 1: Define Data Models
- **File**: Create `time/Views/Timeline/TimelineRenderBlock.swift`
- **Content**:
  - `struct TimelineRenderBlock`: Contains `rect: CGRect`, `color: Color`, `appBundleId: String`, `icon: NSImage?`.
  - `struct TimelineState`: Holds the current zoom level and visible time range.

### Step 2: Implement the Processor
- **File**: Create `time/Views/Timeline/TimelineProcessor.swift`
- **Content**:
  - `class TimelineProcessor`:
    - `func process(activities: [Activity], range: ClosedRange<Date>, width: CGFloat) -> [TimelineRenderBlock]`
    - Implements the **LOD & Coalescing Algorithm** described above.
    - Includes an `NSImage` cache for app icons to avoid reloading them during render.

### Step 3: Implement the View (Canvas)
- **File**: Create `time/Views/Timeline/TimelineView.swift`
- **Content**:
  - Use `GeometryReader` to capture the available width.
  - Use `Canvas` to draw:
    1.  **Background Layer**: Light gray track background.
    2.  **Block Layer**: Iterate `renderBlocks` and call `context.fill()`.
    3.  **Icon Layer**: Draw `block.icon` if `block.rect.width > 20`.

### Step 4: Integration
- **File**: Modify `time/Views/ContentView.swift`
- **Action**:
  - Add a new section (or Tab) for "Timeline".
  - Instantiate `TimelineView` and pass the `activities` from the SwiftData query.
  - Add a simple `DatePicker` or `Slider` to control the `visibleTimeRange` (Zoom/Scroll) for testing.

---

## 3. Future Roadmap (Phase 2 & 3)

### Phase 2: Multi-Track & Layout Support
- **Project Track**:
  - Add a secondary row below App Activities.
  - Render blocks based on `Activity.project` using `Project.color`.
  - Reuse `TimelineProcessor` logic but group by Project ID instead of App Bundle ID.
- **Vertical Orientation**:
  - Implement an `AxisMapper` protocol to abstract coordinate mapping (X vs Y).
  - Add a Toggle button to switch between Horizontal (Timeline) and Vertical (Calendar-like) modes.

### Phase 3: Advanced Interaction
- **Drag Selection**:
  - Implement a drag gesture overlay to draw a semi-transparent selection box.
  - Filter the list of activities based on the selected time range.
- **Rich Tooltips**:
  - Implement a Hit-Test algorithm (Binary Search on `RenderBlocks`) to detect which block is under the mouse.
  - Show a floating Popover with detailed App Name, Duration, and Project info.
- **Context Actions**:
  - Right-click menu to "Assign to Project" or "Delete Activity".
