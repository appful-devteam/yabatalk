import Foundation
import SwiftData

@MainActor
final class ReplySuggestionViewModel: ObservableObject {
    // MARK: - Session Management
    @Published var sessions: [ReplySession] = []
    @Published var currentSession: ReplySession?
    @Published var viewingSessionId: UUID?
    @Published var showSidebar = false
    @Published var showReviewOverlay = false
    @Published var reviewRating: Int = 0
    @Published var selectedReviewReasons: Set<String> = []

    // MARK: - Chat State
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Consultation State
    @Published var consultationContext = ConsultationContext()
    @Published var currentQuickOptions: [QuickOption] = []
    @Published var showToneSettings = false

    // MARK: - Limit State
    @Published var isLimitReached = false
    @Published var limitReachedReason = ""
    @Published var showSubscriptionSheet = false
    private var hasRecordedSessionStart = false
    private var pendingRetryAfterUpgrade = false

    // MARK: - Computed Properties

    var entries: [ReplyChatEntry] {
        if let vid = viewingSessionId,
           let s = sessions.first(where: { $0.id == vid }) {
            return s.entries
        }
        return currentSession?.entries ?? []
    }

    var isViewingHistory: Bool { viewingSessionId != nil }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var consultationPartnerDisplayName: String? {
        let trimmed = partnerName.trimmed
        return trimmed.isEmpty ? nil : trimmed
    }

    var consultationPartnerSessionId: UUID? {
        analysisResult?.sessionId ?? session?.id
    }

    // MARK: - Private State

    private var session: ChatSession?
    private var selfName: String
    private var partnerName: String
    private var analysisResult: AnalysisResult?
    private var resultId: UUID?

    private let suggestionService = ReplySuggestionService.shared
    private let consultationLimitManager = ConsultationLimitManager.shared
    private let subscriptionManager = SubscriptionManager.shared
    private static let maxHistoryEntries = 50
    private static let maxSessions = 20

    var currentTier: SubscriptionTier {
        subscriptionManager.currentTier
    }

    var remainingRalliesText: String? {
        let tier = currentTier
        guard tier != .premiumPlus else { return nil }
        if let remaining = consultationLimitManager.remainingRallies(tier: tier),
           let max = consultationLimitManager.maxRallies(tier: tier) {
            return "\(remaining)/\(max)"
        }
        return nil
    }

    var remainingSessionsText: String? {
        let tier = currentTier
        guard tier != .premiumPlus else { return nil }
        if let remaining = consultationLimitManager.remainingSessions(tier: tier),
           let max = consultationLimitManager.maxSessions(tier: tier) {
            return "\(remaining)/\(max)"
        }
        return nil
    }

    // MARK: - Init

    init(session: ChatSession?, selfName: String, partnerName: String, analysisResult: AnalysisResult? = nil, resultId: UUID? = nil) {
        self.session = session
        self.selfName = selfName
        self.partnerName = partnerName
        self.analysisResult = analysisResult
        self.resultId = resultId ?? analysisResult?.id

        loadSessions()
        if sessions.isEmpty {
            migrateFromFlatHistory()
        }

        startNewSession()
    }

    func updateContext(session: ChatSession?, selfName: String, partnerName: String, analysisResult: AnalysisResult? = nil) {
        self.session = session
        self.selfName = selfName
        self.partnerName = partnerName
        self.analysisResult = analysisResult
        if resultId == nil { resultId = analysisResult?.id }
    }

    // MARK: - Session Lifecycle

    /// ユーザーメッセージがあるアクティブセッションかどうか
    var hasActiveSessionWithMessages: Bool {
        guard let session = currentSession else { return false }
        return session.entries.contains(where: { $0.role == .user })
    }

    func startNewSession() {
        if let current = currentSession, current.entries.filter({ $0.role == .user }).isEmpty {
            resetUIForNewSession()
            return
        }

        autoSaveCurrentSessionIfNeeded()

        viewingSessionId = nil
        showReviewOverlay = false

        consultationContext = ConsultationContext()
        let options = QuickOption.relationshipTypeOptions
        currentQuickOptions = options

        let trimmedPartner = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greetingText: String
        if trimmedPartner.isEmpty {
            greetingText = String(localized: "やっほー！めろまるだよ✨\nどんな関係の人のことで相談したい？", bundle: LanguageManager.appBundle)
        } else {
            let template = String(localized: "やっほー！めろまるだよ✨\n%@さんについてのお話だね。どんな関係の人か教えてくれる？", bundle: LanguageManager.appBundle)
            greetingText = String(format: template, trimmedPartner)
        }
        let greeting = ReplyChatEntry(
            role: .assistant,
            text: greetingText,
            quickOptions: options
        )
        currentSession = ReplySession(
            entries: [greeting],
            consultationContext: ConsultationContext()
        )
        resetUIForNewSession()
    }

    func endCurrentSession() {
        reviewRating = 0
        selectedReviewReasons = []
        showReviewOverlay = true
    }

    func submitReview() {
        if let viewedId = viewingSessionId {
            // 過去セッションのレビュー
            submitReviewForViewedSession(viewedId)
        } else {
            // 現在セッションのレビュー
            submitReviewForCurrentSession()
        }
    }

    private func submitReviewForCurrentSession() {
        guard var session = currentSession else { return }
        session.status = .completed
        session.rating = reviewRating > 0 ? reviewRating : nil
        session.ratingReasons = selectedReviewReasons.isEmpty ? nil : Array(selectedReviewReasons)
        session.updateTitleFromFirstMessage()

        sessions.insert(session, at: 0)
        if sessions.count > Self.maxSessions {
            sessions = Array(sessions.prefix(Self.maxSessions))
        }
        saveSessions()

        showReviewOverlay = false

        let tone = consultationContext.tone.rawValue
        let length = consultationContext.length.rawValue
        Task {
            await AppDataFirestoreService.shared.recordSessionReview(
                sessionId: session.id.uuidString,
                rating: session.rating ?? 0,
                reasons: session.ratingReasons ?? [],
                entryCount: session.entries.count,
                toneSetting: tone,
                lengthSetting: length
            )
        }

        startNewSession()
    }

    private func submitReviewForViewedSession(_ sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        sessions[index].rating = reviewRating > 0 ? reviewRating : nil
        sessions[index].ratingReasons = selectedReviewReasons.isEmpty ? nil : Array(selectedReviewReasons)
        saveSessions()

        showReviewOverlay = false

        let session = sessions[index]
        let tone = session.consultationContext?.tone.rawValue ?? ""
        let length = session.consultationContext?.length.rawValue ?? ""
        Task {
            await AppDataFirestoreService.shared.recordSessionReview(
                sessionId: session.id.uuidString,
                rating: session.rating ?? 0,
                reasons: session.ratingReasons ?? [],
                entryCount: session.entries.count,
                toneSetting: tone,
                lengthSetting: length
            )
        }
    }

    func skipReview() {
        if viewingSessionId != nil {
            // 過去セッション閲覧中はオーバーレイを閉じるだけ
            showReviewOverlay = false
        } else {
            // 現在セッション: 保存して新しいセッション開始
            guard var session = currentSession else { return }
            session.status = .completed
            session.updateTitleFromFirstMessage()

            sessions.insert(session, at: 0)
            if sessions.count > Self.maxSessions {
                sessions = Array(sessions.prefix(Self.maxSessions))
            }
            saveSessions()

            showReviewOverlay = false
            startNewSession()
        }
    }

    func viewSession(_ id: UUID) {
        viewingSessionId = id
        showSidebar = false

        // 未レビューのセッションはレビューオーバーレイを表示
        if let session = sessions.first(where: { $0.id == id }),
           session.rating == nil,
           session.entries.contains(where: { $0.role == .user }) {
            reviewRating = 0
            selectedReviewReasons = []
            showReviewOverlay = true
        }
    }

    func exitHistoryView() {
        viewingSessionId = nil
        showReviewOverlay = false
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if viewingSessionId == id {
            viewingSessionId = nil
        }
        saveSessions()
    }

    func toggleSidebar() {
        showSidebar.toggle()
    }

    // MARK: - Quick Option Selection

    func selectQuickOption(_ option: QuickOption) {
        currentSession?.entries.append(ReplyChatEntry(role: .user, text: option.label))
        currentQuickOptions = []

        switch consultationContext.phase {
        case .selectRelationshipType:
            consultationContext.relationshipType = ConsultationRelationshipType(rawValue: option.value)
            consultationContext.phase = .selectProblemCategory
            currentSession?.consultationContext = consultationContext

            let problemOpts = QuickOption.problemOptions(for: consultationContext.relationshipType!)
            let response = ReplyChatEntry(
                role: .assistant,
                text: String(localized: "\(consultationContext.relationshipType!.emoji) \(consultationContext.relationshipType!.displayName)の相手なんだね！\nどんなことで悩んでる？💭", bundle: LanguageManager.appBundle),
                quickOptions: problemOpts
            )
            currentSession?.entries.append(response)
            currentQuickOptions = problemOpts

        case .selectProblemCategory:
            consultationContext.problemCategory = ConsultationProblemCategory(rawValue: option.value)
            consultationContext.phase = .gathering
            currentSession?.consultationContext = consultationContext
            Task { await sendConsultationMessage() }

        default:
            break
        }

        saveCurrentSession()
    }

    // MARK: - Send Message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        currentQuickOptions = []

        currentSession?.entries.append(ReplyChatEntry(role: .user, text: text))
        currentSession?.updateTitleFromFirstMessage()

        // session=nil は「とりあえず話す」フローなので、履歴ベースのヒントなしで AI を呼ぶ。
        // session がある場合のみグループトーク制限をかける。
        if let session, !session.isOneOnOne {
            currentSession?.entries.append(
                ReplyChatEntry(
                    role: .assistant,
                    text: String(localized: "相談は1対1トークのみ対応しています。", bundle: LanguageManager.appBundle)
                )
            )
            saveCurrentSession()
            return
        }

        if consultationContext.phase == .selectRelationshipType
            || consultationContext.phase == .selectProblemCategory {
            consultationContext.phase = .gathering
            currentSession?.consultationContext = consultationContext
        }

        await sendConsultationMessage()
        saveCurrentSession()
    }

    // MARK: - Consultation AI Call

    private func sendConsultationMessage() async {
        let tier = currentTier

        if !hasRecordedSessionStart {
            guard consultationLimitManager.canStartSession(tier: tier) else {
                limitReachedReason = consultationLimitManager.limitDescription(tier: tier)
                isLimitReached = true
                pendingRetryAfterUpgrade = true
                showLimitMessage()
                return
            }
            consultationLimitManager.recordSessionStart(tier: tier)
            hasRecordedSessionStart = true
        }

        guard consultationLimitManager.canSendRally(tier: tier) else {
            limitReachedReason = consultationLimitManager.limitDescription(tier: tier)
            isLimitReached = true
            pendingRetryAfterUpgrade = true
            showLimitMessage()
            return
        }

        isLoading = true
        defer { isLoading = false }

        // session=nil でも AI 呼び出しを実行する(「とりあえず話す」フロー)
        do {
            let response = try await suggestionService.consultationChat(
                session: session,
                selfName: selfName,
                partnerName: partnerName,
                analysisResult: analysisResult,
                consultationContext: consultationContext,
                chatHistory: currentSession?.entries ?? []
            )
            currentSession?.entries.append(ReplyChatEntry(role: .assistant, text: response))

            consultationLimitManager.recordRally(tier: tier)

            AnalyticsManager.shared.aiConsultationSent(
                isSubscribed: tier != .free,
                freeRemaining: consultationLimitManager.remainingRallies(tier: tier)
            )

            if consultationContext.phase == .gathering {
                consultationContext.gatheringTurns += 1
                if consultationContext.gatheringTurns >= 2 {
                    consultationContext.phase = .advising
                }
                currentSession?.consultationContext = consultationContext
            }

        } catch {
            currentSession?.entries.append(
                ReplyChatEntry(role: .assistant, text: String(localized: "うまく返事できなかった…もう一度試してみて💦", bundle: LanguageManager.appBundle))
            )
        }

        saveCurrentSession()
    }

    private func showLimitMessage() {
        let tier = currentTier
        let upgradeText: String
        switch tier {
        case .free:
            upgradeText = String(localized: "Premiumにアップグレードすると、毎日相談できるよ！✨", bundle: LanguageManager.appBundle)
        case .premium:
            upgradeText = String(localized: "Premium+にアップグレードすると、無制限で相談できるよ！✨", bundle: LanguageManager.appBundle)
        case .premiumPlus:
            return
        }
        currentSession?.entries.append(
            ReplyChatEntry(role: .assistant, text: "\(limitReachedReason)\n\n\(upgradeText)")
        )
        saveCurrentSession()
    }

    /// 課金完了後にリトライ（制限メッセージを削除してリクエストを再送信）
    func retryAfterUpgradeIfNeeded() {
        guard pendingRetryAfterUpgrade else { return }
        pendingRetryAfterUpgrade = false

        let tier = currentTier
        guard consultationLimitManager.canSendRally(tier: tier) else { return }

        // 制限到達時に追加されたアシスタントメッセージを削除
        if let lastEntry = currentSession?.entries.last,
           lastEntry.role == .assistant {
            currentSession?.entries.removeLast()
        }

        isLimitReached = false
        limitReachedReason = ""

        Task {
            await sendConsultationMessage()
            saveCurrentSession()
        }
    }

    // MARK: - Session Persistence

    private func loadSessions() {
        guard let rid = resultId else {
            // resultId が無い (= 「とりあえず話す」) は UserDefaults から読む
            loadGeneralSessions()
            return
        }

        let context = SwiftDataContainer.shared.container.mainContext
        let targetId = rid
        let descriptor = FetchDescriptor<StoredAnalysisResult>(
            predicate: #Predicate { $0.id == targetId }
        )

        if let stored = try? context.fetch(descriptor).first,
           let storedSessions = stored.replySessions,
           !storedSessions.isEmpty {
            sessions = storedSessions
            return
        }

        guard let stored = try? context.fetch(descriptor).first else { return }
        let sameSessionId = stored.sessionId
        let allDescriptor = FetchDescriptor<StoredAnalysisResult>(
            predicate: #Predicate { $0.sessionId == sameSessionId },
            sortBy: [SortDescriptor(\.analyzedAt, order: .reverse)]
        )
        guard let allResults = try? context.fetch(allDescriptor) else { return }
        for result in allResults where result.id != rid {
            if let previousSessions = result.replySessions, !previousSessions.isEmpty {
                sessions = previousSessions
                saveSessions()
                return
            }
        }
    }

    func saveSessions() {
        guard let rid = resultId else {
            saveGeneralSessions()
            return
        }

        let context = SwiftDataContainer.shared.container.mainContext
        let targetId = rid
        let descriptor = FetchDescriptor<StoredAnalysisResult>(
            predicate: #Predicate { $0.id == targetId }
        )

        guard let stored = try? context.fetch(descriptor).first else { return }
        stored.replySessionsData = try? JSONEncoder().encode(sessions)
        try? context.save()
    }

    // MARK: - General Consultation Persistence (resultId == nil)

    private func loadGeneralSessions() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Constants.StorageKeys.generalConsultationSessions),
           let decoded = try? JSONDecoder().decode([ReplySession].self, from: data) {
            sessions = decoded
        }
    }

    private func saveGeneralSessions() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(sessions) {
            defaults.set(data, forKey: Constants.StorageKeys.generalConsultationSessions)
        }
    }

    func saveCurrentSession() {
        guard var session = currentSession else { return }

        if session.entries.count > Self.maxHistoryEntries {
            session.entries = Array(session.entries.suffix(Self.maxHistoryEntries))
            currentSession = session
        }

        saveHistoryLegacy()
    }

    private func migrateFromFlatHistory() {
        guard let rid = resultId else {
            // 「とりあえず話す」: UserDefaults の flat history を完了済みセッションとして移行
            migrateFromGeneralFlatHistory()
            return
        }

        let context = SwiftDataContainer.shared.container.mainContext
        let targetId = rid
        let descriptor = FetchDescriptor<StoredAnalysisResult>(
            predicate: #Predicate { $0.id == targetId }
        )

        guard let stored = try? context.fetch(descriptor).first,
              let history = stored.replyChatHistory,
              !history.isEmpty else {
            return
        }

        var migrated = ReplySession(
            entries: history,
            status: .completed
        )
        migrated.updateTitleFromFirstMessage()
        sessions.append(migrated)
        saveSessions()
    }

    /// 「とりあえず話す」用の crash-recovery flat history を完了済みセッションとして保存。
    private func migrateFromGeneralFlatHistory() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Constants.StorageKeys.generalConsultationCurrentEntries),
              let history = try? JSONDecoder().decode([ReplyChatEntry].self, from: data),
              history.contains(where: { $0.role == .user }) else {
            return
        }
        var migrated = ReplySession(entries: history, status: .completed)
        migrated.updateTitleFromFirstMessage()
        sessions.append(migrated)
        saveSessions()
        defaults.removeObject(forKey: Constants.StorageKeys.generalConsultationCurrentEntries)
    }

    // MARK: - Legacy Persistence

    private func saveHistoryLegacy() {
        let entriesToSave = currentSession?.entries ?? []
        var toSave = entriesToSave
        if toSave.count > Self.maxHistoryEntries {
            toSave = Array(toSave.suffix(Self.maxHistoryEntries))
        }

        guard let rid = resultId else {
            // 「とりあえず話す」: UserDefaults に flat history として保存 (クラッシュ復旧用)
            if let data = try? JSONEncoder().encode(toSave) {
                UserDefaults.standard.set(data, forKey: Constants.StorageKeys.generalConsultationCurrentEntries)
            }
            return
        }

        let context = SwiftDataContainer.shared.container.mainContext
        let targetId = rid
        let descriptor = FetchDescriptor<StoredAnalysisResult>(
            predicate: #Predicate { $0.id == targetId }
        )

        guard let stored = try? context.fetch(descriptor).first else { return }
        stored.replyChatHistoryData = try? JSONEncoder().encode(toSave)
        try? context.save()
    }

    // MARK: - Helpers

    private func autoSaveCurrentSessionIfNeeded() {
        guard var session = currentSession,
              session.entries.contains(where: { $0.role == .user }),
              session.status == .active else { return }
        guard !sessions.contains(where: { $0.id == session.id }) else { return }
        session.status = .completed
        session.updateTitleFromFirstMessage()
        sessions.insert(session, at: 0)
        if sessions.count > Self.maxSessions {
            sessions = Array(sessions.prefix(Self.maxSessions))
        }
        saveSessions()
    }

    private func resetUIForNewSession() {
        showToneSettings = false
        inputText = ""
        consultationContext = ConsultationContext()
        currentQuickOptions = QuickOption.relationshipTypeOptions
        hasRecordedSessionStart = false
        isLimitReached = false
        limitReachedReason = ""
    }
}
