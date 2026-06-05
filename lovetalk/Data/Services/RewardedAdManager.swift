import Foundation
import GoogleMobileAds
import UIKit

// MARK: - Rewarded Ad Manager
/// AdMobリワード広告を管理するマネージャー
@MainActor
final class RewardedAdManager: NSObject, ObservableObject {
    static let shared = RewardedAdManager()

    // MARK: - Constants
    private let adUnitID = "ca-app-pub-9654811308679484/1746749677"

    // MARK: - Published Properties
    @Published private(set) var isAdLoaded = false
    @Published private(set) var isLoading = false
    @Published private(set) var showError = false
    @Published var errorMessage = ""

    // MARK: - Properties
    private var rewardedAd: RewardedAd?
    private var rewardCompletion: ((Bool) -> Void)?

    // MARK: - Initialization
    private override init() {
        super.init()
        loadAd()
    }

    // MARK: - Public Methods

    /// 広告を読み込む
    func loadAd() {
        guard !isLoading else { return }

        isLoading = true
        isAdLoaded = false

        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    print("Rewarded ad failed to load: \(error.localizedDescription)")
                    self.errorMessage = String(localized: "広告の読み込みに失敗しました", bundle: LanguageManager.appBundle)
                    self.showError = true
                    return
                }

                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdLoaded = true
                print("Rewarded ad loaded successfully")
            }
        }
    }

    /// 広告を表示する
    /// - Parameter completion: 広告視聴完了時のコールバック（成功時true）
    func showAd(completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            errorMessage = String(localized: "広告を準備中です", bundle: LanguageManager.appBundle)
            showError = true
            completion(false)
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = String(localized: "広告を表示できません", bundle: LanguageManager.appBundle)
            showError = true
            completion(false)
            return
        }

        // 最前面のView Controllerを取得
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        rewardCompletion = completion

        rewardedAd.present(from: topViewController) { [weak self] in
            // ユーザーが報酬を獲得
            guard let self = self else { return }

            let reward = rewardedAd.adReward
            print("User earned reward: \(reward.amount) \(reward.type)")

            // DailyLimitManagerにボーナスを追加
            DailyLimitManager.shared.addBonusAnalysis()

            self.rewardCompletion?(true)
            self.rewardCompletion = nil
        }
    }

    /// 広告が読み込まれているかチェック
    func checkAdAvailability() -> Bool {
        if !isAdLoaded && !isLoading {
            loadAd()
        }
        return isAdLoaded
    }
}

// MARK: - FullScreenContentDelegate
extension RewardedAdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            // 広告が閉じられたら次の広告を読み込む
            self.rewardedAd = nil
            self.isAdLoaded = false
            self.loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("Rewarded ad failed to present: \(error.localizedDescription)")
            self.errorMessage = String(localized: "広告の表示に失敗しました", bundle: LanguageManager.appBundle)
            self.showError = true
            self.rewardCompletion?(false)
            self.rewardCompletion = nil
            self.loadAd()
        }
    }

    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Rewarded ad will present")
    }
}
