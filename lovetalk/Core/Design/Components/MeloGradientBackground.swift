import SwiftUI

struct MeloGradientBackground: View {
    let style: BackgroundStyle

    enum BackgroundStyle {
        case standard
        case subtle
        case warm
        /// 結果画面用：鮮やかなホットピンクグラデーション
        case result
    }

    var body: some View {
        switch style {
        case .standard:
            LinearGradient(
                colors: [
                    MeloColors.Dark.bg,
                    MeloColors.Dark.bg,
                    MeloColors.Dark.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

        case .subtle:
            LinearGradient(
                colors: [
                    MeloColors.Dark.bgElevated,
                    MeloColors.Dark.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

        case .warm:
            LinearGradient(
                colors: [
                    MeloColors.Dark.bg,
                    MeloColors.Dark.bg,
                    MeloColors.Dark.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

        case .result:
            LinearGradient(
                colors: [MeloColors.Dark.bgElevated, MeloColors.Dark.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - View Modifier
struct MeloBackgroundModifier: ViewModifier {
    let style: MeloGradientBackground.BackgroundStyle

    func body(content: Content) -> some View {
        content
            .background(MeloGradientBackground(style: style))
    }
}

extension View {
    func meloBackground(_ style: MeloGradientBackground.BackgroundStyle = .standard) -> some View {
        modifier(MeloBackgroundModifier(style: style))
    }
}

// MARK: - Animated Background
struct MeloAnimatedBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                MeloColors.Dark.accent.opacity(0.18),
                MeloColors.Dark.accent.opacity(0.10),
                MeloColors.Member.partner.opacity(0.10), // TODO(dark): 要確認（partner ブルーの装飾グラデ）
                MeloColors.Dark.accent.opacity(0.10)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Decorative Circles
struct MeloDecorativeCircles: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(MeloColors.Dark.accent.opacity(0.05))
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)

            Circle()
                .fill(MeloColors.Dark.accent.opacity(0.05))
                .frame(width: 200, height: 200)
                .offset(x: 150, y: -100)

            Circle()
                .fill(MeloColors.Dark.accent.opacity(0.05))
                .frame(width: 250, height: 250)
                .offset(x: -50, y: 300)
        }
    }
}

// MARK: - Preview
#Preview {
    TabView {
        ZStack {
            MeloGradientBackground(style: .standard)
            VStack {
                Text("Standard")
                    .font(MeloTypography.title)
            }
        }
        .tabItem { Text("Standard") }

        ZStack {
            MeloGradientBackground(style: .subtle)
            VStack {
                Text("Subtle")
                    .font(MeloTypography.title)
            }
        }
        .tabItem { Text("Subtle") }

        ZStack {
            MeloGradientBackground(style: .warm)
            VStack {
                Text("Warm")
                    .font(MeloTypography.title)
            }
        }
        .tabItem { Text("Warm") }

        ZStack {
            MeloAnimatedBackground()
            VStack {
                Text("Animated")
                    .font(MeloTypography.title)
            }
        }
        .tabItem { Text("Animated") }
    }
}
