import Foundation
import ServiceManagement
import Observation
import OSLog

@Observable
class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mac-time-trace", category: "LaunchAtLogin")
    
    var isEnabled: Bool {
        didSet {
            updateLaunchAtLogin(enabled: isEnabled)
        }
    }
    
    private init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    logger.info("Launch at login is already enabled")
                    return
                }
                try SMAppService.mainApp.register()
                logger.info("Successfully registered launch at login")
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    logger.info("Launch at login is already disabled")
                    return
                }
                try SMAppService.mainApp.unregister()
                logger.info("Successfully unregistered launch at login")
            }
        } catch {
            logger.error("Failed to update launch at login: \(error.localizedDescription)")
            // Reset isEnabled to actual status if it fails
            self.isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
    
    func refreshStatus() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
    }
}
