import SwiftUI

// MARK: - Enable Swipe Back Gesture
/// navigationBarHidden(true)使用時でもスワイプバックを有効にするモディファイア

extension View {
    /// 左端スワイプでの戻るジェスチャーを有効にする
    func enableSwipeBack() -> some View {
        background(SwipeBackHelper())
    }
}

private struct SwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackViewController {
        SwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: SwipeBackViewController, context: Context) {}
}

private final class SwipeBackViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // NavigationControllerのinteractivePopGestureRecognizerを再有効化
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}
