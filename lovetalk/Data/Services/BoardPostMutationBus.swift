import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// リアクション（ハート等）トグル成功後に送信
    static let boardPostReactionChanged = Notification.Name("boardPostReactionChanged")
    /// 投票成功後に送信
    static let boardPostPollVoted = Notification.Name("boardPostPollVoted")
    /// ブックマークトグル成功後に送信（将来拡張用 - 現状 BoardBookmarkService で共有済み）
    static let boardPostBookmarkChanged = Notification.Name("boardPostBookmarkChanged")
    /// 返信数更新（返信追加/削除）後に送信
    static let boardPostReplyCountChanged = Notification.Name("boardPostReplyCountChanged")
    /// リポストトグル成功後に送信
    static let boardPostRepostChanged = Notification.Name("boardPostRepostChanged")
    /// 引用投稿の作成・削除に伴う quoteCount 変更後に送信
    static let boardPostQuoteCountChanged = Notification.Name("boardPostQuoteCountChanged")
    /// 投稿カード内のハッシュタグがタップされた時。`object` に `String` (#抜きのタグ名) を載せる。
    static let openHashtagSearch = Notification.Name("openHashtagSearch")
}

// MARK: - Board Post Mutation Bus
/// 掲示板フィードカードと投稿詳細間の投稿単位の状態同期用軽量ブロードキャスト。
/// 楽観的更新 → Firestore 書き込み成功後にのみ送信すること（失敗時は送信しない）。
/// 受信側は .onReceive 内で送信してはならない（無限ループ防止）。
enum BoardPostMutationBus {
    /// リアクション結果
    struct ReactionPayload {
        let postId: String
        let myReaction: String?            // nil ならリアクション解除
        let counts: [String: Int]          // 更新後のローカルカウント
    }

    /// 投票結果
    struct PollVotePayload {
        let postId: String
        let myVote: String?                // 選択された optionId（取り消し時 nil）
        let options: [PollOption]          // 更新後の voteCount を含むオプション配列
        let totalVotes: Int
    }

    /// ブックマーク結果（将来拡張用 - 現状は BoardBookmarkService の @Published で共有）
    struct BookmarkPayload {
        let postId: String
        let isBookmarked: Bool
        let bookmarkCount: Int?
    }

    /// 返信追加/削除による返信数更新
    struct ReplyCountPayload {
        let postId: String
        let replyCount: Int
    }

    /// リポストトグル結果（フィード ↔ 詳細 ↔ プロフィール間の同期用）
    struct RepostPayload {
        let postId: String
        let isRepostedByMe: Bool
        let repostCount: Int
    }

    /// 引用投稿の作成/削除による quoteCount 変更
    struct QuoteCountPayload {
        let postId: String
        let quoteCount: Int
    }

    static func postReaction(_ payload: ReactionPayload) {
        NotificationCenter.default.post(
            name: .boardPostReactionChanged,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    static func postPollVote(_ payload: PollVotePayload) {
        NotificationCenter.default.post(
            name: .boardPostPollVoted,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    static func postBookmark(_ payload: BookmarkPayload) {
        NotificationCenter.default.post(
            name: .boardPostBookmarkChanged,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    static func postReplyCount(_ payload: ReplyCountPayload) {
        NotificationCenter.default.post(
            name: .boardPostReplyCountChanged,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    static func postRepost(_ payload: RepostPayload) {
        NotificationCenter.default.post(
            name: .boardPostRepostChanged,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    static func postQuoteCount(_ payload: QuoteCountPayload) {
        NotificationCenter.default.post(
            name: .boardPostQuoteCountChanged,
            object: nil,
            userInfo: ["payload": payload]
        )
    }
}
