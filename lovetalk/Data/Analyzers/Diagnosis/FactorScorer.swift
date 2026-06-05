import Foundation

/// 検出結果を factor 別にスコア化（0–100）
/// 関係性プリオール (spec §3.5 / §4.4 / §4.5) を multiplier + suppression として注入する。
struct FactorScorer: Sendable {
    /// 飽和カーブの片足係数。1 件目から伸びやすく、5 件以上で飽和に近づく。
    private let saturation: Double = 28

    /// 関係性なしの後方互換 API。`unknown` 扱いで処理する（補正なし）。
    func score(detections: [FactorDetection]) -> [FactorScore] {
        score(detections: detections, relationship: .unknown)
    }

    /// 関係性プリオールを適用したスコアリング。
    /// - `relationship.suppressedFactors` に含まれる factor は完全に捨てる
    /// - 残った factor は `relationship.multiplier(for:)` を raw weight に掛けて加算
    func score(detections: [FactorDetection], relationship: RelationshipContext) -> [FactorScore] {
        let suppressed = relationship.suppressedFactors
        let grouped = Dictionary(grouping: detections, by: { $0.factor })
        var out: [FactorScore] = []
        for factor in HarassmentFactor.allCases {
            if suppressed.contains(factor) { continue }
            let items = grouped[factor] ?? []
            guard !items.isEmpty else { continue }
            let multiplier = relationship.multiplier(for: factor)
            // multiplier == 0 はここで弾く（suppressedFactors と一致するが二重防御）
            guard multiplier > 0 else { continue }
            let raw = items.reduce(0.0) { acc, det in
                let weight = ruleWeight(for: det) * det.severity.weightMultiplier
                return acc + weight
            }
            let adjustedRaw = raw * multiplier
            // 飽和カーブ: score = 100 * adjustedRaw / (adjustedRaw + saturation)
            let normalized = 100.0 * adjustedRaw / (adjustedRaw + saturation)
            let topSeverity = items.map(\.severity).max(by: { $0.weightMultiplier < $1.weightMultiplier }) ?? .low
            out.append(
                FactorScore(
                    factor: factor,
                    score: Int(normalized.rounded()),
                    topSeverity: topSeverity,
                    detections: items.sorted { $0.severity.weightMultiplier > $1.severity.weightMultiplier }
                )
            )
        }
        return out.sorted { $0.score > $1.score }
    }

    private func ruleWeight(for detection: FactorDetection) -> Double {
        // matchedPattern と一致する rule の baseWeight を引き当て、無ければ severity 既定値
        if let rule = FactorRuleDictionary.rules.first(where: { detection.matchedPattern.range(of: $0.pattern, options: .regularExpression) != nil && $0.factor == detection.factor }) {
            return Double(rule.baseWeight)
        }
        switch detection.severity {
        case .low: return 8
        case .medium: return 14
        case .high: return 22
        }
    }
}

extension FactorSeverity: Comparable {
    static func < (lhs: FactorSeverity, rhs: FactorSeverity) -> Bool {
        lhs.weightMultiplier < rhs.weightMultiplier
    }
}
