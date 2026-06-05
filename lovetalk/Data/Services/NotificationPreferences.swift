import Foundation

/// 通知の種類ごとのオン/オフ管理
enum NotificationPreferences {
    static var repliesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Constants.StorageKeys.notifyReplies) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Constants.StorageKeys.notifyReplies) }
    }

    static var reactionsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Constants.StorageKeys.notifyReactions) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Constants.StorageKeys.notifyReactions) }
    }

    static var newFollowersEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Constants.StorageKeys.notifyNewFollowers) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Constants.StorageKeys.notifyNewFollowers) }
    }

    static var followingPostsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Constants.StorageKeys.notifyFollowingPosts) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Constants.StorageKeys.notifyFollowingPosts) }
    }

    /// ユーザーが有効にしている通知タイプのSet
    static var enabledTypes: Set<String> {
        var types = Set<String>()
        if repliesEnabled { types.insert("reply") }
        if reactionsEnabled { types.insert("reaction") }
        if newFollowersEnabled { types.insert("follow") }
        if followingPostsEnabled { types.insert("following_post") }
        return types
    }
}
