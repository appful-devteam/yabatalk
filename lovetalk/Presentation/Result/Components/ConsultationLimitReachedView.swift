import SwiftUI

struct ConsultationLimitReachedView: View {
    let tier: SubscriptionTier
    let reason: String
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    private let plusGradient = LinearGradient(
        colors: [MeloColors.Brand.pinkLight, MeloColors.Brand.pinkLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 20) {
            Image("char_meromaru_3d")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)

            Text(String(localized: "相談の制限に達しました", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(18))
                .foregroundColor(MeloColors.Text.primary)

            Text(reason)
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(MeloColors.Text.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Text(String(localized: "Premium+なら回数制限なし！\nめろまるに何度でも相談できます", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(13))
                .foregroundColor(MeloColors.Brand.pinkLight)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                HapticManager.medium()
                onUpgrade()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(String(localized: "Premium+にアップグレード", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(16))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(plusGradient)
                        .shadow(color: MeloColors.Brand.pinkLight.opacity(0.4), radius: 12, x: 0, y: 6)
                )
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Text(String(localized: "閉じる", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(MeloColors.Text.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: MeloColors.Brand.pinkLight.opacity(0.2), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 32)
    }
}
