import SwiftUI

// MARK: - App Language
enum AppLanguage: String, CaseIterable, Identifiable {
    case ja = "ja"
    case en = "en"
    case es = "es"
    case ko = "ko"
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ja: return "日本語"
        case .en: return "English"
        case .es: return "Español"
        case .ko: return "한국어"
        case .zhHans: return "中文（简体）"
        }
    }

    var isJapanese: Bool { self == .ja }

    var localeIdentifier: String { rawValue }

    /// AI プロンプト用の言語名（モデルへの指示に使用）
    var promptLanguageName: String {
        switch self {
        case .ja: return "日本語"
        case .en: return "English"
        case .es: return "Spanish"
        case .ko: return "Korean"
        case .zhHans: return "Simplified Chinese"
        }
    }
}

// MARK: - Language Manager
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @AppStorage(Constants.StorageKeys.appLanguage)
    private var storedLanguage: String = ""

    @Published var currentLanguage: AppLanguage = .ja

    var locale: Locale {
        Locale(identifier: currentLanguage.localeIdentifier)
    }

    /// 端末の優先言語からサポート対象のAppLanguageを検出
    nonisolated static func detectDeviceLanguage() -> AppLanguage {
        for preferredLang in Locale.preferredLanguages {
            let lower = preferredLang.lowercased()
            if lower.hasPrefix("ja") { return .ja }
            if lower.hasPrefix("ko") { return .ko }
            if lower.hasPrefix("es") { return .es }
            if lower.hasPrefix("zh") { return .zhHans }
            if lower.hasPrefix("en") { return .en }
        }
        return .en
    }

    /// 保存済み言語を取得（未設定なら端末言語を検出して保存）
    nonisolated static var resolvedLanguage: String {
        if let stored = UserDefaults.standard.string(forKey: Constants.StorageKeys.appLanguage),
           !stored.isEmpty {
            return stored
        }
        let detected = detectDeviceLanguage()
        UserDefaults.standard.set(detected.rawValue, forKey: Constants.StorageKeys.appLanguage)
        return detected.rawValue
    }

    nonisolated static var isJapanese: Bool {
        resolvedLanguage == AppLanguage.ja.rawValue
    }

    nonisolated static var appLocale: Locale {
        Locale(identifier: resolvedLanguage)
    }

    nonisolated static var appBundle: Bundle {
        let lang = resolvedLanguage
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }

    private init() {
        // 初回起動時: storedLanguageが空 → 端末言語を検出して設定
        if storedLanguage.isEmpty {
            let detected = Self.detectDeviceLanguage()
            storedLanguage = detected.rawValue
            currentLanguage = detected
        } else if let lang = AppLanguage(rawValue: storedLanguage) {
            currentLanguage = lang
        }
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        storedLanguage = language.rawValue
    }
}
