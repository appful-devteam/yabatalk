import Foundation
import SwiftUI
import SwiftData
import UIKit

// MARK: - Persona Chat ViewModel
@MainActor
final class PersonaChatViewModel: ObservableObject {
    @Published var chat: PersonaChat
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var showTypingIndicator: Bool = false
    @Published var errorMessage: String?
    @Published var isChatActive: Bool = false
    @Published var showSettings: Bool = false
    @Published var showLimitReached: Bool = false
    /// 人物像カード生成中フラグ。trueの間はチャット入力をブロックしてオーバーレイを出す。
    @Published var isGeneratingPersonaCard: Bool = false
    /// 学習に使えるメッセージ件数(UI表示用)
    @Published var partnerMessageCount: Int = 0
    /// 学習データが利用可能か。trueでも数件しかない場合あり、`partnerMessageCount`と併用。
    @Published var hasLearningData: Bool = false

    private let limitManager = PersonaChatLimitManager.shared

    var needsSetup: Bool {
        !chat.isConfigured
    }

    private let sessionId: UUID
    private let analysisResult: AnalysisResult
    private let chatSession: ChatSession?
    private let service = PersonaChatService.shared
    private let notificationService = PersonaNotificationService.shared

    // Cached data
    private var partnerMessages: [ChatMessage] = []
    private var allMessages: [ChatMessage] = []
    private var selfName: String = ""
    private var replyStyle: ReplyStyleProfile?

    // Reply timing distribution (from actual chat data, in seconds)
    private var replyP25: TimeInterval = 30
    private var replyMedian: TimeInterval = 120
    private var replyP75: TimeInterval = 600

    // Proactive message timer
    private var proactiveTask: Task<Void, Never>?
    // Pending response task (for delayed delivery)
    private var pendingResponseTask: Task<Void, Never>?
    // Background execution token
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    init(sessionId: UUID, partnerName: String, analysisResult: AnalysisResult, chatSession: ChatSession?) {
        self.sessionId = sessionId
        self.analysisResult = analysisResult
        self.chatSession = chatSession

        if let existing = Self.loadChat(sessionId: sessionId) {
            self.chat = existing
        } else {
            self.chat = PersonaChat(sessionId: sessionId, partnerName: partnerName)
        }

        prepareData()
    }

    // MARK: - Setup

    private func prepareData() {
        selfName = analysisResult.selfParticipant

        if let session = chatSession {
            allMessages = session.messages
            // partnerName が単一参加者と一致する場合は厳密フィルタ。
            // グループチャットでは partnerName が「A・B・C」のような連結文字列になり
            // どの senderName とも一致しないため、フォールバックで「自分以外」を使う。
            let partnerName = chat.partnerName
            let strict = session.messages.filter {
                $0.senderName == partnerName && $0.eventType == .text
            }
            if strict.count >= 5 {
                partnerMessages = strict
            } else {
                partnerMessages = session.messages.filter {
                    $0.senderName != selfName && $0.eventType == .text
                }
            }
            print("[PersonaChat] prepareData self=\(selfName) partner=\(partnerName) all=\(allMessages.count) partnerMsgs=\(partnerMessages.count) strictMatched=\(strict.count)")
        } else {
            print("[PersonaChat] ⚠️ prepareData: chatSession is nil — トーク履歴データが消失している可能性。再インポートが必要")
        }
        // UI公開用の学習統計を更新
        partnerMessageCount = partnerMessages.count
        hasLearningData = partnerMessages.count >= 5

        replyStyle = analysisResult.replyStyleProfiles?.partnerStyle

        // 実際の返信速度分布を取得（P25 < median < P75 を保証）
        let rawValues = analysisResult.axisScore.responseRawValues
        let rawMedian = max(rawValues.partnerReplyMedian, 5)
        let rawP25 = max(rawValues.partnerReplyP25 ?? rawMedian * 0.4, 3)
        let rawP75 = max(rawValues.partnerReplyP75 ?? rawMedian * 2.5, 10)
        replyP25 = min(rawP25, rawMedian - 1)
        replyMedian = rawMedian
        replyP75 = max(rawP75, rawMedian + 1)

        // PersonaChatに分布を保存（バックグラウンドでも使えるように）
        chat.replyTiming = ReplyTimingDistribution(p25: replyP25, median: replyMedian, p75: replyP75)

        chat.markAllRead()
        saveChat()
    }

    // MARK: - Default User Call Name (from analysis data)

    var defaultUserCallName: String {
        replyStyle?.preferredAddressing ?? selfName
    }

    // MARK: - Learning Stats (UIで「ちゃんと学習してる」かを可視化するための要約)

    /// 学習に使った文体特徴の要約。settingsシートに表示する。
    var learningStyleSummary: PersonaLearningSummary {
        guard let s = replyStyle else {
            return PersonaLearningSummary(
                messageCount: partnerMessageCount,
                firstPerson: nil,
                topEndings: [],
                topEmojis: [],
                emojiUse: false,
                politenessLabel: nil,
                medianLength: nil
            )
        }
        let topEndings = s.endingDistribution
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        let topEmojis = s.emojiTop.prefix(8).map { $0 }
        let politeness = s.politenessRatio > 0.5 ? "敬語多め" :
                         s.politenessRatio > 0.1 ? "敬語タメ口混在" : "タメ口中心"
        return PersonaLearningSummary(
            messageCount: partnerMessageCount,
            firstPerson: s.preferredFirstPerson,
            topEndings: Array(topEndings),
            topEmojis: Array(topEmojis),
            emojiUse: s.emojiUse,
            politenessLabel: politeness,
            medianLength: s.medianLength
        )
    }

    // MARK: - Persona Card

    /// PersonaCard が無い / プロンプト世代が古い場合に同期生成。
    /// 既に最新版があれば即返る。`isGeneratingPersonaCard` でUIブロック。
    func ensurePersonaCard() async {
        if let card = chat.personaCard,
           card.promptVersion == PersonaCard.currentPromptVersion {
            return
        }
        await runPersonaCardGeneration()
    }

    /// ユーザー操作による明示的な再生成。
    func regeneratePersonaCard() async {
        await runPersonaCardGeneration()
    }

    private func runPersonaCardGeneration() async {
        // 元データが薄すぎる場合は生成しない(LLMは一般論で返す状態になる)。
        // データなしのケースは PersonaLearningEmptyOverlay で UI 側が案内するので
        // ここではアラートを出さずサイレントに return する(ダブル表示防止)。
        guard partnerMessages.count >= 5 else {
            print("[PersonaChat] ⚠️ ペルソナカード生成スキップ: 学習対象メッセージが\(partnerMessages.count)件しかない (5件未満)")
            return
        }
        guard !isGeneratingPersonaCard else { return }

        isGeneratingPersonaCard = true
        defer { isGeneratingPersonaCard = false }

        do {
            let card = try await service.generatePersonaCard(
                partnerName: chat.partnerName,
                selfName: selfName,
                partnerMessages: partnerMessages,
                allMessages: allMessages,
                replyStyle: replyStyle
            )
            chat.personaCard = card
            saveChat()
        } catch {
            print("[PersonaChat] Card generation failed: \(error)")
            // 失敗してもチャット自体は続行可能(カードなしのフォールバックプロンプトで動く)
        }
    }

    // MARK: - Settings

    func applySettings(_ settings: PersonaChatSettings, userCallName: String) {
        chat.settings = settings
        chat.userCallName = userCallName
        saveChat()
        if settings.notifications {
            requestNotificationPermission()
        }
        // 初回設定完了 → ペルソナカードを同期生成してから自発メッセージを開始
        Task { @MainActor in
            await ensurePersonaCard()
            if isChatActive && settings.proactiveMessages {
                scheduleProactiveMessage()
            }
        }
    }

    func updateSettings(_ settings: PersonaChatSettings, userCallName: String) {
        chat.settings = settings
        chat.userCallName = userCallName.isEmpty ? nil : userCallName
        saveChat()
        if settings.notifications {
            requestNotificationPermission()
        }
        if isChatActive {
            proactiveTask?.cancel()
            if settings.proactiveMessages {
                scheduleProactiveMessage()
            }
        }
    }

    // MARK: - Chat Lifecycle

    func onChatAppear() {
        isChatActive = true
        // バックグラウンドで保存されたメッセージを反映
        reloadChatFromStorage()
        chat.markAllRead()
        chat.lastUserActivityAt = Date()
        saveChat()
        notificationService.cancelScheduledMessages(for: chat.sessionId)
        requestNotificationPermission()
        // 既存チャットでカード未生成 / プロンプト世代が古い場合は同期生成。
        // 新規セットアップ直後は applySettings 側で先に走るのでここはスキップされる。
        Task { @MainActor in
            if chat.isConfigured {
                await ensurePersonaCard()
            }
            if isChatActive && chat.resolvedSettings.proactiveMessages {
                scheduleProactiveMessage()
            }
        }
    }

    /// UserDefaultsから最新のチャットデータを再読み込み
    private func reloadChatFromStorage() {
        if let stored = Self.loadChat(sessionId: sessionId),
           stored.messages.count > chat.messages.count {
            chat = stored
        }
    }

    func onChatDisappear() {
        isChatActive = false
        showTypingIndicator = false
        proactiveTask?.cancel()
        proactiveTask = nil

        // 返信生成中ならバックグラウンド実行時間を確保（最大30秒）
        if isLoading {
            beginBackgroundTask()
        } else {
            // 生成中でなければタスクをキャンセルしてリソース解放
            pendingResponseTask?.cancel()
            pendingResponseTask = nil
        }

        scheduleBackgroundMessages()
        // 通知はBGタスクが実際にメッセージ生成した時のみ送信（PersonaBackgroundService側で処理）
    }

    // MARK: - Background Execution

    private func beginBackgroundTask() {
        guard backgroundTaskId == .invalid else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }

    private func requestNotificationPermission() {
        Task {
            _ = await notificationService.requestPermissionIfNeeded()
        }
    }

    // MARK: - Reply Delay (distribution-based)

    /// 実際のP25/median/P75分布に基づいてリアルなばらつきのある遅延を生成
    /// IQR（四分位範囲）内に50%、外側に各25%の確率で分布する
    /// 安全なレンジを生成（lower > upper の場合を防止）
    private func safeRange(_ lower: TimeInterval, _ upper: TimeInterval) -> ClosedRange<TimeInterval> {
        let lo = min(lower, upper)
        let hi = max(lower, upper, lo + 0.1)
        return lo...hi
    }

    private func generateRealtimeDelay() -> TimeInterval {
        let u = Double.random(in: 0...1)

        if u < 0.10 {
            // 10%: 超速返信（P25の半分〜P25）
            return TimeInterval.random(in: safeRange(max(replyP25 * 0.5, 3), replyP25))
        } else if u < 0.35 {
            // 25%: やや速い（P25〜median）
            return TimeInterval.random(in: safeRange(replyP25, replyMedian))
        } else if u < 0.65 {
            // 30%: 中央付近（median ± IQRの20%）
            let iqr = replyP75 - replyP25
            let lo = max(replyMedian - iqr * 0.2, replyP25)
            let hi = min(replyMedian + iqr * 0.2, replyP75)
            return TimeInterval.random(in: safeRange(lo, hi))
        } else if u < 0.90 {
            // 25%: やや遅い（median〜P75）
            return TimeInterval.random(in: safeRange(replyMedian, replyP75))
        } else {
            // 10%: 遅め（P75〜P75×1.5、最大30分）
            return TimeInterval.random(in: safeRange(replyP75, min(replyP75 * 1.5, 1800)))
        }
    }

    /// 設定に応じた返信遅延を生成
    private func generateReplyDelay() -> TimeInterval {
        switch chat.resolvedSettings.replySpeed {
        case .instant:
            return TimeInterval.random(in: 1...3)
        case .fast:
            // リアルの0.5倍速
            return max(generateRealtimeDelay() * 0.5, 2)
        case .realtime:
            return generateRealtimeDelay()
        }
    }

    private func generateInterMessageDelay() -> TimeInterval {
        TimeInterval.random(in: 0.8...2.5)
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // 日次制限チェック
        guard limitManager.canSendMessage() else {
            AnalyticsManager.shared.limitReached(
                feature: .personaChat,
                isSubscribed: SubscriptionManager.shared.isSubscribed
            )
            showLimitReached = true
            return
        }

        inputText = ""
        proactiveTask?.cancel()

        // 返信待ち中に連続送信 → 前の生成をキャンセル
        if isLoading {
            pendingResponseTask?.cancel()
            showTypingIndicator = false
        }

        let userMessage = PersonaChatMessage(role: .user, text: text)
        chat.appendMessage(userMessage)
        chat.lastUserActivityAt = Date()
        saveChat()

        AnalyticsManager.shared.personaChatSent(
            isSubscribed: SubscriptionManager.shared.isSubscribed
        )

        isLoading = true
        errorMessage = nil

        let isInstant = chat.resolvedSettings.replySpeed == .instant
        if isInstant {
            showTypingIndicator = true
        }

        pendingResponseTask = Task {
            do {
                let responses = try await service.generateResponse(
                    chat: chat,
                    userMessage: text,
                    partnerMessages: partnerMessages,
                    allMessages: allMessages,
                    replyStyle: replyStyle,
                    selfName: selfName,
                    relationshipType: chat.resolvedSettings.relationshipType
                )

                let delay = generateReplyDelay()

                if isChatActive {
                    if !isInstant {
                        // リアル/早め: 遅延の大半を待ってからタイピング表示
                        let typingLeadTime = min(TimeInterval.random(in: 2...5), delay * 0.3)
                        let waitBeforeTyping = delay - typingLeadTime
                        try await Task.sleep(nanoseconds: UInt64(waitBeforeTyping * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        if isChatActive { showTypingIndicator = true }
                        try await Task.sleep(nanoseconds: UInt64(typingLeadTime * 1_000_000_000))
                    } else {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
                // 画面を離れた場合は遅延をスキップして即座に返信を保存
                guard !Task.isCancelled else { return }

                for (index, responseText) in responses.enumerated() {
                    if index > 0 && isChatActive {
                        showTypingIndicator = true
                        let interDelay = generateInterMessageDelay()
                        try await Task.sleep(nanoseconds: UInt64(interDelay * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                    }

                    showTypingIndicator = false
                    let isLastMessage = index == responses.count - 1
                    let personaMessage = PersonaChatMessage(
                        role: .persona,
                        text: responseText,
                        isRead: isChatActive
                    )
                    chat.appendMessage(personaMessage)
                    saveChat()

                    // 画面を離れている & 最後のメッセージ → 通知を送る
                    if !isChatActive && isLastMessage && chat.resolvedSettings.notifications {
                        print("[PersonaChat] Sending notification (isChatActive=\(isChatActive), notifications=\(chat.resolvedSettings.notifications))")
                        notificationService.sendImmediateNotification(for: chat, messageText: responseText)
                    }
                }

                isLoading = false
                limitManager.recordMessage()
                endBackgroundTask()
                if isChatActive && chat.resolvedSettings.proactiveMessages {
                    scheduleProactiveMessage()
                }
            } catch is CancellationError {
                isLoading = false
                showTypingIndicator = false
                endBackgroundTask()
            } catch {
                isLoading = false
                showTypingIndicator = false
                endBackgroundTask()
                print("[PersonaChat] Response error: \(error)")
                errorMessage = String(localized: "メッセージの生成に失敗しました", bundle: LanguageManager.appBundle) + "\n(\(error.localizedDescription))"
            }
        }
    }

    // MARK: - Proactive Messages (in-app)

    private func scheduleProactiveMessage() {
        proactiveTask?.cancel()
        guard chat.isConfigured else { return }
        guard chat.resolvedSettings.proactiveMessages else { return }
        guard !chat.isProactiveTimedOut else { return }

        let delay: TimeInterval
        if chat.messages.isEmpty {
            // 初回は短い遅延で相手から話しかける
            delay = TimeInterval.random(in: 3...8)
        } else if let timing = chat.replyTiming {
            // 実際の返信分布ベースでプロアクティブ間隔を決定
            delay = timing.generateProactiveDelay()
        } else {
            delay = TimeInterval.random(in: 180...1800)
        }

        proactiveTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled, isChatActive, !isLoading else { return }
                await deliverProactiveMessage()
            } catch {
                // Cancelled
            }
        }
    }

    private func deliverProactiveMessage() async {
        guard limitManager.canSendMessage() else { return }
        guard !chat.isProactiveTimedOut else { return }
        isLoading = true

        do {
            let responses = try await service.generateProactiveMessage(
                chat: chat,
                partnerMessages: partnerMessages,
                allMessages: allMessages,
                replyStyle: replyStyle,
                selfName: selfName,
                relationshipType: chat.resolvedSettings.relationshipType
            )

            // プロアクティブはタイピング表示してから少し待って送信
            showTypingIndicator = true
            let typingDuration = TimeInterval.random(in: 1.5...4)
            try? await Task.sleep(nanoseconds: UInt64(typingDuration * 1_000_000_000))

            for (index, responseText) in responses.enumerated() {
                if index > 0 {
                    showTypingIndicator = true
                    let interDelay = generateInterMessageDelay()
                    try await Task.sleep(nanoseconds: UInt64(interDelay * 1_000_000_000))
                    guard !Task.isCancelled else { break }
                }

                showTypingIndicator = false
                let personaMessage = PersonaChatMessage(role: .persona, text: responseText)
                chat.appendMessage(personaMessage)
                if isChatActive { chat.markAllRead() }
                saveChat()
            }

            limitManager.recordMessage()
            scheduleProactiveMessage()
        } catch {
            // Silent fail
        }

        isLoading = false
    }

    // MARK: - Handle Proactive Message (from notification / background)

    func generateProactiveMessage() async {
        guard !isLoading else { return }
        guard chat.resolvedSettings.proactiveMessages else { return }
        guard !chat.isProactiveTimedOut else { return }
        guard limitManager.canSendMessage() else { return }
        isLoading = true

        do {
            let responses = try await service.generateProactiveMessage(
                chat: chat,
                partnerMessages: partnerMessages,
                allMessages: allMessages,
                replyStyle: replyStyle,
                selfName: selfName,
                relationshipType: chat.resolvedSettings.relationshipType
            )

            for responseText in responses {
                let personaMessage = PersonaChatMessage(role: .persona, text: responseText, isRead: false)
                chat.appendMessage(personaMessage)
            }
            saveChat()
            limitManager.recordMessage()

            if chat.resolvedSettings.notifications, let lastText = responses.last {
                notificationService.sendImmediateNotification(for: chat, messageText: lastText)
            }
        } catch {
            // Silent fail
        }
        isLoading = false
    }

    // MARK: - Persistence

    private static let storageKey = "persona_chats"

    /// メッセージ上限数（UserDefaults肥大化防止）
    private static let maxMessagesPerChat = 500

    func saveChat() {
        // メッセージ数が上限を超えていたら古いメッセージを削除
        if chat.messages.count > Self.maxMessagesPerChat {
            chat.messages = Array(chat.messages.suffix(Self.maxMessagesPerChat))
        }
        var allChats = Self.loadAllChats()
        allChats[chat.sessionId.uuidString] = chat
        if let data = try? JSONEncoder().encode(allChats) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func loadChat(sessionId: UUID) -> PersonaChat? {
        loadAllChats()[sessionId.uuidString]
    }

    static func loadAllChats() -> [String: PersonaChat] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let chats = try? JSONDecoder().decode([String: PersonaChat].self, from: data) else {
            return [:]
        }
        return chats
    }

    static func hasUnread(sessionId: UUID) -> Bool {
        loadChat(sessionId: sessionId)?.hasUnread ?? false
    }

    static func unreadCount(sessionId: UUID) -> Int {
        loadChat(sessionId: sessionId)?.unreadCount ?? 0
    }

    // MARK: - Delete Chat

    func clearChat() {
        proactiveTask?.cancel()
        pendingResponseTask?.cancel()
        chat.messages.removeAll()
        chat.lastMessageAt = nil
        saveChat()
        PersonaNotificationService.shared.cancelScheduledMessages(for: chat.sessionId)
    }

    static func deleteChat(sessionId: UUID) {
        var allChats = loadAllChats()
        allChats.removeValue(forKey: sessionId.uuidString)
        if let data = try? JSONEncoder().encode(allChats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        PersonaNotificationService.shared.cancelScheduledMessages(for: sessionId)
    }

    // MARK: - Background Scheduling

    func scheduleBackgroundMessages() {
        PersonaBackgroundService.shared.scheduleBackgroundTask()
    }
}
