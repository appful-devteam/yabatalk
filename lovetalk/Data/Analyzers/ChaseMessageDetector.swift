import Foundation

// MARK: - Chase Message Detector
/// 追いトーク（連続送信）を検出
final class ChaseMessageDetector {
    private let chaseThreshold: Int

    init(chaseThreshold: Int = Constants.Analysis.chaseMessageThreshold) {
        self.chaseThreshold = chaseThreshold
    }

    // MARK: - Public Methods

    /// 会話ブロック内の追いトークを検出
    func detect(in block: ConversationBlock) -> [ChaseMessageRange] {
        let messages = block.messages.filter { $0.eventType == .text }
        guard messages.count > chaseThreshold else { return [] }

        var ranges: [ChaseMessageRange] = []
        var consecutiveCount = 1
        var rangeStartIndex = 0
        var currentSender = messages.first?.senderName ?? ""

        for (index, message) in messages.enumerated().dropFirst() {
            if message.senderName == currentSender {
                consecutiveCount += 1
            } else {
                // 連続が途切れた
                if consecutiveCount > chaseThreshold {
                    ranges.append(ChaseMessageRange(
                        startIndex: rangeStartIndex,
                        endIndex: index - 1,
                        sender: currentSender,
                        count: consecutiveCount
                    ))
                }
                currentSender = message.senderName
                rangeStartIndex = index
                consecutiveCount = 1
            }
        }

        // 最後のチェック
        if consecutiveCount > chaseThreshold {
            ranges.append(ChaseMessageRange(
                startIndex: rangeStartIndex,
                endIndex: messages.count - 1,
                sender: currentSender,
                count: consecutiveCount
            ))
        }

        return ranges
    }

    /// 全ブロックから追いトーク回数を集計
    func countChaseMessages(in blocks: [ConversationBlock]) -> [String: Int] {
        var counts: [String: Int] = [:]

        for block in blocks {
            let ranges = detect(in: block)
            for range in ranges {
                counts[range.sender, default: 0] += range.count - chaseThreshold
            }
        }

        return counts
    }
}
