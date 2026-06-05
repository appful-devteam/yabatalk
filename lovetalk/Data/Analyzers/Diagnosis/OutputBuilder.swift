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
                return "\(first.displayName)\(first.trailingSuffix)"
            }
            var s = primary.shortName
            if !secondary.isEmpty {
                s += " × " + secondary.map(\.shortName).joined(separator: " × ")
            }
            return s
        }()
        let relationPrefix: String = relationship == .unknown ? "" : "\(relationship.shortName)視点で見ると、"
        let levelTone: String
        switch level {
        case .low: return "\(relationPrefix)\(categoryLabel) っぽさがほんのり。今のところ平和ライン。"
        case .caution: levelTone = "ちょっと注意"
        case .medium: levelTone = "中辛"
        case .high: levelTone = "けっこうヤバい"
        case .severe: levelTone = "ヤバ度 MAX"
        }
        return "\(relationPrefix)\(categoryLabel) 系の傾向が「\(levelTone)」レベルで検出。"
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
                return "\(first.displayName)\(first.trailingSuffix)"
            }
            return primaryCategory.displayName
        }()

        // P0: 関係性プリオールの宣言（unknown 以外）
        if relationship != .unknown {
            paragraphs.append("今回は「\(relationship.displayName)」前提で読みます。\(relationship.openingFlavor)")
        }

        // P1: 占い的オープニング（呼称を関係性化）
        let scopedSubject = relationship == .unknown ? "相手" : relationship.partnerNoun
        paragraphs.append("今回のトークから読み取れる\(scopedSubject)の傾向は、ずばり「\(categoryLabel)」寄り。やばさは\(overallScore)% で「\(level.displayName)」レベル。" + flavor(for: level))

        // P2: 主成分
        let topFactors = factors.prefix(3)
        if !topFactors.isEmpty {
            let parts = topFactors.map { "「\($0.factor.displayName)」" }
            let keyFactorPart = parts.joined(separator: "・")
            paragraphs.append("中心にあるのは \(keyFactorPart) の組み合わせ。" + structuralComment(for: primaryCategory))
        }

        // P3: 補助分類
        if !secondaryCategories.isEmpty {
            let secondaryLabel = secondaryCategories.map(\.shortName).joined(separator: " と ")
            paragraphs.append("これに \(secondaryLabel) っぽい要素も混ざっていて、一筋縄ではいかないタイプです。")
        } else if primaryCategory == .other, subCategories.count > 1 {
            let subLabels = subCategories.prefix(3).map { "\($0.displayName)" }.joined(separator: " / ")
            paragraphs.append("その他系では \(subLabels) の傾向も同時に出ています。")
        }

        // P4: 密度
        if stats.totalTextMessages > 0 {
            let densitySentence: String
            if stats.detectionRatePercent >= 30 {
                densitySentence = "テキスト \(stats.totalTextMessages) 件中 \(stats.detectionRatePercent)% にヤバ成分が乗っているので、特定の瞬間というより、トーク全体に染み込んでいるイメージです。"
            } else if stats.detectionRatePercent >= 10 {
                densitySentence = "テキスト \(stats.totalTextMessages) 件中 \(stats.detectionRatePercent)% にヤバ成分。発火ポイントは局所的ですが、刺さる時はちゃんと刺さってます。"
            } else {
                densitySentence = "テキスト \(stats.totalTextMessages) 件中 \(stats.detectionRatePercent)%。割合は少なめですが、出る時はピンポイントで濃いです。"
            }
            paragraphs.append(densitySentence)
        }

        if stats.nightDetectionCount >= 3 {
            paragraphs.append("ちなみに夜の 22 時〜朝 5 時帯で \(stats.nightDetectionCount) 件の検出。深夜にテンション上がるとヤバ濃度がブーストするタイプかもしれません。")
        }

        return paragraphs
    }

    private func flavor(for level: RiskLevel) -> String {
        switch level {
        case .low: return "今のところ、笑い話で済む範囲です。"
        case .caution: return "ちょっと「ん？」が混じってきた、注意マーク点灯フェーズ。"
        case .medium: return "そろそろ友達にスクショを見せたくなる中辛レベル。"
        case .high: return "これは普通に「ヤバくない？」案件、香ばしさ高め。"
        case .severe: return "もう全部やばい、保存ボタン即押し案件です。"
        }
    }

    private func structuralComment(for category: HarassmentCategory) -> String {
        switch category {
        case .power:
            return "立場・評価・仕事を背景にした圧が主な持ち味。"
        case .sexual:
            return "性的・恋愛的な距離感がバグっている瞬間が中心。"
        case .moral:
            return "親密関係を盾にした心理サンドバッグ構造。"
        case .other:
            return "属性押しつけ・制度乱用・プライベート侵略あたりが断片的に。"
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
        let prefix = isPrimary ? "メインの傾向はここ。" : ""
        sentences.append("\(prefix)スコアは \(score)%（\(level.displayName)）。")

        if contributing.isEmpty {
            sentences.append("濃いめの要素は出てないけど、ふんわり関連ワードが顔を出してる感じ。")
        } else {
            let factorNames = contributing.map { "「\($0.factor.displayName)」(\($0.score)%)" }.joined(separator: "、")
            sentences.append("メインで効いてるのは \(factorNames) あたり。")
            sentences.append(categoryStructureExplanation(category: category, contributing: contributing))
        }

        if category == .other, !subCategories.isEmpty {
            let subLabels = subCategories.prefix(3).map { "\($0.displayName)" }.joined(separator: " / ")
            sentences.append("サブで混ざってるのは \(subLabels) 系。")
        }

        return sentences.joined(separator: " ")
    }

    private func categoryStructureExplanation(category: HarassmentCategory, contributing: [FactorScore]) -> String {
        let factorSet = Set(contributing.map(\.factor))
        switch category {
        case .power:
            if factorSet.contains(.dominance) && factorSet.contains(.disadvantageThreat) {
                return "立場の差を後ろに、評価とか処遇のチラつかせがセットで出てるタイプ。"
            }
            if factorSet.contains(.personalityDenial) || factorSet.contains(.abilityDenial) {
                return "指導っぽい流れに乗せて、人格や能力ごとパスしちゃってるかも。"
            }
            if factorSet.contains(.excessiveDemand) {
                return "業務の枠を超える要求が、ちょっと常態化ぎみなパターン。"
            }
            return "評価・仕事の話と立場差の組み合わせが軸になってる感じ。"
        case .sexual:
            if factorSet.contains(.quotaPairing) {
                return "色恋っぽい話と評価・仕事がくっついてる、典型的に注意マークなやつ。"
            }
            if factorSet.contains(.boundaryViolation) {
                return "「やめて」「嫌」のあとも同じノリが続いてて、境界線が結構ふんわり。"
            }
            if factorSet.contains(.persistentRepetition) {
                return "繰り返しの誘いや連絡が多めで、断りにくさを上手く使っちゃってる感じ。"
            }
            return "距離感バグ × 断りにくさのコンボがメイン。"
        case .moral:
            if factorSet.contains(.guiltManipulation) && factorSet.contains(.intimateRelationship) {
                return "関係性を盾にした罪悪感投げが中心の組み立て。"
            }
            if factorSet.contains(.gaslighting) {
                return "「そんなこと言ってない」系で記憶を上書きしてくるムードあり。"
            }
            if factorSet.contains(.monitoringControl) {
                return "返信や行動の追跡みがクセになってる感じ。"
            }
            return "親密関係の裏で、心理的にじわっと押してくる組み立て。"
        case .other:
            if factorSet.contains(.roleStereotype) {
                return "「女だから」「男なら」みたいな役割押しつけがチラつく感じ。"
            }
            if factorSet.contains(.privacyIntrusion) {
                return "プライベートへの踏み込みが、ちょっと多めかも。"
            }
            if factorSet.contains(.groupExclusion) {
                return "「あいつは入れない」みたいなハブり方向の動きが混ざってます。"
            }
            return "属性押しつけ・制度ハック・プライベート踏み込みあたりが、ちょこちょこ顔を出してる感じ。"
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
            countPart = "今回はサクッと 1 件ヒット。"
        case 2...4:
            countPart = "今回 \(count) 件。たまーに顔を出すクセみたいな感じ。"
        case 5...9:
            countPart = "今回 \(count) 件。これくらいだと結構口グセ寄りかも。"
        default:
            countPart = "今回 \(count) 件。ここまで来ると完全に持ちネタです。"
        }
        let severityPart: String
        switch severity {
        case .low: severityPart = "1 発の威力はやさしめだけど、積み重なるとボディブローみたいに効きます。"
        case .medium: severityPart = "威力は中くらい。シチュ次第で結構刺さるやつ。"
        case .high: severityPart = "1 発で「うわ…」ってなる強めパンチタイプ。"
        }
        let extra = factorAdditionalContext(for: factor)
        return [base, countPart, severityPart, extra].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func factorAdditionalContext(for factor: HarassmentFactor) -> String {
        switch factor {
        case .personalityDenial:
            return "「ここ直そう」じゃなく「人としてどうなの」って言われると、いやいや…ってなりがち。"
        case .disadvantageThreat:
            return "「やらないと損するよ」って匂わせ、選んだ気にさせて実は逃げ道をふさぐタイプの圧かも。"
        case .quotaPairing:
            return "色恋と評価がセットで出てくるパターン。これは「対価型セクハラ」っぽい組み合わせなので、要注意マーク強め。"
        case .boundaryViolation:
            return "「やめて」「嫌」って言ったあとに同じノリが続くのは、結構わかりやすい NG サイン。"
        case .gaslighting:
            return "「そんなこと言ってない」「気のせい」で記憶を上書きしようとするのは、こっちの感覚を弱らせるやつ。じわじわ効きます。"
        case .monitoringControl:
            return "返信や位置情報の追跡みは、対等な距離感がちょっと崩れがちなサイン。"
        case .guiltManipulation:
            return "「私の気持ち、あなたのせい」式は、ちょっとずつ罪悪感を貯金させてくる仕組み。優しい人ほど効きます。"
        case .excessiveDemand:
            return "深夜・休日対応とか物理的にムリな締切は、相手の体力前提が抜けちゃってるパターン。"
        case .persistentRepetition:
            return "短時間にバババッと連投する追い打ちは、相手の「断るタイミング」を奪うやつ。"
        case .roleStereotype:
            return "「女らしさ」「男なら」って属性で人を扱うのは、結構レトロな価値観の押しつけかも。"
        case .maternityPenalty:
            return "妊娠・育児・介護を理由に冷たくするのは、ライフイベント側を踏みつけるムードがあります。"
        case .academicPower:
            return "成績・推薦・卒業をチラつかせる圧は、いわゆる「アカハラ」寄りの出方。"
        case .alcoholCoercion:
            return "「飲もうよ」「飲まないの？」が強気めだと、体質や宗教や好みを無視しがち。"
        case .customerAggression:
            return "客・取引先の立場で押してくるパターンは、いわゆる「カスハラ」寄りの出方。"
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
                title: "性的・恋愛的要求と評価/仕事の結合",
                description: "色恋の話と評価・仕事が同じ流れに乗っちゃってるパターン。これは結構ハッキリ赤信号、注意マーク強めです。",
                evidence: sample(.quotaPairing) ?? sample(.sexualContext)
            ))
        }

        // 不利益示唆
        if score(.disadvantageThreat) >= 25 {
            flags.append(RedFlagAmplifier(
                title: "不利益示唆（脅し）",
                description: "クビ・評価下げ・シフト減・別れ・晒し…みたいに「やらないと損するよ」って匂わせるやつ。選んだ気にさせて実は逃げ場をふさぐタイプ。",
                evidence: sample(.disadvantageThreat)
            ))
        }

        // 存在否定
        if score(.existenceDenial) >= 20 {
            flags.append(RedFlagAmplifier(
                title: "存在・所属の否定",
                description: "「来なくていい」「消えろ」「いらない」みたいに、居場所そのものを取り上げる言い方。これはマジで効いちゃう系。",
                evidence: sample(.existenceDenial)
            ))
        }

        // 拒否後の継続
        if score(.boundaryViolation) >= 18 {
            flags.append(RedFlagAmplifier(
                title: "拒否表明後の継続",
                description: "「やめて」「嫌」って言ったあとに同じノリが続くパターン。これはわかりやすい NG サインです。",
                evidence: sample(.boundaryViolation)
            ))
        }

        // 深夜・短時間の大量連投
        if score(.persistentRepetition) >= 25 {
            flags.append(RedFlagAmplifier(
                title: "反復的な連投・追撃",
                description: "短時間にバババッと連投や深夜の連絡が多めなパターン。「断るタイミング」を奪うクラシックな手口かも。",
                evidence: sample(.persistentRepetition)
            ))
        }

        // ガスライティング
        if score(.gaslighting) >= 20 {
            flags.append(RedFlagAmplifier(
                title: "記憶・感覚の否定（ガスライティング）",
                description: "「そんなこと言ってない」「気のせい」で記憶を上書きしてくるやつ。じわじわ自信を削るタイプなので、地味にしんどい。",
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
            steps.append("お互い様の雑談ベースを大事に。違和感が出たら早めに「それやめてー」とライトに言える関係を維持。")
            steps.append("たまにこのアプリで定期健康診断してみると、変化に気付けて面白いです。")
            steps.append("仲良すぎる人ほど、第三者の友達にトーク見せて感想もらうとバランスが取れます。")
        case .caution:
            steps.append("最近ちょっと違和感あるな、と思った瞬間にスクショを残す癖をつけておく。後で見返すと冷静になれます。")
            steps.append("友達に「これ普通？」と聞いてみる。自分一人で判定すると、慣れて麻痺します。")
            steps.append("相手の言い回しで気になるパターンを 1 つだけ、本人に軽く伝えてみる。反応で次が見えます。")
        case .medium:
            steps.append("ヤバ発言が来るタイミング（夜・酔った時・忙しい時など）をメモしておく。パターンが見えるとブロックしやすいです。")
            steps.append("信頼できる友達 1 人に、トーク履歴の一部を見てもらう。客観視できます。")
            steps.append("「これは流す」「これは指摘する」の線引きを自分の中で決めておく。線が無いと全部我慢になります。")
        case .high:
            steps.append("トーク履歴は絶対に削除しない。今のうちにバックアップしておくと安心。")
            steps.append("距離を取る選択肢を頭の片隅に置いておく。即断しなくていいけど、検討する自由は持っておく。")
            steps.append("結果のシェアボタンから友達に「これ見て」と送ってみる。第三者の率直なリアクションは効きます。")
            steps.append("通知ミュート・既読を遅らせる等、自分のペースを取り戻す小技を試してみる。")
        case .severe:
            steps.append("トーク履歴・スクショは絶対に消さない。第三者と共有できる形で保管。")
            steps.append("一人で抱えない。信頼できる人に状況を話す or 専門窓口（労働局・男女共同参画・DV相談プラス等）の存在だけでも頭に入れておく。")
            steps.append("物理的・心理的に距離を取る選択肢を、今すぐ実行しなくていいので「ある」と認識しておく。")
            steps.append("結果のシェアで状況を友達に共有しておくと、いざという時に相談しやすいです。")
        }

        if redFlagCount >= 2 && level != .severe {
            steps.append("ヤバさ MAX 警報が複数点灯しています。これは「気のせい」ではなく、構造として明確に出ている合図です。")
        }

        return steps
    }

    /// 関係性別の最初のアクション。caution 以上のときだけ提示。
    private func relationshipSpecificFirstStep(relationship: RelationshipContext, level: RiskLevel) -> String? {
        guard level != .low, relationship != .unknown else { return nil }
        switch relationship {
        case .romantic:
            return "恋人関係の場合、別れる別れないより先に「自分が安全圏に戻れる時間」を確保するのが先決。返信を一時的に遅らせる/通知を切る等、ペースを取り戻す小技から。"
        case .exRomantic:
            return "元恋人からの脅し・束縛が混ざっているなら、トーク履歴は絶対に消さない。今後の相談・通報の証拠になるので、別端末や iCloud にバックアップを。"
        case .family:
            return "家族関係は逃げ場が物理的に狭いぶん、信頼できる第三者（友達・カウンセラー・公的窓口）に状況を共有しておくと、選択肢が広がります。"
        case .friend:
            return "友達関係なら、まずは「これ嫌だった」を 1 個だけ本人に伝えてみるのが効きます。反応で関係の伸びしろが見えます。"
        case .bossOverMe:
            return "上司・先輩からの圧が強めなら、日時付きで会話ログをスクショ保管。労務・人事・労基への相談を検討する前提で証拠を貯めるフェーズに。"
        case .subToMe:
            return "部下・後輩からの逆パワハラ・カスハラ風の圧は、こちらが上の立場ゆえに我慢しがち。チーム外の上司・人事への共有を早めに。"
        case .colleague:
            return "同僚間の圧は当事者だけで処理せず、信頼できる別部署の同僚 or 人事ルートで第三者を巻き込むと加速しません。"
        case .unknown:
            return nil
        }
    }
}
