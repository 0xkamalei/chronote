import SwiftUI
import UserNotifications

struct NotificationHistoryView: View {
    @ObservedObject var notificationManager: NotificationManager
    @State private var deliveredNotifications: [UNNotification] = []
    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("Notification Type", selection: $selectedTab) {
                Text("Delivered").tag(0)
                Text("Pending").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                // Delivered Notifications Tab
                DeliveredNotificationsView(notifications: deliveredNotifications)
                    .tag(0)
                
                // Pending Notifications Tab
                PendingNotificationsView(notifications: pendingNotifications)
                    .tag(1)
            }
            
            HStack {
                Button("Refresh") {
                    loadNotifications()
                }
                
                Spacer()
                
                Button("Clear All Delivered") {
                    notificationManager.clearDeliveredNotifications()
                    loadNotifications()
                }
                .disabled(deliveredNotifications.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Notification History")
        .onAppear {
            loadNotifications()
        }
    }
    
    private func loadNotifications() {
        Task {
            let delivered = await notificationManager.getDeliveredNotifications()
            let pending = await notificationManager.getPendingNotifications()
            
            await MainActor.run {
                self.deliveredNotifications = delivered
                self.pendingNotifications = pending
            }
        }
    }
}

// MARK: - Delivered Notifications View

struct DeliveredNotificationsView: View {
    let notifications: [UNNotification]
    
    var body: some View {
        List {
            if notifications.isEmpty {
                Text("No delivered notifications")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(notifications, id: \.request.identifier) { notification in
                    NotificationRowView(
                        title: notification.request.content.title,
                        messageBody: notification.request.content.body,
                        category: notification.request.content.categoryIdentifier,
                        date: notification.date,
                        userInfo: notification.request.content.userInfo
                    )
                }
            }
        }
    }
}

// MARK: - Pending Notifications View

struct PendingNotificationsView: View {
    let notifications: [UNNotificationRequest]
    
    var body: some View {
        List {
            if notifications.isEmpty {
                Text("No pending notifications")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(notifications, id: \.identifier) { request in
                    PendingNotificationRowView(request: request)
                }
            }
        }
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let title: String
    let messageBody: String
    let category: String
    let date: Date
    let userInfo: [AnyHashable: Any]
    
    private var categoryDisplayName: String {
        switch category {
        case "TIMER_COMPLETION":
            return "Timer"
        case "TIMER_INTERVAL":
            return "Timer Interval"
        case "TRACKING_STATUS":
            return "Tracking"
        case "PRODUCTIVITY_GOAL":
            return "Goal"
        case "INACTIVITY_REMINDER":
            return "Reminder"
        case "DAILY_SUMMARY":
            return "Daily Summary"
        case "WEEKLY_SUMMARY":
            return "Weekly Summary"
        default:
            return "Other"
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case "TIMER_COMPLETION", "TIMER_INTERVAL":
            return .blue
        case "TRACKING_STATUS":
            return .orange
        case "PRODUCTIVITY_GOAL":
            return .green
        case "INACTIVITY_REMINDER":
            return .yellow
        case "DAILY_SUMMARY", "WEEKLY_SUMMARY":
            return .purple
        default:
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text(categoryDisplayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.2))
                    .foregroundColor(categoryColor)
                    .cornerRadius(4)
            }
            
            Text(messageBody)
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let type = userInfo["type"] as? String {
                    Text("Type: \(type)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pending Notification Row View

struct PendingNotificationRowView: View {
    let request: UNNotificationRequest
    
    private var scheduledDate: Date? {
        if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        } else if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            return Date().addingTimeInterval(intervalTrigger.timeInterval)
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(request.content.title)
                    .font(.headline)
                
                Spacer()
                
                if let date = scheduledDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(request.content.body)
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Text("ID: \(request.identifier)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let type = request.content.userInfo["type"] as? String {
                    Text("Type: \(type)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        NotificationHistoryView(notificationManager: NotificationManager())
    }
    .frame(width: 600, height: 500)
}