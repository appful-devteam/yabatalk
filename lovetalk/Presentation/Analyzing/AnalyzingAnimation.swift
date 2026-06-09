import SwiftUI
import UIKit

// MARK: - Analyzing Colors (NewHomeView 準拠)
private enum AnalyzingColors {
    static let brandPink = MeloColors.Dark.accent
    static let filledPink = MeloColors.Dark.accent
    static let softPink = MeloColors.Dark.accentBright
    static let softBg = MeloColors.Dark.bgElevated
    static let softBgAlt = MeloColors.Dark.bgElevated
    static let textDark = MeloColors.Dark.textPrimary
    static let textGrey = MeloColors.Dark.textSecondary
    static let brownBorder = MeloColors.Dark.cardStroke
}

// MARK: - Analyzing Animation
struct AnalyzingAnimation: View {
    @State private var isAnimating = false
    @State private var heartbeatTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // 背景パーティクル
            ForEach(0..<12, id: \.self) { index in
                HeartParticle(index: index)
            }

            // 外側のリング (ブランドピンク薄)
            Circle()
                .stroke(AnalyzingColors.brandPink.opacity(0.25), lineWidth: 2)
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: isAnimating)

            Circle()
                .stroke(AnalyzingColors.softPink.opacity(0.45), lineWidth: 2)
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(isAnimating ? -288 : 0))
                .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: isAnimating)

            // 中央: めろまる ペア画像 (ハートビートで脈動)
            ZStack {
                Circle()
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        Circle()
                            .stroke(AnalyzingColors.brandPink, lineWidth: 1)
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: AnalyzingColors.brandPink.opacity(0.4), radius: 8, x: 0, y: 3)

                Image("mero_pair_01")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .scaleEffect(isAnimating ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            }
        }
        .onAppear {
            isAnimating = true
            startHeartbeatHaptic()
        }
        .onDisappear {
            heartbeatTask?.cancel()
        }
    }

    /// ハートアニメーション（0.8秒周期）に同期した心拍バイブレーション
    /// 実際の心拍リズム: ドッ(S1・強)→短い間→クン(S2・弱)→長い間→繰り返し
    private func startHeartbeatHaptic() {
        // 即座に最初の1拍
        let first = UIImpactFeedbackGenerator(style: .heavy)
        first.impactOccurred(intensity: 1.0)

        heartbeatTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            // 最初のS2
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            try? await Task.sleep(nanoseconds: 80_000_000)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.5)

            while !Task.isCancelled {
                // 拍間の休止
                try? await Task.sleep(nanoseconds: 550_000_000)

                let s1 = UIImpactFeedbackGenerator(style: .heavy)
                s1.prepare()
                // S1: ドッ — 強く2連打で重い振動を作る
                s1.impactOccurred(intensity: 1.0)
                try? await Task.sleep(nanoseconds: 30_000_000)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)

                // S1→S2 の短い間
                try? await Task.sleep(nanoseconds: 150_000_000)

                // S2: クン — 軽め
                UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.5)
            }
        }
    }
}

// MARK: - Heart Particle
struct HeartParticle: View {
    let index: Int

    @State private var isAnimating = false

    private var angle: Double {
        Double(index) * 30
    }

    private var delay: Double {
        Double(index) * 0.15
    }

    private var baseRadius: CGFloat { 80 }

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 14))
            .foregroundColor(particleColor)
            .scaleEffect(isAnimating ? 0.3 : 1.0)
            .offset(
                x: cos(angle * .pi / 180) * (baseRadius + (isAnimating ? 60 : 0)),
                y: sin(angle * .pi / 180) * (baseRadius + (isAnimating ? 60 : 0))
            )
            .opacity(isAnimating ? 0 : 0.8)
            .animation(
                .easeOut(duration: 2.0)
                .repeatForever(autoreverses: false)
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }

    private var particleColor: Color {
        let colors: [Color] = [
            AnalyzingColors.brandPink,
            AnalyzingColors.filledPink,
            AnalyzingColors.softPink,
            MeloColors.Dark.accentBright
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Progress Steps
struct ProgressSteps: View {
    let steps: [AnalyzingStep]
    let currentStepIndex: Int

    /// 進捗率 (0.0-1.0)
    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(steps.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 上部: プログレスバー (NewHome トラック=FFF1F4 / フィル=F7A2BA)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AnalyzingColors.softBg)
                        .frame(height: 6)

                    Capsule()
                        .fill(AnalyzingColors.filledPink)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)

            // ステップリスト
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 12) {
                        // ステップインジケーター
                        ZStack {
                            Circle()
                                .fill(stepFill(for: index))
                                .overlay(
                                    Circle()
                                        .stroke(stepStroke(for: index), lineWidth: 1)
                                )
                                .frame(width: 26, height: 26)

                            if index < currentStepIndex {
                                // 完了
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(MeloColors.Dark.onAccent)
                            } else if index == currentStepIndex {
                                // 進行中
                                ProgressView()
                                    .scaleEffect(0.55)
                                    .tint(MeloColors.Dark.onAccent)
                            } else {
                                // 未完了
                                Text("\(index + 1)")
                                    .font(MeloFonts.zenMaru(12))
                                    .foregroundColor(AnalyzingColors.textGrey)
                            }
                        }

                        Text(step.title)
                            .font(stepFont(for: index))
                            .tracking(0.3)
                            .foregroundColor(stepTextColor(for: index))

                        Spacer()
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AnalyzingColors.brownBorder, lineWidth: 1)
                )
        )
    }

    private func stepFill(for index: Int) -> Color {
        if index < currentStepIndex {
            return AnalyzingColors.filledPink
        } else if index == currentStepIndex {
            return AnalyzingColors.filledPink
        } else {
            return MeloColors.Dark.card
        }
    }

    private func stepStroke(for index: Int) -> Color {
        if index <= currentStepIndex {
            return AnalyzingColors.brandPink
        } else {
            return AnalyzingColors.brownBorder.opacity(0.4)
        }
    }

    private func stepFont(for index: Int) -> Font {
        index == currentStepIndex ? MeloFonts.zenMaru(14) : MeloFonts.zenMaruRegular(13)
    }

    private func stepTextColor(for index: Int) -> Color {
        if index == currentStepIndex {
            return AnalyzingColors.textDark
        } else if index < currentStepIndex {
            return AnalyzingColors.textDark.opacity(0.85)
        } else {
            return AnalyzingColors.textGrey
        }
    }
}

// MARK: - Analyzing Step
struct AnalyzingStep: Identifiable {
    let id = UUID()
    let title: String
    let duration: Double

    static let defaultSteps: [AnalyzingStep] = [
        AnalyzingStep(title: String(localized: "トーク履歴を分析中...", bundle: LanguageManager.appBundle), duration: 0.8),
        AnalyzingStep(title: String(localized: "会話パターンを解析中...", bundle: LanguageManager.appBundle), duration: 1.2),
        AnalyzingStep(title: String(localized: "関係性を診断中...", bundle: LanguageManager.appBundle), duration: 1.0),
        AnalyzingStep(title: String(localized: "結果を生成中...", bundle: LanguageManager.appBundle), duration: 0.5)
    ]
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [MeloColors.Dark.bg, MeloColors.Dark.bg, MeloColors.Dark.bg],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 40) {
            AnalyzingAnimation()

            ProgressSteps(
                steps: AnalyzingStep.defaultSteps,
                currentStepIndex: 1
            )
            .padding(.horizontal, 28)
        }
    }
}
