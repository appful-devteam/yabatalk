import StoreKit
import UIKit

// MARK: - Review Manager
/// App Storeレビューリクエストを管理
enum ReviewManager {
    /// 最後にレビューリクエストした日からの最小間隔（日）
    private static let minimumDaysBetweenRequests = 14

    /// 2回目以降のリクエスト確率（5回に1回）
    private static let subsequentRequestProbability = 5

    /// 分析完了時にプレレビューを表示すべきか判定
    /// trueの場合、呼び出し側で「気に入りましたか？」ダイアログを表示する
    static func shouldShowPreReviewPrompt() -> Bool {
        let defaults = UserDefaults.standard
        let currentVersion = Constants.App.version

        // アップデート後はカウントをリセット
        let lastVersion = defaults.string(forKey: Constants.StorageKeys.reviewAppVersion)
        if lastVersion != currentVersion {
            defaults.set(0, forKey: Constants.StorageKeys.analysisCompletedCount)
            defaults.set(currentVersion, forKey: Constants.StorageKeys.reviewAppVersion)
        }

        let count = defaults.integer(forKey: Constants.StorageKeys.analysisCompletedCount) + 1
        defaults.set(count, forKey: Constants.StorageKeys.analysisCompletedCount)

        // 最後のリクエストから14日以上経過しているか確認
        if let lastRequestDate = defaults.object(forKey: Constants.StorageKeys.lastReviewRequestDate) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
            guard daysSinceLastRequest >= minimumDaysBetweenRequests else {
                return false
            }
        }

        if count == 1 {
            return true
        } else {
            return Int.random(in: 1...subsequentRequestProbability) == 1
        }
    }

    /// プレレビューで「はい」を選択した場合にApp Storeレビューを表示
    static func requestReview() {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: Constants.StorageKeys.lastReviewRequestDate)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                return
            }
            AppStore.requestReview(in: scene)
        }
    }

    /// プレレビューで「いいえ」を選択した場合もリクエスト日を記録（連続表示防止）
    static func recordPromptShown() {
        UserDefaults.standard.set(Date(), forKey: Constants.StorageKeys.lastReviewRequestDate)
    }
}
