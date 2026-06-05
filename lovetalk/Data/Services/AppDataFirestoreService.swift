import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

/// 運用データの Firestore 書き込み窓口。
///
/// - `users/{uid}`: 既存のコミュニティ機能用ドキュメントに分析用フィールドを merge で追加
/// - `analytics_users/{vendorId}`: 端末単位の分析用ドキュメント。サブスク状態とアンケート
///   回答を 1 ドキュメントに集約する（`users_legacy/{device_id}` と同じ粒度）。
///   profile 用 `users/{uid}` は Auth UID キーで匿名/本アカウントが混在し、アンケートと
///   サブスクが別ドキュメントに散らばってしまうため、分析専用に分離している。
/// - `scores/{auto}`: 診断結果のパーセンタイル計算用
/// - `sessionReviews/{auto}`: 相談機能のフィードバック
///
/// 認証は `BoardAuthService` の匿名サインインを流用。
@MainActor
final class AppDataFirestoreService {
    static let shared = AppDataFirestoreService()

    private let db = Firestore.firestore()
    private let firstBootstrapKey = "appdata_first_bootstrap_done"
    private let analyticsCollection = "analytics_users"

    /// 直近に analytics_users へ書き込んだサブスク tier。重複書き込み抑制用（メモリのみ）。
    private var lastPushedTier: String?

    private init() {}

    // MARK: - Analytics User Document (端末単位の集約)

    /// 端末固有 ID。アプリ更新では維持され、同一ベンダーの全アプリ削除でのみリセット。
    private var analyticsDocId: String? {
        UIDevice.current.identifierForVendor?.uuidString
    }

    /// `analytics_users/{vendorId}` にサブスク状態・アンケート・端末情報をまとめて merge する。
    /// bootstrap / アンケート完了 / サブスク状態変化のいずれの経路からでも安全に呼べる。
    func recordAnalyticsSnapshot(markFirstSeen: Bool = false) async {
        guard let docId = analyticsDocId else { return }
        guard let uid = await ensureAnonymousAuth() else { return }

        let defaults = UserDefaults.standard
        let tier = SubscriptionManager.shared.currentTier
        let language = defaults.string(forKey: Constants.StorageKeys.appLanguage) ?? "ja"
        let country = Locale.current.region?.identifier ?? "Unknown"

        var payload: [String: Any] = [
            "authUid": uid,
            "appVersion": Constants.App.version,
            "osVersion": UIDevice.current.systemVersion,
            "language": language,
            "country": country,
            "isSubscribed": SubscriptionManager.shared.isSubscribed,
            "subscriptionTier": tier.rawValue,
            "lastActiveAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let age = defaults.string(forKey: Constants.StorageKeys.surveyAge) {
            payload["surveyAge"] = age
        }
        if let gender = defaults.string(forKey: Constants.StorageKeys.surveyGender) {
            payload["surveyGender"] = gender
        }
        if let source = defaults.string(forKey: Constants.StorageKeys.surveySource) {
            payload["surveySource"] = source
        }
        if markFirstSeen {
            // setData(merge:) では既存フィールドは上書きされないため、初回のみ意味を持つ。
            payload["firstSeenAt"] = FieldValue.serverTimestamp()
            payload["installCohort"] = Self.cohortString(from: Date())
        }

        do {
            try await db.collection(analyticsCollection).document(docId).setData(payload, merge: true)
            lastPushedTier = tier.rawValue
        } catch {
            print("[AppDataFS] recordAnalyticsSnapshot failed: \(error.localizedDescription)")
        }
    }

    /// サブスク状態が変化した時に SubscriptionManager から呼ぶ。
    /// tier が前回 push 時から変わっていなければ no-op（無駄な書き込みを抑制）。
    func pushSubscriptionStateIfChanged() async {
        let tier = SubscriptionManager.shared.currentTier.rawValue
        guard tier != lastPushedTier else { return }
        await recordAnalyticsSnapshot()
    }

    // MARK: - User Document

    /// アプリ起動時に呼ぶ。匿名サインインを保証し、運用フィールドを更新する。
    /// 初回時は `firstSeenAt` / `installCohort` も初期化。
    func bootstrap() async {
        guard let uid = await ensureAnonymousAuth() else { return }

        let language = UserDefaults.standard.string(forKey: Constants.StorageKeys.appLanguage) ?? "ja"
        let country = Locale.current.region?.identifier ?? "Unknown"
        let isSubscribed = SubscriptionManager.shared.isSubscribed

        var payload: [String: Any] = [
            "appVersion": Constants.App.version,
            "language": language,
            "country": country,
            "isSubscribed": isSubscribed,
            "lastActiveAt": FieldValue.serverTimestamp()
        ]

        let isFirstBootstrap = !UserDefaults.standard.bool(forKey: firstBootstrapKey)
        if isFirstBootstrap {
            payload["firstSeenAt"] = FieldValue.serverTimestamp()
            payload["installCohort"] = Self.cohortString(from: Date())
        }

        do {
            try await db.collection("users").document(uid).setData(payload, merge: true)
            if isFirstBootstrap {
                UserDefaults.standard.set(true, forKey: firstBootstrapKey)
            }
        } catch {
            print("[AppDataFS] bootstrap failed: \(error.localizedDescription)")
        }

        // 端末単位の分析ドキュメントにも集約（サブスク状態＋既存アンケート回答）。
        await recordAnalyticsSnapshot(markFirstSeen: isFirstBootstrap)
    }

    /// オンボーディング調査結果を保存。
    func saveSurvey(age: String?, gender: String?, source: String?) async {
        guard let uid = await ensureAnonymousAuth() else { return }
        var payload: [String: Any] = [
            "surveyCompletedAt": FieldValue.serverTimestamp()
        ]
        if let age = age { payload["surveyAge"] = age }
        if let gender = gender { payload["surveyGender"] = gender }
        if let source = source { payload["surveySource"] = source }
        do {
            try await db.collection("users").document(uid).setData(payload, merge: true)
        } catch {
            print("[AppDataFS] saveSurvey failed: \(error.localizedDescription)")
        }

        // アンケートとサブスク状態を同一の分析ドキュメントに揃える。
        // （呼び出し元が UserDefaults に保存済みなので recordAnalyticsSnapshot が拾う）
        await recordAnalyticsSnapshot()
    }

    /// アプリ内レビュー誘導の回答を保存。
    func saveReviewAnswer(_ answer: String) async {
        guard let uid = await ensureAnonymousAuth() else { return }
        do {
            try await db.collection("users").document(uid).setData([
                "reviewAnswer": answer,
                "reviewAnswerVersion": Constants.App.version,
                "reviewAnsweredAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("[AppDataFS] saveReviewAnswer failed: \(error.localizedDescription)")
        }
    }

    /// 相談機能の利用カウンタを 1 加算。相談セッション開始時などに呼ぶ。
    func incrementConsultationCount() async {
        guard let uid = await ensureAnonymousAuth() else { return }
        do {
            try await db.collection("users").document(uid).setData([
                "totalConsultationCount": FieldValue.increment(Int64(1))
            ], merge: true)
        } catch {
            print("[AppDataFS] incrementConsultationCount failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Scores

    /// 診断完了時に呼ぶ。`scores/` に 1 件作成 + `users.totalDiagnosesCount` を 1 加算。
    func recordScore(
        totalScore: Double,
        balanceScore: Double,
        tensionScore: Double,
        responseScore: Double,
        wordScore: Double,
        totalMessages: Int
    ) async {
        guard let uid = await ensureAnonymousAuth() else { return }
        let payload: [String: Any] = [
            "userId": uid,
            "totalScore": totalScore,
            "balanceScore": balanceScore,
            "tensionScore": tensionScore,
            "responseScore": responseScore,
            "wordScore": wordScore,
            "totalMessages": totalMessages,
            "appVersion": Constants.App.version,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("scores").addDocument(data: payload)
            try await db.collection("users").document(uid).setData([
                "totalDiagnosesCount": FieldValue.increment(Int64(1))
            ], merge: true)
        } catch {
            print("[AppDataFS] recordScore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Reviews

    /// 相談機能のフィードバックを `sessionReviews/` に記録。
    func recordSessionReview(
        sessionId: String,
        rating: Int,
        reasons: [String],
        entryCount: Int,
        toneSetting: String,
        lengthSetting: String
    ) async {
        guard let uid = await ensureAnonymousAuth() else { return }
        let payload: [String: Any] = [
            "userId": uid,
            "sessionId": sessionId,
            "rating": rating,
            "reasons": reasons,
            "entryCount": entryCount,
            "toneSetting": toneSetting,
            "lengthSetting": lengthSetting,
            "appVersion": Constants.App.version,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("sessionReviews").addDocument(data: payload)
        } catch {
            print("[AppDataFS] recordSessionReview failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    /// 匿名サインインを保証し、uid を返す。失敗時は nil。
    private func ensureAnonymousAuth() async -> String? {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        await BoardAuthService.shared.signInAnonymously()
        return Auth.auth().currentUser?.uid
    }

    /// "yyyy-MM" 形式（JST 基準）。インストールコホートに使う。
    private static func cohortString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f.string(from: date)
    }
}
