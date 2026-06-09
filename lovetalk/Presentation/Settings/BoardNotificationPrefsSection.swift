import SwiftUI

/// SettingsView の中で使う「掲示板のプッシュ通知設定」セクション。
/// 7 種類のトグル (フォロー / いいね / コメント / メンション / リポスト / 引用 / 保存)。
/// 切替時に Firestore `users/{uid}.notificationPrefs` に保存し、Cloud Functions 側でこの設定を見て APNs 配信する。
struct BoardNotificationPrefsSection: View {
    @StateObject private var authService = BoardAuthService.shared

    @State private var prefs = BoardNotificationPrefs.allEnabled
    @State private var isLoading = true
    @State private var isSaving = false

    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        section {
            VStack(spacing: 0) {
                if isLoading {
                    HStack {
                        ProgressView()
                            .tint(MeloColors.Dark.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                } else {
                    toggleRow(
                        title: String(localized: "フォローされたとき", bundle: LanguageManager.appBundle),
                        binding: bindingFor(\.follow)
                    )
                    rowDivider
                    toggleRow(
                        title: String(localized: "投稿にいいねされたとき", bundle: LanguageManager.appBundle),
                        binding: bindingFor(\.like)
                    )
                    rowDivider
                    toggleRow(
                        title: String(localized: "投稿にコメントされたとき", bundle: LanguageManager.appBundle),
                        binding: bindingFor(\.reply)
                    )
                    rowDivider
                    toggleRow(
                        title: String(localized: "メンションされたとき", bundle: LanguageManager.appBundle),
                        binding: bindingFor(\.mention)
                    )
                    rowDivider
                    toggleRow(
                        title: String(localized: "投稿がリポストされたとき", bundle: LanguageManager.appBundle),
                        binding: bindingFor(\.repost)
                    )
                    rowDivider
                    toggleRow(
                        title: String(localized: "投稿が引用されたとき", bundle: LanguageManager.appBundle),
                        binding: bindingFor(\.quote)
                    )
                    rowDivider
                    toggleRow(
                        title: String(localized: "投稿が保存されたとき", bundle: LanguageManager.appBundle),
                        binding: bindingFor(\.bookmark)
                    )
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "掲示板の通知", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(13))
                    .tracking(0.36)
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(MeloColors.Dark.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(String(localized: "オフにすると、その種類のバナー通知は届きません。アプリ内の通知タブには引き続き表示されます。", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(11))
                .tracking(0.3)
                .foregroundColor(MeloColors.Dark.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(MeloColors.Dark.divider)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func toggleRow(title: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(MeloColors.Dark.textPrimary)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(MeloColors.Dark.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Binding helper (auto-saves on toggle)

    private func bindingFor(_ keyPath: WritableKeyPath<BoardNotificationPrefs, Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { prefs[keyPath: keyPath] },
            set: { newValue in
                var next = prefs
                next[keyPath: keyPath] = newValue
                prefs = next
                Task { await save() }
            }
        )
    }

    // MARK: - Load / Save

    private func load() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }
        let loaded = await firestoreService.fetchBoardNotificationPrefs(userId: userId)
        await MainActor.run {
            prefs = loaded
            isLoading = false
        }
    }

    private func save() async {
        guard let userId = authService.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        try? await firestoreService.saveBoardNotificationPrefs(userId: userId, prefs: prefs)
    }
}
