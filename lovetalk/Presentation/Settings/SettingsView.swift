import SwiftUI
import SwiftData
import UIKit
import AuthenticationServices

// MARK: - Settings Design Tokens (match NewHomeView)
private enum SettingsTokens {
    static let pageBg = Color.white
    static let headerBg = MeloColors.Surface.pinkPale
    static let brandPink = MeloColors.Brand.pink
    static let filledPink = MeloColors.Brand.pink
    static let softPink = MeloColors.Brand.pinkLight
    static let textDark = MeloColors.Text.primary
    static let textGrey = MeloColors.Text.secondary
    static let textMuted = MeloColors.Text.secondary
    static let strokeBrown = MeloColors.Text.primary
    static let divider = MeloColors.Gray.subButtonLight
    static let destructive = MeloColors.Status.error
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteSuccess = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingCommercialTransactions = false
    @State private var isDeleting = false
    @State private var versionTapCount = 0
    @State private var showDevUnlocked = false
    @AppStorage(Constants.StorageKeys.devSectionUnlocked) private var devSectionUnlocked = false
    @AppStorage(Constants.StorageKeys.pipelineDebugEnabled) private var isLoggingEnabled = false
    @AppStorage("hasAgreedToGeminiTerms_v2") private var hasAgreedConsultation = false
    @AppStorage("hasAgreedToPersonaChatTerms") private var hasAgreedPersonaChat = false
    @AppStorage(Constants.StorageKeys.userPreferredName) private var userPreferredName: String = ""
    @FocusState private var isPreferredNameFocused: Bool
    @State private var showingRevokeConfirmation = false
    @StateObject private var boardAuthService = BoardAuthService.shared
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingDeleteAccountReauth = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsTokens.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 言語 / Language
                        sectionCard(
                            title: String(localized: "言語 / Language", bundle: LanguageManager.appBundle)
                        ) {
                            VStack(spacing: 0) {
                                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, lang in
                                    Button {
                                        HapticManager.light()
                                        languageManager.setLanguage(lang)
                                    } label: {
                                        languageRow(lang: lang)
                                    }
                                    .buttonStyle(.plain)

                                    if index < AppLanguage.allCases.count - 1 {
                                        rowDivider
                                    }
                                }
                            }
                        }

                        // バナー広告
                        AdBannerContainer(
                            adUnitID: AdUnitID.bannerSettings,
                            padding: .init(top: 0, leading: 0, bottom: 0, trailing: 0)
                        )
                        .frame(maxWidth: .infinity)

                        // めろまるが呼ぶ名前
                        sectionCard(
                            title: String(localized: "プロフィール", bundle: LanguageManager.appBundle),
                            footer: String(localized: "「とりあえず話す」など、相手を指定せずに相談する時にめろまるがあなたを呼ぶ名前です。空欄の場合は「あなた」と呼ばれます。", bundle: LanguageManager.appBundle)
                        ) {
                            preferredNameRow
                        }

                        // AI データ共有
                        sectionCard(
                            title: String(localized: "AIデータ共有", bundle: LanguageManager.appBundle),
                            footer: String(localized: "オフにすると、AI機能（サマリー・相談・擬人化チャット）の利用時に再度同意が必要になります。トーク履歴や解析結果は削除されません。", bundle: LanguageManager.appBundle)
                        ) {
                            aiConsentRevokeRow
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }

                        // アカウント
                        if boardAuthService.hasRealAccount {
                            sectionCard(
                                title: String(localized: "アカウント", bundle: LanguageManager.appBundle)
                            ) {
                                VStack(spacing: 0) {
                                    signOutRow
                                    rowDivider
                                    deleteAccountRow
                                }
                            }
                        }

                        // 掲示板の通知設定 (サインイン中のみ)
                        if boardAuthService.hasRealAccount {
                            BoardNotificationPrefsSection()
                        }

                        // データ管理
                        sectionCard(
                            title: String(localized: "データ管理", bundle: LanguageManager.appBundle),
                            footer: String(localized: "解析結果とインポートしたトーク履歴をすべて削除します", bundle: LanguageManager.appBundle)
                        ) {
                            deleteDataButton
                        }

                        // プライバシー / 情報
                        sectionCard(
                            title: String(localized: "情報", bundle: LanguageManager.appBundle)
                        ) {
                            VStack(spacing: 0) {
                                Button {
                                    HapticManager.light()
                                    AnalyticsManager.shared.track("settings_action", properties: ["action": "privacy_policy"])
                                    showingPrivacyPolicy = true
                                } label: {
                                    privacyRow
                                }
                                .buttonStyle(.plain)

                                rowDivider

                                Button {
                                    HapticManager.light()
                                    AnalyticsManager.shared.track("settings_action", properties: ["action": "terms_of_service"])
                                    showingTermsOfService = true
                                } label: {
                                    termsRow
                                }
                                .buttonStyle(.plain)

                                rowDivider

                                Button {
                                    HapticManager.light()
                                    AnalyticsManager.shared.track("settings_action", properties: ["action": "commercial_transactions"])
                                    showingCommercialTransactions = true
                                } label: {
                                    commercialTransactionsRow
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // お問い合わせ
                        sectionCard(
                            title: String(localized: "サポート", bundle: LanguageManager.appBundle)
                        ) {
                            contactRow
                        }

                        // アプリ情報
                        sectionCard(
                            title: String(localized: "アプリについて", bundle: LanguageManager.appBundle)
                        ) {
                            versionRow
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.light()
                                    versionTapCount += 1
                                    if versionTapCount >= 5 && !devSectionUnlocked {
                                        HapticManager.success()
                                        devSectionUnlocked = true
                                        showDevUnlocked = true
                                    }
                                }
                        }

                        // Developer
                        if devSectionUnlocked {
                            sectionCard(title: "Developer") {
                                VStack(spacing: 0) {
                                    Toggle(isOn: $isLoggingEnabled) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "ladybug")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(SettingsTokens.brandPink)
                                                .frame(width: 24)
                                            Text(String(localized: "パイプラインログ", bundle: LanguageManager.appBundle))
                                                .font(MeloFonts.zenMaru(14))
                                                .tracking(0.42)
                                                .foregroundColor(SettingsTokens.textDark)
                                        }
                                    }
                                    .tint(SettingsTokens.brandPink)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                    if isLoggingEnabled {
                                        rowDivider
                                        NavigationLink {
                                            PipelineDebugLogListView()
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "doc.plaintext")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(SettingsTokens.brandPink)
                                                    .frame(width: 24)
                                                Text(String(localized: "ログを見る", bundle: LanguageManager.appBundle))
                                                    .font(MeloFonts.zenMaru(14))
                                                    .tracking(0.42)
                                                    .foregroundColor(SettingsTokens.textDark)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(SettingsTokens.textGrey)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // デモデータ
                        sectionCard(
                            footer: String(localized: "デモデータをダウンロードして、アプリの機能をお試しください", bundle: LanguageManager.appBundle)
                        ) {
                            demoDataRow
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(String(localized: "設定", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(String(localized: "設定", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(18))
                        .tracking(0.54)
                        .foregroundColor(SettingsTokens.textDark)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Text(String(localized: "閉じる", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaru(14))
                            .tracking(0.42)
                            .foregroundColor(SettingsTokens.brandPink)
                    }
                }
            }
            .alert(String(localized: "データを削除しますか？", bundle: LanguageManager.appBundle), isPresented: $showingDeleteConfirmation) {
                Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
                Button(String(localized: "削除", bundle: LanguageManager.appBundle), role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text(String(localized: "この操作は取り消せません。", bundle: LanguageManager.appBundle))
            }
            .alert(String(localized: "削除しました", bundle: LanguageManager.appBundle), isPresented: $showingDeleteSuccess) {
                Button(String(localized: "OK", bundle: LanguageManager.appBundle)) {}
            } message: {
                Text(String(localized: "すべてのデータを削除しました。", bundle: LanguageManager.appBundle))
            }
            .alert("Developer Mode", isPresented: $showDevUnlocked) {
                Button(String(localized: "OK", bundle: LanguageManager.appBundle)) {}
            } message: {
                Text(String(localized: "開発者メニューが有効になりました。", bundle: LanguageManager.appBundle))
            }
            .alert(String(localized: "AIデータ共有の同意を取り消しますか？", bundle: LanguageManager.appBundle), isPresented: $showingRevokeConfirmation) {
                Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
                Button(String(localized: "同意を取り消す", bundle: LanguageManager.appBundle), role: .destructive) {
                    hasAgreedConsultation = false
                    hasAgreedPersonaChat = false
                    AnalyticsManager.shared.track("settings_action", properties: ["action": "revoke_ai_consent"])
                }
            } message: {
                Text(String(localized: "AI機能（サマリー・相談・擬人化チャット）の利用時に再度同意が必要になります。トーク履歴や解析結果は削除されません。", bundle: LanguageManager.appBundle))
            }
            .confirmationDialog(
                String(localized: "ログアウトしますか？", bundle: LanguageManager.appBundle),
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "ログアウト", bundle: LanguageManager.appBundle)) {
                    performSignOut()
                }
                Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
            } message: {
                Text(String(localized: "再度ログインするとアカウントに復帰できます。", bundle: LanguageManager.appBundle))
            }
            .confirmationDialog(
                String(localized: "アカウントを削除しますか？", bundle: LanguageManager.appBundle),
                isPresented: $showingDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "削除する", bundle: LanguageManager.appBundle), role: .destructive) {
                    showingDeleteAccountReauth = true
                }
                Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
            } message: {
                Text(String(localized: "投稿、プロフィール、診断履歴がすべて削除され、復元できません。", bundle: LanguageManager.appBundle))
            }
            .alert(
                String(localized: "削除に失敗しました", bundle: LanguageManager.appBundle),
                isPresented: .init(
                    get: { deleteAccountError != nil },
                    set: { if !$0 { deleteAccountError = nil } }
                )
            ) {
                Button(String(localized: "OK", bundle: LanguageManager.appBundle)) { deleteAccountError = nil }
            } message: {
                Text(deleteAccountError ?? "")
            }
            .sheet(isPresented: $showingDeleteAccountReauth) {
                deleteAccountReauthView
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showingCommercialTransactions) {
                CommercialTransactionsView()
            }
            .overlay {
                if isDeleting || isDeletingAccount {
                    deletingOverlay
                }
            }
        }
    }

    // MARK: - Section Card Builder
    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(MeloFonts.zenMaruMedium(12))
                    .tracking(0.36)
                    .foregroundColor(SettingsTokens.brandPink)
                    .padding(.leading, 4)
            }

            content()
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SettingsTokens.strokeBrown, lineWidth: 1)
                )

            if let footer {
                Text(footer)
                    .font(MeloFonts.zenMaruRegular(11))
                    .tracking(0.24)
                    .foregroundColor(SettingsTokens.textGrey)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(SettingsTokens.divider)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    // MARK: - Rows

    private func languageRow(lang: AppLanguage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsTokens.brandPink)
                .frame(width: 24)

            Text(lang.displayName)
                .font(MeloFonts.zenMaru(14))
                .tracking(0.42)
                .foregroundColor(SettingsTokens.textDark)

            Spacer()

            if languageManager.currentLanguage == lang {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SettingsTokens.brandPink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// めろまるが呼ぶ呼び名 (ニックネーム) を入力するセル。空欄なら "あなた" 扱い。
    private var preferredNameRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsTokens.brandPink)
                .frame(width: 24)

            Text(String(localized: "呼び名", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(14))
                .tracking(0.42)
                .foregroundColor(SettingsTokens.textDark)

            Spacer(minLength: 8)

            TextField(
                "",
                text: $userPreferredName
            )
            .font(MeloFonts.zenMaruMedium(13))
            .foregroundColor(SettingsTokens.textDark)
            .multilineTextAlignment(.trailing)
            .submitLabel(.done)
            .focused($isPreferredNameFocused)
            .frame(maxWidth: 160)
            .onSubmit {
                isPreferredNameFocused = false
                userPreferredName = userPreferredName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var aiConsentRevokeRow: some View {
        let isAnyConsented = hasAgreedConsultation || hasAgreedPersonaChat

        return HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsTokens.brandPink)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "AIデータ共有の同意", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(SettingsTokens.textDark)

                Text(isAnyConsented
                     ? String(localized: "Google LLC（Gemini API）へのデータ送信が許可されています", bundle: LanguageManager.appBundle)
                     : String(localized: "AI機能の利用時に再度同意が必要です", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruRegular(11))
                    .tracking(0.24)
                    .foregroundColor(SettingsTokens.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isAnyConsented {
                Button {
                    HapticManager.light()
                    showingRevokeConfirmation = true
                } label: {
                    Text(String(localized: "同意を取り消す", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(12))
                        .tracking(0.3)
                        .foregroundColor(SettingsTokens.destructive)
                }
                .buttonStyle(.plain)
            } else {
                Text(String(localized: "取り消し済み", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(12))
                    .tracking(0.3)
                    .foregroundColor(SettingsTokens.textMuted)
            }
        }
    }

    private var deleteDataButton: some View {
        Button(role: .destructive) {
            HapticManager.heavy()
            showingDeleteConfirmation = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SettingsTokens.destructive)
                    .frame(width: 24)

                Text(String(localized: "すべてのデータを削除", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(SettingsTokens.destructive)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var signOutRow: some View {
        Button {
            HapticManager.light()
            showingSignOutConfirmation = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SettingsTokens.brandPink)
                    .frame(width: 24)

                Text(String(localized: "ログアウト", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(SettingsTokens.textDark)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var deleteAccountRow: some View {
        Button(role: .destructive) {
            HapticManager.heavy()
            showingDeleteAccountConfirmation = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SettingsTokens.destructive)
                    .frame(width: 24)

                Text(String(localized: "アカウントを削除", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(SettingsTokens.destructive)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete Account Re-auth Sheet

    private var deleteAccountReauthView: some View {
        NavigationStack {
            ZStack {
                SettingsTokens.pageBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(SettingsTokens.destructive.opacity(0.8))

                    Text(String(localized: "本人確認が必要です", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(18))
                        .tracking(0.54)
                        .foregroundColor(SettingsTokens.textDark)

                    Text(String(localized: "アカウントを完全に削除するため、Apple IDで再度サインインしてください。", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(13))
                        .tracking(0.39)
                        .foregroundColor(SettingsTokens.textGrey)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()

                    SignInWithAppleButton(.signIn) { request in
                        let hashedNonce = boardAuthService.prepareAppleSignIn()
                        request.requestedScopes = []
                        request.nonce = hashedNonce
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task { await performDeleteAccount(authorization: authorization) }
                        case .failure(let error):
                            print("[Settings] Apple re-auth cancelled: \(error)")
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .padding(.horizontal, 32)

                    Button {
                        showingDeleteAccountReauth = false
                    } label: {
                        Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaru(13))
                            .tracking(0.39)
                            .foregroundColor(SettingsTokens.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }

                if isDeletingAccount {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(SettingsTokens.brandPink)
                        Text(String(localized: "アカウントを削除中...", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaru(14))
                            .tracking(0.42)
                            .foregroundColor(SettingsTokens.textDark)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(SettingsTokens.strokeBrown, lineWidth: 1)
                            )
                    )
                }
            }
            .navigationTitle(String(localized: "アカウント削除", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる", bundle: LanguageManager.appBundle)) {
                        showingDeleteAccountReauth = false
                    }
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(SettingsTokens.brandPink)
                    .disabled(isDeletingAccount)
                }
            }
            .interactiveDismissDisabled(isDeletingAccount)
        }
    }

    private var privacyRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsTokens.brandPink)
                .frame(width: 24)

            Text(String(localized: "プライバシーポリシー", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(14))
                .tracking(0.42)
                .foregroundColor(SettingsTokens.textDark)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SettingsTokens.textGrey)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var termsRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsTokens.brandPink)
                .frame(width: 24)

            Text(String(localized: "利用規約", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(14))
                .tracking(0.42)
                .foregroundColor(SettingsTokens.textDark)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SettingsTokens.textGrey)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var commercialTransactionsRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "scroll.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsTokens.brandPink)
                .frame(width: 24)

            Text(String(localized: "特定商取引法に基づく表記", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(14))
                .tracking(0.42)
                .foregroundColor(SettingsTokens.textDark)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SettingsTokens.textGrey)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var versionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SettingsTokens.brandPink)
                .frame(width: 24)

            Text(String(localized: "バージョン", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(14))
                .tracking(0.42)
                .foregroundColor(SettingsTokens.textDark)

            Spacer()

            Text(Constants.App.version)
                .font(MeloFonts.zenMaruMedium(12))
                .tracking(0.3)
                .foregroundColor(SettingsTokens.textGrey)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var contactRow: some View {
        Link(destination: contactMailURL) {
            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SettingsTokens.brandPink)
                    .frame(width: 24)

                Text(String(localized: "お問い合わせ", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(SettingsTokens.textDark)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SettingsTokens.textGrey)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var demoDataRow: some View {
        if let demoURL = Bundle.main.url(forResource: "[LINE] Sato Chihiroとのトーク", withExtension: "txt") {
            ShareLink(item: demoURL) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SettingsTokens.textGrey)
                        .frame(width: 24)

                    Text(String(localized: "デモデータをダウンロード", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(14))
                        .tracking(0.42)
                        .foregroundColor(SettingsTokens.textDark)

                    Spacer()

                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SettingsTokens.textGrey)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            // 配置ファイルがない環境でもカードの高さを維持する
            HStack {
                Text(String(localized: "デモデータをダウンロード", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(SettingsTokens.textMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(SettingsTokens.brandPink)

                Text(String(localized: "削除中...", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(16))
                    .tracking(0.48)
                    .foregroundColor(SettingsTokens.textDark)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(SettingsTokens.strokeBrown, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Contact Mail

    private var contactMailURL: URL {
        let subject = String(localized: "【めろとーく】お問い合わせ", bundle: LanguageManager.appBundle)
        let appVersionLabel = String(localized: "アプリバージョン", bundle: LanguageManager.appBundle)
        let iosVersionLabel = String(localized: "iOSバージョン", bundle: LanguageManager.appBundle)
        let deviceLabel = String(localized: "端末", bundle: LanguageManager.appBundle)
        let body = """


        ---
        \(appVersionLabel): \(Constants.App.version)
        \(iosVersionLabel): \(UIDevice.current.systemVersion)
        \(deviceLabel): \(UIDevice.current.model)
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Constants.App.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url ?? URL(string: "mailto:\(Constants.App.supportEmail)") {
            return url
        }
        // mailto: は常に有効なURL
        return URL(string: "mailto:")!
    }

    // MARK: - Methods

    private func performSignOut() {
        boardAuthService.signOut()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AnalyticsManager.shared.track("settings_signout")
            dismiss()
        }
    }

    private func performDeleteAccount(authorization: ASAuthorization) async {
        await MainActor.run { isDeletingAccount = true }
        do {
            try await boardAuthService.reauthenticateAndDeleteAccount(authorization: authorization)
            AnalyticsManager.shared.track("settings_account_delete_success")
            await MainActor.run {
                isDeletingAccount = false
                showingDeleteAccountReauth = false
                dismiss()
            }
        } catch {
            print("[Settings] Account delete failed: \(error)")
            await MainActor.run {
                isDeletingAccount = false
                showingDeleteAccountReauth = false
                deleteAccountError = String(localized: "アカウントの削除に失敗しました。もう一度お試しください。", bundle: LanguageManager.appBundle)
            }
        }
    }

    private func deleteAllData() {
        AnalyticsManager.shared.track("settings_action", properties: ["action": "delete_data"])
        isDeleting = true

        Task {
            do {
                // SwiftDataのすべてのデータを削除
                try modelContext.delete(model: StoredAnalysisResult.self)
                try modelContext.delete(model: StoredMonthlySummary.self)
                try modelContext.delete(model: StoredChatSession.self)
                try modelContext.save()

                // Gemini同意もリセット（@AppStorage経由で統一）
                await MainActor.run {
                    hasAgreedConsultation = false
                    hasAgreedPersonaChat = false
                    isDeleting = false
                    showingDeleteSuccess = true
                }
            } catch {
                print("データ削除エラー: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(LanguageManager.shared)
}
