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
    static let headerBg = MeloColors.Dark.bgElevated
    static let nameText = MeloColors.Dark.textPrimary
    static let selectedBg = MeloColors.Dark.accent
    static let unselectedBg = MeloColors.Dark.bgElevated
    static let tabBorder = MeloColors.Dark.cardStroke
    static let tabText = MeloColors.Dark.textSecondary
    static let accentPink = MeloColors.Dark.accent
}

// MARK: - Header

struct DiagnosisResultHeader: View {
    let displayName: String
    let dateText: String
    let specimenNo: String
    @Binding var selectedTab: DiagnosisTab
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    HapticManager.light()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Text("検体 No. \(specimenNo)")
                    .font(MeloFonts.mono(11))
                    .foregroundColor(MeloColors.Dark.textSecondary)

                Spacer()
                inspectedStamp
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("毒性鑑定書")
                        .font(MeloFonts.anton(30))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                    Text("TOXICITY REPORT")
                        .font(MeloFonts.mono(9))
                        .foregroundColor(MeloColors.Dark.accent)
                        .tracking(1.5)
                }
                Spacer(minLength: 8)
                MascotImage(name: LabMascot.pose(for: selectedTab), size: 86)
                    .id(selectedTab)
                    .transition(.scale(scale: 0.65).combined(with: .opacity))
            }

            Text("\(displayName)  /  \(dateText)")
                .font(MeloFonts.mono(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Rectangle()
                .fill(MeloColors.Dark.cardStroke)
                .frame(height: 1)

            HStack(spacing: 18) {
                ForEach(DiagnosisTab.allCases) { tab in
                    tabPill(for: tab)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var inspectedStamp: some View {
        VStack(spacing: 0) {
            Text("毒見済")
                .font(MeloFonts.zenMaru(11))
                .foregroundColor(MeloColors.Dark.accent)
            Text("INSPECTED")
                .font(MeloFonts.mono(6))
                .foregroundColor(MeloColors.Dark.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(MeloColors.Dark.accent, lineWidth: 1.5)
        )
        .rotationEffect(.degrees(-7))
    }

    private func tabPill(for tab: DiagnosisTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            HapticManager.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                Text(tab.localizedName)
                    .font(isSelected ? MeloFonts.zenMaru(13) : MeloFonts.zenMaruMedium(13))
                    .foregroundColor(isSelected ? MeloColors.Dark.accent : MeloColors.Dark.textSecondary)
                Rectangle()
                    .fill(isSelected ? MeloColors.Dark.accent : Color.clear)
                    .frame(width: 28, height: 2)
            }
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
                dateText: result.labDateText,
                specimenNo: result.labSpecimenNo,
                selectedTab: $selectedTab,
                onBack: { coordinator.popToRoot() }
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
        .background(MeloColors.Dark.bg.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .onAppear {
            #if DEBUG
            if let t = YabatalkDebug.seedInitialTab { selectedTab = t }
            #endif
        }
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
        VStack(spacing: 16) {
            verdictCard
            componentsCard
            classificationCard
        }
    }

    // 鑑定結果（試験管メーター + 危険度 + 疑似バーコード）
    // 見た目の正本は再利用ビュー ToxicityVerdictCardView に集約（掲示板の毒性添付カードと共有）。
    private var verdictCard: some View {
        ToxicityVerdictCardView(result: result)
    }

    // 毒性成分分析（成分表シート + 濃度ドット）
    private var componentsCard: some View {
        LabCard {
            VStack(spacing: 12) {
                LabCardHeader(jp: "毒性成分分析", en: "TOXIC COMPONENTS")
                Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)

                let items = result.topIngredients()
                if items.isEmpty {
                    Text("ヤバ成分は検出されませんでした。")
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        componentRow(item)
                        if idx < items.count - 1 {
                            Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func componentRow(_ item: FactorScore) -> some View {
        let c = labSeverityColor(item.score)
        return HStack(spacing: 10) {
            Text(item.displayName)
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(MeloColors.Dark.textPrimary)
            Spacer(minLength: 8)
            SeverityDots(pct: item.score, color: c)
            Text("\(item.score)%")
                .font(MeloFonts.monoMedium(13))
                .foregroundColor(c)
        }
    }

    // ハラスメント分類（分類コードチップ + ハザードバー）
    private var classificationCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: "ハラスメント分類", en: "CLASSIFICATION")
                ForEach(HarassmentCategory.allCases, id: \.self) { cat in
                    classificationRow(cat)
                }
            }
        }
    }

    private func classificationRow(_ cat: HarassmentCategory) -> some View {
        let score = result.categoryScores[cat] ?? 0
        let c = labSeverityColor(score)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LabCategoryTag(code: cat.labCode, color: c)
                Text(cat.displayName)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Spacer()
                Text("\(score)%")
                    .font(MeloFonts.monoMedium(14))
                    .foregroundColor(c)
            }
            LabBar(pct: score, color: c)
        }
    }
}

// MARK: - TYPE TAB

struct DiagnosisTypeTab: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(spacing: 16) {
            LabSectionTitle(jp: "検体プロファイル", en: "SPECIMEN PROFILE  /  個別に毒性判定")
            if !result.speakerVerdicts.isEmpty {
                ForEach(result.speakerVerdicts) { verdict in
                    speakerVerdictCard(verdict: verdict)
                }
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

    private func speakerVerdictCard(verdict: SpeakerVerdict) -> some View {
        let color = verdict.level.labColor
        return LabCard(hazardColor: color) {
            VStack(alignment: .leading, spacing: 14) {
                // 上段: 検体ラベル + 話者名 + スコア
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("検体")
                        .font(MeloFonts.mono(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                    Text(verdict.speakerName)
                        .font(MeloFonts.zenMaru(16))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(verdict.score)")
                            .font(MeloFonts.anton(26))
                            .foregroundColor(color)
                        Text("%")
                            .font(MeloFonts.anton(12))
                            .foregroundColor(color)
                    }
                    Text(verdict.level.displayName)
                        .font(MeloFonts.zenMaruMedium(11))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }

                // ヒーロー: キャラ・プレート + タイプ名 + 分類chip
                HStack(alignment: .top, spacing: 14) {
                    MascotPlate(name: LabMascot.typePlate, color: color, size: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(verdict.primaryType.typeName)
                            .font(MeloFonts.zenMaru(17))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        PhraseFlowLayout(spacing: 4) {
                            ForEach(Array(verdict.primaryType.primaryCategories.enumerated()), id: \.offset) { _, cat in
                                LabCodeChip(text: cat.shortName, color: MeloColors.Dark.accent, filled: true)
                            }
                        }
                        Text(verdict.dangerLabel)
                            .font(MeloFonts.zenMaruRegular(11))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)

                // 所見
                VStack(alignment: .leading, spacing: 4) {
                    Text("所見 / FINDINGS")
                        .font(MeloFonts.monoMedium(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                    Text(verdict.oneLineVerdict)
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verdict.catchCopy)
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 検出フレーズ
                if !verdict.signaturePhrases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("検出フレーズ / SIGNATURE")
                            .font(MeloFonts.monoMedium(10))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                        PhraseFlowLayout(spacing: 6) {
                            ForEach(verdict.signaturePhrases) { p in
                                LabCodeChip(text: "[\(p.phrase)] ×\(p.count)", color: MeloColors.Dark.accent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 最毒サンプル
                if let q = verdict.topQuote {
                    LabWell {
                        Text("最毒サンプル / KEY SAMPLE")
                            .font(MeloFonts.monoMedium(10))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                        Text("「\(q.quote)」")
                            .font(MeloFonts.zenMaru(13))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("→ \(q.explanation)")
                            .font(MeloFonts.zenMaruRegular(11))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var conversationOverallCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: "総合判定", en: "OVERALL")
                HStack(spacing: 14) {
                    LabCategoryTag(code: result.primaryCategory.labCode, color: MeloColors.Dark.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.primaryType.typeName)
                            .font(MeloFonts.zenMaru(15))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("CATEGORY: \(result.harassmentLabel)")
                            .font(MeloFonts.monoMedium(11))
                            .foregroundColor(MeloColors.Dark.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var heroTypeCard: some View {
        LabCard(hazardColor: result.riskLevel.labColor) {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: "総合判定", en: "OVERALL")
                HStack(alignment: .top, spacing: 14) {
                    LabCategoryTag(code: result.primaryCategory.labCode, color: result.riskLevel.labColor)
                        .scaleEffect(1.4)
                        .frame(width: 56, height: 40)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.primaryType.typeName)
                            .font(MeloFonts.zenMaru(18))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        PhraseFlowLayout(spacing: 4) {
                            ForEach(Array(result.primaryType.primaryCategories.enumerated()), id: \.offset) { _, cat in
                                LabCodeChip(text: cat.shortName, color: MeloColors.Dark.accent, filled: true)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                Text(result.catchCopy)
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var structureCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 10) {
                LabCardHeader(jp: "型の特性", en: "PROFILE")
                Text(result.primaryType.structureSummary)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(result.primaryType.darkHumorAdvice)
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var categoryBreakdownsCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: "カテゴリ別の根拠", en: "BASIS")
                ForEach(result.categoryBreakdowns) { breakdown in
                    breakdownRow(breakdown: breakdown)
                    if breakdown.id != result.categoryBreakdowns.last?.id {
                        Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                    }
                }
            }
        }
    }

    private func breakdownRow(breakdown: CategoryBreakdown) -> some View {
        let c = labSeverityColor(breakdown.score)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LabCategoryTag(code: breakdown.category.labCode, color: c)
                Text(breakdown.category.displayName)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Spacer()
                Text("\(breakdown.score)%")
                    .font(MeloFonts.monoMedium(14))
                    .foregroundColor(c)
            }
            Text(breakdown.narrative)
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !breakdown.contributingFactors.isEmpty {
                Text(breakdown.contributingFactors.map { "\($0.factor.displayName) \($0.score)%" }.joined(separator: "  ・  "))
                    .font(MeloFonts.mono(11))
                    .foregroundColor(MeloColors.Dark.textSecondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - DATA TAB

struct DiagnosisDataTab: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(spacing: 16) {
            LabSectionTitle(jp: "検査データ", en: "LAB DATA  /  全発言スキャン結果")
            speakerCompareCard
            funStatsCard
            if !result.factorDeepDives.isEmpty {
                factorDetailsCard
            }
            quotesCard
            allDetectionsLogCard
        }
    }

    private func severityColor(for severity: FactorSeverity) -> Color {
        switch severity {
        case .low: return MeloColors.Dark.accent
        case .medium: return MeloColors.Dark.caution
        case .high: return MeloColors.Dark.danger
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

        return LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: "検出ログ", en: "DETECTION LOG")
                Text("検出されたヤバ要素を全部時系列で。誰がいつ何のパターンで引っかかったか、納得できなければ実際の発言と比べてください。")
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if allDetections.isEmpty {
                    Text("検出されたヤバ要素はありません。")
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                } else {
                    ForEach(Array(allDetections.enumerated()), id: \.offset) { idx, det in
                        detectionLogRow(
                            speakerName: det.speakerName,
                            timestamp: det.timestamp,
                            factor: det.factor,
                            evidence: det.evidence,
                            matchedPattern: det.matchedPattern,
                            severity: det.severity
                        )
                        if idx < allDetections.count - 1 {
                            Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func detectionLogRow(
        speakerName: String,
        timestamp: Date,
        factor: HarassmentFactor,
        evidence: String,
        matchedPattern: String,
        severity: FactorSeverity
    ) -> some View {
        let c = severityColor(for: severity)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(MeloFonts.mono(10))
                    .foregroundColor(c)
                LabCodeChip(text: factor.displayName, color: c)
                Spacer(minLength: 4)
                Text(speakerName)
                    .font(MeloFonts.mono(9))
                    .foregroundColor(MeloColors.Dark.textSecondary)
            }
            Text("「\(evidence)」")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text("PATTERN: \(matchedPattern)")
                .font(MeloFonts.mono(9))
                .foregroundColor(MeloColors.Dark.textSecondary.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 話者別ヤバ発言比較
    private var speakerCompareCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: "発生源比較", en: "SOURCE")
                Text("両者の発言を全部スキャンしてます。お互いのヤバ発言の出方を比べてみてください。")
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(result.stats.perSpeaker) { speaker in
                    speakerRow(speaker: speaker)
                }
            }
        }
    }

    private func speakerRow(speaker: SpeakerStats) -> some View {
        let totalDetections = max(1, result.stats.perSpeaker.map(\.detectionCount).reduce(0, +))
        let ratio = Double(speaker.detectionCount) / Double(totalDetections)
        let hasHits = speaker.detectionCount > 0
        let barColor = hasHits ? MeloColors.Dark.danger : MeloColors.Dark.track
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(speaker.speakerName)
                    .font(MeloFonts.zenMaruMedium(15))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Spacer()
                Text("\(speaker.detectionCount)")
                    .font(MeloFonts.anton(20))
                    .foregroundColor(hasHits ? MeloColors.Dark.danger : MeloColors.Dark.textSecondary)
                Text("件")
                    .font(MeloFonts.mono(10))
                    .foregroundColor(MeloColors.Dark.textSecondary)
            }
            LabBar(pct: Int((ratio * 100).rounded()), color: barColor, height: 8)
            HStack(spacing: 10) {
                if let topFactor = speaker.topFactor {
                    Text("最多: \(topFactor.displayName)")
                        .font(MeloFonts.mono(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }
                if speaker.nightCount > 0 {
                    Text("深夜 \(speaker.nightCount)")
                        .font(MeloFonts.mono(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }
            }
        }
    }

    private var funStatsCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 10) {
                LabCardHeader(jp: "検査統計", en: "STATISTICS")
                statRow(label: "総発言数", value: "\(result.stats.totalMessages)", color: MeloColors.Dark.textPrimary)
                statRow(label: "テキスト発言", value: "\(result.stats.totalTextMessages)", color: MeloColors.Dark.textPrimary)
                statRow(label: "ヤバ発言の割合", value: "\(result.stats.detectionRatePercent)%", color: labSeverityColor(result.stats.detectionRatePercent))
                statRow(label: "検出された構成要素", value: "\(result.stats.detectedFactorCount) 件", color: MeloColors.Dark.accent)
                if result.stats.nightDetectionCount > 0 {
                    statRow(label: "深夜ヤバ発言", value: "\(result.stats.nightDetectionCount) 件", color: MeloColors.Dark.caution)
                }
                if let first = result.stats.firstDetectionAt {
                    statRow(label: "最初のヤバ発言", value: first.formatted(date: .abbreviated, time: .shortened), color: MeloColors.Dark.textSecondary)
                }
                if let last = result.stats.lastDetectionAt {
                    statRow(label: "最新のヤバ発言", value: last.formatted(date: .abbreviated, time: .shortened), color: MeloColors.Dark.textSecondary)
                }
            }
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(MeloFonts.mono(12))
                .foregroundColor(MeloColors.Dark.textSecondary)
            Spacer()
            Text(value)
                .font(MeloFonts.monoMedium(12))
                .foregroundColor(color)
        }
    }

    private var factorDetailsCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: "成分詳細", en: "COMPONENT DETAIL")
                ForEach(result.factorDeepDives) { dive in
                    deepDiveRow(dive: dive)
                    if dive.id != result.factorDeepDives.last?.id {
                        Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                    }
                }
            }
        }
    }

    private func deepDiveRow(dive: FactorDeepDive) -> some View {
        let c = labSeverityColor(dive.score)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(dive.title)
                    .font(MeloFonts.zenMaru(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Text("検出 \(dive.detectionCount)")
                    .font(MeloFonts.mono(10))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                Text("\(dive.score)%")
                    .font(MeloFonts.monoMedium(14))
                    .foregroundColor(c)
            }
            Text(dive.detail)
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !dive.sampleEvidences.isEmpty {
                LabWell {
                    Text("根拠サンプル (\(dive.sampleEvidences.count))")
                        .font(MeloFonts.monoMedium(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                    ForEach(dive.sampleEvidences) { sample in
                        evidenceSampleRow(sample: sample)
                    }
                }
            }
        }
    }

    private func evidenceSampleRow(sample: FactorEvidenceSample) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let speaker = sample.speaker, !speaker.isEmpty {
                LabCodeChip(text: speaker, color: MeloColors.Dark.accent)
            }
            Text("「\(sample.text)」")
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quotesCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: "証拠サンプル", en: "EVIDENCE")
                if result.quotedEvidences.isEmpty {
                    Text("引用に値する強い表現は検出されませんでした。")
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                } else {
                    ForEach(result.quotedEvidences) { q in
                        quoteRow(quote: q)
                        if q.id != result.quotedEvidences.last?.id {
                            Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func quoteRow(quote: QuotedEvidence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabCodeChip(text: quote.factor.displayName, color: MeloColors.Dark.danger)
            Text("「\(quote.quote)」")
                .font(MeloFonts.zenMaru(13))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("→ \(quote.explanation)")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(quote.speakerName) · \(quote.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(MeloFonts.mono(9))
                .foregroundColor(MeloColors.Dark.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - SUMMARY TAB

struct DiagnosisSummaryTab: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(spacing: 16) {
            LabSectionTitle(jp: "処方箋", en: "PRESCRIPTION  /  これからの処方")
            futureCard
            actionCard
            logicCard
            disclaimerPanel
        }
    }

    private var futureCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 10) {
                LabCardHeader(jp: "予後", en: "PROGNOSIS")
                Text(futureText)
                    .font(MeloFonts.zenMaruRegular(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
            }
        }
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
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Rx")
                        .font(MeloFonts.anton(22))
                        .foregroundColor(MeloColors.Dark.accent)
                    Text("処方")
                        .font(MeloFonts.zenMaru(15))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                    Spacer()
                    Text("ACTIONS")
                        .font(MeloFonts.mono(9))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .tracking(1)
                }
                ForEach(Array(actionItems.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(format: "%02d", idx + 1))
                            .font(MeloFonts.monoMedium(10))
                            .foregroundColor(MeloColors.Dark.onAccent)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(MeloColors.Dark.accent))
                        Text(item)
                            .font(MeloFonts.zenMaruRegular(13))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
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
        LabCard {
            VStack(alignment: .leading, spacing: 10) {
                LabCardHeader(jp: "総合所見", en: "SUMMARY")
                ForEach(Array(result.logicParagraphs.enumerated()), id: \.offset) { _, p in
                    Text(p)
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var disclaimerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISCLAIMER")
                .font(MeloFonts.monoMedium(9))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .tracking(1)
            Text(result.disclaimer)
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeloColors.Dark.bgElevated)
        )
    }
}

// MARK: - Shared helpers

private var whiteCard: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(MeloColors.Dark.card)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
        )
        .shadow(color: MeloColors.Dark.accent.opacity(0.25), radius: 8, x: 0, y: 2)
}

private func sectionHeader(_ text: String) -> some View {
    Text(text)
        .font(MeloFonts.zenMaru(15))
        .foregroundColor(MeloColors.Dark.textPrimary)
        .tracking(0.4)
}

private func colorForScore(_ score: Int) -> Color {
    let level = RiskLevel.from(score: score)
    switch level {
    case .low: return MeloColors.Dark.textSecondary
    case .caution: return MeloColors.Dark.accentBright
    case .medium: return MeloColors.Dark.accent
    case .high: return MeloColors.Dark.accentDeep
    case .severe: return Color(red: 0.95, green: 0.25, blue: 0.35)
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
                        .foregroundColor(MeloColors.Dark.accent)
                    Text("×\(p.count)")
                        .font(MeloFonts.zenMaruRegular(11).monospacedDigit())
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(MeloColors.Dark.bgElevated)
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
