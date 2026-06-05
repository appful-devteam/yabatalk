import Foundation
import UIKit

// MARK: - Supabase Service
/// Supabase REST APIを直接呼び出すサービス（SPMパッケージ不要）
final class SupabaseService: Sendable {
    static let shared = SupabaseService()

    private static let deviceIdKey = "cached_device_id"

    private init() {}

    // MARK: - Device ID (キャッシュ付き)

    /// identifierForVendorがnilの場合に毎回ランダムUUIDが生成されるのを防ぐ
    var deviceId: String {
        if let cached = UserDefaults.standard.string(forKey: Self.deviceIdKey) {
            return cached
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: Self.deviceIdKey)
        return id
    }

    // MARK: - Survey Response

    /// アンケート回答をSupabaseに送信
    func sendSurveyResponse(age: String?, gender: String?, source: String?) async {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        // URLまたはキーが未設定の場合はスキップ
        guard !projectUrl.isEmpty, !anonKey.isEmpty else {
            print("[SupabaseService] Project URL or anon key not configured, skipping.")
            return
        }

        guard let url = URL(string: "\(projectUrl)/rest/v1/survey_responses") else {
            print("[SupabaseService] Invalid URL")
            return
        }

        // デバイスIDを取得（匿名識別用）
        let deviceId = self.deviceId

        var body: [String: Any] = [
            "device_id": deviceId
        ]
        if let age = age { body["age"] = age }
        if let gender = gender { body["gender"] = gender }
        if let source = source { body["source"] = source }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("[SupabaseService] Failed to serialize JSON")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("[SupabaseService] Survey response sent successfully")
                } else {
                    let responseBody = String(data: data, encoding: .utf8) ?? "nil"
                    print("[SupabaseService] Survey failed: status \(httpResponse.statusCode), body: \(responseBody)")
                }
            }
        } catch {
            // サイレントに失敗（UXに影響させない）
            print("[SupabaseService] Failed to send survey: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Review

    /// 相談セッションのレビューを送信
    func sendSessionReview(
        sessionId: String,
        rating: Int,
        reasons: [String],
        entryCount: Int,
        toneSetting: String,
        lengthSetting: String
    ) async {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        guard !projectUrl.isEmpty, !anonKey.isEmpty else { return }
        guard let url = URL(string: "\(projectUrl)/rest/v1/session_reviews") else { return }

        let deviceId = self.deviceId

        let body: [String: Any] = [
            "device_id": deviceId,
            "session_id": sessionId,
            "rating": rating,
            "reasons": reasons,
            "entry_count": entryCount,
            "tone_setting": toneSetting,
            "length_setting": lengthSetting,
            "app_version": Constants.App.version
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Review Response

    /// レビュー回答をusersテーブルに保存（RPC経由、RLSバイパス）
    func sendReviewResponse(answer: String) async {
        await upsertUser(
            isSubscribed: SubscriptionManager.shared.isSubscribed,
            reviewAnswer: answer,
            reviewAppVersion: Constants.App.version
        )
    }

    // MARK: - User Survey Update

    /// アンケート回答をusersテーブルに保存（RPC経由、RLSバイパス）
    func updateUserSurvey(age: String?, gender: String?, source: String?) async {
        await upsertUser(
            isSubscribed: SubscriptionManager.shared.isSubscribed,
            age: age,
            gender: gender,
            source: source
        )
    }

    // MARK: - App Config

    /// Supabaseからアプリ設定値を取得（非機密データ用）
    func fetchConfigValue(key: String) async -> String? {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        guard !projectUrl.isEmpty, !anonKey.isEmpty else { return nil }

        guard let url = URL(string: "\(projectUrl)/rest/v1/app_config?key=eq.\(key)&select=value") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }

            let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            return rows?.first?["value"] as? String
        } catch {
            print("[SupabaseService] Failed to fetch config '\(key)': \(error.localizedDescription)")
            return nil
        }
    }

    /// Edge Function経由でGemini APIキーを安全に取得（service_role keyでRLSバイパス）
    func fetchGeminiKeys(feature: String) async -> String? {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        guard !projectUrl.isEmpty, !anonKey.isEmpty else { return nil }

        guard let url = URL(string: "\(projectUrl)/functions/v1/get-gemini-keys") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let body: [String: String] = ["feature": feature, "bundleId": bundleId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("[SupabaseService] fetchGeminiKeys '\(feature)' failed: HTTP \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return nil
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["keys"] as? String
        } catch {
            print("[SupabaseService] Failed to fetch gemini keys '\(feature)': \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Error Log

    /// エラーログをSupabaseに送信
    /// - Parameters:
    ///   - context: エラーが発生した場所（例: "file_import", "analysis", "gemini_api"）
    ///   - errorType: エラーの種別（例: "group_chat_detected", "encoding_error"）
    ///   - message: エラーの詳細メッセージ
    ///   - metadata: 追加情報（ファイルサイズ、メッセージ数など）
    func sendErrorLog(
        context: String,
        errorType: String,
        message: String,
        metadata: [String: Any]? = nil
    ) async {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        guard !projectUrl.isEmpty, !anonKey.isEmpty else { return }

        guard let url = URL(string: "\(projectUrl)/rest/v1/error_logs") else { return }

        let deviceId = self.deviceId

        var body: [String: Any] = [
            "device_id": deviceId,
            "context": context,
            "error_type": errorType,
            "message": message,
            "app_version": Constants.App.version
        ]

        if let metadata = metadata,
           let metadataJson = try? JSONSerialization.data(withJSONObject: metadata),
           let metadataString = String(data: metadataJson, encoding: .utf8) {
            body["metadata"] = metadataString
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("[SupabaseService] Error log sent: \(context)/\(errorType)")
            }
        } catch {
            print("[SupabaseService] Failed to send error log: \(error.localizedDescription)")
        }
    }

    /// trackError: sendErrorLogのエイリアス
    func trackError(context: String, errorType: String, message: String, metadata: [String: Any]? = nil) async {
        await sendErrorLog(context: context, errorType: errorType, message: message, metadata: metadata)
    }

    /// updateReview: sendReviewResponseのエイリアス
    func updateReview(answer: String) async {
        await sendReviewResponse(answer: answer)
    }

    // MARK: - Event Tracking

    /// イベントをSupabaseに送信
    func trackEvent(_ name: String, properties: [String: Any]? = nil) async {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        guard !projectUrl.isEmpty, !anonKey.isEmpty else { return }

        guard let url = URL(string: "\(projectUrl)/rest/v1/events") else { return }

        let deviceId = self.deviceId

        var body: [String: Any] = [
            "device_id": deviceId,
            "event_name": name,
            "app_version": Constants.App.version
        ]

        if let properties = properties,
           let propsData = try? JSONSerialization.data(withJSONObject: properties),
           let propsString = String(data: propsData, encoding: .utf8) {
            body["properties"] = propsString
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("[SupabaseService] Event tracked: \(name)")
            }
        } catch {
            print("[SupabaseService] Failed to track event: \(error.localizedDescription)")
        }
    }

    /// 複数イベントを一括送信
    func trackEvents(_ events: [[String: Any]]) async {
        for event in events {
            let name = event["event_name"] as? String ?? ""
            let props = event["properties"] as? [String: Any]
            await trackEvent(name, properties: props)
        }
    }

    /// プッシュ通知権限をトラッキング
    func trackPushPermission(granted: Bool) async {
        await trackEvent("push_permission", properties: ["granted": granted])
    }

    /// APNsトークン更新をトラッキング
    func trackPushTokenUpdated(_ token: String) async {
        await trackEvent("push_token_updated", properties: ["token": token])
    }

    // MARK: - Score Collection

    /// 診断スコアをSupabaseに送信（パーセンタイル計算用、匿名）
    func sendScore(
        totalScore: Double,
        balanceScore: Double,
        tensionScore: Double,
        responseScore: Double,
        wordScore: Double,
        totalMessages: Int
    ) async {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        guard !projectUrl.isEmpty, !anonKey.isEmpty else { return }

        guard let url = URL(string: "\(projectUrl)/rest/v1/scores") else { return }

        let body: [String: Any] = [
            "total_score": totalScore,
            "balance_score": balanceScore,
            "tension_score": tensionScore,
            "response_score": responseScore,
            "word_score": wordScore,
            "total_messages": totalMessages
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("[SupabaseService] Score sent successfully")
            }
        } catch {
            print("[SupabaseService] Failed to send score: \(error.localizedDescription)")
        }
    }

    // MARK: - User Upsert

    /// ユーザー情報をSupabaseにupsert（RPC経由）
    /// RLSをバイパスするSECURITY DEFINER関数を使用。
    /// アンケート・レビューデータもRPC経由で送信（直接PATCHはRLSにブロックされるため）。
    func upsertUser(
        isSubscribed: Bool = false,
        age: String? = nil,
        gender: String? = nil,
        source: String? = nil,
        reviewAnswer: String? = nil,
        reviewAppVersion: String? = nil
    ) async {
        let projectUrl = Constants.Supabase.projectUrl
        let anonKey = Constants.Supabase.anonKey

        guard !projectUrl.isEmpty, !anonKey.isEmpty else { return }

        guard let url = URL(string: "\(projectUrl)/rest/v1/rpc/upsert_user") else { return }

        let deviceId = self.deviceId

        // UserDefaultsからアンケートデータを読み込み（引数が優先）
        let defaults = UserDefaults.standard
        let resolvedAge = age ?? defaults.string(forKey: Constants.StorageKeys.surveyAge)
        let resolvedGender = gender ?? defaults.string(forKey: Constants.StorageKeys.surveyGender)
        let resolvedSource = source ?? defaults.string(forKey: Constants.StorageKeys.surveySource)

        var body: [String: Any] = [
            "p_device_id": deviceId,
            "p_app_version": Constants.App.version,
            "p_is_subscribed": isSubscribed,
            "p_language": defaults.string(forKey: Constants.StorageKeys.appLanguage) ?? "ja",
            "p_os_version": UIDevice.current.systemVersion
        ]

        // NULLでない場合のみパラメータに含める（RPCのCOALESCEで既存データを保持）
        if let age = resolvedAge { body["p_age"] = age }
        if let gender = resolvedGender { body["p_gender"] = gender }
        if let source = resolvedSource { body["p_source"] = source }
        if let review = reviewAnswer { body["p_review_answer"] = review }
        if let reviewVer = reviewAppVersion { body["p_review_app_version"] = reviewVer }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("[SupabaseService] User upserted successfully")
                } else if httpResponse.statusCode == 404,
                          body.keys.contains(where: { $0.hasPrefix("p_age") || $0.hasPrefix("p_review") }) {
                    // SQL未適用: 新パラメータを除外してリトライ
                    print("[SupabaseService] RPC doesn't accept new params yet, retrying with base params")
                    let baseBody: [String: Any] = [
                        "p_device_id": deviceId,
                        "p_app_version": Constants.App.version,
                        "p_is_subscribed": isSubscribed,
                        "p_language": defaults.string(forKey: Constants.StorageKeys.appLanguage) ?? "ja",
                        "p_os_version": UIDevice.current.systemVersion
                    ]
                    guard let baseData = try? JSONSerialization.data(withJSONObject: baseBody) else { return }
                    var retryRequest = request
                    retryRequest.httpBody = baseData
                    let (_, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                    if let retryHttp = retryResponse as? HTTPURLResponse,
                       (200...299).contains(retryHttp.statusCode) {
                        print("[SupabaseService] User upserted (base params only)")
                    }
                }
            }
        } catch {
            print("[SupabaseService] Failed to upsert user: \(error.localizedDescription)")
        }
    }
}
