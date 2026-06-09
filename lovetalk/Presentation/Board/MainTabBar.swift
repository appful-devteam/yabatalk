import SwiftUI

// MARK: - Main Tab Bar (Figma design — center popped-out melomaru)
/// アプリ全体のカスタムタブバー。中央に めろまる が飛び出す5タブ構成。
struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    var homeUnreadCount: Int = 0
    var onDoubleTap: ((MainTab) -> Void)? = nil

    /// バー本体の高さ。RootView の .safeAreaInset でこの高さ分だけ
    /// ページコンテンツの下端インセットが押し上がる。
    static let barHeight: CGFloat = 70

    /// ピル形状の左右マージン (タブバーがフローティングカードに見えるように)。
    private static let horizontalMargin: CGFloat = 12
    /// ピル形状の角丸 (= 内側コンテンツ高さの半分でフルピル化)。
    private static let cornerRadius: CGFloat = 35

    // Figma 基準: 402pt幅フレームに対する座標。端末幅で比例配置する。
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let innerWidth = width - Self.horizontalMargin * 2
            // 5等配のスロット中心 (ピル内の有効幅に対して比例配置)
            let slotCenters: [CGFloat] = [
                Self.horizontalMargin + innerWidth * (56 / 402),
                Self.horizontalMargin + innerWidth * (121 / 402),
                width / 2,
                Self.horizontalMargin + innerWidth * (275 / 402),
                Self.horizontalMargin + innerWidth * (336 / 402)
            ]

            ZStack(alignment: .top) {
                // サイドのアイコン（4つ）
                ForEach(Array(MainTab.allCases.enumerated()), id: \.element) { idx, tab in
                    if tab != .diagnose {
                        tabItem(tab, isCenter: false)
                            .position(x: slotCenters[idx], y: 30)
                    }
                }

                // 中央（めろまる）飛び出しタブ
                if let centerIdx = MainTab.allCases.firstIndex(of: .diagnose) {
                    tabItem(.diagnose, isCenter: true)
                        .position(x: slotCenters[centerIdx], y: 14)
                }
            }
        }
        .frame(height: Self.barHeight)
        .background(
            // ピル形状のダークカード + アクセントの淡いグロー
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(MeloColors.Dark.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                )
                .shadow(color: MeloColors.Dark.accent.opacity(0.18), radius: 8, x: 0, y: 2)
                .padding(.horizontal, Self.horizontalMargin)
        )
    }

    @ViewBuilder
    private func tabItem(_ tab: MainTab, isCenter: Bool) -> some View {
        let isSelected = selectedTab == tab
        Button {
            if selectedTab == tab {
                HapticManager.light()
                onDoubleTap?(tab)
            } else {
                HapticManager.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = tab
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: isCenter ? 0 : 1) {
                    tabIcon(for: tab, isSelected: isSelected, isCenter: isCenter)

                    Text(tab.localizedName)
                        .font(MeloFonts.zenMaruMedium(9))
                        .foregroundColor(
                            isSelected
                            ? MeloColors.Dark.accent
                            : MeloColors.Dark.textSecondary
                        )
                        .tracking(0.27)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if tab == .home && homeUnreadCount > 0 {
                    Text(homeUnreadCount > 99 ? "99+" : "\(homeUnreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 8, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab_\(tab.rawValue)")
    }

    /// 中央の診断タブだけは飛び出し演出のためカスタム PNG をそのまま表示。
    /// それ以外は新タブアイコン (`tabicon_xxx` / `tabicon_xxx_selected`) を使用。
    @ViewBuilder
    private func tabIcon(for tab: MainTab, isSelected: Bool, isCenter: Bool) -> some View {
        if isCenter {
            Image(tab.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 80)
        } else {
            Image(tabIconAssetName(for: tab, isSelected: isSelected))
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
        }
    }

    /// 通常 / 選択時で別アセットを返す。
    private func tabIconAssetName(for tab: MainTab, isSelected: Bool) -> String {
        let base: String
        switch tab {
        case .home: base = "tabicon_home"
        case .consultRoom: base = "tabicon_community"
        case .personaChat: base = "tabicon_chat"
        case .profile: base = "tabicon_profile"
        case .diagnose: base = tab.assetName  // (使われない)
        }
        return isSelected ? "\(base)_selected" : base
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        MainTabBar(selectedTab: .constant(.diagnose))
    }
    .background(MeloColors.Dark.bg)
}
