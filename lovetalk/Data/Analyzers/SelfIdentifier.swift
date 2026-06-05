import Foundation

// MARK: - Self Identifier
/// トーク履歴から「自分」を推定
final class SelfIdentifier {

    struct IdentificationResult {
        let selfName: String
        let partnerName: String
        let confidence: Double
        let scores: [String: Double]
    }

    // MARK: - Public Methods

    /// 参加者リストから「自分」を推定
    func identify(
        participants: [ChatParticipant],
        messages: [ChatMessage],
        blocks: [ConversationBlock]
    ) -> IdentificationResult? {
        guard participants.count == 2 else {
            return nil
        }

        var scores: [String: Double] = [:]

        for participant in participants {
            var score: Double = 0

            // 1. 発言量最少 → 候補（+2点）
            let messageCount = messages.filter { $0.senderName == participant.name }.count
            let minCount = participants.map { p in
                messages.filter { $0.senderName == p.name }.count
            }.min() ?? 0

            if messageCount == minCount {
                score += 2
            }

            // 2. 開始率低い → 加点（+1点）
            let initiatedBlocks = blocks.filter { $0.initiator == participant.name }.count
            let initiationRate = blocks.isEmpty ? 0.5 : Double(initiatedBlocks) / Double(blocks.count)
            if initiationRate < 0.4 {
                score += 1
            }

            // 3. 返信速度分布が遅め → 加点（+1点）
            let avgReplySpeed = calculateAverageReplySpeed(for: participant.name, in: messages)
            let allAvgSpeeds = participants.map { calculateAverageReplySpeed(for: $0.name, in: messages) }
            let overallAvg = allAvgSpeeds.reduce(0, +) / Double(allAvgSpeeds.count)
            if avgReplySpeed > overallAvg {
                score += 1
            }

            // 4. テキスト長平均最少 → 加点（+1点）
            let avgLength = calculateAverageTextLength(for: participant.name, in: messages)
            let minLength = participants.map { calculateAverageTextLength(for: $0.name, in: messages) }.min() ?? 0
            if avgLength == minLength && avgLength > 0 {
                score += 1
            }

            scores[participant.name] = score
        }

        // 最高スコアの参加者を「自分」と推定
        let sortedScores = scores.sorted { $0.value > $1.value }
        guard let selfEntry = sortedScores.first,
              let partnerEntry = sortedScores.dropFirst().first else {
            return nil
        }

        // 信頼度計算（スコア差が大きいほど高信頼）
        let scoreDifference = selfEntry.value - partnerEntry.value
        let maxScore: Double = 5.0
        let confidence = min(1.0, max(0.3, scoreDifference / maxScore + 0.5))

        return IdentificationResult(
            selfName: selfEntry.key,
            partnerName: partnerEntry.key,
            confidence: confidence,
            scores: scores
        )
    }

    // MARK: - Private Methods

    /// 平均返信速度を計算（秒）
    private func calculateAverageReplySpeed(for participant: String, in messages: [ChatMessage]) -> Double {
        var replySpeeds: [TimeInterval] = []

        for i in 1..<messages.count {
            let prev = messages[i - 1]
            let curr = messages[i]

            // 他の人のメッセージ → この人の返信パターン
            if prev.senderName != participant && curr.senderName == participant {
                let speed = curr.timestamp.timeIntervalSince(prev.timestamp)
                // 24時間以内のみ
                if speed > 0 && speed < 24 * 60 * 60 {
                    replySpeeds.append(speed)
                }
            }
        }

        guard !replySpeeds.isEmpty else { return 0 }
        return replySpeeds.reduce(0, +) / Double(replySpeeds.count)
    }

    /// 平均テキスト長を計算
    private func calculateAverageTextLength(for participant: String, in messages: [ChatMessage]) -> Double {
        let textMessages = messages.filter {
            $0.senderName == participant && $0.eventType == .text
        }

        guard !textMessages.isEmpty else { return 0 }

        let totalLength = textMessages.reduce(0) { $0 + $1.textLength }
        return Double(totalLength) / Double(textMessages.count)
    }
}
