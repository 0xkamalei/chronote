import Foundation
import AppKit

protocol ContextMonitorDelegate: AnyObject {
    func didDetectContextChange(context: ActivityContext, startTime: Date)
}

class ContextMonitor {
    weak var delegate: ContextMonitorDelegate?
    
    // Configuration
    private let pollInterval: TimeInterval = 1.0
    private let stabilityThreshold: TimeInterval = 5.0
    
    // State
    private var timer: Timer?
    private var currentPid: pid_t?
    
    private var currentContext: ActivityContext?
    private var pendingContext: ActivityContext?
    private var pendingSince: Date?
    
    func startMonitoring(pid: pid_t, initialContext: ActivityContext?) {
        self.currentPid = pid
        self.currentContext = initialContext
        self.pendingContext = nil
        self.pendingSince = nil
        
        stopMonitoring()
        
        timer = Timer.scheduledTimer(timeInterval: pollInterval, target: self, selector: #selector(checkContext), userInfo: nil, repeats: true)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        pendingContext = nil
        pendingSince = nil
    }
    
    func updateCurrentPid(_ pid: pid_t) {
        if pid != currentPid {
            self.currentPid = pid
            pendingContext = nil
            pendingSince = nil
        }
    }
    
    @objc private func checkContext() {
        guard let pid = currentPid else { return }
        
        // 1. Fetch
        let freshContext = WindowMonitor.shared.getContext(for: pid)
        
        // 2. Compare with Current
        if freshContext == currentContext {
            // Stable state, reset pending
            pendingContext = nil
            pendingSince = nil
            return
        }
        
        // 3. Debounce Logic
        if freshContext == pendingContext {
            // Still in the new (different) state
            if let start = pendingSince, Date().timeIntervalSince(start) >= stabilityThreshold {
                // Threshold passed -> COMMIT
                currentContext = freshContext
                delegate?.didDetectContextChange(context: freshContext, startTime: start)
                
                // Reset pending
                pendingContext = nil
                pendingSince = nil
            }
        } else {
            // New potential change detected
            pendingContext = freshContext
            pendingSince = Date()
        }
    }
}
