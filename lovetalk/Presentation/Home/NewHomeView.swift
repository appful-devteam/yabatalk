import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - NewHomeView
// Figma: https://www.figma.com/design/wu7aHSOOgv9yi9phZWRVBo?node-id=643-490
//
// 診断するタブ（中央タブ）のルート画面。
//   1. ピンクヘッダー（めろとーくピル + タイトル）
//   2. LINE相性診断CTAカード（タップで showImport）
//   3. めろまる wave キャラ + 2つの円形ボタン
//      - 上: めろまるに相談 → 最新診断結果の PersonaChat へ
//      - 下: 擬似チャット → selectedTab を .personaChat へ切り替え
//   4. ピンクの分離線
//   5. 最近の診断 カード（履歴を最大5件表示 → タップで結果画面へ）
//
// 既存の診断フロー（Import → Analyzing → Result）は一切変更しない。

// MARK: - Design Tokens
private enum NewHomeTokens {
    static let brandPink = MeloColors.Dark.accent
    static let textDark = MeloColors.Dark.textPrimary
    static let textMuted = MeloColors.Dark.textSecondary
    static let textGrey = MeloColors.Dark.textSecondary
    static let cardBorder = MeloColors.Dark.accent
    static let pinkShadow = MeloColors.Dark.accent.opacity(0.25)

    /// ピンクスターダスト背景画像（後でダーク用アセットに差し替え予定）
    static let backgroundImageName = "bg_diagnose_stardust"
    static let backgroundOpacity: Double = 0.12
}

// MARK: - Diagnose Page Background
/// 診断ページ・結果ページ・診断中ページで共通利用するピンクスターダスト背景。
/// 画像を 30% 透明度で表示し、下に淡いピンクの単色を敷く。
struct DiagnoseStardustBackground: View {
    var body: some View {
        ZStack {
            MeloColors.Dark.bg
            Image("bg_diagnose_stardust")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.12)
        }
        .ignoresSafeArea()
    }
}

// MARK: - NewHomeView
struct NewHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var dailyLimitManager = DailyLimitManager.shared
    @StateObject private var rewardedAdManager = RewardedAdManager.shared
    @StateObject private var fileImportManager = FileImportManager.shared
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \StoredAnalysisResult.analyzedAt, order: .reverse)
    private var analysisHistory: [StoredAnalysisResult]

    @State private var showLimitAlert = false
    @State private var pendingImportURL: URL?
    @State private var showSubscription = false
    @State private var showNoResultAlert = false

    /// めろまるをタップする度にインクリメント。MeromaruAnimatedImage がこれを
    /// 監視してタップバウンスを発火する。
    @State private var meromaruTapCount = 0

    // MARK: - Consultation Flow State
    @State private var showPartnerPicker = false
    @State private var showGeminiConsent = false
    /// 相談機能の初回タップ時に呼び名を聞くポップアップ。1 回だけ表示。
    @State private var showPreferredNamePrompt = false
    /// 呼び名ポップアップを閉じた後に partnerPicker を続けて開くためのフラグ。
    /// .sheet → .sheet を直接連鎖できないので、onDismiss 経由で遷移する。
    @State private var pendingShowPartnerPicker = false
    @AppStorage(Constants.StorageKeys.hasSeenPreferredNamePrompt) private var hasSeenPreferredNamePrompt = false
    @State private var pendingConsultationResult: StoredAnalysisResult?
    /// 相談チャット用の VM を保持する Identifiable wrapper。
    /// `fullScreenCover(item:)` でこの値の有無に応じて画面提示する。
    /// 旧来の `Bool + Optional<VM>` 二段管理は、SwiftUI が `Bool` の変化を先に観測して
    /// カバーが空コンテンツで提示される race を引き起こし、画面が白く見えるバグの原因だった。
    @State private var consultationPresentation: ConsultationPresentation?
    /// Picker 選択 → 親 sheet の onDismiss で本処理を実行するための一時保持。
    /// (sheet 遷移が完了する前に fullScreenCover を出すと iOS が無視するため、
    /// 必ず onDismiss を経由させる)
    @State private var pendingPickerSelection: StoredAnalysisResult?
    @State private var pendingPickerWantsGeneral = false

    // MARK: - History Delete State
    @State private var pendingDeleteResult: StoredAnalysisResult?
    @State private var showDeleteConfirmation = false

    // MARK: - Usage Guide Prompt
    /// 「使い方はわかりますか？」ポップアップを今後表示しないかどうか (UserDefaults 永続化)。
    @AppStorage(Constants.StorageKeys.suppressUsageGuidePrompt) private var suppressUsageGuidePrompt = false
    /// 診断 CTA / ファイルを開く タップ時に表示するポップアップ。
    @State private var showUsageGuidePrompt = false
    /// 「今後表示しない」のローカルチェック状態 (ポップアップ閉じ時に永続化に反映)。
    @State private var promptDontShowAgain = false
    /// 現在ポップアップを呼び出した発火元アクション (見ない / 外側タップ → そのまま実行する)。
    private enum UsageGuidePromptSource {
        case ctaCard       // 「LINE相性診断」CTA カード → openLineForExport
        case fileOpen      // 「ファイルを開く」小ボタン → viewModel.isImporting = true
    }
    @State private var usageGuidePromptSource: UsageGuidePromptSource? = nil

    var body: some View {
        ZStack {
            DiagnoseStardustBackground()

            VStack(spacing: 0) {
                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // ヒーロー: 大きい手振りめろまる + 左サイドメニュー
                        heroSection
                            .padding(.top, 4)

                        // CTA バナー (ピンクグラデの細長ピル)
                        ctaBanner
                            .padding(.horizontal, 32)

                        // 履歴セクション (白オーバーレイ + 行)
                        historyCard
                            .padding(.horizontal, 32)
                            .padding(.bottom, 120)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: FileImportService.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveFileFromShare)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                handleSharedFile(url: url)
            }
        }
        .onAppear {
            if fileImportManager.hasPendingFile, let url = fileImportManager.pendingFileURL {
                handleSharedFile(url: url)
            }
        }
        .alert(String(localized: "エラー", bundle: LanguageManager.appBundle), isPresented: $viewModel.showingError) {
            Button(String(localized: "OK", bundle: LanguageManager.appBundle)) { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? String(localized: "不明なエラー", bundle: LanguageManager.appBundle))
        }
        .alert(String(localized: "診断結果が必要です", bundle: LanguageManager.appBundle), isPresented: $showNoResultAlert) {
            Button(String(localized: "診断をはじめる", bundle: LanguageManager.appBundle)) {
                coordinator.showImport()
            }
            Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
        } message: {
            Text(String(localized: "めろまるに相談するには、まずLINEのトーク履歴を診断してください。", bundle: LanguageManager.appBundle))
        }
        .alert(String(localized: "診断履歴を削除しますか？", bundle: LanguageManager.appBundle), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "削除", bundle: LanguageManager.appBundle), role: .destructive) {
                if let result = pendingDeleteResult {
                    performDeleteHistory(result)
                }
                pendingDeleteResult = nil
            }
            Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {
                pendingDeleteResult = nil
            }
        } message: {
            Text(String(localized: "この診断結果を削除します。元に戻すことはできません。", bundle: LanguageManager.appBundle))
        }
        .sheet(isPresented: $showSubscription, onDismiss: {
            if let url = pendingImportURL, subscriptionManager.isSubscribed {
                pendingImportURL = nil
                processImportURL(url)
            }
        }) {
            SubscriptionView(source: "diagnose_home")
        }
        // 相談機能のタップ時に表示する呼び名入力ポップアップ。
        // 名前が実際に保存された時 (UserPreferredName.stored が non-nil) だけ「見た」フラグを立てる。
        // 「あとで」やスワイプで閉じた場合はフラグを立てず、次回相談タップでまた再表示される。
        .sheet(isPresented: $showPreferredNamePrompt, onDismiss: {
            if UserPreferredName.stored != nil {
                hasSeenPreferredNamePrompt = true
            }
            if pendingShowPartnerPicker {
                pendingShowPartnerPicker = false
                showPartnerPicker = true
            }
        }) {
            PreferredNamePromptView {
                showPreferredNamePrompt = false
            }
            .presentationDetents([.medium, .large])
        }
        // めろまるに相談: 相手選択
        // sheet が完全に dismiss してから次の遷移 (consent / chat) を発火する。
        // .sheet 中に fullScreenCover をセットすると iOS が無視することがあるため、
        // onDismiss で確実に処理する。
        .sheet(isPresented: $showPartnerPicker, onDismiss: {
            if let pending = pendingPickerSelection {
                pendingPickerSelection = nil
                startConsultation(with: pending)
            } else if pendingPickerWantsGeneral {
                pendingPickerWantsGeneral = false
                startGeneralConsultation()
            }
        }) {
            ConsultationPartnerPickerView(
                onSelect: { selected in
                    pendingPickerSelection = selected
                    pendingPickerWantsGeneral = false
                    showPartnerPicker = false
                },
                onSelectGeneral: {
                    pendingPickerSelection = nil
                    pendingPickerWantsGeneral = true
                    showPartnerPicker = false
                }
            )
        }
        // Gemini 同意シート (consultation)
        .sheet(isPresented: $showGeminiConsent) {
            GeminiConsentView(featureType: .consultation) {
                if let stored = pendingConsultationResult {
                    presentConsultationChat(for: stored)
                }
            }
        }
        // 相談チャット本体 (fullScreenCover で没入体験)
        // 戻るボタンでホーム画面へ直接戻る (相手選択画面は自動表示しない)。
        // `item:` 形式: VM の生成と提示を1つの state 更新でアトミックに行う
        // (`Bool + Optional<VM>` 二段管理だと race で白画面になるため)。
        .fullScreenCover(item: $consultationPresentation, onDismiss: {
            pendingConsultationResult = nil
        }) { presentation in
            ConsultationChatView(viewModel: presentation.viewModel)
        }
        .overlay {
            if viewModel.isLoading { loadingOverlay }
        }
        .overlay {
            if showLimitAlert { limitReachedPopup }
        }
        .overlay {
            if showUsageGuidePrompt { usageGuidePromptPopup }
        }
    }

    // MARK: - Header (Figma 724:881: タイトル + 設定 + Premium / 透明背景)
    /// 他ページと padding 16pt を揃えつつ、長いタイトルのオーバーフローを完全防止する。
    /// 右側ボタン群 (settings 32 + spacing 8 + Premium ~100 = 140pt + spacing 8 = 148pt) を
    /// 確保するため、タイトルに与える幅は端末幅から padding と右側固定幅を引いた残り。
    /// 18pt ベースの一回り小さいフォントにすることで、長文でも自然に収まる。
    // MARK: - Header (Figma 724:881: タイトル + 設定 + Premium / 透明背景)
    /// タイトル + 右側ボタンを Spacer で広げず、密にまとめて配置。
    /// 左右の padding を広めに取り、見た目の余白を確保する方式。
    private var headerSection: some View {
        HStack(spacing: 6) {
            Text(String(localized: "ハラスメント診断", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(20))
                .tracking(0.6)
                .foregroundStyle(MeloColors.Dark.accentGradient)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            settingsButton
            PremiumBadgeButton(source: "premium_badge_diagnose") {
                HapticManager.light()
                coordinator.subscriptionSource = "premium_badge_diagnose"
                coordinator.showingSubscription = true
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: - Settings Button (Diagnose tab header) — ピンクグラデ + 白アイコン
    private var settingsButton: some View {
        Button {
            HapticManager.light()
            AnalyticsManager.shared.track("settings_open_from_diagnose_header")
            coordinator.showingSettings = true
        } label: {
            ZStack {
                Circle()
                    .fill(MeloColors.Dark.accentGradient)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MeloColors.Dark.onAccent)
            }
            .frame(width: PremiumBadgeButton.height, height: PremiumBadgeButton.height)
            .shadow(color: MeloColors.Dark.accent.opacity(0.25), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "設定", bundle: LanguageManager.appBundle)))
        .accessibilityIdentifier("settings_button_diagnose")
    }

    // MARK: - Hero Section (Figma 724:881: 大きい手振りめろまる + 左サイドメニュー)
    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            // めろまる + 周りのキラキラ星 + タップ誘導の吹き出し
            ZStack {
                // 後ろのキラキラ星アニメーション
                MeromaruSparkles()
                    .frame(width: 320, height: 280)

                // めろまるキャラ (浮遊+呼吸+タップバウンス)
                Button {
                    HapticManager.light()
                    meromaruTapCount &+= 1
                    consultMeromaru()
                } label: {
                    MeromaruAnimatedImage(bounceTrigger: meromaruTapCount)
                }
                .buttonStyle(NewHomeScaleStyle())
                .accessibilityLabel(Text(String(localized: "めろまるとお話する", bundle: LanguageManager.appBundle)))

                // 吹き出し: 「僕をタップしてみて！」 (フラット表示・装飾エフェクトなし)
                MeromaruSpeechBubble(
                    text: String(localized: "僕をタップしてみて！", bundle: LanguageManager.appBundle)
                )
                .offset(x: 90, y: -90)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // 左サイドメニュー (3 ピル: ファイルから / 使い方 / 履歴)
            VStack(alignment: .leading, spacing: 6) {
                sideMenuButton(
                    icon: "folder",
                    label: String(localized: "ファイルから", bundle: LanguageManager.appBundle),
                    action: { handleFileOpenTap() }
                )
                sideMenuButton(
                    icon: "book",
                    label: String(localized: "使い方", bundle: LanguageManager.appBundle),
                    action: { coordinator.showUsageGuide() }
                )
                sideMenuButton(
                    icon: "bubble.left.and.bubble.right",
                    label: String(localized: "相談", bundle: LanguageManager.appBundle),
                    action: { consultMeromaru() }
                )
            }
            .padding(.leading, 32)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
    }

    // MARK: - Side Menu Pill (アイコン円 + 右に伸びるテール)
    /// 円は白塗り (枠なし)。アイコンは線ピンク (中身は白塗りが透けて見える)。
    /// テキストピルは右側のみ丸角、左側は直角で円の下からまっすぐ伸びるように見せる。
    private func sideMenuButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: -6) {
                ZStack {
                    Circle()
                        .fill(MeloColors.Dark.bgElevated)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(NewHomeTokens.brandPink)
                }
                .frame(width: 35, height: 35)
                .shadow(color: NewHomeTokens.pinkShadow, radius: 3, x: 0, y: 1)
                .zIndex(1)

                Text(label)
                    .font(MeloFonts.zenMaru(10))
                    .tracking(0.24)
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 18)
                    .padding(.trailing, 14)
                    .frame(height: 28)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: 0,
                                bottomLeading: 0,
                                bottomTrailing: 14,
                                topTrailing: 14
                            ),
                            style: .continuous
                        )
                        .fill(MeloColors.Dark.bgElevated)
                        .shadow(color: NewHomeTokens.pinkShadow, radius: 3, x: 0, y: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA Banner (Figma: ピンクグラデの細長ピル + 矢印)
    private var ctaBanner: some View {
        Button {
            HapticManager.medium()
            handleCTATap()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "LINEトーク毒見をはじめる", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(18))
                        .tracking(0.54)
                        .foregroundColor(MeloColors.CTA.onLime)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "トーク履歴からハラスメント構造を毒見診断", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(10))
                        .tracking(0.24)
                        .foregroundColor(MeloColors.CTA.onLime.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .fill(MeloColors.CTA.onLime)
                        .frame(width: 37, height: 37)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MeloColors.CTA.primaryGreen)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(MeloColors.CTA.primaryGreen)
                    .overlay(Capsule().stroke(Color.white, lineWidth: 1))
            )
            .shadow(color: MeloColors.CTA.primaryGreen.opacity(0.45), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(NewHomeScaleStyle())
    }

    // MARK: - History Card (Figma: 白オーバーレイ + 診断履歴 + 行 + ソート切替)
    /// カードに表示している「相手のハラスメント割合」(%)。ランキングのソートキーと表示で共有する。
    /// 二者比較できない旧データは会話全体スコアにフォールバック（historyRow と同一ロジック）。
    private func historyRankValue(stored: StoredAnalysisResult, result: DiagnosisResult) -> Int {
        result.partnerHarassmentShare(selfName: stored.selfParticipant) ?? result.overallRiskScore
    }

    /// 診断結果を保持する履歴を「カード表示の相手ハラスメント% 降順」でランキング化（1 位 = 最高%）。
    private var diagnosisHistory: [(rank: Int, stored: StoredAnalysisResult, result: DiagnosisResult)] {
        let items = analysisHistory.compactMap { s -> (StoredAnalysisResult, DiagnosisResult)? in
            guard let dr = s.diagnosisResult else { return nil }
            return (s, dr)
        }
        .sorted { a, b in
            let av = historyRankValue(stored: a.0, result: a.1)
            let bv = historyRankValue(stored: b.0, result: b.1)
            return av != bv ? av > bv : a.0.analyzedAt > b.0.analyzedAt
        }
        return items.enumerated().map { (idx, e) in (idx + 1, e.0, e.1) }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Text(String(localized: "診断履歴", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(14))
                    .tracking(0.42)
                    .foregroundColor(MeloColors.Dark.textPrimary)
                Spacer()
            }
            .padding(.leading, 6)
            .padding(.trailing, 4)
            .padding(.top, 6)

            if diagnosisHistory.isEmpty {
                emptyHistoryContent
                    .padding(.bottom, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(diagnosisHistory, id: \.stored.id) { item in
                        historyRow(rank: item.rank, stored: item.stored, result: item.result)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                )
        )
    }

    /// 履歴をスコア降順で固定表示。同点の場合は analyzedAt 降順 (新しい方が上) で安定化。
    /// 安定化しないと同点時に並び順が表示の度に揺れて UI がチラついて見える。
    private var emptyHistoryContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 34, weight: .regular))
                .foregroundColor(NewHomeTokens.brandPink.opacity(0.6))
            Text(String(localized: "まだ診断履歴がありません", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(13))
                .tracking(0.3)
                .foregroundColor(NewHomeTokens.textGrey)
            Text(String(localized: "上のカードからLINEトーク毒見をはじめましょう", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(NewHomeTokens.textMuted)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    /// 診断履歴の1行（めろとーく Figma 724:881 のレイアウト踏襲: 行ごと角丸カード /
    /// 左=ランクキャラ 50×50 / 名前+日付 / 右=やばさスコア。配色は yabatーク ダーク + severity 色）。
    /// タップで結果を再オープン。
    private func historyRow(rank: Int, stored: StoredAnalysisResult, result: DiagnosisResult) -> some View {
        Button {
            HapticManager.light()
            // 履歴から開くときも本物のトーク履歴を SwiftData から読み直して渡す。
            // ここで空の ChatSession を渡すと、サマリー(AI月別鑑定)とデータタブ(詳細統計)が
            // session.messages を空とみなして「データなし」になる。本体が破棄済み(容量対策で
            // chatSessionData=nil)のときだけ空のプレースホルダーにフォールバックし、スコア/タイプは表示する。
            Task {
                let real = await loadChatSession(sessionId: result.sessionId)
                let s = real ?? ChatSession(title: result.sessionTitle, messages: [], participants: [])
                coordinator.navigateToDiagnosis(result: result, session: s)
            }
        } label: {
            HStack(spacing: 0) {
                // 1〜3 位はランクキャラ画像、4 位以降は数字。
                rankBadge(rank)
                    .frame(width: 54, alignment: .center)
                    .padding(.leading, 6)

                // 名前 + 日付
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.sessionTitle.isEmpty ? "毒見結果" : result.sessionTitle)
                        .font(MeloFonts.zenMaru(16))
                        .tracking(0.48)
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .lineLimit(1)
                    Text(formatHistoryDate(stored.analyzedAt))
                        .font(MeloFonts.zenMaruRegular(12))
                        .tracking(0.36)
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .lineLimit(1)
                }
                .padding(.leading, 6)

                Spacer(minLength: 8)

                // 右端は「相手のハラスメント割合」（スコアページ上部の相手 % と同値）。
                // ランキングのソートキーと同一値（historyRankValue）で、表示と順位が必ず一致する。
                let rightValue = historyRankValue(stored: stored, result: result)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(result.riskLevel.labColor)
                        .baselineOffset(-2)
                    Text("\(rightValue)")
                        .font(MeloFonts.anton(28))
                        .foregroundColor(result.riskLevel.labColor)
                    Text("%")
                        .font(MeloFonts.mono(11))
                        .foregroundColor(result.riskLevel.labColor)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .padding(.leading, 10)
                    .padding(.trailing, 12)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(MeloColors.Dark.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(MeloColors.Dark.accent.opacity(0.30), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 履歴行の日付表示（yyyy/MM/dd）。
    private func formatHistoryDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    /// 1〜3 位はランクキャラ画像（50×50）、4 位以降は数字（アクセント色）。
    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
        if rank <= 3 {
            Image("rank_\(rank)")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
        } else {
            Text(String(format: "%02d", rank))
                .font(MeloFonts.anton(26))
                .foregroundColor(MeloColors.Dark.accent)
                .frame(width: 50)
        }
    }

    // MARK: - Actions
    private func triggerPrimaryImport() {
        AnalyticsManager.shared.track("diagnose_cta_tap", properties: ["source": "new_home_card"])
        viewModel.isImporting = true
    }

    /// 指定した診断履歴を SwiftData から削除する。
    /// 同じ sessionId の他の period 分もまとめて消す（結果画面の期間切替と整合）。
    private func performDeleteHistory(_ result: StoredAnalysisResult) {
        AnalyticsManager.shared.track("diagnose_history_delete")
        let sessionId = result.sessionId
        let siblings = analysisHistory.filter { $0.sessionId == sessionId }
        for s in siblings {
            modelContext.delete(s)
        }
        try? modelContext.save()
        HapticManager.success()
    }

    private func consultMeromaru() {
        // 診断結果が無ければ従来どおり注意ダイアログ
        guard !analysisHistory.isEmpty else {
            showNoResultAlert = true
            return
        }
        AnalyticsManager.shared.track("consultation_open_from_diagnose")

        // 初回のみ「呼び名」ポップアップを挟む。設定画面で既に入力済みならスキップ。
        let shouldPromptForName = !hasSeenPreferredNamePrompt && (UserPreferredName.stored == nil)
        if shouldPromptForName {
            pendingShowPartnerPicker = true
            showPreferredNamePrompt = true
            return
        }
        showPartnerPicker = true
    }

    /// 相手選択後に ConsultationChatView を開くための準備。
    /// 同意未取得なら GeminiConsentView を先に表示する。
    private func startConsultation(with stored: StoredAnalysisResult) {
        pendingConsultationResult = stored
        if GeminiConsentView.hasAgreed(for: .consultation) {
            presentConsultationChat(for: stored)
        } else {
            showGeminiConsent = true
        }
    }

    /// 相手を特定せずに「とりあえず話す」フロー。
    /// AnalysisResult / partnerName 無しで ReplySuggestionViewModel を初期化し、
    /// ViewModel の greeting は元の汎用版 ("どんな関係の人のことで相談したい？") にフォールバックする。
    private func startGeneralConsultation() {
        AnalyticsManager.shared.track("consultation_open_general_from_diagnose")
        // Gemini 同意未取得なら先に同意フロー
        if !GeminiConsentView.hasAgreed(for: .consultation) {
            pendingConsultationResult = nil
            showGeminiConsent = true
            // GeminiConsentView の onAgree は pendingConsultationResult を見るので、
            // 一般相談の場合はその後手動で呼び直す必要がある。
            // → consent シート閉じた後の onDismiss で handle する代わりに、
            //   下記 onAgree クロージャでカバーする
            return
        }
        // 「とりあえず話す」では分析由来の selfName が無いので、設定画面で入力された呼び名 (なければ "あなた") にフォールバック。
        // partnerName は無いので空文字のまま (system prompt 側で空対応している)。
        let vm = ReplySuggestionViewModel(
            session: nil,
            selfName: UserPreferredName.resolve(),
            partnerName: "",
            analysisResult: nil,
            resultId: nil
        )
        consultationPresentation = ConsultationPresentation(viewModel: vm)
    }

    /// 同意が既に取れている前提で ViewModel を構築し fullScreenCover を立ち上げる。
    /// VM の生成と画面提示を1つの state 更新でまとめることで、SwiftUI の二段 state race
    /// (Bool が先に観測されて Optional VM が nil のままカバーが提示される)を回避する。
    private func presentConsultationChat(for stored: StoredAnalysisResult) {
        let analysisResult = stored.toAnalysisResult()
        Task {
            let session = await loadChatSession(sessionId: stored.sessionId)
            await MainActor.run {
                let vm = ReplySuggestionViewModel(
                    session: session,
                    selfName: analysisResult.selfParticipant,
                    partnerName: analysisResult.partnerParticipant,
                    analysisResult: analysisResult,
                    resultId: analysisResult.id
                )
                consultationPresentation = ConsultationPresentation(viewModel: vm)
            }
        }
    }

    private func loadChatSession(sessionId: UUID) async -> ChatSession? {
        return await Task.detached(priority: .userInitiated) {
            let container = await SwiftDataContainer.shared.container
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<StoredChatSession>(
                predicate: #Predicate<StoredChatSession> { $0.id == sessionId }
            )
            guard let storedSession = try? context.fetch(descriptor).first,
                  let data = storedSession.chatSessionData else { return nil as ChatSession? }
            return try? JSONDecoder().decode(ChatSession.self, from: data)
        }.value
    }

    // MARK: - File Import Handling
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            AnalyticsManager.shared.importStarted(source: .filePicker)
            if !dailyLimitManager.canAnalyze(isSubscribed: subscriptionManager.isSubscribed) {
                AnalyticsManager.shared.limitReached(
                    feature: .analysis, isSubscribed: subscriptionManager.isSubscribed
                )
                pendingImportURL = url
                showLimitAlert = true
                return
            }
            processImportURL(url)
        case .failure(let error):
            AnalyticsManager.shared.importError(.pickerError)
            viewModel.errorMessage = error.localizedDescription
            viewModel.showingError = true
        }
    }

    private func handleSharedFile(url: URL) {
        AnalyticsManager.shared.importStarted(source: .shareExtension)
        fileImportManager.clearPendingFile()

        if !dailyLimitManager.canAnalyze(isSubscribed: subscriptionManager.isSubscribed) {
            AnalyticsManager.shared.limitReached(
                feature: .analysis, isSubscribed: subscriptionManager.isSubscribed
            )
            pendingImportURL = url
            showLimitAlert = true
            return
        }

        processImportURL(url)
    }

    private func processImportURL(_ url: URL) {
        Task {
            if let session = await viewModel.importFile(from: url) {
                coordinator.navigateToImportConfirm(session: session)
            }
        }
    }

    // MARK: - Usage Guide Prompt
    /// 「LINE相性診断」CTA タップ時のハンドラ。
    /// suppressUsageGuidePrompt が true なら従来どおり LINE を開く。
    /// false ならポップアップを表示し、ユーザー選択に応じて遷移を分岐する。
    private func handleCTATap() {
        if suppressUsageGuidePrompt {
            // 中央 CTA は LINE アプリを開く（ファイル取込みは別途「ファイルから」導線が担う）。
            openLineApp()
            return
        }
        usageGuidePromptSource = .ctaCard
        promptDontShowAgain = false
        withAnimation(.easeOut(duration: 0.2)) {
            showUsageGuidePrompt = true
        }
    }

    /// 「ファイルを開く」小ボタン タップ時のハンドラ。
    private func handleFileOpenTap() {
        if suppressUsageGuidePrompt {
            viewModel.isImporting = true
            return
        }
        usageGuidePromptSource = .fileOpen
        promptDontShowAgain = false
        withAnimation(.easeOut(duration: 0.2)) {
            showUsageGuidePrompt = true
        }
    }

    /// LINE アプリを開く（UsageGuideView.openLineApp() と同じ安全パターン）。
    /// line:// scheme のみ使用。https フォールバック (line.me) は LINE 未インストール端末で
    /// Safari に飛んでアプリから離脱するため使わず、App Store の LINE ページへ誘導する。
    private func openLineApp() {
        AnalyticsManager.shared.track("home_cta_open_line_tap")
        let candidates = ["line://nv/chat", "line://"]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        if let storeURL = URL(string: "https://apps.apple.com/jp/app/id443904275") {
            UIApplication.shared.open(storeURL)
        }
    }

    /// ポップアップで選択された「使い方を見る」処理。
    private func usageGuidePromptOpenGuide() {
        if promptDontShowAgain { suppressUsageGuidePrompt = true }
        let _ = usageGuidePromptSource  // 元のソースは使い方ガイド表示後に閉じるだけなので保持しなくてよい
        withAnimation(.easeOut(duration: 0.2)) {
            showUsageGuidePrompt = false
        }
        usageGuidePromptSource = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            coordinator.showUsageGuide()
        }
    }

    /// ポップアップで「見ない」または外側タップで閉じた場合の処理。
    /// 元のボタンのアクションをそのまま続行する。
    private func usageGuidePromptDismissAndProceed() {
        if promptDontShowAgain { suppressUsageGuidePrompt = true }
        let source = usageGuidePromptSource
        withAnimation(.easeOut(duration: 0.2)) {
            showUsageGuidePrompt = false
        }
        usageGuidePromptSource = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            switch source {
            case .ctaCard:
                // 中央 CTA「LINEで始める」は LINE アプリを開く。LINE 未インストール端末は
                // line:// scheme が開けないので App Store の LINE ページへ誘導（Safari 離脱しない）。
                openLineApp()
            case .fileOpen:
                // 「ファイルから」導線は従来どおりファイル取込み。
                viewModel.isImporting = true
            case .none:
                break
            }
        }
    }

    private var usageGuidePromptPopup: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    HapticManager.light()
                    usageGuidePromptDismissAndProceed()
                }

            VStack(spacing: 18) {
                // タイトル
                Text(String(localized: "使い方はわかりますか？", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(18))
                    .tracking(0.45)
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .multilineTextAlignment(.center)

                // 本文
                Text(String(localized: "初めて使う方は使い方ガイドをご覧ください。", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruRegular(13))
                    .tracking(0.3)
                    .foregroundColor(MeloColors.Dark.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // 「今後表示しない」チェックボックス
                Button {
                    HapticManager.light()
                    promptDontShowAgain.toggle()
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(promptDontShowAgain ? MeloColors.Dark.accent : MeloColors.Dark.bgElevated)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(MeloColors.Dark.accent, lineWidth: 1)
                                )
                            if promptDontShowAgain {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(MeloColors.Dark.onAccent)
                            }
                        }
                        Text(String(localized: "今後表示しない", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruRegular(12))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                // 「使い方を見る」(primary, pink filled)
                Button {
                    HapticManager.medium()
                    usageGuidePromptOpenGuide()
                } label: {
                    Text(String(localized: "使い方を見る", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(15))
                        .tracking(0.4)
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(MeloColors.Dark.accentGradient)
                        )
                }
                .buttonStyle(NewHomeScaleStyle())

                // 「見ない」(secondary, outline pink)
                Button {
                    HapticManager.light()
                    usageGuidePromptDismissAndProceed()
                } label: {
                    Text(String(localized: "見ない", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(14))
                        .tracking(0.4)
                        .foregroundColor(MeloColors.Dark.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(MeloColors.Dark.bgElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(MeloColors.Dark.accent, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(NewHomeScaleStyle())
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
            )
            .padding(.horizontal, 36)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showUsageGuidePrompt)
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(MeloColors.Dark.track, lineWidth: 4)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(MeloColors.Dark.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                }
                Text(String(localized: "ファイルを読み込み中...", bundle: LanguageManager.appBundle))
                    .font(MeloTypography.bodyBold)
                    .foregroundColor(MeloColors.Dark.textPrimary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
        }
    }

    // MARK: - Limit Reached Popup
    private var limitReachedPopup: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    HapticManager.light()
                    withAnimation(.easeOut(duration: 0.2)) { showLimitAlert = false }
                }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text(String(localized: "本日の診断回数に達しました", bundle: LanguageManager.appBundle))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                    Text(String(localized: "広告を見て診断回数を追加するか、\nPremiumで無制限に診断できます", bundle: LanguageManager.appBundle))
                        .font(.system(size: 13))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(spacing: 10) {
                    Button {
                        HapticManager.medium()
                        rewardedAdManager.showAd { success in
                            if success {
                                withAnimation(.easeOut(duration: 0.2)) { showLimitAlert = false }
                                if let url = pendingImportURL {
                                    pendingImportURL = nil
                                    processImportURL(url)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(String(localized: "広告を見て+1回", bundle: LanguageManager.appBundle))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!rewardedAdManager.isAdLoaded)
                    .opacity(rewardedAdManager.isAdLoaded ? 1.0 : 0.5)

                    Button {
                        HapticManager.medium()
                        withAnimation(.easeOut(duration: 0.2)) { showLimitAlert = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showSubscription = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(String(localized: "Premiumで無制限", bundle: LanguageManager.appBundle))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        HapticManager.light()
                        withAnimation(.easeOut(duration: 0.2)) { showLimitAlert = false }
                    } label: {
                        Text(String(localized: "閉じる", bundle: LanguageManager.appBundle))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
            )
            .padding(.horizontal, 32)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showLimitAlert)
    }
}

// MARK: - Scale Button Style (local)
private struct NewHomeScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Meromaru Speech Bubble (タップ誘導用、上下に揺れる)
/// 吹き出しはめろまるの右上に配置されるので、テールは左下向きに伸びる。
struct MeromaruSpeechBubble: View {
    let text: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 吹き出し本体 (装飾エフェクトなし、フラット表示)
            Text(text)
                .font(MeloFonts.zenMaru(11))
                .tracking(0.33)
                .foregroundColor(MeloColors.Dark.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        BubbleShapeWithTail()
                            .fill(MeloColors.Dark.bgElevated)
                        BubbleShapeWithTail()
                            .stroke(MeloColors.Dark.accent, lineWidth: 1)
                    }
                )
        }
    }
}

/// 角丸長方形 + 左下にめろまる方向へ伸びるテール (左下対角向き)。
private struct BubbleShapeWithTail: Shape {
    var cornerRadius: CGFloat = 14
    /// テールの根元の幅 (吹き出し下辺上)
    var tailBase: CGFloat = 12
    /// テールの先端のオフセット (吹き出し下辺の根元から左下へ)
    var tailTipDX: CGFloat = -10
    var tailTipDY: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        var p = Path()
        // top-left corner → top-right
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        // right side → bottom-right
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        // bottom-right → tail (start near bottom-left)
        let tailBaseRightX = rect.minX + r + 6 + tailBase
        let tailBaseLeftX  = rect.minX + r + 6
        p.addLine(to: CGPoint(x: tailBaseRightX, y: rect.maxY))
        // tail down-left
        p.addLine(to: CGPoint(x: tailBaseLeftX + tailTipDX, y: rect.maxY + tailTipDY))
        p.addLine(to: CGPoint(x: tailBaseLeftX, y: rect.maxY))
        // tail back up to bottom-left corner
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        // left side → top-left
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Meromaru Animated Image (idle 浮遊 + 呼吸 + タップバウンス)
/// `char_meromaru_3d` を常時アニメーションさせる小さなラッパー。
/// - 上下に ±5pt 浮遊 (2.4s, easeInOut, 永続)
/// - 0.97 ↔ 1.03 で呼吸スケール (3.0s, easeInOut, 永続)
/// - `bounceTrigger` が変わる度にバウンス (1.0 → 1.15 → 1.0, spring)
struct MeromaruAnimatedImage: View {
    let bounceTrigger: Int

    @State private var bobOffset: CGFloat = 0
    @State private var breathScale: CGFloat = 1.0
    @State private var bouncePop: CGFloat = 1.0

    var body: some View {
        Image("char_meromaru_3d")
            .resizable()
            .scaledToFit()
            .frame(width: 250, height: 224)
            .scaleEffect(breathScale * bouncePop)
            .offset(y: bobOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    bobOffset = -5
                }
                withAnimation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
                ) {
                    breathScale = 1.03
                }
            }
            .onChange(of: bounceTrigger) { _, _ in
                triggerBounce()
            }
    }

    private func triggerBounce() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
            bouncePop = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) {
                bouncePop = 1.0
            }
        }
    }
}

// MARK: - Meromaru Sparkles (めろまる周りでキラキラ光る星 + 白&ピンクの後光)
struct MeromaruSparkles: View {
    @State private var haloPhase: CGFloat = 0

    /// 大星 (主役): 大きめ・遅めの周期でじわっと光る
    private let heroStars: [SparkleSpec] = [
        .init(offset: .init(width: -110, height: -90), size: 26, color: .white, duration: 2.4, delay: 0.0),
        .init(offset: .init(width:  120, height: -60), size: 24, color: .pink,  duration: 2.6, delay: 0.6),
        .init(offset: .init(width:  -90, height: 100), size: 22, color: .white, duration: 2.2, delay: 1.1),
        .init(offset: .init(width:  100, height:  90), size: 20, color: .pink,  duration: 2.8, delay: 0.3),
    ]

    /// 中星: 中サイズ・中速。白とピンクを交互に
    private let midStars: [SparkleSpec] = [
        .init(offset: .init(width: -140, height:   0), size: 16, color: .white, duration: 1.5, delay: 0.0),
        .init(offset: .init(width:  140, height:  20), size: 16, color: .pink,  duration: 1.4, delay: 0.4),
        .init(offset: .init(width:    0, height: -130), size: 17, color: .white, duration: 1.6, delay: 0.7),
        .init(offset: .init(width:  -50, height: -130), size: 14, color: .pink,  duration: 1.3, delay: 1.0),
        .init(offset: .init(width:   60, height: -130), size: 15, color: .white, duration: 1.5, delay: 0.2),
        .init(offset: .init(width: -130, height:  60), size: 14, color: .pink,  duration: 1.4, delay: 0.9),
        .init(offset: .init(width:  130, height: -10), size: 15, color: .white, duration: 1.6, delay: 0.5),
    ]

    /// 小星 (背景の粒): 小さく速い瞬き。密度を出す
    private let tinyStars: [SparkleSpec] = [
        .init(offset: .init(width:  -70, height: -50), size: 9,  color: .white, duration: 0.9, delay: 0.0),
        .init(offset: .init(width:   70, height: -40), size: 9,  color: .pink,  duration: 1.0, delay: 0.3),
        .init(offset: .init(width:  -30, height:  70), size: 10, color: .white, duration: 0.9, delay: 0.6),
        .init(offset: .init(width:   30, height:  70), size: 9,  color: .pink,  duration: 1.1, delay: 0.1),
        .init(offset: .init(width:  -90, height:  40), size: 8,  color: .white, duration: 0.8, delay: 0.5),
        .init(offset: .init(width:   90, height:  50), size: 10, color: .white, duration: 1.0, delay: 0.8),
        .init(offset: .init(width:  -40, height: -110), size: 8, color: .pink,  duration: 0.9, delay: 0.2),
        .init(offset: .init(width:   40, height: -110), size: 9, color: .white, duration: 1.0, delay: 0.7),
    ]

    var body: some View {
        ZStack {
            // 後光: 白いふんわり (中心)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.75),
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 160
                    )
                )
                .scaleEffect(0.92 + haloPhase * 0.16)
                .opacity(0.7 + haloPhase * 0.3)
                .blur(radius: 10)

            ForEach(heroStars.indices, id: \.self) { idx in
                SparkleStar(spec: heroStars[idx], rotates: true)
            }
            ForEach(midStars.indices, id: \.self) { idx in
                SparkleStar(spec: midStars[idx], rotates: true)
            }
            ForEach(tinyStars.indices, id: \.self) { idx in
                SparkleStar(spec: tinyStars[idx], rotates: false)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                haloPhase = 1
            }
        }
    }
}

struct SparkleSpec {
    enum Tint { case white, pink }
    let offset: CGSize
    let size: CGFloat
    let color: Tint
    let duration: Double
    let delay: Double
}

private struct SparkleStar: View {
    let spec: SparkleSpec
    /// 中・大星のみ回転させる。小星はチラつきだけで十分
    let rotates: Bool

    @State private var phase: CGFloat = 0
    @State private var rotation: Double = 0

    private var tintColor: Color {
        switch spec.color {
        case .white: return .white
        case .pink:  return MeloColors.Dark.accent
        }
    }

    /// グロー (にじみ) の色。白星は白、ピンク星はライムで光らせて存在感を出す
    private var glowColor: Color {
        switch spec.color {
        case .white: return .white
        case .pink:  return MeloColors.Dark.accent
        }
    }

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: spec.size, weight: .regular))
            .foregroundColor(tintColor)
            .opacity(0.2 + phase * 0.8)
            .scaleEffect(0.4 + phase * 0.9)
            .rotationEffect(.degrees(rotation))
            .shadow(color: glowColor.opacity(0.95), radius: 8)
            .shadow(color: glowColor.opacity(0.55), radius: 3)
            .offset(spec.offset)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + spec.delay) {
                    withAnimation(
                        .easeInOut(duration: spec.duration).repeatForever(autoreverses: true)
                    ) {
                        phase = 1
                    }
                    if rotates {
                        withAnimation(
                            .linear(duration: spec.duration * 6).repeatForever(autoreverses: false)
                        ) {
                            rotation = 360
                        }
                    }
                }
            }
    }
}

// MARK: - Consultation Presentation Wrapper

/// 相談チャットの fullScreenCover(item:) 用 wrapper。
/// VM 自体を Identifiable にせず、提示単位ごとに新しい id を持つ wrapper を介すことで、
/// 同じ VM を再提示するケース(将来的な永続化・キャッシュ等)にも対応できる。
struct ConsultationPresentation: Identifiable {
    let id = UUID()
    let viewModel: ReplySuggestionViewModel
}

// MARK: - Preview
#Preview {
    NavigationStack {
        NewHomeView()
    }
    .environmentObject(AppCoordinator())
    .modelContainer(for: [StoredChatSession.self, StoredAnalysisResult.self])
}
