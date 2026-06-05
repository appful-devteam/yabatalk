import SwiftUI

// MARK: - Domain Model

/// 相談部屋内の投稿モデル。
/// CommunityRoom モデルは `CommunityRoomsView.swift` 側で定義。
struct CommunityRoomPost: Identifiable, Hashable {
    let id: String
    let roomId: String
    /// 投稿者の Firebase Auth uid。モック / レガシー投稿には未設定のため optional。
    let authorId: String?
    let authorName: String
    let authorAvatarSymbol: String   // SF Symbol for mock avatar
    let authorAvatarColor: String    // hex string
    let authorMbti: String?
    let relationshipTag: String?     // 片思い / 遠距離 / 既婚 等
    /// プロフィール画像 URL (R2 / Firebase Storage)。未設定なら avatarSymbol/Color のフォールバック表示。
    var authorProfileImageURL: String? = nil
    /// 投稿テーマ (片思い / 両思い / 失恋 等の構造化ラベル)。本文内の #ハッシュタグとは別管理。
    var themes: [String] = []
    /// 添付された診断カード (任意)。掲示板と同じ Firestore シリアライズを共有。
    var diagnosisCard: DiagnosisCard? = nil
    let body: String
    let imageURL: String?            // 任意の添付画像（モックでは SF Symbol 表現）
    let reactionOptions: [String]    // 縦に並べる回答選択肢
    var reactionCounts: [String: Int]
    var bookmarkCount: Int
    var commentCount: Int
    var likeCount: Int
    var viewCount: Int = 0           // インプレッション（閲覧数）
    var postedAt: Date
    var isLiked: Bool = false
    var isBookmarked: Bool = false
    var selectedReaction: String? = nil

    /// 投票の合計数。
    var totalReactionVotes: Int {
        reactionOptions.reduce(0) { $0 + (reactionCounts[$1] ?? 0) }
    }

    /// 表示用相対時刻。
    func relativeTime(now: Date = Date()) -> String {
        let diff = now.timeIntervalSince(postedAt)
        if diff < 60 { return "たった今" }
        if diff < 3600 { return "\(Int(diff / 60))分" }
        if diff < 86400 { return "\(Int(diff / 3600))時間" }
        return "\(Int(diff / 86400))日"
    }

    /// 旧 CommunityRoomPost を新フローで描画する `BoardPost` に変換する。
    /// 既存投稿を共通 posts コレクションに移行するまでの暫定互換レイヤ。
    /// 投票/いいね等の書き込みは新フロー側に流れるため、旧投稿は表示専用として扱う。
    func toBoardPost(roomTitle: String) -> BoardPost {
        let badge: LoveTypeBadge? = authorMbti.map {
            LoveTypeBadge(typeCode: $0, typeName: "", totalScore: 0)
        }
        return BoardPost(
            id: id,
            authorId: authorId ?? "",
            authorDisplayName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            authorBadge: badge,
            postType: reactionOptions.isEmpty ? .normal : .poll,
            content: body,
            imageURLs: (imageURL?.hasPrefix("http") == true) ? [imageURL!] : [],
            diagnosisCard: diagnosisCard,
            quotedPost: nil,
            stamp: nil,
            pollOptions: nil,
            isAnonymous: authorName == "匿名ユーザー",
            authorIsPrivate: nil,
            aiSummary: nil,
            language: nil,
            themes: themes,
            communityRoomId: roomId,
            communityRoomTitle: roomTitle,
            totalVotes: totalReactionVotes,
            replyCount: commentCount,
            quoteCount: 0,
            repostCount: 0,
            bookmarkCount: bookmarkCount,
            reactionCounts: reactionCounts,
            viewCount: viewCount,
            createdAt: postedAt,
            updatedAt: postedAt,
            myReaction: selectedReaction,
            myVote: nil
        )
    }
}

// MARK: - Repository

protocol CommunityRoomPostRepository {
    func fetchPosts(for roomId: String) async -> [CommunityRoomPost]
    func createPost(_ post: CommunityRoomPost) async
    func deletePost(roomId: String, postId: String) async
    func toggleLike(postId: String) async
    func toggleBookmark(postId: String) async
    func setReaction(postId: String, option: String) async
    func fetchReplies(roomId: String, postId: String) async -> [BoardReply]
    func createReply(roomId: String, postId: String, content: String, mention: ReplyMentionInfo?, asAnonymous: Bool) async -> BoardReply?
    func deleteReply(roomId: String, postId: String, replyId: String) async
    func toggleReplyLike(roomId: String, postId: String, replyId: String) async -> Bool
}

/// Firestore-backed 実装。クラス名は呼び出し側互換のため変更していない。
/// 旧インメモリ実装の動作 (シングルトン経由) を維持しつつ、内部は
/// `CommunityRoomFirestoreService` に委譲する。
///
/// プロトコルの like / bookmark / reaction は postId のみ受け取るので、
/// fetch 時に postId → roomId の対応をローカルキャッシュしておく。
final class InMemoryCommunityRoomPostRepository: CommunityRoomPostRepository, @unchecked Sendable {
    static let shared = InMemoryCommunityRoomPostRepository()

    private let queue = DispatchQueue(label: "InMemoryCommunityRoomPostRepository.lock")
    /// 各投稿が属する roomId のキャッシュ (toggleLike 等が postId しか持たないため)。
    private var postRoomIndex: [String: String] = [:]

    private init() {}

    private func updateIndex(_ posts: [CommunityRoomPost]) {
        queue.sync {
            for p in posts { postRoomIndex[p.id] = p.roomId }
        }
    }

    private func roomId(for postId: String) -> String? {
        queue.sync { postRoomIndex[postId] }
    }

    @MainActor
    private func currentUserId() -> String? {
        BoardAuthService.shared.currentUser?.id
    }

    func fetchPosts(for roomId: String) async -> [CommunityRoomPost] {
        do {
            let posts = try await CommunityRoomFirestoreService.shared
                .fetchPosts(forRoomId: roomId)
            updateIndex(posts)
            return posts
        } catch {
            return []
        }
    }

    func createPost(_ post: CommunityRoomPost) async {
        do {
            try await CommunityRoomFirestoreService.shared.createPost(post)
            updateIndex([post])
        } catch {
            // 失敗時はサイレントに無視 (UI は再 fetch で同期する)。
        }
    }

    func deletePost(roomId: String, postId: String) async {
        try? await CommunityRoomFirestoreService.shared.deletePost(
            roomId: roomId, postId: postId
        )
        queue.sync { postRoomIndex.removeValue(forKey: postId) }
    }

    func toggleLike(postId: String) async {
        guard let rid = roomId(for: postId),
              let uid = await currentUserId() else { return }
        try? await CommunityRoomFirestoreService.shared.toggleLike(
            roomId: rid, postId: postId, userId: uid
        )
    }

    func toggleBookmark(postId: String) async {
        guard let rid = roomId(for: postId),
              let uid = await currentUserId() else { return }
        try? await CommunityRoomFirestoreService.shared.toggleBookmark(
            roomId: rid, postId: postId, userId: uid
        )
    }

    func setReaction(postId: String, option: String) async {
        guard let rid = roomId(for: postId),
              let uid = await currentUserId() else { return }
        try? await CommunityRoomFirestoreService.shared.setReaction(
            roomId: rid, postId: postId, userId: uid, option: option
        )
    }

    /// 部屋削除時の子投稿クリーンアップ (Firestore 側は deleteRoom が連鎖削除済み)。
    /// ここではローカルインデックスから該当 roomId のエントリを除去するだけ。
    func removeAll(forRoomId roomId: String) async {
        queue.sync {
            postRoomIndex = postRoomIndex.filter { $0.value != roomId }
        }
    }

    // MARK: - Replies (BoardReply 再利用)

    func fetchReplies(roomId: String, postId: String) async -> [BoardReply] {
        do {
            return try await CommunityRoomFirestoreService.shared
                .fetchReplies(roomId: roomId, postId: postId)
        } catch {
            return []
        }
    }

    func createReply(roomId: String, postId: String, content: String, mention: ReplyMentionInfo?, asAnonymous: Bool = false) async -> BoardReply? {
        guard let user = await authUser() else { return nil }
        let profile = asAnonymous ? nil : (try? await BoardFirestoreService.shared.getProfile(userId: user.id))
        let resolvedName = asAnonymous ? "匿名ユーザー" : user.displayName
        do {
            return try await CommunityRoomFirestoreService.shared.createReply(
                roomId: roomId,
                postId: postId,
                content: content,
                authorId: user.id,
                authorName: resolvedName,
                authorProfileImageURL: profile?.profileImageURL,
                badge: profile?.badge,
                mention: mention
            )
        } catch {
            return nil
        }
    }

    func deleteReply(roomId: String, postId: String, replyId: String) async {
        try? await CommunityRoomFirestoreService.shared.deleteReply(
            roomId: roomId, postId: postId, replyId: replyId
        )
    }

    func toggleReplyLike(roomId: String, postId: String, replyId: String) async -> Bool {
        guard let uid = await currentUserId() else { return false }
        return (try? await CommunityRoomFirestoreService.shared.toggleReplyLike(
            roomId: roomId, postId: postId, replyId: replyId, userId: uid
        )) ?? false
    }

    @MainActor
    private func authUser() -> BoardUser? {
        BoardAuthService.shared.currentUser
    }
}

// MARK: - ViewModel

@MainActor
final class CommunityRoomDetailViewModel: ObservableObject {
    @Published var posts: [CommunityRoomPost] = []
    @Published var isLoading: Bool = false
    /// 現在表示中の部屋のブロックユーザー集合（フィルタに使用）。
    @Published var blockedUserIds: Set<String> = []

    private let repository: CommunityRoomPostRepository

    init(repository: CommunityRoomPostRepository = InMemoryCommunityRoomPostRepository.shared) {
        self.repository = repository
    }

    /// ブロック済みユーザーを除外した表示用投稿一覧。
    var visiblePosts: [CommunityRoomPost] {
        posts.filter { post in
            guard let aid = post.authorId else { return true }
            return !blockedUserIds.contains(aid)
        }
    }

    func load(roomId: String) async {
        isLoading = true
        let result = await repository.fetchPosts(for: roomId)
        posts = result
        isLoading = false
    }

    /// 親 ViewModel から渡されたブロックリストを反映。
    func applyBlockList(_ ids: [String]) {
        blockedUserIds = Set(ids)
    }

    func toggleLike(_ post: CommunityRoomPost) async {
        await repository.toggleLike(postId: post.id)
        await reload(roomId: post.roomId)
    }

    func toggleBookmark(_ post: CommunityRoomPost) async {
        await repository.toggleBookmark(postId: post.id)
        await reload(roomId: post.roomId)
    }

    func react(_ post: CommunityRoomPost, option: String) async {
        await repository.setReaction(postId: post.id, option: option)
        await reload(roomId: post.roomId)
    }

    func createPost(roomId: String,
                    authorId: String?,
                    authorName: String,
                    mbti: String?,
                    relationship: String?,
                    body: String,
                    themes: [String] = [],
                    diagnosisCard: DiagnosisCard? = nil,
                    reactionOptions: [String] = [],
                    profileImageURL: String? = nil,
                    hasImage: Bool) async {
        var newPost = CommunityRoomPost(
            id: UUID().uuidString,
            roomId: roomId,
            authorId: authorId,
            authorName: authorName.isEmpty ? "あなた" : authorName,
            authorAvatarSymbol: "person.fill",
            authorAvatarColor: "F19EC2",
            authorMbti: mbti,
            relationshipTag: relationship,
            body: body,
            imageURL: hasImage ? "photo" : nil,
            reactionOptions: reactionOptions,
            reactionCounts: [:],
            bookmarkCount: 0,
            commentCount: 0,
            likeCount: 0,
            viewCount: 0,
            postedAt: Date()
        )
        newPost.themes = themes
        newPost.diagnosisCard = diagnosisCard
        newPost.authorProfileImageURL = profileImageURL
        await repository.createPost(newPost)
        await reload(roomId: roomId)
    }

    func deletePost(_ post: CommunityRoomPost) async {
        await repository.deletePost(roomId: post.roomId, postId: post.id)
        await reload(roomId: post.roomId)
    }

    private func reload(roomId: String) async {
        let result = await repository.fetchPosts(for: roomId)
        posts = result
    }
}

// MARK: - Palette

private enum DetailPalette {
    static let background = Color.white
    static let koiPink = MeloColors.Brand.pink
    static let cardBorder = MeloColors.Surface.pinkPale
    static let mbtiPill = MeloColors.Brand.pinkLight
    static let subText = MeloColors.Text.secondary
    static let mutedGray = MeloColors.Text.secondary
    static let reactionBg = MeloColors.Gray.subButtonLight
    static let titleText = MeloColors.Text.primary
    static let avatarBorder = Color.black.opacity(0.3)
    static let overlayBorder = MeloColors.Text.secondary
}

// MARK: - Main View

struct CommunityRoomDetailView: View {
    let room: CommunityRoom
    /// 一覧 VM。部屋削除 / ブロック更新を委譲する（push 元が渡していれば使用）。
    let roomsViewModel: CommunityRoomsViewModel?

    @StateObject private var viewModel = CommunityRoomDetailViewModel()
    @StateObject private var authService = BoardAuthService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompose = false
    @State private var showingSettings = false
    @State private var toastMessage: String? = nil
    /// 投稿タップで開く詳細シートのターゲット (nil = 閉じている)。
    @State private var selectedPost: CommunityRoomPost?
    @State private var boardPosts: [BoardPost] = []
    @State private var selectedBoardPost: BoardPost?
    @State private var isLoadingBoardPosts = false
    @State private var showHashtagSearch = false
    @State private var hashtagSearchQuery: String?
    @State private var toastIsError: Bool = false
    /// 投稿のアバター/ユーザー名タップ時に開く相手プロフィールシート。
    @State private var profileTarget: ProfileSheetTarget?

    init(room: CommunityRoom, roomsViewModel: CommunityRoomsViewModel? = nil) {
        self.room = room
        self.roomsViewModel = roomsViewModel
    }

    /// プレビュー / プレースホルダー経路用フォールバック。
    init() {
        self.room = CommunityRoom(
            id: "r1",
            title: "失恋した人、集まれ",
            subtitle: "失恋して、きつい人。ここで一緒に元気になりましょ",
            participantCount: 20,
            imageURL: nil,
            isJoined: false,
            iconColor: MeloColors.Gray.subButton
        )
        self.roomsViewModel = nil
    }

    /// 現在表示する Room — roomsViewModel の最新状態を優先（設定シートの編集反映用）。
    private var displayedRoom: CommunityRoom {
        roomsViewModel?.latestRoom(id: room.id) ?? room
    }

    /// 現在のユーザーがこの部屋のオーナーか。
    private var isOwner: Bool {
        displayedRoom.isOwnedBy(userId: authService.currentUser?.id)
    }

    /// 現在のユーザー自身がブロック対象になっているか。
    private var isSelfBlocked: Bool {
        displayedRoom.isBlocked(userId: authService.currentUser?.id)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 縦方向のみのスクロールに限定。
            // 内部の VStack も maxWidth: .infinity で固定し、子要素の幅変化が
            // ScrollView の content rect に影響して左右揺れを起こすのを防ぐ。
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    roomHeader
                    postsSection
                }
                .frame(maxWidth: .infinity)
            }
            .background(DetailPalette.background.ignoresSafeArea())

            floatingComposeButton
                .padding(.trailing, 20)
                .padding(.bottom, 24)
        }
        .overlay(alignment: .top) {
            if let msg = toastMessage {
                BoardToastView(
                    msg,
                    icon: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                    isError: toastIsError
                )
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: displayedRoom.id) {
            await loadBoardPosts()
            viewModel.applyBlockList(displayedRoom.blockedUserIds)
        }
        .onChange(of: displayedRoom.blockedUserIds) { _, newList in
            viewModel.applyBlockList(newList)
        }
        .sheet(isPresented: $showingSettings) {
            if let vm = roomsViewModel {
                CommunityRoomSettingsSheet(
                    room: displayedRoom,
                    posts: viewModel.posts,
                    roomsViewModel: vm,
                    onRoomDeleted: { dismiss() }
                )
            }
        }
        .sheet(isPresented: $showingCompose) {
            BoardComposeViewV2(
                onPosted: {
                    Task { await loadBoardPosts() }
                },
                preselectedCommunityRoom: displayedRoom
            )
        }
        .sheet(item: $selectedBoardPost) { post in
            BoardPostDetailView(post: post) {
                boardPosts.removeAll { $0.id == post.id }
            }
        }
        .sheet(item: $selectedPost) { post in
            CommunityPostDetailSheet(
                post: post,
                isOwnPost: post.authorId != nil && post.authorId == authService.currentUser?.id,
                onLike: { Task { await viewModel.toggleLike(post) } },
                onBookmark: { Task { await viewModel.toggleBookmark(post) } },
                onReaction: { option in
                    Task { await viewModel.react(post, option: option) }
                },
                onDelete: {
                    Task {
                        await viewModel.deletePost(post)
                        selectedPost = nil
                    }
                }
            )
        }
        // プロフィールシートはチェーンの末尾に置く(SwiftUI は複数 .sheet(item:) を
        // 積んだ時に挙動が不安定になることがあり、最後に置いたものが最も信頼できる)
        .sheet(item: $profileTarget) { target in
            BoardProfileView(userId: target.userId)
        }
        .fullScreenCover(isPresented: $showHashtagSearch, onDismiss: {
            hashtagSearchQuery = nil
        }) {
            BoardSearchView(initialQuery: hashtagSearchQuery)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHashtagSearch)) { note in
            guard let tag = note.object as? String, !tag.isEmpty else { return }
            hashtagSearchQuery = "#\(tag)"
            showHashtagSearch = true
        }
    }

    // MARK: - Owner Actions

    /// オーナー専用: 指定投稿の投稿者をブロック。
    fileprivate func blockAuthor(_ post: CommunityRoomPost) {
        guard isOwner,
              let authorId = post.authorId,
              let roomsVM = roomsViewModel else { return }
        Task {
            _ = await roomsVM.toggleBlock(roomId: displayedRoom.id, userId: authorId)
            showToast(
                String(localized: "このユーザーをブロックしました", bundle: LanguageManager.appBundle),
                isError: false
            )
        }
    }

    fileprivate func showToast(_ message: String, isError: Bool) {
        withAnimation { toastMessage = message; toastIsError = isError }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { toastMessage = nil }
        }
    }

    private func loadBoardPosts() async {
        isLoadingBoardPosts = true
        defer { isLoadingBoardPosts = false }

        // 自分の uid + フォロー中 uid を先に取得 (プライバシーフィルタで使う)。
        let myUid = BoardAuthService.shared.currentUser?.id
        let followingIds: Set<String>
        if let myUid {
            followingIds = (try? await BoardFirestoreService.shared.getFollowingIds(userId: myUid)) ?? []
        } else {
            followingIds = []
        }

        // テーマ部屋 (id が "theme:..." の virtual room): posts.themes 配列マッチで取得。
        // 全ての投稿は posts/ コレクションの実体なので like / reaction 等もそのまま動作する。
        if let themeLabel = CommunityThemeRoom.themeLabel(forRoomId: displayedRoom.id) {
            let posts = (try? await BoardFirestoreService.shared.fetchPosts(forThemeLabel: themeLabel)) ?? []
            let visible = applyVisibilityFilter(posts, myUid: myUid, followingIds: followingIds)
                .sorted { $0.createdAt > $1.createdAt }
            // 同言語を上に並べて、その中で createdAt 降順を維持する
            boardPosts = BoardFirestoreService.sortByLanguagePriority(
                visible,
                userLanguage: LanguageManager.resolvedLanguage,
                followingIds: followingIds
            )
            return
        }

        // 通常の相談部屋: 旧 community_rooms/{roomId}/posts/ を直接 Firestore で読む
        // (viewModel は in-memory mock を使っているので Firestore のデータを読めない)。
        let legacyPosts = (try? await CommunityRoomFirestoreService.shared.fetchPosts(forRoomId: displayedRoom.id)) ?? []
        let legacyConverted = legacyPosts.map { $0.toBoardPost(roomTitle: displayedRoom.title) }

        // 全ての旧投稿を best-effort で共通 posts/ に移行 (idempotent)。
        // firestore.rules の create 例外で communityRoomId 付き doc は他ユーザ作成の
        // ものでも書き込み可能。失敗しても続行 (rule 変更前のクライアントでは弾かれる)。
        await withTaskGroup(of: Void.self) { group in
            for post in legacyConverted {
                group.addTask {
                    try? await BoardFirestoreService.shared.migratePostIfMissing(post)
                }
            }
        }

        // 新フロー (posts/ where communityRoomId==id) を取得。移行済の自分の投稿はここに含まれる。
        let newPosts = (try? await BoardFirestoreService.shared.fetchPosts(forCommunityRoomId: displayedRoom.id)) ?? []

        // 新 + 旧 を ID で重複排除しつつマージ (新を優先)。新しい順に並べる。
        // 他人の投稿で移行できないものは旧フロー経由で表示専用として見える。
        var seen: Set<String> = []
        let merged = (newPosts + legacyConverted).filter { post in
            guard !seen.contains(post.id) else { return false }
            seen.insert(post.id)
            return true
        }
        let visibleMerged = applyVisibilityFilter(merged, myUid: myUid, followingIds: followingIds)
            .sorted { $0.createdAt > $1.createdAt }
        boardPosts = BoardFirestoreService.sortByLanguagePriority(
            visibleMerged,
            userLanguage: LanguageManager.resolvedLanguage,
            followingIds: followingIds
        )
    }

    /// 非公開アカウント (authorIsPrivate == true) の投稿は本人 + フォロー中の人のみ閲覧可。
    /// 匿名投稿は authorId が意味を持たないため例外で常に表示。
    /// BoardFeedView と同じロジック (相談部屋でもホームと同じプライバシー扱いにするため)。
    private func applyVisibilityFilter(
        _ posts: [BoardPost],
        myUid: String?,
        followingIds: Set<String>
    ) -> [BoardPost] {
        posts.filter { post in
            guard post.authorIsPrivate == true, !post.isAnonymous else { return true }
            return post.authorId == myUid || followingIds.contains(post.authorId)
        }
    }

    // MARK: - Room Header

    private var roomHeader: some View {
        ZStack(alignment: .bottom) {
            headerImage
            headerCardContainer
        }
        .frame(height: 248)
    }

    private var headerImage: some View {
        Group {
            if let data = displayedRoom.headerImageData, let uiImage = UIImage(data: data) {
                // ユーザーが作成した部屋の独自ヘッダー画像
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if UIImage(named: "room_header_bg") != nil {
                Image("room_header_bg")
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [MeloColors.Member.partner, MeloColors.Status.successBg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 90))
                        .foregroundColor(MeloColors.Status.success.opacity(0.6))
                        .offset(y: -20)
                )
            }
        }
        .frame(height: 198)
        .frame(maxWidth: .infinity)
        .clipped()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var headerCardContainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                roomAvatar
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(displayedRoom.title)
                            .font(MeloFonts.zenMaruOrFallback(22))
                            .tracking(0.66)
                            .foregroundColor(DetailPalette.titleText)
                            .lineLimit(1)

                        if isOwner {
                            ownerGearButton
                        }
                    }

                    // 投稿数 (常時) + 参加人数 (通常部屋のみ)。
                    // シード/テーマ部屋は participantCount がダミーなので参加人数は出さない。
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(DetailPalette.subText)
                        Text("投稿\(displayedRoom.postCount)件")
                            .font(MeloFonts.zenMaruMedium(10))
                            .tracking(0.3)
                            .foregroundColor(DetailPalette.subText)

                        if displayedRoom.ownerId != nil {
                            Text("・")
                                .font(MeloFonts.zenMaruMedium(10))
                                .foregroundColor(DetailPalette.subText)
                            memberAvatarStack
                            Text("\(displayedRoom.participantCount)人が話してるよ！")
                                .font(MeloFonts.zenMaruMedium(10))
                                .tracking(0.3)
                                .foregroundColor(DetailPalette.subText)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Text(displayedRoom.subtitle.isEmpty ? "失恋して、きつい人。ここで一緒に元気になりましょ" : displayedRoom.subtitle)
                .font(MeloFonts.zenMaruRegular(10))
                .tracking(0.3)
                .foregroundColor(DetailPalette.subText)
                .lineLimit(2)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110, alignment: .top)
        .background(
            RoundedCorner(radius: 10, corners: [.topLeft, .topRight])
                .fill(Color.white)
        )
    }

    /// オーナー専用の歯車ボタン（タイトル右横）。タップで部屋設定シートを開く。
    private var ownerGearButton: some View {
        Button {
            HapticManager.light()
            showingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MeloColors.Text.primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(MeloColors.Surface.pinkPale)
                        .overlay(
                            Circle().stroke(MeloColors.Text.primary, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "部屋の設定", bundle: LanguageManager.appBundle)))
    }

    private var roomAvatar: some View {
        // 73×73 の角丸正方形にクロップした上で、登録画像 / URL / プレースホルダの順に表示。
        // ユーザー画像/URL 画像のときだけ色付き背景を敷き、デフォルトのめろまる画像時は
        // 背景なしで正方形を満たす（透過部分から下地の色が透けないように）。
        Group {
            if let data = displayedRoom.iconImageData, let uiImage = UIImage(data: data) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(displayedRoom.iconColor)
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 73, height: 73)
                        .clipped()
                }
            } else if let urlString = displayedRoom.imageURL,
                      let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(displayedRoom.iconColor)
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 73, height: 73)
                            .clipped()
                    }
                } placeholder: {
                    Image("room_default_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 73, height: 73)
                        .clipped()
                }
            } else {
                Image("room_default_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 73, height: 73)
                    .clipped()
            }
        }
        .frame(width: 73, height: 73)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.black.opacity(0.6), lineWidth: 0.5)
        )
    }

    private var memberAvatarStack: some View {
        HStack(spacing: -5) {
            memberBubble(color: MeloColors.Brand.pinkLight, symbol: "heart.fill")
            memberBubble(color: MeloColors.Status.warningBg, symbol: "face.smiling.fill")
            memberBubble(color: MeloColors.Status.success, symbol: "leaf.fill")
        }
    }

    private func memberBubble(color: Color, symbol: String) -> some View {
        Circle()
            .fill(color)
            .frame(width: 18, height: 18)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 9))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color.white, lineWidth: 1))
    }

    // MARK: - Posts

    private var postsSection: some View {
        // LazyVStack に切替え + 各カードを画面幅で固定。
        // VStack だとカード内部の async 状態更新(リアクション fetch 等) で
        // 幅が再計算され、左右揺れの一因となる。固定幅を強制する。
        LazyVStack(spacing: 0) {
            if isLoadingBoardPosts && boardPosts.isEmpty {
                ProgressView()
                    .padding(.top, 40)
            } else if boardPosts.isEmpty {
                emptyState
            } else {
                ForEach(boardPosts) { post in
                    BoardFeedPostCard(post: post, horizontalPadding: 36) {
                        selectedBoardPost = post
                    } onAuthorTap: { authorId in
                        profileTarget = ProfileSheetTarget(userId: authorId)
                    } onQuote: { _ in
                    } onRequireSignIn: {
                    }
                    .frame(width: MeloLayout.deviceWidth)
                }
            }
        }
        .frame(width: MeloLayout.deviceWidth)
        .padding(.top, 14)
        .padding(.bottom, 120)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image("mero_pair_15")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
            Text("まだ投稿がありません")
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(DetailPalette.subText)
            Text("最初の相談を投稿してみよう")
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(DetailPalette.mutedGray)
        }
        .padding(.top, 60)
    }

    // MARK: - Floating Compose Button

    private var floatingComposeButton: some View {
        Button {
            if isSelfBlocked {
                HapticManager.light()
                showToast(
                    String(localized: "あなたはこの部屋への投稿が制限されています", bundle: LanguageManager.appBundle),
                    isError: true
                )
                return
            }
            showingCompose = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(isSelfBlocked ? DetailPalette.mutedGray : DetailPalette.koiPink))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新しい投稿を作成")
    }
}

// MARK: - Post Card V2 (Board Feed と統一された新レイアウト)
/// Figma node 582:621 準拠。Home (BoardFeedPostCard) と同じ視覚言語を踏襲。
/// Repository/ViewModel の抽象は触らず、クロージャー経由で既存の toggleLike/toggleBookmark/react に流す。

struct CommunityPostCardV2: View {
    let post: CommunityRoomPost
    let onLike: () -> Void
    let onBookmark: () -> Void
    let onReaction: (String) -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    /// 詳細シートで使う場合は下部 divider を出さない（詳細画面ではコメント欄が直下に来るため）。
    var showsBottomDivider: Bool = true

    /// 同一投稿に対する viewCount 多重インクリメント抑止 (セッション内 1 回限り)。
    @State private var hasCountedView = false
    /// 長文投稿の「もっと表示」用 (掲示板の BoardFeedPostCard と同じ閾値)
    @State private var isContentExpanded = false
    private static let collapseCharThreshold = 150
    private static let collapsedLineLimit = 6

    private var shouldShowExpander: Bool {
        post.body.count > Self.collapseCharThreshold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            cardHeader
            cardBody
            // 旧実装: 本文中の #ハッシュタグを抽出して二重表示する hashtagLine を出していたが、
            // 本文 (cardBody) 内で既にハッシュタグはピンク強調されているため重複してしまう。
            // 構造化テーマピルは cardHeader 内 (MBTI 列) に配置する。
            if let card = post.diagnosisCard {
                BoardDiagnosisCardExpanded(card: card)
            }
            if let imageURL = post.imageURL { cardImage(symbol: imageURL) }
            if !post.reactionOptions.isEmpty {
                CommunityRoomPollBars(
                    options: post.reactionOptions,
                    counts: post.reactionCounts,
                    totalVotes: post.totalReactionVotes,
                    selectedOption: post.selectedReaction,
                    onSelect: onReaction
                )
                .padding(.top, 2)
            }
            engageRow
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            if showsBottomDivider {
                Rectangle()
                    .fill(MeloColors.Gray.subButton)
                    .frame(height: 0.5)
            }
        }
        .onAppear {
            // セッション内で 1 回のみ閲覧数 +1 (掲示板と同じ仕様)。
            guard !hasCountedView, !post.id.hasPrefix("local_") else { return }
            hasCountedView = true
            Task {
                try? await CommunityRoomFirestoreService.shared.incrementViewCount(
                    roomId: post.roomId,
                    postId: post.id
                )
            }
        }
    }

    // MARK: Header

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
                .frame(width: 47, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(post.authorName)
                        .font(MeloFonts.zenMaruOrFallback(16))
                        .tracking(0.48)
                        .foregroundColor(BoardFeedPalette.textBrown)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(post.relativeTime())
                        .font(MeloFonts.zenMaruMedium(12))
                        .tracking(0.36)
                        .foregroundColor(BoardFeedPalette.timeGray)
                }

                HStack(spacing: 5) {
                    if let mbti = post.authorMbti {
                        mbtiPill(mbti)
                    }
                    if let rel = post.relationshipTag {
                        categoryPill(rel)
                    }
                    ForEach(Array(post.themes.prefix(3).enumerated()), id: \.offset) { _, label in
                        themeMiniPill(label)
                    }
                }
                .frame(height: 20)
            }
        }
    }

    private var avatar: some View {
        ZStack {
            // フォールバックは常に背面に置いてサイズを確実に確保。
            // CachedAsyncImage が読み込み完了するとその上に画像が乗る。
            avatarFallbackBase

            if let urlString = post.authorProfileImageURL,
               let url = URL(string: urlString) {
                CachedAsyncImage(url: url) {
                    Color.clear
                }
                .clipShape(Circle())
            }
        }
        .frame(width: 47, height: 48)
    }

    /// 画像が無い (or 読み込み中) 時に表示するアバター土台。
    private var avatarFallbackBase: some View {
        Circle()
            .fill(Color(hex: post.authorAvatarColor))
            .overlay(
                Image(systemName: post.authorAvatarSymbol)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            )
    }

    private func mbtiPill(_ text: String) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruMedium(10))
            .foregroundColor(BoardFeedPalette.textBrown)
            .padding(.horizontal, 16)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(MeloColors.mbtiColor(for: text).opacity(0.35))
            )
    }

    private func categoryPill(_ text: String) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruMedium(10))
            .foregroundColor(BoardFeedPalette.textBrown)
            .padding(.horizontal, 16)
            .padding(.vertical, 3)
            .background(Capsule().fill(BoardFeedPalette.pillBgPink))
    }

    /// テーマピル (#タグ風ではなく、MBTI と並ぶ小さいピンクピル)。
    private func themeMiniPill(_ label: String) -> some View {
        Text(label)
            .font(MeloFonts.zenMaruMedium(10))
            .foregroundColor(BoardFeedPalette.accentPink)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(MeloColors.Surface.pinkPale)
                    .overlay(
                        Capsule().stroke(BoardFeedPalette.accentPink.opacity(0.5), lineWidth: 0.8)
                    )
            )
    }

    // MARK: Body (hashtags highlighted pink)

    private var cardBody: some View {
        let attributed = HashtagAttributedString.make(
            text: post.body,
            bodyColor: BoardFeedPalette.bodyInk,
            hashtagColor: BoardFeedPalette.accentPink
        )
        return VStack(alignment: .leading, spacing: 4) {
            Text(attributed)
                .font(MeloFonts.zenMaruMedium(14))
                .tracking(0.7)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .lineLimit(shouldShowExpander && !isContentExpanded ? Self.collapsedLineLimit : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .handlesHashtagTap()

            if shouldShowExpander && !isContentExpanded {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isContentExpanded = true }
                } label: {
                    Text("もっと表示")
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(BoardFeedPalette.accentPink)
                        .shadow(color: MeloColors.Brand.pink.opacity(0.35), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 本文中の #xxxx をまとめて表示するための補助ライン（本文に既に含まれているが、Figma 上の
    /// ピンク強調ラインを確実に見せるため、タグがある投稿だけ下に列挙する）。
    private var hashtags: [String] {
        Self.extractHashtags(post.body)
    }

    private var hashtagLine: some View {
        Text(hashtags.joined(separator: " "))
            .font(MeloFonts.zenMaruMedium(12))
            .tracking(0.36)
            .foregroundColor(BoardFeedPalette.accentPink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Image

    private func cardImage(symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(
                colors: [MeloColors.Surface.pinkPale, MeloColors.Member.partnerBg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(height: 95)
            .frame(maxWidth: .infinity)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 28))
                    .foregroundColor(BoardFeedPalette.engageGray)
            )
    }

    // MARK: Engage Row (掲示板の BoardFeedPostCard と同じ順序: 閲覧 / コメント / いいね / 共有 / 保存)

    private var engageRow: some View {
        HStack(spacing: 0) {
            // 閲覧数 (インプレッション) — タップ不可
            engageItem(icon: "chart.bar", count: post.viewCount, isActive: false) {}
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            // コメント
            engageItem(icon: "bubble.left", count: post.commentCount, isActive: false) {
                onComment()
            }
            .frame(maxWidth: .infinity)

            // ハート
            engageItem(
                icon: post.isLiked ? "heart.fill" : "heart",
                count: post.likeCount,
                isActive: post.isLiked
            ) {
                onLike()
            }
            .frame(maxWidth: .infinity)

            // リポスト / 引用 (掲示板と同じスタイル)
            // 相談部屋ではバックエンド未対応のため UI のみ。タップでメニュー表示まで。
            Menu {
                Button {
                    HapticManager.light()
                    onShare()
                } label: {
                    Label(String(localized: "リポスト", bundle: LanguageManager.appBundle), systemImage: "arrow.2.squarepath")
                }
                Button {
                    HapticManager.light()
                    onShare()
                } label: {
                    Label(String(localized: "引用", bundle: LanguageManager.appBundle), systemImage: "quote.bubble")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(BoardFeedPalette.engageGray)
                        .frame(width: 18, height: 18)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // ブックマーク (右端 — 掲示板と同じ位置)
            engageItem(
                icon: post.isBookmarked ? "bookmark.fill" : "bookmark",
                count: post.bookmarkCount > 0 ? post.bookmarkCount : nil,
                isActive: post.isBookmarked
            ) {
                onBookmark()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 28)
        .padding(.top, 4)
    }

    private func engageItem(icon: String,
                            count: Int?,
                            isActive: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(isActive ? BoardFeedPalette.accentPink : BoardFeedPalette.engageGray)
                    .frame(width: 18, height: 18)
                if let count = count {
                    Text(verbatim: "\(count)")
                        .font(MeloFonts.zenMaruMedium(16))
                        .foregroundColor(isActive ? BoardFeedPalette.accentPink : BoardFeedPalette.engageGray)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Tokenizer / Hashtag Extraction

    private static func tokenize(_ text: String) -> [(text: String, isHashtag: Bool)] {
        var result: [(String, Bool)] = []
        let separators = CharacterSet.whitespacesAndNewlines
        var buffer = ""
        var isTag = false
        for ch in text {
            let s = String(ch)
            if s.unicodeScalars.allSatisfy({ separators.contains($0) }) {
                if !buffer.isEmpty { result.append((buffer, isTag)); buffer = ""; isTag = false }
                result.append((s, false))
            } else if ch == "#" || ch == "＃" {
                if !buffer.isEmpty { result.append((buffer, isTag)); buffer = "" }
                isTag = true
                buffer.append(ch)
            } else {
                buffer.append(ch)
            }
        }
        if !buffer.isEmpty { result.append((buffer, isTag)) }
        return result
    }

    private static func extractHashtags(_ text: String) -> [String] {
        tokenize(text)
            .filter { $0.isHashtag }
            .map { $0.text }
    }
}

// MARK: - Community Room Poll Bars
/// BoardFeedPollBars と同等挙動のローカル投票バー。
/// Community 側は Firebase を使わず、`post.selectedReaction` の状態をそのまま反映する。

/// 掲示板の `BoardFeedPollBars` と同じデザイン (背景・進捗バー・票数表示)。
private struct CommunityRoomPollBars: View {
    let options: [String]
    let counts: [String: Int]
    let totalVotes: Int
    let selectedOption: String?
    let onSelect: (String) -> Void

    var body: some View {
        let hasVoted = selectedOption != nil
        VStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let voteCount = counts[option] ?? 0
                let percentage = totalVotes > 0 ? Double(voteCount) / Double(totalVotes) : 0
                let isMyVote = selectedOption == option

                Button {
                    onSelect(option)
                } label: {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 21)
                            // 未投票時はグレー、投票後は薄ピンク (掲示板と同仕様)
                            .fill(hasVoted ? BoardFeedPalette.barBgPink : BoardFeedPalette.pollInactiveBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 21)
                                    .stroke(
                                        hasVoted ? BoardFeedPalette.borderPink : Color.clear,
                                        lineWidth: 0.5
                                    )
                            )
                            .frame(height: 34)

                        // 進捗バー塗り (投票後のみ)
                        if hasVoted {
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 21)
                                    .fill(BoardFeedPalette.accentPink.opacity(isMyVote ? 0.95 : 0.75))
                                    .frame(width: max(12, geo.size.width * max(percentage, 0.02)))
                            }
                            .frame(height: 34)
                            .animation(.easeInOut(duration: 0.25), value: percentage)
                            .transition(.opacity)
                        }

                        HStack {
                            HStack(spacing: 4) {
                                if isMyVote {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(BoardFeedPalette.accentPink)
                                }
                                Text(option)
                                    .font(MeloFonts.zenMaruMedium(13))
                                    .foregroundColor(BoardFeedPalette.textBrown)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if hasVoted {
                                Text("\(Int(percentage * 100))%")
                                    .font(MeloFonts.zenMaruMedium(11))
                                    .foregroundColor(BoardFeedPalette.textBrown)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .shadow(color: BoardFeedPalette.shadowPink.opacity(0.45), radius: 3, x: 0, y: 1.5)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()
                Text(verbatim: "\(totalVotes)票")
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(BoardFeedPalette.timeGray)
            }
        }
    }
}

// MARK: - Compose Sheet

private struct CommunityRoomComposeSheet: View {
    let roomName: String
    let onSubmit: (_ name: String, _ mbti: String?, _ relationship: String?, _ body: String, _ hasImage: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var bodyText: String = ""
    @State private var selectedMbti: String? = nil
    @State private var selectedRelationship: String? = nil
    @State private var attachImage: Bool = false

    private let mbtiOptions = ["ENTJ", "INFP", "ENFP", "ISTP", "ESFJ", "ISFJ", "ENTP", "INTJ"]
    private let relationshipOptions = ["片思い", "両思い", "遠距離", "失恋", "復縁希望", "既婚"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    roomBadge
                    nameField
                    tagSection(title: "MBTI", options: mbtiOptions, selection: $selectedMbti, color: DetailPalette.mbtiPill)
                    tagSection(title: "関係性", options: relationshipOptions, selection: $selectedRelationship, color: DetailPalette.koiPink)
                    bodyField
                    imageAttachToggle
                }
                .padding(20)
            }
            .background(MeloColors.Surface.pinkPale.ignoresSafeArea())
            .navigationTitle("相談を投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿") {
                        onSubmit(name, selectedMbti, selectedRelationship, bodyText, attachImage)
                        dismiss()
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var roomBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "door.left.hand.open")
                .foregroundColor(DetailPalette.koiPink)
            Text(roomName)
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(DetailPalette.titleText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().stroke(DetailPalette.cardBorder, lineWidth: 1))
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ニックネーム（任意）")
                .font(MeloFonts.zenMaruMedium(12))
                .foregroundColor(DetailPalette.subText)
            TextField("例: ももせ", text: $name)
                .padding(12)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DetailPalette.cardBorder, lineWidth: 1)
                )
        }
    }

    private func tagSection(title: String,
                            options: [String],
                            selection: Binding<String?>,
                            color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MeloFonts.zenMaruMedium(12))
                .foregroundColor(DetailPalette.subText)
            FlowLayout(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = (selection.wrappedValue == option) ? nil : option
                    } label: {
                        Text(option)
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(selection.wrappedValue == option ? .white : color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selection.wrappedValue == option ? color : Color.white)
                            )
                            .overlay(
                                Capsule().stroke(color, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本文")
                .font(MeloFonts.zenMaruMedium(12))
                .foregroundColor(DetailPalette.subText)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DetailPalette.cardBorder, lineWidth: 1)
                    )
                if bodyText.isEmpty {
                    Text("相談内容を書いてね…")
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(DetailPalette.mutedGray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var imageAttachToggle: some View {
        Toggle(isOn: $attachImage) {
            HStack(spacing: 6) {
                Image(systemName: "photo")
                    .foregroundColor(DetailPalette.subText)
                Text("画像を添付する（モック）")
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(DetailPalette.subText)
            }
        }
        .tint(DetailPalette.koiPink)
    }
}

// MARK: - Rounded Corner Helper

private struct RoundedCorner: Shape {
    var radius: CGFloat = 10
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CommunityRoomDetailView(room: CommunityRoom(
            id: "r1",
            title: "失恋した人、集まれ",
            subtitle: "失恋して、きつい人。ここで一緒に元気になりましょ",
            participantCount: 20,
            imageURL: nil,
            isJoined: false,
            iconColor: MeloColors.Gray.subButton
        ))
    }
}
