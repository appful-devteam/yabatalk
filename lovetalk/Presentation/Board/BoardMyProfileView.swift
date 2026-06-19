import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Profile Content Tab（投稿 / 保存済み）
enum ProfileContentTab: String, CaseIterable, Identifiable {
    case posts
    case bookmarks

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .posts:     return String(localized: "投稿", bundle: LanguageManager.appBundle)
        case .bookmarks: return String(localized: "保存済み", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - Profile Post Filter（Figma準拠: すべて / 参加中 / 片思い / 両思い / 失恋）
enum ProfilePostFilter: String, CaseIterable, Identifiable {
    case all
    case participating
    case oneSidedLove
    case mutualLove
    case brokenHeart

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .all:            return String(localized: "すべて", bundle: LanguageManager.appBundle)
        case .participating:  return String(localized: "参加中", bundle: LanguageManager.appBundle)
        case .oneSidedLove:   return String(localized: "片思い", bundle: LanguageManager.appBundle)
        case .mutualLove:     return String(localized: "両思い", bundle: LanguageManager.appBundle)
        case .brokenHeart:    return String(localized: "失恋", bundle: LanguageManager.appBundle)
        }
    }

    /// 関係性ラベルからこのフィルタに属するか判定
    func matches(post: BoardPost) -> Bool {
        switch self {
        case .all:
            return true
        case .participating:
            // 自分が返信・投票・リアクションした投稿（= 自分の投稿のうちリプライ数が多いものを参加中とみなす）
            return post.replyCount > 0
        case .oneSidedLove:
            return post.diagnosisCard?.relationshipLabel.map { label in
                label.contains("片思い") || label.lowercased().contains("crush")
            } ?? false
        case .mutualLove:
            return post.diagnosisCard?.relationshipLabel.map { label in
                label.contains("両思い") || label.contains("彼氏") || label.contains("彼女") || label.contains("恋人") || label.lowercased().contains("mutual")
            } ?? false
        case .brokenHeart:
            return post.diagnosisCard?.relationshipLabel.map { label in
                label.contains("失恋") || label.contains("元") || label.lowercased().contains("broken")
            } ?? false
        }
    }
}

// MARK: - Board My Profile View (Tab)
/// マイページタブ — 自分のプロフィール＋投稿一覧（Figma: 559:1503）
struct BoardMyProfileView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var authService = BoardAuthService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var bookmarkService = BoardBookmarkService.shared

    @State private var profile: BoardUserProfile = .empty
    @State private var userPosts: [BoardPost] = []
    @State private var isLoading = true
    @State private var showEditProfile = false
    @State private var showFollowList = false
    @State private var followListType: FollowListType = .followers
    @State private var selectedPost: BoardPost?
    @State private var showSignIn = false
    @State private var showFollowRequests = false
    @State private var pendingRequestCount = 0
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var profileImageRefreshId = UUID()
    @State private var selectedFilter: ProfilePostFilter = .all
    @State private var selectedContentTab: ProfileContentTab = .posts
    @State private var bookmarkedPosts: [BoardPost] = []
    @State private var isLoadingBookmarks = false
    @State private var profileTarget: ProfileSheetTarget?
    @State private var loadFailed = false
    @State private var showCompose = false
    @State private var quotePost: QuotedPostInfo?
    @State private var selectedHobbyTags: [String] = []

    private let firestoreService = BoardFirestoreService.shared

    // MARK: - Figma Colors（ダーク化: 黒地 × ホットピンク accent）
    private let pinkAccent = MeloColors.Dark.accent
    private let pinkSoft = MeloColors.Dark.bgElevated
    private let pinkBG = MeloColors.Dark.bgElevated   // ヘッダー背景（一段上の面）
    private let brown = MeloColors.Dark.textPrimary
    private let brownLight = MeloColors.Dark.textSecondary
    private let borderLight = MeloColors.Dark.divider

    private var isSignedIn: Bool {
        authService.isSignedIn && !(authService.currentUser?.isAnonymous ?? true)
    }

    private var targetUserId: String {
        authService.currentUser?.id ?? ""
    }

    private var filteredPosts: [BoardPost] {
        userPosts.filter { selectedFilter.matches(post: $0) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MeloColors.Dark.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isSignedIn {
                        signInPrompt
                    } else if isLoading && !loadFailed {
                        Spacer()
                        ProgressView().tint(pinkAccent)
                        Spacer()
                    } else if loadFailed {
                        Spacer()
                        retryPrompt
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                profileSection
                                    .padding(.top, 20)

                                bioSection
                                    .padding(.top, 14)

                                statsRow
                                    .padding(.top, 14)

                                // 投稿エリアとプロフィール領域の境目:
                                // 線自体は透明 (= 白背景に溶ける)。下方向にピンクシャドウだけ落とす。
                                Rectangle()
                                    .fill(MeloColors.Dark.bg)
                                    .frame(height: 1)
                                    .shadow(color: MeloColors.Dark.accent.opacity(0.15), radius: 5, x: 0, y: 3)
                                    .padding(.top, 14)

                                contentTabSelector
                                    .padding(.top, 8)

                                // 旧 ProfilePostFilter (片思い/両思い/失恋 等) は廃止。
                                // 現行の PostTheme システムと不一致なのでフィルタ表示自体を撤去。

                                pendingRequestBanner

                                postListSection
                                    .padding(.top, 18)
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showEditProfile, onDismiss: {
                profileImageRefreshId = UUID()
                Task { await loadProfile() }
            }) {
                BoardProfileEditView(profile: $profile)
            }
            .sheet(isPresented: $showFollowList) {
                FollowListView(userId: targetUserId, listType: followListType, isOwnProfile: true)
            }
            .sheet(item: $selectedPost) { post in
                BoardPostDetailView(post: post) {
                    userPosts.removeAll { $0.id == post.id }
                }
            }
            .sheet(isPresented: $showSignIn, onDismiss: {
                if isSignedIn {
                    Task { await loadProfile() }
                }
            }) {
                BoardSignInView()
            }
            .sheet(isPresented: $showFollowRequests) {
                FollowRequestsView(userId: targetUserId) {
                    Task { await loadProfile() }
                }
            }
            .sheet(item: $profileTarget) { target in
                BoardProfileView(userId: target.userId)
            }
            .sheet(isPresented: $showCompose, onDismiss: {
                quotePost = nil
            }) {
                BoardComposeViewV2(
                    onPosted: { _ in
                        toastIsError = false
                        toastMessage = String(localized: "投稿しました！", bundle: LanguageManager.appBundle)
                        Task {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            await MainActor.run { toastMessage = nil }
                        }
                    },
                    onRequestOpenConsultRoom: {
                        coordinator.consultRoomPath = NavigationPath()
                        coordinator.selectedTab = .consultRoom
                    },
                    quotedPost: quotePost
                )
            }
            .overlay(alignment: .top) {
                if let msg = toastMessage {
                    BoardToastView(msg, icon: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill", isError: toastIsError)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 100)
                        .zIndex(999)
                }
            }
        }
        .task {
            if isSignedIn {
                await loadProfile()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { notification in
            if let tab = notification.object as? MainTab, tab == .profile {
                Task { await loadProfile() }
            }
        }
    }

    // MARK: - Header (チャット/相談部屋と統一: 115pt, padding.top 23, padding.horizontal 20)

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(String(localized: "マイページ", bundle: LanguageManager.appBundle))
                    .font(zenMaruBold(22))
                    .tracking(0.66)
                    .foregroundColor(MeloColors.Dark.textPrimary)

                Spacer()

                // Premium が rightmost ではなく、設定ボタンの左に置くスタイルだったが、
                // ホームページ (BoardFeedView) に合わせて Premium を最右に配置。
                Button {
                    HapticManager.light()
                    coordinator.showSettings()
                } label: {
                    Circle()
                        .fill(MeloColors.Dark.accentGradient)
                        .frame(width: PremiumBadgeButton.height, height: PremiumBadgeButton.height)
                        .overlay(
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MeloColors.Dark.onAccent)
                        )
                        .shadow(color: MeloColors.Dark.accent.opacity(0.15), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                PremiumBadgeButton(source: "premium_badge_profile") {
                    HapticManager.light()
                    coordinator.subscriptionSource = "premium_badge_profile"
                    coordinator.showingSubscription = true
                }
            }
            .padding(.horizontal, MeloLayout.titleHorizontalPadding)
            .padding(.top, 6)
            .padding(.bottom, 6)

            // ヘッダー下端の区切り線 (3pt フラット線)。
            Rectangle()
                .fill(MeloColors.Dark.divider)
                .frame(height: 3)
        }
        .background(
            pinkBG.ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Profile Section (avatar + name + plan pill)

    private var profileSection: some View {
        HStack(alignment: .top, spacing: 14) {
            avatarWithEditBadge
                .padding(.leading, 20)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(profile.displayName.isEmpty
                         ? String(localized: "名無し", bundle: LanguageManager.appBundle)
                         : profile.displayName)
                        .font(zenMaruBold(24))
                        .tracking(0.72)
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .lineLimit(1)

                    if profile.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MeloColors.Dark.textPrimary.opacity(0.85))
                    }

                    if subscriptionManager.isSubscribed {
                        premiumGlowIcon
                    }
                }

                tagsRow
            }
            .padding(.top, 10)
            .padding(.trailing, 20)

            Spacer(minLength: 0)
        }
    }

    /// 名前の隣に表示する、ピンクに発光する Premium アイコン (無料プランでは表示しない)。
    private var premiumGlowIcon: some View {
        ZStack {
            Image(systemName: "crown.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MeloColors.Dark.accentGradient)
                .shadow(color: MeloColors.Dark.accentBright.opacity(0.85), radius: 6, x: 0, y: 0)
                .shadow(color: MeloColors.Dark.accent.opacity(0.6), radius: 3, x: 0, y: 0)
        }
        .accessibilityLabel(Text(String(localized: "プレミアム会員", bundle: LanguageManager.appBundle)))
    }

    /// MBTI バッジ + プロフィール編集で選んだ趣味タグを横に並べる行。
    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let badge = profile.badge {
                    Text(badge.typeCode)
                        .font(MeloFonts.zenMaruOrFallback(11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(MeloColors.mbtiColor(for: badge.typeCode))
                        )
                }

                ForEach(selectedHobbyTags, id: \.self) { tag in
                    Text(tag)
                        .font(MeloFonts.zenMaruMedium(11))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(MeloColors.Dark.bgElevated)
                        )
                        .overlay(
                            Capsule().stroke(pinkAccent.opacity(0.4), lineWidth: 0.5)
                        )
                }
            }
        }
    }

    private var avatarWithEditBadge: some View {
        ZStack(alignment: .topTrailing) {
            avatarView
                .frame(width: 93, height: 91)
                .clipShape(Circle())
                .overlay(Circle().stroke(brown, lineWidth: 5))

            Button {
                HapticManager.light()
                showEditProfile = true
            } label: {
                Circle()
                    .fill(pinkSoft)
                    .frame(width: 27, height: 27)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .frame(width: 93, height: 91)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlString = profile.profileImageURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) {
                defaultAvatar
            }
            .id(profileImageRefreshId)
        } else {
            defaultAvatar
        }
    }

    private var defaultAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [pinkSoft, pinkAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(profile.displayName.isEmpty ? "?" : String(profile.displayName.prefix(1)))
                .font(zenMaruBold(36))
                .foregroundColor(.white)
        }
    }

    private var planPill: some View {
        let isPremium = subscriptionManager.isSubscribed
        let label = isPremium
            ? String(localized: "プレミアムプラン", bundle: LanguageManager.appBundle)
            : String(localized: "無料プラン", bundle: LanguageManager.appBundle)
        let color = isPremium ? pinkAccent : MeloColors.Dark.textSecondary

        return Text(label)
            .font(zenMaruBold(12))
            .foregroundColor(color)
            .frame(width: 126, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color, lineWidth: 1)
            )
    }

    // MARK: - Bio

    private var bioSection: some View {
        Group {
            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(zenMaruMedium(13))
                    .tracking(0.91)
                    .lineSpacing(13 * 0.45) // line-height 1.45
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .padding(.leading, 25)
                    .padding(.trailing, 20)
            } else {
                Button {
                    HapticManager.light()
                    showEditProfile = true
                } label: {
                    Text(String(localized: "自己紹介を書いてみよう", bundle: LanguageManager.appBundle))
                        .font(zenMaruMedium(13))
                        .foregroundColor(brownLight)
                        .italic()
                        .padding(.leading, 25)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stats Row（フォロー中 / フォロワー / 投稿数）

    private var statsRow: some View {
        HStack(spacing: 23) {
            Spacer(minLength: 0)
            Button {
                HapticManager.light()
                followListType = .following
                showFollowList = true
            } label: {
                statCell(count: profile.followingCount,
                         label: String(localized: "フォロー中", bundle: LanguageManager.appBundle))
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.light()
                followListType = .followers
                showFollowList = true
            } label: {
                statCell(count: profile.followerCount,
                         label: String(localized: "フォロワー", bundle: LanguageManager.appBundle))
            }
            .buttonStyle(.plain)

            statCell(count: profile.postCount,
                     label: String(localized: "投稿数", bundle: LanguageManager.appBundle))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(zenMaruMedium(20))
                .foregroundColor(MeloColors.Dark.textPrimary)
            Text(label)
                .font(zenMaruMedium(10))
                .foregroundColor(brownLight)
        }
        .frame(width: 63, height: 43)
    }

    // MARK: - Filter Pills（すべて / 参加中 / 片思い / 両思い / 失恋）

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(ProfilePostFilter.allCases) { filter in
                    filterPill(filter)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 20)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func filterPill(_ filter: ProfilePostFilter) -> some View {
        let isSelected = selectedFilter == filter

        Button {
            HapticManager.light()
            withAnimation(.easeOut(duration: 0.18)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                if filter == .brokenHeart {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isSelected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
                        .frame(width: 13, height: 13)
                } else if filter != .all {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isSelected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
                        .frame(width: 13, height: 13)
                }

                Text(filter.localizedName)
                    .font(isSelected ? zenMaruBlack(12) : zenMaruMedium(12))
                    .foregroundColor(isSelected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                ZStack {
                    if isSelected {
                        Capsule().fill(MeloColors.Dark.accentGradient)
                    } else {
                        Capsule().fill(MeloColors.Dark.card)
                        Capsule().stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                    }
                }
            )
            .shadow(color: isSelected ? MeloColors.Dark.accent.opacity(0.15) : Color.black.opacity(0.3),
                    radius: isSelected ? 6 : 1.9, x: 0, y: isSelected ? 2 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pending Follow Request Banner

    @ViewBuilder
    private var pendingRequestBanner: some View {
        if profile.isPrivate && pendingRequestCount > 0 {
            Button {
                showFollowRequests = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 13))
                    Text(String(localized: "フォローリクエスト", bundle: LanguageManager.appBundle))
                        .font(zenMaruMedium(13))
                    Text("\(pendingRequestCount)")
                        .font(zenMaruBold(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                }
                .foregroundColor(pinkAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(pinkAccent.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
    }

    // MARK: - Content Tab Selector（投稿 / 保存済み — 下線式インデックスタブ）

    private var contentTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ProfileContentTab.allCases) { tab in
                contentTabIndex(tab)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            // タブ全体の下端線
            VStack {
                Spacer()
                Rectangle().fill(borderLight).frame(height: 1)
            }
        )
    }

    @ViewBuilder
    private func contentTabIndex(_ tab: ProfileContentTab) -> some View {
        let isSelected = selectedContentTab == tab

        Button {
            HapticManager.light()
            withAnimation(.easeOut(duration: 0.18)) {
                selectedContentTab = tab
            }
            if tab == .bookmarks && bookmarkedPosts.isEmpty {
                Task { await loadBookmarkedPosts() }
            }
        } label: {
            VStack(spacing: 6) {
                Text(tab.localizedName)
                    .font(isSelected ? MeloFonts.zenMaruOrFallback(14) : MeloFonts.zenMaruMedium(14))
                    .tracking(0.42)
                    .foregroundStyle(isSelected
                                     ? AnyShapeStyle(MeloColors.Dark.accentGradient)
                                     : AnyShapeStyle(MeloColors.Dark.textSecondary))
                    .frame(height: 22)

                // 選択中だけピンクのインジケータ線。非選択は透明線で高さを揃える。
                Rectangle()
                    .fill(isSelected
                          ? AnyShapeStyle(MeloColors.Dark.accentGradient)
                          : AnyShapeStyle(Color.clear))
                    .frame(height: 2.5)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Post List / Empty State

    @ViewBuilder
    private var postListSection: some View {
        switch selectedContentTab {
        case .posts:
            postsListContent
        case .bookmarks:
            bookmarksListContent
        }
    }

    @ViewBuilder
    private var postsListContent: some View {
        if filteredPosts.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 0) {
                ForEach(filteredPosts) { post in
                    VStack(alignment: .leading, spacing: 6) {
                        if let repostName = post.repostedByDisplayName, !repostName.isEmpty {
                            repostHeaderRow(displayName: repostName)
                                .padding(.horizontal, MeloLayout.boardPostHorizontalPadding)
                                .padding(.top, 8)
                        }
                        BoardFeedPostCard(
                            post: post,
                            horizontalPadding: MeloLayout.boardPostHorizontalPadding
                        ) {
                            selectedPost = post
                        } onAuthorTap: { authorId in
                            profileTarget = ProfileSheetTarget(userId: authorId)
                        } onQuote: { quote in
                            quotePost = quote
                            showCompose = true
                        } onRequireSignIn: {
                            showSignIn = true
                        }
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    /// マイページのタイムラインで、リポストした投稿の上に表示する小さなヘッダー（Twitter風）。
    private func repostHeaderRow(displayName: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(MeloColors.Dark.textSecondary)
            Text(String(format: String(localized: "%@さんがリポスト", bundle: LanguageManager.appBundle), displayName))
                .font(MeloFonts.zenMaruMedium(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
            Spacer()
        }
        .padding(.leading, 8)
    }

    @ViewBuilder
    private var bookmarksListContent: some View {
        if isLoadingBookmarks {
            VStack {
                ProgressView().tint(pinkAccent)
                    .padding(.vertical, 40)
            }
            .frame(maxWidth: .infinity)
        } else if bookmarkedPosts.isEmpty {
            bookmarksEmptyState
        } else {
            LazyVStack(spacing: 0) {
                ForEach(bookmarkedPosts) { post in
                    BoardFeedPostCard(
                        post: post,
                        horizontalPadding: MeloLayout.boardPostHorizontalPadding
                    ) {
                        selectedPost = post
                    } onAuthorTap: { authorId in
                        profileTarget = ProfileSheetTarget(userId: authorId)
                    } onQuote: { quote in
                        quotePost = quote
                        showCompose = true
                    } onRequireSignIn: {
                        showSignIn = true
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("mero_pair_07")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            Text(String(localized: "1つ目の投稿をしてみよ！", bundle: LanguageManager.appBundle))
                .font(zenMaruMedium(12))
                .foregroundColor(brownLight)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var bookmarksEmptyState: some View {
        VStack(spacing: 16) {
            Image("mero_pair_09")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            Text(String(localized: "まだ保存済みの投稿はありません", bundle: LanguageManager.appBundle))
                .font(zenMaruMedium(12))
                .tracking(0.36)
                .foregroundColor(brownLight)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Retry / Sign In prompts

    private var retryPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(brownLight)

            Text(String(localized: "読み込みに失敗しました", bundle: LanguageManager.appBundle))
                .font(zenMaruMedium(15))
                .foregroundColor(MeloColors.Dark.textPrimary)

            Button {
                loadFailed = false
                Task { await loadProfile() }
            } label: {
                Text(String(localized: "再読み込み", bundle: LanguageManager.appBundle))
                    .font(zenMaruBold(14))
                    .foregroundColor(MeloColors.Dark.onAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(pinkAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private var signInPrompt: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            Image(systemName: "person.crop.circle")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [pinkSoft, pinkAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(String(localized: "マイページを使うには\nサインインが必要です", bundle: LanguageManager.appBundle))
                .font(zenMaruMedium(16))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .multilineTextAlignment(.center)

            Button {
                showSignIn = true
            } label: {
                Text(String(localized: "サインイン", bundle: LanguageManager.appBundle))
                    .font(zenMaruBold(14))
                    .foregroundColor(MeloColors.Dark.onAccent)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(pinkAccent))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Data Loading

    private func loadProfile() async {
        guard isSignedIn else { return }
        let isFirstLoad = userPosts.isEmpty && profile.displayName.isEmpty
        isLoading = isFirstLoad
        loadFailed = false

        // プロフィール編集で選択された趣味タグを UserDefaults から読み込む
        let userId = targetUserId
        let selectionKey = "board.profile.hobbies.selected.\(userId)"
        selectedHobbyTags = UserDefaults.standard.stringArray(forKey: selectionKey) ?? []

        // プロフィール / 自分の投稿 / リポスト を並列起動
        // (元実装は逐次で 4-5 ラウンドトリップ。並列化で 1 ラウンドトリップ相当に短縮)
        async let ownPostsResult: [BoardPost] = {
            (try? await firestoreService.getUserPosts(userId: userId, includeAnonymous: true)) ?? []
        }()
        async let repostsResult: [(post: BoardPost, repostedAt: Date)] = {
            (try? await firestoreService.getUserReposts(userId: userId)) ?? []
        }()

        // プロフィール取得は 10 秒タイムアウト付き (Firestore がオフラインで止まった時の保険)
        let loaded: BoardUserProfile?
        do {
            loaded = try await withThrowingTaskGroup(of: BoardUserProfile?.self) { group in
                group.addTask { [firestoreService] in
                    try await firestoreService.getProfile(userId: userId)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    throw CancellationError()
                }
                let result = try await group.next() ?? nil
                group.cancelAll()
                return result
            }
        } catch {
            print("[BoardMyProfile] Profile load error: \(error)")
            loaded = nil
        }

        guard let loadedProfile = loaded else {
            if isFirstLoad {
                loadFailed = true
                isLoading = false
            }
            // async let は scope 外で暗黙キャンセルされるが、明示的に await して構造化する
            _ = await ownPostsResult
            _ = await repostsResult
            return
        }

        // プロフィール本体が届いた瞬間に上部 UI を表示 (投稿の取得完了は待たない)
        profile = loadedProfile
        if isFirstLoad { isLoading = false }

        // 非公開アカウントのみフォローリクエスト数を後追い取得 (UI 表示はブロックしない)
        if loadedProfile.isPrivate {
            Task {
                let count = (try? await firestoreService.fetchPendingFollowRequestCount(userId: userId)) ?? 0
                await MainActor.run { pendingRequestCount = count }
            }
        }

        let ownPosts = await ownPostsResult
        let reposts = await repostsResult

        profile.postCount = ownPosts.count

        // 自分のリポスト（他人 or 自分の投稿に対する 🔁）
        let myDisplayName = profile.displayName.isEmpty
            ? (BoardAuthService.shared.currentUser?.displayName ?? "")
            : profile.displayName
        let repostMarked: [BoardPost] = reposts.map { entry in
            var p = entry.post
            p.repostedByDisplayName = myDisplayName
            // タイムライン上のソート用に「リポスト時刻」を仮想 createdAt として上書き
            p.createdAt = entry.repostedAt
            return p
        }

        // 同一投稿（自分の投稿を自分でリポスト）の重複は元投稿を優先
        let ownIds = Set(ownPosts.map { $0.id })
        let merged = ownPosts + repostMarked.filter { !ownIds.contains($0.id) }
        userPosts = merged.sorted { $0.createdAt > $1.createdAt }

        // 保存済みタブが選択中なら再取得
        if selectedContentTab == .bookmarks {
            await loadBookmarkedPosts()
        }
    }

    /// ブックマーク済み投稿を ID から個別フェッチして時系列に並べる
    private func loadBookmarkedPosts() async {
        isLoadingBookmarks = true
        let ids = Array(bookmarkService.bookmarkedPostIds)

        // 元実装は serial loop で N 件分のラウンドトリップ。並列フェッチに変更。
        var loaded: [BoardPost] = await withTaskGroup(of: BoardPost?.self) { group in
            for id in ids {
                group.addTask { [firestoreService] in
                    try? await firestoreService.fetchPost(postId: id)
                }
            }
            var result: [BoardPost] = []
            for await post in group {
                if let post { result.append(post) }
            }
            return result
        }
        loaded.sort { $0.createdAt > $1.createdAt }
        withAnimation(.easeOut(duration: 0.25)) {
            bookmarkedPosts = loaded
            isLoadingBookmarks = false
        }
    }

    // MARK: - Font helpers

    private func zenMaruBold(_ size: CGFloat) -> Font {
        MeloFonts.zenMaruOrFallback(size)
    }
    private func zenMaruMedium(_ size: CGFloat) -> Font {
        MeloFonts.zenMaruMedium(size)
    }
    private func zenMaruBlack(_ size: CGFloat) -> Font {
        // Zen Maru は Black が無いので Bold を代替（重み感を強調）
        MeloFonts.zenMaruOrFallback(size)
    }
}
