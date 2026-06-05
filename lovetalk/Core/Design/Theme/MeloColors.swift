import SwiftUI

/// アプリ全体のカラーパレット。
/// 新規コードでは必ずこの enum 経由で色を参照すること。
/// MeloColors 以外で `Color(hex:)` を直書きしないこと（SwiftLint で警告）。
/// 唯一の例外: ユーザー設定で動的に決まる色を変数経由で渡すケース。
enum MeloColors {

    // MARK: - Brand
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

    // MARK: - CTA (アクセントとして使う緑)
    enum CTA {
        /// 診断するページの「LINE相性診断をはじめる」ボタン用 (#48D300)
        static let primaryGreen = Color(hex: "48D300")
        /// 緑グラデ (押し感を出すための濃淡)。濃い側を左に配置、全体を少し明るめに調整。
        static let primaryGreenGradient = LinearGradient(
            colors: [Color(hex: "4FC500"), Color(hex: "5BDC10"), Color(hex: "73EE2E")],
            startPoint: .leading,
            endPoint: .trailing
        )
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
