import Foundation

/// 可愛い / 毒舌タイプ名 + 対応ハラスメントカテゴリ
struct HarassmentType: Identifiable, Codable, Hashable, Sendable {
    let id: String                              // 固定 ID（例: "indoctrination_devil"）
    let emoji: String
    let typeName: String
    let primaryCategories: [HarassmentCategory] // 対応ハラスメント（1〜2 個）
    let subCategories: [HarassmentSubCategory]  // その他カテゴリ詳細（あれば）
    let structureSummary: String                // 「主な構造」
    let catchCopyTemplates: [String]            // ランダム選択用
    let triggerFactors: [HarassmentFactor]      // このタイプを示す factor 群（profile 照合用）
    let darkHumorAdvice: String                 // 最後の一言

    var displayCategories: String {
        primaryCategories.map(\.shortName).joined(separator: " / ")
    }
}
