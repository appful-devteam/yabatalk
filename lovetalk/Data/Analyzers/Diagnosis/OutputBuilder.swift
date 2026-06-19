import Foundation

/// 毒見アウトプット（summary / catchCopy / logicExplanation / quotedEvidences / 深掘りセクション）を組み立てる
struct OutputBuilder: Sendable {

    struct Bundle: Sendable {
        let summary: String
        let catchCopy: String
        let logicExplanation: String
        let logicParagraphs: [String]
        let categoryBreakdowns: [CategoryBreakdown]
        let factorDeepDives: [FactorDeepDive]
        let redFlagAmplifiers: [RedFlagAmplifier]
        let stats: DiagnosisStats
        let quotedEvidences: [QuotedEvidence]
        let darkHumorAdvice: String
        let nextSteps: [String]
    }

    /// 関係性なしの後方互換 API。
    func build(
        session: ChatSession,
        overallScore: Int,
        primaryType: HarassmentType,
        primaryCategory: HarassmentCategory,
        secondaryCategories: [HarassmentCategory],
        subCategories: [HarassmentSubCategory],
        categoryScores: [HarassmentCategory: Int],
        factors: [FactorScore],
        decisionRationale: String
    ) -> Bundle {
        build(
            session: session,
            overallScore: overallScore,
            primaryType: primaryType,
            primaryCategory: primaryCategory,
            secondaryCategories: secondaryCategories,
            subCategories: subCategories,
            categoryScores: categoryScores,
            factors: factors,
            decisionRationale: decisionRationale,
            relationship: .unknown
        )
    }

    func build(
        session: ChatSession,
        overallScore: Int,
        primaryType: HarassmentType,
        primaryCategory: HarassmentCategory,
        secondaryCategories: [HarassmentCategory],
        subCategories: [HarassmentSubCategory],
        categoryScores: [HarassmentCategory: Int],
        factors: [FactorScore],
        decisionRationale: String,
        relationship: RelationshipContext
    ) -> Bundle {
        let level = RiskLevel.from(score: overallScore)
        let redFlags = makeRedFlagAmplifiers(factors: factors)
        let stats = makeStats(session: session, factors: factors)

        let summary = makeSummary(
            level: level,
            primary: primaryCategory,
            secondary: secondaryCategories,
            subs: subCategories,
            decisionRationale: decisionRationale,
            relationship: relationship
        )
        let catchCopy = makeCatchCopy(type: primaryType, level: level)
        let quotes = makeQuotedEvidences(factors: factors, primaryCategory: primaryCategory, limit: 20)
        let paragraphs = makeLogicParagraphs(
            overallScore: overallScore,
            level: level,
            factors: factors,
            primaryCategory: primaryCategory,
            secondaryCategories: secondaryCategories,
            subCategories: subCategories,
            redFlags: redFlags,
            quoteCount: quotes.count,
            stats: stats,
            relationship: relationship
        )
        let logic = paragraphs.joined(separator: "\n\n")
        let breakdowns = makeCategoryBreakdowns(
            categoryScores: categoryScores,
            factors: factors,
            primaryCategory: primaryCategory,
            subCategories: subCategories
        )
        let deepDives = makeFactorDeepDives(factors: factors)
        let nextSteps = makeNextSteps(
            level: level,
            primary: primaryCategory,
            redFlagCount: redFlags.count,
            relationship: relationship
        )

        return Bundle(
            summary: summary,
            catchCopy: catchCopy,
            logicExplanation: logic,
            logicParagraphs: paragraphs,
            categoryBreakdowns: breakdowns,
            factorDeepDives: deepDives,
            redFlagAmplifiers: redFlags,
            stats: stats,
            quotedEvidences: quotes,
            darkHumorAdvice: primaryType.darkHumorAdvice,
            nextSteps: nextSteps
        )
    }

    // MARK: - Summary

    private func makeSummary(
        level: RiskLevel,
        primary: HarassmentCategory,
        secondary: [HarassmentCategory],
        subs: [HarassmentSubCategory],
        decisionRationale: String,
        relationship: RelationshipContext
    ) -> String {
        let categoryLabel: String = {
            if primary == .other, let first = subs.first {
                return String(
                    format: String(localized: "%1$@%2$@", bundle: LanguageManager.appBundle),
                    first.displayName, first.trailingSuffix
                )
            }
            var s = primary.shortName
            if !secondary.isEmpty {
                s += " × " + secondary.map(\.shortName).joined(separator: " × ")
            }
            return s
        }()
        let relationPrefix: String = relationship == .unknown ? "" : String(
            format: String(localized: "%1$@視点で見ると、", bundle: LanguageManager.appBundle),
            relationship.shortName
        )
        let levelTone: String
        switch level {
        case .low:
            return String(
                format: String(localized: "%1$@%2$@ っぽさがほんのり。今のところ平和ライン。", bundle: LanguageManager.appBundle),
                relationPrefix, categoryLabel
            )
        case .caution: levelTone = String(localized: "ちょっと注意", bundle: LanguageManager.appBundle)
        case .medium: levelTone = String(localized: "中辛", bundle: LanguageManager.appBundle)
        case .high: levelTone = String(localized: "けっこうヤバい", bundle: LanguageManager.appBundle)
        case .severe: levelTone = String(localized: "ヤバ度 MAX", bundle: LanguageManager.appBundle)
        }
        return String(
            format: String(localized: "%1$@%2$@ 系の傾向が「%3$@」レベルで検出。", bundle: LanguageManager.appBundle),
            relationPrefix, categoryLabel, levelTone
        )
    }

    // MARK: - Catch Copy

    private func makeCatchCopy(type: HarassmentType, level: RiskLevel) -> String {
        guard !type.catchCopyTemplates.isEmpty else { return type.structureSummary }
        let seed = abs(type.id.hashValue &+ level.hashValue)
        let index = seed % type.catchCopyTemplates.count
        return type.catchCopyTemplates[index]
    }

    // MARK: - Quoted Evidence

    private func makeQuotedEvidences(
        factors: [FactorScore],
        primaryCategory: HarassmentCategory,
        limit: Int
    ) -> [QuotedEvidence] {
        let priorityFactors = priorityFactorOrder(for: primaryCategory)
        let scoredByFactor = Dictionary(uniqueKeysWithValues: factors.map { ($0.factor, $0) })

        var picked: [QuotedEvidence] = []
        var seenMessageIds = Set<UUID>()

        // 主分類関連 factor: 1 factor から最大 2 件
        for factor in priorityFactors {
            guard let fs = scoredByFactor[factor] else { continue }
            var perFactorPicked = 0
            for det in fs.detections {
                guard !seenMessageIds.contains(det.messageId) else { continue }
                picked.append(
                    QuotedEvidence(
                        quote: det.evidence,
                        explanation: factor.explanationTemplate(),
                        factor: factor,
                        speakerName: det.speakerName,
                        timestamp: det.timestamp
                    )
                )
                seenMessageIds.insert(det.messageId)
                perFactorPicked += 1
                if perFactorPicked >= 2 { break }
                if picked.count >= limit { break }
            }
            if picked.count >= limit { break }
        }
        // 残り枠を score 上位 factor から
        for fs in factors {
            if picked.count >= limit { break }
            for det in fs.detections {
                guard !seenMessageIds.contains(det.messageId) else { continue }
                picked.append(
                    QuotedEvidence(
                        quote: det.evidence,
                        explanation: fs.factor.explanationTemplate(),
                        factor: fs.factor,
                        speakerName: det.speakerName,
                        timestamp: det.timestamp
                    )
                )
                seenMessageIds.insert(det.messageId)
                if picked.count >= limit { break }
            }
        }
        return picked
    }

    private func priorityFactorOrder(for category: HarassmentCategory) -> [HarassmentFactor] {
        switch category {
        case .power:
            return [.personalityDenial, .disadvantageThreat, .existenceDenial, .refusalImpossible,
                    .excessiveDemand, .abilityDenial, .dominance, .workEvaluation, .groupExclusion]
        case .sexual:
            return [.quotaPairing, .sexualContext, .boundaryViolation, .refusalImpossible,
                    .mockingLaughter, .persistentRepetition, .disadvantageThreat]
        case .moral:
            return [.guiltManipulation, .gaslighting, .monitoringControl, .intimateRelationship,
                    .refusalImpossible, .boundaryViolation, .personalityDenial]
        case .other:
            return [.roleStereotype, .maternityPenalty, .academicPower, .customerAggression,
                    .alcoholCoercion, .privacyIntrusion, .groupExclusion, .monitoringControl]
        }
    }

    // MARK: - Logic Paragraphs (multi-paragraph narrative)

    private func makeLogicParagraphs(
        overallScore: Int,
        level: RiskLevel,
        factors: [FactorScore],
        primaryCategory: HarassmentCategory,
        secondaryCategories: [HarassmentCategory],
        subCategories: [HarassmentSubCategory],
        redFlags: [RedFlagAmplifier],
        quoteCount: Int,
        stats: DiagnosisStats,
        relationship: RelationshipContext
    ) -> [String] {
        var paragraphs: [String] = []

        let categoryLabel: String = {
            if primaryCategory == .other, let first = subCategories.first {
                return String(
                    format: String(localized: "%1$@%2$@", bundle: LanguageManager.appBundle),
                    first.displayName, first.trailingSuffix
                )
            }
            return primaryCategory.displayName
        }()

        // P0: 関係性プリオールの宣言（unknown 以外）
        if relationship != .unknown {
            paragraphs.append(String(
                format: String(localized: "今回は「%1$@」前提で読みます。%2$@", bundle: LanguageManager.appBundle),
                relationship.displayName, relationship.openingFlavor
            ))
        }

        // P1: 占い的オープニング（呼称を関係性化）
        let scopedSubject = relationship == .unknown ? String(localized: "相手", bundle: LanguageManager.appBundle) : relationship.partnerNoun
        paragraphs.append(String(
            format: String(localized: "今回のトークから読み取れる%1$@の傾向は、ずばり「%2$@」寄り。やばさは%3$lld%% で「%4$@」レベル。", bundle: LanguageManager.appBundle),
            scopedSubject, categoryLabel, overallScore, level.displayName
        ) + flavor(for: level))

        // P2: 主成分
        let topFactors = factors.prefix(3)
        if !topFactors.isEmpty {
            let parts = topFactors.map { String(format: String(localized: "「%1$@」", bundle: LanguageManager.appBundle), $0.factor.displayName) }
            let keyFactorPart = parts.joined(separator: "・")
            paragraphs.append(String(
                format: String(localized: "中心にあるのは %1$@ の組み合わせ。", bundle: LanguageManager.appBundle),
                keyFactorPart
            ) + structuralComment(for: primaryCategory))
        }

        // P3: 補助分類
        if !secondaryCategories.isEmpty {
            let secondaryLabel = secondaryCategories.map(\.shortName).joined(separator: String(localized: " と ", bundle: LanguageManager.appBundle))
            paragraphs.append(String(
                format: String(localized: "これに %1$@ っぽい要素も混ざっていて、一筋縄ではいかないタイプです。", bundle: LanguageManager.appBundle),
                secondaryLabel
            ))
        } else if primaryCategory == .other, subCategories.count > 1 {
            let subLabels = subCategories.prefix(3).map { "\($0.displayName)" }.joined(separator: " / ")
            paragraphs.append(String(
                format: String(localized: "その他系では %1$@ の傾向も同時に出ています。", bundle: LanguageManager.appBundle),
                subLabels
            ))
        }

        // P4: 密度
        if stats.totalTextMessages > 0 {
            let densitySentence: String
            if stats.detectionRatePercent >= 30 {
                densitySentence = String(
                    format: String(localized: "テキスト %1$lld 件中 %2$lld%% にヤバ成分が乗っているので、特定の瞬間というより、トーク全体に染み込んでいるイメージです。", bundle: LanguageManager.appBundle),
                    stats.totalTextMessages, stats.detectionRatePercent
                )
            } else if stats.detectionRatePercent >= 10 {
                densitySentence = String(
                    format: String(localized: "テキスト %1$lld 件中 %2$lld%% にヤバ成分。発火ポイントは局所的ですが、刺さる時はちゃんと刺さってます。", bundle: LanguageManager.appBundle),
                    stats.totalTextMessages, stats.detectionRatePercent
                )
            } else {
                densitySentence = String(
                    format: String(localized: "テキスト %1$lld 件中 %2$lld%%。割合は少なめですが、出る時はピンポイントで濃いです。", bundle: LanguageManager.appBundle),
                    stats.totalTextMessages, stats.detectionRatePercent
                )
            }
            paragraphs.append(densitySentence)
        }

        if stats.nightDetectionCount >= 3 {
            paragraphs.append(String(
                format: String(localized: "ちなみに夜の 22 時〜朝 5 時帯で %1$lld 件の検出。深夜にテンション上がるとヤバ濃度がブーストするタイプかもしれません。", bundle: LanguageManager.appBundle),
                stats.nightDetectionCount
            ))
        }

        return paragraphs
    }

    private func flavor(for level: RiskLevel) -> String {
        switch level {
        case .low: return String(localized: "今のところ、笑い話で済む範囲です。", bundle: LanguageManager.appBundle)
        case .caution: return String(localized: "ちょっと「ん？」が混じってきた、注意マーク点灯フェーズ。", bundle: LanguageManager.appBundle)
        case .medium: return String(localized: "そろそろ友達にスクショを見せたくなる中辛レベル。", bundle: LanguageManager.appBundle)
        case .high: return String(localized: "これは普通に「ヤバくない？」案件、香ばしさ高め。", bundle: LanguageManager.appBundle)
        case .severe: return String(localized: "もう全部やばい、保存ボタン即押し案件です。", bundle: LanguageManager.appBundle)
        }
    }

    private func structuralComment(for category: HarassmentCategory) -> String {
        switch category {
        case .power:
            return String(localized: "立場・評価・仕事を背景にした圧が主な持ち味。", bundle: LanguageManager.appBundle)
        case .sexual:
            return String(localized: "性的・恋愛的な距離感がバグっている瞬間が中心。", bundle: LanguageManager.appBundle)
        case .moral:
            return String(localized: "親密関係を盾にした心理サンドバッグ構造。", bundle: LanguageManager.appBundle)
        case .other:
            return String(localized: "属性押しつけ・制度乱用・プライベート侵略あたりが断片的に。", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - Category Breakdown

    private func makeCategoryBreakdowns(
        categoryScores: [HarassmentCategory: Int],
        factors: [FactorScore],
        primaryCategory: HarassmentCategory,
        subCategories: [HarassmentSubCategory]
    ) -> [CategoryBreakdown] {
        var out: [CategoryBreakdown] = []
        for category in HarassmentCategory.allCases {
            let score = categoryScores[category] ?? 0
            guard score > 0 else { continue }
            let level = RiskLevel.from(score: score)
            let priority = priorityFactorOrder(for: category)
            let priorityScored = priority.compactMap { f -> FactorScore? in
                factors.first { $0.factor == f && $0.score > 0 }
            }
            // 上位 4 件
            let contributing = Array(priorityScored.sorted { $0.score > $1.score }.prefix(4))

            let narrative = makeCategoryNarrative(
                category: category,
                score: score,
                level: level,
                contributing: contributing,
                isPrimary: category == primaryCategory,
                subCategories: category == .other ? subCategories : []
            )
            out.append(
                CategoryBreakdown(
                    category: category,
                    score: score,
                    level: level,
                    contributingFactors: contributing,
                    narrative: narrative
                )
            )
        }
        return out.sorted { $0.score > $1.score }
    }

    private func makeCategoryNarrative(
        category: HarassmentCategory,
        score: Int,
        level: RiskLevel,
        contributing: [FactorScore],
        isPrimary: Bool,
        subCategories: [HarassmentSubCategory]
    ) -> String {
        var sentences: [String] = []
        let prefix = isPrimary ? String(localized: "メインの傾向はここ。", bundle: LanguageManager.appBundle) : ""
        sentences.append(String(
            format: String(localized: "%1$@スコアは %2$lld%%（%3$@）。", bundle: LanguageManager.appBundle),
            prefix, score, level.displayName
        ))

        if contributing.isEmpty {
            sentences.append(String(localized: "濃いめの要素は出てないけど、ふんわり関連ワードが顔を出してる感じ。", bundle: LanguageManager.appBundle))
        } else {
            let factorNames = contributing.map {
                String(
                    format: String(localized: "「%1$@」(%2$lld%%)", bundle: LanguageManager.appBundle),
                    $0.factor.displayName, $0.score
                )
            }.joined(separator: "、")
            sentences.append(String(
                format: String(localized: "メインで効いてるのは %1$@ あたり。", bundle: LanguageManager.appBundle),
                factorNames
            ))
            sentences.append(categoryStructureExplanation(category: category, contributing: contributing))
        }

        if category == .other, !subCategories.isEmpty {
            let subLabels = subCategories.prefix(3).map { "\($0.displayName)" }.joined(separator: " / ")
            sentences.append(String(
                format: String(localized: "サブで混ざってるのは %1$@ 系。", bundle: LanguageManager.appBundle),
                subLabels
            ))
        }

        return sentences.joined(separator: " ")
    }

    private func categoryStructureExplanation(category: HarassmentCategory, contributing: [FactorScore]) -> String {
        let factorSet = Set(contributing.map(\.factor))
        switch category {
        case .power:
            if factorSet.contains(.dominance) && factorSet.contains(.disadvantageThreat) {
                return String(localized: "立場の差を後ろに、評価とか処遇のチラつかせがセットで出てるタイプ。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.personalityDenial) || factorSet.contains(.abilityDenial) {
                return String(localized: "指導っぽい流れに乗せて、人格や能力ごとパスしちゃってるかも。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.excessiveDemand) {
                return String(localized: "業務の枠を超える要求が、ちょっと常態化ぎみなパターン。", bundle: LanguageManager.appBundle)
            }
            return String(localized: "評価・仕事の話と立場差の組み合わせが軸になってる感じ。", bundle: LanguageManager.appBundle)
        case .sexual:
            if factorSet.contains(.quotaPairing) {
                return String(localized: "色恋っぽい話と評価・仕事がくっついてる、典型的に注意マークなやつ。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.boundaryViolation) {
                return String(localized: "「やめて」「嫌」のあとも同じノリが続いてて、境界線が結構ふんわり。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.persistentRepetition) {
                return String(localized: "繰り返しの誘いや連絡が多めで、断りにくさを上手く使っちゃってる感じ。", bundle: LanguageManager.appBundle)
            }
            return String(localized: "距離感バグ × 断りにくさのコンボがメイン。", bundle: LanguageManager.appBundle)
        case .moral:
            if factorSet.contains(.guiltManipulation) && factorSet.contains(.intimateRelationship) {
                return String(localized: "関係性を盾にした罪悪感投げが中心の組み立て。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.gaslighting) {
                return String(localized: "「そんなこと言ってない」系で記憶を上書きしてくるムードあり。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.monitoringControl) {
                return String(localized: "返信や行動の追跡みがクセになってる感じ。", bundle: LanguageManager.appBundle)
            }
            return String(localized: "親密関係の裏で、心理的にじわっと押してくる組み立て。", bundle: LanguageManager.appBundle)
        case .other:
            if factorSet.contains(.roleStereotype) {
                return String(localized: "「女だから」「男なら」みたいな役割押しつけがチラつく感じ。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.privacyIntrusion) {
                return String(localized: "プライベートへの踏み込みが、ちょっと多めかも。", bundle: LanguageManager.appBundle)
            }
            if factorSet.contains(.groupExclusion) {
                return String(localized: "「あいつは入れない」みたいなハブり方向の動きが混ざってます。", bundle: LanguageManager.appBundle)
            }
            return String(localized: "属性押しつけ・制度ハック・プライベート踏み込みあたりが、ちょこちょこ顔を出してる感じ。", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - Factor Deep Dives

    private func makeFactorDeepDives(factors: [FactorScore]) -> [FactorDeepDive] {
        let detected = factors.filter { $0.score > 0 }.sorted { $0.score > $1.score }
        return detected.prefix(15).map { fs -> FactorDeepDive in
            let samples = pickEvidenceSamples(from: fs.detections, max: 5)
            return FactorDeepDive(
                factor: fs.factor,
                score: fs.score,
                severity: fs.topSeverity,
                detectionCount: fs.detections.count,
                title: fs.factor.displayName,
                detail: deepDiveDetail(for: fs.factor, count: fs.detections.count, severity: fs.topSeverity),
                sampleEvidences: samples
            )
        }
    }

    /// 重複・近似テキストを避けつつ severity 高い順に最大 `max` 件サンプル抽出
    private func pickEvidenceSamples(from detections: [FactorDetection], max: Int) -> [FactorEvidenceSample] {
        let sorted = detections.sorted { lhs, rhs in
            if lhs.severity.weightMultiplier != rhs.severity.weightMultiplier {
                return lhs.severity.weightMultiplier > rhs.severity.weightMultiplier
            }
            return lhs.evidence.count > rhs.evidence.count
        }
        var picked: [FactorEvidenceSample] = []
        var seen: Set<String> = []
        for det in sorted {
            let evidence = det.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !evidence.isEmpty else { continue }
            let normalized = normalizeForDedup(evidence)
            if seen.contains(normalized) { continue }
            seen.insert(normalized)
            picked.append(
                FactorEvidenceSample(
                    speaker: det.speakerName,
                    text: evidence,
                    timestamp: det.timestamp
                )
            )
            if picked.count >= max { break }
        }
        return picked
    }

    private func normalizeForDedup(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let prefix = lowered.prefix(30)
        return String(prefix)
    }

    private func deepDiveDetail(for factor: HarassmentFactor, count: Int, severity: FactorSeverity) -> String {
        let base = factor.explanationTemplate()
        let countPart: String
        switch count {
        case 1:
            countPart = String(localized: "今回はサクッと 1 件ヒット。", bundle: LanguageManager.appBundle)
        case 2...4:
            countPart = String(format: String(localized: "今回 %1$lld 件。たまーに顔を出すクセみたいな感じ。", bundle: LanguageManager.appBundle), count)
        case 5...9:
            countPart = String(format: String(localized: "今回 %1$lld 件。これくらいだと結構口グセ寄りかも。", bundle: LanguageManager.appBundle), count)
        default:
            countPart = String(format: String(localized: "今回 %1$lld 件。ここまで来ると完全に持ちネタです。", bundle: LanguageManager.appBundle), count)
        }
        let severityPart: String
        switch severity {
        case .low: severityPart = String(localized: "1 発の威力はやさしめだけど、積み重なるとボディブローみたいに効きます。", bundle: LanguageManager.appBundle)
        case .medium: severityPart = String(localized: "威力は中くらい。シチュ次第で結構刺さるやつ。", bundle: LanguageManager.appBundle)
        case .high: severityPart = String(localized: "1 発で「うわ…」ってなる強めパンチタイプ。", bundle: LanguageManager.appBundle)
        }
        let extra = factorAdditionalContext(for: factor)
        return [base, countPart, severityPart, extra].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func factorAdditionalContext(for factor: HarassmentFactor) -> String {
        switch factor {
        case .personalityDenial:
            return String(localized: "「ここ直そう」じゃなく「人としてどうなの」って言われると、いやいや…ってなりがち。", bundle: LanguageManager.appBundle)
        case .disadvantageThreat:
            return String(localized: "「やらないと損するよ」って匂わせ、選んだ気にさせて実は逃げ道をふさぐタイプの圧かも。", bundle: LanguageManager.appBundle)
        case .quotaPairing:
            return String(localized: "色恋と評価がセットで出てくるパターン。これは「対価型セクハラ」っぽい組み合わせなので、要注意マーク強め。", bundle: LanguageManager.appBundle)
        case .boundaryViolation:
            return String(localized: "「やめて」「嫌」って言ったあとに同じノリが続くのは、結構わかりやすい NG サイン。", bundle: LanguageManager.appBundle)
        case .gaslighting:
            return String(localized: "「そんなこと言ってない」「気のせい」で記憶を上書きしようとするのは、こっちの感覚を弱らせるやつ。じわじわ効きます。", bundle: LanguageManager.appBundle)
        case .monitoringControl:
            return String(localized: "返信や位置情報の追跡みは、対等な距離感がちょっと崩れがちなサイン。", bundle: LanguageManager.appBundle)
        case .guiltManipulation:
            return String(localized: "「私の気持ち、あなたのせい」式は、ちょっとずつ罪悪感を貯金させてくる仕組み。優しい人ほど効きます。", bundle: LanguageManager.appBundle)
        case .excessiveDemand:
            return String(localized: "深夜・休日対応とか物理的にムリな締切は、相手の体力前提が抜けちゃってるパターン。", bundle: LanguageManager.appBundle)
        case .persistentRepetition:
            return String(localized: "短時間にバババッと連投する追い打ちは、相手の「断るタイミング」を奪うやつ。", bundle: LanguageManager.appBundle)
        case .roleStereotype:
            return String(localized: "「女らしさ」「男なら」って属性で人を扱うのは、結構レトロな価値観の押しつけかも。", bundle: LanguageManager.appBundle)
        case .maternityPenalty:
            return String(localized: "妊娠・育児・介護を理由に冷たくするのは、ライフイベント側を踏みつけるムードがあります。", bundle: LanguageManager.appBundle)
        case .academicPower:
            return String(localized: "成績・推薦・卒業をチラつかせる圧は、いわゆる「アカハラ」寄りの出方。", bundle: LanguageManager.appBundle)
        case .alcoholCoercion:
            return String(localized: "「飲もうよ」「飲まないの？」が強気めだと、体質や宗教や好みを無視しがち。", bundle: LanguageManager.appBundle)
        case .customerAggression:
            return String(localized: "客・取引先の立場で押してくるパターンは、いわゆる「カスハラ」寄りの出方。", bundle: LanguageManager.appBundle)
        default:
            return ""
        }
    }

    // MARK: - Red Flag Amplifiers (docs §4-3)

    private func makeRedFlagAmplifiers(factors: [FactorScore]) -> [RedFlagAmplifier] {
        let lookup = Dictionary(uniqueKeysWithValues: factors.map { ($0.factor, $0) })
        func score(_ factor: HarassmentFactor) -> Int { lookup[factor]?.score ?? 0 }
        func sample(_ factor: HarassmentFactor) -> String? {
            lookup[factor]?.detections.max { $0.severity.weightMultiplier < $1.severity.weightMultiplier }?.evidence
        }

        var flags: [RedFlagAmplifier] = []

        // 性的要求 + 評価/仕事/成績/シフト
        if score(.quotaPairing) >= 15 {
            flags.append(RedFlagAmplifier(
                title: String(localized: "性的・恋愛的要求と評価/仕事の結合", bundle: LanguageManager.appBundle),
                description: String(localized: "色恋の話と評価・仕事が同じ流れに乗っちゃってるパターン。これは結構ハッキリ赤信号、注意マーク強めです。", bundle: LanguageManager.appBundle),
                evidence: sample(.quotaPairing) ?? sample(.sexualContext)
            ))
        }

        // 不利益示唆
        if score(.disadvantageThreat) >= 25 {
            flags.append(RedFlagAmplifier(
                title: String(localized: "不利益示唆（脅し）", bundle: LanguageManager.appBundle),
                description: String(localized: "クビ・評価下げ・シフト減・別れ・晒し…みたいに「やらないと損するよ」って匂わせるやつ。選んだ気にさせて実は逃げ場をふさぐタイプ。", bundle: LanguageManager.appBundle),
                evidence: sample(.disadvantageThreat)
            ))
        }

        // 存在否定
        if score(.existenceDenial) >= 20 {
            flags.append(RedFlagAmplifier(
                title: String(localized: "存在・所属の否定", bundle: LanguageManager.appBundle),
                description: String(localized: "「来なくていい」「消えろ」「いらない」みたいに、居場所そのものを取り上げる言い方。これはマジで効いちゃう系。", bundle: LanguageManager.appBundle),
                evidence: sample(.existenceDenial)
            ))
        }

        // 拒否後の継続
        if score(.boundaryViolation) >= 18 {
            flags.append(RedFlagAmplifier(
                title: String(localized: "拒否表明後の継続", bundle: LanguageManager.appBundle),
                description: String(localized: "「やめて」「嫌」って言ったあとに同じノリが続くパターン。これはわかりやすい NG サインです。", bundle: LanguageManager.appBundle),
                evidence: sample(.boundaryViolation)
            ))
        }

        // 深夜・短時間の大量連投
        if score(.persistentRepetition) >= 25 {
            flags.append(RedFlagAmplifier(
                title: String(localized: "反復的な連投・追撃", bundle: LanguageManager.appBundle),
                description: String(localized: "短時間にバババッと連投や深夜の連絡が多めなパターン。「断るタイミング」を奪うクラシックな手口かも。", bundle: LanguageManager.appBundle),
                evidence: sample(.persistentRepetition)
            ))
        }

        // ガスライティング
        if score(.gaslighting) >= 20 {
            flags.append(RedFlagAmplifier(
                title: String(localized: "記憶・感覚の否定（ガスライティング）", bundle: LanguageManager.appBundle),
                description: String(localized: "「そんなこと言ってない」「気のせい」で記憶を上書きしてくるやつ。じわじわ自信を削るタイプなので、地味にしんどい。", bundle: LanguageManager.appBundle),
                evidence: sample(.gaslighting)
            ))
        }

        return flags
    }

    // MARK: - Stats

    private func makeStats(session: ChatSession, factors: [FactorScore]) -> DiagnosisStats {
        let textMessages = session.messages.filter { $0.eventType.isTextBased }
        let allDetections = factors.flatMap { $0.detections }
        let detectedMessageIds = Set(allDetections.map(\.messageId))
        let detectionRate: Int = textMessages.isEmpty ? 0 : Int(Double(detectedMessageIds.count) / Double(textMessages.count) * 100)
        let nightCount = allDetections.filter { det in
            let hour = Calendar.current.component(.hour, from: det.timestamp)
            return hour >= 22 || hour < 5
        }.count

        // 話者別集計（参加者全員。検出 0 件の話者も含めて返す）
        let detectionsBySpeaker = Dictionary(grouping: allDetections) { $0.speakerName }
        let perSpeaker: [SpeakerStats] = session.participants
            .map { participant in
                let dets = detectionsBySpeaker[participant.name] ?? []
                let factorCounts = Dictionary(grouping: dets) { $0.factor }.mapValues { $0.count }
                let topFactor = factorCounts.max { $0.value < $1.value }?.key
                let uniqueMsgIds = Set(dets.map(\.messageId))
                let speakerNight = dets.filter { det in
                    let hour = Calendar.current.component(.hour, from: det.timestamp)
                    return hour >= 22 || hour < 5
                }.count
                return SpeakerStats(
                    speakerName: participant.name,
                    detectionCount: dets.count,
                    detectionMessageCount: uniqueMsgIds.count,
                    topFactor: topFactor,
                    nightCount: speakerNight
                )
            }
            .sorted { $0.detectionCount > $1.detectionCount }

        return DiagnosisStats(
            totalMessages: session.messages.count,
            totalTextMessages: textMessages.count,
            detectedFactorCount: allDetections.count,
            uniqueDetectionMessageCount: detectedMessageIds.count,
            detectionRatePercent: detectionRate,
            firstDetectionAt: allDetections.map(\.timestamp).min(),
            lastDetectionAt: allDetections.map(\.timestamp).max(),
            nightDetectionCount: nightCount,
            perSpeaker: perSpeaker
        )
    }

    // MARK: - Next Steps (来月のアクション、占い・性格診断調)

    private func makeNextSteps(
        level: RiskLevel,
        primary: HarassmentCategory,
        redFlagCount: Int,
        relationship: RelationshipContext
    ) -> [String] {
        var steps: [String] = []

        // 関係性別の最初のアクション（unknown 以外）
        if let relationStep = relationshipSpecificFirstStep(relationship: relationship, level: level) {
            steps.append(relationStep)
        }

        switch level {
        case .low:
            steps.append(String(localized: "お互い様の雑談ベースを大事に。違和感が出たら早めに「それやめてー」とライトに言える関係を維持。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "たまにこのアプリで定期健康診断してみると、変化に気付けて面白いです。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "仲良すぎる人ほど、第三者の友達にトーク見せて感想もらうとバランスが取れます。", bundle: LanguageManager.appBundle))
        case .caution:
            steps.append(String(localized: "最近ちょっと違和感あるな、と思った瞬間にスクショを残す癖をつけておく。後で見返すと冷静になれます。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "友達に「これ普通？」と聞いてみる。自分一人で判定すると、慣れて麻痺します。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "相手の言い回しで気になるパターンを 1 つだけ、本人に軽く伝えてみる。反応で次が見えます。", bundle: LanguageManager.appBundle))
        case .medium:
            steps.append(String(localized: "ヤバ発言が来るタイミング（夜・酔った時・忙しい時など）をメモしておく。パターンが見えるとブロックしやすいです。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "信頼できる友達 1 人に、トーク履歴の一部を見てもらう。客観視できます。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "「これは流す」「これは指摘する」の線引きを自分の中で決めておく。線が無いと全部我慢になります。", bundle: LanguageManager.appBundle))
        case .high:
            steps.append(String(localized: "トーク履歴は絶対に削除しない。今のうちにバックアップしておくと安心。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "距離を取る選択肢を頭の片隅に置いておく。即断しなくていいけど、検討する自由は持っておく。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "結果のシェアボタンから友達に「これ見て」と送ってみる。第三者の率直なリアクションは効きます。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "通知ミュート・既読を遅らせる等、自分のペースを取り戻す小技を試してみる。", bundle: LanguageManager.appBundle))
        case .severe:
            steps.append(String(localized: "トーク履歴・スクショは絶対に消さない。第三者と共有できる形で保管。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "一人で抱えない。信頼できる人に状況を話す or 専門窓口（労働局・男女共同参画・DV相談プラス等）の存在だけでも頭に入れておく。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "物理的・心理的に距離を取る選択肢を、今すぐ実行しなくていいので「ある」と認識しておく。", bundle: LanguageManager.appBundle))
            steps.append(String(localized: "結果のシェアで状況を友達に共有しておくと、いざという時に相談しやすいです。", bundle: LanguageManager.appBundle))
        }

        if redFlagCount >= 2 && level != .severe {
            steps.append(String(localized: "ヤバさ MAX 警報が複数点灯しています。これは「気のせい」ではなく、構造として明確に出ている合図です。", bundle: LanguageManager.appBundle))
        }

        return steps
    }

    /// 関係性別の最初のアクション。caution 以上のときだけ提示。
    private func relationshipSpecificFirstStep(relationship: RelationshipContext, level: RiskLevel) -> String? {
        guard level != .low, relationship != .unknown else { return nil }
        switch relationship {
        case .romantic:
            return String(localized: "恋人関係の場合、別れる別れないより先に「自分が安全圏に戻れる時間」を確保するのが先決。返信を一時的に遅らせる/通知を切る等、ペースを取り戻す小技から。", bundle: LanguageManager.appBundle)
        case .exRomantic:
            return String(localized: "元恋人からの脅し・束縛が混ざっているなら、トーク履歴は絶対に消さない。今後の相談・通報の証拠になるので、別端末や iCloud にバックアップを。", bundle: LanguageManager.appBundle)
        case .family:
            return String(localized: "家族関係は逃げ場が物理的に狭いぶん、信頼できる第三者（友達・カウンセラー・公的窓口）に状況を共有しておくと、選択肢が広がります。", bundle: LanguageManager.appBundle)
        case .friend:
            return String(localized: "友達関係なら、まずは「これ嫌だった」を 1 個だけ本人に伝えてみるのが効きます。反応で関係の伸びしろが見えます。", bundle: LanguageManager.appBundle)
        case .bossOverMe:
            return String(localized: "上司・先輩からの圧が強めなら、日時付きで会話ログをスクショ保管。労務・人事・労基への相談を検討する前提で証拠を貯めるフェーズに。", bundle: LanguageManager.appBundle)
        case .subToMe:
            return String(localized: "部下・後輩からの逆パワハラ・カスハラ風の圧は、こちらが上の立場ゆえに我慢しがち。チーム外の上司・人事への共有を早めに。", bundle: LanguageManager.appBundle)
        case .colleague:
            return String(localized: "同僚間の圧は当事者だけで処理せず、信頼できる別部署の同僚 or 人事ルートで第三者を巻き込むと加速しません。", bundle: LanguageManager.appBundle)
        case .unknown:
            return nil
        }
    }
}
