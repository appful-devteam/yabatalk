import SwiftUI
import SwiftData

// MARK: - Diagnosis Tab

enum DiagnosisTab: String, CaseIterable, Identifiable {
    case score
    case type
    case data
    case summary

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .score: return String(localized: "スコア", bundle: LanguageManager.appBundle)
        case .type: return "TYPE"
        case .data: return String(localized: "データ", bundle: LanguageManager.appBundle)
        case .summary: return String(localized: "サマリ", bundle: LanguageManager.appBundle)
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

            HStack(spacing: 0) {
                ForEach(DiagnosisTab.allCases) { tab in
                    tabPill(for: tab)
                }
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
                    .fill(isSelected ? MeloColors.Dark.accent : MeloColors.Dark.cardStroke.opacity(0.5))
                    .frame(height: 2)
                    .frame(maxWidth: 40)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Container View

struct DiagnosisResultView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let result: DiagnosisResult
    let session: ChatSession?
    @State private var selectedTab: DiagnosisTab = .score
    @StateObject private var summaryVM: HarassmentSummaryViewModel

    init(result: DiagnosisResult, session: ChatSession? = nil) {
        self.result = result
        self.session = session
        _summaryVM = StateObject(wrappedValue: HarassmentSummaryViewModel(result: result, session: session))
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                DiagnosisResultHeader(
                    displayName: displayName,
                    dateText: result.labDateText,
                    specimenNo: result.labSpecimenNo,
                    selectedTab: $selectedTab,
                    onBack: { coordinator.popToRoot() }
                )
                .frame(width: geo.size.width)

                ScrollView {
                    VStack(spacing: 18) {
                        switch selectedTab {
                        case .score:
                            DiagnosisScoreTab(result: result, selfName: session?.estimatedSelfName)
                        case .type:
                            DiagnosisTypeTab(result: result, selfName: session?.estimatedSelfName)
                        case .data:
                            DiagnosisDataTab(result: result, session: session)
                        case .summary:
                            HarassmentSummaryTabView(viewModel: summaryVM)
                        }
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    // 画面幅に確定クランプ。長い名前でもコンテンツが画面幅を超えず、
                    // 横スクロール（左右の揺れ）が発生しなくなる。
                    .frame(width: geo.size.width)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
        result.sessionTitle.isEmpty ? String(localized: "毒見結果", bundle: LanguageManager.appBundle) : result.sessionTitle
    }

    private var subtitleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return String(format: String(localized: "%1$@ の毒見", bundle: LanguageManager.appBundle), formatter.string(from: result.createdAt))
    }

    private var shareText: String {
        String(
            format: String(
                localized: """
                🍬 トークの毒見結果

                %1$@ %2$@
                対応: %3$@
                やばさ: %4$lld%% (%5$@)

                %6$@
                """,
                bundle: LanguageManager.appBundle
            ),
            result.primaryType.emoji,
            result.primaryType.typeName,
            result.harassmentLabel,
            result.overallRiskScore,
            result.riskLevel.displayName,
            result.catchCopy
        )
    }
}

// MARK: - Paywall (プレミアム未加入時のぼかしゲート)

/// 非課金時に、カードのタイトルは見せたまま本文だけをぼかすラッパー。
/// 「タイトルだけ読める + 中身はぼかし」を実現する（めろとーく同様の課金導線）。
private struct LockedBody<Content: View>: View {
    let locked: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if locked {
            content()
                .blur(radius: 7)
                .disabled(true)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MeloColors.Dark.bg.opacity(0.12))
                )
        } else {
            content()
        }
    }
}

/// ロック領域の先頭に出す「プレミアムで全部見る」CTA バナー。
/// ぼかし本文の上ではなく独立カードとして置くので、タップ判定がぼかしと競合しない。
struct DiagnosisUnlockCTA: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    var source: String
    var message: String

    var body: some View {
        Button {
            HapticManager.medium()
            coordinator.subscriptionSource = source
            coordinator.showingSubscription = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MeloColors.Dark.onAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("続きはプレミアム会員")
                        .font(MeloFonts.zenMaru(15))
                        .foregroundColor(MeloColors.Dark.onAccent)
                    Text(message)
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Dark.onAccent.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 8)
                Text("見る")
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(MeloColors.Dark.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(MeloColors.Dark.onAccent))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MeloColors.Dark.accentGradient)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("diagnosis_unlock_cta")
    }
}

// MARK: - SCORE TAB

struct DiagnosisScoreTab: View {
    let result: DiagnosisResult
    var selfName: String? = nil

    @State private var expandedComponents: Set<String> = []
    @State private var expandedCategories: Set<HarassmentCategory> = []

    private let selfColor = MeloColors.Dark.selfTint
    private let partnerColor = MeloColors.Dark.partnerTint

    var body: some View {
        VStack(spacing: 16) {
            if let cmp = comparison {
                // 二者比較（自分 vs 相手の相対的なハラスメント度合い）
                relativeCard(cmp)
                componentsCompareCard(cmp)
                classificationCompareCard(cmp)
            } else {
                // フォールバック（話者が 1 人 / 判定不能）: 会話全体の単独表示
                verdictCard
                componentsCard
                classificationCard
            }
            // 旧データタブの内容（検出の内訳）をスコアタブ下部に統合
            DiagnosisDetectionDetailTab(result: result)
        }
    }

    // MARK: - 二者比較の解決

    private struct Comparison {
        let selfV: SpeakerVerdict
        let partnerV: SpeakerVerdict
        let selfLabel: String
        let partnerLabel: String
        let resolvedSelf: Bool
    }

    private var comparison: Comparison? {
        let verdicts = result.speakerVerdicts
        guard verdicts.count >= 2 else { return nil }
        let sn = (selfName?.isEmpty == false) ? selfName : UserPreferredName.resolve()
        if let sn, let me = verdicts.first(where: { $0.speakerName == sn }),
           let other = verdicts.filter({ $0.id != me.id }).max(by: { $0.score < $1.score }) {
            return Comparison(selfV: me, partnerV: other,
                              selfLabel: String(localized: "自分", bundle: LanguageManager.appBundle), partnerLabel: other.speakerName,
                              resolvedSelf: true)
        }
        // 自分が特定できない → スコア上位 2 人を実名ラベルで
        let sorted = verdicts.sorted { $0.score > $1.score }
        return Comparison(selfV: sorted[0], partnerV: sorted[1],
                          selfLabel: sorted[0].speakerName, partnerLabel: sorted[1].speakerName,
                          resolvedSelf: false)
    }

    /// 二人の合計を 100 とした偏り（selfShare + partnerShare = 100）。
    private func shares(_ cmp: Comparison) -> (selfShare: Int, partnerShare: Int) {
        let s = max(0, cmp.selfV.score)
        let p = max(0, cmp.partnerV.score)
        guard s + p > 0 else { return (50, 50) }
        let selfShare = Int((Double(s) / Double(s + p) * 100).rounded())
        return (selfShare, 100 - selfShare)
    }

    // MARK: - 相対比較カード（試験管 2 本）

    private func relativeCard(_ cmp: Comparison) -> some View {
        let sh = shares(cmp)
        return LabCard(hazardColor: partnerColor, padding: 16) {
            VStack(spacing: 14) {
                // ヘッダー: 鑑定結果 / DIAGNOSIS
                HStack {
                    Text("鑑定結果")
                        .font(MeloFonts.monoMedium(11))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                    Spacer()
                    Text("DIAGNOSIS")
                        .font(MeloFonts.mono(9))
                        .tracking(1)
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }

                // 左: 1 本の試験管を上=自分 / 下=相手 で分割。右: 2 人分の縦積みブロック。
                HStack(alignment: .center, spacing: 16) {
                    SplitTestTube(topShare: sh.selfShare, topColor: selfColor, bottomColor: partnerColor)
                        .padding(.leading, 18)
                    VStack(alignment: .leading, spacing: 26) {
                        personBlock(name: cmp.selfLabel, share: sh.selfShare, color: selfColor, copy: cmp.selfV.catchCopy)
                        personBlock(name: cmp.partnerLabel, share: sh.partnerShare, color: partnerColor, copy: cmp.partnerV.catchCopy)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 下: 疑似バーコード + 検体番号
                HStack(alignment: .center, spacing: 10) {
                    LabBarcode()
                    Spacer()
                    Text("\(result.labSpecimenNo)-\(result.primaryCategory.labCode)")
                        .font(MeloFonts.mono(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }
            }
            // カード本文を利用可能幅に固定。長い名前で横にはみ出して横スクロールが
            // 揺れるのを防ぐ（名前は personBlock 側で truncate）。
            .frame(maxWidth: .infinity)
        }
    }

    private func personBlock(name: String, share: Int, color: Color, copy: String) -> some View {
        let lvl = RiskLevel.from(score: share)
        return VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(MeloFonts.zenMaru(16))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            // 数字（% は数字とベースライン揃え）+ 近接したバッジ/DANGER カラム（下端揃え）
            HStack(alignment: .bottom, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(share)")
                        .font(MeloFonts.anton(72))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text("%")
                        .font(MeloFonts.anton(26))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(shareDangerLabel(share))
                        .font(MeloFonts.zenMaru(12))
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color))
                    Text("DANGER Lv.\(lvl.labLevel)")
                        .font(MeloFonts.monoMedium(10))
                        .tracking(0.2)
                        .foregroundColor(color)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
            }
            if !copy.isEmpty {
                Text(copy)
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 偏りシェアから危険ラベル（カードのバッジ用）。
    private func shareDangerLabel(_ share: Int) -> String {
        switch RiskLevel.from(score: share) {
        case .low: return String(localized: "おとなしめ", bundle: LanguageManager.appBundle)
        case .caution: return String(localized: "ちょっと危ない", bundle: LanguageManager.appBundle)
        case .medium: return String(localized: "そこそこヤバい", bundle: LanguageManager.appBundle)
        case .high: return String(localized: "明確にやばい", bundle: LanguageManager.appBundle)
        case .severe: return String(localized: "かなり危険", bundle: LanguageManager.appBundle)
        }
    }

    /// 1 本の試験管を上=自分シェア / 下=相手シェア で分割表示。
    private struct SplitTestTube: View {
        let topShare: Int
        let topColor: Color
        let bottomColor: Color

        private let tubeW: CGFloat = 54
        private let tubeH: CGFloat = 186
        private let rim = MeloColors.Dark.safe
        private var tubeShape: UnevenRoundedRectangle {
            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 22,
                                   bottomTrailingRadius: 22, topTrailingRadius: 8, style: .continuous)
        }

        var body: some View {
            let topH = tubeH * CGFloat(min(max(topShare, 0), 100)) / 100
            HStack(spacing: 6) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rim)
                        .frame(width: 42, height: 8)
                        .zIndex(2)
                    tubeShape
                        .fill(MeloColors.Dark.bg)
                        .frame(width: tubeW, height: tubeH)
                        .overlay {
                            VStack(spacing: 0) {
                                Rectangle().fill(topColor).frame(height: topH)
                                Rectangle().fill(bottomColor)
                                    .overlay(alignment: .top) {
                                        HStack {
                                            Circle().fill(MeloColors.Dark.bg.opacity(0.45))
                                                .frame(width: 7, height: 7).offset(x: 4, y: 12)
                                            Spacer()
                                            Circle().fill(MeloColors.Dark.bg.opacity(0.4))
                                                .frame(width: 4, height: 4).offset(x: -6, y: 26)
                                        }
                                    }
                            }
                        }
                        .clipShape(tubeShape)
                        .overlay(tubeShape.stroke(rim, lineWidth: 2))
                        .padding(.top, 6)
                }
                .frame(width: tubeW)
                VStack(spacing: 22) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle().fill(MeloColors.Dark.textSecondary).frame(width: 7, height: 2)
                    }
                }
                .padding(.top, 30)
            }
        }
    }

    // MARK: - 分割バー（自分色 | 相手色）

    private func splitBar(selfShare: Int, height: CGFloat) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(selfColor)
                    .frame(width: max(0, geo.size.width * CGFloat(selfShare) / 100))
                Rectangle().fill(partnerColor)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }

    private func legendRow(_ cmp: Comparison) -> some View {
        HStack(spacing: 16) {
            legendChip(color: selfColor, label: cmp.selfLabel)
            legendChip(color: partnerColor, label: cmp.partnerLabel)
            Spacer(minLength: 0)
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label)
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - 毒性成分分析（二人の割合）

    private struct FactorRow: Identifiable {
        let id: String
        let name: String
        let explanation: String
        let selfShare: Int
        let total: Int
    }

    private func factorCompareRows(_ cmp: Comparison) -> [FactorRow] {
        var selfMap: [HarassmentFactor: Int] = [:]
        for f in cmp.selfV.topFactors { selfMap[f.factor] = f.score }
        var partnerMap: [HarassmentFactor: Int] = [:]
        for f in cmp.partnerV.topFactors { partnerMap[f.factor] = f.score }
        let factors = Set(selfMap.keys).union(partnerMap.keys)
        var rows: [FactorRow] = []
        for f in factors {
            let s = selfMap[f] ?? 0
            let p = partnerMap[f] ?? 0
            let total = s + p
            guard total > 0 else { continue }
            let selfShare = Int((Double(s) / Double(total) * 100).rounded())
            rows.append(FactorRow(id: String(describing: f), name: f.displayName,
                                  explanation: f.explanationTemplate(), selfShare: selfShare, total: total))
        }
        return Array(rows.sorted { $0.total > $1.total }.prefix(6))
    }

    private func componentsCompareCard(_ cmp: Comparison) -> some View {
        let rows = factorCompareRows(cmp)
        return LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: String(localized: "毒性成分分析", bundle: LanguageManager.appBundle), en: String(localized: "TOXIC COMPONENTS  /  二人の割合", bundle: LanguageManager.appBundle))
                legendRow(cmp)
                Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                if rows.isEmpty {
                    Text("ヤバ成分は検出されませんでした。")
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(rows) { row in
                        compareBarRow(row)
                    }
                }
            }
        }
    }

    private func compareBarRow(_ row: FactorRow) -> some View {
        let isExpanded = expandedComponents.contains(row.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // タイトル末尾に下向き矢印を付けて「タップで開く」を示す
                HStack(spacing: 4) {
                    Text(row.name)
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                Spacer(minLength: 6)
                Text("\(row.selfShare)%").font(MeloFonts.monoMedium(12)).foregroundColor(selfColor)
                Text("/").font(MeloFonts.mono(11)).foregroundColor(MeloColors.Dark.textSecondary)
                Text("\(100 - row.selfShare)%").font(MeloFonts.monoMedium(12)).foregroundColor(partnerColor)
            }
            splitBar(selfShare: row.selfShare, height: 10)

            if isExpanded {
                Text(row.explanation)
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isExpanded { expandedComponents.remove(row.id) }
                else { expandedComponents.insert(row.id) }
            }
        }
    }

    // MARK: - ハラスメント分類（二人の割合）

    private func classificationCompareCard(_ cmp: Comparison) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: String(localized: "ハラスメント分類", bundle: LanguageManager.appBundle), en: String(localized: "CLASSIFICATION  /  二人の割合", bundle: LanguageManager.appBundle))
                legendRow(cmp)
                ForEach(HarassmentCategory.allCases, id: \.self) { cat in
                    classificationCompareRow(cmp, cat: cat)
                }
            }
        }
    }

    private func classificationCompareRow(_ cmp: Comparison, cat: HarassmentCategory) -> some View {
        let s = cmp.selfV.categoryScores[cat] ?? 0
        let p = cmp.partnerV.categoryScores[cat] ?? 0
        let total = s + p
        let selfShare = total > 0 ? Int((Double(s) / Double(total) * 100).rounded()) : 50
        let isExpanded = expandedCategories.contains(cat)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LabCategoryTag(code: cat.labCode, color: MeloColors.Dark.accent)
                // タイトル末尾に下向き矢印を付けて「タップで開く」を示す
                HStack(spacing: 4) {
                    Text(cat.displayName)
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                Spacer()
                if total > 0 {
                    Text("\(selfShare)%").font(MeloFonts.monoMedium(13)).foregroundColor(selfColor)
                    Text("/").font(MeloFonts.mono(11)).foregroundColor(MeloColors.Dark.textSecondary)
                    Text("\(100 - selfShare)%").font(MeloFonts.monoMedium(13)).foregroundColor(partnerColor)
                } else {
                    Text("—").font(MeloFonts.mono(12)).foregroundColor(MeloColors.Dark.textSecondary)
                }
            }
            if total > 0 {
                splitBar(selfShare: selfShare, height: 10)
            } else {
                Capsule().fill(MeloColors.Dark.track).frame(height: 10)
            }

            if isExpanded {
                Text(cat.explanation)
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isExpanded { expandedCategories.remove(cat) }
                else { expandedCategories.insert(cat) }
            }
        }
    }

    // MARK: - フォールバック（単独表示）

    // 鑑定結果（試験管メーター + 危険度 + 疑似バーコード）
    // 見た目の正本は再利用ビュー ToxicityVerdictCardView に集約（掲示板の毒性添付カードと共有）。
    private var verdictCard: some View {
        ToxicityVerdictCardView(result: result)
    }

    // 毒性成分分析（成分表シート + 濃度ドット）
    private var componentsCard: some View {
        LabCard {
            VStack(spacing: 12) {
                LabCardHeader(jp: String(localized: "毒性成分分析", bundle: LanguageManager.appBundle), en: "TOXIC COMPONENTS")
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
                LabCardHeader(jp: String(localized: "ハラスメント分類", bundle: LanguageManager.appBundle), en: "CLASSIFICATION")
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
    var selfName: String? = nil
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var selectedSpeaker: Int = 0

    // スコアカードと共通の固定カラー（自分 = ブルー / 相手 = ピンク）。
    // タブを切り替えると、その人の色にページのアクセントが変わる。
    private let selfColor = MeloColors.Dark.selfTint
    private let partnerColor = MeloColors.Dark.partnerTint

    /// 自分に当たる話者の index（特定できなければ先頭）。
    private var selfIndex: Int {
        let sn = (selfName?.isEmpty == false) ? selfName : UserPreferredName.resolve()
        if let sn, let i = result.speakerVerdicts.firstIndex(where: { $0.speakerName == sn }) {
            return i
        }
        return 0
    }

    private func speakerColor(_ index: Int) -> Color {
        index == selfIndex ? selfColor : partnerColor
    }

    var body: some View {
        let locked = !subscription.isSubscribed
        let verdicts = result.speakerVerdicts
        VStack(spacing: 16) {
            LabSectionTitle(jp: String(localized: "検体プロファイル", bundle: LanguageManager.appBundle), en: String(localized: "SPECIMEN PROFILE  /  各人ごとの毒性判定", bundle: LanguageManager.appBundle))

            if !verdicts.isEmpty {
                // 各人ごとのサブタブ（2 人以上のときだけセレクタを出す）
                if verdicts.count >= 2 {
                    speakerTabSelector(verdicts)
                }
                let idx = min(max(0, selectedSpeaker), verdicts.count - 1)
                let v = verdicts[idx]

                // 選択中の 1 人の分析ページ（その人の固定カラーで配色）
                speakerVerdictCard(verdict: v, accent: speakerColor(idx))
                if locked {
                    DiagnosisUnlockCTA(
                        source: "diag_type_lock",
                        message: String(localized: "この人の型の特性・カテゴリ別の強さを全部見る", bundle: LanguageManager.appBundle)
                    )
                }
                perPersonStructureCard(v, locked: locked)
                perPersonCategoryCard(v, locked: locked)
            } else {
                // フォールバック（話者を分離できない）: 会話全体の単独表示
                heroTypeCard
                if locked {
                    DiagnosisUnlockCTA(
                        source: "diag_type_lock",
                        message: String(localized: "型の特性・カテゴリ別の根拠まで全部見る", bundle: LanguageManager.appBundle)
                    )
                }
                structureCard(locked: locked)
                if !result.categoryBreakdowns.isEmpty {
                    categoryBreakdownsCard(locked: locked)
                }
            }
        }
    }

    // MARK: - 各人サブタブ

    private func speakerTabSelector(_ verdicts: [SpeakerVerdict]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(verdicts.enumerated()), id: \.element.id) { idx, v in
                let isSel = idx == min(max(0, selectedSpeaker), verdicts.count - 1)
                Button {
                    HapticManager.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSpeaker = idx
                    }
                } label: {
                    Text(speakerLabel(v))
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(isSel ? MeloColors.Dark.onAccent : MeloColors.Dark.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isSel ? speakerColor(idx) : MeloColors.Dark.bgElevated)
                                .overlay(
                                    Capsule().stroke(isSel ? Color.clear : speakerColor(idx).opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func speakerLabel(_ v: SpeakerVerdict) -> String {
        let sn = (selfName?.isEmpty == false) ? selfName : UserPreferredName.resolve()
        if let sn, v.speakerName == sn { return String(localized: "自分", bundle: LanguageManager.appBundle) }
        return v.speakerName
    }

    // MARK: - 各人の型の特性 / カテゴリ別

    private func perPersonStructureCard(_ verdict: SpeakerVerdict, locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 10) {
                LabCardHeader(jp: String(localized: "型の特性", bundle: LanguageManager.appBundle), en: "PROFILE")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verdict.primaryType.structureSummary)
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verdict.primaryType.darkHumorAdvice)
                            .font(MeloFonts.zenMaruRegular(13))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func perPersonCategoryCard(_ verdict: SpeakerVerdict, locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: String(localized: "カテゴリ別の強さ", bundle: LanguageManager.appBundle), en: "BREAKDOWN")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(HarassmentCategory.allCases, id: \.self) { cat in
                            perPersonCategoryRow(verdict, cat: cat)
                        }
                        if !verdict.topFactors.isEmpty {
                            Text(String(format: String(localized: "主な成分: %@", bundle: LanguageManager.appBundle), verdict.topFactors.prefix(4).map { "\($0.factor.displayName) \($0.score)%" }.joined(separator: " ・ ")))
                                .font(MeloFonts.mono(11))
                                .foregroundColor(MeloColors.Dark.textSecondary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func perPersonCategoryRow(_ verdict: SpeakerVerdict, cat: HarassmentCategory) -> some View {
        let score = verdict.categoryScores[cat] ?? 0
        let c = labSeverityColor(score)
        return VStack(alignment: .leading, spacing: 6) {
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

    private func speakerVerdictCard(verdict: SpeakerVerdict, accent: Color) -> some View {
        let color = accent
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
                                LabCodeChip(text: cat.shortName, color: color, filled: true)
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
                                LabCodeChip(text: "[\(p.phrase)] ×\(p.count)", color: color)
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

    private var heroTypeCard: some View {
        LabCard(hazardColor: result.riskLevel.labColor) {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: String(localized: "総合判定", bundle: LanguageManager.appBundle), en: "OVERALL")
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

    private func structureCard(locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 10) {
                LabCardHeader(jp: String(localized: "型の特性", bundle: LanguageManager.appBundle), en: "PROFILE")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(result.primaryType.structureSummary)
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(result.primaryType.darkHumorAdvice)
                            .font(MeloFonts.zenMaruRegular(13))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func categoryBreakdownsCard(locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: String(localized: "カテゴリ別の根拠", bundle: LanguageManager.appBundle), en: "BASIS")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(result.categoryBreakdowns) { breakdown in
                            breakdownRow(breakdown: breakdown)
                            if breakdown.id != result.categoryBreakdowns.last?.id {
                                Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                            }
                        }
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

// MARK: - DETECTION DETAIL（旧データタブ＝検出の内訳。スコアタブ下部に表示）

struct DiagnosisDetectionDetailTab: View {
    let result: DiagnosisResult
    @ObservedObject private var subscription = SubscriptionManager.shared

    var body: some View {
        let locked = !subscription.isSubscribed
        VStack(spacing: 16) {
            LabSectionTitle(jp: String(localized: "検出の内訳", bundle: LanguageManager.appBundle), en: String(localized: "DETECTION DETAIL  /  全発言スキャン結果", bundle: LanguageManager.appBundle))
            // 発生源比較までは無料。検査統計以降をプレミアム限定にする
            // （各カードはタイトルだけ見せて本文はぼかし）。
            speakerCompareCard(locked: false)
            if locked {
                DiagnosisUnlockCTA(
                    source: "diag_detection_lock",
                    message: String(localized: "検査統計・成分詳細・証拠サンプル・検出ログを全部見る", bundle: LanguageManager.appBundle)
                )
            }
            funStatsCard(locked: locked)
            if !result.factorDeepDives.isEmpty {
                factorDetailsCard(locked: locked)
            }
            quotesCard(locked: locked)
            allDetectionsLogCard(locked: locked)
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
    private func allDetectionsLogCard(locked: Bool) -> some View {
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
                LabCardHeader(jp: String(localized: "検出ログ", bundle: LanguageManager.appBundle), en: "DETECTION LOG")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 12) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(timestamp.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(LanguageManager.appLocale)))
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
    private func speakerCompareCard(locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: String(localized: "発生源比較", bundle: LanguageManager.appBundle), en: "SOURCE")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("両者の発言を全部スキャンしてます。お互いのヤバ発言の出方を比べてみてください。")
                            .font(MeloFonts.zenMaruRegular(11))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(result.stats.perSpeaker) { speaker in
                            speakerRow(speaker: speaker)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private func funStatsCard(locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 10) {
                LabCardHeader(jp: String(localized: "検査統計", bundle: LanguageManager.appBundle), en: "STATISTICS")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 10) {
                        statRow(label: String(localized: "総発言数", bundle: LanguageManager.appBundle), value: "\(result.stats.totalMessages)", color: MeloColors.Dark.textPrimary)
                        statRow(label: String(localized: "テキスト発言", bundle: LanguageManager.appBundle), value: "\(result.stats.totalTextMessages)", color: MeloColors.Dark.textPrimary)
                        statRow(label: String(localized: "ヤバ発言の割合", bundle: LanguageManager.appBundle), value: String(format: String(localized: "%1$lld%%", bundle: LanguageManager.appBundle), result.stats.detectionRatePercent), color: labSeverityColor(result.stats.detectionRatePercent))
                        statRow(label: String(localized: "検出された構成要素", bundle: LanguageManager.appBundle), value: String(format: String(localized: "%1$lld 件", bundle: LanguageManager.appBundle), result.stats.detectedFactorCount), color: MeloColors.Dark.accent)
                        if result.stats.nightDetectionCount > 0 {
                            statRow(label: String(localized: "深夜ヤバ発言", bundle: LanguageManager.appBundle), value: String(format: String(localized: "%1$lld 件", bundle: LanguageManager.appBundle), result.stats.nightDetectionCount), color: MeloColors.Dark.caution)
                        }
                        if let first = result.stats.firstDetectionAt {
                            statRow(label: String(localized: "最初のヤバ発言", bundle: LanguageManager.appBundle), value: first.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(LanguageManager.appLocale)), color: MeloColors.Dark.textSecondary)
                        }
                        if let last = result.stats.lastDetectionAt {
                            statRow(label: String(localized: "最新のヤバ発言", bundle: LanguageManager.appBundle), value: last.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(LanguageManager.appLocale)), color: MeloColors.Dark.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private func factorDetailsCard(locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: String(localized: "成分詳細", bundle: LanguageManager.appBundle), en: "COMPONENT DETAIL")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(result.factorDeepDives) { dive in
                            deepDiveRow(dive: dive)
                            if dive.id != result.factorDeepDives.last?.id {
                                Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                            }
                        }
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

    private func quotesCard(locked: Bool) -> some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: String(localized: "証拠サンプル", bundle: LanguageManager.appBundle), en: "EVIDENCE")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 14) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("\(quote.speakerName) · \(quote.timestamp.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(LanguageManager.appLocale)))")
                .font(MeloFonts.mono(9))
                .foregroundColor(MeloColors.Dark.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - DATA TAB（詳細鑑定データ）
// 親アプリ めろとーく の詳細データ分析（DetailedStatistics）をハラスメントークのトーンで表示。
// 診断パイプラインには未組込みなので、session から DetailedStatisticsAnalyzer をその場で実行する。

struct DiagnosisDataTab: View {
    let result: DiagnosisResult
    var session: ChatSession?

    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var stats: DetailedStatistics?
    @State private var didCompute = false

    private let selfColor = MeloColors.Dark.selfTint
    private let partnerColor = MeloColors.Dark.partnerTint

    var body: some View {
        let locked = !subscription.isSubscribed
        VStack(spacing: 16) {
            LabSectionTitle(jp: String(localized: "詳細鑑定データ", bundle: LanguageManager.appBundle), en: String(localized: "LAB DATA  /  トーク全体の振る舞い分析", bundle: LanguageManager.appBundle))
            if let s = stats {
                legend
                volumeBalanceSection(s)   // 1. 発言量の偏り（重力）— 無料
                languageSection(s)        // 2. 言葉の出方（様式）— 無料
                // 3 以降はプレミアム限定（セクション名は見せて本文だけぼかす）
                if locked {
                    DiagnosisUnlockCTA(
                        source: "diag_data_lock",
                        message: String(localized: "振る舞いの癖・よく使うフレーズまで全部見る", bundle: LanguageManager.appBundle)
                    )
                }
                funStatsSection(s, locked: locked)   // 3. 振る舞いの癖（向き合い）
                phrasesSection(s, locked: locked)    // 4. よく使うフレーズ（裏表）
            } else {
                loadingCard
            }
        }
        .onAppear(perform: computeIfNeeded)
    }

    // MARK: - 計算

    private func computeIfNeeded() {
        guard !didCompute else { return }
        didCompute = true
        // 診断時（解析中画面の裏）に計算済みなら即表示。再計算しない。
        if let pre = result.detailedStatistics {
            stats = pre
            return
        }
        // 旧データ等で未計算の場合のみ、バックグラウンドでフォールバック計算。
        guard let session else { return }
        // メインでは軽い値だけ取り出し、重い集計はバックグラウンドへ逃がす
        // （DetailedStatisticsAnalyzer をメインで同期実行すると、データタブを開いた
        //  瞬間に UI がブロックして「重い」状態になっていた）。集計中は loadingCard を表示。
        let messages = session.messages
        let names = session.participants.map(\.name)
        let selfN = (session.estimatedSelfName?.isEmpty == false) ? session.estimatedSelfName! : UserPreferredName.resolve()
        let partnerN = session.partnerName(selfName: selfN) ?? ""
        Task {
            let computed = await Task.detached(priority: .userInitiated) {
                DetailedStatisticsAnalyzer().analyze(
                    messages: messages,
                    selfName: selfN,
                    partnerName: partnerN,
                    allParticipantNames: names
                )
            }.value
            stats = computed
        }
    }

    private var loadingCard: some View {
        LabCard {
            VStack(spacing: 12) {
                ProgressView().tint(MeloColors.Dark.accent)
                Text("トーク全体を集計中…")
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Dark.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendChip(color: selfColor, label: String(localized: "自分", bundle: LanguageManager.appBundle))
            legendChip(color: partnerColor, label: String(localized: "相手", bundle: LanguageManager.appBundle))
            Spacer(minLength: 0)
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label).font(MeloFonts.zenMaruRegular(11)).foregroundColor(MeloColors.Dark.textSecondary)
        }
    }

    // MARK: - 1. 発言量の偏り（重力）— めろとーく interactionRatioContent + oneOnOneRatioCard 移植

    @ViewBuilder
    private func volumeBalanceSection(_ s: DetailedStatistics) -> some View {
        let patterns = s.actionsStatistics?.actionPatterns ?? []
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                LabCardHeader(jp: String(localized: "発言量の偏り", bundle: LanguageManager.appBundle), en: "VOLUME BALANCE")
                Text("やり取りのどこにどれだけ偏りがあるか。極端な比率は「一方的に詰める／黙らされる」の手がかり。")
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if patterns.isEmpty {
                    Text("この期間のデータはありません")
                        .font(MeloFonts.zenMaruRegular(12))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                } else {
                    ForEach(patterns) { pattern in
                        ratioCard(pattern)
                    }
                }
            }
        }
    }

    /// 自分↔相手の比率ドーナツ + % + 件数 + 一言コメント（めろとーく oneOnOneRatioCard）
    /// 行動タイプ → 日本語ラベル（ハラスメントトーン。String Catalog 経由だと英語化するため直マップ）。
    private func actionLabel(_ type: String) -> String {
        switch type {
        case "textMessage": return String(localized: "テキスト", bundle: LanguageManager.appBundle)
        case "sticker": return String(localized: "スタンプ", bundle: LanguageManager.appBundle)
        case "photo": return String(localized: "写真", bundle: LanguageManager.appBundle)
        case "video": return String(localized: "動画", bundle: LanguageManager.appBundle)
        case "call": return String(localized: "通話", bundle: LanguageManager.appBundle)
        case "question": return String(localized: "質問・詰問", bundle: LanguageManager.appBundle)
        case "proposal": return String(localized: "要求・指示", bundle: LanguageManager.appBundle)
        case "emotionalMessage": return String(localized: "感情ぶつけ", bundle: LanguageManager.appBundle)
        default: return type
        }
    }

    private func ratioCard(_ pattern: StoredActionPattern) -> some View {
        let total = pattern.totalCount
        let hasData = total > 0
        let selfPct = hasData ? Int((Double(pattern.selfCount) / Double(total) * 100).rounded()) : 0
        let partnerPct = hasData ? 100 - selfPct : 0
        let selfRatio = hasData ? CGFloat(pattern.selfCount) / CGFloat(total) : 0.5

        return VStack(spacing: 8) {
            // ヘッダー（種別 + 区切り線）
            VStack(spacing: 6) {
                Text(actionLabel(pattern.type))
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(MeloColors.Dark.divider)
                    .frame(height: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // 自分 % / ドーナツ / 相手 %
            HStack(spacing: 6) {
                ratioColumn(name: String(localized: "自分", bundle: LanguageManager.appBundle), pct: selfPct, count: pattern.selfCount, color: selfColor, hasData: hasData)
                ratioDonut(selfRatio: selfRatio, hasData: hasData)
                ratioColumn(name: String(localized: "相手", bundle: LanguageManager.appBundle), pct: partnerPct, count: pattern.partnerCount, color: partnerColor, hasData: hasData)
            }
            .padding(.horizontal, 18)

            // 一言コメント
            Text(hasData ? ratioComment(selfPct: selfPct) : String(localized: "この期間のデータはありません", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MeloColors.Dark.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                )
        )
    }

    private func ratioColumn(name: String, pct: Int, count: Int, color: Color, hasData: Bool) -> some View {
        VStack(spacing: 3) {
            Text(name)
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(MeloColors.Dark.textSecondary)
            Text(hasData ? "\(pct)%" : "—")
                .font(MeloFonts.anton(28))
                .foregroundColor(hasData ? color : MeloColors.Dark.textSecondary)
            Text("\(count)回")
                .font(MeloFonts.mono(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 自作ドーナツ（Charts 非依存）。self 比率ぶんだけ self 色でトリム。
    private func ratioDonut(selfRatio: CGFloat, hasData: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(hasData ? partnerColor.opacity(0.3) : MeloColors.Dark.track,
                        lineWidth: 8)
                .frame(width: 56, height: 56)
            if hasData {
                Circle()
                    .trim(from: 0, to: selfRatio)
                    .stroke(selfColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: -1, y: 1)
            }
        }
    }

    private func ratioComment(selfPct: Int) -> String {
        let diff = abs(selfPct - 50)
        if diff <= 5 {
            return String(localized: "ほぼ五分。釣り合いは取れている。", bundle: LanguageManager.appBundle)
        } else if diff <= 15 {
            return selfPct > 50 ? String(localized: "あなたの方がやや多め。", bundle: LanguageManager.appBundle) : String(localized: "相手の方がやや多め。", bundle: LanguageManager.appBundle)
        } else {
            return selfPct > 50 ? String(localized: "あなたが圧倒的に押している。", bundle: LanguageManager.appBundle) : String(localized: "相手に押し負けている。", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - 2. 言葉の出方（様式）— めろとーく languageTendencyCard + languageTendencyBar 移植

    private func languageSection(_ s: DetailedStatistics) -> some View {
        let t = s.textAnalysis
        let sc = t.selfCounts
        let pc = t.partnerCounts
        return LabCard {
            VStack(alignment: .leading, spacing: 8) {
                LabCardHeader(jp: String(localized: "言葉の出方", bundle: LanguageManager.appBundle), en: "LANGUAGE")
                Text("謝罪が一方に偏る・詰問（？）や強い言い切り（！）が多い、は圧の出やすいサイン。")
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                languageRow(String(localized: "🙏 謝罪の言葉", bundle: LanguageManager.appBundle), selfVal: sc?.apologyCount ?? 0, partnerVal: pc?.apologyCount ?? 0, totalFallback: t.apologyCount)
                languageRow(String(localized: "❓ 詰問（？）", bundle: LanguageManager.appBundle), selfVal: sc?.questionMarkCount ?? 0, partnerVal: pc?.questionMarkCount ?? 0, totalFallback: t.questionMarkCount)
                languageRow(String(localized: "❗ 言い切り（！）", bundle: LanguageManager.appBundle), selfVal: sc?.exclamationMarkCount ?? 0, partnerVal: pc?.exclamationMarkCount ?? 0, totalFallback: t.exclamationMarkCount)
                languageRow(String(localized: "💗 感謝", bundle: LanguageManager.appBundle), selfVal: sc?.thanksCount ?? 0, partnerVal: pc?.thanksCount ?? 0, totalFallback: t.thanksCount)
                languageRow(String(localized: "😄 笑い（w/草）", bundle: LanguageManager.appBundle), selfVal: sc?.totalLaughCount ?? 0, partnerVal: pc?.totalLaughCount ?? 0, totalFallback: t.totalLaughCount)
                languageRow(String(localized: "👋 挨拶", bundle: LanguageManager.appBundle), selfVal: sc?.greetingCount ?? 0, partnerVal: pc?.greetingCount ?? 0, totalFallback: t.greetingCount)
            }
        }
    }

    /// 二者バー: ラベル + 合計 + 自分／相手の積み上げ（めろとーく languageTendencyBar）
    private func languageRow(_ label: String, selfVal: Int, partnerVal: Int, totalFallback: Int) -> some View {
        let hasPerson = selfVal > 0 || partnerVal > 0
        let sVal = hasPerson ? selfVal : max(totalFallback / 2, 0)
        let pVal = hasPerson ? partnerVal : max(totalFallback - totalFallback / 2, 0)
        let total = hasPerson ? (sVal + pVal) : totalFallback

        return VStack(spacing: 5) {
            HStack {
                Text(label)
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Spacer()
                Text("合計\(total)回")
                    .font(MeloFonts.mono(11))
                    .foregroundColor(MeloColors.Dark.textSecondary)
            }

            twoPartyBar(selfVal: sVal, partnerVal: pVal)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func twoPartyBar(selfVal: Int, partnerVal: Int) -> some View {
        if selfVal == 0 && partnerVal == 0 {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(MeloColors.Dark.track)
                Text("0").font(MeloFonts.monoMedium(12)).foregroundColor(MeloColors.Dark.textSecondary)
            }
            .frame(height: 24)
        } else {
            GeometryReader { geo in
                let bothShown = selfVal > 0 && partnerVal > 0
                let gap: CGFloat = bothShown ? 2 : 0
                let available = geo.size.width - gap
                let denom = max(CGFloat(selfVal), 0.0001) + max(CGFloat(partnerVal), 0.0001)
                let selfW = available * max(CGFloat(selfVal), 0.0001) / denom
                HStack(spacing: gap) {
                    if selfVal > 0 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5).fill(selfColor)
                            Text("\(selfVal)").font(MeloFonts.monoMedium(13)).foregroundColor(MeloColors.Dark.onAccent)
                        }
                        .frame(width: partnerVal > 0 ? selfW : available, height: 24)
                    }
                    if partnerVal > 0 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5).fill(partnerColor)
                            Text("\(partnerVal)").font(MeloFonts.monoMedium(13)).foregroundColor(MeloColors.Dark.onAccent)
                        }
                        .frame(width: selfVal > 0 ? available - selfW : available, height: 24)
                    }
                }
            }
            .frame(height: 24)
        }
    }

    // MARK: - 3. 振る舞いの癖（向き合い）— めろとーく replySpeed / fastestReply / lateNight / readIgnore 移植

    private func funStatsSection(_ s: DetailedStatistics, locked: Bool) -> some View {
        let r = s.recordsStatistics
        let lateRate = r?.lateNightRate ?? 0
        let si = r?.estimatedSelfReadIgnore ?? 0
        let pi = r?.estimatedPartnerReadIgnore ?? 0
        return LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: String(localized: "振る舞いの癖", bundle: LanguageManager.appBundle), en: "BEHAVIOR")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("返信の速さの差・深夜の連絡・既読スルーの偏りは、追う／逃げるの非対称さを映す。")
                            .font(MeloFonts.zenMaruRegular(11))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // 最速返信タイム（自分 vs 相手）
                        funStatBlock(title: String(localized: "最速返信タイム", bundle: LanguageManager.appBundle)) {
                            versusRow(
                                selfText: formatReplyTime(r?.fastestSelfReply),
                                partnerText: formatReplyTime(r?.fastestPartnerReply)
                            )
                        }

                        // 深夜トーク率
                        funStatBlock(title: String(localized: "深夜トーク率（0-5時）", bundle: LanguageManager.appBundle)) {
                            VStack(spacing: 4) {
                                Text("\(Int((lateRate * 100).rounded()))%")
                                    .font(MeloFonts.anton(28))
                                    .foregroundColor(lateRate >= 0.20 ? MeloColors.Dark.danger : MeloColors.Dark.accent)
                                Text(lateNightComment(lateRate))
                                    .font(MeloFonts.zenMaruRegular(11))
                                    .foregroundColor(MeloColors.Dark.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // 既読スルー（推定）
                        funStatBlock(title: String(localized: "既読スルー（推定）", bundle: LanguageManager.appBundle)) {
                            if si + pi > 0 {
                                versusRow(selfText: String(format: String(localized: "%1$lld回", bundle: LanguageManager.appBundle), si), partnerText: String(format: String(localized: "%1$lld回", bundle: LanguageManager.appBundle), pi))
                            } else {
                                Text("ほぼ即レス。スルーは検出されず。")
                                    .font(MeloFonts.zenMaruRegular(12))
                                    .foregroundColor(MeloColors.Dark.textSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func funStatBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(MeloFonts.monoMedium(10))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MeloColors.Dark.bgElevated)
        )
    }

    /// 自分 vs 相手 の対比（めろとーく fastestReply1on1Content）
    private func versusRow(selfText: String, partnerText: String) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("自分").font(MeloFonts.zenMaruRegular(12)).foregroundColor(MeloColors.Dark.textSecondary)
                Text(selfText).font(MeloFonts.zenMaruMedium(18)).foregroundColor(selfColor)
            }
            .frame(maxWidth: .infinity)

            Text("vs").font(MeloFonts.mono(11)).foregroundColor(MeloColors.Dark.textSecondary)

            VStack(spacing: 4) {
                Text("相手").font(MeloFonts.zenMaruRegular(12)).foregroundColor(MeloColors.Dark.textSecondary)
                Text(partnerText).font(MeloFonts.zenMaruMedium(18)).foregroundColor(partnerColor)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func lateNightComment(_ rate: Double) -> String {
        switch rate {
        case 0..<0.03: return String(localized: "健全な生活リズム", bundle: LanguageManager.appBundle)
        case 0.03..<0.10: return String(localized: "たまに夜更かし", bundle: LanguageManager.appBundle)
        case 0.10..<0.20: return String(localized: "夜型コンビ", bundle: LanguageManager.appBundle)
        default: return String(localized: "完全に夜行性", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - 4. よく使うフレーズ（裏表）— めろとーく frequentPhrasesContent + phraseBlock 移植

    private func phrasesSection(_ s: DetailedStatistics, locked: Bool) -> some View {
        let p = s.phraseAnalysis
        return LabCard {
            VStack(alignment: .leading, spacing: 14) {
                LabCardHeader(jp: String(localized: "よく使うフレーズ", bundle: LanguageManager.appBundle), en: "SIGNATURE PHRASES")
                LockedBody(locked: locked) {
                    VStack(alignment: .leading, spacing: 14) {
                        phraseBlock(title: String(localized: "あなたがよく使う", bundle: LanguageManager.appBundle), phrases: p.selfTopPhrases, color: selfColor)
                        phraseBlock(title: String(localized: "相手がよく使う", bundle: LanguageManager.appBundle), phrases: p.partnerTopPhrases, color: partnerColor)
                        if !p.commonPhrases.isEmpty {
                            Rectangle().fill(MeloColors.Dark.divider).frame(height: 1)
                            phraseBlock(title: String(localized: "ふたりの共通フレーズ", bundle: LanguageManager.appBundle), phrases: p.commonPhrases, color: MeloColors.Dark.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func phraseBlock(title: String, phrases: [PhraseCount], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MeloFonts.monoMedium(10))
                .foregroundColor(MeloColors.Dark.textSecondary)
            if phrases.isEmpty {
                Text("データがありません")
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Dark.textSecondary)
            } else {
                PhraseFlowLayout(spacing: 6) {
                    ForEach(phrases) { pc in
                        LabCodeChip(text: "\(pc.phrase) ×\(pc.count)", color: color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 共通ヘルパー

    private func formatReplyTime(_ interval: TimeInterval?) -> String {
        guard let interval = interval else { return "—" }
        let seconds = Int(interval)
        if seconds < 60 { return String(format: String(localized: "%1$lld秒", bundle: LanguageManager.appBundle), seconds) }
        let m = seconds / 60, s = seconds % 60
        if m < 60 { return s == 0 ? String(format: String(localized: "%1$lld分", bundle: LanguageManager.appBundle), m) : String(format: String(localized: "%1$lld分%2$lld秒", bundle: LanguageManager.appBundle), m, s) }
        let h = m / 60, mm = m % 60
        return mm > 0 ? String(format: String(localized: "%1$lld時間%2$lld分", bundle: LanguageManager.appBundle), h, mm) : String(format: String(localized: "%1$lld時間", bundle: LanguageManager.appBundle), h)
    }
}

// MARK: - SUMMARY TAB (AI 月別ハラスメント鑑定)
// 親アプリ めろとーく の月別 AI サマリーをハラスメントーク版に移植。
// 文脈からハラスメント傾向を AI 鑑定し、該当発言を抜粋して月単位でまとめる。
// 無料は直近 3 ヶ月のみ生成、全期間はサブスク。

@MainActor
final class HarassmentSummaryViewModel: ObservableObject {
    @Published private(set) var summaryState: SummaryState = .idle
    @Published private(set) var monthlySummaries: [MonthlySummary] = []
    /// 課金後に「残りの月だけ」追加生成している最中かどうか（既存サマリーは残したまま）。
    @Published private(set) var isGeneratingMore = false

    let result: DiagnosisResult
    private var session: ChatSession?
    private let gemini = GeminiService.shared
    let freeMaxMonths = 3
    private var didLoadCache = false

    init(result: DiagnosisResult, session: ChatSession?) {
        self.result = result
        self.session = session
    }

    var disclaimer: String { result.disclaimer }

    /// セッション内の総月数（ロック表示の算出用）。
    var totalMonthCount: Int {
        guard let session else { return monthlySummaries.count }
        return Set(session.messages.compactMap { monthKey(for: $0.timestamp) }).count
    }

    /// 非課金で隠れている月数。
    var lockedMonthCount: Int {
        guard !SubscriptionManager.shared.isSubscribed else { return 0 }
        return max(0, totalMonthCount - freeMaxMonths)
    }

    /// 既に鑑定済みの月キー（"YYYY-MM"）。
    private var generatedKeys: Set<String> {
        Set(monthlySummaries.map { String(format: "%04d-%02d", $0.year, $0.month) })
    }

    /// いま閲覧できる範囲（課金=全期間 / 無料=直近 freeMaxMonths）のうち、まだ鑑定していない月数。
    /// 課金して全期間が解放されたのに残りが未生成のとき「残りも鑑定する」導線を出すために使う。
    var pendingMonthCount: Int {
        guard let session, !session.messages.isEmpty else { return 0 }
        let allKeys = Set(session.messages.compactMap { monthKey(for: $0.timestamp) })
        let visible: Set<String> = SubscriptionManager.shared.isSubscribed
            ? allKeys
            : Set(allKeys.sorted(by: >).prefix(freeMaxMonths))
        return visible.subtracting(generatedKeys).count
    }

    func onAppear() {
        guard !didLoadCache else { return }
        didLoadCache = true
        loadCachedSummaries()
    }

    func generate() async {
        guard GeminiConsentView.hasAgreed(for: .consultation) else {
            summaryState = .error(String(localized: "利用規約に同意してください", bundle: LanguageManager.appBundle))
            return
        }
        // 履歴から結果を再オープンすると messages 空のプレースホルダー session が渡る
        // （NewHomeView.historyRow）。session が nil または空なら SwiftData の
        // StoredChatSession から本物のトーク履歴を読み直す。これをしないと groups が空になり、
        // AI を一度も呼ばずに .loaded([]) になって「押しても何も起きない」状態になる。
        if session == nil || (session?.messages.isEmpty ?? true) { loadSessionFromStore() }
        guard let session, !session.messages.isEmpty else {
            summaryState = .error(String(localized: "トーク履歴を再インポートしてください", bundle: LanguageManager.appBundle))
            return
        }

        summaryState = .loading
        monthlySummaries = []

        let groups = groupMessagesByMonth(session.messages)
        var orderedKeys = groups.keys.sorted(by: >) // 新しい月から
        let subscribed = SubscriptionManager.shared.isSubscribed
        if !subscribed { orderedKeys = Array(orderedKeys.prefix(freeMaxMonths)) }

        let selfName = session.participants.first?.name ?? ""
        let partnerName = session.participants.dropFirst().first?.name ?? ""
        let lang = ChatLanguage.from(appLanguage: LanguageManager.shared.currentLanguage)

        var summaries: [MonthlySummary] = []
        do {
            for key in orderedKeys {
                guard let msgs = groups[key], let ym = parseKey(key) else { continue }
                let label = yearMonthLabel(year: ym.0, month: ym.1, language: lang)
                let text = try await gemini.generateHarassmentSummary(
                    messages: msgs,
                    selfName: selfName,
                    partnerName: partnerName,
                    yearMonth: label,
                    language: lang
                )
                summaries.append(MonthlySummary(year: ym.0, month: ym.1, summary: text, messageCount: msgs.count))
            }
            monthlySummaries = summaries.sorted { $0.sortKey > $1.sortKey }
            summaryState = .loaded(monthlySummaries)
            AnalyticsManager.shared.track("harassment_summary_generated", properties: ["months": summaries.count, "subscribed": subscribed])
            persist(summaries)
        } catch {
            summaryState = .error(error.localizedDescription)
            AnalyticsManager.shared.track("harassment_summary_error")
        }
    }

    /// 既存サマリーは残したまま、まだ鑑定していない月だけを追加生成する。
    /// 無料3ヶ月分を生成済みのユーザーが課金して戻ってきたとき、残り月を埋めるのに使う
    /// （全月をやり直さないので AI の無駄打ち・画面のちらつきを避けられる）。
    func generateMissing() async {
        guard !isGeneratingMore else { return }
        guard GeminiConsentView.hasAgreed(for: .consultation) else {
            summaryState = .error(String(localized: "利用規約に同意してください", bundle: LanguageManager.appBundle))
            return
        }
        if session == nil || (session?.messages.isEmpty ?? true) { loadSessionFromStore() }
        guard let session, !session.messages.isEmpty else {
            summaryState = .error(String(localized: "トーク履歴を再インポートしてください", bundle: LanguageManager.appBundle))
            return
        }

        let groups = groupMessagesByMonth(session.messages)
        var orderedKeys = groups.keys.sorted(by: >)
        let subscribed = SubscriptionManager.shared.isSubscribed
        if !subscribed { orderedKeys = Array(orderedKeys.prefix(freeMaxMonths)) }
        let done = generatedKeys
        let missing = orderedKeys.filter { !done.contains($0) }
        guard !missing.isEmpty else { return }

        let selfName = session.participants.first?.name ?? ""
        let partnerName = session.participants.dropFirst().first?.name ?? ""
        let lang = ChatLanguage.from(appLanguage: LanguageManager.shared.currentLanguage)

        isGeneratingMore = true
        defer { isGeneratingMore = false }
        do {
            for key in missing {
                guard let msgs = groups[key], let ym = parseKey(key) else { continue }
                let label = yearMonthLabel(year: ym.0, month: ym.1, language: lang)
                let text = try await gemini.generateHarassmentSummary(
                    messages: msgs,
                    selfName: selfName,
                    partnerName: partnerName,
                    yearMonth: label,
                    language: lang
                )
                let new = MonthlySummary(year: ym.0, month: ym.1, summary: text, messageCount: msgs.count)
                // 1 ヶ月できるたびに反映（リストに次々追加されていく）。
                monthlySummaries = (monthlySummaries + [new]).sorted { $0.sortKey > $1.sortKey }
                summaryState = .loaded(monthlySummaries)
            }
            AnalyticsManager.shared.track("harassment_summary_generated", properties: ["months": monthlySummaries.count, "subscribed": subscribed, "incremental": true])
            persist(monthlySummaries)
        } catch {
            // 途中で失敗しても、ここまで生成できた分は残す（次回また残りを足せる）。
            persist(monthlySummaries)
            summaryState = .loaded(monthlySummaries)
            AnalyticsManager.shared.track("harassment_summary_error")
        }
    }

    // MARK: - Helpers

    private func monthKey(for date: Date) -> String? {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        guard let y = c.year, let m = c.month else { return nil }
        return String(format: "%04d-%02d", y, m)
    }

    private func parseKey(_ key: String) -> (Int, Int)? {
        let p = key.split(separator: "-")
        guard p.count == 2, let y = Int(p[0]), let m = Int(p[1]) else { return nil }
        return (y, m)
    }

    private func groupMessagesByMonth(_ messages: [ChatMessage]) -> [String: [ChatMessage]] {
        var groups: [String: [ChatMessage]] = [:]
        for m in messages where m.eventType.isTextBased {
            guard let key = monthKey(for: m.timestamp) else { continue }
            groups[key, default: []].append(m)
        }
        return groups
    }

    private func yearMonthLabel(year: Int, month: Int, language: ChatLanguage) -> String {
        switch language {
        case .japanese, .chinese: return "\(year)年\(month)月"
        case .korean: return "\(year)년 \(month)월"
        default: return "\(year)/\(month)"
        }
    }

    // MARK: - Persistence (best-effort: StoredChatSession が在れば月別サマリーをキャッシュ)

    private func loadCachedSummaries() {
        let ctx = SwiftDataContainer.shared.container.mainContext
        let sessionId = result.sessionId
        let descriptor = FetchDescriptor<StoredChatSession>(predicate: #Predicate { $0.id == sessionId })
        guard let stored = try? ctx.fetch(descriptor).first,
              let cached = stored.monthlySummaries, !cached.isEmpty else { return }
        let mapped = cached
            .map { MonthlySummary(year: $0.year, month: $0.month, summary: $0.summary, messageCount: $0.messageCount, generatedAt: $0.generatedAt) }
            .sorted { $0.sortKey > $1.sortKey }
        monthlySummaries = mapped
        summaryState = .loaded(mapped)
    }

    private func persist(_ summaries: [MonthlySummary]) {
        let ctx = SwiftDataContainer.shared.container.mainContext
        let sessionId = result.sessionId
        let descriptor = FetchDescriptor<StoredChatSession>(predicate: #Predicate { $0.id == sessionId })
        guard let stored = try? ctx.fetch(descriptor).first else { return }
        for existing in stored.monthlySummaries ?? [] { ctx.delete(existing) }
        for s in summaries {
            let row = StoredMonthlySummary(year: s.year, month: s.month, summary: s.summary, messageCount: s.messageCount)
            row.session = stored
            ctx.insert(row)
        }
        try? ctx.save()
    }

    private func loadSessionFromStore() {
        let ctx = SwiftDataContainer.shared.container.mainContext
        let sessionId = result.sessionId
        let descriptor = FetchDescriptor<StoredChatSession>(predicate: #Predicate { $0.id == sessionId })
        guard let stored = try? ctx.fetch(descriptor).first,
              let data = stored.chatSessionData,
              let loaded = try? JSONDecoder().decode(ChatSession.self, from: data) else { return }
        session = loaded
    }
}

struct HarassmentSummaryTabView: View {
    @ObservedObject var viewModel: HarassmentSummaryViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var expandedMonths: Set<UUID> = []
    @State private var showGeminiConsent = false

    var body: some View {
        VStack(spacing: 16) {
            LabSectionTitle(jp: String(localized: "AI 月別鑑定", bundle: LanguageManager.appBundle), en: String(localized: "MONTHLY AI REPORT  /  月ごとのハラスメント傾向", bundle: LanguageManager.appBundle))

            switch viewModel.summaryState {
            case .idle:
                generatePromptCard
            case .loading:
                loadingCard
            case .loaded(let summaries):
                summariesList(summaries)
            case .error(let message):
                errorCard(message)
            }

            disclaimerPanel
        }
        .sheet(isPresented: $showGeminiConsent) {
            GeminiConsentView {
                Task { await viewModel.generate() }
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - States

    private var generatePromptCard: some View {
        LabCard {
            VStack(spacing: 14) {
                MascotImage(name: LabMascot.pose(for: .summary), size: 120)

                Text("AIが月ごとのハラスメント傾向を\n文脈から鑑定して、気になった発言を\n抜粋してまとめます。")
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    HapticManager.medium()
                    requestGeneration()
                } label: {
                    Text("鑑定をはじめる")
                        .font(MeloFonts.zenMaru(18))
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(MeloColors.Dark.accentGradient))
                }
                .buttonStyle(.plain)

                if !subscription.isSubscribed {
                    Text("無料プランは直近 \(viewModel.freeMaxMonths) ヶ月分まで鑑定できます。全期間はプレミアムで。")
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Google Gemini AI を使用します。トーク履歴の一部（メッセージ本文・送信者名・送信日時）が Google LLC に送信されます。")
                    .font(MeloFonts.mono(9))
                    .foregroundColor(MeloColors.Dark.textSecondary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var loadingCard: some View {
        LabCard {
            VStack(spacing: 14) {
                MascotImage(name: LabMascot.pose(for: .summary), size: 96)
                ProgressView()
                    .tint(MeloColors.Dark.accent)
                Text("AI が月ごとに鑑定中…\n少し時間がかかります")
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private func summariesList(_ summaries: [MonthlySummary]) -> some View {
        let sorted = summaries.sorted { $0.sortKey > $1.sortKey }
        return VStack(spacing: 16) {
            ForEach(sorted) { summary in
                monthlyCard(summary)
            }
            if viewModel.lockedMonthCount > 0 {
                // 非課金：まだロックされている月がある → 解除 CTA
                lockedCard(viewModel.lockedMonthCount)
            } else if viewModel.isGeneratingMore || viewModel.pendingMonthCount > 0 {
                // 課金済みで未生成の月が残っている → 残りを追加生成する導線
                generateMoreCard(viewModel.pendingMonthCount)
            }
            // 再生成（全月やり直し）
            Button {
                HapticManager.light()
                requestGeneration()
            } label: {
                Text("もう一度鑑定する")
                    .font(MeloFonts.zenMaruMedium(13))
                    .foregroundColor(MeloColors.Dark.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func monthlyCard(_ summary: MonthlySummary) -> some View {
        let isExpanded = expandedMonths.contains(summary.id)
        return LabCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text(summary.displayYearMonth)
                        .font(MeloFonts.zenMaru(15))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                    Text("\(summary.messageCount)")
                        .font(MeloFonts.anton(20))
                        .foregroundColor(MeloColors.Dark.accent)
                    Text("件")
                        .font(MeloFonts.mono(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MeloColors.Dark.accent)
                }
                .padding(.vertical, 2)

                if isExpanded {
                    Rectangle().fill(MeloColors.Dark.cardStroke).frame(height: 1)
                        .padding(.vertical, 12)
                    Text(summary.summary)
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded { expandedMonths.remove(summary.id) }
                    else { expandedMonths.insert(summary.id) }
                }
            }
        }
    }

    private func lockedCard(_ hiddenCount: Int) -> some View {
        LabCard {
            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30))
                    .foregroundColor(MeloColors.Dark.accent)
                Text("プレミアムで、残り \(hiddenCount) ヶ月分の\n月別鑑定をすべて見れます")
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    HapticManager.medium()
                    coordinator.subscriptionSource = "summary_tab_lock"
                    coordinator.showingSubscription = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill").font(.system(size: 13))
                        Text("全期間のロックを解除")
                            .font(MeloFonts.zenMaruMedium(14))
                    }
                    .foregroundColor(MeloColors.Dark.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(MeloColors.Dark.accentGradient))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    /// 課金して全期間が解放されたあと、残りの月を追加鑑定するカード。
    /// 生成中はその場で進捗を出し、既存のサマリーは消さない。
    private func generateMoreCard(_ count: Int) -> some View {
        LabCard {
            VStack(spacing: 12) {
                if viewModel.isGeneratingMore {
                    ProgressView()
                        .tint(MeloColors.Dark.accent)
                    Text("残りの月を鑑定中…\n少し時間がかかります")
                        .font(MeloFonts.zenMaruRegular(13))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24))
                        .foregroundColor(MeloColors.Dark.accent)
                    Text("プレミアム特典：残り \(count) ヶ月分も鑑定できます")
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        HapticManager.medium()
                        requestGenerateMore()
                    } label: {
                        Text("残り \(count) ヶ月も鑑定する")
                            .font(MeloFonts.zenMaru(16))
                            .foregroundColor(MeloColors.Dark.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(MeloColors.Dark.accentGradient))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func errorCard(_ message: String) -> some View {
        LabCard {
            VStack(spacing: 12) {
                MascotImage(name: LabMascot.pose(for: .summary), size: 88)
                Text("鑑定に失敗しました")
                    .font(MeloFonts.zenMaru(16))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Text(message)
                    .font(MeloFonts.zenMaruRegular(12))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    HapticManager.light()
                    requestGeneration()
                } label: {
                    Text("再試行")
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(MeloColors.Dark.accentGradient))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var disclaimerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISCLAIMER")
                .font(MeloFonts.monoMedium(9))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .tracking(1)
            Text(viewModel.disclaimer)
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

    // MARK: - Helpers

    private func requestGeneration() {
        if GeminiConsentView.hasAgreed(for: .consultation) {
            Task { await viewModel.generate() }
        } else {
            showGeminiConsent = true
        }
    }

    /// 残りの月だけを追加生成する（既存サマリーは消さない）。
    private func requestGenerateMore() {
        if GeminiConsentView.hasAgreed(for: .consultation) {
            Task { await viewModel.generateMissing() }
        } else {
            showGeminiConsent = true
        }
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
    case .low: return String(localized: "弱", bundle: LanguageManager.appBundle)
    case .medium: return String(localized: "中", bundle: LanguageManager.appBundle)
    case .high: return String(localized: "強", bundle: LanguageManager.appBundle)
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
