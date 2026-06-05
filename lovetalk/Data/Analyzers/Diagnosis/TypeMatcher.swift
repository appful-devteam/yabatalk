import Foundation

/// 主分類 + factor プロファイルから最も適合するタイプを選ぶ
/// 関係性プリオール (spec §6) によって候補プールから除外されるタイプがある。
struct TypeMatcher: Sendable {

    struct Selection: Sendable {
        let primary: HarassmentType
        let secondary: [HarassmentType]
    }

    /// 関係性なしの後方互換 API。
    func match(
        primaryCategory: HarassmentCategory,
        secondaryCategories: [HarassmentCategory],
        subCategories: [HarassmentSubCategory],
        factors: [FactorScore]
    ) -> Selection {
        match(
            primaryCategory: primaryCategory,
            secondaryCategories: secondaryCategories,
            subCategories: subCategories,
            factors: factors,
            relationship: .unknown
        )
    }

    func match(
        primaryCategory: HarassmentCategory,
        secondaryCategories: [HarassmentCategory],
        subCategories: [HarassmentSubCategory],
        factors: [FactorScore],
        relationship: RelationshipContext
    ) -> Selection {
        let lookup = Dictionary(uniqueKeysWithValues: factors.map { ($0.factor, $0.score) })

        let baseCandidates: [HarassmentType]
        if primaryCategory == .other, let firstSub = subCategories.first {
            // その他はサブ分類で絞る
            let subFiltered = HarassmentTypeCatalog.all.filter { $0.subCategories.contains(firstSub) }
            baseCandidates = subFiltered.isEmpty
                ? HarassmentTypeCatalog.types(matching: .other)
                : subFiltered
        } else {
            baseCandidates = HarassmentTypeCatalog.types(matching: primaryCategory)
        }

        // 関係性フィルタを適用（pool が空にならないようフォールバック付き）
        let relationshipFiltered = baseCandidates.filter { relationship.includesType($0) }
        let candidates = relationshipFiltered.isEmpty ? baseCandidates : relationshipFiltered

        // それでも空なら全体から関係性フィルタを通す。最後の砦は all。
        let pool: [HarassmentType]
        if !candidates.isEmpty {
            pool = candidates
        } else {
            let fallback = HarassmentTypeCatalog.all.filter { relationship.includesType($0) }
            pool = fallback.isEmpty ? HarassmentTypeCatalog.all : fallback
        }

        let ranked = pool
            .map { type in (type: type, score: profileScore(type: type, lookup: lookup)) }
            .sorted { $0.score > $1.score }

        let primary = ranked.first?.type ?? pool.first ?? HarassmentTypeCatalog.all.first!
        let secondary = ranked.dropFirst().prefix(2).map(\.type).filter { $0.id != primary.id }
        return Selection(primary: primary, secondary: Array(secondary))
    }

    /// type の triggerFactors と現状 factor スコアのマッチ度。
    /// 平均ではなく「合計 × カバレッジ」を使うことで、
    /// trigger 数が少ない type が自動有利になる偏りを排除する。
    /// さらに trigger 数 < 3 の type には軽いペナルティを掛け、
    /// trigger が 1 個でも 0 なら大きく減点する（必須要件感を担保）。
    private func profileScore(type: HarassmentType, lookup: [HarassmentFactor: Int]) -> Double {
        guard !type.triggerFactors.isEmpty else { return 0 }
        let scores = type.triggerFactors.map { Double(lookup[$0] ?? 0) }
        let sum = scores.reduce(0, +)
        let positiveCount = scores.filter { $0 > 0 }.count
        let coverage = Double(positiveCount) / Double(type.triggerFactors.count)
        let fewTriggerPenalty: Double = type.triggerFactors.count <= 2 ? 0.75 : 1.0
        // どれか 1 個でも 0 なら、coverage が 1 未満になり罰される。
        // trigger 全部が出てる type が最強、というシンプルな構造に。
        return sum * coverage * fewTriggerPenalty
    }
}
