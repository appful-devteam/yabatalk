import Foundation

// MARK: - Analysis Result
/// 解析結果
struct AnalysisResult: Identifiable, Hashable, Codable {
    let id: UUID
    let sessionId: UUID
    let period: AnalysisPeriod
    let axisScore: AxisScore
    let selfParticipant: String
    let partnerParticipant: String
    let analyzedAt: Date

    // MARK: - Statistics

    /// 解析対象の総メッセージ数
    let totalMessages: Int

    /// 解析対象の会話ブロック数
    let totalBlocks: Int

    /// 解析対象の日数
    let analyzedDays: Int

    /// 最初のメッセージ日時
    let firstMessageDate: Date

    /// 最後のメッセージ日時
    let lastMessageDate: Date

    /// 詳細統計
    let detailedStatistics: DetailedStatistics?

    /// グループチャットかどうか
    let isGroupChat: Bool

    /// グループチャットの個人別スコア
    let memberScores: [MemberScore]?

    /// 返信提案向け話し方プロファイル（診断時に事前生成）
    let replyStyleProfiles: ReplyStyleProfiles?

    /// グループチャットの参加者名
    let groupParticipantNames: [String]?

    /// グループ名（セッションタイトル）
    let groupTitle: String?

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        period: AnalysisPeriod,
        axisScore: AxisScore,
        selfParticipant: String,
        partnerParticipant: String,
        analyzedAt: Date = Date(),
        totalMessages: Int,
        totalBlocks: Int,
        analyzedDays: Int,
        firstMessageDate: Date,
        lastMessageDate: Date,
        detailedStatistics: DetailedStatistics? = nil,
        isGroupChat: Bool = false,
        memberScores: [MemberScore]? = nil,
        groupParticipantNames: [String]? = nil,
        groupTitle: String? = nil,
        replyStyleProfiles: ReplyStyleProfiles? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.period = period
        self.axisScore = axisScore
        self.selfParticipant = selfParticipant
        self.partnerParticipant = partnerParticipant
        self.analyzedAt = analyzedAt
        self.totalMessages = totalMessages
        self.totalBlocks = totalBlocks
        self.analyzedDays = analyzedDays
        self.firstMessageDate = firstMessageDate
        self.lastMessageDate = lastMessageDate
        self.detailedStatistics = detailedStatistics
        self.isGroupChat = isGroupChat
        self.memberScores = memberScores
        self.groupParticipantNames = groupParticipantNames
        self.groupTitle = groupTitle
        self.replyStyleProfiles = replyStyleProfiles
    }

    // MARK: - Computed Properties

    /// 総合スコア
    var totalScore: Double {
        axisScore.totalScore
    }

    /// 1日あたりの平均メッセージ数
    var averageMessagesPerDay: Double {
        guard analyzedDays > 0 else { return 0 }
        return Double(totalMessages) / Double(analyzedDays)
    }

    /// 期間の表示文字列
    var periodDisplayString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = LanguageManager.appLocale
        dateFormatter.dateFormat = "yyyy/M/d"

        let start = dateFormatter.string(from: firstMessageDate)
        let end = dateFormatter.string(from: lastMessageDate)

        return "\(start) 〜 \(end)"
    }

    /// 解析日時の表示文字列
    var analyzedAtDisplayString: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "M/d H:mm"
        return formatter.string(from: analyzedAt)
    }

    /// サマリーテキスト
    var summaryText: String {
        String(format: String(localized: "%@さんとの%@の解析結果", bundle: LanguageManager.appBundle), partnerParticipant, period.displayName)
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AnalysisResult, rhs: AnalysisResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Analysis Error
enum AnalysisError: LocalizedError {
    case insufficientData(messageCount: Int)
    case parsingFailed(reason: String)
    case noParticipantsFound
    case notOneOnOneConversation
    case selfIdentificationFailed
    case periodNotAvailable

    var errorDescription: String? {
        switch self {
        case .insufficientData(let count):
            return String(format: String(localized: "メッセージ数が少なすぎます（%d件）。最低%d件必要です。", bundle: LanguageManager.appBundle), count, Constants.Analysis.minimumMessagesRequired)
        case .parsingFailed(let reason):
            return String(format: String(localized: "トーク履歴の読み込みに失敗しました: %@", bundle: LanguageManager.appBundle), reason)
        case .noParticipantsFound:
            return String(localized: "参加者が見つかりませんでした。", bundle: LanguageManager.appBundle)
        case .notOneOnOneConversation:
            return String(localized: "1対1のトークのみ解析できます。", bundle: LanguageManager.appBundle)
        case .selfIdentificationFailed:
            return String(localized: "あなたの特定に失敗しました。", bundle: LanguageManager.appBundle)
        case .periodNotAvailable:
            return String(localized: "指定された期間のデータがありません。", bundle: LanguageManager.appBundle)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .insufficientData:
            return String(localized: "もう少しやり取りを重ねてから再度お試しください。", bundle: LanguageManager.appBundle)
        case .parsingFailed:
            return String(localized: "LINEのトーク履歴を正しくエクスポートしたか確認してください。", bundle: LanguageManager.appBundle)
        case .noParticipantsFound:
            return String(localized: "LINEのトーク履歴ファイルを確認してください。", bundle: LanguageManager.appBundle)
        case .notOneOnOneConversation:
            return String(localized: "1対1のトーク履歴を選択してください。", bundle: LanguageManager.appBundle)
        case .selfIdentificationFailed:
            return String(localized: "手動で選択してください。", bundle: LanguageManager.appBundle)
        case .periodNotAvailable:
            return String(localized: "全期間で解析してみてください。", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - Share Content
extension AnalysisResult {
    /// シェア用テキスト
    var shareText: String {
        let title = String(localized: "【めろとーく診断結果】", bundle: LanguageManager.appBundle)
        let totalLabel = String(format: String(localized: "総合スコア: %d点", bundle: LanguageManager.appBundle), Int(totalScore))
        let axisHeader = String(localized: "📊 4軸スコア", bundle: LanguageManager.appBundle)
        let balanceLabel = String(format: String(localized: "バランス: %d点", bundle: LanguageManager.appBundle), Int(axisScore.balanceScore))
        let tensionLabel = String(format: String(localized: "テンション: %d点", bundle: LanguageManager.appBundle), Int(axisScore.tensionScore))
        let responseLabel = String(format: String(localized: "レスポンス: %d点", bundle: LanguageManager.appBundle), Int(axisScore.responseScore))
        let wordLabel = String(format: String(localized: "ワード: %d点", bundle: LanguageManager.appBundle), Int(axisScore.wordScore))
        let hashtags = String(localized: "#めろとーく #恋愛診断", bundle: LanguageManager.appBundle)
        return """
        \(title)

        \(totalLabel)
        \(axisScore.scoreMessage)

        \(axisHeader)
        \(balanceLabel)
        \(tensionLabel)
        \(responseLabel)
        \(wordLabel)

        \(hashtags)
        """
    }
}
