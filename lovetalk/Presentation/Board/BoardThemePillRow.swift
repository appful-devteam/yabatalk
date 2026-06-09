import SwiftUI

/// 投稿カード上で `posts.themes` をピル列として表示する共通コンポーネント。
/// フィード / 検索 / プロフィール / 投稿詳細など投稿が表示されるすべての場所で再利用する。
struct BoardThemePillRow: View {
    let themes: [String]
    var maxDisplayed: Int = 3

    var body: some View {
        let display = Array(themes.prefix(maxDisplayed))
        if display.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(Array(display.enumerated()), id: \.offset) { _, label in
                    themePill(label)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func themePill(_ label: String) -> some View {
        Text("#\(label)")
            .font(MeloFonts.zenMaruMedium(11))
            .tracking(0.3)
            .foregroundColor(MeloColors.Dark.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        Capsule()
                            .stroke(MeloColors.Dark.accent.opacity(0.5), lineWidth: 0.8)
                    )
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        BoardThemePillRow(themes: ["パワハラ"])
        BoardThemePillRow(themes: ["セクハラ", "モラハラ"])
        BoardThemePillRow(themes: ["カスハラ", "その他", "ぶっちゃけ相談"])
        BoardThemePillRow(themes: [])
    }
    .padding()
    .background(MeloColors.Dark.bg)
}
