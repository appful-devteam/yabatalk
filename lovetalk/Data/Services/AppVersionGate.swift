import Foundation
import SwiftUI

// MARK: - App Version Gate
/// アプリ起動時にリモート config から最低サポートバージョンを取得し、
/// 現バージョンが下回っていれば強制アップデート画面でロックするためのゲート。
///
/// Firebase Remote Config パラメータ:
///   key   = "force_update_config"
///   value = JSON 文字列 (例:
///     `{"minimum_version":"2.3","app_store_url":"https://apps.apple.com/...","message":"..."}`)
///
/// 値が空 / key 未設定 / 不正 JSON / 取得失敗 = OFF (アプリは通常起動)。
/// いつでも有効化したい時にこの value を埋めればロックがかかる。
@MainActor
final class AppVersionGate: ObservableObject {
    static let shared = AppVersionGate()

    /// 強制アップデートが必要か。true で全画面のロック画面を出す。
    @Published private(set) var isUpdateRequired: Bool = false
    /// 「App Store で更新」ボタンの遷移先 URL (remote 設定があればそちら、無ければ Constants の fallback)。
    @Published private(set) var appStoreURL: URL = URL(string: Constants.App.defaultAppStoreURL)!
    /// 強制アップデート画面に表示するメッセージ。空ならデフォルト文言。
    @Published private(set) var message: String = ""
    /// 1 度でも check が走ったか。起動直後の "未確認" 状態を区別したい場合に使う。
    @Published private(set) var hasChecked: Bool = false

    private init() {}

    /// リモート config を取得し、現バージョンと比較する。
    /// 通信失敗時は安全側に倒して update 不要扱い (ユーザーをオフラインで締め出さない)。
    func check() async {
        let raw = await RemoteConfigService.shared
            .string(forKey: Constants.RemoteConfigKeys.forceUpdateConfig)
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let parsed = Self.parseConfig(trimmed)

        if let urlString = parsed.appStoreURL,
           let url = URL(string: urlString),
           !urlString.isEmpty {
            appStoreURL = url
        }
        message = parsed.message ?? ""

        let needsUpdate: Bool
        if let minimum = parsed.minimumVersion, !minimum.isEmpty {
            needsUpdate = Self.compare(current: Constants.App.version, isLessThan: minimum)
        } else {
            needsUpdate = false
        }
        isUpdateRequired = needsUpdate
        hasChecked = true
    }

    // MARK: - Config Parse

    private struct ParsedConfig {
        let minimumVersion: String?
        let appStoreURL: String?
        let message: String?
    }

    /// JSON 文字列から minimum_version / app_store_url / message を抽出。
    /// パース失敗時は全 nil (= 強制アップデート OFF として扱われる)。
    private static func parseConfig(_ raw: String) -> ParsedConfig {
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParsedConfig(minimumVersion: nil, appStoreURL: nil, message: nil)
        }
        return ParsedConfig(
            minimumVersion: (json["minimum_version"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            appStoreURL: (json["app_store_url"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            message: (json["message"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Version Compare

    /// `current < minimum` なら true。"2.3" / "2.10" / "2.3.1" 等の
    /// ドット区切り数値表現を semver 風に比較する。
    /// 数値以外の suffix (例: "2.3-beta") は数値部分だけ取って比較。
    static func compare(current: String, isLessThan minimum: String) -> Bool {
        let cur = parseComponents(current)
        let min_ = parseComponents(minimum)
        let count = max(cur.count, min_.count)
        for i in 0..<count {
            let a = i < cur.count ? cur[i] : 0
            let b = i < min_.count ? min_[i] : 0
            if a < b { return true }
            if a > b { return false }
        }
        return false
    }

    private static func parseComponents(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { String($0) }
            .map { component -> Int in
                // 先頭の連続する数字だけ取る (例: "3rc1" → 3)
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}

// MARK: - Force Update View
/// 全画面ロックの強制アップデート画面。dismiss 不可で「App Store で更新」だけ開ける。
struct ForceUpdateView: View {
    @ObservedObject private var gate = AppVersionGate.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            MeloColors.Surface.pinkPale
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image("char_meromaru_3d")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)

                VStack(spacing: 12) {
                    Text(String(localized: "アプリの更新が必要です", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(22))
                        .foregroundColor(MeloColors.Text.primary)

                    Text(gate.message.isEmpty
                         ? String(localized: "最新版でないと一部機能が利用できません。\nApp Store から更新してください。", bundle: LanguageManager.appBundle)
                         : gate.message)
                        .font(MeloFonts.zenMaruRegular(14))
                        .foregroundColor(MeloColors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    HapticManager.medium()
                    openURL(gate.appStoreURL)
                } label: {
                    Text(String(localized: "App Store で更新", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(MeloColors.Gradient.pinkPrimary)
                        )
                        .shadow(color: MeloColors.Brand.pink.opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
