import SwiftUI

#if DEBUG
extension DiagnosisResult {
    /// プレビュー / 開発用のサンプル診断結果（パワハラ × モラハラ混在ケース）
    static var samplePower: DiagnosisResult {
        let now = Date()
        let messageId1 = UUID()
        let messageId2 = UUID()
        let messageId3 = UUID()
        let typeIndex = HarassmentTypeCatalog.all.firstIndex { $0.id == "indoctrination_devil" } ?? 0
        let type = HarassmentTypeCatalog.all[typeIndex]
        let factors: [FactorScore] = [
            FactorScore(
                factor: .personalityDenial,
                score: 86,
                topSeverity: .high,
                detections: [
                    FactorDetection(
                        factor: .personalityDenial,
                        messageId: messageId1,
                        speakerName: "上司A",
                        timestamp: now.addingTimeInterval(-3600 * 6),
                        evidence: "お前ほんと使えない",
                        matchedPattern: "使えない",
                        severity: .high
                    ),
                ]
            ),
            FactorScore(
                factor: .disadvantageThreat,
                score: 79,
                topSeverity: .high,
                detections: [
                    FactorDetection(
                        factor: .disadvantageThreat,
                        messageId: messageId2,
                        speakerName: "上司A",
                        timestamp: now.addingTimeInterval(-3600 * 5),
                        evidence: "できないならもう来なくていい",
                        matchedPattern: "来なくていい",
                        severity: .high
                    ),
                ]
            ),
            FactorScore(
                factor: .refusalImpossible,
                score: 72,
                topSeverity: .medium,
                detections: [
                    FactorDetection(
                        factor: .refusalImpossible,
                        messageId: messageId3,
                        speakerName: "上司A",
                        timestamp: now.addingTimeInterval(-3600 * 5),
                        evidence: "できないなら",
                        matchedPattern: "できないなら",
                        severity: .medium
                    ),
                ]
            ),
            FactorScore(
                factor: .workEvaluation,
                score: 58,
                topSeverity: .medium,
                detections: []
            ),
        ]

        return DiagnosisResult(
            sessionId: UUID(),
            sessionTitle: "上司Aとのトーク",
            overallRiskScore: 82,
            riskLevel: .severe,
            dangerLabel: "かなり香ばしい",
            summary: "業務文脈に人格否定と不利益示唆が混在しており、パワハラ構造が明確です。",
            primaryType: type,
            secondaryTypes: [],
            catchCopy: type.catchCopyTemplates.first ?? type.structureSummary,
            categoryScores: [
                .power: 86,
                .sexual: 8,
                .moral: 62,
                .other: 24,
            ],
            primaryCategory: .power,
            secondaryCategories: [.moral],
            subCategories: [],
            factorScores: factors,
            logicExplanation: "業務上の指摘に見える表現の中に、人格否定と不利益示唆が含まれています。「お前ほんと使えない」は行動ではなく相手の能力・人格全体を否定し、「できないならもう来なくていい」は居場所を人質にした圧の構造です。",
            quotedEvidences: [
                QuotedEvidence(
                    quote: "お前ほんと使えない",
                    explanation: HarassmentFactor.personalityDenial.explanationTemplate(),
                    factor: .personalityDenial,
                    speakerName: "上司A",
                    timestamp: now.addingTimeInterval(-3600 * 6)
                ),
                QuotedEvidence(
                    quote: "できないならもう来なくていい",
                    explanation: HarassmentFactor.disadvantageThreat.explanationTemplate(),
                    factor: .disadvantageThreat,
                    speakerName: "上司A",
                    timestamp: now.addingTimeInterval(-3600 * 5)
                ),
            ],
            darkHumorAdvice: type.darkHumorAdvice
        )
    }
}

#Preview("毒見結果 - パワハラ") {
    NavigationStack {
        DiagnosisResultView(result: .samplePower)
    }
}
#endif
