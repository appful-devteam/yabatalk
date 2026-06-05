import Foundation

/// LINE トーク（[ChatMessage]）から構成要素を検出する
struct FactorDetector: Sendable {
    /// 検出オプション
    struct Options: Sendable {
        /// 自分（推定）の発言を検出対象から外すか。
        /// yabatalk は相性分析ではなく **両者のヤバ発言を双方向に検出** するアプリなので既定 false。
        var excludeSelfSpeaker: Bool = false
        /// 反復性検出における同一 sender 連続テキスト数の閾値
        var chaseThreshold: Int = 5
        /// 反復性検出における夜間連投の閾値（22:00–05:00 の時間帯で N 件以上）
        var nightFloodThreshold: Int = 6
        /// false-positive 抑制用の周辺チェックウィンドウ（文字数, 前後それぞれ）
        var suppressionWindow: Int = 14
    }

    let options: Options

    init(options: Options = Options()) {
        self.options = options
    }

    /// 検出を実行する
    func detect(session: ChatSession) -> [FactorDetection] {
        let selfName = options.excludeSelfSpeaker ? session.estimatedSelfName : nil
        let messages = session.messages

        var detections: [FactorDetection] = []
        detections.append(contentsOf: detectPatternMatches(messages: messages, selfName: selfName))
        detections.append(contentsOf: detectBoundaryViolation(messages: messages, selfName: selfName))
        detections.append(contentsOf: detectPersistentRepetition(messages: messages, selfName: selfName))
        detections.append(contentsOf: detectIntimateRelationshipFromMeta(session: session))
        return detections
    }

    // MARK: - Pattern Match

    private func detectPatternMatches(messages: [ChatMessage], selfName: String?) -> [FactorDetection] {
        var out: [FactorDetection] = []
        for message in messages where message.eventType.isTextBased {
            if let selfName, message.senderName == selfName { continue }
            for rule in FactorRuleDictionary.rules {
                guard let range = firstMatch(rule.pattern, in: message.content) else { continue }
                let context = surroundingContext(text: message.content, around: range)
                // 1. suppress: モノ語 / 3 人称グチ / rule 固有 suppress
                if shouldSuppress(rule: rule, context: context) { continue }
                // 2. severity adjust: soften / amplify
                let adjustedSeverity = adjustSeverity(
                    rule: rule,
                    context: context
                )
                let evidence = String(message.content[range])
                out.append(
                    FactorDetection(
                        factor: rule.factor,
                        messageId: message.id,
                        speakerName: message.senderName,
                        timestamp: message.timestamp,
                        evidence: extractContext(message.content, around: range, padding: 16),
                        matchedPattern: evidence,
                        severity: adjustedSeverity
                    )
                )
            }
        }
        return out
    }

    /// 検出箇所の周辺ウィンドウ文字列
    private func surroundingContext(text: String, around range: Range<String.Index>) -> String {
        let window = options.suppressionWindow
        let lower = text.index(range.lowerBound, offsetBy: -window, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: window, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[lower..<upper])
    }

    /// suppressIfNearby / requireAnyNearby + 個人攻撃 factor は 3 人称マーカーで suppress
    private func shouldSuppress(rule: FactorRule, context: String) -> Bool {
        if matchesAny(rule.suppressIfNearby, in: context) { return true }
        if !rule.requireAnyNearby.isEmpty {
            let satisfied = matchesAny(rule.requireAnyNearby, in: context)
            if !satisfied { return true }
        }
        // 個人攻撃系 factor: 3 人称マーカーが出てきたら抑制 (「あの上司使えない」)
        if Self.personalAttackFactors.contains(rule.factor),
           matchesAny(SubjectMarkers.thirdPerson, in: context) {
            return true
        }
        return false
    }

    /// soften / amplify / 2 人称 boost / soft marker 緩和 を統合した severity 補正
    private func adjustSeverity(rule: FactorRule, context: String) -> FactorSeverity {
        var current = rule.severity

        // amplify: rule 固有 + 2 人称 direct address
        let amplified = matchesAny(rule.amplifyIfNearby, in: context)
            || matchesAny(SubjectMarkers.directAddress, in: context)
        if amplified { current = current.upgrade() }

        // soften: rule 固有 + 一般的 soft markers
        let softened = matchesAny(rule.softenIfNearby, in: context)
            || matchesAny(SubjectMarkers.softMarkers, in: context)
        if softened { current = current.downgrade() }

        return current
    }

    private func matchesAny(_ patterns: [String], in text: String) -> Bool {
        for p in patterns {
            if text.range(of: p, options: .regularExpression) != nil { return true }
        }
        return false
    }

    /// 「相手」への個人攻撃系 factor。3 人称マーカーがあれば愚痴とみなして suppress。
    private static let personalAttackFactors: Set<HarassmentFactor> = [
        .personalityDenial, .abilityDenial, .existenceDenial
    ]

    // MARK: - Boundary Violation

    /// 拒否表明（「やめて」「嫌」「無理」）の後に、相手が止まれず継続したら検出。
    /// 友達/カップル LINE 用に強化: 「ノリ悪い」「冗談じゃん」「逃げるな」等の冗談シールドも継続行為として検出。
    private func detectBoundaryViolation(messages: [ChatMessage], selfName: String?) -> [FactorDetection] {
        var out: [FactorDetection] = []
        let textMessages = messages.filter { $0.eventType.isTextBased }

        for (index, msg) in textMessages.enumerated() {
            // Stop は誰のメッセージでも検出対象（自分側だけに限定しない）
            guard stopPatterns.contains(where: { msg.content.contains($0) }) else { continue }
            let stopperName = msg.senderName

            // 直後 5 メッセージ以内に、stop した相手以外から「継続」発言があれば検出
            let followUpRange = (index + 1)..<min(index + 6, textMessages.count)
            for followIdx in followUpRange {
                let follow = textMessages[followIdx]
                if follow.senderName == stopperName { continue }
                if let matched = matchedContinuationPattern(in: follow.content) {
                    out.append(
                        FactorDetection(
                            factor: .boundaryViolation,
                            messageId: follow.id,
                            speakerName: follow.senderName,
                            timestamp: follow.timestamp,
                            evidence: "[\(stopperName)が拒否→\(follow.senderName)が継続] " + follow.content,
                            matchedPattern: "stop→継続 (\(matched))",
                            severity: .high
                        )
                    )
                    break
                }
            }
        }
        return out
    }

    private let stopPatterns: [String] = [
        "やめて", "やめてください", "もうやめて", "やめろ",
        "嫌だ", "嫌です", "嫌だよ", "嫌なんだけど",
        "無理", "無理だよ", "無理なんだけど",
        "それはちょっと", "ちょっと困る",
        "やめてほしい", "やめて欲しい",
        "本気で嫌", "マジで嫌"
    ]

    /// 拒否後に続く「継続行為」パターン
    private func matchedContinuationPattern(in text: String) -> String? {
        for pattern in continuationPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return pattern
            }
        }
        return nil
    }

    private var continuationPatterns: [String] {
        [
            // 冗談シールド / 責任回避
            "冗談じゃん", "ノリ悪い", "本気にすんな", "いじりじゃん",
            "本当は嬉しい", "そういうとこ(めんどい|うざ)",
            "なんで無理", "このくらいで(怒|キレ)", "傷つく方がおかしい",
            "空気読めない",
            // 圧の継続
            "逃げるな", "好きならできる", "本当に好きなら",
            "友達なら(普通)?やる", "親友なら",
            // セクハラ系継続
            "ホテル", "添い寝", "2人(きり|だけ)?で", "ふたりきり", "色気",
            // 監視系継続
            "今どこ", "誰といる", "写真送", "位置情報", "証拠",
            // 評価系継続
            "評価", "シフト", "推薦"
        ]
    }

    // MARK: - Persistent Repetition

    /// 5 連続以上の片側テキスト連投 / 深夜時間帯の大量連投を検出
    private func detectPersistentRepetition(messages: [ChatMessage], selfName: String?) -> [FactorDetection] {
        var out: [FactorDetection] = []
        let textMessages = messages.filter { $0.eventType.isTextBased }
        guard !textMessages.isEmpty else { return out }

        // (1) 連続 chase
        var run: [ChatMessage] = []
        for msg in textMessages {
            if let selfName, msg.senderName == selfName {
                if run.count >= options.chaseThreshold, let head = run.first {
                    out.append(
                        FactorDetection(
                            factor: .persistentRepetition,
                            messageId: head.id,
                            speakerName: head.senderName,
                            timestamp: head.timestamp,
                            evidence: "（連投 \(run.count) 件）" + head.content,
                            matchedPattern: "chase \(run.count)",
                            severity: run.count >= options.chaseThreshold + 3 ? .high : .medium
                        )
                    )
                }
                run.removeAll()
            } else {
                if run.last?.senderName == msg.senderName || run.isEmpty {
                    run.append(msg)
                } else {
                    run = [msg]
                }
            }
        }
        if run.count >= options.chaseThreshold, let head = run.first {
            out.append(
                FactorDetection(
                    factor: .persistentRepetition,
                    messageId: head.id,
                    speakerName: head.senderName,
                    timestamp: head.timestamp,
                    evidence: "（連投 \(run.count) 件）" + head.content,
                    matchedPattern: "chase \(run.count)",
                    severity: run.count >= options.chaseThreshold + 3 ? .high : .medium
                )
            )
        }

        // (2) 夜間連投（同一日付の 22:00–05:00 帯に相手側が N 件以上）
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: textMessages) { msg -> DateComponents in
            calendar.dateComponents([.year, .month, .day], from: msg.timestamp)
        }
        for (_, dayMessages) in groupedByDate {
            let nightFromOther = dayMessages.filter { msg in
                guard msg.isNightMessage || msg.isLateNightMessage else { return false }
                if let selfName, msg.senderName == selfName { return false }
                return true
            }
            if nightFromOther.count >= options.nightFloodThreshold, let head = nightFromOther.first {
                out.append(
                    FactorDetection(
                        factor: .persistentRepetition,
                        messageId: head.id,
                        speakerName: head.senderName,
                        timestamp: head.timestamp,
                        evidence: "（夜間連投 \(nightFromOther.count) 件）",
                        matchedPattern: "night flood \(nightFromOther.count)",
                        severity: .high
                    )
                )
            }
        }
        return out
    }

    // MARK: - Intimate Relationship from session

    /// ChatSession の participants が 2 人で、参加者間の親密関連語彙が頻出する場合、親密関係の baseline を上げる
    private func detectIntimateRelationshipFromMeta(session: ChatSession) -> [FactorDetection] {
        guard session.isOneOnOne else { return [] }
        let intimateKeywords = ["好き", "愛してる", "彼女", "彼氏", "付き合", "デート", "結婚", "うちら"]
        let textMessages = session.messages.filter { $0.eventType.isTextBased }
        let totalText = textMessages.count
        guard totalText > 0 else { return [] }
        let intimateHits = textMessages.filter { msg in
            intimateKeywords.contains { msg.content.contains($0) }
        }
        // 5% 以上のメッセージに親密語彙があれば 1on1 親密関係としてマーク
        guard Double(intimateHits.count) / Double(totalText) >= 0.05, let head = intimateHits.first else {
            return []
        }
        return [
            FactorDetection(
                factor: .intimateRelationship,
                messageId: head.id,
                speakerName: head.senderName,
                timestamp: head.timestamp,
                evidence: head.content,
                matchedPattern: "intimate ratio \(intimateHits.count)/\(totalText)",
                severity: .medium
            ),
        ]
    }

    // MARK: - Regex helpers

    private func firstMatch(_ pattern: String, in text: String) -> Range<String.Index>? {
        text.range(of: pattern, options: .regularExpression)
    }

    private func extractContext(_ text: String, around range: Range<String.Index>, padding: Int) -> String {
        let lower = text.index(range.lowerBound, offsetBy: -padding, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: padding, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[lower..<upper])
    }
}
