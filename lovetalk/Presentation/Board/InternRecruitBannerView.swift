import SwiftUI

// MARK: - Intern Recruit Banner
/// 自社広告バナー — 取り下げ時は BoardFeedView から呼び出し行を削除するだけでOK
/// Google Form URL やテキストもここで一元管理
struct InternRecruitBannerView: View {

    // MARK: - Configuration（変更はここだけ）
    private let formURL = "https://docs.google.com/forms/d/e/1FAIpQLSen9uobB1MHmCbNiMP3doC3QtnZEB9xF7GiKfQmF9y5DNGU-g/viewform"
    private let isEnabled = true  // false にするとバナー非表示

    var body: some View {
        if isEnabled {
            Button {
                HapticManager.light()
                if let url = URL(string: formURL) {
                    UIApplication.shared.open(url)
                }
            } label: {
                bannerContent
            }
            .buttonStyle(BannerButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Banner Content
    /// NewHomeView の CTA カードと揃えた、白ベース + ピンク枠の軽やかなプロモバナー。
    /// 左: めろまる (yahho) / 中央: コピー / 右: ピンク pill CTA
    private var bannerContent: some View {
        HStack(spacing: 12) {
            // 左: めろまるキャラ (2D)
            Image("char_meromaru_3d")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            // 中央: テキスト群
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "SNS運用インターン生募集中!", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(14))
                    .tracking(0.42)
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(String(localized: "一緒にめろとーくをバズらせませんか?", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右: ピンク丸 + chevron (NewHomeView の CTA カード末尾と同じ)
            ZStack {
                Circle()
                    .fill(MeloColors.Dark.accentGradient)
                    .frame(width: 29, height: 29)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MeloColors.Dark.onAccent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MeloColors.Dark.accent, lineWidth: 1)
                )
        )
    }

}

// MARK: - Banner Button Style

private struct BannerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        MeloColors.Dark.bg.ignoresSafeArea()
        VStack {
            InternRecruitBannerView()
            Spacer()
        }
    }
}
