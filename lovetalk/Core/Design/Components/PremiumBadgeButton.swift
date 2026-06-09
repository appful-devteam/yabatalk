import SwiftUI

// MARK: - Premium Badge Button (Figma node 671:621)
/// 各タブページの左上に配置する Premium バッジボタン。
/// - 既にプレミアム加入中なら非表示
/// - タップで Subscription シートを開く
struct PremiumBadgeButton: View {
    /// 同じヘッダー行に並ぶ他のボタン(検索/通知/歯車)と直径を合わせるための基準高さ。
    static let height: CGFloat = 32

    var source: String = "premium_badge"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MeloColors.Dark.onAccent)
                Text("Premium")
                    .font(MeloFonts.zenMaruOrFallback(14))
                    .foregroundColor(MeloColors.Dark.onAccent)
                    .tracking(0.42)
            }
            .padding(.horizontal, 8)
            .frame(height: Self.height)
            .background(Capsule().fill(MeloColors.Dark.accentGradient))
            .shadow(color: MeloColors.Dark.accent.opacity(0.45), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("premium_badge_button")
    }
}

#Preview {
    VStack {
        PremiumBadgeButton { }
        Spacer()
    }
    .padding()
    .background(MeloColors.Dark.bg)
}
