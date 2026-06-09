import SwiftUI

// MARK: - Terms Consent View
/// 初回起動時の利用規約・プライバシーポリシー同意画面 — NewHome デザイン準拠
struct TermsConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false

    // Design tokens — dark theme
    private let brandPink = MeloColors.Dark.accent
    private let filledPink = MeloColors.Dark.accent
    private let brownStroke = MeloColors.Dark.cardStroke
    private let textPrimary = MeloColors.Dark.textPrimary
    private let textBody = MeloColors.Dark.textPrimary
    private let textMuted = MeloColors.Dark.textSecondary
    private let textFaint = MeloColors.Dark.textSecondary

    var body: some View {
        ZStack {
            // 背景: 黒地グラデ
            LinearGradient(
                colors: [MeloColors.Dark.bg, MeloColors.Dark.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 12)

                    // 2D mascot (doll)
                    Image("char_meromaru_3d")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)

                    // タイトル
                    Text(String(localized: "ご利用の前に", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(22))
                        .foregroundColor(textPrimary)

                    // サブタイトル
                    Text(String(localized: "利用規約とプライバシーポリシーをご確認ください", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(textBody)
                        .multilineTextAlignment(.center)

                    // 概要カード
                    summaryCard

                    // AI データ共有に関する説明カード
                    aiDataSharingCard

                    // リンク行
                    linkButtons

                    // CTAボタン
                    agreeButton

                    // 同意せずやめるボタン
                    Button {
                        HapticManager.light()
                        // アプリをバックグラウンドへ退避（実質終了）
                        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                    } label: {
                        Text(String(localized: "同意せずやめる", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(13))
                            .foregroundColor(textMuted)
                    }

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Summary Card (white + 1pt brown stroke, radius 10)

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryRow(icon: "iphone", text: String(localized: "トーク履歴は端末内にのみ保存されます", bundle: LanguageManager.appBundle))
            summaryRow(icon: "brain.head.profile", text: String(localized: "AI機能利用時はGoogle LLC（Gemini API）へのデータ送信に別途同意が必要です", bundle: LanguageManager.appBundle))
            summaryRow(icon: "chart.bar.fill", text: String(localized: "アプリ改善のため匿名統計を収集します", bundle: LanguageManager.appBundle))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(brownStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - AI Data Sharing Notice Card (card + 1pt accent stroke)

    private var aiDataSharingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(brandPink)
                Text(String(localized: "第三者AIサービスとのデータ共有について", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(textPrimary)
            }

            Text(String(localized: "本アプリの一部のAI機能（AIサマリー・返信提案・擬人化チャット）では、お客様のトーク履歴の一部を Google LLC が提供する Gemini API に送信します。", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(12))
                .foregroundColor(textBody)
                .lineSpacing(5)

            VStack(alignment: .leading, spacing: 6) {
                aiDataRow(String(localized: "送信先: Google LLC（Gemini API）", bundle: LanguageManager.appBundle))
                aiDataRow(String(localized: "送信データ: メッセージ本文・送信者名・送信日時", bundle: LanguageManager.appBundle))
                aiDataRow(String(localized: "メディア（画像・動画・スタンプ）は送信されません", bundle: LanguageManager.appBundle))
                aiDataRow(String(localized: "AI機能の初回利用時に別途同意が必要です", bundle: LanguageManager.appBundle))
            }

            Text(String(localized: "AI機能を利用しない場合、トーク履歴が外部に送信されることはありません。詳細はプライバシーポリシーをご確認ください。", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(11))
                .foregroundColor(textMuted)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(brandPink, lineWidth: 1)
                )
        )
    }

    private func aiDataRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 11))
                .foregroundColor(brandPink)
                .padding(.top, 1)
            Text(text)
                .font(MeloFonts.zenMaruOrFallback(12))
                .foregroundColor(textBody)
                .lineSpacing(4)
        }
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(brandPink)
                .frame(width: 24)

            Text(text)
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Link Buttons (outlined pink pills)

    private var linkButtons: some View {
        VStack(spacing: 10) {
            Button {
                HapticManager.light()
                showTermsOfService = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(localized: "利用規約を読む", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(14))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(brandPink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MeloColors.Dark.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(brandPink, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.light()
                showPrivacyPolicy = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(localized: "プライバシーポリシーを読む", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(14))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(brandPink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MeloColors.Dark.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(brandPink, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Agree Button (flat pink pill)

    private var agreeButton: some View {
        Button {
            HapticManager.medium()
            AnalyticsManager.shared.track("terms_agreed")
            AnalyticsManager.shared.tutorialComplete()
            UserDefaults.standard.set(true, forKey: Constants.StorageKeys.hasAgreedToTerms)
            dismiss()
        } label: {
            Text(String(localized: "同意して始める", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(16))
                .foregroundColor(MeloColors.Dark.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(filledPink)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - Preview
#Preview {
    TermsConsentView()
}
