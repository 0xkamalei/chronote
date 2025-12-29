# Architecture: Debounced Context Tracking with ContextMonitor

## 1. System Components

We will extract the polling and debouncing logic into a dedicated component to keep `ActivityManager` clean.

### A. ContextMonitor (New Component)

* **Role**: The "Heartbeat" of context tracking. It manages the Timer, polls the Window state, and filters noise.

* **Responsibilities**:

  1. **Periodic Polling**: Runs a `Timer` (1s interval).
  2. **Data Fetching**: Calls `WindowMonitor` to get raw Title/Path/URL.
  3. **Noise Filtering**: Implements the **5-second Debounce Logic**.
  4. **Notification**: Only notifies `ActivityManager` when a *stable* change is confirmed.

### B. WindowMonitor (Enhanced Sensor)

* **Role**: Stateless data fetcher.

* **New Method**: `getContext(pid: pid_t) -> ActivityContext`

  * Fetches `kAXTitle`, `kAXDocument` (Path), and `AXValue` (URL).

### C. ActivityManager (Coordinator)

* **Role**: Manages the `Activity` lifecycle and database.

* **Integration**:

  * On `ContextMonitor` Notification: Calls `trackAppSwitch` (Retroactive).

## 2. Detailed Logic: ContextMonitor

```swift
class ContextMonitor {
    // Configuration
    let pollInterval: TimeInterval = 1.0
    let stabilityThreshold: TimeInterval = 5.0
    
    // State
    private var currentContext: ActivityContext?
    private var pendingContext: ActivityContext?
    private var pendingSince: Date?
    
    // The Loop
    @objc func checkContext() {
        // 1. Fetch
        let freshContext = WindowMonitor.shared.getContext(currentPid)
        
        // 2. Compare
        if freshContext == currentContext {
            // Stable state, reset pending
            pendingContext = nil
            return
        }
        
        // 3. Debounce Logic
        if freshContext == pendingContext {
            // Still in the new (different) state
            if Date().timeIntervalSince(pendingSince) >= stabilityThreshold {
                // threshold passed -> COMMIT
                currentContext = freshContext
                delegate?.didDetectContextChange(freshContext, startTime: pendingSince)
                pendingContext = nil
            }
        } else {
            // New potential change detected
            pendingContext = freshContext
            pendingSince = Date()
        }
    }
}
```

## 3. Data Model

```swift
@Model final class Activity {
    var title: String?
    var filePath: String?
    var webUrl: String?
    var domain: String?
}
```

## 4. Execution Plan

1. **Model**: Update `Activity.swift`.
2. **WindowMonitor**: Implement AX fetching for Title/Path/URL.
3. **ContextMonitor**: Create the new class with the logic above.
4. **Integration**: Wire `ContextMonitor` into `ActivityManager`.

This design ensures modularity (`ContextMonitor` handles the "How", `ActivityManager` handles the "What") and robust noise filtering.
