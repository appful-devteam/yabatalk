import Foundation

/// コンパイル済み `NSRegularExpression` を **pattern 文字列 + case-sensitivity 毎に一度だけ**
/// コンパイルしてキャッシュする純粋な最適化レイヤ。
///
/// 診断エンジンは同一の正規表現パターンを「メッセージ数 × ルール数 × 周辺パターン」で
/// 数百万〜数千万回マッチさせる。従来は `String.range(of:options:.regularExpression)` や
/// 毎回の `NSRegularExpression(pattern:)` がその度に regex を再コンパイルしており致命的に遅かった。
/// 本キャッシュはコンパイル結果を再利用し、**マッチ挙動は一切変えずコンパイル回数だけ削減** する。
///
/// 挙動互換性の担保:
/// - `String.range(of:options:.regularExpression)` と同じ ICU 正規表現エンジン（`NSRegularExpression`）を使用。
/// - `.caseInsensitive`（String.CompareOptions）↔ `NSRegularExpression.Options.caseInsensitive` をマップ。
/// - NSRange ↔ String.Index 変換は NSString 長基準（`(text as NSString).length` / `Range(_:in:)`）で行う。
/// - 不正パターン・空パターンは `nil` / `false`（既存の `try?` と同じ安全側挙動）。
///
/// `@unchecked Sendable`: 内部状態（辞書）は `NSLock` で直列化し、格納する
/// `NSRegularExpression` はコンパイル後イミュータブルでマッチ操作はスレッドセーフ。
final class RegexCache: @unchecked Sendable {

    /// プロセス共有のシングルトン。
    static let shared = RegexCache()

    private let lock = NSLock()
    /// キーは case-sensitivity を含める（"i:" = case-insensitive / "s:" = sensitive）。
    private var cache: [String: NSRegularExpression] = [:]

    private init() {}

    /// コンパイル済み `NSRegularExpression` を返す（キャッシュ。空・不正パターンは `nil`）。
    ///
    /// 全マッチ列挙やキャプチャグループ抽出（`firstMatch` / `matches(in:)`）が必要な呼び出し側は
    /// このメソッドで regex 本体を取得して使う。
    func regex(_ pattern: String, caseInsensitive: Bool = false) -> NSRegularExpression? {
        guard !pattern.isEmpty else { return nil }
        let key = (caseInsensitive ? "i:" : "s:") + pattern

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[key] { return cached }

        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let compiled = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        cache[key] = compiled
        return compiled
    }

    /// 先頭マッチの範囲を `Range<String.Index>` で返す。
    /// `text.range(of: pattern, options: .regularExpression)`（+条件付き `.caseInsensitive`）と互換。
    /// マッチ無し・空/不正パターンは `nil`。
    func firstMatchRange(_ pattern: String, in text: String, caseInsensitive: Bool = false) -> Range<String.Index>? {
        guard let regex = regex(pattern, caseInsensitive: caseInsensitive) else { return nil }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, range: fullRange),
              match.range.location != NSNotFound else {
            return nil
        }
        return Range(match.range, in: text)
    }

    /// マッチするかどうか。`text.range(of: pattern, options: .regularExpression) != nil` と互換。
    func matches(_ pattern: String, in text: String, caseInsensitive: Bool = false) -> Bool {
        firstMatchRange(pattern, in: text, caseInsensitive: caseInsensitive) != nil
    }
}
