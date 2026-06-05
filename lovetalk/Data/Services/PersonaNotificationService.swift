import Foundation
import UserNotifications

// MARK: - Persona Notification Service
/// バックグラウンドで相手からのメッセージ通知をスケジュールするサービス
@MainActor
final class PersonaNotificationService {
    static let shared = PersonaNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let categoryIdentifier = "PERSONA_CHAT"

    private init() {}

    // MARK: - Schedule Next Message

    /// 次回のプロアクティブメッセージ通知をスケジュール
    func scheduleNextMessage(for chat: PersonaChat, delayRange: ClosedRange<TimeInterval>? = nil) {
        // 30分〜4時間のランダムな遅延
        let range = delayRange ?? (30 * 60)...(4 * 60 * 60)
        let delay = TimeInterval.random(in: range)

        let content = UNMutableNotificationContent()
        content.title = chat.partnerName
        content.body = String(localized: "新しいメッセージが届いています", bundle: LanguageManager.appBundle)
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "type": "persona_chat",
            "sessionId": chat.sessionId.uuidString,
            "chatId": chat.id.uuidString
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "persona_\(chat.sessionId.uuidString)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request)
    }

    // MARK: - Send Immediate Notification

    /// 返信が生成された時にすぐ通知を送る（画面を離れている場合）
    func sendImmediateNotification(for chat: PersonaChat, messageText: String) {
        let content = UNMutableNotificationContent()
        content.title = chat.partnerName
        content.body = String(messageText.prefix(100))
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "type": "persona_chat",
            "sessionId": chat.sessionId.uuidString,
            "chatId": chat.id.uuidString
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "persona_reply_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error {
                print("[PersonaNotification] Failed to add notification: \(error)")
            } else {
                print("[PersonaNotification] Notification scheduled for: \(chat.partnerName)")
            }
        }
    }

    // MARK: - Cancel Scheduled

    func cancelScheduledMessages(for sessionId: UUID) {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["persona_\(sessionId.uuidString)"]
        )
    }

    func cancelAllScheduledMessages() {
        notificationCenter.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("persona_") }
                .map(\.identifier)
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Permission

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
    }
}
