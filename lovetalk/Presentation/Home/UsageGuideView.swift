import SwiftUI

// MARK: - Usage Guide Step
struct UsageGuideStep: Identifiable {
    let id: Int
    let imageName: String
    let description: String
    /// 各ステップに寄り添うめろまる 2D アセット
    let meromaruAsset: String
}

// MARK: - Usage Guide Design Tokens (dark theme)
private enum UsageGuideTokens {
    static let pageBg = MeloColors.Dark.bg
    static let headerBg = MeloColors.Dark.bgElevated
    static let softPinkTop = MeloColors.Dark.bg
    static let softPinkBottom = MeloColors.Dark.bg
    static let brandPink = MeloColors.Dark.accent
    static let ctaPink = MeloColors.Dark.accent
    static let softPink = MeloColors.Dark.accentBright
    static let textDark = MeloColors.Dark.textPrimary
    static let textGrey = MeloColors.Dark.textSecondary
    static let textMuted = MeloColors.Dark.textSecondary
    static let cardStroke = MeloColors.Dark.cardStroke
    static let divider = MeloColors.Dark.divider
}

// MARK: - Usage Guide View
struct UsageGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    /// 表示言語に応じた画像サフィックス
    private var langSuffix: String {
        let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? "ja"
        switch stored {
        case "en": return "_en"
        case "es": return "_es"
        case "ko": return "_ko"
        case "zh-Hans": return "_zh"
        default: return ""
        }
    }

    private var steps: [UsageGuideStep] {
        let suffix = langSuffix
        return [
            UsageGuideStep(
                id: 1,
                imageName: "no1",
                description: String(localized: "解析したい相手とのトーク画面を開いて、\n≡ をタップしてメニューを開きます", bundle: LanguageManager.appBundle),
                meromaruAsset: "char_meromaru_3d"
            ),
            UsageGuideStep(
                id: 2,
                imageName: "no2\(suffix)",
                description: String(localized: "メニューから「設定」をタップします", bundle: LanguageManager.appBundle),
                meromaruAsset: "char_meromaru_3d"
            ),
            UsageGuideStep(
                id: 3,
                imageName: "no3\(suffix)",
                description: String(localized: "設定から「トーク履歴を送信」をタップします", bundle: LanguageManager.appBundle),
                meromaruAsset: "char_meromaru_3d"
            ),
            UsageGuideStep(
                id: 4,
                imageName: "no4\(suffix)",
                description: String(localized: "アプリの一覧を一番右にスワイプし、\n「その他」ボタンを押します", bundle: LanguageManager.appBundle),
                meromaruAsset: "char_meromaru_3d"
            ),
            UsageGuideStep(
                id: 5,
                imageName: "no5\(suffix)",
                description: String(localized: "アプリの一覧から\n「めろとーく」を選択します", bundle: LanguageManager.appBundle),
                meromaruAsset: "char_meromaru_3d"
            )
        ]
    }

    var body: some View {
        ZStack {
            // 背景: 白 → やわらかピンクへのグラデーション (NewHomeView のソフト背景に合わせる)
            LinearGradient(
                colors: [
                    UsageGuideTokens.pageBg,
                    UsageGuideTokens.softPinkTop,
                    UsageGuideTokens.softPinkBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ヘッダー (白 bg + Zen Maru タイトル + ピンクストローク丸ボタン)
                headerView

                // スライドショー (TabView は維持、インジケータのみ差し替え)
                TabView(selection: $currentPage) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        slideView(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // ページインジケーター & ボタン
                bottomControls
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        ZStack {
            // タイトル (中央)
            Text(String(localized: "使い方", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(20))
                .tracking(0.6)
                .foregroundColor(UsageGuideTokens.textDark)

            HStack {
                // 戻るボタン (最初のページ以外): ピンク stroke 丸 + ピンク chevron
                if currentPage > 0 {
                    Button {
                        HapticManager.light()
                        withAnimation {
                            currentPage -= 1
                        }
                    } label: {
                        circleIconButton(system: "chevron.left", pointSize: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }

                Spacer()

                // 閉じるボタン: ピンク stroke 丸 + ピンク xmark
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    circleIconButton(system: "xmark", pointSize: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(UsageGuideTokens.headerBg)
    }

    /// 白円 + 1pt ピンク stroke + ピンク SF シンボル (NewHomeView の settingsButton と同じ）
    private func circleIconButton(system: String, pointSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(MeloColors.Dark.card)
                .overlay(
                    Circle()
                        .stroke(UsageGuideTokens.brandPink, lineWidth: 1)
                )
            Image(systemName: system)
                .font(.system(size: pointSize, weight: .semibold))
                .foregroundColor(UsageGuideTokens.brandPink)
        }
        .frame(width: 36, height: 36)
    }

    private func slideView(step: UsageGuideStep) -> some View {
        VStack(spacing: 18) {
            // STEP ピル (ピンク filled 丸バッジ + 白 Zen Maru 数字)
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(UsageGuideTokens.brandPink)
                    Text("\(step.id)")
                        .font(MeloFonts.zenMaruMedium(18))
                        .foregroundColor(MeloColors.Dark.onAccent)
                }
                .frame(width: 34, height: 34)

                Text(String(localized: "STEP", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(13))
                    .tracking(1.2)
                    .foregroundColor(UsageGuideTokens.brandPink)

                Text("\(step.id) / \(steps.count)")
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(UsageGuideTokens.textGrey)
            }
            .padding(.top, 6)

            // スクリーンショット + めろまる (白カード + 1pt 茶 stroke, 角丸10)
            ZStack(alignment: .bottomTrailing) {
                Image(step.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.42)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MeloColors.Dark.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(UsageGuideTokens.cardStroke, lineWidth: 1)
                            )
                    )

                // コンテキストに合わせためろまる 2D (カード右下に寄り添う)
                Image(step.meromaruAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .offset(x: 6, y: 14)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)

            // 説明文カード (白 bg + 1pt ピンク stroke, 角丸10)
            Text(step.description)
                .font(MeloFonts.zenMaru(15))
                .tracking(0.3)
                .foregroundColor(UsageGuideTokens.textDark)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MeloColors.Dark.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(UsageGuideTokens.brandPink, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // ページインジケーター (ピンク filled / soft ピンク)
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == currentPage
                                ? UsageGuideTokens.brandPink
                                : UsageGuideTokens.softPink.opacity(0.5)
                        )
                        .frame(
                            width: index == currentPage ? 20 : 8,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }

            // ボタン (flat F7A2BA pill, radius 14, Zen Maru Medium)
            if currentPage < steps.count - 1 {
                primaryPillButton(
                    title: String(localized: "次へ", bundle: LanguageManager.appBundle),
                    systemIcon: "chevron.right"
                ) {
                    HapticManager.light()
                    withAnimation {
                        currentPage += 1
                    }
                }
                .padding(.horizontal, 24)
            } else {
                // 最終ステップ: LINE を開く (Primary) + はじめる (Secondary)
                VStack(spacing: 10) {
                    primaryPillButton(
                        title: String(localized: "LINEを開く", bundle: LanguageManager.appBundle),
                        systemIcon: "link"
                    ) {
                        HapticManager.medium()
                        openLineApp()
                    }
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Text(String(localized: "はじめる", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .tracking(0.4)
                            .foregroundColor(UsageGuideTokens.ctaPink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(MeloColors.Dark.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(UsageGuideTokens.ctaPink, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(UsageGuideScaleStyle())
                }
                .padding(.horizontal, 24)
            }

            // スキップリンク (最後以外)
            if currentPage < steps.count - 1 {
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    Text(String(localized: "スキップ", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(UsageGuideTokens.textGrey)
                }
                .buttonStyle(.plain)
            } else {
                // 高さを揃えるためのプレースホルダ
                Color.clear.frame(height: 18)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 28)
    }

    /// LINE アプリを開く (NewHomeView.openLineForExport() と同じ URL scheme パターン)。
    /// LINE 未インストールなら App Store の LINE ページへ誘導する
    /// (https://line.me を canOpenURL に渡すと未インストールでも true になり Safari へ離脱するため使わない)。
    private func openLineApp() {
        AnalyticsManager.shared.track("usage_guide_open_line_tap")
        // LINE アプリの URL scheme のみ。https フォールバック (line.me) は LINE 未インストール端末
        // (iPad 等) で Safari に飛んでアプリから離脱するため使わない。
        let candidates = ["line://nv/chat", "line://"]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        // LINE 未インストール → App Store の LINE ページへ誘導。
        if let storeURL = URL(string: "https://apps.apple.com/jp/app/id443904275") {
            UIApplication.shared.open(storeURL)
        }
    }

    /// NewHomeView と同じ flat ピンク pill CTA
    private func primaryPillButton(
        title: String,
        systemIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(MeloFonts.zenMaruMedium(16))
                    .tracking(0.5)
                Image(systemName: systemIcon)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(MeloColors.Dark.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(UsageGuideTokens.ctaPink)
            )
        }
        .buttonStyle(UsageGuideScaleStyle())
    }
}

// MARK: - Scale Button Style (local)
private struct UsageGuideScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    UsageGuideView()
}
