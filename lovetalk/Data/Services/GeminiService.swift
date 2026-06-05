import Foundation
import FirebaseFunctions

// MARK: - Gemini Feature Category
/// 機能カテゴリ。Cloud Functions 側でこの値ごとに別キープールを使い分ける。
enum GeminiFeature: String, CaseIterable {
    case summary       // サマリー生成
    case consultation  // 相談・返信提案
    case personaChat   // 擬人化チャット

    /// Cloud Function に送る feature 値（サーバ側の resolveKeys と一致させる）
    var serverValue: String { rawValue }
}

// MARK: - Gemini Service
/// Cloud Functions プロキシ経由で Gemini API を呼び出すサービス。
/// API キーはサーバ側 (Secret Manager) で管理されており、クライアントには配布されない。
final class GeminiService: @unchecked Sendable {
    static let shared = GeminiService()

    private let functions = Functions.functions(region: "asia-northeast1")

    /// クライアント側スロットリング（UX的な暴走防止）
    private var lastRequestAt: [GeminiFeature: Date] = [:]
    private let minRequestInterval: TimeInterval = 4

    private init() {}

    // MARK: - Public Methods

    /// 2人の関係性を一言で要約
    func generateRelationshipSummary(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        language: ChatLanguage = .japanese
    ) async throws -> String {
        let prompt = buildRelationshipPrompt(
            messages: messages,
            selfName: selfName,
            partnerName: partnerName,
            language: language
        )
        return try await callGeminiAPI(prompt: prompt, maxTokens: 50, feature: .summary)
    }

    /// 汎用テキスト生成（機能カテゴリを指定して使用量を分離）
    func generateText(
        prompt: String,
        maxTokens: Int = 2200,
        temperature: Double = 0.45,
        feature: GeminiFeature = .consultation
    ) async throws -> String {
        try await callGeminiAPI(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature,
            feature: feature
        )
    }

    /// 会話のサマリーを生成
    func generateSummary(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        yearMonth: String,
        language: ChatLanguage = .japanese
    ) async throws -> String {
        let prompt = buildPrompt(
            messages: messages,
            selfName: selfName,
            partnerName: partnerName,
            yearMonth: yearMonth,
            language: language
        )
        return try await callGeminiAPI(prompt: prompt, feature: .summary)
    }

    // MARK: - Cloud Function Call

    private func callGeminiAPI(
        prompt: String,
        maxTokens: Int = 1024,
        temperature: Double = 0.7,
        feature: GeminiFeature = .consultation
    ) async throws -> String {
        await throttleIfNeeded(for: feature)

        let payload: [String: Any] = [
            "feature": feature.serverValue,
            "prompt": prompt,
            "maxTokens": maxTokens,
            "temperature": temperature
        ]

        do {
            let result = try await functions.httpsCallable("callGemini").call(payload)
            guard let dict = result.data as? [String: Any],
                  let text = dict["text"] as? String else {
                throw GeminiError.parsingFailed
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let nsError as NSError where nsError.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: nsError.code) ?? .internal
            print("[GeminiService] Functions error: code=\(nsError.code) message=\(nsError.localizedDescription)")
            switch code {
            case .resourceExhausted:
                throw GeminiError.apiError(statusCode: 429)
            case .invalidArgument, .failedPrecondition:
                throw GeminiError.apiError(statusCode: 400)
            case .unauthenticated, .permissionDenied:
                throw GeminiError.apiError(statusCode: 401)
            default:
                throw GeminiError.apiError(statusCode: nsError.code)
            }
        }
    }

    private func throttleIfNeeded(for feature: GeminiFeature) async {
        if let last = lastRequestAt[feature] {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minRequestInterval {
                let wait = minRequestInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
        lastRequestAt[feature] = Date()
    }

    // MARK: - Prompt Builders

    private func buildPrompt(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        yearMonth: String,
        language: ChatLanguage = .japanese
    ) -> String {
        let sampleMessages = messages.prefix(200)

        var conversationText = ""
        for message in sampleMessages {
            if message.eventType == .text {
                conversationText += "[\(message.senderName)]: \(message.content)\n"
            }
        }

        switch language {
        case .japanese:
            return """
            \(selfName)と\(partnerName)の\(yearMonth)の会話から、話した内容をまとめて。

            【出力形式】必ずこの形式で出力すること
            ・〇〇について話した
            ・〇〇の予定を立てた
            ・〇〇に行った報告をした

            【ルール】
            - 箇条書きで5〜8個
            - 各項目は「・」で始め、15〜25文字程度
            - 「〇〇した」「〇〇について話した」の形式で統一
            - 具体的な内容（場所名、イベント名、話題）を含める
            - 関係性の分析や感情表現は一切不要
            - 会話がない話題は書かない

            【会話履歴】
            \(conversationText)
            """

        case .english:
            return """
            Summarize the conversation topics between \(selfName) and \(partnerName) in \(yearMonth).

            【Output format】Use this format exactly:
            • Talked about ___
            • Made plans for ___
            • Discussed ___

            【Rules】
            - 5 to 8 bullet points
            - Each starts with "•"
            - Keep each point concise (5-15 words)
            - Include specific details (places, events, topics)
            - No relationship analysis or emotional commentary
            - Only mention topics that actually appear in the conversation

            【Chat history】
            \(conversationText)
            """

        case .spanish:
            return """
            Resume los temas de conversación entre \(selfName) y \(partnerName) en \(yearMonth).

            【Formato de salida】Usa exactamente este formato:
            • Hablaron sobre ___
            • Hicieron planes para ___
            • Discutieron ___

            【Reglas】
            - De 5 a 8 puntos
            - Cada punto empieza con "•"
            - Mantén cada punto conciso (5-15 palabras)
            - Incluye detalles específicos (lugares, eventos, temas)
            - Sin análisis de relación ni comentarios emocionales
            - Solo menciona temas que realmente aparecen en la conversación

            【Historial de chat】
            \(conversationText)
            """

        case .korean:
            return """
            \(selfName)와(과) \(partnerName)의 \(yearMonth) 대화 내용을 정리해줘.

            【출력 형식】반드시 이 형식으로 출력할 것
            • ___에 대해 이야기했다
            • ___의 계획을 세웠다
            • ___에 대해 논의했다

            【규칙】
            - 5~8개 항목
            - 각 항목은 "•"로 시작
            - 각 항목은 간결하게 (5~15단어)
            - 구체적인 내용 (장소, 이벤트, 주제) 포함
            - 관계 분석이나 감정 표현 불필요
            - 대화에 실제로 나온 주제만 작성

            【대화 기록】
            \(conversationText)
            """

        case .chinese:
            return """
            请总结\(selfName)和\(partnerName)在\(yearMonth)的对话内容。

            【输出格式】请严格按照以下格式输出：
            • 聊了关于___的话题
            • 制定了___的计划
            • 讨论了___

            【规则】
            - 5到8个要点
            - 每个要点以"•"开头
            - 每个要点简洁（5-15个字）
            - 包含具体细节（地点、活动、话题）
            - 不需要关系分析或情感评论
            - 只提及对话中实际出现的话题

            【聊天记录】
            \(conversationText)
            """
        }
    }

    private func buildRelationshipPrompt(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        language: ChatLanguage = .japanese
    ) -> String {
        let textMessages = messages.filter { $0.eventType == .text }
        var sampled: [ChatMessage] = []
        if textMessages.count <= 300 {
            sampled = textMessages
        } else {
            let mid = textMessages.count / 2
            sampled += Array(textMessages.prefix(100))
            sampled += Array(textMessages[max(0, mid - 50)..<min(textMessages.count, mid + 50)])
            sampled += Array(textMessages.suffix(100))
        }

        var conversationText = ""
        for message in sampled {
            conversationText += "[\(message.senderName)]: \(message.content)\n"
        }

        switch language {
        case .japanese:
            return """
            \(selfName)と\(partnerName)の会話から、2人の関係性を一言で表して。

            【出力ルール】
            - 10文字以内の短いフレーズのみ出力
            - 例:「いい感じの関係」「親友」「気の合う仲間」「恋愛初期っぽい」「長い付き合い」「兄弟みたい」
            - 余計な説明は一切不要、フレーズのみ

            【会話履歴】
            \(conversationText)
            """

        case .english:
            return """
            Describe the relationship between \(selfName) and \(partnerName) in one short phrase.

            【Rules】
            - Output only a short phrase (2-5 words)
            - Examples: "Close friends", "Early romance", "Best friends", "Long-term couple", "Like siblings"
            - No explanation, just the phrase

            【Chat history】
            \(conversationText)
            """

        case .spanish:
            return """
            Describe la relación entre \(selfName) y \(partnerName) en una frase corta.

            【Reglas】
            - Solo una frase corta (2-5 palabras)
            - Ejemplos: "Buenos amigos", "Romance inicial", "Mejores amigos", "Pareja estable", "Como hermanos"
            - Sin explicación, solo la frase

            【Historial de chat】
            \(conversationText)
            """

        case .korean:
            return """
            \(selfName)와(과) \(partnerName)의 관계를 한 마디로 표현해줘.

            【규칙】
            - 짧은 문구만 출력 (2~5단어)
            - 예시: "좋은 사이", "연애 초기", "절친", "오래된 연인", "형제 같은"
            - 부가 설명 없이 문구만 출력

            【대화 기록】
            \(conversationText)
            """

        case .chinese:
            return """
            用一个短语描述\(selfName)和\(partnerName)之间的关系。

            【规则】
            - 只输出一个简短的短语（2-5个字）
            - 示例："好朋友"、"恋爱初期"、"闺蜜"、"老夫老妻"、"兄弟般"
            - 不需要任何解释，只输出短语

            【聊天记录】
            \(conversationText)
            """
        }
    }
}

// MARK: - Gemini Error
enum GeminiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case parsingFailed
    case apiKeyUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "無効なURLです", bundle: LanguageManager.appBundle)
        case .invalidResponse:
            return String(localized: "無効なレスポンスです", bundle: LanguageManager.appBundle)
        case .apiError(let statusCode):
            return String(format: String(localized: "APIエラー: %d", bundle: LanguageManager.appBundle), statusCode)
        case .parsingFailed:
            return String(localized: "レスポンスの解析に失敗しました", bundle: LanguageManager.appBundle)
        case .apiKeyUnavailable:
            return String(localized: "APIキーを取得できませんでした", bundle: LanguageManager.appBundle)
        }
    }
}
