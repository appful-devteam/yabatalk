import SwiftUI
import PhotosUI

// MARK: - Design Tokens (Post Detail - aligned with NewHomeView / BoardFeedView redesign)
private enum BoardDetailTokens {
    static let brandPink = MeloColors.Dark.accent
    static let accentPink = MeloColors.Dark.accent
    static let softPink = MeloColors.Dark.accent
    static let headerBg = MeloColors.Dark.bgElevated
    static let softPinkBg = MeloColors.Dark.bgElevated
    static let softerPinkBg = MeloColors.Dark.bgElevated
    static let textDark = MeloColors.Dark.textPrimary
    static let textMuted = MeloColors.Dark.textSecondary
    static let textGrey = MeloColors.Dark.textSecondary
    static let brownStroke = MeloColors.Dark.cardStroke
    static let divider = MeloColors.Dark.divider
}

// MARK: - Board Post Detail View
struct BoardPostDetailView: View {
    let post: BoardPost
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = BoardAuthService.shared
    @StateObject private var blockService = BoardBlockService.shared
    @StateObject private var bookmarkService = BoardBookmarkService.shared
    @State private var replyText: String = ""
    @State private var replies: [BoardReply] = []
    @State private var isLoadingReplies = false
    @State private var isSendingReply = false
    @State private var showReportSheet = false
    @State private var showDeleteConfirm = false
    @State private var showBlockConfirm = false
    @State private var showSignIn = false
    @State private var showQuoteCompose = false
    @State private var showStampPicker = false
    @State private var myReaction: String?
    @State private var showHeartBurst = false
    @State private var localReactionCounts: [String: Int] = [:]
    @State private var myVote: String?
    @State private var localPollOptions: [PollOption] = []
    @State private var localTotalVotes: Int = 0
    @State private var isVoting = false
    @State private var quotedPostDetail: BoardPost?
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var myProfileImageURL: String?
    @State private var myDisplayName: String = ""
    @State private var showImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var replyImageViewerURLs: [String] = []
    @State private var replyImageViewerIndex = 0
    @State private var showReplyImageViewer = false
    @State private var replyPhotos: [PhotosPickerItem] = []
    @State private var replyImageDatas: [Data] = []
    @State private var profileTarget: ProfileSheetTarget?
    @State private var replyMention: ReplyMentionInfo?
    @State private var likedReplyIds: Set<String> = []
    @State private var replyLikeCounts: [String: Int] = [:]
    @State private var localRepostCount: Int = 0
    @State private var localQuoteCount: Int = 0
    @State private var localBookmarkCount: Int = 0
    @State private var isRepostedByMe: Bool = false
    @FocusState private var isReplyFocused: Bool
    var onDelete: (() -> Void)?

    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MeloColors.Dark.bg
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    detailHeader

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 投稿本体
                            postContent
                                .padding(16)

                            Divider()
                                .background(BoardDetailTokens.divider)
                                .padding(.horizontal, 16)

                            // リアクションバー
                            reactionBar
                                .padding(16)

                            Divider()
                                .background(BoardDetailTokens.divider)
                                .padding(.horizontal, 16)

                            // 返信セクション
                            replySection
                                .padding(16)

                            Spacer().frame(height: 80)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture { isReplyFocused = false }
                }

                // スタンプピッカー + 返信入力バー
                VStack(spacing: 0) {
                    if showStampPicker {
                        stampPickerView
                    }

                    replyInputBar
                }
            }
            .navigationBarHidden(true)
            .alert(String(localized: "この投稿を通報しますか？", bundle: LanguageManager.appBundle), isPresented: $showReportSheet) {
                Button(String(localized: "通報する", bundle: LanguageManager.appBundle), role: .destructive) {
                    Task { await reportPost() }
                }
                Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
            } message: {
                Text(String(localized: "不適切な内容として報告されます", bundle: LanguageManager.appBundle))
            }
            .alert(String(localized: "この投稿を削除しますか？", bundle: LanguageManager.appBundle), isPresented: $showDeleteConfirm) {
                Button(String(localized: "削除する", bundle: LanguageManager.appBundle), role: .destructive) {
                    Task { await deletePost() }
                }
                Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
            } message: {
                Text(String(localized: "この操作は取り消せません", bundle: LanguageManager.appBundle))
            }
            .alert(String(localized: "このユーザーをブロックしますか？", bundle: LanguageManager.appBundle), isPresented: $showBlockConfirm) {
                Button(String(localized: "ブロック", bundle: LanguageManager.appBundle), role: .destructive) {
                    blockService.block(post.authorId)
                    HapticManager.success()
                    dismiss()
                }
                Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
            } message: {
                Text(String(localized: "ブロックするとこのユーザーの投稿が非表示になります", bundle: LanguageManager.appBundle))
            }
            .sheet(isPresented: $showSignIn) {
                BoardSignInView()
            }
            .sheet(isPresented: $showQuoteCompose) {
                // V2 コンポーザに統一。引用情報は V2 内で小さな引用プレビューカードとして表示される。
                BoardComposeViewV2(quotedPost: QuotedPostInfo.from(post))
            }
            .sheet(item: $quotedPostDetail) { quotedPost in
                BoardPostDetailView(post: quotedPost)
            }
            .sheet(item: $profileTarget) { target in
                BoardProfileView(userId: target.userId)
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                FullscreenImageViewer(
                    imageURLs: post.imageURLs,
                    selectedIndex: $selectedImageIndex,
                    isPresented: $showImageViewer
                )
            }
            .fullScreenCover(isPresented: $showReplyImageViewer) {
                FullscreenImageViewer(
                    imageURLs: replyImageViewerURLs,
                    selectedIndex: $replyImageViewerIndex,
                    isPresented: $showReplyImageViewer
                )
            }
            .overlay(alignment: .top) {
                if let msg = toastMessage {
                    BoardToastView(msg, icon: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill", isError: toastIsError)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 60)
                        .zIndex(999)
                }
            }
        }
        .onAppear {
            localReactionCounts = post.reactionCounts
            localPollOptions = post.pollOptions ?? []
            localTotalVotes = post.totalVotes
            localRepostCount = post.repostCount
            localQuoteCount = post.quoteCount
            localBookmarkCount = post.bookmarkCount
            Task {
                await refreshFromServer()    // 最新の repostCount/quoteCount/bookmarkCount/reactionCounts/replyCount を Firestore から再取得
                await loadReplies()
                await loadMyReaction()
                await loadMyVote()
                await loadMyProfile()
                await loadIsReposted()
                // viewCountはフィード表示時にカウント（BoardFeedView側で実行）
            }
        }
        // 親が新しい数値を持つ post に差し替えたら追従(BoardPost.== は id 比較なので
        // SwiftUI は単独では検知できない)。
        .onChange(of: post.repostCount) { newValue in
            localRepostCount = newValue
        }
        .onChange(of: post.quoteCount) { newValue in
            localQuoteCount = newValue
        }
        .onChange(of: post.bookmarkCount) { newValue in
            localBookmarkCount = newValue
        }
        // Cross-view sync: フィードカード側で発生した変更を取り込む
        .onReceive(NotificationCenter.default.publisher(for: .boardPostReactionChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.ReactionPayload,
                  payload.postId == post.id else { return }
            myReaction = payload.myReaction
            localReactionCounts = payload.counts
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostPollVoted)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.PollVotePayload,
                  payload.postId == post.id else { return }
            guard !isVoting else { return }
            myVote = payload.myVote
            localPollOptions = payload.options
            localTotalVotes = payload.totalVotes
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostRepostChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.RepostPayload,
                  payload.postId == post.id else { return }
            isRepostedByMe = payload.isRepostedByMe
            localRepostCount = payload.repostCount
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostQuoteCountChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.QuoteCountPayload,
                  payload.postId == post.id else { return }
            localQuoteCount = payload.quoteCount
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostBookmarkChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.BookmarkPayload,
                  payload.postId == post.id else { return }
            if let count = payload.bookmarkCount {
                localBookmarkCount = count
            }
        }
    }

    // MARK: - Header

    private var detailHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(MeloColors.Dark.bgElevated)
                        .overlay(
                            Circle().stroke(BoardDetailTokens.brandPink, lineWidth: 1)
                        )
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(BoardDetailTokens.brandPink)
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(String(localized: "投稿", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(18))
                .tracking(0.54)
                .foregroundColor(BoardDetailTokens.textDark)
                .lineLimit(1)

            Spacer()

            Menu {
                // 自分の投稿なら削除ボタン
                if let userId = authService.currentUser?.id, post.authorId == userId {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(String(localized: "削除する", bundle: LanguageManager.appBundle), systemImage: "trash")
                    }
                }

                // 他人の投稿ならブロック・通報
                if authService.currentUser?.id != post.authorId {
                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label(String(localized: "このユーザーをブロック", bundle: LanguageManager.appBundle), systemImage: "hand.raised")
                    }

                    Button(role: .destructive) {
                        showReportSheet = true
                    } label: {
                        Label(String(localized: "通報する", bundle: LanguageManager.appBundle), systemImage: "exclamationmark.triangle")
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(MeloColors.Dark.bgElevated)
                        .overlay(
                            Circle().stroke(BoardDetailTokens.brandPink, lineWidth: 1)
                        )
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(BoardDetailTokens.brandPink)
                }
                .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(MeloColors.Dark.bg)
    }

    // MARK: - Post Content

    private var postContent: some View {
        // フィードカードと同じツリー構造（アバター + 名前行 + バッジ/タグ行 + 本文 + 画像 + …）
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                // アバター（フィードカードと同サイズ: 47x48）
                avatarView
                    .frame(width: 47, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    // 1段目: 鍵アイコン + 名前 + 時間（右寄せ）
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if post.authorIsPrivate == true && !post.isAnonymous {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(BoardFeedPalette.textBrown.opacity(0.7))
                        }
                        Text(post.authorDisplayName)
                            .font(MeloFonts.zenMaruOrFallback(16))
                            .tracking(0.48)
                            .foregroundColor(BoardFeedPalette.textBrown)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(BoardFeedTimeFormatter.shortTimeAgo(post.createdAt))
                            .font(MeloFonts.zenMaruMedium(12))
                            .tracking(0.36)
                            .foregroundColor(BoardFeedPalette.timeGray)
                    }

                    // 2段目: MBTI / アンケート / 匿名 / テーマ のピル
                    HStack(spacing: 5) {
                        if let badge = post.authorBadge {
                            Text(badge.typeCode)
                                .font(MeloFonts.zenMaruMedium(10))
                                .foregroundColor(BoardFeedPalette.textBrown)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(MeloColors.mbtiColor(for: badge.typeCode).opacity(0.35))
                                )
                        }
                        if post.postType == .poll {
                            detailPillLabel(String(localized: "アンケート", bundle: LanguageManager.appBundle))
                        }
                        if post.isAnonymous {
                            detailPillLabel(String(localized: "匿名", bundle: LanguageManager.appBundle))
                        }
                        ForEach(Array(post.themes.prefix(3).enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(MeloFonts.zenMaruMedium(10))
                                .foregroundColor(BoardFeedPalette.accentPink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(MeloColors.Dark.bgElevated)
                                        .overlay(
                                            Capsule().stroke(BoardFeedPalette.accentPink.opacity(0.5), lineWidth: 0.8)
                                        )
                                )
                        }
                    }
                    .frame(height: 20)
                }
            }

            // 本文（ハッシュタグをピンクで強調、フィードと同じタイポ）
            detailBodyText

            // 画像
            if !post.imageURLs.isEmpty {
                postImages
            }

            // 診断カード
            if let card = post.diagnosisCard {
                BoardDiagnosisCardFull(card: card)
            }

            // 引用投稿（タップで元投稿に遷移）
            if let quote = post.quotedPost {
                Button {
                    Task {
                        if let original = try? await firestoreService.fetchPost(postId: quote.postId) {
                            quotedPostDetail = original
                        }
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(BoardFeedPalette.accentPink.opacity(0.5))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(quote.authorDisplayName)
                                .font(MeloFonts.zenMaruMedium(10))
                                .foregroundColor(BoardFeedPalette.textBrown)
                            Text(quote.content)
                                .font(MeloFonts.zenMaruMedium(12))
                                .foregroundColor(BoardFeedPalette.textBrown.opacity(0.8))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(BoardFeedPalette.barBgPink)
                    )
                }
                .buttonStyle(.plain)
            }

            // 投票セクション
            if !localPollOptions.isEmpty {
                pollVoteSection
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Featured Post Helpers (aligned with BoardFeedPostCard)

    @ViewBuilder
    private var avatarView: some View {
        if post.isAnonymous {
            Image(AnonymousAvatarPicker.imageName(forSeed: post.id))
                .resizable()
                .scaledToFit()
                .background(Circle().fill(MeloColors.Dark.bgElevated))
                .clipShape(Circle())
        } else if let urlString = post.authorProfileImageURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) {
                Circle()
                    .fill(BoardFeedPalette.shadowPink)
                    .overlay(
                        Text(String(post.authorDisplayName.prefix(1)))
                            .font(MeloFonts.zenMaruOrFallback(16))
                            .foregroundColor(BoardFeedPalette.accentPink)
                    )
            }
            .clipShape(Circle())
        } else {
            Circle()
                .fill(BoardFeedPalette.shadowPink)
                .overlay(
                    Text(String(post.authorDisplayName.prefix(1)))
                        .font(MeloFonts.zenMaruOrFallback(16))
                        .foregroundColor(BoardFeedPalette.accentPink)
                )
        }
    }

    private func detailPillLabel(_ text: String) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruMedium(10))
            .foregroundColor(BoardFeedPalette.textBrown)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(BoardFeedPalette.pillBgPink))
    }

    /// 本文: フィードカード同様、#ハッシュタグだけ accentPink。
    private var detailBodyText: some View {
        let tokens = Self.tokenizeContent(post.content)
        return tokens.reduce(Text(""), { partial, token in
            let t = token.isHashtag
                ? Text(token.text).foregroundColor(BoardFeedPalette.accentPink)
                : Text(token.text).foregroundColor(BoardFeedPalette.bodyInk)
            return partial + t
        })
        .font(MeloFonts.zenMaruMedium(14))
        .tracking(0.7)
        .lineSpacing(8)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func tokenizeContent(_ text: String) -> [(text: String, isHashtag: Bool)] {
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

    // MARK: - Poll Vote Section (aligned with BoardFeedPollBars)

    private var pollVoteSection: some View {
        let hasVoted = myVote != nil
        return VStack(spacing: 6) {
            ForEach(Array(localPollOptions.enumerated()), id: \.element.id) { _, option in
                let percentage = localTotalVotes > 0 ? Double(option.voteCount) / Double(localTotalVotes) : 0
                let isMyVote = myVote == option.id

                Button {
                    guard !isVoting else { return }
                    HapticManager.light()
                    guard authService.hasRealAccount else {
                        showSignIn = true
                        return
                    }
                    Task { await castVote(optionId: option.id) }
                } label: {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 21)
                            .fill(hasVoted ? BoardFeedPalette.barBgPink : BoardFeedPalette.pollInactiveBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 21)
                                    .stroke(
                                        hasVoted ? BoardFeedPalette.borderPink : Color.clear,
                                        lineWidth: 0.5
                                    )
                            )
                            .frame(height: 34)

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
                                Text(option.text)
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
                Text(String(localized: "\(localTotalVotes)票", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(BoardFeedPalette.timeGray)
            }
        }
    }


    // MARK: - Post Images (aligned with BoardFeedPostCard 1/2/3/4 grid)

    @ViewBuilder
    private var postImages: some View {
        let urls = Array(post.imageURLs.prefix(4))
        // 16:9 固定アスペクトに揃え、画像が幅を押し広げないようにする (X/Twitter準拠)。
        Group {
            if urls.count == 1 {
                postImageCell(urls[0], index: 0)
            } else if urls.count == 2 {
                HStack(spacing: 4) {
                    postImageCell(urls[0], index: 0)
                    postImageCell(urls[1], index: 1)
                }
            } else if urls.count == 3 {
                HStack(spacing: 4) {
                    postImageCell(urls[0], index: 0)
                    VStack(spacing: 4) {
                        postImageCell(urls[1], index: 1)
                        postImageCell(urls[2], index: 2)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        postImageCell(urls[0], index: 0)
                        postImageCell(urls[1], index: 1)
                    }
                    HStack(spacing: 4) {
                        postImageCell(urls[2], index: 2)
                        postImageCell(urls[3], index: 3)
                    }
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func postImageCell(_ urlString: String, index: Int) -> some View {
        MeloColors.Dark.bgElevated
            .overlay(
                CachedAsyncImage(url: URL(string: urlString)) {
                    Color.clear
                }
            )
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                selectedImageIndex = index
                showImageViewer = true
            }
    }

    // MARK: - Reaction Bar (aligned with BoardFeedPostCard engageRow)

    private var reactionBar: some View {
        let isLiked = myReaction == "heart"
        let heartCount = localReactionCounts["heart"] ?? 0
        let canRepost = !(post.authorIsPrivate == true && !post.isAnonymous)
        let isBookmarked = bookmarkService.isBookmarked(post.id)
        let combinedRepostCount = localRepostCount + localQuoteCount

        return HStack(spacing: 0) {
            // 閲覧数（表示のみ・タップ不可）
            engageItem(icon: "chart.bar", count: post.viewCount, isActive: false) {}
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            // コメント（タップで返信入力にフォーカス）
            engageItem(icon: "bubble.left", count: replies.isEmpty ? post.replyCount : replies.count, isActive: false) {
                isReplyFocused = true
            }
            .frame(maxWidth: .infinity)

            // ハート
            engageItem(
                icon: isLiked ? "heart.fill" : "heart",
                count: heartCount,
                isActive: isLiked,
                heartBurst: showHeartBurst
            ) {
                HapticManager.light()
                guard authService.hasRealAccount else {
                    showSignIn = true
                    return
                }
                Task { await toggleReaction(type: "heart") }
            }
            .frame(maxWidth: .infinity)

            // リポスト / 引用 (Menu) — 非公開投稿は非表示
            if canRepost {
                Menu {
                    Button {
                        HapticManager.light()
                        guard authService.hasRealAccount else {
                            showSignIn = true
                            return
                        }
                        Task { await toggleRepost() }
                    } label: {
                        Label(
                            String(localized: "リポスト", bundle: LanguageManager.appBundle),
                            systemImage: "arrow.2.squarepath"
                        )
                    }
                    Button {
                        HapticManager.light()
                        guard authService.hasRealAccount else {
                            showSignIn = true
                            return
                        }
                        AnalyticsManager.shared.track("post_quote_initiate", properties: ["postId": post.id])
                        showQuoteCompose = true
                    } label: {
                        Label(
                            String(localized: "引用", bundle: LanguageManager.appBundle),
                            systemImage: "quote.bubble"
                        )
                    }
                } label: {
                    engageItemLabel(
                        icon: "arrow.2.squarepath",
                        count: combinedRepostCount,
                        isActive: isRepostedByMe
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            // ブックマーク（右端）
            engageItem(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                count: localBookmarkCount > 0 ? localBookmarkCount : nil,
                isActive: isBookmarked
            ) {
                HapticManager.light()
                guard authService.hasRealAccount else {
                    showSignIn = true
                    return
                }
                let wasBookmarked = isBookmarked
                bookmarkService.toggle(post.id)
                let delta = wasBookmarked ? -1 : 1
                localBookmarkCount = max(0, localBookmarkCount + delta)
                Task {
                    await firestoreService.incrementBookmarkCount(postId: post.id, delta: delta)
                    BoardPostMutationBus.postBookmark(
                        .init(postId: post.id, isBookmarked: !wasBookmarked, bookmarkCount: localBookmarkCount)
                    )
                    if !wasBookmarked {
                        let actorName = authService.currentUser?.displayName ?? "ユーザー"
                        try? await firestoreService.createBookmarkNotification(
                            postAuthorId: post.authorId,
                            postId: post.id,
                            bookmarkerName: actorName
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 28)
        .padding(.top, 4)
    }

    /// フィードカードの engageItem と同じタイポ/配色。
    private func engageItem(icon: String, count: Int?, isActive: Bool, heartBurst: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            engageItemLabel(icon: icon, count: count, isActive: isActive, heartBurst: heartBurst)
        }
        .buttonStyle(.plain)
    }

    /// Menu などラベルだけ提供したい場合に使うバージョン
    private func engageItemLabel(icon: String, count: Int?, isActive: Bool, heartBurst: Bool = false) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(isActive ? BoardFeedPalette.accentPink : BoardFeedPalette.engageGray)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isActive)
                if heartBurst {
                    HeartBurstView {
                        showHeartBurst = false
                    }
                }
            }
            .frame(width: 18, height: 18)
            if let count = count {
                Text(verbatim: "\(count)")
                    .font(MeloFonts.zenMaruMedium(16))
                    .foregroundColor(isActive ? BoardFeedPalette.accentPink : BoardFeedPalette.engageGray)
            }
        }
    }

    // MARK: - Reply Section

    private var replySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "返信", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(BoardDetailTokens.textDark)

                Text("\(filteredReplies.count)")
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(BoardDetailTokens.textMuted)

                Spacer()
            }
            .padding(.bottom, 4)

            if isLoadingReplies {
                ProgressView()
                    .tint(BoardDetailTokens.brandPink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if filteredReplies.isEmpty {
                VStack(spacing: 8) {
                    Image("mero_pair_04")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)

                    Text(String(localized: "まだ返信がありません", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(BoardDetailTokens.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(threadedReplies, id: \.reply.id) { item in
                    replyRow(item.reply)
                        .padding(.leading, item.isChild ? 38 : 0)

                    Divider()
                        .background(BoardDetailTokens.divider)
                        .padding(.leading, item.isChild ? 38 : 0)
                }
            }
        }
    }

    private var filteredReplies: [BoardReply] {
        replies.filter { !blockService.isBlocked($0.authorId) }
    }

    /// メンションされたコメント (`mentionedReplyId`) を親として、
    /// 親 → 子返信 の順に並べたフラットなスレッド配列を返す。
    /// 子は表示時にインデントする。多階層は1段にフラット化 (X風)。
    private var threadedReplies: [(reply: BoardReply, isChild: Bool)] {
        let visible = filteredReplies
        let map = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })

        // 各 reply のルート (= 一番上の親) を辿る
        func rootId(of reply: BoardReply) -> String {
            var current = reply
            var seen: Set<String> = [current.id]
            while let parentId = current.mentionedReplyId,
                  let parent = map[parentId],
                  !seen.contains(parent.id) {
                seen.insert(parent.id)
                current = parent
            }
            return current.id
        }

        var grouped: [String: [BoardReply]] = [:]
        for r in visible {
            grouped[rootId(of: r), default: []].append(r)
        }

        // ルート (mentionedReplyId が無いか、親が見えない返信) を時系列に並べる
        let roots = visible.filter { reply in
            guard let parentId = reply.mentionedReplyId else { return true }
            return map[parentId] == nil
        }.sorted { $0.createdAt < $1.createdAt }

        var result: [(reply: BoardReply, isChild: Bool)] = []
        for root in roots {
            let group = (grouped[root.id] ?? []).sorted { $0.createdAt < $1.createdAt }
            for r in group {
                result.append((r, isChild: r.id != root.id))
            }
        }
        return result
    }

    private func replyRow(_ reply: BoardReply) -> some View {
        let currentUserId = authService.currentUser?.id
        let canDelete = reply.authorId == currentUserId || post.authorId == currentUserId
        let isLiked = likedReplyIds.contains(reply.id)
        let likeCount = replyLikeCounts[reply.id] ?? 0

        return HStack(alignment: .top, spacing: 10) {
            // アバター（タップでプロフィール表示）
            Button {
                profileTarget = ProfileSheetTarget(userId: reply.authorId)
            } label: {
                if let urlString = reply.authorProfileImageURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) {
                        replyAvatarPlaceholder(reply.authorDisplayName, replyId: reply.id)
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                } else {
                    replyAvatarPlaceholder(reply.authorDisplayName, replyId: reply.id)
                        .frame(width: 30, height: 30)
                }
            }
            .buttonStyle(.plain)

            // コンテンツ
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    // ユーザー名（タップでプロフィール表示）
                    Button {
                        profileTarget = ProfileSheetTarget(userId: reply.authorId)
                    } label: {
                        HStack(spacing: 6) {
                            Text(reply.authorDisplayName)
                                .font(MeloFonts.zenMaruMedium(13))
                                .foregroundColor(MeloColors.Dark.textPrimary)

                            // 投稿者本人による返信に「投稿者」ピル
                            if reply.authorId == post.authorId {
                                Text(String(localized: "投稿者", bundle: LanguageManager.appBundle))
                                    .font(MeloFonts.zenMaruMedium(9))
                                    .foregroundColor(MeloColors.Dark.onAccent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(MeloColors.Dark.accentGradient))
                            }

                            if let badge = reply.authorBadge {
                                Text(badge.typeCode)
                                    .font(MeloFonts.zenMaruMedium(8))
                                    .foregroundColor(MeloColors.Dark.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule()
                                            .fill(MeloColors.mbtiColor(for: badge.typeCode).opacity(0.35))
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(BoardTimeFormatter.timeAgo(reply.createdAt))
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(BoardDetailTokens.textMuted)
                }

                // メンション先の表示
                if let mentionedName = reply.mentionedUserName {
                    HStack(spacing: 2) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 9))
                        Text("@\(mentionedName)")
                            .font(MeloFonts.zenMaruRegular(12))
                    }
                    .foregroundColor(BoardDetailTokens.brandPink)
                    .padding(.top, 1)
                }

                // スタンプの場合は画像表示
                if let stamp = reply.stamp {
                    if stamp.isImageStamp {
                        Image(stamp.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .padding(.top, 2)
                    } else {
                        // 旧絵文字スタンプのフォールバック
                        Text(reply.content)
                            .font(.system(size: 36))
                            .padding(.top, 2)
                    }
                } else {
                    if !reply.content.isEmpty {
                        Text(reply.content)
                            .font(MeloFonts.zenMaruRegular(14))
                            .foregroundColor(BoardDetailTokens.textDark)
                            .lineSpacing(4)
                    }
                }

                // 添付画像
                if !reply.imageURLs.isEmpty {
                    replyImageGrid(reply.imageURLs)
                        .padding(.top, 4)
                }

                // いいね & 返信ボタン
                HStack(spacing: 16) {
                    // いいねボタン
                    Button {
                        HapticManager.light()
                        Task { await toggleReplyLike(reply) }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 13))
                                .foregroundColor(isLiked ? BoardDetailTokens.brandPink : BoardDetailTokens.textGrey)

                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(MeloFonts.zenMaruRegular(11))
                                    .foregroundColor(isLiked ? BoardDetailTokens.brandPink : BoardDetailTokens.textGrey)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // 返信ボタン（メンション付き）
                    Button {
                        HapticManager.light()
                        replyMention = ReplyMentionInfo(replyId: reply.id, userName: reply.authorDisplayName)
                        isReplyFocused = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.system(size: 12))
                            Text(String(localized: "返信", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruRegular(11))
                        }
                        .foregroundColor(BoardDetailTokens.textGrey)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 12)
        .contextMenu {
            if canDelete {
                Button(role: .destructive) {
                    Task { await deleteReply(reply) }
                } label: {
                    Label(String(localized: "削除", bundle: LanguageManager.appBundle), systemImage: "trash")
                }
            }
        }
    }

    private func replyAvatarPlaceholder(_ name: String, replyId: String? = nil) -> some View {
        let anonymousName = String(localized: "匿名ユーザー", bundle: LanguageManager.appBundle)
        let isAnonymous = name == anonymousName
        return Group {
            if isAnonymous {
                // 匿名返信もペア画像から決定論的に。replyId をシードに使うので返信ごとに違う画像が出る。
                Image(AnonymousAvatarPicker.imageName(forSeed: replyId ?? name))
                    .resizable()
                    .scaledToFit()
                    .background(Circle().fill(BoardDetailTokens.softPinkBg))
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(BoardDetailTokens.softPinkBg)
                    .overlay(
                        Text(String(name.prefix(1)))
                            .font(MeloFonts.zenMaruOrFallback(12))
                            .foregroundColor(BoardDetailTokens.brandPink)
                    )
            }
        }
    }

    // MARK: - Reply Image Grid

    private func replyImageGrid(_ urls: [String]) -> some View {
        let imageURLs = Array(urls.prefix(4))
        let count = imageURLs.count

        return Group {
            if count == 1 {
                replyImageCell(imageURLs[0], urls: imageURLs, index: 0)
            } else if count == 2 {
                HStack(spacing: 4) {
                    replyImageCell(imageURLs[0], urls: imageURLs, index: 0)
                    replyImageCell(imageURLs[1], urls: imageURLs, index: 1)
                }
            } else if count == 3 {
                HStack(spacing: 4) {
                    replyImageCell(imageURLs[0], urls: imageURLs, index: 0)
                    VStack(spacing: 4) {
                        replyImageCell(imageURLs[1], urls: imageURLs, index: 1)
                        replyImageCell(imageURLs[2], urls: imageURLs, index: 2)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        replyImageCell(imageURLs[0], urls: imageURLs, index: 0)
                        replyImageCell(imageURLs[1], urls: imageURLs, index: 1)
                    }
                    HStack(spacing: 4) {
                        replyImageCell(imageURLs[2], urls: imageURLs, index: 2)
                        replyImageCell(imageURLs[3], urls: imageURLs, index: 3)
                    }
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func replyImageCell(_ urlString: String, urls: [String], index: Int) -> some View {
        BoardDetailTokens.softPinkBg
            .overlay(
                CachedAsyncImage(url: URL(string: urlString)) {
                    Color.clear
                }
            )
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                replyImageViewerURLs = urls
                replyImageViewerIndex = index
                showReplyImageViewer = true
            }
    }

    // MARK: - Reply Input Bar

    /// 投稿者本人なら4枚、それ以外は1枚まで
    private var replyMaxImages: Int {
        authService.currentUser?.id == post.authorId ? 4 : 1
    }

    private var replyInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(BoardDetailTokens.divider)

            // メンション表示バー
            if let mention = replyMention {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(BoardDetailTokens.brandPink)

                    Text(String(localized: "\(mention.userName) に返信", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(MeloColors.Dark.textPrimary)

                    Spacer()

                    Button {
                        replyMention = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(BoardDetailTokens.textGrey)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(BoardDetailTokens.softPinkBg)
            }

            // 画像プレビュー
            if !replyImageDatas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(replyImageDatas.enumerated()), id: \.offset) { index, imageData in
                            if let uiImage = UIImage(data: imageData) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button {
                                        replyImageDatas.remove(at: index)
                                        if index < replyPhotos.count {
                                            replyPhotos.remove(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 56)
                .padding(.top, 8)
            }

            HStack(alignment: .center, spacing: 10) {
                // 自分のアバター
                myAvatar
                    .frame(width: 30, height: 30)

                // テキスト入力（pill形状）
                HStack(spacing: 6) {
                    // スタンプボタン
                    Button {
                        HapticManager.light()
                        guard authService.hasRealAccount else {
                            showSignIn = true
                            return
                        }
                        showStampPicker.toggle()
                        isReplyFocused = false
                    } label: {
                        Image("stamp_button")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .opacity(showStampPicker ? 1.0 : 0.85)
                    }
                    .buttonStyle(.plain)

                    // 画像添付ボタン
                    PhotosPicker(
                        selection: $replyPhotos,
                        maxSelectionCount: replyMaxImages,
                        matching: .images
                    ) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(!replyImageDatas.isEmpty ? BoardDetailTokens.brandPink : BoardDetailTokens.textGrey)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: replyPhotos) { _ in
                        Task { await loadReplyImages() }
                    }

                    TextField(
                        String(localized: "返信を書く...", bundle: LanguageManager.appBundle),
                        text: $replyText
                    )
                    .font(MeloFonts.zenMaruRegular(14))
                    .foregroundColor(BoardDetailTokens.textDark)
                    .textFieldStyle(.plain)
                    .focused($isReplyFocused)
                    .onTapGesture {
                        showStampPicker = false
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(BoardDetailTokens.softPinkBg)
                )

                // 送信ボタン
                if isSendingReply {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(BoardDetailTokens.brandPink)
                } else {
                    let hasContent = !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !replyImageDatas.isEmpty
                    Button {
                        HapticManager.medium()
                        if authService.hasRealAccount {
                            Task { await submitReply() }
                        } else {
                            showSignIn = true
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(hasContent ? BoardDetailTokens.accentPink : BoardDetailTokens.softerPinkBg)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor(hasContent ? MeloColors.Dark.onAccent : BoardDetailTokens.textMuted)
                                .offset(x: -1)
                        }
                        .frame(width: 30, height: 30)
                    }
                    .disabled(!hasContent)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            Rectangle()
                .fill(MeloColors.Dark.bgElevated)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: -1)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var myAvatar: some View {
        Group {
            if let urlString = myProfileImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) {
                    myAvatarPlaceholder
                }
                .clipShape(Circle())
            } else {
                myAvatarPlaceholder
            }
        }
    }

    private var myAvatarPlaceholder: some View {
        Circle()
            .fill(BoardDetailTokens.softPinkBg)
            .overlay(
                Text(String(myDisplayName.prefix(1)))
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .foregroundColor(BoardDetailTokens.brandPink)
            )
    }

    // MARK: - Stamp Picker

    @State private var selectedStampCategory: BoardStamp.StampCategory = .greeting

    private var stampPickerView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(BoardDetailTokens.divider)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(BoardStamp.StampCategory.allCases, id: \.self) { category in
                        Button {
                            selectedStampCategory = category
                        } label: {
                            Text(category.localizedName)
                                .font(MeloFonts.zenMaruMedium(11))
                                .foregroundColor(selectedStampCategory == category ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(selectedStampCategory == category ? BoardDetailTokens.accentPink : BoardDetailTokens.softPinkBg)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            let stamps = BoardStamp.stamps(for: selectedStampCategory)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(stamps, id: \.id) { stamp in
                    Button {
                        HapticManager.light()
                        Task { await sendStamp(stamp) }
                    } label: {
                        Image(stamp.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(MeloColors.Dark.bgElevated)
    }

    // MARK: - Toast

    private func showToast(_ message: String, isError: Bool = false) {
        toastIsError = isError
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Actions

    /// 詳細を開いた瞬間にサーバー側の最新カウントを取得して同期する。
    /// フィードからの post スナップショットは古い場合があるため。
    /// 取得した値は broadcast でフィード側にも伝搬し、ビュー間の整合を保つ。
    private func refreshFromServer() async {
        guard let fresh = try? await firestoreService.fetchPost(postId: post.id) else { return }
        localReactionCounts = fresh.reactionCounts
        localPollOptions = fresh.pollOptions ?? []
        localTotalVotes = fresh.totalVotes
        localRepostCount = fresh.repostCount
        localQuoteCount = fresh.quoteCount
        localBookmarkCount = fresh.bookmarkCount

        // フィード側にも最新値を伝搬(他の画面で開いている同じ投稿のカウントも揃える)
        BoardPostMutationBus.postRepost(
            .init(postId: post.id, isRepostedByMe: isRepostedByMe, repostCount: fresh.repostCount)
        )
        BoardPostMutationBus.postQuoteCount(
            .init(postId: post.id, quoteCount: fresh.quoteCount)
        )
        BoardPostMutationBus.postReplyCount(
            .init(postId: post.id, replyCount: fresh.replyCount)
        )
    }

    private func loadReplies() async {
        isLoadingReplies = true
        do {
            replies = try await firestoreService.fetchReplies(postId: post.id)

            if !replies.isEmpty {
                let replyIds = replies.map { $0.id }

                // いいね数を取得
                replyLikeCounts = (try? await firestoreService.fetchReplyLikeCounts(postId: post.id, replyIds: replyIds)) ?? [:]

                // 自分のいいね状態を取得
                if let userId = authService.currentUser?.id {
                    likedReplyIds = (try? await firestoreService.fetchMyReplyLikes(postId: post.id, userId: userId, replyIds: replyIds)) ?? []
                }
            }
        } catch {
            print("[Board] Failed to load replies: \(error)")
            showToast(String(localized: "返信の読み込みに失敗しました", bundle: LanguageManager.appBundle), isError: true)
        }
        isLoadingReplies = false
    }

    private func loadMyReaction() async {
        guard let userId = authService.currentUser?.id else { return }
        myReaction = try? await firestoreService.fetchMyReaction(postId: post.id, userId: userId)
    }

    private func loadMyVote() async {
        guard let userId = authService.currentUser?.id else { return }
        guard post.pollOptions != nil else { return }
        myVote = try? await firestoreService.fetchMyVote(postId: post.id, userId: userId)
    }

    private func loadIsReposted() async {
        guard let userId = authService.currentUser?.id else { return }
        isRepostedByMe = (try? await firestoreService.fetchIsReposted(postId: post.id, userId: userId)) ?? false
    }

    private func toggleRepost() async {
        guard let userId = authService.currentUser?.id else { return }
        let wasReposted = isRepostedByMe
        // 楽観的更新
        isRepostedByMe.toggle()
        localRepostCount = max(0, localRepostCount + (isRepostedByMe ? 1 : -1))
        do {
            let nowReposted = try await firestoreService.toggleRepost(
                postId: post.id, userId: userId, authorId: post.authorId
            )
            isRepostedByMe = nowReposted
            // サーバー側の最新カウントを読み戻し、ビュー間で揃える
            let serverCount = (try? await firestoreService.fetchPost(postId: post.id))?.repostCount ?? localRepostCount
            localRepostCount = serverCount
            AnalyticsManager.shared.track("post_repost", properties: ["postId": post.id])
            BoardPostMutationBus.postRepost(
                .init(postId: post.id, isRepostedByMe: nowReposted, repostCount: serverCount)
            )
            if nowReposted {
                let reposterName = authService.currentUser?.displayName ?? "ユーザー"
                try? await firestoreService.createRepostNotification(
                    postAuthorId: post.authorId,
                    postId: post.id,
                    reposterName: reposterName
                )
            }
        } catch {
            isRepostedByMe = wasReposted
            localRepostCount = post.repostCount
        }
    }

    private func loadMyProfile() async {
        guard let userId = authService.currentUser?.id else { return }
        if let profile = try? await firestoreService.getProfile(userId: userId) {
            myProfileImageURL = profile.profileImageURL
            myDisplayName = profile.displayName
        }
    }

    private func castVote(optionId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        isVoting = true

        // 楽観的更新
        let oldVote = myVote
        let oldOptions = localPollOptions
        let oldTotal = localTotalVotes

        // 旧投票の減算
        if let old = oldVote, let idx = localPollOptions.firstIndex(where: { $0.id == old }) {
            localPollOptions[idx] = PollOption(id: localPollOptions[idx].id, text: localPollOptions[idx].text, voteCount: max(0, localPollOptions[idx].voteCount - 1))
        }
        // 新投票の加算
        if let idx = localPollOptions.firstIndex(where: { $0.id == optionId }) {
            localPollOptions[idx] = PollOption(id: localPollOptions[idx].id, text: localPollOptions[idx].text, voteCount: localPollOptions[idx].voteCount + 1)
        }
        if oldVote == nil { localTotalVotes += 1 }
        myVote = optionId

        do {
            try await firestoreService.vote(postId: post.id, userId: userId, optionId: optionId)
            HapticManager.success()
            // Firestore 書き込み成功後のみブロードキャスト
            BoardPostMutationBus.postPollVote(
                .init(postId: post.id, myVote: myVote, options: localPollOptions, totalVotes: localTotalVotes)
            )
        } catch {
            // ロールバック
            myVote = oldVote
            localPollOptions = oldOptions
            localTotalVotes = oldTotal
            HapticManager.error()
        }

        isVoting = false
    }


    private func toggleReaction(type: String) async {
        guard let userId = authService.currentUser?.id else { return }

        // 楽観的UI更新
        let oldReaction = myReaction
        if myReaction == type {
            // 同じリアクション → 解除
            myReaction = nil
            localReactionCounts[type, default: 0] -= 1
        } else {
            // 古いリアクションを減らす
            if let old = oldReaction {
                localReactionCounts[old, default: 0] -= 1
            }
            myReaction = type
            localReactionCounts[type, default: 0] += 1
            if type == "heart" { showHeartBurst = true }
        }

        do {
            try await firestoreService.toggleReaction(postId: post.id, userId: userId, reactionType: type)
            // Firestore 書き込み成功後のみブロードキャスト
            BoardPostMutationBus.postReaction(
                .init(postId: post.id, myReaction: myReaction, counts: localReactionCounts)
            )
        } catch {
            // ロールバック
            myReaction = oldReaction
            localReactionCounts = post.reactionCounts
            print("[Board] Failed to toggle reaction: \(error)")
            showToast(String(localized: "リアクションに失敗しました", bundle: LanguageManager.appBundle), isError: true)
        }
    }

    private func submitReply() async {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImages = !replyImageDatas.isEmpty
        guard !trimmed.isEmpty || hasImages else { return }
        guard let user = authService.currentUser else { return }

        isSendingReply = true

        do {
            let badge = try? await firestoreService.loadUserBadge(userId: user.id)
            let userProfile = try? await firestoreService.getProfile(userId: user.id)

            // 自分の匿名投稿への返信は匿名で送信する
            // (authorId は本人 UID のまま保持し、表示名/アバター/バッジだけ匿名化)
            let isOwnAnonymousPost = (user.id == post.authorId) && post.isAnonymous
            let anonymousName = String(localized: "匿名ユーザー", bundle: LanguageManager.appBundle)
            let resolvedAuthorName: String = isOwnAnonymousPost ? anonymousName : user.displayName
            let resolvedProfileURL: String? = isOwnAnonymousPost ? nil : userProfile?.profileImageURL
            let resolvedBadge: LoveTypeBadge? = isOwnAnonymousPost ? nil : badge

            // 画像アップロード（投稿と同じStorageパスを使用）
            var uploadedImageURLs: [String] = []
            for imageData in replyImageDatas {
                let url = try await firestoreService.uploadImage(imageData, postId: post.id)
                uploadedImageURLs.append(url)
            }

            let currentMention = replyMention
            let reply = try await firestoreService.createReply(
                postId: post.id,
                content: trimmed,
                authorId: user.id,
                authorName: resolvedAuthorName,
                authorProfileImageURL: resolvedProfileURL,
                badge: resolvedBadge,
                imageURLs: uploadedImageURLs,
                mention: currentMention
            )
            replies.append(reply)
            replyText = ""
            replyPhotos = []
            replyImageDatas = []
            replyMention = nil
            isReplyFocused = false
            HapticManager.success()

            // Firestore 成功後のみブロードキャスト（返信数）
            BoardPostMutationBus.postReplyCount(
                .init(postId: post.id, replyCount: replies.count)
            )

            // 投稿者に通知
            try? await firestoreService.createReplyNotification(
                postAuthorId: post.authorId,
                postId: post.id,
                replierName: resolvedAuthorName
            )

            // メンション先ユーザーに通知（投稿者通知と重複しないように）
            if let mention = currentMention {
                let mentionedReply = replies.first { $0.id == mention.replyId }
                if let mentionedUserId = mentionedReply?.authorId, mentionedUserId != post.authorId {
                    try? await firestoreService.createMentionNotification(
                        mentionedUserId: mentionedUserId,
                        postId: post.id,
                        actorName: resolvedAuthorName
                    )
                }
            }
        } catch let error as ContentModeration.ModerationError {
            // App Store Guideline 1.2: 不適切表現で返信がブロックされた
            HapticManager.error()
            showToast(error.errorDescription ?? "", isError: true)
        } catch {
            print("[Board] Failed to submit reply: \(error)")
            HapticManager.error()
            showToast(String(localized: "返信の送信に失敗しました", bundle: LanguageManager.appBundle), isError: true)
        }

        isSendingReply = false
    }

    private func deleteReply(_ reply: BoardReply) async {
        do {
            try await firestoreService.deleteReply(postId: post.id, replyId: reply.id)
            withAnimation {
                replies.removeAll { $0.id == reply.id }
            }
            HapticManager.success()
            // Firestore 成功後のみブロードキャスト（返信数）
            BoardPostMutationBus.postReplyCount(
                .init(postId: post.id, replyCount: replies.count)
            )
        } catch {
            print("[Board] Failed to delete reply: \(error)")
            HapticManager.error()
        }
    }

    private func toggleReplyLike(_ reply: BoardReply) async {
        guard let userId = authService.currentUser?.id else {
            showSignIn = true
            return
        }
        guard authService.hasRealAccount else {
            showSignIn = true
            return
        }

        // 楽観的UI更新
        let wasLiked = likedReplyIds.contains(reply.id)
        if wasLiked {
            likedReplyIds.remove(reply.id)
            replyLikeCounts[reply.id] = max(0, (replyLikeCounts[reply.id] ?? 0) - 1)
        } else {
            likedReplyIds.insert(reply.id)
            replyLikeCounts[reply.id] = (replyLikeCounts[reply.id] ?? 0) + 1
        }

        do {
            let nowLiked = try await firestoreService.toggleReplyLike(postId: post.id, replyId: reply.id, userId: userId)

            // いいね追加時に通知
            if nowLiked {
                try? await firestoreService.createReplyLikeNotification(
                    replyAuthorId: reply.authorId,
                    postId: post.id,
                    likerName: authService.currentUser?.displayName ?? ""
                )
            }
        } catch {
            // ロールバック
            if wasLiked {
                likedReplyIds.insert(reply.id)
                replyLikeCounts[reply.id] = (replyLikeCounts[reply.id] ?? 0) + 1
            } else {
                likedReplyIds.remove(reply.id)
                replyLikeCounts[reply.id] = max(0, (replyLikeCounts[reply.id] ?? 0) - 1)
            }
            print("[Board] Failed to toggle reply like: \(error)")
        }
    }

    private func sendStamp(_ stamp: BoardStamp) async {
        guard let user = authService.currentUser else { return }

        isSendingReply = true
        showStampPicker = false

        do {
            let badge = try? await firestoreService.loadUserBadge(userId: user.id)
            let userProfile = try? await firestoreService.getProfile(userId: user.id)

            // 自分の匿名投稿への返信は匿名で送信する
            let isOwnAnonymousPost = (user.id == post.authorId) && post.isAnonymous
            let anonymousName = String(localized: "匿名ユーザー", bundle: LanguageManager.appBundle)
            let resolvedAuthorName: String = isOwnAnonymousPost ? anonymousName : user.displayName
            let resolvedProfileURL: String? = isOwnAnonymousPost ? nil : userProfile?.profileImageURL
            let resolvedBadge: LoveTypeBadge? = isOwnAnonymousPost ? nil : badge

            let reply = try await firestoreService.createStampReply(
                postId: post.id,
                stamp: stamp,
                authorId: user.id,
                authorName: resolvedAuthorName,
                authorProfileImageURL: resolvedProfileURL,
                badge: resolvedBadge
            )
            replies.append(reply)
            HapticManager.success()

            // Firestore 成功後のみブロードキャスト（返信数）
            BoardPostMutationBus.postReplyCount(
                .init(postId: post.id, replyCount: replies.count)
            )

            try? await firestoreService.createReplyNotification(
                postAuthorId: post.authorId,
                postId: post.id,
                replierName: resolvedAuthorName
            )
        } catch {
            print("[Board] Failed to send stamp: \(error)")
            HapticManager.error()
        }

        isSendingReply = false
    }

    private func reportPost() async {
        guard let userId = authService.currentUser?.id else { return }
        try? await firestoreService.reportPost(postId: post.id, reporterId: userId, reason: "inappropriate")
        HapticManager.success()
    }

    private func deletePost() async {
        do {
            try await firestoreService.deletePost(postId: post.id)
            HapticManager.success()
            onDelete?()
            dismiss()
        } catch {
            print("[Board] Failed to delete post: \(error)")
            HapticManager.error()
        }
    }

    private func loadReplyImages() async {
        var newData: [Data] = []
        for item in replyPhotos {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data),
                   let compressed = compressReplyImage(uiImage) {
                    newData.append(compressed)
                }
            }
        }
        replyImageDatas = newData
    }

    private func compressReplyImage(_ image: UIImage, maxWidth: CGFloat = 800) -> Data? {
        let scale = min(1.0, maxWidth / image.size.width)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Full Diagnosis Card

struct BoardDiagnosisCardFull: View {
    let card: DiagnosisCard

    var body: some View {
        Group {
            switch card.cardStyle {
            case .toxicity:
                ToxicityVerdictCardView(card: card)
            case .type:
                typeFullCard
            case .loveWords:
                loveWordsFullCard
            default:
                // 旧データでも毒性フィールドがあれば毒性カードで描画。
                if card.hasToxicityData {
                    ToxicityVerdictCardView(card: card)
                } else {
                    scoreFullCard
                }
            }
        }
        .padding(.horizontal, card.cardStyle == .toxicity || card.hasToxicityData ? 0 : 22)
        .padding(.vertical, card.cardStyle == .toxicity || card.hasToxicityData ? 0 : 16)
        .background(
            (card.cardStyle == .toxicity || card.hasToxicityData)
                ? AnyView(Color.clear)
                : AnyView(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MeloColors.Dark.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(BoardFeedPalette.cardBorderGray, lineWidth: 1)
                        )
                )
        )
    }

    // MARK: - Score Card (新診断結果デザイン: 相性メッセージ + グレード画像 + 4軸バー)

    private var scoreFullCard: some View {
        VStack(alignment: .center, spacing: 12) {
            // 関係性ラベル + MBTI (任意)
            if card.relationshipLabel != nil || !card.effectivePartnerMBTIs.isEmpty {
                HStack(spacing: 4) {
                    if let label = card.relationshipLabel {
                        Text(label)
                            .font(MeloFonts.zenMaruOrFallback(13))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    }
                    if card.relationshipLabel != nil && !card.effectivePartnerMBTIs.isEmpty {
                        Text("-")
                            .font(MeloFonts.zenMaruRegular(13))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    }
                    ForEach(Array(card.effectivePartnerMBTIs.enumerated()), id: \.offset) { index, mbti in
                        if index > 0 {
                            Text("×")
                                .font(MeloFonts.zenMaruRegular(10))
                                .foregroundColor(MeloColors.Dark.textSecondary)
                        }
                        Text(mbti)
                            .font(MeloFonts.zenMaruOrFallback(9))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(MeloColors.mbtiColor(for: mbti)))
                    }
                }
            }

            // 相性メッセージ (3色分け)
            compatibilityHeadline

            // メイン: グレード画像 + 点数 + 4軸バー
            HStack(alignment: .center, spacing: 16) {
                Image(gradeImageName(for: card.totalScore))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(card.totalScore)")
                            .font(MeloFonts.jerseyOrFallback(48))
                            .foregroundColor(MeloColors.Dark.accent)
                            .tracking(-1.0)
                        Text(String(localized: "点", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(13))
                            .foregroundColor(MeloColors.Dark.accent)
                    }

                    VStack(spacing: 5) {
                        scoreAxisBar(String(localized: "トーク量", bundle: LanguageManager.appBundle), score: card.balanceScore)
                        scoreAxisBar(String(localized: "会話テンション", bundle: LanguageManager.appBundle), score: card.tensionScore)
                        scoreAxisBar(String(localized: "返信ペース", bundle: LanguageManager.appBundle), score: card.responseScore)
                        scoreAxisBar(String(localized: "思いやり度", bundle: LanguageManager.appBundle), score: card.wordScore)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 新診断結果ページと同じ「○○の相性です」見出し (黒+ピンク混合)。
    private var compatibilityHeadline: some View {
        let phrase = compatibilityPhrase(for: card.totalScore)
        let dark = MeloColors.Dark.textPrimary
        let pink = MeloColors.Dark.accent
        return (Text(phrase.prefix).foregroundColor(dark)
                + Text(phrase.highlight).foregroundColor(pink)
                + Text(phrase.suffix).foregroundColor(dark))
            .font(MeloFonts.zenMaruOrFallback(18))
            .tracking(0.54)
            .multilineTextAlignment(.center)
    }

    private func compatibilityPhrase(for total: Int) -> (prefix: String, highlight: String, suffix: String) {
        switch total {
        case 90...:
            return (
                String(localized: "さいっこうの", bundle: LanguageManager.appBundle),
                String(localized: "相性", bundle: LanguageManager.appBundle),
                String(localized: "です", bundle: LanguageManager.appBundle)
            )
        case 70..<90:
            return (
                String(localized: "とても", bundle: LanguageManager.appBundle),
                String(localized: "いい相性", bundle: LanguageManager.appBundle),
                String(localized: "です", bundle: LanguageManager.appBundle)
            )
        case 50..<70:
            return (
                String(localized: "ふつうの", bundle: LanguageManager.appBundle),
                String(localized: "相性", bundle: LanguageManager.appBundle),
                String(localized: "です", bundle: LanguageManager.appBundle)
            )
        case 30..<50:
            return (
                String(localized: "もう少し", bundle: LanguageManager.appBundle),
                String(localized: "頑張ろう", bundle: LanguageManager.appBundle),
                ""
            )
        default:
            return (
                "",
                String(localized: "むずかしいかも", bundle: LanguageManager.appBundle),
                String(localized: "...", bundle: LanguageManager.appBundle)
            )
        }
    }

    private func gradeImageName(for total: Int) -> String {
        switch total {
        case 80...:    return "result_grade_a"
        case 60..<80:  return "result_grade_b"
        case 40..<60:  return "result_grade_c"
        case 20..<40:  return "result_grade_d"
        default:       return "result_grade_e"
        }
    }

    private func scoreAxisBar(_ label: String, score: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(MeloFonts.zenMaruOrFallback(10))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 78, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MeloColors.Dark.track)
                    Capsule()
                        .fill(MeloColors.Dark.accentGradient)
                        .frame(width: geo.size.width * CGFloat(min(score, 100)) / 100)
                }
            }
            .frame(height: 9)
        }
    }

    // MARK: - Type Card

    private var typeFullCard: some View {
        VStack(spacing: 8) {
            // 関係性ラベル - MBTI
            if card.relationshipLabel != nil || card.selfMBTI != nil || !card.effectivePartnerMBTIs.isEmpty {
                HStack(spacing: 6) {
                    if let label = card.relationshipLabel {
                        Text(label)
                            .font(MeloFonts.zenMaruOrFallback(11))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    }
                    if card.relationshipLabel != nil && (card.selfMBTI != nil || !card.effectivePartnerMBTIs.isEmpty) {
                        Text("-")
                            .font(MeloFonts.zenMaruRegular(11))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    }
                    if let selfMBTI = card.selfMBTI {
                        Text(selfMBTI)
                            .font(MeloFonts.zenMaruOrFallback(9))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(MeloColors.mbtiColor(for: selfMBTI)))
                    }
                    ForEach(Array(card.effectivePartnerMBTIs.enumerated()), id: \.offset) { index, mbti in
                        if card.selfMBTI != nil || index > 0 {
                            Text("×")
                                .font(MeloFonts.zenMaruRegular(10))
                                .foregroundColor(MeloColors.Dark.textSecondary)
                        }
                        Text(mbti)
                            .font(MeloFonts.zenMaruOrFallback(9))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(MeloColors.mbtiColor(for: mbti)))
                    }
                }
            }

            // タイプ名（ピンク大文字）
            Text(card.localizedTypeName)
                .font(MeloFonts.zenMaruOrFallback(22))
                .foregroundColor(MeloColors.Dark.accent)
                .shadow(color: MeloColors.Dark.accent.opacity(0.3), radius: 8)
                .multilineTextAlignment(.center)

            // マスコット画像 (古い投稿でも typeCode から最新アセット名を引き直す)
            if let imageName = card.localizedTypeImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
            }

            // 説明文（投稿詳細では全文表示）
            if let desc = card.localizedTypeDescription {
                Text(desc)
                    .font(MeloFonts.zenMaruOrFallback(13))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    // MARK: - Love Words Card

    private var loveWordsFullCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // タイトル（診断ページ準拠）
            Text(String(localized: "愛情表現", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(20))
                .foregroundColor(MeloColors.Dark.accent)

            // カウント比較カード（枠線 + 白背景）
            if let selfTotal = card.selfLoveTotal, let partnerTotal = card.partnerLoveTotal {
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("\(selfTotal)")
                            .font(MeloFonts.jerseyOrFallback(48))
                            .foregroundColor(MeloColors.Dark.accent)
                        Text(String(localized: "自分", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruRegular(12))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                        if let mbti = card.selfMBTI {
                            Text(mbti)
                                .font(MeloFonts.zenMaruOrFallback(9))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(MeloColors.mbtiColor(for: mbti)))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundColor(MeloColors.Dark.accent)

                    VStack(spacing: 6) {
                        Text("\(partnerTotal)")
                            .font(MeloFonts.jerseyOrFallback(48))
                            .foregroundColor(MeloColors.Dark.accent)
                        Text(card.relationshipLabel ?? String(localized: "相手", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruRegular(12))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                        ForEach(card.effectivePartnerMBTIs, id: \.self) { mbti in
                            Text(mbti)
                                .font(MeloFonts.zenMaruOrFallback(9))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(MeloColors.mbtiColor(for: mbti)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MeloColors.Dark.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                        )
                )
            }

            // あなたの感情表現
            if let selfWords = card.selfLoveWords, !selfWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "あなたの感情表現", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(MeloColors.Dark.textPrimary)

                    FlowLayout(spacing: 8) {
                        ForEach(selfWords) { w in
                            HStack(spacing: 4) {
                                Text(w.phrase)
                                    .font(MeloFonts.zenMaruOrFallback(12))
                                    .foregroundColor(MeloColors.Dark.accent)
                                Text("×\(w.count)")
                                    .font(MeloFonts.zenMaruOrFallback(12))
                                    .foregroundColor(MeloColors.Dark.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(MeloColors.Dark.accent.opacity(0.18))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // 相手の感情表現
            if let partnerWords = card.partnerLoveWords, !partnerWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: String(localized: "%@の感情表現", bundle: LanguageManager.appBundle), card.relationshipLabel ?? String(localized: "相手", bundle: LanguageManager.appBundle)))
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(MeloColors.Dark.textPrimary)

                    FlowLayout(spacing: 8) {
                        ForEach(partnerWords) { w in
                            HStack(spacing: 4) {
                                Text(w.phrase)
                                    .font(MeloFonts.zenMaruOrFallback(12))
                                    .foregroundColor(MeloColors.Member.partner)
                                Text("×\(w.count)")
                                    .font(MeloFonts.zenMaruOrFallback(12))
                                    .foregroundColor(MeloColors.Dark.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(MeloColors.Member.partner.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func miniScorePill(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(MeloFonts.zenMaruRegular(9))
                .foregroundColor(MeloColors.Dark.textSecondary)
            Text(value)
                .font(MeloFonts.zenMaruOrFallback(12))
                .foregroundColor(MeloColors.Dark.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(MeloColors.Dark.bgElevated)
        )
    }

}

// MARK: - Preview

#Preview {
    BoardPostDetailView(post: BoardPost.samplePosts[1])
}
