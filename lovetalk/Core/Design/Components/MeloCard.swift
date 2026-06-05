import SwiftUI

// MARK: - Card Style
enum MeloCardStyle {
    case standard       // 白背景 + 影
    case soft           // ソフトピンク背景
    case bordered       // ボーダー付き
    case gradient       // グラデーションボーダー
    case transparent    // 透明（グループ化用）
}

struct MeloCard<Content: View>: View {
    let content: Content
    let style: MeloCardStyle
    let padding: CGFloat
    let cornerRadius: CGFloat

    init(
        style: MeloCardStyle = .standard,
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 28,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }

    private var backgroundColor: Color {
        switch style {
        case .standard, .bordered, .gradient:
            return MeloColors.Surface.card
        case .soft:
            return MeloColors.Surface.pinkPale.opacity(0.5)
        case .transparent:
            return .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .bordered:
            return MeloColors.Brand.pinkDeep.opacity(0.15)
        default:
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .bordered: return 1.5
        default: return 0
        }
    }

    private var shadowColor: Color {
        switch style {
        case .standard:
            return .black.opacity(0.06)
        case .soft, .bordered:
            return .black.opacity(0.04)
        default:
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .standard: return 16
        case .soft, .bordered: return 8
        default: return 0
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .standard: return 4
        case .soft, .bordered: return 2
        default: return 0
        }
    }
}

// MARK: - Gradient Border Card
struct MeloGradientCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat

    init(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 28,
        borderWidth: CGFloat = 2.5,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(MeloColors.Surface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(MeloColors.Gradient.pinkPrimary, lineWidth: borderWidth)
            )
            .shadow(
                color: MeloColors.Brand.pinkDeep.opacity(0.12),
                radius: 16,
                x: 0,
                y: 6
            )
    }
}

// MARK: - Interactive Card
struct MeloInteractiveCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let action: () -> Void
    @State private var isPressed = false

    init(
        cornerRadius: CGFloat = 28,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            content
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(MeloColors.Surface.card)
                        .shadow(
                            color: .black.opacity(0.06),
                            radius: isPressed ? 8 : 16,
                            x: 0,
                            y: isPressed ? 2 : 4
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(MeloColors.Brand.pinkDeep.opacity(isPressed ? 0.3 : 0.1), lineWidth: 1.5)
                )
                .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Stat Card (数値表示用)
struct MeloStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String?
    let color: Color

    init(
        icon: String,
        title: String,
        value: String,
        unit: String? = nil,
        color: Color = MeloColors.Brand.pinkDeep
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.unit = unit
        self.color = color
    }

    var body: some View {
        VStack(spacing: 10) {
            // アイコン
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)

            // タイトル
            Text(title)
                .font(MeloTypography.caption)
                .foregroundColor(MeloColors.Text.secondary)

            // 値
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(MeloTypography.title)
                    .foregroundStyle(MeloColors.Gradient.pinkPrimary)

                if let unit = unit {
                    Text(unit)
                        .font(MeloTypography.caption)
                        .foregroundColor(MeloColors.Text.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(MeloColors.Surface.pinkPale.opacity(0.5))
        )
    }
}

// MARK: - List Row Card
struct MeloListRow<Content: View>: View {
    let content: Content
    let action: (() -> Void)?

    init(
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        if let action = action {
            Button {
                HapticManager.light()
                action()
            } label: {
                rowContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(MeloColors.Brand.pinkDeep.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MeloCard {
                Text("Standard Card")
                    .font(MeloTypography.headline)
            }

            MeloCard(style: .soft) {
                Text("Soft Card")
                    .font(MeloTypography.headline)
            }

            MeloCard(style: .bordered) {
                Text("Bordered Card")
                    .font(MeloTypography.headline)
            }

            MeloGradientCard {
                Text("Gradient Border Card")
                    .font(MeloTypography.headline)
            }

            MeloInteractiveCard(action: {}) {
                Text("Interactive Card - Tap me!")
                    .font(MeloTypography.headline)
            }

            HStack(spacing: 12) {
                MeloStatCard(icon: "message.fill", title: "メッセージ", value: "1,234", unit: "件")
                MeloStatCard(icon: "calendar", title: "期間", value: "90", unit: "日")
            }

            MeloListRow {
                HStack {
                    Text("List Row Item")
                        .font(MeloTypography.body)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(MeloColors.Text.secondary)
                }
            }
        }
        .padding(20)
    }
    .background(MeloColors.Surface.pinkPale)
}
