import SwiftUI

// MARK: - Diagnosis Tab

enum DiagnosisTab: String, CaseIterable, Identifiable {
    case score
    case type
    case data
    case summary

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .score: return "スコア"
        case .type: return "TYPE"
        case .data: return "データ"
        case .summary: return "サマリ"
        }
    }
}

// MARK: - Color tokens (yabatalk 用)

private enum DiagTabColors {
    static let headerBg = MeloColors.Surface.pinkPale
    static let nameText = MeloColors.Text.primary
    static let selectedBg = MeloColors.Brand.pink
    static let unselectedBg = Color.white
    static let tabBorder = MeloColors.Surface.pinkPale
    static let tabText = MeloColors.Text.primary
    static let accentPink = MeloColors.Brand.pink
}

// MARK: - Header

struct DiagnosisResultHeader: View {
    let displayName: String
    @Binding var selectedTab: DiagnosisTab
    let onBack: () -> Void
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                VStack(spacing: 1) {
                    Text(displayName)
                        .font(MeloFonts.zenMaruOrFallback(20))
                        .foregroundColor(MeloColors.Text.primary)
                        .tracking(0.6)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle {
                        Text(subtitle)
                            .font(MeloFonts.zenMaruRegular(11))
                            .foregroundColor(MeloColors.Text.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 54)

                HStack {
                    Button {
                        HapticManager.light()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DiagTabColors.nameText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 8)
            }

            HStack(spacing: 5) {
                ForEach(DiagnosisTab.allCases) { tab in
                    tabPill(for: tab)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.bottom, 10)
    }

    private func tabPill(for tab: DiagnosisTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            HapticManager.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                if !isSelected {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DiagTabColors.accentPink)
                }
                Text(tab.localizedName)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .tracking(0.36)
                    .foregroundColor(isSelected ? .white : DiagTabColors.tabText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minWidth: 76)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(MeloColors.Gradient.pinkPrimary)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(DiagTabColors.unselectedBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(DiagTabColors.tabBorder, lineWidth: 1)
                            )
                    }
                }
            )
            .shadow(
                color: isSelected
                    ? MeloColors.Brand.pink.opacity(0.45)
                    : MeloColors.Brand.pinkLight.opacity(0.5),
                radius: isSelected ? 6 : 3,
                x: 0,
                y: isSelected ? 2 : 1
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Container View

struct DiagnosisResultView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let result: DiagnosisResult
    @State private var selectedTab: DiagnosisTab = .score

    var body: some View {
        VStack(spacing: 0) {
            DiagnosisResultHeader(
                displayName: displayName,
                selectedTab: $selectedTab,
                onBack: { coordinator.popToRoot() },
                subtitle: subtitleText
            )

            ScrollView {
                VStack(spacing: 18) {
                    switch selectedTab {
                    case .score:
                        DiagnosisScoreTab(result: result)
                    case .type:
                        DiagnosisTypeTab(result: result)
                    case .data:
                        DiagnosisDataTab(result: result)
                    case .summary:
                        DiagnosisSummaryTab(result: result)
                    }
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                MeloColors.Surface.pinkPale
                Image("bg_diagnose_stardust")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.3)
            }
            .ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private var displayName: String {
        result.sessionTitle.isEmpty ? "毒見結果" : result.sessionTitle
    }

    private var subtitleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return "\(formatter.string(from: result.createdAt)) の毒見"
    }

    private var shareText: String {
        """
        🍬 トークの毒見結果

        \(result.primaryType.emoji) \(result.primaryType.typeName)
        対応: \(result.harassmentLabel)
        やばさ: \(result.overallRiskScore)% (\(result.riskLevel.displayName))

        \(result.catchCopy)
        """
    }
}

// MARK: - SCORE TAB

struct DiagnosisScoreTab: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(spacing: 18) {
            verdictCard
            categoryBarsCard
            ingredientsCard
        }
    }

    private var verdictCard: some View {
        VStack(spacing: 10) {
            Text(verdictHeadline)
                .font(MeloFonts.zenMaru(22))
                .foregroundColor(MeloColors.Brand.pink)
                .multilineTextAlignment(.center)
                .tracking(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(result.overallRiskScore)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(MeloColors.Gradient.pinkPrimary)
                Text("%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(MeloColors.Gradient.pinkPrimary)
            }

            Text(result.dangerLabel)
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(MeloColors.Text.secondary)

            Text(result.catchCopy)
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(MeloColors.Text.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(whiteCard)
    }

    private var verdictHeadline: String {
        switch result.riskLevel {
        case .low: return "今のところ平和です ✨"
        case .caution: return "ちょっと怪しい香り…"
        case .medium: return "それなりに香ばしい関係"
        case .high: return "かなりヤバいトークです 🚨"
        case .severe: return "ヤバ度 MAX。即避難レベル！"
        }
    }

    private var categoryBarsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("カテゴリ別やばさ")
            VStack(spacing: 12) {
                ForEach(HarassmentCategory.allCases, id: \.self) { cat in
                    let score = result.categoryScores[cat] ?? 0
                    categoryRow(cat: cat, score: score)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func categoryRow(cat: HarassmentCategory, score: Int) -> some View {
        HStack(spacing: 10) {
            Text(cat.emoji)
                .font(.system(size: 22))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cat.displayName)
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(MeloColors.Text.primary)
                    Spacer()
                    Text("\(score)%")
                        .font(MeloFonts.zenMaruMedium(14).monospacedDigit())
                        .foregroundColor(colorForScore(score))
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.7))
                            .overlay(
                                Capsule().stroke(MeloColors.Surface.pinkPale, lineWidth: 1)
                            )
                        Capsule()
                            .fill(MeloColors.Gradient.pinkPrimary)
                            .frame(width: proxy.size.width * CGFloat(score) / 100)
                    }
                }
                .frame(height: 10)
            }
        }
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("🧪 闇成分ミックス")
            let items = result.topIngredients()
            if items.isEmpty {
                Text("ヤバ成分は検出されませんでした。")
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Text.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        ingredientRow(item: item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func ingredientRow(item: FactorScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.displayName)
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(MeloColors.Text.primary)
                Spacer()
                Text("\(item.score)%")
                    .font(MeloFonts.zenMaruMedium(12).monospacedDigit())
                    .foregroundColor(colorForScore(item.score))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MeloColors.Surface.pinkPale)
                    Capsule()
                        .fill(MeloColors.Gradient.pinkPrimary)
                        .frame(width: proxy.size.width * CGFloat(item.score) / 100)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - TYPE TAB

struct DiagnosisTypeTab: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(spacing: 18) {
            if !result.speakerVerdicts.isEmpty {
                speakerVerdictsHeadline
                ForEach(result.speakerVerdicts) { verdict in
                    speakerVerdictCard(verdict: verdict)
                }
                Divider().padding(.horizontal, 20)
                conversationOverallCard
            } else {
                heroTypeCard
            }
            structureCard
            if !result.categoryBreakdowns.isEmpty {
                categoryBreakdownsCard
            }
        }
    }

    private var speakerVerdictsHeadline: some View {
        VStack(spacing: 4) {
            Text("👥 二人それぞれのタイプ")
                .font(MeloFonts.zenMaru(22))
                .foregroundColor(MeloColors.Brand.pink)
            Text("発言主ごとに独立して判定しました。会話全体ではなく、それぞれ個別のヤバ度。")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func speakerVerdictCard(verdict: SpeakerVerdict) -> some View {
        VStack(spacing: 14) {
            // 話者名 + スコア
            HStack {
                Text(verdict.speakerName)
                    .font(MeloFonts.zenMaru(16))
                    .foregroundColor(MeloColors.Text.primary)
                Spacer()
                Text("\(verdict.score)%")
                    .font(MeloFonts.zenMaru(20).monospacedDigit())
                    .foregroundStyle(MeloColors.Gradient.pinkPrimary)
                Text(verdict.level.displayName)
                    .font(MeloFonts.zenMaruMedium(11))
                    .foregroundColor(MeloColors.Text.secondary)
            }

            // タイプ円 + 名前
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(MeloColors.Surface.pinkPale)
                        .frame(width: 92, height: 92)
                    Text(verdict.primaryType.emoji)
                        .font(.system(size: 56))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(verdict.primaryType.typeName)
                        .font(MeloFonts.zenMaru(17))
                        .foregroundColor(MeloColors.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        ForEach(Array(verdict.primaryType.primaryCategories.enumerated()), id: \.offset) { _, cat in
                            Text(cat.shortName)
                                .font(MeloFonts.zenMaruMedium(10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(MeloColors.Gradient.pinkPrimary))
                        }
                    }
                    Text(verdict.dangerLabel)
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Text.secondary)
                }
                Spacer(minLength: 0)
            }

            Divider()

            // ひとことで言うと
            VStack(alignment: .leading, spacing: 4) {
                Text("ひとことで言うと")
                    .font(MeloFonts.zenMaruMedium(11))
                    .foregroundColor(MeloColors.Text.secondary)
                Text(verdict.oneLineVerdict)
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verdict.catchCopy)
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 口癖シグネチャ
            if !verdict.signaturePhrases.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🗣 \(verdict.speakerName) がよく出す言葉")
                        .font(MeloFonts.zenMaruMedium(12))
                        .foregroundColor(MeloColors.Text.primary)
                    PhraseChips(phrases: verdict.signaturePhrases)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 刺さってる一言
            if let q = verdict.topQuote {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💬 特に刺さってる発言")
                        .font(MeloFonts.zenMaruMedium(12))
                        .foregroundColor(MeloColors.Text.primary)
                    Text("「\(q.quote)」")
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(MeloColors.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("→ \(q.explanation)")
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(whiteCard)
    }

    private var conversationOverallCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📍 会話全体の総括タイプ")
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(MeloColors.Text.secondary)
            HStack(spacing: 12) {
                Text(result.primaryType.emoji)
                    .font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.primaryType.typeName)
                        .font(MeloFonts.zenMaru(15))
                    Text(result.harassmentLabel)
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Brand.pink)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(whiteCard)
    }

    private var heroTypeCard: some View {
        VStack(spacing: 12) {
            Text(verdictHeadline)
                .font(MeloFonts.zenMaru(22))
                .foregroundColor(MeloColors.Brand.pink)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .fill(MeloColors.Surface.pinkPale)
                    .frame(width: 140, height: 140)
                Text(result.primaryType.emoji)
                    .font(.system(size: 84))
            }

            Text(result.primaryType.typeName)
                .font(MeloFonts.zenMaru(20))
                .foregroundColor(MeloColors.Text.primary)
                .tracking(0.6)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                ForEach(Array(result.primaryType.primaryCategories.enumerated()), id: \.offset) { _, cat in
                    Text(cat.shortName)
                        .font(MeloFonts.zenMaruMedium(11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(MeloColors.Gradient.pinkPrimary))
                }
            }

            Text(result.catchCopy)
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(MeloColors.Text.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(whiteCard)
    }

    private var verdictHeadline: String {
        switch result.riskLevel {
        case .low, .caution: return "あなたのトーク相手の正体"
        case .medium: return "ちょっと香ばしいタイプ"
        case .high: return "かなりヤバいタイプ"
        case .severe: return "ヤバ度 MAX のタイプ"
        }
    }

    private var structureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("このタイプの特徴")
            Text(result.primaryType.structureSummary)
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(MeloColors.Text.primary)
            Text(result.primaryType.darkHumorAdvice)
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(MeloColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private var categoryBreakdownsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("📂 カテゴリ別の根拠")
            ForEach(result.categoryBreakdowns) { breakdown in
                breakdownRow(breakdown: breakdown)
                if breakdown.id != result.categoryBreakdowns.last?.id {
                    Divider().padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func breakdownRow(breakdown: CategoryBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(breakdown.category.emoji)
                Text(breakdown.category.displayName)
                    .font(MeloFonts.zenMaruMedium(14))
                Spacer()
                Text("\(breakdown.score)%")
                    .font(MeloFonts.zenMaruMedium(14).monospacedDigit())
                    .foregroundColor(colorForScore(breakdown.score))
            }
            Text(breakdown.narrative)
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !breakdown.contributingFactors.isEmpty {
                Text(breakdown.contributingFactors.map { "「\($0.factor.displayName)」\($0.score)%" }.joined(separator: " ・ "))
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(MeloColors.Text.secondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - DATA TAB

struct DiagnosisDataTab: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(spacing: 18) {
            speakerCompareCard
            funStatsCard
            if !result.factorDeepDives.isEmpty {
                factorDetailsCard
            }
            quotesCard
            allDetectionsLogCard
        }
    }

    /// 全検出ログ（時系列、誰がいつ何を言ったか）
    private var allDetectionsLogCard: some View {
        let allDetections: [(speakerName: String, timestamp: Date, factor: HarassmentFactor, evidence: String, matchedPattern: String, severity: FactorSeverity)] = result.factorScores
            .flatMap { fs in
                fs.detections.map { det in
                    (speakerName: det.speakerName,
                     timestamp: det.timestamp,
                     factor: det.factor,
                     evidence: det.evidence,
                     matchedPattern: det.matchedPattern,
                     severity: det.severity)
                }
            }
            .sorted { $0.timestamp < $1.timestamp }

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader("📜 全検出ログ (\(allDetections.count) 件)")
            Text("検出されたヤバ要素を全部時系列で。誰がいつ何のパターンで引っかかったか、納得できなければ実際の発言と比べてください。")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if allDetections.isEmpty {
                Text("検出されたヤバ要素はありません。")
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Text.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(allDetections.enumerated()), id: \.offset) { _, det in
                        detectionLogRow(
                            speakerName: det.speakerName,
                            timestamp: det.timestamp,
                            factor: det.factor,
                            evidence: det.evidence,
                            matchedPattern: det.matchedPattern,
                            severity: det.severity
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func detectionLogRow(
        speakerName: String,
        timestamp: Date,
        factor: HarassmentFactor,
        evidence: String,
        matchedPattern: String,
        severity: FactorSeverity
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(speakerName)
                    .font(MeloFonts.zenMaruMedium(11))
                    .foregroundColor(MeloColors.Brand.pink)
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(MeloFonts.zenMaruRegular(10))
                    .foregroundColor(MeloColors.Text.secondary)
                Spacer()
                Text(factor.displayName)
                    .font(MeloFonts.zenMaruMedium(10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(MeloColors.Surface.pinkPale))
                    .foregroundColor(MeloColors.Brand.pink)
                Text(severityBadge(for: severity))
                    .font(MeloFonts.zenMaruMedium(10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(severityFill(for: severity)))
                    .foregroundColor(.white)
            }
            Text(evidence)
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("パターン: \(matchedPattern)")
                .font(MeloFonts.zenMaruRegular(10))
                .foregroundColor(MeloColors.Text.secondary.opacity(0.8))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeloColors.Surface.pinkPale.opacity(0.4))
        )
    }

    private func severityFill(for severity: FactorSeverity) -> Color {
        switch severity {
        case .low: return MeloColors.Brand.pinkLight
        case .medium: return MeloColors.Brand.pink
        case .high: return MeloColors.Brand.pinkDeep
        }
    }

    /// 話者別ヤバ発言比較
    private var speakerCompareCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("👥 誰がよりヤバいか")
            Text("両者の発言を全部スキャンしてます。お互いの " + "ヤバ発言の出方を比べてみてください。")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                ForEach(result.stats.perSpeaker) { speaker in
                    speakerRow(speaker: speaker)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func speakerRow(speaker: SpeakerStats) -> some View {
        let totalDetections = max(1, result.stats.perSpeaker.map(\.detectionCount).reduce(0, +))
        let ratio = Double(speaker.detectionCount) / Double(totalDetections)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(speaker.speakerName)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Text.primary)
                Spacer()
                Text("\(speaker.detectionCount) 件")
                    .font(MeloFonts.zenMaruMedium(13).monospacedDigit())
                    .foregroundColor(MeloColors.Brand.pink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MeloColors.Surface.pinkPale)
                    Capsule()
                        .fill(MeloColors.Gradient.pinkPrimary)
                        .frame(width: proxy.size.width * CGFloat(ratio))
                }
            }
            .frame(height: 10)
            HStack(spacing: 8) {
                if let topFactor = speaker.topFactor {
                    Text("最多: \(topFactor.displayName)")
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Text.secondary)
                }
                if speaker.nightCount > 0 {
                    Text("🌙 \(speaker.nightCount)")
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Text.secondary)
                }
            }
        }
    }

    private var funStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("📊 おもしろ統計")
            VStack(spacing: 10) {
                statRow(title: "総発言数", value: "\(result.stats.totalMessages)")
                statRow(title: "テキスト発言", value: "\(result.stats.totalTextMessages)")
                statRow(title: "ヤバ発言の割合", value: "\(result.stats.detectionRatePercent)%")
                statRow(title: "検出された構成要素", value: "\(result.stats.detectedFactorCount) 件")
                if result.stats.nightDetectionCount > 0 {
                    statRow(title: "🌙 深夜ヤバ発言", value: "\(result.stats.nightDetectionCount) 件")
                }
                if let first = result.stats.firstDetectionAt {
                    statRow(title: "最初のヤバ発言", value: first.formatted(date: .abbreviated, time: .shortened))
                }
                if let last = result.stats.lastDetectionAt {
                    statRow(title: "最新のヤバ発言", value: last.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(MeloColors.Text.secondary)
            Spacer()
            Text(value)
                .font(MeloFonts.zenMaruMedium(14).monospacedDigit())
                .foregroundColor(MeloColors.Text.primary)
        }
    }

    private var factorDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("🔍 構成要素のディテール")
            ForEach(result.factorDeepDives) { dive in
                deepDiveRow(dive: dive)
                if dive.id != result.factorDeepDives.last?.id {
                    Divider().padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func deepDiveRow(dive: FactorDeepDive) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dive.title)
                    .font(MeloFonts.zenMaruMedium(14))
                Spacer()
                Text("\(dive.score)%")
                    .font(MeloFonts.zenMaruMedium(13).monospacedDigit())
                    .foregroundColor(colorForScore(dive.score))
                Text(severityBadge(for: dive.severity))
                    .font(MeloFonts.zenMaruMedium(10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(MeloColors.Surface.pinkPale))
                    .foregroundColor(MeloColors.Brand.pink)
            }
            Text("検出 \(dive.detectionCount) 件")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Text.secondary)
            Text(dive.detail)
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !dive.sampleEvidences.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("根拠サンプル（\(dive.sampleEvidences.count) 件）")
                        .font(MeloFonts.zenMaruMedium(11))
                        .foregroundColor(MeloColors.Brand.pink)
                    ForEach(dive.sampleEvidences) { sample in
                        evidenceSampleRow(sample: sample)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func evidenceSampleRow(sample: FactorEvidenceSample) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let speaker = sample.speaker, !speaker.isEmpty {
                Text(speaker)
                    .font(MeloFonts.zenMaruMedium(10))
                    .foregroundColor(MeloColors.Brand.pink)
            }
            Text("「\(sample.text)」")
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(MeloColors.Surface.pinkPale.opacity(0.5))
        )
    }

    private var quotesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("💬 刺さってる発言")
            if result.quotedEvidences.isEmpty {
                Text("引用に値する強い表現は検出されませんでした。")
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Text.secondary)
            } else {
                ForEach(result.quotedEvidences) { q in
                    quoteRow(quote: q)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private func quoteRow(quote: QuotedEvidence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                Text("「")
                    .font(.title3.weight(.bold))
                    .foregroundColor(MeloColors.Brand.pink)
                Text(quote.quote)
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("→ \(quote.explanation)")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(quote.speakerName) · \(quote.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(MeloFonts.zenMaruRegular(10))
                .foregroundColor(MeloColors.Text.secondary.opacity(0.7))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - SUMMARY TAB

struct DiagnosisSummaryTab: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(spacing: 18) {
            futureCard
            actionCard
            logicCard
            disclaimerPanel
        }
    }

    private var futureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("🔮 2人の未来")
            Text(futureText)
                .font(MeloFonts.zenMaruRegular(14))
                .foregroundColor(MeloColors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private var futureText: String {
        switch result.riskLevel {
        case .low:
            return "このまま進めば、お互いに違和感なく付き合っていけそうな関係です。たまに「これって普通？」と確認し合うクセを残しておけば、健全さは保たれます。"
        case .caution:
            return "今は許容範囲ですが、放置すると「あれ、これ我慢してる…」と気づくのが半年後になりがちなパターン。違和感は溜めずに、軽いうちに伝えるのが吉です。"
        case .medium:
            return "このまま進むと、笑い話で済まなくなる確率が上がります。「これは指摘していい話」「ここは流していい話」を線引きできるかどうかが分かれ目です。"
        case .high:
            return "このまま進むと、関係そのものがあなたの自己肯定感を消費する装置になります。逃げ場の確保と、距離の取り方をいま考え始めるタイミングです。"
        case .severe:
            return "このまま続けることのコストが、関係を続けるメリットを上回っている可能性が高いです。第三者に相談する・距離を取る・記録を残す、いずれかは今日から動くべきフェーズです。"
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("✨ 来月のアクション")
            ForEach(Array(actionItems.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(idx + 1).")
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(MeloColors.Brand.pink)
                    Text(item)
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(MeloColors.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private var actionItems: [String] {
        if !result.nextSteps.isEmpty {
            return result.nextSteps
        }
        // フォールバック
        switch result.riskLevel {
        case .low, .caution:
            return ["違和感は溜めずに軽く言葉にしておく", "「冗談」と「圧」の境界をお互いに確認しておく"]
        case .medium:
            return ["気になる発言はスクショで残しておく", "信頼できる第三者に状況を雑談ベースで共有しておく"]
        case .high, .severe:
            return ["トーク履歴は削除せず保存しておく", "信頼できる第三者に相談 or 距離をとる選択肢を検討", "結果をシェアして「これ、ヤバくない？」と意見をもらう"]
        }
    }

    private var logicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("📝 占い的に言うと")
            ForEach(Array(result.logicParagraphs.enumerated()), id: \.offset) { _, p in
                Text(p)
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(whiteCard)
    }

    private var disclaimerPanel: some View {
        Text(result.disclaimer)
            .font(MeloFonts.zenMaruRegular(10))
            .foregroundColor(MeloColors.Text.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }
}

// MARK: - Shared helpers

private var whiteCard: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MeloColors.Brand.pink.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: MeloColors.Brand.pink.opacity(0.08), radius: 8, x: 0, y: 2)
}

private func sectionHeader(_ text: String) -> some View {
    Text(text)
        .font(MeloFonts.zenMaru(15))
        .foregroundColor(MeloColors.Text.primary)
        .tracking(0.4)
}

private func colorForScore(_ score: Int) -> Color {
    let level = RiskLevel.from(score: score)
    switch level {
    case .low: return MeloColors.Text.secondary
    case .caution: return MeloColors.Brand.pinkLight
    case .medium: return MeloColors.Brand.pink
    case .high: return MeloColors.Brand.pinkDeep
    case .severe: return Color(red: 0.75, green: 0.05, blue: 0.20)
    }
}

private func severityBadge(for severity: FactorSeverity) -> String {
    switch severity {
    case .low: return "弱"
    case .medium: return "中"
    case .high: return "強"
    }
}

// MARK: - Phrase Chips

/// 口癖シグネチャを 2 行 wrap で表示
struct PhraseChips: View {
    let phrases: [PhraseSignature]

    var body: some View {
        PhraseFlowLayout(spacing: 6) {
            ForEach(phrases) { p in
                HStack(spacing: 4) {
                    Text(p.phrase)
                        .font(MeloFonts.zenMaruMedium(12))
                        .foregroundColor(MeloColors.Brand.pink)
                    Text("×\(p.count)")
                        .font(MeloFonts.zenMaruRegular(11).monospacedDigit())
                        .foregroundColor(MeloColors.Text.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(MeloColors.Surface.pinkPale)
                )
            }
        }
    }
}

/// シンプルな flow layout (iOS 16+ Layout protocol)
struct PhraseFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
