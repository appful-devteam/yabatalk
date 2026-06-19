import SwiftUI

/// アプリ全体のカラーパレット。
/// 新規コードでは必ずこの enum 経由で色を参照すること。
/// MeloColors 以外で `Color(hex:)` を直書きしないこと（SwiftLint で警告）。
/// 唯一の例外: ユーザー設定で動的に決まる色を変数経由で渡すケース。
enum MeloColors {

    // MARK: - Brand（レガシー lovetalk 画面用。診断フローは MeloColors.Dark を使う）
    /// メインピンク。フラット用途は Brand.pink、グラデは Gradient.pinkPrimary を使う。
    enum Brand {
        static let pink         = Color(hex: "FF6CB0") // 中間ストップ。フラット代表色
        static let pinkDeep     = Color(hex: "FF62A9") // グラデ start
        static let pinkLight    = Color(hex: "FF78D7") // グラデ end
    }

    // MARK: - Surface
    /// 背景・カード面。
    enum Surface {
        static let white     = Color.white
        static let pinkPale  = Color(hex: "FFE1F0") // ヘッダー背景・選択後ピル背景
        static let card      = Color.white
    }

    // MARK: - Dark（yabatalk 診断フロー専用ダークテーマ: 黒地 × ネオンライム）
    /// 診断 4 画面（Home / Import / Analyzing / Result）はこの名前空間を使う。
    /// レガシー lovetalk 画面は従来の Brand/Surface/Text（ライト）を使い続ける。
    enum Dark {
        // 地・面
        static let bg          = Color(hex: "0C0C0F") // 画面最背面（ほぼ黒）
        static let bgElevated  = Color(hex: "15151B") // ヘッダー/ピル等の一段持ち上げ
        static let card        = Color(hex: "17171F") // カード面
        static let cardStroke  = Color(hex: "2A2A34") // カード境界線
        static let divider     = Color(hex: "24242C")

        // 文字
        static let textPrimary   = Color(hex: "F2F2F5") // 明文字
        static let textSecondary = Color(hex: "9A9AA6") // 副文字（薄め）

        // アクセント = 危険ホットピンク（旧ネオンライムから変更。アプリ全体の主アクセント）
        static let accent       = Color(hex: "FF3B6B") // 主アクセント（数字/バー/選択ピル/見出し/ボタン/タブバー）
        static let accentBright = Color(hex: "FF6B8E") // ハイライト端
        static let accentDeep   = Color(hex: "E5295A") // グラデ濃端
        static let onAccent     = Color(hex: "0C0C0F") // アクセント面の上の文字（黒。ピンク/黄/緑いずれも明るいので黒が読める）

        // severity ramp（毒性の危険度＝データの意味、ブランド accent とは別）: 安全=safe(緑) / 注意=caution(黄) / 危険=danger(ピンク)
        static let safe        = Color(hex: "C6FF2E") // 安全（〜59%）ライムグリーン
        static let safeBright  = Color(hex: "D8FF63")
        static let safeDeep    = Color(hex: "9BE000")
        static let caution     = Color(hex: "FFD23F") // 注意（60–79%）イエロー
        static let danger      = Color(hex: "FF3B6B") // 危険（80%+）ホットピンク（= accent と同色）
        static let dangerDeep  = Color(hex: "E5295A") // 危険グラデ濃端

        /// アクセントグラデ（ボタン/見出し/バー/選択ピル）
        static let accentGradient = LinearGradient(
            colors: [Color(hex: "E5295A"), Color(hex: "FF3B6B"), Color(hex: "FF6B8E")],
            startPoint: .leading,
            endPoint: .trailing
        )
        /// 安全グラデ（緑）— severity 表示用
        static let safeGradient = LinearGradient(
            colors: [Color(hex: "9BE000"), Color(hex: "C6FF2E"), Color(hex: "D8FF63")],
            startPoint: .leading,
            endPoint: .trailing
        )
        /// バーのトラック（未充填部）
        static let track = Color(hex: "23231C")

        // 二者比較（自分 vs 相手）の固定色。スコアタブの相対比較・分割バーで使う。
        // Figma 診断結果リデザイン（node 43:2）の値に合わせる。
        static let selfTint    = Color(hex: "2E93FF") // 自分（ブルー）
        static let partnerTint = Color(hex: "FF2E6B") // 相手（ピンク）
    }

    // MARK: - Text
    /// テキスト用は基本的に primary を使う。secondary もダーク寄りに揃え、
    /// 「一番薄いグレー」は文字色として使わない方針。微妙なニュアンスは .opacity() で調整。
    enum Text {
        static let primary   = Color(hex: "494850")
        /// 旧 #B3B3B3 → 同じ濃さに変更。階層が必要な場面でも .opacity() で表現する。
        static let secondary = Color(hex: "494850")
        static let onPrimary = Color.white
    }

    // MARK: - Gray
    /// サブボタン・divider 用。
    enum Gray {
        static let subButton      = Color(hex: "B3B3B3")
        static let subButtonLight = Color(hex: "F0F0F0")
        static let divider        = Color(hex: "F0F0F0")
    }

    // MARK: - Gradient
    enum Gradient {
        /// メインアクションボタン・ヘッダー/ボディーの境界線
        static let pinkPrimary = LinearGradient(
            stops: [
                .init(color: Color(hex: "FF62A9"), location: 0),
                .init(color: Color(hex: "FF6CB0"), location: 0.35),
                .init(color: Color(hex: "FF78D7"), location: 0.76)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// アンケートのバーハイライトなど、柔らかいピンクグラデ
        static let pinkSoft = LinearGradient(
            stops: [
                .init(color: Color(hex: "FFA2D2"), location: 0),
                .init(color: Color(hex: "FFBEE8"), location: 0.57),
                .init(color: Color(hex: "FFC5EE"), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// 旧 background — pinkPale を使う場合と互換のための単色フェード
        static let background = LinearGradient(
            colors: [Color(hex: "FFE1F0"), Color(hex: "FFE1F0")],
            startPoint: .top,
            endPoint: .bottom
        )

        /// レーダー/グラフでの自分↔相手のピンク↔ブルー
        static let pinkBlue = LinearGradient(
            colors: [Color(hex: "FF6CB0"), Color(hex: "A2DBF7")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Status (機能カラー、例外)
    enum Status {
        static let success      = Color(hex: "4CAF50")
        static let successBg    = Color(hex: "E9F5DC")
        static let warning      = Color(hex: "FFC107")
        static let warningBg    = Color(hex: "FFE08A")
        static let error        = Color(hex: "E5484D")
        static let errorBg      = Color(hex: "FFEDED")
    }

    // MARK: - CTA (アクセント = アシッドライム ☣ "毒"の差し色)
    /// yabatalk アクセントカラー。互換のため case 名は primaryGreen のままだが実体はアシッドライム。
    /// ライムは高輝度なので、この色を背景に敷くボタンの文字色は必ず濃色（Text.primary 等）を使うこと。
    enum CTA {
        /// 診断 CTA ボタン等のアクセント (#B6FF3C)
        static let primaryGreen = Color(hex: "B6FF3C")
        /// ライムグラデ (押し感を出すための濃淡)。濃い側を左に配置。
        static let primaryGreenGradient = LinearGradient(
            colors: [Color(hex: "9EE82A"), Color(hex: "B6FF3C"), Color(hex: "C8FF5E")],
            startPoint: .leading,
            endPoint: .trailing
        )
        /// ライム背景上の濃色文字（コントラスト確保用）。
        static let onLime = Color(hex: "2A1A3C")
    }

    // MARK: - Axis (4軸スコア、例外)
    enum Axis {
        static let volume       = Color(hex: "FF6B9D")
        static let temperature  = Color(hex: "FF8E72")
        static let rhythm       = Color(hex: "8B5CF6")
        static let word         = Color(hex: "3498DB")
    }

    // MARK: - Member (グラフ等の自分↔相手色分け、例外)
    enum Member {
        static let `self`    = Color(hex: "FF6CB0") // = Brand.pink
        static let partner   = Color(hex: "A2DBF7")
        static let partnerBg = Color(hex: "E7F8FF")
    }

    // MARK: - 16タイプ用グラデーション (例外)
    static func typeGradient(for code: String) -> LinearGradient {
        switch code {
        case "BWSF": // おひさまピクニック
            return LinearGradient(colors: [Color(hex: "FFD93D"), Color(hex: "FF8E72")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "BWSL": // ときめきパレード
            return LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "FF8FAF")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "BWJF": // 夏祭りフィーバー
            return LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FFA500")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "BWJL": // 雨あがりレスキュー
            return LinearGradient(colors: [Color(hex: "74B9FF"), Color(hex: "A29BFE")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "BCSF": // そよ風テラス
            return LinearGradient(colors: [Color(hex: "81ECEC"), Color(hex: "74B9FF")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "BCSL": // 深夜のハイウェイ
            return LinearGradient(colors: [Color(hex: "2D3436"), Color(hex: "636E72")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "BCJF": // きまぐれシャボン玉
            return LinearGradient(colors: [Color(hex: "A29BFE"), Color(hex: "FD79A8")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "BCJL": // 冬のサイレンスエスケープ
            return LinearGradient(colors: [Color(hex: "DFE6E9"), Color(hex: "B2BEC3")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UWSF": // ひまわりサポーター
            return LinearGradient(colors: [Color(hex: "FDCB6E"), Color(hex: "F39C12")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UWSL": // ロマンチックレイン
            return LinearGradient(colors: [Color(hex: "74B9FF"), Color(hex: "A29BFE")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UWJF": // 花火オールナイト
            return LinearGradient(colors: [Color(hex: "E74C3C"), Color(hex: "F39C12")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UWJL": // おかえりコール
            return LinearGradient(colors: [Color(hex: "FFB366"), Color(hex: "FF8E72")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UCSF": // カフェソロデート
            return LinearGradient(colors: [Color(hex: "DFE6E9"), Color(hex: "9B6FD0")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UCSL": // ミステリーシネマ
            return LinearGradient(colors: [Color(hex: "2C3E50"), Color(hex: "4A69BD")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UCJF": // 運命のルーレット
            return LinearGradient(colors: [Color(hex: "E74C3C"), Color(hex: "9B59B6")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "UCJL": // 星空のモノローグ
            return LinearGradient(colors: [Color(hex: "2C3E50"), Color(hex: "6C5CE7")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return Gradient.pinkPrimary
        }
    }

    // MARK: - MBTI 4 グループ色 (例外)
    static func mbtiColor(for code: String) -> Color {
        let upper = code.uppercased()
        if upper.contains("N") && upper.contains("T") { return Color(hex: "C9A0FF") } // Analysts (NT)
        if upper.contains("N") && upper.contains("F") { return Color(hex: "7ED6B0") } // Diplomats (NF)
        if upper.contains("S") && upper.contains("J") { return Color(hex: "97DBFF") } // Sentinels (SJ)
        if upper.contains("S") && upper.contains("P") { return Color(hex: "FFB07A") } // Explorers (SP)
        return Color(hex: "FF80D0")
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
