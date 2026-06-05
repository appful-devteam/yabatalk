import Foundation

// MARK: - Reply Suggestion Chat

enum ReplyChatRole: String, Codable, Hashable {
    case user
    case assistant
}

struct ReplyChatEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let role: ReplyChatRole
    let text: String
    let createdAt: Date
    let suggestion: ReplySuggestionResult?
    let quickOptions: [QuickOption]?

    init(
        id: UUID = UUID(),
        role: ReplyChatRole,
        text: String,
        createdAt: Date = Date(),
        suggestion: ReplySuggestionResult? = nil,
        quickOptions: [QuickOption]? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.suggestion = suggestion
        self.quickOptions = quickOptions
    }
}

// MARK: - Reply Suggestion Result

enum ReplySimulationPattern: String, Codable, Hashable {
    case good
    case neutral
    case badOrSilent = "bad_or_silent"

    var displayName: String {
        switch self {
        case .good: return String(localized: "良い反応", bundle: LanguageManager.appBundle)
        case .neutral: return String(localized: "普通", bundle: LanguageManager.appBundle)
        case .badOrSilent: return String(localized: "微妙・スルー", bundle: LanguageManager.appBundle)
        }
    }
}

struct ReplySimulation: Identifiable, Codable, Hashable {
    let id: UUID
    let pattern: ReplySimulationPattern
    let partnerText: String
    let nextMove: String

    init(
        id: UUID = UUID(),
        pattern: ReplySimulationPattern,
        partnerText: String,
        nextMove: String
    ) {
        self.id = id
        self.pattern = pattern
        self.partnerText = partnerText
        self.nextMove = nextMove
    }
}

struct ReplyCandidate: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let text: String
    let styleScore: Double
    let riskFlags: [String]
    let simulations: [ReplySimulation]

    func withSimulations(_ newSimulations: [ReplySimulation]) -> ReplyCandidate {
        ReplyCandidate(
            id: id,
            label: label,
            text: text,
            styleScore: styleScore,
            riskFlags: riskFlags,
            simulations: newSimulations
        )
    }
}

struct ReplySuggestionResult: Codable, Hashable {
    let candidates: [ReplyCandidate]
    let notes: [String]
    let usedBackfill: Bool

    var hasCandidates: Bool {
        !candidates.isEmpty
    }
}

// MARK: - Pipeline Stage

enum PipelineStage: Int, CaseIterable {
    case preparingStyle = 0
    case designingContent = 1
    case craftingWordChoice = 2
    case applyingStyle = 3
    case qualityCheck = 4
    case simulatingPartner = 5
    case finalizing = 6

    var displayMessage: String {
        switch self {
        case .preparingStyle: return String(localized: "文体と性格を分析中...", bundle: LanguageManager.appBundle)
        case .designingContent: return String(localized: "最適な返信内容を設計中...", bundle: LanguageManager.appBundle)
        case .craftingWordChoice: return String(localized: "返信内容を組み立て中...", bundle: LanguageManager.appBundle)
        case .applyingStyle: return String(localized: "口調を仕上げ中...", bundle: LanguageManager.appBundle)
        case .qualityCheck: return String(localized: "口調の再現度をチェック中...", bundle: LanguageManager.appBundle)
        case .simulatingPartner: return String(localized: "相手の反応を予測中...", bundle: LanguageManager.appBundle)
        case .finalizing: return String(localized: "最終仕上げ中...", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - Content Design Result (Call 1 Output)

struct ContentDesignResult {
    let emotionalProblem: EmotionalProblem
    let rootProblem: RootProblem
    let scenarioPlans: [ScenarioPlan]
    let doList: [String]
    let dontList: [String]
}

struct EmotionalProblem {
    let feeling: String
    let trigger: String
    let approach: String
}

struct RootProblem {
    let situation: String
    let approach: String
}

struct ScenarioPlan {
    let id: String
    let label: String
    let position: String
    let setting: String
    let timing: String
    let contentPoints: [String]
    let emotionalGoal: String
    let practicalGoal: String
}

// MARK: - Reply Session

enum ReplySessionStatus: String, Codable, Hashable {
    case active, completed
}

struct ReplySession: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    var entries: [ReplyChatEntry]
    var status: ReplySessionStatus
    var rating: Int?
    var ratingReasons: [String]?
    var conversationMode: ReplyConversationMode?
    var consultationContext: ConsultationContext?

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        entries: [ReplyChatEntry] = [],
        status: ReplySessionStatus = .active,
        rating: Int? = nil,
        ratingReasons: [String]? = nil,
        conversationMode: ReplyConversationMode? = nil,
        consultationContext: ConsultationContext? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.entries = entries
        self.status = status
        self.rating = rating
        self.ratingReasons = ratingReasons
        self.conversationMode = conversationMode
        self.consultationContext = consultationContext
    }

    mutating func updateTitleFromFirstMessage() {
        guard title.isEmpty else { return }

        // Find the first user message that is actual conversation content
        // (skip quick option selections like relationship type or problem category)
        let allProblemCategories = ConsultationRelationshipType.allCases
            .flatMap { ConsultationProblemCategory.options(for: $0) }
        let quickOptionValues = Set(
            ConsultationRelationshipType.allCases.map { "\($0.emoji) \($0.displayName)" }
            + allProblemCategories.map { $0.displayName }
        )
        let firstRealMessage = entries.first { entry in
            entry.role == .user && !quickOptionValues.contains(entry.text)
        }

        if let message = firstRealMessage {
            let text = message.text
            title = String(text.prefix(20))
            if text.count > 20 { title += "..." }
        } else if let ctx = consultationContext, let problem = ctx.problemCategory {
            // Fallback to problem category if no real message yet
            title = problem.displayName
        } else if let firstUserMessage = entries.first(where: { $0.role == .user }) {
            let text = firstUserMessage.text
            title = String(text.prefix(20))
            if text.count > 20 { title += "..." }
        }
    }
}

struct ReplySessionReviewReason: Identifiable, Hashable {
    let id: String
    let label: String

    static let allReasons: [ReplySessionReviewReason] = [
        .init(id: "accurate", label: String(localized: "的確だった", bundle: LanguageManager.appBundle)),
        .init(id: "helpful", label: String(localized: "参考になった", bundle: LanguageManager.appBundle)),
        .init(id: "natural_tone", label: String(localized: "口調が自然", bundle: LanguageManager.appBundle)),
        .init(id: "more_specific", label: String(localized: "もう少し具体的に", bundle: LanguageManager.appBundle)),
        .init(id: "off_target", label: String(localized: "ずれていた", bundle: LanguageManager.appBundle)),
    ]
}

// MARK: - Conversation Mode

enum ReplyConversationMode: String, Codable, Hashable {
    case continueConversation
    case newConversation
}

// MARK: - Goal Quick Option

struct GoalQuickOption: Identifiable, Hashable {
    let id: String
    let label: String
    let prompt: String

    static let defaults: [GoalQuickOption] = continueDefaults

    static let continueDefaults: [GoalQuickOption] = [
        GoalQuickOption(id: "repair", label: String(localized: "気まずさ解消", bundle: LanguageManager.appBundle), prompt: String(localized: "気まずい空気を戻したい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "closer", label: String(localized: "距離を縮めたい", bundle: LanguageManager.appBundle), prompt: String(localized: "もっと仲良くなりたい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "reply", label: String(localized: "返し方がわからない", bundle: LanguageManager.appBundle), prompt: String(localized: "この返事になんて返せばいいかわからない", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "date", label: String(localized: "デートに誘いたい", bundle: LanguageManager.appBundle), prompt: String(localized: "自然にデートに誘いたい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "apologize", label: String(localized: "謝りたい", bundle: LanguageManager.appBundle), prompt: String(localized: "うまく謝りたい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "confess", label: String(localized: "気持ちを伝えたい", bundle: LanguageManager.appBundle), prompt: String(localized: "好きな気持ちを伝えたい", bundle: LanguageManager.appBundle)),
    ]

    static let newConversationDefaults: [GoalQuickOption] = [
        GoalQuickOption(id: "longTime", label: String(localized: "久しぶりに連絡", bundle: LanguageManager.appBundle), prompt: String(localized: "久しぶりに自然に連絡したい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "dateInvite", label: String(localized: "デートに誘う", bundle: LanguageManager.appBundle), prompt: String(localized: "自然にデートに誘いたい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "funTopic", label: String(localized: "面白い話題", bundle: LanguageManager.appBundle), prompt: String(localized: "面白い話題で会話を始めたい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "casual", label: String(localized: "なんとなく連絡", bundle: LanguageManager.appBundle), prompt: String(localized: "なんとなく連絡を取りたい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "event", label: String(localized: "イベントに誘う", bundle: LanguageManager.appBundle), prompt: String(localized: "イベントや遊びに誘いたい", bundle: LanguageManager.appBundle)),
        GoalQuickOption(id: "feelings", label: String(localized: "気持ちを切り出す", bundle: LanguageManager.appBundle), prompt: String(localized: "気持ちを切り出したい", bundle: LanguageManager.appBundle)),
    ]
}

// MARK: - Composer Output DTO (Call 2)

struct ComposerOutputDTO: Codable {
    let candidates: [ComposerReplyDTO]
    let notes: [String]?
}

struct ComposerReplyDTO: Codable {
    let id: String
    let label: String?
    let text: String
}

// MARK: - Simulator Output DTO (Call 3)

struct SimulatorOutputDTO: Codable {
    let simulations: [SimulationCandidateDTO]
}

struct SimulationCandidateDTO: Codable {
    let id: String
    let patterns: [SimulationPatternDTO]
}

struct SimulationPatternDTO: Codable {
    let pattern: String
    let partnerText: String?
    let nextMove: String?

    enum CodingKeys: String, CodingKey {
        case pattern
        case partnerText = "partner_text"
        case nextMove = "next_move"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pattern = try container.decode(String.self, forKey: .pattern)

        if let v = try? container.decodeIfPresent(String.self, forKey: .partnerText) {
            self.partnerText = v
        } else {
            let dynamic = try decoder.container(keyedBy: FlexCodingKey.self)
            self.partnerText = try? dynamic.decodeIfPresent(String.self, forKey: FlexCodingKey("partnerText"))
        }

        if let v = try? container.decodeIfPresent(String.self, forKey: .nextMove) {
            self.nextMove = v
        } else {
            let dynamic = try decoder.container(keyedBy: FlexCodingKey.self)
            self.nextMove = try? dynamic.decodeIfPresent(String.self, forKey: FlexCodingKey("nextMove"))
        }
    }

    func toSimulation() -> ReplySimulation {
        let mapped: ReplySimulationPattern
        switch pattern.lowercased() {
        case "good": mapped = .good
        case "neutral": mapped = .neutral
        default: mapped = .badOrSilent
        }
        return ReplySimulation(
            pattern: mapped,
            partnerText: partnerText ?? "了解",
            nextMove: nextMove ?? "了解！ありがとう"
        )
    }
}

// MARK: - Tone Preference

enum PolitenessLevel: String, Codable, CaseIterable, Hashable {
    case casual, auto, formal

    var displayName: String {
        switch self {
        case .casual: return String(localized: "タメ口", bundle: LanguageManager.appBundle)
        case .auto: return String(localized: "自動", bundle: LanguageManager.appBundle)
        case .formal: return String(localized: "敬語", bundle: LanguageManager.appBundle)
        }
    }
}

enum EmojiIntensity: String, Codable, CaseIterable, Hashable {
    case none, auto, heavy

    var displayName: String {
        switch self {
        case .none: return String(localized: "なし", bundle: LanguageManager.appBundle)
        case .auto: return String(localized: "自動", bundle: LanguageManager.appBundle)
        case .heavy: return String(localized: "多め", bundle: LanguageManager.appBundle)
        }
    }
}

enum LengthPreference: String, Codable, CaseIterable, Hashable {
    case short, auto, long

    var displayName: String {
        switch self {
        case .short: return String(localized: "短め", bundle: LanguageManager.appBundle)
        case .auto: return String(localized: "自動", bundle: LanguageManager.appBundle)
        case .long: return String(localized: "長め", bundle: LanguageManager.appBundle)
        }
    }
}

struct ReplyTonePreference: Codable, Hashable {
    var politenessLevel: PolitenessLevel = .auto
    var emojiIntensity: EmojiIntensity = .auto
    var lengthPreference: LengthPreference = .auto

    var isDefault: Bool {
        politenessLevel == .auto && emojiIntensity == .auto && lengthPreference == .auto
    }
}

// MARK: - Simulation Focus

enum SimulationFocus: String, Codable, CaseIterable, Hashable {
    case balanced, bestCase, worstCase

    var displayName: String {
        switch self {
        case .balanced: return String(localized: "バランス", bundle: LanguageManager.appBundle)
        case .bestCase: return String(localized: "ベスト", bundle: LanguageManager.appBundle)
        case .worstCase: return String(localized: "ワースト", bundle: LanguageManager.appBundle)
        }
    }

    var promptInstruction: String {
        switch self {
        case .balanced:
            return "各案に3パターン（good/neutral/bad_or_silent）の反応と、それぞれへの「次の一手」を出してください。"
        case .bestCase:
            return "各案に3パターンの反応を出してください。good×2パターン（異なる良い反応）+ neutral×1パターンで構成してください。"
        case .worstCase:
            return "各案に3パターンの反応を出してください。bad_or_silent×2パターン（異なる悪い反応）+ neutral×1パターンで構成してください。"
        }
    }
}

// MARK: - Reply Feedback

enum PartnerReaction: String, Codable, CaseIterable, Hashable {
    case positive, neutral, negative, noReply

    var displayName: String {
        switch self {
        case .positive: return String(localized: "良い", bundle: LanguageManager.appBundle)
        case .neutral: return String(localized: "普通", bundle: LanguageManager.appBundle)
        case .negative: return String(localized: "微妙", bundle: LanguageManager.appBundle)
        case .noReply: return String(localized: "スルー", bundle: LanguageManager.appBundle)
        }
    }

    var emoji: String {
        switch self {
        case .positive: return "😊"
        case .neutral: return "😐"
        case .negative: return "😕"
        case .noReply: return "🫥"
        }
    }
}

struct ReplyFeedback: Codable, Hashable {
    let candidateId: String
    let copiedAt: Date
    var wasSent: Bool?
    var partnerReaction: PartnerReaction?
}

private struct FlexCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { self.stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

// MARK: - Consultation Tree

enum ConsultationRelationshipType: String, Codable, Hashable, CaseIterable {
    case partner, crush, moreThanFriends, ex, datingApp

    var displayName: String {
        switch self {
        case .partner: return String(localized: "恋人", bundle: LanguageManager.appBundle)
        case .crush: return String(localized: "片思い", bundle: LanguageManager.appBundle)
        case .moreThanFriends: return String(localized: "友達以上恋人未満", bundle: LanguageManager.appBundle)
        case .ex: return String(localized: "元カレ・元カノ", bundle: LanguageManager.appBundle)
        case .datingApp: return String(localized: "マッチングアプリ", bundle: LanguageManager.appBundle)
        }
    }

    var emoji: String {
        switch self {
        case .partner: return "💑"
        case .crush: return "💕"
        case .moreThanFriends: return "👫"
        case .ex: return "💔"
        case .datingApp: return "📱"
        }
    }
}

enum ConsultationProblemCategory: String, Codable, Hashable {
    // 共通
    case awkwardTension, wantToGetCloser, strugglingToReply, wantToAskOnDate
    case wantToApologize, wantToExpressFeeling, fightMisunderstanding, messagingFrequency
    // 片思い
    case wantToConfess, checkInterest, dontKnowHowToMessage
    // 友達以上
    case advanceRelationship, unsureAboutDistance, unsureAboutStatusQuo
    // 元
    case wantToGetBackTogether, wantToReconnect, wantToBeFriends, wantToMoveOn
    // アプリ
    case firstMessage, conversationDying, wantToExchangeLine

    var displayName: String {
        switch self {
        case .awkwardTension: return String(localized: "気まずい空気", bundle: LanguageManager.appBundle)
        case .wantToGetCloser: return String(localized: "距離を縮めたい", bundle: LanguageManager.appBundle)
        case .strugglingToReply: return String(localized: "返事に困ってる", bundle: LanguageManager.appBundle)
        case .wantToAskOnDate: return String(localized: "デートに誘いたい", bundle: LanguageManager.appBundle)
        case .wantToApologize: return String(localized: "謝りたい", bundle: LanguageManager.appBundle)
        case .wantToExpressFeeling: return String(localized: "気持ちを伝えたい", bundle: LanguageManager.appBundle)
        case .fightMisunderstanding: return String(localized: "喧嘩・すれ違い", bundle: LanguageManager.appBundle)
        case .messagingFrequency: return String(localized: "連絡頻度", bundle: LanguageManager.appBundle)
        case .wantToConfess: return String(localized: "告白したい", bundle: LanguageManager.appBundle)
        case .checkInterest: return String(localized: "脈あるか知りたい", bundle: LanguageManager.appBundle)
        case .dontKnowHowToMessage: return String(localized: "連絡の仕方がわからない", bundle: LanguageManager.appBundle)
        case .advanceRelationship: return String(localized: "関係を進めたい", bundle: LanguageManager.appBundle)
        case .unsureAboutDistance: return String(localized: "距離感がわからない", bundle: LanguageManager.appBundle)
        case .unsureAboutStatusQuo: return String(localized: "このままでいいか悩む", bundle: LanguageManager.appBundle)
        case .wantToGetBackTogether: return String(localized: "復縁したい", bundle: LanguageManager.appBundle)
        case .wantToReconnect: return String(localized: "久しぶりに連絡したい", bundle: LanguageManager.appBundle)
        case .wantToBeFriends: return String(localized: "友達に戻りたい", bundle: LanguageManager.appBundle)
        case .wantToMoveOn: return String(localized: "未練を断ち切りたい", bundle: LanguageManager.appBundle)
        case .firstMessage: return String(localized: "初メッセージ", bundle: LanguageManager.appBundle)
        case .conversationDying: return String(localized: "会話が続かない", bundle: LanguageManager.appBundle)
        case .wantToExchangeLine: return String(localized: "LINE交換したい", bundle: LanguageManager.appBundle)
        }
    }

    static func options(for type: ConsultationRelationshipType) -> [Self] {
        switch type {
        case .partner:
            return [.awkwardTension, .wantToGetCloser, .strugglingToReply, .wantToAskOnDate,
                    .wantToApologize, .wantToExpressFeeling, .fightMisunderstanding, .messagingFrequency]
        case .crush:
            return [.wantToGetCloser, .wantToConfess, .wantToAskOnDate, .strugglingToReply,
                    .checkInterest, .dontKnowHowToMessage]
        case .moreThanFriends:
            return [.advanceRelationship, .wantToConfess, .unsureAboutDistance, .unsureAboutStatusQuo]
        case .ex:
            return [.wantToGetBackTogether, .wantToReconnect, .wantToBeFriends, .wantToMoveOn]
        case .datingApp:
            return [.firstMessage, .wantToAskOnDate, .conversationDying, .wantToGetCloser]
        }
    }
}

enum ConsultationPhase: String, Codable, Hashable {
    case selectRelationshipType, selectProblemCategory, gathering, advising
}

// MARK: - Consultation Tone & Length

enum ConsultationTone: String, Codable, CaseIterable, Hashable {
    case empathetic, balanced, direct

    var displayName: String {
        switch self {
        case .empathetic: return String(localized: "やさしく", bundle: LanguageManager.appBundle)
        case .balanced: return String(localized: "バランス", bundle: LanguageManager.appBundle)
        case .direct: return String(localized: "ストレート", bundle: LanguageManager.appBundle)
        }
    }

    var toneDescription: String {
        switch self {
        case .empathetic: return "やさしく寄り添うタイプ。共感多め、アドバイスは控えめ"
        case .balanced: return "共感しながらも適度にアドバイスする。バランス型"
        case .direct: return "ストレートに本音を言う。遠回しにしない"
        }
    }

    var promptInstruction: String {
        switch self {
        case .empathetic:
            return """
            【返答スタイル: やさしく寄り添う】
            - 共感を最優先にし、励ましと安心感を中心に返答する
            - 「わかるよ」「つらいよね」「大丈夫だよ」など気持ちに寄り添う言葉を多めに
            - アドバイスは控えめに、求められたときだけ。押し付けない
            - 否定的な表現は避ける
            """
        case .balanced:
            return """
            【返答スタイル: バランス】
            - まず気持ちに寄り添ってから助言する
            - 共感とアドバイスのバランスを取る
            """
        case .direct:
            return """
            【返答スタイル: ストレート — 最重要】
            - 共感は最初の1文だけ。すぐに本題に入る
            - 遠回しな言い方は絶対にしない。「正直に言うと」「ぶっちゃけ」を使ってOK
            - 耳が痛いことでもハッキリ伝える。ユーザーの行動に問題があればズバッと指摘する
            - ただし人格否定はしない。行動や考え方に対して率直に言う
            """
        }
    }
}

enum ConsultationLength: String, Codable, CaseIterable, Hashable {
    case short, medium, long

    var displayName: String {
        switch self {
        case .short: return String(localized: "さくっと", bundle: LanguageManager.appBundle)
        case .medium: return String(localized: "ふつう", bundle: LanguageManager.appBundle)
        case .long: return String(localized: "しっかり", bundle: LanguageManager.appBundle)
        }
    }

    var promptInstruction: String {
        switch self {
        case .short:
            return "【文字数制限: 厳守】返答は50〜100文字以内。これを超えてはならない。1〜2文で簡潔に。メッセージ例も1つまで。"
        case .medium:
            return "【文字数制限: 厳守】返答は100〜200文字以内。これを超えてはならない。要点を絞って返答する。メッセージ例は最大1つ。"
        case .long:
            return "【文字数目安】200〜400文字程度でしっかり返答する。"
        }
    }

    var maxTokens: Int {
        // promptInstruction の文字数制限より十分大きく取る。日本語1文字≈2-3トークンで、
        // モデルが指示を超えて少し書いても途中で切れないように余裕を持たせる。
        switch self {
        case .short: return 600
        case .medium: return 1200
        case .long: return 2000
        }
    }
}

struct ConsultationContext: Codable, Hashable {
    var relationshipType: ConsultationRelationshipType?
    var problemCategory: ConsultationProblemCategory?
    var phase: ConsultationPhase = .selectRelationshipType
    var gatheringTurns: Int = 0
    var tone: ConsultationTone = .balanced
    var length: ConsultationLength = .medium
}

struct QuickOption: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let value: String

    static var relationshipTypeOptions: [QuickOption] {
        ConsultationRelationshipType.allCases.map { type in
            QuickOption(id: type.rawValue, label: "\(type.emoji) \(type.displayName)", value: type.rawValue)
        }
    }

    static func problemOptions(for type: ConsultationRelationshipType) -> [QuickOption] {
        ConsultationProblemCategory.options(for: type).map { cat in
            QuickOption(id: cat.rawValue, label: cat.displayName, value: cat.rawValue)
        }
    }
}
