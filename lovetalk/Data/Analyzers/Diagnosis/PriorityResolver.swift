import Foundation

/// 主分類・補助分類を仕様 §5 の優先ルールに従って決定。
/// 関係性プリオール (§3.5) によって各ルールの発火条件・しきい値が動的に変わる。
struct PriorityResolver: Sendable {

    struct Decision: Sendable {
        let primary: HarassmentCategory
        let secondary: [HarassmentCategory]
        let subCategories: [HarassmentSubCategory]
        let rationale: String
    }

    /// 関係性なしの後方互換 API。
    func resolve(
        categoryScores: [HarassmentCategory: Int],
        factors: [FactorScore]
    ) -> Decision {
        resolve(categoryScores: categoryScores, factors: factors, relationship: .unknown)
    }

    func resolve(
        categoryScores: [HarassmentCategory: Int],
        factors: [FactorScore],
        relationship: RelationshipContext
    ) -> Decision {
        let lookup = Dictionary(uniqueKeysWithValues: factors.map { ($0.factor, $0) })
        func s(_ f: HarassmentFactor) -> Int { lookup[f]?.score ?? 0 }

        let power = categoryScores[.power] ?? 0
        let sexual = categoryScores[.sexual] ?? 0
        let moral = categoryScores[.moral] ?? 0
        let other = categoryScores[.other] ?? 0

        // ルール1: 対価型セクハラ最優先（関係性によって発火可否・しきい値変動）
        if relationship.allowsQuotaPairingRule {
            let qpThreshold = relationship.quotaPairingThreshold
            if s(.quotaPairing) >= qpThreshold
                || (s(.sexualContext) >= 30 && (s(.workEvaluation) >= 25 || s(.dominance) >= 25 || s(.academicPower) >= 18))
            {
                var secondary: [HarassmentCategory] = []
                if power >= 35 { secondary.append(.power) }
                if s(.academicPower) >= 20 { secondary.append(.other) }
                return Decision(
                    primary: .sexual,
                    secondary: secondary,
                    subCategories: deriveOtherSub(factors: lookup),
                    rationale: "性的・恋愛的要求と評価/仕事/成績の結合（対価型）を検出。"
                )
            }
        }

        // ルール2: 業務・評価文脈が強い場合はパワハラ優先（関係性で発火可否・しきい値変動）
        if relationship.allowsPowerRule {
            let (workTh, domTh) = relationship.powerRuleThresholds
            if s(.workEvaluation) >= workTh && s(.dominance) >= domTh
                && (s(.personalityDenial) >= 18 || s(.disadvantageThreat) >= 18 || s(.excessiveDemand) >= 18 || s(.existenceDenial) >= 18)
            {
                var secondary: [HarassmentCategory] = []
                if moral >= 50 { secondary.append(.moral) }
                if other >= 50 { secondary.append(.other) }
                return Decision(
                    primary: .power,
                    secondary: secondary,
                    subCategories: deriveOtherSub(factors: lookup),
                    rationale: "業務/評価文脈と立場差を背景に、人格否定・不利益示唆・過大要求のいずれかが強い。"
                )
            }
        }

        // ルール3: 親密関係 + 心理支配 → モラハラ優先
        // 恋人 / 元恋人 / 家族では intimateRelationship 必須を撤廃し、心理支配 factor 単体で発火させる。
        let moralPsycho = max(s(.guiltManipulation), s(.gaslighting), s(.monitoringControl), s(.personalityDenial))
        let moralRuleFires: Bool = {
            if relationship.bypassIntimacyRequirementForMoral {
                return moralPsycho >= relationship.moralRuleSingleFactorThreshold
            }
            return s(.intimateRelationship) >= 20 && moralPsycho >= 18
        }()
        if moralRuleFires {
            var secondary: [HarassmentCategory] = []
            if other >= 50 { secondary.append(.other) }
            return Decision(
                primary: .moral,
                secondary: secondary,
                subCategories: deriveOtherSub(factors: lookup),
                rationale: relationship.bypassIntimacyRequirementForMoral
                    ? "\(relationship.shortName)関係下で、罪悪感操作・ガスライティング・監視のいずれかが立っている。"
                    : "親密関係を背景に、罪悪感操作/ガスライティング/監視のいずれかが強い。"
            )
        }

        // ルール4: 関係性ベースのデフォルト主分類（弱優先）
        // 他ルール非該当時のみ、関係性が示すデフォルトを少しだけ優遇する。
        if let hint = relationship.defaultCategoryHint {
            let hintScore = categoryScores[hint] ?? 0
            let topScore = categoryScores.values.max() ?? 0
            // top - hint <= 15 までならヒントを採用
            if hintScore > 0 && topScore - hintScore <= 15 {
                let secondary = HarassmentCategory.allCases
                    .filter { $0 != hint }
                    .sorted { (categoryScores[$0] ?? 0) > (categoryScores[$1] ?? 0) }
                    .filter { (categoryScores[$0] ?? 0) >= 50 }
                let subs = hint == .other ? deriveOtherSub(factors: lookup) : []
                return Decision(
                    primary: hint,
                    secondary: secondary,
                    subCategories: subs,
                    rationale: "\(relationship.shortName)関係のデフォルト傾向 (\(hint.shortName)) を採用。"
                )
            }
        }

        // 既定: 最大スコアで決定
        let ranked = categoryScores.sorted { $0.value > $1.value }
        let primary = ranked.first?.key ?? .other
        let secondary = ranked.dropFirst().filter { $0.value >= 50 }.map(\.key)
        let subs = primary == .other ? deriveOtherSub(factors: lookup) : []
        _ = sexual // suppress unused-warning if rule1 short-circuits
        return Decision(
            primary: primary,
            secondary: Array(secondary),
            subCategories: subs,
            rationale: "最大スコア分類を採用。"
        )
    }

    /// その他カテゴリのサブ分類を factor から推定
    private func deriveOtherSub(factors: [HarassmentFactor: FactorScore]) -> [HarassmentSubCategory] {
        var subs: [(HarassmentSubCategory, Int)] = []
        if let f = factors[.roleStereotype], f.score >= 20 { subs.append((.gender, f.score)) }
        if let f = factors[.maternityPenalty], f.score >= 18 { subs.append((.maternity, f.score)) }
        if let f = factors[.academicPower], f.score >= 18 { subs.append((.academic, f.score)) }
        if let f = factors[.customerAggression], f.score >= 18 { subs.append((.customer, f.score)) }
        if let f = factors[.alcoholCoercion], f.score >= 18 { subs.append((.alcohol, f.score)) }
        if let f = factors[.monitoringControl], f.score >= 30 { subs.append((.digital, f.score)) }
        if let f = factors[.privacyIntrusion], f.score >= 20 { subs.append((.privacy, f.score)) }
        if let f = factors[.groupExclusion], f.score >= 20 { subs.append((.grouping, f.score)) }
        return subs.sorted { $0.1 > $1.1 }.map(\.0)
    }
}
