import SwiftUI
import StoreKit

// MARK: - Subscription Colors (dark theme: 黒地 × ホットピンク accent)
private enum SubColors {
    // Dark palette
    static let brandPink = MeloColors.Dark.accent     // primary accent (borders, accents, icons)
    static let filledPink = MeloColors.Dark.accent    // filled CTA accent
    static let softPink = MeloColors.Dark.accentBright      // selection highlight
    static let headerBg = MeloColors.Dark.bgElevated
    static let bgGradientStart = MeloColors.Dark.bg
    static let bgGradientEnd = MeloColors.Dark.bg
    static let textDark = MeloColors.Dark.textPrimary
    static let textGrey = MeloColors.Dark.textSecondary
    static let textMuted = MeloColors.Dark.textSecondary
    static let borderBrown = MeloColors.Dark.cardStroke
    static let neutralDivider = MeloColors.Dark.divider

    // Backwards-compat aliases for callers that still reference these names
    static let accentPink = brandPink
}

// MARK: - Subscription View
struct SubscriptionView: View {
    var source: String = "other"
    var initialTier: SubscriptionTier?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedTier: SubscriptionTier = .premium
    @State private var selectedProduct: SubscriptionProduct = .yearly
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateElements = false
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    @State private var paywallShownDate = Date()

    var body: some View {
        ZStack(alignment: .bottom) {
            // 黒地の背景 (診断フローと同系統)
            LinearGradient(
                colors: [
                    MeloColors.Dark.bg,
                    SubColors.headerBg,
                    SubColors.bgGradientStart,
                    SubColors.bgGradientEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 閉じるボタン用スペース
                Color.clear.frame(height: 36)

                // ヘッダーテキスト（タイトル + 説明文）
                headerText
                    .opacity(animateElements ? 1 : 0)

                // Tier切替ピッカー（固定）
                tierPicker
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .opacity(animateElements ? 1 : 0)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // プラン選択カード(購入動線を最優先で見せる)
                        VStack(spacing: 16) {
                            ForEach(currentTierProducts, id: \.rawValue) { product in
                                softPlanCard(product)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : 22)

                        // プラン比較テーブル(参考情報として下に配置)
                        comparisonTable
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .opacity(animateElements ? 1 : 0)
                            .offset(y: animateElements ? 0 : 25)

                        // 復元ボタンと注意事項
                        VStack(spacing: 16) {
                            restoreButton
                            termsSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 120)
                    }
                }
            }

            // 固定購入ボタン（オーバーレイ）
            fixedPurchaseButton
                .opacity(animateElements ? 1 : 0)
                .offset(y: animateElements ? 0 : 100)

            // 閉じるボタン
            VStack {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.light()
                        AnalyticsManager.shared.track("paywall_dismiss", properties: [
                            "trigger": source,
                            "time_spent_sec": Int(Date().timeIntervalSince(paywallShownDate)),
                            "selected_tier": selectedTier.rawValue,
                            "current_tier": subscriptionManager.currentTier.rawValue
                        ])
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SubColors.textDark)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(MeloColors.Dark.card)
                                    .overlay(
                                        Circle()
                                            .stroke(SubColors.borderBrown.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                Spacer()
            }

            // ローディング
            if isPurchasing {
                purchasingOverlay
            }
        }
        .onAppear {
            paywallShownDate = Date()
            AnalyticsManager.shared.track("paywall_shown", properties: [
                "trigger": source,
                "initial_tier": selectedTier.rawValue,
                "current_tier": subscriptionManager.currentTier.rawValue
            ])

            if let initial = initialTier {
                selectedTier = initial
                selectedProduct = initial == .premiumPlus ? .plusYearly : .yearly
            } else if subscriptionManager.currentTier == .premium {
                // Premiumユーザーは初期表示をPremium+に
                selectedTier = .premiumPlus
                selectedProduct = .plusYearly
            }

            // 購入済みのプランを初期選択にする（initialTier未指定時のみ）
            if initialTier == nil,
               let purchasedProduct = SubscriptionProduct.allCases.first(where: {
                   subscriptionManager.purchasedProductIDs.contains($0.rawValue)
               }) {
                selectedTier = purchasedProduct.tier
                selectedProduct = purchasedProduct
            }

            withAnimation(.easeOut(duration: 0.8)) {
                animateElements = true
            }
        }
        .alert(String(localized: "エラー", bundle: LanguageManager.appBundle), isPresented: $showError) {
            Button(String(localized: "OK", bundle: LanguageManager.appBundle), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Current Tier Products
    private var currentTierProducts: [SubscriptionProduct] {
        SubscriptionProduct.products(for: selectedTier)
    }

    // MARK: - Tier Switch Helper
    private func switchTier(to tier: SubscriptionTier) {
        guard selectedTier != tier else { return }
        HapticManager.light()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedTier = tier
            selectedProduct = tier == .premiumPlus ? .plusYearly : .yearly
        }
    }

    // MARK: - Tier Picker
    private var tierPicker: some View {
        HStack(spacing: 0) {
            tierPickerButton(tier: .premium, label: "Premium")
            tierPickerButton(tier: .premiumPlus, label: "Premium+")
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeloColors.Dark.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SubColors.neutralDivider, lineWidth: 1)
                )
        )
    }

    private func tierPickerButton(tier: SubscriptionTier, label: LocalizedStringKey) -> some View {
        let isSelected = selectedTier == tier

        return Button {
            HapticManager.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTier = tier
                selectedProduct = tier == .premiumPlus ? .plusYearly : .yearly
            }
        } label: {
            Text(label)
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(isSelected ? MeloColors.Dark.onAccent : SubColors.textGrey)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(MeloColors.Dark.accentGradient)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header
    private var headerText: some View {
        VStack(spacing: 4) {
            Text(selectedTier == .premiumPlus
                 ? String(localized: "ハラスメントーク Premium+", bundle: LanguageManager.appBundle)
                 : String(localized: "ハラスメントーク Premium", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(22))
                .tracking(0.66)
                .foregroundColor(SubColors.textDark)

            Text(selectedTier == .premiumPlus
                 ? String(localized: "診断も相談もチャットも全部無制限", bundle: LanguageManager.appBundle)
                 : String(localized: "診断が無制限＋詳細データで深く分析", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(SubColors.textGrey)
        }
        .padding(.horizontal, 24)
        .animation(.easeOut(duration: 0.2), value: selectedTier)
    }

    // MARK: - Soft Plan Card
    private func softPlanCard(_ product: SubscriptionProduct) -> some View {
        let isSelected = selectedProduct == product
        let isRecommended = product.isRecommended
        let isPurchased = subscriptionManager.purchasedProductIDs.contains(product.rawValue)

        return Button {
            HapticManager.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProduct = product
            }
        } label: {
            planCardContent(product: product, isSelected: isSelected, isRecommended: isRecommended, isPurchased: isPurchased)
        }
        .buttonStyle(.plain)
    }

    private func planCardContent(product: SubscriptionProduct, isSelected: Bool, isRecommended: Bool, isPurchased: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            mainPlanContent(product: product, isSelected: isSelected, isPurchased: isPurchased)

            if isPurchased {
                purchasedBadge
            } else if isRecommended {
                recommendedBadge
            }
        }
    }

    private func mainPlanContent(product: SubscriptionProduct, isSelected: Bool, isPurchased: Bool) -> some View {
        HStack(spacing: 16) {
            selectionIndicator(isSelected: isSelected, isPurchased: isPurchased)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(product.displayName)
                        .font(MeloFonts.zenMaruMedium(18))
                        .foregroundColor(SubColors.textDark)

                    if isPurchased {
                        Text(String(localized: "契約中", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(10))
                            .foregroundColor(MeloColors.Dark.onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(MeloColors.Dark.accentGradient)
                            )
                    }
                }

                if let savings = savingsText(for: product) {
                    Text(savings)
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(SubColors.brandPink)
                }
            }

            Spacer()

            priceSection(product: product, isSelected: isSelected)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(planCardBackground(isSelected: isSelected, isPurchased: isPurchased))
    }

    private func savingsText(for product: SubscriptionProduct) -> String? {
        let weeklyProduct: SubscriptionProduct = product.tier == .premiumPlus ? .plusWeekly : .weekly
        return product.localizedSavings(
            weeklyProduct: subscriptionManager.product(for: weeklyProduct),
            thisProduct: subscriptionManager.product(for: product)
        )
    }

    private func selectionIndicator(isSelected: Bool, isPurchased: Bool) -> some View {
        let filled = isSelected || isPurchased

        return ZStack {
            Circle()
                .fill(filled
                      ? AnyShapeStyle(MeloColors.Dark.accentGradient)
                      : AnyShapeStyle(MeloColors.Dark.card))
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(
                            filled ? Color.clear : SubColors.borderBrown.opacity(0.6),
                            lineWidth: 1
                        )
                )

            if filled {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MeloColors.Dark.onAccent)
            }
        }
    }

    private func priceSection(product: SubscriptionProduct, isSelected: Bool) -> some View {
        let storeProduct = subscriptionManager.product(for: product)
        return VStack(alignment: .trailing, spacing: 2) {
            Text(product.localizedPrice(from: storeProduct))
                .font(MeloFonts.zenMaru(24))
                .foregroundColor(isSelected ? SubColors.brandPink : SubColors.textDark)

            Text(product.localizedPricePerDay(from: storeProduct))
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(SubColors.textGrey)
        }
    }

    private func planCardBackground(isSelected: Bool, isPurchased: Bool) -> some View {
        let borderColor: Color
        let lineWidth: CGFloat

        if isPurchased {
            borderColor = SubColors.brandPink
            lineWidth = 1.5
        } else if isSelected {
            borderColor = SubColors.brandPink
            lineWidth = 1.5
        } else {
            borderColor = SubColors.borderBrown.opacity(0.7)
            lineWidth = 1
        }

        return RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? SubColors.headerBg : MeloColors.Dark.card)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
    }

    private var recommendedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
            Text(String(localized: "おすすめ", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(11))
        }
        .foregroundColor(MeloColors.Dark.onAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(MeloColors.Dark.accentGradient)
        )
        .offset(x: -12, y: -10)
    }

    private var purchasedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10, weight: .bold))
            Text(String(localized: "購入済み", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(11))
        }
        .foregroundColor(MeloColors.Dark.onAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(MeloColors.Dark.accentGradient)
        )
        .offset(x: -12, y: -10)
    }


    // MARK: - Comparison Table
    private var comparisonTable: some View {
        VStack(spacing: 0) {
            comparisonHeaderRow

            comparisonDivider

            comparisonTextRow(
                label: String(localized: "診断", bundle: LanguageManager.appBundle), icon: "waveform.path.ecg",
                freeValue: String(localized: "3回/日", bundle: LanguageManager.appBundle), premiumValue: String(localized: "無制限", bundle: LanguageManager.appBundle), plusValue: String(localized: "無制限", bundle: LanguageManager.appBundle)
            )
            comparisonDivider
            comparisonTextRow(
                label: String(localized: "相談", bundle: LanguageManager.appBundle), icon: "bubble.left.and.bubble.right",
                freeValue: String(localized: "1回\n(2通)", bundle: LanguageManager.appBundle), premiumValue: String(localized: "3回/日\n(10通)", bundle: LanguageManager.appBundle), plusValue: String(localized: "無制限", bundle: LanguageManager.appBundle)
            )
            comparisonDivider
            comparisonTextRow(
                label: String(localized: "擬人化\nチャット", bundle: LanguageManager.appBundle), icon: "person.bubble.fill",
                freeValue: String(localized: "5通/日", bundle: LanguageManager.appBundle), premiumValue: String(localized: "30通/日", bundle: LanguageManager.appBundle), plusValue: String(localized: "200通/日", bundle: LanguageManager.appBundle)
            )
            comparisonDivider
            comparisonCheckRowNew(label: String(localized: "詳細データ", bundle: LanguageManager.appBundle), icon: "chart.bar.doc.horizontal", free: false, premium: true, plus: true)
            comparisonDivider
            comparisonCheckRowNew(label: String(localized: "広告非表示", bundle: LanguageManager.appBundle), icon: "eye.slash.fill", free: false, premium: true, plus: true)
        }
        .background(comparisonColumnHighlight)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeloColors.Dark.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SubColors.borderBrown.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // 選択Tier列の縦通しハイライト
    private var comparisonColumnHighlight: some View {
        GeometryReader { geo in
            let labelWidth: CGFloat = 104
            let colWidth = (geo.size.width - labelWidth) / 3
            let xOffset = selectedTier == .premiumPlus ? labelWidth + colWidth * 2 : labelWidth + colWidth

            SubColors.softPink.opacity(0.25)
                .frame(width: colWidth, height: geo.size.height)
                .position(x: xOffset + colWidth / 2, y: geo.size.height / 2)
        }
    }

    private var comparisonDivider: some View {
        Rectangle()
            .fill(SubColors.neutralDivider)
            .frame(height: 1)
            .padding(.horizontal, 12)
    }

    private var comparisonHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 104)

            Text(String(localized: "Free", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(SubColors.textGrey)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

            VStack(spacing: 0) {
                if selectedTier == .premium {
                    SubColors.brandPink
                        .frame(height: 3)
                        .clipShape(Capsule())
                        .padding(.horizontal, 8)
                } else {
                    Color.clear.frame(height: 3)
                }
                Text(String(localized: "Premium", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(selectedTier == .premium ? SubColors.brandPink : SubColors.textGrey)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTier = .premium
                    selectedProduct = .yearly
                }
            }

            VStack(spacing: 0) {
                if selectedTier == .premiumPlus {
                    SubColors.brandPink
                        .frame(height: 3)
                        .clipShape(Capsule())
                        .padding(.horizontal, 8)
                } else {
                    Color.clear.frame(height: 3)
                }
                Text(String(localized: "Premium+", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(selectedTier == .premiumPlus ? SubColors.brandPink : SubColors.textGrey)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTier = .premiumPlus
                    selectedProduct = .plusYearly
                }
            }
        }
    }

    private func comparisonTextRow(label: String, icon: String, freeValue: String, premiumValue: String, plusValue: String) -> some View {
        HStack(alignment: .center, spacing: 0) {
            comparisonLabelCell(label: label, icon: icon)

            Text(freeValue)
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(SubColors.textGrey)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)

            comparisonValueCell(
                text: premiumValue,
                isHighlighted: selectedTier == .premium
            )
            .contentShape(Rectangle())
            .onTapGesture { switchTier(to: .premium) }

            comparisonValueCell(
                text: plusValue,
                isHighlighted: selectedTier == .premiumPlus
            )
            .contentShape(Rectangle())
            .onTapGesture { switchTier(to: .premiumPlus) }
        }
    }

    private func comparisonLabelCell(label: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(SubColors.brandPink)
                .padding(.top, 3)
            Text(label)
                .font(MeloFonts.zenMaruMedium(12))
                .foregroundColor(SubColors.textDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 14)
        .frame(minWidth: 104, maxWidth: 104, minHeight: 48, alignment: .leading)
    }

    private func comparisonValueCell(text: String, isHighlighted: Bool) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruMedium(isHighlighted ? 14 : 13))
            .foregroundColor(isHighlighted ? SubColors.brandPink : SubColors.textGrey)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
    }

    private func comparisonCheckRowNew(label: String, icon: String, free: Bool, premium: Bool, plus: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            comparisonLabelCell(label: label, icon: icon)

            comparisonCheckIcon(enabled: free, isHighlighted: false)

            comparisonCheckIcon(enabled: premium, isHighlighted: selectedTier == .premium)
                .contentShape(Rectangle())
                .onTapGesture { switchTier(to: .premium) }

            comparisonCheckIcon(enabled: plus, isHighlighted: selectedTier == .premiumPlus)
                .contentShape(Rectangle())
                .onTapGesture { switchTier(to: .premiumPlus) }
        }
    }

    private func comparisonCheckIcon(enabled: Bool, isHighlighted: Bool) -> some View {
        Group {
            if enabled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isHighlighted ? SubColors.brandPink : SubColors.brandPink.opacity(0.45))
            } else {
                Text("─")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SubColors.neutralDivider)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
    }

    // MARK: - Fixed Purchase Button
    private var fixedPurchaseButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    MeloColors.Dark.bg.opacity(0),
                    MeloColors.Dark.bg.opacity(0.8),
                    MeloColors.Dark.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            VStack(spacing: 8) {
                Button {
                    HapticManager.medium()
                    Task {
                        await purchase()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MeloColors.Dark.onAccent)

                        Text(purchaseButtonText)
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(MeloColors.Dark.onAccent)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MeloColors.Dark.onAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(MeloColors.Dark.accentGradient)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(MeloColors.Dark.bg)
        }
    }

    private var purchaseButtonText: String {
        let storeProduct = subscriptionManager.product(for: selectedProduct)
        let price = selectedProduct.localizedPrice(from: storeProduct)
        let tierLabel: String
        if subscriptionManager.currentTier == .premium && selectedTier == .premiumPlus {
            tierLabel = String(localized: "Premium+にアップグレード", bundle: LanguageManager.appBundle)
        } else {
            tierLabel = selectedTier == .premiumPlus
                ? String(localized: "Premium+を始める", bundle: LanguageManager.appBundle)
                : String(localized: "Premiumを始める", bundle: LanguageManager.appBundle)
        }
        return "\(tierLabel) — \(price)\(periodSuffix)"
    }

    private var periodSuffix: String {
        switch selectedProduct {
        case .weekly, .plusWeekly: return String(localized: "/週", bundle: LanguageManager.appBundle)
        case .monthly, .plusMonthly: return String(localized: "/月", bundle: LanguageManager.appBundle)
        case .yearly, .plusYearly: return String(localized: "/年", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            HapticManager.light()
            AnalyticsManager.shared.track("subscription_restore", properties: [
                "current_tier": subscriptionManager.currentTier.rawValue
            ])
            Task {
                await subscriptionManager.restorePurchases()
                if subscriptionManager.isSubscribed {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                Text(String(localized: "購入を復元", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(14))
            }
            .foregroundColor(SubColors.textGrey)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 12) {
            Text(String(localized: "サブスクリプションは自動更新されます。解約は次の更新日の24時間前までに設定アプリから行ってください。", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(SubColors.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 20) {
                Button(String(localized: "利用規約", bundle: LanguageManager.appBundle)) {
                    showingTermsOfService = true
                }
                .buttonStyle(.plain)
                Button(String(localized: "プライバシーポリシー", bundle: LanguageManager.appBundle)) {
                    showingPrivacyPolicy = true
                }
                .buttonStyle(.plain)
            }
            .font(MeloFonts.zenMaruMedium(12))
            .foregroundColor(SubColors.brandPink)
        }
        .padding(.top, 8)
    }

    // MARK: - Purchasing Overlay
    private var purchasingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(SubColors.brandPink)

                Text(String(localized: "購入処理中...", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(16))
                    .foregroundColor(SubColors.textDark)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(SubColors.brandPink, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Methods
    private func purchase() async {
        guard let product = subscriptionManager.product(for: selectedProduct) else {
            errorMessage = String(localized: "商品情報を取得できませんでした", bundle: LanguageManager.appBundle)
            showError = true
            return
        }

        isPurchasing = true

        do {
            if let _ = try await subscriptionManager.purchase(product) {
                AnalyticsManager.shared.track("subscription_purchase", properties: [
                    "plan_id": selectedProduct.rawValue,
                    "trigger": source,
                    "tier": selectedTier.rawValue,
                    "previous_tier": subscriptionManager.currentTier.rawValue,
                    "is_upgrade": subscriptionManager.currentTier == .premium && selectedTier == .premiumPlus
                ])
                // GA4 標準 CV イベント (value/currency は予約パラメータ)
                let value = NSDecimalNumber(decimal: product.price).doubleValue
                let currency = product.priceFormatStyle.locale.currency?.identifier
                    ?? Locale.current.currency?.identifier ?? "JPY"
                AnalyticsManager.shared.purchase(
                    value: value,
                    currency: currency,
                    planId: selectedProduct.rawValue,
                    tier: selectedTier.rawValue
                )
                HapticManager.success()
                dismiss()
            }
        } catch {
            HapticManager.error()
            errorMessage = String(localized: "購入に失敗しました。もう一度お試しください。", bundle: LanguageManager.appBundle)
            showError = true
        }

        isPurchasing = false
    }
}


// MARK: - Preview
#Preview {
    SubscriptionView()
}
