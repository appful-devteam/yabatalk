import Foundation

/// factor 単位の検出結果（個別の引用）
struct FactorDetection: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let factor: HarassmentFactor
    let messageId: UUID
    let speakerName: String
    let timestamp: Date
    let evidence: String        // 引用テキスト（原文）
    let matchedPattern: String  // 検出パターン
    let severity: FactorSeverity

    init(
        id: UUID = UUID(),
        factor: HarassmentFactor,
        messageId: UUID,
        speakerName: String,
        timestamp: Date,
        evidence: String,
        matchedPattern: String,
        severity: FactorSeverity
    ) {
        self.id = id
        self.factor = factor
        self.messageId = messageId
        self.speakerName = speakerName
        self.timestamp = timestamp
        self.evidence = evidence
        self.matchedPattern = matchedPattern
        self.severity = severity
    }
}

/// factor 単位の集計スコア
struct FactorScore: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let factor: HarassmentFactor
    let score: Int                  // 0-100
    let topSeverity: FactorSeverity
    let detections: [FactorDetection]

    init(
        id: UUID = UUID(),
        factor: HarassmentFactor,
        score: Int,
        topSeverity: FactorSeverity,
        detections: [FactorDetection]
    ) {
        self.id = id
        self.factor = factor
        self.score = score
        self.topSeverity = topSeverity
        self.detections = detections
    }

    var displayName: String { factor.ingredientName }
    var rawDisplayName: String { factor.displayName }
    var explanation: String { factor.explanationTemplate() }
    var topEvidence: String? { detections.max { $0.severity.weightMultiplier < $1.severity.weightMultiplier }?.evidence }
}

/// 引用の説明（毒見アウトプットの「刺さってる言葉」）
struct QuotedEvidence: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let quote: String
    let explanation: String
    let factor: HarassmentFactor
    let speakerName: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        quote: String,
        explanation: String,
        factor: HarassmentFactor,
        speakerName: String,
        timestamp: Date
    ) {
        self.id = id
        self.quote = quote
        self.explanation = explanation
        self.factor = factor
        self.speakerName = speakerName
        self.timestamp = timestamp
    }
}

/// カテゴリ別の「なぜこのスコアか」の根拠
struct CategoryBreakdown: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let category: HarassmentCategory
    let score: Int
    let level: RiskLevel
    let contributingFactors: [FactorScore]  // score 寄与上位 (最大 4 件)
    let narrative: String                    // 「このカテゴリが立っている理由」

    init(
        id: UUID = UUID(),
        category: HarassmentCategory,
        score: Int,
        level: RiskLevel,
        contributingFactors: [FactorScore],
        narrative: String
    ) {
        self.id = id
        self.category = category
        self.score = score
        self.level = level
        self.contributingFactors = contributingFactors
        self.narrative = narrative
    }
}

/// 構成要素ごとの深掘り（検出件数 + どう問題か + 複数サンプル）
struct FactorDeepDive: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let factor: HarassmentFactor
    let score: Int
    let severity: FactorSeverity
    let detectionCount: Int
    let title: String
    let detail: String
    /// 代表サンプル（3〜5 件を表示）
    let sampleEvidences: [FactorEvidenceSample]

    init(
        id: UUID = UUID(),
        factor: HarassmentFactor,
        score: Int,
        severity: FactorSeverity,
        detectionCount: Int,
        title: String,
        detail: String,
        sampleEvidences: [FactorEvidenceSample]
    ) {
        self.id = id
        self.factor = factor
        self.score = score
        self.severity = severity
        self.detectionCount = detectionCount
        self.title = title
        self.detail = detail
        self.sampleEvidences = sampleEvidences
    }
}

/// FactorDeepDive 内の 1 件サンプル
struct FactorEvidenceSample: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let speaker: String?
    let text: String
    let timestamp: Date?

    init(id: UUID = UUID(), speaker: String?, text: String, timestamp: Date?) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
    }
}

/// 強制高リスク補正トリガー (docs §4-3)
struct RedFlagAmplifier: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String          // 例: "性的要求と評価の結合"
    let description: String    // なぜ重大か
    let evidence: String?      // 引用 (あれば)

    init(id: UUID = UUID(), title: String, description: String, evidence: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.evidence = evidence
    }
}

/// 話者別のヤバ発言サマリ
struct SpeakerStats: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let speakerName: String
    let detectionCount: Int            // この話者のヤバ発言件数
    let detectionMessageCount: Int     // 重複除いた件数
    let topFactor: HarassmentFactor?   // この話者の最多 factor
    let nightCount: Int                // この話者の夜間ヤバ発言件数

    init(
        id: UUID = UUID(),
        speakerName: String,
        detectionCount: Int,
        detectionMessageCount: Int,
        topFactor: HarassmentFactor?,
        nightCount: Int
    ) {
        self.id = id
        self.speakerName = speakerName
        self.detectionCount = detectionCount
        self.detectionMessageCount = detectionMessageCount
        self.topFactor = topFactor
        self.nightCount = nightCount
    }
}

/// 話者の口癖シグネチャ (どの phrase を何回言ったか)
struct PhraseSignature: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let phrase: String
    let count: Int
    let factor: HarassmentFactor?      // 紐付くハラスメント factor があれば

    init(id: UUID = UUID(), phrase: String, count: Int, factor: HarassmentFactor? = nil) {
        self.id = id
        self.phrase = phrase
        self.count = count
        self.factor = factor
    }
}

/// 話者別の独立判定（自分のタイプ / 相手のタイプ）
struct SpeakerVerdict: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let speakerName: String
    let score: Int                          // この話者個人のヤバ度 (0-100)
    let level: RiskLevel
    let dangerLabel: String
    let primaryCategory: HarassmentCategory
    let secondaryCategories: [HarassmentCategory]
    let subCategories: [HarassmentSubCategory]
    let categoryScores: [HarassmentCategory: Int]
    let primaryType: HarassmentType
    let catchCopy: String
    let topFactors: [FactorScore]            // 上位 4
    let oneLineVerdict: String               // 「立場差 + 人格否定 が出てるので 🐉 上司ドラゴン型」
    let signaturePhrases: [PhraseSignature]  // 口癖 top 5
    let topQuote: QuotedEvidence?

    init(
        id: UUID = UUID(),
        speakerName: String,
        score: Int,
        level: RiskLevel,
        dangerLabel: String,
        primaryCategory: HarassmentCategory,
        secondaryCategories: [HarassmentCategory],
        subCategories: [HarassmentSubCategory],
        categoryScores: [HarassmentCategory: Int],
        primaryType: HarassmentType,
        catchCopy: String,
        topFactors: [FactorScore],
        oneLineVerdict: String,
        signaturePhrases: [PhraseSignature],
        topQuote: QuotedEvidence?
    ) {
        self.id = id
        self.speakerName = speakerName
        self.score = score
        self.level = level
        self.dangerLabel = dangerLabel
        self.primaryCategory = primaryCategory
        self.secondaryCategories = secondaryCategories
        self.subCategories = subCategories
        self.categoryScores = categoryScores
        self.primaryType = primaryType
        self.catchCopy = catchCopy
        self.topFactors = topFactors
        self.oneLineVerdict = oneLineVerdict
        self.signaturePhrases = signaturePhrases
        self.topQuote = topQuote
    }
}

/// 数値で見るトーク
struct DiagnosisStats: Codable, Hashable, Sendable {
    let totalMessages: Int             // 総発言数
    let totalTextMessages: Int         // テキスト系のみ
    let detectedFactorCount: Int       // 検出された factor 延べ件数
    let uniqueDetectionMessageCount: Int  // 重複除いた検出メッセージ数
    let detectionRatePercent: Int      // 検出率 (0-100)
    let firstDetectionAt: Date?
    let lastDetectionAt: Date?
    let nightDetectionCount: Int       // 夜間 (22-05) 検出件数
    let perSpeaker: [SpeakerStats]     // 話者別の内訳
}

/// 診断結果（最終的にユーザーに見せるもの）
struct DiagnosisResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let sessionId: UUID
    let sessionTitle: String

    // overall
    let overallRiskScore: Int           // 0-100
    let riskLevel: RiskLevel
    let dangerLabel: String
    let summary: String

    // type
    let primaryType: HarassmentType
    let secondaryTypes: [HarassmentType]
    let catchCopy: String

    // category
    let categoryScores: [HarassmentCategory: Int]
    let primaryCategory: HarassmentCategory
    let secondaryCategories: [HarassmentCategory]
    let subCategories: [HarassmentSubCategory]

    // factors
    let factorScores: [FactorScore]

    // narrative (rich)
    let logicExplanation: String
    let logicParagraphs: [String]            // logicExplanation を段落分割したもの
    let categoryBreakdowns: [CategoryBreakdown]
    let factorDeepDives: [FactorDeepDive]
    let redFlagAmplifiers: [RedFlagAmplifier]
    let stats: DiagnosisStats
    let speakerVerdicts: [SpeakerVerdict]    // 話者別判定（自分・相手それぞれ）
    let quotedEvidences: [QuotedEvidence]
    let darkHumorAdvice: String
    let nextSteps: [String]
    let disclaimer: String
    /// データタブ用の詳細統計。診断時（解析中画面の裏）に計算して持たせる。
    /// 旧データとの後方互換のため optional（未計算なら View 側でフォールバック計算）。
    let detailedStatistics: DetailedStatistics?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sessionId: UUID,
        sessionTitle: String,
        overallRiskScore: Int,
        riskLevel: RiskLevel,
        dangerLabel: String,
        summary: String,
        primaryType: HarassmentType,
        secondaryTypes: [HarassmentType],
        catchCopy: String,
        categoryScores: [HarassmentCategory: Int],
        primaryCategory: HarassmentCategory,
        secondaryCategories: [HarassmentCategory],
        subCategories: [HarassmentSubCategory],
        factorScores: [FactorScore],
        logicExplanation: String,
        logicParagraphs: [String] = [],
        categoryBreakdowns: [CategoryBreakdown] = [],
        factorDeepDives: [FactorDeepDive] = [],
        redFlagAmplifiers: [RedFlagAmplifier] = [],
        stats: DiagnosisStats = DiagnosisStats(
            totalMessages: 0,
            totalTextMessages: 0,
            detectedFactorCount: 0,
            uniqueDetectionMessageCount: 0,
            detectionRatePercent: 0,
            firstDetectionAt: nil,
            lastDetectionAt: nil,
            nightDetectionCount: 0,
            perSpeaker: []
        ),
        speakerVerdicts: [SpeakerVerdict] = [],
        quotedEvidences: [QuotedEvidence],
        darkHumorAdvice: String,
        nextSteps: [String] = [],
        disclaimer: String = String(localized: "この結果はトーク内容から見た構造分析であり、法的な断定ではありません。", bundle: LanguageManager.appBundle),
        detailedStatistics: DetailedStatistics? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.overallRiskScore = overallRiskScore
        self.riskLevel = riskLevel
        self.dangerLabel = dangerLabel
        self.summary = summary
        self.primaryType = primaryType
        self.secondaryTypes = secondaryTypes
        self.catchCopy = catchCopy
        self.categoryScores = categoryScores
        self.primaryCategory = primaryCategory
        self.secondaryCategories = secondaryCategories
        self.subCategories = subCategories
        self.factorScores = factorScores
        self.logicExplanation = logicExplanation
        self.logicParagraphs = logicParagraphs.isEmpty ? [logicExplanation] : logicParagraphs
        self.categoryBreakdowns = categoryBreakdowns
        self.factorDeepDives = factorDeepDives
        self.redFlagAmplifiers = redFlagAmplifiers
        self.stats = stats
        self.speakerVerdicts = speakerVerdicts
        self.quotedEvidences = quotedEvidences
        self.darkHumorAdvice = darkHumorAdvice
        self.nextSteps = nextSteps
        self.disclaimer = disclaimer
        self.detailedStatistics = detailedStatistics
    }

    // detailedStatistics は Hashable ではないため合成 Hashable が壊れる。
    // 結果は id で一意なので、id ベースの同一性判定にする（NavigationPath 用）。
    static func == (lhs: DiagnosisResult, rhs: DiagnosisResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// 主分類 + 補助分類のラベル（表向き UI 用、例: 「セクハラ / パワハラ」）
    var harassmentLabel: String {
        var parts = [primaryCategory.shortName]
        parts.append(contentsOf: secondaryCategories.map(\.shortName))
        // その他の場合はサブ分類名を添える
        if primaryCategory == .other, let first = subCategories.first {
            return String(format: String(localized: "%1$@%2$@", bundle: LanguageManager.appBundle), first.displayName, first.trailingSuffix)
        }
        return parts.joined(separator: " / ")
    }

    /// スコアページ最上部の二者比較カードと完全に同じロジックで「相手のハラスメント割合」(%) を返す。
    /// 自分と相手の合計を 100 とした偏りで、selfShare + partnerShare = 100。
    /// - selfName: 分析で同定した自分の名前（無ければ UserPreferredName へフォールバック）
    /// - Returns: 相手の割合（0-100）。話者が 2 人未満で算出不能なら nil。
    func partnerHarassmentShare(selfName: String?) -> Int? {
        let verdicts = speakerVerdicts
        guard verdicts.count >= 2 else { return nil }
        let sn = (selfName?.isEmpty == false) ? selfName : UserPreferredName.resolve()

        let selfV: SpeakerVerdict
        let partnerV: SpeakerVerdict
        if let sn, let me = verdicts.first(where: { $0.speakerName == sn }),
           let other = verdicts.filter({ $0.id != me.id }).max(by: { $0.score < $1.score }) {
            selfV = me
            partnerV = other
        } else {
            // 自分が特定できない → スコア上位 2 人
            let sorted = verdicts.sorted { $0.score > $1.score }
            selfV = sorted[0]
            partnerV = sorted[1]
        }

        let s = max(0, selfV.score)
        let p = max(0, partnerV.score)
        guard s + p > 0 else { return 50 }
        let selfShare = Int((Double(s) / Double(s + p) * 100).rounded())
        return 100 - selfShare
    }

    /// 闇成分ミックスを score 降順で並べた表示用配列（上位 N 件）
    func topIngredients(limit: Int = 5) -> [FactorScore] {
        factorScores
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
}
