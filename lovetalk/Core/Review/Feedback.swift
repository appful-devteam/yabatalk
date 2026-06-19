//
//  Feedback.swift
//  yabatalk
//
//  Template source: .claude/skills/inapp-review-prompt/templates/Feedback.swift.tmpl
//  Replace {{...}} placeholders, drop into <App>/Core/Review/, and rename to .swift.
//  Related skill: .claude/skills/inapp-review-prompt/SKILL.md
//
//  Page 2B（No 分岐）で集めるフィードバックの値オブジェクト。
//  チャネルに渡す前に必要な環境情報（OS / アプリバージョン）も同梱する。
//

import Foundation
import UIKit

struct Feedback: Sendable, Equatable {
    /// ユーザーがチェックしたカテゴリ。
    var categories: [String]
    /// 自由記入（任意・500 字上限）。
    var freeText: String?
    /// 送信時のアプリバージョン（"1.0" 等）。
    var appVersion: String
    /// 送信時のビルド番号（"1" 等）。
    var buildNumber: String
    /// 送信時の OS バージョン（"iOS 26.0" 等）。
    var osVersion: String
    /// 送信時のデバイスモデル（"iPhone 17 Pro" 等）。
    var deviceModel: String

    /// 現在の Bundle / UIDevice を読み取ってメタデータを埋める初期化。
    @MainActor
    static func current(categories: [String],
                        freeText: String?) -> Feedback {
        let bundle = Bundle.main
        let appVer = (bundle.infoDictionary?["CFBundleShortVersionString"]
                      as? String) ?? "?"
        let build = (bundle.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        let device = UIDevice.current
        return Feedback(
            categories: categories,
            freeText: freeText?.trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty,
            appVersion: appVer,
            buildNumber: build,
            osVersion: "\(device.systemName) \(device.systemVersion)",
            deviceModel: device.model
        )
    }

    /// mailto: 本文 / HTTP body 共通の整形済みテキスト。
    func formattedBody() -> String {
        var lines: [String] = []
        if !categories.isEmpty {
            lines.append(String(localized: "【カテゴリ】"))
            for c in categories { lines.append("- \(c)") }
            lines.append("")
        }
        if let freeText, !freeText.isEmpty {
            lines.append(String(localized: "【ご意見・自由記入】"))
            lines.append(freeText)
            lines.append("")
        }
        lines.append("---")
        lines.append("App: \(appVersion) (\(buildNumber))")
        lines.append("OS: \(osVersion)")
        lines.append("Device: \(deviceModel)")
        return lines.joined(separator: "\n")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
