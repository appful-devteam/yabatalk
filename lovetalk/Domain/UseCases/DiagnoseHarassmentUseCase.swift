import Foundation

/// LINE トーク（ChatSession）→ ハラスメント診断結果（DiagnosisResult）への変換ユースケース
/// session.effectiveRelationship を全段の Scorer/Resolver/Matcher/Builder に渡すことで、
/// 関係性プリオール (spec §3.5) を一貫して効かせる。
struct DiagnoseHarassmentUseCase: Sendable {

    struct Configuration: Sendable {
        var detectorOptions: FactorDetector.Options = FactorDetector.Options()
    }

    let config: Configuration

    init(config: Configuration = Configuration()) {
        self.config = config
    }

    /// 診断を実行
    func execute(session: ChatSession) -> DiagnosisResult {
        let relationship = session.effectiveRelationship
        // トーク言語で検知辞書を選択（英語チャットは英語ルールで解析）
        let lexicon = DiagnosisLexicon.forLanguage(session.detectedLanguage)

        // 1. 構成要素検出（パターン + 会話構造）
        let detector = FactorDetector(options: config.detectorOptions, lexicon: lexicon)
        var detections = detector.detect(session: session)
        let patternAnalyzer = ConversationPatternAnalyzer(lexicon: lexicon)
        detections.append(contentsOf: patternAnalyzer.analyze(session: session))

        // 2. factor 別スコア（会話全体、関係性 multiplier 適用）
        let factorScorer = FactorScorer()
        let factorScores = factorScorer.score(detections: detections, relationship: relationship)

        // 3. 4 分類スコア（factor が補正済みなのでカテゴリも自動補正）
        let categoryScorer = CategoryScorer(lexicon: lexicon)
        let categoryScores = categoryScorer.categoryScores(factors: factorScores)

        // 4. 主分類・補助分類（関係性で優先ルール変動）
        let resolver = PriorityResolver()
        let decision = resolver.resolve(
            categoryScores: categoryScores,
            factors: factorScores,
            relationship: relationship
        )

        // 5. 総合スコア（強制補正後）
        let overallScore = categoryScorer.overallScore(
            categoryScores: categoryScores,
            factors: factorScores
        )
        let riskLevel = RiskLevel.from(score: overallScore)
        let dangerLabel = pickDangerLabel(level: riskLevel, primary: decision.primary)

        // 6. タイプ照合（関係性でタイプ候補をフィルタ）
        let matcher = TypeMatcher()
        let typeSelection = matcher.match(
            primaryCategory: decision.primary,
            secondaryCategories: decision.secondary,
            subCategories: decision.subCategories,
            factors: factorScores,
            relationship: relationship
        )

        // 7. 毒見アウトプット（関係性で呼称・口調・next steps を補正）
        let builder = OutputBuilder()
        let bundle = builder.build(
            session: session,
            overallScore: overallScore,
            primaryType: typeSelection.primary,
            primaryCategory: decision.primary,
            secondaryCategories: decision.secondary,
            subCategories: decision.subCategories,
            categoryScores: categoryScores,
            factors: factorScores,
            decisionRationale: decision.rationale,
            relationship: relationship
        )

        // 8. 話者別の独立判定（A: per-speaker typing、こちらも関係性適用）
        let speakerVerdicts = buildSpeakerVerdicts(
            session: session,
            allDetections: detections,
            factorScorer: factorScorer,
            categoryScorer: categoryScorer,
            resolver: resolver,
            matcher: matcher,
            relationship: relationship
        )

        // 9. データタブ用の詳細統計を診断と同じバックグラウンドで先に計算しておく
        //    （結果画面で開いた瞬間に再計算して重くなるのを防ぐ）。
        let selfName = session.estimatedSelfName ?? ""
        let partnerName = session.partnerName(selfName: selfName) ?? ""
        let detailedStatistics = DetailedStatisticsAnalyzer().analyze(
            messages: session.messages,
            selfName: selfName,
            partnerName: partnerName,
            allParticipantNames: session.participants.map(\.name)
        )

        return DiagnosisResult(
            sessionId: session.id,
            sessionTitle: session.title,
            overallRiskScore: overallScore,
            riskLevel: riskLevel,
            dangerLabel: dangerLabel,
            summary: bundle.summary,
            primaryType: typeSelection.primary,
            secondaryTypes: typeSelection.secondary,
            catchCopy: bundle.catchCopy,
            categoryScores: categoryScores,
            primaryCategory: decision.primary,
            secondaryCategories: decision.secondary,
            subCategories: decision.subCategories,
            factorScores: factorScores,
            logicExplanation: bundle.logicExplanation,
            logicParagraphs: bundle.logicParagraphs,
            categoryBreakdowns: bundle.categoryBreakdowns,
            factorDeepDives: bundle.factorDeepDives,
            redFlagAmplifiers: bundle.redFlagAmplifiers,
            stats: bundle.stats,
            speakerVerdicts: speakerVerdicts,
            quotedEvidences: bundle.quotedEvidences,
            darkHumorAdvice: bundle.darkHumorAdvice,
            nextSteps: bundle.nextSteps,
            detailedStatistics: detailedStatistics
        )
    }

    // MARK: - Per-speaker pipeline

    private func buildSpeakerVerdicts(
        session: ChatSession,
        allDetections: [FactorDetection],
        factorScorer: FactorScorer,
        categoryScorer: CategoryScorer,
        resolver: PriorityResolver,
        matcher: TypeMatcher,
        relationship: RelationshipContext
    ) -> [SpeakerVerdict] {
        let detectionsBySpeaker = Dictionary(grouping: allDetections) { $0.speakerName }
        let textCountsBySpeaker = Dictionary(
            grouping: session.messages.filter { $0.eventType.isTextBased }
        ) { $0.senderName }.mapValues { $0.count }

        var verdicts: [SpeakerVerdict] = []
        for participant in session.participants {
            let dets = detectionsBySpeaker[participant.name] ?? []
            // テキスト発言が極端に少ない参加者はスキップ（システム連携系など）
            let textCount = textCountsBySpeaker[participant.name] ?? 0
            if textCount < 3 && dets.isEmpty { continue }

            let speakerFactors = factorScorer.score(detections: dets, relationship: relationship)
            let speakerCategoryScores = categoryScorer.categoryScores(factors: speakerFactors)
            let speakerDecision = resolver.resolve(
                categoryScores: speakerCategoryScores,
                factors: speakerFactors,
                relationship: relationship
            )
            let speakerOverall = categoryScorer.overallScore(
                categoryScores: speakerCategoryScores,
                factors: speakerFactors
            )
            let speakerLevel = RiskLevel.from(score: speakerOverall)
            let speakerType = matcher.match(
                primaryCategory: speakerDecision.primary,
                secondaryCategories: speakerDecision.secondary,
                subCategories: speakerDecision.subCategories,
                factors: speakerFactors,
                relationship: relationship
            )

            let topFactors = Array(speakerFactors.prefix(4))
            let topDetection = dets.max { $0.severity.weightMultiplier < $1.severity.weightMultiplier }
            let topQuote: QuotedEvidence? = topDetection.map { det in
                QuotedEvidence(
                    quote: det.evidence,
                    explanation: det.factor.explanationTemplate(),
                    factor: det.factor,
                    speakerName: det.speakerName,
                    timestamp: det.timestamp
                )
            }

            let categoryLabel: String = {
                if speakerDecision.primary == .other,
                   let first = speakerDecision.subCategories.first {
                    return "\(first.displayName)\(first.trailingSuffix)"
                }
                return speakerDecision.primary.shortName
            }()
            let oneLine: String
            if topFactors.isEmpty {
                oneLine = String(localized: "目立ったヤバ要素は検出されず。今のところ平和ライン。", bundle: LanguageManager.appBundle)
            } else {
                let names = topFactors.prefix(2).map { $0.factor.displayName }
                let flavors = names.count >= 2
                    ? String(format: String(localized: "「%1$@」と「%2$@」", bundle: LanguageManager.appBundle), names[0], names[1])
                    : String(format: String(localized: "「%1$@」", bundle: LanguageManager.appBundle), names[0])
                oneLine = String(format: String(localized: "%1$@寄り。主な持ち味は%2$@。", bundle: LanguageManager.appBundle), categoryLabel, flavors)
            }

            let signatures = buildSignaturePhrases(detections: dets)

            verdicts.append(
                SpeakerVerdict(
                    speakerName: participant.name,
                    score: speakerOverall,
                    level: speakerLevel,
                    dangerLabel: pickDangerLabel(level: speakerLevel, primary: speakerDecision.primary),
                    primaryCategory: speakerDecision.primary,
                    secondaryCategories: speakerDecision.secondary,
                    subCategories: speakerDecision.subCategories,
                    categoryScores: speakerCategoryScores,
                    primaryType: speakerType.primary,
                    catchCopy: pickCatchCopy(type: speakerType.primary, level: speakerLevel),
                    topFactors: topFactors,
                    oneLineVerdict: oneLine,
                    signaturePhrases: signatures,
                    topQuote: topQuote
                )
            )
        }
        return verdicts.sorted { $0.score > $1.score }
    }

    /// 話者の口癖を集計（D: phrase signature）。
    /// 検出されたパターン (matchedPattern) を「言葉」として頻度集計し、上位 5 件を返す。
    private func buildSignaturePhrases(detections: [FactorDetection]) -> [PhraseSignature] {
        var counts: [String: (count: Int, factor: HarassmentFactor)] = [:]
        for det in detections {
            let key = det.matchedPattern.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, key.count <= 12 else { continue }
            if var existing = counts[key] {
                existing.count += 1
                counts[key] = existing
            } else {
                counts[key] = (1, det.factor)
            }
        }
        return counts
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .map { PhraseSignature(phrase: $0.key, count: $0.value.count, factor: $0.value.factor) }
    }

    private func pickCatchCopy(type: HarassmentType, level: RiskLevel) -> String {
        guard !type.catchCopyTemplates.isEmpty else { return type.structureSummary }
        let seed = abs(type.id.hashValue &+ level.hashValue)
        return type.catchCopyTemplates[seed % type.catchCopyTemplates.count]
    }

    /// 危険度ラベルは候補から決定論的に 1 つ選ぶ（セッション ID 等で安定化）
    private func pickDangerLabel(level: RiskLevel, primary: HarassmentCategory) -> String {
        let candidates = level.dangerLabelCandidates
        guard !candidates.isEmpty else { return level.displayName }
        let seed = abs(primary.hashValue &+ level.hashValue)
        return candidates[seed % candidates.count]
    }
}
