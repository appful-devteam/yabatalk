import SwiftUI

// MARK: - Custom Font Registry
enum MeloFonts {
    /// Jersey 10 — ピクセル風スコア数字用
    static func jersey(_ size: CGFloat) -> Font {
        .custom("Jersey10-Regular", size: size)
    }

    /// Zen Maru Gothic Bold — 丸みのある日本語テキスト用（見出し・強調）
    static func zenMaru(_ size: CGFloat) -> Font {
        .custom("ZenMaruGothic-Bold", size: size)
    }

    /// フォールバック付き Jersey（フォント未ロード時のセーフティ）
    static func jerseyOrFallback(_ size: CGFloat) -> Font {
        if UIFont(name: "Jersey10-Regular", size: size) != nil {
            return .custom("Jersey10-Regular", size: size)
        }
        return .system(size: size, weight: .black, design: .rounded)
    }

    /// フォールバック付き Zen Maru Gothic Bold（見出し・強調テキスト）
    static func zenMaruOrFallback(_ size: CGFloat) -> Font {
        if LanguageManager.isJapanese,
           UIFont(name: "ZenMaruGothic-Bold", size: size) != nil {
            return .custom("ZenMaruGothic-Bold", size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }

    /// フォールバック付き Zen Maru Gothic Regular（本文・通常テキスト）
    static func zenMaruRegular(_ size: CGFloat) -> Font {
        if LanguageManager.isJapanese,
           UIFont(name: "ZenMaruGothic-Regular", size: size) != nil {
            return .custom("ZenMaruGothic-Regular", size: size)
        }
        return .system(size: size, weight: .regular, design: .rounded)
    }

    /// フォールバック付き Zen Maru Gothic Medium（中間ウェイト）
    static func zenMaruMedium(_ size: CGFloat) -> Font {
        if LanguageManager.isJapanese,
           UIFont(name: "ZenMaruGothic-Medium", size: size) != nil {
            return .custom("ZenMaruGothic-Medium", size: size)
        }
        return .system(size: size, weight: .medium, design: .rounded)
    }
}
