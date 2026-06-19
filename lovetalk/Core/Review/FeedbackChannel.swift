//
//  FeedbackChannel.swift
//  yabatalk
//
//  Template source: .claude/skills/inapp-review-prompt/templates/FeedbackChannel.swift.tmpl
//  Replace {{...}} placeholders, drop into <App>/Core/Review/, and rename to .swift.
//  Related skill: .claude/skills/inapp-review-prompt/SKILL.md
//
//  フィードバック送信プロトコルと既定の `mailto:` 実装。
//  バックエンドを持たないアプリではメーラー起動が既定。メーラー未設定端末でも UX を
//  止めない（戻り値 false で呼び出し側が控えめにインライン通知する）。
//  Firestore / HTTP 実装は references/feedback-channels.md を参照。
//

import Foundation
import UIKit

/// フィードバックを送るチャネル抽象。実装は mailto / http / firestore など。
@MainActor
protocol FeedbackChannel: Sendable {
    /// フィードバックを送る。送信を試みた結果（true=成功 or 起動成功）。
    @discardableResult
    func send(_ feedback: Feedback) async -> Bool
}

/// `mailto:` URL を組み立ててメーラーを起動する既定実装。
/// 推奨値:
///   - recipient: "{{FEEDBACK_EMAIL}}"  (`.app-meta.yaml > review.feedbackChannel.to`)
///   - subject:   "{{FEEDBACK_SUBJECT}}" (`.app-meta.yaml > review.feedbackChannel.subject`)
struct MailtoFeedbackChannel: FeedbackChannel {
    let recipient: String
    let subject: String

    init(recipient: String, subject: String) {
        self.recipient = recipient
        self.subject = subject
    }

    func send(_ feedback: Feedback) async -> Bool {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            .init(name: "subject", value: subject),
            .init(name: "body", value: feedback.formattedBody())
        ]
        guard let url = components.url else { return false }
        if UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
            return true
        }
        return false
    }
}
