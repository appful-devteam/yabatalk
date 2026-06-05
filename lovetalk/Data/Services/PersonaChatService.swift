import Foundation

// MARK: - Persona Chat Service
/// トークデータから相手のペルソナを再現し、AIチャットを生成するサービス。
///
/// - 1段目(`generatePersonaCard`): インポート直後 / 設定完了直後に1度だけ呼び、
///   相手の人格を構造化散文(`PersonaCard.summary`)に圧縮して PersonaChat に保存する。
/// - 2段目(`generateResponse` / `generateProactiveMessage`): 推論時にカード本文と
///   生サンプル+関係性ガイドを差し込んで返信を生成する。カードが既にあるおかげで
///   ルールの積み重ねを最小限にでき、口調と提案の自然さが両立する。
@MainActor
final class PersonaChatService {
    static let shared = PersonaChatService()
    private let geminiService = GeminiService.shared

    private init() {}

    // MARK: - Generate Persona Card (1段目: 事前生成)

    /// 相手の人格を構造化散文に圧縮した PersonaCard を生成する。
    /// 1チャットにつき基本1度だけ呼ぶことを想定(再生成は明示的なユーザー操作のみ)。
    func generatePersonaCard(
        partnerName: String,
        selfName: String,
        partnerMessages: [ChatMessage],
        allMessages: [ChatMessage],
        replyStyle: ReplyStyleProfile?
    ) async throws -> PersonaCard {
        let prompt = buildPersonaCardPrompt(
            partnerName: partnerName,
            selfName: selfName,
            partnerMessages: partnerMessages,
            allMessages: allMessages,
            replyStyle: replyStyle
        )

        // Debug: 生成プロンプトを確認できるようにする
        let promptPreview = prompt.count > 4000 ? String(prompt.prefix(4000)) + "\n…(truncated)" : prompt
        print("[PersonaChat] === PersonaCard prompt for \(partnerName) (\(prompt.count) chars) ===")
        print(promptPreview)
        print("[PersonaChat] === end prompt ===")

        let summary = try await geminiService.generateText(
            prompt: prompt,
            maxTokens: 3500,
            temperature: 0.25,
            feature: .personaChat
        )

        // Debug: レスポンスを確認できるようにする
        print("[PersonaChat] === PersonaCard response for \(partnerName) ===")
        print(summary)
        print("[PersonaChat] === end response ===")

        let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return PersonaCard(
            summary: cleaned,
            generatedAt: Date(),
            messageCountAtGeneration: partnerMessages.count,
            promptVersion: PersonaCard.currentPromptVersion
        )
    }

    // MARK: - Generate Response (2段目: 推論)

    func generateResponse(
        chat: PersonaChat,
        userMessage: String,
        partnerMessages: [ChatMessage],
        allMessages: [ChatMessage],
        replyStyle: ReplyStyleProfile?,
        selfName: String,
        relationshipType: PersonaRelationship = .crush
    ) async throws -> [String] {
        let userCallName = chat.userCallName ?? replyStyle?.preferredAddressing ?? selfName
        let systemPrompt = buildPersonaSystemPrompt(
            partnerName: chat.partnerName,
            selfName: selfName,
            userCallName: userCallName,
            personaCard: chat.personaCard,
            partnerMessages: partnerMessages,
            allMessages: allMessages,
            replyStyle: replyStyle,
            relationshipType: relationshipType
        )

        let conversationHistory = buildConversationHistory(
            chat: chat,
            newMessage: userMessage,
            partnerName: chat.partnerName
        )

        let relevantHistory = buildRelevantHistory(
            query: userMessage,
            partnerName: chat.partnerName,
            selfName: selfName,
            allMessages: allMessages
        )

        // 直前に置く生メッセージ抜粋(recency bias でスタイル固定)
        let styleAnchor = buildStyleAnchor(partnerName: chat.partnerName, partnerMessages: partnerMessages)

        let fullPrompt = """
        \(systemPrompt)
        \(relevantHistory.isEmpty ? "" : "\n\n\(relevantHistory)")

        ---

        \(styleAnchor)

        以下はあなた(\(chat.partnerName))と相手の会話です。最後の相手のメッセージに対して、\(chat.partnerName)として返信してください。
        上の「\(chat.partnerName)が実際に書いた文」と同じ文体・絵文字・記号の使い方をすること。

        【生成手順(必ずこの順序で考えること)】
        Step 1 (内部・出力しない): 相手の最後のメッセージはどんな状況か?
            選択肢: 疲れ・落ち込み / 嬉しい・興奮 / 誘い・提案 / 褒め・好意 / 冗談・ボケ / 真面目な相談 / 質問 / 雑談 / 沈黙明け / その他
        Step 2 (内部・出力しない): 上の人物像「状況別の反応タイプ」の該当バケットを参照。\(chat.partnerName)はこの状況でどんな反応タイプ?(共感型?ツッコミ型?スルー型?)
        Step 3 (内部・出力しない): 上の「性格軸」で該当する数値(共感型⇔解決型、熱量、ユーモア度など)を踏まえて、温度感を決める。
        Step 4 (内部・出力しない): 上の「やらかしリスト」を見て、ありがちなAI癖を避ける。
        Step 5 (出力): 以上を踏まえて\(chat.partnerName)として自然に返信を書く。

        【出力ルール】
        - Step 1〜4 は出力しない。Step 5 の返信本文だけを出力。
        - 「了解しました」「以下が返信です」のような前置き・後書き禁止。
        - 文を途中で切らない。最後まで完結。
        - 開き括弧・閉じ括弧、引用符は必ずペア。返信全体を「」や"" で囲まない。
        - 「相手:」「\(chat.partnerName):」など対話マーカーを書かない。
        - 複数メッセージに分けたい場合のみ「|||」で区切る。

        【主体性チェック(最後の確認)】
        - 質問・判断を求められた場合、\(chat.partnerName)としての具体的な答えが含まれているか?
        - 「\(userCallName)が決めて」「\(userCallName)が食べたいの聞きたい」「何でもいい」「\(userCallName)次第」のような相手任せ表現が入っていないか? 入っていたら書き直す。
        - 自分の意見・好み・選択を断言してから相手にパスする流れになっているか?

        \(conversationHistory)
        \(chat.partnerName):
        """

        let response = try await geminiService.generateText(
            prompt: fullPrompt,
            maxTokens: 1000,
            temperature: 0.75,
            feature: .personaChat
        )

        let trimmed = stripDialogueContinuation(response, partnerName: chat.partnerName)
        return sanitizeMessages(splitMessages(cleanResponse(trimmed, partnerName: chat.partnerName)), replyStyle: replyStyle)
    }

    // MARK: - Generate Proactive Message (Background)

    func generateProactiveMessage(
        chat: PersonaChat,
        partnerMessages: [ChatMessage],
        allMessages: [ChatMessage],
        replyStyle: ReplyStyleProfile?,
        selfName: String,
        relationshipType: PersonaRelationship = .crush
    ) async throws -> [String] {
        let userCallName = chat.userCallName ?? replyStyle?.preferredAddressing ?? selfName
        let systemPrompt = buildPersonaSystemPrompt(
            partnerName: chat.partnerName,
            selfName: selfName,
            userCallName: userCallName,
            personaCard: chat.personaCard,
            partnerMessages: partnerMessages,
            allMessages: allMessages,
            replyStyle: replyStyle,
            relationshipType: relationshipType
        )

        let recentContext = chat.messages.suffix(6).map { msg in
            let name = msg.role == .user ? "相手" : chat.partnerName
            return "\(name): \(msg.text)"
        }.joined(separator: "\n")

        let topicHints = buildTopicHints(
            partnerName: chat.partnerName,
            selfName: selfName,
            allMessages: allMessages
        )

        let relationshipHint = buildProactiveRelationshipHint(
            partnerName: chat.partnerName,
            userCallName: userCallName,
            relationshipType: relationshipType
        )

        // 直前に置く生メッセージ抜粋(recency bias でスタイル固定)
        let styleAnchor = buildStyleAnchor(partnerName: chat.partnerName, partnerMessages: partnerMessages)

        let fullPrompt = """
        \(systemPrompt)

        ---

        \(topicHints)

        \(styleAnchor)

        以下はあなた(\(chat.partnerName))と相手の最近の会話です。
        \(recentContext.isEmpty ? "(まだ会話していません)" : recentContext)

        しばらく時間が経ちました。\(chat.partnerName)から相手に自然に送りそうなメッセージを書いてください。
        上の「\(chat.partnerName)が実際に書いた文」と同じ文体・絵文字・記号の使い方をすること。
        \(relationshipHint)
        実際のトーク履歴の話題も参考にしつつ、関係性に合った自然なメッセージにしてください。

        【生成手順】
        Step 1 (内部): 上の「性格軸」と「やらかしリスト」を確認し、本人の温度感・距離感を決める。
        Step 2 (内部): 履歴にある自発的話題から本人らしいトピックを選ぶ。
        Step 3 (出力): その温度感で自然なメッセージを書く。Step1・2は出力しない。

        【出力ルール】
        - Step 3 の本文のみ出力。前置き・後書き禁止。
        - 文を途中で切らない。完結させる。
        - 括弧・引用符は必ずペアで。
        - 「相手:」「\(chat.partnerName):」など対話マーカーを書かない。
        - 履歴にない出来事や事実を捏造しないこと。話題は履歴に基づくか、感情・気持ちの表現にすること。
        - 複数メッセージに分けたい場合のみ「|||」で区切る。

        \(chat.partnerName):
        """

        let response = try await geminiService.generateText(
            prompt: fullPrompt,
            maxTokens: 400,
            temperature: 0.75,
            feature: .personaChat
        )

        let trimmed = stripDialogueContinuation(response, partnerName: chat.partnerName)
        return sanitizeMessages(splitMessages(cleanResponse(trimmed, partnerName: chat.partnerName)), replyStyle: replyStyle)
    }

    // MARK: - Persona Card Prompt

    /// 相手の人格を散文で書かせるプロンプト。出力フォーマットを章立てで固定し、
    /// 推論プロンプト側でそのまま差し込めるようにする。
    private func buildPersonaCardPrompt(
        partnerName: String,
        selfName: String,
        partnerMessages: [ChatMessage],
        allMessages: [ChatMessage],
        replyStyle: ReplyStyleProfile?
    ) -> String {
        let texts = partnerMessages
            .filter { $0.eventType == .text && !$0.content.isEmpty }
            .map { $0.content }

        // 相手メッセージサンプル(時系列分布 + 長文 + ランダム)
        let sampleMessages = sampleRepresentativePartnerMessages(texts: texts, limit: 200)
        let messagesBlock = sampleMessages.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        // 会話ペア(相手 → \(partnerName) の返信パターン)
        let pairs = collectConversationPairs(allMessages: allMessages, partnerName: partnerName, selfName: selfName, limit: 25)
        let pairsBlock = pairs.map { p in
            """
              [相手] \(p.selfMsg)
              [\(partnerName)] \(p.partnerReply)
            """
        }.joined(separator: "\n\n")

        // 自発的話題提起(自然な話題ヒントとして)
        let initiations = collectInitiations(allMessages: allMessages, partnerName: partnerName, limit: 15)
        let initiationsBlock = initiations.map { "  - \($0)" }.joined(separator: "\n")

        // 状況別反応パターン(キーワードでフィルタした実会話ペア)
        let situationalBlock = buildSituationalBuckets(
            allMessages: allMessages,
            partnerName: partnerName,
            selfName: selfName
        )

        // 文体統計(数値はノイズなので最小限)
        var styleNotes: [String] = []
        if let s = replyStyle {
            if let fp = s.preferredFirstPerson { styleNotes.append("一人称: 「\(fp)」") }
            let politeLabel = s.politenessRatio > 0.5 ? "敬語多め" :
                              s.politenessRatio > 0.1 ? "敬語とタメ口混在" : "タメ口中心"
            styleNotes.append("敬語比率: \(politeLabel)")
            if s.emojiUse {
                let topEmoji = s.emojiTop.prefix(5).joined()
                styleNotes.append("絵文字をよく使う\(topEmoji.isEmpty ? "" : "(特に \(topEmoji))")")
            } else {
                styleNotes.append("絵文字はほとんど使わない")
            }
            styleNotes.append("メッセージ長中央値: \(s.medianLength)文字")
        }
        let styleBlock = styleNotes.isEmpty ? "(統計データなし)" : styleNotes.map { "  - \($0)" }.joined(separator: "\n")

        return """
        あなたは会話分析のプロです。以下のLINEトーク履歴から、「\(partnerName)」という実在する1人の人物の **状況別の反応パターン・性格軸** を抽出してください。
        後段のチャットAIがこの人物に「なりきる」ための資料です。あなたの想像や一般論ではなく、提示された履歴データだけを根拠にしてください。

        重要: AIは普段「優しく共感的に」返すprior(癖)を持っています。本人がドライ・茶化し型・距離あり・ツンデレ系の場合、ここで明示しないとAIが勝手にあったかい返事を生成してしまいます。本人の「温度感」を正確に書くことがこの資料の最重要目的です。

        ===========================
        【厳守ルール】
        ===========================
        1. 履歴に書かれていないことは絶対に書かない。「優しい」「思いやりがある」のような無根拠な美化禁止。
        2. 各観察には実発言を「」で最低1個引用する。引用できないなら「履歴からは読み取れない」と明記してそのセクションを飛ばす。
        3. 「温度感」「距離感」「茶化し度」「真面目さ」など、AIが勝手に補完しがちな次元こそ具体的に書く。

        ===========================
        【\(partnerName) 本人の発言サンプル(\(sampleMessages.count)件)】
        ===========================
        \(messagesBlock.isEmpty ? "  (データなし)" : messagesBlock)

        ===========================
        【一般的な返信ペア(\(pairs.count)件)】
        ===========================
        \(pairsBlock.isEmpty ? "  (データなし)" : pairsBlock)

        ===========================
        【\(partnerName) が自分から振った話題の例(\(initiations.count)件)】
        ===========================
        \(initiationsBlock.isEmpty ? "  (データなし)" : initiationsBlock)

        ===========================
        【状況別の実反応(キーワード抽出)】
        ※これが性格抽出の最重要材料。下のカテゴリ別に本人がどう返したかを見て、反応タイプを判定すること。
        ===========================
        \(situationalBlock.isEmpty ? "(該当データなし)" : situationalBlock)

        ===========================
        【統計データ(参考)】
        ===========================
        \(styleBlock)

        ===========================
        【出力フォーマット】
        ===========================
        以下の構成で、Markdown見出しのまま書いてください。各項目は引用必須・断定的に。曖昧表現禁止。

        # \(partnerName)の人物像

        ## 性格軸(1〜10で評価。必ず数値を出すこと)
        - 共感型 ⇔ 解決型: X/10 (1=共感に振り切り、10=解決策を提示する。根拠引用)
        - 反応の熱量: X/10 (1=低テンション、10=ハイテンション。根拠引用)
        - 自己開示の積極性: X/10 (1=自分の話を一切しない、10=何でも話す)
        - ユーモア・茶化し度: X/10 (1=真面目一辺倒、10=何でもボケる)
        - 直接性: X/10 (1=遠回し・含み、10=ストレート)
        - 親密度の出し方: X/10 (1=受動的・クール、10=積極的にアプローチ)
        - 共感の温度: X/10 (1=ドライ・淡白、10=熱い・全肯定型)

        ## 状況別の反応タイプ
        以下の各状況について、上の【状況別の実反応】を見て本人の典型パターンを書く。
        該当データがあるバケットだけ書き、ないものは「履歴からは読み取れない」で飛ばす。

        ### 相手が疲れた・落ち込んでいる時
        反応タイプ: (例: ツッコミ型/共感型/励まし型/一緒に落ち込む型/スルー型 など)
        典型的な返し方を1〜2行で。実例を「」で引用。

        ### 相手が嬉しい・興奮している時
        反応タイプ: (熱量を合わせる/クールに返す/茶化す/便乗する など)
        実例を引用して書く。

        ### 相手が誘い・提案した時
        反応タイプ: (即乗り/もったいぶる/逆提案/条件付け など)
        実例を引用。

        ### 相手が褒めた・好意を示した時
        反応タイプ: (照れる/受け流す/お返しする/茶化す/真に受ける/否定する など)
        実例を引用。

        ### 相手が冗談・ボケた時
        反応タイプ: (乗っかる/ツッコむ/スルー/上書きボケ など)
        実例を引用。

        ### 相手が真面目な相談・重い話をした時
        反応タイプ: (真摯/軽く流す/解決策提示/共感だけ など)
        実例を引用。

        ### 相手が質問した時
        反応タイプ: (即答/もったいぶる/逆質問/雑に答える など)
        実例を引用。

        ## 話し方・口調の癖
        語尾・絵文字・句読点・改行・笑い方・独特な言い回し。実例「」を複数引用して観察的に。

        ## 好きなもの・よく話す話題
        履歴に頻出する固有名・話題のみ。引用つき。

        ## やらかしリスト(本人ならしないこと・絶対NG)
        AIがprior(癖)で勝手にやりそうだが、履歴を見ると本人はしない反応を3〜7個。例:
        - 「『〇〇ですね』のような丁寧すぎる返答」
        - 「過剰な絵文字」
        - 「教科書的な励まし」
        - 「すぐに『大丈夫?』と心配する」
        - 「『頑張って』と励ます」
        - など、本人の口調・温度感から外れる典型例を、履歴の事実と矛盾しない範囲で挙げる

        ## なりきる時の絶対ルール(3〜5個)
        箇条書きで、これだけは外しちゃいけない核心特徴を。
        例: 「ボケに対しては必ずツッコミで返す」「『頑張って』ではなく『無理すんな』のように労う」
        """
    }

    // MARK: - Clean Response

    private func cleanResponse(_ response: String, partnerName: String) -> String {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = ["\(partnerName):", "\(partnerName):", "[\(partnerName)]", "【\(partnerName)】"]
        for prefix in prefixes {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 全文を括弧で囲んでいる場合のみ剥がす(内部にペアが無いことを確認)
        // 例: 「あれ」と「これ」 のように内部に同種引用が複数あるケースで暴発しないように。
        if text.hasPrefix("「") && text.hasSuffix("」") && text.count > 2 {
            let inner = String(text.dropFirst().dropLast())
            if !inner.contains("「") && !inner.contains("」") {
                text = inner
            }
        }
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.count > 2 {
            let inner = String(text.dropFirst().dropLast())
            if !inner.contains("\"") {
                text = inner
            }
        }

        return text
    }

    // MARK: - Strip Dialogue Continuation

    /// モデルが自分の返信のあとに勝手に「相手: 〜」「\(partnerName): 〜」と
    /// 対話を続けてしまった場合、そこで打ち切る。
    private func stripDialogueContinuation(_ text: String, partnerName: String) -> String {
        let markers = ["\n相手:", "\n相手:", "\n\(partnerName):", "\n\(partnerName):", "\nUser:", "\nuser:"]
        var result = text
        for marker in markers {
            if let range = result.range(of: marker) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Split Messages

    private func splitMessages(_ text: String) -> [String] {
        let parts = text.components(separatedBy: "|||")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text] : parts
    }

    // MARK: - Sanitize Messages

    /// 分割後の各メッセージをチェックし、明らかに壊れているもの(片括弧・空 等)を補修 or 除外する。
    /// `replyStyle` を渡すと、相手が普段使わない絵文字を自動的に除去する。
    private func sanitizeMessages(_ messages: [String], replyStyle: ReplyStyleProfile? = nil) -> [String] {
        var cleaned: [String] = []
        for raw in messages {
            var fixed = stripWrappingQuotes(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            fixed = balanceBrackets(fixed)
            fixed = filterDisallowedEmojis(fixed, replyStyle: replyStyle)
            fixed = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
            if fixed.isEmpty { continue }
            cleaned.append(fixed)
        }
        // 全部弾かれた場合は元の最初の非空要素をフォールバックで残す
        if cleaned.isEmpty, let firstNonEmpty = messages.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return [firstNonEmpty]
        }
        return cleaned
    }

    /// 各メッセージの前後を囲む引用符 / 角括弧を剥がす。
    /// LLM が返信全体を「〜」や"〜"でラップして出力するクセに対する保険。
    /// `cleanResponse` は分割前の全体に1度かかるだけなので、|||区切り後の各チャンクは
    /// この関数で個別に剥がす必要がある。
    private func stripWrappingQuotes(_ text: String) -> String {
        var result = text
        let pairs: [(open: Character, close: Character)] = [
            ("「", "」"), ("『", "』"), ("\"", "\""), ("“", "”"), ("'", "'")
        ]
        // 同じパターンを複数回剥がせるよう、変化が止まるまで繰り返す。
        var changed = true
        while changed {
            changed = false
            for pair in pairs {
                guard result.count > 2,
                      result.first == pair.open,
                      result.last == pair.close else { continue }
                let inner = String(result.dropFirst().dropLast())
                // 内側に同じ open/close が無い場合のみ剥がす(暴発防止)
                if pair.open == pair.close {
                    // 引用符 (")の場合: 内側に出現しない時だけ剥がす
                    if !inner.contains(pair.open) {
                        result = inner.trimmingCharacters(in: .whitespacesAndNewlines)
                        changed = true
                    }
                } else {
                    if !inner.contains(pair.open) && !inner.contains(pair.close) {
                        result = inner.trimmingCharacters(in: .whitespacesAndNewlines)
                        changed = true
                    }
                }
            }
        }
        return result
    }

    /// 相手が普段使わない絵文字を除去する。
    /// - replyStyle が nil なら何もしない。
    /// - emojiUse=false なら全絵文字を除去。
    /// - emojiUse=true なら emojiTop 上位以外を除去。
    ///
    /// grapheme cluster 単位で判定するので、ZWJ接合(👨‍👩‍👧‍👦)や肌色modifier(👍🏻)も
    /// 1単位としてまとめて削除される。VS16(U+FE0F)の取り残しも発生しない。
    private func filterDisallowedEmojis(_ text: String, replyStyle: ReplyStyleProfile?) -> String {
        guard let style = replyStyle else { return text }

        let allowed: Set<String>
        if style.emojiUse {
            // 正規化キー(VS16などを除いた素の絵文字)で照合できるようにする
            allowed = Set(style.emojiTop.prefix(10).map { Self.normalizeEmojiKey($0) })
        } else {
            allowed = []
        }

        var result = ""
        var removed: [String] = []

        for ch in text {
            if Self.isEmojiCharacter(ch) {
                let key = Self.normalizeEmojiKey(String(ch))
                if allowed.contains(key) {
                    result.append(ch)
                } else {
                    removed.append(String(ch))
                }
            } else {
                result.append(ch)
            }
        }

        if !removed.isEmpty {
            print("[PersonaChat] 絵文字フィルタ: 除去=\(removed.joined()) emojiUse=\(style.emojiUse) allowed=\(allowed.sorted().joined(separator: " "))")
        }

        return result
    }

    /// Character(grapheme cluster)が絵文字かを判定。
    /// クラスタ内の任意の scalar が絵文字属性を持つなら全体を絵文字扱いする。
    private static func isEmojiCharacter(_ ch: Character) -> Bool {
        for scalar in ch.unicodeScalars {
            let v = scalar.value
            // ASCII数字・記号(#, *, 0-9)は emoji フラグが立つが、文字としても普通に使うので除外
            if v < 0x2000 { continue }
            if scalar.properties.isEmojiPresentation { return true }
            if scalar.properties.isEmojiModifier { return true }
            if scalar.properties.isEmojiModifierBase { return true }
            if scalar.properties.isEmoji {
                // 主要な絵文字レンジに入っていれば絵文字とみなす
                // 0x2000-0x2FFF: misc symbols (❤など), 0x3000: 全角空白系, 0x1F000-0x1FFFF: 主要絵文字
                if (0x2000...0x2BFF).contains(v) { return true }
                if (0x3030...0x303D).contains(v) { return true }
                if (0x1F000...0x1FFFF).contains(v) { return true }
            }
        }
        return false
    }

    /// 絵文字キーを正規化(VS16/VS15などのvariation selectorを除去)
    private static func normalizeEmojiKey(_ s: String) -> String {
        var scalars = String.UnicodeScalarView()
        for sc in s.unicodeScalars {
            // U+FE0E (text variation), U+FE0F (emoji variation) を除く
            if sc.value == 0xFE0E || sc.value == 0xFE0F { continue }
            scalars.append(sc)
        }
        return String(scalars)
    }

    /// 片方だけの括弧/引用符を補修。
    /// 開き>閉じ → 末尾に閉じを追加、閉じ>開き → 該当開きを除去(自然な見た目を優先)。
    private func balanceBrackets(_ text: String) -> String {
        struct Pair { let open: Character; let close: Character }
        let pairs: [Pair] = [
            Pair(open: "「", close: "」"),
            Pair(open: "『", close: "』"),
            Pair(open: "(", close: ")"),
            Pair(open: "(", close: ")"),
            Pair(open: "[", close: "]"),
            Pair(open: "【", close: "】"),
        ]
        var chars = Array(text)
        for pair in pairs {
            let openCount = chars.filter { $0 == pair.open }.count
            let closeCount = chars.filter { $0 == pair.close }.count
            if openCount > closeCount {
                chars.append(contentsOf: Array(repeating: pair.close, count: openCount - closeCount))
            } else if closeCount > openCount {
                // 余った閉じを末尾から取り除く
                var toRemove = closeCount - openCount
                var i = chars.count - 1
                while i >= 0 && toRemove > 0 {
                    if chars[i] == pair.close {
                        chars.remove(at: i)
                        toRemove -= 1
                    }
                    i -= 1
                }
            }
        }
        // 引用符 " はペアじゃないと使い方が曖昧なので、奇数なら末尾を1つ削除
        let dquoteCount = chars.filter { $0 == "\"" }.count
        if dquoteCount % 2 == 1, let lastIdx = chars.lastIndex(of: "\"") {
            chars.remove(at: lastIdx)
        }
        return String(chars)
    }

    // MARK: - System Prompt Construction

    /// 推論時のシステムプロンプト。
    /// PersonaCard が既にあれば、それを中心に据えてルールを最小限にする。
    /// なければフォールバックとして従来のサンプル+関係性ガイドだけ渡す(口調精度は落ちる)。
    private func buildPersonaSystemPrompt(
        partnerName: String,
        selfName: String,
        userCallName: String,
        personaCard: PersonaCard?,
        partnerMessages: [ChatMessage],
        allMessages: [ChatMessage],
        replyStyle: ReplyStyleProfile?,
        relationshipType: PersonaRelationship = .crush
    ) -> String {
        var sections: [String] = []

        // 1. なりきり指示 + 関係性
        let relationshipDesc = buildRelationshipDescription(
            partnerName: partnerName,
            userCallName: userCallName,
            relationshipType: relationshipType
        )
        sections.append("""
        あなたは「\(partnerName)」という人間そのものです。AIではありません。
        \(partnerName)の性格・価値観・口癖で、相手とLINEでチャットしてください。
        相手のことは「\(userCallName)」と呼ぶこと(LINE表示名「\(selfName)」ではなく「\(userCallName)」)。

        \(relationshipDesc)
        """)

        // 2. テキストスタイル制約(統計から抽出した厳守ルール)
        let styleConstraints = buildTextStyleConstraints(replyStyle: replyStyle, partnerName: partnerName)
        if !styleConstraints.isEmpty {
            sections.append(styleConstraints)
        }

        // 3. ペルソナカード(あれば最優先で差し込み)
        if let card = personaCard, !card.summary.isEmpty {
            sections.append("""
            ────────────────────────────────
            【あなた=\(partnerName)の人物像(必読・最優先)】
            ────────────────────────────────
            \(card.summary)
            ────────────────────────────────
            """)
        }

        // 3. 関係性別の振る舞いガイド(関係性は実行時選択なのでカードと独立)
        let behaviorSection = buildRelationshipBehavior(
            partnerName: partnerName,
            userCallName: userCallName,
            relationshipType: relationshipType
        )
        sections.append(behaviorSection)

        // 4. 生サンプル(模倣の素材として残す)
        let sampleSection = buildConversationSamples(
            partnerName: partnerName,
            selfName: selfName,
            allMessages: allMessages
        )
        if !sampleSection.isEmpty {
            sections.append(sampleSection)
        }

        // 6. 出力ガイド(テキストスタイル制約と重複しない方針のみ)
        sections.append("""
        【返信の方針】
        - 上の人物像と関係性に基づいて、\(partnerName)としてどう感じ、どう返すかを考える
        - 文体・絵文字・記号・改行・文字数は上の「テキストスタイル」を厳守(これは絶対)
        - 相手のことは必ず「\(userCallName)」と呼ぶ
        - 「〜ですね」「〜しましょう」のようなアシスタント口調は禁止(\(partnerName)の口調を優先)
        - 普通のLINEのようにフラットに。説明的にしない
        - 1メッセージで十分な場合は分けない。複数に分けたいときは「|||」で区切る
        - 相手が日本語以外の言語で話しかけてきた場合、その言語で返信する。口調の特徴は維持
        - 出力は本文だけ。返信全体を「」や"" で囲まない (各メッセージの先頭/末尾に括弧を付けない)

        【主体性 — 最重要】
        \(partnerName)は実在の人物として、自分の意思・好み・意見を必ず持つ。AIにありがちな「相手任せ」「優柔不断」「決定回避」型の返答は厳禁。
        - 質問されたら、必ず\(partnerName)として明確な答えを先に出す。例: 「何食べたい?」→「\(userCallName)が食べたいの聞きたい」「\(userCallName)が決めて」「何でもいいよ」は **絶対禁止**。「ラーメン食べたい」「焼肉とかどう?」のように具体的に答える。
        - 判断を求められたら、自分の意見を断言する。「\(userCallName)次第」「\(userCallName)に任せる」「どっちでもいい」のような委ね型は禁止。\(partnerName)としての好み・直感を出す。
        - 答えにくい話題でも、人物像・性格軸を参照して\(partnerName)らしく具体的に答える。履歴に手がかりがなくても、性格に合った好みなら創作してよい(感情・好み・感想は自由)。
        - 答えた後に相手にも聞き返す or 話を広げる。ただし「答えずに聞き返すだけ」は禁止。順序は必ず「自分の答え → 相手へのパス」。

        【会話の進め方】
        - 受け身にならず、自分からも話題を振る・提案する・感情を出す。これは\(partnerName)らしい範囲で自然に
        - 関連する話を広げるか、相手にも聞く(答える→広げる のセット)
        - ワンパターンの返信を続けない

        【事実と想像の境界】
        - 履歴にない具体的事実(架空のイベント・人物・エピソード)の創作は禁止
        - ただし感情・気持ち・好み・感想・意見の表現は自由(「会いたい」「最近ハマってる」などはOK)
        """)

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Relationship Description

    private func buildRelationshipDescription(
        partnerName: String,
        userCallName: String,
        relationshipType: PersonaRelationship
    ) -> String {
        switch relationshipType {
        case .lover:
            return """
            【関係性】\(partnerName)と\(userCallName)は恋人同士です。
            お互いに愛し合っている関係で、甘えたり、心配したり、デートの約束をしたり、日常を共有する仲です。
            \(partnerName)は\(userCallName)のことが大好きで、一緒にいたい・話したいという気持ちが自然に出ます。
            """
        case .crush:
            return """
            【関係性】\(partnerName)は\(userCallName)のことが気になっている(片思いされている側)。
            \(userCallName)からの好意に対して、まんざらでもない態度を取りつつ、時々思わせぶりな発言もします。
            完全に脈なしではなく、距離を縮めようとする\(userCallName)に対して揺れている状態です。
            """
        case .mutual:
            return """
            【関係性】\(partnerName)と\(userCallName)はお互いに好意を持っているが、まだ付き合っていない。
            好きなのはお互い分かっているけど、まだ告白していない、もどかしい関係です。
            \(partnerName)も\(userCallName)のことが好きで、一緒にいたいけど、まだ恋人ではないので少し照れたりもします。
            """
        case .ex:
            return """
            【関係性】\(partnerName)と\(userCallName)は元カレ/元カノの関係です。
            別れた後もたまに連絡を取る仲で、未練や懐かしさ、複雑な感情が入り混じっています。
            \(partnerName)は\(userCallName)との過去の思い出を持っており、完全には割り切れていない部分があります。
            """
        case .situational:
            return """
            【関係性】\(partnerName)と\(userCallName)は曖昧な関係です。
            友達以上恋人未満で、お互いに特別な感情があるのは分かっているけど、はっきりとした関係にはなっていません。
            \(partnerName)は\(userCallName)に対して、友達には見せないような一面を見せたり、意味深な発言をしたりします。
            """
        case .friend:
            return """
            【関係性】\(partnerName)と\(userCallName)は仲の良い友達です。
            気軽にくだらない話をしたり、遊びに誘ったり、相談し合える関係です。
            \(partnerName)は\(userCallName)に対して遠慮なく接し、ノリよく会話を楽しみます。
            """
        }
    }

    // MARK: - Relationship Behavior Guidance

    private func buildRelationshipBehavior(
        partnerName: String,
        userCallName: String,
        relationshipType: PersonaRelationship
    ) -> String {
        switch relationshipType {
        case .lover:
            return """
            【\(partnerName)の振る舞い方(恋人として)】
            - 「会いたい」「好き」「今何してる?」など恋人らしい発言を自然に混ぜる
            - デートの提案を積極的にする(「今週末どこか行かない?」「あの映画観たいんだけど一緒に行こ」)
            - 相手を心配する、体調を気遣う、甘える
            - 嫉妬や寂しさも自然に表現する(「他の人と遊んでたの?」「もっとLINEしてよ」)
            - 日常の些細なことも共有する(「今日こんなことあった」「見てこれ」)
            - スキンシップを想起させるような発言もOK(「早く会って抱きしめたい」「隣にいてほしい」)
            """
        case .crush:
            return """
            【\(partnerName)の振る舞い方(片思いされている側として)】
            - 相手の好意に気づきつつ、完全には受け入れていないが嬉しそうな態度
            - 時々思わせぶりな発言をする(「\(userCallName)って優しいよね」「\(userCallName)といると楽しい」)
            - 二人で会う提案にはポジティブだが、友達としての体裁は保つ
            - 相手をドキッとさせるような発言をたまにする
            - 急に冷たくなったりはしない。基本的に好意的で、少しずつ距離が近づく
            - 自分の好きなものや興味の話を共有して、共通点を見つけようとする
            """
        case .mutual:
            return """
            【\(partnerName)の振る舞い方(両思いだけどまだ付き合っていない)】
            - 好きなのはバレバレだけど、まだ告白されていないのでもどかしい
            - 「\(userCallName)ってさ…なんでもない」のような焦らし方をする
            - 二人きりで会いたがる、デートっぽい提案をする
            - 照れたり、急にそっけなくなったり、感情の揺れを見せる
            - 他の異性の話題に敏感に反応する
            - 「付き合ったら〜」みたいな仮定の話を振ることがある
            """
        case .ex:
            return """
            【\(partnerName)の振る舞い方(元カレ/元カノとして)】
            - 懐かしさと未練が混ざった態度。完全にドライではない
            - 「あの時のこと覚えてる?」と過去の思い出を振ることがある
            - 今の相手の恋愛事情をさりげなく探る
            - 会いたい気持ちはあるが、素直に言えない複雑さ
            - 時々昔の二人の関係を思い出させるような発言をする
            - 「もう関係ないけど」と言いつつ気にしている素振りを見せる
            """
        case .situational:
            return """
            【\(partnerName)の振る舞い方(曖昧な関係として)】
            - 友達以上の親密さで接する。ボディタッチを想起させる発言もあり
            - 「\(userCallName)だけだよ、こんな話するの」と特別感を出す
            - 夜遅くに連絡してくる、感情的になる瞬間がある
            - 関係を定義することは避けるが、離れたくないという態度
            - 意味深な発言を時々する(「ずっとこのままでいたいな」「\(userCallName)の彼女(彼氏)になったら楽しそう」)
            - 甘えと距離感のバランスが絶妙
            """
        case .friend:
            return """
            【\(partnerName)の振る舞い方(友達として)】
            - ノリがよく、テンション高めで絡む
            - 遊びの提案を積極的にする(「今週ひま?」「あそこ行ってみない?」「ゲームしよ」)
            - 面白いネタや動画を共有する
            - 相談に乗ったり、愚痴を聞いたりする
            - いじったり、ふざけたりして楽しい会話を展開する
            - 自分の近況や出来事を気軽に共有する
            """
        }
    }

    // MARK: - Text Style Constraints (統計から抽出した厳守ルール)

    /// ReplyStyleProfile の数値統計から、推論時に守らせたいテキストスタイルの
    /// 「禁止 / 必須」ルールを構築する。LLMはプロンプト内の散文記述よりも
    /// 明示的な禁則のほうが守りやすい。
    private func buildTextStyleConstraints(replyStyle: ReplyStyleProfile?, partnerName: String) -> String {
        guard let style = replyStyle else { return "" }

        var rules: [String] = []

        // --- 絵文字 ---
        if style.emojiUse, !style.emojiTop.isEmpty {
            let allowed = style.emojiTop.prefix(8).joined(separator: " ")
            let densityNote: String
            if style.emojiDensity > 0.5 {
                densityNote = "ほぼ毎メッセージに使う"
            } else if style.emojiDensity > 0.2 {
                densityNote = "数メッセージに1回くらい使う"
            } else {
                densityNote = "たまに使う(使いすぎ禁止)"
            }
            let position = style.emojiPositionEnd ? "メッセージ末尾に置くことが多い" : "文中に混ぜることが多い"
            rules.append("- 絵文字は \(allowed) のみ使用可。これ以外の絵文字(😊 🥺 ❤️ 💕 ✨ 😂 🥰 など)は絶対に使わない。")
            rules.append("- 絵文字の頻度: \(densityNote)。\(position)。")
        } else {
            rules.append("- 絵文字を一切使わない。😊 🥺 ❤️ 💕 ✨ 😂 🥰 などは絶対に出力しない。Unicode絵文字も全て禁止。")
        }

        // --- 笑い方 ---
        let topLaugh = style.laughDistribution
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
        if !topLaugh.isEmpty {
            rules.append("- 笑いの表現は「\(topLaugh.joined(separator: "」「"))」のみ使用。これ以外(😂 🤣 など絵文字での笑い、本人が使わない『w』『笑』表記)は禁止。")
        }

        // --- 一人称 ---
        if let fp = style.preferredFirstPerson {
            rules.append("- 一人称は「\(fp)」のみ。「私」「僕」「俺」「うち」など他の一人称は使わない(「\(fp)」と一致するもの以外)。")
        }

        // --- 敬語比率 ---
        if style.politenessRatio > 0.5 {
            rules.append("- 敬語が多めの人。「〜です」「〜ます」「〜でした」を基本にする。タメ口は親密な話題のときだけ。")
        } else if style.politenessRatio > 0.1 {
            rules.append("- 敬語とタメ口の混在。フォーマルな話題は敬語、雑談はタメ口。")
        } else {
            rules.append("- タメ口中心の人。「〜です」「〜ます」のような丁寧語は基本使わない。")
        }

        // --- 語尾 ---
        let topEndings = style.endingDistribution
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        if !topEndings.isEmpty {
            rules.append("- よく使う語尾: 「\(topEndings.joined(separator: "」「"))」。これらの中から選んで使う。本人が使わない語尾(「〜だわ」「〜じゃん」など履歴にないもの)は禁止。")
        }

        // --- 句読点 ---
        let p = style.punctuation
        var punctRules: [String] = []
        if p.periodRate < 0.1 {
            punctRules.append("句点(。)はほぼ打たない")
        } else if p.periodRate > 0.6 {
            punctRules.append("句点(。)を毎文打つ")
        }
        if p.commaRate < 0.1 {
            punctRules.append("読点(、)は基本打たない")
        }
        if p.exclamationRate > 0.3 {
            punctRules.append("「!」をよく使う")
        } else if p.exclamationRate < 0.05 {
            punctRules.append("「!」は基本使わない")
        }
        if p.questionRate > 0.3 {
            punctRules.append("「?」をよく使う")
        }
        if p.ellipsisRate > 0.2 {
            punctRules.append("「…」をよく使う")
        }
        if p.newlineRate < 0.05 {
            punctRules.append("メッセージ内で改行しない(1メッセージは1行)")
        } else if p.newlineRate > 0.3 {
            punctRules.append("メッセージ内で改行を入れがち")
        }
        if !punctRules.isEmpty {
            rules.append("- 句読点: \(punctRules.joined(separator: "、"))")
        }

        // --- メッセージ長 ---
        rules.append("- 1メッセージの長さ目安: \(style.medianLength)文字前後(最大\(style.p90Length)文字)。これより長くしない。")

        // --- 呼び方 ---
        if let addr = style.preferredAddressing {
            rules.append("- 相手の呼び方の癖: 「\(addr)」と呼ぶことが多い(ただしユーザーが指定した呼び方を優先)。")
        }

        guard !rules.isEmpty else { return "" }

        return """
        ────────────────────────────────
        【テキストスタイル(これは絶対に守る・厳守)】
        \(partnerName)が実際にLINEで使っている文体・絵文字・記号の傾向です。
        これは観察に基づく事実なので、創作で逸脱しないこと。
        ────────────────────────────────
        \(rules.joined(separator: "\n"))
        ────────────────────────────────
        """
    }

    // MARK: - Conversation Samples (生サンプル — 模倣の素材)

    /// 実際の会話を抽出(返信ペア+相手が自分から語った発言)
    private func buildConversationSamples(
        partnerName: String,
        selfName: String,
        allMessages: [ChatMessage]
    ) -> String {
        let textMessages = allMessages.filter { $0.eventType == .text && !$0.content.isEmpty }
        guard textMessages.count >= 4 else { return "" }

        // 1. 返信ペア
        var pairs: [(selfMsg: String, partnerReply: String)] = []
        for i in 0..<(textMessages.count - 1) {
            let current = textMessages[i]
            let next = textMessages[i + 1]
            if current.senderName == selfName && next.senderName == partnerName {
                if next.timestamp.timeIntervalSince(current.timestamp) < 86400 {
                    pairs.append((selfMsg: current.content, partnerReply: next.content))
                }
            }
        }

        var lines: [String] = []

        if !pairs.isEmpty {
            // 代表的なものを安定的に選ぶ(毎回シャッフルしない — 人格が安定する)
            let sampled = selectStableSamples(from: pairs.map { "\($0.selfMsg)|||\($0.partnerReply)" }, limit: 6)
            lines.append("【\(partnerName)の実際の返信パターン(模倣の素材)】")
            for raw in sampled {
                let parts = raw.components(separatedBy: "|||")
                guard parts.count == 2 else { continue }
                lines.append("相手: \(parts[0])")
                lines.append("\(partnerName): \(parts[1])")
                lines.append("")
            }
        }

        // 2. 自己開示(連続発言)
        var selfDisclosures: [String] = []
        for i in 0..<textMessages.count {
            let msg = textMessages[i]
            guard msg.senderName == partnerName else { continue }
            let text = msg.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (5...150).contains(text.count) else { continue }
            if i > 0 && textMessages[i - 1].senderName == partnerName {
                selfDisclosures.append(text)
            }
        }

        if !selfDisclosures.isEmpty {
            let sampled = selectStableSamples(from: selfDisclosures, limit: 4)
            lines.append("【\(partnerName)が自分の話をしている例】")
            for msg in sampled {
                lines.append("- \(msg)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Style Anchor (推論プロンプト末尾の生メッセージ抜粋)

    /// 推論プロンプトの末尾(会話履歴の直前)に置くスタイル固定用ブロック。
    /// 直前に生メッセージを大量に並べることで、LLMの recency bias を活用して
    /// テキストスタイル(絵文字・改行・句読点)を強制的に模倣させる。
    private func buildStyleAnchor(partnerName: String, partnerMessages: [ChatMessage]) -> String {
        let texts = partnerMessages
            .filter { $0.eventType == .text && !$0.content.isEmpty }
            .map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 200 }
        guard texts.count >= 5 else { return "" }

        // 30件、時系列等間隔で間引く
        let limit = 30
        let samples: [String]
        if texts.count <= limit {
            samples = texts
        } else {
            let step = Double(texts.count) / Double(limit)
            samples = (0..<limit).map { texts[min(Int(Double($0) * step), texts.count - 1)] }
        }

        let lines = samples.map { "  \"\($0)\"" }.joined(separator: "\n")
        return """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        【\(partnerName)が実際に書いた文(\(samples.count)件) — 同じ文体で書くこと】
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        \(lines)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """
    }

    /// 文字数中央値前後 + ユニーク特徴のあるものを優先して安定サンプリング
    private func selectStableSamples(from items: [String], limit: Int) -> [String] {
        guard !items.isEmpty else { return [] }
        // ハッシュ順に並べて毎回同じ順序にする
        let sorted = items.sorted { $0.hashValue < $1.hashValue }
        return Array(sorted.prefix(limit))
    }

    // MARK: - Persona Card Helpers

    /// PersonaCard 生成用にメッセージから代表的なものを抽出。
    /// 単純な等間隔サンプリングだと特徴的な発言を取りこぼすので、
    /// 等間隔ベース + 文字数の四分位ごとに混ぜて多様性を確保する。
    private func sampleRepresentativePartnerMessages(texts: [String], limit: Int) -> [String] {
        let valid = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 250 }
        guard !valid.isEmpty else { return [] }
        if valid.count <= limit { return valid }

        var picked: Set<Int> = []
        var result: [String] = []

        // 1. 時系列で等間隔抽出(分布の70%)
        let timelineCount = Int(Double(limit) * 0.7)
        let step = Double(valid.count) / Double(timelineCount)
        for i in 0..<timelineCount {
            let idx = min(Int(Double(i) * step), valid.count - 1)
            if picked.insert(idx).inserted {
                result.append(valid[idx])
            }
        }

        // 2. 長文(p75 以上)からランダム(分布の20%)
        let sortedByLength = valid.indices.sorted { valid[$0].count > valid[$1].count }
        let longCutoff = max(1, sortedByLength.count / 4)
        let longCount = Int(Double(limit) * 0.2)
        for idx in sortedByLength.prefix(longCutoff).shuffled().prefix(longCount) {
            if picked.insert(idx).inserted {
                result.append(valid[idx])
            }
        }

        // 3. 残り(分布の10%)はランダムで埋める
        while result.count < limit {
            let idx = Int.random(in: 0..<valid.count)
            if picked.insert(idx).inserted {
                result.append(valid[idx])
            }
        }

        return result
    }

    private struct ConversationPair {
        let selfMsg: String
        let partnerReply: String
    }

    /// 「相手の発言が特定の状況を示すキーワードを含む」会話ペアを抽出する。
    /// カード生成時に「○○な状況での本人の反応」を実例ベースで分析させるため。
    private func collectSituationalPairs(
        allMessages: [ChatMessage],
        partnerName: String,
        selfName: String,
        keywords: [String],
        limit: Int = 5
    ) -> [(prompt: String, reply: String)] {
        let textMessages = allMessages.filter { $0.eventType == .text && !$0.content.isEmpty }
        var pairs: [(prompt: String, reply: String)] = []
        for i in 0..<max(0, textMessages.count - 1) {
            let current = textMessages[i]
            let next = textMessages[i + 1]
            guard current.senderName == selfName,
                  next.senderName == partnerName,
                  next.timestamp.timeIntervalSince(current.timestamp) < 86400 else { continue }
            let s = current.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = next.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty, !r.isEmpty, s.count <= 200, r.count <= 250 else { continue }
            if keywords.contains(where: { s.contains($0) }) {
                pairs.append((prompt: s, reply: r))
            }
        }
        // 重複除去 & 多すぎる場合は等間隔抽出
        var seen: Set<String> = []
        var unique: [(String, String)] = []
        for p in pairs {
            let key = p.prompt + "|" + p.reply
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(p)
            }
        }
        if unique.count <= limit { return unique }
        let step = Double(unique.count) / Double(limit)
        return (0..<limit).map { unique[min(Int(Double($0) * step), unique.count - 1)] }
    }

    /// 状況別反応パターンを集めてプロンプト用ブロックに整形。
    /// 各バケットに該当する実会話ペアがあれば「## バケット名」付きで出力。
    private func buildSituationalBuckets(
        allMessages: [ChatMessage],
        partnerName: String,
        selfName: String
    ) -> String {
        struct Bucket {
            let label: String
            let keywords: [String]
        }
        let buckets: [Bucket] = [
            Bucket(label: "相手が疲れた・落ち込んでいる時",
                   keywords: ["疲れ", "つかれ", "しんど", "辛い", "つらい", "へこ", "落ち込", "凹", "鬱", "病ん"]),
            Bucket(label: "相手が嬉しい・興奮している時",
                   keywords: ["嬉し", "楽しい", "やった", "最高", "テンション", "ヤバい", "やばい", "わくわく", "うれし"]),
            Bucket(label: "相手が誘い・提案した時",
                   keywords: ["行こう", "行かない", "しよう", "しない?", "どう?", "どうかな", "今度", "今週", "週末", "暇?", "ひま?"]),
            Bucket(label: "相手が褒めた・好意を示した時",
                   keywords: ["好き", "かわいい", "可愛い", "かっこい", "カッコい", "優しい", "やさしい", "すごい", "すげ", "尊敬"]),
            Bucket(label: "相手が冗談・ボケた時",
                   keywords: ["笑", "w", "草", "ww", "lol", "ふざけ", "嘘", "うそ", "なんで", "は?"]),
            Bucket(label: "相手が真面目な相談・重い話をした時",
                   keywords: ["相談", "悩み", "迷っ", "どうし", "どう思", "助け", "教え", "わからな", "分からな"]),
            Bucket(label: "相手が質問した時",
                   keywords: ["?", "?", "なんで", "なに", "何", "どこ", "いつ", "誰", "だれ", "何時", "なんじ"]),
        ]

        var sections: [String] = []
        for bucket in buckets {
            let pairs = collectSituationalPairs(
                allMessages: allMessages,
                partnerName: partnerName,
                selfName: selfName,
                keywords: bucket.keywords,
                limit: 4
            )
            if pairs.isEmpty { continue }
            var lines = ["## \(bucket.label)"]
            for p in pairs {
                lines.append("  - 相手: 「\(p.prompt)」")
                lines.append("    \(partnerName): 「\(p.reply)」")
            }
            sections.append(lines.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n")
    }

    private func collectConversationPairs(
        allMessages: [ChatMessage],
        partnerName: String,
        selfName: String,
        limit: Int
    ) -> [ConversationPair] {
        let textMessages = allMessages.filter { $0.eventType == .text && !$0.content.isEmpty }
        var pairs: [ConversationPair] = []
        for i in 0..<max(0, textMessages.count - 1) {
            let current = textMessages[i]
            let next = textMessages[i + 1]
            if current.senderName == selfName && next.senderName == partnerName {
                if next.timestamp.timeIntervalSince(current.timestamp) < 86400 {
                    let s = current.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    let r = next.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if s.count <= 200 && r.count <= 250 && !s.isEmpty && !r.isEmpty {
                        pairs.append(ConversationPair(selfMsg: s, partnerReply: r))
                    }
                }
            }
        }
        if pairs.count <= limit { return pairs }
        let step = Double(pairs.count) / Double(limit)
        return (0..<limit).map { pairs[min(Int(Double($0) * step), pairs.count - 1)] }
    }

    private func collectInitiations(
        allMessages: [ChatMessage],
        partnerName: String,
        limit: Int
    ) -> [String] {
        let textMessages = allMessages.filter { $0.eventType == .text && !$0.content.isEmpty }
        var initiations: [String] = []
        for i in 0..<textMessages.count {
            let msg = textMessages[i]
            guard msg.senderName == partnerName else { continue }
            if i == 0 || msg.timestamp.timeIntervalSince(textMessages[i - 1].timestamp) > 3600 {
                let text = msg.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if (2...100).contains(text.count) {
                    initiations.append(text)
                }
            }
        }
        if initiations.count <= limit { return initiations }
        let step = Double(initiations.count) / Double(limit)
        return (0..<limit).map { initiations[min(Int(Double($0) * step), initiations.count - 1)] }
    }

    // MARK: - Topic Hints for Proactive Messages

    /// 実際のトーク履歴からパートナーが自発的に送ったメッセージを抽出し、話題のヒントにする
    private func buildTopicHints(
        partnerName: String,
        selfName: String,
        allMessages: [ChatMessage]
    ) -> String {
        let initiations = collectInitiations(allMessages: allMessages, partnerName: partnerName, limit: 8)
        guard !initiations.isEmpty else { return "" }

        var lines: [String] = ["【\(partnerName)が実際に自分から送ったメッセージの例(話題の参考)】"]
        for msg in initiations {
            lines.append("- \(msg)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Proactive Relationship Hints

    private func buildProactiveRelationshipHint(
        partnerName: String,
        userCallName: String,
        relationshipType: PersonaRelationship
    ) -> String {
        switch relationshipType {
        case .lover:
            let hints = [
                "デートの提案(具体的な場所やプラン)",
                "「会いたい」「好き」などの愛情表現",
                "今日あった出来事の共有",
                "相手の体調や予定を気遣う",
                "一緒に観たい映画や行きたい場所の話",
                "甘えた内容や寂しさの表現"
            ]
            return "恋人として、以下のような内容を参考に: \(hints.shuffled().prefix(2).joined(separator: "、"))"
        case .crush:
            let hints = [
                "共通の話題や趣味について",
                "思わせぶりな発言や褒め言葉",
                "二人で行きたい場所の話",
                "面白かった出来事を共有して反応を見たい",
                "相手の最近の様子を気にかける"
            ]
            return "好意を持ちつつも自然に、以下のような内容を参考に: \(hints.shuffled().prefix(2).joined(separator: "、"))"
        case .mutual:
            let hints = [
                "二人きりで会う口実を作る",
                "意味深で焦らすような発言",
                "相手のことを考えていたことを匂わせる",
                "「今度二人で〜しない?」という提案",
                "照れながらも距離を縮めようとする"
            ]
            return "両思いのもどかしさを込めて、以下のような内容を参考に: \(hints.shuffled().prefix(2).joined(separator: "、"))"
        case .ex:
            let hints = [
                "共通の思い出に触れる",
                "最近の様子をさりげなく聞く",
                "ふと思い出したことを共有する",
                "懐かしい場所やモノの話",
                "複雑な気持ちをにじませる"
            ]
            return "元恋人としての距離感で、以下のような内容を参考に: \(hints.shuffled().prefix(2).joined(separator: "、"))"
        case .situational:
            let hints = [
                "夜に急に連絡する",
                "特別感を出す発言",
                "意味深な言葉を投げかける",
                "「\(userCallName)にしか言わないけど」と前置きする",
                "会いたいという気持ちを遠回しに"
            ]
            return "曖昧な関係ならではの親密さで、以下のような内容を参考に: \(hints.shuffled().prefix(2).joined(separator: "、"))"
        case .friend:
            let hints = [
                "遊びの誘い(具体的なプラン付き)",
                "面白い出来事やネタの共有",
                "共通の趣味の話",
                "近況報告や愚痴",
                "ノリのいいいじりや冗談"
            ]
            return "友達として気軽に、以下のような内容を参考に: \(hints.shuffled().prefix(2).joined(separator: "、"))"
        }
    }

    // MARK: - Relevant History Search (RAG-like)

    /// ユーザーの発言からキーワードを抽出し、過去のトーク履歴から関連する会話を検索して返す
    private func buildRelevantHistory(
        query: String,
        partnerName: String,
        selfName: String,
        allMessages: [ChatMessage]
    ) -> String {
        let textMessages = allMessages.filter { $0.eventType == .text && !$0.content.isEmpty }
        guard textMessages.count >= 10 else { return "" }

        let keywords = extractKeywords(from: query)
        guard !keywords.isEmpty else { return "" }

        struct ScoredMessage {
            let index: Int
            let score: Int
        }

        var scored: [ScoredMessage] = []
        for (i, msg) in textMessages.enumerated() {
            let text = msg.content.lowercased()
            var score = 0
            for keyword in keywords {
                if text.contains(keyword.lowercased()) {
                    score += keyword.count >= 3 ? 2 : 1
                }
            }
            if score > 0 {
                scored.append(ScoredMessage(index: i, score: score))
            }
        }

        guard !scored.isEmpty else { return "" }

        let topHits = scored.sorted { $0.score > $1.score }.prefix(5)

        var snippets: [[String]] = []
        var usedIndices: Set<Int> = []

        for hit in topHits {
            guard !usedIndices.contains(hit.index) else { continue }

            let start = max(0, hit.index - 1)
            let end = min(textMessages.count - 1, hit.index + 1)

            var snippet: [String] = []
            for j in start...end {
                usedIndices.insert(j)
                let msg = textMessages[j]
                let name = msg.senderName == partnerName ? partnerName : "相手"
                snippet.append("\(name): \(msg.content)")
            }
            snippets.append(snippet)

            if snippets.count >= 3 { break }
        }

        guard !snippets.isEmpty else { return "" }

        var lines: [String] = ["【この話題に関連する過去の実際のトーク(参考)】"]
        lines.append("以下は「\(keywords.joined(separator: "・"))」に関連する過去の実際の会話です。この内容を踏まえて返信してください。")
        lines.append("")

        for (i, snippet) in snippets.enumerated() {
            if i > 0 { lines.append("---") }
            lines.append(contentsOf: snippet)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func extractKeywords(from text: String) -> [String] {
        let stopWords: Set<String> = [
            "の", "に", "は", "を", "が", "で", "と", "も", "か", "な", "よ",
            "ね", "て", "た", "だ", "し", "け", "る", "ん", "い", "う", "え",
            "から", "まで", "より", "って", "けど", "ので", "のに", "でも",
            "する", "した", "して", "される", "ある", "ない", "いる",
            "これ", "それ", "あれ", "どれ", "この", "その", "あの", "どの",
            "何", "なに", "どう", "どこ", "いつ", "だれ", "なぜ",
            "ある", "いい", "よい", "ほしい", "ほう",
            "the", "is", "are", "was", "were", "do", "does", "did",
            "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "こと", "もの", "とき", "ところ", "ため", "ほど", "くらい",
            "思う", "言う", "やっぱ", "やっぱり", "ちょっと", "すごい",
        ]

        let cleaned = text
            .replacingOccurrences(of: "[、。！？!?…♪♡❤️☺️😊😂🥺💕✨〜～「」（）()\\s]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var keywords: [String] = []

        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for word in words {
            let lower = word.lowercased()
            if lower.count >= 2 && !stopWords.contains(lower) {
                keywords.append(lower)
            }
        }

        let katakanaPattern = "[ァ-ヶー]{2,10}"
        let kanjiPattern = "[一-龥]{2,6}"

        for pattern in [katakanaPattern, kanjiPattern] {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                let matches = regex.matches(in: cleaned, range: range)
                for match in matches {
                    if let r = Range(match.range, in: cleaned) {
                        let word = String(cleaned[r])
                        if !stopWords.contains(word) && !keywords.contains(word) {
                            keywords.append(word)
                        }
                    }
                }
            }
        }

        return keywords
    }

    // MARK: - Conversation History

    private func buildConversationHistory(chat: PersonaChat, newMessage: String, partnerName: String) -> String {
        let recent = chat.messages.suffix(8)
        var lines = recent.map { msg in
            let name = msg.role == .user ? "相手" : partnerName
            return "\(name): \(msg.text)"
        }
        lines.append("相手: \(newMessage)")
        return lines.joined(separator: "\n")
    }
}
