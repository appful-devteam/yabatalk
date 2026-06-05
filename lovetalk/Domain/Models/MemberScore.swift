import Foundation
import SwiftUI

// MARK: - Member Score
/// グループチャットにおける個人別4軸スコア
struct MemberScore: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let memberName: String
    let balanceScore: Double
    let tensionScore: Double
    let responseScore: Double
    let wordScore: Double

    init(
        id: UUID = UUID(),
        memberName: String,
        balanceScore: Double,
        tensionScore: Double,
        responseScore: Double,
        wordScore: Double
    ) {
        self.id = id
        self.memberName = memberName
        self.balanceScore = balanceScore
        self.tensionScore = tensionScore
        self.responseScore = responseScore
        self.wordScore = wordScore
    }

    var normalizedValues: [Double] {
        [
            balanceScore / 100,
            tensionScore / 100,
            responseScore / 100,
            wordScore / 100
        ]
    }
}

// MARK: - Member Colors
enum MemberColors {
    /// 自分は常にピンク
    static let selfColor = MeloColors.Brand.pinkLight
    /// 相手（1on1）はブルー
    static let partnerColor = MeloColors.Member.partner

    /// 3人目以降のパレット（自分=ピンク、相手=ブルー の次から使用）
    private static let extraPalette: [Color] = [
        MeloColors.Brand.pinkLight,  // ピーチオレンジ
        MeloColors.Brand.pinkLight,  // ラベンダー
        MeloColors.Status.success,  // ミントグリーン
        MeloColors.Status.warning,  // ハニーイエロー
        MeloColors.Brand.pinkLight,  // ローズピンク
        MeloColors.Member.partner,  // スカイブルー
        MeloColors.Brand.pink,  // モーブピンク
        MeloColors.Status.success,  // セージグリーン
    ]

    /// メンバー名リストと自分の名前から、一貫した色を返す
    static func color(for memberName: String, selfName: String, allMembers: [String]) -> Color {
        if memberName == selfName {
            return selfColor
        }
        // 自分を除いたメンバーリスト（元の順序を維持）
        let others = allMembers.filter { $0 != selfName }
        guard let idx = others.firstIndex(of: memberName) else {
            return partnerColor
        }
        if idx == 0 {
            return partnerColor
        }
        return extraPalette[(idx - 1) % extraPalette.count]
    }

    /// 後方互換: インデックスベース（自分=0, 相手=1, ...）
    static func color(for index: Int) -> Color {
        switch index {
        case 0: return selfColor
        case 1: return partnerColor
        default: return extraPalette[(index - 2) % extraPalette.count]
        }
    }
}

// MARK: - Member Phrase Analysis
struct MemberPhraseAnalysis: Codable, Equatable, Identifiable {
    var id: String { memberName }
    let memberName: String
    let topPhrases: [PhraseCount]
}

// MARK: - Member Love Words Entry
struct MemberLoveWordsEntry: Codable, Equatable, Identifiable {
    var id: String { memberName }
    let memberName: String
    let loveWords: [PhraseCount]
    let totalCount: Int
}
