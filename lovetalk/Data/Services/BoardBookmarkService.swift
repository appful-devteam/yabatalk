import Foundation

// MARK: - Board Bookmark Service
/// 投稿ブックマーク管理。
///
/// **Firestore + ローカルキャッシュの二層構造**で、LINE版 (lovetalk) と IG版 (lovetalk-ig)
/// 間で同じ Apple アカウントなら保存済み投稿が共有される。
/// - Firestore: `users/{uid}.bookmarkedPostIds: [String]` が真の信号源
/// - UserDefaults: オフライン時の即応用キャッシュ
@MainActor
final class BoardBookmarkService: ObservableObject {
    static let shared = BoardBookmarkService()

    @Published private(set) var bookmarkedPostIds: Set<String> = []

    private let storageKey = "board_bookmarked_post_ids"
    private let firestoreService = BoardFirestoreService.shared

    private init() {
        load()
        // ログイン済みなら起動時に Firestore から同期。
        // 未ログインなら BoardAuthService の auth state 変化で `syncFromFirestore` が呼ばれる。
        Task { @MainActor in
            await syncFromFirestore()
        }
    }

    // MARK: - Public

    func isBookmarked(_ postId: String) -> Bool {
        bookmarkedPostIds.contains(postId)
    }

    func toggle(_ postId: String) {
        if bookmarkedPostIds.contains(postId) {
            bookmarkedPostIds.remove(postId)
            saveLocal()
            Task {
                if let userId = BoardAuthService.shared.currentUser?.id {
                    await firestoreService.removeBookmark(userId: userId, postId: postId)
                }
            }
        } else {
            bookmarkedPostIds.insert(postId)
            saveLocal()
            Task {
                if let userId = BoardAuthService.shared.currentUser?.id {
                    await firestoreService.addBookmark(userId: userId, postId: postId)
                }
            }
        }
    }

    /// Firestore から最新のブックマーク一覧を読み込み、ローカルとマージする。
    /// - サインイン直後 / 別アプリで追加された bookmark を反映するため
    /// - サインアウト前のローカル分は失わないように union する
    func syncFromFirestore() async {
        guard let userId = BoardAuthService.shared.currentUser?.id else { return }
        let remote = await firestoreService.fetchBookmarkedPostIds(userId: userId)
        let merged = bookmarkedPostIds.union(remote)
        // ローカルにあるが Firestore に無いものは push (双方向同期)
        let toPush = merged.subtracting(remote)
        bookmarkedPostIds = merged
        saveLocal()
        if !toPush.isEmpty {
            for postId in toPush {
                await firestoreService.addBookmark(userId: userId, postId: postId)
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            bookmarkedPostIds = ids
        }
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(bookmarkedPostIds) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
