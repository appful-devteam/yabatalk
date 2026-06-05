import Foundation
import GoogleMobileAds
import UIKit

// MARK: - App Open Ad Manager
/// AdMobアプリ起動広告を管理するマネージャー
@MainActor
final class AppOpenAdManager: NSObject, ObservableObject {
    static let shared = AppOpenAdManager()

    private var appOpenAd: AppOpenAd?
    private var isLoadingAd = false
    private var isShowingAd = false
    private var hasShownAd = false
    private var loadTime: Date?

    /// 広告の有効期限（4時間）
    private let adExpirationHours: TimeInterval = 4

    private override init() {
        super.init()
    }

    // MARK: - Load

    func loadAd() {
        guard !isLoadingAd else { return }
        isLoadingAd = true

        // StoreKit の entitlement 初回読込を待ってから課金判定する。
        // 起動直後は SubscriptionManager.isSubscribed がまだ false なので、
        // ここで待たないと課金ユーザーにも広告が表示されてしまう。
        Task { @MainActor [weak self] in
            await SubscriptionManager.shared.awaitInitialLoad()
            guard let self = self else { return }
            guard !SubscriptionManager.shared.isSubscribed else {
                self.isLoadingAd = false
                return
            }

            AppOpenAd.load(with: AdUnitID.appOpen, request: Request()) { [weak self] ad, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoadingAd = false

                    if let error = error {
                        print("[AppOpenAd] Failed to load: \(error.localizedDescription)")
                        return
                    }

                    self.appOpenAd = ad
                    self.appOpenAd?.fullScreenContentDelegate = self
                    self.loadTime = Date()
                    print("[AppOpenAd] Loaded successfully")

                    // 初回ロード完了時に自動表示
                    if !self.hasShownAd {
                        self.showAdIfAvailable()
                    }
                }
            }
        }
    }

    // MARK: - Show

    func showAdIfAvailable() {
        // 初回起動時のみ表示
        guard !hasShownAd else { return }
        // プレミアムユーザーは広告を表示しない
        guard !SubscriptionManager.shared.isSubscribed else { return }
        guard !isShowingAd else { return }
        guard let ad = appOpenAd, !isAdExpired() else {
            loadAd()
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        isShowingAd = true
        hasShownAd = true
        ad.present(from: topViewController)
    }

    // MARK: - Expiration Check

    private func isAdExpired() -> Bool {
        guard let loadTime = loadTime else { return true }
        return Date().timeIntervalSince(loadTime) > adExpirationHours * 3600
    }
}

// MARK: - FullScreenContentDelegate
extension AppOpenAdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.isShowingAd = false
            self.appOpenAd = nil
            self.loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[AppOpenAd] Failed to present: \(error.localizedDescription)")
            self.isShowingAd = false
            self.appOpenAd = nil
            self.loadAd()
        }
    }

    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[AppOpenAd] Will present")
    }
}
