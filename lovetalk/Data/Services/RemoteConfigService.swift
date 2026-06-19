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
            Constants.RemoteConfigKeys.adsEnabled: false as NSObject,
            // AI プロバイダ情報。空 = 既定(Qwen / Alibaba Cloud Singapore)。
            Constants.RemoteConfigKeys.aiProvider: "" as NSObject
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

    /// 現在の AI データ送信先プロバイダ情報。
    /// Remote Config `ai_provider`(JSON) があればそれを、無ければ既定(Qwen / Alibaba Cloud Singapore)。
    /// Firebase Remote Config のローカルキャッシュ値を同期読みするため、UI から即時参照できる。
    var currentAIProvider: AIProviderInfo {
        let raw = remoteConfig[Constants.RemoteConfigKeys.aiProvider].stringValue
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let info = try? JSONDecoder().decode(AIProviderInfo.self, from: data) else {
            return .qwen
        }
        return info
    }
}

// MARK: - AI Provider Info（同意画面・開示文の単一ソース）

/// AI 機能のデータ送信先プロバイダ情報。同意画面・各開示文はここを参照して表示する。
/// 既定は Qwen(Alibaba Cloud Singapore / 国際版)。Remote Config `ai_provider` で上書きでき、
/// モデル/プロバイダを変更してもこの値を更新するだけで全開示文が追従する（アプリ再提出不要）。
struct AIProviderInfo: Codable, Equatable, Sendable {
    var serviceName: String     // 例: "Qwen API"
    var companyName: String     // 例: "Alibaba Cloud Singapore Pte. Ltd."（法人正式名）
    var companyShort: String    // 例: "Alibaba Cloud"（短縮表記）
    var region: String          // 例: "シンガポール"（データ処理地域）
    var endpoint: String        // 例: "dashscope-intl.aliyuncs.com"
    var termsURL: String
    var privacyURL: String

    static let qwen = AIProviderInfo(
        serviceName: "Qwen API",
        companyName: "Alibaba Cloud Singapore Pte. Ltd.",
        companyShort: "Alibaba Cloud",
        region: "シンガポール",
        endpoint: "dashscope-intl.aliyuncs.com",
        termsURL: "https://qwen.ai/termsservice",
        privacyURL: "https://www.alibabacloud.com/help/en/legal/latest/alibaba-cloud-international-website-privacy-policy"
    )
}
