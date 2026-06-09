import SwiftUI

// MARK: - 毒性鑑定書カード（再利用ビュー）
//
// `DiagnosisScoreTab.verdictCard`（鑑定結果カード）を再利用可能なビューに切り出したもの。
// 掲示板への添付カード（`.toxicity` スタイル）と診断結果画面の双方から使う。
// 入力は素のフィールド（DiagnosisCard / DiagnosisResult のどちらからも渡せる）。
// 黒地×severity 色の LabKit トークン/部品のみ使用（新色は発明しない）。
struct ToxicityVerdictCardView: View {
    let score: Int              // 総合毒性スコア 0-100
    let level: RiskLevel
    let dangerLabel: String
    let catchCopy: String
    let categoryCode: String    // PWR/SEX/MRL/ETC
    let specimenNo: String      // 検体番号 "YT-MMdd"
    /// feed の縮小表示用。試験管を小さくし一部要素を省略して高さを抑える。
    var compact: Bool = false
    /// 掲示板添付カード用: 選んだ関係性名（例「彼氏」）。マスコットの上に表示。結果画面では nil。
    var relationshipLabel: String? = nil
    /// 掲示板添付カード用: 選んだ相手MBTI（例「INTJ」）。関係性名の下に表示。結果画面では nil。
    var mbti: String? = nil

    // MARK: - 便利イニシャライザ

    /// 保存済み診断結果から生成。
    init(result: DiagnosisResult, compact: Bool = false) {
        self.score = result.overallRiskScore
        self.level = result.riskLevel
        self.dangerLabel = result.dangerLabel
        self.catchCopy = result.catchCopy
        self.categoryCode = result.primaryCategory.labCode
        self.specimenNo = result.labSpecimenNo
        self.compact = compact
    }

    /// 掲示板カード（DiagnosisCard の毒性フィールド）から生成。
    init(card: DiagnosisCard, compact: Bool = false) {
        self.score = card.toxicityScore ?? 0
        self.level = card.toxicityRiskLevel
        self.dangerLabel = card.toxicityDangerLabel ?? ""
        self.catchCopy = card.toxicityCatchCopy ?? ""
        self.categoryCode = card.toxicityCategoryCode ?? "ETC"
        self.specimenNo = card.toxicitySpecimenNo ?? "YT-0000"
        self.compact = compact
        self.relationshipLabel = card.relationshipLabel
        self.mbti = card.partnerMBTIs?.first ?? card.partnerMBTI
    }

    /// 明示フィールドから生成。
    init(score: Int, level: RiskLevel, dangerLabel: String, catchCopy: String,
         categoryCode: String, specimenNo: String, compact: Bool = false) {
        self.score = score
        self.level = level
        self.dangerLabel = dangerLabel
        self.catchCopy = catchCopy
        self.categoryCode = categoryCode
        self.specimenNo = specimenNo
        self.compact = compact
    }

    var body: some View {
        let color = level.labColor
        return LabCard(hazardColor: color, padding: 16) {
            VStack(spacing: compact ? 10 : 14) {
                // 上部ラベル行
                HStack {
                    Text("鑑定結果")
                        .font(MeloFonts.monoMedium(11))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                    Spacer()
                    Text("DIAGNOSIS")
                        .font(MeloFonts.mono(9))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .tracking(1)
                }

                HStack(alignment: .center, spacing: compact ? 12 : 16) {
                    if !compact {
                        TestTubeGauge(pct: score, color: color)
                    }

                    VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                        Text("総合毒性スコア")
                            .font(MeloFonts.monoMedium(11))
                            .foregroundColor(MeloColors.Dark.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(score)")
                                .font(MeloFonts.anton(compact ? 44 : 64))
                                .foregroundColor(color)
                            Text("%")
                                .font(MeloFonts.anton(compact ? 20 : 26))
                                .foregroundColor(color)
                        }

                        HStack(spacing: 8) {
                            Text(dangerLabel)
                                .font(MeloFonts.zenMaru(12))
                                .foregroundColor(MeloColors.Dark.onAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(color))
                            Text("DANGER Lv.\(level.labLevel)")
                                .font(MeloFonts.monoMedium(10))
                                .foregroundColor(color)
                        }

                        if !catchCopy.isEmpty {
                            Text(catchCopy)
                                .font(MeloFonts.zenMaruRegular(13))
                                .foregroundColor(MeloColors.Dark.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(compact ? 2 : nil)
                        }
                    }

                    Spacer(minLength: 4)
                    if !compact {
                        VStack(spacing: 3) {
                            if let relationshipLabel, !relationshipLabel.isEmpty {
                                Text(relationshipLabel)
                                    .font(MeloFonts.zenMaru(13))
                                    .foregroundColor(MeloColors.Dark.textPrimary)
                                    .lineLimit(1)
                            }
                            if let mbti, !mbti.isEmpty {
                                Text(mbti)
                                    .font(MeloFonts.monoMedium(11))
                                    .foregroundColor(level.labColor)
                                    .tracking(0.5)
                                    .lineLimit(1)
                            }
                            MascotImage(name: LabMascot.verdictPose, size: 66)
                        }
                        .fixedSize()
                    }
                }

                // 下部：疑似バーコード + 検体番号
                HStack(alignment: .center, spacing: 10) {
                    LabBarcode()
                    Spacer()
                    Text("\(specimenNo)-\(categoryCode)")
                        .font(MeloFonts.mono(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }
            }
        }
    }
}
