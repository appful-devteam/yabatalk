import SwiftUI

// MARK: - Consent Feature Type
enum ConsentFeatureType {
    case consultation  // 相談機能
    case personaChat   // 擬人化チャット

    var consentKey: String {
        switch self {
        case .consultation: return "hasAgreedToGeminiTerms_v2"
        case .personaChat: return "hasAgreedToPersonaChatTerms"
        }
    }

    /// 送信先プロバイダ名を差し込んだ機能説明（provider は Remote Config 駆動）。
    func featureDescription(provider: AIProviderInfo) -> String {
        let fmt: String
        switch self {
        case .consultation:
            fmt = String(localized: "相談機能では、お客様がインポートしたLINEのトーク履歴を、%1$@ が提供する生成AI「%2$@」に送信し、相談への回答を生成します。", bundle: LanguageManager.appBundle)
        case .personaChat:
            fmt = String(localized: "擬人化チャットでは、お客様がインポートしたLINEのトーク履歴を、%1$@ が提供する生成AI「%2$@」に送信し、相手の性格を再現したAIチャットを生成します。", bundle: LanguageManager.appBundle)
        }
        return String(format: fmt, provider.companyShort, provider.serviceName)
    }
}

// MARK: - Gemini Consent View
/// トーク履歴の外部送信に関する同意モーダル
struct GeminiConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isAgreed = false

    let featureType: ConsentFeatureType
    let onAgree: () -> Void

    /// AI データ送信先プロバイダ（Remote Config 駆動・既定 Qwen/Alibaba Cloud Singapore）。
    private var provider: AIProviderInfo { RemoteConfigService.shared.currentAIProvider }

    /// 相談機能用の後方互換イニシャライザ
    init(onAgree: @escaping () -> Void) {
        self.featureType = .consultation
        self.onAgree = onAgree
    }

    init(featureType: ConsentFeatureType, onAgree: @escaping () -> Void) {
        self.featureType = featureType
        self.onAgree = onAgree
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    dataRecipientBanner
                    dataTransmissionCard
                    providerDataHandlingCard
                    privacyWarningCard
                    disclaimerCard
                    agreeToggle
                    actionButtons
                }
                .padding(24)
            }
            .background(MeloGradientBackground(style: .subtle))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [MeloColors.Dark.accent, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 8)

            Text(String(localized: "トーク履歴の外部送信に関する同意", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(18))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .multilineTextAlignment(.center)

            Text(String(localized: "本機能を利用する前に、以下の内容をよくお読みください。", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(13))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Data Recipient Banner

    private var dataRecipientBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text(String(localized: "データ送信先", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(.white.opacity(0.9))
            }

            Text(provider.companyName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("\(provider.serviceName) (\(provider.endpoint))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                recipientDetailRow(
                    label: String(localized: "送信データ", bundle: LanguageManager.appBundle),
                    value: String(localized: "メッセージ本文・送信者名・送信日時", bundle: LanguageManager.appBundle)
                )
                recipientDetailRow(
                    label: String(localized: "利用目的", bundle: LanguageManager.appBundle),
                    value: featureType == .consultation
                        ? String(localized: "AIサマリー・返信提案の生成", bundle: LanguageManager.appBundle)
                        : String(localized: "擬人化AIチャットの生成", bundle: LanguageManager.appBundle)
                )
                recipientDetailRow(
                    label: String(localized: "非送信データ", bundle: LanguageManager.appBundle),
                    value: String(localized: "画像・動画・スタンプ等", bundle: LanguageManager.appBundle)
                )
                recipientDetailRow(
                    label: String(localized: "処理地域", bundle: LanguageManager.appBundle),
                    value: provider.region
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            // TODO(dark): 要確認（送信先バナーの独自インディゴ→紫グラデ。暗地でも白文字が読めるため据え置き）
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.35, blue: 0.65), Color(red: 0.35, green: 0.25, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        )
    }

    private func recipientDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 72, alignment: .trailing)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineSpacing(3)
        }
    }

    // MARK: - Data Transmission Card

    private var dataTransmissionCard: some View {
        consentCard(
            icon: "arrow.up.doc.fill",
            iconColor: .blue,
            title: String(localized: "この機能について", bundle: LanguageManager.appBundle)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                consentText(featureType.featureDescription(provider: provider))
            }
        }
    }

    // MARK: - Provider Data Handling Card

    private var providerDataHandlingCard: some View {
        consentCard(
            icon: "server.rack",
            iconColor: .purple,
            title: String(format: String(localized: "%@ によるデータの取り扱い", bundle: LanguageManager.appBundle), provider.companyShort)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                consentText(String(format: String(localized: "本アプリは %1$@ が提供する生成AI「%2$@」を利用しています。送信されたデータの取り扱いは、%1$@ の利用規約およびプライバシーポリシーに従います。", bundle: LanguageManager.appBundle), provider.companyShort, provider.serviceName))

                bulletItem(String(format: String(localized: "送信データは、AIによる回答生成のため %1$@ のサーバー（%2$@ リージョン）上で処理されます。", bundle: LanguageManager.appBundle), provider.companyShort, provider.region))
                bulletItem(String(localized: "送信後のデータの保持・利用については、下記の利用規約・プライバシーポリシーをご確認ください。", bundle: LanguageManager.appBundle))
                bulletItem(String(localized: "本アプリの開発者は、送信後のデータ管理には関与しません。", bundle: LanguageManager.appBundle))

                linkButton(
                    title: String(format: String(localized: "%@ 利用規約", bundle: LanguageManager.appBundle), provider.serviceName),
                    url: provider.termsURL
                )

                linkButton(
                    title: String(format: String(localized: "%@ プライバシーポリシー", bundle: LanguageManager.appBundle), provider.companyShort),
                    url: provider.privacyURL
                )
            }
        }
    }

    // MARK: - Privacy Warning Card

    private var privacyWarningCard: some View {
        consentCard(
            icon: "person.2.fill",
            iconColor: .orange,
            title: String(localized: "トーク相手のプライバシーについて", bundle: LanguageManager.appBundle)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                consentText(String(localized: "トーク履歴にはお客様以外の方（トーク相手）の発言や個人情報が含まれています。", bundle: LanguageManager.appBundle))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text(String(localized: "日本の個人情報保護法に基づき、第三者の個人情報を外部サービスに提供する際は、原則としてその方の同意が必要です。本機能のご利用にあたっては、お客様の責任において、トーク相手のプライバシーに十分ご配慮ください。", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(12))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .lineSpacing(5)
                }

                consentText(String(localized: "また、LINEの利用規約では、第三者の個人情報を不正に収集・開示・提供する行為が禁止されています。エクスポートしたトーク履歴の利用については、お客様ご自身の責任で適切にご判断ください。", bundle: LanguageManager.appBundle))
            }
        }
    }

    // MARK: - Disclaimer Card

    private var disclaimerCard: some View {
        consentCard(
            icon: "info.circle.fill",
            iconColor: MeloColors.Dark.textSecondary,
            title: String(localized: "免責事項", bundle: LanguageManager.appBundle)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                bulletItem(String(format: String(localized: "本アプリの開発者は、%@ に送信されたデータの取り扱いについて責任を負いません", bundle: LanguageManager.appBundle), provider.serviceName))
                bulletItem(String(format: String(localized: "データ送信後の取り扱いは %@ のプライバシーポリシーおよび利用規約に従います", bundle: LanguageManager.appBundle), provider.companyName))
                bulletItem(String(localized: "本機能の利用により生じたいかなる損害（トーク相手との関係悪化、プライバシー侵害に関する紛争等を含む）についても、本アプリの開発者は一切の責任を負いません", bundle: LanguageManager.appBundle))
                bulletItem(String(localized: "本同意は、設定画面の「AIデータ共有」から、データを削除せずにいつでも取り消すことができます", bundle: LanguageManager.appBundle))
            }
        }
    }

    // MARK: - Agree Toggle

    private var agreeToggle: some View {
        Button {
            HapticManager.light()
            isAgreed.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(isAgreed ? MeloColors.Dark.accent : MeloColors.Dark.textSecondary)

                Text(String(format: String(localized: "上記の内容をすべて確認し、トーク履歴の一部が %1$@（%2$@）に送信されることに同意します", bundle: LanguageManager.appBundle), provider.companyName, provider.serviceName))
                    .font(MeloFonts.zenMaruOrFallback(13))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isAgreed ? MeloColors.Dark.accent.opacity(0.08) : MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isAgreed ? MeloColors.Dark.accent.opacity(0.3) : MeloColors.Dark.divider, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.medium()
                UserDefaults.standard.set(true, forKey: featureType.consentKey)
                dismiss()
                onAgree()
            } label: {
                Text(String(localized: "同意して開始", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(16))
                    .foregroundColor(isAgreed ? MeloColors.Dark.onAccent : MeloColors.Dark.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isAgreed ? AnyShapeStyle(MeloColors.Dark.accentGradient) : AnyShapeStyle(MeloColors.Dark.bgElevated))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isAgreed)

            Button {
                HapticManager.light()
                dismiss()
            } label: {
                Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(MeloColors.Dark.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Reusable Components

    private func consentCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(MeloFonts.zenMaruOrFallback(15))
                    .foregroundColor(MeloColors.Dark.textPrimary)
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(MeloColors.Dark.card)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
        )
    }

    private func consentText(_ text: String) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruOrFallback(12))
            .foregroundColor(MeloColors.Dark.textSecondary)
            .lineSpacing(5)
    }

    private func consentSubheading(_ text: String) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruOrFallback(13))
            .foregroundColor(MeloColors.Dark.textPrimary)
            .padding(.top, 4)
    }

    private func bulletItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 12))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .padding(.top, 1)
            Text(text)
                .font(MeloFonts.zenMaruOrFallback(12))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .lineSpacing(5)
        }
    }

    private func linkButton(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                Text(title)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .underline()
            }
            .foregroundColor(MeloColors.Dark.accent)
        }
        .padding(.top, 4)
    }

    // MARK: - Static Helpers

    /// 機能別の同意状態チェック
    static func hasAgreed(for featureType: ConsentFeatureType) -> Bool {
        UserDefaults.standard.bool(forKey: featureType.consentKey)
    }
}
