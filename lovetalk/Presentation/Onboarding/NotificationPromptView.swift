import SwiftUI
import UserNotifications

// MARK: - Notification Prompt View
/// オンボーディング中の通知許可説明画面 — NewHome デザイン準拠
struct NotificationPromptView: View {
    @Environment(\.dismiss) private var dismiss

    // Design tokens (shared across onboarding)
    private let brandPink = MeloColors.Brand.pink
    private let filledPink = MeloColors.Brand.pink
    private let brownStroke = MeloColors.Text.primary
    private let textPrimary = MeloColors.Text.primary
    private let textMuted = MeloColors.Text.secondary
    private let textFaint = MeloColors.Text.secondary

    var body: some View {
        ZStack {
            // 背景: ソフトピンクグラデ（FFF1F4 → FFE5EE）
            LinearGradient(
                colors: [MeloColors.Surface.pinkPale, MeloColors.Surface.pinkPale],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 2D mascot (wave)
                Image("char_meromaru_3d")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)

                // タイトル
                Text(String(localized: "投稿の通知を受け取ろう", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(22))
                    .foregroundColor(textPrimary)
                    .padding(.top, 20)

                // 説明
                Text(String(localized: "いいね・返信・フォローなどの\nお知らせをリアルタイムで受け取れます", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(MeloColors.Text.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)

                // 通知の種類一覧カード — 白 + 1pt brown stroke, radius 10
                VStack(alignment: .leading, spacing: 14) {
                    notificationFeatureRow(icon: "heart.fill", text: String(localized: "投稿にいいねがあった時", bundle: LanguageManager.appBundle))
                    notificationFeatureRow(icon: "bubble.left.fill", text: String(localized: "投稿に返信があった時", bundle: LanguageManager.appBundle))
                    notificationFeatureRow(icon: "person.badge.plus", text: String(localized: "誰かにフォローされた時", bundle: LanguageManager.appBundle))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(brownStroke, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 28)
                .padding(.top, 22)

                Spacer()

                // 次へボタン — フラットピンク pill
                Button {
                    HapticManager.medium()
                    requestNotificationPermission()
                } label: {
                    Text(String(localized: "次へ", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(filledPink)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                // スキップ
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Text(String(localized: "あとで", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(13))
                        .foregroundColor(textMuted)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Feature Row

    private func notificationFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(brandPink)
                .frame(width: 24)

            Text(text)
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(MeloColors.Text.primary)
        }
    }

    // MARK: - Permission Request

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            }

            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NotificationPromptView()
}
