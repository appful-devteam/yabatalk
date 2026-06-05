import Foundation

// MARK: - Reply Suggestion Service

final class ReplySuggestionService: @unchecked Sendable {
    static let shared = ReplySuggestionService()

    private let geminiService = GeminiService.shared

    private init() {}

    // MARK: - Public API

    func precomputeStyleProfiles(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String
    ) -> ReplyStyleProfiles {
        let textMessages = messages
            .filter { $0.eventType == .text }
            .sorted { $0.timestamp < $1.timestamp }

        let selfStyle = buildStyleDNA(
            messages: textMessages,
            senderName: selfName,
            partnerName: partnerName
        )
        let partnerStyle = buildStyleDNA(
            messages: textMessages,
            senderName: partnerName,
            partnerName: selfName
        )

        return ReplyStyleProfiles(
            selfName: selfName,
            partnerName: partnerName,
            selfStyle: toReplyStyleProfile(selfStyle),
            partnerStyle: toReplyStyleProfile(partnerStyle),
            generatedAt: Date()
        )
    }

    func suggestReplies(
        session: ChatSession,
        selfName: String,
        partnerName: String,
        userGoal: String,
        history: [ReplyChatEntry],
        analysisResult: AnalysisResult? = nil,
        mode: ReplyConversationMode = .continueConversation,
        onStageChange: @Sendable @MainActor (PipelineStage) -> Void = { _ in }
    ) async throws -> ReplySuggestionResult {
        // ── Logging setup ──
        let logger = PipelineDebugLogger.shared
        let isLogging = logger.isEnabled
        let logBuilder = isLogging ? PipelineLogBuilder() : nil
        logBuilder?.startStage("preprocessing")

        // ── Stage 0 (LOCAL): 前処理 ──
        await onStageChange(.preparingStyle)

        let textMessages = session.messages
            .filter { $0.eventType == .text }
            .sorted { $0.timestamp < $1.timestamp }

        guard !textMessages.isEmpty else {
            return ReplySuggestionResult(
                candidates: [],
                notes: ["テキストメッセージが不足しているため提案を生成できませんでした。"],
                usedBackfill: false
            )
        }

        let latestDate = textMessages.last?.timestamp ?? Date()

        // ── Mode-dependent preprocessing ──
        let recentSnippet: String
        let selectedBlocks: [ReplyConversationBlock]
        let contextMessages: [ChatMessage]
        let relationshipIntel: String

        switch mode {
        case .continueConversation:
            let recentCutoff = latestDate.daysAgo(14)
            let recentMessages = textMessages.filter { $0.timestamp >= recentCutoff }

            let allBlocks = buildConversationBlocks(messages: textMessages)
            let needsBackfill = shouldUseBackfill(goal: userGoal, recentCount: recentMessages.count)
            if needsBackfill {
                selectedBlocks = retrieveRelevantBlocks(goal: userGoal, blocks: allBlocks, recentCutoff: recentCutoff)
            } else {
                selectedBlocks = []
            }

            let backfillMessages = selectedBlocks.flatMap(\.messages)
            contextMessages = mergeAndSortMessages(primary: recentMessages, secondary: backfillMessages)

            recentSnippet = buildRecentSnippet(
                messages: contextMessages,
                selfName: selfName,
                partnerName: partnerName,
                maxLines: 30
            )

            relationshipIntel = buildRelationshipIntel(
                messages: contextMessages,
                selfName: selfName,
                partnerName: partnerName,
                analysisResult: analysisResult
            )

        case .newConversation:
            selectedBlocks = []
            contextMessages = Array(textMessages.suffix(10))

            recentSnippet = buildRecentSnippet(
                messages: textMessages,
                selfName: selfName,
                partnerName: partnerName,
                maxLines: 3
            )

            relationshipIntel = buildNewConversationRelationshipSummary(
                messages: textMessages,
                selfName: selfName,
                partnerName: partnerName,
                analysisResult: analysisResult
            )
        }

        guard let resolvedStyles = resolveStyleProfiles(
            analysisResult: analysisResult,
            selfName: selfName,
            partnerName: partnerName
        ) else {
            logBuilder?.error = "missing_style_profile"
            if let lb = logBuilder { logger.save(lb.build()) }
            return ReplySuggestionResult(
                candidates: [],
                notes: [
                    "話し方プロファイルが未準備です。先にトーク診断を実行してください。"
                ],
                usedBackfill: !selectedBlocks.isEmpty
            )
        }
        let userStyle = resolvedStyles.userStyle

        // RAG取得（既存）
        let ragExamples = retrieveRAGUserExamples(
            query: userGoal,
            allMessages: textMessages,
            selfName: selfName,
            maxCount: 6
        )

        // PersonalityContext構築
        let personalityContext = buildPersonalityContext(
            selfName: selfName,
            partnerName: partnerName,
            analysisResult: analysisResult
        )

        // ── Log: inputContext + preprocessing ──
        if let lb = logBuilder {
            let snippetPreview = String(recentSnippet.prefix(200))
            lb.inputContext = .init(
                selfName: selfName,
                partnerName: partnerName,
                messageCount: textMessages.count,
                recentMessageCount: contextMessages.count,
                userGoal: userGoal,
                historyEntryCount: history.count,
                recentSnippetPreview: snippetPreview,
                conversationMode: mode.rawValue
            )
            lb.preprocessing = .init(
                ragExampleCount: ragExamples.count,
                styleDNASummary: styleDescription(style: userStyle),
                personalityContext: personalityContext,
                relationshipIntel: relationshipIntel,
                usedBackfill: !selectedBlocks.isEmpty,
                backfillBlockCount: selectedBlocks.count,
                duration: lb.elapsed("preprocessing")
            )
        }

        // ── Call 1: 内容設計 ──
        await onStageChange(.designingContent)
        logBuilder?.startStage("call1")

        var contentDesign: ContentDesignResult?
        do {
            let (result, prompt, raw) = try await requestContentDesign(
                userGoal: userGoal,
                recentSnippet: recentSnippet,
                personalityContext: personalityContext,
                relationshipIntel: relationshipIntel,
                history: history,
                mode: mode
            )
            contentDesign = result
            if let lb = logBuilder {
                let summary = "scenarios:\(result.scenarioPlans.count), do:\(result.doList.count), dont:\(result.dontList.count)"
                lb.call1 = .init(stageName: "contentDesign", prompt: prompt, rawResponse: raw, parsedSummary: summary, duration: lb.elapsed("call1"))
            }
        } catch {
            logBuilder?.call1 = .init(stageName: "contentDesign", prompt: "", rawResponse: "", parsedSummary: "", duration: logBuilder?.elapsed("call1") ?? 0, error: error.localizedDescription)
            ErrorTracker.record(
                context: "reply_pipeline",
                errorType: "call1_failed",
                message: error.localizedDescription
            )
        }

        let design = contentDesign ?? defaultContentDesign(userGoal: userGoal)

        // ── Call 2a: 内容起草 ──
        await onStageChange(.craftingWordChoice)
        logBuilder?.startStage("call2a")

        let (draftPayload, call2aPrompt, call2aRaw) = try await requestContentDraft(
            design: design,
            personalityContext: personalityContext,
            history: history
        )
        var composerPayload = draftPayload

        if let lb = logBuilder {
            let summary = composerPayload.candidates.map { "\($0.id): \($0.text)" }.joined(separator: " | ")
            lb.call2a = .init(stageName: "contentDraft", prompt: call2aPrompt, rawResponse: call2aRaw, parsedSummary: summary, duration: lb.elapsed("call2a"))
        }

        // ── Call 2b: スタイル転写 ──
        await onStageChange(.applyingStyle)
        logBuilder?.startStage("call2b")

        let quantitativeStyleTargets = buildQuantitativeStyleTargets(style: userStyle)
        let hardConstraintRules = buildHardConstraintRules(style: userStyle)

        let (styledPayload, call2bPrompt, call2bRaw) = try await requestStyleTransfer(
            contentPayload: composerPayload,
            userStyleDesc: styleDescription(style: userStyle),
            quantitativeStyleTargets: quantitativeStyleTargets,
            hardConstraintRules: hardConstraintRules,
            ragExamples: ragExamples
        )
        composerPayload = styledPayload

        if let lb = logBuilder {
            let summary = composerPayload.candidates.map { "\($0.id): \($0.text)" }.joined(separator: " | ")
            lb.call2b = .init(stageName: "styleTransfer", prompt: call2bPrompt, rawResponse: call2bRaw, parsedSummary: summary, duration: lb.elapsed("call2b"))
        }

        // ── LOCAL: ハード制約適用 ──
        logBuilder?.startStage("hardConstraints")
        let beforeHC = composerPayload.candidates.map { "\($0.id): \($0.text)" }

        composerPayload = applyHardConstraintsToPayload(
            payload: composerPayload,
            style: userStyle
        )

        if let lb = logBuilder {
            let afterHC = composerPayload.candidates.map { "\($0.id): \($0.text)" }
            lb.hardConstraints = .init(
                candidatesBefore: beforeHC,
                candidatesAfter: afterHC,
                appliedRules: hardConstraintRules,
                duration: lb.elapsed("hardConstraints")
            )
        }

        // ── LOCAL: 品質審査 ──
        await onStageChange(.qualityCheck)
        logBuilder?.startStage("evaluation")

        var evaluated = evaluate(payload: composerPayload, userStyle: userStyle)
        var rewriteCount = 0

        if let lb = logBuilder {
            let scores = evaluated.candidates.map { "\($0.id): \(String(format: "%.2f", $0.styleScore))" }
            let targets = evaluated.rewriteTargets.map { "\($0.id): \($0.reasons.joined(separator: ","))" }
            lb.evaluation = .init(scores: scores, rewriteTargets: targets, duration: lb.elapsed("evaluation"))
        }

        // Call 2.5: リライト（1回まで）
        while rewriteCount < 1, !evaluated.rewriteTargets.isEmpty {
            do {
                logBuilder?.startStage("call25")
                let (rewrittenPayload, rwPrompt, rwRaw) = try await requestComposerRewrite(
                    previousPayload: composerPayload,
                    rewriteTargets: evaluated.rewriteTargets,
                    hardConstraintRules: hardConstraintRules,
                    userStyleDesc: styleDescription(style: userStyle),
                    ragExamples: ragExamples,
                    userGoal: userGoal
                )
                composerPayload = rewrittenPayload

                if let lb = logBuilder {
                    let summary = composerPayload.candidates.map { "\($0.id): \($0.text)" }.joined(separator: " | ")
                    lb.call25 = .init(stageName: "composerRewrite", prompt: rwPrompt, rawResponse: rwRaw, parsedSummary: summary, duration: lb.elapsed("call25"))
                }

                // 再度Stage 2b
                composerPayload = applyHardConstraintsToPayload(
                    payload: composerPayload,
                    style: userStyle
                )
                evaluated = evaluate(payload: composerPayload, userStyle: userStyle)
                rewriteCount += 1
            } catch {
                break
            }
        }

        var accepted = evaluated.candidates
            .filter { $0.styleScore >= 0.80 }
            .sorted { lhs, rhs in
                if lhs.styleScore == rhs.styleScore {
                    return lhs.label < rhs.label
                }
                return lhs.styleScore > rhs.styleScore
            }

        // Fallback: 0.80全滅なら安全な候補をスコア順で返す
        var usedLenientFallback = false
        if accepted.isEmpty {
            let lenient = composerPayload.candidates.compactMap { candidate -> ReplyCandidate? in
                let score = styleScore(for: candidate.text, style: userStyle)
                guard score >= 0.55 else { return nil }
                let risks = detectSafetyRisks(text: candidate.text)
                guard risks.isEmpty else { return nil }
                guard isCoherentText(candidate.text) else { return nil }
                return ReplyCandidate(
                    id: candidate.id,
                    label: candidate.label,
                    text: candidate.text,
                    styleScore: score,
                    riskFlags: [],
                    simulations: candidate.simulations
                )
            }
            .sorted { $0.styleScore > $1.styleScore }

            if !lenient.isEmpty {
                accepted = Array(lenient.prefix(3))
                usedLenientFallback = true
            }
        }

        // ── LOCAL: 最終組立 ──
        await onStageChange(.finalizing)

        var notes = composerPayload.notes
        if !selectedBlocks.isEmpty {
            notes.append("過去参照: \(selectedBlocks.count)ブロックを追加で参照しました。")
        } else {
            notes.append("過去参照: 直近2週間の文脈のみで提案しました。")
        }

        if accepted.isEmpty {
            notes.append("提案を生成できませんでした。以下を含めて再度お試しください：")
            notes.append("・相手の最新メッセージの内容（例: 「既読無視されてる」「〇〇って言われた」）")
            notes.append("・自分が伝えたいこと（例: 「謝りたい」「デートに誘いたい」）")
            notes.append("・今の関係の状況（例: 「喧嘩中」「最近距離を感じる」）")
        } else if usedLenientFallback {
            notes.append("口調の再現度がやや低めですが、最善の案を表示しています。具体的な状況を追加すると精度が上がります。")
        } else if accepted.count < 3 {
            notes.append("品質優先で案数を絞っています（0.80以上のみ表示）。")
        }
        if !accepted.isEmpty {
            notes.append("相手反応は各案の「シミュレーション」から必要な案だけ生成できます。")
        }

        // ── Log: finalOutput + save ──
        if let lb = logBuilder {
            lb.finalOutput = .init(
                acceptedCandidates: accepted.map { "\($0.id)(\($0.label)): \($0.text)" },
                notes: notes,
                usedLenientFallback: usedLenientFallback,
                totalDuration: lb.elapsed("preprocessing")
            )
            logger.save(lb.build())
        }

        return ReplySuggestionResult(
            candidates: accepted,
            notes: notes,
            usedBackfill: !selectedBlocks.isEmpty
        )
    }

    func simulatePartnerReaction(
        session: ChatSession,
        selfName: String,
        partnerName: String,
        candidate: ReplyCandidate,
        analysisResult: AnalysisResult?,
        onStageChange: @Sendable @MainActor (PipelineStage) -> Void = { _ in }
    ) async throws -> [ReplySimulation] {
        await onStageChange(.simulatingPartner)

        let textMessages = session.messages
            .filter { $0.eventType == .text }
            .sorted { $0.timestamp < $1.timestamp }

        guard !textMessages.isEmpty else {
            throw ReplySuggestionServiceError.insufficientTextMessages
        }

        guard let resolvedStyles = resolveStyleProfiles(
            analysisResult: analysisResult,
            selfName: selfName,
            partnerName: partnerName
        ) else {
            throw ReplySuggestionServiceError.missingPrecomputedStyleProfile
        }

        let latestDate = textMessages.last?.timestamp ?? Date()
        let recentMessages = textMessages.filter { $0.timestamp >= latestDate.daysAgo(14) }
        let recentSnippet = buildRecentSnippet(
            messages: recentMessages,
            selfName: selfName,
            partnerName: partnerName,
            maxLines: 30
        )
        let relationshipIntel = buildRelationshipIntel(
            messages: recentMessages,
            selfName: selfName,
            partnerName: partnerName,
            analysisResult: analysisResult
        )

        let simOutput = try await requestSimulation(
            candidates: [candidate],
            partnerStyleDesc: styleDescription(style: resolvedStyles.partnerStyle),
            relationshipContext: relationshipIntel,
            recentSnippet: recentSnippet
        )

        let merged = mergeSimulations(candidates: [candidate], simOutput: simOutput)
        return merged.first?.simulations ?? []
    }

    private func buildPersonalityContext(
        selfName: String,
        partnerName: String,
        analysisResult: AnalysisResult?
    ) -> String {
        return "（性格データなし）"
    }

    // MARK: - Consultation Chat

    func consultationChat(
        session: ChatSession?,
        selfName: String,
        partnerName: String,
        analysisResult: AnalysisResult?,
        consultationContext: ConsultationContext,
        chatHistory: [ReplyChatEntry]
    ) async throws -> String {
        // 「とりあえず話す」フローでは session=nil。
        // 履歴ベースのヒント類は省略し、関係性ガイドだけで返答できるようにする。
        let textMessages: [ChatMessage] = session?.messages
            .filter { $0.eventType == .text }
            .sorted { $0.timestamp < $1.timestamp } ?? []

        let recentSnippet = textMessages.isEmpty ? "" : buildRecentSnippet(
            messages: textMessages,
            selfName: selfName,
            partnerName: partnerName,
            maxLines: 80
        )

        let relationshipIntel = textMessages.isEmpty ? "" : buildRelationshipIntel(
            messages: textMessages,
            selfName: selfName,
            partnerName: partnerName,
            analysisResult: analysisResult
        )

        let personalityContext = buildPersonalityContext(
            selfName: selfName,
            partnerName: partnerName,
            analysisResult: analysisResult
        )

        let styleHint = textMessages.isEmpty ? "" : buildStyleHintForConsultation(
            messages: textMessages,
            selfName: selfName
        )

        let systemPrompt = buildConsultationSystemPrompt(
            selfName: selfName,
            partnerName: partnerName,
            consultationContext: consultationContext,
            relationshipIntel: relationshipIntel,
            personalityContext: personalityContext,
            styleHint: styleHint,
            recentSnippet: recentSnippet
        )

        let conversationHistory = buildConversationHistoryForGemini(chatHistory: chatHistory)

        let fullPrompt = """
        \(systemPrompt)

        【これまでの会話 / Conversation so far】
        \(conversationHistory)

        めろまるの返答 / Mero's response:
        """

        return try await geminiService.generateText(
            prompt: fullPrompt,
            maxTokens: consultationContext.length.maxTokens,
            temperature: 0.7
        )
    }

    private func buildStyleHintForConsultation(
        messages: [ChatMessage],
        selfName: String
    ) -> String {
        let selfMessages = messages.filter { $0.senderName == selfName }
        guard !selfMessages.isEmpty else { return "（話し方データなし）" }

        let sample = selfMessages.suffix(50)
        let texts = sample.map { $0.content }

        let firstPersonCandidates = ["俺", "僕", "私", "わたし", "あたし", "うち", "自分"]
        var firstPersonCounts: [String: Int] = [:]
        for text in texts {
            for fp in firstPersonCandidates {
                if text.contains(fp) {
                    firstPersonCounts[fp, default: 0] += 1
                }
            }
        }
        let topFirstPerson = firstPersonCounts.max(by: { $0.value < $1.value })?.key

        let avgLength = texts.isEmpty ? 0 : texts.map(\.count).reduce(0, +) / texts.count

        let emojiCount = texts.filter { $0.containsEmoji }.count
        let emojiRate = texts.isEmpty ? 0.0 : Double(emojiCount) / Double(texts.count)

        let politeCount = texts.filter { $0.contains("です") || $0.contains("ます") || $0.contains("ました") }.count
        let politeRate = texts.isEmpty ? 0.0 : Double(politeCount) / Double(texts.count)

        var hints: [String] = []
        if let fp = topFirstPerson {
            hints.append("一人称: \(fp)")
        }
        hints.append("平均文長: \(avgLength)文字")
        if emojiRate > 0.3 {
            hints.append("絵文字: よく使う")
        } else if emojiRate < 0.05 {
            hints.append("絵文字: ほぼ使わない")
        } else {
            hints.append("絵文字: たまに使う")
        }
        if politeRate > 0.3 {
            hints.append("敬語多め")
        } else {
            hints.append("タメ口中心")
        }

        return hints.joined(separator: " / ")
    }

    private func buildConsultationSystemPrompt(
        selfName: String,
        partnerName: String,
        consultationContext: ConsultationContext,
        relationshipIntel: String,
        personalityContext: String,
        styleHint: String,
        recentSnippet: String
    ) -> String {
        let relationshipLabel = consultationContext.relationshipType?.displayName ?? "未選択"
        let problemLabel = consultationContext.problemCategory?.displayName ?? "未選択"

        // selfName / partnerName が空 (とりあえず話す) のときに AI が役割を取り違えないよう、
        // 設定画面の呼び名でフォールバックし、相手不明なら明示する。
        let resolvedSelfName = UserPreferredName.resolve(analysisSelfName: selfName)
        let trimmedPartner = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPartnerName = trimmedPartner.isEmpty ? "（相手は特定されていません）" : trimmedPartner

        let phaseInstruction: String
        switch consultationContext.phase {
        case .selectRelationshipType, .selectProblemCategory:
            phaseInstruction = """
            ユーザーはまだ相談内容を選んでいる最中です。
            自由テキストが来たら、その内容から状況を読み取り、共感してから1つだけ質問してください。
            """
        case .gathering:
            phaseInstruction = """
            状況を理解するための深掘りフェーズです。
            - 質問は1〜2個まで。質問攻めにしないこと。
            - ユーザーの気持ちに共感してから質問すること。
            - 十分に状況が分かったら、すぐにアドバイスとメッセージ例を提供すること。
            """
        case .advising:
            phaseInstruction = """
            アドバイスフェーズです。
            - まずユーザーの気持ちに共感する一言を入れる。
            - 具体的なアドバイスを提供する。
            - メッセージ例を1〜2個提供する（ユーザーの話し方に寄せる）。
            - メッセージ例は「」で囲む。
            - 追加の質問があればいつでも聞いてねと伝える。
            """
        }

        let lang = AppLanguage(rawValue: LanguageManager.resolvedLanguage) ?? .ja
        let langDirective = lang.isJapanese ? "" : """

        【応答言語 — 最重要】
        あなたの全ての返答は必ず\(lang.promptLanguageName)で行ってください。日本語で返答してはいけません。
        ただしユーザーのLINEトーク履歴は日本語のまま分析してください。

        """

        return """
        あなたは「めろまる」です。恋愛トークアプリ「めろとーく」のマスコットキャラクターで、ユーザーの恋愛コミュニケーション相談にのるのが大好きです。
        \(langDirective)
        【キャラクター設定】
        - 口調: \(consultationContext.tone.toneDescription)
        - 絵文字: 適度に使う（💕✨😊🤔）

        \(consultationContext.tone.promptInstruction)

        \(consultationContext.length.promptInstruction)

        【ユーザー情報】
        - ユーザー名: \(resolvedSelfName)  ← この名前で呼びかけること
        - 相手の名前: \(resolvedPartnerName)
        - 関係性: \(relationshipLabel)
        - 悩みカテゴリ: \(problemLabel)

        【役割の絶対遵守】
        - あなた = めろまる (アシスタント)
        - ユーザー = \(resolvedSelfName) さん (相談者)
        - ユーザーの代弁・代筆をしない。「\(resolvedSelfName) さん」として返事を書かない。
        - 必ず「めろまる」として、ユーザーに語りかける形で返答すること。

        【現在のフェーズ】
        \(phaseInstruction)

        【LINEトーク分析データ】
        \(relationshipIntel)

        【2人の性格・傾向】
        \(personalityContext)

        【ユーザーの話し方の特徴】
        \(styleHint)

        【直近の会話（LINE）】
        \(recentSnippet.isEmpty ? "（データなし）" : recentSnippet)

        【トーク履歴の活用ルール — 最重要】
        - 上記のLINEトーク履歴にはユーザーと相手の実際のやり取りが含まれている
        - 相手が何を言ったか、ユーザーが何と返したかなど、履歴から分かる情報はすべて把握済みとして振る舞うこと
        - ユーザーに「その時なんて返した？」「相手はなんて言ってた？」など、履歴を見れば分かることを質問してはいけない
        - 代わりに「あの時〇〇って言ってたよね」のように、履歴の内容を自分から引用・参照して会話を進めること
        - 履歴にない情報だけをユーザーに質問すること

        【絶対禁止事項】
        - 架空の場所名・イベント名・店名の捏造
        - プレースホルダー（[〇〇]や【〇〇】）の使用
        - 敬語（です・ます調）での返答
        - 「3案」「案1」のような構造的出力
        - 箇条書きの羅列（自然な文章で返す）
        - 上記の文字数制限を超える返答（会話が長くなっても毎回文字数を守ること）
        """
    }

    private func buildConversationHistoryForGemini(chatHistory: [ReplyChatEntry]) -> String {
        let relevant = chatHistory.suffix(20)
        return relevant.map { entry in
            let role = entry.role == .user ? "User" : "Mero"
            return "[\(role)] \(entry.text)"
        }.joined(separator: "\n")
    }

    // MARK: - RelationshipIntel構築（新規）

    private func buildRelationshipIntel(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        analysisResult: AnalysisResult?
    ) -> String {
        let localContext = buildLocalRelationshipContext(
            messages: messages,
            selfName: selfName,
            partnerName: partnerName
        )

        guard let result = analysisResult else {
            return localContext
        }

        let axis = result.axisScore
        var axisInterpretation: [String] = []

        // バランス軸
        if axis.balanceScore < 40 {
            axisInterpretation.append("会話バランスが偏っている（\(Int(axis.balanceScore))点）")
        } else if axis.balanceScore > 70 {
            axisInterpretation.append("会話バランスが良好（\(Int(axis.balanceScore))点）")
        }

        // テンション軸
        if axis.tensionScore < 40 {
            axisInterpretation.append("テンションが低め（\(Int(axis.tensionScore))点）→ 盛り上げ要素を入れると良い")
        } else if axis.tensionScore > 70 {
            axisInterpretation.append("テンション高め（\(Int(axis.tensionScore))点）→ ノリを合わせる")
        }

        // レスポンス軸
        if axis.responseScore < 40 {
            axisInterpretation.append("返信速度に差あり（\(Int(axis.responseScore))点）→ 負担をかけない長さに")
        }

        // ワード軸
        if axis.wordScore > 70 {
            axisInterpretation.append("愛情表現が豊か（\(Int(axis.wordScore))点）")
        } else if axis.wordScore < 40 {
            axisInterpretation.append("愛情表現が少なめ（\(Int(axis.wordScore))点）→ さりげない愛情表現を")
        }

        let axisText = axisInterpretation.isEmpty
            ? "4軸スコアは平均的"
            : axisInterpretation.joined(separator: " / ")

        return "\(localContext) / 【4軸分析】\(axisText)"
    }

    private func buildNewConversationRelationshipSummary(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        analysisResult: AnalysisResult?
    ) -> String {
        var parts: [String] = []

        // 全体の会話バランス
        let balanceHint = relationshipHint(from: messages, selfName: selfName, partnerName: partnerName)
        parts.append(balanceHint)

        // 最後のメッセージからの経過日数
        if let lastMessage = messages.last {
            let daysSinceLast = Calendar.current.dateComponents([.day], from: lastMessage.timestamp, to: Date()).day ?? 0
            if daysSinceLast == 0 {
                parts.append("最後のやり取り: 今日")
            } else if daysSinceLast == 1 {
                parts.append("最後のやり取り: 昨日")
            } else {
                parts.append("最後のやり取り: \(daysSinceLast)日前")
            }

            // 最後に送ったのは自分か相手か
            if lastMessage.senderName == selfName {
                parts.append("最後に送ったのは自分")
            } else {
                parts.append("最後に送ったのは相手")
            }
        }

        // 4軸データからの簡易アドバイス
        if let result = analysisResult {
            let axis = result.axisScore
            var advice: [String] = []

            if axis.balanceScore < 40 {
                advice.append("会話バランスが偏り気味→相手のペースに合わせると◎")
            }
            if axis.tensionScore < 40 {
                advice.append("テンション低め→軽い話題から入ると自然")
            } else if axis.tensionScore > 70 {
                advice.append("テンション高め→ノリの良い話題が刺さりやすい")
            }
            if axis.wordScore > 70 {
                advice.append("愛情表現豊か→素直な気持ちを伝えても受け入れられやすい")
            } else if axis.wordScore < 40 {
                advice.append("愛情表現控えめ→さりげない切り出しが好印象")
            }

            if !advice.isEmpty {
                parts.append("【アドバイス】\(advice.joined(separator: " / "))")
            }
        }

        return parts.joined(separator: " / ")
    }

    // MARK: - Call 1: 内容設計

    private func requestContentDesign(
        userGoal: String,
        recentSnippet: String,
        personalityContext: String,
        relationshipIntel: String,
        history: [ReplyChatEntry],
        mode: ReplyConversationMode = .continueConversation
    ) async throws -> (ContentDesignResult, String, String) {
        let prompt = buildContentDesignPrompt(
            userGoal: userGoal,
            recentSnippet: recentSnippet,
            personalityContext: personalityContext,
            relationshipIntel: relationshipIntel,
            history: history,
            mode: mode
        )

        let rawText = try await geminiService.generateText(prompt: prompt, maxTokens: 1600, temperature: 0.4)
        return (try decodeContentDesign(from: rawText), prompt, rawText)
    }

    private func buildContentDesignPrompt(
        userGoal: String,
        recentSnippet: String,
        personalityContext: String,
        relationshipIntel: String,
        history: [ReplyChatEntry],
        mode: ReplyConversationMode = .continueConversation
    ) -> String {
        let historySnippet = history
            .suffix(4)
            .map { entry in
                let role = entry.role == .user ? "USER" : "ASSISTANT"
                return "[\(role)] \(entry.text)"
            }
            .joined(separator: "\n")

        switch mode {
        case .continueConversation:
            return """
            あなたはLINE恋愛コンサルタントです。必ずJSONのみで返してください。

            【タスク】
            ユーザーの悩みを深く理解し、3つの返信シナリオを「内容面だけ」で設計してください。
            文体・口調・絵文字などのスタイルは一切考慮しないでください。内容と戦略のみに集中してください。

            【ステップ1: 問題の特定】
            - 感情面の問題：ユーザーが今どんな気持ちで、何に悩んでいるか
            - 根本の問題：その感情の裏にある実際の状況・原因は何か

            【ステップ2: 文脈リサーチ】
            - 今の会話の温度感
            - 相手の最後のメッセージの意図
            - 未解決の話題や約束

            【ステップ3: シナリオ設計】
            各案に必ず含めること：
            - 立場（どんなスタンスで返すか）
            - 設定（どんな文脈で返すか）
            - タイミング（いつ送るのが最適か）
            - 内容（具体的に何を伝えるか 2-4点）
            - 感情面の解決 / 実務面の解決

            【絶対禁止】
            - [〇〇]や（相手の好きなもの）のようなプレースホルダーは禁止。直近会話の具体的な話題・固有名詞を使うこと。
            - 情報が不足する場合は、汎用的だが具体的な表現にすること（例: ×「[場所名]」→ ○「あのカフェ」「前行ったとこ」）

            【ユーザーの相談】
            \(userGoal)

            【2人の性格・傾向】
            \(personalityContext)

            【関係性データ】
            \(relationshipIntel)

            【直近会話】
            \(recentSnippet)

            【提案チャット履歴】
            \(historySnippet.isEmpty ? "初回相談" : historySnippet)

            【出力JSON】
            {
              "emotional_problem": {"feeling":"...", "trigger":"...", "approach":"..."},
              "root_problem": {"situation":"...", "approach":"..."},
              "scenario_plans": [
                {"id":"A", "label":"案A（...）", "position":"...", "setting":"...",
                 "timing":"...", "content_points":["..."], "emotional_goal":"...", "practical_goal":"..."},
                {"id":"B", "label":"案B（...）", "position":"...", "setting":"...",
                 "timing":"...", "content_points":["..."], "emotional_goal":"...", "practical_goal":"..."},
                {"id":"C", "label":"案C（...）", "position":"...", "setting":"...",
                 "timing":"...", "content_points":["..."], "emotional_goal":"...", "practical_goal":"..."}
              ],
              "do_list": ["..."],
              "dont_list": ["..."]
            }
            """

        case .newConversation:
            return """
            あなたはLINE恋愛コンサルタントです。必ずJSONのみで返してください。

            【タスク】
            ユーザーは「新しい話題で会話を始めたい」と考えています。3つの切り出し方を「内容面だけ」で設計してください。
            文体・口調・絵文字などのスタイルは一切考慮しないでください。内容と戦略のみに集中してください。

            【ステップ1: 状況把握】
            - ユーザーの意図：何を目的に連絡したいのか
            - 前回会話の終わり方：最後のやり取りの雰囲気はどうだったか

            【ステップ2: 切り出し方の設計ポイント】
            - 自然な入り方：唐突感のない会話の始め方
            - フック：相手が興味を持ちそうな要素
            - 返信しやすさ：相手が気軽に返せる工夫

            【ステップ3: シナリオ設計】
            各案に必ず含めること：
            - 立場（どんなスタンスで切り出すか）
            - 設定（どんな口実・きっかけで連絡するか）
            - タイミング（いつ送るのが最適か）
            - 内容（具体的に何を伝えるか 2-4点）
            - 感情面のゴール / 実務面のゴール

            【絶対禁止】
            - [〇〇]や（相手の好きなもの）のようなプレースホルダーは禁止。関係性データから具体的な話題を使うこと。
            - 情報が不足する場合は、汎用的だが具体的な表現にすること。
            - 「久しぶり！元気？」のような定型的すぎる切り出しは禁止。相手が返信したくなる具体的なフックを必ず含めること。

            【ユーザーの意図】
            \(userGoal)

            【2人の性格・傾向】
            \(personalityContext)

            【関係性データ】
            \(relationshipIntel)

            【直近の会話の終わり方（参考）】
            \(recentSnippet)

            【提案チャット履歴】
            \(historySnippet.isEmpty ? "初回相談" : historySnippet)

            【出力JSON】
            {
              "emotional_problem": {"feeling":"...", "trigger":"...", "approach":"..."},
              "root_problem": {"situation":"...", "approach":"..."},
              "scenario_plans": [
                {"id":"A", "label":"案A（...）", "position":"...", "setting":"...",
                 "timing":"...", "content_points":["..."], "emotional_goal":"...", "practical_goal":"..."},
                {"id":"B", "label":"案B（...）", "position":"...", "setting":"...",
                 "timing":"...", "content_points":["..."], "emotional_goal":"...", "practical_goal":"..."},
                {"id":"C", "label":"案C（...）", "position":"...", "setting":"...",
                 "timing":"...", "content_points":["..."], "emotional_goal":"...", "practical_goal":"..."}
              ],
              "do_list": ["..."],
              "dont_list": ["..."]
            }
            """
        }
    }

    private func decodeContentDesign(from rawText: String) throws -> ContentDesignResult {
        let cleaned = sanitizeToJSON(rawText)
        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.parsingFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let epJSON = json["emotional_problem"] as? [String: Any] ?? [:]
        let emotionalProblem = EmotionalProblem(
            feeling: epJSON["feeling"] as? String ?? "",
            trigger: epJSON["trigger"] as? String ?? "",
            approach: epJSON["approach"] as? String ?? ""
        )

        let rpJSON = json["root_problem"] as? [String: Any] ?? [:]
        let rootProblem = RootProblem(
            situation: rpJSON["situation"] as? String ?? "",
            approach: rpJSON["approach"] as? String ?? ""
        )

        let plansJSON = json["scenario_plans"] as? [[String: Any]] ?? []
        let scenarioPlans = plansJSON.map { p in
            ScenarioPlan(
                id: p["id"] as? String ?? "",
                label: p["label"] as? String ?? "",
                position: p["position"] as? String ?? "",
                setting: p["setting"] as? String ?? "",
                timing: p["timing"] as? String ?? "",
                contentPoints: p["content_points"] as? [String] ?? [],
                emotionalGoal: p["emotional_goal"] as? String ?? "",
                practicalGoal: p["practical_goal"] as? String ?? ""
            )
        }

        return ContentDesignResult(
            emotionalProblem: emotionalProblem,
            rootProblem: rootProblem,
            scenarioPlans: scenarioPlans.isEmpty ? defaultScenarioPlans() : scenarioPlans,
            doList: json["do_list"] as? [String] ?? [],
            dontList: json["dont_list"] as? [String] ?? []
        )
    }

    private func defaultContentDesign(userGoal: String) -> ContentDesignResult {
        ContentDesignResult(
            emotionalProblem: EmotionalProblem(
                feeling: "返信に悩んでいる",
                trigger: userGoal,
                approach: "相手の気持ちに寄り添う"
            ),
            rootProblem: RootProblem(
                situation: "適切な返信がわからない",
                approach: "自然体で接する"
            ),
            scenarioPlans: defaultScenarioPlans(),
            doList: ["ユーザーの悩みに寄り添う", "自然な文面にする"],
            dontList: ["操作的な表現を避ける"]
        )
    }

    private func defaultScenarioPlans() -> [ScenarioPlan] {
        [
            ScenarioPlan(id: "A", label: "案A（安心感を与える）", position: "理解者", setting: "日常の流れで", timing: "すぐに", contentPoints: ["共感を示す", "軽い返答"], emotionalGoal: "安心させる", practicalGoal: "会話を続ける"),
            ScenarioPlan(id: "B", label: "案B（一歩踏み込む）", position: "対等なパートナー", setting: "自然な流れで", timing: "少し間を置いて", contentPoints: ["気持ちを伝える", "提案をする"], emotionalGoal: "距離を縮める", practicalGoal: "次のアクションに繋げる"),
            ScenarioPlan(id: "C", label: "案C（最短）", position: "気楽な存在", setting: "シンプルに", timing: "すぐに", contentPoints: ["短く返す"], emotionalGoal: "負担をかけない", practicalGoal: "返信する")
        ]
    }

    // MARK: - Call 2a: 内容起草（スタイルフリー）

    private func requestContentDraft(
        design: ContentDesignResult,
        personalityContext: String,
        history: [ReplyChatEntry]
    ) async throws -> (GeminiReplyPayload, String, String) {
        let prompt = buildContentDraftPrompt(
            design: design,
            personalityContext: personalityContext,
            history: history
        )

        let rawText = try await geminiService.generateText(prompt: prompt, maxTokens: 1000, temperature: 0.40)
        return (try decodeComposerOutput(from: rawText), prompt, rawText)
    }

    private func buildContentDraftPrompt(
        design: ContentDesignResult,
        personalityContext: String,
        history: [ReplyChatEntry]
    ) -> String {
        let ep = design.emotionalProblem
        let rp = design.rootProblem

        let scenarioLines = design.scenarioPlans.map { plan in
            """
            ■ \(plan.id)「\(plan.label)」
              立場: \(plan.position) / 設定: \(plan.setting)
              伝える内容: \(plan.contentPoints.joined(separator: "、"))
              感情面の目標: \(plan.emotionalGoal) / 実務面の目標: \(plan.practicalGoal)
            """
        }.joined(separator: "\n")

        let doLines = design.doList.isEmpty ? "特になし" : design.doList.joined(separator: "、")
        let dontLines = design.dontList.isEmpty ? "特になし" : design.dontList.joined(separator: "、")

        let historySnippet = history
            .suffix(4)
            .map { entry in
                let role = entry.role == .user ? "USER" : "ASSISTANT"
                return "[\(role)] \(entry.text)"
            }
            .joined(separator: "\n")

        return """
        あなたはLINE返信の内容設計専門家です。必ずJSONのみで返してください。

        【タスク】
        以下のシナリオ設計をもとに、返信文の「内容」を起草してください。
        スタイル（語尾・絵文字・口調）は次のステップで変換するので、ここではニュートラルな文章で書いてください。

        【最重要: 内容の正確さ】
        - シナリオ設計の「伝える内容」「感情面の目標」「実務面の目標」を必ず達成すること
        - ユーザーの相談内容に対する回答として成立していること
        - 操作・脅し・束縛・虚偽・暴言・違法・過度に性的な内容は禁止
        - 質問は最大1つまで
        - [〇〇]や（場所名）のようなプレースホルダーは絶対禁止。そのまま送信できる具体的な文章にすること

        【書き方のルール】
        - 短く自然なLINEメッセージとして書くこと（1案あたり40文字以内目安）
        - 絵文字・顔文字は使わないこと（次ステップで付与する）
        - 敬語/タメ口はどちらでもよい（次ステップで統一する）
        - 性格傾向を踏まえた「伝え方のニュアンス」は反映してよい

        【感情面の問題】\(ep.feeling) → \(ep.approach)
        【根本の問題】\(rp.situation) → \(rp.approach)

        【シナリオ設計（3案）】
        \(scenarioLines)

        【Do】\(doLines)
        【Don't】\(dontLines)

        【ユーザーの性格傾向】
        \(personalityContext)

        【提案チャット履歴】
        \(historySnippet.isEmpty ? "初回相談" : historySnippet)

        【出力JSON】
        {"candidates": [{"id":"A", "label":"案A（...）", "text":"..."},{"id":"B", "label":"案B（...）", "text":"..."},{"id":"C", "label":"案C（...）", "text":"..."}], "notes":["..."]}
        """
    }

    // MARK: - Call 2b: スタイル転写

    private func requestStyleTransfer(
        contentPayload: GeminiReplyPayload,
        userStyleDesc: String,
        quantitativeStyleTargets: String,
        hardConstraintRules: String,
        ragExamples: [String]
    ) async throws -> (GeminiReplyPayload, String, String) {
        let prompt = buildStyleTransferPrompt(
            contentPayload: contentPayload,
            userStyleDesc: userStyleDesc,
            quantitativeStyleTargets: quantitativeStyleTargets,
            hardConstraintRules: hardConstraintRules,
            ragExamples: ragExamples
        )

        let rawText = try await geminiService.generateText(prompt: prompt, maxTokens: 1000, temperature: 0.30)
        return (try decodeComposerOutput(from: rawText), prompt, rawText)
    }

    private func buildStyleTransferPrompt(
        contentPayload: GeminiReplyPayload,
        userStyleDesc: String,
        quantitativeStyleTargets: String,
        hardConstraintRules: String,
        ragExamples: [String]
    ) -> String {
        let candidatesText = formatCandidatesForStyleTransfer(contentPayload)

        let ragLines = ragExamples.isEmpty
            ? "（なし）"
            : ragExamples.map { "「\($0)」" }.joined(separator: "\n")

        return """
        あなたはLINEメッセージのスタイル転写専門家です。必ずJSONのみで返してください。

        【タスク】
        以下の「変換対象テキスト」を、ユーザーの口調・文体に変換してください。
        あなたの仕事は「どんな言葉で言うか」だけです。内容は変えません。

        【絶対禁止】
        - 意味・意図・感情を変えること
        - 情報を追加・削除すること
        - 相談内容への回答として成立しなくなる変更

        【変換ルール】
        - 語尾・絵文字・句読点・一人称・相手の呼び方をユーザーのスタイルに合わせる
        - 文の長さはユーザーの傾向に合わせて調整する（短い人は短く、長い人はそのまま）

        【ハード制約（絶対厳守）】
        \(hardConstraintRules)

        【ユーザー文体プロファイル】
        \(userStyleDesc)

        【スタイル数値目標】
        \(quantitativeStyleTargets)

        【口調の手本（内容は無関係。語尾・絵文字・句読点だけ参考にすること）】
        \(ragLines)

        【変換対象テキスト】
        \(candidatesText)

        【出力JSON】
        {"candidates": [{"id":"A", "label":"案A（...）", "text":"変換後テキスト"},{"id":"B", "label":"案B（...）", "text":"変換後テキスト"},{"id":"C", "label":"案C（...）", "text":"変換後テキスト"}], "notes":["..."]}
        """
    }

    private func formatCandidatesForStyleTransfer(_ payload: GeminiReplyPayload) -> String {
        payload.candidates.map { candidate in
            "- id=\"\(candidate.id)\" label=\"\(candidate.label)\": \(candidate.text)"
        }.joined(separator: "\n")
    }

    private func buildQuantitativeStyleTargets(style: StyleDNA) -> String {
        var sections: [String] = []

        // 語尾目標
        let topEndings = style.endingDistribution
            .sorted { $0.value > $1.value }
            .prefix(5)
        if !topEndings.isEmpty {
            let endingLines = topEndings.map { "\($0.key):\(Int($0.value * 100))%" }.joined(separator: ", ")
            sections.append("語尾目標: \(endingLines)")
        }

        // 使ってほしい言葉
        let sigWords = style.signatureWords.prefix(4)
        if !sigWords.isEmpty {
            sections.append("使ってほしい言葉: \(sigWords.joined(separator: "、"))")
        }

        // 絵文字
        if style.emojiUse {
            let topEmoji = style.emojiTop.prefix(3).joined(separator: " ")
            let densityHint = style.emojiDensity > 0.03 ? "多め" : style.emojiDensity > 0.01 ? "適度" : "控えめ"
            let positionHint = style.emojiPositionEnd ? "文末に配置" : "文中に自然に配置"
            sections.append("絵文字: \(topEmoji)（密度:\(densityHint)、\(positionHint)）")
        } else {
            sections.append("絵文字: 使用しない")
        }

        // 「！」の使用ガイド
        if style.punctuation.exclamationRate > 0.03 {
            sections.append("「！」: 積極的に使う（出現率\(Int(style.punctuation.exclamationRate * 100))%超）")
        } else if style.punctuation.exclamationRate < 0.005 {
            sections.append("「！」: 使わない")
        }

        return sections.joined(separator: "\n")
    }

    // MARK: - Stage 2b: ハード制約ローカル適用

    private func applyHardConstraintsToPayload(
        payload: GeminiReplyPayload,
        style: StyleDNA
    ) -> GeminiReplyPayload {
        let updatedCandidates = payload.candidates.map { candidate in
            var text = applyHardConstraints(draftText: candidate.text, style: style)
            text = applyStyleTuning(text: text, style: style)
            return GeminiReplyCandidate(
                id: candidate.id,
                label: candidate.label,
                text: text,
                simulations: candidate.simulations
            )
        }
        return GeminiReplyPayload(candidates: updatedCandidates, notes: payload.notes)
    }

    private func applyHardConstraints(draftText: String, style: StyleDNA) -> String {
        var text = draftText

        // 一人称置換
        if let preferred = style.preferredFirstPerson {
            let firstPersons = ["私", "わたし", "うち", "俺", "おれ", "ぼく", "僕"]
            for fp in firstPersons where fp != preferred {
                text = text.replacingOccurrences(of: fp, with: preferred)
            }
        }

        // 絵文字制御
        if !style.emojiUse {
            text = removeAllEmoji(from: text)
        }

        // 句点削除（ユーザーが句点を使わない場合）
        if style.punctuation.periodRate < 0.002 {
            text = text.replacingOccurrences(of: "。", with: "")
        }

        // w/ww削除（ユーザーが使わない場合）
        let wFrequency = style.laughDistribution["w", default: 0] + style.laughDistribution["ww", default: 0]
        if wFrequency < 0.08 {
            text = text.replacingOccurrences(of: "ww", with: "")
            text = text.replacingOccurrences(of: "ｗｗ", with: "")
            // 単独の w は文脈依存のため慎重に: 英単語中の w を壊さないよう語末のみ
            let wPattern = try? NSRegularExpression(pattern: "(?<=[ぁ-んァ-ン一-龥])w+$|(?<=[ぁ-んァ-ン一-龥])w+(?=[\\s、。！？])", options: [])
            if let regex = wPattern {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
            text = text.replacingOccurrences(of: "ｗ", with: "")
        }

        // 敬語↔タメ口変換（基本パターン）
        if style.politenessRatio < 0.1 {
            // タメ口モード: 敬語を除去
            text = text.replacingOccurrences(of: "ですね", with: "だね")
            text = text.replacingOccurrences(of: "ですか", with: "？")
            text = text.replacingOccurrences(of: "ですよ", with: "だよ")
            text = text.replacingOccurrences(of: "ました", with: "した")
            text = text.replacingOccurrences(of: "でした", with: "だった")
            text = text.replacingOccurrences(of: "ですが", with: "だけど")
            text = text.replacingOccurrences(of: "ません", with: "ない")
            text = text.replacingOccurrences(of: "ます", with: "る")
            text = text.replacingOccurrences(of: "です", with: "だ")
        } else if style.politenessRatio > 0.5 {
            // 敬語モード: タメ口を敬語に
            text = text.replacingOccurrences(of: "だね", with: "ですね")
            text = text.replacingOccurrences(of: "だよ", with: "ですよ")
            text = text.replacingOccurrences(of: "だった", with: "でした")
            text = text.replacingOccurrences(of: "だけど", with: "ですが")
        }

        // 長さ制限
        let maxLen = max(18, Int(Double(max(style.p90Length, 18)) * 1.5))
        if text.count > maxLen {
            let searchStart = max(0, maxLen - 10)
            let startIdx = text.index(text.startIndex, offsetBy: searchStart)
            let endIdx = text.index(text.startIndex, offsetBy: min(text.count, maxLen))

            // 優先1: 文の区切り（。！？改行）で切る
            let sentenceBreaks: Set<Character> = ["。", "！", "？", "\n"]
            var bestBreak: String.Index?
            var idx = text.index(before: endIdx)
            while idx >= startIdx {
                if sentenceBreaks.contains(text[idx]) {
                    bestBreak = text.index(after: idx)
                    break
                }
                if idx == startIdx { break }
                idx = text.index(before: idx)
            }

            // 優先2: 文の区切りが見つからなければ読点で切る
            if bestBreak == nil {
                idx = text.index(before: endIdx)
                while idx >= startIdx {
                    if text[idx] == "、" {
                        bestBreak = text.index(after: idx)
                        break
                    }
                    if idx == startIdx { break }
                    idx = text.index(before: idx)
                }
            }

            if let breakPoint = bestBreak, breakPoint > startIdx {
                text = String(text[..<breakPoint])
            } else {
                text = String(text.prefix(maxLen))
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeAllEmoji(from text: String) -> String {
        String(text.unicodeScalars.filter { scalar in
            !(scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x238C))
        })
    }

    // MARK: - Style Tuning (Stage 2b拡張)

    private func applyStyleTuning(text: String, style: StyleDNA) -> String {
        var result = text
        result = tuneEnding(text: result, style: style)
        result = tuneEmoji(text: result, style: style)
        result = tunePunctuation(text: result, style: style)
        return result
    }

    /// 語尾チューニング（重み0.22、最重要）
    /// 意味を変えない範囲でのみ語尾を置換する。断定↔不確定の変換は行わない。
    private func tuneEnding(text: String, style: StyleDNA) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        // 疑問符で終わる場合はそのまま（意図破壊防止）
        if trimmed.hasSuffix("?") || trimmed.hasSuffix("？") { return text }

        // 末尾が絵文字の場合はそのまま（絵文字の後に語尾を追加しない）
        if isEmojiAtEnd(trimmed) { return text }

        // ユーザーのtop3語尾を取得
        let topEndings = style.endingDistribution
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
        guard !topEndings.isEmpty else { return text }

        // 現在の語尾を検出
        let currentEnding = extractEndingToken(trimmed)

        // ユーザーのtop3に含まれていれば何もしない
        if let current = currentEnding, topEndings.contains(current) {
            return text
        }

        // 意味を保つ入れ替え可能語尾グループ（断定系と不確定系は分離）
        let swappableGroups: [[String]] = [
            ["だよ", "だよね", "だね"],    // 断定・共感系
            ["かな", "かも", "かもね"],    // 不確定・推量系
            ["ね", "よ"],                  // 軽い助詞系
            ["じゃん", "だよね"],           // 確認系
        ]

        // 現在の語尾が入れ替え可能グループに含まれるか確認
        if let current = currentEnding {
            for group in swappableGroups {
                if group.contains(current) {
                    // 同グループ内でtop語尾と一致するものがあれば置換
                    if let replacement = topEndings.first(where: { group.contains($0) }) {
                        if trimmed.hasSuffix(current) {
                            let base = String(trimmed.dropLast(current.count))
                            return base + replacement
                        }
                    }
                }
            }
        }

        // 該当なし時は「ね」「よ」のみ追加候補（「かな」は意味が変わるため除外）
        let safeAppendEndings = ["ね", "よ"]
        if let appendEnding = topEndings.first(where: { safeAppendEndings.contains($0) }) {
            if !trimmed.hasSuffix(appendEnding) {
                return trimmed + appendEnding
            }
        }

        return text
    }

    /// 絵文字チューニング（重み0.18）
    /// 深刻・謝罪・悲しみの文脈では絵文字を挿入しない。
    private func tuneEmoji(text: String, style: StyleDNA) -> String {
        guard style.emojiUse, style.emojiDensity >= 0.01 else { return text }
        guard !style.emojiTop.isEmpty else { return text }

        // 深刻な文脈では絵文字追加をスキップ
        if isSeriousContext(text) { return text }

        let topEmoji = style.emojiTop[0]
        let topEmojiSet = Set(style.emojiTop.prefix(3))
        let existingEmojis = extractEmojis(from: text)

        if existingEmojis.isEmpty {
            // 絵文字0個 → top[0]を文末に1つ挿入
            return text + topEmoji
        }

        // 絵文字が存在するがユーザーのtop3と不一致 → 最初の1つをtop[0]に置換
        if !existingEmojis.contains(where: { topEmojiSet.contains($0) }) {
            if let firstEmoji = existingEmojis.first,
               let range = text.range(of: firstEmoji) {
                var result = text
                result.replaceSubrange(range, with: topEmoji)
                return result
            }
        }

        return text
    }

    /// 句読点チューニング（重み0.15）
    /// 深刻・謝罪の文脈では「。」→「！」変換を行わない。
    private func tunePunctuation(text: String, style: StyleDNA) -> String {
        guard style.punctuation.exclamationRate > 0.03 else { return text }

        let hasExclamation = text.contains("！") || text.contains("!")
        guard !hasExclamation else { return text }

        // 深刻な文脈では変換をスキップ
        if isSeriousContext(text) { return text }

        // 末尾の「。」を「！」に変換
        if text.hasSuffix("。") {
            return String(text.dropLast()) + "！"
        }

        return text
    }

    /// 謝罪・深刻・悲しみなど、スタイル装飾が不適切な文脈を検出
    private func isSeriousContext(_ text: String) -> Bool {
        let seriousKeywords = [
            "ごめん", "すみません", "申し訳", "反省",
            "悲しい", "つらい", "辛い", "寂しい", "不安",
            "心配", "怒ら", "傷つ", "別れ", "離れ"
        ]
        return seriousKeywords.contains { text.contains($0) }
    }

    /// テキストが自然な日本語として成立しているかチェック
    private func isCoherentText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }

        // 接続助詞で終わる → 文が途中で切れている
        let danglingEndings = ["けど", "から", "ので", "のに", "って", "ても", "たら", "なら", "てて"]
        for ending in danglingEndings {
            if trimmed.hasSuffix(ending) { return false }
        }

        // 「〜るん」「〜あるん」で終わる → 「〜るんだけど」等の途中切れ
        if trimmed.hasSuffix("るん") || trimmed.hasSuffix("たん") || trimmed.hasSuffix("なん") {
            // ただし「？」直前なら疑問形として成立
            let beforeSuffix = String(trimmed.dropLast(2))
            if !beforeSuffix.hasSuffix("？") && !beforeSuffix.hasSuffix("?") {
                return false
            }
        }

        // 孤立した全角数字を検出（例: "感謝２ "）
        if let regex = try? NSRegularExpression(pattern: "[ぁ-んァ-ヶー一-龥][０-９][\\s　ぁ-んァ-ヶー一-龥]") {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if regex.firstMatch(in: trimmed, range: range) != nil { return false }
        }

        // 孤立カタカナ断片を検出（例: "してるイル"）— ひらがな+カタカナ1〜2文字+非カタカナ
        if let regex = try? NSRegularExpression(pattern: "[ぁ-ん][ァ-ヶー]{1,2}[ぁ-ん。！？、\\s]") {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if regex.firstMatch(in: trimmed, range: range) != nil { return false }
        }

        // 文末が孤立カタカナ1〜2文字で終わる（例: "してるイル！"）
        if let regex = try? NSRegularExpression(pattern: "[ぁ-ん][ァ-ヶー]{1,2}[！!]?$") {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if regex.firstMatch(in: trimmed, range: range) != nil { return false }
        }

        return true
    }

    // MARK: - Call 2.5: Rewrite

    private func requestComposerRewrite(
        previousPayload: GeminiReplyPayload,
        rewriteTargets: [RewriteTarget],
        hardConstraintRules: String,
        userStyleDesc: String,
        ragExamples: [String],
        userGoal: String
    ) async throws -> (GeminiReplyPayload, String, String) {
        let prompt = buildComposerRewritePrompt(
            previousPayload: previousPayload,
            rewriteTargets: rewriteTargets,
            hardConstraintRules: hardConstraintRules,
            userStyleDesc: userStyleDesc,
            ragExamples: ragExamples,
            userGoal: userGoal
        )

        let rawText = try await geminiService.generateText(prompt: prompt, maxTokens: 1200, temperature: 0.35)
        let rewritePayload = try decodeComposerOutput(from: rawText)

        var merged = previousPayload
        for rewritten in rewritePayload.candidates {
            if let idx = merged.candidates.firstIndex(where: { $0.id == rewritten.id }) {
                merged.candidates[idx] = rewritten
            }
        }

        if !rewritePayload.notes.isEmpty {
            merged.notes = rewritePayload.notes
        }

        return (merged, prompt, rawText)
    }

    private func buildComposerRewritePrompt(
        previousPayload: GeminiReplyPayload,
        rewriteTargets: [RewriteTarget],
        hardConstraintRules: String,
        userStyleDesc: String,
        ragExamples: [String],
        userGoal: String
    ) -> String {
        let existingTexts = previousPayload.candidates.map { candidate in
            "{\"id\":\"\(candidate.id)\",\"label\":\"\(candidate.label)\",\"text\":\"\(candidate.text)\"}"
        }.joined(separator: ",\n")

        let rewriteLines = rewriteTargets.map { target in
            "- id=\(target.id): \(target.reasons.joined(separator: ", "))"
        }.joined(separator: "\n")

        let ragLines = ragExamples.isEmpty
            ? "（なし）"
            : ragExamples.map { "「\($0)」" }.joined(separator: "\n")

        return """
        次のJSON候補のうち、指定IDだけを修正してください。必ずJSONのみ返してください。

        【最重要: 内容を変えないこと】
        - 元の文が伝えようとしている内容・意図・感情は絶対に変えないでください
        - 修正はスタイル（語尾・絵文字・句読点・語彙）の調整のみにしてください
        - 相談内容への回答として成立しなくなる修正は禁止です

        【ハード制約（絶対厳守）】
        \(hardConstraintRules)

        【相談内容】
        \(userGoal)

        【ユーザー文体プロファイル】
        \(userStyleDesc)

        【口調の手本（内容は無関係。語尾・絵文字・句読点だけ参考にすること）】
        \(ragLines)

        【修正対象と理由】
        \(rewriteLines)

        【元データ】
        {"candidates": [\(existingTexts)]}

        【出力JSON（修正対象のみ）】
        {
          "candidates": [
            {"id": "A or B or C", "label": "既存ラベル", "text": "修正文"}
          ],
          "notes": []
        }
        """
    }

    // MARK: - Pipeline Call 3: Simulator (既存のまま)

    private func requestSimulation(
        candidates: [ReplyCandidate],
        partnerStyleDesc: String,
        relationshipContext: String,
        recentSnippet: String
    ) async throws -> SimulatorOutputDTO {
        let prompt = buildSimulatorPrompt(
            candidates: candidates,
            partnerStyleDesc: partnerStyleDesc,
            relationshipContext: relationshipContext,
            recentSnippet: recentSnippet
        )

        let rawText = try await geminiService.generateText(prompt: prompt, maxTokens: 2000, temperature: 0.45)
        return try decodeSimulatorOutput(from: rawText)
    }

    private func buildSimulatorPrompt(
        candidates: [ReplyCandidate],
        partnerStyleDesc: String,
        relationshipContext: String,
        recentSnippet: String
    ) -> String {
        let candidateTexts = candidates.map { c in
            "- id=\"\(c.id)\": \(c.text)"
        }.joined(separator: "\n")

        return """
        あなたはLINE相手シミュレーターです。必ずJSONのみで返してください。

        【タスク】
        以下の返信案を受け取った相手がどう反応するかを予測してください。
        各案に3パターン（good/neutral/bad_or_silent）の反応と、それぞれへの「次の一手」を出してください。

        【相手文体プロファイル】
        \(partnerStyleDesc)

        【関係性】
        \(relationshipContext)

        【直近会話】
        \(recentSnippet)

        【返信案】
        \(candidateTexts)

        【出力JSON】
        {
          "simulations": [
            {
              "id": "A",
              "patterns": [
                {"pattern": "good", "partner_text": "相手の反応（相手の口調で）", "next_move": "次の一手"},
                {"pattern": "neutral", "partner_text": "...", "next_move": "..."},
                {"pattern": "bad_or_silent", "partner_text": "...", "next_move": "..."}
              ]
            },
            {"id": "B", "patterns": [...]},
            {"id": "C", "patterns": [...]}
          ]
        }
        """
    }

    private func decodeSimulatorOutput(from rawText: String) throws -> SimulatorOutputDTO {
        let cleaned = sanitizeToJSON(rawText)
        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.parsingFailed
        }

        do {
            return try JSONDecoder().decode(SimulatorOutputDTO.self, from: data)
        } catch {
            throw GeminiError.parsingFailed
        }
    }

    private func mergeSimulations(candidates: [ReplyCandidate], simOutput: SimulatorOutputDTO) -> [ReplyCandidate] {
        candidates.map { candidate in
            let simCandidate = simOutput.simulations.first { $0.id == candidate.id }
            let simulations = simCandidate?.patterns.map { $0.toSimulation() } ?? []

            return ReplyCandidate(
                id: candidate.id,
                label: candidate.label,
                text: candidate.text,
                styleScore: candidate.styleScore,
                riskFlags: candidate.riskFlags,
                simulations: simulations.isEmpty ? candidate.simulations : simulations
            )
        }
    }

    // MARK: - Local Processing

    private func buildLocalRelationshipContext(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String
    ) -> String {
        let baseHint = relationshipHint(from: messages, selfName: selfName, partnerName: partnerName)

        let recent = Array(messages.suffix(80))
        guard recent.count >= 4 else { return baseHint }

        let half = recent.count / 2
        let firstHalf = Array(recent.prefix(half))
        let secondHalf = Array(recent.suffix(half))

        let firstPartnerRate = Double(firstHalf.filter { $0.senderName == partnerName }.count) / Double(max(1, firstHalf.count))
        let secondPartnerRate = Double(secondHalf.filter { $0.senderName == partnerName }.count) / Double(max(1, secondHalf.count))
        let delta = secondPartnerRate - firstPartnerRate

        let momentum: String
        if delta > 0.1 {
            momentum = "相手の参加度が上昇中"
        } else if delta < -0.1 {
            momentum = "相手の参加度が低下中"
        } else {
            momentum = "会話モメンタムは安定"
        }

        let topTerms = extractTopTerms(messages: recent, limit: 5)
        let topicsHint = topTerms.isEmpty ? "" : " / 最近の話題: \(topTerms.joined(separator: "、"))"

        return "\(baseHint) / \(momentum)\(topicsHint)"
    }

    private func buildRecentSnippet(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        maxLines: Int
    ) -> String {
        let recent = Array(messages.suffix(maxLines))
        return recent.map { msg in
            let sender = msg.senderName == selfName ? "自分" : "相手"
            return "[\(sender)] \(msg.content)"
        }.joined(separator: "\n")
    }

    private func buildHardConstraintRules(style: StyleDNA) -> String {
        var rules: [String] = []

        if let fp = style.preferredFirstPerson {
            rules.append("- 一人称は「\(fp)」固定。他の一人称は使用禁止。")
        }

        if !style.emojiUse {
            rules.append("- 絵文字は一切使わないこと。")
        } else if style.emojiDensity > 0.02 {
            let topEmoji = style.emojiTop.prefix(3).joined(separator: " ")
            rules.append("- 絵文字を適度に使う（推奨: \(topEmoji)）。")
        }

        if style.punctuation.periodRate < 0.002 {
            rules.append("- 句点「。」は使わないこと。")
        }

        let wFrequency = style.laughDistribution["w", default: 0] + style.laughDistribution["ww", default: 0]
        if wFrequency < 0.08 {
            rules.append("- 「w」「ww」は使わないこと。")
        }

        let laughFrequency = style.laughDistribution["笑", default: 0]
        if laughFrequency > 0.1 {
            rules.append("- 笑い表現は「笑」を使う。")
        }

        let maxLen = max(18, Int(Double(max(style.p90Length, 18)) * 1.5))
        let recommendedMin = max(8, style.medianLength - 10)
        let recommendedMax = max(15, style.medianLength + 15)
        rules.append("- 文字数は\(maxLen)文字以内（推奨\(recommendedMin)〜\(recommendedMax)文字）。")

        if style.politenessRatio > 0.5 {
            rules.append("- 敬語モードで書くこと。")
        } else if style.politenessRatio < 0.1 {
            rules.append("- タメ口で書くこと。敬語禁止。")
        }

        let topEndings = style.endingDistribution
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "「\($0.key)」" }
        if !topEndings.isEmpty {
            rules.append("- 語尾は\(topEndings.joined(separator: ""))を中心に。")
        }

        if let addressing = style.preferredAddressing, !addressing.isEmpty {
            rules.append("- 相手の呼び方は「\(addressing)」を使う。")
        }

        if style.punctuation.exclamationRate > 0.03 {
            rules.append("- 「！」を自然に使うこと。")
        } else if style.punctuation.exclamationRate < 0.005 {
            rules.append("- 「！」は控えめに（使わなくてよい）。")
        }

        return rules.joined(separator: "\n")
    }

    private func extractTopTerms(messages: [ChatMessage], limit: Int) -> [String] {
        let stopWords: Set<String> = [
            "それ", "これ", "あれ", "こと", "もの", "の", "に", "を", "は", "が", "で", "と",
            "する", "した", "して", "です", "ます", "いる", "ある", "なる", "そう"
        ]

        var counts: [String: Int] = [:]
        for msg in messages {
            for token in tokenize(msg.content) {
                if token.count < 2 { continue }
                if stopWords.contains(token) { continue }
                counts[token, default: 0] += 1
            }
        }

        return Array(counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key))
    }

    // MARK: - Evaluation

    private func evaluate(payload: GeminiReplyPayload, userStyle: StyleDNA) -> EvaluationResult {
        var acceptedCandidates: [ReplyCandidate] = []
        var rewriteTargets: [RewriteTarget] = []

        for candidate in payload.candidates {
            let hardViolations = hardConstraintViolations(text: candidate.text, style: userStyle)
            let riskFlags = detectSafetyRisks(text: candidate.text)
            let breakdown = styleScoreWithBreakdown(for: candidate.text, style: userStyle)

            let mergedViolations = hardViolations + riskFlags
            if breakdown.total < 0.80 || !mergedViolations.isEmpty {
                var reasons = mergedViolations
                if breakdown.total < 0.80 {
                    reasons.append(styleBreakdownFeedback(breakdown: breakdown, style: userStyle))
                }

                rewriteTargets.append(RewriteTarget(id: candidate.id, reasons: deduplicated(reasons)))
                continue
            }

            let replyCandidate = ReplyCandidate(
                id: candidate.id,
                label: candidate.label,
                text: candidate.text,
                styleScore: breakdown.total,
                riskFlags: riskFlags,
                simulations: candidate.simulations
            )
            acceptedCandidates.append(replyCandidate)
        }

        return EvaluationResult(candidates: acceptedCandidates, rewriteTargets: rewriteTargets)
    }

    private func styleBreakdownFeedback(breakdown: StyleScoreBreakdown, style: StyleDNA) -> String {
        var hints: [String] = []

        if breakdown.ending < 0.80 {
            let topEndings = style.endingDistribution
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { "「\($0.key)」" }
                .joined()
            hints.append("語尾スコア:\(String(format: "%.2f", breakdown.ending))→\(topEndings)を使って")
        }

        if breakdown.emoji < 0.80, style.emojiUse {
            let topEmoji = style.emojiTop.prefix(3).joined()
            hints.append("絵文字スコア:\(String(format: "%.2f", breakdown.emoji))→\(topEmoji)を文末に追加")
        }

        if breakdown.vocabulary < 0.80 {
            let words = style.signatureWords.prefix(4).joined(separator: "・")
            hints.append("語彙スコア:\(String(format: "%.2f", breakdown.vocabulary))→\(words)を使って")
        }

        if breakdown.punctuation < 0.80 {
            if style.punctuation.exclamationRate > 0.03 {
                hints.append("句読点スコア:\(String(format: "%.2f", breakdown.punctuation))→「！」を使って")
            } else {
                hints.append("句読点スコア:\(String(format: "%.2f", breakdown.punctuation))→句読点パターンを合わせて")
            }
        }

        return hints.isEmpty ? "style_below_threshold" : hints.joined(separator: " / ")
    }

    private func hardConstraintViolations(text: String, style: StyleDNA) -> [String] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return ["empty_reply"] }

        var violations: [String] = []

        let emojiCount = countEmoji(in: normalized)
        if !style.emojiUse, emojiCount > 0 {
            violations.append("emoji_mismatch")
        }

        if style.emojiUse, style.emojiDensity > 0.02, emojiCount == 0 {
            violations.append("emoji_missing")
        }

        if let preferredFirstPerson = style.preferredFirstPerson {
            let firstPersons = detectFirstPersons(in: normalized)
            if firstPersons.contains(where: { $0 != preferredFirstPerson }) {
                violations.append("first_person_mismatch")
            }
        }

        if let preferredAddressing = style.preferredAddressing,
           let candidateAddressing = detectLeadingAddressing(in: normalized),
           !candidateAddressing.isEmpty,
           candidateAddressing != preferredAddressing,
           !style.addressingDistribution.keys.contains(candidateAddressing) {
            violations.append("addressing_mismatch")
        }

        if normalized.contains("w") || normalized.contains("ｗ") {
            let wFrequency = style.laughDistribution["w", default: 0] + style.laughDistribution["ww", default: 0]
            if wFrequency < 0.08 {
                violations.append("laugh_token_mismatch")
            }
        }

        if style.punctuation.periodRate < 0.002,
           normalized.filter({ $0 == "。" }).count > 0 {
            violations.append("period_style_mismatch")
        }

        let maxLength = max(18, Int(Double(max(style.p90Length, 18)) * 1.5))
        if normalized.count > maxLength {
            violations.append("too_long")
        }

        let questionCount = normalized.filter { $0 == "?" || $0 == "？" }.count
        if questionCount > 1 {
            violations.append("too_many_questions")
        }

        return deduplicated(violations)
    }

    private func detectSafetyRisks(text: String) -> [String] {
        let lower = text.lowercased()
        var risks: [String] = []

        let controlKeywords = ["なんで返信", "返してよ", "絶対", "今すぐ", "監視", "証拠送って"]
        let harassmentKeywords = ["バカ", "死ね", "きもい", "消えろ"]
        let deceptionKeywords = ["嘘ついて", "なりすまして", "ごまかして"]

        if controlKeywords.contains(where: { lower.contains($0) }) {
            risks.append("control")
        }

        if harassmentKeywords.contains(where: { lower.contains($0) }) {
            risks.append("harassment")
        }

        if deceptionKeywords.contains(where: { lower.contains($0) }) {
            risks.append("deception")
        }

        return deduplicated(risks)
    }

    private func styleScore(for text: String, style: StyleDNA) -> Double {
        styleScoreWithBreakdown(for: text, style: style).total
    }

    private func styleScoreWithBreakdown(for text: String, style: StyleDNA) -> StyleScoreBreakdown {
        let candidateStyle = buildSingleTextStyle(text: text)

        let sEnding = endingSimilarity(candidate: candidateStyle.endings, target: style.endingDistribution)
        let sVocab = vocabularySimilarity(text: text, signatureWords: style.signatureWords)
        let sEmoji = emojiSimilarity(candidate: candidateStyle, target: style)
        let sPunct = punctuationSimilarity(candidate: candidateStyle.punctuation, target: style.punctuation)
        let sCasual = casualSimilarity(candidatePoliteness: candidateStyle.politenessRatio, targetPoliteness: style.politenessRatio, text: text, style: style)
        let sLen = lengthSimilarity(length: text.count, median: style.medianLength, p90: style.p90Length)

        let weighted =
            0.22 * sEnding +
            0.20 * sVocab +
            0.18 * sEmoji +
            0.15 * sPunct +
            0.15 * sCasual +
            0.10 * sLen

        let total = min(0.99, max(0, round(weighted * 100) / 100))

        return StyleScoreBreakdown(
            ending: round(sEnding * 100) / 100,
            vocabulary: round(sVocab * 100) / 100,
            emoji: round(sEmoji * 100) / 100,
            punctuation: round(sPunct * 100) / 100,
            casual: round(sCasual * 100) / 100,
            length: round(sLen * 100) / 100,
            total: total
        )
    }

    private func endingSimilarity(candidate: [String: Double], target: [String: Double]) -> Double {
        guard !target.isEmpty else { return 0.85 }
        guard !candidate.isEmpty else { return 0.75 }

        let keys = Set(candidate.keys).union(target.keys)
        var distance: Double = 0
        for key in keys {
            let diff = abs(candidate[key, default: 0] - target[key, default: 0])
            distance += diff
        }

        let score = 1.0 - min(1.0, distance / 2.0)
        return max(0.6, score)
    }

    private func vocabularySimilarity(text: String, signatureWords: [String]) -> Double {
        guard !signatureWords.isEmpty else { return 0.88 }

        let matched = signatureWords.filter { word in
            text.contains(word)
        }.count

        let cap = max(1, min(6, signatureWords.count))
        let coverage = Double(matched) / Double(cap)
        return min(1.0, 0.78 + coverage * 0.25)
    }

    private func emojiSimilarity(candidate: SingleTextStyle, target: StyleDNA) -> Double {
        if !target.emojiUse {
            return candidate.emojiCount == 0 ? 1.0 : 0.4
        }

        if candidate.emojiCount == 0 {
            return target.emojiDensity < 0.01 ? 0.85 : 0.55
        }

        let candidateSet = Set(candidate.emojis)
        let targetSet = Set(target.emojiTop.prefix(3))

        let intersection = Double(candidateSet.intersection(targetSet).count)
        let union = Double(max(1, candidateSet.union(targetSet).count))
        let jaccard = intersection / union

        let densityDelta = abs(candidate.emojiDensity - target.emojiDensity)
        let densityScore = exp(-densityDelta / 0.03)
        let positionScore = candidate.emojiAtEnd == target.emojiPositionEnd ? 1.0 : 0.7

        return min(1.0, max(0.4, (jaccard * 0.4) + (densityScore * 0.35) + (positionScore * 0.25)))
    }

    private func punctuationSimilarity(candidate: PunctuationProfile, target: PunctuationProfile) -> Double {
        let sigma = 0.02
        let period = exp(-abs(candidate.periodRate - target.periodRate) / sigma)
        let comma = exp(-abs(candidate.commaRate - target.commaRate) / sigma)
        let exclamation = exp(-abs(candidate.exclamationRate - target.exclamationRate) / sigma)
        let question = exp(-abs(candidate.questionRate - target.questionRate) / sigma)
        let newline = exp(-abs(candidate.newlineRate - target.newlineRate) / 0.35)

        return (period + comma + exclamation + question + newline) / 5.0
    }

    private func casualSimilarity(candidatePoliteness: Double, targetPoliteness: Double, text: String, style: StyleDNA) -> Double {
        let politeness = exp(-abs(candidatePoliteness - targetPoliteness) / 0.3)

        var laughScore = 0.9
        if text.contains("w") || text.contains("ｗ") {
            let wFrequency = style.laughDistribution["w", default: 0] + style.laughDistribution["ww", default: 0]
            laughScore = wFrequency > 0.1 ? 1.0 : 0.45
        }
        if text.contains("笑") {
            let laughFrequency = style.laughDistribution["笑", default: 0]
            laughScore = max(laughScore, laughFrequency > 0.05 ? 1.0 : 0.6)
        }

        return min(1.0, (politeness * 0.7) + (laughScore * 0.3))
    }

    private func lengthSimilarity(length: Int, median: Int, p90: Int) -> Double {
        let center = max(8, median)
        let tolerance = max(10, Int(Double(max(p90, center)) * 0.8))
        let diff = abs(length - center)
        let score = exp(-Double(diff) / Double(tolerance))
        return min(1.0, max(0.5, score))
    }

    // MARK: - Context Retrieval

    private func shouldUseBackfill(goal: String, recentCount: Int) -> Bool {
        if recentCount < 60 {
            return true
        }

        let backfillKeywords = ["去年", "先月", "前", "前回", "昔", "あのとき", "旅行", "前に"]
        return backfillKeywords.contains { goal.contains($0) }
    }

    private func retrieveRelevantBlocks(goal: String, blocks: [ReplyConversationBlock], recentCutoff: Date) -> [ReplyConversationBlock] {
        let queryTerms = Set(tokenize(goal))
        guard !queryTerms.isEmpty else { return [] }

        let olderBlocks = blocks.filter { $0.end < recentCutoff }
        guard !olderBlocks.isEmpty else { return [] }

        let scored = olderBlocks.map { block -> (ReplyConversationBlock, Int) in
            let hitCount = queryTerms.intersection(block.indexTerms).count
            return (block, hitCount)
        }

        let sorted = scored
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.end > rhs.0.end
                }
                return lhs.1 > rhs.1
            }

        return Array(sorted.prefix(5).map(\.0))
    }

    private func buildConversationBlocks(messages: [ChatMessage]) -> [ReplyConversationBlock] {
        var blocks: [ReplyConversationBlock] = []
        var currentMessages: [ChatMessage] = []
        var currentChars = 0
        var blockIndex = 1

        func flushCurrent() {
            guard !currentMessages.isEmpty else { return }
            let terms = tokenize(currentMessages.map(\.content).joined(separator: " "))
            let block = ReplyConversationBlock(
                id: "b_\(blockIndex)",
                messages: currentMessages,
                start: currentMessages.first?.timestamp ?? Date(),
                end: currentMessages.last?.timestamp ?? Date(),
                indexTerms: Set(terms)
            )
            blocks.append(block)
            blockIndex += 1
            currentMessages = []
            currentChars = 0
        }

        for message in messages {
            if let previous = currentMessages.last {
                let gapHours = abs(message.timestamp.timeIntervalSince(previous.timestamp)) / 3600
                let shouldSplitByGap = gapHours >= 6
                let shouldSplitBySize = currentMessages.count >= 40 || currentChars >= 3000

                if shouldSplitByGap || shouldSplitBySize {
                    flushCurrent()
                }
            }

            currentMessages.append(message)
            currentChars += message.content.count
        }

        flushCurrent()
        return blocks
    }

    private func retrieveRAGUserExamples(
        query: String,
        allMessages: [ChatMessage],
        selfName: String,
        maxCount: Int
    ) -> [String] {
        // スタイル多様性ベースのRAG取得
        let userMessages = allMessages
            .filter { $0.senderName == selfName }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { $0.content.count >= 5 && $0.content.count <= 70 }

        guard !userMessages.isEmpty else { return [] }

        // スタイルフィンガープリントでグループ化
        var groups: [String: [ChatMessage]] = [:]
        for msg in userMessages {
            let fingerprint = styleFingerprint(msg.content)
            groups[fingerprint, default: []].append(msg)
        }

        // 各グループから最新1件を代表として選出
        let representatives: [(message: ChatMessage, groupSize: Int)] = groups.compactMap { (_, msgs) in
            guard let latest = msgs.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
            return (message: latest, groupSize: msgs.count)
        }

        // グループサイズ降順でソート（頻出パターン優先）
        let sorted = representatives
            .sorted { $0.groupSize > $1.groupSize }
            .prefix(maxCount)
            .map(\.message.content)

        return deduplicated(Array(sorted))
    }

    private func styleFingerprint(_ text: String) -> String {
        // 語尾判定
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ending: String
        if trimmed.hasSuffix("笑") || trimmed.hasSuffix("w") || trimmed.hasSuffix("ｗ") {
            ending = "laugh"
        } else if trimmed.hasSuffix("！") || trimmed.hasSuffix("!") {
            ending = "excl"
        } else if trimmed.hasSuffix("？") || trimmed.hasSuffix("?") {
            ending = "question"
        } else if trimmed.hasSuffix("。") {
            ending = "period"
        } else if trimmed.hasSuffix("〜") || trimmed.hasSuffix("～") || trimmed.hasSuffix("ー") {
            ending = "extend"
        } else {
            ending = "bare"
        }

        // 絵文字有無
        let hasEmoji = trimmed.unicodeScalars.contains { scalar in
            let v = scalar.value
            return (0x1F600...0x1F64F).contains(v) ||
                   (0x1F300...0x1F5FF).contains(v) ||
                   (0x1F680...0x1F6FF).contains(v) ||
                   (0x1F900...0x1F9FF).contains(v) ||
                   (0x2600...0x26FF).contains(v) ||
                   (0x2700...0x27BF).contains(v)
        }
        let emojiFlag = hasEmoji ? "E" : "N"

        // 敬語/タメ口
        let polite = trimmed.contains("です") || trimmed.contains("ます") || trimmed.contains("ました") || trimmed.contains("ですか")
        let politeFlag = polite ? "P" : "C"

        // 長さバケット
        let lenBucket: String
        switch trimmed.count {
        case 0..<10: lenBucket = "S"
        case 10..<25: lenBucket = "M"
        default: lenBucket = "L"
        }

        return "\(ending)_\(emojiFlag)_\(politeFlag)_\(lenBucket)"
    }

    private func relationshipHint(from messages: [ChatMessage], selfName: String, partnerName: String) -> String {
        let recent = Array(messages.suffix(80))
        let selfCount = recent.filter { $0.senderName == selfName }.count
        let partnerCount = recent.filter { $0.senderName == partnerName }.count

        let balance: String
        if selfCount == 0 || partnerCount == 0 {
            balance = "片側発話が多め"
        } else {
            let ratio = Double(min(selfCount, partnerCount)) / Double(max(selfCount, partnerCount))
            if ratio > 0.8 {
                balance = "会話量はほぼ均衡"
            } else if selfCount > partnerCount {
                balance = "ユーザー主導"
            } else {
                balance = "相手主導"
            }
        }

        let avgLengthSelf = averageLength(messages: recent.filter { $0.senderName == selfName })
        let avgLengthPartner = averageLength(messages: recent.filter { $0.senderName == partnerName })

        let lengthHint: String
        if avgLengthPartner < 12 {
            lengthHint = "相手は短文寄り"
        } else if avgLengthPartner > 35 {
            lengthHint = "相手は説明多め"
        } else {
            lengthHint = "相手は中間的な文長"
        }

        return "\(balance) / \(lengthHint) / 自分平均\(avgLengthSelf)文字・相手平均\(avgLengthPartner)文字"
    }

    private func averageLength(messages: [ChatMessage]) -> Int {
        guard !messages.isEmpty else { return 0 }
        let total = messages.reduce(0) { $0 + $1.content.count }
        return total / messages.count
    }

    private func mergeAndSortMessages(primary: [ChatMessage], secondary: [ChatMessage]) -> [ChatMessage] {
        var merged: [UUID: ChatMessage] = [:]
        for message in primary + secondary {
            merged[message.id] = message
        }
        return merged.values.sorted { $0.timestamp < $1.timestamp }
    }

    private func resolveStyleProfiles(
        analysisResult: AnalysisResult?,
        selfName: String,
        partnerName: String
    ) -> (userStyle: StyleDNA, partnerStyle: StyleDNA)? {
        guard let stored = analysisResult?.replyStyleProfiles else { return nil }

        if stored.selfName == selfName, stored.partnerName == partnerName {
            return (
                userStyle: fromReplyStyleProfile(stored.selfStyle),
                partnerStyle: fromReplyStyleProfile(stored.partnerStyle)
            )
        }

        if stored.selfName == partnerName, stored.partnerName == selfName {
            return (
                userStyle: fromReplyStyleProfile(stored.partnerStyle),
                partnerStyle: fromReplyStyleProfile(stored.selfStyle)
            )
        }

        return nil
    }

    private func toReplyStyleProfile(_ style: StyleDNA) -> ReplyStyleProfile {
        ReplyStyleProfile(
            preferredFirstPerson: style.preferredFirstPerson,
            firstPersonDistribution: style.firstPersonDistribution,
            preferredAddressing: style.preferredAddressing,
            addressingDistribution: style.addressingDistribution,
            endingDistribution: style.endingDistribution,
            politenessRatio: style.politenessRatio,
            laughDistribution: style.laughDistribution,
            emojiUse: style.emojiUse,
            emojiTop: style.emojiTop,
            emojiDensity: style.emojiDensity,
            emojiPositionEnd: style.emojiPositionEnd,
            punctuation: ReplyPunctuationProfile(
                periodRate: style.punctuation.periodRate,
                commaRate: style.punctuation.commaRate,
                exclamationRate: style.punctuation.exclamationRate,
                questionRate: style.punctuation.questionRate,
                ellipsisRate: style.punctuation.ellipsisRate,
                newlineRate: style.punctuation.newlineRate
            ),
            medianLength: style.medianLength,
            p90Length: style.p90Length,
            signatureWords: style.signatureWords
        )
    }

    private func fromReplyStyleProfile(_ style: ReplyStyleProfile) -> StyleDNA {
        // サニタイズ: 旧データで数字がemojiTopに混入している場合を除去
        let sanitizedEmojiTop = style.emojiTop.filter { str in
            guard let scalar = str.unicodeScalars.first else { return false }
            return scalar.properties.isEmojiPresentation ||
                   (scalar.properties.isEmoji && scalar.value > 0x238C)
        }
        let sanitizedEmojiUse = sanitizedEmojiTop.isEmpty ? false : style.emojiUse
        let sanitizedEmojiDensity = sanitizedEmojiTop.isEmpty ? 0.0 : style.emojiDensity

        return StyleDNA(
            preferredFirstPerson: style.preferredFirstPerson,
            firstPersonDistribution: style.firstPersonDistribution,
            preferredAddressing: style.preferredAddressing,
            addressingDistribution: style.addressingDistribution,
            endingDistribution: style.endingDistribution,
            politenessRatio: style.politenessRatio,
            laughDistribution: style.laughDistribution,
            emojiUse: sanitizedEmojiUse,
            emojiTop: sanitizedEmojiTop,
            emojiDensity: sanitizedEmojiDensity,
            emojiPositionEnd: sanitizedEmojiTop.isEmpty ? false : style.emojiPositionEnd,
            punctuation: PunctuationProfile(
                periodRate: style.punctuation.periodRate,
                commaRate: style.punctuation.commaRate,
                exclamationRate: style.punctuation.exclamationRate,
                questionRate: style.punctuation.questionRate,
                ellipsisRate: style.punctuation.ellipsisRate,
                newlineRate: style.punctuation.newlineRate
            ),
            medianLength: style.medianLength,
            p90Length: style.p90Length,
            signatureWords: style.signatureWords
        )
    }

    // MARK: - Style DNA

    private func buildStyleDNA(messages: [ChatMessage], senderName: String, partnerName: String) -> StyleDNA {
        // チャンク処理: 中間カウントを蓄積してメモリピークを抑制
        let chunkSize = 2000
        var firstPersonCounts: [String: Int] = [:]
        var addressingCounts: [String: Int] = [:]
        var endingCounts: [String: Int] = [:]
        var laughCounts: [String: Int] = [:]
        var lengths: [Int] = []
        var politeCount = 0
        var totalTextCount = 0
        var allSenderTexts: [String] = []

        let senderMessages = messages.filter { $0.senderName == senderName }

        for startIndex in stride(from: 0, to: senderMessages.count, by: chunkSize) {
            autoreleasepool {
                let end = min(startIndex + chunkSize, senderMessages.count)
                let chunkTexts = senderMessages[startIndex..<end]
                    .map(\.content)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                for text in chunkTexts {
                    // 一人称
                    for fp in detectFirstPersons(in: text) {
                        firstPersonCounts[fp, default: 0] += 1
                    }
                    // 呼びかけ
                    if let addr = detectLeadingAddressing(in: text) {
                        addressingCounts[addr, default: 0] += 1
                    }
                    // 文末
                    if let ending = extractEndingToken(text) {
                        endingCounts[ending, default: 0] += 1
                    }
                    // 笑い
                    for laugh in detectLaughTokens(in: text) {
                        laughCounts[laugh, default: 0] += 1
                    }
                    // 丁寧語
                    if isPoliteSpeech(text) { politeCount += 1 }
                    lengths.append(text.count)
                }
                totalTextCount += chunkTexts.count
                allSenderTexts.append(contentsOf: chunkTexts)
            }
        }

        let senderTexts = allSenderTexts
        let firstPersonDistribution = normalizeCounts(firstPersonCounts)
        let addressingDistribution = normalizeCounts(addressingCounts)
        let endingDistribution = normalizeCounts(endingCounts)
        let laughDistribution = normalizeCounts(laughCounts)
        let politenessRatio = totalTextCount > 0 ? Double(politeCount) / Double(totalTextCount) : 0

        let punctuation = buildPunctuationProfile(texts: senderTexts)
        let medianLength = percentile(lengths: lengths, percentile: 0.5)
        let p90Length = percentile(lengths: lengths, percentile: 0.9)
        let emojiStats = buildEmojiStats(texts: senderTexts)
        let signatureWords = buildSignatureWords(texts: senderTexts)

        return StyleDNA(
            preferredFirstPerson: firstPersonDistribution.max(by: { $0.value < $1.value })?.key,
            firstPersonDistribution: firstPersonDistribution,
            preferredAddressing: addressingDistribution.max(by: { $0.value < $1.value })?.key ?? inferredPreferredAddressing(senderTexts: senderTexts, partnerName: partnerName),
            addressingDistribution: addressingDistribution,
            endingDistribution: endingDistribution,
            politenessRatio: politenessRatio,
            laughDistribution: laughDistribution,
            emojiUse: emojiStats.useEmoji,
            emojiTop: emojiStats.top,
            emojiDensity: emojiStats.density,
            emojiPositionEnd: emojiStats.positionEnd,
            punctuation: punctuation,
            medianLength: medianLength,
            p90Length: p90Length,
            signatureWords: signatureWords
        )
    }

    private func buildSingleTextStyle(text: String) -> SingleTextStyle {
        let endings = normalizeCounts(countDictionary(values: [extractEndingToken(text)].compactMap { $0 }))
        let punctuation = buildPunctuationProfile(texts: [text])
        let politenessRatio = calculatePolitenessRatio(texts: [text])

        let emojis = extractEmojis(from: text)
        let emojiDensity = text.isEmpty ? 0 : Double(emojis.count) / Double(text.count)
        let emojiAtEnd = isEmojiAtEnd(text)

        return SingleTextStyle(
            endings: endings,
            punctuation: punctuation,
            politenessRatio: politenessRatio,
            emojis: emojis,
            emojiCount: emojis.count,
            emojiDensity: emojiDensity,
            emojiAtEnd: emojiAtEnd
        )
    }

    private func inferredPreferredAddressing(senderTexts: [String], partnerName: String) -> String {
        // ユーザーのメッセージから相手のニックネーム呼びを検出
        // 短い単独メッセージ（2-8文字、ひらがな/カタカナ/漢字のみ）で名前っぽいものを探す
        let shortMessages = senderTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { msg in
                guard (2...8).contains(msg.count) else { return false }
                // ひらがな・カタカナ・漢字のみで構成
                return msg.allSatisfy { ch in
                    let s = String(ch).unicodeScalars.first!.value
                    return (0x3040...0x309F).contains(s) || // ひらがな
                           (0x30A0...0x30FF).contains(s) || // カタカナ
                           (0x4E00...0x9FFF).contains(s)    // 漢字
                }
            }

        // パートナー名のパーツ（スペース区切り、先頭のみ等）と照合
        let nameParts = partnerName
            .components(separatedBy: CharacterSet.whitespaces.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
            .flatMap { part -> [String] in
                [part, part.lowercased()]
            }

        // ユーザーのメッセージに相手名の一部が含まれるか（ローマ字→ひらがな一致は困難なので、直接一致を確認）
        // 頻度カウントで最頻出のニックネームを選ぶ
        var nicknameCounts: [String: Int] = [:]
        for msg in shortMessages {
            // パートナー名のパーツとの類似性チェック（先頭一致）
            for part in nameParts {
                if msg.lowercased() == part.lowercased() {
                    nicknameCounts[msg, default: 0] += 1
                }
            }
            // 短い単独メッセージが複数回出現（呼びかけパターン）
            nicknameCounts[msg, default: 0] += 1
        }

        // 2回以上出現する短いメッセージを呼びかけ候補とする
        let candidates = nicknameCounts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }

        if let best = candidates.first?.key {
            return best
        }

        // フォールバック: パートナー名をそのまま使う
        let compactPartner = partnerName.replacingOccurrences(of: " ", with: "")
        let alts = [partnerName, compactPartner]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return alts.first ?? ""
    }

    private func calculatePolitenessRatio(texts: [String]) -> Double {
        guard !texts.isEmpty else { return 0 }

        let politeCount = texts.reduce(0) { partial, text in
            return partial + (isPoliteSpeech(text) ? 1 : 0)
        }

        return min(1.0, Double(politeCount) / Double(max(texts.count, 1)))
    }

    private func isPoliteSpeech(_ text: String) -> Bool {
        text.contains("です") || text.contains("ます") || text.contains("でした") || text.contains("ました")
    }

    private func buildPunctuationProfile(texts: [String]) -> PunctuationProfile {
        let allText = texts.joined(separator: "\n")
        let totalChars = max(1, allText.count)

        let period = allText.filter { $0 == "。" }.count
        let comma = allText.filter { $0 == "、" }.count
        let exclamation = allText.filter { $0 == "!" || $0 == "！" }.count
        let question = allText.filter { $0 == "?" || $0 == "？" }.count
        let ellipsis = allText.filter { $0 == "…" }.count
        let newlineMessages = texts.filter { $0.contains("\n") }.count

        return PunctuationProfile(
            periodRate: Double(period) / Double(totalChars),
            commaRate: Double(comma) / Double(totalChars),
            exclamationRate: Double(exclamation) / Double(totalChars),
            questionRate: Double(question) / Double(totalChars),
            ellipsisRate: Double(ellipsis) / Double(totalChars),
            newlineRate: Double(newlineMessages) / Double(max(texts.count, 1))
        )
    }

    private func buildEmojiStats(texts: [String]) -> EmojiStats {
        let emojiLists = texts.map(extractEmojis)
        let allEmoji = emojiLists.flatMap { $0 }
        let totalChars = max(1, texts.joined().count)
        let top = Array(countDictionary(values: allEmoji).sorted(by: { $0.value > $1.value }).prefix(5).map(\.key))

        let withEmojiCount = emojiLists.filter { !$0.isEmpty }.count
        let useEmoji = Double(withEmojiCount) / Double(max(texts.count, 1)) >= 0.05

        let endMatches = texts.filter(isEmojiAtEnd).count
        let positionEnd = endMatches >= max(1, texts.count / 4)

        return EmojiStats(
            useEmoji: useEmoji,
            top: top,
            density: Double(allEmoji.count) / Double(totalChars),
            positionEnd: positionEnd
        )
    }

    private func buildSignatureWords(texts: [String]) -> [String] {
        let stopWords: Set<String> = [
            "それ", "これ", "あれ", "こと", "もの", "の", "に", "を", "は", "が", "で", "と", "する", "した", "して",
            "です", "ます", "いる", "ある", "なる", "そう", "ほんと", "まじ", "www"
        ]

        var counts: [String: Int] = [:]
        for text in texts {
            for token in tokenize(text) {
                if token.count < 2 { continue }
                if stopWords.contains(token) { continue }
                counts[token, default: 0] += 1
            }
        }

        return Array(counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.count < rhs.key.count
                }
                return lhs.value > rhs.value
            }
            .prefix(20)
            .map(\.key))
    }

    private func extractEndingToken(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 既知の語尾パターン（長い順にマッチ。suffix(3)フォールバックは
        // 「イル」等の単語断片をノイズとして拾うため廃止）
        let endings = [
            // 3文字
            "だよね", "かもね", "よねー", "だよー", "かなー", "ないー",
            // 2文字（断定・共感系）
            "だよ", "だね", "だな", "だわ", "だぞ",
            // 2文字（不確定・推量系）
            "かも", "かな",
            // 2文字（確認・反語系）
            "じゃん", "っけ",
            // 2文字（関西弁系）
            "やん", "やで", "やな", "やろ",
            // 2文字（伸ばし系）
            "よー", "ねー", "なー", "わー",
            // 2文字（接続系 — 途中切れ検出に利用）
            "のに", "けど",
            // 1文字（助詞系）
            "ね", "よ", "な", "さ", "わ", "ぞ", "ぜ",
            // 1文字（記号・リアクション）
            "！", "!", "？", "?", "笑", "w", "ｗ", "〜", "…",
        ]

        for ending in endings {
            if trimmed.hasSuffix(ending) {
                return ending
            }
        }

        // 既知パターンに一致しない場合はnilを返す
        return nil
    }

    private func detectFirstPersons(in text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "(私|わたし|うち|俺|おれ|ぼく|僕)")
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex?.matches(in: text, range: nsRange) ?? []
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func detectLeadingAddressing(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pattern = "^([ぁ-んァ-ン一-龥A-Za-z0-9ー〜_@]+)([、,\\s])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let tokenRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }

        let token = String(trimmed[tokenRange])
        return token.count >= 2 ? token : nil
    }

    private func detectLaughTokens(in text: String) -> [String] {
        var tokens: [String] = []
        if text.contains("笑") { tokens.append("笑") }
        if text.contains("草") { tokens.append("草") }
        if text.contains("w") { tokens.append("w") }
        if text.contains("ｗ") { tokens.append("w") }
        if text.contains("😂") { tokens.append("😂") }
        return tokens
    }

    private func tokenize(_ text: String) -> [String] {
        let pattern = "[ぁ-んァ-ン一-龥A-Za-z0-9]{2,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)

        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range]).lowercased()
        }
    }

    private func extractEmojis(from text: String) -> [String] {
        text.unicodeScalars.compactMap { scalar in
            if scalar.properties.isEmojiPresentation ||
               (scalar.properties.isEmoji && scalar.value > 0x238C) {
                return String(scalar)
            }
            return nil
        }
    }

    private func countEmoji(in text: String) -> Int {
        extractEmojis(from: text).count
    }

    private func isEmojiAtEnd(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let suffix = String(trimmed.suffix(2))
        return countEmoji(in: suffix) > 0
    }

    private func percentile(lengths: [Int], percentile: Double) -> Int {
        guard !lengths.isEmpty else { return 0 }
        let sorted = lengths.sorted()
        let index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * percentile)))
        return sorted[index]
    }

    private func countDictionary(values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { partial, item in
            partial[item, default: 0] += 1
        }
    }

    private func normalizeCounts(_ counts: [String: Int]) -> [String: Double] {
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [:] }
        return counts.mapValues { Double($0) / Double(total) }
    }

    private func styleDescription(style: StyleDNA) -> String {
        let firstPerson = style.preferredFirstPerson ?? "(不定)"
        let partner = style.preferredAddressing ?? "(不定)"
        let endings = style.endingDistribution
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { "\($0.key):\(String(format: "%.2f", $0.value))" }
            .joined(separator: ", ")

        let emojis = style.emojiTop.prefix(5).joined(separator: " ")
        let signatures = style.signatureWords.prefix(8).joined(separator: ", ")

        return """
        - first_person: \(firstPerson)
        - partner_call: \(partner)
        - polite_ratio: \(String(format: "%.2f", style.politenessRatio))
        - endings: \(endings.isEmpty ? "(なし)" : endings)
        - emoji_use: \(style.emojiUse ? "true" : "false"), top: \(emojis.isEmpty ? "(なし)" : emojis), density: \(String(format: "%.3f", style.emojiDensity)), end_position: \(style.emojiPositionEnd)
        - punctuation(period/comma/excl/question/newline): \(String(format: "%.3f", style.punctuation.periodRate))/\(String(format: "%.3f", style.punctuation.commaRate))/\(String(format: "%.3f", style.punctuation.exclamationRate))/\(String(format: "%.3f", style.punctuation.questionRate))/\(String(format: "%.3f", style.punctuation.newlineRate))
        - length(median/p90): \(style.medianLength)/\(style.p90Length)
        - signature_words: \(signatures.isEmpty ? "(なし)" : signatures)
        """
    }

    // MARK: - Decoder

    private func decodeComposerOutput(from rawText: String) throws -> GeminiReplyPayload {
        let cleaned = sanitizeToJSON(rawText)
        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.parsingFailed
        }

        do {
            let dto = try JSONDecoder().decode(ComposerOutputDTO.self, from: data)
            return composerOutputToPayload(dto)
        } catch {
            throw GeminiError.parsingFailed
        }
    }

    private func composerOutputToPayload(_ dto: ComposerOutputDTO) -> GeminiReplyPayload {
        let candidates = dto.candidates.map { c in
            GeminiReplyCandidate(
                id: c.id,
                label: c.label ?? "案\(c.id)",
                text: c.text,
                simulations: []
            )
        }

        // Gemini が自己言及メタノートを返すことがあるのでフィルタする
        let metaNotePatterns = [
            "文字数制限", "スタイルを遵守", "制限を守", "指示に従",
            "フォーマットに従", "ガイドラインに沿", "条件を満た",
            "修正メモ", "特になし", "なし。"
        ]
        let filteredNotes = (dto.notes ?? []).filter { note in
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return false }
            return !metaNotePatterns.contains { trimmed.contains($0) }
        }

        return GeminiReplyPayload(
            candidates: candidates,
            notes: filteredNotes
        )
    }

    // MARK: - Parsing

    private func sanitizeToJSON(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            trimmed = trimmed
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}") {
            return String(trimmed[firstBrace...lastBrace])
        }

        return trimmed
    }

    // MARK: - Helpers

    private func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

// MARK: - Internal Types

private enum ReplySuggestionServiceError: LocalizedError {
    case missingPrecomputedStyleProfile
    case insufficientTextMessages

    var errorDescription: String? {
        switch self {
        case .missingPrecomputedStyleProfile:
            return "話し方プロファイルが未準備です。先にトーク診断を実行してください。"
        case .insufficientTextMessages:
            return "シミュレーションに必要なテキストメッセージが不足しています。"
        }
    }
}

private struct ReplyConversationBlock {
    let id: String
    let messages: [ChatMessage]
    let start: Date
    let end: Date
    let indexTerms: Set<String>
}

private struct PunctuationProfile {
    let periodRate: Double
    let commaRate: Double
    let exclamationRate: Double
    let questionRate: Double
    let ellipsisRate: Double
    let newlineRate: Double
}

private struct StyleDNA {
    let preferredFirstPerson: String?
    let firstPersonDistribution: [String: Double]
    let preferredAddressing: String?
    let addressingDistribution: [String: Double]
    let endingDistribution: [String: Double]
    let politenessRatio: Double
    let laughDistribution: [String: Double]
    let emojiUse: Bool
    let emojiTop: [String]
    let emojiDensity: Double
    let emojiPositionEnd: Bool
    let punctuation: PunctuationProfile
    let medianLength: Int
    let p90Length: Int
    let signatureWords: [String]
}

private struct SingleTextStyle {
    let endings: [String: Double]
    let punctuation: PunctuationProfile
    let politenessRatio: Double
    let emojis: [String]
    let emojiCount: Int
    let emojiDensity: Double
    let emojiAtEnd: Bool
}

private struct EmojiStats {
    let useEmoji: Bool
    let top: [String]
    let density: Double
    let positionEnd: Bool
}

private struct RewriteTarget {
    let id: String
    let reasons: [String]
}

private struct EvaluationResult {
    let candidates: [ReplyCandidate]
    let rewriteTargets: [RewriteTarget]
}

private struct StyleScoreBreakdown {
    let ending: Double
    let vocabulary: Double
    let emoji: Double
    let punctuation: Double
    let casual: Double
    let length: Double
    let total: Double
}

private struct GeminiReplyPayload {
    var candidates: [GeminiReplyCandidate]
    var notes: [String]
}

private struct GeminiReplyCandidate {
    let id: String
    let label: String
    let text: String
    let simulations: [ReplySimulation]
}

// MARK: - Pipeline Debug Log Models

struct PipelineLogEntry: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    var durationTotal: TimeInterval
    var inputContext: InputContext?
    var preprocessing: Preprocessing?
    var call1: APICallLog?
    var call2a: APICallLog?
    var call2b: APICallLog?
    var hardConstraints: HardConstraintLog?
    var evaluation: EvaluationLog?
    var call25: APICallLog?
    var finalOutput: FinalOutputLog?
    var error: String?

    struct InputContext: Codable {
        let selfName: String
        let partnerName: String
        let messageCount: Int
        let recentMessageCount: Int
        let userGoal: String
        let historyEntryCount: Int
        let recentSnippetPreview: String
        var conversationMode: String = "continueConversation"
    }

    struct Preprocessing: Codable {
        let ragExampleCount: Int
        let styleDNASummary: String
        let personalityContext: String
        let relationshipIntel: String
        let usedBackfill: Bool
        let backfillBlockCount: Int
        let duration: TimeInterval
    }

    struct APICallLog: Codable {
        let stageName: String
        let prompt: String
        let rawResponse: String
        let parsedSummary: String
        let duration: TimeInterval
        var error: String?
    }

    struct HardConstraintLog: Codable {
        let candidatesBefore: [String]
        let candidatesAfter: [String]
        let appliedRules: String
        let duration: TimeInterval
    }

    struct EvaluationLog: Codable {
        let scores: [String]
        let rewriteTargets: [String]
        let duration: TimeInterval
    }

    struct FinalOutputLog: Codable {
        let acceptedCandidates: [String]
        let notes: [String]
        let usedLenientFallback: Bool
        let totalDuration: TimeInterval
    }
}

struct PipelineLogSummary: Identifiable {
    let id: UUID
    let createdAt: Date
    let userGoal: String
    let selfName: String
    let partnerName: String
    let duration: TimeInterval
    let candidateCount: Int
    let hasError: Bool
    let fileURL: URL
}

// MARK: - Pipeline Debug Logger

final class PipelineDebugLogger: @unchecked Sendable {
    static let shared = PipelineDebugLogger()

    private let maxEntries = 30
    private let queue = DispatchQueue(label: "pipelineDebugLogger", qos: .utility)

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Constants.StorageKeys.pipelineDebugEnabled)
    }

    private var logDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("PipelineDebugLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    func save(_ entry: PipelineLogEntry) {
        guard isEnabled else { return }
        queue.async { [self] in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(entry) else { return }

            let fileName = "\(Self.fileFormatter.string(from: entry.createdAt))_\(entry.id.uuidString.prefix(8)).json"
            let fileURL = logDirectory.appendingPathComponent(fileName)
            try? data.write(to: fileURL, options: .atomic)

            pruneIfNeeded()
        }
    }

    func listEntries() -> [PipelineLogSummary] {
        let dir = logDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        ) else { return [] }

        let jsonFiles = files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        return jsonFiles.compactMap { url -> PipelineLogSummary? in
            guard let data = try? Data(contentsOf: url),
                  let entry = try? Self.decoder.decode(PipelineLogEntry.self, from: data) else { return nil }
            return PipelineLogSummary(
                id: entry.id,
                createdAt: entry.createdAt,
                userGoal: entry.inputContext?.userGoal ?? "(unknown)",
                selfName: entry.inputContext?.selfName ?? "",
                partnerName: entry.inputContext?.partnerName ?? "",
                duration: entry.durationTotal,
                candidateCount: entry.finalOutput?.acceptedCandidates.count ?? 0,
                hasError: entry.error != nil,
                fileURL: url
            )
        }
    }

    func loadEntry(from url: URL) -> PipelineLogEntry? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(PipelineLogEntry.self, from: data)
    }

    func deleteAll() {
        queue.async { [self] in
            let dir = logDirectory
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            ) else { return }
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func deleteEntry(at url: URL) {
        queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func pruneIfNeeded() {
        let dir = logDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return }

        let jsonFiles = files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        if jsonFiles.count > maxEntries {
            for file in jsonFiles.dropFirst(maxEntries) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private static let fileFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

// MARK: - Pipeline Log Builder

final class PipelineLogBuilder {
    private let id = UUID()
    private let createdAt = Date()
    private var stageStarts: [String: Date] = [:]

    var inputContext: PipelineLogEntry.InputContext?
    var preprocessing: PipelineLogEntry.Preprocessing?
    var call1: PipelineLogEntry.APICallLog?
    var call2a: PipelineLogEntry.APICallLog?
    var call2b: PipelineLogEntry.APICallLog?
    var hardConstraints: PipelineLogEntry.HardConstraintLog?
    var evaluation: PipelineLogEntry.EvaluationLog?
    var call25: PipelineLogEntry.APICallLog?
    var finalOutput: PipelineLogEntry.FinalOutputLog?
    var error: String?

    func startStage(_ name: String) {
        stageStarts[name] = Date()
    }

    func elapsed(_ name: String) -> TimeInterval {
        guard let start = stageStarts[name] else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func build() -> PipelineLogEntry {
        PipelineLogEntry(
            id: id,
            createdAt: createdAt,
            durationTotal: Date().timeIntervalSince(createdAt),
            inputContext: inputContext,
            preprocessing: preprocessing,
            call1: call1,
            call2a: call2a,
            call2b: call2b,
            hardConstraints: hardConstraints,
            evaluation: evaluation,
            call25: call25,
            finalOutput: finalOutput,
            error: error
        )
    }
}
