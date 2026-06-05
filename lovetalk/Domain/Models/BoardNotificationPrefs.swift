import Foundation

/// 掲示板関連のプッシュ通知設定。
/// `users/{uid}.notificationPrefs` に map として保存され、
/// Firestore 側 (Cloud Functions) でこれを読み、enable のものだけ APNs バナー送信する。
struct BoardNotificationPrefs: Codable, Equatable {
    var follow: Bool = true
    var like: Bool = true
    var reply: Bool = true
    var mention: Bool = true
    var repost: Bool = true
    var quote: Bool = true
    var bookmark: Bool = true

    static let allEnabled = BoardNotificationPrefs()

    /// Firestore dict 表現
    var toDict: [String: Any] {
        [
            "follow": follow,
            "like": like,
            "reply": reply,
            "mention": mention,
            "repost": repost,
            "quote": quote,
            "bookmark": bookmark
        ]
    }

    static func from(dict: [String: Any]?) -> BoardNotificationPrefs {
        var prefs = BoardNotificationPrefs()
        guard let dict else { return prefs }
        if let v = dict["follow"] as? Bool { prefs.follow = v }
        if let v = dict["like"] as? Bool { prefs.like = v }
        if let v = dict["reply"] as? Bool { prefs.reply = v }
        if let v = dict["mention"] as? Bool { prefs.mention = v }
        if let v = dict["repost"] as? Bool { prefs.repost = v }
        if let v = dict["quote"] as? Bool { prefs.quote = v }
        if let v = dict["bookmark"] as? Bool { prefs.bookmark = v }
        return prefs
    }
}
