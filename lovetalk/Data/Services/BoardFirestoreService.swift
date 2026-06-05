import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Board Firestore Service
/// 掲示板のFirestore CRUD操作
@MainActor
final class BoardFirestoreService: ObservableObject {
    static let shared = BoardFirestoreService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Collections

    private var postsCollection: CollectionReference { db.collection("posts") }
    private func repliesCollection(postId: String) -> CollectionReference {
        postsCollection.document(postId).collection("replies")
    }
    private var usersCollection: CollectionReference { db.collection("users") }
    private func followersCollection(userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("followers")
    }
    private func followingCollection(userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("following")
    }
    private func followRequestsCollection(userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("followRequests")
    }

    // MARK: - Fetch Posts (Paginated)

    func fetchPosts(sort: BoardFeedSort, limit: Int = 20, after: DocumentSnapshot? = nil, followingIds: Set<String> = [], userLanguage: String? = nil) async throws -> ([BoardPost], DocumentSnapshot?) {
        var query: Query

        switch sort {
        case .latest:
            query = postsCollection.order(by: "createdAt", descending: true)
            query = query.limit(to: limit)
            if let after {
                query = query.start(afterDocument: after)
            }
        case .popular:
            // おすすめ: 全投稿を取得 → クライアント側でスコア計算
            query = postsCollection
                .order(by: "createdAt", descending: true)
                .limit(to: 200)
        case .following:
            // フォロー中: 全投稿から取得してクライアント側でフィルタ
            query = postsCollection.order(by: "createdAt", descending: true).limit(to: 50)
        }

        let snapshot = try await query.getDocuments()
        let lastDoc = snapshot.documents.last

        var posts = snapshot.documents.compactMap { doc -> BoardPost? in
            try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
        }

        if sort == .popular {
            posts = Self.rankPosts(posts, followingIds: followingIds, userLanguage: userLanguage)
        } else if sort == .latest, let lang = userLanguage {
            // 最新タブ: 同じ言語の投稿を優先表示（フォロー中は言語関係なく含む）
            posts = Self.sortByLanguagePriority(posts, userLanguage: lang, followingIds: followingIds)
        } else if sort == .following {
            posts = posts.filter { followingIds.contains($0.authorId) }
        }

        return (posts, lastDoc)
    }

    /// 同言語の投稿を先頭、異言語(かつ非フォロー)を末尾に並べる共通ソート。
    /// 古い投稿の `language` が nil の場合は "ja" として扱う。
    static func sortByLanguagePriority(
        _ posts: [BoardPost],
        userLanguage: String,
        followingIds: Set<String>
    ) -> [BoardPost] {
        let sameLang = posts.filter { (($0.language ?? "ja") == userLanguage) || followingIds.contains($0.authorId) }
        let otherLang = posts.filter { (($0.language ?? "ja") != userLanguage) && !followingIds.contains($0.authorId) }
        return sameLang + otherLang
    }

    func fetchPosts(forCommunityRoomId roomId: String, limit: Int = 50, followingIds: Set<String> = [], userLanguage: String? = nil) async throws -> [BoardPost] {
        let snapshot = try await postsCollection
            .whereField("communityRoomId", isEqualTo: roomId)
            .limit(to: limit)
            .getDocuments()

        let posts = snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
        }
        .sorted { $0.createdAt > $1.createdAt }

        if let lang = userLanguage {
            return Self.sortByLanguagePriority(posts, userLanguage: lang, followingIds: followingIds)
        }
        return posts
    }

    // MARK: - Room Post Count (おすすめ並び替え用)

    /// 通常の相談部屋に紐付く投稿数を集計。`count` aggregation で1リクエスト1リード。
    func countPosts(forCommunityRoomId roomId: String) async throws -> Int {
        let snap = try await postsCollection
            .whereField("communityRoomId", isEqualTo: roomId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snap.count)
    }

    /// テーマ部屋に紐付く投稿数を集計 (themes array-contains)。
    func countPosts(forThemeLabel label: String) async throws -> Int {
        let snap = try await postsCollection
            .whereField("themes", arrayContains: label)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snap.count)
    }

    /// テーマ部屋 (PostTheme) として、posts の `themes` 配列に
    /// 指定ラベルを含む投稿を返す。
    func fetchPosts(forThemeLabel label: String, limit: Int = 100, followingIds: Set<String> = [], userLanguage: String? = nil) async throws -> [BoardPost] {
        let snapshot = try await postsCollection
            .whereField("themes", arrayContains: label)
            .limit(to: limit)
            .getDocuments()

        let posts = snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
        }
        .sorted { $0.createdAt > $1.createdAt }

        if let lang = userLanguage {
            return Self.sortByLanguagePriority(posts, userLanguage: lang, followingIds: followingIds)
        }
        return posts
    }

    // MARK: - Migration

    /// 旧 community_rooms/{roomId}/posts/ にあった投稿を共通 posts コレクションへ
    /// 同一 ID で 1 度だけ書き込む。既に同 ID の doc が存在する場合は何もしない (idempotent)。
    /// 旧データの段階的移行用。完全移行後はこのメソッドと呼び出し側を削除可。
    func migratePostIfMissing(_ post: BoardPost) async throws {
        let docRef = postsCollection.document(post.id)
        let existing = try await docRef.getDocument()
        guard !existing.exists else { return }

        var data: [String: Any] = [
            "authorId": post.authorId,
            "authorDisplayName": post.authorDisplayName,
            "content": post.content,
            "postType": post.postType.rawValue,
            "isAnonymous": post.isAnonymous,
            "imageURLs": post.imageURLs,
            "themes": post.themes,
            "replyCount": post.replyCount,
            "quoteCount": post.quoteCount,
            "repostCount": post.repostCount,
            "bookmarkCount": post.bookmarkCount,
            "reactionCounts": post.reactionCounts,
            "totalReactions": post.reactionCounts.values.reduce(0, +),
            "totalVotes": post.totalVotes,
            "viewCount": post.viewCount,
            "createdAt": Timestamp(date: post.createdAt),
            "updatedAt": Timestamp(date: post.updatedAt)
        ]
        if let url = post.authorProfileImageURL {
            data["authorProfileImageURL"] = url
        }
        if let badge = post.authorBadge {
            data["authorBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }
        if let roomId = post.communityRoomId {
            data["communityRoomId"] = roomId
        }
        if let title = post.communityRoomTitle {
            data["communityRoomTitle"] = title
        }
        if let card = post.diagnosisCard {
            data["diagnosisCard"] = Self.diagnosisCardDict(card)
        }
        if let language = post.language {
            data["language"] = language
        }
        if let summary = post.aiSummary {
            data["aiSummary"] = summary
        }
        if let polls = post.pollOptions {
            data["pollOptions"] = polls.map { [
                "id": $0.id,
                "text": $0.text,
                "voteCount": $0.voteCount
            ] as [String: Any] }
        }

        try await docRef.setData(data)
    }

    // MARK: - Recommendation Algorithm

    /// Xの「おすすめ」風ランキングアルゴリズム
    /// エンゲージメント × 時間減衰 × 各種ブーストでスコア計算 + 著者多様性
    static func rankPosts(_ posts: [BoardPost], followingIds: Set<String> = [], userLanguage: String? = nil) -> [BoardPost] {
        let now = Date()
        var scored = posts
            .map { post -> (BoardPost, Double) in
                let score = calculatePopularityScore(post: post, now: now, followingIds: followingIds, userLanguage: userLanguage)
                return (post, score)
            }
            .sorted { $0.1 > $1.1 }

        // 著者多様性: 同一著者の連続投稿を分散させる
        var result: [(BoardPost, Double)] = []
        var authorRecentCount: [String: Int] = [:]
        for item in scored {
            let count = authorRecentCount[item.0.authorId] ?? 0
            if count < 2 {
                result.append(item)
                authorRecentCount[item.0.authorId] = count + 1
            } else {
                // 3投稿目以降は後ろに回す
                result.append((item.0, item.1 * 0.3))
            }
        }

        return result.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    private static func calculatePopularityScore(post: BoardPost, now: Date, followingIds: Set<String> = [], userLanguage: String? = nil) -> Double {
        let hoursAge = max(now.timeIntervalSince(post.createdAt) / 3600, 0)

        // エンゲージメントスコア（対数スケールで大きな差を緩和）
        let hearts = Double(post.reactionCounts.values.reduce(0, +))
        let replies = Double(post.replyCount)
        let quotes = Double(post.quoteCount)
        let views = Double(max(post.viewCount, 1))
        let engagement = log2(hearts * 3.0 + replies * 5.0 + quotes * 4.0 + sqrt(views) * 0.5 + 1.0)

        // エンゲージメント率ボーナス（バイラル性）
        let engagementRate = (hearts + replies + quotes) / views
        let viralBonus = 1.0 + min(engagementRate * 2.0, 1.0)

        // 時間減衰（緩やか：古い投稿もランキングに残る）
        let timeDecay = 1.0 / pow(hoursAge / 24.0 + 1.0, 1.0)

        // 鮮度ブースト（段階的：1h以内→2.0、3h以内→1.5、6h以内→1.2）
        let freshnessBoost: Double
        if hoursAge < 1 { freshnessBoost = 2.0 }
        else if hoursAge < 3 { freshnessBoost = 1.5 }
        else if hoursAge < 6 { freshnessBoost = 1.2 }
        else { freshnessBoost = 1.0 }

        // 診断カード添付ボーナス（コンテンツの質）
        let cardBonus: Double = post.diagnosisCard != nil ? 1.3 : 1.0

        // コンテンツ長ボーナス（短すぎず長すぎない投稿を優遇）
        let contentLength = post.content.count
        let lengthBonus: Double
        if contentLength >= 30 && contentLength <= 200 { lengthBonus = 1.15 }
        else if contentLength > 200 { lengthBonus = 1.05 }
        else { lengthBonus = 1.0 }

        // 画像付きボーナス
        let imageBonus: Double = post.imageURLs.isEmpty ? 1.0 : 1.15

        // フォロー中ユーザーのブースト（おすすめに優先表示）
        let followBoost: Double = followingIds.contains(post.authorId) ? 1.8 : 1.0

        // 投稿タイプボーナス（アンケートはエンゲージメント向上コンテンツ）
        let typeBonus: Double
        switch post.postType {
        case .poll, .consultation: typeBonus = 1.3  // アンケートは参加型で優遇
        case .normal: typeBonus = 1.0
        }

        // 投票参加ボーナス（投票数が多いほどブースト）
        let voteBonus: Double = post.totalVotes > 0 ? 1.0 + min(log2(Double(post.totalVotes) + 1) * 0.1, 0.5) : 1.0

        // 言語ブースト（同じ言語の投稿を優先、フォロー中は言語関係なく表示）
        // 古い投稿で language フィールドが nil のものは "ja" として扱う
        // (この機能導入前は日本語ユーザー前提で運用されていたため)。
        let languageBoost: Double
        if let userLang = userLanguage {
            let postLang = post.language ?? "ja"
            if postLang == userLang {
                languageBoost = 3.0
            } else if followingIds.contains(post.authorId) {
                languageBoost = 1.5  // フォロー中は異言語でもある程度表示
            } else {
                languageBoost = 0.03  // 異言語非フォローは強くペナルティ(英語ユーザーが日本語投稿に埋もれないように)
            }
        } else {
            languageBoost = 1.0
        }

        return engagement * viralBonus * timeDecay * freshnessBoost * cardBonus * lengthBonus * imageBonus * followBoost * typeBonus * voteBonus * languageBoost
    }

    // MARK: - Create Post

    func createPost(content: String, authorId: String, authorName: String, authorProfileImageURL: String? = nil, badge: LoveTypeBadge?, diagnosisCard: DiagnosisCard?, quotedPost: QuotedPostInfo? = nil, postType: BoardPostType = .normal, pollOptions: [PollOption]? = nil, isAnonymous: Bool = false, authorIsPrivate: Bool = false, themes: [String] = [], communityRoomId: String? = nil, communityRoomTitle: String? = nil) async throws -> BoardPost {
        let now = Timestamp(date: Date())

        var data: [String: Any] = [
            "authorId": authorId,
            "authorDisplayName": authorName,
            "content": content,
            "postType": postType.rawValue,
            "isAnonymous": isAnonymous,
            "authorIsPrivate": authorIsPrivate,
            "language": LanguageManager.resolvedLanguage,
            "imageURLs": [String](),
            "themes": themes,
            "replyCount": 0,
            "quoteCount": 0,
            "repostCount": 0,
            "bookmarkCount": 0,
            "reactionCounts": [String: Int](),
            "totalReactions": 0,
            "totalVotes": 0,
            "viewCount": 0,
            "createdAt": now,
            "updatedAt": now
        ]

        if let authorProfileImageURL {
            data["authorProfileImageURL"] = authorProfileImageURL
        }

        if let communityRoomId {
            data["communityRoomId"] = communityRoomId
        }
        if let communityRoomTitle {
            data["communityRoomTitle"] = communityRoomTitle
        }

        if let badge {
            data["authorBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }

        if let card = diagnosisCard {
            data["diagnosisCard"] = Self.diagnosisCardDict(card)
        }

        if let quote = quotedPost {
            data["quotedPost"] = Self.quotedPostDict(quote)
        }

        if let options = pollOptions {
            data["pollOptions"] = options.map { [
                "id": $0.id,
                "text": $0.text,
                "voteCount": $0.voteCount
            ] as [String: Any] }
        }

        let docRef = try await postsCollection.addDocument(data: data)

        // 引用元の投稿のquoteCountをインクリメント + 引用元投稿者に通知
        if let quote = quotedPost {
            try? await postsCollection.document(quote.postId).updateData([
                "quoteCount": FieldValue.increment(Int64(1))
            ])
            // インクリメント後の値を読み戻してフィード/詳細ビューに伝搬
            if let quotedDoc = try? await postsCollection.document(quote.postId).getDocument() {
                let data = quotedDoc.data()
                if let newCount = data?["quoteCount"] as? Int {
                    await MainActor.run {
                        BoardPostMutationBus.postQuoteCount(
                            .init(postId: quote.postId, quoteCount: newCount)
                        )
                    }
                }
                if let quotedAuthorId = data?["authorId"] as? String {
                    try? await createQuoteNotification(
                        originalAuthorId: quotedAuthorId,
                        postId: docRef.documentID,
                        quoterName: isAnonymous ? "匿名ユーザー" : authorName
                    )
                }
            }
        }

        let displayName = isAnonymous
            ? String(localized: "匿名", bundle: LanguageManager.appBundle)
            : authorName

        return BoardPost(
            id: docRef.documentID,
            authorId: authorId,
            authorDisplayName: displayName,
            authorProfileImageURL: isAnonymous ? nil : authorProfileImageURL,
            authorBadge: isAnonymous ? nil : badge,
            postType: postType,
            content: content,
            imageURLs: [],
            diagnosisCard: diagnosisCard,
            quotedPost: quotedPost,
            stamp: nil,
            pollOptions: pollOptions,
            isAnonymous: isAnonymous,
            authorIsPrivate: authorIsPrivate,
            aiSummary: nil,
            language: LanguageManager.resolvedLanguage,
            themes: themes,
            communityRoomId: communityRoomId,
            communityRoomTitle: communityRoomTitle,
            totalVotes: 0,
            replyCount: 0,
            quoteCount: 0,
            repostCount: 0,
            bookmarkCount: 0,
            reactionCounts: [:],
            viewCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            myReaction: nil,
            myVote: nil
        )
    }

    // MARK: - Fetch Replies

    func fetchReplies(postId: String) async throws -> [BoardReply] {
        let snapshot = try await repliesCollection(postId: postId)
            .order(by: "createdAt", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> BoardReply? in
            try? doc.data(as: FirestoreReply.self).toBoardReply(id: doc.documentID, postId: postId)
        }
    }

    // MARK: - Create Reply

    func uploadReplyImage(_ imageData: Data, postId: String) async throws -> String {
        let compressed = ImageCompressor.compressForPost(imageData) ?? imageData
        let result = try await R2StorageService.shared.uploadImage(
            data: compressed,
            type: .reply,
            ownerId: postId
        )
        return result.url.absoluteString
    }

    func createReply(postId: String, content: String, authorId: String, authorName: String, authorProfileImageURL: String? = nil, badge: LoveTypeBadge?, imageURLs: [String] = [], mention: ReplyMentionInfo? = nil) async throws -> BoardReply {
        let now = Timestamp(date: Date())

        var data: [String: Any] = [
            "authorId": authorId,
            "authorDisplayName": authorName,
            "content": content,
            "likeCount": 0,
            "createdAt": now
        ]

        if let authorProfileImageURL {
            data["authorProfileImageURL"] = authorProfileImageURL
        }

        if let badge {
            data["authorBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }

        if !imageURLs.isEmpty {
            data["imageURLs"] = imageURLs
        }

        if let mention {
            data["mentionedReplyId"] = mention.replyId
            data["mentionedUserName"] = mention.userName
        }

        let docRef = try await repliesCollection(postId: postId).addDocument(data: data)

        // 投稿のreplyCountをインクリメント
        try await postsCollection.document(postId).updateData([
            "replyCount": FieldValue.increment(Int64(1))
        ])

        return BoardReply(
            id: docRef.documentID,
            postId: postId,
            authorId: authorId,
            authorDisplayName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            authorBadge: badge,
            content: content,
            stamp: nil,
            imageURLs: imageURLs,
            likeCount: 0,
            mentionedReplyId: mention?.replyId,
            mentionedUserName: mention?.userName,
            createdAt: Date()
        )
    }

    // MARK: - Delete Reply

    func deleteReply(postId: String, replyId: String) async throws {
        try await repliesCollection(postId: postId).document(replyId).delete()
        try await postsCollection.document(postId).updateData([
            "replyCount": FieldValue.increment(Int64(-1))
        ])
    }

    // MARK: - Toggle Reaction

    func toggleReaction(postId: String, userId: String, reactionType: String) async throws {
        let reactionDoc = postsCollection.document(postId).collection("reactions").document(userId)

        let existing = try await reactionDoc.getDocument()

        if existing.exists, let currentType = existing.data()?["type"] as? String, currentType == reactionType {
            // 同じリアクション → 削除
            try await reactionDoc.delete()
            try await postsCollection.document(postId).updateData([
                "reactionCounts.\(reactionType)": FieldValue.increment(Int64(-1)),
                "totalReactions": FieldValue.increment(Int64(-1))
            ])
        } else {
            // 別のリアクションがあれば古いのを減らす
            if existing.exists, let oldType = existing.data()?["type"] as? String {
                try await postsCollection.document(postId).updateData([
                    "reactionCounts.\(oldType)": FieldValue.increment(Int64(-1))
                ])
            } else {
                // 新規リアクション
                try await postsCollection.document(postId).updateData([
                    "totalReactions": FieldValue.increment(Int64(1))
                ])
            }

            try await reactionDoc.setData([
                "type": reactionType,
                "userId": userId,
                "createdAt": Timestamp(date: Date())
            ])
            try await postsCollection.document(postId).updateData([
                "reactionCounts.\(reactionType)": FieldValue.increment(Int64(1))
            ])
        }
    }

    // MARK: - Toggle Reply Like

    private func replyLikesCollection(postId: String) -> CollectionReference {
        postsCollection.document(postId).collection("replyLikes")
    }

    private func replyLikeDocId(replyId: String, userId: String) -> String {
        "\(replyId)_\(userId)"
    }

    func toggleReplyLike(postId: String, replyId: String, userId: String) async throws -> Bool {
        let docId = replyLikeDocId(replyId: replyId, userId: userId)
        let likeDoc = replyLikesCollection(postId: postId).document(docId)

        let existing = try await likeDoc.getDocument()

        if existing.exists {
            // いいね解除
            try await likeDoc.delete()
            return false
        } else {
            // いいね追加
            try await likeDoc.setData([
                "userId": userId,
                "replyId": replyId,
                "createdAt": Timestamp(date: Date())
            ])
            return true
        }
    }

    func fetchMyReplyLikes(postId: String, userId: String, replyIds: [String]) async throws -> Set<String> {
        var likedIds: Set<String> = []
        for replyId in replyIds {
            let docId = replyLikeDocId(replyId: replyId, userId: userId)
            let doc = try await replyLikesCollection(postId: postId).document(docId).getDocument()
            if doc.exists {
                likedIds.insert(replyId)
            }
        }
        return likedIds
    }

    func fetchReplyLikeCounts(postId: String, replyIds: [String]) async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for replyId in replyIds {
            let snapshot = try await replyLikesCollection(postId: postId)
                .whereField("replyId", isEqualTo: replyId)
                .getDocuments()
            counts[replyId] = snapshot.documents.count
        }
        return counts
    }

    // MARK: - Report Post

    func reportPost(postId: String, reporterId: String, reason: String) async throws {
        try await db.collection("reports").addDocument(data: [
            "postId": postId,
            "reporterId": reporterId,
            "reason": reason,
            "createdAt": Timestamp(date: Date()),
            "status": "pending"
        ])
    }

    // MARK: - Save User Profile

    func saveUserProfile(userId: String, displayName: String, badge: LoveTypeBadge?) async throws {
        var data: [String: Any] = [
            "displayName": displayName,
            "updatedAt": Timestamp(date: Date())
        ]

        if let badge {
            data["badge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        } else {
            data["badge"] = FieldValue.delete()
        }

        try await usersCollection.document(userId).setData(data, merge: true)
    }

    // MARK: - Load User Badge

    func loadUserBadge(userId: String) async throws -> LoveTypeBadge? {
        let doc = try await usersCollection.document(userId).getDocument()
        guard let badgeData = doc.data()?["badge"] as? [String: Any],
              let typeCode = badgeData["typeCode"] as? String,
              let typeName = badgeData["typeName"] as? String,
              let totalScore = badgeData["totalScore"] as? Int else {
            return nil
        }
        return LoveTypeBadge(typeCode: typeCode, typeName: typeName, totalScore: totalScore)
    }

    // MARK: - Fetch My Reaction

    func fetchMyReaction(postId: String, userId: String) async throws -> String? {
        let doc = try await postsCollection.document(postId).collection("reactions").document(userId).getDocument()
        return doc.data()?["type"] as? String
    }

    // MARK: - Create Reply with Stamp

    func createStampReply(postId: String, stamp: BoardStamp, authorId: String, authorName: String, authorProfileImageURL: String? = nil, badge: LoveTypeBadge?) async throws -> BoardReply {
        let now = Timestamp(date: Date())

        let content = stamp.isImageStamp ? stamp.id : stamp.emoji
        var data: [String: Any] = [
            "authorId": authorId,
            "authorDisplayName": authorName,
            "content": content,
            "stampId": stamp.id,
            "stampCategory": stamp.category.rawValue,
            "createdAt": now
        ]

        if let authorProfileImageURL {
            data["authorProfileImageURL"] = authorProfileImageURL
        }

        if let badge {
            data["authorBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }

        let docRef = try await repliesCollection(postId: postId).addDocument(data: data)

        try await postsCollection.document(postId).updateData([
            "replyCount": FieldValue.increment(Int64(1))
        ])

        return BoardReply(
            id: docRef.documentID,
            postId: postId,
            authorId: authorId,
            authorDisplayName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            authorBadge: badge,
            content: content,
            stamp: stamp,
            imageURLs: [],
            likeCount: 0,
            createdAt: Date()
        )
    }

    // MARK: - Notifications

    func createReplyNotification(postAuthorId: String, postId: String, replierName: String) async throws {
        // 自分自身への通知は不要
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != postAuthorId else { return }

        try await db.collection("notifications").addDocument(data: [
            "userId": postAuthorId,
            "type": "reply",
            "postId": postId,
            "actorName": replierName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func createReactionNotification(postAuthorId: String, postId: String, reactorName: String) async throws {
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != postAuthorId else { return }

        try await db.collection("notifications").addDocument(data: [
            "userId": postAuthorId,
            "type": "reaction",
            "postId": postId,
            "actorName": reactorName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func createReplyLikeNotification(replyAuthorId: String, postId: String, likerName: String) async throws {
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != replyAuthorId else { return }

        try await db.collection("notifications").addDocument(data: [
            "userId": replyAuthorId,
            "type": "reply_like",
            "postId": postId,
            "actorName": likerName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func createMentionNotification(mentionedUserId: String, postId: String, actorName: String) async throws {
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != mentionedUserId else { return }

        try await db.collection("notifications").addDocument(data: [
            "userId": mentionedUserId,
            "type": "mention",
            "postId": postId,
            "actorName": actorName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    /// 引用 (quote) 通知 — 引用元 投稿者宛て
    func createQuoteNotification(originalAuthorId: String, postId: String, quoterName: String) async throws {
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != originalAuthorId else { return }
        try await db.collection("notifications").addDocument(data: [
            "userId": originalAuthorId,
            "type": "quote",
            "postId": postId,
            "actorName": quoterName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    /// リポスト通知 — 投稿者宛て
    func createRepostNotification(postAuthorId: String, postId: String, reposterName: String) async throws {
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != postAuthorId else { return }
        try await db.collection("notifications").addDocument(data: [
            "userId": postAuthorId,
            "type": "repost",
            "postId": postId,
            "actorName": reposterName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    /// ブックマーク通知 — 投稿者宛て
    func createBookmarkNotification(postAuthorId: String, postId: String, bookmarkerName: String) async throws {
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != postAuthorId else { return }
        try await db.collection("notifications").addDocument(data: [
            "userId": postAuthorId,
            "type": "bookmark",
            "postId": postId,
            "actorName": bookmarkerName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func createFollowNotification(targetUserId: String, followerName: String) async throws {
        guard let currentUserId = BoardAuthService.shared.currentUser?.id,
              currentUserId != targetUserId else { return }

        try await db.collection("notifications").addDocument(data: [
            "userId": targetUserId,
            "type": "follow",
            "postId": "",
            "actorName": followerName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func createFollowingPostNotification(followerIds: [String], postId: String, authorName: String) async throws {
        let currentUserId = BoardAuthService.shared.currentUser?.id

        for followerId in followerIds {
            guard followerId != currentUserId else { continue }
            try await db.collection("notifications").addDocument(data: [
                "userId": followerId,
                "type": "following_post",
                "postId": postId,
                "actorName": authorName,
                "read": false,
                "createdAt": Timestamp(date: Date())
            ])
        }
    }

    /// 自分のフォロワーIDリストを取得（投稿時の通知用）
    func getFollowerIds(userId: String) async throws -> [String] {
        let snapshot = try await followersCollection(userId: userId).getDocuments()
        return snapshot.documents.map { $0.documentID }
    }

    func fetchUnreadNotificationCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("read", isEqualTo: false)
            .getDocuments()

        let enabledTypes = NotificationPreferences.enabledTypes
        return snapshot.documents.filter { doc in
            guard let type = doc.data()["type"] as? String else { return false }
            return enabledTypes.contains(type)
        }.count
    }

    func fetchNotifications(userId: String) async throws -> [BoardNotification] {
        // 複合インデックス不要にするため、orderByを使わずローカルでソート
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        // ユーザーの通知設定で有効な種類のみ返す
        let enabledTypes = NotificationPreferences.enabledTypes

        let results = snapshot.documents.compactMap { doc -> BoardNotification? in
            let data = doc.data()
            guard let type = data["type"] as? String,
                  let actorName = data["actorName"] as? String,
                  let read = data["read"] as? Bool,
                  let ts = data["createdAt"] as? Timestamp else { return nil }

            let postId = data["postId"] as? String ?? ""

            // ユーザーが無効にしている通知タイプはスキップ
            guard enabledTypes.contains(type) else { return nil }

            return BoardNotification(
                id: doc.documentID,
                type: type,
                postId: postId,
                actorName: actorName,
                read: read,
                createdAt: ts.dateValue()
            )
        }

        return results.sorted { $0.createdAt > $1.createdAt }.prefix(50).map { $0 }
    }

    func markNotificationsRead(userId: String) async throws {
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("read", isEqualTo: false)
            .getDocuments()

        for doc in snapshot.documents {
            try await doc.reference.updateData(["read": true])
        }
    }

    // MARK: - Fetch Single Post

    func fetchPost(postId: String) async throws -> BoardPost? {
        let doc = try await postsCollection.document(postId).getDocument()
        guard doc.exists else { return nil }
        return try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
    }

    // MARK: - Delete Post

    func deletePost(postId: String) async throws {
        // 引用元のquoteCountをデクリメント
        let doc = try await postsCollection.document(postId).getDocument()
        if let data = doc.data(),
           let quotedPost = data["quotedPost"] as? [String: Any],
           let quotedPostId = quotedPost["postId"] as? String {
            try? await postsCollection.document(quotedPostId).updateData([
                "quoteCount": FieldValue.increment(Int64(-1))
            ])
            // デクリメント後の値を読み戻して伝搬(他ビューの combinedRepostCount を即座に減らす)
            if let updatedDoc = try? await postsCollection.document(quotedPostId).getDocument(),
               let newCount = updatedDoc.data()?["quoteCount"] as? Int {
                await MainActor.run {
                    BoardPostMutationBus.postQuoteCount(
                        .init(postId: quotedPostId, quoteCount: newCount)
                    )
                }
            }
        }
        try await postsCollection.document(postId).delete()
    }

    // MARK: - Upload Image

    func uploadImage(_ imageData: Data, postId: String) async throws -> String {
        let compressed = ImageCompressor.compressForPost(imageData) ?? imageData
        let result = try await R2StorageService.shared.uploadImage(
            data: compressed,
            type: .post,
            ownerId: postId
        )
        return result.url.absoluteString
    }

    // MARK: - Create Post with Images

    func createPostWithImages(content: String, authorId: String, authorName: String, authorProfileImageURL: String? = nil, badge: LoveTypeBadge?, diagnosisCard: DiagnosisCard?, quotedPost: QuotedPostInfo? = nil, postType: BoardPostType = .normal, pollOptions: [PollOption]? = nil, isAnonymous: Bool = false, authorIsPrivate: Bool = false, themes: [String] = [], communityRoomId: String? = nil, communityRoomTitle: String? = nil, images: [Data]) async throws -> BoardPost {
        let tempId = UUID().uuidString
        var imageURLs: [String] = []
        var uploadedKeys: [String] = []

        for imageData in images {
            let compressed = ImageCompressor.compressForPost(imageData) ?? imageData
            let result = try await R2StorageService.shared.uploadImage(
                data: compressed,
                type: .post,
                ownerId: tempId
            )
            uploadedKeys.append(result.key)
            imageURLs.append(result.url.absoluteString)
        }

        let now = Timestamp(date: Date())
        var data: [String: Any] = [
            "authorId": authorId,
            "authorDisplayName": authorName,
            "content": content,
            "postType": postType.rawValue,
            "isAnonymous": isAnonymous,
            "authorIsPrivate": authorIsPrivate,
            "language": LanguageManager.resolvedLanguage,
            "imageURLs": imageURLs,
            "themes": themes,
            "replyCount": 0,
            "quoteCount": 0,
            "repostCount": 0,
            "bookmarkCount": 0,
            "reactionCounts": [String: Int](),
            "totalReactions": 0,
            "totalVotes": 0,
            "viewCount": 0,
            "createdAt": now,
            "updatedAt": now
        ]

        if let authorProfileImageURL {
            data["authorProfileImageURL"] = authorProfileImageURL
        }

        if let communityRoomId {
            data["communityRoomId"] = communityRoomId
        }
        if let communityRoomTitle {
            data["communityRoomTitle"] = communityRoomTitle
        }

        if let badge {
            data["authorBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }

        if let card = diagnosisCard {
            data["diagnosisCard"] = Self.diagnosisCardDict(card)
        }

        if let quote = quotedPost {
            data["quotedPost"] = Self.quotedPostDict(quote)
        }

        if let options = pollOptions {
            data["pollOptions"] = options.map { [
                "id": $0.id,
                "text": $0.text,
                "voteCount": $0.voteCount
            ] as [String: Any] }
        }

        let docRef: DocumentReference
        do {
            docRef = try await postsCollection.addDocument(data: data)
        } catch {
            // Firestore書き込み失敗時、アップロード済み画像を削除
            for key in uploadedKeys {
                try? await R2StorageService.shared.deleteImage(key: key)
            }
            throw error
        }

        // 引用元の投稿のquoteCountをインクリメント + 引用元投稿者に通知
        if let quote = quotedPost {
            try? await postsCollection.document(quote.postId).updateData([
                "quoteCount": FieldValue.increment(Int64(1))
            ])
            if let quotedDoc = try? await postsCollection.document(quote.postId).getDocument() {
                let data = quotedDoc.data()
                if let newCount = data?["quoteCount"] as? Int {
                    await MainActor.run {
                        BoardPostMutationBus.postQuoteCount(
                            .init(postId: quote.postId, quoteCount: newCount)
                        )
                    }
                }
                if let quotedAuthorId = data?["authorId"] as? String {
                    try? await createQuoteNotification(
                        originalAuthorId: quotedAuthorId,
                        postId: docRef.documentID,
                        quoterName: isAnonymous ? "匿名ユーザー" : authorName
                    )
                }
            }
        }

        let displayName = isAnonymous
            ? String(localized: "匿名", bundle: LanguageManager.appBundle)
            : authorName

        return BoardPost(
            id: docRef.documentID,
            authorId: authorId,
            authorDisplayName: displayName,
            authorProfileImageURL: isAnonymous ? nil : authorProfileImageURL,
            authorBadge: isAnonymous ? nil : badge,
            postType: postType,
            content: content,
            imageURLs: imageURLs,
            diagnosisCard: diagnosisCard,
            quotedPost: quotedPost,
            stamp: nil,
            pollOptions: pollOptions,
            isAnonymous: isAnonymous,
            authorIsPrivate: authorIsPrivate,
            aiSummary: nil,
            language: LanguageManager.resolvedLanguage,
            themes: themes,
            communityRoomId: communityRoomId,
            communityRoomTitle: communityRoomTitle,
            totalVotes: 0,
            replyCount: 0,
            quoteCount: 0,
            repostCount: 0,
            bookmarkCount: 0,
            reactionCounts: [:],
            viewCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            myReaction: nil,
            myVote: nil
        )
    }

    // MARK: - View Count

    func incrementViewCount(postId: String) async throws {
        try await postsCollection.document(postId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])
    }

    // MARK: - Poll Vote

    private func votesCollection(postId: String) -> CollectionReference {
        postsCollection.document(postId).collection("votes")
    }

    /// 投票（1人1票。変更可能）
    func vote(postId: String, userId: String, optionId: String) async throws {
        let voteRef = votesCollection(postId: postId).document(userId)
        let postRef = postsCollection.document(postId)

        _ = try await db.runTransaction { transaction, errorPointer in
            // 既存投票を確認
            let voteDoc: DocumentSnapshot
            do {
                voteDoc = try transaction.getDocument(voteRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let oldOptionId = voteDoc.data()?["optionId"] as? String

            // 同じ選択肢なら何もしない
            if oldOptionId == optionId { return nil }

            // 投稿ドキュメントを取得
            let postDoc: DocumentSnapshot
            do {
                postDoc = try transaction.getDocument(postRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard var options = postDoc.data()?["pollOptions"] as? [[String: Any]] else {
                return nil
            }

            // 旧投票を減算
            if let oldId = oldOptionId {
                if let idx = options.firstIndex(where: { $0["id"] as? String == oldId }) {
                    let count = (options[idx]["voteCount"] as? Int) ?? 0
                    options[idx]["voteCount"] = max(0, count - 1)
                }
            }

            // 新投票を加算
            if let idx = options.firstIndex(where: { $0["id"] as? String == optionId }) {
                let count = (options[idx]["voteCount"] as? Int) ?? 0
                options[idx]["voteCount"] = count + 1
            }

            // totalVotes更新（新規投票の場合のみ+1）
            let totalDelta: Int64 = oldOptionId == nil ? 1 : 0

            transaction.setData(["optionId": optionId, "votedAt": FieldValue.serverTimestamp()], forDocument: voteRef)
            transaction.updateData([
                "pollOptions": options,
                "totalVotes": FieldValue.increment(totalDelta)
            ], forDocument: postRef)

            return nil
        }
    }

    /// ユーザーの投票を取得
    func fetchMyVote(postId: String, userId: String) async throws -> String? {
        let doc = try await votesCollection(postId: postId).document(userId).getDocument()
        return doc.data()?["optionId"] as? String
    }

    // MARK: - Reposts (リポスト)

    /// 投稿に対するリポスト一覧（投稿側）
    private func repostsCollection(postId: String) -> CollectionReference {
        postsCollection.document(postId).collection("reposts")
    }

    /// 自分の行ったリポスト一覧（ユーザー側）— マイページで自分のリポストを並べるために使う
    private func userRepostsCollection(userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("reposts")
    }

    /// リポストをトグル。
    /// 返り値 = リポスト後の状態（true = リポスト済み / false = 解除済み）。
    func toggleRepost(postId: String, userId: String, authorId: String) async throws -> Bool {
        let postRepostRef = repostsCollection(postId: postId).document(userId)
        let userRepostRef = userRepostsCollection(userId: userId).document(postId)

        let existing = try await postRepostRef.getDocument()
        let now = Timestamp(date: Date())

        if existing.exists {
            // 解除
            try await postRepostRef.delete()
            try? await userRepostRef.delete()
            try? await postsCollection.document(postId).updateData([
                "repostCount": FieldValue.increment(Int64(-1))
            ])
            return false
        } else {
            // 追加
            try await postRepostRef.setData([
                "userId": userId,
                "createdAt": now
            ])
            try await userRepostRef.setData([
                "postId": postId,
                "originalAuthorId": authorId,
                "createdAt": now
            ])
            try? await postsCollection.document(postId).updateData([
                "repostCount": FieldValue.increment(Int64(1))
            ])
            return true
        }
    }

    /// 自分がこの投稿をリポスト済みか
    func fetchIsReposted(postId: String, userId: String) async throws -> Bool {
        let doc = try await repostsCollection(postId: postId).document(userId).getDocument()
        return doc.exists
    }

    /// ユーザーのリポストを古い→新しい順で BoardPost として復元
    func getUserReposts(userId: String) async throws -> [(post: BoardPost, repostedAt: Date)] {
        let snapshot = try await userRepostsCollection(userId: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        let entries: [(postId: String, repostedAt: Date)] = snapshot.documents.compactMap { doc in
            guard let postId = doc.data()["postId"] as? String else { return nil }
            let repostedAt = (doc.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            return (postId, repostedAt)
        }

        // 個別の fetchPost を並列実行 (元実装は serial loop で N 倍のラウンドトリップ)
        return await withTaskGroup(of: (post: BoardPost, repostedAt: Date)?.self) { group in
            for entry in entries {
                group.addTask { [weak self] in
                    guard let self,
                          let post = try? await self.fetchPost(postId: entry.postId) else {
                        return nil
                    }
                    return (post, entry.repostedAt)
                }
            }
            var results: [(post: BoardPost, repostedAt: Date)] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            // 並列実行で順序が崩れるので元の repostedAt 降順を復元
            results.sort { $0.repostedAt > $1.repostedAt }
            return results
        }
    }

    // MARK: - Bookmark Count (display only — 実トグルは BoardBookmarkService)

    /// ブックマーク数のサーバー側カウンタを増減（ローカルトグルとペアで呼ぶ）。
    func incrementBookmarkCount(postId: String, delta: Int) async {
        do {
            try await postsCollection.document(postId).updateData([
                "bookmarkCount": FieldValue.increment(Int64(delta))
            ])
        } catch {
            print("[BoardFirestore] incrementBookmarkCount failed: \(error)")
        }
    }


    // MARK: - Diagnosis Card Helper

    /// `diagnosisCardDict` の逆変換。Firestore に dict 形式で格納された診断カードを
    /// DiagnosisCard モデルに復元する (相談部屋など、Codable 経路を使わない呼び出し元向け)。
    static func decodeDiagnosisCard(_ dict: [String: Any]) -> DiagnosisCard? {
        guard let typeCode = dict["typeCode"] as? String,
              let typeName = dict["typeName"] as? String,
              let totalScore = dict["totalScore"] as? Int,
              let balanceScore = dict["balanceScore"] as? Double,
              let tensionScore = dict["tensionScore"] as? Double,
              let responseScore = dict["responseScore"] as? Double,
              let wordScore = dict["wordScore"] as? Double else {
            return nil
        }
        var card = DiagnosisCard(
            typeCode: typeCode,
            typeName: typeName,
            totalScore: totalScore,
            balanceScore: balanceScore,
            tensionScore: tensionScore,
            responseScore: responseScore,
            wordScore: wordScore
        )
        if let s = dict["cardStyle"] as? String {
            card.cardStyle = DiagnosisCard.CardStyle(rawValue: s)
        }
        card.typeTagline = dict["typeTagline"] as? String
        card.typeDescription = dict["typeDescription"] as? String
        card.typeImageName = dict["typeImageName"] as? String
        card.relationshipLabel = dict["relationshipLabel"] as? String
        card.selfMBTI = dict["selfMBTI"] as? String
        card.partnerMBTI = dict["partnerMBTI"] as? String
        card.partnerMBTIs = dict["partnerMBTIs"] as? [String]
        if let words = dict["selfLoveWords"] as? [[String: Any]] {
            card.selfLoveWords = words.compactMap { d -> SharedPhraseCount? in
                guard let phrase = d["phrase"] as? String,
                      let count = d["count"] as? Int else { return nil }
                return SharedPhraseCount(phrase: phrase, count: count)
            }
        }
        if let words = dict["partnerLoveWords"] as? [[String: Any]] {
            card.partnerLoveWords = words.compactMap { d -> SharedPhraseCount? in
                guard let phrase = d["phrase"] as? String,
                      let count = d["count"] as? Int else { return nil }
                return SharedPhraseCount(phrase: phrase, count: count)
            }
        }
        card.selfLoveTotal = dict["selfLoveTotal"] as? Int
        card.partnerLoveTotal = dict["partnerLoveTotal"] as? Int
        return card
    }

    static func diagnosisCardDict(_ card: DiagnosisCard) -> [String: Any] {
        var dict: [String: Any] = [
            "typeCode": card.typeCode,
            "typeName": card.typeName,
            "totalScore": card.totalScore,
            "balanceScore": card.balanceScore,
            "tensionScore": card.tensionScore,
            "responseScore": card.responseScore,
            "wordScore": card.wordScore
        ]
        if let style = card.cardStyle { dict["cardStyle"] = style.rawValue }
        if let v = card.typeTagline { dict["typeTagline"] = v }
        if let v = card.typeDescription { dict["typeDescription"] = v }
        if let v = card.typeImageName { dict["typeImageName"] = v }
        if let v = card.relationshipLabel { dict["relationshipLabel"] = v }
        if let v = card.selfMBTI { dict["selfMBTI"] = v }
        if let v = card.partnerMBTI { dict["partnerMBTI"] = v }
        if let v = card.partnerMBTIs { dict["partnerMBTIs"] = v }
        if let words = card.selfLoveWords {
            dict["selfLoveWords"] = words.map { ["phrase": $0.phrase, "count": $0.count] }
        }
        if let words = card.partnerLoveWords {
            dict["partnerLoveWords"] = words.map { ["phrase": $0.phrase, "count": $0.count] }
        }
        if let v = card.selfLoveTotal { dict["selfLoveTotal"] = v }
        if let v = card.partnerLoveTotal { dict["partnerLoveTotal"] = v }
        return dict
    }

    // MARK: - Quoted Post Helper

    static func quotedPostDict(_ quote: QuotedPostInfo) -> [String: Any] {
        [
            "postId": quote.postId,
            "authorDisplayName": quote.authorDisplayName,
            "content": quote.content,
            "createdAt": Timestamp(date: quote.createdAt)
        ]
    }

    // MARK: - Profile

    private func countFollowers(userId: String) async throws -> Int {
        let snapshot = try await followersCollection(userId: userId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    private func countFollowing(userId: String) async throws -> Int {
        let snapshot = try await followingCollection(userId: userId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    func getProfile(userId: String) async throws -> BoardUserProfile {
        let doc = try await usersCollection.document(userId).getDocument()
        guard let data = doc.data() else {
            return BoardUserProfile(
                id: userId,
                displayName: BoardAuthService.shared.currentUser?.displayName ?? "ユーザー",
                bio: "",
                profileImageURL: nil,
                badge: nil,
                isPrivate: false,
                followerCount: 0,
                followingCount: 0,
                postCount: 0,
                createdAt: Date()
            )
        }
        // バッジを復元
        var badge: LoveTypeBadge?
        if let badgeData = data["badge"] as? [String: Any],
           let typeCode = badgeData["typeCode"] as? String,
           let typeName = badgeData["typeName"] as? String,
           let totalScore = badgeData["totalScore"] as? Int {
            badge = LoveTypeBadge(typeCode: typeCode, typeName: typeName, totalScore: totalScore)
        }

        // サブコレクションの全ドキュメントを読むとフォロー数に比例して遅くなるため、count aggregation を使う。
        async let followerCountFuture = countFollowers(userId: userId)
        async let followingCountFuture = countFollowing(userId: userId)
        let followerCount = (try? await followerCountFuture) ?? 0
        let followingCount = (try? await followingCountFuture) ?? 0

        return BoardUserProfile(
            id: userId,
            displayName: data["displayName"] as? String ?? "ユーザー",
            bio: data["bio"] as? String ?? "",
            profileImageURL: data["profileImageURL"] as? String,
            badge: badge,
            isPrivate: data["isPrivate"] as? Bool ?? false,
            followerCount: followerCount,
            followingCount: followingCount,
            postCount: data["postCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    // MARK: - Push Token

    /// APNsデバイストークンをFirestoreユーザードキュメントに保存（Cloud Functions用）
    func savePushToken(userId: String, token: String) async {
        do {
            try await usersCollection.document(userId).setData([
                "apnsToken": token,
                "tokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("[BoardFirestore] Failed to save push token: \(error)")
        }
    }

    // MARK: - Notification Preferences

    /// 自分の通知設定を取得 (未保存ならデフォルト = 全 ON)。
    func fetchBoardNotificationPrefs(userId: String) async -> BoardNotificationPrefs {
        guard let doc = try? await usersCollection.document(userId).getDocument(),
              let data = doc.data() else {
            return .allEnabled
        }
        return BoardNotificationPrefs.from(dict: data["notificationPrefs"] as? [String: Any])
    }

    /// 通知設定を Firestore に保存。Cloud Functions 側で各通知トリガー時にここを参照する。
    func saveBoardNotificationPrefs(userId: String, prefs: BoardNotificationPrefs) async throws {
        try await usersCollection.document(userId).setData([
            "notificationPrefs": prefs.toDict,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    /// Firestoreにプロフィールが存在するかチェック
    func hasExistingProfile(userId: String) async -> Bool {
        guard let doc = try? await usersCollection.document(userId).getDocument(),
              let data = doc.data(),
              data["displayName"] != nil else {
            return false
        }
        return true
    }

    func updateProfile(userId: String, displayName: String, bio: String, profileImageURL: String?) async throws {
        var data: [String: Any] = [
            "displayName": displayName,
            "bio": bio,
            // 検索用の部分一致 indexed フィールド (searchUsers の arrayContains 対象)。
            "searchKeywords": Self.searchKeywords(for: displayName),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let url = profileImageURL {
            data["profileImageURL"] = url
        }
        try await usersCollection.document(userId).setData(data, merge: true)

        // Update displayName on auth
        if let user = Auth.auth().currentUser {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }
    }

    func uploadProfileImage(userId: String, imageData: Data) async throws -> String {
        let compressed = ImageCompressor.compressForProfile(imageData) ?? imageData
        let result = try await R2StorageService.shared.uploadImage(
            data: compressed,
            type: .profile,
            ownerId: userId
        )
        // R2 のプロフィール画像は同じ key (`profile_images/{uid}.jpg`) で常に上書きされるが、
        // CDN/ブラウザ側では URL がキャッシュされてしまうため、cache-busting に updatedAt クエリを付ける。
        return "\(result.url.absoluteString)?v=\(Int(Date().timeIntervalSince1970))"
    }

    /// ユーザーが投稿した記事を取得。
    /// - Parameter includeAnonymous: 匿名投稿を含めるか。
    ///   自分自身のマイページから取得する時のみ true を渡し、他人プロフィールでは false (匿名は隠す)。
    func getUserPosts(userId: String, includeAnonymous: Bool = false) async throws -> [BoardPost] {
        let snapshot: QuerySnapshot
        do {
            // Composite index (authorId + createdAt) が必要
            snapshot = try await postsCollection
                .whereField("authorId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
        } catch {
            // インデックス未作成時のフォールバック（ソートなし → クライアント側でソート）
            print("[Board] Composite index fallback: \(error)")
            let fallback = try await postsCollection
                .whereField("authorId", isEqualTo: userId)
                .limit(to: 50)
                .getDocuments()
            return fallback.documents
                .compactMap { doc -> BoardPost? in
                    try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
                }
                .filter { includeAnonymous || !$0.isAnonymous }
                .sorted { $0.createdAt > $1.createdAt }
        }

        return snapshot.documents.compactMap { doc -> BoardPost? in
            try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
        }
        .filter { includeAnonymous || !$0.isAnonymous }
    }

    // MARK: - Follow / Unfollow

    func followUser(currentUserId: String, targetUserId: String, targetProfile: BoardUserProfile) async throws {
        // 1) 自分のfollowingサブコレクションに追加
        let followingRef = followingCollection(userId: currentUserId).document(targetUserId)
        var followingData: [String: Any] = [
            "displayName": targetProfile.displayName,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let imageURL = targetProfile.profileImageURL {
            followingData["profileImageURL"] = imageURL
        }
        if let badge = targetProfile.badge {
            followingData["badge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }
        try await followingRef.setData(followingData)

        // 2) 相手のfollowersサブコレクションに追加
        let currentDisplayName = BoardAuthService.shared.currentUser?.displayName ?? "ユーザー"
        let followerRef = followersCollection(userId: targetUserId).document(currentUserId)
        var followerData: [String: Any] = [
            "displayName": currentDisplayName,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let myBadge = try? await loadUserBadge(userId: currentUserId) {
            followerData["badge"] = [
                "typeCode": myBadge.typeCode,
                "typeName": myBadge.typeName,
                "totalScore": myBadge.totalScore
            ]
        }
        try await followerRef.setData(followerData)
    }

    func unfollowUser(currentUserId: String, targetUserId: String) async throws {
        // 自分のfollowingから削除
        try await followingCollection(userId: currentUserId).document(targetUserId).delete()

        // 相手のfollowersから削除
        try await followersCollection(userId: targetUserId).document(currentUserId).delete()
    }

    // MARK: - Follow Requests（非公開アカウント用）

    /// フォローリクエストを送信
    func sendFollowRequest(currentUserId: String, targetUserId: String) async throws {
        let currentUser = BoardAuthService.shared.currentUser
        let displayName = currentUser?.displayName ?? "ユーザー"

        var data: [String: Any] = [
            "requesterId": currentUserId,
            "requesterDisplayName": displayName,
            "createdAt": FieldValue.serverTimestamp()
        ]

        // プロフィール画像があれば追加
        if let profile = try? await getProfile(userId: currentUserId),
           let imageURL = profile.profileImageURL {
            data["requesterProfileImageURL"] = imageURL
        }

        // バッジがあれば追加
        if let badge = try? await loadUserBadge(userId: currentUserId) {
            data["requesterBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }

        try await followRequestsCollection(userId: targetUserId).document(currentUserId).setData(data)
    }

    /// フォローリクエストを承認
    func acceptFollowRequest(currentUserId: String, requesterId: String) async throws {
        // リクエスト情報を取得
        let requestDoc = try await followRequestsCollection(userId: currentUserId).document(requesterId).getDocument()
        let requestData = requestDoc.data()

        // 相手のfollowing に自分を追加
        let followingRef = followingCollection(userId: requesterId).document(currentUserId)
        let myProfile = try await getProfile(userId: currentUserId)
        var followingData: [String: Any] = [
            "displayName": myProfile.displayName,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let imageURL = myProfile.profileImageURL {
            followingData["profileImageURL"] = imageURL
        }
        if let badge = myProfile.badge {
            followingData["badge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }
        try await followingRef.setData(followingData)

        // 自分のfollowers にリクエスト者を追加
        let followerRef = followersCollection(userId: currentUserId).document(requesterId)
        var followerData: [String: Any] = [
            "displayName": requestData?["requesterDisplayName"] as? String ?? "ユーザー",
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let imageURL = requestData?["requesterProfileImageURL"] as? String {
            followerData["profileImageURL"] = imageURL
        }
        if let badgeData = requestData?["requesterBadge"] as? [String: Any] {
            followerData["badge"] = badgeData
        }
        try await followerRef.setData(followerData)

        // リクエストを削除
        try await followRequestsCollection(userId: currentUserId).document(requesterId).delete()

        // 承認通知を送信
        let acceptorName = myProfile.displayName
        try await createFollowRequestAcceptedNotification(requesterId: requesterId, acceptorName: acceptorName)
    }

    /// フォローリクエストを拒否
    func rejectFollowRequest(currentUserId: String, requesterId: String) async throws {
        try await followRequestsCollection(userId: currentUserId).document(requesterId).delete()
    }

    /// フォローリクエストを取り消し
    func cancelFollowRequest(currentUserId: String, targetUserId: String) async throws {
        try await followRequestsCollection(userId: targetUserId).document(currentUserId).delete()
    }

    /// 保留中のフォローリクエストを取得
    func fetchPendingFollowRequests(userId: String) async throws -> [FollowRequest] {
        let snapshot = try await followRequestsCollection(userId: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            var badge: LoveTypeBadge?
            if let badgeData = data["requesterBadge"] as? [String: Any],
               let typeCode = badgeData["typeCode"] as? String,
               let typeName = badgeData["typeName"] as? String,
               let totalScore = badgeData["totalScore"] as? Int {
                badge = LoveTypeBadge(typeCode: typeCode, typeName: typeName, totalScore: totalScore)
            }
            return FollowRequest(
                id: doc.documentID,
                requesterId: data["requesterId"] as? String ?? doc.documentID,
                requesterDisplayName: data["requesterDisplayName"] as? String ?? "ユーザー",
                requesterProfileImageURL: data["requesterProfileImageURL"] as? String,
                requesterBadge: badge,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }

    /// 保留中のフォローリクエスト数
    func fetchPendingFollowRequestCount(userId: String) async throws -> Int {
        let snapshot = try await followRequestsCollection(userId: userId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    /// フォロー状態を取得（following / requested / notFollowing）
    func getFollowState(currentUserId: String, targetUserId: String) async throws -> FollowState {
        // まずフォロー中か確認
        let followingDoc = try await followingCollection(userId: currentUserId).document(targetUserId).getDocument()
        if followingDoc.exists { return .following }

        // リクエスト中か確認
        let requestDoc = try await followRequestsCollection(userId: targetUserId).document(currentUserId).getDocument()
        if requestDoc.exists { return .requested }

        return .notFollowing
    }

    /// フォロワーを削除（ブロックとは別）
    func removeFollower(currentUserId: String, followerId: String) async throws {
        // 自分のfollowersから削除
        try await followersCollection(userId: currentUserId).document(followerId).delete()
        // 相手のfollowingから自分を削除
        try await followingCollection(userId: followerId).document(currentUserId).delete()
    }

    // MARK: - Privacy Toggle

    /// 公開/非公開を切り替え
    func togglePrivacy(userId: String, isPrivate: Bool) async throws {
        try await usersCollection.document(userId).setData(["isPrivate": isPrivate], merge: true)

        // 非公開→公開：保留中リクエストを全て承認
        if !isPrivate {
            try await approveAllPendingRequests(userId: userId)
        }

        // 全投稿のauthorIsPrivateフラグを更新
        try await updatePostsPrivacyFlag(userId: userId, isPrivate: isPrivate)
    }

    private func approveAllPendingRequests(userId: String) async throws {
        let snapshot = try await followRequestsCollection(userId: userId).getDocuments()
        for doc in snapshot.documents {
            try await acceptFollowRequest(currentUserId: userId, requesterId: doc.documentID)
        }
    }

    private func updatePostsPrivacyFlag(userId: String, isPrivate: Bool) async throws {
        let snapshot = try await postsCollection
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.updateData(["authorIsPrivate": isPrivate])
        }
    }

    /// プロフィール変更を過去の投稿に一括反映
    func updatePostsAuthorInfo(userId: String, displayName: String, profileImageURL: String?, badge: LoveTypeBadge?) async throws {
        let snapshot = try await postsCollection
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()

        var updateData: [String: Any] = [
            "authorDisplayName": displayName
        ]
        if let profileImageURL {
            updateData["authorProfileImageURL"] = profileImageURL
        } else {
            updateData["authorProfileImageURL"] = FieldValue.delete()
        }
        if let badge {
            updateData["authorBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        } else {
            updateData["authorBadge"] = FieldValue.delete()
        }

        for doc in snapshot.documents {
            try await doc.reference.updateData(updateData)
        }

        // 全投稿への返信も更新（collectionGroup）
        if let allRepliesSnapshot = try? await db.collectionGroup("replies")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments() {
            for replyDoc in allRepliesSnapshot.documents {
                try await replyDoc.reference.updateData(updateData)
            }
        }
    }

    // MARK: - Follow Request Notifications

    func createFollowRequestNotification(targetUserId: String, requesterName: String) async throws {
        try await db.collection("notifications").addDocument(data: [
            "userId": targetUserId,
            "type": "follow_request",
            "postId": "",
            "actorName": requesterName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func createFollowRequestAcceptedNotification(requesterId: String, acceptorName: String) async throws {
        try await db.collection("notifications").addDocument(data: [
            "userId": requesterId,
            "type": "follow_request_accepted",
            "postId": "",
            "actorName": acceptorName,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool {
        let doc = try await followingCollection(userId: currentUserId).document(targetUserId).getDocument()
        return doc.exists
    }

    func getFollowers(userId: String) async throws -> [FollowRelationship] {
        let snapshot = try await followersCollection(userId: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.map { doc in
            let data = doc.data()
            var badge: LoveTypeBadge?
            if let badgeData = data["badge"] as? [String: Any],
               let typeCode = badgeData["typeCode"] as? String,
               let typeName = badgeData["typeName"] as? String,
               let totalScore = badgeData["totalScore"] as? Int {
                badge = LoveTypeBadge(typeCode: typeCode, typeName: typeName, totalScore: totalScore)
            }
            return FollowRelationship(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "ユーザー",
                profileImageURL: data["profileImageURL"] as? String,
                badge: badge,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }

    func getFollowing(userId: String) async throws -> [FollowRelationship] {
        let snapshot = try await followingCollection(userId: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.map { doc in
            let data = doc.data()
            var badge: LoveTypeBadge?
            if let badgeData = data["badge"] as? [String: Any],
               let typeCode = badgeData["typeCode"] as? String,
               let typeName = badgeData["typeName"] as? String,
               let totalScore = badgeData["totalScore"] as? Int {
                badge = LoveTypeBadge(typeCode: typeCode, typeName: typeName, totalScore: totalScore)
            }
            return FollowRelationship(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "ユーザー",
                profileImageURL: data["profileImageURL"] as? String,
                badge: badge,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }

    /// フォロー中ユーザーのIDだけを軽量に取得
    func getFollowingIds(userId: String) async throws -> Set<String> {
        let snapshot = try await followingCollection(userId: userId).getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }

    // MARK: - Search

    /// 投稿をキーワード検索（クライアント側フィルタ）
    func searchPosts(query: String, limit: Int = 50, followingIds: Set<String> = [], userLanguage: String? = nil) async throws -> [BoardPost] {
        let snapshot = try await postsCollection
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .getDocuments()

        let allPosts = snapshot.documents.compactMap { doc -> BoardPost? in
            try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
        }

        let lowered = query.lowercased()
        let matched = allPosts.filter { post in
            // 非公開アカウントの非匿名投稿は検索結果から除外（フォロワーを除く）
            if post.authorIsPrivate == true && !post.isAnonymous && !followingIds.contains(post.authorId) {
                return false
            }
            return post.content.lowercased().contains(lowered) ||
                post.authorDisplayName.lowercased().contains(lowered)
        }

        // 同言語の投稿を先頭に並べてから limit
        let prioritized: [BoardPost]
        if let lang = userLanguage {
            prioritized = Self.sortByLanguagePriority(matched, userLanguage: lang, followingIds: followingIds)
        } else {
            prioritized = matched
        }
        return Array(prioritized.prefix(limit))
    }

    /// displayName から部分一致検索用のキーワード配列を生成する。
    /// 長さ 1〜4 の全部分文字列を小文字化してユニークに抽出 (例: "メロ女子" → ["メ","ロ","女","子","メロ","ロ女","女子","メロ女","ロ女子","メロ女子"])。
    /// この配列を `users.searchKeywords` に保存し、Firestore の `arrayContains` で indexed 検索する。
    static func searchKeywords(for displayName: String) -> [String] {
        let normalized = displayName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        var keywords = Set<String>()
        let chars = Array(normalized)
        let n = chars.count
        let maxLen = min(n, 4)
        for length in 1...maxLen {
            for start in 0...(n - length) {
                keywords.insert(String(chars[start..<(start + length)]))
            }
        }
        return Array(keywords)
    }

    /// ユーザーをキーワード検索（displayName部分一致）。
    /// `users.searchKeywords` (長さ1〜4の部分文字列配列) に対して `arrayContains` で indexed 検索する。
    /// クエリが 5文字以上ある場合は先頭 4文字で arrayContains して、その結果に対してクライアント側で部分一致を絞り込む。
    /// 旧データ (searchKeywords 未設定) も拾えるよう displayName 順スキャンによるフォールバックも併用。
    func searchUsers(query: String, limit: Int = 20, followingIds: Set<String> = []) async throws -> [BoardUserProfile] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowered.isEmpty else { return [] }

        // arrayContains は単一文字列マッチなので、クエリの先頭 4文字までを lookup key にする。
        let lookupKey = String(lowered.prefix(4))

        // ① 新方式: searchKeywords arrayContains (indexed)
        let primary = (try? await usersCollection
            .whereField("searchKeywords", arrayContains: lookupKey)
            .limit(to: 100)
            .getDocuments()) ?? nil

        // ② フォールバック: searchKeywords が未設定の旧 doc を救う (displayName 順 limit)
        let fallback = try? await usersCollection
            .whereField("displayName", isGreaterThan: "")
            .order(by: "displayName")
            .limit(to: 400)
            .getDocuments()

        var seen = Set<String>()
        var documents: [QueryDocumentSnapshot] = []
        for doc in (primary?.documents ?? []) {
            if seen.insert(doc.documentID).inserted { documents.append(doc) }
        }
        for doc in (fallback?.documents ?? []) {
            if seen.insert(doc.documentID).inserted { documents.append(doc) }
        }

        return documents.compactMap { doc -> BoardUserProfile? in
            let data = doc.data()
            guard let displayName = data["displayName"] as? String else { return nil }
            guard displayName.lowercased().contains(lowered) else { return nil }

            let isPrivate = data["isPrivate"] as? Bool ?? false

            return BoardUserProfile(
                id: doc.documentID,
                displayName: displayName,
                bio: data["bio"] as? String ?? "",
                profileImageURL: data["profileImageURL"] as? String,
                badge: nil,
                isPrivate: isPrivate,
                followerCount: data["followerCount"] as? Int ?? 0,
                followingCount: data["followingCount"] as? Int ?? 0,
                postCount: data["postCount"] as? Int ?? 0,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }.prefix(limit).map { $0 }
    }

    // MARK: - Realtime Listener

    private var feedListener: ListenerRegistration?
    /// おすすめタブ用のキャッシュ（投稿IDの順序を保持）
    private var cachedPopularOrder: [String] = []
    private var lastPopularRankTime: Date = .distantPast

    func listenToPosts(sort: BoardFeedSort, limit: Int = 20, followingIds: Set<String> = [], userLanguage: String? = nil, onUpdate: @escaping ([BoardPost]) -> Void) {
        feedListener?.remove()

        var query: Query
        switch sort {
        case .latest:
            query = postsCollection.order(by: "createdAt", descending: true)
            query = query.limit(to: limit)
        case .popular:
            // おすすめ: 全投稿を取得 → クライアント側でランキング
            query = postsCollection
                .order(by: "createdAt", descending: true)
                .limit(to: 200)
        case .following:
            // フォロー中: 全投稿を取得してクライアント側でフィルタ
            query = postsCollection.order(by: "createdAt", descending: true).limit(to: 50)
        }

        feedListener = query.addSnapshotListener { [self] snapshot, error in
            guard let snapshot, error == nil else { return }
            var posts = snapshot.documents.compactMap { doc -> BoardPost? in
                try? doc.data(as: FirestorePost.self).toBoardPost(id: doc.documentID)
            }
            if sort == .popular {
                let postIds = Set(posts.map(\.id))
                let cachedIds = Set(cachedPopularOrder)
                // キャッシュ済みの投稿がクエリ結果から消えた場合のみ再ランキング
                // いいね/返信でデータが変わっただけでは順序を変えない
                let cachedPostMissing = !cachedPopularOrder.isEmpty && !cachedIds.isSubset(of: postIds)
                let shouldReRank = cachedPopularOrder.isEmpty || cachedPostMissing

                if shouldReRank {
                    posts = Self.rankPosts(posts, followingIds: followingIds, userLanguage: userLanguage)
                    cachedPopularOrder = posts.map(\.id)
                    lastPopularRankTime = Date()
                } else {
                    // キャッシュされた順序を維持しつつデータだけ更新
                    let postMap = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
                    posts = cachedPopularOrder.compactMap { postMap[$0] }
                }
            } else if sort == .latest, let lang = userLanguage {
                posts = Self.sortByLanguagePriority(posts, userLanguage: lang, followingIds: followingIds)
            } else if sort == .following {
                posts = posts.filter { followingIds.contains($0.authorId) }
            }
            onUpdate(posts)
        }
    }

    func stopListening() {
        feedListener?.remove()
        feedListener = nil
    }

    /// おすすめの順序キャッシュをリセット（pull-to-refresh時）
    func resetPopularCache() {
        cachedPopularOrder = []
        lastPopularRankTime = .distantPast
    }
}

// MARK: - Firestore Codable Models

private struct FirestorePost: Codable {
    let authorId: String
    let authorDisplayName: String
    let authorProfileImageURL: String?
    let authorBadge: FirestoreBadge?
    let postType: String?
    let content: String
    let imageURLs: [String]?
    let diagnosisCard: FirestoreDiagnosisCard?
    let quotedPost: FirestoreQuotedPost?
    let pollOptions: [FirestorePollOption]?
    let isAnonymous: Bool?
    let authorIsPrivate: Bool?
    let aiSummary: String?
    let language: String?
    let themes: [String]?
    let communityRoomId: String?
    let communityRoomTitle: String?
    let totalVotes: Int?
    let replyCount: Int?
    let quoteCount: Int?
    let repostCount: Int?
    let bookmarkCount: Int?
    let reactionCounts: [String: Int]?
    let viewCount: Int?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?

    func toBoardPost(id: String) -> BoardPost {
        let type = BoardPostType(rawValue: postType ?? "normal") ?? .normal
        let anonymous = isAnonymous ?? false
        let displayName = anonymous
            ? String(localized: "匿名", bundle: LanguageManager.appBundle)
            : authorDisplayName

        return BoardPost(
            id: id,
            authorId: authorId,
            authorDisplayName: displayName,
            authorProfileImageURL: anonymous ? nil : authorProfileImageURL,
            authorBadge: anonymous ? nil : authorBadge?.toLoveTypeBadge(),
            postType: type,
            content: content,
            imageURLs: imageURLs ?? [],
            diagnosisCard: diagnosisCard?.toDiagnosisCard(),
            quotedPost: quotedPost?.toQuotedPostInfo(),
            stamp: nil,
            pollOptions: pollOptions?.map { $0.toPollOption() },
            isAnonymous: isAnonymous ?? false,
            authorIsPrivate: authorIsPrivate,
            aiSummary: aiSummary,
            language: language,
            themes: themes ?? [],
            communityRoomId: communityRoomId,
            communityRoomTitle: communityRoomTitle,
            totalVotes: totalVotes ?? 0,
            replyCount: replyCount ?? 0,
            quoteCount: quoteCount ?? 0,
            repostCount: repostCount ?? 0,
            bookmarkCount: bookmarkCount ?? 0,
            reactionCounts: reactionCounts ?? [:],
            viewCount: viewCount ?? 0,
            createdAt: createdAt?.dateValue() ?? Date(),
            updatedAt: updatedAt?.dateValue() ?? Date(),
            myReaction: nil,
            myVote: nil
        )
    }
}

private struct FirestorePollOption: Codable {
    let id: String
    let text: String
    let voteCount: Int

    func toPollOption() -> PollOption {
        PollOption(id: id, text: text, voteCount: voteCount)
    }
}

private struct FirestoreQuotedPost: Codable {
    let postId: String
    let authorDisplayName: String
    let content: String
    @ServerTimestamp var createdAt: Timestamp?

    func toQuotedPostInfo() -> QuotedPostInfo {
        QuotedPostInfo(
            postId: postId,
            authorDisplayName: authorDisplayName,
            content: content,
            createdAt: createdAt?.dateValue() ?? Date()
        )
    }
}

private struct FirestoreReply: Decodable {
    let authorId: String
    let authorDisplayName: String
    let authorProfileImageURL: String?
    let authorBadge: FirestoreBadge?
    let content: String
    let stampId: String?
    let stampCategory: String?
    let imageURLs: [String]
    let likeCount: Int
    let mentionedReplyId: String?
    let mentionedUserName: String?
    var createdAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case authorId, authorDisplayName, authorProfileImageURL, authorBadge
        case content, stampId, stampCategory, imageURL, imageURLs
        case likeCount, mentionedReplyId, mentionedUserName, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorDisplayName = try container.decode(String.self, forKey: .authorDisplayName)
        authorProfileImageURL = try container.decodeIfPresent(String.self, forKey: .authorProfileImageURL)
        authorBadge = try container.decodeIfPresent(FirestoreBadge.self, forKey: .authorBadge)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        stampId = try container.decodeIfPresent(String.self, forKey: .stampId)
        stampCategory = try container.decodeIfPresent(String.self, forKey: .stampCategory)
        // imageURLs（配列）優先、なければ旧imageURL（単体）をフォールバック
        if let urls = try? container.decodeIfPresent([String].self, forKey: .imageURLs), !urls.isEmpty {
            imageURLs = urls
        } else if let single = try container.decodeIfPresent(String.self, forKey: .imageURL) {
            imageURLs = [single]
        } else {
            imageURLs = []
        }
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        mentionedReplyId = try container.decodeIfPresent(String.self, forKey: .mentionedReplyId)
        mentionedUserName = try container.decodeIfPresent(String.self, forKey: .mentionedUserName)
        createdAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt)
    }

    func toBoardReply(id: String, postId: String) -> BoardReply {
        var stamp: BoardStamp?
        if let stampId, let stampCategory {
            // 新カテゴリにマッチしない旧データは .reaction にフォールバック
            let category = BoardStamp.StampCategory(rawValue: stampCategory) ?? .reaction
            stamp = BoardStamp(id: stampId, category: category)
        }

        return BoardReply(
            id: id,
            postId: postId,
            authorId: authorId,
            authorDisplayName: authorDisplayName,
            authorProfileImageURL: authorProfileImageURL,
            authorBadge: authorBadge?.toLoveTypeBadge(),
            content: content,
            stamp: stamp,
            imageURLs: imageURLs,
            likeCount: likeCount,
            mentionedReplyId: mentionedReplyId,
            mentionedUserName: mentionedUserName,
            createdAt: createdAt?.dateValue() ?? Date()
        )
    }
}

private struct FirestoreBadge: Codable {
    let typeCode: String
    let typeName: String
    let totalScore: Int

    func toLoveTypeBadge() -> LoveTypeBadge {
        LoveTypeBadge(typeCode: typeCode, typeName: typeName, totalScore: totalScore)
    }
}

private struct FirestoreDiagnosisCard: Codable {
    let typeCode: String
    let typeName: String
    let totalScore: Int
    let balanceScore: Double
    let tensionScore: Double
    let responseScore: Double
    let wordScore: Double
    // Card style & extended fields
    let cardStyle: String?
    let typeTagline: String?
    let typeDescription: String?
    let typeImageName: String?
    let animalType: String?
    let animalIcon: String?
    let loveCharacter: String?
    let loveCharacterIcon: String?
    let roleType: String?
    let catchphrase: String?
    let relationshipLabel: String?
    let selfMBTI: String?
    let partnerMBTI: String?
    let partnerMBTIs: [String]?
    // Love words fields
    let selfLoveWords: [FirestorePhraseCount]?
    let partnerLoveWords: [FirestorePhraseCount]?
    let selfLoveTotal: Int?
    let partnerLoveTotal: Int?

    func toDiagnosisCard() -> DiagnosisCard {
        var card = DiagnosisCard(
            typeCode: typeCode,
            typeName: typeName,
            totalScore: totalScore,
            balanceScore: balanceScore,
            tensionScore: tensionScore,
            responseScore: responseScore,
            wordScore: wordScore
        )
        if let styleStr = cardStyle {
            card.cardStyle = DiagnosisCard.CardStyle(rawValue: styleStr)
        }
        card.typeTagline = typeTagline
        card.typeDescription = typeDescription
        card.typeImageName = typeImageName
        card.relationshipLabel = relationshipLabel
        card.selfMBTI = selfMBTI
        card.partnerMBTI = partnerMBTI
        card.partnerMBTIs = partnerMBTIs
        card.selfLoveWords = selfLoveWords?.map { SharedPhraseCount(phrase: $0.phrase, count: $0.count) }
        card.partnerLoveWords = partnerLoveWords?.map { SharedPhraseCount(phrase: $0.phrase, count: $0.count) }
        card.selfLoveTotal = selfLoveTotal
        card.partnerLoveTotal = partnerLoveTotal
        return card
    }
}

private struct FirestorePhraseCount: Codable {
    let phrase: String
    let count: Int
}

// MARK: - Account Deletion

extension BoardFirestoreService {
    /// ユーザーに関連するFirestoreデータとStorageファイルを削除
    /// 他ユーザーのサブコレクションへの書き込みはセキュリティルールで拒否されるため、
    /// 自分が所有するデータのみ削除する。相手側の参照は孤立するが表示時にハンドルされる。
    func deleteAllUserData(userId: String) async {
        // 1) ユーザーの全投稿を削除
        if let postsSnapshot = try? await postsCollection
            .whereField("authorId", isEqualTo: userId)
            .getDocuments() {
            for doc in postsSnapshot.documents {
                try? await deletePost(postId: doc.documentID)
            }
        }

        // 2) 自分のフォロワー/フォロー中/リクエストのサブコレクションを削除
        // ※ 他ユーザーのサブコレクションは権限がないためスキップ
        if let followersSnap = try? await followersCollection(userId: userId).getDocuments() {
            for doc in followersSnap.documents {
                try? await doc.reference.delete()
            }
        }

        if let followingSnap = try? await followingCollection(userId: userId).getDocuments() {
            for doc in followingSnap.documents {
                try? await doc.reference.delete()
            }
        }

        if let requestsSnap = try? await followRequestsCollection(userId: userId).getDocuments() {
            for doc in requestsSnap.documents {
                try? await doc.reference.delete()
            }
        }

        // 3) 自分宛ての通知を削除
        if let notifSnap = try? await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments() {
            for doc in notifSnap.documents {
                try? await doc.reference.delete()
            }
        }

        // 4) プロフィール画像を R2 から削除 (旧 Firebase Storage の残骸も best-effort で消す)
        try? await R2StorageService.shared.deleteImage(key: "profile_images/\(userId).jpg")
        let legacyStorageRef = Storage.storage().reference().child("profile_images/\(userId).jpg")
        try? await legacyStorageRef.delete()

        // 5) ユーザードキュメントを削除
        try? await usersCollection.document(userId).delete()
    }

    // MARK: - Bookmarks (cross-app sync via Firestore)

    /// ユーザーのブックマーク済み投稿IDをFirestoreから取得。
    /// LINE版とIG版で同じ uid を共有するため、片方で保存した bookmark がもう片方にも反映される。
    func fetchBookmarkedPostIds(userId: String) async -> [String] {
        do {
            let snap = try await usersCollection.document(userId).getDocument()
            return snap.get("bookmarkedPostIds") as? [String] ?? []
        } catch {
            print("[BoardFirestore] fetchBookmarkedPostIds failed: \(error)")
            return []
        }
    }

    /// ブックマークを追加 (arrayUnion で重複なし)。
    func addBookmark(userId: String, postId: String) async {
        do {
            try await usersCollection.document(userId).setData([
                "bookmarkedPostIds": FieldValue.arrayUnion([postId])
            ], merge: true)
        } catch {
            print("[BoardFirestore] addBookmark failed: \(error)")
        }
    }

    /// ブックマークを削除。
    func removeBookmark(userId: String, postId: String) async {
        do {
            try await usersCollection.document(userId).setData([
                "bookmarkedPostIds": FieldValue.arrayRemove([postId])
            ], merge: true)
        } catch {
            print("[BoardFirestore] removeBookmark failed: \(error)")
        }
    }

    // MARK: - Joined Theme Rooms (cross-app sync via Firestore)

    /// 参加中のテーマ相談部屋IDを Firestore から取得。
    /// 通常の相談部屋は CommunityRoomFirestoreService 側で同期されているが、
    /// テーマ部屋 (id="theme:...") は仮想ルームのため Firestore に書けず、
    /// 別途 users/{uid}.joinedThemeRoomIds 配列で管理する。
    func fetchJoinedThemeRoomIds(userId: String) async -> [String] {
        do {
            let snap = try await usersCollection.document(userId).getDocument()
            return snap.get("joinedThemeRoomIds") as? [String] ?? []
        } catch {
            print("[BoardFirestore] fetchJoinedThemeRoomIds failed: \(error)")
            return []
        }
    }

    /// テーマ部屋への参加を記録。
    func joinThemeRoom(userId: String, themeRoomId: String) async {
        do {
            try await usersCollection.document(userId).setData([
                "joinedThemeRoomIds": FieldValue.arrayUnion([themeRoomId])
            ], merge: true)
        } catch {
            print("[BoardFirestore] joinThemeRoom failed: \(error)")
        }
    }

    /// テーマ部屋からの退出を記録。
    func leaveThemeRoom(userId: String, themeRoomId: String) async {
        do {
            try await usersCollection.document(userId).setData([
                "joinedThemeRoomIds": FieldValue.arrayRemove([themeRoomId])
            ], merge: true)
        } catch {
            print("[BoardFirestore] leaveThemeRoom failed: \(error)")
        }
    }
}
