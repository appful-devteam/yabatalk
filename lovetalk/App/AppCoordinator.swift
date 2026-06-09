import SwiftUI

// MARK: - Main Tab
/// 5タブ構成: ホーム / 相談部屋 / 診断する（中央） / 擬似チャット / マイページ
enum MainTab: String, CaseIterable {
    case home = "home"                  // 旧掲示板（表示順1）
    case consultRoom = "consult_room"   // 相談部屋（表示順2・新機能）
    case diagnose = "diagnose"          // 診断する（表示順3・中央）
    case personaChat = "persona_chat"   // 擬似チャット（表示順4）
    case profile = "profile"            // マイページ（表示順5）

    var localizedName: String {
        switch self {
        case .home: return String(localized: "ホーム", bundle: LanguageManager.appBundle)
        case .consultRoom: return String(localized: "相談部屋", bundle: LanguageManager.appBundle)
        case .diagnose: return String(localized: "診断する", bundle: LanguageManager.appBundle)
        case .personaChat: return String(localized: "チャット", bundle: LanguageManager.appBundle)
        case .profile: return String(localized: "マイページ", bundle: LanguageManager.appBundle)
        }
    }

    /// Figma からエクスポートしたタブアイコン（Assets.xcassets）
    var assetName: String {
        switch self {
        case .home: return "tab_home"
        case .consultRoom: return "tab_community"
        case .diagnose: return "tab_melomaru"
        case .personaChat: return "tab_chat"
        case .profile: return "tab_profile"
        }
    }

    /// サイドタブの SF Symbol。選択時は `.fill` 変種を、非選択時は枠のみ変種を使う。
    /// 中央の `.diagnose` はカスタム PNG アセットを使うため nil。
    var sfSymbolName: (filled: String, outline: String)? {
        switch self {
        case .home: return ("house.fill", "house")
        case .consultRoom: return ("person.2.fill", "person.2")
        case .diagnose: return nil
        case .personaChat: return ("bubble.left.and.bubble.right.fill", "bubble.left.and.bubble.right")
        case .profile: return ("person.crop.circle.fill", "person.crop.circle")
        }
    }
}

// MARK: - App Coordinator
/// アプリ全体のナビゲーションを管理
@MainActor
final class AppCoordinator: ObservableObject {
    // MARK: - Navigation State
    /// 診断タブ（中央）の NavigationStack。ImportConfirm / Analyzing / Result など診断フロー全般を担う。
    @Published var path = NavigationPath()
    /// 擬似チャットタブの NavigationStack
    @Published var chatPath = NavigationPath()
    /// ホームタブ（旧掲示板）の NavigationStack
    @Published var homePath = NavigationPath()
    /// 相談部屋タブの NavigationStack
    @Published var consultRoomPath = NavigationPath()

    @Published var showingComposeV2 = false
    @Published var selectedTab: MainTab = .diagnose  // 中央（診断する）をデフォルト
    @Published var showingSettings = false
    @Published var showingImport = false
    @Published var showingUsageGuide = false
    @Published var showPreReviewAlert = false
    @Published var showingSubscription = false
    @Published var subscriptionSource: String = "other"

    /// スクロール時にタブバーを隠す
    @Published var isBarsHidden = false

    /// ホームタブ（旧掲示板）の未読通知数（タブバーバッジ用）
    @Published var homeUnreadCount = 0

    // MARK: - Data State
    @Published var currentSession: ChatSession?
    @Published var currentResult: AnalysisResult?

    /// 新規分析が完了したかどうか（レビュープロンプト表示判定用）
    private var didCompleteNewAnalysis = false

    // MARK: - Navigation Destinations
    enum Destination: Hashable {
        case importConfirm(ChatSession)
        case analyzing(ChatSession, String) // session, selfName
        case diagnosis(DiagnosisResult, ChatSession) // ヤバ診断結果, session
        case personaChat(AnalysisResult, ChatSession?) // AI擬人化チャット
    }

    // MARK: - Navigation Methods

    func navigateToImportConfirm(session: ChatSession) {
        currentSession = session
        path.append(Destination.importConfirm(session))
        AnalyticsManager.shared.screenView("import_confirm")
    }

    func navigateToAnalyzing(session: ChatSession, selfName: String) {
        path.append(Destination.analyzing(session, selfName))
        AnalyticsManager.shared.screenView("analyzing")
    }

    func navigateToDiagnosis(result: DiagnosisResult, session: ChatSession) {
        currentSession = session
        didCompleteNewAnalysis = true
        path = NavigationPath()
        path.append(Destination.diagnosis(result, session))
        AnalyticsManager.shared.screenView("diagnosis_result")
        AnalyticsManager.shared.resultViewed(.first)
    }

    func navigateToPersonaChat(result: AnalysisResult, session: ChatSession?) {
        path.append(Destination.personaChat(result, session))
        AnalyticsManager.shared.screenView("persona_chat")
    }

    func popToRoot() {
        path = NavigationPath()
        currentSession = nil

        if didCompleteNewAnalysis {
            didCompleteNewAnalysis = false
            if ReviewManager.shouldShowPreReviewPrompt() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showPreReviewAlert = true
                }
            }
            AnnouncementManager.shared.trigger("after_analysis")
        }
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func showSettings() {
        showingSettings = true
    }

    func showImport() {
        showingImport = true
    }

    func showUsageGuide() {
        showingUsageGuide = true
    }

    /// 投稿に紐づいた相談部屋を開く。タブを相談部屋に切り替え、ID/タイトル のみの軽量
    /// CommunityRoom スタブを path に積む。詳細ビュー側は room.id を使って Firestore から
    /// 投稿リストを取得するので、subtitle 等が空でも動作する。
    func openCommunityRoom(id: String, title: String) {
        guard !id.isEmpty else { return }
        let stub = CommunityRoom(
            id: id,
            title: title,
            subtitle: "",
            participantCount: 0
        )
        // selectedTab 切替 → consultRoomPath への push を別フレームで実行 (一度に切り替えると iOS が無視する場合あり)
        selectedTab = .consultRoom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.consultRoomPath.append(stub)
        }
    }
}

// MARK: - StoredAnalysisResult Extension
extension StoredAnalysisResult {
    func toAnalysisResult() -> AnalysisResult {
        // 保存されたRaw Valuesを使用（なければデフォルト値）
        let storedBalanceRaw = balanceRawValues ?? BalanceRawValues(
            textSendRatio: 0.5,
            blockInitiationRatio: 0.5,
            chaseMessageDifference: 0,
            selfMessageCount: totalMessages / 2,
            partnerMessageCount: totalMessages / 2
        )

        let storedTensionRaw = tensionRawValues ?? TensionRawValues(
            stickerRate: 0,
            laughRate: 0,
            emojiRate: 0,
            exclamationRate: 0,
            mediaRate: 0,
            stickerCount: 0,
            laughCount: 0,
            emojiCount: 0,
            exclamationCount: 0,
            mediaCount: 0
        )

        let storedResponseRaw = responseRawValues ?? ResponseRawValues(
            selfReplyMedian: 300,
            partnerReplyMedian: 300,
            replySpeedDifference: 0,
            selfReplyCount: 0,
            partnerReplyCount: 0
        )

        let storedWordRaw = wordRawValues ?? WordRawValues(
            lovePhraseRate: 0,
            gratitudeRate: 0,
            careRate: 0,
            greetingRate: 0,
            encouragementRate: 0,
            affirmationRate: 0,
            missingRate: 0,
            futureRate: 0,
            totalWordHits: 0,
            totalTextMessages: totalMessages
        )

        let axisScore = AxisScore(
            balanceScore: balanceScore,
            balanceRawValues: storedBalanceRaw,
            tensionScore: tensionScore,
            tensionRawValues: storedTensionRaw,
            responseScore: responseScore,
            responseRawValues: storedResponseRaw,
            wordScore: wordScore,
            wordRawValues: storedWordRaw,
            confidence: confidence
        )

        return AnalysisResult(
            id: id,
            sessionId: sessionId,
            period: AnalysisPeriod(rawValue: period) ?? .all,
            axisScore: axisScore,
            selfParticipant: selfParticipant,
            partnerParticipant: partnerParticipant,
            analyzedAt: analyzedAt,
            totalMessages: totalMessages,
            totalBlocks: totalBlocks,
            analyzedDays: analyzedDays,
            firstMessageDate: firstMessageDate ?? session?.firstMessageDate ?? Date(),
            lastMessageDate: lastMessageDate ?? session?.lastMessageDate ?? Date(),
            detailedStatistics: detailedStatistics,
            isGroupChat: (groupParticipantNames?.count ?? 0) > 2,
            memberScores: memberScores,
            groupParticipantNames: groupParticipantNames,
            groupTitle: session?.title,
            replyStyleProfiles: replyStyleProfiles
        )
    }
}

// MARK: - Root View
struct RootView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var announcementManager = AnnouncementManager.shared
    @StateObject private var versionGate = AppVersionGate.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    // onboarding usage guide is now gated by NewHomeView's diagnose CTA / file open popup
    @State private var showSurvey = false
    @State private var showFirstLaunchPaywall = false
    @State private var isFirstLaunch = false
    @State private var showTermsConsent = false
    @State private var showNotificationPrompt = false

    private let hasLaunchedBeforeKey = "hasLaunchedBefore"

    var body: some View {
        // 強制アップデート: Supabase の minimum_supported_version より下なら全画面ロック。
        // hasChecked 前は通常 UI をそのまま出す (オフラインで起動できない事態を避けるため)。
        // yabatalk では lovetalk 用 Remote Config を共有しているため、
        // force-update gate を無効化（yabatalk の minimum_version 設定が出来るまでロック回避）。
        mainContent
    }

    private var mainContent: some View {
        ZStack {
            Group {
                switch coordinator.selectedTab {
                case .home:
                    NavigationStack(path: $coordinator.homePath) {
                        BoardFeedView()
                    }

                case .consultRoom:
                    NavigationStack(path: $coordinator.consultRoomPath) {
                        // navigationDestination は CommunityRoomsView 内で登録する
                        // （所有する一覧 VM を詳細ビューに渡せるようにするため）。
                        CommunityRoomsView(
                            onRoomTap: { room in
                                coordinator.consultRoomPath.append(room)
                            },
                            onCompose: {
                                coordinator.showingComposeV2 = true
                            }
                        )
                    }

                case .diagnose:
                    NavigationStack(path: $coordinator.path) {
                        NewHomeView()
                            .navigationDestination(for: AppCoordinator.Destination.self) { destination in
                                switch destination {
                                case .importConfirm(let session):
                                    ImportConfirmView(session: session)

                                case .analyzing(let session, let selfName):
                                    AnalyzingView(session: session, selfName: selfName)

                                case .diagnosis(let result, _):
                                    DiagnosisResultView(result: result)

                                case .personaChat(let result, let session):
                                    PersonaChatView(
                                        viewModel: PersonaChatViewModel(
                                            sessionId: result.sessionId,
                                            partnerName: result.partnerParticipant,
                                            analysisResult: result,
                                            chatSession: session
                                        )
                                    )
                                }
                            }
                    }

                case .personaChat:
                    NavigationStack(path: $coordinator.chatPath) {
                        ChatListView()
                            .navigationDestination(for: ChatListDestination.self) { dest in
                                PersonaChatView(
                                    viewModel: PersonaChatViewModel(
                                        sessionId: dest.result.sessionId,
                                        partnerName: dest.result.partnerParticipant,
                                        analysisResult: dest.result,
                                        chatSession: dest.session
                                    )
                                )
                            }
                    }

                case .profile:
                    BoardMyProfileView()
                }
            }
            // メインタブ間の左右スワイプ移動は廃止 (掲示板のテーマタブを横スワイプで切り替えると
            // 隣のタブへ遷移してしまう副作用があったため)。タブの切替はタブバータップのみ。
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // .safeAreaInset を使うことでコンテンツの下端がタブバー上端で
                // 止まり、スクロール可能コンテンツがタブバー背面に隠れない。
                if coordinator.path.isEmpty
                    && coordinator.chatPath.isEmpty
                    && coordinator.homePath.isEmpty
                    && coordinator.consultRoomPath.isEmpty
                    && !coordinator.isBarsHidden {
                    MainTabBar(
                        selectedTab: $coordinator.selectedTab,
                        homeUnreadCount: coordinator.homeUnreadCount,
                        onDoubleTap: { tab in
                            NotificationCenter.default.post(name: .scrollToTop, object: tab)
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .environmentObject(coordinator)
            .environmentObject(languageManager)
            .onChange(of: coordinator.selectedTab) { _ in
                coordinator.isBarsHidden = false
            }
            .sheet(isPresented: $coordinator.showingSettings) {
                SettingsView()
                    .environmentObject(languageManager)
            }
            .sheet(isPresented: $coordinator.showingComposeV2) {
                BoardComposeViewV2(
                    onRequestOpenConsultRoom: {
                        coordinator.consultRoomPath = NavigationPath()
                        coordinator.selectedTab = .consultRoom
                    }
                )
            }
            .sheet(isPresented: $coordinator.showingUsageGuide) {
                UsageGuideView()
            }
            .sheet(isPresented: $coordinator.showingSubscription) {
                SubscriptionView(source: coordinator.subscriptionSource)
            }
            .alert(
                String(localized: "めろとーくを気に入りましたか？", bundle: LanguageManager.appBundle),
                isPresented: $coordinator.showPreReviewAlert
            ) {
                Button(String(localized: "はい", bundle: LanguageManager.appBundle)) {
                    ReviewManager.requestReview()
                    AnalyticsManager.shared.track("pre_review_prompt", properties: ["action": "yes"])
                }
                Button(
                    String(localized: "いいえ", bundle: LanguageManager.appBundle),
                    role: .cancel
                ) {
                    ReviewManager.recordPromptShown()
                    AnalyticsManager.shared.track("pre_review_prompt", properties: ["action": "no"])
                }
            } message: {
                Text(String(localized: "よろしければApp Storeでの評価にご協力ください。", bundle: LanguageManager.appBundle))
            }
            // onboarding usage guide is now gated by NewHomeView's diagnose CTA / file open popup
            .fullScreenCover(isPresented: $showSurvey, onDismiss: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showNotificationPrompt = true
                }
            }) {
                OnboardingSurveyView()
            }
            .fullScreenCover(isPresented: $showNotificationPrompt, onDismiss: {
                let hasAgreed = UserDefaults.standard.bool(forKey: Constants.StorageKeys.hasAgreedToTerms)
                if isFirstLaunch {
                    if hasAgreed {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showFirstLaunchPaywall = true
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showTermsConsent = true
                        }
                    }
                } else {
                    if hasAgreed {
                        announcementManager.trigger("on_launch")
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showTermsConsent = true
                        }
                    }
                }
            }) {
                NotificationPromptView()
            }
            .fullScreenCover(isPresented: $showTermsConsent, onDismiss: {
                if isFirstLaunch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showFirstLaunchPaywall = true
                    }
                } else {
                    announcementManager.trigger("on_launch")
                }
            }) {
                TermsConsentView()
                    .interactiveDismissDisabled(true)
            }
            .fullScreenCover(isPresented: $showFirstLaunchPaywall) {
                SubscriptionView(source: "first_launch")
            }

            if let announcement = announcementManager.activeAnnouncement {
                AnnouncementPopupView(
                    announcement: announcement,
                    onDismiss: { dontShowAgain in
                        announcementManager.dismissCurrent(dontShowAgain: dontShowAgain)
                    },
                    onPrimaryAction: {
                        if let url = announcementManager.handlePrimaryAction() {
                            openURL(url)
                        }
                        announcementManager.dismissCurrent()
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        // ホームインジケータ領域含めた全画面を白で塗り、
        // タブバーの下(SafeArea)からコンテンツが透けないようにする。
        .background(Color.white.ignoresSafeArea())
        .environment(\.locale, languageManager.locale)
        .onAppear {
            SessionMergeService.splitMismergedSessions(modelContext: modelContext)
            SessionMergeService.mergeIfNeeded(modelContext: modelContext)
            checkFirstLaunch()
            AnalyticsManager.shared.track("app_open", properties: [
                "is_first_launch": !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            ])
            Task {
                await AppDataFirestoreService.shared.bootstrap()
            }
            WeeklyReminderService.shared.rescheduleIfAuthorized()
            #if DEBUG
            // 起動引数 -yt_seed_diagnosis YES でサンプル診断を流し込み結果画面へ直行（動作確認用）。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                YabatalkDebug.seedIfNeeded(coordinator)
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerAnnouncement)) { notification in
            if let triggerName = notification.userInfo?["trigger"] as? String {
                announcementManager.trigger(triggerName)
            }
        }
    }

    private func checkFirstLaunch() {
        #if DEBUG
        // seed 動作確認時 / ASC スクショ撮影時は初回起動ゲート（アンケート/規約/ペイウォール）を出さない。
        if YabatalkDebug.isSeedingDiagnosis || YabatalkDebug.isScreenshotMode { return }
        #endif
        let defaults = UserDefaults.standard
        let hasLaunchedBefore = defaults.bool(forKey: hasLaunchedBeforeKey)
        let surveyCompleted = defaults.string(forKey: Constants.StorageKeys.surveyCompletedVersion) != nil
        let needsSurvey = !surveyCompleted

        if !hasLaunchedBefore {
            defaults.set(true, forKey: hasLaunchedBeforeKey)
            isFirstLaunch = true
            AnalyticsManager.shared.tutorialBegin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSurvey = true
            }
        } else if needsSurvey {
            isFirstLaunch = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSurvey = true
            }
        } else {
            let hasAgreed = defaults.bool(forKey: Constants.StorageKeys.hasAgreedToTerms)
            if !hasAgreed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTermsConsent = true
                }
            } else {
                announcementManager.trigger("on_launch")
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let scrollToTop = Notification.Name("scrollToTop")
}

#if DEBUG
// MARK: - Debug Seed（診断フロー動作確認用ハーネス）
/// シミュレータにタップ操作ツールが無い環境でも、サンプル LINE トークから
/// 診断パイプライン（FactorDetector→…→OutputBuilder）を実走させ、結果画面まで
/// 自動遷移して目視確認するための DEBUG 限定ハーネス。本番ビルドには含まれない。
///
/// 使い方（XcodeBuildMCP の launchArgs / Xcode の Scheme 引数）:
///   -yt_seed_diagnosis YES                 サンプル診断を実行して結果画面へ直行
///   -yt_seed_relationship bossOverMe       関係性を指定（既定: bossOverMe）
///     指定可: romantic / exRomantic / family / friend / bossOverMe / subToMe / colleague
enum YabatalkDebug {
    static var isSeedingDiagnosis: Bool {
        UserDefaults.standard.bool(forKey: "yt_seed_diagnosis")
    }

    /// ASC スクショ撮影用。-yt_no_ads YES で App Open 広告を抑止し、クリーンなホーム等を撮る。
    static var isScreenshotMode: Bool {
        UserDefaults.standard.bool(forKey: "yt_no_ads")
    }

    static var seedRelationship: RelationshipContext {
        let raw = UserDefaults.standard.string(forKey: "yt_seed_relationship") ?? "bossOverMe"
        return RelationshipContext(rawValue: raw) ?? .bossOverMe
    }

    /// 結果画面の初期タブ（動作確認/スクショ用）。-yt_seed_tab score|type|data|summary
    static var seedInitialTab: DiagnosisTab? {
        guard let raw = UserDefaults.standard.string(forKey: "yt_seed_tab") else { return nil }
        return DiagnosisTab(rawValue: raw)
    }

    /// 上司→自分のパワハラ＋示唆を含むサンプル。タブ区切り LINE エクスポート形式。
    static let sampleChat: String = [
        "[LINE] 田中課長とのトーク履歴",
        "2024/1/15(月)",
        "21:30\t田中課長\t明日の資料、まだできてないの？こんなこともできないなんて使えないな",
        "21:31\t田中課長\tお前みたいなやつ、ほんと頭悪いよな",
        "21:35\t自分\tすみません、明日の朝までに必ず仕上げます",
        "21:36\t田中課長\tは？今日中に決まってるだろ。常識ないの？",
        "21:40\t田中課長\tできないなら評価下げるから。来期のシフトも減らすぞ",
        "22:50\t田中課長\tおい、まだ返事ないけど無視してんの？",
        "23:30\t田中課長\t深夜だろうが関係ない。今すぐ電話しろ",
        "23:31\t田中課長\t断るとかありえないから。嫌なら辞めれば？代わりはいくらでもいる",
        "2024/1/16(火)",
        "0:15\t田中課長\t返信遅いんだよ。お前みたいな価値ないやつ、ほんと存在が邪魔",
        "0:20\t自分\t申し訳ありません、すぐ対応します",
        "0:21\t田中課長\tこのこと誰にも言うなよ。言ったらどうなるか分かってるよな",
        "7:00\t田中課長\tあと、この前の飲み会の写真、SNSに晒してやろうか笑"
    ].joined(separator: "\n")

    @MainActor
    static func seedIfNeeded(_ coordinator: AppCoordinator) {
        guard isSeedingDiagnosis else { return }
        guard coordinator.path.isEmpty else { return }  // 二重投入を防ぐ
        do {
            var session = try LineChatParser().parse(sampleChat, title: "田中課長")
            session.relationship = seedRelationship
            session.estimatedSelfName = "自分"
            let result = DiagnoseHarassmentUseCase().execute(session: session)
            coordinator.selectedTab = .diagnose
            coordinator.navigateToDiagnosis(result: result, session: session)
        } catch {
            print("[YabatalkDebug] seed failed: \(error)")
        }
    }
}
#endif

// MARK: - Preview
#Preview {
    RootView()
}
