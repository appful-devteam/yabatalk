import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    private override init() {
        super.init()
    }

    // MARK: - Configure on Launch

    func configureOnLaunch() {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    func syncAuthorizationStatus(requestIfNeeded: Bool = false) {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .notDetermined:
                if requestIfNeeded {
                    await requestPermission()
                }
            case .authorized, .provisional, .ephemeral:
                UserDefaults.standard.set(true, forKey: Constants.StorageKeys.pushPermissionGranted)
                registerForRemoteNotifications()
            case .denied:
                UserDefaults.standard.set(false, forKey: Constants.StorageKeys.pushPermissionGranted)
            @unknown default:
                break
            }
        }
    }

    private func requestPermission() async {
        let center = UNUserNotificationCenter.current()

        UserDefaults.standard.set(true, forKey: Constants.StorageKeys.pushPermissionRequested)

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            UserDefaults.standard.set(granted, forKey: Constants.StorageKeys.pushPermissionGranted)

            await MainActor.run {
                AnalyticsManager.shared.track("push_permission", properties: ["granted": granted])
            }

            if granted {
                registerForRemoteNotifications()
            }
        } catch {
            print("[PushNotificationManager] Permission request failed: \(error)")
        }
    }

    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Token Handling

    func handleRegisteredDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[PushNotificationManager] APNs token: \(token)")

        UserDefaults.standard.set(token, forKey: Constants.StorageKeys.apnsDeviceToken)

        // 実トークン値はプライバシー上 Analytics に送らず、更新イベントのみ記録
        Task { @MainActor in
            AnalyticsManager.shared.track("push_token_updated")
        }
    }

    func handleFailedRegistration(_ error: Error) {
        print("[PushNotificationManager] Failed to register for remote notifications: \(error)")
    }

    // MARK: - Pending Persona Chat Navigation
    @Published var pendingPersonaChatSessionId: UUID?

    // MARK: - Notification Open Handling

    func handleNotificationOpen(userInfo: [AnyHashable: Any]) {
        if let announcementId = userInfo["announcement_id"] as? String {
            AnnouncementManager.shared.handlePushAnnouncement(id: announcementId)
        }

        // ペルソナチャット通知からの遷移
        if let type = userInfo["type"] as? String, type == "persona_chat",
           let sessionIdStr = userInfo["sessionId"] as? String,
           let sessionId = UUID(uuidString: sessionIdStr) {
            pendingPersonaChatSessionId = sessionId
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: @preconcurrency UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            self.handleNotificationOpen(userInfo: userInfo)
        }

        completionHandler()
    }
}
