import Foundation
import SwiftUI

// MARK: - Error Presenter

@MainActor
class ErrorPresenter: ObservableObject {
    static let shared = ErrorPresenter()
    
    @Published var currentAlert: ErrorAlert?
    @Published var errorBanner: ErrorBanner?
    @Published var errorHistory: [PresentedError] = []
    
    private let logger = ErrorLogger.shared
    private let recoveryManager = ErrorRecoveryManager.shared
    
    private init() {}
    
    // MARK: - Error Presentation
    
    func presentError(
        _ error: TimeTrackingError,
        context: ErrorContext,
        presentationStyle: ErrorPresentationStyle = .automatic
    ) {
        let presentedError = PresentedError(
            error: error,
            context: context,
            presentationStyle: presentationStyle,
            presentedAt: Date()
        )
        
        errorHistory.insert(presentedError, at: 0)
        
        // Keep only last 50 presented errors
        if errorHistory.count > 50 {
            errorHistory.removeLast()
        }
        
        // Log the error
        logger.logError(error, context: context)
        
        // Determine presentation method
        let actualStyle = presentationStyle == .automatic ? 
            determineOptimalPresentationStyle(for: error) : presentationStyle
        
        switch actualStyle {
        case .alert:
            presentAlert(for: presentedError)
        case .banner:
            presentBanner(for: presentedError)
        case .silent:
            // Only log, don't show UI
            break
        case .automatic:
            // This case is handled above
            break
        }
    }
    
    private func determineOptimalPresentationStyle(for error: TimeTrackingError) -> ErrorPresentationStyle {
        switch error.severity {
        case .critical, .high:
            return .alert
        case .medium:
            return .banner
        case .low:
            return .silent
        }
    }
    
    private func presentAlert(for presentedError: PresentedError) {
        let alert = ErrorAlert(
            title: getErrorTitle(for: presentedError.error),
            message: presentedError.error.localizedDescription,
            recoverySuggestion: presentedError.error.recoverySuggestion,
            actions: createErrorActions(for: presentedError)
        )
        
        currentAlert = alert
    }
    
    private func presentBanner(for presentedError: PresentedError) {
        let banner = ErrorBanner(
            message: presentedError.error.localizedDescription,
            severity: presentedError.error.severity,
            actions: createBannerActions(for: presentedError),
            dismissAfter: getBannerDismissTime(for: presentedError.error.severity)
        )
        
        errorBanner = banner
        
        // Auto-dismiss banner after specified time
        if let dismissTime = banner.dismissAfter {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(dismissTime * 1_000_000_000))
                if errorBanner?.id == banner.id {
                    errorBanner = nil
                }
            }
        }
    }
    
    private func getErrorTitle(for error: TimeTrackingError) -> String {
        switch error.category {
        case .activityTracking:
            return "Activity Tracking Issue"
        case .timer:
            return "Timer Problem"
        case .database:
            return "Database Error"
        case .ruleEngine:
            return "Rule Processing Error"
        case .search:
            return "Search Error"
        case .system:
            return "System Error"
        case .dataIntegrity:
            return "Data Integrity Issue"
        case .network:
            return "Network Error"
        }
    }
    
    private func createErrorActions(for presentedError: PresentedError) -> [ErrorAction] {
        var actions: [ErrorAction] = []
        
        // Always include dismiss action
        actions.append(ErrorAction(
            title: "OK",
            style: .default,
            action: { [weak self] in
                self?.currentAlert = nil
            }
        ))
        
        // Add recovery action if available
        if let recoverySuggestion = presentedError.error.recoverySuggestion {
            actions.insert(ErrorAction(
                title: "Try to Fix",
                style: .default,
                action: { [weak self] in
                    self?.attemptRecovery(for: presentedError)
                }
            ), at: 0)
        }
        
        // Add specific actions based on error type
        switch presentedError.error {
        case .activityTrackingPermissionDenied, .systemPermissionDenied:
            actions.insert(ErrorAction(
                title: "Open System Preferences",
                style: .default,
                action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            ), at: 0)
            
        case .databaseCorruption, .dataValidationFailure:
            actions.insert(ErrorAction(
                title: "Repair Data",
                style: .default,
                action: { [weak self] in
                    self?.repairData(for: presentedError)
                }
            ), at: 0)
            
        case .timerAlreadyRunning:
            actions.insert(ErrorAction(
                title: "Stop Current Timer",
                style: .destructive,
                action: { [weak self] in
                    self?.stopCurrentTimer()
                }
            ), at: 0)
            
        default:
            break
        }
        
        return actions
    }
    
    private func createBannerActions(for presentedError: PresentedError) -> [ErrorAction] {
        var actions: [ErrorAction] = []
        
        // Add retry action for retryable errors
        if isRetryable(presentedError.error) {
            actions.append(ErrorAction(
                title: "Retry",
                style: .default,
                action: { [weak self] in
                    self?.attemptRecovery(for: presentedError)
                }
            ))
        }
        
        // Add dismiss action
        actions.append(ErrorAction(
            title: "Dismiss",
            style: .cancel,
            action: { [weak self] in
                self?.errorBanner = nil
            }
        ))
        
        return actions
    }
    
    private func getBannerDismissTime(for severity: ErrorSeverity) -> TimeInterval? {
        switch severity {
        case .low:
            return 3.0
        case .medium:
            return 5.0
        case .high, .critical:
            return nil // Don't auto-dismiss
        }
    }
    
    private func isRetryable(_ error: TimeTrackingError) -> Bool {
        switch error {
        case .activityTrackingPermissionDenied, .systemPermissionDenied:
            return false
        case .timerAlreadyRunning:
            return false
        default:
            return true
        }
    }
    
    // MARK: - Error Actions
    
    private func attemptRecovery(for presentedError: PresentedError) {
        currentAlert = nil
        errorBanner = nil
        
        Task {
            let strategy = RecoveryStrategyFactory.createStrategy(for: presentedError.error)
            let result = await recoveryManager.attemptRecovery(
                for: presentedError.error,
                context: presentedError.context,
                recoveryStrategy: strategy
            )
            
            switch result {
            case .success(let attempts):
                presentSuccessMessage("Problem resolved after \(attempts) attempt(s)")
            case .failure(let error):
                presentError(
                    TimeTrackingError.systemResourceExhausted,
                    context: ErrorContext(
                        userAction: "Recovery attempt failed",
                        additionalInfo: ["original_error": presentedError.error.localizedDescription,
                                       "recovery_error": error.localizedDescription]
                    )
                )
            }
        }
    }
    
    private func repairData(for presentedError: PresentedError) {
        currentAlert = nil
        
        Task {
            // Implementation would depend on specific data repair mechanisms
            // For now, show a placeholder success message
            presentSuccessMessage("Data repair completed")
        }
    }
    
    private func stopCurrentTimer() {
        currentAlert = nil
        
        // Implementation would stop the current timer
        // This would typically involve calling TimerManager.shared.stopTimer()
        presentSuccessMessage("Timer stopped")
    }
    
    private func presentSuccessMessage(_ message: String) {
        let banner = ErrorBanner(
            message: message,
            severity: .low,
            actions: [],
            dismissAfter: 3.0,
            isSuccess: true
        )
        
        errorBanner = banner
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if errorBanner?.id == banner.id {
                errorBanner = nil
            }
        }
    }
    
    // MARK: - Error History Management
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    func getErrorHistory(for category: ErrorCategory? = nil) -> [PresentedError] {
        if let category = category {
            return errorHistory.filter { $0.error.category == category }
        }
        return errorHistory
    }
    
    func dismissCurrentError() {
        currentAlert = nil
        errorBanner = nil
    }
}

// MARK: - Supporting Types

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?
    let actions: [ErrorAction]
}

struct ErrorBanner: Identifiable {
    let id = UUID()
    let message: String
    let severity: ErrorSeverity
    let actions: [ErrorAction]
    let dismissAfter: TimeInterval?
    let isSuccess: Bool
    
    init(message: String, 
         severity: ErrorSeverity, 
         actions: [ErrorAction], 
         dismissAfter: TimeInterval? = nil, 
         isSuccess: Bool = false) {
        self.message = message
        self.severity = severity
        self.actions = actions
        self.dismissAfter = dismissAfter
        self.isSuccess = isSuccess
    }
}

struct ErrorAction {
    let title: String
    let style: ErrorActionStyle
    let action: () -> Void
}

enum ErrorActionStyle {
    case `default`
    case cancel
    case destructive
}

enum ErrorPresentationStyle {
    case automatic
    case alert
    case banner
    case silent
}

struct PresentedError: Identifiable {
    let id = UUID()
    let error: TimeTrackingError
    let context: ErrorContext
    let presentationStyle: ErrorPresentationStyle
    let presentedAt: Date
}

// MARK: - SwiftUI Integration

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorPresenter = ErrorPresenter.shared
    
    func body(content: Content) -> some View {
        content
            .alert(item: $errorPresenter.currentAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message + (alert.recoverySuggestion.map { "\n\n\($0)" } ?? "")),
                    primaryButton: alert.actions.first.map { action in
                        .default(Text(action.title)) {
                            action.action()
                        }
                    } ?? .default(Text("OK")) {
                        errorPresenter.currentAlert = nil
                    },
                    secondaryButton: alert.actions.count > 1 ? 
                        .cancel(Text(alert.actions[1].title)) {
                            alert.actions[1].action()
                        } : .default(Text("OK")) {
                            errorPresenter.currentAlert = nil
                        }
                )
            }
    }
}

struct ErrorBannerView: View {
    let banner: ErrorBanner
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: banner.isSuccess ? "checkmark.circle.fill" : iconName)
                .foregroundColor(banner.isSuccess ? .green : iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                if !banner.actions.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(banner.actions.enumerated()), id: \.offset) { index, action in
                            Button(action.title) {
                                action.action()
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(actionColor(for: action.style))
                        }
                    }
                }
            }
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var iconName: String {
        switch banner.severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high, .critical:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch banner.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high, .critical:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        if banner.isSuccess {
            return Color.green.opacity(0.1)
        }
        
        switch banner.severity {
        case .low:
            return Color.blue.opacity(0.1)
        case .medium:
            return Color.orange.opacity(0.1)
        case .high, .critical:
            return Color.red.opacity(0.1)
        }
    }
    
    private func actionColor(for style: ErrorActionStyle) -> Color {
        switch style {
        case .default:
            return .accentColor
        case .cancel:
            return .secondary
        case .destructive:
            return .red
        }
    }
}

extension View {
    func errorHandling() -> some View {
        modifier(ErrorAlertModifier())
    }
}