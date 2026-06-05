import Foundation

// MARK: - Conversation Block
/// 60分以内のメッセージをグループ化した会話ブロック
struct ConversationBlock: Identifiable, Codable {
    let id: UUID
    let messages: [ChatMessage]
    let startTime: Date
    let endTime: Date

    /// ブロックを開始した人
    let initiator: String

    init(
        id: UUID = UUID(),
        messages: [ChatMessage],
        initiator: String
    ) {
        self.id = id
        self.messages = messages
        self.startTime = messages.first?.timestamp ?? Date()
        self.endTime = messages.last?.timestamp ?? Date()
        self.initiator = initiator
    }

    // MARK: - Computed Properties

    /// ブロックの継続時間（秒）
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// ブロックの継続時間（分）
    var durationMinutes: Int {
        Int(duration / 60)
    }

    /// メッセージ数
    var messageCount: Int {
        messages.count
    }

    /// 参加者ごとのメッセージ数
    var participantMessageCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for message in messages {
            counts[message.senderName, default: 0] += 1
        }
        return counts
    }

    /// 参加者ごとのテキストメッセージ数
    var participantTextMessageCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for message in messages where message.eventType == .text {
            counts[message.senderName, default: 0] += 1
        }
        return counts
    }

    /// テキストメッセージ数
    var textMessageCount: Int {
        messages.filter { $0.eventType == .text }.count
    }

    /// 夜間のブロックか
    var isNightBlock: Bool {
        startTime.isNightTime || endTime.isNightTime
    }

    /// 質問を含むか
    var containsQuestion: Bool {
        messages.contains { $0.isQuestion }
    }

    /// 感情記号を含むか
    var containsEmotionalSymbols: Bool {
        messages.contains { $0.hasEmotionalSymbols }
    }

    // MARK: - Date Formatting

    /// 日付文字列（例: "1/15(月)"）
    var dateString: String {
        startTime.shortDateWithWeekdayString
    }

    /// 時間範囲文字列（例: "21:30 - 23:45"）
    var timeRangeString: String {
        "\(startTime.timeString) - \(endTime.timeString)"
    }
}

// MARK: - Chase Message Range
/// 追いトーク（連続送信）の範囲
struct ChaseMessageRange: Identifiable, Codable {
    let id: UUID
    let startIndex: Int
    let endIndex: Int
    let sender: String
    let count: Int

    init(
        id: UUID = UUID(),
        startIndex: Int,
        endIndex: Int,
        sender: String,
        count: Int
    ) {
        self.id = id
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.sender = sender
        self.count = count
    }
}

// MARK: - Block Statistics
/// ブロック全体の統計情報
struct BlockStatistics: Codable {
    let totalBlocks: Int
    let totalMessages: Int
    let averageBlockDuration: TimeInterval
    let averageMessagesPerBlock: Double

    /// 参加者ごとの開始回数
    let initiationCounts: [String: Int]

    /// 参加者ごとの追いトーク回数
    let chaseCounts: [String: Int]

    /// 夜間ブロック数
    let nightBlockCount: Int

    /// 夜間メッセージ数
    let nightMessageCount: Int

    init(
        totalBlocks: Int,
        totalMessages: Int,
        averageBlockDuration: TimeInterval,
        averageMessagesPerBlock: Double,
        initiationCounts: [String: Int],
        chaseCounts: [String: Int],
        nightBlockCount: Int,
        nightMessageCount: Int
    ) {
        self.totalBlocks = totalBlocks
        self.totalMessages = totalMessages
        self.averageBlockDuration = averageBlockDuration
        self.averageMessagesPerBlock = averageMessagesPerBlock
        self.initiationCounts = initiationCounts
        self.chaseCounts = chaseCounts
        self.nightBlockCount = nightBlockCount
        self.nightMessageCount = nightMessageCount
    }

    /// 参加者の開始率を計算
    func initiationRate(for participant: String) -> Double {
        guard totalBlocks > 0 else { return 0 }
        let count = initiationCounts[participant] ?? 0
        return Double(count) / Double(totalBlocks)
    }

    /// 参加者の追いトーク率を計算
    func chaseRate(for participant: String) -> Double {
        let totalChase = chaseCounts.values.reduce(0, +)
        guard totalChase > 0 else { return 0 }
        let count = chaseCounts[participant] ?? 0
        return Double(count) / Double(totalChase)
    }

    /// 夜間率
    var nightRate: Double {
        guard totalMessages > 0 else { return 0 }
        return Double(nightMessageCount) / Double(totalMessages)
    }
}
