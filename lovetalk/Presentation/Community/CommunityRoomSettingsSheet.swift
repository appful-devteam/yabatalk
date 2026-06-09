import SwiftUI

// MARK: - Palette
//
// 新デザイン仕様:
//  - 背景: soft pink
//  - カード: 白地 / corner radius 10 / 1pt #716463 stroke
//  - プライマリボタン: F7A2BA (flat)
//  - 破壊的アクション: 赤系

private enum RoomSettingsPalette {
    static let background = MeloColors.Dark.bg
    static let cardBg = MeloColors.Dark.card
    static let stroke = MeloColors.Dark.cardStroke
    static let textMain = MeloColors.Dark.textPrimary
    static let textSub = MeloColors.Dark.textSecondary
    static let accent = MeloColors.Dark.accent
    static let accentSoft = MeloColors.Dark.bgElevated
    static let destructive = MeloColors.Status.error      // 状態色（意味）: 変えない
    static let destructiveSoft = MeloColors.Status.errorBg // 状態色（意味）: 変えない
}

// MARK: - Settings Sheet
//
// オーナー専用。部屋の情報編集 / 参加者管理 (ブロック切替) / 危険な操作 (削除) の
// 3 セクションを表示する。
struct CommunityRoomSettingsSheet: View {
    let room: CommunityRoom
    /// 詳細ビューが保持している投稿一覧。参加者リストはここから authorId で集計する
    /// （参加者コレクションが Firestore に無いため、投稿者を実質的な「参加者」として扱う）。
    let posts: [CommunityRoomPost]
    @ObservedObject var roomsViewModel: CommunityRoomsViewModel
    /// 部屋削除後に呼ばれる。親の詳細ビューが dismiss する。
    var onRoomDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var subtitle: String
    @State private var showingDeleteConfirm: Bool = false
    @State private var isSaving: Bool = false
    @State private var toast: String? = nil
    @State private var toastIsError: Bool = false

    init(
        room: CommunityRoom,
        posts: [CommunityRoomPost],
        roomsViewModel: CommunityRoomsViewModel,
        onRoomDeleted: @escaping () -> Void
    ) {
        self.room = room
        self.posts = posts
        self.roomsViewModel = roomsViewModel
        self.onRoomDeleted = onRoomDeleted
        _title = State(initialValue: room.title)
        _subtitle = State(initialValue: room.subtitle)
    }

    // MARK: - Derived

    /// 最新の Room スナップショット。編集や block 操作後の即時反映に使用。
    private var currentRoom: CommunityRoom {
        roomsViewModel.latestRoom(id: room.id) ?? room
    }

    /// authorId を持つ投稿から参加者リストを集計。
    /// 投稿 authorId が同じユーザーは 1 行にまとめ、最新の displayName を採用。
    private var participants: [ParticipantEntry] {
        var dict: [String: ParticipantEntry] = [:]
        for post in posts {
            guard let aid = post.authorId else { continue }
            // 既存エントリがあれば維持。新規なら作成。
            if dict[aid] == nil {
                dict[aid] = ParticipantEntry(
                    userId: aid,
                    displayName: post.authorName,
                    avatarColorHex: post.authorAvatarColor
                )
            }
        }
        return dict.values.sorted(by: { $0.displayName < $1.displayName })
    }

    private var hasTitleChanges: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines) != currentRoom.title
            || subtitle.trimmingCharacters(in: .whitespacesAndNewlines) != currentRoom.subtitle
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    infoSection
                    participantsSection
                    dangerSection
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .background(RoomSettingsPalette.background.ignoresSafeArea())
            .overlay(alignment: .top) {
                if let toast {
                    BoardToastView(
                        toast,
                        icon: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                        isError: toastIsError
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle(Text(String(localized: "部屋の設定", bundle: LanguageManager.appBundle)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Text(String(localized: "閉じる", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(RoomSettingsPalette.textMain)
                    }
                }
            }
            .confirmationDialog(
                Text(String(localized: "この部屋を削除しますか？", bundle: LanguageManager.appBundle)),
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    Task { await performDelete() }
                } label: {
                    Text(String(localized: "削除する", bundle: LanguageManager.appBundle))
                }
                Button(role: .cancel) { } label: {
                    Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                }
            } message: {
                Text(String(localized: "投稿内容も含めて復元できません。", bundle: LanguageManager.appBundle))
            }
        }
    }

    // MARK: - Section 1: 部屋の情報

    private var infoSection: some View {
        sectionCard(title: String(localized: "部屋の情報", bundle: LanguageManager.appBundle)) {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel(String(localized: "タイトル", bundle: LanguageManager.appBundle))
                TextField("", text: $title)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(RoomSettingsPalette.textMain)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(MeloColors.Dark.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(RoomSettingsPalette.stroke, lineWidth: 1)
                            )
                    )

                fieldLabel(String(localized: "説明文", bundle: LanguageManager.appBundle))
                ZStack(alignment: .topLeading) {
                    if subtitle.isEmpty {
                        Text(String(localized: "どんな雰囲気の部屋かを紹介してください", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(12))
                            .foregroundColor(RoomSettingsPalette.textSub)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $subtitle)
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(RoomSettingsPalette.textMain)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: 100)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MeloColors.Dark.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(RoomSettingsPalette.stroke, lineWidth: 1)
                        )
                )

                HStack {
                    Spacer()
                    primaryPill(
                        title: String(localized: "保存", bundle: LanguageManager.appBundle),
                        isEnabled: hasTitleChanges && !isSaving,
                        action: { Task { await performSave() } }
                    )
                }
            }
        }
    }

    // MARK: - Section 2: 参加者管理

    private var participantsSection: some View {
        sectionCard(title: String(localized: "参加者管理", bundle: LanguageManager.appBundle)) {
            VStack(spacing: 10) {
                if participants.isEmpty {
                    Text(String(localized: "まだ参加者がいません", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(RoomSettingsPalette.textSub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    ForEach(participants) { p in
                        participantRow(p)
                    }
                }
            }
        }
    }

    private func participantRow(_ p: ParticipantEntry) -> some View {
        let isBlocked = currentRoom.blockedUserIds.contains(p.userId)
        return HStack(spacing: 12) {
            // 丸アバター（頭文字）
            ZStack {
                Circle()
                    .fill(Color(hex: p.avatarColorHex))
                Text(String(p.displayName.prefix(1)))
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(p.displayName)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(RoomSettingsPalette.textMain)
                    .lineLimit(1)
                Text(p.userId.prefix(8) + "…")
                    .font(MeloFonts.zenMaruRegular(10))
                    .foregroundColor(RoomSettingsPalette.textSub)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task { await performToggleBlock(userId: p.userId) }
            } label: {
                Text(isBlocked
                     ? String(localized: "ブロック解除", bundle: LanguageManager.appBundle)
                     : String(localized: "ブロック", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(isBlocked ? RoomSettingsPalette.textMain : MeloColors.Dark.onAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(
                        Capsule()
                            .fill(isBlocked ? RoomSettingsPalette.accentSoft : RoomSettingsPalette.accent)
                            .overlay(
                                Capsule()
                                    .stroke(isBlocked ? RoomSettingsPalette.stroke : Color.clear, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Section 3: 危険な操作

    private var dangerSection: some View {
        sectionCard(title: String(localized: "危険な操作", bundle: LanguageManager.appBundle)) {
            VStack(spacing: 10) {
                Text(String(localized: "この部屋を削除すると投稿も含めて復元できません。", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(RoomSettingsPalette.textSub)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    HapticManager.medium()
                    showingDeleteConfirm = true
                } label: {
                    Text(String(localized: "部屋を削除", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(RoomSettingsPalette.destructive)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func performSave() async {
        isSaving = true
        let updated = await roomsViewModel.updateRoomInfo(
            roomId: room.id,
            title: title,
            subtitle: subtitle
        )
        isSaving = false
        if updated != nil {
            showToast(
                String(localized: "保存しました", bundle: LanguageManager.appBundle),
                isError: false
            )
        } else {
            showToast(
                String(localized: "保存に失敗しました", bundle: LanguageManager.appBundle),
                isError: true
            )
        }
    }

    private func performToggleBlock(userId: String) async {
        HapticManager.light()
        _ = await roomsViewModel.toggleBlock(roomId: room.id, userId: userId)
    }

    private func performDelete() async {
        let ok = await roomsViewModel.deleteRoom(currentRoom)
        if ok {
            dismiss()
            // 親側の詳細 dismiss をわずかに遅らせて、シートが閉じたあと実行。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onRoomDeleted()
            }
        } else {
            showToast(
                String(localized: "削除に失敗しました", bundle: LanguageManager.appBundle),
                isError: true
            )
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(MeloFonts.zenMaruOrFallback(14))
                .tracking(0.42)
                .foregroundColor(RoomSettingsPalette.textMain)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RoomSettingsPalette.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(RoomSettingsPalette.stroke, lineWidth: 1)
                )
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruMedium(12))
            .foregroundColor(RoomSettingsPalette.textSub)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryPill(title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MeloFonts.zenMaruOrFallback(14))
                .tracking(0.42)
                .foregroundColor(MeloColors.Dark.onAccent)
                .padding(.horizontal, 22)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(isEnabled ? RoomSettingsPalette.accent : RoomSettingsPalette.accent.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func showToast(_ message: String, isError: Bool) {
        withAnimation { toast = message; toastIsError = isError }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - Participant Entry

private struct ParticipantEntry: Identifiable, Hashable {
    let userId: String
    let displayName: String
    let avatarColorHex: String

    var id: String { userId }
}
