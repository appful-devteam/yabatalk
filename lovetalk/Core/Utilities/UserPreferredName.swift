import Foundation

/// めろまるがユーザーを呼ぶ名前 (ニックネーム) の解決ヘルパー。
///
/// 解決優先順位:
///   1. 引数 `analysisSelfName` (LINE トーク分析で同定した自分の名前) — 最優先
///   2. 設定画面でユーザーが入力した呼び名 (`Constants.StorageKeys.userPreferredName`)
///   3. デフォルト "あなた"
///
/// 「とりあえず話す」のように 1. が無い場面で 2. をフォールバックさせるのが主用途。
enum UserPreferredName {
    /// 設定画面の TextField からの読み出し。空文字や空白のみは nil 扱い。
    static var stored: String? {
        let raw = UserDefaults.standard.string(forKey: Constants.StorageKeys.userPreferredName) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 分析由来の名前を最優先しつつ、無ければユーザー設定 → デフォルトの順でフォールバック。
    /// AI への system prompt や UI 表示の双方で使う。
    static func resolve(analysisSelfName: String? = nil) -> String {
        if let analysis = analysisSelfName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !analysis.isEmpty {
            return analysis
        }
        if let stored = stored {
            return stored
        }
        return String(localized: "あなた", bundle: LanguageManager.appBundle)
    }
}
