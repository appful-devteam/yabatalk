import Foundation
import UIKit
import FirebaseAnalytics

@MainActor
final class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    private var sessionId = UUID().uuidString
    private var sessionStartDate = Date()
    private var eventQueue: [[String: Any]] = []
    private let batchSize = 10
    private let flushInterval: TimeInterval = 30
    private var flushTimer: Timer?

    private init() {
        setupLifecycleObservers()
        startFlushTimer()
    }

    // MARK: - Public API

    func track(_ event: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["session_id"] = sessionId
        props["timestamp"] = ISO8601DateFormatter().string(from: Date())

        eventQueue.append([
            "event_name": event,
            "properties": props
        ])

        if eventQueue.count >= batchSize {
            flush()
        }
    }

    func screenView(_ name: String) {
        track("screen_view", properties: ["screen_name": name])
    }

    /// 課金状態を GA4 ユーザープロパティに反映。これで track した全イベント
    /// （analysis_completed / share / result_viewed / board_post_created など）を
    /// 課金/無課金・tier で層別できる。SubscriptionManager の entitlement 更新時に呼ぶ。
    /// バッチではなく即時設定（以降のイベントに紐づくため）。
    func setSubscriptionState(isSubscribed: Bool, tier: String) {
        Analytics.setUserProperty(isSubscribed ? "true" : "false", forName: "is_subscribed")
        Analytics.setUserProperty(tier, forName: "subscription_tier")
    }

    // MARK: - Lifecycle

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleBackground()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleForeground()
            }
        }
    }

    private func handleBackground() {
        let duration = Date().timeIntervalSince(sessionStartDate)
        track("app_background", properties: ["session_duration_sec": Int(duration)])
        flush()
    }

    private func handleForeground() {
        sessionId = UUID().uuidString
        sessionStartDate = Date()
        track("app_open", properties: [
            "is_first_launch": !UserDefaults.standard.bool(forKey: Constants.StorageKeys.hasCompletedOnboarding)
        ])
    }

    // MARK: - Batch Flush

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flush()
            }
        }
    }

    func flush() {
        guard !eventQueue.isEmpty else { return }
        let batch = eventQueue
        eventQueue.removeAll()

        for item in batch {
            let rawName = item["event_name"] as? String ?? ""
            let name = Self.sanitizedEventName(rawName)
            let rawProps = item["properties"] as? [String: Any]
            let params = Self.sanitizedParameters(rawProps)
            Analytics.logEvent(name, parameters: params)
        }
    }

    /// Firebase Analytics の event 名は [a-zA-Z0-9_] 40文字以下、英字始まり
    private static func sanitizedEventName(_ s: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        var cleaned = String(s.unicodeScalars.compactMap { allowed.contains(Character($0)) ? Character($0) : "_" })
        if let first = cleaned.first, first.isNumber {
            cleaned = "e_" + cleaned
        }
        return String(cleaned.prefix(40))
    }

    /// Analytics パラメータの制約: name [a-zA-Z0-9_] 40文字、value は String <= 100 / Int / Double
    private static func sanitizedParameters(_ props: [String: Any]?) -> [String: Any]? {
        guard let props = props, !props.isEmpty else { return nil }
        var out: [String: Any] = [:]
        for (k, v) in props {
            let key = sanitizedEventName(k)
            switch v {
            case let n as Int: out[key] = n
            case let n as Double: out[key] = n
            case let b as Bool: out[key] = b ? 1 : 0
            case let s as String: out[key] = String(s.prefix(100))
            default: out[key] = String(String(describing: v).prefix(100))
            }
        }
        return out
    }
}
