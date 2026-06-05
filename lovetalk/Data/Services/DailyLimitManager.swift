import Foundation

// MARK: - Daily Limit Manager
/// 1日の診断回数を管理するマネージャー
final class DailyLimitManager: ObservableObject {
    static let shared = DailyLimitManager()

    // MARK: - Constants
    private let maxFreeAnalysesPerDay = 3
    private let userDefaultsKey = "dailyAnalysisCount"
    private let lastResetDateKey = "lastAnalysisResetDate"
    private let bonusAnalysesKey = "bonusAnalysesCount"

    // MARK: - Published Properties
    @Published private(set) var todayAnalysisCount: Int = 0
    @Published private(set) var bonusAnalyses: Int = 0  // 広告視聴で追加された回数

    // MARK: - Properties
    private let userDefaults = UserDefaults.standard

    // MARK: - Computed Properties
    var remainingAnalyses: Int {
        max(0, maxFreeAnalysesPerDay + bonusAnalyses - todayAnalysisCount)
    }

    var hasReachedLimit: Bool {
        todayAnalysisCount >= (maxFreeAnalysesPerDay + bonusAnalyses)
    }

    var maxAnalyses: Int {
        maxFreeAnalysesPerDay + bonusAnalyses
    }

    /// 広告視聴でボーナスを追加できるかどうか
    var canWatchAdForBonus: Bool {
        hasReachedLimit
    }

    // MARK: - Initialization
    private init() {
        resetIfNewDay()
        loadTodayCount()
        loadBonusCount()
    }

    // MARK: - Public Methods

    /// 診断を記録
    func recordAnalysis() {
        resetIfNewDay()
        todayAnalysisCount += 1
        saveTodayCount()
    }

    /// 診断が可能かチェック（サブスク状態を考慮）
    func canAnalyze(isSubscribed: Bool) -> Bool {
        #if DEBUG
        return true
        #else
        if isSubscribed {
            return true
        }
        resetIfNewDay()
        return !hasReachedLimit
        #endif
    }

    /// 今日のカウントをリセット
    func resetTodayCount() {
        todayAnalysisCount = 0
        bonusAnalyses = 0
        saveTodayCount()
        saveBonusCount()
        saveLastResetDate()
    }

    /// 広告視聴でボーナス診断回数を追加
    func addBonusAnalysis() {
        bonusAnalyses += 1
        saveBonusCount()
    }

    // MARK: - Private Methods

    private func loadTodayCount() {
        todayAnalysisCount = userDefaults.integer(forKey: userDefaultsKey)
    }

    private func saveTodayCount() {
        userDefaults.set(todayAnalysisCount, forKey: userDefaultsKey)
    }

    private func loadBonusCount() {
        bonusAnalyses = userDefaults.integer(forKey: bonusAnalysesKey)
    }

    private func saveBonusCount() {
        userDefaults.set(bonusAnalyses, forKey: bonusAnalysesKey)
    }

    private func saveLastResetDate() {
        userDefaults.set(Date(), forKey: lastResetDateKey)
    }

    private func resetIfNewDay() {
        guard let lastResetDate = userDefaults.object(forKey: lastResetDateKey) as? Date else {
            // 初回起動時
            saveLastResetDate()
            return
        }

        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            // 新しい日になった
            todayAnalysisCount = 0
            bonusAnalyses = 0  // ボーナスもリセット
            saveTodayCount()
            saveBonusCount()
            saveLastResetDate()
        }
    }
}
