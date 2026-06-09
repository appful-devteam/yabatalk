import Foundation
import SwiftData

// MARK: - Schema Versioning

/// 現在のスキーマ（V1）
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [StoredChatSession.self, StoredAnalysisResult.self, StoredMonthlySummary.self]
    }
}

/// マイグレーションプラン
enum LovetalkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

// MARK: - SwiftData Container Configuration
@MainActor
final class SwiftDataContainer {
    static let shared = SwiftDataContainer()

    let container: ModelContainer

    /// インメモリフォールバックで起動した場合 true（データ復旧の必要あり）
    private(set) var isRunningInMemory = false

    private init() {
        let schema = Schema([
            StoredChatSession.self,
            StoredAnalysisResult.self,
            StoredMonthlySummary.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        // 1. マイグレーションプラン付きで試行
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: LovetalkMigrationPlan.self,
                configurations: [configuration]
            )
            return
        } catch {
            print("[SwiftData] migrationPlan付き作成失敗: \(error)")
        }

        // 2. lightweight migration（マイグレーションプランなし）で再試行
        //    オプショナルフィールドの追加はこれで自動処理される
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            return
        } catch {
            print("[SwiftData] lightweight migration失敗: \(error)")
        }

        // 3. 最終手段: インメモリコンテナで起動（既存DBファイルには一切触れない）
        //    - クラッシュ無限ループを防止
        //    - 既存のDBファイルは保持されるため、次のアプリ更新で復旧の可能性を残す
        print("[SwiftData] ⚠️ インメモリモードで起動。既存データは次回更新時に復旧を試みます。")
        let inMemoryConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [inMemoryConfig]
            )
            isRunningInMemory = true
        } catch {
            // インメモリすら失敗する場合はスキーマ定義自体に問題がある
            // 空のコンテナを作成（モデルなし相当）して起動を保証
            print("[SwiftData] ❌ インメモリ作成も失敗: \(error)")
            container = try! ModelContainer(
                for: Schema([]),
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
            isRunningInMemory = true
        }
    }
}

// MARK: - Stored Chat Session
@Model
final class StoredChatSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var participantNames: [String]
    var messageCount: Int
    var importedAt: Date
    var firstMessageDate: Date?
    var lastMessageDate: Date?
    var relationshipSummary: String?

    // セッションデータ（サマリー生成用にメッセージを保持）
    @Attribute(.externalStorage) var chatSessionData: Data?

    // 関連する解析結果
    @Relationship(deleteRule: .cascade, inverse: \StoredAnalysisResult.session)
    var analysisResults: [StoredAnalysisResult]?
    
    // 関連する月ごとのサマリー
    @Relationship(deleteRule: .cascade, inverse: \StoredMonthlySummary.session)
    var monthlySummaries: [StoredMonthlySummary]?

    init(
        id: UUID = UUID(),
        title: String,
        participantNames: [String],
        messageCount: Int,
        importedAt: Date = Date(),
        firstMessageDate: Date? = nil,
        lastMessageDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.participantNames = participantNames
        self.messageCount = messageCount
        self.importedAt = importedAt
        self.firstMessageDate = firstMessageDate
        self.lastMessageDate = lastMessageDate
    }
}

// MARK: - Stored Analysis Result
@Model
final class StoredAnalysisResult {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var period: String
    var balanceScore: Double
    var tensionScore: Double
    var responseScore: Double
    var wordScore: Double
    var confidence: Double
    var selfParticipant: String
    var partnerParticipant: String
    var analyzedAt: Date
    var totalMessages: Int
    var totalBlocks: Int
    var analyzedDays: Int
    var firstMessageDate: Date?
    var lastMessageDate: Date?

    // 詳細統計（JSONエンコード）
    var detailedStatisticsData: Data?

    // Raw Values（JSONエンコード）
    var balanceRawValuesData: Data?
    var tensionRawValuesData: Data?
    var responseRawValuesData: Data?
    var wordRawValuesData: Data?

    // グループチャット関連（JSONエンコード）
    var memberScoresData: Data?
    // レガシー: 性格プロフィール (v2.0で廃止、スキーマ互換性のため保持)
    var personalityProfilesData: Data?
    var replyStyleProfilesData: Data?
    var groupParticipantNames: [String]?

    // 相談セッション（JSONエンコード）
    var replySessionsData: Data?
    var replyChatHistoryData: Data?

    // yabatalk: ハラスメント診断結果（DiagnosisResult を JSON エンコード）
    var diagnosisData: Data?

    // リレーション
    var session: StoredChatSession?

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        period: String,
        balanceScore: Double,
        tensionScore: Double,
        responseScore: Double,
        wordScore: Double,
        confidence: Double,
        selfParticipant: String,
        partnerParticipant: String,
        analyzedAt: Date = Date(),
        totalMessages: Int,
        totalBlocks: Int,
        analyzedDays: Int,
        firstMessageDate: Date? = nil,
        lastMessageDate: Date? = nil,
        detailedStatisticsData: Data? = nil,
        balanceRawValuesData: Data? = nil,
        tensionRawValuesData: Data? = nil,
        responseRawValuesData: Data? = nil,
        wordRawValuesData: Data? = nil,
        memberScoresData: Data? = nil,
        groupParticipantNames: [String]? = nil,
        replyStyleProfilesData: Data? = nil,
        diagnosisData: Data? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.period = period
        self.balanceScore = balanceScore
        self.tensionScore = tensionScore
        self.responseScore = responseScore
        self.wordScore = wordScore
        self.confidence = confidence
        self.selfParticipant = selfParticipant
        self.partnerParticipant = partnerParticipant
        self.analyzedAt = analyzedAt
        self.totalMessages = totalMessages
        self.totalBlocks = totalBlocks
        self.analyzedDays = analyzedDays
        self.firstMessageDate = firstMessageDate
        self.lastMessageDate = lastMessageDate
        self.detailedStatisticsData = detailedStatisticsData
        self.balanceRawValuesData = balanceRawValuesData
        self.tensionRawValuesData = tensionRawValuesData
        self.responseRawValuesData = responseRawValuesData
        self.wordRawValuesData = wordRawValuesData
        self.memberScoresData = memberScoresData
        self.replyStyleProfilesData = replyStyleProfilesData
        self.groupParticipantNames = groupParticipantNames
        self.diagnosisData = diagnosisData
    }

    // MARK: - Computed Properties

    /// 総合スコア
    var totalScore: Double {
        (balanceScore + tensionScore + responseScore + wordScore) / 4.0
    }

    /// yabatalk: ハラスメント診断結果（保存済みなら復元）
    var diagnosisResult: DiagnosisResult? {
        decodeJSON(DiagnosisResult.self, from: diagnosisData, label: "DiagnosisResult")
    }

    /// JSONデコードヘルパー（失敗時にログ出力）
    /// - 注意: 過去保存されたレコードで `null` が JSON 本体としてシリアライズされている
    ///   ケースがあるため (memberScores など)、リテラル "null" を nil として扱う。
    private func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data?, label: String) -> T? {
        guard let data = data else { return nil }
        // JSON の literal `null` (4 バイト "null") は nil として扱う
        if data.count == 4, String(data: data, encoding: .utf8) == "null" {
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("[SwiftData] \(label) デコード失敗 (id=\(id)): \(error)")
            return nil
        }
    }

    /// DetailedStatisticsを取得
    var detailedStatistics: DetailedStatistics? {
        decodeJSON(DetailedStatistics.self, from: detailedStatisticsData, label: "DetailedStatistics")
    }

    /// BalanceRawValuesを取得
    var balanceRawValues: BalanceRawValues? {
        decodeJSON(BalanceRawValues.self, from: balanceRawValuesData, label: "BalanceRawValues")
    }

    /// TensionRawValuesを取得
    var tensionRawValues: TensionRawValues? {
        decodeJSON(TensionRawValues.self, from: tensionRawValuesData, label: "TensionRawValues")
    }

    /// ResponseRawValuesを取得
    var responseRawValues: ResponseRawValues? {
        decodeJSON(ResponseRawValues.self, from: responseRawValuesData, label: "ResponseRawValues")
    }

    /// WordRawValuesを取得
    var wordRawValues: WordRawValues? {
        decodeJSON(WordRawValues.self, from: wordRawValuesData, label: "WordRawValues")
    }

    /// MemberScoresを取得
    var memberScores: [MemberScore]? {
        decodeJSON([MemberScore].self, from: memberScoresData, label: "MemberScores")
    }

    /// ReplyStyleProfilesを取得
    var replyStyleProfiles: ReplyStyleProfiles? {
        decodeJSON(ReplyStyleProfiles.self, from: replyStyleProfilesData, label: "ReplyStyleProfiles")
    }

    /// ReplySessionsを取得
    var replySessions: [ReplySession]? {
        decodeJSON([ReplySession].self, from: replySessionsData, label: "ReplySessions")
    }

    /// ReplyChatHistoryを取得
    var replyChatHistory: [ReplyChatEntry]? {
        decodeJSON([ReplyChatEntry].self, from: replyChatHistoryData, label: "ReplyChatHistory")
    }
}

// MARK: - Chat Session Repository
protocol ChatSessionRepository {
    func save(session: ChatSession, result: AnalysisResult) async throws
    func fetchAllSessions() async throws -> [StoredChatSession]
    func fetchResults(for sessionId: UUID) async throws -> [StoredAnalysisResult]
    func deleteAll() async throws
}

@MainActor
final class ChatSessionRepositoryImpl: ChatSessionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(session: ChatSession, result: AnalysisResult) async throws {
        // セッションを保存
        let storedSession = StoredChatSession(
            id: session.id,
            title: session.title,
            participantNames: session.participants.map { $0.name },
            messageCount: session.totalMessageCount,
            importedAt: session.importedAt,
            firstMessageDate: session.firstMessageDate,
            lastMessageDate: session.lastMessageDate
        )

        modelContext.insert(storedSession)

        // 詳細統計をJSONエンコード
        let detailedStatsData = try? JSONEncoder().encode(result.detailedStatistics)
        let balanceRawData = try? JSONEncoder().encode(result.axisScore.balanceRawValues)
        let tensionRawData = try? JSONEncoder().encode(result.axisScore.tensionRawValues)
        let responseRawData = try? JSONEncoder().encode(result.axisScore.responseRawValues)
        let wordRawData = try? JSONEncoder().encode(result.axisScore.wordRawValues)
        let replyStyleProfilesData = try? JSONEncoder().encode(result.replyStyleProfiles)

        // 結果を保存
        let storedResult = StoredAnalysisResult(
            id: result.id,
            sessionId: result.sessionId,
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
            replyStyleProfilesData: replyStyleProfilesData
        )

        storedResult.session = storedSession
        modelContext.insert(storedResult)

        try modelContext.save()
    }

    func fetchAllSessions() async throws -> [StoredChatSession] {
        let descriptor = FetchDescriptor<StoredChatSession>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchResults(for sessionId: UUID) async throws -> [StoredAnalysisResult] {
        let descriptor = FetchDescriptor<StoredAnalysisResult>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.analyzedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func deleteAll() async throws {
        try modelContext.delete(model: StoredAnalysisResult.self)
        try modelContext.delete(model: StoredMonthlySummary.self)
        try modelContext.delete(model: StoredChatSession.self)
        try modelContext.save()
    }
}

// MARK: - Stored Monthly Summary
@Model
final class StoredMonthlySummary {
    @Attribute(.unique) var id: UUID
    var year: Int
    var month: Int
    var summary: String
    var messageCount: Int
    var generatedAt: Date
    
    // リレーション
    var session: StoredChatSession?
    
    init(
        id: UUID = UUID(),
        year: Int,
        month: Int,
        summary: String,
        messageCount: Int,
        generatedAt: Date = Date(),
        session: StoredChatSession? = nil
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.summary = summary
        self.messageCount = messageCount
        self.generatedAt = generatedAt
        self.session = session
    }
    
    /// 表示用の年月文字列（表示言語に応じたフォーマット）
    var displayYearMonth: String {
        if LanguageManager.isJapanese {
            return "\(year)年\(month)月"
        }
        guard month >= 1, month <= 12 else { return "\(year)/\(month)" }
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        let monthName = formatter.shortMonthSymbols[month - 1].capitalized
        return "\(monthName) \(year)"
    }
    
    /// ソート用の値
    var sortKey: Int {
        year * 100 + month
    }
}
