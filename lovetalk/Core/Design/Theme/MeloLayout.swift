import SwiftUI
import UIKit

/// 端末サイズに応じて伸縮する余白などのレイアウト指標。
/// iPhone SE (375pt) から iPad (~1024pt) まで、固定 pt ではなく端末幅に対する比率で算出する。
enum MeloLayout {

    /// 現在の端末幅 (point)。
    /// iOS 16+ では UIScreen.main は deprecated だが、ホームスクリーンサイズ取得用途では
    /// 連結中の WindowScene から読み出す。フォールバックは iPhone 16 標準値。
    @MainActor
    static var deviceWidth: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.screen.bounds.width ?? 393
    }

    /// メインコンテンツ (掲示板投稿カード本文等) の横余白。
    /// 端末幅の約 16% で、36〜96pt にクランプ。投稿が端末中央にゆったり収まるよう広めに取る。
    @MainActor
    static var contentHorizontalPadding: CGFloat {
        let raw = deviceWidth * 0.16
        return max(36, min(96, raw))
    }

    /// 掲示板投稿カード (BoardFeedPostCard) の横余白。
    /// 端末幅の約 7.5% (24〜32pt)。コンテンツ余白より狭く、投稿の本文を画面いっぱいに使う。
    /// Board / MyPage / 通知など、投稿カードを表示する全ページで同じ値を使う。
    @MainActor
    static var boardPostHorizontalPadding: CGFloat {
        min(32, max(24, deviceWidth * 0.075))
    }

    /// ヘッダー / タブ行 / カテゴリピル行など、横並びのアイコン/ラベルが集まるエリアの横余白。
    /// 端末幅の約 7% (20〜44pt)。投稿本文より狭めに取り、アイコン群が中央に詰まらないように。
    @MainActor
    static var headerHorizontalPadding: CGFloat {
        let raw = deviceWidth * 0.07
        return max(20, min(44, raw))
    }

    /// タイトル行 (ホーム+検索+通知+Premium 等) の横余白。ヘッダー余白よりさらに狭め。
    /// 端末幅の約 4% (12〜28pt)。要素を画面端ぎりぎりまで広げて使う。
    @MainActor
    static var titleHorizontalPadding: CGFloat {
        let raw = deviceWidth * 0.04
        return max(12, min(28, raw))
    }

    /// FAB (右下浮遊ボタン) の trailing 余白。端末幅の約 4%、12〜32pt。
    /// 画面外にはみ出さない範囲で、なるべく右側に寄せる。
    @MainActor
    static var fabTrailing: CGFloat {
        let raw = deviceWidth * 0.04
        return max(12, min(32, raw))
    }
}

// MARK: - View Modifier

/// 横余白を端末幅に合わせてレスポンシブに付与する。
struct AdaptiveHorizontalPaddingModifier: ViewModifier {
    let ratio: CGFloat
    let minPadding: CGFloat
    let maxPadding: CGFloat

    func body(content: Content) -> some View {
        content.padding(.horizontal, padding)
    }

    @MainActor
    private var padding: CGFloat {
        let raw = MeloLayout.deviceWidth * ratio
        return max(minPadding, min(maxPadding, raw))
    }
}

extension View {
    /// 端末幅に応じた横余白を付与する (デフォルトはコンテンツ余白)。
    func adaptiveHorizontalPadding(
        ratio: CGFloat = 0.11,
        min: CGFloat = 24,
        max: CGFloat = 72
    ) -> some View {
        modifier(AdaptiveHorizontalPaddingModifier(ratio: ratio, minPadding: min, maxPadding: max))
    }
}
