import Foundation

/// factor スコアから 4 分類スコアと総合スコアを算出
struct CategoryScorer: Sendable {

    /// 言語別の検知語彙（既定は日本語）。severePatterns の言語切替に使う。
    let lexicon: DiagnosisLexicon

    init(lexicon: DiagnosisLexicon = .japanese) {
        self.lexicon = lexicon
    }

    /// 分類スコア算出（仕様 §4-1）
    func categoryScores(factors: [FactorScore]) -> [HarassmentCategory: Int] {
        let lookup = Dictionary(uniqueKeysWithValues: factors.map { ($0.factor, $0.score) })
        func s(_ f: HarassmentFactor) -> Int { lookup[f] ?? 0 }

        // 重み付き平均（spec §4-1 の構成）
        let power = weightedAverage(values: [
            (s(.dominance), 1.0),
            (s(.workEvaluation), 1.0),
            (s(.personalityDenial), 1.2),
            (s(.disadvantageThreat), 1.2),
            (s(.excessiveDemand), 1.0),
            (s(.refusalImpossible), 1.1),
            (s(.groupExclusion), 1.0),
            (s(.privacyIntrusion), 0.8),
            (s(.persistentRepetition), 0.9),
            (s(.existenceDenial), 1.2),
            (s(.abilityDenial), 1.0),
        ])

        let sexual = weightedAverage(values: [
            (s(.sexualContext), 1.4),
            (s(.quotaPairing), 1.4),
            (s(.refusalImpossible), 1.1),
            (s(.disadvantageThreat), 1.0),
            (s(.dominance), 0.9),
            (s(.boundaryViolation), 1.2),
            (s(.persistentRepetition), 1.0),
            (s(.mockingLaughter), 0.8),
        ])

        let moral = weightedAverage(values: [
            (s(.intimateRelationship), 1.0),
            (s(.personalityDenial), 1.1),
            (s(.guiltManipulation), 1.3),
            (s(.gaslighting), 1.3),
            (s(.monitoringControl), 1.2),
            (s(.boundaryViolation), 1.0),
            (s(.persistentRepetition), 0.9),
            (s(.existenceDenial), 1.0),
        ])

        let other = weightedAverage(values: [
            (s(.roleStereotype), 1.2),
            (s(.alcoholCoercion), 1.2),
            (s(.customerAggression), 1.2),
            (s(.maternityPenalty), 1.3),
            (s(.academicPower), 1.2),
            (s(.privacyIntrusion), 1.0),
            (s(.groupExclusion), 1.0),
            (s(.monitoringControl), 0.8),
        ])

        return [
            .power: clamp(power),
            .sexual: clamp(sexual),
            .moral: clamp(moral),
            .other: clamp(other),
        ]
    }

    /// 仕様 §4-3 強制高リスク補正後の総合スコア
    func overallScore(
        categoryScores: [HarassmentCategory: Int],
        factors: [FactorScore]
    ) -> Int {
        let topCategory = categoryScores.values.max() ?? 0
        // category 上位 2 つの平均を base に。突出させすぎないように。
        let sorted = categoryScores.values.sorted(by: >)
        let base = sorted.prefix(2).reduce(0, +) / max(1, sorted.prefix(2).count)
        var score = max(topCategory, base)

        // 強制補正
        let factorMap = Dictionary(uniqueKeysWithValues: factors.map { ($0.factor, $0) })
        let boostThresholds: [(HarassmentFactor, Int)] = [
            (.quotaPairing, 12),
            (.disadvantageThreat, 18),
            (.existenceDenial, 18),
            (.boundaryViolation, 12),
            (.gaslighting, 18),
        ]
        var boosts = 0
        for (factor, threshold) in boostThresholds {
            if let fs = factorMap[factor], fs.score >= threshold {
                boosts += 1
            }
        }
        score += min(20, boosts * 4)

        // 「誰にも言うな」「スクショばらまく」「自殺・自傷を使った脅し」が混入していたら +12
        let severeOptions: String.CompareOptions = lexicon.caseInsensitive ? [.regularExpression, .caseInsensitive] : [.regularExpression]
        let allEvidence = factors.flatMap(\.detections).map(\.evidence).joined(separator: "\n")
        if lexicon.severePatterns.contains(where: { allEvidence.range(of: $0, options: severeOptions) != nil }) {
            score += 12
        }

        return clamp(score)
    }

    // MARK: - Helpers

    private func weightedAverage(values: [(Int, Double)]) -> Int {
        let totalWeight = values.reduce(0.0) { $0 + $1.1 }
        guard totalWeight > 0 else { return 0 }
        let sum = values.reduce(0.0) { $0 + Double($1.0) * $1.1 }
        return Int((sum / totalWeight).rounded())
    }

    private func clamp(_ value: Int) -> Int { max(0, min(100, value)) }
}
