import Foundation

/// 会話の **応答ペア構造** から factor 検出を行う。
/// 単発の regex では拾えない「心配 → 冷たい返し」「質問の一方向性」「マウント語」「命令形比率」等を扱う。
/// 出力は FactorDetection なので既存の集計パイプラインに合流できる。
struct ConversationPatternAnalyzer: Sendable {

    /// 言語別の検知語彙（既定は日本語）
    let lexicon: DiagnosisLexicon

    init(lexicon: DiagnosisLexicon = .japanese) {
        self.lexicon = lexicon
    }

    private func matches(_ pattern: String, in text: String) -> Bool {
        RegexCache.shared.matches(pattern, in: text, caseInsensitive: lexicon.caseInsensitive)
    }

    /// 会話パターン検出を実行
    func analyze(session: ChatSession) -> [FactorDetection] {
        let textMessages = session.messages.filter { $0.eventType.isTextBased }
        guard !textMessages.isEmpty else { return [] }

        var detections: [FactorDetection] = []

        detections.append(contentsOf: detectColdResponseToWorry(messages: textMessages))
        detections.append(contentsOf: detectImperativeBias(messages: textMessages))
        detections.append(contentsOf: detectShortReplyBias(messages: textMessages))
        detections.append(contentsOf: detectQuestionOneWayness(messages: textMessages))
        detections.append(contentsOf: detectMountingPhrases(messages: textMessages))
        detections.append(contentsOf: detectSarcasmMarkers(messages: textMessages))
        detections.append(contentsOf: detectReadPressurePhrases(messages: textMessages))
        detections.append(contentsOf: detectDismissiveOnliners(messages: textMessages))

        return detections
    }

    // MARK: - 1. 心配/感情表明 → 冷たい返し

    /// A が感情・心配を出した直後 (3 メッセージ以内) に B が短い冷たい返しをしたら検出
    private func detectColdResponseToWorry(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        // 英語は短文の冷たい返しがやや長め ("not my problem" 等) なので上限を緩める
        let coldMaxLen = lexicon.caseInsensitive ? 18 : 10
        for (i, msg) in messages.enumerated() {
            let isEmotion = lexicon.worryEmotionPatterns.contains { matches($0, in: msg.content) }
            guard isEmotion else { continue }
            let lookahead = (i + 1)..<min(i + 4, messages.count)
            for j in lookahead {
                let follow = messages[j]
                if follow.senderName == msg.senderName { continue }
                let trimmed = follow.content.trimmingCharacters(in: .whitespaces)
                guard trimmed.count <= coldMaxLen else { continue }
                if lexicon.coldShortReplies.contains(where: { matches($0, in: trimmed) }) {
                    out.append(FactorDetection(
                        factor: .guiltManipulation,
                        messageId: follow.id,
                        speakerName: follow.senderName,
                        timestamp: follow.timestamp,
                        evidence: follow.content,
                        matchedPattern: "感情→冷たい",
                        severity: .medium
                    ))
                    break
                }
            }
        }
        return out
    }

    // MARK: - 2. 命令形バイアス（speakerごとの比率）

    /// 発言数 ≥ 8 の speaker について、命令形比率が 30% 以上なら検出
    private func detectImperativeBias(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        let bySpeaker = Dictionary(grouping: messages) { $0.senderName }
        for (_, msgs) in bySpeaker where msgs.count >= 8 {
            let imperatives = msgs.filter { msg in
                lexicon.imperativePatterns.contains { suffix in
                    matches(suffix, in: msg.content)
                }
            }
            let ratio = Double(imperatives.count) / Double(msgs.count)
            guard ratio >= 0.30, let sample = imperatives.first else { continue }
            out.append(FactorDetection(
                factor: .dominance,
                messageId: sample.id,
                speakerName: sample.senderName,
                timestamp: sample.timestamp,
                evidence: "（命令形 \(imperatives.count) / \(msgs.count) 件 = \(Int(ratio * 100))%）" + sample.content,
                matchedPattern: "命令形バイアス",
                severity: ratio >= 0.5 ? .high : .medium
            ))
        }
        return out
    }

    // MARK: - 3. 短文返信比率（無関心）

    /// speaker の発言中、3 文字以下が 50% 以上を占めるなら検出
    private func detectShortReplyBias(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        let bySpeaker = Dictionary(grouping: messages) { $0.senderName }
        for (_, msgs) in bySpeaker where msgs.count >= 10 {
            let shortReplies = msgs.filter { $0.content.trimmingCharacters(in: .whitespaces).count <= 3 }
            let ratio = Double(shortReplies.count) / Double(msgs.count)
            guard ratio >= 0.5, let sample = shortReplies.first else { continue }
            out.append(FactorDetection(
                factor: .guiltManipulation,
                messageId: sample.id,
                speakerName: sample.senderName,
                timestamp: sample.timestamp,
                evidence: "（3文字以下 \(shortReplies.count) / \(msgs.count) 件 = \(Int(ratio * 100))%）「\(sample.content)」",
                matchedPattern: "短文返信バイアス",
                severity: ratio >= 0.7 ? .high : .medium
            ))
        }
        return out
    }

    // MARK: - 4. 質問の一方向性

    /// 一方の speaker が圧倒的に質問していて、相手が質問返さないなら検出（モラハラ / 監視寄り）
    private func detectQuestionOneWayness(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        let bySpeaker = Dictionary(grouping: messages) { $0.senderName }
        guard bySpeaker.count == 2 else { return [] }

        let questionCounts: [String: Int] = bySpeaker.mapValues { msgs in
            msgs.filter { $0.content.contains("？") || $0.content.contains("?") || $0.content.contains("か？") }.count
        }
        let speakerNames = Array(questionCounts.keys)
        guard speakerNames.count == 2 else { return [] }
        let a = speakerNames[0]
        let b = speakerNames[1]
        let qa = questionCounts[a] ?? 0
        let qb = questionCounts[b] ?? 0
        let total = qa + qb
        guard total >= 10 else { return [] }

        // 圧倒的に片側が質問している場合
        if qa >= 8 && qb < qa / 4 {
            if let sample = bySpeaker[a]?.first(where: { $0.content.contains("？") || $0.content.contains("?") }) {
                out.append(FactorDetection(
                    factor: .monitoringControl,
                    messageId: sample.id,
                    speakerName: a,
                    timestamp: sample.timestamp,
                    evidence: "（質問 \(qa) vs \(qb)、一方向の問い詰め傾向）" + sample.content,
                    matchedPattern: "質問一方向",
                    severity: .medium
                ))
            }
        }
        if qb >= 8 && qa < qb / 4 {
            if let sample = bySpeaker[b]?.first(where: { $0.content.contains("？") || $0.content.contains("?") }) {
                out.append(FactorDetection(
                    factor: .monitoringControl,
                    messageId: sample.id,
                    speakerName: b,
                    timestamp: sample.timestamp,
                    evidence: "（質問 \(qb) vs \(qa)、一方向の問い詰め傾向）" + sample.content,
                    matchedPattern: "質問一方向",
                    severity: .medium
                ))
            }
        }
        return out
    }

    // MARK: - 5. マウント語

    private func detectMountingPhrases(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        for msg in messages {
            for phrase in lexicon.mountingPhrases where matches(phrase, in: msg.content) {
                out.append(FactorDetection(
                    factor: .dominance,
                    messageId: msg.id,
                    speakerName: msg.senderName,
                    timestamp: msg.timestamp,
                    evidence: msg.content,
                    matchedPattern: phrase,
                    severity: .medium
                ))
                break
            }
        }
        return out
    }

    // MARK: - 6. 皮肉マーカー

    private let sarcasmPatterns: [String] = [
        "すごいね（笑）", "すごいねw", "すごいねー", "へー、すごい",
        "ふーん", "なるほどね", "ほー、そうですか", "ほー、そう",
        "あっそ", "へぇ.{0,3}そう"
    ]

    private func detectSarcasmMarkers(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        for msg in messages {
            let trimmed = msg.content.trimmingCharacters(in: .whitespaces)
            guard trimmed.count <= 20 else { continue }
            for pattern in sarcasmPatterns {
                if RegexCache.shared.matches(pattern, in: trimmed, caseInsensitive: false) {
                    out.append(FactorDetection(
                        factor: .mockingLaughter,
                        messageId: msg.id,
                        speakerName: msg.senderName,
                        timestamp: msg.timestamp,
                        evidence: msg.content,
                        matchedPattern: "皮肉",
                        severity: .medium
                    ))
                    break
                }
            }
        }
        return out
    }

    // MARK: - 7. 既読圧フレーズ（既存 monitoringControl の補完）

    private let readPressurePhrases: [String] = [
        "返事は？", "返事まだ？", "なんで返さないの",
        "無視？", "無視するの？",
        "怒ってる？", "なんか怒ってる",
        "既読つけたよね", "既読見たよね",
        "返信ぐらい", "返信して"
    ]

    private func detectReadPressurePhrases(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        for msg in messages {
            for phrase in readPressurePhrases where msg.content.contains(phrase) {
                out.append(FactorDetection(
                    factor: .monitoringControl,
                    messageId: msg.id,
                    speakerName: msg.senderName,
                    timestamp: msg.timestamp,
                    evidence: msg.content,
                    matchedPattern: phrase,
                    severity: .high
                ))
                break
            }
        }
        return out
    }

    // MARK: - 8. 突き放し系の一文返し

    private let dismissivePatterns: [String] = [
        "^で？$", "^だから？$", "^それで？$", "^は？$", "^なに？$",
        "^どうでもいい$", "^勝手にして$", "^知らんがな$",
        "^好きにすれば$", "^好きにしたら$"
    ]

    private func detectDismissiveOnliners(messages: [ChatMessage]) -> [FactorDetection] {
        var out: [FactorDetection] = []
        for msg in messages {
            let trimmed = msg.content.trimmingCharacters(in: .whitespaces)
            guard trimmed.count <= 15 else { continue }
            for pattern in dismissivePatterns {
                if RegexCache.shared.matches(pattern, in: trimmed, caseInsensitive: false) {
                    out.append(FactorDetection(
                        factor: .guiltManipulation,
                        messageId: msg.id,
                        speakerName: msg.senderName,
                        timestamp: msg.timestamp,
                        evidence: msg.content,
                        matchedPattern: "突き放し",
                        severity: .medium
                    ))
                    break
                }
            }
        }
        return out
    }
}
