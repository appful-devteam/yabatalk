import Foundation

// MARK: - Conversation Block Analyzer
/// メッセージを会話ブロックに分割
final class ConversationBlockAnalyzer {
    private let blockGapThreshold: TimeInterval

    init(blockGapThreshold: TimeInterval = Constants.Analysis.blockGapThreshold) {
        self.blockGapThreshold = blockGapThreshold
    }

    // MARK: - Public Methods

    /// メッセージ配列を会話ブロックに分割
    func analyze(_ messages: [ChatMessage]) -> [ConversationBlock] {
        guard !messages.isEmpty else { return [] }

        // 時系列でソート
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }

        var blocks: [ConversationBlock] = []
        var currentBlockMessages: [ChatMessage] = []

        for message in sortedMessages {
            // システムメッセージはスキップ
            guard message.eventType != .system else { continue }

            if let lastMessage = currentBlockMessages.last {
                let gap = message.timestamp.timeIntervalSince(lastMessage.timestamp)

                if gap > blockGapThreshold {
                    // 新しいブロック開始
                    if let block = createBlock(from: currentBlockMessages) {
                        blocks.append(block)
                    }
                    currentBlockMessages = [message]
                } else {
                    currentBlockMessages.append(message)
                }
            } else {
                currentBlockMessages.append(message)
            }
        }

        // 最後のブロック
        if let block = createBlock(from: currentBlockMessages) {
            blocks.append(block)
        }

        return blocks
    }

    /// ブロック全体の統計を計算
    func calculateStatistics(
        blocks: [ConversationBlock],
        messages: [ChatMessage],
        chaseCounts: [String: Int]
    ) -> BlockStatistics {
        let totalBlocks = blocks.count
        let totalMessages = messages.filter { $0.eventType != .system }.count

        // 平均ブロック継続時間
        let durations = blocks.map { $0.duration }
        let averageDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        // 平均メッセージ数/ブロック
        let messageCounts = blocks.map { Double($0.messageCount) }
        let averageMessages = messageCounts.isEmpty ? 0 : messageCounts.reduce(0, +) / Double(messageCounts.count)

        // 開始回数
        var initiationCounts: [String: Int] = [:]
        for block in blocks {
            initiationCounts[block.initiator, default: 0] += 1
        }

        // 夜間ブロック/メッセージ
        let nightBlockCount = blocks.filter { $0.isNightBlock }.count
        let nightMessageCount = messages.filter { $0.isNightMessage }.count

        return BlockStatistics(
            totalBlocks: totalBlocks,
            totalMessages: totalMessages,
            averageBlockDuration: averageDuration,
            averageMessagesPerBlock: averageMessages,
            initiationCounts: initiationCounts,
            chaseCounts: chaseCounts,
            nightBlockCount: nightBlockCount,
            nightMessageCount: nightMessageCount
        )
    }

    // MARK: - Private Methods

    private func createBlock(from messages: [ChatMessage]) -> ConversationBlock? {
        guard !messages.isEmpty,
              let firstMessage = messages.first else {
            return nil
        }

        return ConversationBlock(
            messages: messages,
            initiator: firstMessage.senderName
        )
    }
}
