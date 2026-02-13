import AppKit
import CoreGraphics
import Foundation
import os

@MainActor
class IdleMonitor: ObservableObject {
    static let shared = IdleMonitor()
    
    @Published var isIdle: Bool = false
    @Published var lastActivityTime: Date = Date()
    
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let checkInterval: TimeInterval = 10.0
    private let idleThreshold: TimeInterval = 300.0 // 5 minutes (configurable)
    
    private let logger = Logger(subsystem: "com.time.vscode", category: "IdleMonitor")
    
    private init() {}
    
    func startMonitoring() {
        if timer != nil { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdleStatus()
            }
        }
        
        // Listen for system wake to reset idle state
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemWake()
            }
        }
        
        logger.info("Idle monitoring started")
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
        
        logger.info("Idle monitoring stopped")
    }
    
    /// Reset idle state after system wake
    /// This prevents false idle detection due to sleep duration being counted as idle time
    private func handleSystemWake() {
        logger.info("System wake detected, resetting idle state")
        isIdle = false
        lastActivityTime = Date()
    }
    
    private func checkIdleStatus() {
        // CGEventSource.secondsSinceLastEventType needs to be robust
        // kCGAnyInputEventType is not exposed directly in Swift as such, use .any (if available) or raw value
        // CGEventSourceStateID.hidSystemState is correct
        
        // kCGAnyInputEventType is ~0
        let anyInput = CGEventType(rawValue: ~0)!
        
        let seconds = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: anyInput)
        
        if seconds > idleThreshold {
            if !isIdle {
                // Just became idle
                isIdle = true
                
                // The idle actually started 'seconds' ago
                let idleStart = Date().addingTimeInterval(-TimeInterval(seconds))
                self.lastActivityTime = idleStart
                
                self.logger.info("User became idle. Idle started at \(idleStart)")
                
                NotificationCenter.default.post(
                    name: .userDidBecomeIdle,
                    object: nil,
                    userInfo: ["idleStartTime": idleStart]
                )
            }
        } else {
            if isIdle {
                // Just became active
                isIdle = false
                let idleEnd = Date()
                
                self.logger.info("User became active. Idle duration: \(idleEnd.timeIntervalSince(self.lastActivityTime))s")
                
                NotificationCenter.default.post(
                    name: .userDidBecomeActive,
                    object: nil,
                    userInfo: [
                        "idleStartTime": self.lastActivityTime,
                        "idleEndTime": idleEnd
                    ]
                )
            }
        }
    }
}

extension NSNotification.Name {
    static let userDidBecomeIdle = NSNotification.Name("userDidBecomeIdle")
    static let userDidBecomeActive = NSNotification.Name("userDidBecomeActive")
}
