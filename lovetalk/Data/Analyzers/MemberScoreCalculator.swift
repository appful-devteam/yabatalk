import Foundation

// MARK: - Member Score Calculator
/// グループチャットにおける各メンバーの4軸スコアを個別計算
final class MemberScoreCalculator {

    // MARK: - Love Words (言語別パターンリスト)

    private static func loveWordPatterns(for language: ChatLanguage) -> [String] {
        switch language {
        case .japanese:
            return [
                "好き", "すき", "スキ", "大好き", "だいすき", "ダイスキ",
                "愛してる", "あいしてる", "会いたい", "あいたい",
                "かわいい", "可愛い", "カワイイ", "かっこいい", "カッコいい",
                "きゅん", "キュン", "ちゅ", "チュ",
                "ありがとう", "ありがと", "サンキュー", "さんきゅー",
                "嬉しい", "うれしい", "助かる", "たすかる",
                "ごめんね", "ごめん", "大丈夫", "だいじょうぶ", "気をつけて",
                "おはよう", "おはよ", "おやすみ", "おつかれ", "お疲れ",
                "頑張って", "がんばって", "がんばれ", "ファイト",
                "すごい", "さすが", "いいね", "最高",
                "楽しみ", "たのしみ", "一緒に", "いっしょに", "ずっと"
            ]
        case .english:
            return [
                "love you", "love u", "i love you", "miss you", "missing you",
                "you're cute", "you're beautiful", "babe", "baby", "darling",
                "thank you", "thanks", "thx", "appreciate",
                "i'm sorry", "sorry", "you okay", "take care", "be careful",
                "good morning", "good night", "sleep well", "sweet dreams",
                "you can do it", "you got this", "believe in you",
                "amazing", "awesome", "great job", "well done",
                "looking forward", "can't wait", "together", "forever"
            ]
        case .spanish:
            return [
                "te quiero", "te amo", "te extraño", "te echo de menos",
                "eres hermosa", "eres hermoso", "mi amor", "cariño", "corazón",
                "gracias", "muchas gracias", "te lo agradezco",
                "lo siento", "perdón", "estás bien", "cuídate",
                "buenos días", "buenas noches", "dulces sueños",
                "tú puedes", "ánimo", "sigue adelante",
                "increíble", "genial", "bien hecho",
                "tengo ganas", "juntos", "siempre"
            ]
        case .korean:
            return [
                "사랑해", "좋아해", "보고싶어", "보고싶다",
                "귀여워", "이뻐", "예뻐", "자기야", "오빠",
                "고마워", "감사해요", "감사합니다",
                "미안해", "괜찮아", "조심해",
                "좋은아침", "잘자", "안녕", "수고",
                "힘내", "화이팅", "파이팅",
                "대박", "대단해", "최고",
                "기대돼", "같이", "항상"
            ]
        case .chinese:
            return [
                // Simplified
                "爱你", "我爱你", "喜欢你", "想你", "好想你",
                "好可爱", "好帅", "好漂亮", "宝贝", "亲爱的",
                "谢谢", "感谢", "多谢",
                "对不起", "抱歉", "你还好吗", "小心",
                "早安", "晚安", "你好", "辛苦了",
                "加油", "你可以的", "相信你",
                "厉害", "好棒", "666",
                "好期待", "一起", "永远",
                // Traditional
                "愛你", "我愛你", "喜歡你",
                "好可愛", "好帥", "好漂亮", "寶貝", "親愛的",
                "謝謝", "感謝",
                "對不起", "你還好嗎",
                "厲害",
                "好期待", "永遠"
            ]
        }
    }

    // MARK: - Public Methods

    /// 全メンバーの個人別スコアを計算
    func calculateAll(
        messages: [ChatMessage],
        selfName: String,
        allParticipantNames: [String],
        language: ChatLanguage = .japanese
    ) -> [MemberScore] {
        // 辞書のsubscript defaultで直接appendし、コピーを回避
        var memberAllMessages: [String: [ChatMessage]] = [:]
        var memberTextMessages: [String: [ChatMessage]] = [:]
        var memberStickerCounts: [String: Int] = [:]
        var totalNonSystemCount = 0
        var uniqueSenders: Set<String> = []

        for msg in messages {
            guard msg.eventType != .system else { continue }
            totalNonSystemCount += 1
            uniqueSenders.insert(msg.senderName)
            memberAllMessages[msg.senderName, default: []].append(msg)
            if msg.eventType == .text {
                memberTextMessages[msg.senderName, default: []].append(msg)
            } else if msg.eventType == .sticker {
                memberStickerCounts[msg.senderName, default: 0] += 1
            }
        }

        let uniqueParticipantCount = uniqueSenders.count

        // 返信速度を1回のパスで全メンバー分計算
        var replySpeeds: [String: [Double]] = [:]
        for i in 1..<messages.count {
            let prev = messages[i - 1]
            let curr = messages[i]
            if prev.senderName != curr.senderName {
                let speed = curr.timestamp.timeIntervalSince(prev.timestamp)
                if speed > 0 && speed <= 24 * 60 * 60 {
                    replySpeeds[curr.senderName, default: []].append(speed)
                }
            }
        }

        return allParticipantNames.map { memberName in
            let allMsgs = memberAllMessages[memberName] ?? []
            let textMsgs = memberTextMessages[memberName] ?? []

            let balanceScore = calculateBalance(
                memberCount: allMsgs.count,
                totalCount: totalNonSystemCount,
                uniqueParticipantCount: uniqueParticipantCount
            )
            let tensionScore = calculateTension(
                textMessages: textMsgs,
                totalMemberCount: allMsgs.count,
                stickerCount: memberStickerCounts[memberName] ?? 0
            )
            let responseScore = calculateResponse(
                replySpeeds: replySpeeds[memberName] ?? []
            )
            let wordScore = calculateWord(
                textMessages: textMsgs,
                language: language
            )

            return MemberScore(
                memberName: memberName,
                balanceScore: balanceScore,
                tensionScore: tensionScore,
                responseScore: responseScore,
                wordScore: wordScore
            )
        }
    }

    // MARK: - Balance（メッセージシェア率）

    private func calculateBalance(
        memberCount: Int,
        totalCount: Int,
        uniqueParticipantCount: Int
    ) -> Double {
        guard totalCount > 0 else { return 50.0 }

        let shareRatio = Double(memberCount) / Double(totalCount)
        let idealRatio = 1.0 / Double(max(uniqueParticipantCount, 2))

        let deviation = abs(shareRatio - idealRatio) / idealRatio
        let score = 100.0 * pow(max(0, 1.0 - deviation), 2.0)
        return max(0, min(100, score))
    }

    // MARK: - Tension（絵文字・笑い・感嘆符の使用率）

    private func calculateTension(
        textMessages: [ChatMessage],
        totalMemberCount: Int,
        stickerCount: Int
    ) -> Double {
        let textCount = textMessages.count
        guard totalMemberCount > 0 else { return 0 }

        // スタンプ率
        let stickerRate = Double(stickerCount) / Double(totalMemberCount)
        let stickerScore = logScore(rate: stickerRate, maxRate: 0.05)

        // 1回のループで笑い・絵文字・感嘆符をまとめてカウント
        let laughPatterns = [
            "笑", "w", "W", "草", "ワラ", "わら",
            "lol", "lmao", "haha", "hehe",
            "ㅋㅋ", "ㅎㅎ",
            "哈哈", "嘻嘻", "233", "jaja", "jeje"
        ]
        var laughCount = 0
        var emojiCount = 0
        var exclamationCount = 0

        for msg in textMessages {
            let content = msg.content
            if laughPatterns.contains(where: { content.contains($0) }) {
                laughCount += 1
            }
            if content.containsEmoji {
                emojiCount += 1
            }
            if content.contains("！") || content.contains("!") {
                exclamationCount += 1
            }
        }

        let laughRate = textCount > 0 ? Double(laughCount) / Double(textCount) : 0
        let laughScore = logScore(rate: laughRate, maxRate: 0.10)

        let emojiRate = textCount > 0 ? Double(emojiCount) / Double(textCount) : 0
        let emojiScore = logScore(rate: emojiRate, maxRate: 0.15)

        let exclamationRate = textCount > 0 ? Double(exclamationCount) / Double(textCount) : 0
        let exclamationScore = logScore(rate: exclamationRate, maxRate: 0.20)

        let score = 0.30 * stickerScore + 0.30 * laughScore + 0.20 * emojiScore + 0.20 * exclamationScore
        return max(0, min(100, score))
    }

    // MARK: - Response（返信速度）

    private func calculateResponse(
        replySpeeds: [Double]
    ) -> Double {
        guard replySpeeds.count >= 3 else { return 50.0 }

        let sorted = replySpeeds.sorted()
        let median = sorted[sorted.count / 2]

        let medianMinutes = median / 60.0
        let logDiff = log(1.0 + medianMinutes)
        let maxLogDiff = log(1.0 + 180.0)
        let rawScore = max(0, 100 * (1 - logDiff / maxLogDiff))

        let dataFactor = min(1.0, Double(replySpeeds.count) / 30.0)
        let adjustedScore = 50 + (rawScore - 50) * dataFactor

        return max(0, min(100, adjustedScore))
    }

    // MARK: - Word（愛情表現使用率）

    /// 全言語のパターンを統合（混在言語のトークでも正確にスコアリング）
    private static let allLoveWordPatterns: [String] = {
        var all: [String] = []
        for lang in [ChatLanguage.japanese, .english, .spanish, .korean, .chinese] {
            all += loveWordPatterns(for: lang)
        }
        return all
    }()

    private func calculateWord(
        textMessages: [ChatMessage],
        language: ChatLanguage = .japanese
    ) -> Double {
        let totalTextCount = textMessages.count
        guard totalTextCount > 0 else { return 0 }

        let patterns = Self.allLoveWordPatterns
        var hitCount = 0
        for message in textMessages {
            let content = message.content.lowercased()
            for pattern in patterns {
                if content.contains(pattern.lowercased()) {
                    hitCount += 1
                    break
                }
            }
        }

        let rate = Double(hitCount) / Double(totalTextCount)
        let score = logScore(rate: rate, maxRate: 0.08)
        return max(0, min(100, score))
    }

    // MARK: - Helpers

    private func logScore(rate: Double, maxRate: Double) -> Double {
        let baseline = 0.005
        guard rate > 0 else { return 0 }
        return min(100, log(1.0 + rate / baseline) / log(1.0 + maxRate / baseline) * 100.0)
    }
}
