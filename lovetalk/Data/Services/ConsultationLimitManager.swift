import Foundation

// MARK: - Consultation Limit Manager
/// 相談機能（めろまるチャット）の利用制限を管理
/// Free: 1セッション / 2ラリー (lifetime)
/// Premium: 3セッション / 10ラリー (日替わりリセット)
/// PremiumPlus: 無制限
@MainActor
final class ConsultationLimitManager: ObservableObject {
    static let shared = ConsultationLimitManager()

    // MARK: - Limits
    private enum Limits {
        // Free tier (lifetime)
        static let freeMaxSessions = 1
        static let freeMaxRallies = 2

        // Premium tier (daily)
        static let premiumMaxSessions = 3
        static let premiumMaxRallies = 10
    }

    // MARK: - UserDefaults Keys
    private enum Keys {
        // Free: lifetime tracking
        static let lifetimeSessions = "consultation_lifetime_sessions"
        static let lifetimeRallies = "consultation_lifetime_rallies"

        // Premium: daily tracking
        static let dailySessions = "consultation_daily_sessions"
        static let dailyRallies = "consultation_daily_rallies"
        static let lastResetDate = "consultation_last_reset_date"
    }

    // MARK: - Published Properties
    @Published private(set) var lifetimeSessions: Int = 0
    @Published private(set) var lifetimeRallies: Int = 0
    @Published private(set) var dailySessions: Int = 0
    @Published private(set) var dailyRallies: Int = 0

    private let userDefaults = UserDefaults.standard

    // MARK: - Init
    private init() {
        loadAll()
    }

    // MARK: - Public API

    func canStartSession(tier: SubscriptionTier) -> Bool {
        switch tier {
        case .premiumPlus: return true
        case .premium:
            resetIfNewDay()
            if dailySessions >= Limits.premiumMaxSessions {
                AnalyticsManager.shared.limitReached(
                    feature: .consultation, isSubscribed: true,
                    tier: tier.rawValue, usedCount: dailySessions
                )
                return false
            }
            return true
        case .free:
            if lifetimeSessions >= Limits.freeMaxSessions {
                AnalyticsManager.shared.limitReached(
                    feature: .consultation, isSubscribed: false,
                    tier: tier.rawValue, usedCount: lifetimeSessions
                )
                return false
            }
            return true
        }
    }

    func canSendRally(tier: SubscriptionTier) -> Bool {
        switch tier {
        case .premiumPlus: return true
        case .premium:
            resetIfNewDay()
            if dailyRallies >= Limits.premiumMaxRallies {
                AnalyticsManager.shared.limitReached(
                    feature: .consultation, isSubscribed: true,
                    tier: tier.rawValue, usedCount: dailyRallies
                )
                return false
            }
            return true
        case .free:
            if lifetimeRallies >= Limits.freeMaxRallies {
                AnalyticsManager.shared.limitReached(
                    feature: .consultation, isSubscribed: false,
                    tier: tier.rawValue, usedCount: lifetimeRallies
                )
                return false
            }
            return true
        }
    }

    func recordSessionStart(tier: SubscriptionTier) {
        switch tier {
        case .premiumPlus: break
        case .premium:
            resetIfNewDay()
            dailySessions += 1
            userDefaults.set(dailySessions, forKey: Keys.dailySessions)
        case .free:
            lifetimeSessions += 1
            userDefaults.set(lifetimeSessions, forKey: Keys.lifetimeSessions)
        }
    }

    func recordRally(tier: SubscriptionTier) {
        switch tier {
        case .premiumPlus: break
        case .premium:
            resetIfNewDay()
            dailyRallies += 1
            userDefaults.set(dailyRallies, forKey: Keys.dailyRallies)
        case .free:
            lifetimeRallies += 1
            userDefaults.set(lifetimeRallies, forKey: Keys.lifetimeRallies)
        }
    }

    func remainingSessions(tier: SubscriptionTier) -> Int? {
        switch tier {
        case .premiumPlus: return nil
        case .premium:
            resetIfNewDay()
            return max(0, Limits.premiumMaxSessions - dailySessions)
        case .free:
            return max(0, Limits.freeMaxSessions - lifetimeSessions)
        }
    }

    func remainingRallies(tier: SubscriptionTier) -> Int? {
        switch tier {
        case .premiumPlus: return nil
        case .premium:
            resetIfNewDay()
            return max(0, Limits.premiumMaxRallies - dailyRallies)
        case .free:
            return max(0, Limits.freeMaxRallies - lifetimeRallies)
        }
    }

    func maxSessions(tier: SubscriptionTier) -> Int? {
        switch tier {
        case .premiumPlus: return nil
        case .premium: return Limits.premiumMaxSessions
        case .free: return Limits.freeMaxSessions
        }
    }

    func maxRallies(tier: SubscriptionTier) -> Int? {
        switch tier {
        case .premiumPlus: return nil
        case .premium: return Limits.premiumMaxRallies
        case .free: return Limits.freeMaxRallies
        }
    }

    /// 制限に達した理由の説明テキスト
    func limitDescription(tier: SubscriptionTier) -> String {
        switch tier {
        case .premiumPlus:
            return ""
        case .premium:
            if !canStartSession(tier: tier) {
                return String(format: String(localized: "今日の相談回数（%d回）を使い切りました", bundle: LanguageManager.appBundle), Limits.premiumMaxSessions)
            }
            if !canSendRally(tier: tier) {
                return String(format: String(localized: "今日のメッセージ回数（%d回）を使い切りました", bundle: LanguageManager.appBundle), Limits.premiumMaxRallies)
            }
            return ""
        case .free:
            if !canStartSession(tier: tier) {
                return String(format: String(localized: "無料の相談回数（%d回）を使い切りました", bundle: LanguageManager.appBundle), Limits.freeMaxSessions)
            }
            if !canSendRally(tier: tier) {
                return String(format: String(localized: "無料のメッセージ回数（%d回）を使い切りました", bundle: LanguageManager.appBundle), Limits.freeMaxRallies)
            }
            return ""
        }
    }

    // MARK: - Private

    private func loadAll() {
        lifetimeSessions = userDefaults.integer(forKey: Keys.lifetimeSessions)
        lifetimeRallies = userDefaults.integer(forKey: Keys.lifetimeRallies)
        dailySessions = userDefaults.integer(forKey: Keys.dailySessions)
        dailyRallies = userDefaults.integer(forKey: Keys.dailyRallies)
        resetIfNewDay()
    }

    private func resetIfNewDay() {
        guard let lastReset = userDefaults.object(forKey: Keys.lastResetDate) as? Date else {
            userDefaults.set(Date(), forKey: Keys.lastResetDate)
            return
        }

        if !Calendar.current.isDateInToday(lastReset) {
            dailySessions = 0
            dailyRallies = 0
            userDefaults.set(dailySessions, forKey: Keys.dailySessions)
            userDefaults.set(dailyRallies, forKey: Keys.dailyRallies)
            userDefaults.set(Date(), forKey: Keys.lastResetDate)
        }
    }
}
