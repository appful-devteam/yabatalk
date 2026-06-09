import Foundation
import FirebaseRemoteConfig

@MainActor
final class RemoteConfigService {
    static let shared = RemoteConfigService()

    private let remoteConfig: RemoteConfig
    private var lastFetchedAt: Date?
    private let minimumFetchInterval: TimeInterval = 5 * 60

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval
        remoteConfig.configSettings = settings

        remoteConfig.setDefaults([
            Constants.RemoteConfigKeys.inAppAnnouncements: "" as NSObject,
            Constants.RemoteConfigKeys.forceUpdateConfig: "" as NSObject,
            // 広告の ON/OFF。公開前デフォルトは false（広告なし）。公開後に Console で true に切替。
            Constants.RemoteConfigKeys.adsEnabled: false as NSObject
        ])
    }

    func string(forKey key: String) async -> String? {
        await fetchAndActivateIfNeeded()
        let value = remoteConfig[key].stringValue
        return value.isEmpty ? nil : value
    }

    private func fetchAndActivateIfNeeded() async {
        if let last = lastFetchedAt,
           Date().timeIntervalSince(last) < minimumFetchInterval {
            return
        }
        // fetch と activate を分離してエラー詳細をログ
        await withCheckedContinuation { continuation in
            remoteConfig.fetch(withExpirationDuration: 0) { [weak self] status, error in
                if let error = error {
                    print("[RemoteConfigService] fetch error: \(error.localizedDescription)")
                    print("[RemoteConfigService] fetch error full: \(error)")
                }
                print("[RemoteConfigService] fetch status: \(status.rawValue) (1=success, 2=throttled, 3=failure)")

                self?.remoteConfig.activate { changed, activateError in
                    if let activateError = activateError {
                        print("[RemoteConfigService] activate error: \(activateError.localizedDescription)")
                    }
                    print("[RemoteConfigService] activate changed: \(changed)")

                    let testValue = self?.remoteConfig[Constants.RemoteConfigKeys.inAppAnnouncements].stringValue ?? ""
                    print("[RemoteConfigService] in_app_announcements length: \(testValue.count)")

                    self?.lastFetchedAt = Date()
                    continuation.resume()
                }
            }
        }
    }
}
