import SwiftUI
import SwiftData
import UIKit

// MARK: - Analyzing View Tokens (NewHomeView 準拠)
private enum AnalyzingTokens {
    static let pageBg = Color.white
    static let softBg = MeloColors.Surface.pinkPale
    static let softBgAlt = MeloColors.Surface.pinkPale
    static let brandPink = MeloColors.Brand.pink
    static let filledPink = MeloColors.Brand.pink
    static let softPink = MeloColors.Brand.pinkLight
    static let textDark = MeloColors.Text.primary
    static let textGrey = MeloColors.Text.secondary
    static let brownBorder = MeloColors.Text.primary
}

// MARK: - Analyzing View
struct AnalyzingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.modelContext) private var modelContext
    let session: ChatSession
    let selfName: String

    @State private var currentStepIndex = 0
    @State private var analysisTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var showingError = false

    private let steps = AnalyzingStep.defaultSteps
    private let diagnoseUseCase = DiagnoseHarassmentUseCase()

    var body: some View {
        ZStack {
            // 背景: 診断するページと共通のピンクスターダスト (30% opacity)
            ZStack {
                MeloColors.Surface.pinkPale
                Image("bg_diagnose_stardust")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.3)
            }
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // アニメーション (新デザインに合わせて更新)
                AnalyzingAnimation()

                // テキスト
                VStack(spacing: 8) {
                    Text(String(localized: "解析中...", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(22))
                        .tracking(0.66)
                        .foregroundColor(AnalyzingTokens.textDark)

                    if isGroupChat {
                        groupChatLabel
                    } else {
                        partnerChatLabel
                    }
                }

                Spacer()

                // 進捗ステップ
                ProgressSteps(
                    steps: steps,
                    currentStepIndex: currentStepIndex
                )
                .padding(.horizontal, 28)

                Spacer()
                    .frame(height: 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startAnalysis()
        }
        .onDisappear {
            analysisTask?.cancel()
        }
        .alert(String(localized: "エラー", bundle: LanguageManager.appBundle), isPresented: $showingError) {
            Button(String(localized: "戻る", bundle: LanguageManager.appBundle)) {
                coordinator.popToRoot()
            }
        } message: {
            Text(errorMessage ?? String(localized: "解析に失敗しました", bundle: LanguageManager.appBundle))
        }
    }

    // MARK: - Subviews

    private var groupChatLabel: some View {
        (Text(session.title)
            .font(MeloFonts.zenMaru(15))
            .foregroundColor(AnalyzingTokens.brandPink)
        + Text(String(localized: "のグループを診断しています", bundle: LanguageManager.appBundle))
            .font(MeloFonts.zenMaruRegular(13))
            .foregroundColor(AnalyzingTokens.textGrey))
            .tracking(0.3)
    }

    private var partnerChatLabel: some View {
        (Text(partnerName)
            .font(MeloFonts.zenMaru(15))
            .foregroundColor(AnalyzingTokens.brandPink)
        + Text(String(localized: "さんとの関係を診断しています", bundle: LanguageManager.appBundle))
            .font(MeloFonts.zenMaruRegular(13))
            .foregroundColor(AnalyzingTokens.textGrey))
            .tracking(0.3)
    }

    // MARK: - Computed Properties

    private var isGroupChat: Bool {
        !session.isOneOnOne
    }

    private var partnerName: String {
        if isGroupChat {
            return session.title
        }
        return session.participants.first { $0.name != selfName }?.name ?? ""
    }

    // MARK: - Methods

    private func startAnalysis() {
        analysisTask = Task {
            // ステップを順番に進める
            for (index, step) in steps.enumerated() {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStepIndex = index
                    }
                }

                // 実際の解析は最後のステップで実行
                if index == steps.count - 1 {
                    await performAnalysis()
                } else {
                    // 演出用の待機
                    try? await Task.sleep(nanoseconds: UInt64(step.duration * 1_000_000_000))
                }
            }
        }
    }

    private func performAnalysis() async {
        let startTime = Date()
        await MainActor.run {
            AnalyticsManager.shared.analysisStarted(
                period: .all,
                messageCount: session.totalMessageCount
            )
        }

        let useCase = diagnoseUseCase
        var sessionForDiagnosis = session
        sessionForDiagnosis.estimatedSelfName = selfName

        // バックグラウンドスレッドで重い解析を実行
        let diagnosisResult = await Task.detached(priority: .userInitiated) {
            useCase.execute(session: sessionForDiagnosis)
        }.value

        guard !Task.isCancelled else { return }

        // 診断回数を記録
        await MainActor.run {
            DailyLimitManager.shared.recordAnalysis()
        }

        // 分析完了イベント(コア完了 CV)
        await MainActor.run {
            AnalyticsManager.shared.analysisCompleted(
                durationSec: Int(Date().timeIntervalSince(startTime)),
                relationshipType: diagnosisResult.primaryCategory.rawValue,
                totalScore: Double(diagnosisResult.overallRiskScore),
                balanceScore: 0,
                tensionScore: 0,
                responseScore: 0,
                wordScore: 0
            )
        }

        // 診断完了バイブレーション → 結果画面に遷移
        // ドドドッ → ドンッ！の演出
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.6)
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.8)
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        // 最後のドンッ！
        await MainActor.run {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            coordinator.navigateToDiagnosis(result: diagnosisResult, session: session)
        }
    }

    /// セッションを保存（Upsert方式）
    /// - 同じ相手（title + 参加者一致）の場合: 既存セッションを更新し、古いトーク履歴を最新で上書き
    /// - 新しい相手の場合: 新規セッションを作成
    /// → 一人につき常に最新のトーク履歴1つだけを保持。診断結果は別テーブルなので影響なし
    @MainActor
    private func saveSession() -> StoredChatSession {
        let sessionTitle = session.title
        let currentParticipants = Set(session.participants.map { $0.name })
        let descriptor = FetchDescriptor<StoredChatSession>(
            predicate: #Predicate { $0.title == sessionTitle }
        )

        // titleが一致 かつ 参加者が同じセッション → 既存を更新（古いトーク履歴は上書き削除）
        if let candidates = try? modelContext.fetch(descriptor),
           let existingSession = candidates.first(where: { stored in
               Set(stored.participantNames) == currentParticipants
           }) {
            existingSession.participantNames = session.participants.map { $0.name }
            existingSession.messageCount = session.totalMessageCount
            existingSession.importedAt = Date()
            existingSession.firstMessageDate = session.firstMessageDate
            existingSession.lastMessageDate = session.lastMessageDate
            // 古いchatSessionDataを最新で上書き（@externalStorageなので古いファイルは自動削除）
            existingSession.chatSessionData = try? JSONEncoder().encode(session)

            releaseOldSessionData()
            try? modelContext.save()
            return existingSession
        }

        // 新規セッション作成
        let storedSession = StoredChatSession(
            id: session.id,
            title: session.title,
            participantNames: session.participants.map { $0.name },
            messageCount: session.totalMessageCount,
            importedAt: session.importedAt,
            firstMessageDate: session.firstMessageDate,
            lastMessageDate: session.lastMessageDate
        )
        storedSession.chatSessionData = try? JSONEncoder().encode(session)
        modelContext.insert(storedSession)

        releaseOldSessionData()
        try? modelContext.save()
        return storedSession
    }

    /// トーク履歴データのストレージ管理
    /// - 一人（title + 参加者）につき最新のトーク履歴を1つだけ保持（saveSession()のupsertで保証）
    /// - 最大20人分のトーク履歴を保持し、21人目以降は古い順にデータのみ削除
    /// - 削除するのはchatSessionData（トーク生データ）のみ。診断結果(StoredAnalysisResult)は残す
    @MainActor
    private func releaseOldSessionData() {
        let allDescriptor = FetchDescriptor<StoredChatSession>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        if let allSessions = try? modelContext.fetch(allDescriptor) {
            let sessionsWithData = allSessions.filter { $0.chatSessionData != nil }
            if sessionsWithData.count > 20 {
                for oldSession in sessionsWithData.dropFirst(20) {
                    // chatSessionDataのみnilにする（セッション・診断結果は保持）
                    oldSession.chatSessionData = nil
                }
            }
        }
    }

    @MainActor
    private func saveResult(_ result: AnalysisResult, to storedSession: StoredChatSession) async {
        // 詳細統計とRaw ValuesをJSONエンコード
        let detailedStatsData = try? JSONEncoder().encode(result.detailedStatistics)
        let balanceRawData = try? JSONEncoder().encode(result.axisScore.balanceRawValues)
        let tensionRawData = try? JSONEncoder().encode(result.axisScore.tensionRawValues)
        let responseRawData = try? JSONEncoder().encode(result.axisScore.responseRawValues)
        let wordRawData = try? JSONEncoder().encode(result.axisScore.wordRawValues)
        let memberScoresData = try? JSONEncoder().encode(result.memberScores)
        let replyStyleProfilesData = try? JSONEncoder().encode(result.replyStyleProfiles)

        // 結果を保存（sessionIdはstoredSessionのIDを使用）
        let storedResult = StoredAnalysisResult(
            id: result.id,
            sessionId: storedSession.id,
            period: result.period.rawValue,
            balanceScore: result.axisScore.balanceScore,
            tensionScore: result.axisScore.tensionScore,
            responseScore: result.axisScore.responseScore,
            wordScore: result.axisScore.wordScore,
            confidence: result.axisScore.confidence,
            selfParticipant: result.selfParticipant,
            partnerParticipant: result.partnerParticipant,
            analyzedAt: result.analyzedAt,
            totalMessages: result.totalMessages,
            totalBlocks: result.totalBlocks,
            analyzedDays: result.analyzedDays,
            firstMessageDate: result.firstMessageDate,
            lastMessageDate: result.lastMessageDate,
            detailedStatisticsData: detailedStatsData,
            balanceRawValuesData: balanceRawData,
            tensionRawValuesData: tensionRawData,
            responseRawValuesData: responseRawData,
            wordRawValuesData: wordRawData,
            memberScoresData: memberScoresData,
            groupParticipantNames: result.groupParticipantNames,
            replyStyleProfilesData: replyStyleProfilesData
        )

        storedResult.session = storedSession
        modelContext.insert(storedResult)

        try? modelContext.save()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AnalyzingView(
            session: ChatSession(
                title: "テスト",
                messages: [],
                participants: [
                    ChatParticipant(name: "田中さん", messageCount: 150),
                    ChatParticipant(name: "自分", messageCount: 100)
                ]
            ),
            selfName: "自分"
        )
    }
    .environmentObject(AppCoordinator())
}
