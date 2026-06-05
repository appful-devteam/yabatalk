import Foundation

// MARK: - Chat Language
/// トーク履歴の言語（UIの表示言語とは独立）
enum ChatLanguage: String, Codable {
    case japanese
    case english
    case spanish
    case korean
    case chinese

    /// テキストメッセージの内容からトーク履歴の言語を自動検出
    static func detect(from messages: [ChatMessage]) -> ChatLanguage {
        let textMessages = messages.filter { $0.eventType == .text }
        let sampleSize = min(textMessages.count, 200)
        guard sampleSize > 0 else { return .japanese }

        var hiraganaKatakana = 0
        var hangul = 0
        var cjk = 0
        var latin = 0
        var spanishIndicators = 0

        for msg in textMessages.prefix(sampleSize) {
            let content = msg.content
            for scalar in content.unicodeScalars {
                switch scalar.value {
                case 0x3040...0x309F, 0x30A0...0x30FF:
                    hiraganaKatakana += 1
                case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F:
                    hangul += 1
                case 0x4E00...0x9FFF:
                    cjk += 1
                case 0x0041...0x007A, 0x00C0...0x024F:
                    latin += 1
                default:
                    break
                }
            }
            // スペイン語固有の記号・パターン
            let lower = content.lowercased()
            if lower.contains("¿") || lower.contains("¡") || lower.contains("ñ") {
                spanishIndicators += 1
            }
        }

        // ひらがな/カタカナがあれば日本語（漢字だけでは中国語と区別不可）
        if hiraganaKatakana > 0 { return .japanese }
        // ハングル
        if hangul > cjk && hangul > latin { return .korean }
        // CJK（ひらがな/カタカナなし）= 中国語
        if cjk > latin { return .chinese }
        // スペイン語
        if spanishIndicators > 0 || detectSpanishWords(messages: textMessages.prefix(sampleSize)) {
            return .spanish
        }
        // デフォルト: 英語
        return .english
    }

    /// AppLanguage（UI表示言語）からChatLanguageへ変換
    static func from(appLanguage: AppLanguage) -> ChatLanguage {
        switch appLanguage {
        case .ja: return .japanese
        case .en: return .english
        case .es: return .spanish
        case .ko: return .korean
        case .zhHans: return .chinese
        }
    }

    /// スペイン語の頻出単語でスペイン語を判定
    private static func detectSpanishWords(messages: some Collection<ChatMessage>) -> Bool {
        let spanishMarkers = ["hola", "gracias", "buenos días", "buenas noches",
                              "te quiero", "te amo", "cómo estás", "también",
                              "por favor", "perdón", "lo siento"]
        var hitCount = 0
        for msg in messages.prefix(100) {
            let lower = msg.content.lowercased()
            for marker in spanishMarkers {
                if lower.contains(marker) {
                    hitCount += 1
                    break
                }
            }
        }
        return hitCount >= 3
    }
}
