import Foundation

// MARK: - Persona Relationship (チャット相手との関係性)
/// ペルソナチャット開始時に選択する相手との関係性
enum PersonaRelationship: String, Codable, Hashable, CaseIterable {
    case lover       // 恋人
    case crush       // 片思い
    case mutual      // 両思い（付き合う前）
    case ex          // 元カレ・元カノ
    case situational // 曖昧な関係
    case friend      // 友達
}

// MARK: - Persona Chat Message
struct PersonaChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: PersonaChatRole
    let text: String
    let createdAt: Date
    var isRead: Bool

    init(id: UUID = UUID(), role: PersonaChatRole, text: String, createdAt: Date = Date(), isRead: Bool = true) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

// MARK: - Role
enum PersonaChatRole: String, Codable, Hashable {
    case user
    case persona
}

// MARK: - Persona Chat Settings
struct PersonaChatSettings: Codable, Hashable {
    var replySpeed: ReplySpeed
    var proactiveMessages: Bool
    var notifications: Bool
    var relationshipType: PersonaRelationship

    static var `default`: PersonaChatSettings {
        PersonaChatSettings(replySpeed: .realtime, proactiveMessages: true, notifications: true, relationshipType: .crush)
    }

    // 既存データとの後方互換性: relationshipTypeが無い場合はcrushをデフォルトに
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        replySpeed = try container.decode(ReplySpeed.self, forKey: .replySpeed)
        proactiveMessages = try container.decode(Bool.self, forKey: .proactiveMessages)
        notifications = try container.decode(Bool.self, forKey: .notifications)
        relationshipType = try container.decodeIfPresent(PersonaRelationship.self, forKey: .relationshipType) ?? .crush
    }

    init(replySpeed: ReplySpeed, proactiveMessages: Bool, notifications: Bool, relationshipType: PersonaRelationship) {
        self.replySpeed = replySpeed
        self.proactiveMessages = proactiveMessages
        self.notifications = notifications
        self.relationshipType = relationshipType
    }
}

// MARK: - Reply Speed
enum ReplySpeed: String, Codable, Hashable, CaseIterable {
    case instant   // 即レス（1-3秒）
    case fast      // 早め（リアルの0.5倍速）
    case realtime  // リアル（実際の返信速度・分布をそのまま再現）
}

// MARK: - Reply Timing Distribution
struct ReplyTimingDistribution: Codable, Hashable {
    let p25: TimeInterval
    let median: TimeInterval
    let p75: TimeInterval

    /// 実際の分布ベースでばらつきのある遅延を生成
    func generateDelay() -> TimeInterval {
        let u = Double.random(in: 0...1)
        if u < 0.10 {
            return TimeInterval.random(in: max(p25 * 0.5, 3)...p25)
        } else if u < 0.35 {
            return TimeInterval.random(in: p25...median)
        } else if u < 0.65 {
            let iqr = p75 - p25
            let lo = max(median - iqr * 0.2, p25)
            let hi = min(median + iqr * 0.2, p75)
            return TimeInterval.random(in: lo...hi)
        } else if u < 0.90 {
            return TimeInterval.random(in: median...p75)
        } else {
            return TimeInterval.random(in: p75...min(p75 * 1.5, 1800))
        }
    }

    /// 自発メッセージ用の間隔を生成（P75〜P75×3、分布のばらつきを反映）
    func generateProactiveDelay() -> TimeInterval {
        let u = Double.random(in: 0...1)
        if u < 0.3 {
            // 30%: 比較的早め（P75〜P75×1.5）
            return TimeInterval.random(in: p75...p75 * 1.5)
        } else if u < 0.7 {
            // 40%: 中間（P75×1.5〜P75×2.5）
            return TimeInterval.random(in: p75 * 1.5...p75 * 2.5)
        } else {
            // 30%: 遅め（P75×2.5〜P75×4）
            return TimeInterval.random(in: p75 * 2.5...p75 * 4)
        }
    }
}

// MARK: - Persona Learning Summary (UI表示用 — 「ちゃんと学習してるか」を見せる)

/// 学習に使われた文体特徴の要約。設定シートで「実際に何をデータから抽出したか」を見せるため。
/// silent failure(履歴データ消失で実は何も学習してない)を即座に見抜けるようにする目的。
struct PersonaLearningSummary {
    let messageCount: Int
    let firstPerson: String?
    let topEndings: [String]
    let topEmojis: [String]
    let emojiUse: Bool
    let politenessLabel: String?
    let medianLength: Int?

    /// 学習データが事実上空かどうか
    var isEmpty: Bool {
        messageCount < 5
    }
}

// MARK: - Persona Card (人物像カード — Geminiが事前生成する相手の人格描写)

/// 相手の人格を構造化散文で表現したもの。チャット推論時のシステムプロンプトに差し込む。
/// インポート時の生データを基に1度だけ生成し、PersonaChatに永続化する。
struct PersonaCard: Codable, Hashable {
    /// LLMが生成した人物像本文(マークダウン風の章立て)
    let summary: String
    /// 生成時刻
    let generatedAt: Date
    /// 生成時の相手メッセージ件数(元データ更新検知用 — 大幅に増えたら再生成推奨)
    let messageCountAtGeneration: Int
    /// プロンプトテンプレート世代。テンプレ改修時に既存カードを破棄して再生成するため。
    let promptVersion: String

    /// 現行のプロンプト世代。`PersonaChatService.generatePersonaCard` を変更したらここを上げる。
    /// `ensurePersonaCard` が世代不一致を検知して既存カードを自動的に再生成する。
    static let currentPromptVersion = "v4"
}

// MARK: - Persona Chat (1 conversation thread per session)
struct PersonaChat: Identifiable, Codable, Hashable {
    let id: UUID
    let sessionId: UUID
    let partnerName: String
    var userCallName: String?
    var replyTiming: ReplyTimingDistribution?
    var personaCard: PersonaCard?
    var messages: [PersonaChatMessage]
    var createdAt: Date
    var lastMessageAt: Date?
    var lastUserActivityAt: Date?
    var settings: PersonaChatSettings?

    var hasUnread: Bool {
        messages.contains { $0.role == .persona && !$0.isRead }
    }

    var unreadCount: Int {
        messages.filter { $0.role == .persona && !$0.isRead }.count
    }

    var isConfigured: Bool {
        settings != nil
    }

    var resolvedSettings: PersonaChatSettings {
        settings ?? .default
    }

    /// プロアクティブ送信を停止する非アクティブ期間（48時間）
    static let proactiveTimeoutInterval: TimeInterval = 48 * 60 * 60

    /// ユーザーが48時間以上非アクティブならプロアクティブ送信を停止
    var isProactiveTimedOut: Bool {
        // lastUserActivityAt が nil の場合は createdAt をフォールバック（既存データ互換）
        let lastActivity = lastUserActivityAt ?? createdAt
        return Date().timeIntervalSince(lastActivity) > Self.proactiveTimeoutInterval
    }

    init(id: UUID = UUID(), sessionId: UUID, partnerName: String, messages: [PersonaChatMessage] = [], createdAt: Date = Date(), settings: PersonaChatSettings? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.partnerName = partnerName
        self.messages = messages
        self.createdAt = createdAt
        self.lastMessageAt = messages.last?.createdAt
        self.lastUserActivityAt = createdAt
        self.settings = settings
    }

    mutating func appendMessage(_ message: PersonaChatMessage) {
        messages.append(message)
        lastMessageAt = message.createdAt
    }

    mutating func markAllRead() {
        for i in messages.indices {
            messages[i].isRead = true
        }
    }
}
