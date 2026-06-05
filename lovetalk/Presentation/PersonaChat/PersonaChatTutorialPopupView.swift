import SwiftUI

// MARK: - Persona Chat Tutorial Popup
/// 初回表示ポップアップ：ペルソナチャット機能の紹介
struct PersonaChatTutorialPopupView: View {
    let onClose: () -> Void

    @State private var showContent = false

    // NewHome tokens
    private let brandPink = MeloColors.Brand.pink
    private let filledPink = MeloColors.Brand.pink
    private let brownStroke = MeloColors.Text.primary
    private let textDark = MeloColors.Text.primary
    private let textSub = MeloColors.Text.secondary

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { }

            cardContent
                .scaleEffect(showContent ? 1.0 : 0.9)
                .opacity(showContent ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showContent = true
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Character — 2D meromaru waving
            Image("char_meromaru_3d")
                .resizable()
                .scaledToFit()
                .frame(height: 90)
                .padding(.top, 28)

            // Title
            Text(String(localized: "AIチャットへようこそ！", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(20))
                .foregroundColor(textDark)
                .padding(.top, 14)

            // Description
            Text(String(localized: "LINEのトーク履歴をもとに\n相手の性格や口調をAIが再現します\nまるで本人とチャットしている感覚で\n会話の練習や気持ちの整理ができます", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(13))
                .foregroundColor(textSub)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.top, 10)
                .padding(.horizontal, 16)

            // Steps
            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", text: String(localized: "診断済みの相手を選ぶ", bundle: LanguageManager.appBundle))
                stepRow(number: "2", text: String(localized: "AIが相手の話し方を再現", bundle: LanguageManager.appBundle))
                stepRow(number: "3", text: String(localized: "自由にチャットしてみよう", bundle: LanguageManager.appBundle))
            }
            .padding(.top, 18)
            .padding(.horizontal, 24)

            // Close button — flat pink pill
            Button {
                HapticManager.medium()
                dismissThen { onClose() }
            } label: {
                Text(String(localized: "はじめる", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(filledPink)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(brownStroke, lineWidth: 1)
                )
        )
        .padding(.horizontal, 28)
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(brandPink)
                )

            Text(text)
                .font(MeloFonts.zenMaruOrFallback(13))
                .foregroundColor(textDark)
        }
    }

    private func dismissThen(_ action: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action()
        }
    }
}
