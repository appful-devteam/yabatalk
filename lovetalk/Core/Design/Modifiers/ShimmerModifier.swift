import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let animation: Animation
    let gradient: Gradient

    init(
        animation: Animation = .linear(duration: 1.5).repeatForever(autoreverses: false),
        gradient: Gradient = Gradient(colors: [
            .clear,
            Color.white.opacity(0.25),
            .clear
        ])
    ) {
        self.animation = animation
        self.gradient = gradient
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(animation) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(
        animation: Animation = .linear(duration: 1.5).repeatForever(autoreverses: false),
        gradient: Gradient = Gradient(colors: [.clear, Color.white.opacity(0.25), .clear])
    ) -> some View {
        modifier(ShimmerModifier(animation: animation, gradient: gradient))
    }
}

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(MeloColors.Dark.bgElevated)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Pulse Animation Modifier
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse() -> some View {
        modifier(PulseModifier())
    }
}

// MARK: - Glow Modifier
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isGlowing ? 0.6 : 0.3), radius: radius)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
    }
}

extension View {
    func glow(color: Color = MeloColors.Dark.accent, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        Text("Shimmer Effect")
            .font(MeloTypography.title)
            .foregroundStyle(MeloColors.Dark.accentGradient)
            .shimmer()

        VStack(alignment: .leading, spacing: 8) {
            SkeletonView(width: 200, height: 24)
            SkeletonView(width: 150, height: 16)
            SkeletonView(height: 16)
        }
        .padding()

        Image(systemName: "heart.fill")
            .font(.system(size: 60))
            .foregroundStyle(MeloColors.Dark.accentGradient)
            .pulse()

        Text("Glowing")
            .font(MeloTypography.headline)
            .foregroundColor(MeloColors.Dark.accent)
            .glow()
    }
    .padding()
    .meloBackground()
}
