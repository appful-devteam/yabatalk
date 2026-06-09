import SwiftUI

// MARK: - 毒性鑑定書（ラボ）デザインキット
// Figma "毒性ラボ鑑定書" デザインの共通部品。絵文字は使わずベクター/コード/計器で表現する。
// 色は MeloColors.Dark（黒地×ネオンライム＋severity ramp）、書体は Anton(計器) / RobotoMono(コード) / ZenMaru(本文)。

// MARK: - マスコット（キャラ配置）

/// タブ毎に切り替わるキャラのポーズ名。
/// ※現状は既存の透過キャラアセットを暫定使用。最新キャラのポーズ生成が揃ったら
///   この name を差し替えるだけで全配置に反映される。
enum LabMascot {
    /// ハラスメントーク最新キャラ（アプリアイコンの怒り青／不安ピンク）を円形クロップした顔アバター。
    /// 青 = 加害/毒の威圧、ピンク = 受け手の不安。タブ切替で交互に変える。
    static let blue = "mascot_blue"
    static let pink = "mascot_pink"

    /// タブ毎のキャラ（タブ切替で変化）。
    static func pose(for tab: DiagnosisTab) -> String {
        switch tab {
        case .score:   return blue
        case .type:    return pink
        case .data:    return blue
        case .summary: return pink
        }
    }
    /// 鑑定結果カード右に置くキャラ（毒＝青）。
    static let verdictPose = blue
    /// TYPE のタイプ・プレートに置くキャラ（青）。
    static let typePlate = blue
}

/// 円形アバター（PNG は円形クロップ済み・透過）。
struct MascotImage: View {
    let name: String
    var size: CGFloat
    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// TYPE のタイプ・プレート（severity リング付きの円形キャラ）。
struct MascotPlate: View {
    var name: String
    var color: Color
    var size: CGFloat = 64

    var body: some View {
        MascotImage(name: name, size: size)
            .background(Circle().fill(MeloColors.Dark.bg))
            .clipShape(Circle())
            .overlay(Circle().stroke(color, lineWidth: 2))
    }
}

// MARK: severity / 分類コード

/// 毒性%を severity 色に（安全=safe / 注意=caution / 危険=danger）。
func labSeverityColor(_ pct: Int) -> Color {
    if pct >= 80 { return MeloColors.Dark.danger }
    if pct >= 60 { return MeloColors.Dark.caution }
    return MeloColors.Dark.safe
}

extension DiagnosisResult {
    /// 鑑定書の日付表記（yyyy.MM.dd）。
    var labDateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: createdAt)
    }
    /// 検体番号（YT-MMdd）。
    var labSpecimenNo: String {
        let f = DateFormatter()
        f.dateFormat = "MMdd"
        return "YT-\(f.string(from: createdAt))"
    }
}

extension HarassmentCategory {
    /// ラボ分類コード（絵文字の代わり）。
    var labCode: String {
        switch self {
        case .power:  return "PWR"
        case .sexual: return "SEX"
        case .moral:  return "MRL"
        case .other:  return "ETC"
        }
    }
}

extension RiskLevel {
    /// 鑑定結果の severity 色（計器の数字・液色）。
    var labColor: Color {
        switch self {
        case .low:     return MeloColors.Dark.safe
        case .caution: return MeloColors.Dark.caution
        case .medium:  return MeloColors.Dark.caution
        case .high:    return MeloColors.Dark.danger
        case .severe:  return MeloColors.Dark.danger
        }
    }
    /// DANGER Lv.N の N。
    var labLevel: Int {
        switch self {
        case .low: return 1
        case .caution: return 2
        case .medium: return 3
        case .high: return 4
        case .severe: return 5
        }
    }
}

// MARK: - ハザード斜線ストライプ

struct HazardStripe: View {
    var color: Color
    var height: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            let stripeW: CGFloat = 6
            let step: CGFloat = 16
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + stripeW, y: 0))
                p.addLine(to: CGPoint(x: x + stripeW, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
                x += step
            }
        }
        .frame(height: height)
        .background(color.opacity(0.15))
        .clipped()
    }
}

// MARK: - 試験管メーター（毒性メーター）

struct TestTubeGauge: View {
    var pct: Int          // 0-100
    var color: Color      // 液色（severity）

    private let tubeW: CGFloat = 44
    private let tubeH: CGFloat = 158
    private var tubeShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 22,
                               bottomTrailingRadius: 22, topTrailingRadius: 8, style: .continuous)
    }

    var body: some View {
        let filled = tubeH * CGFloat(min(max(pct, 0), 100)) / 100

        HStack(spacing: 6) {
            ZStack(alignment: .top) {
                // 注ぎ口リップ
                RoundedRectangle(cornerRadius: 3)
                    .fill(MeloColors.Dark.accent)
                    .frame(width: 34, height: 7)
                    .zIndex(2)

                // 管本体
                tubeShape
                    .fill(MeloColors.Dark.bg)
                    .frame(width: tubeW, height: tubeH)
                    .overlay(alignment: .bottom) {
                        ZStack(alignment: .top) {
                            Rectangle().fill(color)
                            // 泡
                            HStack {
                                Circle().fill(MeloColors.Dark.bg.opacity(0.45)).frame(width: 7, height: 7)
                                    .offset(x: 2, y: 12)
                                Spacer()
                                Circle().fill(MeloColors.Dark.bg.opacity(0.4)).frame(width: 4, height: 4)
                                    .offset(x: -4, y: 26)
                            }
                        }
                        .frame(height: filled)
                    }
                    .clipShape(tubeShape)
                    .overlay(tubeShape.stroke(MeloColors.Dark.accent, lineWidth: 2))
                    .padding(.top, 6)
            }
            .frame(width: tubeW)

            // 目盛り
            VStack(spacing: 22) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle().fill(MeloColors.Dark.textSecondary).frame(width: 7, height: 2)
                }
            }
            .padding(.top, 24)
        }
        .frame(height: 176)
    }
}

// MARK: - 濃度ドット（成分の severity 表示）

struct SeverityDots: View {
    var pct: Int
    var color: Color

    var body: some View {
        let n = Int((Double(pct) / 20).rounded())
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < n ? color : MeloColors.Dark.track)
                    .frame(width: 6, height: 6)
                    .overlay {
                        if i >= n {
                            Circle().stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                        }
                    }
            }
        }
    }
}

// MARK: - コードチップ

/// 小さなモノスペースのコードタグ（[人格否定] / [PWR] / 時刻 等）。
struct LabCodeChip: View {
    var text: String
    var color: Color
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(MeloFonts.monoMedium(10))
            .foregroundColor(filled ? MeloColors.Dark.onAccent : color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(filled ? color : MeloColors.Dark.bg)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(color, lineWidth: filled ? 0 : 1))
            )
    }
}

/// 分類タグ（PWR/SEX/MRL/ETC）— 一定幅のスクエア。
struct LabCategoryTag: View {
    var code: String
    var color: Color

    var body: some View {
        Text(code)
            .font(MeloFonts.monoMedium(10))
            .foregroundColor(color)
            .frame(width: 36, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(MeloColors.Dark.bg)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(color, lineWidth: 1.5))
            )
    }
}

// MARK: - 疑似バーコード

struct LabBarcode: View {
    private let widths: [CGFloat] = [2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2,
                                     1, 1, 3, 1, 2, 2, 1, 3, 1, 1, 2, 1, 2, 3, 1]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(widths.enumerated()), id: \.offset) { i, w in
                Rectangle()
                    .fill(i % 5 == 0 ? MeloColors.Dark.textSecondary : MeloColors.Dark.textPrimary)
                    .frame(width: w, height: 26)
            }
        }
    }
}

// MARK: - 進捗バー（severity 色）

struct LabBar: View {
    var pct: Int
    var color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(MeloColors.Dark.track)
                Capsule().fill(color)
                    .frame(width: max(5, proxy.size.width * CGFloat(min(max(pct, 0), 100)) / 100))
            }
        }
        .frame(height: height)
    }
}

// MARK: - カード

/// 役割別カードの基本形（任意でハザード上辺）。
struct LabCard<Content: View>: View {
    var hazardColor: Color? = nil
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if let hz = hazardColor {
                HazardStripe(color: hz, height: 8)
            }
            content()
                .padding(padding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeloColors.Dark.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
        )
        .shadow(color: MeloColors.Dark.accent.opacity(0.12), radius: 8, x: 0, y: 2)
    }
}

/// カード見出し（日本語 + 英語ラベル）。
struct LabCardHeader: View {
    var jp: String
    var en: String

    var body: some View {
        HStack(spacing: 8) {
            Text(jp)
                .font(MeloFonts.zenMaru(15))
                .foregroundColor(MeloColors.Dark.textPrimary)
            Spacer(minLength: 8)
            Text(en)
                .font(MeloFonts.mono(9))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .tracking(1)
        }
    }
}

/// 凹んだ証拠ウェル（根拠サンプル等）。
struct LabWell<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(MeloColors.Dark.bg)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(MeloColors.Dark.cardStroke, lineWidth: 1))
            )
    }
}

/// セクション見出し（タブ内の "検体プロファイル" 等の大見出し）。
struct LabSectionTitle: View {
    var jp: String
    var en: String
    var body: some View {
        VStack(spacing: 4) {
            Text(jp)
                .font(MeloFonts.anton(24))
                .foregroundColor(MeloColors.Dark.textPrimary)
            Text(en)
                .font(MeloFonts.mono(10))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
    }
}
