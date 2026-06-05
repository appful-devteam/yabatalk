import SwiftUI
import SwiftData
import PhotosUI
import AuthenticationServices

// MARK: - Board Profile View
struct BoardProfileView: View {
    let userId: String?  // nil = 自分のプロフィール

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = BoardAuthService.shared
    @State private var profile: BoardUserProfile = .empty
    @State private var userPosts: [BoardPost] = []
    @State private var isLoading = true
    @State private var followState: FollowState = .notFollowing
    @State private var isFollowLoading = false
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
    @State private var profileTarget: ProfileSheetTarget?

    private let firestoreService = BoardFirestoreService.shared

    // MARK: - Figma palette (aligned with NewHomeView / BoardMyProfileView)
    private let pinkAccent = MeloColors.Brand.pink
    private let pinkBrand = MeloColors.Brand.pink
    private let pinkSoft = MeloColors.Surface.pinkPale
    private let pinkBG = Color.white
    private let brown = MeloColors.Text.primary
    private let brownLight = MeloColors.Gray.subButton
    private let borderLight = MeloColors.Gray.subButtonLight
    private let textDark = MeloColors.Text.primary

    private var isOwnProfile: Bool {
        guard let currentId = authService.currentUser?.id else { return false }
        return userId == nil || userId == currentId
    }

    /// 非公開アカウント＆フォロワーでない場合、コンテンツを制限
    private var isPrivateAndNotFollower: Bool {
        !isOwnProfile && profile.isPrivate && followState != .following
    }

    private var targetUserId: String {
        userId ?? authService.currentUser?.id ?? ""
    }

    init(userId: String? = nil) {
        self.userId = userId
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if isLoading {
                        Spacer()
                        ProgressView().tint(pinkAccent)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                profileSection
                                    .padding(.top, 18)

                                bioSection
                                    .padding(.top, 8)

                                statsRow
                                    .padding(.top, 10)

                                actionButtons
                                    .padding(.top, 14)

                                postsSection
                                    .padding(.top, 18)
                            }
                            .padding(.bottom, 60)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showEditProfile, onDismiss: {
                // プロフィール画像のキャッシュを無効化して再読み込み
                profileImageRefreshId = UUID()
            }) {
                BoardProfileEditView(profile: $profile)
            }
            .sheet(isPresented: $showFollowList) {
                FollowListView(userId: targetUserId, listType: followListType, isOwnProfile: isOwnProfile)
            }
            .sheet(item: $selectedPost) { post in
                BoardPostDetailView(post: post) {
                    userPosts.removeAll { $0.id == post.id }
                }
            }
            .sheet(isPresented: $showSignIn) {
                BoardSignInView()
            }
            .sheet(isPresented: $showFollowRequests) {
                FollowRequestsView(userId: targetUserId) {
                    // リクエスト承認後にカウントを更新
                    Task { await loadProfile() }
                }
            }
            .sheet(item: $profileTarget) { target in
                BoardProfileView(userId: target.userId)
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
        .task {
            await loadProfile()
        }
    }

    // MARK: - Header (compact 48pt, white bg, chevron-back + optional edit)

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                // 左: 戻る
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(pinkAccent)
                        )
                        .overlay(
                            Circle().stroke(pinkAccent, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                // 中央: 名前（簡易表示、空ならタイトル）
                Text(profile.displayName.isEmpty
                     ? String(localized: "プロフィール", bundle: LanguageManager.appBundle)
                     : profile.displayName)
                    .font(MeloFonts.zenMaruOrFallback(22))
                    .tracking(0.66)
                    .foregroundColor(MeloColors.Text.primary)
                    .lineLimit(1)

                Spacer()

                // 右: 自分のプロフィールならedit、他人なら空スペーサー（将来 ... menu 用）
                if isOwnProfile {
                    Button {
                        HapticManager.light()
                        showEditProfile = true
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(pinkAccent)
                            )
                            .overlay(
                                Circle().stroke(pinkAccent, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    // 対称性のための空スペース（chevron-back と同じサイズ）
                    Color.clear
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Rectangle()
                .fill(borderLight)
                .frame(height: 1)
        }
        .frame(height: 48)
        .background(
            pinkBG.ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Profile Section (avatar + name + MBTI)

    private var profileSection: some View {
        HStack(alignment: .top, spacing: 14) {
            avatarView
                .frame(width: 93, height: 91)
                .clipShape(Circle())
                .overlay(Circle().stroke(brown, lineWidth: 5))
                .padding(.leading, 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if profile.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(MeloColors.Text.primary.opacity(0.7))
                    }
                    Text(profile.displayName.isEmpty
                         ? String(localized: "名無し", bundle: LanguageManager.appBundle)
                         : profile.displayName)
                        .font(MeloFonts.zenMaruOrFallback(24))
                        .tracking(0.72)
                        .foregroundColor(MeloColors.Text.primary)
                        .lineLimit(1)
                }

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
            }
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
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
                .font(MeloFonts.zenMaruOrFallback(36))
                .foregroundColor(.white)
        }
    }

    // MARK: - Bio Section

    private var bioSection: some View {
        Group {
            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(MeloFonts.zenMaruMedium(13))
                    .tracking(0.91)
                    .lineSpacing(13 * 0.45)
                    .foregroundColor(MeloColors.Text.primary)
                    .padding(.leading, 25)
                    .padding(.trailing, 20)
            } else if isOwnProfile {
                Button {
                    HapticManager.light()
                    showEditProfile = true
                } label: {
                    Text(String(localized: "自己紹介を書いてみよう", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(brownLight)
                        .italic()
                        .padding(.leading, 25)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stats Row（投稿 / フォロワー / フォロー中）

    private var statsRow: some View {
        HStack(spacing: 23) {
            Spacer(minLength: 0)

            statCell(count: isPrivateAndNotFollower ? nil : profile.postCount,
                     label: String(localized: "投稿", bundle: LanguageManager.appBundle))

            Button {
                guard !isPrivateAndNotFollower else { return }
                HapticManager.light()
                followListType = .followers
                showFollowList = true
            } label: {
                statCell(count: isPrivateAndNotFollower ? nil : profile.followerCount,
                         label: String(localized: "フォロワー", bundle: LanguageManager.appBundle))
            }
            .buttonStyle(.plain)
            .disabled(isPrivateAndNotFollower)

            Button {
                guard !isPrivateAndNotFollower else { return }
                HapticManager.light()
                followListType = .following
                showFollowList = true
            } label: {
                statCell(count: isPrivateAndNotFollower ? nil : profile.followingCount,
                         label: String(localized: "フォロー中", bundle: LanguageManager.appBundle))
            }
            .buttonStyle(.plain)
            .disabled(isPrivateAndNotFollower)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(count: Int?, label: String) -> some View {
        VStack(spacing: 2) {
            Text(count.map { "\($0)" } ?? "-")
                .font(MeloFonts.zenMaruMedium(20))
                .foregroundColor(MeloColors.Text.primary)
            Text(label)
                .font(MeloFonts.zenMaruMedium(10))
                .foregroundColor(brownLight)
        }
        .frame(width: 68, height: 43)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        Group {
            if isOwnProfile {
                VStack(spacing: 8) {
                    Button {
                        HapticManager.light()
                        showEditProfile = true
                    } label: {
                        Text(String(localized: "プロフィールを編集", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(13))
                            .foregroundColor(pinkAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(pinkAccent, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // フォローリクエスト（非公開アカウントのみ）
                    if profile.isPrivate && pendingRequestCount > 0 {
                        Button {
                            showFollowRequests = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.clock")
                                    .font(.system(size: 13))
                                Text(String(localized: "フォローリクエスト", bundle: LanguageManager.appBundle))
                                    .font(MeloFonts.zenMaruMedium(13))
                                Text("\(pendingRequestCount)")
                                    .font(MeloFonts.zenMaruOrFallback(12))
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
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(pinkAccent.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            } else {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    HStack(spacing: 6) {
                        if isFollowLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(followState == .notFollowing ? .white : MeloColors.Text.primary)
                        }
                        Text(followButtonLabel)
                            .font(MeloFonts.zenMaruMedium(14))
                    }
                    .foregroundColor(followState == .notFollowing ? .white : MeloColors.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(followState == .notFollowing ? pinkAccent : Color.white)
                    )
                    .overlay(
                        followState != .notFollowing
                        ? RoundedRectangle(cornerRadius: 10).stroke(pinkAccent, lineWidth: 1)
                        : nil
                    )
                }
                .buttonStyle(.plain)
                .disabled(isFollowLoading)
                .padding(.horizontal, 20)
            }
        }
    }

    private var followButtonLabel: String {
        switch followState {
        case .notFollowing:
            return profile.isPrivate
                ? String(localized: "フォローリクエスト", bundle: LanguageManager.appBundle)
                : String(localized: "フォローする", bundle: LanguageManager.appBundle)
        case .requested:
            return String(localized: "リクエスト済み", bundle: LanguageManager.appBundle)
        case .following:
            return String(localized: "フォロー中", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - Posts Section

    @ViewBuilder
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "投稿", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(15))
                .foregroundColor(MeloColors.Text.primary)
                .padding(.horizontal, 20)

            // 非公開アカウント＆フォロワーでない場合
            if isPrivateAndNotFollower {
                VStack(spacing: 12) {
                    Image("char_meromaru_3d")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 144, height: 115)
                    Text(String(localized: "非公開アカウントです", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(MeloColors.Text.primary)
                    Text(String(localized: "フォロワーだけが投稿を見れます", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(12))
                        .foregroundColor(brownLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if userPosts.isEmpty {
                VStack(spacing: 12) {
                    Image("char_meromaru_3d")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 144, height: 115)
                    Text(String(localized: "まだ投稿がありません", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(12))
                        .foregroundColor(brownLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(userPosts) { post in
                        BoardFeedPostCard(post: post, horizontalPadding: MeloLayout.boardPostHorizontalPadding) {
                            selectedPost = post
                        } onAuthorTap: { authorId in
                            profileTarget = ProfileSheetTarget(userId: authorId)
                        } onRequireSignIn: {
                            showSignIn = true
                        }
                    }
                }
            }
        }
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
        isLoading = true
        do {
            profile = try await firestoreService.getProfile(userId: targetUserId)

            if !isOwnProfile, let currentId = authService.currentUser?.id {
                followState = try await firestoreService.getFollowState(
                    currentUserId: currentId,
                    targetUserId: targetUserId
                )
            }

            // 自分のプロフィールの場合、保留中リクエスト数を取得
            if isOwnProfile && profile.isPrivate {
                pendingRequestCount = (try? await firestoreService.fetchPendingFollowRequestCount(userId: targetUserId)) ?? 0
            }
        } catch {
            print("[BoardProfile] Load error: \(error)")
            showToast(String(localized: "プロフィールの読み込みに失敗しました", bundle: LanguageManager.appBundle), isError: true)
        }

        // 非公開アカウント＆フォロワーでない場合は投稿を取得しない
        if !isOwnProfile && profile.isPrivate && followState != .following {
            isLoading = false
            return
        }

        // 投稿の取得は別途（composite indexエラーでプロフィール全体が失敗するのを防ぐ）
        do {
            userPosts = try await firestoreService.getUserPosts(userId: targetUserId)
            profile.postCount = userPosts.count
        } catch {
            print("[BoardProfile] Posts load error: \(error)")
        }

        isLoading = false
    }

    private func toggleFollow() async {
        guard let currentId = authService.currentUser?.id else { return }
        guard authService.hasRealAccount else {
            showSignIn = true
            return
        }
        isFollowLoading = true
        do {
            switch followState {
            case .following:
                // フォロー解除
                try await firestoreService.unfollowUser(
                    currentUserId: currentId,
                    targetUserId: targetUserId
                )
                followState = .notFollowing
                profile.followerCount = max(0, profile.followerCount - 1)

            case .requested:
                // リクエスト取り消し
                try await firestoreService.cancelFollowRequest(
                    currentUserId: currentId,
                    targetUserId: targetUserId
                )
                followState = .notFollowing

            case .notFollowing:
                if profile.isPrivate {
                    // 非公開アカウント → リクエスト送信
                    try await firestoreService.sendFollowRequest(
                        currentUserId: currentId,
                        targetUserId: targetUserId
                    )
                    followState = .requested

                    // リクエスト通知
                    let requesterName = authService.currentUser?.displayName ?? "ユーザー"
                    try? await firestoreService.createFollowRequestNotification(
                        targetUserId: targetUserId,
                        requesterName: requesterName
                    )
                } else {
                    // 公開アカウント → 即フォロー
                    try await firestoreService.followUser(
                        currentUserId: currentId,
                        targetUserId: targetUserId,
                        targetProfile: profile
                    )
                    followState = .following
                    profile.followerCount += 1

                    // フォロー通知
                    let followerName = authService.currentUser?.displayName ?? "ユーザー"
                    try? await firestoreService.createFollowNotification(
                        targetUserId: targetUserId,
                        followerName: followerName
                    )
                }
            }
            HapticManager.success()
        } catch {
            print("[BoardProfile] Follow error: \(error)")
            HapticManager.error()
            showToast(String(localized: "フォローに失敗しました", bundle: LanguageManager.appBundle), isError: true)
        }
        isFollowLoading = false
    }
}

// MARK: - Follow List Type
enum FollowListType: String {
    case followers
    case following

    var localizedTitle: String {
        switch self {
        case .followers: return String(localized: "フォロワー", bundle: LanguageManager.appBundle)
        case .following: return String(localized: "フォロー中", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - Follow List View
struct FollowListView: View {
    let userId: String
    let listType: FollowListType
    var isOwnProfile: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var users: [FollowRelationship] = []
    @State private var isLoading = true
    @State private var showRemoveConfirm: FollowRelationship?
    @State private var profileTarget: ProfileSheetTarget?

    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                BoardColors.bgBottom.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(BoardColors.accent)
                } else if users.isEmpty {
                    VStack(spacing: 8) {
                        Image("mero_pair_10")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 130, height: 130)
                        Text(listType == .followers
                             ? String(localized: "フォロワーはまだいません", bundle: LanguageManager.appBundle)
                             : String(localized: "フォロー中のユーザーはいません", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(13))
                            .foregroundColor(BoardColors.textTertiary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(users) { user in
                                Button {
                                    HapticManager.light()
                                    profileTarget = ProfileSheetTarget(userId: user.id)
                                } label: {
                                    followRow(user)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if isOwnProfile && listType == .followers {
                                        Button(role: .destructive) {
                                            showRemoveConfirm = user
                                        } label: {
                                            Label(String(localized: "フォロワーを削除", bundle: LanguageManager.appBundle), systemImage: "person.badge.minus")
                                        }
                                    }
                                }
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .alert(
                        String(localized: "フォロワーを削除", bundle: LanguageManager.appBundle),
                        isPresented: Binding(
                            get: { showRemoveConfirm != nil },
                            set: { if !$0 { showRemoveConfirm = nil } }
                        )
                    ) {
                        Button(String(localized: "削除", bundle: LanguageManager.appBundle), role: .destructive) {
                            if let user = showRemoveConfirm {
                                Task {
                                    try? await firestoreService.removeFollower(currentUserId: userId, followerId: user.id)
                                    users.removeAll { $0.id == user.id }
                                }
                            }
                        }
                        Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
                    } message: {
                        Text(String(localized: "このユーザーをフォロワーから削除しますか？", bundle: LanguageManager.appBundle))
                    }
                }
            }
            .navigationTitle(listType.localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BoardColors.textSecondary)
                    }
                }
            }
        }
        .task {
            await loadList()
        }
        .sheet(item: $profileTarget) { target in
            BoardProfileView(userId: target.userId)
        }
    }

    private func followRow(_ user: FollowRelationship) -> some View {
        HStack(spacing: 12) {
            // アバター
            if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) {
                    followAvatarPlaceholder(name: user.displayName)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                followAvatarPlaceholder(name: user.displayName)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(BoardColors.textPrimary)

                if let badge = user.badge {
                    Text(badge.typeCode)
                        .font(MeloFonts.zenMaruOrFallback(10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(MeloColors.mbtiColor(for: badge.typeCode))
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func followAvatarPlaceholder(name: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [BoardColors.accentLight.opacity(0.5), BoardColors.accent.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(MeloFonts.zenMaruOrFallback(16))
                    .foregroundColor(.white)
            )
    }

    private func loadList() async {
        isLoading = true
        do {
            switch listType {
            case .followers:
                users = try await firestoreService.getFollowers(userId: userId)
            case .following:
                users = try await firestoreService.getFollowing(userId: userId)
            }
        } catch {
            print("[FollowList] Load error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Follow Requests View
/// フォローリクエスト管理画面
struct FollowRequestsView: View {
    let userId: String
    var onChanged: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var requests: [FollowRequest] = []
    @State private var isLoading = true

    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                BoardColors.bgBottom.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(BoardColors.accent)
                } else if requests.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.clock")
                            .font(.system(size: 28))
                            .foregroundColor(BoardColors.textTertiary.opacity(0.5))
                        Text(String(localized: "リクエストはありません", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(13))
                            .foregroundColor(BoardColors.textTertiary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(requests) { request in
                                requestRow(request)
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "フォローリクエスト", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BoardColors.textSecondary)
                    }
                }
            }
        }
        .task {
            await loadRequests()
        }
    }

    private func requestRow(_ request: FollowRequest) -> some View {
        HStack(spacing: 12) {
            // アバター
            if let urlString = request.requesterProfileImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) {
                    requestAvatarPlaceholder(name: request.requesterDisplayName)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                requestAvatarPlaceholder(name: request.requesterDisplayName)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.requesterDisplayName)
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(BoardColors.textPrimary)

                if let badge = request.requesterBadge {
                    Text(badge.typeCode)
                        .font(MeloFonts.zenMaruOrFallback(10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(MeloColors.mbtiColor(for: badge.typeCode))
                        )
                }
            }

            Spacer()

            // 承認・拒否ボタン
            HStack(spacing: 8) {
                Button {
                    Task { await acceptRequest(request) }
                } label: {
                    Text(String(localized: "承認", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(BoardColors.accent))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await rejectRequest(request) }
                } label: {
                    Text(String(localized: "拒否", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(12))
                        .foregroundColor(BoardColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(BoardColors.divider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func requestAvatarPlaceholder(name: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [BoardColors.accentLight.opacity(0.5), BoardColors.accent.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(MeloFonts.zenMaruOrFallback(16))
                    .foregroundColor(.white)
            )
    }

    private func loadRequests() async {
        isLoading = true
        do {
            requests = try await firestoreService.fetchPendingFollowRequests(userId: userId)
        } catch {
            print("[FollowRequests] Load error: \(error)")
        }
        isLoading = false
    }

    private func acceptRequest(_ request: FollowRequest) async {
        do {
            try await firestoreService.acceptFollowRequest(currentUserId: userId, requesterId: request.requesterId)
            requests.removeAll { $0.id == request.id }
            onChanged?()
            HapticManager.success()
        } catch {
            print("[FollowRequests] Accept error: \(error)")
            HapticManager.error()
        }
    }

    private func rejectRequest(_ request: FollowRequest) async {
        do {
            try await firestoreService.rejectFollowRequest(currentUserId: userId, requesterId: request.requesterId)
            requests.removeAll { $0.id == request.id }
            HapticManager.success()
        } catch {
            print("[FollowRequests] Reject error: \(error)")
            HapticManager.error()
        }
    }
}

// MARK: - Profile Edit View (Figma 559:1919 準拠)
struct BoardProfileEditView: View {
    @Binding var profile: BoardUserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = BoardAuthService.shared

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var birthday: Date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    @State private var hasBirthday: Bool = false
    @State private var showBirthdayPicker: Bool = false

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isSaving = false
    @State private var selectedBadge: LoveTypeBadge?
    @State private var showBadgePicker = false
    @State private var isPrivate: Bool = false

    @State private var hobbyTags: [String] = []
    @State private var selectedHobbies: Set<String> = []
    @State private var showAddHobbySheet: Bool = false
    @State private var newHobbyText: String = ""

    @FocusState private var focusedField: EditField?

    private let firestoreService = BoardFirestoreService.shared

    enum EditField { case name, bio, hobby }

    // MARK: - Figma colors
    private let pinkAccent = MeloColors.Brand.pink
    private let pinkSoft = MeloColors.Surface.pinkPale
    private let pinkBG = MeloColors.Surface.pinkPale
    private let brown = MeloColors.Text.primary
    private let brownLight = MeloColors.Gray.subButton
    private let borderLight = MeloColors.Gray.subButtonLight

    private static let defaultHobbyTags: [String] = [
        "映画", "音楽", "読書", "旅行", "カフェ", "ゲーム",
        "料理", "スポーツ", "写真", "アート", "ファッション", "K-POP"
    ]

    private var birthdayStorageKey: String {
        "board.profile.birthday.\(authService.currentUser?.id ?? "anon")"
    }
    private var hobbyStorageKey: String {
        "board.profile.hobbies.\(authService.currentUser?.id ?? "anon")"
    }
    private var hobbySelectionKey: String {
        "board.profile.hobbies.selected.\(authService.currentUser?.id ?? "anon")"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    editHeader

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 21) {
                            avatarPicker
                                .padding(.top, 20)

                            fieldSection(title: String(localized: "ユーザー名", bundle: LanguageManager.appBundle)) {
                                roundedTextField(
                                    placeholder: String(localized: "ニックネーム", bundle: LanguageManager.appBundle),
                                    text: $displayName,
                                    focus: .name
                                )
                            }

                            fieldSection(title: String(localized: "誕生日", bundle: LanguageManager.appBundle)) {
                                birthdayField
                            }

                            fieldSection(title: String(localized: "紹介", bundle: LanguageManager.appBundle)) {
                                bioEditor
                            }

                            fieldSection(title: String(localized: "趣味タグ", bundle: LanguageManager.appBundle)) {
                                hobbyTagBox
                            }

                            mbtiRow

                            privacyRow

                            if let user = authService.currentUser, !user.isAnonymous {
                                signOutButton
                            }

                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, 40)
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showBadgePicker) {
                MBTIPickerView(selectedBadge: $selectedBadge)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showAddHobbySheet) {
                addHobbySheet
                    .presentationDetents([.height(240)])
            }
        }
        .onAppear {
            displayName = profile.displayName
            bio = profile.bio
            selectedBadge = profile.badge
            isPrivate = profile.isPrivate
            loadLocalExtras()
        }
        .onChange(of: selectedPhoto) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    profileImage = uiImage
                }
            }
        }
    }

    // MARK: - Header（上: 戻る + タイトル + 完了）

    private var editHeader: some View {
        ZStack(alignment: .bottom) {
            pinkBG

            HStack(alignment: .center) {
                Button {
                    dismiss()
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(MeloColors.Text.primary)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(String(localized: "プロフィール編集", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(22))
                    .tracking(0.66)
                    .foregroundColor(MeloColors.Text.primary)

                Spacer()

                Button {
                    Task { await saveProfile() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(pinkAccent))
                    } else {
                        Circle()
                            .fill(pinkAccent)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 14)

            Rectangle()
                .fill(borderLight)
                .frame(height: 1)
        }
        .frame(height: 96)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Avatar Picker（円形 104x104、5pt 黒border）

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if let urlString = profile.profileImageURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) {
                            editAvatarPlaceholder
                        }
                    } else {
                        editAvatarPlaceholder
                    }
                }
                .frame(width: 104, height: 104)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 5))

                Circle()
                    .fill(pinkAccent)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var editAvatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [pinkSoft, pinkAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(displayName.isEmpty ? "?" : String(displayName.prefix(1)))
                .font(MeloFonts.zenMaruOrFallback(40))
                .foregroundColor(.white)
        }
    }

    // MARK: - Generic field section

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MeloFonts.zenMaruOrFallback(16))
                .foregroundColor(MeloColors.Text.primary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roundedTextField(placeholder: String, text: Binding<String>, focus: EditField) -> some View {
        TextField(placeholder, text: text)
            .font(MeloFonts.zenMaruMedium(15))
            .foregroundColor(MeloColors.Text.primary)
            .focused($focusedField, equals: focus)
            .padding(.horizontal, 20)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(brown, lineWidth: 1)
            )
    }

    // MARK: - Birthday Field

    private var birthdayField: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showBirthdayPicker.toggle()
                HapticManager.light()
            } label: {
                HStack {
                    Text(hasBirthday ? birthdayFormatter.string(from: birthday) : String(localized: "選択してください", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(15))
                        .foregroundColor(hasBirthday ? MeloColors.Text.primary : brownLight)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(MeloColors.Text.primary)
                }
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(brown, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if showBirthdayPicker {
                VStack(spacing: 8) {
                    DatePicker(
                        "",
                        selection: $birthday,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)
                    .clipped()
                    .environment(\.locale, LanguageManager.shared.locale)
                    .onChange(of: birthday) { _ in
                        hasBirthday = true
                    }

                    Button {
                        hasBirthday = true
                        showBirthdayPicker = false
                    } label: {
                        Text(String(localized: "完了", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(pinkAccent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(brown, lineWidth: 1)
                )
                .padding(.top, 12)
            }
        }
    }

    private var birthdayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = LanguageManager.shared.locale
        f.dateStyle = .long
        return f
    }

    // MARK: - Bio Editor（160pt textarea、角丸15、border 1pt #716463）

    private var bioEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: 15)
                .stroke(brown, lineWidth: 1)

            if bio.isEmpty {
                Text(String(localized: "自己紹介", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(15))
                    .foregroundColor(brownLight)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $bio)
                .font(MeloFonts.zenMaruMedium(15))
                .foregroundColor(MeloColors.Text.primary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .focused($focusedField, equals: .bio)
                .onChange(of: bio) { newValue in
                    if newValue.count > 150 {
                        bio = String(newValue.prefix(150))
                    }
                }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(bio.count)/150")
                        .font(MeloFonts.zenMaruRegular(10))
                        .foregroundColor(brownLight)
                        .padding(8)
                }
            }
        }
        .frame(height: 160)
    }

    // MARK: - Hobby Tag Box

    private var hobbyTagBox: some View {
        ScrollView(showsIndicators: false) {
            FlowLayout(spacing: 8) {
                ForEach(tagItemsWithCreate(), id: \.self) { item in
                    hobbyPill(item)
                }
            }
            .padding(10)
        }
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(brown, lineWidth: 1)
        )
    }

    private func tagItemsWithCreate() -> [HobbyTagItem] {
        var items: [HobbyTagItem] = [.create]
        for tag in hobbyTags {
            items.append(.tag(tag))
        }
        return items
    }

    @ViewBuilder
    private func hobbyPill(_ item: HobbyTagItem) -> some View {
        switch item {
        case .create:
            Button {
                newHobbyText = ""
                showAddHobbySheet = true
                HapticManager.light()
            } label: {
                Text("+ " + String(localized: "趣味タグをつくる", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Text.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(brownLight))
            }
            .buttonStyle(.plain)

        case .tag(let name):
            let selected = selectedHobbies.contains(name)
            Button {
                HapticManager.light()
                if selected {
                    selectedHobbies.remove(name)
                } else {
                    selectedHobbies.insert(name)
                }
            } label: {
                Text(name)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(selected ? .white : pinkAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if selected {
                                Capsule().fill(pinkAccent)
                            } else {
                                Capsule().fill(Color.white)
                                Capsule().stroke(pinkAccent, lineWidth: 1)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    hobbyTags.removeAll { $0 == name }
                    selectedHobbies.remove(name)
                } label: {
                    Label(String(localized: "削除", bundle: LanguageManager.appBundle),
                          systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Add Hobby Sheet

    private var addHobbySheet: some View {
        VStack(spacing: 16) {
            Text(String(localized: "趣味タグをつくる", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(16))
                .foregroundColor(MeloColors.Text.primary)
                .padding(.top, 20)

            TextField(
                String(localized: "例：映画、カフェ巡り", bundle: LanguageManager.appBundle),
                text: $newHobbyText
            )
            .font(MeloFonts.zenMaruMedium(14))
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(brown, lineWidth: 1)
            )
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button {
                    showAddHobbySheet = false
                } label: {
                    Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(MeloColors.Text.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().stroke(brown, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    let trimmed = newHobbyText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if !hobbyTags.contains(trimmed) {
                        hobbyTags.append(trimmed)
                    }
                    selectedHobbies.insert(trimmed)
                    newHobbyText = ""
                    showAddHobbySheet = false
                    HapticManager.success()
                } label: {
                    Text(String(localized: "追加", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(pinkAccent))
                }
                .buttonStyle(.plain)
                .disabled(newHobbyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - MBTI row（既存ロジックを維持）

    private var mbtiRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MBTI")
                .font(MeloFonts.zenMaruOrFallback(16))
                .foregroundColor(MeloColors.Text.primary)

            Button {
                HapticManager.light()
                showBadgePicker = true
            } label: {
                HStack {
                    if let badge = selectedBadge {
                        Text(badge.typeCode)
                            .font(MeloFonts.zenMaruOrFallback(13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(MeloColors.mbtiColor(for: badge.typeCode))
                            )
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 14))
                                .foregroundColor(pinkAccent.opacity(0.6))
                            Text(String(localized: "MBTIを設定する", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruMedium(15))
                                .foregroundColor(brownLight)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(brownLight)
                }
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(brown, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Privacy row（既存ロジック維持）

    private var privacyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "アカウント公開設定", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(16))
                .foregroundColor(MeloColors.Text.primary)

            Toggle(isOn: $isPrivate) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(pinkAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "非公開アカウント", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(MeloColors.Text.primary)
                        Text(String(localized: "フォロワーだけが投稿を見れます", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruRegular(11))
                            .foregroundColor(brownLight)
                    }
                }
            }
            .tint(pinkAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(brown.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            HapticManager.light()
            authService.signOut()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14))
                Text(String(localized: "サインアウト", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(14))
            }
            .foregroundColor(.red.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Local extras (birthday / hobbies persisted via UserDefaults)

    private func loadLocalExtras() {
        let ud = UserDefaults.standard
        if let saved = ud.object(forKey: birthdayStorageKey) as? Date {
            birthday = saved
            hasBirthday = true
        }
        let savedTags = ud.stringArray(forKey: hobbyStorageKey) ?? []
        if savedTags.isEmpty {
            hobbyTags = BoardProfileEditView.defaultHobbyTags
        } else {
            hobbyTags = savedTags
        }
        if let selected = ud.stringArray(forKey: hobbySelectionKey) {
            selectedHobbies = Set(selected)
        }
    }

    private func saveLocalExtras() {
        let ud = UserDefaults.standard
        if hasBirthday {
            ud.set(birthday, forKey: birthdayStorageKey)
        }
        ud.set(hobbyTags, forKey: hobbyStorageKey)
        ud.set(Array(selectedHobbies), forKey: hobbySelectionKey)
    }

    // MARK: - Save

    private func saveProfile() async {
        guard let userId = authService.currentUser?.id else { return }
        isSaving = true

        var imageURL = profile.profileImageURL

        if let image = profileImage,
           let data = image.jpegData(compressionQuality: 0.7) {
            do {
                imageURL = try await firestoreService.uploadProfileImage(userId: userId, imageData: data)
            } catch {
                print("[BoardProfile] Image upload failed: \(error)")
            }
        }

        if displayName != authService.currentUser?.displayName {
            await authService.updateDisplayName(displayName)
        }

        try? await firestoreService.updateProfile(
            userId: userId,
            displayName: displayName,
            bio: bio,
            profileImageURL: imageURL
        )

        try? await firestoreService.saveUserProfile(
            userId: userId,
            displayName: displayName,
            badge: selectedBadge
        )

        try? await firestoreService.updatePostsAuthorInfo(
            userId: userId,
            displayName: displayName,
            profileImageURL: imageURL,
            badge: selectedBadge
        )

        // 非公開アカウント設定を Firestore にも反映
        if isPrivate != profile.isPrivate {
            do {
                try await firestoreService.togglePrivacy(userId: userId, isPrivate: isPrivate)
                AnalyticsManager.shared.track(
                    "profile_privacy_toggle",
                    properties: ["is_private": isPrivate]
                )
            } catch {
                print("[BoardProfile] Privacy toggle failed: \(error)")
            }
        }

        profile.displayName = displayName
        profile.bio = bio
        profile.profileImageURL = imageURL
        profile.badge = selectedBadge
        profile.isPrivate = isPrivate

        saveLocalExtras()

        isSaving = false
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Hobby Tag Item
private enum HobbyTagItem: Hashable {
    case create
    case tag(String)
}


// MARK: - MBTI Picker View

struct MBTIPickerView: View {
    @Binding var selectedBadge: LoveTypeBadge?
    @Environment(\.dismiss) private var dismiss

    private let mbtiTypes: [(code: String, name: String, group: String)] = [
        // Analysts (NT)
        ("INTJ", "Architect", "Analysts"),
        ("INTP", "Logician", "Analysts"),
        ("ENTJ", "Commander", "Analysts"),
        ("ENTP", "Debater", "Analysts"),
        // Diplomats (NF)
        ("INFJ", "Advocate", "Diplomats"),
        ("INFP", "Mediator", "Diplomats"),
        ("ENFJ", "Protagonist", "Diplomats"),
        ("ENFP", "Campaigner", "Diplomats"),
        // Sentinels (SJ)
        ("ISTJ", "Logistician", "Sentinels"),
        ("ISFJ", "Defender", "Sentinels"),
        ("ESTJ", "Executive", "Sentinels"),
        ("ESFJ", "Consul", "Sentinels"),
        // Explorers (SP)
        ("ISTP", "Virtuoso", "Explorers"),
        ("ISFP", "Adventurer", "Explorers"),
        ("ESTP", "Entrepreneur", "Explorers"),
        ("ESFP", "Entertainer", "Explorers"),
    ]

    private let groups = ["Analysts", "Diplomats", "Sentinels", "Explorers"]

    private func groupLabel(_ group: String) -> String {
        switch group {
        case "Analysts": return String(localized: "分析家", bundle: LanguageManager.appBundle)
        case "Diplomats": return String(localized: "外交官", bundle: LanguageManager.appBundle)
        case "Sentinels": return String(localized: "番人", bundle: LanguageManager.appBundle)
        case "Explorers": return String(localized: "探検家", bundle: LanguageManager.appBundle)
        default: return group
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 非表示オプション
                    Button {
                        HapticManager.light()
                        selectedBadge = nil
                        dismiss()
                    } label: {
                        Text(String(localized: "非表示", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(14))
                            .foregroundColor(selectedBadge == nil ? .white : BoardColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(selectedBadge == nil ? BoardColors.accent : Color.white)
                                    .shadow(color: BoardColors.accent.opacity(0.08), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)

                    // MBTIグループ別
                    ForEach(groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(mbtiTypes.filter { $0.group == group }, id: \.code) { mbti in
                                    let isSelected = selectedBadge?.typeCode == mbti.code
                                    let color = MeloColors.mbtiColor(for: mbti.code)

                                    Button {
                                        HapticManager.light()
                                        selectedBadge = LoveTypeBadge(
                                            typeCode: mbti.code,
                                            typeName: mbti.code,
                                            totalScore: 0
                                        )
                                        dismiss()
                                    } label: {
                                        Text(mbti.code)
                                            .font(MeloFonts.zenMaruOrFallback(15))
                                            .foregroundColor(isSelected ? .white : color)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                Capsule()
                                                    .fill(isSelected ? color : color.opacity(0.12))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [BoardColors.bgTop, BoardColors.bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("MBTI")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    BoardProfileView()
        .modelContainer(for: [StoredChatSession.self, StoredAnalysisResult.self])
}
