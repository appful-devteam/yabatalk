import SwiftUI

enum MeloTypography {
    // MARK: - Display
    static let typeDisplay = Font.system(size: 32, weight: .bold, design: .rounded)
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)

    // MARK: - Titles
    static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 18, weight: .semibold, design: .rounded)

    // MARK: - Body
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    static let bodyBold = Font.system(size: 15, weight: .semibold, design: .rounded)

    // MARK: - Supporting
    static let callout = Font.system(size: 14, weight: .regular, design: .rounded)
    static let subheadline = Font.system(size: 13, weight: .regular, design: .rounded)
    static let footnote = Font.system(size: 12, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 11, weight: .regular, design: .rounded)
    static let captionBold = Font.system(size: 11, weight: .semibold, design: .rounded)

    // MARK: - Special
    static let scoreDisplay = Font.system(size: 48, weight: .bold, design: .rounded)
    static let axisLabel = Font.system(size: 10, weight: .medium, design: .rounded)
    static let badgeText = Font.system(size: 10, weight: .bold, design: .rounded)
}

// MARK: - Text Style Modifiers
struct MeloTextStyle: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

extension View {
    func meloTextStyle(_ font: Font, color: Color = MeloColors.Dark.textPrimary) -> some View {
        modifier(MeloTextStyle(font: font, color: color))
    }
}
