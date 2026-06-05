import Foundation

// MARK: - Board Post Type
enum BoardPostType: String, Codable, CaseIterable {
    case normal = "normal"
    case poll = "poll"                  // 恋愛アンケート

    // consultation は既存データの後方互換用（UIには表示しない）
    case consultation = "consultation"

    // UI表示用のケース（consultationを除く）
    static var visibleCases: [BoardPostType] { [.normal, .poll] }

    var localizedName: String {
        switch self {
        case .normal: return String(localized: "投稿", bundle: LanguageManager.appBundle)
        case .poll, .consultation: return String(localized: "アンケート", bundle: LanguageManager.appBundle)
        }
    }

    var icon: String {
        switch self {
        case .normal: return "square.and.pencil"
        case .poll, .consultation: return "chart.bar.xaxis"
        }
    }
}

// MARK: - Poll Option
struct PollOption: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    var voteCount: Int
}

// MARK: - Board Post
/// 掲示板の投稿モデル
struct BoardPost: Identifiable, Codable, Hashable {
    let id: String
    let authorId: String
    let authorDisplayName: String
    let authorProfileImageURL: String?
    let authorBadge: LoveTypeBadge?
    var postType: BoardPostType
    var content: String
    var imageURLs: [String]
    var diagnosisCard: DiagnosisCard?
    var quotedPost: QuotedPostInfo?
    var stamp: BoardStamp?
    var pollOptions: [PollOption]?
    var isAnonymous: Bool
    var authorIsPrivate: Bool?
    var aiSummary: String?
    var language: String?          // 投稿時のデバイス言語（例: "ja", "en", "ko"）
    /// 投稿に付けられたテーマラベル (新方式 — 構造化フィールド)。
    /// 旧投稿は空配列。値は `PostTheme.label` と一致する文字列 (例: "片思い", "両思い", "デート・LINE")。
    var themes: [String] = []
    /// 投稿が紐付く相談部屋。nil の場合は通常の掲示板投稿。
    var communityRoomId: String?
    var communityRoomTitle: String?
    var totalVotes: Int
    var replyCount: Int
    var quoteCount: Int
    var repostCount: Int
    var bookmarkCount: Int
    var reactionCounts: [String: Int] // stamp id -> count
    var viewCount: Int
    var createdAt: Date
    var updatedAt: Date

    // Local-only state
    var myReaction: String?
    var myVote: String?  // 投票したオプションのID
    var isRepostedByMe: Bool? = nil
    /// マイページタイムラインで「自分がリポストした投稿」を区別するための表示ヒント。
    /// nil または false = 通常の投稿、true = リポスト経由で表示。
    var repostedByDisplayName: String? = nil

    static func == (lhs: BoardPost, rhs: BoardPost) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Board Reply
struct BoardReply: Identifiable, Codable {
    let id: String
    let postId: String
    let authorId: String
    let authorDisplayName: String
    let authorProfileImageURL: String?
    let authorBadge: LoveTypeBadge?
    var content: String
    var stamp: BoardStamp?
    var imageURLs: [String]
    var likeCount: Int
    var mentionedReplyId: String?
    var mentionedUserName: String?
    var createdAt: Date

    // Local-only state (not persisted to Firestore)
    var likedByCurrentUser: Bool = false
}

// MARK: - Reply Mention Info
/// 返信先情報（メンション付き返信用）
struct ReplyMentionInfo {
    let replyId: String
    let userName: String
}

// MARK: - Love Type Badge
/// 恋愛タイプバッジ（診断結果から取得）
struct LoveTypeBadge: Codable, Hashable {
    let typeCode: String    // e.g. "BWSF"
    let typeName: String    // e.g. "おひさまピクニック"
    let totalScore: Int
}

// MARK: - Diagnosis Card
/// 診断結果の共有カード
struct DiagnosisCard: Codable, Hashable {
    let typeCode: String
    let typeName: String
    let totalScore: Int
    let balanceScore: Double
    let tensionScore: Double
    let responseScore: Double
    let wordScore: Double

    // カード表示スタイル
    var cardStyle: CardStyle?

    // タイプカード用
    var typeTagline: String?
    var typeDescription: String?
    var typeImageName: String?

    var relationshipLabel: String?  // 関係性ラベル（例: 彼氏、片思い）
    var selfMBTI: String?           // 自分のMBTI（例: ENFJ）
    var partnerMBTI: String?        // 相手のMBTI（例: INFP）— 1対1用（後方互換）
    var partnerMBTIs: [String]?     // 相手のMBTI（複数）— グループトーク用

    // 愛情表現カード用
    var selfLoveWords: [SharedPhraseCount]?
    var partnerLoveWords: [SharedPhraseCount]?
    var selfLoveTotal: Int?
    var partnerLoveTotal: Int?

    // MARK: - タイプカード再ローカライズ（typeCodeから現在のロケールで再取得）

    /// 現在のロケールでのタイプ名
    var localizedTypeName: String {
        guard let type = RelationshipType(rawValue: typeCode) else { return typeName }
        return type.displayName
    }

    /// 現在のロケールでのタグライン
    var localizedTypeTagline: String? {
        guard let type = RelationshipType(rawValue: typeCode) else { return typeTagline }
        return type.tagline
    }

    /// 現在のロケールでのタイプ説明
    var localizedTypeDescription: String? {
        guard let type = RelationshipType(rawValue: typeCode) else { return typeDescription }
        return type.description
    }

    /// 相性カード用キャラクター画像のアセット名。
    /// 古い投稿は Firestore に保存された旧アセット名が入っている可能性があるため、
    /// `typeCode` から最新の `RelationshipType.imageName` を都度引き直す。
    /// `typeCode` が解決できない場合のみ、保存済み `typeImageName` をフォールバック。
    var localizedTypeImageName: String? {
        if let type = RelationshipType(rawValue: typeCode) {
            return type.imageName
        }
        return typeImageName
    }

    /// partnerMBTIs優先、なければpartnerMBTIフォールバック
    var effectivePartnerMBTIs: [String] {
        if let mbtis = partnerMBTIs, !mbtis.isEmpty { return mbtis }
        if let mbti = partnerMBTI { return [mbti] }
        return []
    }

    enum CardStyle: String, Codable, CaseIterable {
        case score = "score"
        case type = "type"
        case loveWords = "loveWords"

        var localizedName: String {
            switch self {
            case .score: return String(localized: "スコアカード", bundle: LanguageManager.appBundle)
            case .type: return String(localized: "相性タイプ", bundle: LanguageManager.appBundle)
            case .loveWords: return String(localized: "愛情表現", bundle: LanguageManager.appBundle)
            }
        }

        var icon: String {
            switch self {
            case .score: return "chart.bar.fill"
            case .type: return "heart.text.clipboard.fill"
            case .loveWords: return "heart.fill"
            }
        }
    }
}

// MARK: - Shared Phrase Count
/// 掲示板共有用の愛情表現フレーズ
struct SharedPhraseCount: Codable, Hashable, Identifiable {
    var id: String { phrase }
    let phrase: String
    let count: Int
}

// MARK: - Quoted Post Info
/// 引用投稿の要約情報
struct QuotedPostInfo: Codable, Hashable {
    let postId: String
    let authorDisplayName: String
    let content: String            // 元投稿の本文（最大100文字）
    let createdAt: Date

    /// 元のBoardPostからQuotedPostInfoを生成
    static func from(_ post: BoardPost) -> QuotedPostInfo {
        QuotedPostInfo(
            postId: post.id,
            authorDisplayName: post.authorDisplayName,
            content: String(post.content.prefix(100)),
            createdAt: post.createdAt
        )
    }
}

// MARK: - Board Stamp
/// めろとーくオリジナルスタンプ
struct BoardStamp: Codable, Hashable {
    let id: String
    let category: StampCategory

    enum StampCategory: String, Codable, CaseIterable {
        case greeting = "greeting"    // あいさつ
        case emotion = "emotion"      // きもち
        case reaction = "reaction"    // リアクション
        case cheer = "cheer"          // 応援

        var localizedName: String {
            switch self {
            case .greeting: return String(localized: "あいさつ", bundle: LanguageManager.appBundle)
            case .emotion: return String(localized: "きもち", bundle: LanguageManager.appBundle)
            case .reaction: return String(localized: "リアクション", bundle: LanguageManager.appBundle)
            case .cheer: return String(localized: "応援", bundle: LanguageManager.appBundle)
            }
        }
    }

    /// アセットカタログの画像名
    var imageName: String {
        switch id {
        case "stamp_1": return "stamp_1"    // ありがと
        case "stamp_2": return "stamp_2"    // ひらめいた
        case "stamp_3": return "stamp_3"    // ほぉい
        case "stamp_4": return "stamp_4"    // すごぉい
        case "stamp_5": return "stamp_5"    // どうしたの
        case "stamp_6": return "stamp_6"    // わくわく
        case "stamp_7": return "stamp_7"    // やったぁぁ
        case "stamp_8": return "stamp_8"    // ふぉぉぉお
        case "stamp_9": return "stamp_9"    // うぅ
        case "stamp_10": return "stamp_10"  // おやすみ
        case "stamp_11": return "stamp_11"  // わぁっ
        case "stamp_12": return "stamp_12"  // おっけい
        case "stamp_13": return "stamp_13"  // それいい
        case "stamp_14": return "stamp_14"  // すねた
        case "stamp_15": return "stamp_15"  // ねぇねぇ
        case "stamp_16": return "stamp_16"  // おはよう
        case "stamp_17": return "stamp_17"  // (ひょっこり)
        default: return "stamp_1"
        }
    }

    /// 旧絵文字フォールバック（Firestore既存データ用）
    var emoji: String {
        switch id {
        case "love_heart": return "❤️"
        case "love_sparkle": return "✨"
        case "love_kiss": return "😘"
        case "love_ribbon": return "🎀"
        case "cheer_thumbsup": return "👍"
        case "cheer_clap": return "👏"
        case "cheer_muscle": return "💪"
        case "cheer_fire": return "🔥"
        case "empathy_cry": return "🥺"
        case "empathy_hug": return "🤗"
        case "empathy_nod": return "😌"
        case "empathy_sob": return "😭"
        case "funny_laugh": return "🤣"
        case "funny_shock": return "😱"
        case "funny_wink": return "😜"
        case "funny_skull": return "💀"
        default: return ""
        }
    }

    /// 新スタンプかどうか
    var isImageStamp: Bool {
        id.hasPrefix("stamp_")
    }

    static let allStamps: [BoardStamp] = [
        // あいさつ
        BoardStamp(id: "stamp_16", category: .greeting),  // おはよう
        BoardStamp(id: "stamp_10", category: .greeting),  // おやすみ
        BoardStamp(id: "stamp_3", category: .greeting),   // ほぉい
        BoardStamp(id: "stamp_15", category: .greeting),  // ねぇねぇ
        BoardStamp(id: "stamp_1", category: .greeting),   // ありがと
        // きもち
        BoardStamp(id: "stamp_6", category: .emotion),    // わくわく
        BoardStamp(id: "stamp_9", category: .emotion),    // うぅ
        BoardStamp(id: "stamp_14", category: .emotion),   // すねた
        BoardStamp(id: "stamp_5", category: .emotion),    // どうしたの
        // リアクション
        BoardStamp(id: "stamp_4", category: .reaction),   // すごぉい
        BoardStamp(id: "stamp_11", category: .reaction),  // わぁっ
        BoardStamp(id: "stamp_8", category: .reaction),   // ふぉぉぉお
        BoardStamp(id: "stamp_2", category: .reaction),   // ひらめいた
        BoardStamp(id: "stamp_17", category: .reaction),  // ひょっこり
        // 応援
        BoardStamp(id: "stamp_7", category: .cheer),      // やったぁぁ
        BoardStamp(id: "stamp_12", category: .cheer),     // おっけい
        BoardStamp(id: "stamp_13", category: .cheer),     // それいい
    ]

    static func stamps(for category: StampCategory) -> [BoardStamp] {
        allStamps.filter { $0.category == category }
    }
}

// MARK: - Board Notification
struct BoardNotification: Identifiable {
    let id: String
    let type: String        // "reply", "reaction", "reply_like", "mention"
    let postId: String
    let actorName: String
    var read: Bool
    let createdAt: Date
}

// MARK: - Board Feed Sort
enum BoardFeedSort: String, CaseIterable {
    case popular = "popular"
    case following = "following"
    case latest = "latest"

    var localizedName: String {
        switch self {
        case .popular: return String(localized: "おすすめ", bundle: LanguageManager.appBundle)
        case .following: return String(localized: "フォロー中", bundle: LanguageManager.appBundle)
        case .latest: return String(localized: "新着", bundle: LanguageManager.appBundle)
        }
    }

    var icon: String {
        switch self {
        case .popular: return "sparkles"
        case .following: return "person.2"
        case .latest: return "clock"
        }
    }
}

// MARK: - Board User Profile
/// ユーザープロフィール
struct BoardUserProfile: Identifiable, Codable {
    let id: String
    var displayName: String
    var bio: String
    var profileImageURL: String?
    var badge: LoveTypeBadge?
    var isPrivate: Bool
    var followerCount: Int
    var followingCount: Int
    var postCount: Int
    var createdAt: Date

    static let empty = BoardUserProfile(
        id: "",
        displayName: "",
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

// MARK: - Follow State
/// フォロー状態（公開/非公開アカウント対応）
enum FollowState: Equatable {
    case notFollowing
    case following
    case requested      // 非公開アカウントへのリクエスト中
}

// MARK: - Follow Request
/// フォローリクエスト
struct FollowRequest: Identifiable, Codable {
    let id: String           // = requesterId
    let requesterId: String
    let requesterDisplayName: String
    let requesterProfileImageURL: String?
    let requesterBadge: LoveTypeBadge?
    let createdAt: Date
}

// MARK: - Follow Relationship
struct FollowRelationship: Identifiable, Codable {
    let id: String        // the followed/follower user ID
    let displayName: String
    let profileImageURL: String?
    let badge: LoveTypeBadge?
    let createdAt: Date
}

// MARK: - Sample Data (for preview / development)
extension BoardPost {
    static let samplePosts: [BoardPost] = [
        BoardPost(
            id: "1",
            authorId: "user1",
            authorDisplayName: "さくら🌸",
            authorProfileImageURL: nil,
            authorBadge: LoveTypeBadge(typeCode: "BWSF", typeName: "おひさまピクニック", totalScore: 78),
            postType: .normal,
            content: "彼氏のLINE分析したら既読スルー率が高すぎて泣いた😭でもめろとーくのスコア的には相性良いらしい…信じていいの？",
            imageURLs: [],
            diagnosisCard: nil,
            quotedPost: nil,
            stamp: nil,
            pollOptions: nil,
            isAnonymous: false,
            authorIsPrivate: false,
            aiSummary: nil,
            language: "ja",
            themes: [],
            communityRoomId: nil,
            communityRoomTitle: nil,
            totalVotes: 0,
            replyCount: 12,
            quoteCount: 3,
            repostCount: 0,
            bookmarkCount: 0,
            reactionCounts: ["heart": 24],
            viewCount: 156,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3600),
            myReaction: nil,
            myVote: nil
        ),
        BoardPost(
            id: "2",
            authorId: "user2",
            authorDisplayName: "みゆ",
            authorProfileImageURL: nil,
            authorBadge: LoveTypeBadge(typeCode: "UCJF", typeName: "運命のルーレット", totalScore: 85),
            postType: .poll,
            content: "好きな人に既読無視されてます😭\nこれって脈なし？",
            imageURLs: [],
            diagnosisCard: nil,
            quotedPost: nil,
            stamp: nil,
            pollOptions: [
                PollOption(id: "opt1", text: "脈あり", voteCount: 15),
                PollOption(id: "opt2", text: "脈なし", voteCount: 42)
            ],
            isAnonymous: true,
            authorIsPrivate: false,
            aiSummary: nil,
            language: "ja",
            themes: [],
            communityRoomId: nil,
            communityRoomTitle: nil,
            totalVotes: 57,
            replyCount: 28,
            quoteCount: 5,
            repostCount: 0,
            bookmarkCount: 0,
            reactionCounts: ["heart": 56],
            viewCount: 342,
            createdAt: Date().addingTimeInterval(-7200),
            updatedAt: Date().addingTimeInterval(-7200),
            myReaction: nil,
            myVote: nil
        ),
        BoardPost(
            id: "3",
            authorId: "user3",
            authorDisplayName: "あやか",
            authorProfileImageURL: nil,
            authorBadge: nil,
            postType: .poll,
            content: "付き合う前のLINE頻度、みんなどのくらい？",
            imageURLs: [],
            diagnosisCard: nil,
            quotedPost: nil,
            stamp: nil,
            pollOptions: [
                PollOption(id: "opt1", text: "毎日", voteCount: 89),
                PollOption(id: "opt2", text: "2〜3日に1回", voteCount: 45),
                PollOption(id: "opt3", text: "週1", voteCount: 12)
            ],
            isAnonymous: false,
            authorIsPrivate: false,
            aiSummary: nil,
            language: "ja",
            themes: [],
            communityRoomId: nil,
            communityRoomTitle: nil,
            totalVotes: 146,
            replyCount: 45,
            quoteCount: 8,
            repostCount: 0,
            bookmarkCount: 0,
            reactionCounts: ["heart": 31],
            viewCount: 89,
            createdAt: Date().addingTimeInterval(-14400),
            updatedAt: Date().addingTimeInterval(-14400),
            myReaction: nil,
            myVote: nil
        )
    ]
}
