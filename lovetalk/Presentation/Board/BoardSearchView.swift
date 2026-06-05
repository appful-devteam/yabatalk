import SwiftUI

// 旧 SearchTab enum は廃止 (ユーザー検索タブ削除のため)。投稿のみの検索画面になっている。

// MARK: - Search Palette (NewHome / NewFeed tokens)

private enum BoardSearchPalette {
    static let accentPink = MeloColors.Brand.pink          // メインピンク（アクセント / ストローク）
    static let accentPinkSoft = MeloColors.Brand.pink      // チップ選択塗り
    static let highlightPink = MeloColors.Brand.pinkLight       // ハイライト
    static let headerBg = MeloColors.Surface.pinkPale            // ヘッダー背景
    static let softBg = MeloColors.Surface.pinkPale              // チップ未選択背景 / エンプティ背景
    static let softBgAlt = MeloColors.Surface.pinkPale           // ソフトピンク代替
    static let textPrimary = MeloColors.Text.primary         // 本文
    static let textMuted = MeloColors.Text.secondary           // ミュート
    static let placeholder = MeloColors.Text.secondary         // プレースホルダ
    static let strokeBrown = MeloColors.Text.primary         // ブラウンストローク
    static let divider = MeloColors.Gray.subButtonLight             // ディバイダ
}

// MARK: - Board Search View
struct BoardSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var postResults: [BoardPost] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var selectedPost: BoardPost?
    @State private var profileTarget: ProfileSheetTarget?
    @FocusState private var isSearchFocused: Bool

    /// 初期表示時に既に文字列が入った状態で開く (= ハッシュタグタップから遷移する場合に使用)。
    private let initialQuery: String?

    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
    }

    @StateObject private var authService = BoardAuthService.shared
    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                searchBar

                // 結果 (投稿のみ。ユーザー検索タブは廃止)
                if isSearching {
                    loadingState
                } else if !hasSearched {
                    searchPlaceholder
                } else if postResults.isEmpty {
                    emptyResults(
                        message: String(localized: "投稿が見つかりませんでした", bundle: LanguageManager.appBundle),
                        assetName: "char_meromaru_3d"
                    )
                } else {
                    resultsList
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedPost) { post in
                BoardPostDetailView(post: post)
            }
            .sheet(item: $profileTarget) { target in
                BoardProfileView(userId: target.userId)
            }
        }
        .onAppear {
            if let initial = initialQuery, !initial.isEmpty, searchText.isEmpty {
                searchText = initial
                performSearch()
            } else {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            // 閉じるボタン：白丸 + ピンクストローク + ピンクシェブロン
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 37, height: 37)
                        .overlay(
                            Circle().stroke(BoardSearchPalette.accentPink, lineWidth: 1)
                        )
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BoardSearchPalette.accentPink)
                }
            }
            .buttonStyle(.plain)

            // 白い Pill + ピンクストローク
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BoardSearchPalette.accentPink)

                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text(String(localized: "キーワードで検索", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .tracking(0.36)
                            .foregroundColor(BoardSearchPalette.placeholder)
                    }
                    TextField("", text: $searchText)
                        .font(MeloFonts.zenMaruMedium(14))
                        .tracking(0.36)
                        .foregroundColor(BoardSearchPalette.textPrimary)
                        .tint(BoardSearchPalette.accentPink)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        postResults = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(BoardSearchPalette.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(
                        Capsule().stroke(BoardSearchPalette.accentPink, lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(BoardSearchPalette.headerBg)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .tint(BoardSearchPalette.accentPink)
                .scaleEffect(1.1)
            Text(String(localized: "けんさくちゅう…", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(12))
                .tracking(0.36)
                .foregroundColor(BoardSearchPalette.textMuted)
            Spacer()
        }
    }

    // MARK: - Placeholder (initial state)

    private var searchPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("char_meromaru_3d")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 112)

            Text(String(localized: "投稿やユーザーを検索", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(13))
                .tracking(0.36)
                .foregroundColor(BoardSearchPalette.strokeBrown)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty Results

    private func emptyResults(message: String, assetName: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(BoardSearchPalette.softBg)
                    .frame(width: 180, height: 180)
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 112)
            }

            Text(message)
                .font(MeloFonts.zenMaruMedium(13))
                .tracking(0.36)
                .foregroundColor(BoardSearchPalette.strokeBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                sectionHeader(String(localized: "投稿", bundle: LanguageManager.appBundle))
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                ForEach(postResults) { post in
                    BoardFeedPostCard(
                        post: post,
                        // ホームフィードと同じ余白で表示
                        horizontalPadding: MeloLayout.boardPostHorizontalPadding,
                        onTap: {
                            selectedPost = post
                        },
                        onAuthorTap: { authorId in
                            profileTarget = ProfileSheetTarget(userId: authorId)
                        },
                        onQuote: nil,
                        onRequireSignIn: nil
                    )
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(MeloFonts.zenMaruMedium(12))
            .tracking(0.36)
            .foregroundColor(BoardSearchPalette.accentPink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Search Action

    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        hasSearched = true
        isSearchFocused = false

        Task {
            // フォロー中のIDを取得して非公開アカウントのフィルタに使用
            var followingIds: Set<String> = []
            if let userId = authService.currentUser?.id {
                followingIds = (try? await firestoreService.getFollowingIds(userId: userId)) ?? []
            }

            let posts = (try? await firestoreService.searchPosts(query: trimmed, followingIds: followingIds, userLanguage: LanguageManager.resolvedLanguage)) ?? []

            withAnimation(.easeOut(duration: 0.2)) {
                postResults = posts
                isSearching = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BoardSearchView()
}
