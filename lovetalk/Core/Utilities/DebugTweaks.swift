import SwiftUI

#if DEBUG
// MARK: - Debug Tweaks (DEBUG only)
/// デバッグ用UI調整ツール — リリースビルドではスライダーUI含め完全に除外される
final class DebugTweaks: ObservableObject {
    static let shared = DebugTweaks()

    // MARK: - TYPE ページ: ヘッダーセル
    @Published var headerFontSize: CGFloat = 12
    @Published var headerHighLowSize: CGFloat = 28

    // MARK: - TYPE ページ: InsightMetricRow
    @Published var metricAxisNameSize: CGFloat = 13
    @Published var metricBarWidth: CGFloat = 155
    @Published var metricBadGoodSize: CGFloat = 11
    @Published var metricDescSize: CGFloat = 10
    @Published var metricHighLowSize: CGFloat = 28

    // MARK: - スコアページ: 軸カード
    @Published var scoreAxisNameSize: CGFloat = 17
    @Published var scoreAxisDescSize: CGFloat = 12
    @Published var scoreBarPaddingH: CGFloat = 4
    @Published var scoreDetailDescSize: CGFloat = 13
    @Published var scoreNumberSize: CGFloat = 52

    // MARK: - ホーム画面
    @Published var homeSpeechFontSize: CGFloat = 12
    @Published var homeSpeechPaddingH: CGFloat = 20
    @Published var homeSpeechPaddingV: CGFloat = 6
    @Published var homeMascotWidth: CGFloat = 105
    @Published var homeRankNameSize: CGFloat = 15
    @Published var homeRankScoreSize: CGFloat = 40
    @Published var homeRankBadgeSize: CGFloat = 16
    @Published var homeRankRowHeight: CGFloat = 64
    @Published var homeSortWidth: CGFloat = 200
    @Published var homeSortFontSize: CGFloat = 10
    @Published var homeCtaFontSize: CGFloat = 16
    @Published var homePremiumFontSize: CGFloat = 10
    @Published var homeSettingIconSize: CGFloat = 16

    // MARK: - レーダーチャート
    @Published var radarLabelScale: CGFloat = 0.75
    @Published var radarSideLabelScale: CGFloat = 0.89
    @Published var radarLabelFontSize: CGFloat = 13
    @Published var radarScoreFontSize: CGFloat = 22

    func exportValues() -> String {
        """
        [TYPE ヘッダー]
        headerFontSize: \(Int(headerFontSize))
        headerHighLowSize: \(Int(headerHighLowSize))

        [TYPE MetricRow]
        metricAxisNameSize: \(Int(metricAxisNameSize))
        metricBarWidth: \(Int(metricBarWidth))
        metricBadGoodSize: \(Int(metricBadGoodSize))
        metricDescSize: \(Int(metricDescSize))
        metricHighLowSize: \(Int(metricHighLowSize))

        [スコア軸カード]
        scoreAxisNameSize: \(Int(scoreAxisNameSize))
        scoreAxisDescSize: \(Int(scoreAxisDescSize))
        scoreBarPaddingH: \(Int(scoreBarPaddingH))
        scoreDetailDescSize: \(Int(scoreDetailDescSize))
        scoreNumberSize: \(Int(scoreNumberSize))

        [レーダーチャート]
        radarLabelScale: \(String(format: "%.2f", radarLabelScale))
        radarSideLabelScale: \(String(format: "%.2f", radarSideLabelScale))
        radarLabelFontSize: \(Int(radarLabelFontSize))
        radarScoreFontSize: \(Int(radarScoreFontSize))

        [ホーム]
        homeSpeechFontSize: \(Int(homeSpeechFontSize))
        homeSpeechPaddingH: \(Int(homeSpeechPaddingH))
        homeSpeechPaddingV: \(Int(homeSpeechPaddingV))
        homeMascotWidth: \(Int(homeMascotWidth))
        homeRankNameSize: \(Int(homeRankNameSize))
        homeRankScoreSize: \(Int(homeRankScoreSize))
        homeRankBadgeSize: \(Int(homeRankBadgeSize))
        homeRankRowHeight: \(Int(homeRankRowHeight))
        homeSortWidth: \(Int(homeSortWidth))
        homeSortFontSize: \(Int(homeSortFontSize))
        homeCtaFontSize: \(Int(homeCtaFontSize))
        homeSettingIconSize: \(Int(homeSettingIconSize))
        homePremiumFontSize: \(Int(homePremiumFontSize))
        """
    }
}

// MARK: - Debug Slider Panel
struct DebugSliderPanel: View {
    @ObservedObject var tweaks = DebugTweaks.shared
    @Binding var isShowing: Bool
    @State private var selectedPage = 0
    @State private var panelOffset: CGFloat = 0
    @State private var isCollapsed = false
    @State private var copiedFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // ドラッグハンドル
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 6)
                .padding(.bottom, 2)

            // ヘッダー
            HStack(spacing: 6) {
                Picker("", selection: $selectedPage) {
                    Text("TYPE").tag(0)
                    Text("スコア").tag(1)
                    Text("レーダー").tag(2)
                    Text("ホーム").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)

                Button {
                    UIPasteboard.general.string = tweaks.exportValues()
                    copiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedFeedback = false }
                } label: {
                    Text(copiedFeedback ? "OK!" : "コピー")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(copiedFeedback ? Color.green : Color.blue))
                }

                Button { isShowing = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            if !isCollapsed {
                VStack(spacing: 6) {
                    switch selectedPage {
                    case 0: typePageSliders
                    case 1: scorePageSliders
                    case 2: radarSliders
                    case 3: homePageSliders
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10)
        .frame(maxHeight: isCollapsed ? 50 : 200)
        .offset(y: panelOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    panelOffset = value.translation.height
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3)) {
                        if value.translation.height > 60 {
                            isCollapsed = true
                        } else if value.translation.height < -60 {
                            isCollapsed = false
                        }
                        panelOffset = 0
                    }
                }
        )
        .padding(.horizontal, 8)
    }

    // MARK: - TYPE ページ
    private var typePageSliders: some View {
        VStack(spacing: 6) {
            sliderRow("ヘッダー文字", $tweaks.headerFontSize, range: 8...18)
            sliderRow("ヘッダーHigh/Low", $tweaks.headerHighLowSize, range: 16...36)
            Divider()
            sliderRow("軸名文字", $tweaks.metricAxisNameSize, range: 8...16)
            sliderRow("バー幅", $tweaks.metricBarWidth, range: 100...220)
            sliderRow("BAD/GOOD文字", $tweaks.metricBadGoodSize, range: 6...14)
            sliderRow("説明文字", $tweaks.metricDescSize, range: 6...14)
            sliderRow("High/Low", $tweaks.metricHighLowSize, range: 16...36)
        }
    }

    // MARK: - スコア軸カード
    private var scorePageSliders: some View {
        VStack(spacing: 6) {
            sliderRow("軸名文字", $tweaks.scoreAxisNameSize, range: 10...20)
            sliderRow("軸説明文字", $tweaks.scoreAxisDescSize, range: 6...16)
            sliderRow("バー左右余白", $tweaks.scoreBarPaddingH, range: 0...60)
            sliderRow("詳細説明文字", $tweaks.scoreDetailDescSize, range: 6...16)
            sliderRow("スコア数字", $tweaks.scoreNumberSize, range: 24...60)
        }
    }

    // MARK: - レーダーチャート
    private var radarSliders: some View {
        VStack(spacing: 6) {
            sliderRow("上下ラベル距離", $tweaks.radarLabelScale, range: 0.6...1.0, step: 0.01)
            sliderRow("左右ラベル距離", $tweaks.radarSideLabelScale, range: 0.6...1.0, step: 0.01)
            sliderRow("ラベル文字", $tweaks.radarLabelFontSize, range: 8...16)
            sliderRow("スコア文字", $tweaks.radarScoreFontSize, range: 14...30)
        }
    }

    // MARK: - ホーム
    private var homePageSliders: some View {
        VStack(spacing: 6) {
            sliderRow("吹き出し文字", $tweaks.homeSpeechFontSize, range: 6...16)
            sliderRow("吹き出し横余白", $tweaks.homeSpeechPaddingH, range: 8...40)
            sliderRow("吹き出し縦余白", $tweaks.homeSpeechPaddingV, range: 2...16)
            sliderRow("マスコット幅", $tweaks.homeMascotWidth, range: 60...160)
            Divider()
            sliderRow("名前文字", $tweaks.homeRankNameSize, range: 10...24)
            sliderRow("スコア文字", $tweaks.homeRankScoreSize, range: 20...50)
            sliderRow("ランク文字", $tweaks.homeRankBadgeSize, range: 12...30)
            sliderRow("行の高さ", $tweaks.homeRankRowHeight, range: 40...90)
            Divider()
            sliderRow("ソート幅", $tweaks.homeSortWidth, range: 140...300)
            sliderRow("ソート文字", $tweaks.homeSortFontSize, range: 8...16)
            sliderRow("CTA文字", $tweaks.homeCtaFontSize, range: 10...22)
            sliderRow("設定アイコン", $tweaks.homeSettingIconSize, range: 10...24)
            sliderRow("Premium文字", $tweaks.homePremiumFontSize, range: 8...16)
        }
    }

    // MARK: - Slider Row
    private func sliderRow(_ label: String, _ value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat = 1) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 90, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(step < 1 ? String(format: "%.2f", value.wrappedValue) : "\(Int(value.wrappedValue))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Debug Toggle Button
struct DebugToggleButton: View {
    @Binding var isShowing: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isShowing.toggle()
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.7)))
        }
    }
}

#else
// MARK: - Release Tweaks (固定値)
/// リリースビルドではデフォルト値の定数として提供。View側の t.xxx 参照はそのまま動作する。
final class DebugTweaks: ObservableObject {
    static let shared = DebugTweaks()

    let headerFontSize: CGFloat = 12
    let headerHighLowSize: CGFloat = 28
    let metricAxisNameSize: CGFloat = 13
    let metricBarWidth: CGFloat = 155
    let metricBadGoodSize: CGFloat = 11
    let metricDescSize: CGFloat = 10
    let metricHighLowSize: CGFloat = 28
    let scoreAxisNameSize: CGFloat = 17
    let scoreAxisDescSize: CGFloat = 12
    let scoreBarPaddingH: CGFloat = 4
    let scoreDetailDescSize: CGFloat = 13
    let scoreNumberSize: CGFloat = 52
    let homeSpeechFontSize: CGFloat = 12
    let homeSpeechPaddingH: CGFloat = 20
    let homeSpeechPaddingV: CGFloat = 6
    let homeMascotWidth: CGFloat = 105
    let homeRankNameSize: CGFloat = 15
    let homeRankScoreSize: CGFloat = 40
    let homeRankBadgeSize: CGFloat = 16
    let homeRankRowHeight: CGFloat = 64
    let homeSortWidth: CGFloat = 200
    let homeSortFontSize: CGFloat = 10
    let homeCtaFontSize: CGFloat = 16
    let homePremiumFontSize: CGFloat = 10
    let homeSettingIconSize: CGFloat = 16
    let radarLabelScale: CGFloat = 0.75
    let radarSideLabelScale: CGFloat = 0.89
    let radarLabelFontSize: CGFloat = 13
    let radarScoreFontSize: CGFloat = 22
}
#endif
