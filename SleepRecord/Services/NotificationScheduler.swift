import Foundation
import UserNotifications

@MainActor
struct NotificationScheduler {
    static let bedtimeReminderID = "sleep-record.bedtime-reminder"

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func scheduleBedtimeReminder(at hour: Int, minute: Int) async {
        guard await requestAuthorizationIfNeeded() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [bedtimeReminderID])

        let content = UNMutableNotificationContent()
        content.title = "そろそろお休みの時間です"
        content.body = "おやすみ前にタップを忘れずに 🌙"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: bedtimeReminderID,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func cancelBedtimeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [bedtimeReminderID]
        )
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
