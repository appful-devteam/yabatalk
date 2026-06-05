import SwiftUI

/// 相談部屋の投稿詳細シート (本投稿 + 返信スレッド + 返信入力)。
/// 掲示板の `BoardPostDetailView` の最小版相当を提供する:
///   - 本投稿 (CommunityPostCardV2)
///   - 自分の投稿なら削除ボタン
///   - 返信一覧 (タップで「○○さんに返信」モード)
///   - 自分の返信は長押しで削除
///   - 返信入力欄 (mention 付き返信に対応)
struct CommunityPostDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let post: CommunityRoomPost
    let isOwnPost: Bool
    let onLike: () -> Void
    let onBookmark: () -> Void
    let onReaction: (String) -> Void
    let onDelete: () -> Void

    @StateObject private var authService = BoardAuthService.shared
    @State private var replies: [BoardReply] = []
    @State private var isLoadingReplies = true
    @State private var replyText: String = ""
    @State private var replyMention: ReplyMentionInfo?
    @State private var isSendingReply = false
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteReply: BoardReply?
    @FocusState private var replyFocused: Bool

    private let repository = InMemoryCommunityRoomPostRepository.shared

    /// メンションされたコメント (`mentionedReplyId`) を親として親 → 子の順に並べたフラット配列。
    /// 子は表示時にインデント。多階層は1段にフラット化 (X風)。
    private var threadedReplies: [(reply: BoardReply, isChild: Bool)] {
        let map = Dictionary(uniqueKeysWithValues: replies.map { ($0.id, $0) })

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
        for r in replies {
            grouped[rootId(of: r), default: []].append(r)
        }

        let roots = replies.filter { reply in
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        CommunityPostCardV2(
                            post: post,
                            onLike: onLike,
                            onBookmark: onBookmark,
                            onReaction: onReaction,
                            onComment: {
                                replyFocused = true
                            },
                            onShare: {},
                            showsBottomDivider: true  // 詳細でも投稿とコメントの境界として下線を出す
                        )

                        // 投稿の削除は投稿カードの長押し (.contextMenu) 経由のみ。

                        repliesList
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                }
                .background(Color.white)
                .scrollDismissesKeyboard(.interactively)

                replyComposer
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(String(localized: "投稿", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MeloColors.Text.primary)
                    }
                }
            }
            .alert(
                String(localized: "投稿を削除しますか？", bundle: LanguageManager.appBundle),
                isPresented: $showDeleteConfirm
            ) {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text(String(localized: "削除", bundle: LanguageManager.appBundle))
                }
                Button(role: .cancel) {} label: {
                    Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                }
            } message: {
                Text(String(localized: "削除した投稿は元に戻せません。", bundle: LanguageManager.appBundle))
            }
            .alert(
                String(localized: "返信を削除しますか？", bundle: LanguageManager.appBundle),
                isPresented: Binding(
                    get: { pendingDeleteReply != nil },
                    set: { if !$0 { pendingDeleteReply = nil } }
                )
            ) {
                Button(role: .destructive) {
                    if let reply = pendingDeleteReply {
                        Task { await deleteReply(reply) }
                    }
                } label: {
                    Text(String(localized: "削除", bundle: LanguageManager.appBundle))
                }
                Button(role: .cancel) {
                    pendingDeleteReply = nil
                } label: {
                    Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                }
            }
            .task {
                await loadReplies()
            }
        }
    }

    // MARK: - Replies List

    @ViewBuilder
    private var repliesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(String(localized: "返信", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(MeloColors.Text.primary)
                Text(verbatim: "\(replies.count)")
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(MeloColors.Text.secondary)
            }

            if isLoadingReplies {
                HStack {
                    Spacer()
                    ProgressView().tint(MeloColors.Brand.pink)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if replies.isEmpty {
                Text(String(localized: "まだ返信がありません", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Text.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(threadedReplies, id: \.reply.id) { item in
                        replyRow(item.reply)
                            .padding(.leading, item.isChild ? 36 : 0)
                    }
                }
            }
        }
    }

    private func replyRow(_ reply: BoardReply) -> some View {
        let isOwn = (reply.authorId == authService.currentUser?.id)
        let anonymousName = String(localized: "匿名ユーザー", bundle: LanguageManager.appBundle)
        let isAnonymous = reply.authorDisplayName == anonymousName
        return HStack(alignment: .top, spacing: 10) {
            // アバター (匿名はペア画像、それ以外はイニシャル)
            Group {
                if isAnonymous {
                    Image(AnonymousAvatarPicker.imageName(forSeed: reply.id))
                        .resizable()
                        .scaledToFit()
                        .background(Circle().fill(MeloColors.Surface.pinkPale))
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(MeloColors.Surface.pinkPale)
                        .overlay(
                            Text(String(reply.authorDisplayName.prefix(1)))
                                .font(MeloFonts.zenMaruOrFallback(12))
                                .foregroundColor(MeloColors.Brand.pink)
                        )
                }
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(reply.authorDisplayName)
                            .font(MeloFonts.zenMaruMedium(13))
                            .foregroundColor(MeloColors.Text.primary)

                        // 投稿者本人による返信に「投稿者」ピル
                        if let pid = post.authorId, reply.authorId == pid {
                            Text(String(localized: "投稿者", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruMedium(9))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(MeloColors.Gradient.pinkPrimary))
                        }

                        if let badge = reply.authorBadge {
                            Text(badge.typeCode)
                                .font(MeloFonts.zenMaruMedium(8))
                                .foregroundColor(MeloColors.Text.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(MeloColors.mbtiColor(for: badge.typeCode).opacity(0.35))
                                )
                        }
                    }

                    Spacer()

                    Text(BoardTimeFormatter.timeAgo(reply.createdAt))
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Text.secondary)
                }

                // メンション先の表示 (掲示板と同じ位置: 名前行直下)
                if let mentionedName = reply.mentionedUserName {
                    HStack(spacing: 2) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 9))
                        Text(verbatim: "@\(mentionedName)")
                            .font(MeloFonts.zenMaruRegular(12))
                    }
                    .foregroundColor(MeloColors.Brand.pink)
                    .padding(.top, 1)
                }

                // 本文
                if !reply.content.isEmpty {
                    Text(HashtagAttributedString.make(
                        text: reply.content,
                        bodyColor: MeloColors.Text.primary,
                        hashtagColor: MeloColors.Brand.pink
                    ))
                    .font(MeloFonts.zenMaruRegular(14))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .handlesHashtagTap()
                }

                // いいね & 返信ボタン (掲示板と同じ順序: ハート → 返信)
                HStack(spacing: 16) {
                    Button {
                        HapticManager.light()
                        Task { await toggleLike(reply) }
                    } label: {
                        let liked = reply.likedByCurrentUser
                        HStack(spacing: 3) {
                            Image(systemName: liked ? "heart.fill" : "heart")
                                .font(.system(size: 13))
                                .foregroundColor(liked ? MeloColors.Brand.pink : MeloColors.Text.secondary)
                            if reply.likeCount > 0 {
                                Text(verbatim: "\(reply.likeCount)")
                                    .font(MeloFonts.zenMaruRegular(11))
                                    .foregroundColor(liked ? MeloColors.Brand.pink : MeloColors.Text.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        HapticManager.light()
                        startReplyTo(reply)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.system(size: 12))
                            Text(String(localized: "返信", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruRegular(11))
                        }
                        .foregroundColor(MeloColors.Text.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 12)
        .contextMenu {
            if isOwn {
                Button(role: .destructive) {
                    pendingDeleteReply = reply
                } label: {
                    Label(
                        String(localized: "返信を削除", bundle: LanguageManager.appBundle),
                        systemImage: "trash"
                    )
                }
            }
        }
    }

    // MARK: - Reply Composer

    private var replyComposer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // メンション中インジケータ
            if let m = replyMention {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(MeloColors.Brand.pink)
                    Text(String(format: String(localized: "%@さんへの返信", bundle: LanguageManager.appBundle), m.userName))
                        .font(MeloFonts.zenMaruMedium(11))
                        .foregroundColor(MeloColors.Brand.pink)
                    Spacer(minLength: 0)
                    Button {
                        HapticManager.light()
                        replyMention = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(MeloColors.Brand.pink.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(MeloColors.Surface.pinkPale)
            }

            HStack(spacing: 8) {
                // 自分のアバタープレースホルダー (掲示板と同じ 30×30)
                Circle()
                    .fill(MeloColors.Surface.pinkPale)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(MeloColors.Brand.pink)
                    )

                // pill 形状: スタンプ + 画像 + テキスト入力
                HStack(spacing: 6) {
                    Button {
                        HapticManager.light()
                        // TODO: スタンプピッカー実装が入ったらここにフックを置く
                    } label: {
                        Image("stamp_button")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .opacity(0.85)
                    }
                    .buttonStyle(.plain)

                    Button {
                        HapticManager.light()
                        // TODO: 画像添付の実装が入ったらここにフックを置く
                    } label: {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(MeloColors.Text.secondary)
                    }
                    .buttonStyle(.plain)

                    TextField(
                        String(localized: "返信を書く…", bundle: LanguageManager.appBundle),
                        text: $replyText
                    )
                    .font(MeloFonts.zenMaruRegular(14))
                    .foregroundColor(MeloColors.Text.primary)
                    .textFieldStyle(.plain)
                    .focused($replyFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(MeloColors.Surface.pinkPale)
                )

                // 送信ボタン (掲示板と同じ 30×30 円)
                if isSendingReply {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(MeloColors.Brand.pink)
                } else {
                    Button {
                        HapticManager.medium()
                        Task { await submitReply() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(canSend
                                      ? AnyShapeStyle(MeloColors.Gradient.pinkPrimary)
                                      : AnyShapeStyle(MeloColors.Surface.pinkPale))
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor(canSend ? .white : MeloColors.Text.secondary)
                                .offset(x: -1)
                        }
                        .frame(width: 30, height: 30)
                    }
                    .disabled(!canSend)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(MeloColors.Gray.subButtonLight)
                    .frame(height: 0.5),
                alignment: .top
            )
        }
    }

    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    /// 「返信」ボタンを押した時の処理。入力欄に `@username ` を自動挿入し、
    /// 構造化メンション (replyMention) も同時にセットする。
    private func startReplyTo(_ reply: BoardReply) {
        replyMention = ReplyMentionInfo(
            replyId: reply.id,
            userName: reply.authorDisplayName
        )
        let prefix = "@\(reply.authorDisplayName) "
        // 既に同じユーザー宛の prefix が入っていれば二重挿入しない
        if replyText.hasPrefix(prefix) {
            // no-op
        } else if replyText.isEmpty {
            replyText = prefix
        } else {
            // 既存の `@…` 先頭を一旦取り除いてから新しいメンションを挿入
            let stripped = stripLeadingMention(from: replyText)
            replyText = prefix + stripped
        }
        replyFocused = true
    }

    /// `@xxx ` で始まるテキストから、その先頭メンション部分だけを取り除く。
    /// 既存テキスト中の他の `@xxx` には影響しない。
    private func stripLeadingMention(from text: String) -> String {
        guard text.first == "@" else { return text }
        // 最初の空白までを mention とみなす
        if let spaceIndex = text.firstIndex(of: " ") {
            return String(text[text.index(after: spaceIndex)...])
        }
        return ""
    }

    private func loadReplies() async {
        isLoadingReplies = true
        let fetched = await repository.fetchReplies(roomId: post.roomId, postId: post.id)
        replies = fetched
        isLoadingReplies = false
    }

    private func submitReply() async {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSendingReply else { return }
        isSendingReply = true
        defer { isSendingReply = false }

        // 通知用: 送信前に mention 先 reply の authorId を確保
        let mentionedAuthorId: String? = {
            guard let m = replyMention else { return nil }
            return replies.first(where: { $0.id == m.replyId })?.authorId
        }()

        // 自分の匿名投稿への返信は匿名扱い (community は authorName=="匿名ユーザー" で匿名判定)
        let anonymousName = String(localized: "匿名ユーザー", bundle: LanguageManager.appBundle)
        let isOwnAnonymousPost: Bool = {
            guard let uid = authService.currentUser?.id, let aid = post.authorId else { return false }
            return uid == aid && post.authorName == anonymousName
        }()
        let actorName = isOwnAnonymousPost
            ? anonymousName
            : (authService.currentUser?.displayName ?? "")

        if let new = await repository.createReply(
            roomId: post.roomId,
            postId: post.id,
            content: trimmed,
            mention: replyMention,
            asAnonymous: isOwnAnonymousPost
        ) {
            replies.append(new)
            replyText = ""
            replyMention = nil
            replyFocused = false

            // メンションされたユーザーに通知 (自分自身/同一の場合は createMentionNotification 内でスキップ)
            if let mentionedAuthorId, !actorName.isEmpty {
                try? await BoardFirestoreService.shared.createMentionNotification(
                    mentionedUserId: mentionedAuthorId,
                    postId: post.id,
                    actorName: actorName
                )
            }
        }
    }

    private func deleteReply(_ reply: BoardReply) async {
        await repository.deleteReply(roomId: post.roomId, postId: post.id, replyId: reply.id)
        replies.removeAll { $0.id == reply.id }
        pendingDeleteReply = nil
    }

    /// 返信のいいねトグル。楽観的更新 → サーバー結果で同期。
    private func toggleLike(_ reply: BoardReply) async {
        guard let idx = replies.firstIndex(where: { $0.id == reply.id }) else { return }
        let wasLiked = replies[idx].likedByCurrentUser
        // 楽観的更新
        replies[idx].likedByCurrentUser = !wasLiked
        replies[idx].likeCount = max(0, replies[idx].likeCount + (wasLiked ? -1 : 1))
        let nowLiked = await repository.toggleReplyLike(
            roomId: post.roomId,
            postId: post.id,
            replyId: reply.id
        )
        // 結果と同期
        if let idx2 = replies.firstIndex(where: { $0.id == reply.id }) {
            replies[idx2].likedByCurrentUser = nowLiked
        }
    }
}
