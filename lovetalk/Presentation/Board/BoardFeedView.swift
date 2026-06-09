import SwiftUI
import FirebaseFirestore

// MARK: - Board Toast View
struct BoardToastView: View {
    let message: String
    let icon: String
    let isError: Bool

    init(_ message: String, icon: String = "checkmark.circle.fill", isError: Bool = false) {
        self.message = message
        self.icon = icon
        self.isError = isError
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isError ? MeloColors.Status.error : BoardColors.accent)

            Text(message)
                .font(MeloFonts.zenMaruOrFallback(13))
                .foregroundColor(BoardColors.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(MeloColors.Dark.card.opacity(0.92))
                )
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Heart Burst Effect
struct HeartBurstView: View {
    @State private var particles: [(id: Int, offset: CGSize, opacity: Double)] = []
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { p in
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundColor(BoardColors.accent)
                    .offset(p.offset)
                    .opacity(p.opacity)
            }
        }
        .onAppear {
            // 6つのパーティクルを放射状に配置
            for i in 0..<6 {
                let angle = Double(i) * (.pi * 2 / 6) + .pi / 6
                particles.append((id: i, offset: .zero, opacity: 1.0))
                withAnimation(.easeOut(duration: 0.5)) {
                    particles[i].offset = CGSize(
                        width: cos(angle) * 16,
                        height: sin(angle) * 16
                    )
                    particles[i].opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }
}

// MARK: - Board Colors
enum BoardColors {
    static let bgTop = MeloColors.Dark.bg
    static let bgBottom = MeloColors.Dark.bg
    static let cardBg = MeloColors.Dark.card
    static let accent = MeloColors.Dark.accent
    static let accentLight = MeloColors.Dark.accent
    static let textPrimary = MeloColors.Dark.textPrimary
    static let textSecondary = MeloColors.Dark.textSecondary
    static let textTertiary = MeloColors.Dark.textSecondary
    static let divider = MeloColors.Dark.divider
    static let sortPill = MeloColors.Dark.bgElevated
    static let composeGradientStart = MeloColors.Dark.accentDeep
    static let composeGradientEnd = MeloColors.Dark.accent
}

// MARK: - Skeleton Loading Card
struct SkeletonPostCard: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(MeloColors.Dark.bgElevated)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(MeloColors.Dark.bgElevated)
                        .frame(width: 80, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(MeloColors.Dark.bgElevated)
                        .frame(width: 50, height: 10)
                }
                Spacer()
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(MeloColors.Dark.bgElevated)
                .frame(height: 14)
            RoundedRectangle(cornerRadius: 4)
                .fill(MeloColors.Dark.bgElevated)
                .frame(width: 200, height: 14)
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(MeloColors.Dark.bgElevated)
                    .frame(width: 40, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(MeloColors.Dark.bgElevated)
                    .frame(width: 40, height: 12)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(BoardColors.cardBg)
                .shadow(color: BoardColors.accent.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .opacity(shimmer ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Bars Scroll State
/// FAB / タブバーの表示状態を制御する。
/// `lastOffset` / `accumulator` は @Published にしないことで、
/// スクロール毎フレームの状態更新が SwiftUI 側の view 再評価を起こさないようにしている。
/// 旧実装は @State で同じ値を持っており、減速時に毎フレーム body 再評価が走ってカクついていた。
@MainActor
private final class BarsScrollState: ObservableObject {
    /// 直前のスクロールオフセット (毎フレーム更新するが Published ではない)
    var lastOffset: CGFloat = 0
    /// 同方向のスクロール量を蓄積 (方向が変わったらリセット)
    var accumulator: CGFloat = 0
    /// 実際にバーを隠すかどうか。閾値を跨いだ瞬間だけ flip するので body 再評価は最小限。
    @Published var barsHidden: Bool = false

    /// 新しいスクロールオフセットを受け取り、必要なら barsHidden を flip する。
    /// 戻り値は flip した場合 true (= withAnimation を呼ぶ価値がある場合のみ)。
    /// - Parameter offset: ScrollGeometry.contentOffset.y。下スクロールで小さくなる慣習に合わせて
    ///   旧 GeometryReader 実装と同じ符号 (上方向 = 正) で渡す。
    func handleOffset(_ offset: CGFloat) -> Bool {
        let delta = offset - lastOffset
        lastOffset = offset

        // 最上部付近では常にバーを表示
        if offset > -20 {
            accumulator = 0
            if barsHidden {
                barsHidden = false
                return true
            }
            return false
        }

        // 方向が変わったら蓄積をリセット
        if (delta > 0 && accumulator < 0) || (delta < 0 && accumulator > 0) {
            accumulator = 0
        }
        accumulator += delta

        // 下スクロール: 蓄積が閾値を超えたらバーを隠す
        if accumulator < -60 && !barsHidden {
            barsHidden = true
            accumulator = 0
            return true
        }
        // 上スクロール: 蓄積が閾値を超えたらバーを表示
        if accumulator > 40 && barsHidden {
            barsHidden = false
            accumulator = 0
            return true
        }
        return false
    }

    /// スクロール位置を頭に戻すなど、外部要因で確実に表示したい時用。
    func forceShow() {
        accumulator = 0
        if barsHidden {
            barsHidden = false
        }
    }
}

// MARK: - Board Feed View
struct BoardFeedView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var authService = BoardAuthService.shared
    @StateObject private var blockService = BoardBlockService.shared
    @State private var selectedSort: BoardFeedSort = .popular
    @State private var selectedCategory: BoardFeedCategory = .all
    @State private var showCompose = false
    @State private var showSignIn = false
    @State private var profileTarget: ProfileSheetTarget?
    @State private var showNotifications = false
    @State private var showSearch = false
    @State private var searchInitialQuery: String?
    @State private var posts: [BoardPost] = []
    @State private var selectedPost: BoardPost?
    @State private var isLoadingPosts = true
    @State private var lastDocument: DocumentSnapshot?
    @State private var hasMorePosts = true
    @State private var unreadNotificationCount = 0
    @State private var quotePost: QuotedPostInfo?
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var loadError: String?
    @State private var scrollToTopTrigger = false

    // スクロール方向検出 (オフセットベース)。
    // 詳細は BarsScrollState のコメント参照。@State から外したことが減速時カクつきの主因解消。
    @StateObject private var scrollState = BarsScrollState()
    private var barsHidden: Bool { scrollState.barsHidden }

    // フォロー中ユーザーIDキャッシュ
    @State private var followingIds: Set<String> = []

    private let firestoreService = BoardFirestoreService.shared

    private var homeFeedPostHorizontalPadding: CGFloat {
        MeloLayout.boardPostHorizontalPadding
    }

    /// CommunityRoomsView の作成 FAB (trailing 20pt) と同じ位置に来るように調整。
    private var composeButtonTrailingPadding: CGFloat {
        20
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // ヘッダーは常時表示
                    boardHeader
                        .background(MeloColors.Dark.bg)

                    // 新着 / おすすめ / フォロー の行 (常時表示・下線インジケータ式)
                    sortTabsRow

                    // フィード
                    if isLoadingPosts && posts.isEmpty {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { _ in
                                    SkeletonPostCard()
                                        .padding(.horizontal, homeFeedPostHorizontalPadding)
                                }
                            }
                            .padding(.top, 12)
                        }
                    } else if posts.isEmpty {
                        emptyState
                    } else {
                        feedScrollView
                    }
                }

                // 投稿ボタン（FAB）— スクロール時は縮小して右下に退避
                // 端末幅に応じて trailing 余白を伸縮させ、画面端からはみ出さないようにする。
                // scaleEffect の anchor を bottomTrailing にして、縮小時に位置がずれないようにする。
                composeButton
                    .padding(.trailing, composeButtonTrailingPadding)
                    .padding(.bottom, barsHidden ? 40 : 96)
                    .scaleEffect(barsHidden ? 0.75 : 1.0, anchor: .bottomTrailing)
                    .opacity(barsHidden ? 0.7 : 1.0)
            }
            .background(MeloColors.Dark.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showCompose, onDismiss: {
                quotePost = nil
            }) {
                // V2 コンポーザに統一（引用・通常いずれの導線でも使用）。
                // onSubmit は渡さず V2 内部の Firestore 投稿経路に任せ、
                // 投稿成功時のみ onPosted 経由でトーストを表示する。
                BoardComposeViewV2(
                    onPosted: {
                        showToast(String(localized: "投稿しました！", bundle: LanguageManager.appBundle))
                    },
                    onRequestOpenConsultRoom: {
                        coordinator.consultRoomPath = NavigationPath()
                        coordinator.selectedTab = .consultRoom
                    },
                    quotedPost: quotePost
                )
            }
            .sheet(item: $selectedPost) { post in
                BoardPostDetailView(post: post) {
                    posts.removeAll { $0.id == post.id }
                }
            }
            .sheet(isPresented: $showSignIn, onDismiss: {
                // サインイン成功後 → 投稿画面を自動表示
                if authService.hasRealAccount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCompose = true
                    }
                }
            }) {
                BoardSignInView()
            }
            .sheet(item: $profileTarget, onDismiss: {
                // プロフィール画面でフォロー/アンフォローした可能性があるため再取得
                Task {
                    await loadFollowingIds()
                    if selectedSort == .following || selectedSort == .popular {
                        startListening()
                    }
                }
            }) { target in
                BoardProfileView(userId: target.userId)
            }
            .sheet(isPresented: $showNotifications) {
                BoardNotificationsView()
            }
            .fullScreenCover(isPresented: $showSearch, onDismiss: {
                searchInitialQuery = nil
            }) {
                BoardSearchView(initialQuery: searchInitialQuery)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openHashtagSearch)) { note in
                guard let tag = note.object as? String, !tag.isEmpty else { return }
                searchInitialQuery = "#\(tag)"
                showSearch = true
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
            // タブ表示時はバーを復帰
            coordinator.isBarsHidden = false
            scrollState.forceShow()
            ensureSignedIn()
            checkUnreadNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { notification in
            if let tab = notification.object as? MainTab, tab == .home {
                scrollToTopTrigger.toggle()
            }
        }
        .onChange(of: selectedSort) { _ in
            lastDocument = nil
            hasMorePosts = true
            // タブ切替時は既存の posts を破棄してフレッシュロード扱いにする。
            // (startListening 側のマージ処理が posts.isEmpty == false の場合
            //  「既存維持 + 新規追加」になり、旧タブの結果が残ってしまうため)
            posts = []
            firestoreService.resetPopularCache()
            if selectedSort == .following || selectedSort == .popular {
                // フォロー中タブ or おすすめタブ切替時にフォローIDを再取得
                Task {
                    await loadFollowingIds()
                    startListening()
                }
            } else {
                startListening()
            }
        }
        .onDisappear {
            firestoreService.stopListening()
        }
    }

    // MARK: - Auth

    private func ensureSignedIn() {
        if !authService.isSignedIn {
            Task {
                await authService.signInAnonymously()
                // サインイン後: リスナー即開始 + フォローID並行取得
                startListening()
                PushNotificationManager.shared.syncAuthorizationStatus()
                await loadFollowingIds()
                // フォローID取得後にリスナー再起動（フィルタ精度向上）
                startListening()
            }
        } else {
            // リスナーを即開始（フォローID無しで）、並行してフォローID取得
            startListening()
            PushNotificationManager.shared.syncAuthorizationStatus()
            Task {
                await loadFollowingIds()
                // フォローID取得後にリスナー再起動（フィルタ精度向上）
                startListening()
            }
        }
    }

    private func loadFollowingIds() async {
        guard let userId = authService.currentUser?.id else { return }
        followingIds = (try? await firestoreService.getFollowingIds(userId: userId)) ?? []
    }

    // MARK: - Realtime Listener

    private func startListening() {
        isLoadingPosts = posts.isEmpty
        let currentUserId = authService.currentUser?.id
        firestoreService.listenToPosts(sort: selectedSort, limit: 20, followingIds: followingIds, userLanguage: LanguageManager.resolvedLanguage) { updatedPosts in
            // 非公開アカウントの投稿をフィルタ（匿名投稿は除外しない）
            let filtered = updatedPosts.filter { post in
                guard post.authorIsPrivate == true, !post.isAnonymous else { return true }
                return post.authorId == currentUserId || followingIds.contains(post.authorId)
            }

            withAnimation(.easeOut(duration: 0.25)) {
                if posts.isEmpty {
                    // 初回ロード: そのまま反映
                    posts = filtered
                } else {
                    // 既にページネーションで古い投稿が読み込まれている可能性があるため、
                    // listener の結果で全置換すると遡って読んだ古い投稿が消えてしまい、
                    // スクロール位置が強制的に先頭に戻る不具合になる。
                    // → 既存投稿は in-place 更新、新規投稿のみ先頭に追加し、古い投稿は保持する。
                    let updatedById = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
                    for i in posts.indices {
                        if let updated = updatedById[posts[i].id] {
                            posts[i] = updated
                        }
                    }
                    let existingIds = Set(posts.map(\.id))
                    let brandNew = filtered.filter { !existingIds.contains($0.id) }
                    if !brandNew.isEmpty {
                        posts.insert(contentsOf: brandNew, at: 0)
                    }
                }
                isLoadingPosts = false
            }

            // アバター画像をバックグラウンドでプリフェッチ
            let avatarURLs = filtered.compactMap { post -> URL? in
                guard !post.isAnonymous,
                      let urlString = post.authorProfileImageURL,
                      let url = URL(string: urlString),
                      ImageCache.shared.get(url) == nil else { return nil }
                return url
            }
            if !avatarURLs.isEmpty {
                Task { await ImageCache.shared.prefetch(avatarURLs) }
            }
        }
    }

    // MARK: - Load Posts (Pagination)

    private func loadPosts() async {
        guard !isLoadingPosts else { return }
        isLoadingPosts = true

        do {
            let (newPosts, lastDoc) = try await firestoreService.fetchPosts(
                sort: selectedSort,
                limit: 20,
                after: lastDocument,
                followingIds: followingIds,
                userLanguage: LanguageManager.resolvedLanguage
            )

            // プロフィール画像をプリフェッチ
            let avatarURLs = newPosts.compactMap { post -> URL? in
                guard !post.isAnonymous,
                      let urlString = post.authorProfileImageURL,
                      let url = URL(string: urlString),
                      ImageCache.shared.get(url) == nil else { return nil }
                return url
            }
            if !avatarURLs.isEmpty {
                await ImageCache.shared.prefetch(avatarURLs)
            }

            // 非公開アカウントの投稿をフィルタ（匿名投稿は除外しない）
            let currentUserId = authService.currentUser?.id
            let filtered = newPosts.filter { post in
                guard post.authorIsPrivate == true, !post.isAnonymous else { return true }
                return post.authorId == currentUserId || followingIds.contains(post.authorId)
            }

            let existingIds = Set(posts.map(\.id))
            let uniqueNewPosts = filtered.filter { !existingIds.contains($0.id) }
            posts.append(contentsOf: uniqueNewPosts)
            lastDocument = lastDoc
            hasMorePosts = newPosts.count == 20
        } catch {
            print("[Board] Failed to load posts: \(error)")
            showToast(String(localized: "投稿の読み込みに失敗しました", bundle: LanguageManager.appBundle), isError: true)
        }

        isLoadingPosts = false
    }

    private func refreshPosts() async {
        lastDocument = nil
        hasMorePosts = true
        posts = []
        firestoreService.resetPopularCache()
        startListening()
    }

    private var filteredPosts: [BoardPost] {
        posts.filter { post in
            !blockService.isBlocked(post.authorId)
        }
    }

    private func loadMoreIfNeeded(currentPost: BoardPost) {
        guard hasMorePosts, !isLoadingPosts else { return }
        guard let index = posts.firstIndex(where: { $0.id == currentPost.id }) else { return }
        if index >= posts.count - 3 {
            Task { await loadPosts() }
        }
    }

    private func checkUnreadNotifications() {
        guard let userId = authService.currentUser?.id else { return }
        Task {
            let count = (try? await firestoreService.fetchUnreadNotificationCount(userId: userId)) ?? 0
            unreadNotificationCount = count
            coordinator.homeUnreadCount = count
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

    // MARK: - Header (Figma 【確定】ホーム画面)

    /// 新着 / おすすめ / フォロー の共通ソートラベルボタン。
    /// 文字サイズは選択状態に関わらず一定。Bold は使わず Medium ウェイト。
    /// 選択中: ピンクグラデ + 直下に太いピンク線、非選択: グレー + 透明線。
    @ViewBuilder
    private func sortLabelButton(sort: BoardFeedSort, label: String) -> some View {
        let isSelected = selectedSort == sort
        Button {
            guard selectedSort != sort else { return }
            HapticManager.light()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSort = sort
            }
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(MeloFonts.zenMaruMedium(16))
                    .tracking(0.48)
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(MeloColors.Dark.accentGradient)
                        : AnyShapeStyle(BoardFeedPalette.textBrown)
                    )
                    .shadow(
                        color: isSelected ? MeloColors.Dark.accent.opacity(0.4) : .clear,
                        radius: 4, x: 0, y: 2
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(
                        isSelected
                        ? AnyShapeStyle(MeloColors.Dark.accentGradient)
                        : AnyShapeStyle(Color.clear)
                    )
                    .frame(height: isSelected ? 3 : 1)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board_sort_\(sort.rawValue)")
    }

    /// 新着 / おすすめ / フォロー の独立行 (boardHeader と categoryPillRow の間に挟む)。
    /// 各タブが等幅セルで横に並び、中央タブ (おすすめ) が画面中央に正確に配置される。
    /// 行の最下端には画面端から端まで伸びる薄いグレー線。選択中タブ下のピンク太線が
    /// その線と同じ y 位置に重なって、その区間だけ太く見える。
    private var sortTabsRow: some View {
        ZStack(alignment: .bottom) {
            // 画面端から端まで伸びるフルワイド薄線
            Rectangle()
                .fill(MeloColors.Dark.divider)
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: 0) {
                sortLabelButton(sort: .latest, label: String(localized: "新着", bundle: LanguageManager.appBundle))
                    .frame(maxWidth: .infinity)
                sortLabelButton(sort: .popular, label: String(localized: "おすすめ", bundle: LanguageManager.appBundle))
                    .frame(maxWidth: .infinity)
                sortLabelButton(sort: .following, label: String(localized: "フォロー", bundle: LanguageManager.appBundle))
                    .frame(maxWidth: .infinity)
            }
            // タブを画面幅いっぱいに均等配置するため、左右の padding は最小限に。
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .background(MeloColors.Dark.bg)
    }

    private var boardHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            // タイトル: ホーム
            Text(String(localized: "ホーム", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(22))
                .tracking(0.66)
                .foregroundColor(MeloColors.Dark.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // 検索ボタン（37x37 円）
            Button {
                HapticManager.light()
                showSearch = true
            } label: {
                ZStack {
                    Circle()
                        .fill(MeloColors.Dark.bgElevated)
                        .frame(width: PremiumBadgeButton.height, height: PremiumBadgeButton.height)
                        .overlay(
                            Circle().stroke(BoardFeedPalette.borderPink, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1.9)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BoardFeedPalette.textBrown)
                }
            }
            .buttonStyle(.plain)

            // 通知ボタン（37x37 円）
            Button {
                HapticManager.light()
                guard authService.hasRealAccount else {
                    showSignIn = true
                    return
                }
                showNotifications = true
                unreadNotificationCount = 0
                coordinator.homeUnreadCount = 0
            } label: {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(MeloColors.Dark.bgElevated)
                            .frame(width: PremiumBadgeButton.height, height: PremiumBadgeButton.height)
                            .overlay(
                                Circle().stroke(BoardFeedPalette.borderPink, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1.9)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BoardFeedPalette.textBrown)
                    }
                    if unreadNotificationCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(MeloColors.Dark.bg, lineWidth: 1.5))
                            .offset(x: -3, y: 3)
                    }
                }
                .frame(width: PremiumBadgeButton.height, height: PremiumBadgeButton.height)
            }
            .buttonStyle(.plain)

            // Premium バッジ（右端）
            PremiumBadgeButton(source: "premium_badge_home") {
                HapticManager.light()
                coordinator.subscriptionSource = "premium_badge_home"
                coordinator.showingSubscription = true
            }
        }
        .padding(.horizontal, MeloLayout.titleHorizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(MeloColors.Dark.bg)
    }

    // MARK: - Category Pill Row

    private var categoryPillRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(BoardFeedCategory.allCases) { cat in
                    categoryPill(cat)
                }
            }
            // テーマピル列は左端から少し早めに開始させる (ヘッダー余白より狭く)。
            .padding(.leading, max(12, MeloLayout.headerHorizontalPadding - 12))
            .padding(.trailing, MeloLayout.headerHorizontalPadding)
            .padding(.vertical, 4)
        }
        .frame(height: 40)
    }

    private func categoryPill(_ cat: BoardFeedCategory) -> some View {
        let isSelected = selectedCategory == cat

        return Button {
            HapticManager.light()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = cat
            }
        } label: {
            HStack(spacing: 4) {
                if let icon = cat.icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? MeloColors.Dark.onAccent : BoardFeedPalette.accentPink)
                }
                Text(cat.localizedName)
                    .font(isSelected ? MeloFonts.zenMaruOrFallback(12) : MeloFonts.zenMaruMedium(12))
                    .tracking(0.36)
                    .foregroundColor(isSelected ? MeloColors.Dark.onAccent : BoardFeedPalette.textBrown)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(
                ZStack {
                    Capsule()
                        .fill(isSelected ? BoardFeedPalette.accentPink : MeloColors.Dark.card)
                    if !isSelected {
                        Capsule()
                            .stroke(BoardFeedPalette.borderPink, lineWidth: 1)
                    }
                }
            )
            .shadow(color: isSelected ? Color.clear : Color.black.opacity(0.3), radius: 3, x: 0, y: 1.9)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            if selectedSort == .following {
                Image("mero_pair_05")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                if followingIds.isEmpty {
                    Text(String(localized: "まだ誰もフォローしていません", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(16))
                        .foregroundColor(BoardColors.textTertiary)

                    Text(String(localized: "気になるユーザーをフォローすると\nここに投稿が表示されます", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(13))
                        .foregroundColor(BoardColors.textTertiary)
                        .multilineTextAlignment(.center)

                    // ユーザー検索CTA
                    Button {
                        HapticManager.medium()
                        showSearch = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13))
                            Text(String(localized: "ユーザーを探す", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruOrFallback(13))
                        }
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [BoardColors.composeGradientStart, BoardColors.composeGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    Text(String(localized: "フォロー中のユーザーの投稿がありません", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(16))
                        .foregroundColor(BoardColors.textTertiary)
                }
            } else {
                Image("mero_pair_01")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                Text(String(localized: "まだ投稿がありません", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(16))
                    .foregroundColor(BoardColors.textTertiary)

                Text(String(localized: "最初の投稿をしてみよう！", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(13))
                    .foregroundColor(BoardColors.textTertiary)

                // 投稿CTA
                Button {
                    HapticManager.medium()
                    openCompose(type: .normal)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13))
                        Text(String(localized: "投稿する", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(13))
                    }
                    .foregroundColor(MeloColors.Dark.onAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [BoardColors.composeGradientStart, BoardColors.composeGradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer()
        }
    }

    // MARK: - Feed

    private var feedScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // 旧 GeometryReader アンカーはスクロール毎フレーム preference を発火させていたため削除。
                    // オフセット検知は外側の .onScrollGeometryChange で行う。
                    Color.clear.frame(height: 0).id("feedTop")

                    ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
                        BoardFeedPostCard(post: post, horizontalPadding: homeFeedPostHorizontalPadding) {
                            selectedPost = post
                        } onAuthorTap: { authorId in
                            profileTarget = ProfileSheetTarget(userId: authorId)
                        } onQuote: { quote in
                            quotePost = quote
                            showCompose = true
                        } onRequireSignIn: {
                            showSignIn = true
                        }
                        .onAppear {
                            loadMoreIfNeeded(currentPost: post)
                            Task { try? await firestoreService.incrementViewCount(postId: post.id) }
                        }

                        // 2番目と3番目の投稿の間にバナー広告
                        if index == 1 {
                            AdBannerContainer(adUnitID: AdUnitID.bannerBoard)
                                .padding(.horizontal, MeloLayout.contentHorizontalPadding)
                                .padding(.vertical, 14)
                        }
                    }

                    if isLoadingPosts {
                        ProgressView()
                            .tint(BoardColors.accent)
                            .padding()
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, 4)
            }
            // スクロールオフセットの読み取りは onScrollGeometryChange に集約。
            // GeometryReader+PreferenceKey と違い、内部で最適化されており毎フレーム
            // SwiftUI の View 階層を invalidate しない。
            // contentOffset.y は標準では下スクロールで正方向に増えるため、旧実装と
            // 同じ符号 (上スクロール = 正) になるよう反転する。
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                -geometry.contentOffset.y
            } action: { _, newOffset in
                // BarsScrollState 内で flip 判定。flip した瞬間だけ true が返るので
                // withAnimation と coordinator.isBarsHidden の更新もそのときだけ実行する。
                let flipped = scrollState.handleOffset(newOffset)
                if flipped {
                    withAnimation(.easeOut(duration: 0.25)) {
                        coordinator.isBarsHidden = scrollState.barsHidden
                    }
                }
            }
            .refreshable {
                await refreshPosts()
            }
            .onChange(of: scrollToTopTrigger) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("feedTop", anchor: .top)
                }
                // バーも表示に戻す
                scrollState.forceShow()
                if coordinator.isBarsHidden {
                    withAnimation(.easeOut(duration: 0.25)) {
                        coordinator.isBarsHidden = false
                    }
                }
            }
        }
    }

    // MARK: - Compose FAB (相談部屋詳細と同じ square.and.pencil 56pt スタイル)

    private var composeButton: some View {
        Button {
            HapticManager.medium()
            if authService.hasRealAccount {
                coordinator.showingComposeV2 = true
            } else {
                showSignIn = true
            }
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(MeloColors.Dark.onAccent)
                .frame(width: 56, height: 56)
                .background(Circle().fill(MeloColors.Dark.accentGradient))
                .shadow(color: MeloColors.Dark.accent.opacity(0.45), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(ScaleFABStyle())
        .accessibilityLabel("新しい投稿を作成")
    }

    private func openCompose(type: BoardPostType) {
        // V2 への移行により type は未使用。将来の拡張のため引数シグネチャは維持。
        _ = type
        if authService.hasRealAccount {
            showCompose = true
        } else {
            showSignIn = true
        }
    }
}

// MARK: - Board Feed Palette (Figma 【確定】ホーム画面)

enum BoardFeedPalette {
    static let accentPink = MeloColors.Dark.accent
    static let textBrown = MeloColors.Dark.textPrimary
    static let bodyInk = MeloColors.Dark.textPrimary          // 投稿本文のより黒い色
    static let borderPink = MeloColors.Dark.cardStroke
    /// 投稿カード/相談部屋カード/診断カード/各種カード共通のアウトライン色 (濃いグレー)
    static let cardBorderGray = MeloColors.Dark.cardStroke
    static let shadowPink = MeloColors.Dark.bgElevated
    static let barBgPink = MeloColors.Dark.bgElevated
    static let pillBgPink = MeloColors.Dark.bgElevated
    static let timeGray = MeloColors.Dark.textSecondary
    static let engageGray = MeloColors.Dark.textSecondary
    static let pollInactiveBg = MeloColors.Dark.track    // アンケート未投票時の灰色背景
    static let pollInactiveFill = MeloColors.Dark.track  // 未投票時のバー色
}

// MARK: - Board Feed Category (UI-only filter)

enum BoardFeedCategory: String, CaseIterable, Identifiable {
    case all
    case power     // パワハラ
    case sexual    // セクハラ
    case moral     // モラハラ
    case customer  // カスハラ
    case other     // その他
    case consult   // ぶっちゃけ相談

    var id: String { rawValue }

    /// 各カテゴリに対応するテーマラベル (Firestore `posts.themes` に保存される文字列)。
    /// `PostTheme.label` と一致させること。`.all` は空 = 全件マッチ。
    var themeLabel: String? {
        switch self {
        case .all:      return nil
        case .power:    return "パワハラ"
        case .sexual:   return "セクハラ"
        case .moral:    return "モラハラ"
        case .customer: return "カスハラ"
        case .other:    return "その他"
        case .consult:  return "ぶっちゃけ相談"
        }
    }

    var localizedName: String {
        switch self {
        case .all:      return String(localized: "すべて", bundle: LanguageManager.appBundle)
        case .power:    return String(localized: "パワハラ", bundle: LanguageManager.appBundle)
        case .sexual:   return String(localized: "セクハラ", bundle: LanguageManager.appBundle)
        case .moral:    return String(localized: "モラハラ", bundle: LanguageManager.appBundle)
        case .customer: return String(localized: "カスハラ", bundle: LanguageManager.appBundle)
        case .other:    return String(localized: "その他", bundle: LanguageManager.appBundle)
        case .consult:  return String(localized: "ぶっちゃけ相談", bundle: LanguageManager.appBundle)
        }
    }

    /// テーマ別アイコン。すべて=アイコンなし。
    var icon: String? {
        switch self {
        case .all:      return nil
        case .power:    return "bolt.fill"
        case .sexual:   return "eye.slash.fill"
        case .moral:    return "cloud.fog.fill"
        case .customer: return "megaphone.fill"
        case .other:    return "ellipsis.circle.fill"
        case .consult:  return "bubble.left.and.bubble.right.fill"
        }
    }

    /// テーマフィールドが完全一致した場合のみマッチ。旧 (substring) ロジックは破棄。
    /// → 既存のテーマ未付与投稿はどのカテゴリにも入らず「すべて」のみ表示される。
    func matches(_ post: BoardPost) -> Bool {
        guard let label = themeLabel else { return true }
        return post.themes.contains(label)
    }
}

// MARK: - Board Feed Post Card (Figma 【確定】ホーム画面)
/// フィード専用の投稿カード。既存の BoardPostCard（検索・プロフィール等で流用中）は別途維持。
struct BoardFeedPostCard: View {
    let post: BoardPost
    var horizontalPadding: CGFloat? = nil
    let onTap: () -> Void
    var onAuthorTap: ((String) -> Void)? = nil
    var onQuote: ((QuotedPostInfo) -> Void)? = nil
    var onRequireSignIn: (() -> Void)? = nil

    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var authService = BoardAuthService.shared
    @StateObject private var bookmarkService = BoardBookmarkService.shared
    @State private var isLiked = false
    @State private var localHeartCount: Int = 0
    @State private var localReplyCount: Int = 0
    @State private var localRepostCount: Int = 0
    @State private var localQuoteCount: Int = 0
    @State private var localBookmarkCount: Int = 0
    @State private var isRepostedByMe: Bool = false
    @State private var showHeartBurst = false
    @State private var showImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var quotedPostDetail: BoardPost?
    @State private var isContentExpanded = false

    /// 一定文字数以上を超えると「もっと表示」を出す閾値
    private static let collapseCharThreshold = 150
    private static let collapsedLineLimit = 6

    private let firestoreService = BoardFirestoreService.shared

    private var shouldShowExpander: Bool {
        post.content.count > Self.collapseCharThreshold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            cardHeader
            cardBody
            if !post.imageURLs.isEmpty { cardImages }
            if let card = post.diagnosisCard { BoardDiagnosisCardExpanded(card: card) }
            if let quote = post.quotedPost { quoteBlock(quote) }
            if let options = post.pollOptions, !options.isEmpty {
                BoardFeedPollBars(postId: post.id, options: options, totalVotes: post.totalVotes)
                    .padding(.top, 2)
            }
            engageRow
        }
        .padding(.horizontal, horizontalPadding ?? MeloLayout.contentHorizontalPadding)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeloColors.Dark.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MeloColors.Dark.divider)
                .frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            localHeartCount = post.reactionCounts["heart"] ?? 0
            localReplyCount = post.replyCount
            localRepostCount = post.repostCount
            localQuoteCount = post.quoteCount
            localBookmarkCount = post.bookmarkCount
        }
        // 親(listener や別ビュー由来の更新)から post prop の数値が更新された時、
        // local state を再同期。`BoardPost` は `==` が id だけで判定されるので、
        // 親が同じ id の post を新しい数値で差し替えても SwiftUI は body を再評価しない。
        // そこで個別フィールドの onChange で明示的に追従する。
        .onChange(of: post.repostCount) { newValue in
            localRepostCount = newValue
        }
        .onChange(of: post.quoteCount) { newValue in
            localQuoteCount = newValue
        }
        .onChange(of: post.replyCount) { newValue in
            localReplyCount = newValue
        }
        .onChange(of: post.bookmarkCount) { newValue in
            localBookmarkCount = newValue
        }
        .onChange(of: post.reactionCounts["heart"] ?? 0) { newValue in
            localHeartCount = newValue
        }
        .task {
            guard let userId = authService.currentUser?.id else { return }
            isLiked = (try? await firestoreService.fetchMyReaction(postId: post.id, userId: userId)) == "heart"
            isRepostedByMe = (try? await firestoreService.fetchIsReposted(postId: post.id, userId: userId)) ?? false
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostReactionChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.ReactionPayload,
                  payload.postId == post.id else { return }
            isLiked = (payload.myReaction == "heart")
            localHeartCount = payload.counts["heart"] ?? localHeartCount
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostReplyCountChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.ReplyCountPayload,
                  payload.postId == post.id else { return }
            localReplyCount = payload.replyCount
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
        .sheet(item: $quotedPostDetail) { quotedPost in
            BoardPostDetailView(post: quotedPost)
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            FullscreenImageViewer(
                imageURLs: post.imageURLs,
                selectedIndex: $selectedImageIndex,
                isPresented: $showImageViewer
            )
        }
    }

    // MARK: Header

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
                .frame(width: 47, height: 48)

            VStack(alignment: .leading, spacing: 4) {
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
                        pillLabel(String(localized: "アンケート", bundle: LanguageManager.appBundle))
                    }
                    if post.isAnonymous {
                        pillLabel(String(localized: "匿名", bundle: LanguageManager.appBundle))
                    }
                    if let roomTitle = post.communityRoomTitle, !roomTitle.isEmpty {
                        Button {
                            HapticManager.light()
                            coordinator.openCommunityRoom(
                                id: post.communityRoomId ?? "",
                                title: roomTitle
                            )
                        } label: {
                            communityRoomPill(roomTitle)
                        }
                        .buttonStyle(.plain)
                        // 親 (投稿カード) の onTap が伝播しないように
                        .simultaneousGesture(TapGesture().onEnded {})
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
        Button {
            if !post.isAnonymous {
                onAuthorTap?(post.authorId)
            }
        } label: {
            Group {
                if post.isAnonymous {
                    // 匿名投稿はペア画像 (mero_pair_XX) を postId のハッシュで決定論的に選んで表示
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
        }
        .buttonStyle(.plain)
    }

    private func pillLabel(_ text: String) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruMedium(10))
            .foregroundColor(BoardFeedPalette.textBrown)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(BoardFeedPalette.pillBgPink))
    }

    private func communityRoomPill(_ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(MeloFonts.zenMaruMedium(10))
                .lineLimit(1)
        }
        .foregroundColor(BoardFeedPalette.textBrown)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(MeloColors.Dark.bgElevated))
        .overlay(Capsule().stroke(BoardFeedPalette.accentPink.opacity(0.35), lineWidth: 0.8))
    }

    /// テーマピル (MBTI/匿名ピルと並ぶ小さいピンクピル)。
    private func themeMiniPill(_ label: String) -> some View {
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

    // MARK: Body (hashtags highlighted pink)

    private var cardBody: some View {
        let attributed = HashtagAttributedString.make(
            text: post.content,
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
                }
                .buttonStyle(.plain)
            }
        }
    }


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

    // MARK: Images

    @ViewBuilder
    private var cardImages: some View {
        let urls = Array(post.imageURLs.prefix(4))
        // 全レイアウトで外枠を 16:9 の固定アスペクトに揃える (X/Twitter準拠)。
        // 中の image cell は Color を土台にして overlay + clipped で
        // CachedAsyncImage の intrinsic size がカード幅を押し広げないようにする。
        Group {
            if urls.count == 1 {
                imageCell(urls[0], index: 0)
            } else if urls.count == 2 {
                HStack(spacing: 4) {
                    imageCell(urls[0], index: 0)
                    imageCell(urls[1], index: 1)
                }
            } else if urls.count == 3 {
                HStack(spacing: 4) {
                    imageCell(urls[0], index: 0)
                    VStack(spacing: 4) {
                        imageCell(urls[1], index: 1)
                        imageCell(urls[2], index: 2)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        imageCell(urls[0], index: 0)
                        imageCell(urls[1], index: 1)
                    }
                    HStack(spacing: 4) {
                        imageCell(urls[2], index: 2)
                        imageCell(urls[3], index: 3)
                    }
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func imageCell(_ urlString: String, index: Int) -> some View {
        // 土台は Color (intrinsic size 無し) → 親 (HStack/VStack の分配サイズ) に
        // 完全追従。CachedAsyncImage は overlay として土台のサイズに収まり、
        // .clipped() が画像のはみ出しを防ぐ。これでカードが画像幅で広がらない。
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

    // MARK: Quote

    private func quoteBlock(_ quote: QuotedPostInfo) -> some View {
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

    // MARK: Engage row (view / comment / heart / repost / bookmark)

    private var engageRow: some View {
        // 非公開投稿は引用・リポスト不可（匿名投稿はOK — PostDetail と同条件）
        let canRepost = !(post.authorIsPrivate == true && !post.isAnonymous)
        let combinedRepostCount = localRepostCount + localQuoteCount

        return HStack(spacing: 0) {
            // インプレッション（閲覧数）— タップ不可・表示のみ
            engageItem(
                icon: "chart.bar",
                count: post.viewCount,
                isActive: false
            ) {}
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)

            // コメント
            engageItem(icon: "bubble.left", count: localReplyCount, isActive: false) {
                onTap()
            }
            .frame(maxWidth: .infinity)

            // ハート
            engageItem(
                icon: isLiked ? "heart.fill" : "heart",
                count: localHeartCount,
                isActive: isLiked,
                heartBurst: showHeartBurst
            ) {
                HapticManager.light()
                guard authService.hasRealAccount else {
                    onRequireSignIn?()
                    return
                }
                Task { await toggleHeart() }
            }
            .frame(maxWidth: .infinity)

            // リポスト / 引用 — 非公開投稿は非表示
            if canRepost {
                Menu {
                    Button {
                        HapticManager.light()
                        guard authService.hasRealAccount else {
                            onRequireSignIn?()
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
                            onRequireSignIn?()
                            return
                        }
                        AnalyticsManager.shared.track("post_quote_initiate", properties: ["postId": post.id])
                        onQuote?(QuotedPostInfo.from(post))
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
                icon: bookmarkService.isBookmarked(post.id) ? "bookmark.fill" : "bookmark",
                count: localBookmarkCount > 0 ? localBookmarkCount : nil,
                isActive: bookmarkService.isBookmarked(post.id)
            ) {
                HapticManager.light()
                guard authService.hasRealAccount else {
                    onRequireSignIn?()
                    return
                }
                let wasBookmarked = bookmarkService.isBookmarked(post.id)
                bookmarkService.toggle(post.id)
                let delta = wasBookmarked ? -1 : 1
                localBookmarkCount = max(0, localBookmarkCount + delta)
                Task {
                    await firestoreService.incrementBookmarkCount(postId: post.id, delta: delta)
                    BoardPostMutationBus.postBookmark(
                        .init(postId: post.id, isBookmarked: !wasBookmarked, bookmarkCount: localBookmarkCount)
                    )
                    // 新規にブックマークした時のみ通知
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
                    HeartBurstView { }
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

    private func toggleHeart() async {
        guard let userId = authService.currentUser?.id else { return }
        let wasLiked = isLiked
        isLiked.toggle()
        localHeartCount += isLiked ? 1 : -1
        if isLiked { showHeartBurst = true }
        do {
            try await firestoreService.toggleReaction(postId: post.id, userId: userId, reactionType: "heart")
            if isLiked {
                let reactorName = authService.currentUser?.displayName ?? "ユーザー"
                try? await firestoreService.createReactionNotification(
                    postAuthorId: post.authorId,
                    postId: post.id,
                    reactorName: reactorName
                )
            }
            // Firestore 書き込み成功後のみブロードキャスト（失敗時は送信しない）
            var counts = post.reactionCounts
            counts["heart"] = localHeartCount
            BoardPostMutationBus.postReaction(
                .init(postId: post.id, myReaction: isLiked ? "heart" : nil, counts: counts)
            )
        } catch {
            isLiked = wasLiked
            localHeartCount = post.reactionCounts["heart"] ?? 0
        }
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
            // 結果と同期
            isRepostedByMe = nowReposted
            // サーバー側の最新カウントを読み戻して broadcast 値の精度を確保
            // (他ユーザーが同時にリポストしている場合、increment(1)されたサーバー値は
            //  自分のlocalRepostCount + 1とは異なる)
            let serverCount = (try? await firestoreService.fetchPost(postId: post.id))?.repostCount ?? localRepostCount
            localRepostCount = serverCount
            AnalyticsManager.shared.track("post_repost", properties: ["postId": post.id])
            BoardPostMutationBus.postRepost(
                .init(postId: post.id, isRepostedByMe: nowReposted, repostCount: serverCount)
            )
            // 通知 (新規にリポストした時のみ)
            if nowReposted {
                let reposterName = authService.currentUser?.displayName ?? "ユーザー"
                try? await firestoreService.createRepostNotification(
                    postAuthorId: post.authorId,
                    postId: post.id,
                    reposterName: reposterName
                )
            }
        } catch {
            // ロールバック
            isRepostedByMe = wasReposted
            localRepostCount = post.repostCount
        }
    }
}

// MARK: - Board Feed Poll Bars (Figma: 横長プログレスバー)

struct BoardFeedPollBars: View {
    let postId: String
    let options: [PollOption]
    let totalVotes: Int

    @StateObject private var authService = BoardAuthService.shared
    @State private var myVote: String?
    @State private var localOptions: [PollOption] = []
    @State private var localTotalVotes: Int = 0
    @State private var didLoadVote = false
    @State private var isVoting = false
    @State private var showSignIn = false

    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        let hasVoted = myVote != nil
        return VStack(spacing: 6) {
            ForEach(Array(localOptions.enumerated()), id: \.element.id) { _, option in
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
                            // 未投票時はグレー、投票後は薄ピンク
                            .fill(hasVoted ? BoardFeedPalette.barBgPink : BoardFeedPalette.pollInactiveBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 21)
                                    .stroke(
                                        hasVoted ? BoardFeedPalette.borderPink : Color.clear,
                                        lineWidth: 0.5
                                    )
                            )
                            .frame(height: 34)

                        // 進捗バー塗り: 投票済みの場合のみ表示（ピンク）
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
                            // 投票済みの場合のみパーセンテージを表示
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
        .task {
            if !didLoadVote {
                localOptions = options
                localTotalVotes = totalVotes
                if let userId = authService.currentUser?.id {
                    myVote = try? await firestoreService.fetchMyVote(postId: postId, userId: userId)
                }
                didLoadVote = true
            }
        }
        .onChange(of: options) { newOptions in
            if !isVoting { localOptions = newOptions }
        }
        .onChange(of: totalVotes) { newTotal in
            if !isVoting { localTotalVotes = newTotal }
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostPollVoted)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.PollVotePayload,
                  payload.postId == postId else { return }
            guard !isVoting else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                myVote = payload.myVote
                localOptions = payload.options
                localTotalVotes = payload.totalVotes
            }
        }
        .sheet(isPresented: $showSignIn) {
            BoardSignInView()
        }
    }

    private func castVote(optionId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        isVoting = true
        let oldVote = myVote
        let oldOptions = localOptions
        let oldTotal = localTotalVotes
        withAnimation(.easeOut(duration: 0.2)) {
            if let oldId = oldVote, let idx = localOptions.firstIndex(where: { $0.id == oldId }) {
                localOptions[idx] = PollOption(id: oldId, text: localOptions[idx].text, voteCount: max(0, localOptions[idx].voteCount - 1))
            }
            if let idx = localOptions.firstIndex(where: { $0.id == optionId }) {
                localOptions[idx] = PollOption(id: optionId, text: localOptions[idx].text, voteCount: localOptions[idx].voteCount + 1)
            }
            if oldVote == nil { localTotalVotes += 1 }
            myVote = optionId
        }
        do {
            try await firestoreService.vote(postId: postId, userId: userId, optionId: optionId)
            // Firestore 書き込み成功後のみブロードキャスト
            BoardPostMutationBus.postPollVote(
                .init(postId: postId, myVote: myVote, options: localOptions, totalVotes: localTotalVotes)
            )
        } catch {
            HapticManager.error()
            withAnimation {
                myVote = oldVote
                localOptions = oldOptions
                localTotalVotes = oldTotal
            }
        }
        isVoting = false
    }
}

// MARK: - Board Feed Time Formatter

enum BoardFeedTimeFormatter {
    /// Figma表記「5分」「2時間」「3日」（"前"を付けない短縮形）
    static func shortTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return String(localized: "たった今", bundle: LanguageManager.appBundle)
        } else if interval < 3600 {
            return String(localized: "\(Int(interval / 60))分", bundle: LanguageManager.appBundle)
        } else if interval < 86400 {
            return String(localized: "\(Int(interval / 3600))時間", bundle: LanguageManager.appBundle)
        } else if interval < 86400 * 7 {
            return String(localized: "\(Int(interval / 86400))日", bundle: LanguageManager.appBundle)
        } else {
            let f = DateFormatter()
            f.locale = Locale(identifier: LanguageManager.resolvedLanguage)
            f.dateFormat = "M/d"
            return f.string(from: date)
        }
    }
}

// MARK: - Post Card

struct BoardPostCard: View {
    let post: BoardPost
    let onTap: () -> Void
    var onAuthorTap: ((String) -> Void)? = nil
    var onQuote: ((QuotedPostInfo) -> Void)? = nil
    @StateObject private var authService = BoardAuthService.shared
    @StateObject private var bookmarkService = BoardBookmarkService.shared
    @State private var isLiked = false
    @State private var localHeartCount: Int = 0
    @State private var localReplyCount: Int = 0
    @State private var showSignIn = false
    @State private var quotedPostDetail: BoardPost?
    @State private var showHeartBurst = false
    @State private var showImageViewer = false
    @State private var selectedImageIndex = 0

    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 投稿タイプタグ
            if post.postType != .normal {
                HStack(spacing: 4) {
                    Image(systemName: post.postType.icon)
                        .font(.system(size: 10))
                    Text(post.postType.localizedName)
                        .font(MeloFonts.zenMaruOrFallback(10))
                }
                .foregroundColor(MeloColors.Dark.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(MeloColors.Dark.bgElevated)
                )
            }

            // Twitter/X風レイアウト: アバター左 + コンテンツ右
            HStack(alignment: .top, spacing: 10) {
                // アバター
                Button {
                    if !post.isAnonymous { onAuthorTap?(post.authorId) }
                } label: {
                    if post.isAnonymous {
                        Image(AnonymousAvatarPicker.imageName(forSeed: post.id))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(MeloColors.Dark.bgElevated))
                            .clipShape(Circle())
                    } else if let urlString = post.authorProfileImageURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [BoardColors.accentLight.opacity(0.5), BoardColors.accent.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(post.authorDisplayName.prefix(1)))
                                        .font(MeloFonts.zenMaruOrFallback(14))
                                        .foregroundColor(BoardColors.accent)
                                )
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BoardColors.accentLight.opacity(0.5), BoardColors.accent.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(post.authorDisplayName.prefix(1)))
                                    .font(MeloFonts.zenMaruOrFallback(14))
                                    .foregroundColor(BoardColors.accent)
                            )
                    }
                }
                .buttonStyle(.plain)

                // コンテンツ（ユーザー名の下に本文・画像・引用等）
                VStack(alignment: .leading, spacing: 8) {
                    // ヘッダー: 名前 + バッジ + 時間
                    HStack(spacing: 4) {
                        if post.authorIsPrivate == true && !post.isAnonymous {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(BoardColors.textTertiary)
                        }
                        Text(post.authorDisplayName)
                            .font(MeloFonts.zenMaruOrFallback(14))
                            .fontWeight(.bold)
                            .foregroundColor(BoardColors.textPrimary)

                        if let badge = post.authorBadge {
                            Text(badge.typeCode)
                                .font(MeloFonts.zenMaruOrFallback(10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(MeloColors.mbtiColor(for: badge.typeCode))
                                )
                        }

                        Text("· \(BoardTimeFormatter.timeAgo(post.createdAt))")
                            .font(MeloFonts.zenMaruOrFallback(12))
                            .foregroundColor(BoardColors.textTertiary)

                        Spacer()
                    }

                    // テーマピル (MBTI バッジと同じ行に並ぶ小さいピンクピル)
                    if !post.themes.isEmpty {
                        HStack(spacing: 5) {
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
                    }

                    // 本文
                    Text(post.content)
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(BoardColors.textPrimary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 画像グリッド（X風の大きな表示）
                    if !post.imageURLs.isEmpty {
                        postImageGrid
                    }

                    // 診断カード（詳細表示）
                    if let card = post.diagnosisCard {
                        BoardDiagnosisCardExpanded(card: card)
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
                                    .fill(BoardColors.accent.opacity(0.4))
                                    .frame(width: 3)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(quote.authorDisplayName)
                                        .font(MeloFonts.zenMaruMedium(10))
                                        .foregroundColor(BoardColors.textSecondary)

                                    Text(quote.content)
                                        .font(MeloFonts.zenMaruOrFallback(12))
                                        .foregroundColor(BoardColors.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(MeloColors.Dark.bgElevated)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // 投票選択肢（インタラクティブ）
                    if let options = post.pollOptions, !options.isEmpty {
                        BoardPollInteractive(
                            postId: post.id,
                            options: options,
                            totalVotes: post.totalVotes
                        )
                    }

                    // フッター: 閲覧数 → 引用 → コメント → ハート
                    HStack(spacing: 0) {
                // 閲覧数
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 12))
                        .foregroundColor(BoardColors.textTertiary.opacity(0.7))
                    Text(verbatim: "\(post.viewCount)")
                        .font(MeloFonts.zenMaruOrFallback(12))
                        .foregroundColor(BoardColors.textTertiary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 引用ボタン（非公開アカウントの投稿は引用不可、匿名は除外）
                if !(post.authorIsPrivate == true && !post.isAnonymous) {
                    Button {
                        HapticManager.light()
                        guard authService.hasRealAccount else {
                            showSignIn = true
                            return
                        }
                        onQuote?(QuotedPostInfo.from(post))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.2.squarepath")
                                .font(.system(size: 13))
                            if post.quoteCount > 0 {
                                Text("\(post.quoteCount)")
                                    .font(MeloFonts.zenMaruOrFallback(12))
                            }
                        }
                        .foregroundColor(BoardColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }

                // コメント数
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 13))
                        .foregroundColor(BoardColors.textTertiary)
                    Text("\(localReplyCount)")
                        .font(MeloFonts.zenMaruOrFallback(12))
                        .foregroundColor(BoardColors.textTertiary)
                }
                .frame(maxWidth: .infinity)

                // ハートボタン
                Button {
                    HapticManager.light()
                    guard authService.hasRealAccount else {
                        showSignIn = true
                        return
                    }
                    Task { await toggleHeart() }
                } label: {
                    HStack(spacing: 4) {
                        ZStack {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundColor(isLiked ? BoardColors.accent : BoardColors.textTertiary)
                                .scaleEffect(isLiked ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isLiked)

                            if showHeartBurst {
                                HeartBurstView {
                                    showHeartBurst = false
                                }
                            }
                        }
                        .frame(width: 20, height: 20)
                        Text("\(localHeartCount)")
                            .font(MeloFonts.zenMaruOrFallback(12))
                            .foregroundColor(isLiked ? BoardColors.accent : BoardColors.textTertiary)
                            .animation(.none, value: isLiked)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // ブックマーク
                Button {
                    HapticManager.light()
                    bookmarkService.toggle(post.id)
                } label: {
                    Image(systemName: bookmarkService.isBookmarked(post.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundColor(bookmarkService.isBookmarked(post.id) ? BoardColors.accent : BoardColors.textTertiary)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bookmarkService.isBookmarked(post.id))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.top, 4)
                } // end content VStack
            } // end HStack (avatar + content)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(MeloColors.Dark.bg)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            localHeartCount = post.reactionCounts["heart"] ?? 0
            localReplyCount = post.replyCount
        }
        .task {
            guard let userId = authService.currentUser?.id else { return }
            isLiked = (try? await firestoreService.fetchMyReaction(postId: post.id, userId: userId)) == "heart"
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostReactionChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.ReactionPayload,
                  payload.postId == post.id else { return }
            isLiked = (payload.myReaction == "heart")
            localHeartCount = payload.counts["heart"] ?? localHeartCount
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostReplyCountChanged)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.ReplyCountPayload,
                  payload.postId == post.id else { return }
            localReplyCount = payload.replyCount
        }
        .sheet(isPresented: $showSignIn) {
            BoardSignInView()
        }
        .sheet(item: $quotedPostDetail) { quotedPost in
            BoardPostDetailView(post: quotedPost)
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            FullscreenImageViewer(
                imageURLs: post.imageURLs,
                selectedIndex: $selectedImageIndex,
                isPresented: $showImageViewer
            )
        }
    }

    // MARK: - Image Grid (X-style)

    private var postImageGrid: some View {
        let urls = Array(post.imageURLs.prefix(4))
        let count = urls.count

        return Group {
            if count == 1 {
                postImageCell(urls[0], height: 200, index: 0)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if count == 2 {
                HStack(spacing: 4) {
                    postImageCell(urls[0], height: 180, index: 0)
                    postImageCell(urls[1], height: 180, index: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if count == 3 {
                HStack(spacing: 4) {
                    postImageCell(urls[0], height: 200, index: 0)
                    VStack(spacing: 4) {
                        postImageCell(urls[1], height: 98, index: 1)
                        postImageCell(urls[2], height: 98, index: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        postImageCell(urls[0], height: 120, index: 0)
                        postImageCell(urls[1], height: 120, index: 1)
                    }
                    HStack(spacing: 4) {
                        postImageCell(urls[2], height: 120, index: 2)
                        postImageCell(urls[3], height: 120, index: 3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func postImageCell(_ urlString: String, height: CGFloat, index: Int) -> some View {
        // GeometryReader を避ける(スクロール中のセル再測定で横揺れの原因になる)。
        CachedAsyncImage(url: URL(string: urlString)) {
            Rectangle()
                .fill(MeloColors.Dark.bgElevated)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            selectedImageIndex = index
            showImageViewer = true
        }
    }

    private func toggleHeart() async {
        guard let userId = authService.currentUser?.id else { return }

        let wasLiked = isLiked
        // 楽観的更新
        isLiked.toggle()
        localHeartCount += isLiked ? 1 : -1
        if isLiked { showHeartBurst = true }

        do {
            try await firestoreService.toggleReaction(postId: post.id, userId: userId, reactionType: "heart")
            // いいね時のみ通知（取り消し時は不要）
            if isLiked {
                let reactorName = authService.currentUser?.displayName ?? "ユーザー"
                try? await firestoreService.createReactionNotification(
                    postAuthorId: post.authorId,
                    postId: post.id,
                    reactorName: reactorName
                )
            }
            // Firestore 書き込み成功後のみブロードキャスト
            var counts = post.reactionCounts
            counts["heart"] = localHeartCount
            BoardPostMutationBus.postReaction(
                .init(postId: post.id, myReaction: isLiked ? "heart" : nil, counts: counts)
            )
        } catch {
            // ロールバック
            isLiked = wasLiked
            localHeartCount = post.reactionCounts["heart"] ?? 0
        }
    }
}

// MARK: - Expanded Diagnosis Card (for Feed)
struct BoardDiagnosisCardExpanded: View {
    let card: DiagnosisCard

    var body: some View {
        Group {
            switch card.cardStyle {
            case .toxicity:
                ToxicityVerdictCardView(card: card)
            case .type:
                wrappedCard { typeCard }
            case .loveWords:
                wrappedCard { loveWordsCard }
            default:
                if card.hasToxicityData {
                    ToxicityVerdictCardView(card: card)
                } else {
                    wrappedCard { scoreCard }
                }
            }
        }
    }

    /// 旧 lovetalk カード用の角丸チェース。毒性カードは自前の LabCard 枠を持つので適用しない。
    @ViewBuilder
    private func wrappedCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(BoardFeedPalette.cardBorderGray, lineWidth: 1)
                )
        )
    }

    // MARK: - Score Card（新診断デザイン: 相性メッセージ + グレード画像 + 4軸バー）

    private var scoreCard: some View {
        VStack(alignment: .center, spacing: 10) {
            // 関係性ラベル + MBTI (任意)
            if card.relationshipLabel != nil || !card.effectivePartnerMBTIs.isEmpty {
                HStack(spacing: 4) {
                    if let label = card.relationshipLabel {
                        Text(label)
                            .font(MeloFonts.zenMaruOrFallback(12))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    }
                    if card.relationshipLabel != nil && !card.effectivePartnerMBTIs.isEmpty {
                        Text("-")
                            .font(MeloFonts.zenMaruRegular(12))
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

            // 相性メッセージ (3色分け、スコア帯に応じて変化)
            compatibilityHeadline

            // メイン: グレード画像 + 点数 + 4軸バー
            HStack(alignment: .center, spacing: 14) {
                Image(gradeImageName(for: card.totalScore))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(card.totalScore)")
                            .font(MeloFonts.jerseyOrFallback(40))
                            .foregroundColor(MeloColors.Dark.accent)
                            .tracking(-1.0)
                        Text(String(localized: "点", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(12))
                            .foregroundColor(MeloColors.Dark.accent)
                    }

                    VStack(spacing: 4) {
                        scoreAxisBar(label: String(localized: "トーク量", bundle: LanguageManager.appBundle), score: card.balanceScore)
                        scoreAxisBar(label: String(localized: "会話テンション", bundle: LanguageManager.appBundle), score: card.tensionScore)
                        scoreAxisBar(label: String(localized: "返信ペース", bundle: LanguageManager.appBundle), score: card.responseScore)
                        scoreAxisBar(label: String(localized: "思いやり度", bundle: LanguageManager.appBundle), score: card.wordScore)
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
            .font(MeloFonts.zenMaruOrFallback(16))
            .tracking(0.48)
            .multilineTextAlignment(.center)
    }

    /// スコア帯 → 相性メッセージ (新診断結果ページと同じ閾値: 90/70/50/30)
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

    /// スコア帯 → グレード画像名 (A〜E、main ブランチ準拠: 80/60/40/20)
    private func gradeImageName(for total: Int) -> String {
        switch total {
        case 80...:    return "result_grade_a"
        case 60..<80:  return "result_grade_b"
        case 40..<60:  return "result_grade_c"
        case 20..<40:  return "result_grade_d"
        default:       return "result_grade_e"
        }
    }

    private func scoreAxisBar(label: String, score: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(MeloFonts.zenMaruOrFallback(9))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 64, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MeloColors.Dark.track)
                    Capsule()
                        .fill(MeloColors.Dark.accentGradient)
                        .frame(width: geo.size.width * CGFloat(min(score, 100)) / 100)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Type Card（マスコット画像＋説明）

    private var typeCard: some View {
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
                .font(MeloFonts.zenMaruOrFallback(20))
                .foregroundColor(MeloColors.Dark.accent)
                .multilineTextAlignment(.center)

            // マスコット画像 (古い投稿でも typeCode から最新アセット名を引き直す)
            if let imageName = card.localizedTypeImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
            }

            // 説明文（フィードでは途中で途切れる）
            if let desc = card.localizedTypeDescription {
                Text(desc)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Love Words Card（愛情表現 — フィードではカウントのみ）

    private var loveWordsCard: some View {
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
        }
    }
}

// MARK: - Mini Diagnosis Card (reused across Board views)

struct BoardDiagnosisCardMini: View {
    let card: DiagnosisCard

    var body: some View {
        Group {
            switch card.cardStyle {
            case .toxicity:
                ToxicityVerdictCardView(card: card, compact: true)
            case .type:
                typeMiniCard
                    .padding(12)
                    .background(miniBackground)
            case .loveWords:
                loveWordsMiniCard
                    .padding(12)
                    .background(miniBackground)
            default:
                if card.hasToxicityData {
                    ToxicityVerdictCardView(card: card, compact: true)
                } else {
                    scoreMiniCard
                        .padding(12)
                        .background(miniBackground)
                }
            }
        }
    }

    /// 旧 lovetalk ミニカード用の背景。毒性カードは LabCard 枠を持つので適用しない。
    private var miniBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(MeloColors.Dark.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BoardColors.accent.opacity(0.15), lineWidth: 1)
            )
    }

    // Score style (default)
    private var scoreMiniCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.typeName)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .foregroundColor(BoardColors.textPrimary)

                Text(String(localized: "総合スコア", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruRegular(10))
                    .foregroundColor(BoardColors.textTertiary)
            }

            Spacer()

            Text("\(card.totalScore)")
                .font(MeloFonts.jerseyOrFallback(28))
                .foregroundStyle(MeloColors.Dark.accentGradient)
        }
    }

    // Type style
    private var typeMiniCard: some View {
        HStack(spacing: 10) {
            if let imageName = card.localizedTypeImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.localizedTypeName)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .foregroundColor(BoardColors.textPrimary)

                if let tagline = card.localizedTypeTagline {
                    Text(tagline)
                        .font(MeloFonts.zenMaruRegular(10))
                        .foregroundColor(BoardColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(card.typeCode)
                .font(MeloFonts.zenMaruOrFallback(11))
                .foregroundColor(BoardColors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(MeloColors.Dark.bgElevated)
                )
        }
    }

    // Love words style
    private var loveWordsMiniCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(BoardColors.accent)
                    Text(String(localized: "愛情表現", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(12))
                        .foregroundColor(BoardColors.textPrimary)

                    if let label = card.relationshipLabel {
                        Text("· \(label)")
                            .font(MeloFonts.zenMaruRegular(10))
                            .foregroundColor(BoardColors.textTertiary)
                    }
                }

                if let words = card.selfLoveWords?.prefix(3), !words.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(words)) { w in
                            Text(w.phrase)
                                .font(MeloFonts.zenMaruRegular(10))
                                .foregroundColor(MeloColors.Dark.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(MeloColors.Dark.bgElevated)
                                )
                        }
                    }
                }
            }

            Spacer()

            if let total = card.selfLoveTotal, let partnerTotal = card.partnerLoveTotal {
                VStack(spacing: 1) {
                    Text("\(total + partnerTotal)")
                        .font(MeloFonts.jerseyOrFallback(22))
                        .foregroundColor(BoardColors.accent)
                    Text(String(localized: "回", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruRegular(8))
                        .foregroundColor(BoardColors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Interactive Poll (Feed Card)

struct BoardPollInteractive: View {
    let postId: String
    let options: [PollOption]
    let totalVotes: Int

    @StateObject private var authService = BoardAuthService.shared
    @State private var myVote: String?
    @State private var localOptions: [PollOption] = []
    @State private var localTotalVotes: Int = 0
    @State private var isVoting = false
    @State private var showSignIn = false
    @State private var didLoadVote = false
    @State private var voteError = false

    private let firestoreService = BoardFirestoreService.shared
    private let accentPink = MeloColors.Dark.accent

    private var maxVoteCount: Int {
        localOptions.map(\.voteCount).max() ?? 0
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(localOptions.enumerated()), id: \.element.id) { index, option in
                let percentage = localTotalVotes > 0 ? Double(option.voteCount) / Double(localTotalVotes) : 0
                let isMyVote = myVote == option.id
                let hasVoted = myVote != nil
                let isMostPopular = hasVoted && option.voteCount == maxVoteCount && maxVoteCount > 0

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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(MeloColors.Dark.track)
                            .frame(height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isMyVote ? accentPink.opacity(0.6) : Color.clear, lineWidth: 2)
                            )

                        if hasVoted {
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isMostPopular ? accentPink.opacity(0.35) : MeloColors.Dark.bgElevated)
                                    .frame(width: geo.size.width * max(percentage, 0.02))
                            }
                            .frame(height: 36)
                        }

                        HStack {
                            if isMyVote {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(accentPink)
                            }

                            Text(option.text)
                                .font(MeloFonts.zenMaruOrFallback(14))
                                .foregroundColor(BoardColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if hasVoted {
                                HStack(spacing: 3) {
                                    Text("\(option.voteCount)")
                                        .font(MeloFonts.zenMaruOrFallback(10))
                                        .foregroundColor(BoardColors.textSecondary)
                                    Text("\(Int(percentage * 100))%")
                                        .font(MeloFonts.zenMaruOrFallback(11))
                                        .foregroundColor(isMostPopular ? accentPink : BoardColors.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text(String(localized: "\(localTotalVotes)票", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(10))
                    .foregroundColor(BoardColors.textTertiary)
                Spacer()
                if voteError {
                    Text(String(localized: "投票に失敗しました", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruRegular(10))
                        .foregroundColor(MeloColors.Status.error)
                        .transition(.opacity)
                }
            }
        }
        .task {
            // 初回のみ: Firestoreから自分の投票を読み込んでからオプションをセット
            if !didLoadVote {
                localOptions = options
                localTotalVotes = totalVotes
                if let userId = authService.currentUser?.id {
                    myVote = try? await firestoreService.fetchMyVote(postId: postId, userId: userId)
                }
                didLoadVote = true
            }
        }
        .onChange(of: options) { newOptions in
            // 投票中でなければ親データの更新を反映（Firestoreリスナー経由）
            if !isVoting {
                localOptions = newOptions
            }
        }
        .onChange(of: totalVotes) { newTotal in
            if !isVoting {
                localTotalVotes = newTotal
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardPostPollVoted)) { note in
            guard let payload = note.userInfo?["payload"] as? BoardPostMutationBus.PollVotePayload,
                  payload.postId == postId else { return }
            guard !isVoting else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                myVote = payload.myVote
                localOptions = payload.options
                localTotalVotes = payload.totalVotes
            }
        }
        .sheet(isPresented: $showSignIn) {
            BoardSignInView()
        }
    }

    private func castVote(optionId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        isVoting = true

        let oldVote = myVote
        let oldOptions = localOptions
        let oldTotal = localTotalVotes

        // 楽観的更新
        withAnimation(.easeOut(duration: 0.2)) {
            if let oldId = oldVote, let idx = localOptions.firstIndex(where: { $0.id == oldId }) {
                localOptions[idx] = PollOption(id: oldId, text: localOptions[idx].text, voteCount: max(0, localOptions[idx].voteCount - 1))
            }
            if let idx = localOptions.firstIndex(where: { $0.id == optionId }) {
                localOptions[idx] = PollOption(id: optionId, text: localOptions[idx].text, voteCount: localOptions[idx].voteCount + 1)
            }
            if oldVote == nil { localTotalVotes += 1 }
            myVote = optionId
        }

        do {
            try await firestoreService.vote(postId: postId, userId: userId, optionId: optionId)
            // Firestore 書き込み成功後のみブロードキャスト
            BoardPostMutationBus.postPollVote(
                .init(postId: postId, myVote: myVote, options: localOptions, totalVotes: localTotalVotes)
            )
        } catch {
            print("[BoardPoll] Vote error: \(error)")
            HapticManager.error()
            // ロールバック
            withAnimation {
                myVote = oldVote
                localOptions = oldOptions
                localTotalVotes = oldTotal
                voteError = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { voteError = false }
            }
        }

        isVoting = false
    }
}

// MARK: - Profile Sheet Target

struct ProfileSheetTarget: Identifiable {
    let id = UUID()
    let userId: String?  // nil = 自分のプロフィール
}

// MARK: - Time Formatter

enum BoardTimeFormatter {
    static func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return String(localized: "たった今", bundle: LanguageManager.appBundle)
        } else if interval < 3600 {
            return String(localized: "\(Int(interval / 60))分前", bundle: LanguageManager.appBundle)
        } else if interval < 86400 {
            return String(localized: "\(Int(interval / 3600))時間前", bundle: LanguageManager.appBundle)
        } else {
            return String(localized: "\(Int(interval / 86400))日前", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - FAB Button Style

private struct ScaleFABStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    BoardFeedView()
}
