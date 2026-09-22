import Foundation
import UserNotifications

/// UNUserNotificationCenter delivery for BrowserCore.AlertEngine.
/// Local alerts only — no remote pushes, nothing leaves the Mac.
enum AlertDelivery {
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "browserdaddy.alert.\(UUID().uuidString)",
                content: content, trigger: nil)) { _ in }
    }
}
