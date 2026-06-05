import Foundation
import FirebaseAnalytics

// MARK: - Canonical Analytics Taxonomy
//
// このファイルは「めろとーく計測設計」(lovetalk.md) の正規イベント定義を
// 1箇所に集約する型付きレイヤー。各 View / ViewModel は文字列リテラルではなく
// ここのメソッド経由でイベントを発火する。これにより
//   - イベント名 / パラメータ名の typo を防ぐ
//   - 「二重定義」を排除し対応関係を一望できる
//   - **トーク本文・参加者氏名を絶対に送らない**(件数・分類のみ) を担保する
//
// GA4 標準(予約)イベントは FirebaseAnalytics の AnalyticsEvent* 定数を使う。
extension AnalyticsManager {

    // MARK: 列挙(パラメータ値の正規化)

    /// インポート流入経路
    enum ImportSource: String {
        case filePicker = "file_picker"
        case shareExtension = "share_extension"
    }

    /// インポート離脱要因
    enum ImportErrorType: String {
        case insufficientMessages = "insufficient_messages"
        case tooManyParticipants = "too_many_participants"
        case parseError = "parse_error"
        case pickerError = "picker_error"
    }

    /// 解析対象期間
    enum AnalysisPeriodParam: String {
        case all
        case days7 = "7d"
        case days30 = "30d"
    }

    /// 結果到達の種別
    enum ResultType: String {
        case first
        case reAnalysis = "re_analysis"
    }

    /// 課金トリガーとなった機能
    enum LimitFeature: String {
        case analysis
        case consultation
        case personaChat = "persona_chat"
    }

    /// 掲示板投稿の種別
    enum BoardPostKind: String {
        case analysisShare = "analysis_share"
        case question
        case text
    }

    /// 拡散経路
    enum ShareMethod: String {
        case board
        case system
    }

    // MARK: - インポート → 解析完了ファネル

    func importStarted(source: ImportSource) {
        track("import_started", properties: ["source": source.rawValue])
    }

    /// パース成功(=.txt がメッセージ列に変換できた)。本文は送らず件数のみ。
    func fileParsed(participantCount: Int, messageCount: Int) {
        track("file_parsed", properties: [
            "status": "success",
            "participant_count": participantCount,
            "message_count": messageCount
        ])
    }

    func importError(_ type: ImportErrorType) {
        track("import_error", properties: ["error_type": type.rawValue])
    }

    func selfNameConfirmed(isGroupChat: Bool, partnerCount: Int) {
        track("self_name_confirmed", properties: [
            "is_group_chat": isGroupChat,
            "partner_count": partnerCount
        ])
    }

    func analysisStarted(period: AnalysisPeriodParam, messageCount: Int) {
        track("analysis_started", properties: [
            "period": period.rawValue,
            "message_count": messageCount
        ])
    }

    /// コア完了(CV)。relationshipType は 16タイプの内部コード(BWSF 等)、氏名は送らない。
    /// スコアは 0-100 の Double を整数に丸めて送る。
    func analysisCompleted(
        durationSec: Int,
        relationshipType: String,
        totalScore: Double,
        balanceScore: Double,
        tensionScore: Double,
        responseScore: Double,
        wordScore: Double
    ) {
        track("analysis_completed", properties: [
            "duration_sec": durationSec,
            "relationship_type": relationshipType,
            "total_score": Int(totalScore.rounded()),
            "score_balance": Int(balanceScore.rounded()),
            "score_voltage": Int(tensionScore.rounded()),
            "score_timing": Int(responseScore.rounded()),
            "score_depth": Int(wordScore.rounded())
        ])
    }

    func analysisError(errorType: String) {
        track("analysis_error", properties: ["error_type": errorType])
    }

    func resultViewed(_ type: ResultType) {
        track("result_viewed", properties: ["result_type": type.rawValue])
    }

    // MARK: - AI 機能

    func aiSummaryUsed(isSubscribed: Bool, apiSuccess: Bool, monthCount: Int) {
        track("ai_summary_used", properties: [
            "is_subscribed": isSubscribed,
            "api_success": apiSuccess,
            "month_count": monthCount
        ])
    }

    func aiConsultationSent(isSubscribed: Bool, freeRemaining: Int?) {
        var props: [String: Any] = ["is_subscribed": isSubscribed]
        if let freeRemaining { props["free_remaining"] = freeRemaining }
        track("ai_consultation_sent", properties: props)
    }

    func personaChatSent(isSubscribed: Bool) {
        track("persona_chat_sent", properties: ["is_subscribed": isSubscribed])
    }

    // MARK: - 課金トリガー / コミュニティ

    /// 課金トリガー。feature で機能を分離、tier/used_count は任意の補足。
    func limitReached(feature: LimitFeature, isSubscribed: Bool, tier: String? = nil, usedCount: Int? = nil) {
        var props: [String: Any] = [
            "feature": feature.rawValue,
            "is_subscribed": isSubscribed
        ]
        if let tier { props["tier"] = tier }
        if let usedCount { props["used_count"] = usedCount }
        track("limit_reached", properties: props)
    }

    func boardPostCreated(postType: BoardPostKind, hasDiagnosis: Bool, hasImages: Bool) {
        track("board_post_created", properties: [
            "post_type": postType.rawValue,
            "has_diagnosis": hasDiagnosis,
            "has_images": hasImages
        ])
    }

    // MARK: - GA4 標準(予約)CV イベント

    /// 購入。GA4 予約イベント `purchase`。value/currency は予約パラメータ名で送る。
    func purchase(value: Double, currency: String, planId: String, tier: String) {
        track(AnalyticsEventPurchase, properties: [
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency,
            "plan_id": planId,
            "tier": tier
        ])
    }

    /// 拡散。GA4 予約イベント `share`。このアプリの結果拡散導線=診断カード付き掲示板投稿。
    func resultShared(method: ShareMethod) {
        track(AnalyticsEventShare, properties: [
            AnalyticsParameterContentType: "result",
            AnalyticsParameterMethod: method.rawValue
        ])
    }

    func tutorialBegin() {
        track(AnalyticsEventTutorialBegin)
    }

    func tutorialComplete() {
        track(AnalyticsEventTutorialComplete)
    }
}
