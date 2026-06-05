import Foundation

// MARK: - Persona Chat Limit Manager
/// 擬人化チャットの1日あたりのメッセージ数を課金ステータスに応じて制限
@MainActor
final class PersonaChatLimitManager: ObservableObject {
    static let shared = PersonaChatLimitManager()

    // MARK: - Tier Limits
    private static let freeLimit = 5
    private static let premiumLimit = 30
    private static let premiumPlusLimit = 200

    // MARK: - Storage Keys
    private let countKey = "personaChatDailyCount"
    private let lastResetKey = "personaChatLastResetDate"

    // MARK: - Published
    @Published private(set) var todayMessageCount: Int = 0

    private let userDefaults = UserDefaults.standard

    private init() {
        resetIfNewDay()
        todayMessageCount = userDefaults.integer(forKey: countKey)
    }

    // MARK: - Limits

    /// 現在のTierに応じた1日の上限
    var dailyLimit: Int {
        switch SubscriptionManager.shared.currentTier {
        case .free: return Self.freeLimit
        case .premium: return Self.premiumLimit
        case .premiumPlus: return Self.premiumPlusLimit
        }
    }

    /// 残りメッセージ数
    var remainingMessages: Int {
        max(0, dailyLimit - todayMessageCount)
    }

    /// 制限に達しているか
    var hasReachedLimit: Bool {
        todayMessageCount >= dailyLimit
    }

    // MARK: - Public Methods

    /// メッセージ送信可能かチェック
    func canSendMessage() -> Bool {
        resetIfNewDay()
        return !hasReachedLimit
    }

    /// メッセージ送信を記録
    func recordMessage() {
        resetIfNewDay()
        todayMessageCount += 1
        userDefaults.set(todayMessageCount, forKey: countKey)
    }

    // MARK: - Private

    private func resetIfNewDay() {
        guard let lastReset = userDefaults.object(forKey: lastResetKey) as? Date else {
            userDefaults.set(Date(), forKey: lastResetKey)
            return
        }

        if !Calendar.current.isDateInToday(lastReset) {
            todayMessageCount = 0
            userDefaults.set(0, forKey: countKey)
            userDefaults.set(Date(), forKey: lastResetKey)
        }
    }
}
