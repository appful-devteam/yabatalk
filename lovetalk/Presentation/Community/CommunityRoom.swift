import SwiftUI

// MARK: - CommunityRoom Model
//
// 相談部屋の主モデル。将来 Firestore 等から取得する前提で、
// `imageURL` は optional（URL 未設定ならプレースホルダを表示）。
// `iconColor` はプレースホルダ時の背景色・ブランド識別用。
// `isJoined` は UI で上書きされるため `var`。
// `ownerId` は作成者 (Firebase Auth uid)。Firestore の既存ドキュメントに
// 無い場合は nil にフォールバック。
// `blockedUserIds` は部屋オーナーがブロックしたユーザー uid の集合。
struct CommunityRoom: Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String
    let participantCount: Int
    let imageURL: String?
    /// ユーザーが作成した部屋の正方形アイコン画像バイナリ（モック用）
    let iconImageData: Data?
    /// 部屋詳細ヘッダーに表示するバナー画像バイナリ（モック用）
    let headerImageData: Data?
    var isJoined: Bool
    let iconColor: Color
    /// 部屋の作成者 (Firebase Auth uid)。未設定のレガシー / シード部屋は nil。
    var ownerId: String?
    /// 部屋オーナーによってブロックされたユーザー uid 一覧。
    var blockedUserIds: [String]
    /// この部屋に紐づく投稿数 (おすすめソート用)。fetchRooms 後に非同期で更新される。
    /// テーマ部屋は posts.themes、通常部屋は posts.communityRoomId で集計。
    var postCount: Int

    init(
        id: String,
        title: String,
        subtitle: String,
        participantCount: Int,
        imageURL: String? = nil,
        iconImageData: Data? = nil,
        headerImageData: Data? = nil,
        isJoined: Bool = false,
        iconColor: Color = MeloColors.Gray.subButton,
        ownerId: String? = nil,
        blockedUserIds: [String] = [],
        postCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.participantCount = participantCount
        self.imageURL = imageURL
        self.iconImageData = iconImageData
        self.headerImageData = headerImageData
        self.isJoined = isJoined
        self.iconColor = iconColor
        self.ownerId = ownerId
        self.blockedUserIds = blockedUserIds
        self.postCount = postCount
    }

    /// 現在のユーザーが部屋のオーナーかどうか。
    func isOwnedBy(userId: String?) -> Bool {
        guard let userId, let ownerId else { return false }
        return userId == ownerId
    }

    /// 指定ユーザーがブロックされているか。
    func isBlocked(userId: String?) -> Bool {
        guard let userId else { return false }
        return blockedUserIds.contains(userId)
    }
}

// MARK: - Theme Room
/// 投稿テーマ (PostTheme) を仮想的な相談部屋として扱うためのヘルパ。
/// 部屋の id は `theme:<themeRawValue>` というプレフィックス付き文字列で識別する。
/// Firestore の `community_rooms` には存在せず、投稿は posts コレクションを
/// `themes array-contains <label>` で問い合わせる。
enum CommunityThemeRoom {
    static let idPrefix = "theme:"

    /// 与えられた id が テーマ部屋 のものか判定。
    static func isThemeRoomId(_ id: String) -> Bool {
        id.hasPrefix(idPrefix)
    }

    /// テーマ部屋 id から PostTheme.label に変換。マッチしなければ nil。
    static func themeLabel(forRoomId id: String) -> String? {
        guard isThemeRoomId(id) else { return nil }
        let raw = String(id.dropFirst(idPrefix.count))
        return PostTheme(rawValue: raw)?.label
    }

    /// PostTheme から仮想 CommunityRoom を生成。
    static func makeRoom(for theme: PostTheme) -> CommunityRoom {
        CommunityRoom(
            id: idPrefix + theme.rawValue,
            title: theme.label,
            subtitle: theme.subtitle,
            participantCount: 0,
            imageURL: nil,
            isJoined: false,
            iconColor: theme.iconColor
        )
    }

    /// 全テーマ部屋。一覧に追加する用途。
    static var all: [CommunityRoom] {
        PostTheme.allCases.map { makeRoom(for: $0) }
    }
}

private extension PostTheme {
    /// 部屋詳細・カードに表示するサブタイトル文 (テーマ別)。
    var subtitle: String {
        switch self {
        case .power:    return "職場の上下関係・威圧的な言動の悩みを話そう"
        case .sexual:   return "性的な言動・不快な接触の相談はこちら"
        case .moral:    return "言葉や態度による精神的な攻撃について"
        case .customer: return "客からの理不尽な要求・暴言の相談に"
        case .other:    return "アカハラ・マタハラなど、その他の悩みを"
        case .consult:  return "カテゴリ問わず、本音で相談しよう"
        }
    }

    /// 部屋アイコンの背景色 (テーマ別)。
    var iconColor: Color {
        switch self {
        case .power, .customer:  return MeloColors.Brand.pink
        case .sexual, .moral:    return MeloColors.Brand.pinkLight
        case .other, .consult:   return MeloColors.Surface.pinkPale
        }
    }
}

// MARK: - CommunityRoomTab

enum CommunityRoomTab: String, CaseIterable, Identifiable {
    case search
    case joined
    case created

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: return "さがす"
        case .joined: return "参加中"
        case .created: return "作成部屋"
        }
    }
}
