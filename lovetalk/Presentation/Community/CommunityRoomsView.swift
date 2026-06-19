import SwiftUI

// MARK: - Palette (Figma node 576:334)

private enum RoomsPalette {
    static let headerBackground = MeloColors.Dark.bg          // ダーク: 画面背景（黒）
    static let headerBorder = MeloColors.Dark.cardStroke          // 下 border（暗い枠）
    static let koiPink = MeloColors.Dark.accent             // アクセント（選択タブ・参加ボタン）
    static let joinedPinkBg = MeloColors.Dark.bgElevated          // 参加中ボタン背景（暗い面）
    static let pillBorder = MeloColors.Dark.cardStroke           // 非選択タブの枠
    static let bodyText = MeloColors.Dark.textPrimary         // メインテキスト
    static let subText = MeloColors.Dark.textSecondary          // サブ / キャプション
    static let cardBorder = MeloColors.Dark.cardStroke          // カード枠
    static let imagePlaceholder = MeloColors.Dark.textSecondary // 画像プレースホルダ
    static let shadow = Color.black.opacity(0.3)
    static let searchButtonBg = MeloColors.Dark.bgElevated       // 検索ボタン背景
    static let searchFieldBorder = MeloColors.Dark.cardStroke    // 検索フィールド枠
}

// MARK: - Focus

private enum RoomsSearchField: Hashable {
    case search
}

// MARK: - Main View

struct CommunityRoomsView: View {
    @StateObject private var viewModel: CommunityRoomsViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    var onRoomTap: ((CommunityRoom) -> Void)? = nil
    var onCompose: (() -> Void)? = nil

    @State private var isSearching: Bool = false
    @State private var showingCreateSheet: Bool = false
    @FocusState private var focusedField: RoomsSearchField?

    init(
        viewModel: CommunityRoomsViewModel = CommunityRoomsViewModel(),
        onRoomTap: ((CommunityRoom) -> Void)? = nil,
        onCompose: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onRoomTap = onRoomTap
        self.onCompose = onCompose
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            body_
        }
        .background(MeloColors.Dark.bg.ignoresSafeArea())
        .navigationDestination(for: CommunityRoom.self) { room in
            // 一覧 VM を詳細へ渡し、オーナーの削除 / ブロック操作を
            // そのまま一覧に反映できるようにする。
            CommunityRoomDetailView(room: room, roomsViewModel: viewModel)
        }
        // 相談部屋は read/write 共に匿名認証が必須（Firestore ルール）。
        // 掲示板を経由せず直接開いた場合でも、サインインを確立してから読み込む。
        .task {
            if !BoardAuthService.shared.isSignedIn {
                await BoardAuthService.shared.signInAnonymously()
            }
            if viewModel.rooms.isEmpty {
                viewModel.load()
            }
        }
        // 部屋作成 FAB（右下）— 投稿ボタンと同じ 56pt スタイル、中央は plus アイコン
        .overlay(alignment: .bottomTrailing) {
            Button {
                HapticManager.medium()
                showingCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(MeloColors.Dark.onAccent)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(MeloColors.Dark.accentGradient)
                            .shadow(color: MeloColors.Dark.accent.opacity(0.45), radius: 10, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 96)
            .accessibilityLabel("新しい相談部屋を作成")
        }
        .sheet(isPresented: $showingCreateSheet) {
            CommunityRoomCreateSheet { title, subtitle, iconData, headerData in
                Task {
                    _ = await viewModel.createRoom(
                        title: title,
                        subtitle: subtitle,
                        iconImageData: iconData,
                        headerImageData: headerData
                    )
                }
            }
        }
    }

    // MARK: - Header (タイトル行とタブピル間を詰めて全体を狭く)

    private var header: some View {
        // ホームページ (BoardFeedView) のヘッダーとテーマピルの隙間 (= 6 + 2 = 8pt) と
        // 同じ幅にしたいので、タイトル行 padding.bottom = 6 + タブ列 padding.top = 2 で合計 8pt。
        VStack(alignment: .leading, spacing: 0) {
            // 上段: タイトル + Premium + 検索ボタン
            HStack(alignment: .center, spacing: 8) {
                Text("相談部屋")
                    .font(MeloFonts.zenMaruOrFallback(22))
                    .tracking(0.66)
                    .foregroundColor(RoomsPalette.bodyText)
                    .frame(height: 32, alignment: .leading)

                Spacer(minLength: 0)

                searchButton

                PremiumBadgeButton(source: "premium_badge_consult_room") {
                    HapticManager.light()
                    coordinator.subscriptionSource = "premium_badge_consult_room"
                    coordinator.showingSubscription = true
                }
            }
            .padding(.horizontal, MeloLayout.titleHorizontalPadding)
            .padding(.top, 6)
            .padding(.bottom, 6)

            // 下段: 検索中は検索バー、通常時はタブ
            Group {
                if isSearching {
                    searchBarRow
                } else {
                    tabBar
                }
            }
            .padding(.horizontal, MeloLayout.titleHorizontalPadding)
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoomsPalette.headerBackground
                .ignoresSafeArea(edges: .top)
        )
    }

    private var searchButton: some View {
        Button {
            openSearch()
        } label: {
            ZStack {
                Circle()
                    .fill(RoomsPalette.searchButtonBg)
                    .overlay(
                        Circle()
                            .stroke(RoomsPalette.pillBorder, lineWidth: 1)
                    )
                    .shadow(color: RoomsPalette.headerBorder.opacity(0.8), radius: 2, x: 0, y: 1)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(RoomsPalette.bodyText)
            }
            .frame(width: PremiumBadgeButton.height, height: PremiumBadgeButton.height)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("部屋を検索"))
    }

    /// ホームページの sortTabsRow と同じ「テキスト + 下線インジケータ」スタイル。
    /// 行の最下端に画面端から端までフルワイドの薄ピンク線、選択中タブのみ下に太いピンク線が重なる。
    private var tabBar: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(MeloColors.Dark.divider)
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(CommunityRoomTab.allCases) { tab in
                    tabPill(tab)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 36)
    }

    private func tabPill(_ tab: CommunityRoomTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectTab(tab)
            }
        } label: {
            VStack(spacing: 4) {
                Text(tab.title)
                    .font(MeloFonts.zenMaruMedium(16))
                    .tracking(0.48)
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(MeloColors.Dark.accentGradient)
                        : AnyShapeStyle(RoomsPalette.bodyText)
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
    }

    // MARK: - Search bar

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            searchField
            cancelButton
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(RoomsPalette.subText)

            TextField(
                "",
                text: $viewModel.searchQuery,
                prompt: Text("部屋を検索")
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(RoomsPalette.subText)
            )
            .font(MeloFonts.zenMaruMedium(14))
            .foregroundColor(RoomsPalette.bodyText)
            .tint(RoomsPalette.koiPink)
            .submitLabel(.search)
            .focused($focusedField, equals: .search)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(RoomsPalette.subText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("検索キーワードをクリア"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MeloColors.Dark.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RoomsPalette.searchFieldBorder, lineWidth: 1)
        )
    }

    private var cancelButton: some View {
        Button {
            closeSearch()
        } label: {
            Text("キャンセル")
                .font(MeloFonts.zenMaruMedium(14))
                .tracking(0.42)
                .foregroundColor(RoomsPalette.bodyText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body (rooms list)

    private var body_: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.displayedRooms) { room in
                    let card = RoomCard(
                        room: room,
                        onTapJoin: { viewModel.toggleJoin(room) },
                        onTapCard: { onRoomTap?(room) }
                    )

                    // オーナー限定の削除メニュー。
                    // 非オーナーには通常の RoomCard のみ表示（従来 UX を維持）。
                    if room.isOwnedBy(userId: BoardAuthService.shared.currentUser?.id) {
                        card.contextMenu {
                            Button(role: .destructive) {
                                HapticManager.medium()
                                Task { await viewModel.deleteRoom(room) }
                            } label: {
                                Label(
                                    String(localized: "部屋を削除", bundle: LanguageManager.appBundle),
                                    systemImage: "trash"
                                )
                            }
                        }
                    } else {
                        card
                    }
                }

                if viewModel.displayedRooms.isEmpty {
                    emptyState
                        .padding(.top, 60)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 100) // タブバー + FAB 分の余白を確保し最後のカードが隠れないように
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(spacing: 10) {
            Image("mero_pair_13")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            if !trimmed.isEmpty {
                Text("“\(trimmed)” に一致する部屋が見つかりません")
                    .font(MeloFonts.zenMaruMedium(14))
                    .tracking(0.3)
                    .foregroundColor(RoomsPalette.subText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    viewModel.clearSearch()
                } label: {
                    Text("検索キーワードをクリア")
                        .font(MeloFonts.zenMaruMedium(13))
                        .tracking(0.3)
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(RoomsPalette.koiPink)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                Text(emptyMessage(for: viewModel.selectedTab))
                    .font(MeloFonts.zenMaruMedium(13))
                    .tracking(0.3)
                    .foregroundColor(RoomsPalette.bodyText)
            }
        }
    }

    private func emptyMessage(for tab: CommunityRoomTab) -> String {
        switch tab {
        case .joined: return String(localized: "まだ参加している部屋はないよ", bundle: LanguageManager.appBundle)
        case .created: return String(localized: "まだ作成した部屋はないよ", bundle: LanguageManager.appBundle)
        case .search: return String(localized: "部屋が見つかりません", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - Search handlers

    private func openSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearching = true
        }
        // 200ms 遅延で自動フォーカス（キーボード表示）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            focusedField = .search
        }
    }

    private func closeSearch() {
        focusedField = nil
        viewModel.clearSearch()
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearching = false
        }
    }
}

// MARK: - Room Card (width 364 / height 130)

private struct RoomCard: View {
    let room: CommunityRoom
    let onTapJoin: () -> Void
    let onTapCard: () -> Void

    var body: some View {
        Button(action: onTapCard) {
            cardBody
        }
        .buttonStyle(.plain)
    }

    private var cardBody: some View {
        ZStack(alignment: .topLeading) {
            // 背景
            RoundedRectangle(cornerRadius: 15)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(RoomsPalette.cardBorder, lineWidth: 1)
                )

            // Room image: 左18 / 上21, 54x54
            roomImage
                .padding(.leading, 18)
                .padding(.top, 21)

            // Title: 左85 / 上21, 幅160
            Text(room.title)
                .font(MeloFonts.zenMaruOrFallback(16))
                .tracking(0.48)
                .foregroundColor(RoomsPalette.bodyText)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
                .padding(.leading, 85)
                .padding(.top, 21)

            // 投稿数 + (任意で参加人数) : 左97 / 上47, 幅220
            // 投稿数は常に表示。参加人数はシード/テーマ部屋ではダミー(または0)なので
            // ownerId が設定された通常作成部屋のときだけ追加表示する。
            Text(roomMetaText(for: room))
                .font(MeloFonts.zenMaruMedium(10))
                .tracking(0.3)
                .foregroundColor(RoomsPalette.bodyText)
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)
                .padding(.leading, 97)
                .padding(.top, 47)

            // subtitle: 左85 / 上73, 幅262
            Text(room.subtitle)
                .font(MeloFonts.zenMaruMedium(12))
                .tracking(0.36)
                .foregroundColor(RoomsPalette.subText)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(width: 262, alignment: .leading)
                .padding(.leading, 85)
                .padding(.top, 73)

            // 参加ボタン: 左267 / 上22, 73x29
            // テーマ部屋(theme: prefix)は参加状態を持たず誰でもアクセス可能なので、
            // 「参加」ボタンを表示しない。通常の相談部屋のみ表示する。
            if !CommunityThemeRoom.isThemeRoomId(room.id) {
                joinButton
                    .padding(.leading, 267)
                    .padding(.top, 22)
            }
        }
        .frame(width: 364, height: 130)
    }

    /// カードに表示する meta 行: 投稿数 (常時) + 参加人数 (通常部屋のみ)。
    private func roomMetaText(for room: CommunityRoom) -> String {
        var parts: [String] = []
        parts.append(String(format: String(localized: "投稿%lld件", bundle: LanguageManager.appBundle), room.postCount))
        if room.ownerId != nil {
            parts.append(String(format: String(localized: "%lld人が話してるよ！", bundle: LanguageManager.appBundle), room.participantCount))
        }
        return parts.joined(separator: " ・ ")
    }

    private var roomImage: some View {
        // 54×54 の角丸正方形に画像をクロップする。
        // ユーザー画像が存在するときだけ色付き背景を出し、デフォルトのめろまる画像
        // 使用時は背景を敷かずに画像で正方形を満たす（透過部分から下地の色が
        // 透けるのを防ぐ）。
        Group {
            if let data = room.iconImageData, let uiImage = UIImage(data: data) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(room.iconColor.opacity(0.9))
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 54, height: 54)
                        .clipped()
                }
            } else if let urlString = room.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(room.iconColor.opacity(0.9))
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 54, height: 54)
                                .clipped()
                        }
                    case .failure:
                        placeholderGlyph
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderGlyph
                    }
                }
            } else {
                placeholderGlyph
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholderGlyph: some View {
        Image("room_default_icon")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 54, height: 54)
            .clipped()
    }

    private var joinButton: some View {
        Button(action: onTapJoin) {
            Text(room.isJoined ? String(localized: "参加中", bundle: LanguageManager.appBundle) : String(localized: "参加", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(16))
                .tracking(0.48)
                .foregroundColor(room.isJoined ? RoomsPalette.koiPink : MeloColors.Dark.onAccent)
                .frame(width: 73, height: 29)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(room.isJoined
                              ? RoomsPalette.joinedPinkBg
                              : RoomsPalette.koiPink)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("相談部屋 一覧") {
    CommunityRoomsView()
}
