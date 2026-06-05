import Foundation

// MARK: - Event Type
enum EventType: String, Codable, CaseIterable {
    case text = "text"
    case sticker = "sticker"
    case photo = "photo"
    case video = "video"
    case call = "call"
    case missedCall = "missedCall"
    case system = "system"

    var displayName: String {
        switch self {
        case .text: return String(localized: "テキスト", bundle: LanguageManager.appBundle)
        case .sticker: return String(localized: "スタンプ", bundle: LanguageManager.appBundle)
        case .photo: return String(localized: "写真", bundle: LanguageManager.appBundle)
        case .video: return String(localized: "動画", bundle: LanguageManager.appBundle)
        case .call: return String(localized: "通話", bundle: LanguageManager.appBundle)
        case .missedCall: return String(localized: "不在着信", bundle: LanguageManager.appBundle)
        case .system: return String(localized: "システム", bundle: LanguageManager.appBundle)
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .sticker: return "face.smiling"
        case .photo: return "photo"
        case .video: return "video"
        case .call: return "phone"
        case .missedCall: return "phone.arrow.down.left"
        case .system: return "info.circle"
        }
    }

    /// 診断に使用するか（systemは除外）
    var isUsedForAnalysis: Bool {
        self != .system
    }

    /// テキストベースのイベントか
    var isTextBased: Bool {
        self == .text
    }

    /// メディアイベントか
    var isMedia: Bool {
        self == .photo || self == .video
    }

    /// 通話関連か
    var isCallRelated: Bool {
        self == .call || self == .missedCall
    }
}

// MARK: - Chat Message
struct ChatMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let senderName: String
    let content: String
    let eventType: EventType
    let rawLine: String

    /// 通話時間（秒）- 通話イベントの場合のみ
    let callDurationSeconds: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        senderName: String,
        content: String,
        eventType: EventType,
        rawLine: String = "",
        callDurationSeconds: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.senderName = senderName
        self.content = content
        self.eventType = eventType
        self.rawLine = rawLine
        self.callDurationSeconds = callDurationSeconds
    }

    // MARK: - Computed Properties

    /// 感情記号を含むか（!?絵文字）
    var hasEmotionalSymbols: Bool {
        content.hasEmotionalSymbols
    }

    /// 感情記号の数
    var emotionalSymbolCount: Int {
        content.emotionalSymbolCount
    }

    /// 質問かどうか（?で終わる）
    var isQuestion: Bool {
        content.isQuestion
    }

    /// 提案を含むか
    var containsProposal: Bool {
        content.containsProposal
    }

    /// テキストの長さ
    var textLength: Int {
        content.count
    }

    /// 夜間のメッセージか（22:00-02:00）
    var isNightMessage: Bool {
        timestamp.isNightTime
    }

    /// 深夜のメッセージか（00:00-05:00）
    var isLateNightMessage: Bool {
        timestamp.isLateNight
    }

    /// 時間帯
    var timePeriod: Date.TimePeriod {
        timestamp.timePeriod
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat Participant
struct ChatParticipant: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    var messageCount: Int
    var textMessageCount: Int
    var stickerCount: Int
    var photoCount: Int
    var videoCount: Int
    var callCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        messageCount: Int = 0,
        textMessageCount: Int = 0,
        stickerCount: Int = 0,
        photoCount: Int = 0,
        videoCount: Int = 0,
        callCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.messageCount = messageCount
        self.textMessageCount = textMessageCount
        self.stickerCount = stickerCount
        self.photoCount = photoCount
        self.videoCount = videoCount
        self.callCount = callCount
    }

    /// 総メディア数
    var totalMediaCount: Int {
        photoCount + videoCount
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ChatParticipant, rhs: ChatParticipant) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat Session
struct ChatSession: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let messages: [ChatMessage]
    let participants: [ChatParticipant]
    let importedAt: Date

    /// パース時に推定された「自分」の名前
    var estimatedSelfName: String?

    /// トーク内容から自動検出された言語
    var detectedLanguage: ChatLanguage

    /// 診断前にユーザーが選択する相手との関係性。
    /// `nil` の場合は `.unknown` 扱い（補正なし）。
    /// docs/spec/diagnosis-logic.md §3.5 参照。
    var relationship: RelationshipContext?

    init(
        id: UUID = UUID(),
        title: String,
        messages: [ChatMessage],
        participants: [ChatParticipant],
        importedAt: Date = Date(),
        estimatedSelfName: String? = nil,
        detectedLanguage: ChatLanguage = .japanese,
        relationship: RelationshipContext? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.participants = participants
        self.importedAt = importedAt
        self.estimatedSelfName = estimatedSelfName
        self.detectedLanguage = detectedLanguage
        self.relationship = relationship
    }

    /// 関係性。未指定の場合は `.unknown`。
    var effectiveRelationship: RelationshipContext {
        relationship ?? .unknown
    }

    // MARK: - Computed Properties

    /// 総メッセージ数
    var totalMessageCount: Int {
        messages.count
    }

    /// テキストメッセージ数
    var textMessageCount: Int {
        messages.filter { $0.eventType == .text }.count
    }

    /// 最初のメッセージ日時
    var firstMessageDate: Date? {
        messages.first?.timestamp
    }

    /// 最後のメッセージ日時
    var lastMessageDate: Date? {
        messages.last?.timestamp
    }

    /// 期間（日数）
    var durationDays: Int {
        guard let first = firstMessageDate, let last = lastMessageDate else { return 0 }
        return first.daysBetween(last)
    }

    /// 1対1の会話か
    var isOneOnOne: Bool {
        participants.count == 2
    }

    /// 相手の名前（1対1の場合）
    func partnerName(selfName: String) -> String? {
        guard isOneOnOne else { return nil }
        return participants.first { $0.name != selfName }?.name
    }

    /// 期間でフィルタリングしたメッセージを取得
    func messages(for period: AnalysisPeriod) -> [ChatMessage] {
        guard let lastDate = lastMessageDate else { return messages }

        switch period {
        case .all:
            return messages
        case .days30:
            let startDate = lastDate.daysAgo(30)
            return messages.filter { $0.timestamp >= startDate }
        case .days7:
            let startDate = lastDate.daysAgo(7)
            return messages.filter { $0.timestamp >= startDate }
        }
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Analysis Period
enum AnalysisPeriod: String, CaseIterable, Codable, Identifiable {
    case all = "all"
    case days30 = "days30"
    case days7 = "days7"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return String(localized: "全期間", bundle: LanguageManager.appBundle)
        case .days30: return String(localized: "30日", bundle: LanguageManager.appBundle)
        case .days7: return String(localized: "7日", bundle: LanguageManager.appBundle)
        }
    }

    var shortName: String {
        switch self {
        case .all: return String(localized: "全", bundle: LanguageManager.appBundle)
        case .days30: return String(localized: "30日_short", bundle: LanguageManager.appBundle)
        case .days7: return String(localized: "7日_short", bundle: LanguageManager.appBundle)
        }
    }

    var days: Int? {
        switch self {
        case .all: return nil
        case .days30: return 30
        case .days7: return 7
        }
    }
}
