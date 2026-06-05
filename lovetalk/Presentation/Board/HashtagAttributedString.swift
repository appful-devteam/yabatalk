import SwiftUI

/// 投稿本文中の `#xxxx` をタップ可能にする AttributedString ビルダ。
/// タップ時は `.openHashtagSearch` Notification を `object: <タグ名>` で post する。
/// ハッシュタグは独自スキーム `merotalk://hashtag/<encoded>` の URL link として埋め込み、
/// 表示側は `.environment(\.openURL, ...)` でハンドリングする。
enum HashtagAttributedString {

    /// 本文をハッシュタグ link 付き AttributedString に変換する。
    /// - Parameters:
    ///   - text: 投稿本文 (生文字列)
    ///   - bodyColor: ハッシュタグ以外の文字色
    ///   - hashtagColor: ハッシュタグの文字色 (link でも色を維持するため明示)
    static func make(
        text: String,
        bodyColor: Color,
        hashtagColor: Color,
        mentionColor: Color? = nil
    ) -> AttributedString {
        var result = AttributedString()
        let tokens = tokenize(text)
        for token in tokens {
            var part = AttributedString(token.text)
            switch token.kind {
            case .hashtag:
                part.foregroundColor = hashtagColor
                let raw = token.text.trimmingCharacters(in: CharacterSet(charactersIn: "#＃"))
                if !raw.isEmpty,
                   let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "merotalk://hashtag/\(encoded)") {
                    part.link = url
                }
            case .mention:
                // mentionColor が指定されない場合は hashtagColor を再利用 (見た目を揃える)。
                part.foregroundColor = mentionColor ?? hashtagColor
            case .body:
                part.foregroundColor = bodyColor
            }
            result += part
        }
        return result
    }

    private enum TokenKind {
        case body, hashtag, mention
    }

    private struct Token {
        let text: String
        let kind: TokenKind
    }

    private static func tokenize(_ text: String) -> [Token] {
        var result: [Token] = []
        let separators = CharacterSet.whitespacesAndNewlines
        var buffer = ""
        var kind: TokenKind = .body
        for ch in text {
            let s = String(ch)
            if s.unicodeScalars.allSatisfy({ separators.contains($0) }) {
                if !buffer.isEmpty {
                    result.append(Token(text: buffer, kind: kind))
                    buffer = ""
                    kind = .body
                }
                result.append(Token(text: s, kind: .body))
            } else if ch == "#" || ch == "#" {
                if !buffer.isEmpty {
                    result.append(Token(text: buffer, kind: kind))
                    buffer = ""
                }
                kind = .hashtag
                buffer.append(ch)
            } else if ch == "@" || ch == "@" {
                if !buffer.isEmpty {
                    result.append(Token(text: buffer, kind: kind))
                    buffer = ""
                }
                kind = .mention
                buffer.append(ch)
            } else {
                buffer.append(ch)
            }
        }
        if !buffer.isEmpty {
            result.append(Token(text: buffer, kind: kind))
        }
        return result
    }
}

/// 投稿カードの本文用 modifier。
/// `.environment(\.openURL)` でハッシュタグ link をキャッチし `.openHashtagSearch` を post する。
struct HashtagOpenURLModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "merotalk", url.host == "hashtag" else {
                    return .systemAction
                }
                let tag = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
                if !tag.isEmpty {
                    HapticManager.light()
                    NotificationCenter.default.post(name: .openHashtagSearch, object: tag)
                }
                return .handled
            })
    }
}

extension View {
    func handlesHashtagTap() -> some View {
        modifier(HashtagOpenURLModifier())
    }
}
