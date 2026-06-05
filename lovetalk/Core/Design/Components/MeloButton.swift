import SwiftUI

struct MeloButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let size: ButtonSize
    let isLoading: Bool
    let action: () -> Void

    enum ButtonStyle {
        case primary      // グラデーション塗りつぶし
        case secondary    // 白背景 + ボーダー
        case outline      // 透明 + ボーダー
        case cream        // クリーム色（黄色系）
        case ghost        // テキストのみ
    }

    enum ButtonSize {
        case large
        case medium
        case small

        var height: CGFloat {
            switch self {
            case .large: return 56
            case .medium: return 48
            case .small: return 40
            }
        }

        var font: Font {
            switch self {
            case .large: return MeloTypography.headline
            case .medium: return MeloTypography.bodyBold
            case .small: return MeloTypography.captionBold
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .large: return 18
            case .medium: return 16
            case .small: return 14
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .large: return 24
            case .medium: return 20
            case .small: return 16
            }
        }
    }

    init(
        title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        size: ButtonSize = .large,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }
                    Text(title)
                        .font(size.font)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .foregroundColor(textColor)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            MeloColors.Gradient.pinkPrimary
        case .secondary:
            Color.white
        case .outline, .ghost:
            Color.clear
        case .cream:
            MeloColors.Surface.pinkPale
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return MeloColors.Brand.pinkDeep
        case .outline:
            return MeloColors.Brand.pinkDeep
        case .cream:
            return MeloColors.Text.primary
        case .ghost:
            return MeloColors.Text.secondary
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary:
            return MeloColors.Brand.pinkDeep.opacity(0.3)
        case .outline:
            return MeloColors.Brand.pinkDeep
        case .cream:
            return MeloColors.Brand.pink
        default:
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .secondary: return 1.5
        case .outline: return 2
        case .cream: return 2
        default: return 0
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary:
            return MeloColors.Brand.pinkDeep.opacity(0.35)
        case .cream:
            return MeloColors.Brand.pink.opacity(0.3)
        default:
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .primary, .cream: return 12
        default: return 0
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .primary, .cream: return 6
        default: return 0
        }
    }
}

// MARK: - Pill Button (Compact)
struct MeloPillButton: View {
    let title: String
    let icon: String?
    let style: MeloButton.ButtonStyle
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        style: MeloButton.ButtonStyle = .secondary,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(MeloTypography.bodyBold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .foregroundColor(isSelected ? .white : MeloColors.Brand.pinkDeep)
            .background(
                isSelected
                    ? AnyView(MeloColors.Gradient.pinkPrimary)
                    : AnyView(Color.white)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : MeloColors.Brand.pinkDeep.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(
                color: isSelected ? MeloColors.Brand.pinkDeep.opacity(0.3) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
}

// MARK: - Icon Button
struct MeloIconButton: View {
    let icon: String
    let size: CGFloat
    let style: MeloButton.ButtonStyle
    let action: () -> Void

    init(
        icon: String,
        size: CGFloat = 44,
        style: MeloButton.ButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.style = style
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(style == .primary ? .white : MeloColors.Brand.pinkLight)
                .frame(width: size, height: size)
                .background(
                    style == .primary
                        ? AnyView(MeloColors.Gradient.pinkPrimary)
                        : AnyView(Color.white)
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(style == .primary ? Color.clear : MeloColors.Brand.pinkLight.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Group {
                MeloButton(title: "プライマリボタン", icon: "heart.fill", style: .primary) {}
                MeloButton(title: "セカンダリボタン", style: .secondary) {}
                MeloButton(title: "アウトラインボタン", style: .outline) {}
                MeloButton(title: "クリームボタン", style: .cream) {}
                MeloButton(title: "読み込み中...", style: .primary, isLoading: true) {}
            }

            Divider()

            Group {
                MeloButton(title: "Mediumサイズ", style: .primary, size: .medium) {}
                MeloButton(title: "Smallサイズ", style: .secondary, size: .small) {}
            }

            Divider()

            HStack(spacing: 12) {
                MeloPillButton(title: "選択中", isSelected: true) {}
                MeloPillButton(title: "未選択") {}
            }

            Divider()

            HStack(spacing: 16) {
                MeloIconButton(icon: "heart.fill", style: .primary) {}
                MeloIconButton(icon: "square.and.arrow.up") {}
                MeloIconButton(icon: "gearshape") {}
            }
        }
        .padding(24)
    }
    .background(MeloColors.Surface.pinkPale)
}
